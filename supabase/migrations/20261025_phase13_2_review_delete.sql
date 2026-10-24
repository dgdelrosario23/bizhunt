-- Phase 13.2: authenticated review owner may delete their own review.
-- Run after the Phase 13 and 13.1 migrations.
create or replace function public.delete_own_business_review(p_review uuid)
returns void language plpgsql security definer set search_path = ''
as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 delete from public.business_reviews
 where id = p_review and customer_id = auth.uid();
 if not found then raise exception 'Review not found or not yours'; end if;
end $$;
revoke all on function public.delete_own_business_review(uuid) from public,anon;
grant execute on function public.delete_own_business_review(uuid) to authenticated;
