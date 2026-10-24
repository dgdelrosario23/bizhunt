-- Phase 12: Followed businesses and merchant photo galleries.
-- Run after Phase 10 in Supabase SQL Editor.
create table if not exists public.business_follows (
 business_id uuid not null references public.businesses(id) on delete cascade,
 customer_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key (business_id,customer_id)
);
alter table public.business_follows enable row level security;
create policy "public follow counts" on public.business_follows for select to authenticated using (true);
create policy "follow own" on public.business_follows for insert to authenticated with check (customer_id=auth.uid());
create policy "unfollow own" on public.business_follows for delete to authenticated using (customer_id=auth.uid());
create index if not exists business_follows_customer_idx on public.business_follows(customer_id);
create table if not exists public.business_gallery (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id) on delete cascade,
 image_path text not null unique,
 caption text not null default '',
 created_at timestamptz not null default now(),
 constraint gallery_caption_length check(length(caption)<=160),
 constraint gallery_path_format check(image_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/gallery/[0-9a-f-]{36}[.](png|jpg|webp)$')
);
alter table public.business_gallery enable row level security;
create policy "public gallery read" on public.business_gallery for select to anon,authenticated using(true);
create policy "owner gallery insert" on public.business_gallery for insert to authenticated with check (
 exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid())
 and split_part(image_path,'/',1)=auth.uid()::text and split_part(image_path,'/',2)=business_id::text
);
create policy "owner gallery delete" on public.business_gallery for delete to authenticated using (
 exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid())
);
create index if not exists business_gallery_business_idx on public.business_gallery(business_id);
create policy "merchant upload gallery media" on storage.objects for insert to authenticated
with check (bucket_id='bizhunt-business-media'
 and (storage.foldername(name))[1]=auth.uid()::text
 and (storage.foldername(name))[3]='gallery'
 and exists(select 1 from public.businesses b where b.owner_id=auth.uid() and b.id::text=(storage.foldername(name))[2])
 and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/gallery/[0-9a-f-]{36}[.](png|jpg|webp)$');
-- Count distinct customers with a verified stamp, independent of campaign or redemption.
create or replace function public.business_member_counts()
returns table(business_id uuid, members bigint)
language sql stable security definer set search_path=public
as $$ select c.business_id,count(distinct s.customer_id)::bigint
 from public.stamp_events s join public.campaigns c on c.id=s.campaign_id
 group by c.business_id $$;
revoke all on function public.business_member_counts() from public;
grant execute on function public.business_member_counts() to authenticated;
