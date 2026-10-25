-- Phase 36: Merchant-approved community partnerships. Run manually in Supabase SQL Editor.
-- Existing partner rows remain pending until the actual business owner approves.
alter table public.bizhunt_community_places
 add column if not exists partnership_status text not null default 'pending'
 check (partnership_status in ('pending','approved','declined'));

update public.bizhunt_community_places
set partnership_status='pending', confirmed_by_merchant=false
where relationship='partner' and confirmed_by_merchant=false;

create index if not exists bizhunt_community_places_business_status_idx
 on public.bizhunt_community_places(business_id,partnership_status)
 where relationship='partner';

-- Only the owner of the linked BizHunt business can approve or decline.
create or replace function public.bizhunt_respond_partner_request(p_place_id uuid,p_approve boolean)
returns text language plpgsql security definer set search_path=public as $respond$
declare v_place public.bizhunt_community_places%rowtype;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 select * into v_place from public.bizhunt_community_places where id=p_place_id for update;
 if not found then raise exception 'Partner request not found'; end if;
 if v_place.relationship<>'partner' or v_place.business_id is null then
  raise exception 'This is not a linked business partnership request';
 end if;
 if not exists(select 1 from public.businesses b
   where b.id=v_place.business_id and b.owner_id=auth.uid()) then
  raise exception 'Only the business owner can respond';
 end if;
 if v_place.partnership_status<>'pending' then
  raise exception 'This request has already been reviewed';
 end if;
 update public.bizhunt_community_places
 set partnership_status=case when p_approve then 'approved' else 'declined' end,
     confirmed_by_merchant=p_approve
 where id=p_place_id;
 return case when p_approve then 'Partnership approved' else 'Partnership declined' end;
end
$respond$;
revoke all on function public.bizhunt_respond_partner_request(uuid,boolean) from public;
grant execute on function public.bizhunt_respond_partner_request(uuid,boolean) to authenticated;

-- Merchant owners may see requests for their own linked business even in private communities.
create policy "Business owners view their partnership requests"
 on public.bizhunt_community_places for select to authenticated
 using (business_id is not null and exists (
  select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid()
 ));

-- Merchant can see the linked community name without exposing private community contents.
create or replace function public.bizhunt_my_partner_requests()
returns table(place_id uuid,community_name text,business_id uuid,business_name text,
 perk_details text,partnership_status text,created_at timestamptz)
language sql stable security definer set search_path=public as $requests$
 select p.id,c.name,p.business_id,b.name,p.perk_details,p.partnership_status,p.created_at
 from public.bizhunt_community_places p
 join public.businesses b on b.id=p.business_id
 join public.bizhunt_communities c on c.id=p.community_id
 where b.owner_id=auth.uid() and p.relationship='partner'
 order by p.created_at desc
$requests$;
revoke all on function public.bizhunt_my_partner_requests() from public;
grant execute on function public.bizhunt_my_partner_requests() to authenticated;
