-- BizHunt Phase B16: historical merchant loyalty participation metrics
-- REVIEW BEFORE APPLYING. This migration is not applied by committing it.
-- Read-only aggregate RPC; owner-authorized, scoped to one business.
begin;

create or replace function public.merchant_customer_retention_metrics(p_business_id uuid)
returns table (
  customers_with_stamps bigint,
  customers_with_multiple_stamps bigint,
  customers_in_multiple_campaigns bigint,
  stamp_customers_with_redemptions bigint,
  total_stamp_events bigint,
  total_reward_redemptions bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  with authorized as (
    select b.id
    from public.businesses b
    where b.id = p_business_id
      and b.owner_id = (select auth.uid())
  ),
  business_campaigns as (
    select c.id
    from public.campaigns c
    join authorized a on a.id = c.business_id
  ),
  customer_stamps as (
    select s.customer_id,
           count(*)::bigint as stamp_count,
           count(distinct s.campaign_id)::bigint as campaign_count
    from public.stamp_events s
    join business_campaigns c on c.id = s.campaign_id
    group by s.customer_id
  ),
  redeemed_customers as (
    select distinct r.customer_id
    from public.reward_redemptions r
    join business_campaigns c on c.id = r.campaign_id
  ),
  redemption_total as (
    select count(*)::bigint as n
    from public.reward_redemptions r
    join business_campaigns c on c.id = r.campaign_id
  )
  select
    count(*)::bigint,
    count(*) filter (where s.stamp_count >= 2)::bigint,
    count(*) filter (where s.campaign_count >= 2)::bigint,
    count(*) filter (where rc.customer_id is not null)::bigint,
    coalesce(sum(s.stamp_count),0)::bigint,
    (select n from redemption_total)
  from customer_stamps s
  left join redeemed_customers rc on rc.customer_id = s.customer_id
  where exists (select 1 from authorized);
$$;

revoke all on function public.merchant_customer_retention_metrics(uuid) from public, anon;
grant execute on function public.merchant_customer_retention_metrics(uuid) to authenticated;
commit;

-- This function intentionally returns no customer identifiers.
-- A non-owner receives an empty result (not another merchant's counts).
-- Multiple stamps are NOT verified separate visits; reward counts are events.
