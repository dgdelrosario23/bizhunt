-- Apply manually before deploying promo distribution mode UI.
-- Existing promotions retain guaranteed mode and their existing max_claims limit.
alter table public.business_promos
 add column if not exists distribution_mode text not null default 'guaranteed'
 check (distribution_mode in ('guaranteed','first_come')),
 add column if not exists max_redemptions integer
 check (max_redemptions is null or max_redemptions > 0);
create index if not exists promo_vouchers_redemption_count_idx on public.promo_vouchers(promo_id) where redeemed_at is not null;

create or replace function public.bizhunt_promo_availability()
returns table(promo_id uuid, distribution_mode text, max_saves integer, max_redemptions integer, saves bigint, redemptions bigint, sold_out boolean)
language sql stable security definer set search_path = '' as $$
 select p.id,p.distribution_mode,p.max_claims,p.max_redemptions,
   (select count(*) from public.promo_vouchers v where v.promo_id=p.id),
   (select count(*) from public.promo_vouchers v where v.promo_id=p.id and v.redeemed_at is not null),
   case when p.distribution_mode='guaranteed'
     then p.max_claims is not null and (select count(*) from public.promo_vouchers v where v.promo_id=p.id)>=p.max_claims
     else p.max_redemptions is not null and (select count(*) from public.promo_vouchers v where v.promo_id=p.id and v.redeemed_at is not null)>=p.max_redemptions end
 from public.business_promos p
 where auth.uid() is not null and p.active and p.starts_at<=now() and p.ends_at>now()
$$;
revoke all on function public.bizhunt_promo_availability() from public, anon;
grant execute on function public.bizhunt_promo_availability() to authenticated;

create or replace function public.claim_business_promo(p_promo_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare p public.business_promos%rowtype; v uuid; n bigint;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select * into p from public.business_promos where id=p_promo_id for update;
 if not found or not p.active or now()<p.starts_at or now()>=p.ends_at then raise exception 'Promotion unavailable'; end if;
 select id into v from public.promo_vouchers where promo_id=p_promo_id and customer_id=auth.uid();
 if v is not null then return v; end if;
 if p.distribution_mode='guaranteed' and p.max_claims is not null then
   select count(*) into n from public.promo_vouchers where promo_id=p_promo_id;
   if n>=p.max_claims then raise exception 'All vouchers claimed'; end if;
 elsif p.distribution_mode='first_come' and p.max_redemptions is not null then
   select count(*) into n from public.promo_vouchers where promo_id=p_promo_id and redeemed_at is not null;
   if n>=p.max_redemptions then raise exception 'Promotion sold out'; end if;
 end if;
 insert into public.promo_vouchers(promo_id,customer_id) values(p_promo_id,auth.uid()) returning id into v;
 return v;
end $$;

create or replace function public.redeem_business_promo(p_voucher_id uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare v public.promo_vouchers%rowtype; p public.business_promos%rowtype; n bigint;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 -- Lock the promo row first to serialize redemption against the cap.
 select bp.* into p from public.business_promos bp
 join public.promo_vouchers pv on pv.promo_id=bp.id
 where pv.id=p_voucher_id for update of bp;
 if not found then raise exception 'Voucher not found'; end if;
 if not exists(select 1 from public.businesses b where b.id=p.business_id and b.owner_id=auth.uid()) then raise exception 'Not authorized merchant'; end if;
 select * into v from public.promo_vouchers where id=p_voucher_id for update;
 if v.redeemed_at is not null then raise exception 'Voucher already redeemed'; end if;
 if not p.active or now()<p.starts_at or now()>=p.ends_at then raise exception 'Promotion expired or inactive'; end if;
 if p.distribution_mode='first_come' and p.max_redemptions is not null then
   select count(*) into n from public.promo_vouchers where promo_id=p.id and redeemed_at is not null;
   if n>=p.max_redemptions then raise exception 'Promotion sold out'; end if;
 end if;
 update public.promo_vouchers set redeemed_at=now(),redeemed_by=auth.uid() where id=v.id;
 return true;
end $$;
revoke all on function public.claim_business_promo(uuid),public.redeem_business_promo(uuid) from public,anon;
grant execute on function public.claim_business_promo(uuid),public.redeem_business_promo(uuid) to authenticated;
