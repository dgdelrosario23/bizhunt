-- Read only. First query must return zero rows.
select c.relname as table_name,r.rolname as role_name,p.priv as privilege from pg_class c join pg_namespace n on n.oid=c.relnamespace
cross join pg_roles r
cross join (values ('REFERENCES'),('TRIGGER'),('TRUNCATE')) p(priv)
where n.nspname='public' and c.relkind in ('r','p')
and r.rolname in ('anon','authenticated')
and has_table_privilege(r.oid,c.oid,p.priv);
-- Inspect both report policies; INSERT must compare r.business_id with content_reports.business_id.
select policyname,permissive,roles,cmd,qual,with_check from pg_policies
where schemaname='public' and tablename='content_reports' order by policyname;
-- Compare CRUD with predeployment snapshot.
select table_name,grantee,privilege_type from information_schema.role_table_grants
where table_schema='public' and grantee in ('anon','authenticated') and privilege_type in ('SELECT','INSERT','UPDATE','DELETE')
order by table_name,grantee,privilege_type;
-- Test matching/mismatching review reports using authenticated JWT in staging.
