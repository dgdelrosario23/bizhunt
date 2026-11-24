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
INSERT INTO public.business_reviews(id,business_id,customer_id,rating) VALUES ('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002',5);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true), set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
DO $$
DECLARE u uuid := '10000000-0000-4000-8000-000000000001'; v uuid := '10000000-0000-4000-8000-000000000002'; a uuid := '20000000-0000-4000-8000-000000000001'; b uuid := '20000000-0000-4000-8000-000000000002'; r uuid := '30000000-0000-4000-8000-000000000001';
BEGIN
 IF auth.uid() IS DISTINCT FROM u OR current_user <> 'authenticated' THEN RAISE EXCEPTION 'Invalid test identity'; END IF;
 INSERT INTO public.content_reports(reporter_id,business_id,reason) VALUES(u,a,'Other');
 RAISE NOTICE 'PASS 1: business report allowed';
 INSERT INTO public.content_reports(reporter_id,business_id,review_id,reason) VALUES(u,a,r,'Other');
 RAISE NOTICE 'PASS 2: matching review allowed';
 BEGIN
 INSERT INTO public.content_reports(reporter_id,business_id,review_id,reason) VALUES(u,b,r,'Other');
 RAISE EXCEPTION 'FAIL 3: mismatched review accepted';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS 3: mismatched review denied'; END;
 IF (SELECT count(*) FROM public.content_reports WHERE reporter_id=u) <> 2 THEN RAISE EXCEPTION 'FAIL 4: own reports not visible'; END IF;
 RAISE NOTICE 'PASS 4: own reports visible';
 BEGIN
 INSERT INTO public.content_reports(reporter_id,business_id,reason) VALUES(v,a,'Other');
 RAISE EXCEPTION 'FAIL 5: impersonation accepted';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS 5: impersonation denied'; END;
 BEGIN
 INSERT INTO public.content_reports(reporter_id,business_id,reason,status) VALUES(u,a,'Other','resolved');
 RAISE EXCEPTION 'FAIL 6: unauthorized status accepted';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS 6: unauthorized status denied'; END;
END $$;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true), set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
DO $$ BEGIN
 IF auth.uid() IS DISTINCT FROM '10000000-0000-4000-8000-000000000002'::uuid THEN RAISE EXCEPTION 'Invalid test identity'; END IF;
 IF EXISTS (SELECT 1 FROM public.content_reports WHERE reporter_id='10000000-0000-4000-8000-000000000001') THEN RAISE EXCEPTION 'FAIL 7: other reports visible'; END IF;
 RAISE NOTICE 'PASS 7: other reports hidden';
END $$;
RESET ROLE;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub','',true),set_config('request.jwt.claims','{"role":"anon"}',true);
DO $$ BEGIN
 IF auth.uid() IS NOT NULL OR current_user <> 'anon' THEN RAISE EXCEPTION 'Invalid anonymous identity'; END IF;
 BEGIN
 INSERT INTO public.content_reports(reporter_id,business_id,reason) VALUES('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Other');
 RAISE EXCEPTION 'FAIL 8: anonymous report accepted';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS 8: anonymous report denied'; END;
END $$;
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
DO $$
DECLARE u uuid := auth.uid(); a uuid := '20000000-0000-4000-8000-000000000001'; v uuid := '10000000-0000-4000-8000-000000000002'; g uuid; post uuid; n integer;
BEGIN
 IF u IS DISTINCT FROM '10000000-0000-4000-8000-000000000001'::uuid THEN RAISE EXCEPTION 'Wrong identity'; END IF;
 IF (SELECT count(*) FROM public.businesses WHERE id=a) <> 1 THEN RAISE EXCEPTION 'Discovery failed'; END IF;
 RAISE NOTICE 'PASS 9: business discovery';
 UPDATE public.profiles SET display_name='S1 Updated' WHERE id=u;
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'Own profile update failed'; END IF;
 RAISE NOTICE 'PASS 10: own profile update';
 UPDATE public.profiles SET display_name='Forbidden' WHERE id=v;
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>0 THEN RAISE EXCEPTION 'Cross profile update accepted'; END IF;
 RAISE NOTICE 'PASS 11: other profile protected';
 IF public.bizhunt_owns_business(a) IS DISTINCT FROM false THEN RAISE EXCEPTION 'Wrong ownership'; END IF;
 UPDATE public.businesses SET name='Forbidden' WHERE id=a;
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>0 THEN RAISE EXCEPTION 'Cross business update accepted'; END IF;
 RAISE NOTICE 'PASS 12: merchant ownership protected';
 IF public.bizhunt_founder_authorized() IS DISTINCT FROM false THEN RAISE EXCEPTION 'Unexpected admin'; END IF;
 BEGIN
 PERFORM public.bizhunt_founder_records('users','s1-',10,0);
 RAISE EXCEPTION 'Founder records exposed';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Founder admin access required' THEN RAISE; END IF; END;
 RAISE NOTICE 'PASS 13: founder access denied';
 g:=public.bizhunt_create_community('S1 Regression','Synthetic','Other','Test','public','open');
 IF public.bizhunt_feed_member(g) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Owner membership missing'; END IF;
 post:=public.bizhunt_feed_create(g,'S1 synthetic post',NULL);
 PERFORM public.bizhunt_feed_comment(post,'S1 synthetic comment');
 IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(public.bizhunt_feed_list(g)) x WHERE x->>'id'=post::text AND jsonb_array_length(x->'comments')=1) THEN RAISE EXCEPTION 'Feed round trip failed'; END IF;
 RAISE NOTICE 'PASS 14: community create, post, comment, read';
 PERFORM set_config('s1.test_group',g::text,true);
END $$;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
DO $$ DECLARE a uuid:='20000000-0000-4000-8000-000000000001'; g uuid:=current_setting('s1.test_group')::uuid; n integer; join_result text; is_member boolean;
BEGIN
 IF public.bizhunt_owns_business(a) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Owner check failed'; END IF;
 UPDATE public.businesses SET name='S1 Updated Cafe' WHERE id=a;
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'Owner update failed'; END IF;
 RAISE NOTICE 'PASS 15: merchant update';
 join_result := public.bizhunt_join_community(g);
 IF join_result IS DISTINCT FROM 'Joined community' THEN RAISE EXCEPTION 'Join RPC returned: %', join_result; END IF;
 is_member := public.bizhunt_feed_member(g);
 IF is_member IS DISTINCT FROM true THEN RAISE EXCEPTION 'Join RPC succeeded but active membership check returned: %', is_member; END IF;
 RAISE NOTICE 'PASS 16: community join';
END $$;
RESET ROLE;
ROLLBACK;
