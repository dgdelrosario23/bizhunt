-- Phase B1 rollback: restores pre-B1 function, ledger policies and RPC grants.
-- Apply manually ONLY if B1 has been deployed and rollback is required.
-- WARNING: restores prior privacy exposure and historical merchant_id read behavior.
BEGIN;
CREATE OR REPLACE FUNCTION public.has_verified_business_stamp(p_business uuid,p_customer uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
 SELECT EXISTS (
  SELECT 1 FROM public.stamp_events s
  JOIN public.campaigns c ON c.id=s.campaign_id
  WHERE c.business_id=p_business AND s.customer_id=p_customer
 );
$$;
REVOKE EXECUTE ON FUNCTION public.has_verified_business_stamp(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_verified_business_stamp(uuid,uuid) TO authenticated;

DROP POLICY IF EXISTS "customer or business owner reads stamps" ON public.stamp_events;
DROP POLICY IF EXISTS "customer or merchant reads stamps" ON public.stamp_events;
CREATE POLICY "customer or merchant reads stamps"
 ON public.stamp_events FOR SELECT TO authenticated
 USING (customer_id=auth.uid() OR merchant_id=auth.uid());
DROP POLICY IF EXISTS "customer or business owner reads redemptions" ON public.reward_redemptions;
DROP POLICY IF EXISTS "customer or merchant reads redemptions" ON public.reward_redemptions;
CREATE POLICY "customer or merchant reads redemptions"
 ON public.reward_redemptions FOR SELECT TO authenticated
 USING (customer_id=auth.uid() OR merchant_id=auth.uid());

-- Live pre-B1 audit showed anon=true for these six functions.
-- Re-grant PUBLIC to reproduce that effective execution access.
GRANT EXECUTE ON FUNCTION public.claim_business_promo(uuid),
 public.redeem_business_promo(uuid), public.record_promo_impression(uuid),
 public.merchant_promo_metrics(uuid), public.record_business_engagement(uuid,text),
 public.merchant_engagement_metrics(uuid,integer) TO PUBLIC;
COMMIT;
