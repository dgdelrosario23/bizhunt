-- Phase 14D: private saved businesses, separate from Following and the stamp Wallet
create table if not exists public.business_saves (
  customer_id uuid not null references auth.users(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (customer_id, business_id)
);
create index if not exists business_saves_customer_created
  on public.business_saves(customer_id,created_at desc);
alter table public.business_saves enable row level security;
drop policy if exists "Read own saved businesses" on public.business_saves;
drop policy if exists "Save own businesses" on public.business_saves;
drop policy if exists "Remove own saved businesses" on public.business_saves;
create policy "Read own saved businesses" on public.business_saves
 for select to authenticated using (customer_id = (select auth.uid()));
create policy "Save own businesses" on public.business_saves
 for insert to authenticated with check (customer_id = (select auth.uid()));
create policy "Remove own saved businesses" on public.business_saves
 for delete to authenticated using (customer_id = (select auth.uid()));
revoke all on public.business_saves from anon;
grant select, insert, delete on public.business_saves to authenticated;
