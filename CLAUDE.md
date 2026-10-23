# CLAUDE.md — Tintara Lab

Instructions for every agent in this repository (orchestrator, implementation and QA). Read this file completely before doing anything.

## 1. Project in one paragraph

Tintara Lab is a portfolio web app for a photographer (Luisa Sanabria, Medellín, Colombia). The public site is one long server-rendered page in Spanish: Landing → Field Experience → Portfolio → Services → About Me → Contact. It has no visitor login. An admin area under `/admin` lets admins edit all content. The monorepo holds a Rails 8.1 API (`apps/api`) and a React Router framework-mode app in TypeScript (`apps/web`). Data lives in PostgreSQL (Docker in development) and images in Cloudinary (direct signed uploads). All code and documentation are in **English**; site content is in Spanish.

## 2. The handoff is the source of truth

`handoff/` is the project's memory. Anything that isn't in the handoff doesn't officially exist.

| Path | What it holds | Who writes |
|---|---|---|
| `handoff/status/current-status.md` | Current phase, done / in progress / next, blockers, Feature & fix counters | Orchestrator |
| `handoff/decisions/decision-log.md` | Every decision with rationale and rejected alternatives (D-XXX) | Orchestrator |
| `handoff/plan/master-plan.md` | Phases and tasks | Orchestrator |
| `handoff/plan/api-contract.md` | API contract (written before Phase 3) | Orchestrator |
| `handoff/prompts/implementation/` | One prompt per implementation task | Orchestrator |
| `handoff/prompts/qa/` | One prompt per QA task | Orchestrator |
| `handoff/agent-outputs/implementation/` | One report per implementation task | Implementation agents |
| `handoff/agent-outputs/qa/` | One report per QA task | QA agents |
| `handoff/learning/` | One teaching chapter per task: how to build this app step by step (D-064) | Implementation agents |
| `handoff/templates/` | Required shapes for prompts, reports and learning chapters | Orchestrator |
| `handoff/Answers.md`, `handoff/FinalAnswers.md` | Owner's discovery answers (read-only) | Owner |
| `handoff/PC view mockup.jpeg`, `handoff/mobile view mockup.jpeg` | Visual reference (read-only) | Owner |

### Reading order for every agent
1. This file.
2. `handoff/status/current-status.md`
3. `handoff/decisions/decision-log.md`: at minimum, every entry your task references.
4. `handoff/plan/master-plan.md`: your task and its phase.
5. Your prompt file.
6. The outputs of the tasks your prompt depends on.

## 3. Roles

### Orchestrator
- Owns decisions, plan, status, prompts and templates.
- Validates agent outputs together with the owner before the next task starts.
- Assigns each task's `Feature N` or `fix N` number and records the counters in the status file.

### Implementation agent
- Does exactly what its prompt says: nothing more, nothing less.
- Works on its own branch and opens a PR. **Never merges.**
- Writes its report to `handoff/agent-outputs/implementation/` using `handoff/templates/implementation-output.md`.
- Writes its learning chapter to `handoff/learning/` using `handoff/templates/learning-chapter.md` (D-064). Both files are committed inside its own PR.
- **Does not edit** the decision log, status, plan or prompts. Proposals and questions go in the report.

### QA agent
- Verifies one PR against its prompt's acceptance criteria, the decision log and this file.
- **Does not change application code** and does not push to the PR branch.
- Also verifies the learning chapter: every command and file content in it must match what the PR actually contains, and its explanations must be correct (D-064). A wrong chapter is a finding like any other.
- Writes its report to `handoff/agent-outputs/qa/` using `handoff/templates/qa-output.md`, with a verdict: `PASS`, `PASS WITH NOTES` or `FAIL`.

### Owner (human)
- Dispatches agents, reviews reports with the orchestrator, and **is the only one who merges PRs**, using squash merge.

## 4. Non-negotiable rules

1. **Don't make anything up.** If a requirement, value, name or behavior isn't in the prompt, the decision log or this file, stop and list it under "Questions for the owner" in your report. Never silently assume. Never contradict an Accepted decision; if you think one is wrong, say so in your report.
2. **Verify versions and facts** (library versions, platform limits, APIs) from official sources or the installed tools. Report the versions you pinned (D-055).
3. **Spec-driven development** (D-042, D-050):
   - Write the RSpec or Jest spec first, commit it, then implement until it passes.
   - The spec commit comes before the implementation commit in the branch history.
   - No behavior ships without a spec.
4. **Never commit secrets.** Credentials go in Rails credentials or environment variables. Commit `.env.example` files, never `.env`.
5. **Lint and tests must pass locally** before opening a PR. Paste the command outputs, or their summaries, into your report.
6. **Stay in scope.** Unrelated improvements go in the report as suggestions, not in the code.
7. **English only** in code, comments, commits, PRs and handoff documents. Spanish only in user-facing site strings.

## 5. Git and PR conventions (D-021, D-034, D-035, D-048, D-049)

- **Base branch:** `main`. The repo is `Myepes05/tintara-lab`, readable by everyone since 2026-09-15 (D-059), so never commit anything that should stay unpublished.
- **Branch names:** `feature/N-<slug>` and `fix/N-<slug>`. The prompt gives you N and the slug.
- **PR title** = squash commit on main. It must be exactly `Feature N: <one-line summary>` or `fix N: <one-line summary>`, with that casing.
- **Commits inside the branch** use the same prefix: `Feature N: add specs for ...`, `Feature N: implement ...`.
- **N counts PRs**, with a separate counter per type (`docs N` counts commits; see below). Never choose N yourself; use the one in your prompt.
- **One task = one branch = one PR.**
- **PR description:** what changed, how it was tested, a link to your report file, and the decision IDs it implements.
- **Merging:** only the owner merges (squash). Agents never merge, force-push to `main`, or rewrite `main`'s history.
- **Exception:** `Feature 1` is committed directly to `main` (D-049).

### Committing handoff documents (D-053)
- **Handoff-only changes** (prompts, status, decisions, plan, templates, QA reports) are committed **directly to `main`** as `docs N: <brief summary>`. Only the orchestrator does this, only with the owner's approval. `docs` has its own counter, and N counts commits.
- **Implementation agents** commit only their own report file and their learning chapter, inside their PR. They touch no other `handoff/` file unless their prompt says so.
- **QA agents** write their report as an **untracked file and never commit it**. When done, switch back to `main`; the orchestrator commits the report.
- **Before starting**, confirm `git status` on `main` is clean and `git pull` succeeds. If `main` has uncommitted handoff changes, stop and report it.

### One shared checkout (D-068)
Every agent and the orchestrator work in the **same folder**, so whichever branch one of them leaves checked out is the branch the next one finds.
- **Every agent, implementation and QA alike, ends its session on `main`**: `git switch main` after its last push. Untracked build output of an unmerged app may appear there; that is expected, and nobody stages it.
- **Before any `docs N` commit**, the orchestrator confirms `git branch --show-current` prints `main`, stages **explicit paths only** (never `git add -A` or `git add .`), and confirms the push actually moved `origin/main`.
- **Only one agent works at a time.** The owner never runs an agent while another agent, or the orchestrator, is changing files.

### Fixing QA findings (D-054)
- **Where fixes happen:** findings on an open PR are fixed **in the same PR, before merging**:
  1. A fix-round prompt (`feature-NNN-<slug>-fix-rK.md`) sends the implementation agent back to the same branch.
  2. The agent's commits are prefixed `Feature N: fix <finding>`.
  3. The agent adds a "Fix round K" section to its report.
  4. A QA re-check follows (`qa-feature-NNN-<slug>-rK.md`).
- **What must be fixed:** `blocker` and `major` findings, before merging. For `minor` and `nit` findings, the owner decides.
- **`fix N` PRs** are only for bugs in code already merged into `main`.

## 6. Architecture essentials (details in the decision log)

### Monorepo layout (D-032)
```
apps/api/                      Rails 8.1 API (Ruby 3.4.3)
apps/web/                      React Router framework mode, TypeScript, Tailwind, pnpm
docker-compose.yml             Postgres only (D-030)
.github/workflows/api.yml      RuboCop + RSpec (D-033)
.github/workflows/web.yml      ESLint/Prettier + TypeScript + Jest + Build (D-033)
                               both: every PR runs both, pushes to main are path-filtered (D-065),
                               token is read-only (D-066)
handoff/
CLAUDE.md
```

### API (`apps/api`)
- **Routes:** API mode, versioned under `/api/v1` (D-031). Public endpoints live under `/api/v1/public/...`; admin endpoints under `/api/v1/admin/...`.
- **Authentication:** Rails 8 authentication generator (no Devise), a `sessions` table, and a signed session cookie that is httpOnly, Secure in production, `SameSite=Lax` and host-only (D-016, D-039).
- **CORS:** rack-cors allows only the frontend origin from an environment variable, with credentials enabled. CSRF tokens come from an API endpoint and are sent back in the `X-CSRF-Token` header, plus an Origin check (D-039).
- **Rate limits:**
  - Rails `rate_limit`, backed by Solid Cache, with the values from D-029.
  - Server-side rendering requests that carry a valid `X-Internal-Token` are exempt from the public per-IP limit (D-045).
  - The test cache store must support rate-limit specs.
- **Background jobs and mail:** Solid Queue for `deliver_later`; Gmail SMTP configured through environment variables (D-014, D-015). Solid Cache and Solid Queue use the primary database (D-052).
- **Images:** store the Cloudinary `public_id`, `width` and `height`, never URLs (D-024). Albums reference their cover with `albums.cover_photo_id` (D-026). Model: D-027.
- **Domain rules to always respect:**
  - Singletons (D-008).
  - Every album has at least one category; a category can't be deleted if that would leave an album without one (D-012).
  - Admin rules (D-017).
  - Honeypot on the contact form (D-013).
- **Tooling:** RSpec, FactoryBot, RuboCop.

### Web (`apps/web`)
- **Rendering:** the public page (`/`) is server-rendered and loads data through **one** call to `GET /api/v1/public/site` (D-018, D-046), using `API_INTERNAL_URL` and `X-Internal-Token`. It returns `Cache-Control: s-maxage=60, stale-while-revalidate=300` (D-045).
- **Admin:** `/admin/*` is client-rendered. It calls the public API base URL (an environment variable) with `credentials: 'include'`.
- **Styling:** Tailwind. Material UI only with a recorded decision (D-005).
- **Tests:** Jest, React Testing Library and jsdom (D-020). No Playwright (D-022). Read environment values through a config module that tests can mock, never with `import.meta.env` directly in components.
- **Images:** built through a Cloudinary URL helper (`f_auto`, `q_auto`, responsive widths, **2000 px maximum on the long edge**). Protection measures from D-025.
- **SEO baseline:** D-019.
- **Design:** the mockups are the visual reference; the brief wins when they differ. Excluded mockup sections: D-007. Fixed texts: D-006.

## 7. Local development (updated as tasks land)

Commands are filled in by the tasks that create them. If a command here is missing or wrong, report it; don't guess.

- **Postgres** (from the repo root, after `cp .env.example .env`): start `docker compose up -d` · health `docker compose ps` and `docker compose exec db pg_isready` · stop `docker compose down` (keeps the `db_data` volume) · logs `docker compose logs -f db`
- **API** (from `apps/api`, with Postgres running): install `bundle install` · database `bin/rails db:prepare` · server `bin/rails server` (http://localhost:3000, health check `GET /api/v1/health`) · specs `bundle exec rspec` · lint `bundle exec rubocop`. Credentials come from the root `.env`; no `apps/api/.env` is needed.
- **Web** (from `apps/web`, after `corepack enable` once per machine; Node from `apps/web/.node-version`): install `pnpm install` · dev server `pnpm dev` (http://localhost:5173) · specs `pnpm test` · lint `pnpm lint` and `pnpm format:check` · typecheck `pnpm typecheck` · build `pnpm build` · serve the build `pnpm start` (port 3000, or a random free port if 3000 is taken; it prints the URL; `PORT=<port> pnpm start` fixes it). Variables are documented in `apps/web/.env.example`; nothing requires them yet.

## 7b. The learning chapter (D-064)

Every implementation task ends with a chapter in `handoff/learning/`, written with `handoff/templates/learning-chapter.md`. Its purpose is that the owner can rebuild an app like this alone, so:

- **Teach, don't report.** The report proves the work; the chapter explains how to do it. Don't just restate the report.
- **Explain terms** the first time they appear, and say why each choice was made, including the ones that were rejected.
- **Use real content**: the actual commands you ran and the actual files you wrote. Never invent illustrative examples.
- **Write down the traps**: what failed first, what looks right but isn't, what you deliberately did not do and why. This is the most valuable section.
- **Make it reproducible**: someone following the chapter from the previous chapter's end state must reach the same result.
- Name the file `NN-<slug>.md`, where NN matches the task order, and add its row to `handoff/learning/README.md`.

## 8. Report requirements (summary)

Every agent report follows its template in `handoff/templates/` and must include:
- the task, branch, PR URL and status
- the decision IDs applied
- the commands run, with their results
- an acceptance-criteria checklist
- deviations, questions for the owner, and suggested follow-ups

A report without test and lint evidence is incomplete.
