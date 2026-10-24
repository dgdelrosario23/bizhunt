-- BizHunt Phase 14: local discovery, essential services, emergency directory
-- Apply after earlier BizHunt migrations in Supabase SQL Editor.
alter table public.businesses
 add column if not exists business_type text not null default 'place',
 add column if not exists service_area text not null default '',
 add column if not exists mobile_service boolean not null default false;
do $$ begin
 if not exists(select 1 from pg_constraint where conname='bizhunt_business_type_check') then
  alter table public.businesses add constraint bizhunt_business_type_check
   check (business_type in ('place','service'));
 end if;
end $$;
create index if not exists bizhunt_businesses_type_category on public.businesses(business_type,category);
create table if not exists public.emergency_contacts (
 id uuid primary key default gen_random_uuid(),
 name text not null check (char_length(name) between 2 and 140),
 category text not null check(category in ('Fire','Police','Ambulance','Hospital ER','Disaster Rescue')),
 area text not null,
 phone text not null check(phone ~ '^[+]?[0-9() -]{3,25}),
 address text not null default '',
 source_url text not null default '',
 verified_at timestamptz not null,
 published boolean not null default false,
 created_at timestamptz not null default now()
);
alter table public.emergency_contacts enable row level security;
drop policy if exists "Public verified emergency contacts" on public.emergency_contacts;
create policy "Public verified emergency contacts" on public.emergency_contacts
 for select to anon,authenticated using (published and verified_at is not null);
revoke insert,update,delete on public.emergency_contacts from anon,authenticated;
grant select on public.emergency_contacts to anon,authenticated;
comment on table public.emergency_contacts is 'Admin-curated emergency numbers only. Verify with the responsible agency before publishing. Never use as a merchant self-service directory.';
),
 address text not null default '',
 source_url text not null default '',
 verified_at timestamptz not null,
 published boolean not null default false,
 created_at timestamptz not null default now()
);
alter table public.emergency_contacts enable row level security;
drop policy if exists "Public verified emergency contacts" on public.emergency_contacts;
create policy "Public verified emergency contacts" on public.emergency_contacts
 for select to anon,authenticated using (published and verified_at is not null);
revoke insert,update,delete on public.emergency_contacts from anon,authenticated;
grant select on public.emergency_contacts to anon,authenticated;
comment on table public.emergency_contacts is 'Admin-curated emergency numbers only. Verify with the responsible agency before publishing. Never use as a merchant self-service directory.';
