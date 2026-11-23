-- BizHunt Phase S1 rollback: restore grants present in the supplied audit.
-- Do NOT execute unless reverting Phase S1. This intentionally does not
-- restore grants to any table that did not have them in the original export.
begin;
-- Original snapshot: TRUNCATE, TRIGGER and REFERENCES granted to BOTH
-- anon and authenticated on these tables.
grant truncate, trigger, references on table
  public.bizhunt_communities,
  public.bizhunt_community_comments,
  public.bizhunt_community_id_tokens,
  public.bizhunt_community_members,
  public.bizhunt_community_places,
  public.bizhunt_community_posts,
  public.bizhunt_community_reactions,
  public.bizhunt_community_votes,
  public.bizhunt_curated_follows,
  public.business_follows,
  public.business_gallery,
  public.business_menu_files,
  public.business_promos,
  public.businesses,
  public.campaigns,
  public.profiles,
  public.promo_impressions,
  public.promo_vouchers,
  public.townhall_comments,
  public.townhall_votes
to anon, authenticated;

-- Original snapshot: these grants existed for authenticated only.
grant truncate, trigger, references on table
  public.business_saves,
  public.business_verification_requests,
  public.community_collection_places,
  public.community_collection_saves,
  public.community_collections,
  public.community_profiles,
  public.community_user_follows,
  public.content_reports,
  public.townhall_follows
to authenticated;

-- Original snapshot: read-only tables still had REFERENCES/TRIGGER/TRUNCATE.
grant truncate, trigger, references on table
  public.business_reviews,
  public.emergency_contacts,
  public.reward_redemptions,
  public.stamp_events,
  public.townhall_status_history
to anon, authenticated;

-- Original snapshot: some authenticated-only tables had these grants.
grant truncate, trigger, references on table
  public.townhall_posts
to anon, authenticated;

-- Original policy as supplied in the read-only pg_policies export.
drop policy if exists "Reporters submit reports" on public.content_reports;
create policy "Reporters submit reports"
on public.content_reports
as permissive for insert to authenticated
with check (
  reporter_id = (select auth.uid())
  and status = 'pending'
  and exists (select 1 from public.businesses b where b.id = business_id)
  and (
    review_id is null
    or exists (
      select 1 from public.business_reviews r
      where r.id = content_reports.review_id
        and r.business_id = r.business_id
    )
  )
);
commit;
-- WARNING: restores unsafe historical privileges and the original policy defect.
