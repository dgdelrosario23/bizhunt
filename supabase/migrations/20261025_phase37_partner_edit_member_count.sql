-- Phase 37: Member counts and safe partner editing. Run in Supabase SQL Editor.
create or replace function public.bizhunt_community_member_count(p_id uuid)
returns integer language sql stable security definer set search_path=public as $count$
 select case when public.bizhunt_can_view_community(p_id)
 then (select count(*)::integer from public.bizhunt_community_members where community_id=p_id and status='active')
 else 0 end
$count$;
revoke all on function public.bizhunt_community_member_count(uuid) from public;
grant execute on function public.bizhunt_community_member_count(uuid) to authenticated;

-- Existing Phase 34 UPDATE policy prohibits confirmed_by_merchant=true updates.
-- Replace it with an RPC that checks admins and resets approval when the offer changes.
create or replace function public.bizhunt_edit_community_partner(
 p_id uuid,p_name text,p_category text,p_address text,p_relationship text,
 p_perk_details text,p_latitude double precision,p_longitude double precision,
 p_business_id uuid
) returns void language plpgsql security definer set search_path=public as $edit$
declare existing public.bizhunt_community_places%rowtype; changed boolean;
begin
 select * into existing from public.bizhunt_community_places where id=p_id for update;
 if not found then raise exception 'Partner listing not found'; end if;
 if not public.bizhunt_is_community_admin(existing.community_id) then raise exception 'Not authorized'; end if;
 if char_length(trim(coalesce(p_name,''))) not between 2 and 120 then raise exception 'Name must be 2–120 characters'; end if;
 if char_length(coalesce(p_perk_details,''))>500 then raise exception 'Perk details too long'; end if;
 if p_relationship not in ('partner','recommended') then raise exception 'Invalid listing type'; end if;
 if p_relationship='partner' and p_business_id is null then raise exception 'Link a BizHunt business to request partnership'; end if;
 changed := existing.business_id is distinct from p_business_id
   or existing.relationship is distinct from p_relationship
   or existing.perk_details is distinct from coalesce(p_perk_details,'');
 update public.bizhunt_community_places
 set name=trim(p_name),category=coalesce(p_category,'Other'),address=coalesce(p_address,''),
     relationship=p_relationship,perk_details=coalesce(p_perk_details,''),
     latitude=p_latitude,longitude=p_longitude,business_id=p_business_id,
     confirmed_by_merchant=case when changed then false else existing.confirmed_by_merchant end,
     partnership_status=case when changed then 'pending' else existing.partnership_status end
 where id=p_id;
end
$edit$;
revoke all on function public.bizhunt_edit_community_partner(uuid,text,text,text,text,text,double precision,double precision,uuid) from public;
grant execute on function public.bizhunt_edit_community_partner(uuid,text,text,text,text,text,double precision,double precision,uuid) to authenticated;
