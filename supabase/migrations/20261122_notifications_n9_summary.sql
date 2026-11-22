-- N9: owner-scoped read-only notification delivery summary.
-- Requires N8 Phase 2. Apply manually in Supabase SQL Editor.
begin;
create or replace function public.bizhunt_merchant_notification_summary(p_business uuid)
returns table(
 source_type text, source_id uuid, state text, delivered integer,
 run_at timestamptz, created_at timestamptz, finished_at timestamptz
) language plpgsql stable security definer set search_path='' as $fn$
begin
 if auth.uid() is null or not exists(
  select 1 from public.businesses b where b.id=p_business and b.owner_id=auth.uid()
 ) then
  raise exception 'Business owner authorization required';
 end if;
 return query
 select j.source_type,j.source_id,j.state,j.delivered,j.run_at,j.created_at,j.finished_at
 from public.bizhunt_follower_delivery_jobs j
 where j.business_id=p_business
 order by j.created_at desc
 limit 10;
end $fn$;
revoke all on function public.bizhunt_merchant_notification_summary(uuid) from public,anon;
grant execute on function public.bizhunt_merchant_notification_summary(uuid) to authenticated;
commit;
