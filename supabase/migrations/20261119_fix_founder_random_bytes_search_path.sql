-- Fix founder verification failures caused by pgcrypto function search_path.
-- Error: function gen_random_bytes(integer) does not exist
-- Supabase normally installs pgcrypto into the extensions schema.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

do $fix$
declare fn record;
begin
  if to_regprocedure('extensions.gen_random_bytes(integer)') is null
     and to_regprocedure('public.gen_random_bytes(integer)') is null then
    raise exception 'pgcrypto gen_random_bytes(integer) was not found. Check installed extensions.';
  end if;

  -- Preserve founder verification and the existing SECURITY DEFINER functions.
  -- Only expand their function lookup path to include Supabase's extensions schema.
  for fn in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in (
        'bizhunt_founder_curated_challenge',
        'bizhunt_founder_curated_mutate',
        'bizhunt_founder_challenge',
        'bizhunt_founder_mutate'
      )
  loop
    execute format('alter function %s set search_path = public, extensions, pg_temp',fn.signature);
  end loop;
end $fix$;
