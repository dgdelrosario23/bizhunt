# BizHunt Phase 15 rollout and moderation

## Deployment
1. Apply prior Phase 13/14/14D migrations if not yet applied.
2. Run `supabase/migrations/20261025_phase15_discovery_trust_moderation.sql` in Supabase SQL Editor with an administrator connection.
3. Verify `businesses.verification_status`, `businesses.weekly_hours`, `business_verification_requests`, and `content_reports` exist.
4. Test customer Discover, business registration, Merchant Hub weekly schedules and verification requests, and customer Report Business.
5. Do not mark businesses verified without independent evidence.

## Administrative review (Supabase SQL Editor, privileged role only)
View pending verification requests:
```sql
select r.id,r.business_id,b.name,r.requester_id,r.evidence_note,r.created_at
from public.business_verification_requests r
join public.businesses b on b.id=r.business_id
where r.status='pending'
order by r.created_at;
```
After verifying ownership using trusted independent channels, mark a request approved and the business verified in a single transaction:
```sql
begin;
update public.business_verification_requests
set status='approved',reviewed_at=now()
where id='<VERIFICATION_REQUEST_UUID>' and status='pending';
-- Only after checking the prior update affected exactly one row:
update public.businesses set verification_status='verified'
where id='<BUSINESS_UUID>';
commit;
```
Reject a request:
```sql
update public.business_verification_requests
set status='rejected',reviewed_at=now()
where id='<VERIFICATION_REQUEST_UUID>' and status='pending';
```
View reports:
```sql
select r.id,r.business_id,b.name,r.review_id,r.reason,r.details,r.reporter_id,r.created_at
from public.content_reports r join public.businesses b on b.id=r.business_id
where r.status='pending' order by r.created_at;
```
After reviewing and taking appropriate action:
```sql
update public.content_reports set status='resolved'
where id='<REPORT_UUID>' and status in ('pending','reviewing');
```
These operations are administrator-only; customer and merchant sessions must not run them.

## Limitations
- Geolocation is opt-in, uses browser permission and OpenStreetMap Nominatim, and suggests an existing listed area; it does not determine GPS distance or prove the business address.
- Open Now is computed in the viewer's local timezone, not a stored business timezone. Accurate for local Pampanga users/businesses; should be replaced with timezone-aware logic before expanding geographically. It relies on merchant-entered weekly hours and does not cover holidays.
- Report Business currently uses simple browser prompts, not a polished moderation form; review-level reports are supported in the schema but not yet exposed in the UI.
- Verification requests are submitted for administrator review; there is no automatic approval or fully featured founder moderation dashboard.
- The customer app requires the Phase 15 migration before its updated businesses query works.
- JavaScript syntax checks were performed; live browser, Supabase RLS, geolocation, and end-to-end integration tests were not performed.
