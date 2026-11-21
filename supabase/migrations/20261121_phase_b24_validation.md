# Phase B24 validation
- SQL is **not applied** by merging this branch.
- Confirm the function is SECURITY DEFINER, has an empty search_path, anon EXECUTE=false, authenticated EXECUTE=true.
- Test with actual authenticated merchant sessions: owner gets one row per owned campaign including zero-activity campaigns; non-owner gets zero rows; anon cannot execute.
- Cross-check stamp and redemption totals against source tables for a known business.
- Confirm no customer IDs are returned and multiple stamps are not labeled as verified visits.
- Frontend is not changed in this phase: 7/30/90-day filters still use recently loaded records. Integrate all-history RPC separately after deployment.
