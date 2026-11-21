# Historical retention RPC: deployment and verification checklist

**Status:** Proposed migration only. GitHub merging does not execute SQL in Supabase.

## Preconditions
1. Compare `supabase/schema.sql` with the **actual deployed** tables, column types, ownership model, and newer migrations. The repository schema may not be current.
2. Confirm `public.businesses.owner_id`, `public.campaigns.business_id`, `public.stamp_events.(campaign_id,customer_id)`, and `public.reward_redemptions.(campaign_id,customer_id)` exist with expected semantics.
3. Confirm the execution role/owner of the SECURITY DEFINER function is trusted, and that the function does not expose personal identifiers.
4. Test on a nonproduction Supabase environment first. Do not use production customer data for destructive tests.

## Authorization matrix (run with separate real JWT sessions)
| Session | Business | Expected |
|---|---|---|
| Owner A | Own business A | Exactly one aggregate row |
| Owner A | Business B owned by someone else | No rows |
| Signed-in non-owner | Business A | No rows |
| Anonymous | Business A | Permission denied (no EXECUTE) |
| Owner A | Unknown business UUID | No rows |

**Important:** A SQL editor run as a privileged role does not simulate a user's authenticated JWT. Test with genuine client sessions and verify `auth.uid()` is populated correctly.

## Data correctness
- No campaigns / no stamps: owner should receive zero counts.
- One customer with 2 stamps in the same campaign: 1 unique customer, 1 multiple-stamp customer, 0 multi-campaign customers.
- One customer with stamps in 2 campaigns: 1 multi-campaign customer.
- A customer with stamps and at least 1 redemption: count customer once for reward participation.
- Multiple redemptions by one customer: total reward events increases, redeemed customer count does not.
- Two businesses sharing a merchant owner: totals must remain separated by `p_business_id`.
- Compare RPC totals with independent database aggregates for the same business.

## Frontend checks (merged PR #35)
- Without migration, Overview explicitly shows **Recent records** and remains usable.
- After deployment, authorized owner sees **All history** with server counts.
- Switch businesses quickly: no stale counts from the previous business.
- Check zero-data business, narrow mobile layout, and info disclosure.
- Simulate RPC error or permission denial: fallback remains clearly labeled.

## Performance and release
- Use EXPLAIN (ANALYZE, BUFFERS) with representative data in a safe test environment.
- Confirm indexes support `campaigns.business_id`, `stamp_events.campaign_id`, and `reward_redemptions.campaign_id`; add targeted indexes in a separate reviewed migration if needed.
- Monitor RPC latency and permission errors after release.
- Rollback file drops the function; verify dependencies and coordinate with frontend before rollback.

## Known interpretation limits
Two stamp events are not necessarily two separate visits. Counts include all historical records available to the RPC, not a retention cohort measured over time.
