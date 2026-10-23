# BizHunt Phase 3 — Supabase backend setup

The customer and merchant apps currently remain **local-only demos**. This directory introduces the database and secure merchant operations; it does not silently switch the public app to production.

## Setup
1. Create a Supabase project at https://supabase.com/dashboard.
2. Open **SQL Editor**, paste the full contents of `supabase/schema.sql`, and run it on a new project.
3. In **Authentication → Providers**, enable email authentication. Configure your production redirect URLs and email verification settings.
4. Find **Project URL** and **publishable (anon) key** in Supabase's API settings. Never commit the service-role or secret key, database password, or any customer personal data.
5. Before wiring the frontend, create two test users: one merchant and one customer. The merchant creates a business and campaign; only the merchant can call the secured stamp/redeem functions.

## Important boundaries
- GitHub Pages hosts static frontend files; Supabase handles accounts and database.
- The SQL enables RLS. Public visitors can read business listings and active campaigns, but not private loyalty events.
- Stamp and redemption functions validate merchant ownership server-side. Customers cannot issue their own stamps.
- This is **not yet production-ready**: add idempotency, transactional concurrency locking, abuse/rate limits, merchant verification, audit trails, data privacy notices, and secure customer identification before a real pilot.
- In particular, avoid using raw customer UUIDs as an in-store verification mechanism. Use expiring one-time visit tokens issued after customer sign-in.
- If you rerun schema.sql after it was already applied, policy creation may error; use a migration workflow for subsequent schema changes.

## Next implementation milestone
Build login and signup screens, Supabase client initialization with the project URL/publishable key, business and campaign CRUD, and a verified QR/one-time-code workflow. Keep the demo route available until these flows have been tested.
