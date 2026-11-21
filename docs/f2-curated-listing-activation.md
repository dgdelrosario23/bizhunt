# F2 Community Listings — activation and verification

Status: **not applied**. PR #59 must remain unmerged until staging validation.

## Prerequisites
- Phase 39 founder audit/challenge tables and `bizhunt_founder_authorized()`.
- Phase 41 `bizhunt_curated_businesses`, `bizhunt_founder_curated_records`, `bizhunt_founder_curated_challenge`, and `bizhunt_founder_curated_mutate`.
- 20261119 curated media editor migration for photos/hours.
- A test founder account in `bizhunt_admins`.

## Apply in staging first
1. Record current listing count, IDs, and names. Back up the curated table and audit data.
2. Run `supabase/migrations/20261121_f2_curated_listing_management.sql` as database owner.
3. Verify a non-founder and anonymous user cannot execute create/archive RPCs.
4. Verify founder create inserts one row and one audit record, and duplicate names are rejected by existing unique index.
5. Verify archive requires a one-time code; archived rows are invisible to anonymous and regular authenticated users via table select and the customer Discover page, but remain accessible in the founder editor.
6. Verify restore makes the same record visible again without losing photos/hours.
7. Verify update, media-save, and existing permanent delete still work. Confirm audit logs show create/archive/restore/delete.
8. Verify pagination at 0, 100 and 200 records, mobile layout, and legacy dashboard features.
9. Check policies and function grants in Supabase after migration; confirm no direct insert/update/delete privileges for regular users.

## Production activation
After staging passes, apply the same migration in Supabase SQL Editor and then merge PR #59. The frontend should not be merged first because it calls new RPCs.

## Rollback caveat
The companion rollback removes create/archive RPCs and restores the original public read policy, which **will expose previously archived listings**. Before rollback, restore archived listings or explicitly decide how to keep them hidden. Do not run rollback without reviewing that consequence.

## Known limits
- New listings become publicly discoverable immediately upon creation; upload photos/hours after creation.
- Permanent deletion is irreversible and may leave uploaded storage objects; verify cleanup requirements separately.
- This checklist describes tests to perform; no live database or browser execution has been completed.
