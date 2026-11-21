-- Phase B24: historical owner-scoped campaign analytics. REVIEW BEFORE APPLYING.
begin;
create or replace function public.merchant_campaign_history_metrics(p_business_id uuid)
returns table(campaign_id uuid,customers_with_stamps bigint,customers_with_multiple_stamps bigint,total_stamp_events bigint,total_reward_redemptions bigint)
language sql stable security definer set search_path = ''
as $$
with authorized as (
 select id from public.businesses where id=p_business_id and owner_id=(select auth.uid())
), owned as (
 select c.id from public.campaigns c join authorized a on a.id=c.business_id
), customer_counts as (
 select s.campaign_id,s.customer_id,count(*)::bigint as n from public.stamp_events s
 join owned c on c.id=s.campaign_id where s.customer_id is not null group by s.campaign_id,s.customer_id
), customers as (
 select campaign_id,count(*)::bigint as total,count(*) filter(where n>=2)::bigint as multiple
 from customer_counts group by campaign_id
), stamps as (
 select s.campaign_id,count(*)::bigint as n from public.stamp_events s join owned c on c.id=s.campaign_id group by s.campaign_id
), redemptions as (
 select r.campaign_id,count(*)::bigint as n from public.reward_redemptions r join owned c on c.id=r.campaign_id group by r.campaign_id
)
select c.id,coalesce(u.total,0)::bigint,coalesce(u.multiple,0)::bigint,coalesce(s.n,0)::bigint,coalesce(r.n,0)::bigint
from owned c left join customers u on u.campaign_id=c.id
left join stamps s on s.campaign_id=c.id left join redemptions r on r.campaign_id=c.id;
$$;
revoke all on function public.merchant_campaign_history_metrics(uuid) from public,anon;
grant execute on function public.merchant_campaign_history_metrics(uuid) to authenticated;
commit;
-- Non-owner: zero rows. No customer identifiers returned. Multiple stamps do not prove repeat visits.
