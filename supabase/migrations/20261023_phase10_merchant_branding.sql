-- Phase 10: Merchant branding, profiles, and public media. Run once in Supabase SQL Editor.
alter table public.businesses add column if not exists logo_path text;
alter table public.businesses add column if not exists cover_path text;
alter table public.businesses add column if not exists phone text not null default '';
alter table public.businesses add column if not exists opening_hours text not null default '';
alter table public.businesses add column if not exists website text not null default '';
alter table public.businesses add column if not exists instagram text not null default '';
alter table public.businesses add column if not exists brand_color text not null default '#7042dc';
alter table public.campaigns add column if not exists card_color text not null default '#7042dc';
alter table public.businesses add constraint businesses_brand_color_format check (brand_color ~ '^#[0-9a-fA-F]{6}$');
alter table public.campaigns add constraint campaigns_card_color_format check (card_color ~ '^#[0-9a-fA-F]{6}$');
alter table public.businesses add constraint businesses_profile_lengths check (
 length(phone)<=40 and length(opening_hours)<=180 and length(website)<=240 and length(instagram)<=100
);
alter table public.businesses add constraint businesses_media_paths check (
 (logo_path is null or logo_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/logo/[0-9a-f-]{36}\\.(png|jpg|webp)$')
 and (cover_path is null or cover_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/cover/[0-9a-f-]{36}\\.(png|jpg|webp)$')
);
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('bizhunt-business-media','bizhunt-business-media',true,3145728,array['image/png','image/jpeg','image/webp'])
on conflict (id) do update set public=true,file_size_limit=3145728,allowed_mime_types=array['image/png','image/jpeg','image/webp'];
create policy "merchant upload business media" on storage.objects for insert to authenticated
with check (bucket_id='bizhunt-business-media'
 and (storage.foldername(name))[1]=auth.uid()::text
 and exists (select 1 from public.businesses b where b.owner_id=auth.uid() and b.id::text=(storage.foldername(name))[2])
 and (storage.foldername(name))[3] in ('logo','cover')
 and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/(logo|cover)/[0-9a-f-]{36}\\.(png|jpg|webp)$');
-- Public bucket permits public image downloads, but not anonymous uploads.
-- Deliberately no UPDATE/DELETE storage policy: uploaded files are immutable.
-- Unreferenced images can be cleaned by an administrator after the pilot.
