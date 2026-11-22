-- N8 Phase 2: queued, scheduled, batched follower announcements.
-- Requires N8, N7, N3. Run manually. Worker needs an external scheduler.
begin;
create table if not exists public.bizhunt_follower_delivery_jobs(
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id) on delete cascade,
 source_type text not null check(source_type in ('promo','campaign')),
 source_id uuid not null,
 run_at timestamptz not null,
 cursor_customer_id uuid,
 delivered integer not null default 0,
 state text not null default 'pending' check(state in ('pending','complete','cancelled')),
 created_at timestamptz not null default now(),
 finished_at timestamptz,
 unique(source_type,source_id)
);
create index if not exists bh_follower_jobs_due on public.bizhunt_follower_delivery_jobs(run_at,id) where state='pending';
alter table public.bizhunt_follower_delivery_jobs enable row level security;
revoke all on public.bizhunt_follower_delivery_jobs from public,anon,authenticated;

revoke execute on function public.bizhunt_broadcast_to_followers(uuid,text,uuid) from authenticated;
alter table public.bizhunt_notifications add column if not exists announcement_type text;
alter table public.bizhunt_notifications add column if not exists announcement_id uuid;
alter table public.bizhunt_notifications drop constraint if exists bh_notifications_announcement_pair;
alter table public.bizhunt_notifications add constraint bh_notifications_announcement_pair check (
 (announcement_type is null and announcement_id is null)
 or (announcement_type in ('promo','campaign') and announcement_id is not null)
);

create or replace function public.bizhunt_queue_follower_announcement(p_business uuid,p_source_type text,p_source_id uuid)
returns timestamptz language plpgsql security definer set search_path='' as $fn$
declare v_created timestamptz;v_run timestamptz;v_end timestamptz;
begin
 if auth.uid() is null or not exists(select 1 from public.businesses b where b.id=p_business and b.owner_id=auth.uid()) then
  raise exception 'Business owner authorization required';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(p_business::text,987));
 if p_source_type='promo' then
  select p.created_at,greatest(p.starts_at,now()),p.ends_at into v_created,v_run,v_end
  from public.business_promos p where p.id=p_source_id and p.business_id=p_business and p.active and p.ends_at>now();
 elsif p_source_type='campaign' then
  select c.created_at,now() into v_created,v_run from public.campaigns c
  where c.id=p_source_id and c.business_id=p_business and c.active;
 else raise exception 'Unsupported announcement type';end if;
 if v_created is null then raise exception 'Active source not found';end if;
 if v_created<now()-interval '1 hour' then raise exception 'Only newly published items can notify followers';end if;
 if v_end is not null and v_run>=v_end then raise exception 'Promotion expires before announcement';end if;
 if exists(select 1 from public.bizhunt_follower_delivery_jobs where source_type=p_source_type and source_id=p_source_id)
 or exists(select 1 from public.bizhunt_follower_broadcasts where source_type=p_source_type and source_id=p_source_id) then
  raise exception 'Announcement already scheduled or sent';
 end if;
 if (select count(*) from public.bizhunt_follower_delivery_jobs j where j.business_id=p_business and j.created_at>now()-interval '7 days')
 +(select count(*) from public.bizhunt_follower_broadcasts b where b.business_id=p_business and b.created_at>now()-interval '7 days')>=2 then
  raise exception 'Limit reached: 2 announcements per business every 7 days';
 end if;
 insert into public.bizhunt_follower_delivery_jobs(business_id,source_type,source_id,run_at)
 values(p_business,p_source_type,p_source_id,v_run);
 return v_run;
end $fn$;
revoke all on function public.bizhunt_queue_follower_announcement(uuid,text,uuid) from public,anon;
grant execute on function public.bizhunt_queue_follower_announcement(uuid,text,uuid) to authenticated;

-- Invoked only by a trusted scheduler / postgres role, never directly by app clients.
create or replace function public.bizhunt_process_follower_jobs(p_max_jobs integer default 5,p_batch_size integer default 200)
returns integer language plpgsql security definer set search_path='' as $fn$
declare j record;v_last uuid;v_rows integer;v_total integer:=0;v_name text;v_title text;v_active boolean;
begin
 if p_max_jobs not between 1 and 20 or p_batch_size not between 1 and 500 then raise exception 'Invalid batch limits';end if;
 for j in
  select * from public.bizhunt_follower_delivery_jobs
  where state='pending' and run_at<=now() order by run_at,id limit p_max_jobs for update skip locked
 loop
  v_active:=false;v_title:=null;v_name:=null;
  select left(b.name,80) into v_name from public.businesses b where b.id=j.business_id;
  if j.source_type='promo' then
   select left(p.title,100),(p.active and p.starts_at<=now() and p.ends_at>now())
   into v_title,v_active from public.business_promos p where p.id=j.source_id and p.business_id=j.business_id;
  else
   select left(c.name,100),c.active into v_title,v_active from public.campaigns c
   where c.id=j.source_id and c.business_id=j.business_id;
  end if;
  if not coalesce(v_active,false) then
   update public.bizhunt_follower_delivery_jobs set state='cancelled',finished_at=now() where id=j.id;
   continue;
  end if;
  v_last:=null;v_rows:=0;
  with eligible as (
   select f.customer_id from public.business_follows f
   left join public.bizhunt_notification_preferences pref on pref.user_id=f.customer_id
   where f.business_id=j.business_id and (j.cursor_customer_id is null or f.customer_id>j.cursor_customer_id)
    and coalesce(pref.followed_businesses_enabled,true)
   order by f.customer_id limit p_batch_size
  ), delivered as (
   insert into public.bizhunt_notifications(user_id,title,body,kind,target_type,target_id,announcement_type,announcement_id)
   select e.customer_id,
    left(case when j.source_type='promo' then 'New promotion from ' else 'New loyalty campaign from ' end||coalesce(v_name,'a business'),120),
    left(coalesce(v_title,'New offer')||' — View details on BizHunt.',500),
    case when j.source_type='promo' then 'promo' else 'business' end,
    'business',j.business_id,j.source_type,j.source_id from eligible e
   returning user_id
  )
  select (array_agg(user_id order by user_id desc))[1],count(*) into v_last,v_rows from delivered;
  if v_rows=0 then
   update public.bizhunt_follower_delivery_jobs set state='complete',finished_at=now() where id=j.id;
  else
   update public.bizhunt_follower_delivery_jobs
    set cursor_customer_id=v_last,delivered=delivered+v_rows where id=j.id;
   v_total:=v_total+v_rows;
   if v_rows<p_batch_size then
    update public.bizhunt_follower_delivery_jobs set state='complete',finished_at=now() where id=j.id;
   end if;
  end if;
 end loop;
 return v_total;
end $fn$;
revoke all on function public.bizhunt_process_follower_jobs(integer,integer) from public,anon,authenticated;
commit;
