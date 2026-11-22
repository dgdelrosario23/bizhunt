# Phase N8 — Business follower notifications

## Included
- Existing `business_follows` table is the follower source for merchant-owned businesses. Curated listing follows are separate and not included.
- Merchant promotion and loyalty campaign creation forms have an **unchecked** opt-in checkbox to notify followers.
- Owner-verified RPC `bizhunt_broadcast_to_followers` validates source ownership and active publication, permits only new items created in the past hour, limits to two broadcasts per business in seven days, prevents re-sending the same item, and respects each recipient's `followed_businesses_enabled` preference.
- Customer inbox notification links to the business profile, not an exact promo/campaign. A future deep-link phase is needed for exact item navigation.
- This first release supports at most 500 eligible followers. For larger businesses, the RPC refuses to broadcast and returns a clear merchant error. **No queue/background delivery exists yet.**
- Promotion announcements require the promotion to be currently active and within its start/end dates. Future-scheduled promos can be published but cannot broadcast at creation time.
- The merchant creates the promo/campaign first, then requests the notification. If broadcasting fails, publication still succeeds and the merchant sees an error.
- Existing campaigns, edited promotions, and reactivations are not broadcast automatically.
- No push notifications: only the existing in-app inbox and N6 Realtime refresh when configured.

## Supabase manual activation
Apply after Phase 29, N3 and N7. N4/N5 are required by N7; N6 is optional.
`supabase/migrations/20261122_notifications_n8_business_followers.sql`

## QA
1. Verify only the business owner can call the RPC; test with another merchant and a customer.
2. Follow/unfollow from two customer accounts. Publish a current promo and opt in; verify one alert per eligible follower.
3. Disable 'Businesses I follow' for one account; verify no alert.
4. Publish an active campaign with opt-in and verify the customer inbox business link.
5. Try to broadcast the same source twice, exceed 2 per 7 days, and exceed 500 followers; verify safe errors.
6. Publish a future-scheduled promo with opt-in; confirm the merchant sees a broadcast error while promo remains saved.
7. Confirm pre-migration UI still loads and existing customer notification preferences can be saved.
8. Test SQL permissions/RLS and realtime in staging before production.

No Supabase SQL or live browser E2E testing was performed by ChatGPT.
