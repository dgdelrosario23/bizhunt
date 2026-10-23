-- BizHunt Phase 3: Supabase schema (run once in SQL Editor)
-- Merchant approval is server-authorized; customers cannot mint their own stamps.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default now()
);
create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id),
  name text not null check (length(name) between 1 and 100),
  category text not null,
  location text not null,
  description text not null default '',
  created_at timestamptz not null default now()
);
create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  reward text not null,
  stamp_goal int not null check (stamp_goal between 2 and 20),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.stamp_events (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id),
  customer_id uuid not null references auth.users(id),
  merchant_id uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create table if not exists public.reward_redemptions (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id),
  customer_id uuid not null references auth.users(id),
  merchant_id uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists stamp_events_customer_campaign on public.stamp_events(customer_id,campaign_id);
create index if not exists redemptions_customer_campaign on public.reward_redemptions(customer_id,campaign_id);

alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.campaigns enable row level security;
alter table public.stamp_events enable row level security;
alter table public.reward_redemptions enable row level security;

create policy "read own profile" on public.profiles for select to authenticated using (id=auth.uid());
create policy "insert own profile" on public.profiles for insert to authenticated with check (id=auth.uid());
create policy "update own profile" on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid());
create policy "public business discovery" on public.businesses for select to anon,authenticated using (true);
create policy "create own business" on public.businesses for insert to authenticated with check (owner_id=auth.uid());
create policy "edit own business" on public.businesses for update to authenticated using (owner_id=auth.uid()) with check (owner_id=auth.uid());
create policy "read campaigns" on public.campaigns for select to anon,authenticated using (active or exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid()));
create policy "create own campaign" on public.campaigns for insert to authenticated with check (exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid()));
create policy "edit own campaign" on public.campaigns for update to authenticated using (exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid())) with check (exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid()));
create policy "customer or merchant reads stamps" on public.stamp_events for select to authenticated using (customer_id=auth.uid() or merchant_id=auth.uid());
create policy "customer or merchant reads redemptions" on public.reward_redemptions for select to authenticated using (customer_id=auth.uid() or merchant_id=auth.uid());

-- Revoke direct mutation privileges on ledger tables; use the verified functions below.
revoke insert, update, delete on public.stamp_events from anon,authenticated;
revoke insert, update, delete on public.reward_redemptions from anon,authenticated;

create or replace function public.issue_stamp(p_campaign uuid,p_customer uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_goal int; v_stamps bigint; v_redeemed bigint;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select c.stamp_goal into v_goal
  from public.campaigns c join public.businesses b on b.id=c.business_id
  where c.id=p_campaign and c.active and b.owner_id=auth.uid();
  if v_goal is null then raise exception 'Not an authorized active merchant campaign'; end if;
  if not exists(select 1 from auth.users where id=p_customer) then raise exception 'Customer not found'; end if;
  if p_customer=auth.uid() then raise exception 'Merchant cannot stamp own account'; end if;
  select count(*) into v_stamps from public.stamp_events where campaign_id=p_campaign and customer_id=p_customer;
  select count(*) into v_redeemed from public.reward_redemptions where campaign_id=p_campaign and customer_id=p_customer;
  if v_stamps-v_redeemed*v_goal >= v_goal then raise exception 'Unredeemed reward already available'; end if;
  insert into public.stamp_events(campaign_id,customer_id,merchant_id) values(p_campaign,p_customer,auth.uid()) returning id into v_id;
  return v_id;
end $$;
create or replace function public.redeem_reward(p_campaign uuid,p_customer uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_goal int; v_stamps bigint; v_redeemed bigint;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select c.stamp_goal into v_goal
  from public.campaigns c join public.businesses b on b.id=c.business_id
  where c.id=p_campaign and c.active and b.owner_id=auth.uid();
  if v_goal is null then raise exception 'Not an authorized active merchant campaign'; end if;
  select count(*) into v_stamps from public.stamp_events where campaign_id=p_campaign and customer_id=p_customer;
  select count(*) into v_redeemed from public.reward_redemptions where campaign_id=p_campaign and customer_id=p_customer;
  if v_stamps-v_redeemed*v_goal < v_goal then raise exception 'Not enough stamps'; end if;
  insert into public.reward_redemptions(campaign_id,customer_id,merchant_id) values(p_campaign,p_customer,auth.uid()) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.issue_stamp(uuid,uuid) from public,anon;
revoke all on function public.redeem_reward(uuid,uuid) from public,anon;
grant execute on function public.issue_stamp(uuid,uuid) to authenticated;
grant execute on function public.redeem_reward(uuid,uuid) to authenticated;
