# Phase N7 — Notification preferences rollout

## Scope
- Two independent preferences: loyalty stamp/redemption alerts and community post reply alerts.
- Both default ON for accounts with no saved preferences, preserving N4/N5 behavior.
- User-specific RLS policies permit only the signed-in user to read/write their preferences.
- Existing N4/N5 SECURITY DEFINER trigger functions are updated to skip new notifications for opted-out recipients.
- Preferences do not remove existing notifications, disable scanner transactions, or suppress community comments.
- The notification center displays the settings when the table exists and a setup message before the migration is applied.

## Dependencies
Apply Phase 29, N3, N4 and N5 migrations before N7. N6 Realtime is optional.

## Manual verification
1. Verify customer A cannot read/update customer B's preference row.
2. Disable loyalty notifications for A; perform a valid stamp and redemption. Verify transactions succeed but no new alerts appear.
3. Enable loyalty notifications; perform another valid stamp. Verify exactly one alert.
4. Disable community replies for A; have active member B comment on A's post. Verify comment succeeds with no alert.
5. Enable replies; repeat and verify one alert and the existing 5/day cap.
6. Test a new account with no preference row (defaults ON), sign-out/account switching, and the pre-migration fallback.
7. If rollback is needed, restore the exact reviewed N4/N5 trigger function definitions first; see rollback notes. Do not blindly drop the preferences table.

**No SQL has been applied or live database tested by ChatGPT.**
