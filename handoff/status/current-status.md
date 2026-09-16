# Current Status

**Last updated:** 2026-09-15 by the orchestrator (session 1)

## Current stage: Phase 1 — Foundation · Feature 1 delivered, Feature 2 not started

### Done
- **Discovery and planning complete.** Decisions D-000 to D-061. `CLAUDE.md`, `handoff/templates/` and `plan/master-plan.md` v1 are in place.
- **Feature 1 (monorepo bootstrap): completed.** Commit `ab52b86` on `main`, pushed to https://github.com/Myepes05/tintara-lab
  - Root scaffolding: `.gitignore`, `.editorconfig`, `README.md`, `.env.example`, `docker-compose.yml` (Postgres 18), `.github/pull_request_template.md`, `apps/.gitkeep`.
  - `CLAUDE.md` §7 now lists the real Postgres commands.
  - Repository merge settings: squash only, squash commit title taken from the PR title.
  - Report: `agent-outputs/implementation/feature-001-monorepo-bootstrap.md` (still untracked; commit it as `docs 1`).
- **Owner decisions taken during Feature 1:** Postgres 18 (D-058); repository visibility opened to everyone and `main` protected (D-059, D-060).

### Orchestrator verification of Feature 1 (2026-09-15, in place of a QA agent — see D-061)
| Check | Result |
|---|---|
| `git log` | exactly one commit, `ab52b86 Feature 1: push the first commit of the monorepo` |
| `git ls-files` / `git status` | 25 files tracked; only the untracked report; no `.env`, no `.DS_Store` |
| `.gitignore` | correct, including the `.vscode/*` + `!.vscode/extensions.json` pattern |
| `docker-compose.yml` | `postgres:18`, no secret literals, `${POSTGRES_PORT:-5432}`, healthcheck, named volume mounted at `/var/lib/postgresql` (required by Postgres 18 images) |
| `.env.example` | three documented variables, development-only placeholders |
| `README.md`, PR template | complete and matching the prompt |
| `CLAUDE.md` §7 | Postgres line updated; API and Web lines untouched |
| Repository settings | `visibility: PUBLIC`, squash-only, squash title = PR title |
| Branch protection | active: PR required (0 approvals), linear history, no force pushes, no deletions, conversation resolution required, administrators not included |
| Container health | not re-run by the orchestrator: the Docker daemon was stopped. The report has the evidence (healthy, PostgreSQL 18.6, `pg_isready` accepting connections) |

**Verdict:** Feature 1 meets every acceptance criterion. No blocking findings.

### Owner decisions on 2026-09-15
- **Repository visibility (D-059):** keep it as it is; revisit making it private later. The orchestrator's concern stays on record.
- **D-061 accepted:** QA agents are dispatched only for tasks that produce application code. Feature 1 had none; QA resumes with Feature 2.
- Still open, not urgent: GitHub Issues are enabled on a repository anyone can read; consider disabling them.

### New in this session (2026-09-15)
- **D-064 accepted:** `handoff/learning/` now holds a teaching chapter per implementation task, written by the implementation agent inside its own PR and verified by QA. `CLAUDE.md` §2, §3, §5 and the new §7b, plus all four templates, were updated; `handoff/templates/learning-chapter.md` was added.
- **Backfill in progress:** Features 1 and 2 predate D-064, so their chapters are backfilled by the still-live Feature 2 agent through `prompts/implementation/feature-002-rails-api-skeleton-ext-learning.md`, committed to the open PR #1. QA then verifies code and both chapters in one pass.

### In progress
- **Feature 2** (Rails API skeleton): implementation finished. PR #1 https://github.com/Myepes05/tintara-lab/pull/1, branch `feature/2-rails-api-skeleton`, 5 commits, spec commit `d490ca9` before implementation `cdd649e`. Report delivered. The orchestrator has not reviewed the code yet.
- **Feature 2 extension:** done. Chapters 01 and 02 committed to PR #1 as `981349e`, documentation only.
- **Feature 2 QA:** prompt written at `prompts/qa/qa-feature-002-rails-api-skeleton.md`. Waiting for the owner to dispatch the QA agent.

### Orchestrator pre-review of PR #1 (2026-09-15)
Not a QA pass; QA still runs. What the orchestrator checked directly:
- 6 commits, spec `d490ca9` before implementation `cdd649e`. CI green on all three pushed heads.
- Solid Cache and Solid Queue tables live in `db/schema.rb` on the primary database; no separate cache or queue database is declared (D-052 satisfied).
- `database.yml` holds no credentials; dotenv reads the root `.env` and is assigned before the `Application` class.
- Health endpoint returns only `status` and `time`, and a spec asserts exactly that.
- Pinned actions verified upstream: `actions/checkout@v7` (latest v7.0.1) and `ruby/setup-ruby@v1` (that action's own convention). The chapter's claim that `setup-ruby` has no `ruby-version-file` input was verified against its `action.yml`: correct.
- Learning chapters are substantial and specific; the traps sections describe real failures.

**Risk found by the orchestrator, and its correct size (owner challenged the framing, 2026-09-15):** the root `.gitignore` does not ignore `*.key`. Inside `apps/api` the generated `.gitignore` covers `/config/*.key`, so the key is ignored on the feature branch and, once PR #1 merges, on `main` as well. The exposure is therefore a **window**, not a permanent hole: only while PR #1 is unmerged, and only if someone runs `git add -A` while `main` is checked out. The owner is the only person pushing, so the practical risk is small.

**Resolution:** the extension prompt `prompts/implementation/feature-002-rails-api-skeleton-ext-gitignore-keys.md` was written but **is not dispatched**. A round trip through the agent, chapter edits and QA re-verification is not worth a one-line defence-in-depth rule. The line is folded into the Feature 3 prompt instead, where an agent is editing the repository anyway. Until PR #1 merges, handoff commits on `main` stage explicit paths, never `git add -A`.
- New proposals the owner can object to: D-062 (RuboCop omakase), D-063 (Rails components skipped).

### Next
1. The owner dispatches Feature 2 from a new session.
2. The orchestrator reviews the report, then writes `prompts/qa/qa-feature-002-rails-api-skeleton.md` (QA applies from here on, D-061).
3. Fix rounds if needed (D-054), then the owner squash-merges the PR.
4. Commit the reports as the next `docs N`, then write the Feature 3 prompt (web skeleton).

### Carry-over notes for Feature 2 / Feature 3
- Read the host database port from `POSTGRES_PORT`, so it is configured in one place only.
- Once `api.yml` and `web.yml` have run on `main`, add them as required status checks in the branch protection (D-060).
- At deployment, pick Railway's Postgres 18 image explicitly; its `:latest` tag resolves to 16 (D-058).

### Counters (D-035, D-053)
- Last `Feature`: 1 (`Feature 2` assigned to the Rails API skeleton).
- Last `fix`: none (next is `fix 1`).
- Last `docs`: 1 (Feature 1 report + handoff updates + Feature 2 prompt).

### Blockers
- None technical. Git identity is configured; port 5432 was free.
