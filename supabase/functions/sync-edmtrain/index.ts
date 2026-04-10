// supabase/functions/sync-edmtrain/index.ts
// Edge Function that syncs EDM Train events + locations into Supabase.
// Triggered by an external cron service or invoked manually.
// Optimized: only 2 API calls total (1 locations + 1 events).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const EDMTRAIN_API = "https://edmtrain.com/api";

interface SyncLog {
  sync_type: string;
  events_upserted: number;
  started_at: string;
  completed_at?: string;
  error?: string;
}

Deno.serve(async (req) => {
  try {
    // Auth guard: require the service role key or a shared secret
    const authHeader = req.headers.get("Authorization") ?? "";
    const expectedKey = Deno.env.get("SYNC_SECRET") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!expectedKey || authHeader !== `Bearer ${expectedKey}`) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }

    const edmTrainApiKey = Deno.env.get("EDMTRAIN_API_KEY");
    if (!edmTrainApiKey) {
      return new Response(JSON.stringify({ error: "EDMTRAIN_API_KEY not set" }), { status: 500 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const startedAt = new Date().toISOString();
    let totalEventsUpserted = 0;

    // --- 1. Sync all US locations (single API call) ---
    console.log("Fetching all locations...");
    const locUrl = `${EDMTRAIN_API}/locations?client=${edmTrainApiKey}`;
    const locRes = await fetch(locUrl);

    if (!locRes.ok) {
      throw new Error(`Locations API returned ${locRes.status}`);
    }

    const locJson = await locRes.json();
    if (!locJson.success) {
      throw new Error(`Locations API error: ${locJson.message}`);
    }

    const allLocations: any[] = locJson.data ?? [];
    console.log(`Fetched ${allLocations.length} locations`);

    if (allLocations.length > 0) {
      const locationRows = allLocations.map((loc: any) => ({
        id: loc.id,
        city: loc.city,
        state: loc.state,
        state_code: loc.stateCode,
        country: loc.country,
        country_code: loc.countryCode,
        latitude: loc.latitude,
        longitude: loc.longitude,
        link: loc.link ?? null,
      }));

      // Batch upsert in chunks of 500
      for (let i = 0; i < locationRows.length; i += 500) {
        const chunk = locationRows.slice(i, i + 500);
        const { error: locErr } = await supabase
          .from("edmtrain_locations")
          .upsert(chunk, { onConflict: "id" });

        if (locErr) console.error("Location upsert error:", locErr.message);
      }
      console.log(`Upserted ${locationRows.length} locations`);
    }

    // --- 2. Sync all events (single API call, next 90 days) ---
    console.log("Fetching all events...");
    const today = new Date();
    const endDate = new Date(today);
    endDate.setDate(endDate.getDate() + 90);

    const startStr = formatDate(today);
    const endStr = formatDate(endDate);

    const evtUrl = `${EDMTRAIN_API}/events?client=${edmTrainApiKey}&startDate=${startStr}&endDate=${endStr}`;
    const evtRes = await fetch(evtUrl);

    if (!evtRes.ok) {
      throw new Error(`Events API returned ${evtRes.status}`);
    }

    const evtJson = await evtRes.json();
    if (!evtJson.success) {
      throw new Error(`Events API error: ${evtJson.message}`);
    }

    const events: any[] = evtJson.data ?? [];
    console.log(`Fetched ${events.length} events`);

    if (events.length > 0) {
      // Upsert events in chunks
      const eventRows = events.map((e: any) => ({
        id: e.id,
        name: e.name ?? null,
        date: e.date,
        start_time: e.startTime ?? null,
        end_time: e.endTime ?? null,
        ages: e.ages ?? null,
        festival_ind: e.festivalInd ?? false,
        livestream_ind: e.livestreamInd ?? false,
        electronic_genre_ind: e.electronicGenreInd ?? true,
        other_genre_ind: e.otherGenreInd ?? false,
        link: e.link ?? null,
        created_date: e.createdDate ?? null,
        venue_id: e.venue?.id ?? null,
        venue_name: e.venue?.name ?? null,
        venue_location: e.venue?.location ?? null,
        venue_address: e.venue?.address ?? null,
        venue_state: e.venue?.state ?? null,
        venue_country: e.venue?.country ?? null,
        venue_latitude: e.venue?.latitude ?? null,
        venue_longitude: e.venue?.longitude ?? null,
        synced_at: new Date().toISOString(),
      }));

      for (let i = 0; i < eventRows.length; i += 500) {
        const chunk = eventRows.slice(i, i + 500);
        const { error: evtErr } = await supabase
          .from("edmtrain_events")
          .upsert(chunk, { onConflict: "id" });

        if (evtErr) {
          console.error(`Event upsert error (batch ${i}):`, evtErr.message);
        } else {
          totalEventsUpserted += chunk.length;
        }
      }

      // Upsert artists
      const artistRows: any[] = [];
      for (const e of events) {
        if (!Array.isArray(e.artistList)) continue;
        e.artistList.forEach((a: any, idx: number) => {
          artistRows.push({
            event_id: e.id,
            artist_id: a.id,
            artist_name: a.name,
            artist_link: a.link ?? null,
            b2b_ind: a.b2bInd ?? false,
            sort_order: idx,
          });
        });
      }

      for (let i = 0; i < artistRows.length; i += 500) {
        const chunk = artistRows.slice(i, i + 500);
        const { error: artErr } = await supabase
          .from("edmtrain_event_artists")
          .upsert(chunk, { onConflict: "event_id,artist_id" });

        if (artErr) console.error(`Artist upsert error (batch ${i}):`, artErr.message);
      }
    }

    // --- 3. Cleanup old events ---
    const cutoff = new Date(today);
    cutoff.setDate(cutoff.getDate() - 7);
    const { error: delErr } = await supabase
      .from("edmtrain_events")
      .delete()
      .lt("date", formatDate(cutoff));

    if (delErr) console.error("Cleanup error:", delErr.message);

    // --- 4. Log sync result ---
    const log: SyncLog = {
      sync_type: "full",
      events_upserted: totalEventsUpserted,
      started_at: startedAt,
      completed_at: new Date().toISOString(),
    };

    await supabase.from("edmtrain_sync_log").insert(log);

    console.log(`Sync complete: ${totalEventsUpserted} events upserted`);
    return new Response(JSON.stringify({ success: true, ...log }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    console.error("Sync failed:", errorMsg);

    try {
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      const supabase = createClient(supabaseUrl, supabaseServiceKey);
      await supabase.from("edmtrain_sync_log").insert({
        sync_type: "full",
        events_upserted: 0,
        started_at: new Date().toISOString(),
        completed_at: new Date().toISOString(),
        error: errorMsg,
      });
    } catch { /* ignore logging failure */ }

    return new Response(JSON.stringify({ error: errorMsg }), { status: 500 });
  }
});

function formatDate(d: Date): string {
  return d.toISOString().split("T")[0];
}
