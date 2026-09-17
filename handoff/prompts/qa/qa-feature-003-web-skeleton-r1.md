# QA re-check (round 1) — Feature 3: create the React Router web skeleton with Jest, ESLint and CI

**Type:** QA re-check (D-054) · **Target:** PR #2, branch `feature/3-web-skeleton`, fix-round commits `acb3ba3..HEAD`
**Previous QA report:** `handoff/agent-outputs/qa/qa-feature-003-web-skeleton.md` (FAIL, reviewed `acb3ba3`)
**Fix prompt:** `handoff/prompts/implementation/feature-003-web-skeleton-fix-r1.md`
**Fix report:** the "Fix round 1" section of `handoff/agent-outputs/implementation/feature-003-web-skeleton.md` (on the branch)
**Report file:** `handoff/agent-outputs/qa/qa-feature-003-web-skeleton-r1.md` (use `handoff/templates/qa-output.md`)

## Rules
- Same rules as the first QA pass: do not modify anything, do not push, leave your report untracked, and **end your session on `main`** (D-068).
- This is a **re-check**, not a full re-audit. Verify each fix, look for regressions the fixes could have caused, and review the new infrastructure the round introduced. Don't re-file findings the first pass already accepted.
- Decisions already taken, not to be re-filed: D-069 (the original deviations), D-071 (renamed checks), D-072 (fix scope), D-073 (`pnpm test` runs typegen first).

## Before you start
Read the fix prompt, the fix-round section of the report, your predecessor's QA report, and decisions D-071 to D-075.

## A. Every finding, verified
For F-1 to F-10, confirm that the fix exists, matches the fix prompt, and is correct. In particular:
1. **F-1:** `grep -rn 'import\.meta\.env' apps/web/app`. The only non-comment reads must be in `client-env.ts`. `ErrorBoundary` reads `clientEnv.DEV`. The "only reader" claim is consistent in the `client-env.ts` comment, the report summary, the PR body, and chapter 03 step 7 and §5.
2. **F-1 spec first:** check out `7eb7df3`, install, run `pnpm test`, and confirm that `root.test.tsx` fails there with the stated error while the other suites pass. Then check out `ff41b9a` and confirm it passes.
3. **F-1 production behaviour:** build, then `curl` a missing route. It must still be a 404, and the development-only details must not render. Look in `build/client` for how `DEV` is inlined, and judge the agent's note that the development branch now ships but never runs (chapter trap 17). Is that an acceptable trade-off, or a finding?
4. **F-3:** `tsconfig.jest.json` has no `module` override, and 16 tests pass with `--no-cache`.
5. **F-4:** the chapter renders on GitHub with step 14 outside any code block. Check it rendered, not only by counting fences.
6. **F-5:** spot-check the byte-identical claim for `web.yml` yourself (all 166 lines) and for at least three more listings.
7. **F-8:** the PR body follows the template.
8. **F-9:** repeat at least one of the agent's mutation checks (remove `.trim()`, or change `cached ??=` to `cached =`), confirm a test fails, and revert.
9. **F-10:** `.env.example` names both server-only variables.

## B. New infrastructure introduced by the round
1. **The `jest.mock("react-router", factory)` in `root.test.tsx`:**
   - Compare its copied `isRouteErrorResponse` with the real implementation in `node_modules/react-router` 8.3.1. Is it faithful?
   - What happens when React Router is upgraded (for example 8.4.x)? Is the drift risk visible to a future maintainer (comment, chapter), or silent?
   - Does the mock hide anything the `ErrorBoundary` test claims to verify? Would the test still catch a regression in `ErrorBoundary`'s own logic?
   - This workaround is known and has a planned replacement (D-074). Judge only whether it is safe and honest *as it stands*.
2. **`"test": "react-router typegen && jest"` (D-073):** confirm that a fresh state (`rm -rf .react-router`) passes locally, and that the `Web Jest` CI log shows typegen running.
3. **`readPublicConfig(env: Pick<ClientEnv, "VITE_PUBLIC_API_BASE_URL">)`:** type-only, and no behaviour changed.
4. **The CSS mapper is now used by `root.test.tsx`.** Its comment says so; the image mapper's comment still says it is unused.

## C. Renamed checks (D-071)
1. `gh pr checks 2` shows exactly the six new names, all passing, on the **current head** commit.
2. Only `name:` values changed in both workflows. Job IDs, steps, triggers and permissions are unchanged: `git diff acb3ba3..HEAD -- .github/workflows`.
3. The "Required status checks" command in the report lists the six new names, `strict: false`, and every other field matching the live protection settings (`gh api repos/Myepes05/tintara-lab/branches/main/protection`). **Do not run it.**
4. Chapter 02's note about later renames is accurate, and no chapter still names an old check as current.

## D. Regressions and scope
1. Full suite from a fresh state: `rm -rf .react-router build`, then `pnpm install --frozen-lockfile`, `pnpm lint`, `pnpm format:check`, `pnpm typecheck`, `pnpm test`, `pnpm build`. Everything passes, with zero warnings.
2. Server rendering still works (`curl /` contains the heading, `lang="es"` and the title).
3. The `.server` boundary still holds: `grep` in `build/client` finds no server-only names.
4. `git diff --stat acb3ba3..HEAD` touches nothing outside what the fix prompt allowed. Explain anything unexpected.
5. **The agent's D-067 re-read listed seven gaps it closed.** Pick at least three and confirm they are really closed.

## E. The fix report itself
Is the "Fix round 1" section accurate? Check at least five of its concrete claims. The agent disclosed a process slip (R-7) that it says was caught before committing. Confirm nothing of the kind reached the branch: the committed `jest.config.js` and `tsconfig.jest.json` contain the F-3, F-6 and F-7 edits.

## Verdict
`PASS`, `PASS WITH NOTES` or `FAIL`. Only `blocker` and `major` findings trigger another fix round (D-054).

## Final step
`git switch main`, and confirm `git status` shows only your untracked report and the untracked `apps/web` build folders.
