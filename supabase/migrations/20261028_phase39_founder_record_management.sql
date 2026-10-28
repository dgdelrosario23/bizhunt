-- Phase 39. Apply manually in Supabase SQL Editor. High-impact admin actions.
-- Access is restricted to bizhunt_admins. Confirmation challenges are single-use and expire.
create table if not exists public.bizhunt_founder_audit (
 id bigserial primary key,actor_id uuid not null,entity_type text not null,
 entity_id uuid not null,action text not null,before_data jsonb,after_data jsonb,
 created_at timestamptz not null default now()
);
create index if not exists bh_founder_audit_time on public.bizhunt_founder_audit(created_at desc);
create table if not exists public.bizhunt_founder_challenges (
 actor_id uuid primary key,entity_type text not null,entity_id uuid not null,
 action text not null,code_hash text not null,expires_at timestamptz not null
);
alter table public.bizhunt_founder_audit enable row level security;
alter table public.bizhunt_founder_challenges enable row level security;
revoke all on public.bizhunt_founder_audit,public.bizhunt_founder_challenges from anon,authenticated;
create or replace function public.bizhunt_founder_authorized()
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.bizhunt_admins where user_id=auth.uid())
$$;
create or replace function public.bizhunt_founder_records(p_type text,p_search text default '',p_limit integer default 30,p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder admin access required'; end if;
 if p_limit<1 or p_limit>100 or p_offset<0 then raise exception 'Invalid pagination'; end if;
 if p_type='users' then
 select coalesce(jsonb_agg(x),'[]'::jsonb) into result from (
 select jsonb_build_object('id',u.id,'email',u.email,'created_at',u.created_at,'last_sign_in_at',u.last_sign_in_at,
 'email_confirmed_at',u.email_confirmed_at,'display_name',cp.display_name,'username',cp.username,'bio',cp.bio,
 'details',to_jsonb(d),'business_count',(select count(*) from public.businesses b where b.owner_id=u.id)) x
 from auth.users u left join public.community_profiles cp on cp.user_id=u.id
 left join public.bizhunt_user_details d on d.user_id=u.id
 where coalesce(u.email,'') ilike '%'||p_search||'%' or coalesce(cp.display_name,'') ilike '%'||p_search||'%'
 or coalesce(cp.username,'') ilike '%'||p_search||'%' or u.id::text ilike '%'||p_search||'%'
 order by u.created_at desc limit p_limit offset p_offset
 ) q;
 elsif p_type='businesses' then
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from (
 select b.*,u.email as owner_email from public.businesses b left join auth.users u on u.id=b.owner_id
 where b.name ilike '%'||p_search||'%' or b.id::text ilike '%'||p_search||'%'
 or coalesce(u.email,'') ilike '%'||p_search||'%'
 order by b.created_at desc limit p_limit offset p_offset
 ) x;
 else raise exception 'Invalid record type';end if;
 return result;
end $$;
create or replace function public.bizhunt_founder_logs(p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder admin access required'; end if;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from (
 select id,actor_id,entity_type,entity_id,action,before_data,after_data,created_at
 from public.bizhunt_founder_audit order by created_at desc limit least(greatest(p_limit,1),100)
 ) x;return result;
end $$;
create or replace function public.bizhunt_founder_challenge(p_type text,p_id uuid,p_action text)
returns text language plpgsql security definer set search_path=public as $$
declare code text;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder admin access required';end if;
 if p_type not in ('users','businesses') or p_action not in ('update','delete') then raise exception 'Invalid action';end if;
 if p_type='users' and not exists(select 1 from auth.users where id=p_id) then raise exception 'User not found';end if;
 if p_type='businesses' and not exists(select 1 from public.businesses where id=p_id) then raise exception 'Business not found';end if;
 code=lpad(floor(random()*1000000)::text,6,'0');
 insert into public.bizhunt_founder_challenges(actor_id,entity_type,entity_id,action,code_hash,expires_at)
 values(auth.uid(),p_type,p_id,p_action,md5(code),now()+interval '5 minutes')
 on conflict(actor_id) do update set entity_type=excluded.entity_type,entity_id=excluded.entity_id,
 action=excluded.action,code_hash=excluded.code_hash,expires_at=excluded.expires_at;
 return code;
end $$;
create or replace function public.bizhunt_founder_mutate(p_type text,p_id uuid,p_action text,p_code text,p_changes jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path=public as $$
declare old_row jsonb;new_row jsonb; ch record; allowed text[];
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder admin access required';end if;
 select * into ch from public.bizhunt_founder_challenges where actor_id=auth.uid() for update;
 if not found or ch.entity_type<>p_type or ch.entity_id<>p_id or ch.action<>p_action
 or ch.expires_at<now() or ch.code_hash<>md5(coalesce(p_code,'')) then raise exception 'Invalid or expired confirmation code';end if;
 delete from public.bizhunt_founder_challenges where actor_id=auth.uid();
 if p_type='users' then
  select jsonb_build_object('id',u.id,'email',u.email,'created_at',u.created_at,'profile',to_jsonb(cp),'details',to_jsonb(d))
  into old_row from auth.users u left join public.community_profiles cp on cp.user_id=u.id
  left join public.bizhunt_user_details d on d.user_id=u.id where u.id=p_id;
  if old_row is null then raise exception 'User not found';end if;
  if p_action='delete' then
   if p_id=auth.uid() then raise exception 'You cannot delete your own admin account';end if;
   if exists(select 1 from public.bizhunt_admins where user_id=p_id) then raise exception 'Remove admin privileges separately before deleting this account';end if;
   delete from auth.users where id=p_id;
   new_row=null;
  elsif p_action='update' then
   allowed:=array['display_name','username','bio'];
   if exists(select 1 from jsonb_object_keys(p_changes) k where not k=any(allowed)) then raise exception 'Unsupported user field';end if;
   insert into public.community_profiles(user_id,display_name,username,bio)
   values(p_id,coalesce(p_changes->>'display_name',''),nullif(p_changes->>'username',''),coalesce(p_changes->>'bio',''))
   on conflict(user_id) do update set display_name=coalesce(p_changes->>'display_name',community_profiles.display_name),
   username=case when p_changes ? 'username' then nullif(p_changes->>'username','') else community_profiles.username end,
   bio=coalesce(p_changes->>'bio',community_profiles.bio);
   select jsonb_build_object('id',u.id,'email',u.email,'profile',to_jsonb(cp))
   into new_row from auth.users u left join public.community_profiles cp on cp.user_id=u.id where u.id=p_id;
  else raise exception 'Invalid action';end if;
 elsif p_type='businesses' then
  select to_jsonb(b) into old_row from public.businesses b where id=p_id for update;
  if old_row is null then raise exception 'Business not found';end if;
  if p_action='delete' then
   delete from public.businesses where id=p_id;new_row=null;
  elsif p_action='update' then
   allowed:=array['name','category','location','description','phone','website','instagram'];
   if exists(select 1 from jsonb_object_keys(p_changes) k where not k=any(allowed)) then raise exception 'Unsupported business field';end if;
   update public.businesses set
    name=case when p_changes ? 'name' then p_changes->>'name' else name end,
    category=case when p_changes ? 'category' then p_changes->>'category' else category end,
    location=case when p_changes ? 'location' then p_changes->>'location' else location end,
    description=case when p_changes ? 'description' then p_changes->>'description' else description end,
    phone=case when p_changes ? 'phone' then p_changes->>'phone' else phone end,
    website=case when p_changes ? 'website' then p_changes->>'website' else website end,
    instagram=case when p_changes ? 'instagram' then p_changes->>'instagram' else instagram end
   where id=p_id;
   select to_jsonb(b) into new_row from public.businesses b where id=p_id;
  else raise exception 'Invalid action';end if;
 else raise exception 'Invalid record type';end if;
 insert into public.bizhunt_founder_audit(actor_id,entity_type,entity_id,action,before_data,after_data)
 values(auth.uid(),p_type,p_id,p_action,old_row,new_row);
end $$;
revoke all on function public.bizhunt_founder_authorized() from public;
revoke all on function public.bizhunt_founder_records(text,text,integer,integer) from public;
revoke all on function public.bizhunt_founder_logs(integer) from public;
revoke all on function public.bizhunt_founder_challenge(text,uuid,text) from public;
revoke all on function public.bizhunt_founder_mutate(text,uuid,text,text,jsonb) from public;
grant execute on function public.bizhunt_founder_records(text,text,integer,integer),
public.bizhunt_founder_logs(integer),public.bizhunt_founder_challenge(text,uuid,text),
public.bizhunt_founder_mutate(text,uuid,text,text,jsonb) to authenticated;
