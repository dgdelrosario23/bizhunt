-- Phase 17: collections, public creator profiles and social following
-- Run in Supabase SQL Editor after earlier migrations.
create table if not exists public.community_profiles(
 user_id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique check(username ~ '^[a-z0-9_]{3,24}$'),
 display_name text not null default '' check(char_length(display_name)<=60),
 bio text not null default '' check(char_length(bio)<=240),
 created_at timestamptz not null default now()
);
create table if not exists public.community_collections(
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 title text not null check(char_length(btrim(title)) between 3 and 100),
 description text not null default '' check(char_length(description)<=500),
 visibility text not null default 'private' check(visibility in ('private','public')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.community_collection_places(
 collection_id uuid not null references public.community_collections(id) on delete cascade,
 business_id uuid not null references public.businesses(id) on delete cascade,
 position integer not null default 0 check(position between 0 and 10000),
 note text not null default '' check(char_length(note)<=240),
 primary key(collection_id,business_id)
);
create table if not exists public.community_user_follows(
 follower_id uuid not null references auth.users(id) on delete cascade,
 followed_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(follower_id,followed_id),
 check(follower_id<>followed_id)
);
create table if not exists public.community_collection_saves(
 user_id uuid not null references auth.users(id) on delete cascade,
 collection_id uuid not null references public.community_collections(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(user_id,collection_id)
);
create index if not exists community_collections_public_recent on public.community_collections(visibility,updated_at desc);
create index if not exists community_collection_places_position on public.community_collection_places(collection_id,position);
create index if not exists community_follows_followed on public.community_user_follows(followed_id);
create index if not exists community_saves_collection on public.community_collection_saves(collection_id);
alter table public.community_profiles enable row level security;
alter table public.community_collections enable row level security;
alter table public.community_collection_places enable row level security;
alter table public.community_user_follows enable row level security;
alter table public.community_collection_saves enable row level security;

create policy "Public creator profiles" on public.community_profiles for select to authenticated using(true);
create policy "Create own creator profile" on public.community_profiles for insert to authenticated with check(user_id=(select auth.uid()));
create policy "Update own creator profile" on public.community_profiles for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy "Visible collections" on public.community_collections for select to authenticated using(visibility='public' or owner_id=(select auth.uid()));
create policy "Create own collections" on public.community_collections for insert to authenticated with check(owner_id=(select auth.uid()));
create policy "Edit own collections" on public.community_collections for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy "Delete own collections" on public.community_collections for delete to authenticated using(owner_id=(select auth.uid()));
create policy "Visible collection places" on public.community_collection_places for select to authenticated using(exists(select 1 from public.community_collections c where c.id=collection_id and (c.visibility='public' or c.owner_id=(select auth.uid()))));
create policy "Owner adds collection places" on public.community_collection_places for insert to authenticated with check(exists(select 1 from public.community_collections c where c.id=collection_id and c.owner_id=(select auth.uid())));
create policy "Owner updates collection places" on public.community_collection_places for update to authenticated using(exists(select 1 from public.community_collections c where c.id=collection_id and c.owner_id=(select auth.uid()))) with check(exists(select 1 from public.community_collections c where c.id=collection_id and c.owner_id=(select auth.uid())));
create policy "Owner removes collection places" on public.community_collection_places for delete to authenticated using(exists(select 1 from public.community_collections c where c.id=collection_id and c.owner_id=(select auth.uid())));
create policy "Follow counts and relationships" on public.community_user_follows for select to authenticated using(true);
create policy "Follow other creators" on public.community_user_follows for insert to authenticated with check(follower_id=(select auth.uid()) and exists(select 1 from public.community_profiles p where p.user_id=followed_id));
create policy "Unfollow creators" on public.community_user_follows for delete to authenticated using(follower_id=(select auth.uid()));
-- Collection saves are private to the saver. Discovery rankings use an aggregate RPC.
create policy "Read own collection saves" on public.community_collection_saves for select to authenticated using(user_id=(select auth.uid()));
create policy "Save public collections" on public.community_collection_saves for insert to authenticated with check(user_id=(select auth.uid()) and exists(select 1 from public.community_collections c where c.id=collection_id and c.visibility='public'));
create policy "Unsave own collections" on public.community_collection_saves for delete to authenticated using(user_id=(select auth.uid()));
revoke all on public.community_profiles,public.community_collections,public.community_collection_places,public.community_user_follows,public.community_collection_saves from anon;
grant select,insert,update,delete on public.community_profiles,public.community_collections,public.community_collection_places,public.community_user_follows,public.community_collection_saves to authenticated;
-- Enforce visibility changes: saves on newly private lists are removed.
create or replace function public.community_private_cleanup()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.visibility='public' and new.visibility='private' then
  delete from public.community_collection_saves where collection_id=new.id;
 end if;
 return new;
end $$;
drop trigger if exists community_private_cleanup_trigger on public.community_collections;
create trigger community_private_cleanup_trigger after update of visibility on public.community_collections
for each row execute function public.community_private_cleanup();
-- Read-only public list ranking; no user IDs of savers exposed.
create or replace function public.community_collection_rankings()
returns table(collection_id uuid,save_count bigint,recent_saves bigint)
language sql stable security definer set search_path='' as $$
 select c.id,count(s.user_id),count(s.user_id) filter(where s.created_at>=now()-interval '14 days')
 from public.community_collections c
 left join public.community_collection_saves s on s.collection_id=c.id
 where c.visibility='public'
 group by c.id
$$;
revoke all on function public.community_collection_rankings() from public,anon;
grant execute on function public.community_collection_rankings() to authenticated;
