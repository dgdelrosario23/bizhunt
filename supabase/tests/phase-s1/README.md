# BizHunt Phase S1 regression suite

Local-only database regression baseline: 71 checkpoints across five stages (16, 13, 14, 14, 14). The original suite passed on Windows on 2026-11-24.

## Prerequisites

Windows PowerShell, Docker Desktop (desktop-linux context), and a disposable local Supabase database container named `supabase_db_BizHunt-Local-Test` with the Phase S1 schema and migration applied. Use an empty application dataset with synthetic fixtures only; no production data, queued jobs, live integrations or external notification endpoints. Verify the Docker context points to your own local engine. Do not run individual SQL files against production. Stage 5 invokes the notification worker, which may process existing queued jobs.

## Run

From this directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run-s1-regression.ps1
```

Expected: `SUCCESS: 71/71 checkpoints passed.` and exit code 0. Each SQL script ends in ROLLBACK. The runner checks script hashes, ordered PASS notices, exit codes and rollback output. Keep generated logs private. Do not commit database backups, exports, credentials or logs. Preserve SQL bytes; if intentionally updating a test, review the changes, update its hash and expected count in the runner, and rerun the suite.

These tests cover selected database workflows, not complete API/UI coverage or backup restoration. No migrations are executed by the runner. Never use the suite as a production deployment command.
