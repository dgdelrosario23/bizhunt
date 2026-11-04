-- BizHunt QR transaction hardening: reject NULL action explicitly.
-- PostgreSQL NULL NOT IN (...) evaluates to NULL, not TRUE. The original
-- function could therefore enter its ELSE (redeem) branch for NULL action.
-- Run in Supabase SQL Editor after Phase 4. Existing records are untouched.

create or replace function public.process_visit_token(p_token text,p_campaign uuid,p_action text)
returns table(customer_id uuid,stamp_balance bigint,stamps_required int,action_taken text)
language plpgsql security definer set search_path=''
as $$
declare v_customer uuid;v_goal int;v_stamps bigint;v_redemptions bigint;v_token_id uuid;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if p_token is null or p_token !~ '^[0-9a-f]{48}$' then raise exception 'Invalid code'; end if;
 if p_action is null or p_action not in ('stamp','redeem') then raise exception 'Invalid action'; end if;
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


revoke all on function public.process_visit_token(text,uuid,text) from public,anon,authenticated;
grant execute on function public.process_visit_token(text,uuid,text) to authenticated;
