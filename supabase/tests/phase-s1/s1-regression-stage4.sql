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
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN INSERT INTO public.townhall_posts(id,author_id,title,body) VALUES ('60000000-0000-4000-8000-000000000001',auth.uid(),'Synthetic idea','Synthetic test body'); RAISE NOTICE 'PASS 1: town hall submission'; END $$;
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN g:=public.bizhunt_create_community('S1 Regression','Synthetic','Other','Test','public','open'); PERFORM set_config('s1.group',g::text,true); RAISE NOTICE 'PASS 2: community creation'; END $$;
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN INSERT INTO public.bizhunt_community_places(id,community_id,business_id,name,relationship,perk_details,created_by) VALUES ('60000000-0000-4000-8000-000000000002',current_setting('s1.group')::uuid,'20000000-0000-4000-8000-000000000001','S1 Cafe A','partner','10 percent discount',auth.uid()); RAISE NOTICE 'PASS 3: partner request created'; END $$;
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN INSERT INTO public.townhall_votes(post_id,user_id) VALUES ('60000000-0000-4000-8000-000000000001',auth.uid()); RAISE NOTICE 'PASS 4: town hall vote'; END $$;
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN BEGIN INSERT INTO public.townhall_votes(post_id,user_id) VALUES ('60000000-0000-4000-8000-000000000001',auth.uid()); RAISE EXCEPTION 'Duplicate accepted'; EXCEPTION WHEN unique_violation THEN NULL; END; RAISE NOTICE 'PASS 5: duplicate vote denied'; END $$;
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN INSERT INTO public.townhall_comments(post_id,author_id,body) VALUES ('60000000-0000-4000-8000-000000000001',auth.uid(),'Synthetic comment'); RAISE NOTICE 'PASS 6: town hall comment'; END $$;
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN DELETE FROM public.townhall_posts WHERE id='60000000-0000-4000-8000-000000000001'; GET DIAGNOSTICS k=ROW_COUNT; IF k<>0 THEN RAISE EXCEPTION 'Unauthorized deletion'; END IF; RAISE NOTICE 'PASS 7: other submission protected'; END $$;
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN IF public.bizhunt_respond_partner_request('60000000-0000-4000-8000-000000000002',true) IS DISTINCT FROM 'Partnership approved' THEN RAISE EXCEPTION 'Approval failed'; END IF; RAISE NOTICE 'PASS 8: merchant approves partnership'; END $$;
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN IF public.bizhunt_join_community(current_setting('s1.group')::uuid) IS DISTINCT FROM 'Joined community' THEN RAISE EXCEPTION 'Join failed'; END IF; RAISE NOTICE 'PASS 9: community join'; END $$;
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN IF NOT EXISTS(SELECT 1 FROM public.bizhunt_community_places WHERE id='60000000-0000-4000-8000-000000000002' AND confirmed_by_merchant AND partnership_status='approved' AND perk_details='10 percent discount') THEN RAISE EXCEPTION 'Perk missing'; END IF; RAISE NOTICE 'PASS 10: member sees approved perk'; END $$;
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN BEGIN PERFORM public.bizhunt_issue_community_id(current_setting('s1.group')::uuid); RAISE EXCEPTION 'Unexpected success'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Active community membership required' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 11: nonmember ID denied'; END $$;
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN BEGIN PERFORM public.bizhunt_edit_community_partner('60000000-0000-4000-8000-000000000002','Forbidden','Other','','partner','',NULL,NULL,'20000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'Unexpected success'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Not authorized' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 12: nonadmin partner edit denied'; END $$;
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN SELECT token INTO t FROM public.bizhunt_issue_community_id(current_setting('s1.group')::uuid); IF t IS NULL THEN RAISE EXCEPTION 'Missing token'; END IF; PERFORM set_config('s1.idtoken',t::text,true); RAISE NOTICE 'PASS 13: member ID issued'; END $$;
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
DO $$ DECLARE g uuid; t uuid; k integer; BEGIN IF NOT EXISTS(SELECT 1 FROM public.bizhunt_verify_community_id(current_setting('s1.idtoken')::uuid) WHERE valid) THEN RAISE EXCEPTION 'Invalid member ID'; END IF; RAISE NOTICE 'PASS 14: merchant verifies member ID'; END $$;
RESET ROLE;
ROLLBACK;
