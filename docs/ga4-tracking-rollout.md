# GA4 tracking rollout

## Public marketing pages
Home and VIP use existing GTM-56V7CC35. Existing homepage CTA events remain. The VIP inquiry script sends only the event name vip_inquiry_submit after the RPC succeeds; no form fields are sent.

## App routes
Account, Customer App, Merchant Hub, Communities and Town Hall use the existing GA4 measurement ID G-KDF528M1Z6 directly. Do not install GTM on these routes. The shared optional consent choice has been updated to explain app analytics: previously declined choices remain declined; previously allowed choices must opt in again. No external analytics scripts load before consent. Unknown entry query parameters and all fragments are excluded; a clean, static page URL and title plus an origin-only referrer are supplied on every event. Initial page views are dispatched once manually. Screen events are deduplicated across rerenders and intentionally contain no entity IDs. No analytics integration on founder, VIP leads, verification or the emergency page. No explicit QR/scanner events.

| Route | Events besides page_view |
| --- | --- |
| /account/ | login, sign_up (immediate session only), sign_up_request (verification requested), merchant_registration |
| /app/ | discover_view, business_view, deals_view, wallet_view, profile_view, merchant_registration |
| /hub/ | merchant_overview_view, merchant_campaign_view, merchant_promos_view, merchant_business_view, merchant_registration |
| /communities/ | communities_view, community_view |
| /townhall/ | page_view only |

OAuth and email-verification redirects are excluded. Do not interpret sign_up_request as completed account verification. A new business event is emitted only on a successful insert. Direct entry through excluded URLs will not be measured; this is intentional.

## GA4 and GTM setup
1. In the BizHunt Production web stream keep form interactions, outbound clicks, site search, video, file downloads and browser-history-based page views disabled. Keep Google Signals and Ads personalization off. For defense in depth turn on data redaction for query keys such as token, access_token, refresh_token, code, email, id, business, businessTab, invite, and state. Email redaction should remain enabled.
2. In GTM verify the Google tag uses the existing measurement ID, and no tag captures form values, DOM text or personal data. App events are sent directly to GA4, so do not create GTM tags for them.
3. Create one GTM Custom Event trigger matching vip_inquiry_submit exactly, and a GA4 Event tag with event name vip_inquiry_submit and the existing Google tag. No event parameters. Publish only after verification.
4. Before merging or publishing: test consent allow/decline, privacy revocation, callback URLs, app screens, and VIP event with an isolated test backend. Verify actual network payloads and DebugView contain only fixed page paths, allowed event names and no sensitive parameters. Confirm exactly one page_view per document load; screen events should not duplicate on rerender. Do not submit test inquiries or create businesses in production.
5. Mark vip_inquiry_submit and merchant_registration as key events; decide whether sign_up_request is appropriate as a signup-intent key event (not verified signup). App OAuth and verification conversions require a future dedicated success hook.

## Search Console
The existing sitemap contains the homepage and VIP marketing page only. Future canonical, indexable marketing pages should be added once implemented; logged-in or administrative routes should not be added.
