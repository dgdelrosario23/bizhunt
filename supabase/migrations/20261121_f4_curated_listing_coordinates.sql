-- F4: Founder-controlled coordinates for curated community listings.
-- Apply manually in Supabase before using the new map pin editor.
begin;
alter table public.bizhunt_curated_businesses
 add column if not exists latitude double precision,
 add column if not exists longitude double precision;
alter table public.bizhunt_curated_businesses
 drop constraint if exists bizhunt_curated_coordinates_valid;
alter table public.bizhunt_curated_businesses
 add constraint bizhunt_curated_coordinates_valid check (
 (latitude is null and longitude is null) or
 (latitude between -90 and 90 and longitude between -180 and 180)
 );
create or replace function public.bizhunt_founder_curated_location_save(
 p_id uuid, p_latitude double precision, p_longitude double precision
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_before jsonb;v_after jsonb;
begin
 if not public.bizhunt_founder_authorized() then
  raise exception 'Founder access required' using errcode='42501';
 end if;
 if not ((p_latitude is null and p_longitude is null) or
 (p_latitude between -90 and 90 and p_longitude between -180 and 180)) then
  raise exception 'Invalid map coordinates' using errcode='22023';
 end if;
 select to_jsonb(b) into v_before from public.bizhunt_curated_businesses b
 where b.id=p_id for update;
 if v_before is null then raise exception 'Listing not found';end if;
 update public.bizhunt_curated_businesses
 set latitude=p_latitude,longitude=p_longitude where id=p_id;
 select to_jsonb(b) into v_after from public.bizhunt_curated_businesses b where b.id=p_id;
 if v_before is distinct from v_after then
  insert into public.bizhunt_founder_audit(actor_id,entity_type,entity_id,action,before_data,after_data)
  values(auth.uid(),'curated',p_id,'update_location',v_before,v_after);
 end if;
end $$;
revoke all on function public.bizhunt_founder_curated_location_save(uuid,double precision,double precision) from public,anon;
grant execute on function public.bizhunt_founder_curated_location_save(uuid,double precision,double precision) to authenticated;
commit;
