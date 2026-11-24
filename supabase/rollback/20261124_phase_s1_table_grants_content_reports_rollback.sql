-- Emergency rollback only; restores unsafe historical permissions and policy.
-- Run as postgres only after confirming no intervening schema/ACL changes.
begin;
set local search_path = public, pg_catalog;
set local lock_timeout = '5s';
do $$ begin
 if current_user <> 'postgres' then raise exception 'S1 requires postgres'; end if;
 if exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
cross join pg_roles r
cross join (values ('REFERENCES'),('TRIGGER'),('TRUNCATE')) p(priv)
where n.nspname='public' and c.relkind in ('r','p')
and r.rolname in ('anon','authenticated')
and has_table_privilege(r.oid,c.oid,p.priv)) then raise exception 'S1 rollback requires hardened privilege state'; end if;
 if not exists (select 1 from pg_policies where schemaname='public' and tablename='content_reports' and policyname='Reporters submit reports' and cmd='INSERT' and permissive='PERMISSIVE' and roles=array['authenticated']::name[] and regexp_replace(with_check,'[[:space:]]','','g')=regexp_replace($policy$((reporter_id = ( SELECT auth.uid() AS uid)) AND (status = 'pending'::text) AND (EXISTS ( SELECT 1
   FROM businesses b
  WHERE (b.id = content_reports.business_id))) AND ((review_id IS NULL) OR (EXISTS ( SELECT 1
   FROM business_reviews r
  WHERE ((r.id = content_reports.review_id) AND (r.business_id = content_reports.business_id))))))$policy$,'[[:space:]]','','g')) then raise exception 'S1 rollback policy mismatch'; end if;
end $$;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_communities TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_communities TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_comments TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_comments TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_id_tokens TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_id_tokens TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_members TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_members TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_places TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_places TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_posts TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_posts TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_reactions TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_reactions TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_votes TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_community_votes TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_curated_follows TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.bizhunt_curated_follows TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.business_follows TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.business_follows TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.business_gallery TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.business_gallery TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.business_menu_files TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.business_menu_files TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.business_promos TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.business_promos TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.business_reviews TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.business_reviews TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.business_saves TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.business_verification_requests TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.businesses TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.businesses TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.campaigns TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.campaigns TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.community_collection_places TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.community_collection_saves TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.community_collections TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.community_profiles TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.community_user_follows TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.content_reports TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.emergency_contacts TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.emergency_contacts TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.profiles TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.profiles TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.promo_impressions TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.promo_impressions TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.promo_vouchers TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.promo_vouchers TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.reward_redemptions TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.reward_redemptions TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.stamp_events TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.stamp_events TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.townhall_comments TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.townhall_comments TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.townhall_follows TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.townhall_posts TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.townhall_posts TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.townhall_status_history TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.townhall_status_history TO authenticated;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.townhall_votes TO anon;
GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.townhall_votes TO authenticated;
alter policy "Reporters submit reports" on public.content_reports
with check (
  reporter_id = (select auth.uid())
  and status = 'pending'::text
  and exists (select 1 from public.businesses b where b.id = content_reports.business_id)
  and (review_id is null or exists (
    select 1 from public.business_reviews r
    where r.id = content_reports.review_id
      and r.business_id = r.business_id
  ))
);
commit;
