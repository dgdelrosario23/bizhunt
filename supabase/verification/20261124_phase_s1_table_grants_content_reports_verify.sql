-- BizHunt Phase S1: READ ONLY verification after optional deployment.
-- Expected: zero rows for dangerous grants on public tables.
select n.nspname as schema_name,c.relname as table_name,
       r.rolname as role_name, x.privilege_type
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
cross join (values ('anon'),('authenticated')) rname(role_name)
join pg_roles r on r.rolname=rname.role_name
cross join (values ('TRUNCATE'),('TRIGGER'),('REFERENCES')) x(privilege_type)
where n.nspname='public' and c.relkind in ('r','p')
and has_table_privilege(r.oid,c.oid,x.privilege_type)
order by c.relname,r.rolname,x.privilege_type;

-- Expected: INSERT policy includes content_reports.business_id comparison.
select tablename,policyname,cmd,roles,with_check
from pg_policies
where schemaname='public' and tablename='content_reports'
  and policyname='Reporters submit reports';

-- Expected: normal CRUD grants remain unchanged; compare with pre-deploy export.
select table_name,grantee,privilege_type
from information_schema.role_table_grants
where table_schema='public'
  and grantee in ('anon','authenticated')
  and privilege_type in ('SELECT','INSERT','UPDATE','DELETE')
order by table_name,grantee,privilege_type;

-- Follow-up testing must use real JWT roles, not the privileged SQL editor:
-- customer report matching/mismatching business; merchant CRUD; founder flows;
-- community flows; stamp and redemption; and notification updates.
