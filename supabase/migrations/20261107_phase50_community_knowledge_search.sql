-- Phase 50: server-side community knowledge search (no AI or external data sharing).
-- Run after Phase 38. Results are limited to active community members.
create index if not exists bh_community_posts_body_search on public.bizhunt_community_posts using gin (to_tsvector('simple',body));
create index if not exists bh_community_comments_body_search on public.bizhunt_community_comments using gin (to_tsvector('simple',body));
create or replace function public.bizhunt_community_knowledge_search(p_group uuid,p_query text)
returns table(post_id uuid,post_body text,author text,created_at timestamptz,match_type text,excerpt text)
language plpgsql stable security definer set search_path='' as $$
declare q text;
begin
 if not public.bizhunt_feed_member(p_group) then raise exception 'Active membership required'; end if;
 q:=trim(coalesce(p_query,''));
 if char_length(q)<2 or char_length(q)>120 then raise exception 'Search must be 2–120 characters'; end if;
 return query
 with hits as (
  select p.id as pid,p.body as body,p.created_at as created,'post'::text as kind,
   left(p.body,240) as snippet,p.author_id as uid
  from public.bizhunt_community_posts p
  where p.community_id=p_group and p.body ilike '%'||replace(replace(replace(q,'\\','\\\\'),'%','\\%'),'_','\\_')||'%' escape '\\'
  union all
  select p.id,p.body,c.created_at,'comment'::text,left(c.body,240),c.author_id
  from public.bizhunt_community_comments c join public.bizhunt_community_posts p on p.id=c.post_id
  where p.community_id=p_group and c.body ilike '%'||replace(replace(replace(q,'\\','\\\\'),'%','\\%'),'_','\\_')||'%' escape '\\'
 )
 select h.pid,h.body,coalesce(nullif(cp.display_name,''),'BizHunt member'),h.created,h.kind,h.snippet
 from hits h left join public.community_profiles cp on cp.user_id=h.uid
 order by h.created desc limit 40;
end $$;
revoke all on function public.bizhunt_community_knowledge_search(uuid,text) from public,anon,authenticated;
grant execute on function public.bizhunt_community_knowledge_search(uuid,text) to authenticated;
