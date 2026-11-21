-- F11: single founder confirmation for an atomic gallery batch.
-- Apply manually after F9d. Does not change existing media path constraints.
begin;
create or replace function public.bizhunt_founder_business_gallery_batch(
 p_id uuid, p_code text, p_items jsonb
) returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare
 ch record;
 owner_uuid uuid;
 item jsonb;
 path_value text;
 inserted_count integer := 0;
begin
 if not public.bizhunt_founder_authorized() then
  raise exception 'Founder authorization required';
 end if;
 if p_items is null or jsonb_typeof(p_items) <> 'array'
    or jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 30 then
  raise exception 'Choose between 1 and 30 gallery photos';
 end if;
 select owner_id into owner_uuid from public.businesses where id=p_id for update;
 if not found or owner_uuid is null then
  raise exception 'Registered business owner not found';
 end if;
 select * into ch from public.bizhunt_founder_challenges
  where actor_id=auth.uid() for update;
 if not found or ch.entity_type <> 'businesses' or ch.entity_id <> p_id
    or ch.action <> 'update' or ch.expires_at < now()
    or ch.code_hash <> md5(coalesce(p_code,'')) then
  raise exception 'Invalid or expired confirmation code';
 end if;
 if (select count(*) from public.business_gallery where business_id=p_id)
     + jsonb_array_length(p_items) > 30 then
  raise exception 'Gallery limit is 30 photos';
 end if;
 for item in select value from jsonb_array_elements(p_items) loop
  if jsonb_typeof(item) <> 'object' then raise exception 'Invalid gallery item';end if;
  path_value:=item->>'path';
  if path_value is null or path_value !~ (
    '^'||owner_uuid::text||'/'||p_id::text||'/gallery/[0-9a-f-]{36}[.](png|jpg|webp)$'
  ) then raise exception 'Invalid gallery photo path';end if;
  if item->>'file_type' not in ('image/png','image/jpeg','image/webp') then
   raise exception 'Unsupported gallery image type';
  end if;
  insert into public.business_gallery(business_id,image_path,caption)
  values(p_id,path_value,left(coalesce(item->>'title',''),250));
  inserted_count:=inserted_count+1;
 end loop;
 delete from public.bizhunt_founder_challenges where actor_id=auth.uid();
 insert into public.bizhunt_founder_audit(actor_id,entity_type,entity_id,action,before_data,after_data)
 values(auth.uid(),'businesses',p_id,'gallery_batch_add',
  jsonb_build_object('count',0),
  jsonb_build_object('count',inserted_count));
 return inserted_count;
end $$;
revoke all on function public.bizhunt_founder_business_gallery_batch(uuid,text,jsonb) from public,anon;
grant execute on function public.bizhunt_founder_business_gallery_batch(uuid,text,jsonb) to authenticated;
commit;
