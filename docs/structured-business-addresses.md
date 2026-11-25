# Structured business addresses and weekly hours

Deploy only after reviewing and applying `supabase/migrations/20261125_structured_business_addresses.sql` in Supabase. This migration adds nullable address components to both registered businesses and curated listings. Existing location strings and coordinates are not modified in bulk. The existing combined `location` value remains compatible with customer profiles, search, directions, and older clients.

New entries require a building/street/area, city or municipality, and province. Existing addresses are shown as editable suggestions; ambiguous addresses remain in the first field, with city and province blank. Saving an unrelated change does not rewrite an existing address. Completing or changing the three fields stores the components independently and updates the displayed address. Review any prefilled legacy components when editing an address.

Weekly hours are now the sole editable schedule in both founder editors. Existing merchant special-date hours remain supported. Customer profiles show today's schedule and an expandable weekly schedule. Unscheduled businesses show that hours are unavailable rather than relying on an old free-text description.

## Verification

- `node --test tests/business-address.test.cjs`
- Create a business in customer onboarding and check the three stored address components and combined location.
- Edit the registered business in Merchant Hub and Founder Dashboard; confirm the location pin remains unchanged.
- Add and edit a community listing, then check its public profile and weekly hours.
- Open a legacy listing and save unrelated details without changing its address; the original location must remain identical.
- Check menu photo upload and the existing registered merchant menu flow after deployment.
- Confirm an existing non-founder cannot use founder-only address mutation RPCs.
