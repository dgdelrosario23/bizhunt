-- Phase N5 rollback: disable new reply alerts without deleting existing inbox messages.
begin;
drop trigger if exists bizhunt_notify_community_reply_insert on public.bizhunt_community_comments;
drop function if exists public.bizhunt_notify_community_reply();
drop table if exists public.bizhunt_community_notification_events;
commit;
