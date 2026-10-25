-- Phase 25: founder-only community claim review.
create or replace function public.founder_community_claims()
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from public.bizhunt_admins where user_id=auth.uid()) then raise exception 'Founder access required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(c) order by c.created_at desc) from public.community_listing_claims c), '[]'::jsonb);
end $$;
create or replace function public.founder_review_community_claim(p_claim_id uuid,p_action text)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from public.bizhunt_admins where user_id=auth.uid()) then raise exception 'Founder access required'; end if;
 if p_action not in ('approved','rejected') then raise exception 'Invalid action'; end if;
 update public.community_listing_claims set status=p_action,reviewed_at=now() where id=p_claim_id and status='pending';
 if not found then raise exception 'Claim not found or already reviewed'; end if;
 -- Approval records verification decision only. Actual merchant profile creation and
 -- owner transfer must be done separately after identity and authority checks.
end $$;
revoke all on function public.founder_community_claims() from public,anon;
revoke all on function public.founder_review_community_claim(uuid,text) from public,anon;
grant execute on function public.founder_community_claims() to authenticated;
grant execute on function public.founder_review_community_claim(uuid,text) to authenticated;
