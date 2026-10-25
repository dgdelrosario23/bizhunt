-- BizHunt Communities MVP. Run manually in Supabase SQL Editor.
create table if not exists public.bizhunt_communities (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null check (char_length(trim(name)) between 3 and 80),
 description text not null default '' check (char_length(description)<=1000),
 category text not null default 'Other',
 city text not null default '',
 visibility text not null default 'public' check (visibility in ('public','private')),
 join_policy text not null default 'open' check (join_policy in ('open','approval')),
 created_at timestamptz not null default now()
);
create table if not exists public.bizhunt_community_members (
 community_id uuid not null references public.bizhunt_communities(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null default 'member' check(role in ('owner','admin','member')),
 status text not null default 'pending' check(status in ('pending','active')),
 joined_at timestamptz not null default now(),
 primary key(community_id,user_id)
);
create table if not exists public.bizhunt_community_places (
 id uuid primary key default gen_random_uuid(),
 community_id uuid not null references public.bizhunt_communities(id) on delete cascade,
 business_id uuid references public.businesses(id) on delete set null,
 name text not null check(char_length(trim(name)) between 2 and 120),
 category text not null default 'Other',
 address text not null default '',
 latitude double precision check(latitude between -90 and 90),
 longitude double precision check(longitude between -180 and 180),
 relationship text not null default 'recommended' check(relationship in ('recommended','partner')),
 perk_details text not null default '' check(char_length(perk_details)<=500),
 confirmed_by_merchant boolean not null default false,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create index if not exists bizhunt_community_members_user_idx on public.bizhunt_community_members(user_id);
create index if not exists bizhunt_community_places_community_idx on public.bizhunt_community_places(community_id);
create or replace function public.bizhunt_can_view_community(p_id uuid)
returns boolean language sql stable security definer set search_path=public as $can_view$
 select exists(select 1 from public.bizhunt_communities c where c.id=p_id and
 (c.visibility='public' or c.owner_id=auth.uid() or exists(
 select 1 from public.bizhunt_community_members m where m.community_id=c.id and m.user_id=auth.uid() and m.status='active')))
$can_view$;
create or replace function public.bizhunt_is_community_admin(p_id uuid)
returns boolean language sql stable security definer set search_path=public as $is_admin$
 select exists(select 1 from public.bizhunt_communities c where c.id=p_id and c.owner_id=auth.uid())
 or exists(select 1 from public.bizhunt_community_members m where m.community_id=p_id and m.user_id=auth.uid() and m.role='admin' and m.status='active')
$is_admin$;
create or replace function public.bizhunt_join_community(p_id uuid)
returns text language plpgsql security definer set search_path=public as $join_community$
declare c public.bizhunt_communities%rowtype; desired text;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 select * into c from public.bizhunt_communities where id=p_id;
 if not found then raise exception 'Community not found'; end if;
 if c.owner_id=auth.uid() then return 'You own this community'; end if;
 desired:=case when c.visibility='public' and c.join_policy='open' then 'active' else 'pending' end;
 insert into public.bizhunt_community_members(community_id,user_id,role,status)
 values(p_id,auth.uid(),'member',desired)
 on conflict(community_id,user_id) do nothing;
 return case when desired='active' then 'Joined community' else 'Membership request sent' end;
end
$join_community$;
create or replace function public.bizhunt_manage_community_member(p_id uuid,p_user uuid,p_approve boolean)
returns void language plpgsql security definer set search_path=public as $manage_member$
begin
 if not public.bizhunt_is_community_admin(p_id) then raise exception 'Not authorized'; end if;
 if p_approve then
  update public.bizhunt_community_members set status='active' where community_id=p_id and user_id=p_user and status='pending';
 else
  delete from public.bizhunt_community_members where community_id=p_id and user_id=p_user and role='member';
 end if;
end
$manage_member$;
create or replace function public.bizhunt_create_community(p_name text,p_description text,p_category text,p_city text,p_visibility text,p_join_policy text)
returns uuid language plpgsql security definer set search_path=public as $create_community$
declare new_id uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 insert into public.bizhunt_communities(owner_id,name,description,category,city,visibility,join_policy)
 values(auth.uid(),trim(p_name),coalesce(p_description,''),coalesce(p_category,'Other'),coalesce(p_city,''),p_visibility,p_join_policy)
 returning id into new_id;
 insert into public.bizhunt_community_members(community_id,user_id,role,status) values(new_id,auth.uid(),'owner','active');
 return new_id;
end
$create_community$;
alter table public.bizhunt_communities enable row level security;
alter table public.bizhunt_community_members enable row level security;
alter table public.bizhunt_community_places enable row level security;
create policy "View accessible communities" on public.bizhunt_communities for select to authenticated using(public.bizhunt_can_view_community(id));
create policy "Admins edit communities" on public.bizhunt_communities for update to authenticated using(public.bizhunt_is_community_admin(id)) with check(public.bizhunt_is_community_admin(id));
create policy "View own or managed members" on public.bizhunt_community_members for select to authenticated using(user_id=auth.uid() or public.bizhunt_is_community_admin(community_id));
create policy "Leave own community membership" on public.bizhunt_community_members for delete to authenticated using(user_id=auth.uid() and role='member');
create policy "View accessible community places" on public.bizhunt_community_places for select to authenticated using(public.bizhunt_can_view_community(community_id));
create policy "Admins add community places" on public.bizhunt_community_places for insert to authenticated with check(public.bizhunt_is_community_admin(community_id) and created_by=auth.uid() and confirmed_by_merchant=false);
create policy "Admins update community places" on public.bizhunt_community_places for update to authenticated using(public.bizhunt_is_community_admin(community_id)) with check(public.bizhunt_is_community_admin(community_id) and confirmed_by_merchant=false);
create policy "Admins delete community places" on public.bizhunt_community_places for delete to authenticated using(public.bizhunt_is_community_admin(community_id));
revoke all on function public.bizhunt_can_view_community(uuid) from public;
revoke all on function public.bizhunt_is_community_admin(uuid) from public;
grant execute on function public.bizhunt_can_view_community(uuid) to authenticated;
grant execute on function public.bizhunt_is_community_admin(uuid) to authenticated;
grant execute on function public.bizhunt_join_community(uuid) to authenticated;
grant execute on function public.bizhunt_manage_community_member(uuid,uuid,boolean) to authenticated;
grant execute on function public.bizhunt_create_community(text,text,text,text,text,text) to authenticated;

-- Private invite links expose only limited metadata until membership is approved.
create or replace function public.bizhunt_community_invite(p_id uuid)
returns table(id uuid,name text,category text,city text,visibility text)
language sql stable security definer set search_path=public as $community_invite$
 select c.id,c.name,c.category,c.city,c.visibility from public.bizhunt_communities c where c.id=p_id
$community_invite$;
revoke all on function public.bizhunt_community_invite(uuid) from public;
grant execute on function public.bizhunt_community_invite(uuid) to authenticated;
