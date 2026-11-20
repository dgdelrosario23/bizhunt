-- Phase 1 reliability: reject untyped legacy tokens at the server boundary.
-- Apply in Supabase SQL editor after reviewing against deployed function definition.
BEGIN;
CREATE OR REPLACE FUNCTION public.process_visit_token(p_token text, p_campaign uuid, p_action text)
RETURNS TABLE(customer_id uuid, stamp_balance bigint, stamps_required integer, action_taken text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_customer uuid;v_goal int;v_stamps bigint;v_redemptions bigint;v_token_id uuid;
        v_action_type text;v_token_campaign uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
 IF p_token IS NULL OR p_token !~ '^[0-9a-f]{48}$' THEN RAISE EXCEPTION 'Invalid code'; END IF;
 IF p_action IS NULL OR p_action NOT IN ('stamp','redeem') THEN RAISE EXCEPTION 'Invalid action'; END IF;
 SELECT c.stamp_goal INTO v_goal FROM public.campaigns c
 JOIN public.businesses b ON b.id=c.business_id
 WHERE c.id=p_campaign AND c.active AND b.owner_id=auth.uid();
 IF v_goal IS NULL THEN RAISE EXCEPTION 'Merchant is not authorized for this campaign'; END IF;
 SELECT t.id,t.customer_id,t.action_type,t.campaign_id
 INTO v_token_id,v_customer,v_action_type,v_token_campaign
 FROM public.visit_tokens t WHERE t.token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex')
 AND t.consumed_at IS NULL AND t.expires_at>now() FOR UPDATE;
 IF v_token_id IS NULL THEN RAISE EXCEPTION 'Code expired or already used'; END IF;
 IF v_action_type IS NULL THEN RAISE EXCEPTION 'Legacy QR is no longer supported. Ask customer for a fresh code'; END IF;
 IF (v_action_type<>p_action OR (v_token_campaign IS NOT NULL AND v_token_campaign IS DISTINCT FROM p_campaign))
   THEN RAISE EXCEPTION 'QR action or campaign does not match'; END IF;
 IF v_customer=auth.uid() THEN RAISE EXCEPTION 'Cannot approve your own visit'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(v_customer::text||p_campaign::text,73));
 SELECT count(*) INTO v_stamps FROM public.stamp_events s
 WHERE s.customer_id=v_customer AND s.campaign_id=p_campaign;
 SELECT count(*) INTO v_redemptions FROM public.reward_redemptions r
 WHERE r.customer_id=v_customer AND r.campaign_id=p_campaign;
 IF p_action='stamp' THEN
   IF v_stamps-v_redemptions*v_goal >= v_goal THEN
     RAISE EXCEPTION 'Reward available: redeem before collecting more stamps';
   END IF;
   INSERT INTO public.stamp_events(campaign_id,customer_id,merchant_id)
   VALUES(p_campaign,v_customer,auth.uid());
   v_stamps:=v_stamps+1;
 ELSE
   IF v_stamps-v_redemptions*v_goal < v_goal THEN RAISE EXCEPTION 'Not enough stamps to redeem'; END IF;
   INSERT INTO public.reward_redemptions(campaign_id,customer_id,merchant_id)
   VALUES(p_campaign,v_customer,auth.uid());
   v_redemptions:=v_redemptions+1;
 END IF;
 UPDATE public.visit_tokens SET consumed_at=now() WHERE id=v_token_id;
 RETURN QUERY SELECT v_customer,v_stamps-v_redemptions*v_goal,v_goal,p_action;
END $function$;

COMMIT;
