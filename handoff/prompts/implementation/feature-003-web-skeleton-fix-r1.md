# Feature 3 — fix round 1: QA findings and unique check names

**Type:** Implementation (fix round on the open Feature 3 PR, D-054) · **Phase:** 1 — Foundation
**Branch:** `feature/3-web-skeleton` · **PR:** #2 — add to it, do not merge
**Commit prefix:** `Feature 3: fix ...`
**QA report:** `handoff/agent-outputs/qa/qa-feature-003-web-skeleton.md` (on `main`; read it first)

## Before you start
1. `git switch main && git pull`, read the QA report, then `git switch feature/3-web-skeleton && git pull`.
2. Re-read `CLAUDE.md` §5, "One shared checkout" (D-068): **end your session on `main`**.
3. Read decisions D-066, D-067, D-069, D-070 and D-071.

## Context
QA returned **FAIL** because of one `major` finding (F-1). The owner and the orchestrator decided the following:
- **F-1** stays `major`, and gets fixed.
- **Every other finding** also gets fixed now. They are all small, and most are in teaching material.
- **F-3:** remove the redundant configuration.
- **F-6:** keep the forward-looking configuration, with truthful comments.
- **QA's question 3:** rename the CI check names now, before they become required (D-071).

Do not re-litigate these decisions. If you think one is wrong, implement it anyway and say why in your report.

## Task 1 — F-1 (major): no component reads `import.meta.env`
`app/root.tsx`'s `ErrorBoundary` reads `import.meta.env.DEV`, which breaks `CLAUDE.md` §6 and makes the "only reader" claim false.
- Expose the development flag through the config module: add it to `ClientEnv` (in `env-types.ts`), to `client-env.ts` (read by its full name, like the existing variable), and to the Jest stub.
- `ErrorBoundary` then reads it from the config module.
- **Spec first** (D-050): before changing `root.tsx`, commit a test proving the `ErrorBoundary` behaviour. It shows the error message and stack trace only when the development flag is on, and hides them otherwise. That test was impossible before (TS1343), which is part of why F-1 matters.
- Then make the "only reader" claim true everywhere it appears: the `client-env.ts` comment, the report, the PR body, and chapter 03 (step 7 and §5, which currently contradict each other).
- Verify with `grep -rn 'import\.meta\.env' apps/web/app`: the only matches must be in `client-env.ts` and the `vite-env.d.ts` type declaration.
- Leave `ErrorBoundary`'s English strings alone; translating them belongs to Feature 14 or 18.

## Task 2 — F-2 (minor): chapter Jest table, row 1
Quote the file that actually fails (`…/test/setup-jest.ts`), and add a sentence explaining that the setup file loads before any test.

## Task 3 — F-3 (minor): remove the redundant `module` override
Remove `"module": "CommonJS"` from `tsconfig.jest.json`, because ts-jest emits CommonJS anyway outside ESM mode. Confirm the tests still pass. In chapter 03, explain that ts-jest forces CommonJS on its own, and that the override that matters is `verbatimModuleSyntax: false`.

## Task 4 — F-4 (minor): broken code fence in step 13
Put the closing fence on its own line, so the "Step 14" heading renders again. Then check that **every** fence in the chapter is balanced, and report the count you checked.

## Task 5 — F-5 (minor): give `web.yml` in full
Include the whole `web.yml` in chapter 03, byte-identical to the file, as it stands **after** task 7's renames. Quote the real `api.yml` trigger comment instead of calling it "the same". Verify both by extraction and comparison, as the Feature 2 agent did, and report the result.

## Task 6 — F-6 (nit): keep the forward-looking pieces, with honest comments
Keep the CSS and image mappers and their stubs, and keep `"jest"` in `tsconfig.json` `types`.
- Comment the mappers as needed from the first component that imports CSS or an image (Phase 4).
- Reword chapter line 1236 to say the `types` entry makes the dependency explicit, not that `tsc` needs it today.

## Task 7 — Unique check names (D-071)
The job names are what GitHub reports as check names, and they will become required checks (D-070). Generic names like `Build` and `Jest` would be satisfied by any future workflow job with the same name, for example a deploy workflow's `Build`. Rename all six jobs with their app prefix:

| Workflow | Old name | New name |
|---|---|---|
| `api.yml` | `RuboCop` | `API RuboCop` |
| `api.yml` | `RSpec` | `API RSpec` |
| `web.yml` | `ESLint` | `Web ESLint` |
| `web.yml` | `TypeScript` | `Web TypeScript` |
| `web.yml` | `Jest` | `Web Jest` |
| `web.yml` | `Build` | `Web Build` |

- Change only the job `name:` values. Job IDs, steps and triggers stay as they are.
- Update the "Required status checks" command in your report so it lists the new names.
- Update chapter 02 or 03 wherever the old check names appear as reader-visible output. Check chapter 02 too: its CI walkthrough may quote them. Chapter 02 is already merged, so edit it in this PR.
- Confirm on the PR that the six new check names appear and pass: `gh pr checks 2`.

## Task 8 — Nits F-7 to F-10
- **F-7:** rewrap the long comment line in `jest.config.js` so the file matches the chapter's excerpt exactly.
- **F-8:** edit the PR #2 body into the shape of `.github/pull_request_template.md`, with Task and prompt link, Decisions, How it was tested, a report link and the Checklist.
- **F-9:** add a spec case for trimming (`" http://x "` → `"http://x"`) and one for `getServerConfig()` caching. Commit the specs first. Route tests can wait for Phase 4.
- **F-10:** name `API_INTERNAL_URL` and `API_INTERNAL_TOKEN` explicitly in `.env.example`'s warning. Add one sentence to the `client-env.ts` comment and to chapter trap 8: reading `import.meta.env` as a whole object inlines **every** `VITE_` variable, including a wrongly prefixed secret that no code references, which is why variables are read by full name.

## Report
Add a "**Fix round 1**" section to your implementation report:
- a row per finding: what changed and where
- the spec-first evidence for tasks 1 and 8, with SHAs
- the `grep` output from task 1
- the fence count from task 4, and the extraction and comparison result from task 5
- the renamed check list, and `gh pr checks 2` output
- your re-read of chapter 03 for D-067 gaps introduced by these edits

## Out of scope
- Translating `ErrorBoundary`'s strings; route tests; any design or data loading.
- Changing workflow triggers or permissions.
- Anything in `apps/api` other than chapter text.
- Running the required-status-checks command.

## Acceptance criteria
- [ ] F-1 fixed: `grep` shows `import.meta.env` only in `client-env.ts` and `vite-env.d.ts`; an `ErrorBoundary` test exists and was committed first
- [ ] F-2 to F-10 addressed as described
- [ ] Six jobs renamed; the report's command updated; `gh pr checks 2` shows six passing checks with the new names
- [ ] `pnpm lint`, `pnpm format:check`, `pnpm typecheck`, `pnpm test` and `pnpm build` pass, with output in the report
- [ ] Chapter 03 and any affected chapter 02 text match the files exactly
- [ ] Commits prefixed `Feature 3: fix ...`, pushed to PR #2, not merged
- [ ] Session ends on `main`
