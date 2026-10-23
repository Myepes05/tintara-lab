# Current Status

**Last updated:** 2026-10-22 by the orchestrator

## Current stage: Phase 1 done · Phase 2 next (Feature 4)

## Where things stand

| Task | State | Where |
|---|---|---|
| Discovery and planning | Done | Decisions D-000 to D-070 · `plan/master-plan.md` v1 · `CLAUDE.md` · `templates/` |
| Feature 1 — monorepo bootstrap | **Merged** (`ab52b86`, direct to `main` per D-049) | Verified by the orchestrator, no QA agent (D-061) |
| Feature 2 — Rails API skeleton | **Merged** (`af4afec`, PR #1) | QA: PASS WITH NOTES, all findings fixed in fix round 1 |
| Feature 3 — web skeleton | **Merged** (`a528d21`, PR #2) | QA: FAIL → fix round 1 → PASS WITH NOTES → fix round 2 (text only), verified by the orchestrator (D-077) |
| Learning chapters | 01, 02, 03 merged | `learning/` (D-064, D-067) |

## Feature 3 — detail
- **Orchestrator verification (2026-09-17):**
  - All six CI checks pass: `ESLint`, `TypeScript`, `Jest`, `Build`, `RuboCop` and `RSpec`. The last two running on a web-only PR proves D-065 works.
  - Spec commit `204cf7e` precedes implementation `3e1052e`.
  - No `.env`, key file or build output is tracked.
  - `server-config.server.ts` exists and fails loudly on missing variables.
  - Scope outside `apps/web`: both workflows, the root `.gitignore`, the `CLAUDE.md` §7 Web line, two empty `apps/api/tmp` `.keep` files, the report, chapter 03 and its index row.
- **The report's ten deviations are accepted** (D-069).
- **QA (2026-09-17): FAIL.** One `major` (F-1: `ErrorBoundary` reads `import.meta.env.DEV` directly), four `minor`, five `nit`. Build, SSR, the `.server` boundary (proved by deliberately breaking it), tests, CI, versions and `.gitignore` all verified clean. Report: `agent-outputs/qa/qa-feature-003-web-skeleton.md`.
- **Fix round 1 (done, 2026-09-17):** all ten findings fixed; six checks renamed and green (`API RuboCop`, `API RSpec`, `Web ESLint`, `Web TypeScript`, `Web Jest`, `Web Build`); spec `7eb7df3` before `ff41b9a`; 16 tests. Verified by the orchestrator (D-075).
  - New infrastructure disclosed by the agent: a `jest.mock("react-router")` factory in `root.test.tsx` (React Router 8 ships only ES modules), and `pnpm test` running typegen first (accepted as D-073). The CSS mapper is now in use.
  - The agent's open question on testing real router components became **D-074 (accepted)**: a spike before Phase 4, on option (b) with (c) as the fallback.
- **QA re-check (2026-09-17): PASS WITH NOTES** on `a7ac6bc`. F-1 to F-10 verified fixed; all six checks green. New: N-1 `minor` (chapter 03 step 10 says 20 linted files, really 21), N-2 and N-3 `nit`. Report: `agent-outputs/qa/qa-feature-003-web-skeleton-r1.md`.
- **Fix round 2 (D-076):** the owner chose to fix N-1 and N-2 before merging. Text-only, so the orchestrator verifies it with a diff read and `gh pr checks 2`; no QA re-check. Prompt: `prompts/implementation/feature-003-web-skeleton-fix-r2.md`. N-3 is handled in the carry-over notes below.
- **Fix round 2 verified (2026-10-22, D-077):** only chapter 03 and the report changed; six checks green on `b634f9f`. PR #2 squash-merged as `a528d21`; both workflows passed on `main`.
- **Required status checks are live on `main` (D-070, D-077):** `strict: false`, the six D-071 names, tied to GitHub Actions (app `15368`). Applied by the owner on 2026-10-22; other protection fields unchanged.

## Next
1. The orchestrator writes the Feature 4 prompt (API security baseline, Phase 2) for the owner's review.
2. The D-074 spike (Jest with real React Router components) runs before any Phase 4 prompt.

## Open owner decisions
- **Not urgent:** GitHub Issues are enabled on a repository anyone can read; consider disabling them.

## Carry-over notes for later features
- **Feature 4:** `config/environments/test.rb` uses `:null_store`; rate-limit specs need a real cache store in test.
- **Phase 4, first loader:** Vite does not load `.env` into `process.env`, so development needs a way to supply `API_INTERNAL_URL` and `API_INTERNAL_TOKEN` (for example `node --env-file`).
- **Feature 14 or 18:** `root.tsx`'s `ErrorBoundary` still has the template's English text; user-facing strings must be Spanish.
- **Dependency upkeep:** bump React Router to 8.4.x and `@types/node` once they are past pnpm's release-age window. On every React Router upgrade, re-check the hand-copied `isRouteErrorResponse` in `apps/web/app/root.test.tsx` against the new version's `dist/production/lib/router/utils.js`, or remove it through the D-074 spike (QA N-3). Node 25+ no longer bundles corepack, so revisit CI and `CLAUDE.md` when upgrading Node.
- **When real components land:** consider `eslint-plugin-jsx-a11y` (accessibility supports D-019).
- **Deployment:** pick Railway's Postgres 18 image explicitly; its `:latest` tag resolves to 16 (D-058). Configure the Rails trusted proxies (D-029). Set `RAILS_MASTER_KEY`, or plain environment variables, on Railway.
- **Next PR that touches `web.yml`:** its comment says "the same five setup steps" but each job has six; fix the file and chapter 03's listing together (D-077).
- **Brakeman and bundler-audit** are installed but not run in CI; cheap to add to the API lint job once there is real code.

## Process notes for the next orchestrator
- **One shared checkout (D-068).** Before any `docs N` commit: check that `git branch --show-current` prints `main`, stage explicit paths only, and confirm `origin/main` moved. Assert every text replacement in edit scripts. The stray commit `beb2b45` sits on the merged `feature/2-rails-api-skeleton` branch and can be ignored or deleted.
- **Required checks:** every PR to `main` now needs the six checks green before it can merge. Direct `docs N` pushes still go through the owner's admin bypass.
- **Repository visibility (D-059):** readable by everyone, by the owner's choice. Nothing that should stay unpublished goes into git.
- **The Rails master key** is backed up by the owner (confirmed 2026-09-17).

## Counters (D-035, D-053)
- Last `Feature`: 3 (merged; `Feature 4` is next).
- Last `fix`: none (next is `fix 1`).
- Last `docs`: 12.

## Blockers
- None.
