-- BizHunt Phase S1: narrow table-privilege and report-policy hardening.
-- REVIEW ONLY: GitHub commits do not execute SQL in Supabase.
-- Precondition: live grants/policy match the November 2026 read-only audit.
-- Preserve SELECT/INSERT/UPDATE/DELETE and existing RPC definitions.
begin;

-- RLS does not govern TRUNCATE. TRIGGER/REFERENCES are not needed by
-- normal anon/authenticated application roles. Limit to public base/partitioned tables.
do $$
declare t record;
begin
  for t in
    select c.oid::regclass as relation
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind in ('r','p')
  loop
    execute format('revoke truncate, trigger, references on table %s from anon, authenticated', t.relation);
  end loop;
end $$;

-- A submitted review must belong to the business in the report.
-- Keep the original reporter, pending-status and business-existence checks.
drop policy if exists "Reporters submit reports" on public.content_reports;
create policy "Reporters submit reports"
on public.content_reports
as permissive
for insert to authenticated
with check (
  reporter_id = (select auth.uid())
  and status = 'pending'
  and exists (select 1 from public.businesses b where b.id = business_id)
  and (
    review_id is null
    or exists (
      select 1 from public.business_reviews r
      where r.id = review_id and r.business_id = content_reports.business_id
    )
  )
);
commit;
