# Phase 16 deployment and manual QA

## Required order
1. Run all prerequisite Phase 13, Phase 14, Phase 14D, and Phase 15 migrations in Supabase SQL Editor, if not already applied.
2. Run `supabase/migrations/20261025_phase16_moderation_location_hours.sql` as the Supabase database owner.
3. Find the founder's UUID in Supabase Authentication > Users and explicitly grant admin access via SQL Editor:
```sql
insert into public.bizhunt_admins(user_id)
values ('<VERIFIED_FOUNDER_AUTH_USER_UUID>')
on conflict do nothing;
```
Do **not** add anonymous or unverified users. The existing founder analytics access and new moderation allowlist are separate.

## Security and moderation
- `bizhunt_moderation_queue` and `bizhunt_moderate` are SECURITY DEFINER RPCs that check the signed-in user's ID against a server-side administrator allowlist on every call.
- Reports and verification requests remain private via Phase 15 RLS. Admins only access them through the restricted RPCs.
- Admins must verify ownership independently before approving. Approve/reject changes the request status; approving also sets the verified badge.
- Reports can be investigated, resolved, or dismissed; no automatic content removal is performed.
- Unique partial index prevents duplicate active reports for the same reporter and business/review. If older active duplicates already exist, clean them up before applying the migration.
- Phase 16 strengthens the verification trigger to prevent merchants from self-verifying on INSERT as well as UPDATE.

## Merchant QA
- In Merchant Hub, add both map latitude and longitude to a test business, save, and reload. Do not paste coordinates for a different storefront.
- Add one special date with hours and another marked closed. Check Open Now from the customer app on those dates.
- Existing weekly hours remain; special date overrides apply to the selected day.
- All businesses default to `Asia/Manila` timezone; no timezone editor is exposed yet.

## Customer QA
- Discover > Nearby businesses: explicitly allow browser location, confirm distances show for coordinate-equipped listings and sorting is nearest-first. Toggle again to clear.
- Reject permission and confirm area selection still works. Distance is straight-line, **not** driving distance or ETA.
- Open a business > Report: submit a report, verify status in Profile > My Reports. Report a review separately.
- Attempt to report the same item twice while the first report is pending; confirm a duplicate warning.
- Confirm only approved verified businesses show the verified badge.

## Founder QA
- Log in with an allowlisted admin and test queue loading and an approval on a **test business**.
- Test a normal account: moderation RPC must return unauthorized, and the dashboard must not expose report notes or request evidence.
- Confirm report statuses and verification approvals update correctly.

## Limitations
- The code was committed and JavaScript syntax checked, but there was no live Supabase migration execution, RLS penetration testing, browser integration testing, or mobile/GPS testing.
- Nearby sorting excludes businesses without confirmed coordinates when Nearby is enabled; it does not geocode merchants automatically.
- Holiday/special-date overrides use the merchant's configured timezone, default Asia/Manila. Overnight schedules crossing midnight may require further edge-case handling.
- Reports use a basic inline form; no attachments or moderator audit-history log are implemented.
- The founder allowlist requires a manual administrator SQL insert. Do not confuse founder analytics access with moderation permission.
