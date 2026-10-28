-- Phase 41: Persist previously hardcoded discovery listings.
-- Run AFTER phases 39 and 40. Public can read active curated listings;
-- only founder admins can edit or delete through audited, confirmed RPCs.
create table if not exists public.bizhunt_curated_businesses (
 id uuid primary key default gen_random_uuid(),
 name text not null,category text not null default 'Other',
 location text not null default '',description text not null default
 'Community discovery listing. Not a verified BizHunt merchant; no rewards or deals are offered.',
 created_at timestamptz not null default now()
);
alter table public.bizhunt_curated_businesses enable row level security;
revoke all on public.bizhunt_curated_businesses from anon,authenticated;
grant select on public.bizhunt_curated_businesses to anon,authenticated;
drop policy if exists "Anyone reads curated businesses" on public.bizhunt_curated_businesses;
create policy "Anyone reads curated businesses" on public.bizhunt_curated_businesses for select to anon,authenticated using(true);
insert into public.bizhunt_curated_businesses(name,category,location)
values ('Los Komunidad','Café','18 Jesus St, Angeles City, Pampanga'),
('COFFEEBAY','Café','Fil-Am Friendship Highway, Angeles City, Pampanga'),
('LALA Garden Cafe','Café','Poinsettia Avenue, Angeles City, Pampanga'),
('The Coffee Lab & Lounge','Café','Marlim Mansions Hotel, MacArthur Highway, Balibago, Angeles City'),
('Kapebaluan by Morgen','Café','Santo Entierro, Angeles City, Pampanga'),
('Angeles Fried Chicken','Restaurant','Marlim Avenue, Balibago, Angeles City, Pampanga'),
('25 Seeds','Restaurant','Angeles City, Pampanga'),
('Rustica Restaurant','Restaurant','Angeles City, Pampanga'),
('Funnside Ningnangan','Restaurant','Angeles City, Pampanga'),
('Gerry''s Grill Balibago','Restaurant','Villarica Compound, MacArthur Highway, Balibago, Angeles City')
on conflict do nothing;
-- Idempotent seed: do not insert duplicates on migration reruns.
-- Deduplicate by name for any previously created curated rows.
with duplicates as (
 select id,row_number() over(partition by lower(trim(name)) order by created_at,id) as rn
 from public.bizhunt_curated_businesses
)
delete from public.bizhunt_curated_businesses b using duplicates d where b.id=d.id and d.rn>1;
create unique index if not exists bh_curated_name_unique on public.bizhunt_curated_businesses(lower(trim(name)));
create or replace function public.bizhunt_founder_curated_records(p_search text default '',p_limit integer default 30,p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder admin access required';end if;
 if p_limit<1 or p_limit>100 or p_offset<0 then raise exception 'Invalid pagination';end if;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from
 (select *,true as is_unclaimed,'curated'::text as source from public.bizhunt_curated_businesses
 where name ilike '%'||p_search||'%' or location ilike '%'||p_search||'%'
 order by created_at desc limit p_limit offset p_offset)x;
 return result;
end $$;
create or replace function public.bizhunt_founder_curated_challenge(p_id uuid,p_action text)
returns text language plpgsql security definer set search_path=public as $$
declare code text;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder admin access required';end if;
 if p_action not in ('update','delete') then raise exception 'Invalid action';end if;
 if not exists(select 1 from public.bizhunt_curated_businesses where id=p_id) then raise exception 'Listing not found';end if;
 code=encode(gen_random_bytes(12),'hex');
 insert into public.bizhunt_founder_challenges(actor_id,entity_type,entity_id,action,code_hash,expires_at)
 values(auth.uid(),'curated',p_id,p_action,md5(code),now()+interval '5 minutes')
 on conflict(actor_id) do update set entity_type=excluded.entity_type,entity_id=excluded.entity_id,
 action=excluded.action,code_hash=excluded.code_hash,expires_at=excluded.expires_at;
 return code;
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
  if exists(select 1 from jsonb_object_keys(p_changes) k where k not in ('name','category','location','description'))
  then raise exception 'Unsupported field';end if;
  if p_changes ? 'name' and char_length(trim(p_changes->>'name'))<2 then raise exception 'Name too short';end if;
  update public.bizhunt_curated_businesses set
   name=case when p_changes ? 'name' then trim(p_changes->>'name') else name end,
   category=case when p_changes ? 'category' then p_changes->>'category' else category end,
   location=case when p_changes ? 'location' then p_changes->>'location' else location end,
   description=case when p_changes ? 'description' then p_changes->>'description' else description end
  where id=p_id;
  select to_jsonb(b) into new_row from public.bizhunt_curated_businesses b where id=p_id;
 else raise exception 'Invalid action';end if;
 insert into public.bizhunt_founder_audit(actor_id,entity_type,entity_id,action,before_data,after_data)
 values(auth.uid(),'curated',p_id,p_action,old_row,new_row);
end $$;
revoke all on function public.bizhunt_founder_curated_records(text,integer,integer) from public;
revoke all on function public.bizhunt_founder_curated_challenge(uuid,text) from public;
revoke all on function public.bizhunt_founder_curated_mutate(uuid,text,text,jsonb) from public;
grant execute on function public.bizhunt_founder_curated_records(text,integer,integer),
 public.bizhunt_founder_curated_challenge(uuid,text),
 public.bizhunt_founder_curated_mutate(uuid,text,text,jsonb) to authenticated;
