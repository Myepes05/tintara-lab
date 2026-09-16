# Feature 2: create the Rails API skeleton with RSpec, RuboCop and CI

**Type:** Implementation · **Phase:** 1 — Foundation
**Branch:** `feature/2-rails-api-skeleton`
**PR title (exact):** `Feature 2: create the Rails API skeleton with RSpec, RuboCop and CI`
**Report file:** `handoff/agent-outputs/implementation/feature-002-rails-api-skeleton.md` (use `handoff/templates/implementation-output.md`)
**Working directory:** `/Users/miguelangel/Documents/projects/tintara-lab`

## Before you start
1. Read `CLAUDE.md` completely.
2. Read `handoff/status/current-status.md`.
3. Read these decisions in `handoff/decisions/decision-log.md`: D-014, D-023, D-028, D-030, D-031, D-032, D-033, D-034, D-035, D-042, D-050, D-051, D-052, D-053, D-054, D-055, D-058, D-060, D-062, D-063.
4. Read the Feature 1 report: `handoff/agent-outputs/implementation/feature-001-monorepo-bootstrap.md`.
5. Confirm `git status` on `main` is clean and `git pull` succeeds. Create your branch from up-to-date `main`.

Depends on: Feature 1 (repo, Postgres container).

## Goal
Create the Rails API application at `apps/api`, wired to the Docker Postgres, with the testing and linting tools, one health endpoint proving the stack works end to end, and a GitHub Actions workflow that lints and tests it.

## Context you need
- **Repository is readable by everyone** (D-059). Never commit secrets. `config/master.key` must stay ignored; verify it.
- **Postgres** runs from the repo root `docker-compose.yml` (`postgres:18`), with credentials and host port in the root `.env` (see `.env.example`). Start it with `docker compose up -d` from the repo root.
- **`main` is protected** (D-060): open a PR, never push to `main`, never merge.

## Scope
### In scope
- The Rails app at `apps/api`
- Database configuration against the Docker Postgres
- RSpec, FactoryBot, shoulda-matchers
- RuboCop as Rails 8 ships it (D-062)
- Solid Cache and Solid Queue on the primary database (D-052)
- `GET /api/v1/health` plus its request spec
- `.github/workflows/api.yml`
- Updating the API line of `CLAUDE.md` §7

### Out of scope (do NOT do)
- Authentication, sessions, admins (Feature 5)
- CORS, CSRF, rate limiting, error format (Feature 4)
- Any domain model, migration or seed for site content (Phase 3)
- Serializers (decided with the API contract, D-051)
- Anything in `apps/web` or its workflow (Feature 3)
- Any deployment configuration beyond what `rails new` generates
- Editing any `handoff/` file other than creating your report

## Requirements

### 1. Generate the application
- Use the installed Ruby 3.4.3 and Rails 8.1.x. Report the exact Rails version you used (D-055).
- Generate into `apps/api` as an **API-only** app with **PostgreSQL**.
- **Skip** (D-063): the default test framework, Action Cable, Active Storage, Action Mailbox, Jbuilder and Kamal.
- **Keep:** Action Mailer, Solid Cache, Solid Queue, Brakeman, RuboCop.
- Keep the generated `.ruby-version`.
- Confirm that `apps/api/.gitignore` ignores `config/master.key`, `.env*`, `tmp/`, `log/` and `storage/`.

### 2. Database configuration
- `config/database.yml` reads from environment variables, with sensible development defaults:
  - host, port (from `POSTGRES_PORT`, defaulting to 5432), username and password from the root `.env`
  - databases `tintara_lab_development` and `tintara_lab_test`
  - production reads `DATABASE_URL` (unused for now, deployment deferred)
- Development and test load the **root** `.env` (two levels up). Use `dotenv-rails` configured to read `../../.env`, or an equivalent approach. Whatever you choose, it must:
  - work when the app is run from `apps/api`
  - not break in CI, where the variables come from the workflow environment instead
  - never require duplicating credentials in a second file
- **No hard-coded credentials anywhere.**

### 3. Solid Cache and Solid Queue on the primary database (D-052)
- Both must use the **primary** database rather than the Rails 8 default of separate cache and queue databases.
- Their tables belong to the primary schema, and `bin/rails db:prepare` must set up everything from a clean database.
- The `test` environment must run without needing a queue worker (inline or test adapter).
- Document in your report exactly what you changed, since Rails' defaults differ.

### 4. Testing tools
- `rspec-rails`, `factory_bot_rails` and `shoulda-matchers` in the `:development, :test` group as appropriate.
- `rails generate rspec:install`, plus:
  - FactoryBot syntax methods available in specs
  - shoulda-matchers configured for RSpec and Rails
  - `spec/rails_helper.rb` failing loudly on pending migrations
- Keep the generated `spec/spec_helper.rb` defaults. No `--format` customization needed.

### 5. Health endpoint (this is the spec-first part, D-042 and D-050)
1. **First commit:** the request spec at `spec/requests/api/v1/health_spec.rb`, asserting:
   - `GET /api/v1/health` returns 200
   - the response content type is JSON
   - the body contains `status` equal to `"ok"`
   - the body contains a `time` field that parses as a timestamp
2. **Then** implement until it passes:
   - routes: namespaced `api/v1`, endpoint `health`
   - a controller returning that JSON
- Keep the Rails default `/up` endpoint as generated.
- The response must not leak the Rails version, environment names or any internal detail beyond status and time.

### 6. CI workflow `.github/workflows/api.yml` (D-033)
- **Triggers:** pull requests targeting `main`, and pushes to `main`.
- **Path filter:** `apps/api/**` and `.github/workflows/api.yml`.
- **Two jobs** (they may run in parallel): `lint` running RuboCop, and `test` running RSpec.
- The `test` job needs a Postgres **18** service, with credentials passed through environment variables, and a health check so the steps wait for it.
- Ruby comes from `apps/api/.ruby-version`, with bundler caching enabled and `apps/api` as the working directory.
- Prepare the test database before running specs.
- **Pin every action to a current major version, verified from its repository, and cite the sources in your report** (D-055).
- The workflow must **not** contain any real credential; development-only values defined inside the workflow are fine.

### 7. `CLAUDE.md` §7
Update only the **API** line with the real commands: install dependencies, prepare the database, run the server, run specs, run RuboCop. Leave the Postgres and Web lines untouched.

### 8. Verify locally before opening the PR
From the repo root: `docker compose up -d`, then from `apps/api`:
- `bin/rails db:prepare`
- `bundle exec rspec` — all green
- `bundle exec rubocop` — no offenses
- `bin/rails server`, then `curl -s localhost:3000/api/v1/health` returns the expected JSON. Include the actual response in your report.
- Confirm a clean-database path works: drop and re-prepare the test database, then run the specs again.
- `git status`: no `.env`, no `master.key`, no `.DS_Store`, no `log/` or `tmp/` files staged.

### 9. Branch, commits and PR
- Branch from up-to-date `main`: `feature/2-rails-api-skeleton`.
- Commit order matters (D-050): scaffolding and tooling, then the **health spec**, then the implementation that makes it pass. Every commit message is prefixed `Feature 2:`.
- Open the PR with the exact title, fill in the PR template, and link your report. **Do not merge.**
- After opening the PR, commit your report file to the same branch and push (D-053).

## Acceptance criteria
- [ ] `apps/api` holds a Rails 8.1 API-only app on PostgreSQL, with the components in D-063 skipped or kept as specified
- [ ] `bin/rails db:prepare`, `bundle exec rspec` and `bundle exec rubocop` all succeed locally, with outputs in the report
- [ ] `GET /api/v1/health` returns `{"status":"ok","time":...}` with a 200 and a JSON content type
- [ ] The health request spec was committed **before** the implementation, and the report shows both commit SHAs
- [ ] Solid Cache and Solid Queue use the primary database, and a clean `db:prepare` sets everything up
- [ ] Database credentials come from the root `.env` in development and from the environment in CI, with none hard-coded
- [ ] `.github/workflows/api.yml` exists with the path filter, the Postgres 18 service, lint and test jobs, and pinned, source-verified action versions
- [ ] The workflow runs on the PR and both jobs pass (link the run in the report)
- [ ] No secrets committed; `config/master.key` is ignored
- [ ] `CLAUDE.md` §7 API line updated; other lines untouched
- [ ] PR opened with the exact title and not merged; report committed to the branch
- [ ] Nothing outside the scope was done

## Verification commands (include outputs or summaries in the report)
```
ruby -v && (cd apps/api && bin/rails -v)
docker compose up -d && docker compose ps
cd apps/api && bin/rails db:prepare
bundle exec rspec
bundle exec rubocop
curl -si localhost:3000/api/v1/health
cd ../.. && git log --oneline main..HEAD
git status --short
gh pr view --json title,url,state
gh run list --branch feature/2-rails-api-skeleton --limit 5
```

## Questions
If anything is unclear, or a requirement conflicts with what Rails 8.1 actually generates, do not improvise. Record it under "Questions for the owner" in your report, and stop if it blocks you. If a decision in the log looks wrong to you, say so in the report rather than working around it.
