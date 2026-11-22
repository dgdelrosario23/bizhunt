# Phase N6: customer realtime notification updates

- Frontend subscribes to `postgres_changes` on `public.bizhunt_notifications` with an authenticated `user_id` filter.
- Events trigger a debounced **RLS-protected refetch** of the unread count and currently open inbox; payload contents are not used for rendering.
- The subscription starts after the existing customer screen load, avoiding a new blocking startup dependency.
- On sign-out/account change the previous channel and pending refresh/retry timers are removed.
- On channel errors, retries occur after 5 seconds; foregrounding the tab also refreshes badge and open inbox.
- An existing connection is reused on repeated renders and loads. No new inbox rows are appended blindly, preventing duplicate cards.
- If the publication migration is not applied, the existing lazy badge fetch, manual inbox opening and visibility refresh continue working. The app does not require realtime to load.

## Manual activation
1. Confirm Phase 29 recipient-only SELECT RLS is present and test that one user cannot read another's notifications.
2. Apply `20261122_notifications_n6_realtime.sql` in Supabase SQL Editor, or enable the table in Supabase Realtime publication settings.
3. In two separate sessions, create a notification for one test user. Confirm only that user's bell/inbox refreshes.
4. Mark read and verify badge decrement; repeat while backgrounded and after reconnect/sign-out.
5. If needed, run `20261122_notifications_n6_realtime_rollback.sql` to disable publication.

No SQL was executed by ChatGPT. This is in-app realtime, not OS/browser push notifications. Browser-based authenticated end-to-end testing remains pending.
