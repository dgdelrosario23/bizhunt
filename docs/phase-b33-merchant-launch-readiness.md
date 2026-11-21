# Phase B33 — Merchant launch readiness checklist

Status: **code review and inline JavaScript syntax validation complete; live QA pending**.

## Scope and change
- Campaign historical analytics now update the four participation numbers in-place instead of calling `render()` after the RPC returns. This avoids closing a merchant's open campaign form, clearing typed edits, or resetting filters when the asynchronous request finishes.
- No SQL migrations, schema changes, permissions changes, or new RPCs.

## Manual QA — signed-in merchant
1. Open Merchant Hub on a narrow mobile viewport (320, 375, 430 px) and desktop. Verify all five tabs, no horizontal overflow or visible scrollbars, aligned Overview engagement cards, and legible campaign/promotion controls.
2. In Campaigns, start editing an existing campaign while analytics loads. Confirm the form remains open and unsaved input persists after totals update. Test create wizard, edit appearance, pause/resume, and Scan QR with a fresh customer QR.
3. In Overview, compare 7/30/90-day loaded records and All history. Confirm labels and info icons describe limited data honestly; verify empty campaign and no-activity states.
4. In Promos, test create with future start/end dates, live/scheduled/expired filters, sorting, pause/resume, and zero metrics. Confirm voucher save and redemption using a separate customer account.
5. In Scanner, test fresh QR, expired QR, duplicate approval, wrong merchant/business, camera permission denied, and retry after network failure. Confirm rejected attempts do not award stamps.
6. Switch between two merchant-owned businesses while historical analytics are loading; ensure figures never appear on the wrong business.
7. Sign out and sign in as a different merchant. Confirm prior merchant data does not remain visible.

## Authorization — required before wider rollout
Run these using *real signed-in accounts*, not Supabase SQL Editor:
- Merchant A requests `merchant_campaign_history_metrics` for business A: returns only A's campaigns.
- Merchant B requests the same function for business A: returns **zero rows**.
- Anonymous client cannot execute the RPC.
- Repeat for `merchant_customer_retention_metrics`, and verify private customer records are not exposed in UI or network responses.
- Confirm business ownership, campaign edits, promo updates, and scan approvals are enforced server-side; hiding buttons is not an authorization control.

## Release gates
- [x] Inline JavaScript syntax checked.
- [x] No Supabase migration required for B33.
- [ ] Live desktop/mobile browser QA.
- [ ] Cross-merchant and anonymous authorization tests.
- [ ] End-to-end transaction verification with two accounts.
- [ ] Confirm GitHub Pages deployment and smoke test.

**Do not consider BizHunt launch-ready until the unchecked gates pass.**
