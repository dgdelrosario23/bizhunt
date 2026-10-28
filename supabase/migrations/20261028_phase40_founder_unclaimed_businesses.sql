-- Phase 40: Include unclaimed businesses in founder record management.
-- Run after Phase 39. An unclaimed business is one with no assigned owner_id.
-- Preserve the existing authorization, pagination, and user-management behavior.
create or replace function public.bizhunt_founder_records(p_type text,p_search text default '',p_limit integer default 30,p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Founder admin access required'; end if;
 if p_limit<1 or p_limit>100 or p_offset<0 then raise exception 'Invalid pagination'; end if;
 if p_type='users' then
  select coalesce(jsonb_agg(x),'[]'::jsonb) into result from (
   select jsonb_build_object('id',u.id,'email',u.email,'created_at',u.created_at,
    'last_sign_in_at',u.last_sign_in_at,'email_confirmed_at',u.email_confirmed_at,
    'display_name',cp.display_name,'username',cp.username,'bio',cp.bio,
    'details',to_jsonb(d),'business_count',(select count(*) from public.businesses b where b.owner_id=u.id)) x
   from auth.users u left join public.community_profiles cp on cp.user_id=u.id
   left join public.bizhunt_user_details d on d.user_id=u.id
   where coalesce(u.email,'') ilike '%'||p_search||'%' or coalesce(cp.display_name,'') ilike '%'||p_search||'%'
    or coalesce(cp.username,'') ilike '%'||p_search||'%' or u.id::text ilike '%'||p_search||'%'
   order by u.created_at desc limit p_limit offset p_offset
  ) q;
 elsif p_type in ('businesses','unclaimed_businesses') then
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from (
   select b.*,u.email as owner_email,(b.owner_id is null) as is_unclaimed
   from public.businesses b left join auth.users u on u.id=b.owner_id
   where (p_type='businesses' or b.owner_id is null)
    and (b.name ilike '%'||p_search||'%' or b.id::text ilike '%'||p_search||'%'
     or coalesce(u.email,'') ilike '%'||p_search||'%')
   order by b.created_at desc limit p_limit offset p_offset
  ) x;
 else raise exception 'Invalid record type';end if;
 return result;
end $$;
revoke all on function public.bizhunt_founder_records(text,text,integer,integer) from public;
grant execute on function public.bizhunt_founder_records(text,text,integer,integer) to authenticated;
