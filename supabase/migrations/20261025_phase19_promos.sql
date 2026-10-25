-- Phase 19: merchant promos, claims, privacy-preserving impressions and atomic redemption.
-- Apply manually in Supabase SQL Editor after prior migrations.
create table public.business_promos (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id) on delete cascade,
 title text not null check (char_length(trim(title)) between 3 and 100),
 description text not null default '' check (char_length(description)<=1000),
 terms text not null default '' check (char_length(terms)<=1000),
 starts_at timestamptz not null default now(),
 ends_at timestamptz not null,
 max_claims integer check(max_claims is null or max_claims>0),
 active boolean not null default true,
 created_at timestamptz not null default now(),
 constraint promo_dates check(ends_at>starts_at)
);
create index business_promos_business_idx on public.business_promos(business_id,ends_at);
create table public.promo_vouchers (
 id uuid primary key default gen_random_uuid(),
 promo_id uuid not null references public.business_promos(id) on delete cascade,
 customer_id uuid not null references auth.users(id) on delete cascade,
 claimed_at timestamptz not null default now(),
 redeemed_at timestamptz,
 redeemed_by uuid references auth.users(id),
 unique(promo_id,customer_id)
);
create index promo_vouchers_promo_idx on public.promo_vouchers(promo_id);
create table public.promo_impressions (
 id bigint generated always as identity primary key,
 promo_id uuid not null references public.business_promos(id) on delete cascade,
 viewer_id uuid not null references auth.users(id) on delete cascade,
 viewed_at timestamptz not null default now()
);
create index promo_impressions_metrics_idx on public.promo_impressions(promo_id,viewed_at,viewer_id);
alter table public.business_promos enable row level security;
alter table public.promo_vouchers enable row level security;
alter table public.promo_impressions enable row level security;
create policy "Public can read active promos" on public.business_promos for select to authenticated using (
 (active and starts_at<=now() and ends_at>now()) or exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid())
);
create policy "Owners create promos" on public.business_promos for insert to authenticated with check (
 exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid())
);
create policy "Owners edit promos" on public.business_promos for update to authenticated using (
 exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid())
) with check (exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid()));
create policy "Owners delete promos" on public.business_promos for delete to authenticated using (
 exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid())
);
create policy "Customers see own vouchers" on public.promo_vouchers for select to authenticated using (
 customer_id=auth.uid() or exists(select 1 from public.business_promos p join public.businesses b on b.id=p.business_id where p.id=promo_id and b.owner_id=auth.uid())
);
-- All mutations to vouchers and impressions go through controlled RPCs.
create or replace function public.claim_business_promo(p_promo_id uuid) returns uuid language plpgsql security definer set search_path=public as $$
declare p public.business_promos%rowtype; v uuid; n bigint;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select * into p from public.business_promos where id=p_promo_id for update;
 if not found or not p.active or now()<p.starts_at or now()>=p.ends_at then raise exception 'Promotion unavailable'; end if;
 select id into v from public.promo_vouchers where promo_id=p_promo_id and customer_id=auth.uid();
 if v is not null then return v; end if;
 if p.max_claims is not null then
  select count(*) into n from public.promo_vouchers where promo_id=p_promo_id;
  if n>=p.max_claims then raise exception 'All vouchers claimed'; end if;
 end if;
 insert into public.promo_vouchers(promo_id,customer_id) values(p_promo_id,auth.uid()) returning id into v;
 return v;
end $$;
create or replace function public.redeem_business_promo(p_voucher_id uuid) returns boolean language plpgsql security definer set search_path=public as $$
declare v public.promo_vouchers%rowtype; p public.business_promos%rowtype;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select * into v from public.promo_vouchers where id=p_voucher_id for update;
 if not found then raise exception 'Voucher not found'; end if;
 select * into p from public.business_promos where id=v.promo_id;
 if not exists(select 1 from public.businesses b where b.id=p.business_id and b.owner_id=auth.uid()) then raise exception 'Not authorized merchant'; end if;
 if v.redeemed_at is not null then raise exception 'Voucher already redeemed'; end if;
 if not p.active or now()<p.starts_at or now()>=p.ends_at then raise exception 'Promotion expired or inactive'; end if;
 update public.promo_vouchers set redeemed_at=now(),redeemed_by=auth.uid() where id=v.id;
 return true;
end $$;
create or replace function public.record_promo_impression(p_promo_id uuid) returns void language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null then return; end if;
 if not exists(select 1 from public.business_promos where id=p_promo_id and active and starts_at<=now() and ends_at>now()) then return; end if;
 insert into public.promo_impressions(promo_id,viewer_id) values(p_promo_id,auth.uid());
end $$;
create or replace function public.merchant_promo_metrics(p_promo_id uuid)
returns table(impressions bigint,unique_viewers bigint,saved_vouchers bigint,total_redeems bigint)
language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null or not exists(select 1 from public.business_promos p join public.businesses b on b.id=p.business_id where p.id=p_promo_id and b.owner_id=auth.uid()) then raise exception 'Not authorized'; end if;
 return query select
 (select count(*) from public.promo_impressions i where i.promo_id=p_promo_id),
 (select count(distinct i.viewer_id) from public.promo_impressions i where i.promo_id=p_promo_id),
 (select count(*) from public.promo_vouchers v where v.promo_id=p_promo_id),
 (select count(*) from public.promo_vouchers v where v.promo_id=p_promo_id and v.redeemed_at is not null);
end $$;
revoke all on function public.claim_business_promo(uuid),public.redeem_business_promo(uuid),public.record_promo_impression(uuid),public.merchant_promo_metrics(uuid) from public;
grant execute on function public.claim_business_promo(uuid),public.redeem_business_promo(uuid),public.record_promo_impression(uuid),public.merchant_promo_metrics(uuid) to authenticated;
