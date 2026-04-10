-- ============================================================
-- PLUR Party Features — Database Migration
-- Run this in the Supabase SQL Editor (https://supabase.com/dashboard)
-- ============================================================

-- ============================================================
-- 1. Tables
-- ============================================================

-- Profiles (mirrors AppUser)
create table if not exists profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    username text unique not null,
    display_name text not null,
    avatar_url text,
    bio text,
    created_at timestamptz not null default now()
);

-- Groups / Parties (mirrors RaveGroup)
create table if not exists groups (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    rave_id int not null default 0,
    created_by uuid not null references profiles(id),
    invite_code text unique not null,
    event_name text not null,
    venue text not null default 'TBD',
    start_date timestamptz not null,
    end_date timestamptz not null,
    playlist_link text,
    created_at timestamptz not null default now()
);

-- ============================================================
-- 1b. Schema repair (for existing databases)
-- ============================================================
-- If you created `groups` before adding `event_name`, the RPC `create_group`
-- will fail with: "column event_name of relation groups does not exist".
-- This block makes the migration safe to re-run.

-- If an earlier schema added a foreign key for `rave_id` (e.g. to a `raves` table),
-- it will break when we store EDM Train event IDs. Remove it.
alter table public.groups drop constraint if exists groups_rave_id_fkey;

-- If an earlier schema pointed `created_by` at a `users` table, fix it to `profiles`.
alter table public.groups drop constraint if exists groups_created_by_fkey;
alter table public.groups
    add constraint groups_created_by_fkey
    foreign key (created_by) references public.profiles(id);

alter table groups add column if not exists event_name text;
alter table groups add column if not exists venue text;
alter table groups add column if not exists rave_id int;
alter table groups add column if not exists start_date timestamptz;
alter table groups add column if not exists end_date timestamptz;
alter table groups add column if not exists playlist_link text;

do $$
begin
    -- Attempt to migrate from common older column names, if present.
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'groups' and column_name = 'event'
    ) then
        execute 'update public.groups set event_name = coalesce(event_name, event::text)';
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'groups' and column_name = 'event_title'
    ) then
        execute 'update public.groups set event_name = coalesce(event_name, event_title::text)';
    end if;
end $$;

update public.groups
set event_name = coalesce(event_name, name)
where event_name is null;

alter table public.groups alter column event_name set not null;

update public.groups
set venue = coalesce(venue, 'TBD')
where venue is null;

alter table public.groups alter column venue set default 'TBD';
alter table public.groups alter column venue set not null;

update public.groups
set rave_id = coalesce(rave_id, 0)
where rave_id is null;

alter table public.groups alter column rave_id set default 0;
alter table public.groups alter column rave_id set not null;

update public.groups
set start_date = coalesce(start_date, created_at, now())
where start_date is null;

update public.groups
set end_date = coalesce(end_date, start_date)
where end_date is null;

alter table public.groups alter column start_date set not null;
alter table public.groups alter column end_date set not null;

-- Group Members (mirrors GroupMember)
create table if not exists group_members (
    id uuid primary key default gen_random_uuid(),
    group_id uuid not null references groups(id) on delete cascade,
    user_id uuid not null references profiles(id) on delete cascade,
    role text not null default 'member' check (role in ('owner', 'admin', 'member')),
    rsvp_status text not null default 'going' check (rsvp_status in ('going', 'maybe', 'invited')),
    display_name text not null,
    joined_at timestamptz not null default now(),
    unique(group_id, user_id)
);

-- Schema repair (for existing databases)
alter table public.group_members drop constraint if exists group_members_user_id_fkey;
alter table public.group_members
    add constraint group_members_user_id_fkey
    foreign key (user_id) references public.profiles(id) on delete cascade;

alter table public.group_members add column if not exists role text;
alter table public.group_members add column if not exists rsvp_status text;
alter table public.group_members add column if not exists display_name text;
alter table public.group_members add column if not exists joined_at timestamptz;

update public.group_members set role = coalesce(role, 'member') where role is null;
alter table public.group_members alter column role set default 'member';
alter table public.group_members alter column role set not null;

update public.group_members set rsvp_status = coalesce(rsvp_status, 'going') where rsvp_status is null;
alter table public.group_members alter column rsvp_status set default 'going';
alter table public.group_members alter column rsvp_status set not null;

update public.group_members set display_name = coalesce(display_name, 'Unknown') where display_name is null;
alter table public.group_members alter column display_name set not null;

update public.group_members set joined_at = coalesce(joined_at, now()) where joined_at is null;
alter table public.group_members alter column joined_at set default now();
alter table public.group_members alter column joined_at set not null;

-- Messages (mirrors Message)
create table if not exists messages (
    id uuid primary key default gen_random_uuid(),
    group_id uuid not null references groups(id) on delete cascade,
    user_id uuid not null references profiles(id) on delete cascade,
    sender_name text not null,
    content text not null,
    is_pinned boolean not null default false,
    created_at timestamptz not null default now()
);

-- Schema repair (for existing databases)
alter table public.messages drop constraint if exists messages_user_id_fkey;
alter table public.messages
    add constraint messages_user_id_fkey
    foreign key (user_id) references public.profiles(id) on delete cascade;

alter table public.messages add column if not exists sender_name text;
alter table public.messages add column if not exists is_pinned boolean;
alter table public.messages add column if not exists created_at timestamptz;

update public.messages set sender_name = coalesce(sender_name, 'Unknown') where sender_name is null;
alter table public.messages alter column sender_name set not null;

update public.messages set is_pinned = coalesce(is_pinned, false) where is_pinned is null;
alter table public.messages alter column is_pinned set default false;
alter table public.messages alter column is_pinned set not null;

update public.messages set created_at = coalesce(created_at, now()) where created_at is null;
alter table public.messages alter column created_at set default now();
alter table public.messages alter column created_at set not null;

-- Announcements (mirrors Announcement)
create table if not exists announcements (
    id uuid primary key default gen_random_uuid(),
    group_id uuid not null references groups(id) on delete cascade,
    user_id uuid not null references profiles(id) on delete cascade,
    title text not null,
    content text not null,
    is_pinned boolean not null default false,
    created_at timestamptz not null default now()
);

-- Schema repair (for existing databases)
alter table public.announcements drop constraint if exists announcements_user_id_fkey;
alter table public.announcements
    add constraint announcements_user_id_fkey
    foreign key (user_id) references public.profiles(id) on delete cascade;

alter table public.announcements add column if not exists title text;
alter table public.announcements add column if not exists is_pinned boolean;
alter table public.announcements add column if not exists created_at timestamptz;

update public.announcements set title = coalesce(title, 'Announcement') where title is null;
alter table public.announcements alter column title set not null;

update public.announcements set is_pinned = coalesce(is_pinned, false) where is_pinned is null;
alter table public.announcements alter column is_pinned set default false;
alter table public.announcements alter column is_pinned set not null;

update public.announcements set created_at = coalesce(created_at, now()) where created_at is null;
alter table public.announcements alter column created_at set default now();
alter table public.announcements alter column created_at set not null;

-- Photos (mirrors Photo)
create table if not exists photos (
    id uuid primary key default gen_random_uuid(),
    group_id uuid not null references groups(id) on delete cascade,
    user_id uuid not null references profiles(id) on delete cascade,
    image_url text not null,
    caption text,
    created_at timestamptz not null default now()
);

-- Schema repair (for existing databases)
alter table public.photos drop constraint if exists photos_user_id_fkey;
alter table public.photos
    add constraint photos_user_id_fkey
    foreign key (user_id) references public.profiles(id) on delete cascade;

alter table public.photos add column if not exists image_url text;
alter table public.photos add column if not exists created_at timestamptz;

update public.photos set image_url = coalesce(image_url, '') where image_url is null;
alter table public.photos alter column image_url set not null;

update public.photos set created_at = coalesce(created_at, now()) where created_at is null;
alter table public.photos alter column created_at set default now();
alter table public.photos alter column created_at set not null;

-- ============================================================
-- 2. RLS Helper (inline membership checks)
-- ============================================================
-- Avoid policies that reference `group_members` from within `group_members` policies,
-- which can trigger infinite recursion in Postgres. We keep membership checks inline
-- on other tables (groups/messages/etc).

-- ============================================================
-- 3. Row-Level Security
-- ============================================================

alter table profiles enable row level security;
alter table groups enable row level security;
alter table group_members enable row level security;
alter table messages enable row level security;
alter table announcements enable row level security;
alter table photos enable row level security;

-- If you previously experimented with different policy names, ensure we don't
-- keep any legacy `group_members` policies around (they can cause recursion).
do $$
declare
    r record;
begin
    for r in
        select policyname
        from pg_policies
        where schemaname = 'public' and tablename = 'group_members'
    loop
        execute format('drop policy if exists %I on public.group_members', r.policyname);
    end loop;
end $$;

-- Profiles
drop policy if exists "Profiles are viewable by authenticated users" on profiles;
create policy "Profiles are viewable by authenticated users"
    on profiles for select to authenticated using (true);
drop policy if exists "Users can insert own profile" on profiles;
create policy "Users can insert own profile"
    on profiles for insert to authenticated with check (auth.uid() = id);
drop policy if exists "Users can update own profile" on profiles;
create policy "Users can update own profile"
    on profiles for update to authenticated using (auth.uid() = id);

-- Groups
drop policy if exists "Group members can view their groups" on groups;
create policy "Group members can view their groups"
    on groups for select to authenticated
    using (
        exists (
            select 1 from public.group_members gm
            where gm.group_id = groups.id and gm.user_id = auth.uid()
        )
    );
drop policy if exists "Authenticated users can create groups" on groups;
create policy "Authenticated users can create groups"
    on groups for insert to authenticated
    with check (auth.uid() = created_by);
drop policy if exists "Group owner can update group" on groups;
create policy "Group owner can update group"
    on groups for update to authenticated
    using (auth.uid() = created_by);

-- Group Members
create policy "Members can view co-members"
    on group_members for select to authenticated
    using (true);
drop policy if exists "Users can insert themselves as members" on group_members;
create policy "Users can insert themselves as members"
    on group_members for insert to authenticated
    with check (auth.uid() = user_id);
drop policy if exists "Users can update own membership" on group_members;
create policy "Users can update own membership"
    on group_members for update to authenticated
    using (auth.uid() = user_id);

-- Messages
drop policy if exists "Members can view messages" on messages;
create policy "Members can view messages"
    on messages for select to authenticated
    using (
        exists (
            select 1 from public.group_members gm
            where gm.group_id = messages.group_id and gm.user_id = auth.uid()
        )
    );
drop policy if exists "Members can send messages" on messages;
create policy "Members can send messages"
    on messages for insert to authenticated
    with check (
        auth.uid() = user_id and
        exists (
            select 1 from public.group_members gm
            where gm.group_id = messages.group_id and gm.user_id = auth.uid()
        )
    );
drop policy if exists "Members can toggle pin on messages" on messages;
create policy "Members can toggle pin on messages"
    on messages for update to authenticated
    using (
        exists (
            select 1 from public.group_members gm
            where gm.group_id = messages.group_id and gm.user_id = auth.uid()
        )
    );

-- Announcements
drop policy if exists "Members can view announcements" on announcements;
create policy "Members can view announcements"
    on announcements for select to authenticated
    using (
        exists (
            select 1 from public.group_members gm
            where gm.group_id = announcements.group_id and gm.user_id = auth.uid()
        )
    );
drop policy if exists "Admins can create announcements" on announcements;
create policy "Admins can create announcements"
    on announcements for insert to authenticated
    with check (
        auth.uid() = user_id and
        exists (
            select 1 from public.group_members gm
            where gm.group_id = announcements.group_id and gm.user_id = auth.uid()
        )
    );

-- Photos
drop policy if exists "Members can view photos" on photos;
create policy "Members can view photos"
    on photos for select to authenticated
    using (
        exists (
            select 1 from public.group_members gm
            where gm.group_id = photos.group_id and gm.user_id = auth.uid()
        )
    );
drop policy if exists "Members can upload photos" on photos;
create policy "Members can upload photos"
    on photos for insert to authenticated
    with check (
        auth.uid() = user_id and
        exists (
            select 1 from public.group_members gm
            where gm.group_id = photos.group_id and gm.user_id = auth.uid()
        )
    );

drop policy if exists "Users can delete own photos" on photos;
create policy "Users can delete own photos"
    on photos for delete to authenticated
    using (auth.uid() = user_id);

-- ============================================================
-- 4. RPC Functions
-- ============================================================

-- Create a group atomically (group row + owner membership)
create or replace function create_group(
    p_name text,
    p_event_name text,
    p_rave_id int default 0,
    p_venue text default 'TBD',
    p_start_date timestamptz default now(),
    p_end_date timestamptz default now(),
    p_playlist_link text default null
) returns void as $$
declare
    new_group_id uuid;
    user_profile profiles;
    invite text;
    auth_row auth.users;
begin
    invite := upper(substr(md5(random()::text), 1, 6));

    -- Ensure the caller has a profile row (avoids FK violation on groups.created_by).
    select * into strict auth_row from auth.users where id = auth.uid();
    insert into public.profiles (id, username, display_name)
    values (
        auth.uid(),
        coalesce(auth_row.raw_user_meta_data->>'username', 'user_' || left(auth.uid()::text, 8)),
        coalesce(auth_row.raw_user_meta_data->>'display_name', 'user_' || left(auth.uid()::text, 8))
    )
    on conflict (id) do nothing;

    select * into strict user_profile from public.profiles where id = auth.uid();

    insert into groups (name, created_by, invite_code, event_name, rave_id, venue, start_date, end_date, playlist_link)
    values (p_name, auth.uid(), invite, p_event_name, p_rave_id, p_venue, p_start_date, p_end_date, p_playlist_link)
    returning id into new_group_id;

    insert into group_members (group_id, user_id, role, rsvp_status, display_name)
    values (new_group_id, auth.uid(), 'owner', 'going', user_profile.display_name);
end;
$$ language plpgsql security definer;

-- Join a group by invite code
create or replace function join_group_by_code(p_code text)
returns void as $$
declare
    found_group groups;
    user_profile profiles;
begin
    select * into found_group from groups where invite_code = p_code;
    if not found then
        raise exception 'No group found with that invite code';
    end if;

    select * into strict user_profile from profiles where id = auth.uid();

    insert into group_members (group_id, user_id, role, rsvp_status, display_name)
    values (found_group.id, auth.uid(), 'member', 'going', user_profile.display_name)
    on conflict (group_id, user_id) do nothing;
end;
$$ language plpgsql security definer;

-- Invite another user to a group (caller must be a member)
create or replace function invite_to_group(p_group_id uuid, p_user_id uuid)
returns void as $$
declare
    invitee_profile profiles;
begin
    if not exists (
        select 1 from public.group_members gm
        where gm.group_id = p_group_id and gm.user_id = auth.uid()
    ) then
        raise exception 'Only group members can invite others';
    end if;

    select * into strict invitee_profile from profiles where id = p_user_id;

    insert into group_members (group_id, user_id, role, rsvp_status, display_name)
    values (p_group_id, p_user_id, 'member', 'invited', invitee_profile.display_name)
    on conflict (group_id, user_id) do nothing;
end;
$$ language plpgsql security definer;

-- ============================================================
-- 5. Indexes
-- ============================================================

create index if not exists idx_group_members_group_id on group_members(group_id);
create index if not exists idx_group_members_user_id on group_members(user_id);
create index if not exists idx_messages_group_id_created on messages(group_id, created_at);
create index if not exists idx_groups_invite_code on groups(invite_code);

-- ============================================================
-- 6. Profile Trigger (auto-create on signup)
-- ============================================================

create or replace function handle_new_user()
returns trigger as $$
begin
    insert into public.profiles (id, username, display_name)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'username', 'user_' || left(new.id::text, 8)),
        coalesce(new.raw_user_meta_data->>'display_name', 'user_' || left(new.id::text, 8))
    )
    on conflict do nothing;
    return new;
exception when others then
    raise log 'handle_new_user failed for %: %', new.id, sqlerrm;
    return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function handle_new_user();

-- ============================================================
-- 7. Backfill profiles for existing auth users
-- ============================================================

insert into profiles (id, username, display_name)
select
    id,
    'user_' || left(id::text, 8),
    'user_' || left(id::text, 8)
from auth.users
where id not in (select id from profiles)
on conflict do nothing;

-- ============================================================
-- 8. Storage Bucket for Party Photos
-- ============================================================

insert into storage.buckets (id, name, public)
values ('party-photos', 'party-photos', true)
on conflict (id) do nothing;

-- Allow authenticated group members to upload photos into their group's folder
drop policy if exists "Members can upload party photos" on storage.objects;
create policy "Members can upload party photos"
    on storage.objects for insert to authenticated
    with check (
        bucket_id = 'party-photos' and
        exists (
            select 1 from public.group_members gm
            where gm.group_id = (storage.foldername(name))[1]::uuid
              and gm.user_id = auth.uid()
        )
    );

-- Allow anyone to read (bucket is public, but belt-and-suspenders)
drop policy if exists "Anyone can view party photos" on storage.objects;
create policy "Anyone can view party photos"
    on storage.objects for select to public
    using (bucket_id = 'party-photos');

-- Allow photo owner to delete their uploads
drop policy if exists "Users can delete own party photos" on storage.objects;
create policy "Users can delete own party photos"
    on storage.objects for delete to authenticated
    using (
        bucket_id = 'party-photos' and
        owner = auth.uid()
    );

-- ============================================================
-- 9. Photos table indexes
-- ============================================================

create index if not exists idx_photos_group_id on photos(group_id);
create index if not exists idx_photos_user_id on photos(user_id);

-- ============================================================
-- 10. Festival schedule (lineups + per-group set selections)
-- ============================================================
-- Dummy schedule is keyed by rave_id = 888888 (EDMTrain-style int).
-- Point a test group's groups.rave_id at 888888 to see the grid in the app.

create table if not exists event_schedules (
    id uuid primary key default gen_random_uuid(),
    rave_id int not null unique,
    timezone text not null,
    created_at timestamptz not null default now()
);

create table if not exists schedule_days (
    id uuid primary key default gen_random_uuid(),
    schedule_id uuid not null references event_schedules(id) on delete cascade,
    day_index int not null check (day_index >= 1),
    label text not null,
    unique (schedule_id, day_index)
);

create table if not exists schedule_stages (
    id uuid primary key default gen_random_uuid(),
    schedule_id uuid not null references event_schedules(id) on delete cascade,
    name text not null,
    sort_order int not null,
    accent_color text,
    unique (schedule_id, sort_order)
);

create table if not exists schedule_slots (
    id uuid primary key default gen_random_uuid(),
    schedule_id uuid not null references event_schedules(id) on delete cascade,
    day_id uuid not null references schedule_days(id) on delete cascade,
    stage_id uuid not null references schedule_stages(id) on delete cascade,
    title text not null,
    start_at timestamptz not null,
    end_at timestamptz not null,
    edmtrain_artist_id int,
    created_at timestamptz not null default now()
);

create table if not exists set_selections (
    id uuid primary key default gen_random_uuid(),
    group_id uuid not null references groups(id) on delete cascade,
    user_id uuid not null references profiles(id) on delete cascade,
    slot_id uuid not null references schedule_slots(id) on delete cascade,
    created_at timestamptz not null default now(),
    unique (group_id, user_id, slot_id)
);

create index if not exists idx_schedule_slots_day_start on schedule_slots(day_id, start_at);
create index if not exists idx_schedule_slots_schedule_day on schedule_slots(schedule_id, day_id);
create index if not exists idx_set_selections_group_slot on set_selections(group_id, slot_id);
create index if not exists idx_set_selections_group_user on set_selections(group_id, user_id);

alter table event_schedules enable row level security;
alter table schedule_days enable row level security;
alter table schedule_stages enable row level security;
alter table schedule_slots enable row level security;
alter table set_selections enable row level security;

drop policy if exists "Authenticated users can read event schedules" on event_schedules;
create policy "Authenticated users can read event schedules"
    on event_schedules for select to authenticated using (true);

drop policy if exists "Authenticated users can read schedule days" on schedule_days;
create policy "Authenticated users can read schedule days"
    on schedule_days for select to authenticated using (true);

drop policy if exists "Authenticated users can read schedule stages" on schedule_stages;
create policy "Authenticated users can read schedule stages"
    on schedule_stages for select to authenticated using (true);

drop policy if exists "Authenticated users can read schedule slots" on schedule_slots;
create policy "Authenticated users can read schedule slots"
    on schedule_slots for select to authenticated using (true);

drop policy if exists "Group members can view set selections" on set_selections;
create policy "Group members can view set selections"
    on set_selections for select to authenticated
    using (
        exists (
            select 1 from public.group_members gm
            where gm.group_id = set_selections.group_id and gm.user_id = auth.uid()
        )
    );

drop policy if exists "Group members can insert own set selections" on set_selections;
create policy "Group members can insert own set selections"
    on set_selections for insert to authenticated
    with check (
        auth.uid() = user_id and
        exists (
            select 1 from public.group_members gm
            where gm.group_id = set_selections.group_id and gm.user_id = auth.uid()
        )
    );

drop policy if exists "Users can delete own set selections" on set_selections;
create policy "Users can delete own set selections"
    on set_selections for delete to authenticated
    using (auth.uid() = user_id);

-- Dummy Ultra Miami–style grid data (America/New_York, March 2026)
insert into event_schedules (rave_id, timezone) values (888888, 'America/New_York')
on conflict (rave_id) do nothing;

do $$
declare
    sid uuid;
    d1 uuid := '22222222-2222-4222-8222-222222222201'::uuid;
    d2 uuid := '22222222-2222-4222-8222-222222222202'::uuid;
    d3 uuid := '22222222-2222-4222-8222-222222222203'::uuid;
    st_main uuid := '33333333-3333-4333-8333-333333333301'::uuid;
    st_world uuid := '33333333-3333-4333-8333-333333333302'::uuid;
    st_mega uuid := '33333333-3333-4333-8333-333333333303'::uuid;
    st_cove uuid := '33333333-3333-4333-8333-333333333304'::uuid;
    st_live uuid := '33333333-3333-4333-8333-333333333305'::uuid;
    st_radio uuid := '33333333-3333-4333-8333-333333333306'::uuid;
    st_grove uuid := '33333333-3333-4333-8333-333333333307'::uuid;
begin
    select id into sid from event_schedules where rave_id = 888888 limit 1;
    if sid is null then
        return;
    end if;

    delete from schedule_slots where schedule_id = sid and title = 'AURORA LIVE';

    insert into schedule_days (id, schedule_id, day_index, label) values
        (d1, sid, 1, 'Fri, Mar 27'),
        (d2, sid, 2, 'Sat, Mar 28'),
        (d3, sid, 3, 'Sun, Mar 29')
    on conflict (schedule_id, day_index) do nothing;

    insert into schedule_stages (id, schedule_id, name, sort_order, accent_color) values
        (st_main, sid, 'Mainstage', 1, '#8B6B78'),
        (st_world, sid, 'Worldwide', 2, '#5C7D8A'),
        (st_mega, sid, 'Resistance Megastructure', 3, '#5A8A72'),
        (st_cove, sid, 'Resistance The Cove', 4, '#8A7A5C'),
        (st_live, sid, 'Live Arena', 5, '#7268A0'),
        (st_radio, sid, 'UMF Radio', 6, '#4F7A8A'),
        (st_grove, sid, 'Oasis Grove', 7, '#6B6560')
    on conflict (schedule_id, sort_order) do nothing;

    update schedule_stages set accent_color = v.accent_color, name = v.name
    from (values
        (1, 'Mainstage', '#8B6B78'),
        (2, 'Worldwide', '#5C7D8A'),
        (3, 'Resistance Megastructure', '#5A8A72'),
        (4, 'Resistance The Cove', '#8A7A5C'),
        (5, 'Live Arena', '#7268A0'),
        (6, 'UMF Radio', '#4F7A8A'),
        (7, 'Oasis Grove', '#6B6560')
    ) as v(sort_order, name, accent_color)
    where schedule_stages.schedule_id = sid and schedule_stages.sort_order = v.sort_order;

    select id into d1 from schedule_days where schedule_id = sid and day_index = 1;
    select id into d2 from schedule_days where schedule_id = sid and day_index = 2;
    select id into d3 from schedule_days where schedule_id = sid and day_index = 3;
    select id into st_main from schedule_stages where schedule_id = sid and sort_order = 1;
    select id into st_world from schedule_stages where schedule_id = sid and sort_order = 2;
    select id into st_mega from schedule_stages where schedule_id = sid and sort_order = 3;
    select id into st_cove from schedule_stages where schedule_id = sid and sort_order = 4;
    select id into st_live from schedule_stages where schedule_id = sid and sort_order = 5;
    select id into st_radio from schedule_stages where schedule_id = sid and sort_order = 6;
    select id into st_grove from schedule_stages where schedule_id = sid and sort_order = 7;

    -- Day 1 sample slots (local times encoded as timestamptz on that calendar day)
    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_main, 'FRANK WALKER', '2026-03-27 16:00:00-04', '2026-03-27 16:45:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'FRANK WALKER' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_main, 'WORSHIP', '2026-03-27 17:00:00-04', '2026-03-27 18:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'WORSHIP' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_world, 'MAR-T', '2026-03-27 16:00:00-04', '2026-03-27 17:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'MAR-T' and stage_id = st_world);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_world, 'PRADA2000', '2026-03-27 18:55:00-04', '2026-03-27 19:45:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'PRADA2000' and stage_id = st_world);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_mega, 'TECHNO SET A', '2026-03-27 15:00:00-04', '2026-03-27 17:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'TECHNO SET A' and stage_id = st_mega);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_cove, 'SUNSET HOUR', '2026-03-27 18:00:00-04', '2026-03-27 19:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'SUNSET HOUR' and stage_id = st_cove);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_main, 'PLUR OPEN', '2026-03-27 15:00:00-04', '2026-03-27 15:40:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'PLUR OPEN' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_world, 'EARLY BIRD', '2026-03-27 15:10:00-04', '2026-03-27 15:55:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'EARLY BIRD' and stage_id = st_world);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_world, 'ZONE 3', '2026-03-27 17:35:00-04', '2026-03-27 18:50:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'ZONE 3' and stage_id = st_world);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_world, 'NIGHT SHIFT', '2026-03-27 19:55:00-04', '2026-03-27 21:20:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'NIGHT SHIFT' and stage_id = st_world);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_mega, 'DEEP CUT', '2026-03-27 17:05:00-04', '2026-03-27 18:20:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'DEEP CUT' and stage_id = st_mega);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_mega, 'PEAK TECHNO', '2026-03-27 18:30:00-04', '2026-03-27 20:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'PEAK TECHNO' and stage_id = st_mega);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_cove, 'CHILL PAD', '2026-03-27 16:00:00-04', '2026-03-27 17:15:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'CHILL PAD' and stage_id = st_cove);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_cove, 'LATE GROOVE', '2026-03-27 19:35:00-04', '2026-03-27 21:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'LATE GROOVE' and stage_id = st_cove);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_main, 'PRIME BLOCK', '2026-03-27 18:45:00-04', '2026-03-27 20:15:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'PRIME BLOCK' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_main, 'ENCORE HOUR', '2026-03-27 20:25:00-04', '2026-03-27 21:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'ENCORE HOUR' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_live, 'B2B WARMUP', '2026-03-27 15:30:00-04', '2026-03-27 16:45:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'B2B WARMUP' and stage_id = st_live);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_live, 'LIVE BAND EDM', '2026-03-27 17:00:00-04', '2026-03-27 18:10:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'LIVE BAND EDM' and stage_id = st_live);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_live, 'ARENA CLOSER', '2026-03-27 19:15:00-04', '2026-03-27 20:45:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'ARENA CLOSER' and stage_id = st_live);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_radio, 'FIRST AIR', '2026-03-27 15:20:00-04', '2026-03-27 16:10:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'FIRST AIR' and stage_id = st_radio);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_radio, 'DRIVE TIME', '2026-03-27 16:20:00-04', '2026-03-27 17:50:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'DRIVE TIME' and stage_id = st_radio);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_radio, 'SUNSET MIX', '2026-03-27 18:00:00-04', '2026-03-27 19:25:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'SUNSET MIX' and stage_id = st_radio);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_radio, 'CLOSING BROADCAST', '2026-03-27 19:35:00-04', '2026-03-27 21:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'CLOSING BROADCAST' and stage_id = st_radio);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_grove, 'ACOUSTIC BITES', '2026-03-27 15:45:00-04', '2026-03-27 16:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'ACOUSTIC BITES' and stage_id = st_grove);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_grove, 'GROVE SESSION', '2026-03-27 16:40:00-04', '2026-03-27 17:55:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'GROVE SESSION' and stage_id = st_grove);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_grove, 'FIREPIT SET', '2026-03-27 18:05:00-04', '2026-03-27 19:20:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'FIREPIT SET' and stage_id = st_grove);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d1, st_grove, 'LATE GROVE', '2026-03-27 19:30:00-04', '2026-03-27 20:55:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d1 and title = 'LATE GROVE' and stage_id = st_grove);

    -- Day 2
    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_main, 'HEADLINER ONE', '2026-03-28 21:00:00-04', '2026-03-28 23:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'HEADLINER ONE' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_world, 'AFTERNOON VIBES', '2026-03-28 14:00:00-04', '2026-03-28 16:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'AFTERNOON VIBES' and stage_id = st_world);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_main, 'DAY TWO OPEN', '2026-03-28 15:00:00-04', '2026-03-28 15:45:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'DAY TWO OPEN' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_main, 'BUILD UP', '2026-03-28 16:00:00-04', '2026-03-28 17:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'BUILD UP' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_main, 'SUNSET MAIN', '2026-03-28 17:45:00-04', '2026-03-28 19:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'SUNSET MAIN' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_main, 'PRIME TIME D2', '2026-03-28 19:15:00-04', '2026-03-28 20:45:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'PRIME TIME D2' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_world, 'WORLD GROOVE', '2026-03-28 16:15:00-04', '2026-03-28 17:45:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'WORLD GROOVE' and stage_id = st_world);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_world, 'GLOBAL HOUR', '2026-03-28 18:00:00-04', '2026-03-28 19:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'GLOBAL HOUR' and stage_id = st_world);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_world, 'LATE WORLD', '2026-03-28 19:45:00-04', '2026-03-28 21:15:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'LATE WORLD' and stage_id = st_world);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_mega, 'MEGA WARMUP', '2026-03-28 15:30:00-04', '2026-03-28 17:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'MEGA WARMUP' and stage_id = st_mega);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_mega, 'WAREHOUSE', '2026-03-28 17:15:00-04', '2026-03-28 18:45:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'WAREHOUSE' and stage_id = st_mega);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_mega, 'MEGA PEAK', '2026-03-28 19:00:00-04', '2026-03-28 20:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'MEGA PEAK' and stage_id = st_mega);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_cove, 'COVE DAY', '2026-03-28 15:00:00-04', '2026-03-28 16:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'COVE DAY' and stage_id = st_cove);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_cove, 'COVE NIGHT', '2026-03-28 17:00:00-04', '2026-03-28 18:45:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'COVE NIGHT' and stage_id = st_cove);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_live, 'ARENA D2', '2026-03-28 16:00:00-04', '2026-03-28 17:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'ARENA D2' and stage_id = st_live);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_live, 'LIVE D2 LATE', '2026-03-28 18:00:00-04', '2026-03-28 19:45:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'LIVE D2 LATE' and stage_id = st_live);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_radio, 'RADIO MATINEE', '2026-03-28 15:15:00-04', '2026-03-28 16:45:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'RADIO MATINEE' and stage_id = st_radio);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_radio, 'RADIO PRIME', '2026-03-28 17:00:00-04', '2026-03-28 18:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'RADIO PRIME' and stage_id = st_radio);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_grove, 'GROVE D2', '2026-03-28 15:45:00-04', '2026-03-28 17:15:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'GROVE D2' and stage_id = st_grove);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d2, st_grove, 'GROVE LATE D2', '2026-03-28 17:30:00-04', '2026-03-28 19:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d2 and title = 'GROVE LATE D2' and stage_id = st_grove);

    -- Day 3
    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d3, st_main, 'CLOSING SET', '2026-03-29 22:00:00-04', '2026-03-29 23:59:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d3 and title = 'CLOSING SET' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d3, st_main, 'FINAL DAY KICK', '2026-03-29 16:00:00-04', '2026-03-29 17:15:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d3 and title = 'FINAL DAY KICK' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d3, st_main, 'LAST SUNSET', '2026-03-29 17:30:00-04', '2026-03-29 19:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d3 and title = 'LAST SUNSET' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d3, st_main, 'PRE-CLOSE', '2026-03-29 19:15:00-04', '2026-03-29 21:45:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d3 and title = 'PRE-CLOSE' and stage_id = st_main);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d3, st_world, 'WORLD FINALE A', '2026-03-29 16:30:00-04', '2026-03-29 18:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d3 and title = 'WORLD FINALE A' and stage_id = st_world);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d3, st_world, 'WORLD FINALE B', '2026-03-29 18:15:00-04', '2026-03-29 19:45:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d3 and title = 'WORLD FINALE B' and stage_id = st_world);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d3, st_world, 'WORLD OUTRO', '2026-03-29 20:00:00-04', '2026-03-29 21:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d3 and title = 'WORLD OUTRO' and stage_id = st_world);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d3, st_mega, 'MEGA FINALE', '2026-03-29 17:00:00-04', '2026-03-29 19:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d3 and title = 'MEGA FINALE' and stage_id = st_mega);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d3, st_cove, 'COVE GOODBYE', '2026-03-29 16:00:00-04', '2026-03-29 18:30:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d3 and title = 'COVE GOODBYE' and stage_id = st_cove);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d3, st_live, 'ARENA SWAN', '2026-03-29 18:00:00-04', '2026-03-29 20:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d3 and title = 'ARENA SWAN' and stage_id = st_live);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d3, st_radio, 'SIGN-OFF MIX', '2026-03-29 19:00:00-04', '2026-03-29 21:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d3 and title = 'SIGN-OFF MIX' and stage_id = st_radio);

    insert into schedule_slots (schedule_id, day_id, stage_id, title, start_at, end_at, edmtrain_artist_id)
    select sid, d3, st_grove, 'LAST GROVE', '2026-03-29 17:15:00-04', '2026-03-29 19:00:00-04', null
    where not exists (select 1 from schedule_slots where day_id = d3 and title = 'LAST GROVE' and stage_id = st_grove);
end $$;

-- ============================================================
-- 11. EDM Train Cache Tables
-- ============================================================
-- Shared event cache so the iOS app never hits the EDMTrain API directly.
-- A Supabase Edge Function syncs data on a schedule.

create extension if not exists pg_trgm;

-- Cached locations (one row per city)
create table if not exists edmtrain_locations (
    id int primary key,
    city text not null,
    state text not null,
    state_code text not null,
    country text not null,
    country_code text not null,
    latitude double precision not null,
    longitude double precision not null,
    link text
);

-- Cached events (denormalized with venue info)
create table if not exists edmtrain_events (
    id int primary key,
    name text,
    date date not null,
    start_time text,
    end_time text,
    ages text,
    festival_ind boolean not null default false,
    livestream_ind boolean not null default false,
    electronic_genre_ind boolean not null default true,
    other_genre_ind boolean not null default false,
    link text,
    created_date text,
    venue_id int,
    venue_name text,
    venue_location text,
    venue_address text,
    venue_state text,
    venue_country text,
    venue_latitude double precision,
    venue_longitude double precision,
    synced_at timestamptz not null default now()
);

create index if not exists idx_edmtrain_events_date on edmtrain_events(date);
create index if not exists idx_edmtrain_events_venue_state on edmtrain_events(venue_state);
create index if not exists idx_edmtrain_events_name_trgm on edmtrain_events using gin (coalesce(name, '') gin_trgm_ops);

-- Event artists (join table)
create table if not exists edmtrain_event_artists (
    event_id int not null references edmtrain_events(id) on delete cascade,
    artist_id int not null,
    artist_name text not null,
    artist_link text,
    b2b_ind boolean not null default false,
    sort_order int not null default 0,
    primary key (event_id, artist_id)
);

create index if not exists idx_edmtrain_artists_name on edmtrain_event_artists(artist_name);

-- Sync audit log
create table if not exists edmtrain_sync_log (
    id bigint generated always as identity primary key,
    sync_type text not null,
    events_upserted int not null default 0,
    started_at timestamptz not null default now(),
    completed_at timestamptz,
    error text
);

-- ============================================================
-- 12. EDM Train Cache — RLS (read-only for app users)
-- ============================================================

alter table edmtrain_locations enable row level security;
alter table edmtrain_events enable row level security;
alter table edmtrain_event_artists enable row level security;
alter table edmtrain_sync_log enable row level security;

-- Authenticated users can read cached data
create policy "edmtrain_locations_select"
    on edmtrain_locations for select
    to authenticated using (true);

create policy "edmtrain_events_select"
    on edmtrain_events for select
    to authenticated using (true);

create policy "edmtrain_event_artists_select"
    on edmtrain_event_artists for select
    to authenticated using (true);

create policy "edmtrain_sync_log_select"
    on edmtrain_sync_log for select
    to authenticated using (true);

-- ============================================================
-- 13. EDM Train Cache — Search RPC
-- ============================================================
-- Returns JSON matching the iOS EDMTrainEvent Codable shape (camelCase keys).

create or replace function search_events(
    p_location_ids int[] default null,
    p_artist_ids int[] default null,
    p_venue_ids int[] default null,
    p_event_name text default null,
    p_start_date date default null,
    p_end_date date default null,
    p_festival_only boolean default false,
    p_include_electronic boolean default true,
    p_include_other_genres boolean default false,
    p_limit int default 100,
    p_offset int default 0
) returns jsonb
language sql stable
as $$
    select coalesce(jsonb_agg(evt order by evt->>'date', evt->>'id'), '[]'::jsonb)
    from (
        select jsonb_build_object(
            'id', e.id,
            'name', e.name,
            'date', to_char(e.date, 'YYYY-MM-DD'),
            'startTime', e.start_time,
            'endTime', e.end_time,
            'ages', e.ages,
            'festivalInd', e.festival_ind,
            'livestreamInd', e.livestream_ind,
            'electronicGenreInd', e.electronic_genre_ind,
            'otherGenreInd', e.other_genre_ind,
            'link', e.link,
            'createdDate', e.created_date,
            'venue', case when e.venue_id is not null then jsonb_build_object(
                'id', e.venue_id,
                'name', coalesce(e.venue_name, ''),
                'location', e.venue_location,
                'address', e.venue_address,
                'state', e.venue_state,
                'country', e.venue_country,
                'latitude', e.venue_latitude,
                'longitude', e.venue_longitude
            ) else null end,
            'artistList', coalesce((
                select jsonb_agg(
                    jsonb_build_object(
                        'id', a.artist_id,
                        'name', a.artist_name,
                        'link', a.artist_link,
                        'b2bInd', a.b2b_ind
                    ) order by a.sort_order
                )
                from edmtrain_event_artists a
                where a.event_id = e.id
            ), '[]'::jsonb)
        ) as evt
        from edmtrain_events e
        where
            (p_location_ids is null or exists (
                select 1 from edmtrain_locations loc
                where loc.id = any(p_location_ids)
                  and loc.state_code = e.venue_state
            ))
            and (p_venue_ids is null or e.venue_id = any(p_venue_ids))
            and (p_artist_ids is null or exists (
                select 1 from edmtrain_event_artists ea
                where ea.event_id = e.id and ea.artist_id = any(p_artist_ids)
            ))
            and (p_event_name is null or p_event_name = '' or
                 coalesce(e.name, '') ilike '%' || p_event_name || '%' or
                 exists (
                     select 1 from edmtrain_event_artists ea
                     where ea.event_id = e.id
                       and ea.artist_name ilike '%' || p_event_name || '%'
                 ))
            and (p_start_date is null or e.date >= p_start_date)
            and (p_end_date is null or e.date <= p_end_date)
            and (not p_festival_only or e.festival_ind = true)
            and (not p_include_electronic or e.electronic_genre_ind = true)
            and (not p_include_other_genres or e.other_genre_ind = true)
        order by e.date, e.id
        limit p_limit
        offset p_offset
    ) sub
$$;

-- ============================================================
-- 14. Refresh PostgREST schema cache
-- ============================================================
-- Supabase's REST/RPC layer caches schema metadata. After changing functions
-- (like `create_group`), you may need to refresh the cache.
notify pgrst, 'reload schema';
