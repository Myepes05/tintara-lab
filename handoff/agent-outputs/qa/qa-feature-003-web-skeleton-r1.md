# QA Report — Feature 3: create the React Router web skeleton with Jest, ESLint and CI (re-check, round 1)

- **Date:** 2026-09-17
- **PR / branch:** https://github.com/Myepes05/tintara-lab/pull/2 · `feature/3-web-skeleton`
- **Commit reviewed:** `a7ac6bcd210ed90eca4795912d6c0c08b36eab0d` (fix round `acb3ba3..a7ac6bc`, 9 commits)
- **Prompt:** `handoff/prompts/qa/qa-feature-003-web-skeleton-r1.md`
- **Previous QA report:** `handoff/agent-outputs/qa/qa-feature-003-web-skeleton.md` (FAIL on `acb3ba3`)
- **Verdict:** **PASS WITH NOTES.**
  - **F-1 to F-10:** all ten findings are fixed and verified independently. F-1 was checked in both directions: the spec fails at `7eb7df3` and passes at `ff41b9a`, and a throwaway throwing route shows the error details under `pnpm dev` and hides them in the production build.
  - **The round's new infrastructure** is faithful and honest as it stands.
  - **CI:** all six renamed checks pass on the current head.
  - **New findings:** one `minor` (a file count in chapter 03 that the round made stale) and two `nit`s. Nothing is `blocker` or `major`, so D-054 does not require another fix round.

## Checks run
```
# Setup
git status (main) clean except untracked apps/web/ (expected, D-068); git pull -> up to date
git switch feature/3-web-skeleton; git pull -> up to date, HEAD a7ac6bc, working tree clean
git log acb3ba3..HEAD -> 9 commits, all "Feature 3: fix …", author Myepes05

# A.1 F-1 grep (branch head)
grep -rn 'import\.meta\.env' apps/web/app ->
  app/vite-env.d.ts:2 (comment) · client-env.ts:4,7,21,23 (comments) · client-env.ts:25 DEV · client-env.ts:26 VITE_PUBLIC_API_BASE_URL
  Identical to the report's output. root.tsx:47 now reads `clientEnv.DEV`.
"Only reader" wording: client-env.ts:4-5, report summary line 11, PR body Summary bullet 2,
  chapter step 7 (line 814) and §5 (line 1525) all agree. The earlier step 7 / §5 contradiction is gone.

# A.2 Spec first (git archive into the scratchpad, pnpm install --frozen-lockfile, pnpm test)
7eb7df3: FAIL app/root.test.tsx; Test Suites: 1 failed, 3 passed, 4 total; Tests: 12 passed, 12 total
  error: app/root.tsx:46:14 - error TS1343: The 'import.meta' meta-property is only allowed when the '--module' option is …
  pnpm typecheck: client-env.ts(16,14): error TS2741: Property 'DEV' is missing … (disclosed as R-3)
ff41b9a: Test Suites: 4 passed · Tests: 14 passed (the F-9 specs arrive later in bc57c0a); pnpm typecheck exit 0

# A.3 Production behaviour of DEV (branch head, pnpm build, PORT=3191 pnpm start)
curl /nope -> HTTP/1.1 404; <main …><h1>404</h1><p>The requested page could not be found.</p></main>; no <pre>
build/client/assets/root-D0oGXDpP.js: var ge={DEV:!1,VITE_PUBLIC_API_BASE_URL:void 0} … ge.DEV&&e&&e instanceof Error&&(n=e.message,r=e.stack)
build/server/index.js: `DEV: false,` and `clientEnv.DEV && error && …`
acb3ba3 build (scratch): grep -c '\.stack' root-*.js -> 0 (the branch had been removed; trap 17 is accurate)
Thrown-error experiment (scratch copy of HEAD plus a throwaway /boom route whose loader throws "SECRET-DETAIL-boom"):
  production build: GET /boom -> 500, <h1>Oops!</h1><p>An unexpected error occurred.</p>, no SECRET-DETAIL, no <pre>
  pnpm dev:         GET /boom -> 500, SECRET-DETAIL-boom present (4x), <pre> present
  -> clientEnv.DEV is false in production and true in development; the shipped branch never runs in production.

# A.4 F-3
tsconfig.jest.json: only "verbatimModuleSyntax": false; "module" appears only in the comment
rm -rf .react-router; react-router typegen; jest --no-cache -> Test Suites: 4 passed · Tests: 16 passed

# A.5 F-4 (rendered by GitHub, not counted by hand)
gh api -H 'Accept: application/vnd.github.html' repos/…/contents/handoff/learning/03-web-skeleton.md?ref=a7ac6bc
  parsed HTML: <h3> "Step 1" … "Step 14 — Push and open the pull request (repository root)" all present as headings;
  60 <pre> blocks (the report says 60); no <pre> left open;
  the only heading-like lines inside <pre> are the three "## " lines of step 4's README listing (intended)

# A.6 F-5 (my own extraction script: CommonMark fences, byte comparison with the branch file)
.github/workflows/web.yml               166 lines -> chapter line 1158: identical
apps/web/jest.config.js                  42 lines -> identical
apps/web/tsconfig.jest.json              12 lines -> identical
apps/web/app/root.test.tsx               66 lines -> identical
apps/web/app/config/client-env.ts        27 lines -> identical
apps/web/app/config/public-config.ts     40 lines -> identical
apps/web/app/config/server-config.test.ts 83 lines -> identical
apps/web/.env.example                    45 lines -> identical
apps/web/test/stubs/client-env.ts        15 lines -> identical after dropping the leading "// path" line
api.yml lines 3-7 (D-065 comment) vs chapter step 11 quote -> identical

# A.7 F-8
gh pr view 2 --json body: Summary, Task (prompt + fix-round prompt + QA report), Decisions implemented,
  How it was tested (Lint/Tests), Implementation report (links), Checklist (6 items, ticked) -> matches the template

# A.8 F-9 mutations (scratch copy of HEAD, each reverted and verified with cmp)
no .trim() on apiInternalUrl    -> Tests: 1 failed, 15 passed
no .trim() on apiInternalToken  -> Tests: 1 failed, 15 passed
cached ??= -> cached =          -> Tests: 1 failed, 15 passed

# A.9 F-10
.env.example lines 10-11: "Never give a secret a VITE_ prefix: API_INTERNAL_URL and API_INTERNAL_TOKEN below must keep exactly those names."
client-env.ts:22-24 and chapter trap 8 carry the whole-object sentence.

# B.1 The jest.mock factory
Real implementation, react-router 8.3.1 dist/production/lib/router/utils.js:829-830:
  return error != null && typeof error.status === "number" && typeof error.statusText === "string"
         && typeof error.internal === "boolean" && "data" in error;
The mock has the same five conditions in the same order -> faithful.
react-router 8.4.0 (npm pack, utils.js:831-832): same body -> no drift at the next planned upgrade.
ErrorBoundary mutations (scratch copy, reverted):
  clientEnv.DEV -> true          -> 1 failed, 15 passed
  clientEnv.DEV -> !clientEnv.DEV -> 2 failed (both root tests)
  clientEnv.DEV -> false         -> suite fails to compile (TS18046); still a red run
  drop `stack = error.stack`     -> 1 failed
  drop `details = error.message` -> 1 failed
  never render <pre>             -> 1 failed
Mock mutations:
  drop the `"data" in` check      -> 16 passed (the tests pass only an Error, so the mock's precision is not exercised)
  return true for any object      -> root.test.tsx: 1 failed, 1 passed (a grossly wrong mock is caught)
jest-mock 30.5.1 build/index.js:846: replaceProperty adds its restore to _spyState; restoreAllMocks (877) runs them
  -> the chapter's "restoreAllMocks puts the stub's false back" is correct.

# B.2 typegen before jest (D-073)
rm -rf .react-router build; pnpm test -> "$ react-router typegen && jest", 4 suites, 16 tests pass
gh run view 35243546332 --job 105277812112 --log (Web Jest on a7ac6bc):
  "$ react-router typegen && jest" · "Test Suites: 4 passed, 4 total" · "Tests: 16 passed, 16 total"

# B.3 readPublicConfig signature
diff: only `env: ClientEnv` -> `env: Pick<ClientEnv, "VITE_PUBLIC_API_BASE_URL">` plus a doc comment; body unchanged

# B.4 Mapper comments
jest.config.js:32 "Needed since app/root.test.tsx: root.tsx imports app.css."; test/stubs/style.ts says the same
jest.config.js:34-35 and test/stubs/asset.ts: image mapper "Not used by any test yet … (Phase 4)"
CSS mapper removed (scratch) -> app/app.css:4 SyntaxError: Invalid or unexpected token (R-2 is accurate)

# C.1-C.3 Renamed checks
gh pr checks 2 (head a7ac6bc; runs API 35243546336, Web 35243546332, both success):
  API RSpec pass · API RuboCop pass · Web Build pass · Web ESLint pass · Web Jest pass · Web TypeScript pass
git diff acb3ba3..HEAD -- .github/workflows -> exactly six `name:` lines changed; nothing else
Live protection (gh api …/branches/main/protection, read only):
  dismiss_stale_reviews true, require_code_owner_reviews false, require_last_push_approval false, approvals 0,
  enforce_admins false, required_linear_history true, allow_force_pushes false, allow_deletions false,
  block_creations false, required_conversation_resolution true, lock_branch false, allow_fork_syncing false,
  no restrictions key, required_status_checks absent
  -> every field in the report's PUT payload matches; the payload lists the six new names with strict: false. Not run.
gh pr view 2 -> OPEN, MERGEABLE, CLEAN

# C.4 Chapters
Chapter 02 diff: one "Later changes" note after the api.yml listing (D-065 and D-071, both new names) -> accurate
grep for bare check names in chapters 01-03: chapter 02's listing (lines 472, 490) is the file as chapter 02 leaves it,
  covered by the note; chapter 03 lines 1348/1353 describe chapter 02's pre-rename file in the D-065 scenario (historical,
  followed immediately by the rename instruction); line 1545 names tools, not checks. No chapter presents an old name as current.

# D.1 Full suite from a fresh state (apps/web, branch head)
rm -rf .react-router build
pnpm install --frozen-lockfile -> "Lockfile passes supply-chain policies", "Lockfile is up to date", Done
pnpm lint          -> exit 0; eslint --format json: 21 files, 0 errors, 0 warnings
pnpm format:check  -> All matched files use Prettier code style!
pnpm typecheck     -> exit 0, no output
pnpm test          -> Test Suites: 4 passed, 4 total · Tests: 16 passed, 16 total (no console warnings)
pnpm build         -> exit 0, "✓ built in 296ms" / "✓ built in 53ms", no warnings or deprecations

# D.2 SSR
curl -si / -> HTTP/1.1 200, lang="es", <title>Tintara Lab</title>, <h1 class="text-3xl font-semibold">Tintara Lab</h1>

# D.3 .server boundary
grep -rlE 'API_INTERNAL|readServerConfig|getServerConfig|server-config|replace-me' build/client -> none

# D.4 Scope
git diff --stat acb3ba3..HEAD -> 18 files. Nothing outside apps/web, both workflows, chapters 02/03 and the Feature 3 report.
  Beyond the prompt's list: package.json `test` script (D-073) and public-config.ts `Pick` (R-1.3). Both are disclosed and justified.

# D.5 D-067 gaps (four of seven checked)
Gap 1: chapter line 141 shows "test": "react-router typegen && jest" in step 3                       -> closed
Gap 2: reader's-order reproduction (204cf7e + the final test-side files and scripts, pnpm test):
       4 suites fail with exactly the TS2307 lines the chapter shows (root.test.tsx:3:27 on ~/config/client-env) -> closed
Gap 3: step 7 (lines 788-800) gives the import and the new ErrorBoundary condition                   -> closed
Gap 5: lines 984 and 1588 show 4 suites / 16 tests                                                   -> closed

# E. Fix report
Claims checked against the report: see "Fix report accuracy" under Spec review. R-7: HEAD's jest.config.js has the rewrap (F-7)
and both mapper comments (F-6); HEAD's tsconfig.jest.json has no module override (F-3). 56f300a and 8a2299a carry them.

# Final
git switch main -> clean except untracked apps/web/ and this report
```

## Acceptance criteria verification
From the fix prompt, re-checked:

| Criterion | Result | Evidence |
|---|---|---|
| F-1 fixed: `grep` shows `import.meta.env` only in `client-env.ts` and `vite-env.d.ts`; an `ErrorBoundary` test exists and was committed first | Pass | A.1, A.2 (`7eb7df3` fails with TS1343, `ff41b9a` passes) |
| F-2 to F-10 addressed as described | Pass | A.4–A.9, B.4; chapter line 294 and line 299 for F-2 |
| Six jobs renamed; report command updated; `gh pr checks 2` shows six passing checks with the new names | Pass | C.1–C.3, on the current head `a7ac6bc` |
| lint, format:check, typecheck, test and build pass, with output in the report | Pass | D.1 re-run from a fresh state |
| Chapter 03 and affected chapter 02 text match the files exactly | Pass, with one stale count | A.6 (9 listings plus the `api.yml` comment identical). Line 1150's "20 files" is stale (N-1) |
| Commits prefixed `Feature 3: fix ...`, pushed to PR #2, not merged | Pass | 9 commits; PR `OPEN` |
| Session ends on `main` | Pass | `main` was checked out when this session started |

## Decision compliance
| Decision | Compliant? | Notes |
|---|---|---|
| D-020 / CLAUDE.md §6 | Yes | No component reads `import.meta.env`. `ErrorBoundary` reads `clientEnv.DEV`, which a test replaces with `jest.replaceProperty` |
| D-039 / D-045 | Yes | `build/client` is free of server-only names. Both bundles hard-code `DEV: false` |
| D-050 | Yes | `7eb7df3` (failing spec) precedes `ff41b9a`. `bc57c0a` adds specs for behaviour that already existed, and the mutations prove they are not vacuous |
| D-054 | Yes | Fixes are in the same PR, with `Feature 3: fix …` prefixes and a "Fix round 1" report section |
| D-065 / D-066 | Yes | Triggers and permissions are unchanged by the round |
| D-067 | Mostly | The seven listed gaps are closed (four verified). One count the round made stale (N-1) |
| D-068 | Yes | This session found `main` checked out and ends on `main` |
| D-070 / D-071 | Yes | Six prefixed names, `strict: false`, other fields match live protection. Not executed |
| D-072 | Yes | F-3 removed; F-6 kept with truthful comments; F-10 is documentation only (no code change needed) |
| D-073 | Yes | `test` = `react-router typegen && jest`; the CI log shows it running |
| D-074 | Yes | The mock is the documented stopgap. It is faithful to 8.3.1 and 8.4.0 (B.1) |
| D-069 / D-071 / D-072 / D-073 | Not re-filed | As instructed |

## Spec review
- **`root.test.tsx`:**
  - Both tests fail for real regressions in `ErrorBoundary`'s own logic: an inverted flag, a hard-coded flag, a dropped message, a dropped stack, and a never-rendered `<pre>` (B.1).
  - The stub default `DEV: false` matches production, and `restoreAllMocks` really restores the replaced property (verified in jest-mock's source).
- **What the mock hides:**
  - The tests pass only a plain `Error`, so they exercise only the "not a route error response" path of the copied `isRouteErrorResponse`. A slightly looser copy (without the `"data" in` check) still passes, but a grossly wrong one is caught.
  - The 404 / route-error branch of `ErrorBoundary` is untested. The round never claimed to test it, and `curl /nope` shows it works in the real build.
  - Nothing the test *claims* to verify is hidden by the mock.
- **Drift:**
  - The mock's comment names the source version and file (`react-router 8.3.1, dist/production/lib/router/utils.js`), so a maintainer reading the test can see where it came from.
  - Nothing *fails* on an upgrade, though. The status file's "bump React Router to 8.4.x" carry-over does not mention the copy (N-3).
  - Today the risk is nil: 8.4.0's body is identical, and D-074 plans to remove the mock.
- **Trap 17, the `DEV` dead-code trade-off:** acceptable, not a finding.
  - The shipped branch contains only rendering code, not data.
  - Both bundles fix `DEV` to `false`, and the production experiment shows the branch never runs.
  - The only way to flip it at runtime is script already running in the page, and such script already has full control.
  - The cost is a few bytes, and the gain is a real test plus compliance with §6. The chapter states this honestly.
- **F-9 specs:** the trim cases (URL and token) and the caching case each catch their mutation.
- **Fix report accuracy (12 claims checked, all true):**
  1. The `7eb7df3` failure text, and 12 passing tests.
  2. The `typecheck` TS2741 message at `7eb7df3`.
  3. The `{DEV:!1,VITE_PUBLIC_API_BASE_URL:void 0}` build content.
  4. `.stack` was absent at `acb3ba3`.
  5. The grep output.
  6. 60 fenced blocks.
  7. The 27-comparison claim (9 re-done).
  8. The `web.yml` 166-line identity.
  9. The mutation results (`1 failed`).
  10. The `Web Jest` log shows typegen.
  11. 21 linted files.
  12. R-2's `app.css:4 SyntaxError`, and R-6's reader's-order output (D.5, gap 2).

  Two more: the step 7 snippet lines ("lines 10–12 and 47") match `root.tsx`, and the live protection is unchanged.

## Learning chapter review
- **F-2:** row 1 quotes `…/test/setup-jest.ts`. Line 299 explains the load order correctly.
- **F-3:**
  - Line 392 explains that ts-jest forces CommonJS and cites the source, which the first pass verified.
  - Trap 18 is accurate.
  - The comment in `tsconfig.jest.json` names `verbatimModuleSyntax` as the one setting that matters.
- **F-4:** it renders correctly on GitHub (A.5).
- **F-5:** the full `web.yml` is given byte for byte. The `api.yml` comment is quoted, and its differing last sentence is pointed out.
- **F-6:** step 6 and §5 (line 1529) now say `"jest"` in `types` "makes the dependency explicit" and that `tsc` does not need it today. That is true, as the first pass verified.
- **New traps 15–19:** checked against the evidence.
  - Trap 16 (typegen on a fresh checkout) matches D-073 and the CI log.
  - Trap 17 is verified both ways (A.3).
  - Trap 19 matches R-7.
- **Chapter 02 note:** accurate, and the choice not to rename inside chapter 02's listing (R-5) is sound, because that listing is a historical file.
- **Reproducibility:**
  - The step 6 failure output reproduces exactly in the reader's order (D.5, gap 2).
  - Step 7 now includes both `root.tsx` edits.
  - The step 3 `package.json` and the step 7 / §8 counts are updated.
  - **Missed:** step 10's "lists 20 files" (N-1).
- **§5 wording (N-2):** it says "One line changed" about `root.tsx`'s `ErrorBoundary`, but the change is two lines: the new import and the condition. Step 7 gives both, so a reader following the steps is not misled.

## Findings
| # | Severity | Finding | Location | Steps to reproduce / evidence | Suggested fix |
|---|---|---|---|---|---|
| N-1 | minor | **Stale file count.** Chapter step 10 still says `pnpm exec eslint . --format json` "lists 20 files". This round added `app/root.test.tsx` in step 6, so a reader at step 10 gets 21, the count the report and PR body now state. The round's D-067 re-read updated the test counts but missed this one. Rated `minor` by the first pass's rule for inaccurate quoted output: the reader sees a different number from the chapter's check, but the conclusion (ESLint lints the files) still holds. | `handoff/learning/03-web-skeleton.md:1150` | `pnpm exec eslint . --format json` at `a7ac6bc` → 21 files, 0 errors, 0 warnings | Change "20 files" to "21 files" |
| N-2 | nit | **Understated change.** §5 says "One line changed" for `ErrorBoundary`, but `root.tsx` gained an import line as well as the changed condition | `handoff/learning/03-web-skeleton.md:1525` | `git diff acb3ba3..HEAD -- apps/web/app/root.tsx` → 1 line changed, 1 added | "Two lines changed: the `clientEnv` import and the condition" |
| N-3 | nit | **Silent drift risk.** The hand-copied `isRouteErrorResponse` in `root.test.tsx` is not mentioned in the dependency-upkeep carry-over note ("bump React Router to 8.4.x"). The drift is visible in the test's comment, but nothing fails if a future version changes the function. Today there is no drift: 8.4.0's body is identical. | `current-status.md` carry-over notes (orchestrator-owned); `apps/web/app/root.test.tsx:7-12` | `npm pack react-router@8.4.0`: `utils.js:831-832` is identical to 8.3.1's | Add "re-check the copied `isRouteErrorResponse` in `root.test.tsx`, or remove it via the D-074 spike" to the upgrade note. No code change needed |

## Security & conventions
- **Secrets:**
  - Nothing new is tracked beyond the 18 listed files.
  - `.env.example` still holds placeholders only.
  - `build/client` holds no server-only names.
  - The only value the new `DEV` read inlines is a boolean.
- **The `DEV` flag in production:** both bundles hard-code `false`, and error details and stack traces do not reach a production response (A.3).
- **Workflows:** only `name:` values changed. Triggers, permissions (`contents: read`) and action pins are untouched.
- **Conventions:**
  - Branch, PR title and commit prefixes are correct, and all commits are by the owner's account.
  - English everywhere.
  - The PR is open and not merged, and GitHub reports it `MERGEABLE` / `CLEAN`.
- **Environment note:**
  - **What:** a `react-router-serve` process from the shared checkout was already listening on port 3187 when I started (PID 16535, started 10:54, before this session). Most likely the implementation agent's `PORT=3187` server.
  - **What I did:** I did not stop it, because it isn't mine. My own servers (ports 3191, 3192 and 5198) were stopped.
  - **Why it matters:** it serves `apps/web/build`, which my D.1 run rebuilt. The owner may want to stop it with `kill 16535`.

## Questions for the owner
1. **N-1 and N-2** are one-word or one-phrase chapter fixes. Would you rather fix them before merging (a tiny fix round 2, no re-check needed beyond a diff read), or carry them as notes? Neither blocks merging under D-054.
2. **N-3** is an orchestrator-side note for the status file, not an agent task.
