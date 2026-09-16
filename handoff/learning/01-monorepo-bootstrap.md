# Chapter 01 — Monorepo bootstrap: git, Docker Postgres and the GitHub repository

**Task:** Feature 1 · **Decisions:** D-021, D-030, D-032, D-034, D-035, D-037, D-049, D-053, D-055, D-058, D-059, D-060 · **Code:** commit [`ab52b86`](https://github.com/Myepes05/tintara-lab/commit/ab52b86) on `main` (no PR, see D-049)

> **How this chapter was written.** It is a backfill. `handoff/learning/` was created by D-064 after Features 1 and 2 were already finished, so this chapter was reconstructed from three sources: the Feature 1 report (`handoff/agent-outputs/implementation/feature-001-monorepo-bootstrap.md`), the files themselves as they exist in the repository, and the live GitHub settings, which were re-queried while writing. Where the evidence does not say what happened, this chapter says so instead of guessing.

## 1. What we are building in this chapter

At the end of this chapter you have a git repository with one commit, pushed to GitHub, containing the root scaffolding that every later task depends on: ignore rules, an editor configuration, a README, an environment-file template, a pull-request template, and a `docker-compose.yml` that starts a PostgreSQL 18 database on your machine. You also have the repository's rules in place: squash-only merges, a protected `main`, and a naming convention for commits.

No application code exists yet. That is deliberate. The point of this chapter is that by the time you generate a Rails app (chapter 02) or a React app, the database already runs, the conventions already hold, and nothing you write has to be moved later.

## 2. What you need to know first

- **Monorepo.** One git repository holding several applications instead of one repository per application. Here it holds two: a Rails API and a React frontend.
- **git.** The version control system. A *repository* is a folder whose history git tracks. A *commit* is one recorded snapshot with a message. A *branch* is a movable name pointing at a commit; the main line of work here is called `main`.
- **Remote.** A copy of the repository hosted elsewhere, here on GitHub. `origin` is the conventional name for the one you cloned from or pushed to first.
- **Docker.** Software that runs programs in *containers*: isolated environments built from an *image* (a read-only template, for example `postgres:18`). You get PostgreSQL without installing PostgreSQL on your machine.
- **Docker Compose.** A tool that describes containers in a YAML file (`docker-compose.yml`) so you start them with one command instead of a long `docker run` line.
- **Volume.** Storage that lives outside the container, so data survives when the container is deleted and recreated. A *named volume* is one Docker manages for you under its own directory.
- **Healthcheck.** A command Docker runs inside a container on a schedule to decide whether the service is actually ready, not merely started. A database process can be up for a second before it accepts connections.
- **Environment variable.** A value passed to a process from outside it, so configuration and secrets stay out of the source code. Docker Compose reads them from a file called `.env`.
- **`gh`.** GitHub's official command-line tool. It talks to the GitHub API, so repository creation and settings can be done from the terminal instead of the web UI.
- **Squash merge.** A way of merging a pull request that collapses all its commits into a single commit on `main`. The branch's messy history disappears; one clean line remains.
- **Branch protection.** GitHub rules on a branch, for example "changes must arrive through a pull request" or "no force pushes".

## 3. Starting point

A folder on disk named `tintara-lab` (renamed from `photographer-portfolio`, D-037), containing only the planning material written before any code:

```
CLAUDE.md          instructions for every agent in the repository
handoff/           decisions, plan, status, prompts, templates, the owner's answers, the mockups
```

It was **not** a git repository yet, and there was no GitHub repository. Tools verified on the machine before starting (D-055 requires checking versions instead of assuming them): git 2.53.0, Docker 29.2.1, `gh` 2.100.0, Ruby 3.4.3, Node 24.14.0, Corepack 0.34.6.

## 4. Step by step

### Step 1 — Turn the folder into a repository, with `main` as the base branch

- **Command:**
  ```sh
  git init -b main
  ```
- **What it does:** creates the hidden `.git` directory and sets the first branch's name to `main`.
- **Why this way:** `-b main` states the branch name explicitly instead of relying on git's default, which has changed over time (`master` in older versions, configurable since 2.28). Every convention in this project — PR titles, branch protection, CI triggers — names `main`, so the name must be certain rather than inherited from whatever git version a machine happens to have.
- **What you should see:** `Initialized empty Git repository in .../tintara-lab/.git/`.

### Step 2 — Write `.gitignore` before anything else

- **File:** `.gitignore` (full content in section 5).
- **What it does:** tells git which paths never to track.
- **Why this way:** it comes first because the cheapest way to never commit a secret is for the rule to exist before the file does. Once a file is committed and pushed, deleting it later does not remove it from the history.
- **What you should see:** after creating `.env` in step 5, `git status` does not list it.

### Step 3 — `.editorconfig`

- **File:** `.editorconfig` (section 5).
- **What it does:** a standard, editor-agnostic file that sets indentation, character encoding and line endings for everyone who opens the project.
- **Why this way:** two apps in two languages, edited by several agents and by the owner, on macOS while CI runs on Linux. Pinning `end_of_line = lf` and `charset = utf-8` keeps diffs free of invisible whitespace-only noise.

### Step 4 — `README.md`

- **File:** `README.md`.
- **What it does:** describes the project, the repository layout, the prerequisite tool versions and the commands to start Postgres.
- **Why this way:** the README is what a human reads first; `CLAUDE.md` is the long protocol for agents. Keeping them separate means the README can stay short and practical.

### Step 5 — The environment-file split: `.env.example` (committed) and `.env` (never)

- **File:** `.env.example`
  ```sh
  # Local development only. Copy this file to .env and never commit .env.

  # Superuser name for the local Postgres container (development only).
  POSTGRES_USER=tintara_dev

  # Superuser password for the local Postgres container (development-only placeholder).
  POSTGRES_PASSWORD=dev_password_change_me

  # Host port mapped to the container's 5432. Change it if 5432 is taken on your machine.
  POSTGRES_PORT=5432
  ```
- **Command:**
  ```sh
  cp .env.example .env
  ```
- **What it does:** `.env.example` documents *which* variables exist and what they mean; `.env` holds the actual values on one machine. `.gitignore` tracks the first and ignores the second.
- **Why this way:** a newcomer cloning the repository can see exactly what configuration is required without anyone sending them a file over chat, and no real value is ever in the history. The values above are deliberately obvious placeholders for a database that only listens on your own machine — they are not credentials worth protecting, and treating them as if they were would teach the wrong lesson about the ones that are (Cloudinary keys, the Gmail app password) which never go in a committed file at all.
- **What you should see:** `git status` shows `.env.example` as a new file and says nothing about `.env`.

### Step 6 — `docker-compose.yml`: one service, Postgres only

- **File:** `docker-compose.yml` (annotated line by line in section 5).
- **Command:**
  ```sh
  docker compose up -d
  ```
- **What it does:** downloads the `postgres:18` image if needed and starts one container in the background (`-d`, detached).
- **Why this way:** Docker runs *only* the database (D-030). Rails and the frontend run directly on the machine, where they start faster, attach to a debugger, and reload code without rebuilding an image. The database is the one dependency that is genuinely annoying to install natively and that must match production's major version, so that is the one thing containerised. No Redis is in the file either: Rails 8 covers caching and background jobs with Postgres-backed components, so Redis would be a service to run, learn and pay for with nothing asking for it yet (D-028).
- **What you should see:**
  ```
  $ docker compose ps
  NAME               IMAGE         SERVICE   STATUS                   PORTS
  tintara-lab-db-1   postgres:18   db        Up 6 seconds (healthy)   0.0.0.0:5432->5432/tcp

  $ docker compose exec db pg_isready
  /var/run/postgresql:5432 - accepting connections
  ```
  `(healthy)` is the healthcheck answering, not just the container being up.

### Step 7 — `.github/pull_request_template.md`

- **File:** `.github/pull_request_template.md`.
- **What it does:** GitHub pre-fills every new pull request's description with this file.
- **Why this way:** the description then always carries the same sections — summary, task, decisions implemented, how it was tested, a link to the report, and a checklist — so a reviewer never has to ask for them. Chapter 02's pull request is filled straight from this template.

### Step 8 — `apps/.gitkeep`

- **Command:**
  ```sh
  mkdir apps && touch apps/.gitkeep
  ```
- **What it does:** creates the `apps/` directory that will hold both applications, with an empty placeholder file inside it.
- **Why this way:** **git does not track directories, only files.** An empty directory cannot be committed, so it would vanish for anyone cloning the repository. The convention is a zero-byte file, `.gitkeep`, whose only job is to give the directory something to contain. (The name is convention, not a git feature; Rails uses `.keep` for the same trick, which is why you will see both spellings in chapter 02.)
- **On the lowercase name:** `apps/`, not `Apps/` (D-032). macOS filesystems are case-insensitive by default, so both spellings work locally and the mistake is invisible; GitHub Actions runners (Linux) and the deployment platforms are case-sensitive, where `apps/api` and `Apps/api` are different paths. A path that resolves locally and 404s in CI is a miserable bug to chase, so the casing is fixed once, in writing, at the start.

### Step 9 — Verify the database before committing anything

- **Commands:**
  ```sh
  docker compose up -d
  docker compose ps
  docker compose exec db pg_isready
  docker compose exec db psql -U "$POSTGRES_USER" -c "select version();"
  docker compose down
  ```
- **What it does:** proves the container starts, becomes healthy, accepts connections and runs the version you think it runs.
- **What you should see:** `PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2) on x86_64-pc-linux-gnu`.
- **Why this way:** committing a compose file you have not run is committing a guess. `docker compose down` stops and removes the container and the network but **keeps** the named volume, because no `-v` flag was passed; the data is still there next time.

### Step 10 — The first commit, on `main`, with no pull request

- **Command:**
  ```sh
  git add -A
  git commit -m "Feature 1: push the first commit of the monorepo"
  ```
- **Why this way:** every other task in this project goes through a branch and a pull request (D-034). Feature 1 cannot: a pull request needs a base branch to merge into, and `main` does not exist until something is committed to it. D-049 records this as the single, deliberate exception.
- **The message format matters** (D-035): `Feature N: <one-line summary>` for planned work, `fix N: <summary>` for bugs found in already-merged code, `docs N: <summary>` for changes to `handoff/` only. Each type has its own counter, and the numbers are assigned in the task prompt so that two agents never pick the same one.

### Step 11 — Create the GitHub repository and force the commit convention

- **Commands:**
  ```sh
  gh repo create tintara-lab --private --source=. --remote=origin --push

  gh repo edit --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false
  gh api -X PATCH repos/Myepes05/tintara-lab \
    -f squash_merge_commit_title=PR_TITLE \
    -f squash_merge_commit_message=PR_BODY
  ```
- **What it does:** the first command creates the repository, adds it as the remote `origin` and pushes `main`. The second restricts merging to squash only. The third tells GitHub to build the squash commit's subject from the **pull request title** and its body from the PR description.
- **Why this way:** this is the mechanism that makes the naming convention real rather than aspirational. Because the only way to merge is a squash, and the squash subject is the PR title, `main`'s history is exactly the list of PR titles. If a PR is titled `Feature 2: create the Rails API skeleton with RSpec, RuboCop and CI`, that is the commit on `main`, whatever the branch's internal commits looked like. Rebase merging was rejected (D-034): it copies every branch commit onto `main`, so a branch's work-in-progress messages would become permanent history.
- **What you should see:**
  ```
  $ gh api repos/Myepes05/tintara-lab --jq '{squash: .allow_squash_merge, merge: .allow_merge_commit, rebase: .allow_rebase_merge, title: .squash_merge_commit_title}'
  {"merge":false,"rebase":false,"squash":true,"title":"PR_TITLE"}
  ```

### Step 12 — Branch protection, and the price that was paid for it

- **What was attempted:**
  ```sh
  gh api repos/Myepes05/tintara-lab/branches/main/protection
  ```
  On the private repository this returned:
  ```
  {"message":"Upgrade to GitHub Pro or make this repository public to enable this feature.","status":"403"}
  ```
- **What it means:** on GitHub's free plan, branch protection rules are only available on repositories that anyone can read. The owner's account reports `plan: null`, so the API refused.
- **The choice:** two options existed. Pay for GitHub Pro (about $4/month) and keep the repository private with protection; or make the repository readable by everyone and get protection for free. The owner chose the second, and reaffirmed it when the consequences were put in writing (D-059).
- **What that trade-off actually costs.** Everything in this repository is now world-readable, including `handoff/`: the photographer's real name and city, the mockups, the discovery answers and the business plan, plus the owner's email address. It is in the first commit, so rewriting a file later does not remove it from the history. From that moment, **any secret committed by mistake must be treated as compromised the instant it is pushed** — not "if someone notices", but immediately, because public repositories are continuously scraped by bots looking for exactly that. The correct response to such a mistake is to rotate the credential, not to delete the file. One consolation: GitHub Actions minutes are free on public repositories, so all the CI in chapter 02 costs nothing.
- **What was configured** (verified live while writing this chapter):
  ```sh
  $ gh api repos/Myepes05/tintara-lab/branches/main/protection \
      --jq '{pr: .required_pull_request_reviews.required_approving_review_count,
             linear: .required_linear_history.enabled,
             force: .allow_force_pushes.enabled,
             deletions: .allow_deletions.enabled,
             conversation: .required_conversation_resolution.enabled,
             admins: .enforce_admins.enabled}'
  {"pr":0,"linear":true,"force":false,"deletions":false,"conversation":true,"admins":false}
  ```
  Changes reach `main` only through a pull request; history stays linear; force pushes and branch deletion are blocked; review conversations must be resolved before merging.
- **Two settings that look wrong and are not:**
  - **Zero required approvals.** A single GitHub account cannot approve its own pull request. Requiring one approval on a one-person project would make merging impossible. The pull request is still required — the rule enforces the *process*, and the owner supplies the judgement.
  - **Administrators are not included** (`enforce_admins: false`). If the rule applied to administrators too, nobody could push anything directly to `main` — and the project's own protocol (D-053) depends on exactly that: handoff-only changes (prompts, status, decision log, templates) are committed straight to `main` as `docs N: ...`, with no branch and no PR, because those files are edited continuously by the orchestrator and would conflict endlessly if they travelled inside feature branches. Excluding administrators is what keeps that path open while every code change still goes through review.

## 5. The important files, explained

### `.gitignore`

```gitignore
# macOS
.DS_Store

# Editors
.idea/
.vscode/*
!.vscode/extensions.json

# Environment files (commit only the example)
.env
.env.*
!.env.example

# Dependencies
node_modules/

# Logs
*.log

# Test coverage
coverage/

# Temporary files
tmp/
```

Line by line:

- `.DS_Store` — a metadata file macOS drops into every folder you open in Finder. Committing it is a classic first-pull-request embarrassment.
- `.idea/` — JetBrains editor settings, personal to one machine.
- **`.vscode/*` followed by `!.vscode/extensions.json`** — this pattern is worth understanding, because the obvious alternative silently fails. The goal is: ignore my personal VS Code settings, but share the list of recommended extensions. The rule is a git rule with no workaround:
  > A negation (`!`) cannot re-include a file if one of its parent **directories** is excluded, because git never looks inside an excluded directory.

  `.vscode/*` (with the star) excludes the *contents* of the directory, one entry at a time, while the directory itself stays visible to git — so the negation on one of those entries works. `.vscode/` (with a trailing slash) excludes the *directory*, git stops descending, and `!.vscode/extensions.json` is dead text that looks perfectly reasonable in the file. The same rule bites again in chapter 02, from the other direction, with `tmp/`.
- `.env` and `.env.*`, then `!.env.example` — ignore every environment file, then make one exception for the committed template. Same pattern, same reason it is written with a star-free path: `.env.*` matches files, not a directory, so the negation is allowed.
- `node_modules/`, `*.log`, `coverage/`, `tmp/` — build output, logs and dependencies, all reproducible from source and all large.

### `.editorconfig`

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.md]
trim_trailing_whitespace = false
```

`root = true` stops editors from looking for more `.editorconfig` files further up the filesystem. The `[*.md]` override exists because in Markdown two trailing spaces mean a line break; trimming them would silently change rendered documents — including these chapters.

### `docker-compose.yml`

```yaml
name: tintara-lab

services:
  db:
    image: postgres:18
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:?Set POSTGRES_USER in .env}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    volumes:
      # Postgres 18+ images keep data under /var/lib/postgresql/<major>/docker,
      # so the volume is mounted at the parent directory.
      - db_data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \"$${POSTGRES_USER}\""]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s

volumes:
  db_data:
```

- **`name: tintara-lab`** — the project name Compose prefixes onto containers, networks and volumes. Without it Compose uses the directory name, so renaming the folder would orphan your database volume.
- **`services:` / `db:`** — one service. `db` is the name you use in commands: `docker compose exec db ...`.
- **`image: postgres:18`** — pinned to a major version, never `latest`. `latest` is a moving target: the day PostgreSQL 19 becomes the default tag, a teammate's `docker compose pull` silently gives them a different database engine than yours, and major versions are not data-compatible — the container would refuse to start on an existing volume. Pinning `18` still receives patch releases (it resolved to 18.6 here) without ever crossing a major boundary. The choice of 18 specifically: it is the current stable major, supported until November 2030, and the intended host offers it (D-058, D-055).
- **`restart: unless-stopped`** — the container comes back after a machine reboot or a Docker restart, unless you stopped it on purpose.
- **`${POSTGRES_USER:?Set POSTGRES_USER in .env}`** — the `:?` form means *fail with this message if the variable is unset or empty*. Compose refuses to start and tells you exactly what is missing. The tempting alternative, `${POSTGRES_USER:-postgres}`, supplies a default — and defaults are how a project ends up with a database whose credentials nobody wrote down, or worse, with a real password committed in the compose file because someone found the indirection confusing. **The compose file contains no credential literal at all**; the values come from `.env`, which is never committed.
- **`"${POSTGRES_PORT:-5432}:5432"`** — `host:container`. The container always listens on 5432 internally; the *host* port is configurable and defaults to 5432. This one uses `:-` (a default) rather than `:?` (an error) because unlike the credentials, there is a correct default — and it is configurable because port 5432 is frequently already taken by a natively installed Postgres or another project's container. One variable in `.env` moves it; nothing else changes. Chapter 02 reads the same variable, so the Rails app follows automatically.
- **`db_data:/var/lib/postgresql`** and the `volumes:` block at the bottom — a named volume that Docker stores outside the container. Delete and recreate the container and the data is still there; `docker compose down` keeps it, `docker compose down -v` destroys it. That `-v` is the difference between "stop for the night" and "lose the database", and there is no confirmation prompt.
- **The mount path is the trap of this file.** See section 7.
- **`healthcheck:`** — `pg_isready` is the PostgreSQL tool that answers "can this server accept connections yet?". Compose runs it every 5 seconds, allows a 10-second grace period on boot (`start_period`) and gives up after 10 failures. Without a healthcheck, `docker compose up -d` returns as soon as the *process* starts, which is a second or two before the database is reachable — long enough for a script that runs immediately afterwards to fail with a confusing connection error. The same idea reappears in chapter 02, where the CI job's Postgres service needs its own healthcheck for exactly this reason.
- **`$${POSTGRES_USER}`** — doubling the `$` escapes it, so Compose leaves the text alone and the *shell inside the container* expands it at check time, where the variable actually lives.

### `.github/pull_request_template.md`

Sections: Summary · Task · Decisions implemented · How it was tested · Implementation report · Checklist. The checklist repeats the six rules that are easiest to skip in a hurry: specs committed before the implementation, lint and tests pass locally, no secrets committed, English only, scope matches the prompt, PR title follows the convention.

## 6. Decisions behind this chapter

| Decision | What we chose | What we rejected | Why |
|---|---|---|---|
| D-032 | One monorepo, both apps under lowercase `apps/` | Two repositories; `Apps/` with a capital | One repo keeps API and frontend changes reviewable together; lowercase avoids a path that works on case-insensitive macOS and breaks on case-sensitive Linux CI and hosts |
| D-030 | Docker runs Postgres only | Containerising Rails and the frontend too | Apps run faster and debug more easily natively; the database is the dependency that must match production |
| D-058 | `postgres:18`, pinned to the major | `postgres:latest` | `latest` changes under you and major versions are not data-compatible; 18 is current stable and offered by the intended host |
| D-034 | GitHub repo, PRs for everything, squash-only merge | Rebase merge; merge commits | The squash subject is the PR title, so `main`'s history is the list of delivered tasks |
| D-035 | `Feature N:` / `fix N:` / `docs N:` prefixes, numbers assigned in the prompt | Agents choosing their own numbers | Separate counters per type, no collisions between parallel agents |
| D-049 | Feature 1 committed directly to `main` | A PR for Feature 1 | A pull request needs a base branch; `main` does not exist before the first commit |
| D-059 | Repository readable by everyone, to unlock branch protection | GitHub Pro (~$4/month) with a private repo | The owner chose the free path; the cost is that `handoff/` and its personal data are published permanently |
| D-060 | PR required, linear history, no force pushes, admins excluded | Including administrators in the rule | Excluding admins keeps the `docs N` direct-commit path (D-053) working |
| D-053 | Handoff-only changes go straight to `main` as `docs N` | Carrying handoff edits inside feature branches | Status and decision files change constantly; in branches they would conflict on every merge |
| D-028 | No Redis | Redis for cache and jobs | Rails 8 covers both on Postgres; a service with no requirement asking for it is cost and complexity |

## 7. Traps, mistakes and things we avoided

**1. The Postgres 18 volume path — the one that silently loses your data.** Nearly every tutorial, and most existing compose files, mount the volume at `/var/lib/postgresql/data`. That was correct for years. The official image changed for 18: `PGDATA` now points at `/var/lib/postgresql/<major>/docker`, and Docker Hub's documentation says to mount at the parent, `/var/lib/postgresql`. Mount the old path against an 18 image and the container still starts, still accepts connections, and still looks perfectly healthy — while the real data directory sits outside the volume and disappears with the container. The failure arrives days later as an empty database nobody can explain. This file mounts `db_data:/var/lib/postgresql`, with a comment saying why, because the next person to read it will have the old path in their fingers.

**2. Branch protection is not free on private repositories.** The `gh api .../protection` call returned a 403 telling us to upgrade or go public. Worth knowing before you promise someone a protected `main`: on the free plan, protection and publication are the same decision (D-059).

**3. Publishing is permanent, and it applies to the whole history.** The repository was made public *after* the first commit, which already contained `handoff/` with a third party's name, city and the owner's email. Deleting those files now would not help: git keeps history. This is worth saying plainly because it is the most common irreversible mistake in this whole chapter — not committing a secret, but committing something personal and only later making the repository public. The orchestrator recorded a standing recommendation to revert to private; the owner chose to keep the current visibility, and the concern stays on record (D-059).

**4. `docker compose down -v` destroys the database, with no prompt.** `down` alone removes the container and the network and keeps the volume. Adding `-v` removes the volume too. One character between a clean restart and losing your local data.

**5. `${VAR:-default}` versus `${VAR:?message}`.** Using a default for credentials is how projects end up with a database nobody can log into and a password nobody wrote down. Credentials use `:?` and fail loudly; only the host port, which has a genuinely correct default, uses `:-`.

**6. The `.vscode/*` versus `.vscode/` distinction.** Written above in section 5, and worth repeating because the broken version looks right: git cannot re-include a file whose parent directory is excluded, so `.vscode/` + `!.vscode/extensions.json` quietly ignores the exception. The star form works. In chapter 02 the same rule bites in the opposite direction, where the root `tmp/` rule outranks a negation inside `apps/api/.gitignore` and a file Rails expects to be tracked simply is not.

**7. Empty directories do not exist in git.** `apps/` needed `.gitkeep` or it would not have survived a clone. There is no git setting for this; the placeholder file is the whole solution.

**8. Case-insensitive macOS hides path bugs until CI.** `apps/` versus `Apps/` is identical locally and different everywhere your code will actually run. Decide the casing once and write it down (D-032).

**9. Port 5432 may already be taken.** It was checked before choosing (`lsof -nP -iTCP:5432 -sTCP:LISTEN`, no output, so free). If it had been taken, the fix is `POSTGRES_PORT` in `.env` — which is why that variable exists at all.

**10. `latest` on a managed host is not the `latest` you expect.** The intended production host's Postgres template builds its `latest` tag from major 16, not 18, even though it publishes an `:18` tag. Matching development to production therefore means naming `:18` explicitly at deployment time, not trusting a default (D-058, D-036). That deployment step has not happened yet; the note exists so it is not discovered the hard way.

**Deliberately not done, so you do not go looking for it:** no application code, no CI workflows (chapter 02 adds the first one), no Redis, no deployment configuration, and — despite pnpm being the chosen frontend package manager (D-021) — no pnpm setup, because the frontend does not exist until Feature 3. Every one of those is a later chapter with its own decisions.

## 8. How to verify it yourself

```sh
# History: exactly one commit, with the right message
git log --oneline
# ab52b86 Feature 1: push the first commit of the monorepo

# Nothing unwanted is tracked, and the ignores work
git ls-files | wc -l            # 25 files at this point
git status --short              # empty: no .env, no .DS_Store
git check-ignore -v .env        # .gitignore:10:.env   .env

# The database really runs
cp .env.example .env
docker compose up -d
docker compose ps               # STATUS must read "Up ... (healthy)"
docker compose exec db pg_isready
# /var/run/postgresql:5432 - accepting connections
docker compose exec db psql -U "$POSTGRES_USER" -c "select version();"
# PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2) on x86_64-pc-linux-gnu
docker compose down             # keeps the db_data volume

# GitHub settings
gh api repos/<you>/tintara-lab --jq '{squash: .allow_squash_merge, merge: .allow_merge_commit, rebase: .allow_rebase_merge, title: .squash_merge_commit_title}'
# {"merge":false,"rebase":false,"squash":true,"title":"PR_TITLE"}
gh api repos/<you>/tintara-lab/branches/main/protection --jq '.required_linear_history.enabled'
# true
```

If the container's status says `Up` but never `(healthy)`, the healthcheck is failing: run `docker compose logs -f db` and check that `POSTGRES_USER` in `.env` matches the user the check is asking about.

## 9. What comes next

This chapter leaves the repository deliberately empty of code. `apps/` contains nothing but a placeholder, there is no CI, and nothing connects to the database that is now running.

**Chapter 02** fills `apps/api` with the Rails 8.1 API, points it at this container by reading the same root `.env`, writes the first spec before the first endpoint, and adds the first GitHub Actions workflow. Chapter 03 will do the equivalent for `apps/web`.

One loose end is recorded rather than fixed: required status checks are not part of branch protection yet, because no workflow has ever run on `main`. Once chapter 02's `api.yml` and the future `web.yml` have run there, they can be added as required checks (D-060).

## 10. Glossary

- **Base branch** — the branch pull requests merge into; here, `main`.
- **Branch protection** — GitHub rules restricting what may happen to a branch (PR required, no force pushes, linear history).
- **Container / image** — a running isolated environment / the read-only template it starts from.
- **Docker Compose** — declares containers in `docker-compose.yml` so one command starts them.
- **Healthcheck** — a command Docker runs inside a container to decide whether it is genuinely ready.
- **Linear history** — a history with no merge commits, which squash-only merging produces.
- **Monorepo** — one repository containing several applications.
- **Named volume** — Docker-managed storage that outlives the container.
- **`pg_isready`** — PostgreSQL's "are you accepting connections?" utility.
- **Remote / `origin`** — a hosted copy of the repository / its conventional name.
- **Squash merge** — collapsing a pull request's commits into one commit on the base branch.
- **`.gitkeep`** — a conventional empty file that lets git track an otherwise empty directory.
- **`${VAR:?msg}` / `${VAR:-default}`** — in Compose, fail with a message if unset / substitute a default if unset.
