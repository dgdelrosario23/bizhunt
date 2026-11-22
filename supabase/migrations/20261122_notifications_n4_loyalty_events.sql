-- Phase N4: optional, server-generated loyalty notifications.
-- Apply manually AFTER 20261122_notifications_n3_targets.sql.
-- No changes to the existing scanner RPCs, rewards, balances or permissions.
begin;
alter table public.bizhunt_notifications
  add column if not exists source_event_type text,
  add column if not exists source_event_id uuid;
alter table public.bizhunt_notifications
  drop constraint if exists bizhunt_notifications_source_pair;
alter table public.bizhunt_notifications
  add constraint bizhunt_notifications_source_pair check (
    (source_event_type is null and source_event_id is null)
    or (source_event_type in ('stamp','redemption') and source_event_id is not null)
  );
create unique index if not exists bizhunt_notifications_source_unique
  on public.bizhunt_notifications(source_event_type,source_event_id)
  where source_event_type is not null and source_event_id is not null;

create or replace function public.bizhunt_notify_loyalty_event()
returns trigger language plpgsql security definer set search_path = ''
as $fn$
declare v_business_name text; v_campaign_name text; v_title text; v_body text;
begin
  select left(coalesce(b.name,'a BizHunt business'),70),
         left(coalesce(c.name,'your loyalty card'),70)
  into v_business_name,v_campaign_name
  from public.campaigns c
  join public.businesses b on b.id=c.business_id
  where c.id=new.campaign_id;
  if tg_table_name='stamp_events' then
    v_title:='New loyalty stamp';
    v_body:='You received a stamp for '||coalesce(v_campaign_name,'your loyalty card')||' at '||coalesce(v_business_name,'a BizHunt business')||'.';
  elsif tg_table_name='reward_redemptions' then
    v_title:='Reward redeemed';
    v_body:='Your reward redemption for '||coalesce(v_campaign_name,'your loyalty card')||' at '||coalesce(v_business_name,'a BizHunt business')||' was recorded.';
  else
    return new;
  end if;
  insert into public.bizhunt_notifications
    (user_id,title,body,kind,target_type,target_id,source_event_type,source_event_id)
  values
    (new.customer_id,v_title,left(v_body,500),
     case when tg_table_name='stamp_events' then 'stamp_earned' else 'reward_redeemed' end,
     'reward',new.id,
     case when tg_table_name='stamp_events' then 'stamp' else 'redemption' end,new.id)
  on conflict (source_event_type,source_event_id)
    where source_event_type is not null and source_event_id is not null
    do nothing;
  return new;
end;
$fn$;
revoke all on function public.bizhunt_notify_loyalty_event() from public,anon,authenticated;
drop trigger if exists bizhunt_notify_stamp_insert on public.stamp_events;
create trigger bizhunt_notify_stamp_insert after insert on public.stamp_events
for each row execute function public.bizhunt_notify_loyalty_event();
drop trigger if exists bizhunt_notify_redemption_insert on public.reward_redemptions;
create trigger bizhunt_notify_redemption_insert after insert on public.reward_redemptions
for each row execute function public.bizhunt_notify_loyalty_event();
commit;
