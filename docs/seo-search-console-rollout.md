# Search Console expansion

Public canonical URLs: /, /vip/, /businesses/, /loyalty-program/, /discover/, /about/, /faq/. Each new marketing page has distinct content, title, description, social metadata, visible breadcrumbs, structured data and a consent-based analytics preference. The homepage footer links all pages; cross-links use canonical paths. /landing/ points to the homepage as its canonical. Account, app, community, QR verification, merchant, founder, and Town Hall pages are excluded from indexing with noindex; this is only an indexing directive, not access control. The emergency information page remains outside the marketing sitemap.

After the PR is merged and GitHub Pages deployment completes:
1. Open https://bizhunt.app/sitemap.xml and check all seven URLs.
2. In Google Search Console, choose the BizHunt property and open Sitemaps. Submit sitemap.xml (or resubmit existing sitemap if needed); verify a successful fetch.
3. Inspect each of the five new URLs using URL Inspection → Test Live URL, then Request Indexing if eligible.
4. Verify page views with GA4 Realtime after consenting, visiting the five pages with clean URLs.
5. Review Search Console Pages and Performance over time. Sitemap submission does not guarantee indexing or ranking. Avoid requesting indexing of account, app, admin, QR or lead pages.

No database migration or production data changes are needed.
