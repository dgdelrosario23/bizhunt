-- Phase 15: business verification, opening hours, and private moderation
-- Run after Phase 14. Existing businesses remain unverified until reviewed.
alter table public.businesses
  add column if not exists verification_status text not null default 'unverified',
  add column if not exists weekly_hours jsonb not null default '{}'::jsonb;
do $$
begin
 if not exists (select 1 from pg_constraint where conrelid='public.businesses'::regclass and conname='bizhunt_verification_status_check') then
  alter table public.businesses add constraint bizhunt_verification_status_check
  check (verification_status in ('unverified','verified'));
 end if;
 if not exists (select 1 from pg_constraint where conrelid='public.businesses'::regclass and conname='bizhunt_weekly_hours_check') then
  alter table public.businesses add constraint bizhunt_weekly_hours_check
  check (jsonb_typeof(weekly_hours)='object');
 end if;
end $$;
-- Only the privileged database administrator can change verification status.
-- Even business owners must not self-verify.
create or replace function public.bizhunt_protect_verification()
returns trigger language plpgsql set search_path = '' as $$
begin
 if new.verification_status is distinct from old.verification_status then
  if current_user not in ('postgres','service_role') then
   raise exception 'Business verification can only be changed by an administrator';
  end if;
 end if;
 return new;
end $$;
drop trigger if exists bizhunt_protect_verification on public.businesses;
create trigger bizhunt_protect_verification before update on public.businesses
 for each row execute function public.bizhunt_protect_verification();

create table if not exists public.business_verification_requests (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id) on delete cascade,
 requester_id uuid not null references auth.users(id) on delete cascade,
 evidence_note text not null check(char_length(evidence_note) between 20 and 1000),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 created_at timestamptz not null default now(),
 reviewed_at timestamptz,
 unique(business_id,requester_id)
);
create table if not exists public.content_reports (
 id uuid primary key default gen_random_uuid(),
 reporter_id uuid not null references auth.users(id) on delete cascade,
 business_id uuid not null references public.businesses(id) on delete cascade,
 review_id uuid references public.business_reviews(id) on delete set null,
 reason text not null check(reason in ('Incorrect information','Closed business','Spam','Inappropriate content','Other')),
 details text not null default '' check(char_length(details)<=1000),
 status text not null default 'pending' check(status in ('pending','reviewing','resolved','dismissed')),
 created_at timestamptz not null default now()
);
create index if not exists bizhunt_reports_status on public.content_reports(status,created_at desc);
create index if not exists bizhunt_verification_requests_status on public.business_verification_requests(status,created_at desc);
alter table public.business_verification_requests enable row level security;
alter table public.content_reports enable row level security;
drop policy if exists "Owners read own verification requests" on public.business_verification_requests;
drop policy if exists "Owners submit verification requests" on public.business_verification_requests;
drop policy if exists "Reporters read own reports" on public.content_reports;
drop policy if exists "Reporters submit reports" on public.content_reports;
create policy "Owners read own verification requests" on public.business_verification_requests
 for select to authenticated using(requester_id=(select auth.uid()));
create policy "Owners submit verification requests" on public.business_verification_requests
 for insert to authenticated with check(requester_id=(select auth.uid()) and status='pending' and reviewed_at is null and exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=(select auth.uid())));
create policy "Reporters read own reports" on public.content_reports
 for select to authenticated using(reporter_id=(select auth.uid()));
create policy "Reporters submit reports" on public.content_reports
 for insert to authenticated with check(reporter_id=(select auth.uid()) and status='pending' and exists(select 1 from public.businesses b where b.id=business_id) and (review_id is null or exists(select 1 from public.business_reviews r where r.id=review_id and r.business_id=business_id)));
revoke all on public.business_verification_requests,public.content_reports from anon;
grant select,insert on public.business_verification_requests,public.content_reports to authenticated;
-- Administrators review pending requests and reports in the Supabase SQL Editor,
-- using a privileged role; do not expose an unrestricted moderation API.
