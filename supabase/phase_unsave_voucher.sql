-- BizHunt: allow customers to unsave their own unredeemed promo vouchers.
-- Run this migration in the Supabase SQL editor before using the Unsave button.
create or replace function public.unsave_business_promo(p_voucher_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  delete from public.promo_vouchers
  where id = p_voucher_id
    and customer_id = auth.uid()
    and redeemed_at is null;

  if not found then
    raise exception 'Voucher not found, already redeemed, or not owned by this account';
  end if;
end;
$$;

revoke all on function public.unsave_business_promo(uuid) from public;
revoke all on function public.unsave_business_promo(uuid) from anon;
grant execute on function public.unsave_business_promo(uuid) to authenticated;
