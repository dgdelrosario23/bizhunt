# Founder Overview F1 validation (manual staging)
1. Apply the F1 migration to staging as database owner. Do not run against production without approval.
2. Call `bizhunt_founder_overview_v2(7)`, `(30)`, `(90)` as a founder in `founder_admins`. Compare all aggregates to independent read-only SQL counts.
3. Call as authenticated non-founder and as anonymous: both must receive SQLSTATE 42501 (or denied EXECUTE for anon).
4. Call with 0, 31, 365 and null: reject invalid periods. Check boundary timestamps are exclusive at end.
5. Verify `founder_dashboard()`, all moderation, claims, curated listings, record editing and audit logging still work.
6. Test mobile 320px, 375px and desktop; test refresh and the fallback when the new RPC is not yet installed.
7. Verify no sensitive user fields or raw rows are returned.
8. Rollback only using the companion rollback SQL, then confirm the legacy overview still works.

Caveats: the metric `stamps` counts stamp_events records, not necessarily unique visits; `redemptions` counts reward_redemptions records. Registered unclaimed businesses are separate from curated sample listings. New users are from auth.users and exclude deleted accounts. Pending counts are exact table counts, unlike the existing moderation queue which is capped at 100.
