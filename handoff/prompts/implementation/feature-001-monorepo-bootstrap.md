# Feature 1: push the first commit of the monorepo

**Type:** Implementation · **Phase:** 1 — Foundation
**Branch:** none. This task commits directly to `main`, the only exception to the PR rule (D-049).
**Commit message (exact):** `Feature 1: push the first commit of the monorepo`
**Report file:** `handoff/agent-outputs/implementation/feature-001-monorepo-bootstrap.md` (use `handoff/templates/implementation-output.md`)
**Working directory:** `/Users/miguelangel/Documents/projects/tintara-lab`

## Before you start
1. Read `CLAUDE.md` completely.
2. Read `handoff/status/current-status.md`.
3. Read these decisions in `handoff/decisions/decision-log.md`: D-021, D-030, D-032, D-034, D-035, D-037, D-049, D-053, D-055, D-057.
4. Skim `handoff/plan/master-plan.md` (Phase 1).

Depends on: nothing (first task).

## Goal
Turn the existing folder into a git repository with the root scaffolding and a working Postgres container for development, then publish it as the private GitHub repository `tintara-lab` with `main` as the base branch.

## Current state (verified by the orchestrator on 2026-09-13)
- The folder contains only `CLAUDE.md` and `handoff/`. It is **not** a git repository yet.
- Installed: git 2.53.0, Docker 29.2.1, gh 2.100.0, authenticated as `Myepes05` with the `repo` and `workflow` scopes.
- Re-verify all of this yourself before acting (`git --version`, `docker info`, `gh auth status`).

## Scope
### In scope
- Git initialization with `main`
- Root files: `.gitignore`, `.editorconfig`, `README.md`, `.env.example`, `docker-compose.yml`, `.github/pull_request_template.md`, `apps/.gitkeep`
- Updating `CLAUDE.md` §7, Postgres commands only
- Creating and pushing the private GitHub repo; configuring its merge settings
- Checking, and only reporting, whether branch protection is available

### Out of scope (do NOT do)
- Creating the Rails app or the web app, or anything inside `apps/` other than `.gitkeep` (Features 2 and 3)
- Any GitHub Actions workflow (Features 2 and 3)
- Configuring branch protection or rulesets (report only, D-057)
- Editing any `handoff/` file other than creating your report
- Committing your report (see step 11)

## Requirements

### 1. Initialize git
- Run `git init -b main` in the working directory.
- Do not change the global git configuration. If `user.name` or `user.email` isn't set, stop and ask the owner.

### 2. `.gitignore` (root)
At minimum, ignore:
- macOS files: `.DS_Store`
- editor folders: `.idea/`, `.vscode/` (but keep `.vscode/extensions.json` if one is ever added)
- env files: `.env` and `.env.*`, with an exception for `.env.example`
- `node_modules/`
- logs: `*.log`
- `coverage/`
- `tmp/`

App-specific ignores will come from the app generators in Features 2 and 3; don't add Rails or Vite entries now.

### 3. `.editorconfig`
- UTF-8, LF line endings, final newline, trim trailing whitespace.
- 2-space indentation.
- For `*.md`, don't trim trailing whitespace.

### 4. `docker-compose.yml` (root, D-030)
- **Project name:** `name: tintara-lab`
- **One service, `db`:**
  - The official `postgres` image, pinned to a **major version tag** (e.g. `postgres:NN`). Choose the latest stable major version, and check Railway's documentation for which Postgres versions its Postgres service offers, so development matches production. If the two differ or you can't verify, pin the latest major version Railway supports and explain in your report (D-055).
  - `POSTGRES_USER` and `POSTGRES_PASSWORD` come from environment variables, loaded from a root `.env`, with no hard-coded secrets in the compose file.
  - Port mapping `"${POSTGRES_PORT:-5432}:5432"`.
  - A named volume for data persistence.
  - A healthcheck using `pg_isready`.
  - `restart: unless-stopped`.
- **Port conflicts:** the owner has other projects on this machine. Before starting the container, check whether port 5432 is already in use (`lsof -nP -iTCP:5432 -sTCP:LISTEN`). If it is, don't stop anything that belongs to other projects. Set `POSTGRES_PORT` in your local `.env` to a free port, and report it.

### 5. `.env.example` (root)
- Contains `POSTGRES_USER`, `POSTGRES_PASSWORD` and `POSTGRES_PORT`, each with a comment.
- Values are clearly development-only placeholders.
- Create a local `.env` copy for your own verification. It must **not** be committed.

### 6. `README.md` (root, English)
- **Title:** Tintara Lab
- A one-paragraph description, taken from `CLAUDE.md` §1
- **Repository structure** (D-032):
  - `apps/api` and `apps/web`, both marked "coming in Feature 2 / Feature 3"
  - `handoff/`
  - `CLAUDE.md`
- **Prerequisites**, with the versions you verified on this machine: Ruby 3.4.3 (rbenv), Node 24, Corepack, Docker, gh
- **Getting started:** copy `.env.example` to `.env`, run `docker compose up -d`, check health, stop
- **How work is organized:** a short pointer to `CLAUDE.md` and `handoff/`, with the conventions summarized in 3–5 bullets. Don't duplicate `CLAUDE.md`.

### 7. `.github/pull_request_template.md`
Sections:
- Summary
- Task: `Feature N` / `fix N`, with a link to the prompt file
- Decisions implemented (D-XXX)
- How it was tested: lint and test results
- Implementation report link
- Checklist:
  - [ ] Specs committed before implementation (D-050)
  - [ ] Lint and tests pass locally
  - [ ] No secrets committed
  - [ ] English only
  - [ ] Scope matches the prompt
  - [ ] PR title follows `Feature N: ...` / `fix N: ...`

### 8. `apps/.gitkeep`
Creates the empty `apps/` folder (lowercase, D-032).

### 9. `CLAUDE.md` §7
Update only the Postgres line of section 7, "Local development", with the real commands to start, check health, stop, and view logs. Leave the API and Web lines unchanged.

### 10. Verify locally before committing
- `docker compose config`: valid, with no secret literals in the compose file.
- `docker compose up -d`, then wait until the `db` service is healthy.
- `docker compose exec db pg_isready`
- `docker compose exec db psql -U "$POSTGRES_USER" -c "select version();"`, loading the variables from `.env`.
- `docker compose down`, which keeps the volume. Don't use `-v`.
- `git status`: confirm that `.env` and `.DS_Store` files are **not** staged.
- Scan staged files for anything that looks like a secret.

### 11. Commit, create the repo, push
1. Stage everything **except** your report file, which you haven't written yet. It is committed later by the orchestrator as a `docs N` commit (D-053).
2. Commit with the exact message `Feature 1: push the first commit of the monorepo`.
3. Create the repo and push:
   `gh repo create tintara-lab --private --source=. --remote=origin --push`
4. Verify: `gh repo view tintara-lab --json name,visibility,defaultBranchRef,url`. It must show `PRIVATE` and default branch `main`.

### 12. Repository merge settings (implements D-034 and D-035)
Configure the repo so that squash merge is the **only** allowed merge method, and a squash commit takes the PR title as its title:
- `gh repo edit --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false`
- `gh api -X PATCH repos/{owner}/tintara-lab -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY`

Verify with `gh api repos/{owner}/tintara-lab --jq '{squash: .allow_squash_merge, merge: .allow_merge_commit, rebase: .allow_rebase_merge, title: .squash_merge_commit_title}'`.

If any of these settings aren't available on the owner's plan, don't work around it; report it.

### 13. Branch protection check (D-057, report only)
Run `gh api repos/{owner}/tintara-lab/branches/main/protection` and report the exact response. It will likely be either "Branch not protected" (available but not configured) or an error saying it requires a paid plan. **Don't configure protection.**

### 14. Write the report
Write `handoff/agent-outputs/implementation/feature-001-monorepo-bootstrap.md` using the template. Leave it **uncommitted**.
- **Spec-first section:** "N/A — no application code in this task".
- **Also include:**
  - the Postgres version you chose and why, with sources
  - the port used
  - the repo URL
  - the output of the merge-settings verification
  - the branch-protection response

## Acceptance criteria
- [ ] The folder is a git repo whose default branch is `main`, with exactly one commit: `Feature 1: push the first commit of the monorepo`
- [ ] The commit contains `CLAUDE.md`, all of `handoff/` (except your report), `.gitignore`, `.editorconfig`, `README.md`, `.env.example`, `docker-compose.yml`, `.github/pull_request_template.md` and `apps/.gitkeep`
- [ ] `.env` and `.DS_Store` files are not committed
- [ ] `docker compose up -d` brings up a healthy Postgres, and `select version()` works (output in the report)
- [ ] The Postgres image is pinned to a major version, with the choice justified and sourced
- [ ] The private GitHub repo `tintara-lab` exists, `main` is pushed, and it's the default branch
- [ ] Squash is the only merge method, and the squash title uses the PR title (or a plan limitation is reported)
- [ ] The branch-protection availability response is reported; nothing is configured
- [ ] `CLAUDE.md` §7 has real Postgres commands
- [ ] The report is written with the template and left uncommitted
- [ ] Nothing outside the scope was done

## Verification commands (include outputs or summaries in the report)
```
git log --oneline
git ls-files
git status
docker compose config
docker compose up -d && docker compose ps
docker compose exec db pg_isready
docker compose down
gh repo view tintara-lab --json name,visibility,defaultBranchRef,url
gh api repos/{owner}/tintara-lab --jq '{squash: .allow_squash_merge, merge: .allow_merge_commit, rebase: .allow_rebase_merge, title: .squash_merge_commit_title}'
gh api repos/{owner}/tintara-lab/branches/main/protection
```

## Questions
If anything is unclear or missing, or a command fails in a way this prompt doesn't cover, don't improvise. Record it under "Questions for the owner" in your report, and stop if it blocks you. Never delete or change anything outside `/Users/miguelangel/Documents/projects/tintara-lab`.
