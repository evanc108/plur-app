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
create policy if not exists "Members can upload party photos"
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
create policy if not exists "Anyone can view party photos"
    on storage.objects for select to public
    using (bucket_id = 'party-photos');

-- Allow photo owner to delete their uploads
create policy if not exists "Users can delete own party photos"
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
-- 10. Refresh PostgREST schema cache
-- ============================================================
-- Supabase's REST/RPC layer caches schema metadata. After changing functions
-- (like `create_group`), you may need to refresh the cache.
notify pgrst, 'reload schema';
