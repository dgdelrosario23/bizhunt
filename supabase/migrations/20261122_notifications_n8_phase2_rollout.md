# N8 Phase 2 — scheduled, batched follower notifications

## What changed
- Merchant's optional "Notify followers" checkbox now queues an announcement. Scheduled promotions are queued for their start time; active campaigns queue immediately.
- Server queue processes up to 200 eligible followers per job per run (configurable, max 500). The worker uses a cursor, transactional progress, and row locks with SKIP LOCKED.
- No 500-follower audience cap. Rate limit remains two announcements per business per seven days.
- The old synchronous N8 broadcast RPC is revoked from authenticated clients to prevent bypassing the new queue.
- Worker rechecks promo/campaign active state, current follows and per-user opt-outs before delivery. Expired/paused sources cancel remaining work.
- Inbox includes announcement metadata. Promotion notifications open the merchant business profile's Promos tab; campaign notifications open the business profile. Exact promo card or campaign card highlighting is **not yet implemented**.
- No web push notifications.

## Required manual Supabase steps
1. Ensure N3, N7 and N8 migrations are already applied.
2. Apply `supabase/migrations/20261122_notifications_n8_phase2_queue.sql` in staging first.
3. Configure a **trusted database scheduler** to execute `select public.bizhunt_process_follower_jobs(5,200);` once per minute as a privileged postgres job. Example, if pg_cron is installed and approved in your Supabase project:
   `select cron.schedule('bizhunt-follower-delivery','* * * * *',$$select public.bizhunt_process_follower_jobs(5,200);$$);`
   The migration **does not install pg_cron or schedule anything**. Without this worker schedule, announcements remain pending and followers will receive no notifications.
4. Test an active promo, future-dated promo, and campaign with two accounts. Verify the job moves to complete, only current followers who opted in receive an alert, and the customer link works.
5. Test 501+ followers, multiple batches, source deactivation before delivery, two announcements/week, duplicate enqueue, unauthorized RPC attempts, and user preference opt-out.
6. Before rollback, stop the scheduler (e.g. `select cron.unschedule('bizhunt-follower-delivery');` when pg_cron was used). Then use the rollback SQL. Previously delivered inbox messages remain.

## Important limitations
- Queued announcements are processed on the worker's cadence, not instantly.
- Publishing an item succeeds even if queue creation fails; merchant sees a separate warning.
- There is no UI to inspect/cancel pending jobs; the database holds their state.
- No live SQL execution, cron scheduling, or browser E2E tests were performed. Review SECURITY DEFINER permissions and publication/RLS in staging.
