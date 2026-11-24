-- Phase S1: exact November 24 snapshot; run as postgres only after staging test.
begin;
set local search_path = public, pg_catalog;
set local lock_timeout = '5s';
create temporary table s1_expected(table_name text, role_name text, primary key(table_name,role_name)) on commit drop;
insert into s1_expected values
    ('bizhunt_communities', 'anon'),
    ('bizhunt_communities', 'authenticated'),
    ('bizhunt_community_comments', 'anon'),
    ('bizhunt_community_comments', 'authenticated'),
    ('bizhunt_community_id_tokens', 'anon'),
    ('bizhunt_community_id_tokens', 'authenticated'),
    ('bizhunt_community_members', 'anon'),
    ('bizhunt_community_members', 'authenticated'),
    ('bizhunt_community_places', 'anon'),
    ('bizhunt_community_places', 'authenticated'),
    ('bizhunt_community_posts', 'anon'),
    ('bizhunt_community_posts', 'authenticated'),
    ('bizhunt_community_reactions', 'anon'),
    ('bizhunt_community_reactions', 'authenticated'),
    ('bizhunt_community_votes', 'anon'),
    ('bizhunt_community_votes', 'authenticated'),
    ('bizhunt_curated_follows', 'anon'),
    ('bizhunt_curated_follows', 'authenticated'),
    ('business_follows', 'anon'),
    ('business_follows', 'authenticated'),
    ('business_gallery', 'anon'),
    ('business_gallery', 'authenticated'),
    ('business_menu_files', 'anon'),
    ('business_menu_files', 'authenticated'),
    ('business_promos', 'anon'),
    ('business_promos', 'authenticated'),
    ('business_reviews', 'anon'),
    ('business_reviews', 'authenticated'),
    ('business_saves', 'authenticated'),
    ('business_verification_requests', 'authenticated'),
    ('businesses', 'anon'),
    ('businesses', 'authenticated'),
    ('campaigns', 'anon'),
    ('campaigns', 'authenticated'),
    ('community_collection_places', 'authenticated'),
    ('community_collection_saves', 'authenticated'),
    ('community_collections', 'authenticated'),
    ('community_profiles', 'authenticated'),
    ('community_user_follows', 'authenticated'),
    ('content_reports', 'authenticated'),
    ('emergency_contacts', 'anon'),
    ('emergency_contacts', 'authenticated'),
    ('profiles', 'anon'),
    ('profiles', 'authenticated'),
    ('promo_impressions', 'anon'),
    ('promo_impressions', 'authenticated'),
    ('promo_vouchers', 'anon'),
    ('promo_vouchers', 'authenticated'),
    ('reward_redemptions', 'anon'),
    ('reward_redemptions', 'authenticated'),
    ('stamp_events', 'anon'),
    ('stamp_events', 'authenticated'),
    ('townhall_comments', 'anon'),
    ('townhall_comments', 'authenticated'),
    ('townhall_follows', 'authenticated'),
    ('townhall_posts', 'anon'),
    ('townhall_posts', 'authenticated'),
    ('townhall_status_history', 'anon'),
    ('townhall_status_history', 'authenticated'),
    ('townhall_votes', 'anon'),
    ('townhall_votes', 'authenticated');
do $$
begin
  if current_user <> 'postgres' then raise exception 'S1 requires postgres'; end if;
  if exists (
    with expected as (
      select e.table_name,e.role_name,p.priv,'postgres'::text as grantor,false as grantable
      from s1_expected e cross join (values ('REFERENCES'),('TRIGGER'),('TRUNCATE')) p(priv)
    ), actual as (
      select c.relname::text, r.rolname::text,a.privilege_type,pg_get_userbyid(a.grantor)::text,a.is_grantable
      from pg_class c join pg_namespace n on n.oid=c.relnamespace
      cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a
      join pg_roles r on r.oid=a.grantee
      where n.nspname='public' and c.relkind in ('r','p')
      and r.rolname in ('anon','authenticated') and a.privilege_type in ('REFERENCES','TRIGGER','TRUNCATE')
    )
    (select * from expected except select * from actual)
    union all
    (select * from actual except select * from expected)
  ) then raise exception 'S1 grant snapshot mismatch'; end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='content_reports'
    and policyname='Reporters submit reports' and cmd='INSERT' and permissive='PERMISSIVE'
    and roles=array['authenticated']::name[] and qual is null
    and regexp_replace(with_check,'[[:space:]]','','g')=regexp_replace($policy$((reporter_id = ( SELECT auth.uid() AS uid)) AND (status = 'pending'::text) AND (EXISTS ( SELECT 1
   FROM businesses b
  WHERE (b.id = content_reports.business_id))) AND ((review_id IS NULL) OR (EXISTS ( SELECT 1
   FROM business_reviews r
  WHERE ((r.id = content_reports.review_id) AND (r.business_id = r.business_id))))))$policy$,'[[:space:]]','','g'))
    or (select count(*) from pg_policies where schemaname='public' and tablename='content_reports' and cmd in ('INSERT','ALL'))<>1
  then raise exception 'S1 report policy snapshot mismatch'; end if;
end $$;
revoke references, trigger, truncate on table public.bizhunt_communities from anon restrict;
revoke references, trigger, truncate on table public.bizhunt_communities from authenticated restrict;
revoke references, trigger, truncate on table public.bizhunt_community_comments from anon restrict;
revoke references, trigger, truncate on table public.bizhunt_community_comments from authenticated restrict;
revoke references, trigger, truncate on table public.bizhunt_community_id_tokens from anon restrict;
revoke references, trigger, truncate on table public.bizhunt_community_id_tokens from authenticated restrict;
revoke references, trigger, truncate on table public.bizhunt_community_members from anon restrict;
revoke references, trigger, truncate on table public.bizhunt_community_members from authenticated restrict;
revoke references, trigger, truncate on table public.bizhunt_community_places from anon restrict;
revoke references, trigger, truncate on table public.bizhunt_community_places from authenticated restrict;
revoke references, trigger, truncate on table public.bizhunt_community_posts from anon restrict;
revoke references, trigger, truncate on table public.bizhunt_community_posts from authenticated restrict;
revoke references, trigger, truncate on table public.bizhunt_community_reactions from anon restrict;
revoke references, trigger, truncate on table public.bizhunt_community_reactions from authenticated restrict;
revoke references, trigger, truncate on table public.bizhunt_community_votes from anon restrict;
revoke references, trigger, truncate on table public.bizhunt_community_votes from authenticated restrict;
revoke references, trigger, truncate on table public.bizhunt_curated_follows from anon restrict;
revoke references, trigger, truncate on table public.bizhunt_curated_follows from authenticated restrict;
revoke references, trigger, truncate on table public.business_follows from anon restrict;
revoke references, trigger, truncate on table public.business_follows from authenticated restrict;
revoke references, trigger, truncate on table public.business_gallery from anon restrict;
revoke references, trigger, truncate on table public.business_gallery from authenticated restrict;
revoke references, trigger, truncate on table public.business_menu_files from anon restrict;
revoke references, trigger, truncate on table public.business_menu_files from authenticated restrict;
revoke references, trigger, truncate on table public.business_promos from anon restrict;
revoke references, trigger, truncate on table public.business_promos from authenticated restrict;
revoke references, trigger, truncate on table public.business_reviews from anon restrict;
revoke references, trigger, truncate on table public.business_reviews from authenticated restrict;
revoke references, trigger, truncate on table public.business_saves from authenticated restrict;
revoke references, trigger, truncate on table public.business_verification_requests from authenticated restrict;
revoke references, trigger, truncate on table public.businesses from anon restrict;
revoke references, trigger, truncate on table public.businesses from authenticated restrict;
revoke references, trigger, truncate on table public.campaigns from anon restrict;
revoke references, trigger, truncate on table public.campaigns from authenticated restrict;
revoke references, trigger, truncate on table public.community_collection_places from authenticated restrict;
revoke references, trigger, truncate on table public.community_collection_saves from authenticated restrict;
revoke references, trigger, truncate on table public.community_collections from authenticated restrict;
revoke references, trigger, truncate on table public.community_profiles from authenticated restrict;
revoke references, trigger, truncate on table public.community_user_follows from authenticated restrict;
revoke references, trigger, truncate on table public.content_reports from authenticated restrict;
revoke references, trigger, truncate on table public.emergency_contacts from anon restrict;
revoke references, trigger, truncate on table public.emergency_contacts from authenticated restrict;
revoke references, trigger, truncate on table public.profiles from anon restrict;
revoke references, trigger, truncate on table public.profiles from authenticated restrict;
revoke references, trigger, truncate on table public.promo_impressions from anon restrict;
revoke references, trigger, truncate on table public.promo_impressions from authenticated restrict;
revoke references, trigger, truncate on table public.promo_vouchers from anon restrict;
revoke references, trigger, truncate on table public.promo_vouchers from authenticated restrict;
revoke references, trigger, truncate on table public.reward_redemptions from anon restrict;
revoke references, trigger, truncate on table public.reward_redemptions from authenticated restrict;
revoke references, trigger, truncate on table public.stamp_events from anon restrict;
revoke references, trigger, truncate on table public.stamp_events from authenticated restrict;
revoke references, trigger, truncate on table public.townhall_comments from anon restrict;
revoke references, trigger, truncate on table public.townhall_comments from authenticated restrict;
revoke references, trigger, truncate on table public.townhall_follows from authenticated restrict;
revoke references, trigger, truncate on table public.townhall_posts from anon restrict;
revoke references, trigger, truncate on table public.townhall_posts from authenticated restrict;
revoke references, trigger, truncate on table public.townhall_status_history from anon restrict;
revoke references, trigger, truncate on table public.townhall_status_history from authenticated restrict;
revoke references, trigger, truncate on table public.townhall_votes from anon restrict;
revoke references, trigger, truncate on table public.townhall_votes from authenticated restrict;
alter policy "Reporters submit reports" on public.content_reports
with check (
  reporter_id = (select auth.uid())
  and status = 'pending'::text
  and exists (select 1 from public.businesses b where b.id = content_reports.business_id)
  and (review_id is null or exists (
    select 1 from public.business_reviews r
    where r.id = content_reports.review_id
      and r.business_id = content_reports.business_id
  ))
);
do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
cross join pg_roles r
cross join (values ('REFERENCES'),('TRIGGER'),('TRUNCATE')) p(priv)
where n.nspname='public' and c.relkind in ('r','p')
and r.rolname in ('anon','authenticated')
and has_table_privilege(r.oid,c.oid,p.priv)) then raise exception 'S1 residual effective privileges; transaction aborted'; end if;
end $$;
commit;
