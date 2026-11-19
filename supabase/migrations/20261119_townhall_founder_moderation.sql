-- BizHunt Town Hall: founder-only status and official responses.
-- Run after 20261119_townhall_phase1_status.sql and founder admin setup.
alter table public.townhall_posts add column if not exists official_response text;
alter table public.townhall_posts add column if not exists status_updated_at timestamptz;
create table if not exists public.townhall_status_history (
 id bigint generated always as identity primary key,
 post_id uuid not null references public.townhall_posts(id) on delete cascade,
 actor_id uuid not null references auth.users(id),
 old_status text not null,
 new_status text not null,
 official_response text,
 created_at timestamptz not null default now()
);
create index if not exists townhall_history_post_idx on public.townhall_status_history(post_id,created_at desc);
alter table public.townhall_status_history enable row level security;
drop policy if exists "townhall history read" on public.townhall_status_history;
create policy "townhall history read" on public.townhall_status_history for select to authenticated using(true);
revoke insert,update,delete on public.townhall_status_history from anon,authenticated;
-- Remove direct updates even if a future policy is accidentally permissive.
revoke update on public.townhall_posts from anon,authenticated;
create or replace function public.bizhunt_townhall_manage(
 p_post_id uuid,p_status text,p_response text default null
) returns void language plpgsql security definer set search_path=public as $$
declare old_post public.townhall_posts%rowtype;
begin
 if auth.uid() is null or not exists(select 1 from public.bizhunt_admins where user_id=auth.uid()) then
  raise exception 'Founder access required';
 end if;
 if p_status not in ('Submitted','Under Review','Planned','In Progress','Completed','Declined') then
  raise exception 'Invalid status';
 end if;
 if p_response is not null and char_length(p_response)>2000 then
  raise exception 'Official response must be at most 2000 characters';
 end if;
 select * into old_post from public.townhall_posts where id=p_post_id for update;
 if not found then raise exception 'Suggestion not found'; end if;
 if old_post.status is distinct from p_status or old_post.official_response is distinct from nullif(btrim(p_response),'') then
  update public.townhall_posts set status=p_status,official_response=nullif(btrim(p_response),''),
   status_updated_at=now() where id=p_post_id;
  insert into public.townhall_status_history(post_id,actor_id,old_status,new_status,official_response)
  values(p_post_id,auth.uid(),old_post.status,p_status,nullif(btrim(p_response),''));
 end if;
end $$;
revoke all on function public.bizhunt_townhall_manage(uuid,text,text) from public;
grant execute on function public.bizhunt_townhall_manage(uuid,text,text) to authenticated;
