-- Town Hall Phase 1: persist suggestion lifecycle status.
-- Safe to run after supabase/phase_townhall.sql.
alter table public.townhall_posts
  add column if not exists status text not null default 'Submitted';
alter table public.townhall_posts
  drop constraint if exists townhall_posts_status_check;
alter table public.townhall_posts
  add constraint townhall_posts_status_check
  check (status in ('Submitted','Under Review','Planned','In Progress','Completed','Declined'));
create index if not exists townhall_posts_status_idx on public.townhall_posts(status);
-- Status updates are intentionally not granted to ordinary users.
-- A future founder dashboard can use a server-authorized operation to change status.
