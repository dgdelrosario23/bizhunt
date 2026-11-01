-- BizHunt: secure owner-only image uploads for business logos, covers and galleries.
-- Apply in Supabase SQL Editor. Does not disable RLS or grant public uploads.
-- Existing policies remain; PostgreSQL combines permissive policies with OR.
-- First inspect existing policies, including restrictive ones.
select policyname,cmd,permissive,roles,qual,with_check
from pg_policies
where schemaname='storage' and tablename='objects'
  and (coalesce(qual,'') ilike '%bizhunt-business-media%' or coalesce(with_check,'') ilike '%bizhunt-business-media%');

do $$
begin
 if not exists (select 1 from storage.buckets where id='bizhunt-business-media') then
   raise exception 'Missing storage bucket bizhunt-business-media. Check bucket setup.';
 end if;
end $$;

drop policy if exists "BizHunt owners insert business media" on storage.objects;
create policy "BizHunt owners insert business media"
on storage.objects for insert to authenticated
with check (
 bucket_id='bizhunt-business-media'
 and (storage.foldername(name))[1]=(select auth.uid())::text
 and (storage.foldername(name))[3] in ('logo','cover','gallery')
 and exists (
   select 1 from public.businesses b
   where b.id::text=(storage.foldername(name))[2]
     and b.owner_id=(select auth.uid())
 )
);

drop policy if exists "BizHunt owners delete business media" on storage.objects;
create policy "BizHunt owners delete business media"
on storage.objects for delete to authenticated
using (
 bucket_id='bizhunt-business-media'
 and (storage.foldername(name))[1]=(select auth.uid())::text
 and (storage.foldername(name))[3] in ('logo','cover','gallery')
 and exists (
   select 1 from public.businesses b
   where b.id::text=(storage.foldername(name))[2]
     and b.owner_id=(select auth.uid())
 )
);
-- If uploads still fail, inspect restrictive policies and verify businesses.owner_id.
