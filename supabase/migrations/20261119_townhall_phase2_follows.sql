-- Town Hall Phase 2: opt-in following of suggestions.
create table if not exists public.townhall_follows (
 post_id uuid not null references public.townhall_posts(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(post_id,user_id)
);
create index if not exists townhall_follows_user_idx on public.townhall_follows(user_id,created_at desc);
alter table public.townhall_follows enable row level security;
drop policy if exists "townhall follows own read" on public.townhall_follows;
create policy "townhall follows own read" on public.townhall_follows for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists "townhall follows own create" on public.townhall_follows;
create policy "townhall follows own create" on public.townhall_follows for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists "townhall follows own delete" on public.townhall_follows;
create policy "townhall follows own delete" on public.townhall_follows for delete to authenticated using(user_id=(select auth.uid()));
revoke all on public.townhall_follows from anon;
grant select,insert,delete on public.townhall_follows to authenticated;
