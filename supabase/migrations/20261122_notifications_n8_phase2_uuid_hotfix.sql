-- N8 Phase 2 hotfix: repair UUID cursor aggregation in the deployed worker.
-- Does not modify queued jobs or already-delivered notifications.
do $$
declare v_definition text;
begin
 select pg_get_functiondef(p.oid) into v_definition
 from pg_proc p
 join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='bizhunt_process_follower_jobs'
   and pg_get_function_identity_arguments(p.oid)='p_max_jobs integer, p_batch_size integer';
 if v_definition is null then
   raise exception 'Worker function not found; no changes made';
 end if;
 if position('select max(user_id),count(*) into v_last,v_rows from delivered;' in v_definition)=0 then
   raise exception 'Expected worker code not found; no changes made';
 end if;
 v_definition:=replace(v_definition,
  'select max(user_id),count(*) into v_last,v_rows from delivered;',
  'select (array_agg(user_id order by user_id desc))[1],count(*) into v_last,v_rows from delivered;');
 execute v_definition;
end $$;
