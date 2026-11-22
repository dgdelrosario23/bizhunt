-- Phase N7: per-user notification preferences. Apply manually after N3/N4/N5.
begin;
create table if not exists public.bizhunt_notification_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade,
 loyalty_enabled boolean not null default true,
 community_replies_enabled boolean not null default true,
 updated_at timestamptz not null default now()
);
alter table public.bizhunt_notification_preferences enable row level security;
revoke all on public.bizhunt_notification_preferences from public,anon,authenticated;
grant select,insert,update on public.bizhunt_notification_preferences to authenticated;
drop policy if exists "Read own notification preferences" on public.bizhunt_notification_preferences;
create policy "Read own notification preferences" on public.bizhunt_notification_preferences
for select to authenticated using (user_id=auth.uid());
drop policy if exists "Create own notification preferences" on public.bizhunt_notification_preferences;
create policy "Create own notification preferences" on public.bizhunt_notification_preferences
for insert to authenticated with check (user_id=auth.uid());
drop policy if exists "Update own notification preferences" on public.bizhunt_notification_preferences;
create policy "Update own notification preferences" on public.bizhunt_notification_preferences
for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

-- Loyalty trigger respects customer choice. Preserve original trigger and ledger logic.
create or replace function public.bizhunt_notify_loyalty_event()
returns trigger language plpgsql security definer set search_path = ''
as $fn$
declare v_business_name text; v_campaign_name text; v_title text; v_body text;
begin
 if exists(select 1 from public.bizhunt_notification_preferences p where p.user_id=new.customer_id and not p.loyalty_enabled) then return new; end if;
 select left(coalesce(b.name,'a BizHunt business'),70),left(coalesce(c.name,'your loyalty card'),70)
 into v_business_name,v_campaign_name from public.campaigns c join public.businesses b on b.id=c.business_id where c.id=new.campaign_id;
 if tg_table_name='stamp_events' then
  v_title:='New loyalty stamp';
  v_body:='You received a stamp for '||coalesce(v_campaign_name,'your loyalty card')||' at '||coalesce(v_business_name,'a BizHunt business')||'.';
 elsif tg_table_name='reward_redemptions' then
  v_title:='Reward redeemed';
  v_body:='Your reward redemption for '||coalesce(v_campaign_name,'your loyalty card')||' at '||coalesce(v_business_name,'a BizHunt business')||' was recorded.';
 else return new; end if;
 insert into public.bizhunt_notifications(user_id,title,body,kind,target_type,target_id,source_event_type,source_event_id)
 values(new.customer_id,v_title,left(v_body,500),
 case when tg_table_name='stamp_events' then 'stamp_earned' else 'reward_redeemed' end,
 'reward',new.id,case when tg_table_name='stamp_events' then 'stamp' else 'redemption' end,new.id)
 on conflict (source_event_type,source_event_id)
 where source_event_type is not null and source_event_id is not null do nothing;
 return new;
end $fn$;
revoke all on function public.bizhunt_notify_loyalty_event() from public,anon,authenticated;

-- Community reply trigger respects recipient choice. Preserve membership checks and daily cap.
create or replace function public.bizhunt_notify_community_reply()
returns trigger language plpgsql security definer set search_path=''
as $fn$
declare v_author uuid;v_community uuid;v_name text;v_notification uuid;
begin
 select p.author_id,p.community_id into v_author,v_community from public.bizhunt_community_posts p where p.id=new.post_id;
 if v_author is null or v_author=new.author_id then return new; end if;
 if exists(select 1 from public.bizhunt_notification_preferences p where p.user_id=v_author and not p.community_replies_enabled) then return new; end if;
 if not exists(select 1 from public.bizhunt_community_members m where m.community_id=v_community and m.user_id=v_author and m.status='active')
 or not exists(select 1 from public.bizhunt_community_members m where m.community_id=v_community and m.user_id=new.author_id and m.status='active') then return new; end if;
 if (select count(*) from public.bizhunt_notifications n where n.user_id=v_author and n.kind='community_reply'
 and n.target_type='community' and n.target_id=v_community and n.created_at>now()-interval '24 hours')>=5 then return new; end if;
 select left(c.name,90) into v_name from public.bizhunt_communities c where c.id=v_community;
 insert into public.bizhunt_community_notification_events(comment_id) values(new.id) on conflict do nothing;
 if not found then return new; end if;
 insert into public.bizhunt_notifications(user_id,title,body,kind,target_type,target_id)
 values(v_author,'New reply to your post',left('Someone replied to your post in '||coalesce(v_name,'your community')||'.',500),'community_reply','community',v_community)
 returning id into v_notification;
 update public.bizhunt_community_notification_events set notification_id=v_notification where comment_id=new.id;
 return new;
end $fn$;
revoke all on function public.bizhunt_notify_community_reply() from public,anon,authenticated;
commit;
