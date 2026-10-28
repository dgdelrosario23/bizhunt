-- Phase 42: Member-submitted missing map places; founder moderation.
-- Apply after Phase 39. Listings are map-only until an independently verified owner claim.
create table if not exists public.bizhunt_missing_places (
 id uuid primary key default gen_random_uuid(),
 submitted_by uuid not null references auth.users(id) on delete restrict,
 name text not null check(char_length(trim(name)) between 2 and 120),
 category text not null check(char_length(trim(category)) between 2 and 80),
 location text not null check(char_length(trim(location)) between 5 and 250),
 latitude double precision not null check(latitude between -90 and 90),
 longitude double precision not null check(longitude between -180 and 180),
 notes text not null default '' check(char_length(notes)<=500),
 status text not null default 'pending' check(status in ('pending','approved','rejected','claimed')),
 claimed_business_id uuid references public.businesses(id) on delete set null,
 reviewed_by uuid references auth.users(id) on delete set null,
 reviewed_at timestamptz,created_at timestamptz not null default now()
);
create index if not exists bh_missing_status on public.bizhunt_missing_places(status,created_at desc);
alter table public.bizhunt_missing_places enable row level security;
revoke all on public.bizhunt_missing_places from anon,authenticated;
create or replace function public.bizhunt_submit_missing_place(p_name text,p_category text,p_location text,p_latitude double precision,p_longitude double precision,p_notes text default '')
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first';end if;
 if char_length(trim(coalesce(p_name,''))) not between 2 and 120 or char_length(trim(coalesce(p_category,''))) not between 2 and 80 or char_length(trim(coalesce(p_location,''))) not between 5 and 250 then raise exception 'Provide a valid name, category and address';end if;
 if p_latitude is null or p_longitude is null or p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then raise exception 'Select a valid map location';end if;
 if char_length(coalesce(p_notes,''))>500 then raise exception 'Notes too long';end if;
 if exists(select 1 from public.bizhunt_missing_places where lower(trim(name))=lower(trim(p_name)) and status in ('pending','approved','claimed')) then raise exception 'A submission with this name already exists';end if;
 if exists(select 1 from public.businesses where lower(trim(name))=lower(trim(p_name))) then raise exception 'This business is already listed';end if;
 insert into public.bizhunt_missing_places(submitted_by,name,category,location,latitude,longitude,notes)
 values(auth.uid(),trim(p_name),trim(p_category),trim(p_location),p_latitude,p_longitude,coalesce(p_notes,'')) returning id into v_id;
 return v_id;
end $$;
create or replace function public.bizhunt_public_missing_places()
returns table(id uuid,name text,category text,location text,latitude double precision,longitude double precision)
language sql stable security definer set search_path=public as $$
 select id,name,category,location,latitude,longitude from public.bizhunt_missing_places where status='approved'
$$;
create or replace function public.bizhunt_founder_missing_queue()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare r jsonb;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Admin access required';end if;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into r from
 (select id,name,category,location,latitude,longitude,notes,status,submitted_by,created_at,reviewed_by,reviewed_at
 from public.bizhunt_missing_places order by created_at desc limit 100)x;
 return r;
end $$;
create or replace function public.bizhunt_founder_review_missing(p_id uuid,p_approve boolean,p_code text)
returns void language plpgsql security definer set search_path=public as $$
declare ch record;before_row jsonb;after_row jsonb;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Admin access required';end if;
 select * into ch from public.bizhunt_founder_challenges where actor_id=auth.uid() for update;
 if not found or ch.entity_type<>'missing_place' or ch.entity_id<>p_id or ch.action<>'review'
 or ch.expires_at<now() or ch.code_hash<>md5(coalesce(p_code,'')) then raise exception 'Invalid or expired verification code';end if;
 delete from public.bizhunt_founder_challenges where actor_id=auth.uid();
 select to_jsonb(p) into before_row from public.bizhunt_missing_places p where id=p_id and status='pending' for update;
 if before_row is null then raise exception 'Pending submission not found';end if;
 update public.bizhunt_missing_places set status=case when p_approve then 'approved' else 'rejected' end,reviewed_by=auth.uid(),reviewed_at=now() where id=p_id;
 select to_jsonb(p) into after_row from public.bizhunt_missing_places p where id=p_id;
 insert into public.bizhunt_founder_audit(actor_id,entity_type,entity_id,action,before_data,after_data)
 values(auth.uid(),'missing_place',p_id,case when p_approve then 'approve' else 'reject' end,before_row,after_row);
end $$;
create or replace function public.bizhunt_founder_missing_challenge(p_id uuid)
returns text language plpgsql security definer set search_path=public as $$
declare code text;
begin
 if not public.bizhunt_founder_authorized() then raise exception 'Admin access required';end if;
 if not exists(select 1 from public.bizhunt_missing_places where id=p_id and status='pending') then raise exception 'Pending submission not found';end if;
 code=encode(gen_random_bytes(12),'hex');
 insert into public.bizhunt_founder_challenges(actor_id,entity_type,entity_id,action,code_hash,expires_at)
 values(auth.uid(),'missing_place',p_id,'review',md5(code),now()+interval '5 minutes')
 on conflict(actor_id) do update set entity_type=excluded.entity_type,entity_id=excluded.entity_id,action=excluded.action,code_hash=excluded.code_hash,expires_at=excluded.expires_at;
 return code;
end $$;
revoke all on function public.bizhunt_submit_missing_place(text,text,text,double precision,double precision,text) from public;
revoke all on function public.bizhunt_public_missing_places() from public;
revoke all on function public.bizhunt_founder_missing_queue() from public;
revoke all on function public.bizhunt_founder_missing_challenge(uuid) from public;
revoke all on function public.bizhunt_founder_review_missing(uuid,boolean,text) from public;
grant execute on function public.bizhunt_submit_missing_place(text,text,text,double precision,double precision,text),public.bizhunt_public_missing_places() to authenticated;
grant execute on function public.bizhunt_founder_missing_queue(),public.bizhunt_founder_missing_challenge(uuid),public.bizhunt_founder_review_missing(uuid,boolean,text) to authenticated;
