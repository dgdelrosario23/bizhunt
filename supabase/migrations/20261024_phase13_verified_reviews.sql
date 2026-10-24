-- Phase 13: Verified customer reviews and merchant responses.
-- Run in Supabase SQL Editor after Phases 4, 10, and 12.
-- Eligibility uses the server-authorized stamp ledger; followers alone cannot review.
create or replace function public.has_verified_business_stamp(p_business uuid, p_customer uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
 select exists (
  select 1 from public.stamp_events s
  join public.campaigns c on c.id=s.campaign_id
  where c.business_id=p_business and s.customer_id=p_customer
 );
$$;
revoke all on function public.has_verified_business_stamp(uuid,uuid) from public,anon;
grant execute on function public.has_verified_business_stamp(uuid,uuid) to authenticated;

create table if not exists public.business_reviews (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id) on delete cascade,
 customer_id uuid not null references auth.users(id) on delete cascade,
 rating smallint not null check (rating between 1 and 5),
 review_text text not null default '' check (char_length(review_text)<=1500),
 merchant_reply text check (merchant_reply is null or char_length(merchant_reply)<=1200),
 merchant_replied_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique (business_id,customer_id)
);
create index if not exists business_reviews_business_idx on public.business_reviews(business_id,created_at desc);
alter table public.business_reviews enable row level security;
create policy "read public verified reviews" on public.business_reviews
 for select to anon,authenticated using (true);
create policy "verified customers create review" on public.business_reviews
 for insert to authenticated
 with check (customer_id=auth.uid() and public.has_verified_business_stamp(business_id,auth.uid())
 and merchant_reply is null and merchant_replied_at is null);
-- Avoid direct UPDATE: a customer must not alter the merchant reply and a merchant
-- must not change the customer's rating or review. Use narrowly scoped RPCs.
revoke insert,update,delete on public.business_reviews from anon,authenticated;
grant insert on public.business_reviews to authenticated;

create or replace function public.edit_own_business_review(
 p_business uuid,p_rating integer,p_text text
) returns void language plpgsql security definer set search_path = ''
as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if p_rating not between 1 and 5 or char_length(coalesce(p_text,''))>1500 then
  raise exception 'Invalid review'; end if;
 if not public.has_verified_business_stamp(p_business,auth.uid()) then
  raise exception 'At least one verified stamp is required'; end if;
 update public.business_reviews set rating=p_rating,review_text=coalesce(p_text,''),
 updated_at=now()
 where business_id=p_business and customer_id=auth.uid();
 if not found then raise exception 'Review not found'; end if;
end $$;
revoke all on function public.edit_own_business_review(uuid,integer,text) from public,anon;
grant execute on function public.edit_own_business_review(uuid,integer,text) to authenticated;

create or replace function public.reply_to_business_review(p_review uuid,p_reply text)
returns void language plpgsql security definer set search_path = ''
as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if char_length(coalesce(p_reply,''))>1200 or btrim(coalesce(p_reply,''))='' then
  raise exception 'Reply must be 1–1200 characters'; end if;
 update public.business_reviews r
 set merchant_reply=btrim(p_reply),merchant_replied_at=now()
 where r.id=p_review and exists (
  select 1 from public.businesses b
  where b.id=r.business_id and b.owner_id=auth.uid()
 );
 if not found then raise exception 'Review not found or not your business'; end if;
end $$;
revoke all on function public.reply_to_business_review(uuid,text) from public,anon;
grant execute on function public.reply_to_business_review(uuid,text) to authenticated;
-- Review moderation and abuse-reporting workflows should be added before public rollout.
