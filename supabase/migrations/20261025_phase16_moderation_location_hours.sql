-- Phase 16. Apply Phase 15 first. Run in Supabase SQL Editor as database owner.
create table if not exists public.bizhunt_admins (
 user_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
alter table public.bizhunt_admins enable row level security;
revoke all on public.bizhunt_admins from anon,authenticated;
-- Manually add your trusted founder user id using SQL Editor after verifying identity:
-- insert into public.bizhunt_admins(user_id) values ('<FOUNDER_AUTH_USER_UUID>') on conflict do nothing;

alter table public.businesses
 add column if not exists latitude double precision,
 add column if not exists longitude double precision,
 add column if not exists timezone text not null default 'Asia/Manila',
 add column if not exists special_hours jsonb not null default '{}'::jsonb;
do $$ begin
 if not exists(select 1 from pg_constraint where conrelid='public.businesses'::regclass and conname='bizhunt_latitude_valid') then
 alter table public.businesses add constraint bizhunt_latitude_valid check(latitude between -90 and 90); end if;
 if not exists(select 1 from pg_constraint where conrelid='public.businesses'::regclass and conname='bizhunt_longitude_valid') then
 alter table public.businesses add constraint bizhunt_longitude_valid check(longitude between -180 and 180); end if;
 if not exists(select 1 from pg_constraint where conrelid='public.businesses'::regclass and conname='bizhunt_coordinates_pair') then
 alter table public.businesses add constraint bizhunt_coordinates_pair check((latitude is null)=(longitude is null)); end if;
 if not exists(select 1 from pg_constraint where conrelid='public.businesses'::regclass and conname='bizhunt_special_hours_object') then
 alter table public.businesses add constraint bizhunt_special_hours_object check(jsonb_typeof(special_hours)='object'); end if;
end $$;

create or replace function public.bizhunt_moderation_queue()
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.bizhunt_admins a where a.user_id=auth.uid()) then
  raise exception 'Not authorized' using errcode='42501';
 end if;
 return jsonb_build_object(
 'requests',coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc) from
  (select r.id,r.business_id,b.name as business_name,r.requester_id,r.evidence_note,r.status,r.created_at
   from public.business_verification_requests r join public.businesses b on b.id=r.business_id
   where r.status='pending' order by r.created_at desc limit 100) q),'[]'::jsonb),
 'reports',coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc) from
  (select r.id,r.business_id,b.name as business_name,r.review_id,r.reason,r.details,r.status,r.created_at
   from public.content_reports r join public.businesses b on b.id=r.business_id
   where r.status in ('pending','reviewing') order by r.created_at desc limit 100) q),'[]'::jsonb));
end $$;

create or replace function public.bizhunt_moderate(p_kind text,p_id uuid,p_action text)
returns void language plpgsql security definer set search_path='' as $$
declare v_business uuid; v_status text;
begin
 if auth.uid() is null or not exists(select 1 from public.bizhunt_admins a where a.user_id=auth.uid()) then
  raise exception 'Not authorized' using errcode='42501';
 end if;
 if p_kind='verification' and p_action in ('approved','rejected') then
  select business_id,status into v_business,v_status from public.business_verification_requests where id=p_id for update;
  if v_business is null or v_status<>'pending' then raise exception 'Request not pending'; end if;
  update public.business_verification_requests set status=p_action,reviewed_at=now() where id=p_id;
  if p_action='approved' then
   -- verification_status trigger from Phase 15 must explicitly trust this audited function.
   update public.businesses set verification_status='verified' where id=v_business;
  end if;
 elsif p_kind='report' and p_action in ('reviewing','resolved','dismissed') then
  update public.content_reports set status=p_action where id=p_id and status in ('pending','reviewing');
  if not found then raise exception 'Report not actionable'; end if;
 else raise exception 'Invalid moderation action'; end if;
end $$;

-- Phase 15's trigger must permit ONLY this privileged function's database owner.
-- The security definer function runs as postgres when created in Supabase SQL Editor.
revoke all on function public.bizhunt_moderation_queue() from public,anon;
revoke all on function public.bizhunt_moderate(text,uuid,text) from public,anon;
grant execute on function public.bizhunt_moderation_queue() to authenticated;
grant execute on function public.bizhunt_moderate(text,uuid,text) to authenticated;

create unique index if not exists bizhunt_reports_dedup_pending
 on public.content_reports(reporter_id,business_id,coalesce(review_id,'00000000-0000-0000-0000-000000000000'::uuid))
 where status in ('pending','reviewing');
