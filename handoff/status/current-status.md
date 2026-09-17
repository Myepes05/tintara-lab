# Current Status

**Last updated:** 2026-09-17 by the orchestrator (session 1)

## Current stage: Phase 1 — Foundation · Feature 3 in QA

## Where things stand

| Task | State | Where |
|---|---|---|
| Discovery and planning | Done | Decisions D-000 to D-070 · `plan/master-plan.md` v1 · `CLAUDE.md` · `templates/` |
| Feature 1 — monorepo bootstrap | **Merged** (`ab52b86`, direct to `main` per D-049) | Verified by the orchestrator, no QA agent (D-061) |
| Feature 2 — Rails API skeleton | **Merged** (`af4afec`, PR #1) | QA: PASS WITH NOTES, all findings fixed in fix round 1 |
| Feature 3 — web skeleton | **Implementation done, QA pending** | PR #2, branch `feature/3-web-skeleton` |
| Learning chapters | 01, 02 merged · 03 in PR #2 | `learning/` (D-064, D-067) |

## Feature 3 — detail
- **Orchestrator verification (2026-09-17):**
  - All six CI checks pass: `ESLint`, `TypeScript`, `Jest`, `Build`, `RuboCop` and `RSpec`. The last two running on a web-only PR proves D-065 works.
  - Spec commit `204cf7e` precedes implementation `3e1052e`.
  - No `.env`, key file or build output is tracked.
  - `server-config.server.ts` exists and fails loudly on missing variables.
  - Scope outside `apps/web`: both workflows, the root `.gitignore`, the `CLAUDE.md` §7 Web line, two empty `apps/api/tmp` `.keep` files, the report, chapter 03 and its index row.
- **The report's ten deviations are accepted** (D-069).
- **QA prompt:** `prompts/qa/qa-feature-003-web-skeleton.md`. Waiting for the owner to dispatch it.

## Next
1. The owner dispatches the Feature 3 QA agent from a new session.
2. The orchestrator reviews the QA report; fix rounds per D-054.
3. The owner squash-merges PR #2.
4. Once both workflows have run on `main`: configure the six required status checks with `strict: false` (D-070, accepted). The full command is in the Feature 3 report.
5. Phase 2 begins with Feature 4 (API security baseline).

## Open owner decisions
- **Not urgent:** GitHub Issues are enabled on a repository anyone can read; consider disabling them.

## Carry-over notes for later features
- **Feature 4:** `config/environments/test.rb` uses `:null_store`; rate-limit specs need a real cache store in test.
- **Phase 4, first loader:** Vite does not load `.env` into `process.env`, so development needs a way to supply `API_INTERNAL_URL` and `API_INTERNAL_TOKEN` (for example `node --env-file`).
- **Feature 14 or 18:** `root.tsx`'s `ErrorBoundary` still has the template's English text; user-facing strings must be Spanish.
- **Dependency upkeep:** bump React Router to 8.4.x and `@types/node` once they are past pnpm's release-age window. Node 25+ no longer bundles corepack, so revisit CI and `CLAUDE.md` when upgrading Node.
- **When real components land:** consider `eslint-plugin-jsx-a11y` (accessibility supports D-019).
- **Deployment:** pick Railway's Postgres 18 image explicitly; its `:latest` tag resolves to 16 (D-058). Configure the Rails trusted proxies (D-029). Set `RAILS_MASTER_KEY`, or plain environment variables, on Railway.
- **Brakeman and bundler-audit** are installed but not run in CI; cheap to add to the API lint job once there is real code.

## Process notes for the next orchestrator
- **One shared checkout (D-068).** Before any `docs N` commit: check that `git branch --show-current` prints `main`, stage explicit paths only, and confirm `origin/main` moved. Assert every text replacement in edit scripts. The stray commit `beb2b45` sits on the merged `feature/2-rails-api-skeleton` branch and can be ignored or deleted.
- **Untracked `apps/web/build/` and `apps/web/.react-router/`** appear on `main` until PR #2 merges. Never stage them.
- **Repository visibility (D-059):** readable by everyone, by the owner's choice. Nothing that should stay unpublished goes into git.
- **The Rails master key** is backed up by the owner (confirmed 2026-09-17).

## Counters (D-035, D-053)
- Last `Feature`: 3 (in review; `Feature 4` is next).
- Last `fix`: none (next is `fix 1`).
- Last `docs`: 7.

## Blockers
- None.
