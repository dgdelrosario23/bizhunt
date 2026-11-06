-- Phase 49 follow-up: member post reports and admin review queue.
-- Run after Phase 38 and the Phase 48-49 migration.
create table if not exists public.bizhunt_community_post_reports (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.bizhunt_community_posts(id) on delete cascade,
 reporter_id uuid not null references auth.users(id) on delete cascade,
 reason text not null check(char_length(trim(reason)) between 5 and 500),
 status text not null default 'open' check(status in ('open','dismissed','removed')),
 created_at timestamptz not null default now(),
 reviewed_at timestamptz,
 reviewed_by uuid references auth.users(id),
 unique(post_id,reporter_id)
);
create index if not exists bh_post_reports_status on public.bizhunt_community_post_reports(status,created_at desc);
alter table public.bizhunt_community_post_reports enable row level security;
revoke all on public.bizhunt_community_post_reports from public,anon,authenticated;
create or replace function public.bizhunt_report_community_post(p_post uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare g uuid;
begin
 select community_id into g from public.bizhunt_community_posts where id=p_post;
 if g is null or not public.bizhunt_feed_member(g) then raise exception 'Active membership required'; end if;
 if char_length(trim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'Reason must be 5–500 characters'; end if;
 insert into public.bizhunt_community_post_reports(post_id,reporter_id,reason)
 values(p_post,auth.uid(),trim(p_reason))
 on conflict(post_id,reporter_id) do update set reason=excluded.reason,status='open',created_at=now(),reviewed_at=null,reviewed_by=null;
end $$;
create or replace function public.bizhunt_community_reports(p_group uuid)
returns table(id uuid,post_id uuid,post_body text,reason text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if not public.bizhunt_community_is_admin(p_group) then raise exception 'Community admin required'; end if;
 return query select r.id,r.post_id,p.body,r.reason,r.created_at
 from public.bizhunt_community_post_reports r join public.bizhunt_community_posts p on p.id=r.post_id
 where p.community_id=p_group and r.status='open' order by r.created_at desc limit 100;
end $$;
create or replace function public.bizhunt_review_community_report(p_report uuid,p_remove boolean)
returns void language plpgsql security definer set search_path='' as $$
declare g uuid;
begin
 select p.community_id into g from public.bizhunt_community_post_reports r join public.bizhunt_community_posts p on p.id=r.post_id where r.id=p_report;
 if g is null or not public.bizhunt_community_is_admin(g) then raise exception 'Community admin required'; end if;
 if p_remove is null then raise exception 'Decision required'; end if;
 if p_remove then
  update public.bizhunt_community_post_reports set status='removed',reviewed_at=now(),reviewed_by=auth.uid()
  where post_id=(select post_id from public.bizhunt_community_post_reports where id=p_report) and status='open';
  delete from public.bizhunt_community_posts where id=(select post_id from public.bizhunt_community_post_reports where id=p_report);
 else
  update public.bizhunt_community_post_reports set status='dismissed',reviewed_at=now(),reviewed_by=auth.uid()
  where id=p_report and status='open';
 end if;
end $$;
revoke all on function public.bizhunt_report_community_post(uuid,text),public.bizhunt_community_reports(uuid),public.bizhunt_review_community_report(uuid,boolean) from public,anon,authenticated;
grant execute on function public.bizhunt_report_community_post(uuid,text),public.bizhunt_community_reports(uuid),public.bizhunt_review_community_report(uuid,boolean) to authenticated;
