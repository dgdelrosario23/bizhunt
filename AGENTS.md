# BizHunt repository guidance

BizHunt is a mobile-first local discovery, loyalty, deals and community platform for Pampanga. It uses static HTML/CSS/JavaScript and Supabase. Inspect current files before assuming behavior.

- Customer: `app/index.html`; accounts: `account/index.html`; merchant: `merchant/index.html`; founder: `founder/index.html`; public site: `index.html`; shared code: `assets/`; database: `supabase/schema.sql` and applicable migrations.
- Preserve existing features; favor compact, accessible, mobile-first UI; hide visual scrollbars without disabling scrolling.
- Never expose secrets or personal data. Use isolated local fixtures; do not modify production Supabase, deploy or merge PRs without explicit founder approval.
- Inspect, implement and verify within the requested scope. Report changed files, actual test results, preview URL where supported, and blockers. Never claim unrun tests passed.
- For specialist help, see [BizHunt AI Team v1](docs/ai-team/README.md). Invoke specialists only when requested; the lead remains accountable for scope and verification.
