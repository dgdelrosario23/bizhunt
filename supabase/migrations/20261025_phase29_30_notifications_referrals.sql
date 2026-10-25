-- Phases 29-30: private notification inbox and referral tracking (no redeemable points).
create table if not exists public.bizhunt_notifications(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 title text not null check(length(title) between 1 and 120),
 body text not null check(length(body)<=500),
 kind text not null default 'update',
 read_at timestamptz,
 created_at timestamptz not null default now()
);
create index if not exists bizhunt_notifications_user_date on public.bizhunt_notifications(user_id,created_at desc);
alter table public.bizhunt_notifications enable row level security;
revoke all on public.bizhunt_notifications from anon,authenticated;
grant select on public.bizhunt_notifications to authenticated;
drop policy if exists "Notification recipient can read" on public.bizhunt_notifications;
create policy "Notification recipient can read" on public.bizhunt_notifications for select to authenticated using(user_id=auth.uid());
drop policy if exists "Notification recipient can mark read" on public.bizhunt_notifications;
create policy "Notification recipient can mark read" on public.bizhunt_notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create or replace function public.bizhunt_mark_notification_read(p_id uuid) returns void language plpgsql security definer set search_path=public as $
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 update public.bizhunt_notifications set read_at=coalesce(read_at,now()) where id=p_id and user_id=auth.uid();
end $;
revoke all on function public.bizhunt_mark_notification_read(uuid) from public,anon;
grant execute on function public.bizhunt_mark_notification_read(uuid) to authenticated;
-- Do not allow client-controlled notification insertion.
create table if not exists public.bizhunt_referral_codes(
 user_id uuid primary key references auth.users(id) on delete cascade,
 code text unique not null check(code ~ '^BH[A-F0-9]{12}$'),
 created_at timestamptz not null default now()
);
create table if not exists public.bizhunt_referrals(
 referred_user_id uuid primary key references auth.users(id) on delete cascade,
 referrer_user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 check(referred_user_id<>referrer_user_id)
);
create index if not exists bizhunt_referrals_referrer on public.bizhunt_referrals(referrer_user_id);
alter table public.bizhunt_referral_codes enable row level security;
alter table public.bizhunt_referrals enable row level security;
revoke all on public.bizhunt_referral_codes,public.bizhunt_referrals from anon,authenticated;
grant select on public.bizhunt_referral_codes,public.bizhunt_referrals to authenticated;
create policy "Read own referral code" on public.bizhunt_referral_codes for select to authenticated using(user_id=auth.uid());
create policy "Read own referral history" on public.bizhunt_referrals for select to authenticated using(referrer_user_id=auth.uid() or referred_user_id=auth.uid());
create or replace function public.bizhunt_my_referral_code() returns text language plpgsql security definer set search_path=public as $$
declare v_code text;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 insert into public.bizhunt_referral_codes(user_id,code)
 values(auth.uid(),'BH'||upper(substr(md5(auth.uid()::text),1,12)))
 on conflict(user_id) do nothing;
 select code into v_code from public.bizhunt_referral_codes where user_id=auth.uid();
 return v_code;
end $$;
create or replace function public.bizhunt_use_referral(p_code text) returns text language plpgsql security definer set search_path=public as $$
declare v_referrer uuid; v_created timestamptz;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select created_at into v_created from auth.users where id=auth.uid();
 if v_created<now()-interval '7 days' then raise exception 'Referral codes are for new accounts only'; end if;
 select user_id into v_referrer from public.bizhunt_referral_codes where code=upper(trim(p_code));
 if v_referrer is null then raise exception 'Referral code not found'; end if;
 if v_referrer=auth.uid() then raise exception 'Cannot refer yourself'; end if;
 insert into public.bizhunt_referrals(referred_user_id,referrer_user_id) values(auth.uid(),v_referrer);
 return 'Referral recorded. No points or rewards are issued.';
exception when unique_violation then raise exception 'Referral already recorded for this account';
end $$;
revoke all on function public.bizhunt_my_referral_code() from public,anon;
revoke all on function public.bizhunt_use_referral(text) from public,anon;
grant execute on function public.bizhunt_my_referral_code() to authenticated;
grant execute on function public.bizhunt_use_referral(text) to authenticated;
