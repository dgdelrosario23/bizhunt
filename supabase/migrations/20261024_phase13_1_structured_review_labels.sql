-- Phase 13.1: Structured review labels, separate from the review narrative.
-- Apply after 20261024_phase13_verified_reviews.sql.
alter table public.business_reviews
 add column if not exists highlights text[] not null default '{}'::text[],
 add column if not exists visit_type text;
alter table public.business_reviews
 add constraint business_reviews_highlights_allowed check (
  highlights <@ array['Great service','Good value','Friendly staff','Clean place','Nice atmosphere','Long wait']::text[]
  and cardinality(highlights)<=6
 ),
 add constraint business_reviews_visit_type_allowed check (
  visit_type is null or visit_type in ('Breakfast','Lunch','Dinner','Coffee','Other')
 );
create or replace function public.save_business_review(
 p_business uuid,p_rating integer,p_text text,p_highlights text[],p_visit_type text
) returns void language plpgsql security definer set search_path = ''
as $$
declare
 v_highlights text[] := coalesce(p_highlights,'{}'::text[]);
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if p_rating not between 1 and 5 or char_length(coalesce(p_text,''))>1500 then
  raise exception 'Invalid review'; end if;
 if cardinality(v_highlights)>6 or not(v_highlights <@ array['Great service','Good value','Friendly staff','Clean place','Nice atmosphere','Long wait']::text[]) then
  raise exception 'Invalid review highlights'; end if;
 if p_visit_type is not null and p_visit_type not in ('Breakfast','Lunch','Dinner','Coffee','Other') then
  raise exception 'Invalid visit type'; end if;
 if not public.has_verified_business_stamp(p_business,auth.uid()) then
  raise exception 'At least one verified stamp is required'; end if;
 insert into public.business_reviews(business_id,customer_id,rating,review_text,highlights,visit_type)
 values(p_business,auth.uid(),p_rating,coalesce(p_text,''),v_highlights,p_visit_type)
 on conflict(business_id,customer_id) do update
 set rating=excluded.rating,review_text=excluded.review_text,
     highlights=excluded.highlights,visit_type=excluded.visit_type,updated_at=now();
end $$;
revoke all on function public.save_business_review(uuid,integer,text,text[],text) from public,anon;
grant execute on function public.save_business_review(uuid,integer,text,text[],text) to authenticated;
