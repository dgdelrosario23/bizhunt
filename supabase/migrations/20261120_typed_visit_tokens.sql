-- BizHunt: typed visit QR tokens (additive rollout)
-- Apply in Supabase SQL Editor BEFORE enabling the typed QR interfaces.
-- Existing create_visit_token() remains available for legacy clients.
BEGIN;

ALTER TABLE public.visit_tokens
  ADD COLUMN IF NOT EXISTS action_type text,
  ADD COLUMN IF NOT EXISTS campaign_id uuid;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'visit_tokens_action_type_check' AND conrelid = 'public.visit_tokens'::regclass) THEN
    ALTER TABLE public.visit_tokens ADD CONSTRAINT visit_tokens_action_type_check
      CHECK (action_type IS NULL OR action_type IN ('stamp','redeem'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'visit_tokens_typed_pair_check' AND conrelid = 'public.visit_tokens'::regclass) THEN
    ALTER TABLE public.visit_tokens ADD CONSTRAINT visit_tokens_typed_pair_check
      CHECK ((action_type IS NULL AND campaign_id IS NULL) OR (action_type IS NOT NULL AND campaign_id IS NOT NULL));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.create_typed_visit_token(p_campaign uuid, p_action text)
RETURNS TABLE(token text, expires_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_token text; v_exp timestamptz; v_goal integer; v_stamps bigint; v_redemptions bigint;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
  IF p_action IS NULL OR p_action NOT IN ('stamp','redeem') THEN RAISE EXCEPTION 'Invalid action'; END IF;
  SELECT c.stamp_goal INTO v_goal FROM public.campaigns c WHERE c.id=p_campaign AND c.active;
  IF v_goal IS NULL OR v_goal < 1 THEN RAISE EXCEPTION 'Campaign unavailable'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text,42));
  PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_campaign::text,73));
  SELECT count(*) INTO v_stamps FROM public.stamp_events WHERE customer_id=auth.uid() AND campaign_id=p_campaign;
  SELECT count(*) INTO v_redemptions FROM public.reward_redemptions WHERE customer_id=auth.uid() AND campaign_id=p_campaign;
  IF p_action='redeem' AND v_stamps-v_redemptions*v_goal < v_goal THEN RAISE EXCEPTION 'Not enough stamps to redeem'; END IF;
  IF p_action='stamp' AND v_stamps-v_redemptions*v_goal >= v_goal THEN RAISE EXCEPTION 'Reward available: redeem before collecting more stamps'; END IF;
  IF (SELECT count(*) FROM public.visit_tokens WHERE customer_id=auth.uid() AND created_at>now()-interval '1 minute')>=6
    THEN RAISE EXCEPTION 'Too many codes. Please wait a minute'; END IF;
  UPDATE public.visit_tokens SET consumed_at=now() WHERE customer_id=auth.uid() AND consumed_at IS NULL;
  v_token:=substr(replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-',''),1,48);
  v_exp:=now()+interval '90 seconds';
  INSERT INTO public.visit_tokens(customer_id,token_hash,expires_at,action_type,campaign_id)
    VALUES(auth.uid(),encode(sha256(convert_to(v_token,'UTF8')),'hex'),v_exp,p_action,p_campaign);
  RETURN QUERY SELECT v_token,v_exp;
END $function$;

CREATE OR REPLACE FUNCTION public.inspect_visit_token(p_token text, p_campaign uuid)
RETURNS TABLE(action_type text, campaign_id uuid, expires_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_action text; v_campaign uuid; v_exp timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
  IF p_token IS NULL OR p_token !~ '^[0-9a-f]{48}$' THEN RAISE EXCEPTION 'Invalid code'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.campaigns c JOIN public.businesses b ON b.id=c.business_id
    WHERE c.id=p_campaign AND c.active AND b.owner_id=auth.uid()
  ) THEN RAISE EXCEPTION 'Merchant is not authorized for this campaign'; END IF;
  SELECT t.action_type,t.campaign_id,t.expires_at INTO v_action,v_campaign,v_exp
    FROM public.visit_tokens t
    WHERE t.token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex')
      AND t.consumed_at IS NULL AND t.expires_at>now();
  IF NOT FOUND THEN RAISE EXCEPTION 'Code expired or already used'; END IF;
  IF v_action IS NULL THEN RAISE EXCEPTION 'Legacy code: ask customer to generate a new action-specific QR'; END IF;
  IF v_campaign IS DISTINCT FROM p_campaign THEN RAISE EXCEPTION 'QR belongs to another campaign'; END IF;
  RETURN QUERY SELECT v_action,v_campaign,v_exp;
END $function$;

-- Retain existing signature, return shape, security checks and transaction confirmation.
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
 IF v_action_type IS NOT NULL AND (v_action_type<>p_action OR v_token_campaign IS DISTINCT FROM p_campaign)
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

REVOKE ALL ON FUNCTION public.create_typed_visit_token(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.inspect_visit_token(text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_typed_visit_token(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inspect_visit_token(text,uuid) TO authenticated;

COMMIT;
