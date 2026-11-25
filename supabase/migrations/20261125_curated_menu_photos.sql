-- Community listing menu photos use the existing founder-curated media bucket.
begin;
alter table public.bizhunt_curated_businesses add column if not exists menu_paths text[] not null default '{}';

create or replace function public.bizhunt_founder_curated_menu_save(p_id uuid, p_previous text[], p_paths text[])
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare old_row public.bizhunt_curated_businesses%rowtype;
declare new_row public.bizhunt_curated_businesses%rowtype;
declare path text;
begin
 if auth.uid() is null or not public.bizhunt_founder_authorized() then raise exception 'Founder access required' using errcode='42501'; end if;
 select * into old_row from public.bizhunt_curated_businesses where id=p_id for update;
 if not found then raise exception 'Listing not found'; end if;
 if old_row.menu_paths is distinct from p_previous then raise exception 'Menu changed. Reload the listing and try again'; end if;
 if p_paths is null or cardinality(p_paths)>12 then raise exception 'Maximum twelve menu photos'; end if;
 if cardinality(p_paths)<>(select count(distinct v) from unnest(p_paths) as t(v)) then raise exception 'Invalid or duplicate menu photos'; end if;
 foreach path in array p_paths loop
  if path !~ ('^founder-curated/'||p_id::text||'/menu-[0-9a-f-]{36}\.(jpg|png|webp)$') or not exists(select 1 from storage.objects where bucket_id='bizhunt-business-media' and name=path) then raise exception 'Invalid menu photo'; end if;
 end loop;
 update public.bizhunt_curated_businesses set menu_paths=p_paths where id=p_id returning * into new_row;
 insert into public.bizhunt_curated_media_audit(listing_id,actor_id,before_data,after_data) values(p_id::text,auth.uid(),to_jsonb(old_row),to_jsonb(new_row));
end $$;
revoke all on function public.bizhunt_founder_curated_menu_save(uuid,text[],text[]) from public,anon;
grant execute on function public.bizhunt_founder_curated_menu_save(uuid,text[],text[]) to authenticated;
notify pgrst, 'reload schema';
commit;
