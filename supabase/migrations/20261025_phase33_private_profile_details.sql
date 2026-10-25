-- Phase 33: private optional customer profile fields and private profile photos
create table if not exists public.bizhunt_user_details(
 user_id uuid primary key references auth.users(id) on delete cascade,
 gender text check(gender in ('woman','man','nonbinary','self_describe','prefer_not_to_say') or gender is null),
 gender_custom text check(length(gender_custom)<=80),
 birthday date check(birthday<=current_date or birthday is null),
 mobile_number text check(mobile_number ~ '^\\+?[0-9 ()-]{7,25}$' or mobile_number is null),
 city text check(length(city)<=100),
 interests text check(length(interests)<=240),
 avatar_path text check(length(avatar_path)<=300),
 updated_at timestamptz not null default now()
);
alter table public.bizhunt_user_details enable row level security;
revoke all on public.bizhunt_user_details from anon,authenticated;
grant select,insert,update,delete on public.bizhunt_user_details to authenticated;
drop policy if exists "Own profile details read" on public.bizhunt_user_details;
create policy "Own profile details read" on public.bizhunt_user_details for select to authenticated using(user_id=auth.uid());
drop policy if exists "Own profile details insert" on public.bizhunt_user_details;
create policy "Own profile details insert" on public.bizhunt_user_details for insert to authenticated with check(user_id=auth.uid());
drop policy if exists "Own profile details update" on public.bizhunt_user_details;
create policy "Own profile details update" on public.bizhunt_user_details for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists "Own profile details delete" on public.bizhunt_user_details;
create policy "Own profile details delete" on public.bizhunt_user_details for delete to authenticated using(user_id=auth.uid());
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('bizhunt-avatars','bizhunt-avatars',false,2097152,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=2097152,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists "Avatar owner upload" on storage.objects;
create policy "Avatar owner upload" on storage.objects for insert to authenticated
with check(bucket_id='bizhunt-avatars' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "Avatar owner read" on storage.objects;
create policy "Avatar owner read" on storage.objects for select to authenticated
using(bucket_id='bizhunt-avatars' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "Avatar owner update" on storage.objects;
create policy "Avatar owner update" on storage.objects for update to authenticated
using(bucket_id='bizhunt-avatars' and (storage.foldername(name))[1]=auth.uid()::text)
with check(bucket_id='bizhunt-avatars' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "Avatar owner delete" on storage.objects;
create policy "Avatar owner delete" on storage.objects for delete to authenticated
using(bucket_id='bizhunt-avatars' and (storage.foldername(name))[1]=auth.uid()::text);
