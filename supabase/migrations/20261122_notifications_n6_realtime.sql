-- Phase N6: opt in notification table to Supabase Realtime Postgres Changes.
-- Apply manually after reviewing Supabase Realtime settings and RLS.
-- Phase 29 recipient-only SELECT RLS is mandatory.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='bizhunt_notifications'
  ) then
    alter publication supabase_realtime add table public.bizhunt_notifications;
  end if;
end $$;
-- No REPLICA IDENTITY FULL: the client refetches under RLS rather than relying on old row contents.
