-- Phase N8: explicit, owner-authorized follower notifications (small audience MVP).
-- Apply manually after N3 and N7. No automatic trigger on draft/edits.
begin;
alter table public.bizhunt_notification_preferences add column if not exists followed_businesses_enabled boolean not null default true;
create table if not exists public.bizhunt_follower_broadcasts(
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id) on delete cascade,
 source_type text not null check(source_type in ('promo','campaign')),
 source_id uuid not null,
 created_at timestamptz not null default now(),
 unique(source_type,source_id)
);
create index if not exists bh_follower_broadcasts_business_time on public.bizhunt_follower_broadcasts(business_id,created_at desc);
alter table public.bizhunt_follower_broadcasts enable row level security;
revoke all on public.bizhunt_follower_broadcasts from public,anon,authenticated;
create or replace function public.bizhunt_broadcast_to_followers(p_business uuid,p_source_type text,p_source_id uuid)
returns integer language plpgsql security definer set search_path='' as $fn$
declare v_name text;v_title text;v_kind text;v_count integer;v_eligible integer;v_created timestamptz;
begin
 if auth.uid() is null then raise exception 'Sign in required';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_business::text,987));
 select left(name,80) into v_name from public.businesses where id=p_business and owner_id=auth.uid();
 if v_name is null then raise exception 'Business owner authorization required';end if;
 if p_source_type='promo' then
  select left(title,100),created_at into v_title,v_created from public.business_promos
  where id=p_source_id and business_id=p_business and active and starts_at<=now() and ends_at>now();
  v_kind:='promo';
 elsif p_source_type='campaign' then
  select left(name,100),created_at into v_title,v_created from public.campaigns
  where id=p_source_id and business_id=p_business and active;
  v_kind:='business';
 else raise exception 'Unsupported announcement type';end if;
 if v_title is null then raise exception 'Publish and activate this promotion or campaign first';end if;
 if v_created<now()-interval '1 hour' then raise exception 'Only newly published items can notify followers';end if;
 if exists(select 1 from public.bizhunt_follower_broadcasts where source_type=p_source_type and source_id=p_source_id) then
  raise exception 'Followers were already notified about this item';end if;
 if (select count(*) from public.bizhunt_follower_broadcasts where business_id=p_business and created_at>now()-interval '7 days')>=2 then
  raise exception 'Follower notification limit reached (2 per 7 days)';end if;
 select count(*) into v_eligible from public.business_follows f
 left join public.bizhunt_notification_preferences pref on pref.user_id=f.customer_id
 where f.business_id=p_business and coalesce(pref.followed_businesses_enabled,true);
 if v_eligible>500 then raise exception 'Audience exceeds 500. Batched delivery is required before notifying followers';end if;
 insert into public.bizhunt_follower_broadcasts(business_id,source_type,source_id) values(p_business,p_source_type,p_source_id);
 insert into public.bizhunt_notifications(user_id,title,body,kind,target_type,target_id)
 select f.customer_id,
  left(case when p_source_type='promo' then 'New promotion from ' else 'New loyalty campaign from ' end||v_name,120),
  left(v_title||' — Open BizHunt to see the details.',500),
  v_kind,'business',p_business
 from public.business_follows f
 left join public.bizhunt_notification_preferences pref on pref.user_id=f.customer_id
 where f.business_id=p_business and coalesce(pref.followed_businesses_enabled,true);
 get diagnostics v_count=row_count;
 return v_count;
end $fn$;
revoke all on function public.bizhunt_broadcast_to_followers(uuid,text,uuid) from public,anon;
grant execute on function public.bizhunt_broadcast_to_followers(uuid,text,uuid) to authenticated;
commit;
