# BizHunt staging setup (GitHub Pages)

## Purpose
Preview `phase-b3-first-stamp-guide` without changing production `main` or its GitHub Pages settings.

## One-time setup (GitHub UI)
1. Create a separate **public** repository named `bizhunt-staging` under your GitHub account. GitHub Pages on a free personal account generally requires a public repository. **Do not copy credentials or secrets.**
2. In the production repository, select branch `phase-b3-first-stamp-guide`, choose **Code > Download ZIP** and extract it.
3. Upload the extracted site files and directories **at the root** of `bizhunt-staging` (not inside a nested folder). Verify `hub/index.html` is present. Do not upload `.env`, credentials, service-role keys, private files or customer exports.
4. In the staging repository, open **Settings > Pages > Build and deployment > Deploy from a branch**, select `main` and `/(root)`, then Save.
5. Wait for GitHub Pages to report the published URL. It will typically be `https://<username>.github.io/bizhunt-staging/` unless account/repository settings differ. Open `<published URL>/hub/`.
6. In Supabase Auth URL Configuration, check whether the staging callback/redirect URL must be added to the permitted redirect URLs for your sign-in flow. Add only the required staging URL(s), and do not change the production Site URL. Verify redirects before attempting sign-in.
7. Use dedicated test accounts and businesses. **This static staging copy still points at whichever Supabase project the code configures**; staging is not isolated from production data unless a separate backend is configured. Avoid real customer transactions, administrative actions and destructive tests.

## Phase B3 smoke test
- Campaign > Create > Design: eight colored boxes appear; native color input is absent.
- Clicking each box changes the selected outline/checkmark and the card preview color.
- Back/Continue/Review preserves the chosen color; publish only with test data in an isolated backend.
- Overview and Scanner: first-customer guidance appears when the selected business has no loaded transactions; buttons navigate to the appropriate existing screens.
- Switch between two test businesses; verify no cross-business campaign/transaction information appears.
- Check narrow/mobile viewport, keyboard focus, and the absence of horizontal overflow or visible scrollbars.

## Updating staging later
Replace the staging repository files with the files from the next feature branch, then allow Pages to redeploy. Keep the production repository's Pages settings unchanged. Do not merge PR #7 until checks pass.

## Security limitation
A publicly accessible GitHub Pages site cannot enforce private staging access by itself. Avoid using production credentials or confidential test content. For real end-to-end testing, configure a separate Supabase project and explicit staging environment settings before testing writes.
