# GA4 tracking rollout

## Current change
Consent-based GTM container GTM-56V7CC35 loads on / and /vip/ only, without query strings or fragments. Both routes use the existing localStorage consent key. VIP sends `vip_inquiry_submit` only after the server accepts the inquiry, and sends no form values. Existing homepage CTA events are unchanged.

## Google Tag Manager setup before publishing
1. Confirm the Google tag uses the existing BizHunt GA4 web stream, with page-load trigger restricted to the public routes / and /vip/.
2. Disable any automatic/third-party form, click-text, URL-history, user-provided data or DOM scraping tags that could capture values from the inquiry form. Disable GA4 enhanced form interactions; keep advertising consent denied. Verify no email, names, phone numbers, business names, search strings or tokens appear in any network payload.
3. In GTM create a Custom Event trigger named exactly vip_inquiry_submit and a GA4 Event tag with that same name using the existing Google tag. Do not add event parameters or form variables.
4. Preview both pages; allow analytics and confirm a single page_view for each navigation. Decline analytics and verify there are no GTM or GA requests. Use a test environment for submission and check that only successful inquiries emit the event. Then publish the container, and mark vip_inquiry_submit as a key event in GA4 as appropriate.

## Authenticated app coverage (next deployment)
Do not extend a general-purpose GTM script to authenticated pages until the container has been audited. BizHunt routes include member/business identifiers, auth callback tokens, location and QR flows. Use a dedicated, reviewed GA4 measurement integration with manually allowlisted event names and constant, query-free URLs; avoid automatic page views, history tracking, form interactions, user IDs, QR contents, and any DOM scraping. No analytics on /founder/, /vip/leads/, verification, or QR/token pages. Avoid sensitive emergency interactions.

Proposed event names: sign_up, login, discover_view, business_view, deals_view, wallet_view, community_view, merchant_registration. Add explicit success hooks for conversion events and deduplicated screen events to app navigation; never include record IDs, personal details or dynamic titles.

The existing sitemap contains only the homepage and VIP landing page. Future canonical, indexable marketing pages should be added to it once implemented; logged-in app and administrative routes should not be added.
