-- BizHunt Community Partner Offers (Phase 39)
-- Apply in Supabase SQL Editor after the existing community migrations.
create table if not exists public.bizhunt_community_partner_offers (
 id uuid primary key default gen_random_uuid(),
 place_id uuid not null references public.bizhunt_community_places(id) on delete cascade,
 title text not null check (char_length(trim(title)) between 1 and 120),
 details text not null default '',
 offer_type text not null default 'discount' check (offer_type in ('discount','freebie','exclusive','other')),
 redemption_instructions text not null default '',
 starts_at timestamptz,
 expires_at timestamptz,
 is_active boolean not null default true,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint offer_date_order check (expires_at is null or starts_at is null or expires_at > starts_at)
);
create index if not exists community_partner_offers_place_idx on public.bizhunt_community_partner_offers(place_id);
alter table public.bizhunt_community_partner_offers enable row level security;
revoke all on public.bizhunt_community_partner_offers from anon, authenticated;
grant select, insert, update, delete on public.bizhunt_community_partner_offers to authenticated;
-- All access is scoped to active community membership and community administrator privileges.
drop policy if exists offers_read on public.bizhunt_community_partner_offers;
create policy offers_read on public.bizhunt_community_partner_offers for select to authenticated using (
 exists(select 1 from public.bizhunt_community_places p
 join public.bizhunt_communities c on c.id=p.community_id
 where p.id=place_id and (
 c.owner_id=(select auth.uid()) or exists(select 1 from public.bizhunt_community_members m where m.community_id=c.id and m.user_id=(select auth.uid()) and m.status='active')
 )));
drop policy if exists offers_insert on public.bizhunt_community_partner_offers;
create policy offers_insert on public.bizhunt_community_partner_offers for insert to authenticated with check (
 created_by=(select auth.uid()) and exists(select 1 from public.bizhunt_community_places p
 join public.bizhunt_communities c on c.id=p.community_id
 where p.id=place_id and (c.owner_id=(select auth.uid()) or exists(select 1 from public.bizhunt_community_members m where m.community_id=c.id and m.user_id=(select auth.uid()) and m.status='active' and m.role='admin')))
);
drop policy if exists offers_update on public.bizhunt_community_partner_offers;
create policy offers_update on public.bizhunt_community_partner_offers for update to authenticated using (
 exists(select 1 from public.bizhunt_community_places p join public.bizhunt_communities c on c.id=p.community_id
 where p.id=place_id and (c.owner_id=(select auth.uid()) or exists(select 1 from public.bizhunt_community_members m where m.community_id=c.id and m.user_id=(select auth.uid()) and m.status='active' and m.role='admin')))
) with check (
 exists(select 1 from public.bizhunt_community_places p join public.bizhunt_communities c on c.id=p.community_id
 where p.id=place_id and (c.owner_id=(select auth.uid()) or exists(select 1 from public.bizhunt_community_members m where m.community_id=c.id and m.user_id=(select auth.uid()) and m.status='active' and m.role='admin')))
);
drop policy if exists offers_delete on public.bizhunt_community_partner_offers;
create policy offers_delete on public.bizhunt_community_partner_offers for delete to authenticated using (
 exists(select 1 from public.bizhunt_community_places p join public.bizhunt_communities c on c.id=p.community_id
 where p.id=place_id and (c.owner_id=(select auth.uid()) or exists(select 1 from public.bizhunt_community_members m where m.community_id=c.id and m.user_id=(select auth.uid()) and m.status='active' and m.role='admin')))
);
-- IMPORTANT: Offers are informational until a merchant verifies the partnership.
-- Redemption tokens must be issued and consumed by a server-side authenticated function,
-- not by a client-generated QR code or unrestricted table write.
