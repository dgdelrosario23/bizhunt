-- Phase 48-49: community events, RSVPs and community rules.
-- Run after Phase 38. All access is via membership-checked RPCs.
create table if not exists public.bizhunt_community_events (
 id uuid primary key default gen_random_uuid(),
 community_id uuid not null references public.bizhunt_communities(id) on delete cascade,
 creator_id uuid not null references auth.users(id),
 title text not null check(char_length(trim(title)) between 3 and 120),
 details text not null default '' check(char_length(details)<=2000),
 venue text not null default '' check(char_length(venue)<=200),
 starts_at timestamptz not null,
 created_at timestamptz not null default now()
);
create table if not exists public.bizhunt_community_event_rsvps (
 event_id uuid not null references public.bizhunt_community_events(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 status text not null check(status in ('going','interested')),
 primary key(event_id,user_id)
);
alter table public.bizhunt_community_events enable row level security;
alter table public.bizhunt_community_event_rsvps enable row level security;
revoke all on public.bizhunt_community_events,public.bizhunt_community_event_rsvps from public,anon,authenticated;
alter table public.bizhunt_communities add column if not exists rules text not null default '';
alter table public.bizhunt_communities add constraint bh_community_rules_length check(char_length(rules)<=2000);
create or replace function public.bizhunt_community_is_admin(p_group uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.bizhunt_communities c where c.id=p_group and c.owner_id=auth.uid())
 or exists(select 1 from public.bizhunt_community_members m where m.community_id=p_group and m.user_id=auth.uid() and m.status='active' and m.role in ('owner','admin'))
$$;
create or replace function public.bizhunt_events_list(p_group uuid)
returns table(id uuid,title text,details text,venue text,starts_at timestamptz,going bigint,interested bigint,my_status text)
language plpgsql security definer set search_path='' as $$
begin
 if not public.bizhunt_feed_member(p_group) then raise exception 'Active membership required'; end if;
 return query select e.id,e.title,e.details,e.venue,e.starts_at,
 count(*) filter(where r.status='going'),count(*) filter(where r.status='interested'),
 max(r.status) filter(where r.user_id=auth.uid())
 from public.bizhunt_community_events e left join public.bizhunt_community_event_rsvps r on r.event_id=e.id
 where e.community_id=p_group group by e.id order by e.starts_at asc limit 100;
end $$;
create or replace function public.bizhunt_event_create(p_group uuid,p_title text,p_details text,p_venue text,p_starts_at timestamptz)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if not public.bizhunt_community_is_admin(p_group) then raise exception 'Community admin required'; end if;
 if p_starts_at<=now() then raise exception 'Event must be in the future'; end if;
 insert into public.bizhunt_community_events(community_id,creator_id,title,details,venue,starts_at)
 values(p_group,auth.uid(),trim(p_title),coalesce(p_details,''),coalesce(p_venue,''),p_starts_at) returning id into v_id;
 return v_id;
end $$;
create or replace function public.bizhunt_event_rsvp(p_event uuid,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare g uuid;
begin
 select community_id into g from public.bizhunt_community_events where id=p_event;
 if g is null or not public.bizhunt_feed_member(g) then raise exception 'Active membership required'; end if;
 if p_status is null then
  delete from public.bizhunt_community_event_rsvps where event_id=p_event and user_id=auth.uid();
 elsif p_status in ('going','interested') then
  insert into public.bizhunt_community_event_rsvps(event_id,user_id,status) values(p_event,auth.uid(),p_status)
  on conflict(event_id,user_id) do update set status=excluded.status;
 else raise exception 'Invalid RSVP status';
 end if;
end $$;
create or replace function public.bizhunt_community_set_rules(p_group uuid,p_rules text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.bizhunt_community_is_admin(p_group) then raise exception 'Community admin required'; end if;
 if char_length(coalesce(p_rules,''))>2000 then raise exception 'Rules too long'; end if;
 update public.bizhunt_communities set rules=coalesce(p_rules,'') where id=p_group;
end $$;
revoke all on function public.bizhunt_community_is_admin(uuid) from public,anon,authenticated;
revoke all on function public.bizhunt_events_list(uuid) from public,anon,authenticated;
revoke all on function public.bizhunt_event_create(uuid,text,text,text,timestamptz) from public,anon,authenticated;
revoke all on function public.bizhunt_event_rsvp(uuid,text) from public,anon,authenticated;
revoke all on function public.bizhunt_community_set_rules(uuid,text) from public,anon,authenticated;
grant execute on function public.bizhunt_events_list(uuid),public.bizhunt_event_create(uuid,text,text,text,timestamptz),public.bizhunt_event_rsvp(uuid,text),public.bizhunt_community_set_rules(uuid,text) to authenticated;
