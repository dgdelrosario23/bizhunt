-- Separate address fields with a backwards-compatible combined location.
-- No existing address or map pin is backfilled or overwritten.
begin;
alter table public.businesses
 add column if not exists address_line text,
 add column if not exists address_city text,
 add column if not exists address_province text;
alter table public.bizhunt_curated_businesses
 add column if not exists address_line text,
 add column if not exists address_city text,
 add column if not exists address_province text;

-- Preserve legacy writes: a change to location alone invalidates old components.
-- Structured writes always derive the public location from the three components.
create or replace function public.bizhunt_sync_business_address()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 if tg_op='UPDATE' then
  if row(new.address_line,new.address_city,new.address_province) is not distinct from row(old.address_line,old.address_city,old.address_province) then
   if new.location is distinct from old.location then
    new.address_line=null;new.address_city=null;new.address_province=null;
   end if;
   return new;
  end if;
 end if;
 if new.address_line is null and new.address_city is null and new.address_province is null then return new; end if;
 new.address_line=btrim(coalesce(new.address_line,''));
 new.address_city=btrim(coalesce(new.address_city,''));
 new.address_province=btrim(coalesce(new.address_province,''));
 if char_length(new.address_line) not between 1 and 140
 or char_length(new.address_city) not between 1 and 50
 or char_length(new.address_province) not between 1 and 50
 or position(',' in new.address_city)>0 or position(',' in new.address_province)>0 then
  raise exception 'Invalid structured business address';
 end if;
 new.location=concat_ws(', ',new.address_line,new.address_city,new.address_province);
 return new;
end $$;
revoke all on function public.bizhunt_sync_business_address() from public,anon,authenticated;
drop trigger if exists bizhunt_sync_address on public.businesses;
create trigger bizhunt_sync_address before insert or update of location,address_line,address_city,address_province on public.businesses for each row execute function public.bizhunt_sync_business_address();
drop trigger if exists bizhunt_sync_address on public.bizhunt_curated_businesses;
create trigger bizhunt_sync_address before insert or update of location,address_line,address_city,address_province on public.bizhunt_curated_businesses for each row execute function public.bizhunt_sync_business_address();

create or replace function public.bizhunt_founder_business_save(p_id uuid,p_code text,p_changes jsonb)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare ch record; old_row jsonb; new_row jsonb; allowed text[]:=array[
'name','category','location','address_line','address_city','address_province','description','phone','website','instagram','opening_hours',
'weekly_hours','timezone','special_hours','latitude','longitude','brand_color','business_type',
'service_area','mobile_service','logo_path','cover_path'];
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder authorization required'; end if;
 if p_changes is null or jsonb_typeof(p_changes)<>'object' then raise exception 'Invalid changes';end if;
 if exists(select 1 from jsonb_object_keys(p_changes) k where not k=any(allowed)) then raise exception 'Unsupported business field';end if;
 select * into ch from public.bizhunt_founder_challenges where actor_id=auth.uid() for update;
 if not found or ch.entity_type<>'businesses' or ch.entity_id<>p_id or ch.action<>'update'
    or ch.expires_at<now() or ch.code_hash<>md5(coalesce(p_code,'')) then raise exception 'Invalid or expired confirmation code';end if;
 delete from public.bizhunt_founder_challenges where actor_id=auth.uid();
 select to_jsonb(b) into old_row from public.businesses b where id=p_id for update;
 if old_row is null then raise exception 'Business not found';end if;
 if p_changes ? 'name' and length(trim(coalesce(p_changes->>'name','')))<2 then raise exception 'Business name too short';end if;
 if p_changes ? 'weekly_hours' and jsonb_typeof(p_changes->'weekly_hours')<>'object' then raise exception 'Invalid weekly hours';end if;
 if p_changes ? 'special_hours' and jsonb_typeof(p_changes->'special_hours') not in ('object','array','null') then raise exception 'Invalid special hours';end if;
 if p_changes ? 'latitude' and p_changes->>'latitude' is not null and (p_changes->>'latitude')::numeric not between -90 and 90 then raise exception 'Invalid latitude';end if;
 if p_changes ? 'longitude' and p_changes->>'longitude' is not null and (p_changes->>'longitude')::numeric not between -180 and 180 then raise exception 'Invalid longitude';end if;
 if p_changes ? 'logo_path' and p_changes->>'logo_path' is not null and (p_changes->>'logo_path') !~ ('^'||(old_row->>'owner_id')||'/'||p_id::text||'/logo/[0-9a-f-]{36}[.](png|jpg|webp)$') then raise exception 'Invalid logo path';end if;
 if p_changes ? 'cover_path' and p_changes->>'cover_path' is not null and (p_changes->>'cover_path') !~ ('^'||(old_row->>'owner_id')||'/'||p_id::text||'/cover/[0-9a-f-]{36}[.](png|jpg|webp)$') then raise exception 'Invalid cover path';end if;
 update public.businesses b set
 name=case when p_changes?'name' then p_changes->>'name' else b.name end,
 category=case when p_changes?'category' then p_changes->>'category' else b.category end,
 location=case when p_changes?'location' then p_changes->>'location' else b.location end,
 address_line=case when p_changes?'address_line' then p_changes->>'address_line' else b.address_line end,
 address_city=case when p_changes?'address_city' then p_changes->>'address_city' else b.address_city end,
 address_province=case when p_changes?'address_province' then p_changes->>'address_province' else b.address_province end,
 description=case when p_changes?'description' then p_changes->>'description' else b.description end,
 phone=case when p_changes?'phone' then p_changes->>'phone' else b.phone end,
 website=case when p_changes?'website' then p_changes->>'website' else b.website end,
 instagram=case when p_changes?'instagram' then p_changes->>'instagram' else b.instagram end,
 opening_hours=case when p_changes?'opening_hours' then p_changes->>'opening_hours' else b.opening_hours end,
 weekly_hours=case when p_changes?'weekly_hours' then p_changes->'weekly_hours' else b.weekly_hours end,
 special_hours=case when p_changes?'special_hours' then p_changes->'special_hours' else b.special_hours end,
 timezone=case when p_changes?'timezone' then p_changes->>'timezone' else b.timezone end,
 latitude=case when p_changes?'latitude' then (p_changes->>'latitude')::numeric else b.latitude end,
 longitude=case when p_changes?'longitude' then (p_changes->>'longitude')::numeric else b.longitude end,
 brand_color=case when p_changes?'brand_color' then p_changes->>'brand_color' else b.brand_color end,
 business_type=case when p_changes?'business_type' then p_changes->>'business_type' else b.business_type end,
 service_area=case when p_changes?'service_area' then p_changes->>'service_area' else b.service_area end,
 mobile_service=case when p_changes?'mobile_service' then (p_changes->>'mobile_service')::boolean else b.mobile_service end,
 logo_path=case when p_changes?'logo_path' then p_changes->>'logo_path' else b.logo_path end,
 cover_path=case when p_changes?'cover_path' then p_changes->>'cover_path' else b.cover_path end
 where b.id=p_id;
 select to_jsonb(b) into new_row from public.businesses b where id=p_id;
 insert into public.bizhunt_founder_audit(actor_id,entity_type,entity_id,action,before_data,after_data)
 values(auth.uid(),'businesses',p_id,'update',old_row,new_row);
end $$;

create or replace function public.bizhunt_founder_curated_mutate(p_id uuid,p_action text,p_code text,p_changes jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path=public as $$
declare old_row jsonb;new_row jsonb;ch record;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder admin access required';end if;
 select * into ch from public.bizhunt_founder_challenges where actor_id=auth.uid() for update;
 if not found or ch.entity_type<>'curated' or ch.entity_id<>p_id or ch.action<>p_action
 or ch.expires_at<now() or ch.code_hash<>md5(coalesce(p_code,'')) then raise exception 'Invalid or expired confirmation code';end if;
 delete from public.bizhunt_founder_challenges where actor_id=auth.uid();
 select to_jsonb(b) into old_row from public.bizhunt_curated_businesses b where id=p_id for update;
 if old_row is null then raise exception 'Listing not found';end if;
 if p_action='delete' then delete from public.bizhunt_curated_businesses where id=p_id;new_row=null;
 elsif p_action='update' then
  if exists(select 1 from jsonb_object_keys(p_changes) k where k not in ('name','category','location','address_line','address_city','address_province','description'))
  then raise exception 'Unsupported field';end if;
  if p_changes ? 'name' and char_length(trim(p_changes->>'name'))<2 then raise exception 'Name too short';end if;
  update public.bizhunt_curated_businesses set
   name=case when p_changes ? 'name' then trim(p_changes->>'name') else name end,
   category=case when p_changes ? 'category' then p_changes->>'category' else category end,
   location=case when p_changes ? 'location' then p_changes->>'location' else location end,
 address_line=case when p_changes?'address_line' then p_changes->>'address_line' else address_line end,
 address_city=case when p_changes?'address_city' then p_changes->>'address_city' else address_city end,
 address_province=case when p_changes?'address_province' then p_changes->>'address_province' else address_province end,
   description=case when p_changes ? 'description' then p_changes->>'description' else description end
  where id=p_id;
  select to_jsonb(b) into new_row from public.bizhunt_curated_businesses b where id=p_id;
 else raise exception 'Invalid action';end if;
 insert into public.bizhunt_founder_audit(actor_id,entity_type,entity_id,action,before_data,after_data)
 values(auth.uid(),'curated',p_id,p_action,old_row,new_row);
end $$;

create or replace function public.bizhunt_founder_curated_create_address(p_name text,p_category text,p_location text,p_description text,p_address_line text,p_address_city text,p_address_province text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid; v_row jsonb;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder admin access required' using errcode='42501'; end if;
 if length(trim(coalesce(p_name,'')))<2 or length(p_name)>250 then raise exception 'Invalid business name'; end if;
 if length(coalesce(p_category,''))>250 or length(coalesce(p_location,''))>250 or length(coalesce(p_description,''))>1500 then raise exception 'Field too long'; end if;
 insert into public.bizhunt_curated_businesses(name,category,location,description,address_line,address_city,address_province)
 values(trim(p_name),coalesce(nullif(trim(p_category),''),'Other'),coalesce(trim(p_location),''),
 coalesce(nullif(trim(p_description),''),'Community discovery listing. Not a verified BizHunt merchant; no rewards or deals are offered.'),p_address_line,p_address_city,p_address_province)
 returning id into v_id;
 select to_jsonb(b) into v_row from public.bizhunt_curated_businesses b where b.id=v_id;
 insert into public.bizhunt_founder_audit(actor_id,entity_type,entity_id,action,before_data,after_data)
 values(auth.uid(),'curated',v_id,'create',null,v_row);
 return v_id;
end $$;
revoke all on function public.bizhunt_founder_business_save(uuid,text,jsonb) from public,anon;
grant execute on function public.bizhunt_founder_business_save(uuid,text,jsonb) to authenticated;
revoke all on function public.bizhunt_founder_curated_mutate(uuid,text,text,jsonb) from public,anon;
grant execute on function public.bizhunt_founder_curated_mutate(uuid,text,text,jsonb) to authenticated;
revoke all on function public.bizhunt_founder_curated_create_address(text,text,text,text,text,text,text) from public,anon;
grant execute on function public.bizhunt_founder_curated_create_address(text,text,text,text,text,text,text) to authenticated;
notify pgrst, 'reload schema';
commit;
