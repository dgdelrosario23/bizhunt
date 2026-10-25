-- Phase 22: privacy-conscious merchant engagement events
create table if not exists public.business_engagement_events (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id) on delete cascade,
 event_type text not null check (event_type in ('profile_view','map_view','directions_click','call_click','website_click')),
 viewer_id uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now()
);
create index if not exists business_engagement_events_business_date_idx on public.business_engagement_events(business_id,created_at desc);
alter table public.business_engagement_events enable row level security;
revoke all on public.business_engagement_events from anon,authenticated;
create or replace function public.record_business_engagement(p_business_id uuid,p_event_type text)
returns void language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if p_event_type not in ('profile_view','map_view','directions_click','call_click','website_click') then raise exception 'Invalid event'; end if;
 if not exists(select 1 from public.businesses where id=p_business_id) then raise exception 'Business not found'; end if;
 insert into public.business_engagement_events(business_id,event_type,viewer_id) values(p_business_id,p_event_type,auth.uid());
end; $$;
create or replace function public.merchant_engagement_metrics(p_business_id uuid,p_days integer default 30)
returns table(event_type text,event_count bigint,unique_users bigint)
language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null or not exists(select 1 from public.businesses where id=p_business_id and owner_id=auth.uid()) then raise exception 'Not authorized'; end if;
 if p_days not in (7,30) then raise exception 'Invalid period'; end if;
 return query select e.event_type,count(*)::bigint,count(distinct e.viewer_id)::bigint from public.business_engagement_events e where e.business_id=p_business_id and e.created_at>=now()-(p_days||' days')::interval group by e.event_type;
end; $$;
revoke all on function public.record_business_engagement(uuid,text) from public;
revoke all on function public.merchant_engagement_metrics(uuid,integer) from public;
grant execute on function public.record_business_engagement(uuid,text) to authenticated;
grant execute on function public.merchant_engagement_metrics(uuid,integer) to authenticated;
