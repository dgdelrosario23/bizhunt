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
INSERT INTO public.bizhunt_admins(user_id) VALUES ('10000000-0000-4000-8000-000000000003');
INSERT INTO public.campaigns(id,business_id,name,reward,stamp_goal,active) VALUES ('40000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','S1 campaign','Coffee',2,true);
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
DO $$ BEGIN IF public.bizhunt_founder_authorized() IS DISTINCT FROM false THEN RAISE EXCEPTION 'Unexpected founder access'; END IF; RAISE NOTICE 'PASS 1: ordinary user not founder'; END $$;
DO $$ BEGIN BEGIN PERFORM public.bizhunt_founder_records('users','',10,0); RAISE EXCEPTION 'Unexpected success'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Founder admin access required' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 2: founder records denied'; END $$;
DO $$ BEGIN INSERT INTO public.business_follows(business_id,customer_id) VALUES ('20000000-0000-4000-8000-000000000001',auth.uid()); IF NOT EXISTS(SELECT 1 FROM public.business_follows WHERE business_id='20000000-0000-4000-8000-000000000001' AND customer_id=auth.uid()) THEN RAISE EXCEPTION 'Follow missing'; END IF; RAISE NOTICE 'PASS 3: follow business'; END $$;
DO $$ BEGIN BEGIN INSERT INTO public.business_follows(business_id,customer_id) VALUES ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003'); RAISE EXCEPTION 'Unexpected success'; EXCEPTION WHEN insufficient_privilege THEN NULL; END; RAISE NOTICE 'PASS 4: cannot follow as another user'; END $$;
DO $$ BEGIN BEGIN PERFORM public.bizhunt_queue_follower_announcement('20000000-0000-4000-8000-000000000001','campaign','40000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'Unexpected success'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Business owner authorization required' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 5: unauthorized announcement denied'; END $$;
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
DO $$ BEGIN IF public.bizhunt_founder_authorized() IS DISTINCT FROM true THEN RAISE EXCEPTION 'Founder denied'; END IF; RAISE NOTICE 'PASS 6: founder authorized'; END $$;
DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.bizhunt_founder_records('users','10000000-0000-4000-8000-000000000001',10,0)) x WHERE x->>'id'='10000000-0000-4000-8000-000000000001') THEN RAISE EXCEPTION 'User missing'; END IF; RAISE NOTICE 'PASS 7: founder records visible'; END $$;
DO $$ BEGIN INSERT INTO public.business_follows(business_id,customer_id) VALUES ('20000000-0000-4000-8000-000000000001',auth.uid()); INSERT INTO public.bizhunt_notification_preferences(user_id,followed_businesses_enabled) VALUES (auth.uid(),false) ON CONFLICT(user_id) DO UPDATE SET followed_businesses_enabled=false; RAISE NOTICE 'PASS 8: opt out of follower notifications'; END $$;
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
DO $$ BEGIN IF public.bizhunt_queue_follower_announcement('20000000-0000-4000-8000-000000000001','campaign','40000000-0000-4000-8000-000000000001') IS NULL THEN RAISE EXCEPTION 'Queue failed'; END IF; RAISE NOTICE 'PASS 9: merchant queues announcement'; END $$;
DO $$ BEGIN BEGIN PERFORM public.bizhunt_queue_follower_announcement('20000000-0000-4000-8000-000000000001','campaign','40000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'Unexpected success'; EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'Announcement already scheduled or sent' THEN RAISE; END IF; END; RAISE NOTICE 'PASS 10: duplicate announcement denied'; END $$;
RESET ROLE;
DO $$ BEGIN IF public.bizhunt_process_follower_jobs(5,200) IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'Unexpected delivery count'; END IF; RAISE NOTICE 'PASS 11: worker delivers exactly one notification'; END $$;
DO $$ BEGIN IF (SELECT count(*) FROM public.bizhunt_notifications WHERE announcement_id='40000000-0000-4000-8000-000000000001')<>1 OR NOT EXISTS(SELECT 1 FROM public.bizhunt_notifications WHERE announcement_id='40000000-0000-4000-8000-000000000001' AND user_id='10000000-0000-4000-8000-000000000001') THEN RAISE EXCEPTION 'Incorrect recipients'; END IF; RAISE NOTICE 'PASS 12: recipient and opt-out verified'; END $$;
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.bizhunt_notifications WHERE announcement_id='40000000-0000-4000-8000-000000000001') THEN RAISE EXCEPTION 'Privacy failure'; END IF; RAISE NOTICE 'PASS 13: other notification hidden'; END $$;
RESET ROLE; SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true),set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
DO $$ BEGIN IF (SELECT count(*) FROM public.bizhunt_notifications WHERE announcement_id='40000000-0000-4000-8000-000000000001' AND read_at IS NULL)<>1 THEN RAISE EXCEPTION 'Unread notification missing'; END IF; PERFORM public.bizhunt_mark_notification_read((SELECT id FROM public.bizhunt_notifications WHERE announcement_id='40000000-0000-4000-8000-000000000001')); IF NOT EXISTS(SELECT 1 FROM public.bizhunt_notifications WHERE announcement_id='40000000-0000-4000-8000-000000000001' AND read_at IS NOT NULL) THEN RAISE EXCEPTION 'Mark read failed'; END IF; RAISE NOTICE 'PASS 14: own notification visible and mark read'; END $$;
RESET ROLE;
ROLLBACK;
