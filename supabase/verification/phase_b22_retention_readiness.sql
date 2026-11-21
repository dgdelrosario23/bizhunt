-- Phase B22: read-only deployment diagnostics for historical retention RPC
-- Run in Supabase SQL Editor to inspect the deployed schema before applying the migration.
-- SQL Editor runs privileged: this does NOT verify end-user JWT permissions.

select to_regclass('public.businesses') as businesses,
       to_regclass('public.campaigns') as campaigns,
       to_regclass('public.stamp_events') as stamp_events,
       to_regclass('public.reward_redemptions') as reward_redemptions;

select table_name,column_name,data_type
from information_schema.columns
where table_schema='public'
  and table_name in ('businesses','campaigns','stamp_events','reward_redemptions')
  and column_name in ('id','owner_id','business_id','campaign_id','customer_id')
order by table_name,column_name;

select p.oid::regprocedure::text as function_signature,
       pg_get_userbyid(p.proowner) as function_owner,
       p.prosecdef as security_definer,
       p.proconfig as function_settings,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='merchant_customer_retention_metrics';

select tablename,indexname,indexdef
from pg_indexes
where schemaname='public' and tablename in ('campaigns','stamp_events','reward_redemptions')
order by tablename,indexname;
