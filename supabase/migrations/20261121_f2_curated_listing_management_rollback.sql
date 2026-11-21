-- F2 rollback: remove new RPCs; restore original public read policy.
-- WARNING: this makes archived rows visible again; review before executing.
begin;
drop function if exists public.bizhunt_founder_curated_archive(uuid,boolean,text);
drop function if exists public.bizhunt_founder_curated_create(text,text,text,text);
drop policy if exists "Anyone reads curated businesses" on public.bizhunt_curated_businesses;
create policy "Anyone reads curated businesses" on public.bizhunt_curated_businesses for select to anon,authenticated using(true);
-- Preserve archived_at data and the extended challenge RPC for audit/history safety.
commit;
