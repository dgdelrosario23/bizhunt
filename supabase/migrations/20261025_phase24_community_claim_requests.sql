-- Community listing claim requests: submission does not confer ownership.
create table if not exists public.community_listing_claims (
 id uuid primary key default gen_random_uuid(),
 requester_id uuid not null references auth.users(id) on delete cascade,
 listing_key text not null check (listing_key ~ '^community-angeles-[0-9]+$'),
 business_name text not null,
 contact_name text not null,
 role_at_business text not null,
 contact_email text not null,
 evidence_url text,
 message text,
 status text not null default 'pending' check (status in ('pending','approved','rejected')),
 created_at timestamptz not null default now(),
 reviewed_at timestamptz,
 unique(requester_id,listing_key)
);
alter table public.community_listing_claims enable row level security;
revoke all on public.community_listing_claims from anon,authenticated;
grant select,insert on public.community_listing_claims to authenticated;
drop policy if exists "Submit own listing claims" on public.community_listing_claims;
create policy "Submit own listing claims" on public.community_listing_claims for insert to authenticated with check (requester_id=auth.uid() and status='pending');
drop policy if exists "Read own listing claims" on public.community_listing_claims;
create policy "Read own listing claims" on public.community_listing_claims for select to authenticated using (requester_id=auth.uid());
-- Approval and ownership transfer require separate, privileged manual review.
