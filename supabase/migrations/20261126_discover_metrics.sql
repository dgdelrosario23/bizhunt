-- Aggregate only public listing attributes; preserve caller RLS (no definer).
begin;
create or replace function public.bizhunt_discover_metrics(p_business_ids uuid[])
returns table(business_id uuid, follower_count bigint, review_count bigint, average_rating numeric, gallery_count bigint, menu_count bigint)
language sql stable security invoker set search_path = ''
as $$
 select b.id,
 (select count(*) from public.business_follows f where f.business_id=b.id),
 (select count(*) from public.business_reviews r where r.business_id=b.id),
 (select avg(r.rating) from public.business_reviews r where r.business_id=b.id),
 (select count(*) from public.business_gallery g where g.business_id=b.id),
 (select count(*) from public.business_menu_files m where m.business_id=b.id)
 from public.businesses b
 where b.id=any(p_business_ids) and cardinality(p_business_ids)<=500;
$$;
revoke all on function public.bizhunt_discover_metrics(uuid[]) from public,anon;
grant execute on function public.bizhunt_discover_metrics(uuid[]) to authenticated;
notify pgrst, 'reload schema';
commit;
