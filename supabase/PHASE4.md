# Phase 4 — QR loyalty migration and deployment

**Run only after** `supabase/schema.sql` has been applied successfully.

1. In Supabase SQL Editor, run `supabase/migrations/20261023_phase4_qr_loyalty.sql` using a privileged project admin. The migration creates one-time QR tokens and transaction functions, and revokes the earlier UUID-only functions.
2. In Supabase Authentication → URL Configuration, allow `https://dgdelrosario23.github.io/bizhunt/loyalty/` as a redirect URL (also keep the `/account/` URL).
3. Visit [the Phase 4 app](https://dgdelrosario23.github.io/bizhunt/loyalty/). Use two different verified email accounts and separate browser profiles: customer and merchant.
4. Merchant: create a business and an active campaign under `/account/` first. Customer: sign in to `/loyalty/`, select **My QR**, and generate a code. Merchant: sign in on another device/browser, choose a campaign, scan the QR or paste the code, then approve stamp.
5. Customer refreshes **Wallet** to view their stamp balance. Repeat until the goal, then merchant selects **Redeem** and scans a *fresh* customer code. The code is single-use and expires after 90 seconds.
6. Test denied cases: customer cannot approve own code; another merchant cannot issue for a campaign they do not own; code cannot be reused; expired code fails; insufficient stamps cannot redeem; reward-eligible customer cannot collect more stamps until redemption.

## Security and scope
- This is a beta/pilot prototype. QR proves access to a signed-in customer session, **not** a completed purchase or physical presence; merchants must verify purchases themselves.
- Browser only contains Supabase project URL and publishable key, never a secret/service-role key.
- Tokens are random, hashed in the database, expire after 90 seconds, and are consumed atomically with the ledger operation.
- One outstanding token per customer; at most six token creations per minute. Merchant must be authenticated and own the campaign.
- Concurrent redemptions/stamps for a customer/campaign are serialized with transaction advisory locks.
- Existing `/account/`, `/merchant/` and `/` demos remain intact.
- The previous ledger RPCs are revoked from client roles; do not grant them back.
- **Not production-ready:** add verified merchant onboarding, purchase proof, fraud monitoring, stronger anti-automation rate limits, privacy controls and retention policies, end-to-end tests, and verified on-device QR scanning across browsers.
- Camera scanning uses the browser's BarcodeDetector API when supported. Manual paste of the token is the supported fallback. Codes are visible as text for accessibility and compatibility.
- The SQL has not been executed in your Supabase project by GitHub deployment. You must run it yourself. Do not treat GitHub Pages publication as proof of database migration.
