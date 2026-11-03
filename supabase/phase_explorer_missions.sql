-- Phase 2: Explorer missions, badges, discovery XP, opt-in community rankings.
-- Run AFTER phase_explorer_xp.sql in Supabase SQL Editor.
begin;
create table if not exists public.bizhunt_explorer_discoveries(
 user_id uuid not null references auth.users(id) on delete cascade,
 business_id uuid not null references public.businesses(id) on delete cascade,
 discovered_at timestamptz not null default now(),
 primary key(user_id,business_id)
);
alter table public.bizhunt_explorer_discoveries enable row level security;
revoke all on public.bizhunt_explorer_discoveries from anon,authenticated;
grant select on public.bizhunt_explorer_discoveries to authenticated;
drop policy if exists "Read own discoveries" on public.bizhunt_explorer_discoveries;
create policy "Read own discoveries" on public.bizhunt_explorer_discoveries for select to authenticated using(user_id=(select auth.uid()));
create table if not exists public.bizhunt_explorer_preferences(
 user_id uuid primary key references auth.users(id) on delete cascade,
 show_on_leaderboards boolean not null default false
);
alter table public.bizhunt_explorer_preferences enable row level security;
revoke all on public.bizhunt_explorer_preferences from anon,authenticated;
grant select,insert,update on public.bizhunt_explorer_preferences to authenticated;
drop policy if exists "Own explorer preferences" on public.bizhunt_explorer_preferences;
create policy "Own explorer preferences" on public.bizhunt_explorer_preferences for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create or replace function public.bizhunt_record_discovery(p_business_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_count integer;v_added integer;
begin
 if v_uid is null then raise exception 'Sign in required';end if;
 if not exists(select 1 from public.businesses where id=p_business_id) then raise exception 'Business not found';end if;
 -- A business is rewarded once; daily cap of 5 rewarded discoveries.
 insert into public.bizhunt_explorer_discoveries(user_id,business_id) values(v_uid,p_business_id)
 on conflict do nothing;
 get diagnostics v_added=row_count;
 if v_added=0 then return 0;end if;
 select count(*) into v_count from public.bizhunt_xp_events
 where user_id=v_uid and event_type='discovery' and created_at>=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC';
 if v_count>=5 then return 0;end if;
 insert into public.bizhunt_xp_events(user_id,event_key,event_type,xp)
 values(v_uid,'discovery:'||p_business_id::text,'discovery',5)
 on conflict(user_id,event_key) do nothing;
 return 5;
end $$;
revoke all on function public.bizhunt_record_discovery(uuid) from public,anon;
grant execute on function public.bizhunt_record_discovery(uuid) to authenticated;
create or replace function public.bizhunt_explorer_missions()
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();p record;avatar boolean;joined integer;xp integer;
begin
 if u is null then return '{}'::jsonb;end if;
 select display_name,username into p from public.community_profiles where user_id=u;
 select exists(select 1 from public.bizhunt_user_details where user_id=u and avatar_path is not null) into avatar;
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
-- Return only opt-in active members of a community the caller belongs to.
create or replace function public.bizhunt_community_xp_leaderboard(p_community_id uuid)
returns table(display_name text,level_xp bigint,place bigint,is_me boolean)
language sql stable security definer set search_path='' as $$
 with eligible as(
 select m.user_id,coalesce(nullif(p.display_name,''),nullif(p.username,''),'Explorer')::text as label
 from public.bizhunt_community_members m
 join public.bizhunt_explorer_preferences pref on pref.user_id=m.user_id and pref.show_on_leaderboards=true
 left join public.community_profiles p on p.user_id=m.user_id
 where m.community_id=p_community_id and m.status='active'
 and exists(select 1 from public.bizhunt_community_members mine where mine.community_id=p_community_id and mine.user_id=auth.uid() and mine.status='active')
 ),totals as(
 select e.user_id,e.label,coalesce(sum(x.xp),0)::bigint as xp
 from eligible e left join public.bizhunt_xp_events x on x.user_id=e.user_id group by e.user_id,e.label
 )
 select label,xp,dense_rank() over(order by xp desc),user_id=auth.uid() from totals order by xp desc limit 30
$$;
revoke all on function public.bizhunt_community_xp_leaderboard(uuid) from public,anon;
grant execute on function public.bizhunt_community_xp_leaderboard(uuid) to authenticated;
commit;
