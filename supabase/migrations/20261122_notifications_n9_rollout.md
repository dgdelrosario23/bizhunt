# N9 notification UX rollout

## Changes
- Customer inbox groups notifications by Today, Yesterday, or calendar date and improves unread presentation.
- Follower announcement notifications navigate to the business profile's Promos tab and attempt to scroll to and highlight the exact promo or loyalty campaign card.
- Merchant Overview displays recent announcement jobs and delivered counts, with manual refresh. This is a delivery count, **not** an open/read count.

## Manual SQL
Apply `supabase/migrations/20261122_notifications_n9_summary.sql` after N8 Phase 2. The read-only owner-scoped RPC is needed for the Merchant Overview panel; without it the panel shows a setup hint. Rollback: `20261122_notifications_n9_rollback.sql`.

## Test
1. Merchant Overview: verify only the current owner's business jobs appear; switch businesses and refresh.
2. Confirm the prior successful promotion appears as Complete with 2 delivered.
3. Customer inbox: verify date headings, unread styling, and timestamp labels.
4. Open a promo announcement: verify business profile, Promos tab, highlighted promo card.
5. Open a campaign announcement: verify highlighted loyalty campaign card.
6. Test paused/expired promo: business profile still opens, but unavailable card cannot be highlighted; no stale content should be shown.
7. Confirm other notification kinds and legacy records still navigate as before.

No Supabase SQL was applied automatically and no live browser/DB E2E tests were performed.
