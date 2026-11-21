-- Rollback for Phase B16, only if no other deployment depends on the RPC.
begin;
drop function if exists public.merchant_customer_retention_metrics(uuid);
commit;
