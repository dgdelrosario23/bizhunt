-- Explorer avatar mission: recognize either uploaded BizHunt avatar or OAuth provider avatar.
-- Preserve existing event_key uniqueness; profile:avatar XP is granted at most once.
-- Apply in Supabase SQL Editor after reviewing. No data deletion.
create or replace function public.bizhunt_explorer_missions()
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();p record;avatar boolean;joined integer;xp integer;
begin
 if u is null then return '{}'::jsonb;end if;
 select display_name,username into p from public.community_profiles where user_id=u;
 select (exists(select 1 from public.bizhunt_user_details where user_id=u and nullif(btrim(avatar_path),'') is not null) or exists(select 1 from auth.users where id=u and nullif(btrim(raw_user_meta_data->>'avatar_url'),'') is not null and (raw_user_meta_data->>'avatar_url') ~ '^https://')) into avatar;
 select count(*) into joined from public.bizhunt_community_members where user_id=u and status='active';
 insert into public.bizhunt_xp_events(user_id,event_key,event_type,xp)
 select u,'profile:avatar','profile',20 where avatar
 on conflict(user_id,event_key) do nothing;
 insert into public.bizhunt_xp_events(user_id,event_key,event_type,xp)
 select u,'profile:identity','profile',20 where nullif(trim(p.display_name),'') is not null and nullif(trim(p.username),'') is not null
 on conflict(user_id,event_key) do nothing;
 insert into public.bizhunt_xp_events(user_id,event_key,event_type,xp)
 select u,'community:'||community_id::text,'community',25 from public.bizhunt_community_members where user_id=u and status='active'
 on conflict(user_id,event_key) do nothing;
 return jsonb_build_object('avatar',avatar,'identity',nullif(trim(p.display_name),'') is not null and nullif(trim(p.username),'') is not null,'communities',joined);
end $$;
revoke all on function public.bizhunt_explorer_missions() from public,anon;
grant execute on function public.bizhunt_explorer_missions() to authenticated;
