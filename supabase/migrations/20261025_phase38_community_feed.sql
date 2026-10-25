-- Phase 38: Member-only community feed (text, polls, reactions, comments).
-- Run in Supabase SQL Editor after Phases 34–37.
create table if not exists public.bizhunt_community_posts (
 id uuid primary key default gen_random_uuid(),
 community_id uuid not null references public.bizhunt_communities(id) on delete cascade,
 author_id uuid not null references auth.users(id) on delete cascade,
 body text not null default '' check(char_length(body)<=3000),
 kind text not null default 'text' check(kind in ('text','poll')),
 poll_options jsonb,
 created_at timestamptz not null default now(),
 check(kind='text' or (jsonb_typeof(poll_options)='array' and jsonb_array_length(poll_options) between 2 and 6))
);
create table if not exists public.bizhunt_community_comments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.bizhunt_community_posts(id) on delete cascade,
 author_id uuid not null references auth.users(id) on delete cascade,
 body text not null check(char_length(trim(body)) between 1 and 1000),
 created_at timestamptz not null default now()
);
create table if not exists public.bizhunt_community_reactions (
 post_id uuid not null references public.bizhunt_community_posts(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 primary key(post_id,user_id)
);
create table if not exists public.bizhunt_community_votes (
 post_id uuid not null references public.bizhunt_community_posts(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 option_index integer not null check(option_index between 0 and 5),
 primary key(post_id,user_id)
);
create index if not exists bh_posts_group_date on public.bizhunt_community_posts(community_id,created_at desc);
create index if not exists bh_comments_post on public.bizhunt_community_comments(post_id,created_at);
alter table public.bizhunt_community_posts enable row level security;
alter table public.bizhunt_community_comments enable row level security;
alter table public.bizhunt_community_reactions enable row level security;
alter table public.bizhunt_community_votes enable row level security;
-- All reads and writes go through membership-checked RPCs, never direct table access.
create or replace function public.bizhunt_feed_member(p_group uuid)
returns boolean language sql stable security definer set search_path=public as $fn$
 select exists(select 1 from public.bizhunt_community_members m
 where m.community_id=p_group and m.user_id=auth.uid() and m.status='active')
$fn$;
create or replace function public.bizhunt_feed_create(p_group uuid,p_body text,p_options jsonb default null)
returns uuid language plpgsql security definer set search_path=public as $fn$
declare new_id uuid;
begin
 if not public.bizhunt_feed_member(p_group) then raise exception 'Active membership required'; end if;
 if char_length(coalesce(p_body,''))>3000 then raise exception 'Post is too long'; end if;
 if p_options is not null and (jsonb_typeof(p_options)<>'array' or jsonb_array_length(p_options) not between 2 and 6
 or exists(select 1 from jsonb_array_elements(p_options) x where jsonb_typeof(x)<>'string' or char_length(trim(x #>> '{}')) not between 1 and 120)) then
 raise exception 'Poll needs 2–6 valid options'; end if;
 if p_options is null and char_length(trim(coalesce(p_body,'')))=0 then raise exception 'Write something first'; end if;
 insert into public.bizhunt_community_posts(community_id,author_id,body,kind,poll_options)
 values(p_group,auth.uid(),trim(coalesce(p_body,'')),case when p_options is null then 'text' else 'poll' end,p_options)
 returning id into new_id;
 return new_id;
end $fn$;
create or replace function public.bizhunt_feed_comment(p_post uuid,p_body text)
returns void language plpgsql security definer set search_path=public as $fn$
declare g uuid;
begin
 select community_id into g from public.bizhunt_community_posts where id=p_post;
 if g is null or not public.bizhunt_feed_member(g) then raise exception 'Active membership required'; end if;
 insert into public.bizhunt_community_comments(post_id,author_id,body) values(p_post,auth.uid(),trim(p_body));
end $fn$;
create or replace function public.bizhunt_feed_react(p_post uuid)
returns boolean language plpgsql security definer set search_path=public as $fn$
declare g uuid;
begin
 select community_id into g from public.bizhunt_community_posts where id=p_post;
 if g is null or not public.bizhunt_feed_member(g) then raise exception 'Active membership required'; end if;
 if exists(select 1 from public.bizhunt_community_reactions where post_id=p_post and user_id=auth.uid()) then
 delete from public.bizhunt_community_reactions where post_id=p_post and user_id=auth.uid();return false;
 end if;
 insert into public.bizhunt_community_reactions(post_id,user_id) values(p_post,auth.uid());return true;
end $fn$;
create or replace function public.bizhunt_feed_vote(p_post uuid,p_option integer)
returns void language plpgsql security definer set search_path=public as $fn$
declare g uuid; opts jsonb;
begin
 select community_id,poll_options into g,opts from public.bizhunt_community_posts where id=p_post and kind='poll';
 if g is null or not public.bizhunt_feed_member(g) then raise exception 'Active membership required'; end if;
 if p_option<0 or p_option>=jsonb_array_length(opts) then raise exception 'Invalid option'; end if;
 insert into public.bizhunt_community_votes(post_id,user_id,option_index) values(p_post,auth.uid(),p_option)
 on conflict(post_id,user_id) do update set option_index=excluded.option_index;
end $fn$;
create or replace function public.bizhunt_feed_list(p_group uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $fn$
begin
 if not public.bizhunt_feed_member(p_group) then raise exception 'Active membership required'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
  'id',p.id,'body',p.body,'kind',p.kind,'options',p.poll_options,'created_at',p.created_at,
  'author',coalesce(nullif(cp.display_name,''),'BizHunt member'),'username',cp.username,
  'mine',p.author_id=auth.uid(),
  'likes',(select count(*) from public.bizhunt_community_reactions r where r.post_id=p.id),
  'liked',exists(select 1 from public.bizhunt_community_reactions r where r.post_id=p.id and r.user_id=auth.uid()),
  'votes',coalesce((select jsonb_agg(jsonb_build_object('option',v.option_index,'count',v.n)) from
   (select option_index,count(*) n from public.bizhunt_community_votes where post_id=p.id group by option_index)v),'[]'::jsonb),
  'my_vote',(select option_index from public.bizhunt_community_votes where post_id=p.id and user_id=auth.uid()),
  'comments',coalesce((select jsonb_agg(jsonb_build_object('id',cm.id,'body',cm.body,'created_at',cm.created_at,
   'author',coalesce(nullif(cp2.display_name,''),'BizHunt member'),'username',cp2.username) order by cm.created_at)
   from public.bizhunt_community_comments cm left join public.community_profiles cp2 on cp2.user_id=cm.author_id
   where cm.post_id=p.id),'[]'::jsonb)
 ) order by p.created_at desc)
 from (select * from public.bizhunt_community_posts where community_id=p_group order by created_at desc limit 50)p
 left join public.community_profiles cp on cp.user_id=p.author_id),'[]'::jsonb);
end $fn$;
revoke all on function public.bizhunt_feed_member(uuid) from public;
revoke all on function public.bizhunt_feed_create(uuid,text,jsonb) from public;
revoke all on function public.bizhunt_feed_comment(uuid,text) from public;
revoke all on function public.bizhunt_feed_react(uuid) from public;
revoke all on function public.bizhunt_feed_vote(uuid,integer) from public;
revoke all on function public.bizhunt_feed_list(uuid) from public;
grant execute on function public.bizhunt_feed_member(uuid),public.bizhunt_feed_create(uuid,text,jsonb),
 public.bizhunt_feed_comment(uuid,text),public.bizhunt_feed_react(uuid),
 public.bizhunt_feed_vote(uuid,integer),public.bizhunt_feed_list(uuid) to authenticated;
