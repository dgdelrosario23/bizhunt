-- BizHunt Explorer XP Phase 1. Run once in Supabase SQL Editor.
create table if not exists public.bizhunt_xp_events (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 event_key text not null,
 event_type text not null,
 xp integer not null check (xp between 1 and 100),
 created_at timestamptz not null default now(),
 unique(user_id,event_key)
);
alter table public.bizhunt_xp_events enable row level security;
revoke all on public.bizhunt_xp_events from anon,authenticated;
grant select on public.bizhunt_xp_events to authenticated;
drop policy if exists "Users read their own XP" on public.bizhunt_xp_events;
create policy "Users read their own XP" on public.bizhunt_xp_events for select to authenticated using (user_id=(select auth.uid()));
create or replace function public.bizhunt_award_xp() returns trigger language plpgsql security definer set search_path='' as $$
declare uid uuid; source_id text; kind text; amount integer;
begin
 if TG_TABLE_NAME='stamp_events' then
   uid:=NEW.customer_id;source_id:=NEW.id::text;kind:='stamp';amount:=10;
 elsif TG_TABLE_NAME='business_follows' then
   uid:=NEW.customer_id;source_id:=NEW.business_id::text;kind:='follow';amount:=10;
 elsif TG_TABLE_NAME='reward_redemptions' then
   uid:=NEW.customer_id;source_id:=NEW.id::text;kind:='redemption';amount:=30;
 else return NEW;
 end if;
 if uid is not null then
   insert into public.bizhunt_xp_events(user_id,event_key,event_type,xp)
   values(uid,kind||':'||source_id,kind,amount) on conflict(user_id,event_key) do nothing;
   if kind='stamp' then
     insert into public.bizhunt_xp_events(user_id,event_key,event_type,xp)
     values(uid,'first_stamp','first_stamp',40) on conflict(user_id,event_key) do nothing;
   end if;
 end if;
 return NEW;
end $$;
revoke all on function public.bizhunt_award_xp() from public,anon,authenticated;
drop trigger if exists bizhunt_xp_stamp on public.stamp_events;
create trigger bizhunt_xp_stamp after insert on public.stamp_events for each row execute function public.bizhunt_award_xp();
drop trigger if exists bizhunt_xp_follow on public.business_follows;
create trigger bizhunt_xp_follow after insert on public.business_follows for each row execute function public.bizhunt_award_xp();
drop trigger if exists bizhunt_xp_redemption on public.reward_redemptions;
create trigger bizhunt_xp_redemption after insert on public.reward_redemptions for each row execute function public.bizhunt_award_xp();
-- Backfill existing legitimate activities, idempotently.
insert into public.bizhunt_xp_events(user_id,event_key,event_type,xp)
select customer_id,'stamp:'||id::text,'stamp',10 from public.stamp_events where customer_id is not null
on conflict(user_id,event_key) do nothing;
insert into public.bizhunt_xp_events(user_id,event_key,event_type,xp)
select distinct on(customer_id) customer_id,'first_stamp','first_stamp',40 from public.stamp_events where customer_id is not null order by customer_id,created_at
on conflict(user_id,event_key) do nothing;
insert into public.bizhunt_xp_events(user_id,event_key,event_type,xp)
select customer_id,'follow:'||business_id::text,'follow',10 from public.business_follows where customer_id is not null
on conflict(user_id,event_key) do nothing;
insert into public.bizhunt_xp_events(user_id,event_key,event_type,xp)
select customer_id,'redemption:'||id::text,'redemption',30 from public.reward_redemptions where customer_id is not null
on conflict(user_id,event_key) do nothing;
