-- F1 Founder Overview v2: additive, read-only analytics. Apply manually after review.
-- Preserves founder_dashboard() and all existing administrative RPCs.
begin;
create or replace function public.bizhunt_founder_overview_v2(p_days integer default 30)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare v_from timestamptz; v_previous timestamptz; v_now timestamptz := now(); v_result jsonb;
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.founder_admins f where f.user_id = (select auth.uid())
  ) then
    raise exception 'Founder access only' using errcode = '42501';
  end if;
  if p_days is null or p_days not in (7,30,90) then
    raise exception 'Invalid reporting period' using errcode = '22023';
  end if;
  v_from := v_now - make_interval(days => p_days);
  v_previous := v_from - make_interval(days => p_days);
  select jsonb_build_object(
    'days',p_days,
    'generated_at',v_now,
    'new_users',(select count(*) from auth.users where created_at >= v_from and created_at < v_now),
    'previous_new_users',(select count(*) from auth.users where created_at >= v_previous and created_at < v_from),
    'new_businesses',(select count(*) from public.businesses where created_at >= v_from and created_at < v_now),
    'previous_new_businesses',(select count(*) from public.businesses where created_at >= v_previous and created_at < v_from),
    'stamps',(select count(*) from public.stamp_events where created_at >= v_from and created_at < v_now),
    'previous_stamps',(select count(*) from public.stamp_events where created_at >= v_previous and created_at < v_from),
    'redemptions',(select count(*) from public.reward_redemptions where created_at >= v_from and created_at < v_now),
    'previous_redemptions',(select count(*) from public.reward_redemptions where created_at >= v_previous and created_at < v_from),
    'claimed_businesses',(select count(*) from public.businesses where owner_id is not null),
    'unclaimed_registered_businesses',(select count(*) from public.businesses where owner_id is null),
    'pending_verifications',(select count(*) from public.business_verification_requests where status='pending'),
    'open_reports',(select count(*) from public.content_reports where status in ('pending','reviewing'))
  ) into v_result;
  return v_result;
end $$;
revoke all on function public.bizhunt_founder_overview_v2(integer) from public, anon, authenticated;
grant execute on function public.bizhunt_founder_overview_v2(integer) to authenticated;
commit;
