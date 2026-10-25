-- Phase 35: short-lived Community ID verification QR codes.
-- Run in Supabase SQL Editor after Phase 34.
create table if not exists public.bizhunt_community_id_tokens (
 token uuid primary key default gen_random_uuid(),
 community_id uuid not null references public.bizhunt_communities(id) on delete cascade,
 member_id uuid not null references auth.users(id) on delete cascade,
 expires_at timestamptz not null default (now()+interval '90 seconds'),
 created_at timestamptz not null default now()
);
create index if not exists bizhunt_community_id_tokens_member_idx on public.bizhunt_community_id_tokens(member_id,community_id);
alter table public.bizhunt_community_id_tokens enable row level security;
-- No direct access to tokens; only the issuing and verifying RPCs can read them.
create or replace function public.bizhunt_issue_community_id(p_community_id uuid)
returns table(token uuid,expires_at timestamptz)
language plpgsql security definer set search_path=public as $issue_id$
begin
 if auth.uid() is null or not exists(
  select 1 from public.bizhunt_community_members m
  where m.community_id=p_community_id and m.user_id=auth.uid() and m.status='active'
 ) then raise exception 'Active community membership required'; end if;
 delete from public.bizhunt_community_id_tokens t
 where t.member_id=auth.uid() and t.community_id=p_community_id;
 return query insert into public.bizhunt_community_id_tokens(community_id,member_id)
 values(p_community_id,auth.uid()) returning bizhunt_community_id_tokens.token,bizhunt_community_id_tokens.expires_at;
end
$issue_id$;
create or replace function public.bizhunt_verify_community_id(p_token uuid)
returns table(community_name text,member_name text,valid boolean,verified_at timestamptz)
language plpgsql security definer set search_path=public as $verify_id$
begin
 if auth.uid() is null or not exists(select 1 from public.businesses b where b.owner_id=auth.uid()) then
  raise exception 'A signed-in BizHunt merchant account is required';
 end if;
 return query
 select c.name,
 coalesce(nullif(cp.display_name,''),'BizHunt member'),
 (m.status='active' and t.expires_at>now()),
 now()
 from public.bizhunt_community_id_tokens t
 join public.bizhunt_communities c on c.id=t.community_id
 join public.bizhunt_community_members m on m.community_id=t.community_id and m.user_id=t.member_id
 left join public.community_profiles cp on cp.user_id=t.member_id
 where t.token=p_token and t.expires_at>now();
end
$verify_id$;
revoke all on function public.bizhunt_issue_community_id(uuid) from public;
revoke all on function public.bizhunt_verify_community_id(uuid) from public;
grant execute on function public.bizhunt_issue_community_id(uuid) to authenticated;
grant execute on function public.bizhunt_verify_community_id(uuid) to authenticated;
