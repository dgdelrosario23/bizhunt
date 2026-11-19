-- BizHunt: Founder-managed photos and operating hours for curated community listings.
-- Run in Supabase SQL Editor before using the new Founder photo editor.
alter table public.bizhunt_curated_businesses
  add column if not exists logo_path text,
  add column if not exists cover_path text,
  add column if not exists gallery_paths text[] not null default '{}',
  add column if not exists opening_hours text,
  add column if not exists weekly_hours jsonb not null default '{}'::jsonb,
  add column if not exists timezone text not null default 'Asia/Manila',
  add column if not exists phone text,
  add column if not exists website text,
  add column if not exists instagram text;

create table if not exists public.bizhunt_curated_media_audit (
 id bigint generated always as identity primary key,
 listing_id text not null,
 actor_id uuid not null,
 before_data jsonb not null,
 after_data jsonb not null,
 created_at timestamptz not null default now()
);
alter table public.bizhunt_curated_media_audit enable row level security;
revoke all on public.bizhunt_curated_media_audit from anon, authenticated;

create or replace function public.bizhunt_founder_curated_media_save(
 p_id text, p_logo_path text, p_cover_path text, p_gallery_paths text[],
 p_opening_hours text, p_weekly_hours jsonb, p_phone text, p_website text, p_instagram text
) returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare old_record public.bizhunt_curated_businesses%rowtype;
declare new_record public.bizhunt_curated_businesses%rowtype;
declare media_path text;
begin
 if auth.uid() is null or not exists (select 1 from public.bizhunt_admins where user_id=auth.uid()) then
  raise exception 'Founder access required';
 end if;
 select * into old_record from public.bizhunt_curated_businesses where id::text=p_id for update;
 if not found then raise exception 'Listing not found'; end if;
 if cardinality(coalesce(p_gallery_paths,array[]::text[]))>8 then raise exception 'Maximum eight gallery photos'; end if;
 foreach media_path in array (array[coalesce(p_logo_path,''),coalesce(p_cover_path,'')] || coalesce(p_gallery_paths,array[]::text[])) loop
  if media_path<>'' and (length(media_path)>350 or media_path not like 'founder-curated/'||p_id||'/%' or media_path !~ '\.(jpg|jpeg|png|webp)$') then
   raise exception 'Invalid photo path';
  end if;
 end loop;
 if p_weekly_hours is null or jsonb_typeof(p_weekly_hours)<>'object' then raise exception 'Invalid weekly hours'; end if;
 if length(coalesce(p_opening_hours,''))>160 or length(coalesce(p_phone,''))>40 or length(coalesce(p_website,''))>300 or length(coalesce(p_instagram,''))>100 then
  raise exception 'Field too long';
 end if;
 update public.bizhunt_curated_businesses
 set logo_path=nullif(p_logo_path,''),cover_path=nullif(p_cover_path,''),
 gallery_paths=coalesce(p_gallery_paths,array[]::text[]),
 opening_hours=nullif(trim(p_opening_hours),''),
 weekly_hours=p_weekly_hours,phone=nullif(trim(p_phone),''),
 website=nullif(trim(p_website),''),instagram=nullif(trim(p_instagram),'')
 where id::text=p_id returning * into new_record;
 insert into public.bizhunt_curated_media_audit(listing_id,actor_id,before_data,after_data)
 values(p_id,auth.uid(),to_jsonb(old_record),to_jsonb(new_record));
end $$;
revoke all on function public.bizhunt_founder_curated_media_save(text,text,text,text[],text,jsonb,text,text,text) from public, anon;
grant execute on function public.bizhunt_founder_curated_media_save(text,text,text,text[],text,jsonb,text,text,text) to authenticated;

-- Existing public bucket is used by the app; uploads are restricted to founders and a curated prefix.
drop policy if exists "founder curated photo uploads" on storage.objects;
create policy "founder curated photo uploads" on storage.objects for insert to authenticated
with check (bucket_id='bizhunt-business-media' and name like 'founder-curated/%'
 and exists (select 1 from public.bizhunt_admins where user_id=auth.uid()));
