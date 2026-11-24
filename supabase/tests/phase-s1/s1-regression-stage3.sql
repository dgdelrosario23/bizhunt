-- LOCAL TEST ONLY. Synthetic fixtures; no production data required.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO auth.users (id,email) VALUES
 ('10000000-0000-4000-8000-000000000001','s1-reporter@example.invalid'),
 ('10000000-0000-4000-8000-000000000002','s1-other@example.invalid'),
 ('10000000-0000-4000-8000-000000000003','s1-third@example.invalid');
INSERT INTO public.profiles(id,display_name) VALUES ('10000000-0000-4000-8000-000000000001','S1 Reporter'),('10000000-0000-4000-8000-000000000002','S1 Other') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.businesses(id,owner_id,name,category,location) VALUES
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','S1 Cafe A','Café','Test location'),
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000003','S1 Cafe B','Café','Test location');
INSERT INTO public.campaigns(id,business_id,name,reward,stamp_goal) VALUES ('40000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','Other campaign','Coffee',2);
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
DO $$ DECLARE k integer; v uuid; BEGIN INSERT INTO public.campaigns(id,business_id,name,reward,stamp_goal) VALUES ('40000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','S1 campaign','Coffee',2); RAISE NOTICE 'PASS 1: campaign create'; END $$;
DO $$ DECLARE k integer; v uuid; BEGIN UPDATE public.campaigns SET name='Updated' WHERE id='40000000-0000-4000-8000-000000000001'; GET DIAGNOSTICS k=ROW_COUNT; IF k<>1 THEN RAISE EXCEPTION 'Update failed'; END IF; RAISE NOTICE 'PASS 2: own campaign update'; END $$;
DO $$ DECLARE k integer; v uuid; BEGIN UPDATE public.campaigns SET name='Unauthorized' WHERE id='40000000-0000-4000-8000-000000000002'; GET DIAGNOSTICS k=ROW_COUNT; IF k<>0 THEN RAISE EXCEPTION 'Unauthorized update'; END IF; RAISE NOTICE 'PASS 3: other campaign protected'; END $$;
DO $$ DECLARE k integer; v uuid; BEGIN INSERT INTO public.business_promos(id,business_id,title,starts_at,ends_at,max_claims) VALUES ('50000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Active promo',now()-interval '1 day',now()+interval '1 day',1),('50000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','Expired promo',now()-interval '2 days',now()-interval '1 day',1); RAISE NOTICE 'PASS 4: merchant creates promotions'; END $$;
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
DO $$ DECLARE k integer; v uuid; BEGIN v:=public.claim_business_promo('50000000-0000-4000-8000-000000000001'); IF v IS NULL THEN RAISE EXCEPTION 'No voucher'; END IF; PERFORM set_config('s1.voucher',v::text,true); RAISE NOTICE 'PASS 5: active claim'; END $$;
DO $$ DECLARE k integer; v uuid; BEGIN BEGIN PERFORM public.claim_business_promo('50000000-0000-4000-8000-000000000002'); RAISE EXCEPTION 'Unexpected success'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Promotion unavailable' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 6: expired claim denied'; END $$;
DO $$ DECLARE k integer; v uuid; BEGIN v:=public.claim_business_promo('50000000-0000-4000-8000-000000000001'); IF v IS DISTINCT FROM current_setting('s1.voucher')::uuid THEN RAISE EXCEPTION 'Duplicate voucher'; END IF; RAISE NOTICE 'PASS 7: duplicate claim idempotent'; END $$;
DO $$ DECLARE k integer; v uuid; BEGIN IF (SELECT count(*) FROM public.promo_vouchers WHERE id=current_setting('s1.voucher')::uuid)<>1 THEN RAISE EXCEPTION 'Own voucher hidden'; END IF; RAISE NOTICE 'PASS 8: own voucher visible'; END $$;
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
DO $$ DECLARE k integer; v uuid; BEGIN BEGIN PERFORM public.claim_business_promo('50000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'Unexpected success'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'All vouchers claimed' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 9: claim cap enforced'; END $$;
DO $$ DECLARE k integer; v uuid; BEGIN IF EXISTS(SELECT 1 FROM public.promo_vouchers WHERE id=current_setting('s1.voucher')::uuid) THEN RAISE EXCEPTION 'Other voucher exposed'; END IF; RAISE NOTICE 'PASS 10: other voucher hidden'; END $$;
DO $$ DECLARE k integer; v uuid; BEGIN BEGIN PERFORM public.redeem_business_promo(current_setting('s1.voucher')::uuid); RAISE EXCEPTION 'Unexpected success'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Not authorized merchant' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 11: unauthorized merchant redemption denied'; END $$;
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
DO $$ DECLARE k integer; v uuid; BEGIN IF public.redeem_business_promo(current_setting('s1.voucher')::uuid) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Redemption failed'; END IF; RAISE NOTICE 'PASS 12: authorized redemption'; END $$;
DO $$ DECLARE k integer; v uuid; BEGIN BEGIN PERFORM public.redeem_business_promo(current_setting('s1.voucher')::uuid); RAISE EXCEPTION 'Unexpected success'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Voucher already redeemed' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 13: duplicate redemption denied'; END $$;
RESET ROLE;
DO $$ DECLARE k integer; v uuid; BEGIN IF (SELECT count(*) FROM public.promo_vouchers WHERE promo_id='50000000-0000-4000-8000-000000000001' AND redeemed_at IS NOT NULL AND redeemed_by='10000000-0000-4000-8000-000000000002')<>1 OR (SELECT count(*) FROM public.promo_vouchers WHERE promo_id='50000000-0000-4000-8000-000000000001')<>1 THEN RAISE EXCEPTION 'Ledger mismatch'; END IF; RAISE NOTICE 'PASS 14: voucher ledger correct'; END $$;
ROLLBACK;
