# BizHunt Notifications N4 — event review and rollout

## Existing event sources
- Confirmed loyalty stamps: `public.stamp_events`, inserted by `process_visit_token` after token and merchant authorization.
- Confirmed reward redemptions: `public.reward_redemptions`, inserted by the same RPC.
- Community posts/comments: `bizhunt_community_posts` / `bizhunt_community_comments`, written by membership-checked RPCs. **Not enabled in N4**: fan-out, moderation visibility, member preferences and spam controls require design.
- Business changes and promotions: no single verified notification event source selected. **Not enabled in N4**.

## Scope
N4 adds two AFTER INSERT triggers only, preserving the existing scanner RPC signatures and balances. Each successful stamp/redeem creates one notification for its customer; retries are deduplicated using source event type and UUID. New events only; no historical backfill.

## Rollout
1. Confirm Phase 29 and N3 SQL were applied.
2. Review and manually apply `20261122_notifications_n4_loyalty_events.sql` in Supabase SQL Editor. **GitHub does not apply SQL**.
3. Perform one test stamp and one test redemption using existing merchant/customer flows; verify recipient-only inbox and no duplicate notifications. Verify failed/rolled-back scans create none.
4. If issues occur, manually run the paired rollback. It stops triggers but retains notifications already created.

## Limitations
- This is database-generated in-app notification creation, **not** push notification or live delivery. Bell count refreshes through existing app load logic.
- The current customer Wallet navigation opens the Wallet section, not an individual redemption/stamp.
- Trigger writes are part of the transaction: if notification insertion fails, the original scan transaction may fail. Test in staging before production.
- SQL has been reviewed structurally, but not executed against a live database.
