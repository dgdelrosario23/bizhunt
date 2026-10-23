-- BizHunt Phase 4 migration. Run AFTER supabase/schema.sql.
-- One-time customer-presented QR tokens, merchant-only issuance, atomic redemption.
create table if not exists public.visit_tokens (
 id uuid primary key default gen_random_uuid(),
 customer_id uuid not null references auth.users(id) on delete cascade,
 token_hash text not null unique,
 expires_at timestamptz not null,
 consumed_at timestamptz,
 created_at timestamptz not null default now()
);
create index if not exists visit_tokens_customer_recent on public.visit_tokens(customer_id,created_at desc);
alter table public.visit_tokens enable row level security;
revoke all on public.visit_tokens from anon, authenticated;
-- The database owner alone manages visit_tokens via constrained RPC functions.

-- Prevent direct ledger writes even if older grants or policies are present.
revoke insert,update,delete on public.stamp_events from anon,authenticated;
revoke insert,update,delete on public.reward_redemptions from anon,authenticated;
grant select on public.stamp_events,public.reward_redemptions to authenticated;
grant select on public.businesses,public.campaigns to authenticated;
grant select,insert on public.businesses,public.campaigns to authenticated;

-- Disable previous UUID-only merchant functions; they bypass the proof-of-presence flow.
revoke execute on function public.issue_stamp(uuid,uuid) from public,anon,authenticated;
revoke execute on function public.redeem_reward(uuid,uuid) from public,anon,authenticated;

create or replace function public.create_visit_token()
returns table(token text,expires_at timestamptz)
language plpgsql security definer set search_path=''
as $$
declare v_token text; v_exp timestamptz;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 -- Per-account issuance throttling. One active token at a time.
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,42));
 if (select count(*) from public.visit_tokens
     where customer_id=auth.uid() and created_at>now()-interval '1 minute')>=6
 then raise exception 'Too many codes. Please wait a minute'; end if;
 update public.visit_tokens set consumed_at=now()
 where customer_id=auth.uid() and consumed_at is null;
 v_token:=substr(replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-',''),1,48);
 v_exp:=now()+interval '90 seconds';
 insert into public.visit_tokens(customer_id,token_hash,expires_at)
 values(auth.uid(),encode(sha256(convert_to(v_token,'UTF8')),'hex'),v_exp);
 return query select v_token,v_exp;
end $$;

create or replace function public.process_visit_token(p_token text,p_campaign uuid,p_action text)
returns table(customer_id uuid,stamp_balance bigint,stamps_required int,action_taken text)
language plpgsql security definer set search_path=''
as $$
declare v_customer uuid;v_goal int;v_stamps bigint;v_redemptions bigint;v_token_id uuid;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if p_token is null or p_token !~ '^[0-9a-f]{48}$' then raise exception 'Invalid code'; end if;
 if p_action not in ('stamp','redeem') then raise exception 'Invalid action'; end if;
 select c.stamp_goal into v_goal from public.campaigns c
 join public.businesses b on b.id=c.business_id
 where c.id=p_campaign and c.active and b.owner_id=auth.uid();
 if v_goal is null then raise exception 'Merchant is not authorized for this campaign'; end if;
 select t.id,t.customer_id into v_token_id,v_customer
 from public.visit_tokens t where t.token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex')
 and t.consumed_at is null and t.expires_at>now() for update;
 if v_token_id is null then raise exception 'Code expired or already used'; end if;
 if v_customer=auth.uid() then raise exception 'Cannot approve your own visit'; end if;
 -- Serialize all stamp/redemption transactions per customer/campaign.
 perform pg_advisory_xact_lock(hashtextextended(v_customer::text||p_campaign::text,73));
 select count(*) into v_stamps from public.stamp_events s
 where s.customer_id=v_customer and s.campaign_id=p_campaign;
 select count(*) into v_redemptions from public.reward_redemptions r
 where r.customer_id=v_customer and r.campaign_id=p_campaign;
 if p_action='stamp' then
   if v_stamps-v_redemptions*v_goal >= v_goal then
     raise exception 'Reward available: redeem before collecting more stamps';
   end if;
   insert into public.stamp_events(campaign_id,customer_id,merchant_id)
   values(p_campaign,v_customer,auth.uid());
   v_stamps:=v_stamps+1;
 else
   if v_stamps-v_redemptions*v_goal < v_goal then raise exception 'Not enough stamps to redeem'; end if;
   insert into public.reward_redemptions(campaign_id,customer_id,merchant_id)
   values(p_campaign,v_customer,auth.uid());
   v_redemptions:=v_redemptions+1;
 end if;
 update public.visit_tokens set consumed_at=now() where id=v_token_id;
 return query select v_customer,v_stamps-v_redemptions*v_goal,v_goal,p_action;
end $$;

revoke all on function public.create_visit_token() from public,anon,authenticated;
revoke all on function public.process_visit_token(text,uuid,text) from public,anon,authenticated;
grant execute on function public.create_visit_token() to authenticated;
grant execute on function public.process_visit_token(text,uuid,text) to authenticated;

-- Existing select policies from schema.sql keep customer and merchant records private.
-- Production hardening: merchant verification, rate limiting at API edge,
-- location/purchase checks, audit logging, abuse monitoring, retention schedule.
