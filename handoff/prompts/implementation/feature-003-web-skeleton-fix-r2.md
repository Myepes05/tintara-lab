# Feature 3 — fix round 2: two chapter 03 corrections

**Type:** Implementation (fix round on the open Feature 3 PR, D-054) · **Phase:** 1 — Foundation
**Branch:** `feature/3-web-skeleton` · **PR:** #2 — add to it, do not merge
**Commit prefix:** `Feature 3: fix ...`
**QA report:** `handoff/agent-outputs/qa/qa-feature-003-web-skeleton-r1.md` (on `main`; read its Findings table first)

## Before you start
1. `git switch main && git pull`, read the QA report, then `git switch feature/3-web-skeleton && git pull`. The head must be `a7ac6bc`; if it is not, stop and report it.
2. Re-read `CLAUDE.md` §5, "One shared checkout" (D-068): **end your session on `main`**.
3. Read decision D-076.

## Context
The QA re-check returned **PASS WITH NOTES**. The owner decided to fix N-1 and N-2 before merging (D-076). N-3 is an orchestrator-side note and is **not** part of this round.

This round changes **only** `handoff/learning/03-web-skeleton.md` and your implementation report. No application code, tests, workflows or other chapters change, so no spec commit is needed (D-050 covers behaviour; this is teaching text).

## Task 1 — N-1 (minor): stale file count in step 10
Line 1150 says `pnpm exec eslint . --format json` "lists 20 files". Since fix round 1 added `app/root.test.tsx`, the real count is 21.
- Run `pnpm exec eslint . --format json` from `apps/web` on the branch head and count the files yourself. Do not copy the number from this prompt.
- Put the number you counted in the chapter.

## Task 2 — N-2 (nit): understated change in §5
Line 1525 says "One line changed" about `root.tsx`'s `ErrorBoundary`. The change is two lines: the new `clientEnv` import and the changed condition.
- Confirm with `git diff acb3ba3..HEAD -- apps/web/app/root.tsx`.
- Reword the sentence so it states both changes, for example "Two lines changed: the `clientEnv` import and the condition."

## Task 3 — Re-read for other stale counts
Search chapter 03 for every other number that describes command output (file counts, test and suite counts, fence counts, line counts). For each one, confirm it still matches the branch head, or fix it. List what you checked in the report.

## Report
Add a "**Fix round 2**" section to your implementation report:
- one row per finding: what changed, with the line number
- the ESLint file count you measured, and the command output summary
- the `git diff` output from task 2
- the list from task 3
- `git diff --stat a7ac6bc..HEAD`, which must show only the chapter and the report

## Out of scope
- N-3 (the status file's upgrade note); the orchestrator handles it.
- Any change to `apps/`, `.github/`, chapter 02 or other `handoff/` files.

## Acceptance criteria
- [ ] N-1: step 10 states the measured file count, and it equals the real `eslint --format json` output
- [ ] N-2: §5 names both changed lines in `root.tsx`
- [ ] Task 3's re-read is listed in the report
- [ ] `git diff --stat a7ac6bc..HEAD` shows only `handoff/learning/03-web-skeleton.md` and the Feature 3 report
- [ ] The six CI checks still pass on the new head (`gh pr checks 2`)
- [ ] Commits prefixed `Feature 3: fix ...`, pushed to PR #2, not merged
- [ ] Session ends on `main`
