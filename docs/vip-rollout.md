# BizHunt VIP rollout

- The official marketing page is `/vip/`; the home page links to it on desktop and mobile.
- The founder-only lead inbox is `/vip/leads/`; sign in using an approved BizHunt founder account.
- Apply `supabase/migrations/20261125_vip_inquiries.sql` to an isolated staging database first, and run the read-only verification SQL. Confirm the founder allowlist exists.
- Test a synthetic inquiry, consent validation, deduplication, founder retrieval and status changes in the isolated environment. Confirm non-founder accounts cannot read or change leads. Do not test real submissions on production during preview.
- On launch, apply the reviewed migration to production before merging the website PR. The form reports failure if the migration is not installed.
- This new inbox is separate from the original private concept site's lead database; do not transfer personal information without a reviewed migration.
- Before wider public promotion, configure service-side abuse prevention/rate limits and email alerts using an approved delivery service. The form deduplicates repeated email/business pairs and validates inputs, but this is not comprehensive bot protection.
- The rollback SQL disables the endpoints while preserving collected data.
- The VIP membership program remains a proposed feature; no paid subscription or membership entitlements are enabled by this marketing page.
