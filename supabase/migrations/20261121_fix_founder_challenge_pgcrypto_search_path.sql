-- Fix founder confirmation-code generation in Supabase projects where pgcrypto
-- functions are installed in the extensions schema (outside the RPC search_path).
-- ALTER FUNCTION preserves the existing function bodies, grants and audit workflow.
-- Verify pgcrypto is installed in extensions before running.
begin;
do $$
begin
 if to_regprocedure('extensions.gen_random_bytes(integer)') is null
    and to_regprocedure('public.gen_random_bytes(integer)') is null then
  raise exception 'pgcrypto gen_random_bytes(integer) not found in extensions or public; enable pgcrypto in Supabase Database > Extensions before applying';
 end if;
end $$;
alter function public.bizhunt_founder_curated_challenge(uuid,text)
 set search_path = public, extensions, pg_temp;
alter function public.bizhunt_founder_challenge(text,uuid,text)
 set search_path = public, extensions, pg_temp;
commit;
