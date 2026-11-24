-- LOCAL TEST ONLY. Synthetic fixtures; no production data required.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO auth.users (id,email) VALUES
 ('10000000-0000-4000-8000-000000000001','s1-reporter@example.invalid'),
 ('10000000-0000-4000-8000-000000000002','s1-other@example.invalid');
INSERT INTO public.profiles(id,display_name) VALUES ('10000000-0000-4000-8000-000000000001','S1 Reporter'),('10000000-0000-4000-8000-000000000002','S1 Other') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.businesses(id,owner_id,name,category,location) VALUES
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','S1 Cafe A','Café','Test location'),
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','S1 Cafe B','Café','Test location');
INSERT INTO public.campaigns(id,business_id,name,reward,stamp_goal) VALUES ('40000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','S1 A','Coffee',2),('40000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','S1 B','Coffee',2);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
DO $$ DECLARE r record; t text; BEGIN
SELECT token INTO STRICT t FROM public.create_typed_visit_token('40000000-0000-4000-8000-000000000001','stamp'); IF t !~ '^[0-9a-f]{48}$' THEN RAISE EXCEPTION 'Invalid generated token'; END IF; PERFORM set_config('s1.first',t,true); RAISE NOTICE 'PASS 1: valid QR';
END $$;
DO $$ DECLARE r record; t text; BEGIN
BEGIN PERFORM public.create_typed_visit_token('40000000-0000-4000-8000-000000000001','redeem'); RAISE EXCEPTION 'FAIL 2: unexpectedly allowed'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Not enough stamps to redeem' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 2: Not enough stamps to redeem';
END $$;
DO $$ DECLARE r record; t text; BEGIN
BEGIN PERFORM public.process_visit_token(current_setting('s1.first'),'40000000-0000-4000-8000-000000000001','stamp'); RAISE EXCEPTION 'FAIL 3: unexpectedly allowed'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Merchant is not authorized for this campaign' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 3: Merchant is not authorized for this campaign';
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
DO $$ DECLARE r record; t text; BEGIN
BEGIN PERFORM public.process_visit_token(current_setting('s1.first'),'40000000-0000-4000-8000-000000000002','stamp'); RAISE EXCEPTION 'FAIL 4: unexpectedly allowed'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'QR action or campaign does not match' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 4: QR action or campaign does not match';
END $$;
DO $$ DECLARE r record; t text; BEGIN
BEGIN PERFORM public.process_visit_token(current_setting('s1.first'),'40000000-0000-4000-8000-000000000001','redeem'); RAISE EXCEPTION 'FAIL 5: unexpectedly allowed'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'QR action or campaign does not match' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 5: QR action or campaign does not match';
END $$;
DO $$ DECLARE r record; t text; BEGIN
SELECT * INTO STRICT r FROM public.process_visit_token(current_setting('s1.first'),'40000000-0000-4000-8000-000000000001','stamp'); IF r.customer_id IS DISTINCT FROM '10000000-0000-4000-8000-000000000001'::uuid OR r.stamp_balance IS DISTINCT FROM 1::bigint OR r.stamps_required IS DISTINCT FROM 2 OR r.action_taken IS DISTINCT FROM 'stamp' THEN RAISE EXCEPTION 'FAIL 6: unexpected transaction result'; END IF; RAISE NOTICE 'PASS 6: stamp balance 1';
END $$;
DO $$ DECLARE r record; t text; BEGIN
BEGIN PERFORM public.process_visit_token(current_setting('s1.first'),'40000000-0000-4000-8000-000000000001','stamp'); RAISE EXCEPTION 'FAIL 7: unexpectedly allowed'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Code expired or already used' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 7: Code expired or already used';
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
DO $$ DECLARE r record; t text; BEGIN
SELECT token INTO STRICT t FROM public.create_typed_visit_token('40000000-0000-4000-8000-000000000001','stamp'); IF t !~ '^[0-9a-f]{48}$' THEN RAISE EXCEPTION 'Invalid generated token'; END IF; PERFORM set_config('s1.expired',t,true);
END $$;
RESET ROLE;
UPDATE public.visit_tokens SET expires_at=now()-interval '1 second' WHERE token_hash=encode(sha256(convert_to(current_setting('s1.expired'),'UTF8')),'hex');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
DO $$ DECLARE r record; t text; BEGIN
BEGIN PERFORM public.process_visit_token(current_setting('s1.expired'),'40000000-0000-4000-8000-000000000001','stamp'); RAISE EXCEPTION 'FAIL 8: unexpectedly allowed'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Code expired or already used' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 8: Code expired or already used';
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
DO $$ DECLARE r record; t text; BEGIN
SELECT token INTO STRICT t FROM public.create_typed_visit_token('40000000-0000-4000-8000-000000000001','stamp'); IF t !~ '^[0-9a-f]{48}$' THEN RAISE EXCEPTION 'Invalid generated token'; END IF; PERFORM set_config('s1.second',t,true);
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
DO $$ DECLARE r record; t text; BEGIN
SELECT * INTO STRICT r FROM public.process_visit_token(current_setting('s1.second'),'40000000-0000-4000-8000-000000000001','stamp'); IF r.customer_id IS DISTINCT FROM '10000000-0000-4000-8000-000000000001'::uuid OR r.stamp_balance IS DISTINCT FROM 2::bigint OR r.stamps_required IS DISTINCT FROM 2 OR r.action_taken IS DISTINCT FROM 'stamp' THEN RAISE EXCEPTION 'FAIL 9: unexpected transaction result'; END IF; RAISE NOTICE 'PASS 9: stamp balance 2';
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
DO $$ DECLARE r record; t text; BEGIN
BEGIN PERFORM public.create_typed_visit_token('40000000-0000-4000-8000-000000000001','stamp'); RAISE EXCEPTION 'FAIL 10: unexpectedly allowed'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Reward available: redeem before collecting more stamps' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 10: Reward available: redeem before collecting more stamps';
END $$;
DO $$ DECLARE r record; t text; BEGIN
SELECT token INTO STRICT t FROM public.create_typed_visit_token('40000000-0000-4000-8000-000000000001','redeem'); PERFORM set_config('s1.reward',t,true);
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
DO $$ DECLARE r record; t text; BEGIN
SELECT * INTO STRICT r FROM public.process_visit_token(current_setting('s1.reward'),'40000000-0000-4000-8000-000000000001','redeem'); IF r.customer_id IS DISTINCT FROM '10000000-0000-4000-8000-000000000001'::uuid OR r.stamp_balance IS DISTINCT FROM 0::bigint OR r.stamps_required IS DISTINCT FROM 2 OR r.action_taken IS DISTINCT FROM 'redeem' THEN RAISE EXCEPTION 'FAIL 11: unexpected transaction result'; END IF; RAISE NOTICE 'PASS 11: redeem balance 0';
END $$;
DO $$ DECLARE r record; t text; BEGIN
BEGIN PERFORM public.process_visit_token(current_setting('s1.reward'),'40000000-0000-4000-8000-000000000001','redeem'); RAISE EXCEPTION 'FAIL 12: unexpectedly allowed'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Code expired or already used' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 12: Code expired or already used';
END $$;
RESET ROLE;
DO $$ BEGIN IF (SELECT count(*) FROM public.stamp_events WHERE campaign_id='40000000-0000-4000-8000-000000000001' AND customer_id='10000000-0000-4000-8000-000000000001')<>2 OR (SELECT count(*) FROM public.reward_redemptions WHERE campaign_id='40000000-0000-4000-8000-000000000001' AND customer_id='10000000-0000-4000-8000-000000000001')<>1 THEN RAISE EXCEPTION 'FAIL 13: ledger mismatch'; END IF; RAISE NOTICE 'PASS 13: ledger counts correct'; END $$;
ROLLBACK;
