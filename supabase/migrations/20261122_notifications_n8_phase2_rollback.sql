-- Stop scheduler before rollback. Preserve already-delivered notifications.
begin;
revoke all on function public.bizhunt_process_follower_jobs(integer,integer) from public,anon,authenticated;
drop function if exists public.bizhunt_process_follower_jobs(integer,integer);
drop function if exists public.bizhunt_queue_follower_announcement(uuid,text,uuid);
drop table if exists public.bizhunt_follower_delivery_jobs;
alter table public.bizhunt_notifications drop constraint if exists bh_notifications_announcement_pair;
alter table public.bizhunt_notifications drop column if exists announcement_type;
alter table public.bizhunt_notifications drop column if exists announcement_id;
commit;
