-- Read-only checks after applying the migration in the intended environment.
select relrowsecurity as rls_enabled from pg_class
where oid='public.bizhunt_vip_inquiries'::regclass;
select role_name, has_table_privilege(role_name,'public.bizhunt_vip_inquiries','SELECT') as can_read,
has_table_privilege(role_name,'public.bizhunt_vip_inquiries','INSERT') as can_insert,
has_table_privilege(role_name,'public.bizhunt_vip_inquiries','UPDATE') as can_update
from (values ('anon'),('authenticated')) r(role_name);
select
  has_function_privilege('anon','public.bizhunt_submit_vip_inquiry(text,text,text,text,boolean)','EXECUTE') as anonymous_intake,
  has_function_privilege('anon','public.bizhunt_founder_vip_inquiries(integer)','EXECUTE') as anonymous_read,
  has_function_privilege('anon','public.bizhunt_founder_vip_inquiry_status(uuid,text)','EXECUTE') as anonymous_update;
