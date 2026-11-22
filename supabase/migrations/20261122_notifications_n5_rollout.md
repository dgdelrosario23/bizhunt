# BizHunt Notifications N5: community reply alerts

## Scope and source review
- Reviewed Phase 34 community memberships and Phase 38 feed RPCs.
- A new comment is inserted by `bizhunt_feed_comment`, which checks active membership.
- N5 notifies **only the author of the parent post** when another active member comments. No mass post fan-out, mentions, reactions, poll votes, or self-reply notifications.
- Checks both author's and commenter's active membership at notification time.
- Caps notifications to five per recipient per community in a rolling 24-hour window.
- Uses `target_type='community'` and the community UUID. Existing client opens that community, not the exact post.
- No notification text exposes comment contents or a private post.
- Duplicate event guard uses a private comment-ID ledger table, with no authenticated access.
- This is an optional server-side trigger migration, not yet applied.

## Dependencies
Apply Phase 29 and `20261122_notifications_n3_targets.sql` first. Phase N4 is independent.

## Manual staging checks
1. User A and B join one community as active members.
2. A posts; B comments: A receives one alert, B receives none.
3. A replies to own post: no alert.
4. Pending/ex-member replies or recipients: no notification.
5. Verify cap after five replies in 24 hours; no more alerts.
6. Verify notification opens the correct community and does not leak comment text.
7. Confirm ordinary posting/commenting still succeeds, including after rollback.

## Operational caution
The notification trigger runs in the same database transaction as comment creation; an unexpected trigger error could roll back a comment. Test on staging before production. No SQL has been executed by ChatGPT.
