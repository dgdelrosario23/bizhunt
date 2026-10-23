-- BizHunt founder analytics: run in Supabase SQL Editor after previous migrations.
-- Set your founder UUID below, then run this file. Never put the service-role key in the browser.
create table if not exists public.founder_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.founder_admins enable row level security;
revoke all on public.founder_admins from anon, authenticated;
-- IMPORTANT: Replace the UUID with your own auth.users.id before running:
-- insert into public.founder_admins(user_id) values ('YOUR-FOUNDER-USER-UUID') on conflict do nothing;

create or replace function public.founder_dashboard()
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare result jsonb;
begin
  if auth.uid() is null or not exists (
    select 1 from public.founder_admins a where a.user_id = auth.uid()
  ) then
    raise exception 'Founder access only' using errcode='42501';
  end if;
  select jsonb_build_object(
    'users', (select count(*) from auth.users),
    'businesses', (select count(*) from public.businesses),
    'stamps', (select count(*) from public.stamp_events),
    'redemptions', (select count(*) from public.reward_redemptions),
    'active_campaigns', (select count(*) from public.campaigns where active),
    'unique_customers', (select count(distinct customer_id) from public.stamp_events),
    'repeat_customers', (select count(*) from (
      select customer_id from public.stamp_events group by customer_id having count(*) >= 2
    ) q),
    'cities', (select count(distinct lower(trim(split_part(location, ',', 1))))
      from public.businesses where trim(split_part(location, ',', 1)) <> ''),
    'monthly', (select coalesce(jsonb_agg(jsonb_build_object(
      'month', to_char(m.month,'YYYY-MM'),
      'users', (select count(*) from auth.users u where u.created_at >= m.month and u.created_at < m.month + interval '1 month'),
      'businesses', (select count(*) from public.businesses b where b.created_at >= m.month and b.created_at < m.month + interval '1 month'),
      'stamps', (select count(*) from public.stamp_events s where s.created_at >= m.month and s.created_at < m.month + interval '1 month'),
      'redemptions', (select count(*) from public.reward_redemptions r where r.created_at >= m.month and r.created_at < m.month + interval '1 month')
    ) order by m.month), '[]'::jsonb) from generate_series(
      date_trunc('month', now()) - interval '5 months',
      date_trunc('month', now()), interval '1 month') as m(month)),
    'top_businesses', (select coalesce(jsonb_agg(row_data order by (row_data->>'stamps')::bigint desc),'[]'::jsonb)
      from (select jsonb_build_object('name',b.name,'location',b.location,
        'stamps',(select count(*) from public.stamp_events s join public.campaigns c on c.id=s.campaign_id where c.business_id=b.id),
        'redemptions',(select count(*) from public.reward_redemptions r join public.campaigns c on c.id=r.campaign_id where c.business_id=b.id)
      ) as row_data from public.businesses b order by
        (select count(*) from public.stamp_events s join public.campaigns c on c.id=s.campaign_id where c.business_id=b.id) desc
      limit 5) top)
  ) into result;
  return result;
end $$;
revoke all on function public.founder_dashboard() from public, anon, authenticated;
grant execute on function public.founder_dashboard() to authenticated;
