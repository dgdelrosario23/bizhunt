-- Phase N8 rollback. Stops new broadcasts and removes only N8 structures.
begin;
revoke all on function public.bizhunt_broadcast_to_followers(uuid,text,uuid) from public,anon,authenticated;
drop function if exists public.bizhunt_broadcast_to_followers(uuid,text,uuid);
drop table if exists public.bizhunt_follower_broadcasts;
alter table public.bizhunt_notification_preferences drop column if exists followed_businesses_enabled;
commit;
