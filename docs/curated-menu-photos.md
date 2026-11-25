# Community listing menu photos

## Rollout

1. Apply `supabase/migrations/20261125_curated_menu_photos.sql` in the Supabase SQL Editor before deploying the UI.
2. In Founder Dashboard → Community listings, edit a listing. In Menu photos, select multiple images, reorder or remove them, then click **Save menu photos**.
3. Reopen the listing to verify the saved order. In Discover, open the listing's Menu tab and tap a photo to zoom.
4. Confirm that registered merchant menus still open and that a non-founder cannot save community menu photos.

Menu images use the existing founder-managed media bucket and are kept separate from gallery images. Removing a page removes its public listing reference, not the underlying object. The menu save is audited and rejects stale edits.

## Claim handoff

The existing claim review records approval only; it does not transfer ownership or associate a curated listing with a registered merchant. Menu paths stay on the curated record. During the existing manual, verified claim handoff, copy the original menu images into the merchant's Menu editor before archiving the curated listing. Do not infer ownership or transfer photos based on a matching business name alone.
