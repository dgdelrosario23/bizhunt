-- F9d: corrected founder media path migration, replacing broken F9c. Do not run F9c.
-- Use after F9 migration. Requires review against actual businesses_media_paths constraint.
-- REVIEW AND APPLY MANUALLY in Supabase SQL Editor. Never execute from the app.
begin;
create or replace function public.bizhunt_founder_business_save(p_id uuid,p_code text,p_changes jsonb)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare ch record; old_row jsonb; new_row jsonb; allowed text[]:=array[
'name','category','location','description','phone','website','instagram','opening_hours',
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
create or replace function public.bizhunt_founder_business_media(p_id uuid,p_code text,p_kind text,p_action text,p_path text default null,p_file_type text default null,p_title text default null,p_item_id uuid default null)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare ch record; old_row jsonb; new_row jsonb; owner_uuid uuid;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder authorization required';end if;
 if p_kind not in ('gallery','menu') or p_action not in ('add','remove') then raise exception 'Invalid media action';end if;
 select * into ch from public.bizhunt_founder_challenges where actor_id=auth.uid() for update;
 if not found or ch.entity_type<>'businesses' or ch.entity_id<>p_id or ch.action<>'update'
 or ch.expires_at<now() or ch.code_hash<>md5(coalesce(p_code,'')) then raise exception 'Invalid or expired confirmation code';end if;
 delete from public.bizhunt_founder_challenges where actor_id=auth.uid();
 select owner_id into owner_uuid from public.businesses where id=p_id;
 if not found then raise exception 'Business not found';end if;
 if owner_uuid is null then raise exception 'Business owner is required for media uploads';end if;
 if p_action='add' then
  if p_path is null or p_path !~ ('^'||owner_uuid::text||'/'||p_id::text||'/'||p_kind||'/[0-9a-f-]{36}[.](png|jpg|webp|pdf)$') then raise exception 'Invalid media path';end if;
  if p_kind='gallery' then
   if (select count(*) from public.business_gallery where business_id=p_id)>=30 then raise exception 'Gallery limit reached';end if;
   insert into public.business_gallery(business_id,image_path,caption) values(p_id,p_path,left(coalesce(p_title,''),250));
  else
   if p_file_type not in ('application/pdf','image/png','image/jpeg','image/webp') then raise exception 'Invalid menu type';end if;
   insert into public.business_menu_files(business_id,file_path,file_type,title,sort_order)
   values(p_id,p_path,p_file_type,left(coalesce(nullif(trim(p_title),''),'Menu'),200),(select count(*) from public.business_menu_files where business_id=p_id));
  end if;
 else
  if p_item_id is null then raise exception 'Media item required';end if;
  if p_kind='gallery' then
   delete from public.business_gallery where id=p_item_id and business_id=p_id;
  else
   delete from public.business_menu_files where id=p_item_id and business_id=p_id;
  end if;
 end if;
 insert into public.bizhunt_founder_audit(actor_id,entity_type,entity_id,action,before_data,after_data)
 values(auth.uid(),'businesses',p_id,'media_'||p_action,jsonb_build_object('kind',p_kind,'item_id',p_item_id),jsonb_build_object('path',p_path,'title',p_title));
end $$;
-- Restrict founder uploads to a dedicated per-business prefix; no owner permissions are expanded.
drop policy if exists "Founder business media uploads" on storage.objects;
create policy "Founder business media uploads" on storage.objects for insert to authenticated
with check(bucket_id in ('bizhunt-business-media','bizhunt-business-menus')
 and ((bucket_id='bizhunt-business-media' and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/(logo|cover|gallery)/[0-9a-f-]{36}[.](png|jpg|webp)$') or (bucket_id='bizhunt-business-menus' and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/menu/[0-9a-f-]{36}[.](png|jpg|webp|pdf)$'))
 and public.bizhunt_founder_authorized());
revoke all on function public.bizhunt_founder_business_save(uuid,text,jsonb) from public,anon;
revoke all on function public.bizhunt_founder_business_media(uuid,text,text,text,text,text,text,uuid) from public,anon;
grant execute on function public.bizhunt_founder_business_save(uuid,text,jsonb),public.bizhunt_founder_business_media(uuid,text,text,text,text,text,text,uuid) to authenticated;
commit;
