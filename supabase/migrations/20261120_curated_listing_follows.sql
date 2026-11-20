-- Community listing follows are separate from verified merchant follows.
create table if not exists public.bizhunt_curated_follows (
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references public.bizhunt_curated_businesses(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id,listing_id)
);
create index if not exists bizhunt_curated_follows_listing_idx on public.bizhunt_curated_follows(listing_id);
alter table public.bizhunt_curated_follows enable row level security;
drop policy if exists "curated follows read own" on public.bizhunt_curated_follows;
create policy "curated follows read own" on public.bizhunt_curated_follows for select to authenticated using (user_id=auth.uid());
drop policy if exists "curated follows insert own" on public.bizhunt_curated_follows;
create policy "curated follows insert own" on public.bizhunt_curated_follows for insert to authenticated with check (user_id=auth.uid());
drop policy if exists "curated follows delete own" on public.bizhunt_curated_follows;
create policy "curated follows delete own" on public.bizhunt_curated_follows for delete to authenticated using (user_id=auth.uid());
grant select,insert,delete on public.bizhunt_curated_follows to authenticated;
