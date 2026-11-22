-- Phase N5: low-noise community reply notifications.
-- Apply manually AFTER Phase 29 and N3 structured targets.
-- Does not depend on Phase N4 loyalty triggers.
-- Only notify a post's author of replies by other active members.
begin;
create unique index if not exists bizhunt_notifications_n5_comment_once
  on public.bizhunt_notifications (target_id, user_id, kind, created_at)
  where false; -- reserved no-op; actual event dedup is tracked below
create table if not exists public.bizhunt_community_notification_events (
  comment_id uuid primary key references public.bizhunt_community_comments(id) on delete cascade,
  notification_id uuid unique references public.bizhunt_notifications(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.bizhunt_community_notification_events enable row level security;
revoke all on public.bizhunt_community_notification_events from public,anon,authenticated;

create or replace function public.bizhunt_notify_community_reply()
returns trigger language plpgsql security definer set search_path=''
as $fn$
declare v_author uuid; v_community uuid; v_name text; v_notification uuid;
begin
  select p.author_id,p.community_id into v_author,v_community
    from public.bizhunt_community_posts p where p.id=new.post_id;
  if v_author is null or v_author=new.author_id then return new; end if;
  -- Re-check active membership at delivery time. Private communities stay private.
  if not exists (select 1 from public.bizhunt_community_members m
                 where m.community_id=v_community and m.user_id=v_author and m.status='active')
     or not exists (select 1 from public.bizhunt_community_members m
                    where m.community_id=v_community and m.user_id=new.author_id and m.status='active')
  then return new; end if;
  -- Limit reply notifications per recipient per community to 5 per rolling day.
  if (select count(*) from public.bizhunt_notifications n
      where n.user_id=v_author and n.kind='community_reply'
        and n.target_type='community' and n.target_id=v_community
        and n.created_at>now()-interval '24 hours')>=5
  then return new; end if;
  select left(c.name,90) into v_name from public.bizhunt_communities c where c.id=v_community;
  insert into public.bizhunt_community_notification_events(comment_id)
  values(new.id) on conflict do nothing;
  if not found then return new; end if;
  insert into public.bizhunt_notifications(user_id,title,body,kind,target_type,target_id)
  values(v_author,'New reply to your post',
    left('Someone replied to your post in '||coalesce(v_name,'your community')||'.',500),
    'community_reply','community',v_community)
  returning id into v_notification;
  update public.bizhunt_community_notification_events
    set notification_id=v_notification where comment_id=new.id;
  return new;
end;
$fn$;
revoke all on function public.bizhunt_notify_community_reply() from public,anon,authenticated;
drop trigger if exists bizhunt_notify_community_reply_insert on public.bizhunt_community_comments;
create trigger bizhunt_notify_community_reply_insert
after insert on public.bizhunt_community_comments
for each row execute function public.bizhunt_notify_community_reply();
commit;
