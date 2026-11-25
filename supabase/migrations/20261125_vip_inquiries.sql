-- Add a separate lead intake surface. Existing app permissions and tables are unchanged.
begin;
create table public.bizhunt_vip_inquiries (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (length(full_name) between 1 and 120),
  business_name text not null check (length(business_name) between 1 and 160),
  email text not null check (length(email) between 3 and 254),
  mobile text not null check (length(mobile) between 7 and 32),
  consent_version text not null,
  status text not null default 'New' check (status in ('New','Contacted','In Discussion','Onboarded')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index bizhunt_vip_inquiries_dedupe on public.bizhunt_vip_inquiries (lower(email), lower(business_name));
create index bizhunt_vip_inquiries_created on public.bizhunt_vip_inquiries (created_at desc);
alter table public.bizhunt_vip_inquiries enable row level security;
revoke all on public.bizhunt_vip_inquiries from public, anon, authenticated;

create function public.bizhunt_submit_vip_inquiry(p_name text,p_business text,p_email text,p_mobile text,p_consent boolean)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if p_consent is distinct from true
    or coalesce(length(trim(p_name)),0) not between 1 and 120
    or coalesce(length(trim(p_business)),0) not between 1 and 160
    or coalesce(length(trim(p_email)),0) not between 3 and 254
    or trim(p_email) !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    or coalesce(length(trim(p_mobile)),0) not between 7 and 32
    or trim(p_mobile) !~ '^[+0-9 ().-]+$'
    or length(regexp_replace(p_mobile,'[^0-9]','','g')) not between 7 and 15
  then raise exception 'Invalid inquiry' using errcode='22023'; end if;
  insert into public.bizhunt_vip_inquiries(full_name,business_name,email,mobile,consent_version)
  values(trim(p_name),trim(p_business),lower(trim(p_email)),trim(p_mobile),'partnership-contact-v1')
  on conflict do nothing;
end;
$$;
revoke all on function public.bizhunt_submit_vip_inquiry(text,text,text,text,boolean) from public, anon, authenticated;
grant execute on function public.bizhunt_submit_vip_inquiry(text,text,text,text,boolean) to anon, authenticated;

create function public.bizhunt_founder_vip_inquiries(p_offset integer default 0)
returns setof public.bizhunt_vip_inquiries language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not exists(select 1 from public.founder_admins a where a.user_id=auth.uid()) then
    raise exception 'Founder access only' using errcode='42501';
  end if;
  return query select i.* from public.bizhunt_vip_inquiries i order by i.created_at desc,i.id limit 50 offset greatest(coalesce(p_offset,0),0);
end;
$$;
revoke all on function public.bizhunt_founder_vip_inquiries(integer) from public, anon, authenticated;
grant execute on function public.bizhunt_founder_vip_inquiries(integer) to authenticated;

create function public.bizhunt_founder_vip_inquiry_status(p_id uuid,p_status text)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not exists(select 1 from public.founder_admins a where a.user_id=auth.uid()) then
    raise exception 'Founder access only' using errcode='42501';
  end if;
  if p_status is null or p_status not in ('New','Contacted','In Discussion','Onboarded') then
    raise exception 'Invalid status' using errcode='22023';
  end if;
  update public.bizhunt_vip_inquiries set status=p_status,updated_at=now() where id=p_id;
end;
$$;
revoke all on function public.bizhunt_founder_vip_inquiry_status(uuid,text) from public, anon, authenticated;
grant execute on function public.bizhunt_founder_vip_inquiry_status(uuid,text) to authenticated;
commit;
