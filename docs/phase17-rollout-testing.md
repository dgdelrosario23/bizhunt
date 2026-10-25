# Phase 17 Collections & Community — rollout and QA

## Required deployment
Run `supabase/migrations/20261025_phase17_community_collections.sql` in the Supabase SQL Editor, after previous BizHunt migrations. GitHub commits alone do not apply SQL migrations. No production database operations were performed.

## User features
- Lists tab and Account shortcut: create a creator profile (unique lowercase username, display name, bio).
- Create public/private lists, add existing BizHunt businesses, notes, rearrange, edit title/description/privacy, remove places, and delete collections.
- Public profiles via View creator on collection cards; follow/unfollow users.
- Save/unsave other users' public collections.
- Discover: Trending Collections (last 14 days' saves) and Most Saved Collections (total saves). Early-stage rankings may be tied/empty.
- Existing merchant loyalty stamps and verified reviews are independent from collection saves.

## Security expectations
- Only owner can select private collections and their items; other users can only select public collections.
- Only owner can edit/delete collections and their contents.
- Users can only modify their own follows and saves. Self-follow is prohibited.
- Saves are private; the ranking RPC returns only aggregate counts for public collections.
- Switching a public collection to private removes existing saves via database trigger. Re-publication does not restore them.
- All data access is authenticated; anonymous users are directed to sign in by the existing app.
- Never put Supabase service-role credentials in browser JavaScript.

## Manual test plan
1. Apply migration. Test two signed-in accounts A and B.
2. A creates profile, private list, and adds two places. B cannot see list or list items, including via direct API queries.
3. A changes list to public. B can view the creator and list, follow A, and save list.
4. A changes list back to private. B can no longer access it; saved relation is removed.
5. A edits title and note, moves an item, removes an item, and deletes a list.
6. B tries to insert/edit/delete A's collection rows through the Supabase client; RLS must reject them.
7. B cannot follow themselves or save private collections. Check duplicate follows/saves fail cleanly.
8. Discover rankings update after save and refresh.
9. Test narrow mobile viewport and account navigation.

## Known limitations
- JavaScript syntax was checked; production Supabase migration, end-to-end RLS, browser, and mobile tests have not been run.
- List editing uses browser prompts; collection cover uploads, drag-and-drop ordering, and direct shareable creator URLs are not yet implemented.
- Discover has trending and most-saved sections; editor-curated picks and a dedicated Following feed are not included.
- Public creator profiles are accessible from collection cards, but no global people search or standalone public profile route yet.
- App currently loads bounded result sets (up to 500 lists and profiles and 3,000 list items), so pagination and server-side search are needed before large-scale growth.
- Sorting of newly tied rankings is not curated. Anti-manipulation/rate limits beyond unique saves are not yet present.
