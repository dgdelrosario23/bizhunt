-- Phase 40: Official business menu files (run once in Supabase SQL Editor).
create table if not exists public.business_menu_files (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id) on delete cascade,
 file_path text not null unique,
 file_type text not null check (file_type in ('image/jpeg','image/png','image/webp','application/pdf')),
 title text not null default 'Menu',
 sort_order integer not null default 0,
 created_at timestamptz not null default now()
);
create index if not exists business_menu_files_business_idx on public.business_menu_files(business_id,sort_order,created_at);
alter table public.business_menu_files enable row level security;
create policy "Anyone can read official menus" on public.business_menu_files for select using (true);
create policy "Owners can add official menus" on public.business_menu_files for insert to authenticated with check (
 exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=(select auth.uid()))
 and file_path like (select auth.uid())::text || '/' || business_id::text || '/menu/%'
);
create policy "Owners can edit official menus" on public.business_menu_files for update to authenticated using (
 exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=(select auth.uid()))
) with check (
 exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=(select auth.uid()))
 and file_path like (select auth.uid())::text || '/' || business_id::text || '/menu/%'
);
create policy "Owners can delete official menus" on public.business_menu_files for delete to authenticated using (
 exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=(select auth.uid()))
);
-- Dedicated public bucket; uploads are still restricted to actual business owners.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('bizhunt-business-menus','bizhunt-business-menus',true,10485760,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do update set public=true,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;
create policy "Business owners upload menu files" on storage.objects for insert to authenticated with check (
 bucket_id='bizhunt-business-menus'
 and exists (
  select 1 from public.businesses b
  where b.id=(split_part(name,'/',2))::uuid
    and b.owner_id=(select auth.uid())
    and split_part(name,'/',1)=(select auth.uid())::text
    and split_part(name,'/',3)='menu'
 )
);
create policy "Business owners remove menu files" on storage.objects for delete to authenticated using (
 bucket_id='bizhunt-business-menus'
 and exists (
  select 1 from public.businesses b
  where b.id=(split_part(name,'/',2))::uuid
    and b.owner_id=(select auth.uid())
    and split_part(name,'/',1)=(select auth.uid())::text
    and split_part(name,'/',3)='menu'
 )
);
notify pgrst, 'reload schema';
