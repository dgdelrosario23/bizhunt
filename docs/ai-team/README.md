# BizHunt AI Team v1

Seven repository-local specialist profiles for Codex, inspired by the role/mission/workflow/deliverable approach in [Agency Agents](https://github.com/msitarzewski/agency-agents). These are original BizHunt-specific instructions, not an imported framework. No external services, credentials, runtime endpoint or scheduler are installed.

| Agent | Use for |
| --- | --- |
| `bizhunt_product_lead` (Product Lead) | Prioritize BizHunt features and define acceptance criteria. |
| `bizhunt_frontend_engineer` (Frontend Engineer) | Implement mobile-first customer, merchant, founder and landing-page interfaces. |
| `bizhunt_backend_engineer` (Supabase Backend Engineer) | Prepare scoped database and application integration changes. |
| `bizhunt_qa_engineer` (QA and Reliability Engineer) | Verify feature behavior and regression coverage using local fixtures. |
| `bizhunt_privacy_reviewer` (Security and Privacy Reviewer) | Perform defensive source review and propose safe remediation. |
| `bizhunt_growth_marketer` (Growth and Content Strategist) | Create local acquisition, retention, positioning and content plans. |
| `bizhunt_merchant_success` (Merchant Success Specialist) | Design practical merchant onboarding, loyalty campaigns and partner support. |

## Use

Open the repository in a Codex environment supporting project agents in `.codex/agents/`. Explicitly request a specialist by name, e.g. “Use bizhunt_product_lead to define criteria for multi-branch loyalty; report only.” You can also read the TOML developer instructions and use them as a manual role brief in other environments. Client support and permissions vary; these profiles are instructions, not enforcement or proof of agent discovery.

For an implementation request, ask Product for scope if needed; Frontend or Backend for scoped changes; QA for verification; Privacy for defensive review when warranted. Growth and Merchant Success create drafts for founder review. Give each specialist the narrow assignment, applicable files, acceptance criteria, and environment. Lead integrates evidence and opens a PR only when authorized. Founder alone approves merge, production database changes, deployments, publishing or external outreach.

## Validation

From repository root run `python3 scripts/validate_ai_team.py` (Python 3.11+). This checks seven expected TOML profiles, identities, required keys, boundary phrases and documentation references; it does not execute agents or verify model behavior. Suggested manual smoke checks: request product acceptance criteria; request a compact UI assessment; request a migration draft without applying it; request QA test matrix; request defensive privacy review; request a Taglish draft; request a merchant onboarding checklist. Verify each remains within scope and reports unverified items. No live services are required.
