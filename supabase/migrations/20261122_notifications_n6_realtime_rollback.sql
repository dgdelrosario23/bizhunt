-- Optional Phase N6 rollback: remove notifications from the Realtime publication.
do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='bizhunt_notifications'
  ) then
    alter publication supabase_realtime drop table public.bizhunt_notifications;
  end if;
end $$;
