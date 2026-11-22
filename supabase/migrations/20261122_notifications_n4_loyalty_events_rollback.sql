-- Phase N4 rollback: stops future loyalty notifications; leaves existing inbox entries.
begin;
drop trigger if exists bizhunt_notify_stamp_insert on public.stamp_events;
drop trigger if exists bizhunt_notify_redemption_insert on public.reward_redemptions;
drop function if exists public.bizhunt_notify_loyalty_event();
drop index if exists public.bizhunt_notifications_source_unique;
alter table public.bizhunt_notifications drop constraint if exists bizhunt_notifications_source_pair;
alter table public.bizhunt_notifications drop column if exists source_event_id;
alter table public.bizhunt_notifications drop column if exists source_event_type;
commit;
