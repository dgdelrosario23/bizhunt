# Discover Recommended ranking

Default list sorting is Recommended. Profile completeness contributes 50%, Bayesian rating (five prior reviews at 3.5 stars) 25%, followers 15% and verified review volume 10%. Logarithmic follower/review contributions cap at 100/50 respectively. Completeness bands (80+, 50–79, below 50) sort first, then score, completeness, name and ID. No reviews is neutral; no new-business boost is needed to reach the top completeness band. Featured local favorites require an 80+ score, logo and cover, and a registered merchant. Founder-curated listings retain their existing listing behavior; user-submitted missing places remain map-only. Current feed retrieval limits remain unchanged. Explicit sorting overrides Recommended.

The merchant checklist uses the same profile formula and requires a complete seven-day schedule (closed days count). Mobile services can provide a coverage area instead of a physical pin; services may use their description in place of a menu. Curated listings use available profile media but are not assigned private follower counts or verified review scores.

## Deployment
Apply `supabase/migrations/20261126_discover_metrics.sql` in Supabase before merging. It adds only an authenticated, security invoker aggregate RPC for the IDs already visible to the caller. No table data or policies change. Before migration, ranking falls back to loaded data, which may be truncated. Rollback: revert the PR, then optionally run `drop function if exists public.bizhunt_discover_metrics(uuid[]);`.

## QA
Run `node tests/discover-ranking.test.cjs`. In an isolated staging environment check default ranking, alternate sort options, nearby filter reset, search/category filters, map-only missing places, profile checklist updates after media/hours edits, and mobile layout. Verify aggregate RPC returns one row per visible registered business. Do not use production data for write tests.
