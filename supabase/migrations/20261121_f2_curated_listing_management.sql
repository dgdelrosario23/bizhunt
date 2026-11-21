-- F2 curated listing management: additive creation + reversible archive.
-- Apply only after review; depends on Phase 41 and founder audit/challenge schema.
begin;
alter table public.bizhunt_curated_businesses add column if not exists archived_at timestamptz;
drop policy if exists "Anyone reads curated businesses" on public.bizhunt_curated_businesses;
create policy "Anyone reads curated businesses" on public.bizhunt_curated_businesses for select to anon,authenticated using (archived_at is null or public.bizhunt_founder_authorized());
create or replace function public.bizhunt_founder_curated_create(p_name text,p_category text,p_location text,p_description text default '')
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid; v_row jsonb;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder admin access required' using errcode='42501'; end if;
 if length(trim(coalesce(p_name,'')))<2 or length(p_name)>250 then raise exception 'Invalid business name'; end if;
 if length(coalesce(p_category,''))>250 or length(coalesce(p_location,''))>250 or length(coalesce(p_description,''))>1500 then raise exception 'Field too long'; end if;
 insert into public.bizhunt_curated_businesses(name,category,location,description)
 values(trim(p_name),coalesce(nullif(trim(p_category),''),'Other'),coalesce(trim(p_location),''),
 coalesce(nullif(trim(p_description),''),'Community discovery listing. Not a verified BizHunt merchant; no rewards or deals are offered.'))
 returning id into v_id;
 select to_jsonb(b) into v_row from public.bizhunt_curated_businesses b where b.id=v_id;
 insert into public.bizhunt_founder_audit(actor_id,entity_type,entity_id,action,before_data,after_data)
 values(auth.uid(),'curated',v_id,'create',null,v_row);
 return v_id;
end $$;
create or replace function public.bizhunt_founder_curated_archive(p_id uuid,p_archive boolean,p_code text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare ch record; old_row jsonb; new_row jsonb; v_action text := case when p_archive then 'archive' else 'restore' end;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder admin access required' using errcode='42501'; end if;
 select * into ch from public.bizhunt_founder_challenges where actor_id=auth.uid() for update;
 if not found or ch.entity_type<>'curated' or ch.entity_id<>p_id or ch.action<>v_action or ch.expires_at<now() or ch.code_hash<>md5(coalesce(p_code,'')) then raise exception 'Invalid or expired confirmation code'; end if;
 delete from public.bizhunt_founder_challenges where actor_id=auth.uid();
 select to_jsonb(b) into old_row from public.bizhunt_curated_businesses b where id=p_id for update;
 if old_row is null then raise exception 'Listing not found'; end if;
 update public.bizhunt_curated_businesses set archived_at=case when p_archive then now() else null end where id=p_id;
 select to_jsonb(b) into new_row from public.bizhunt_curated_businesses b where id=p_id;
 insert into public.bizhunt_founder_audit(actor_id,entity_type,entity_id,action,before_data,after_data)
 values(auth.uid(),'curated',p_id,v_action,old_row,new_row);
end $$;
-- Existing challenge RPC accepts only update/delete. Extend it without changing their semantics.
create or replace function public.bizhunt_founder_curated_challenge(p_id uuid,p_action text)
returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare code text;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder admin access required';end if;
 if p_action not in ('update','delete','archive','restore') then raise exception 'Invalid action';end if;
 if not exists(select 1 from public.bizhunt_curated_businesses where id=p_id) then raise exception 'Listing not found';end if;
 code=encode(gen_random_bytes(12),'hex');
 insert into public.bizhunt_founder_challenges(actor_id,entity_type,entity_id,action,code_hash,expires_at)
 values(auth.uid(),'curated',p_id,p_action,md5(code),now()+interval '5 minutes')
 on conflict(actor_id) do update set entity_type=excluded.entity_type,entity_id=excluded.entity_id,action=excluded.action,code_hash=excluded.code_hash,expires_at=excluded.expires_at;
 return code;
end $$;
revoke all on function public.bizhunt_founder_curated_create(text,text,text,text) from public,anon;
revoke all on function public.bizhunt_founder_curated_archive(uuid,boolean,text) from public,anon;
grant execute on function public.bizhunt_founder_curated_create(text,text,text,text),public.bizhunt_founder_curated_archive(uuid,boolean,text) to authenticated;
commit;
