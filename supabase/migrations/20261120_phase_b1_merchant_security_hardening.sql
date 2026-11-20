-- Phase B1: targeted merchant security hardening. REVIEW before applying manually.
-- No application changes. Execute in Supabase SQL Editor only after staging validation.
-- Assumptions: current owner should read all history for their business;
-- previous issuers should not retain merchant-only access after ownership transfer.
BEGIN;

-- Remove PUBLIC's inherited EXECUTE grants; retain authenticated clients.
-- PUBLIC includes anon AND authenticated, so explicitly regrant authenticated.
REVOKE EXECUTE ON FUNCTION public.claim_business_promo(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.redeem_business_promo(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_promo_impression(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.merchant_promo_metrics(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_business_engagement(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.merchant_engagement_metrics(uuid,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_business_promo(uuid),
 public.redeem_business_promo(uuid), public.record_promo_impression(uuid),
 public.merchant_promo_metrics(uuid), public.record_business_engagement(uuid,text),
 public.merchant_engagement_metrics(uuid,integer) TO authenticated;

-- Existing verified-review INSERT policy and review RPCs call this helper with
-- auth.uid(). Restrict arbitrary customer probing without changing its signature.
CREATE OR REPLACE FUNCTION public.has_verified_business_stamp(p_business uuid,p_customer uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
 SELECT p_customer IS NOT NULL AND p_customer = auth.uid() AND EXISTS (
   SELECT 1 FROM public.stamp_events s
   JOIN public.campaigns c ON c.id=s.campaign_id
   WHERE c.business_id=p_business AND s.customer_id=p_customer
 );
$$;
-- Retain authenticated EXECUTE: the review INSERT RLS policy calls this helper.
REVOKE EXECUTE ON FUNCTION public.has_verified_business_stamp(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_verified_business_stamp(uuid,uuid) TO authenticated;

-- Preserve customer access; replace merchant_id-based access with current
-- business ownership. This is a deliberate ownership-transfer semantics change.
DROP POLICY IF EXISTS "customer or merchant reads stamps" ON public.stamp_events;
DROP POLICY IF EXISTS "customer or business owner reads stamps" ON public.stamp_events;
CREATE POLICY "customer or business owner reads stamps"
ON public.stamp_events FOR SELECT TO authenticated USING (
 customer_id = (SELECT auth.uid()) OR EXISTS (
  SELECT 1 FROM public.campaigns c JOIN public.businesses b ON b.id=c.business_id
  WHERE c.id=stamp_events.campaign_id AND b.owner_id=(SELECT auth.uid())
 )
);
DROP POLICY IF EXISTS "customer or merchant reads redemptions" ON public.reward_redemptions;
DROP POLICY IF EXISTS "customer or business owner reads redemptions" ON public.reward_redemptions;
CREATE POLICY "customer or business owner reads redemptions"
ON public.reward_redemptions FOR SELECT TO authenticated USING (
 customer_id = (SELECT auth.uid()) OR EXISTS (
  SELECT 1 FROM public.campaigns c JOIN public.businesses b ON b.id=c.business_id
  WHERE c.id=reward_redemptions.campaign_id AND b.owner_id=(SELECT auth.uid())
 )
);
COMMIT;

-- Post-apply tests (separate authenticated sessions, not SQL-editor superuser):
-- 1. anon cannot execute six merchant RPCs; authenticated still can.
-- 2. Verified customer can create/edit review; unrelated account cannot probe visit.
-- 3. Customer can read own ledger; owner A cannot read owner B's ledger.
-- 4. New owner sees existing ledger; former owner loses merchant-only access.
-- 5. Merchant Hub history, wallet balance and redemption still work.
