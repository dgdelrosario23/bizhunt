-- F1 rollback: removes ONLY the additive overview v2 function.
begin;
drop function if exists public.bizhunt_founder_overview_v2(integer);
commit;
