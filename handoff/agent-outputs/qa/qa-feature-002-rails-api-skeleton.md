# QA Report — Feature 2: create the Rails API skeleton with RSpec, RuboCop and CI

- **Date:** 2026-09-15
- **PR / branch:** https://github.com/Myepes05/tintara-lab/pull/1 · `feature/2-rails-api-skeleton`
- **Commit reviewed:** `981349e` (PR head; also the head of `origin/feature/2-rails-api-skeleton`)
- **Verdict:** **PASS WITH NOTES**

Everything the prompt asked for works, and it works when re-derived independently rather than read from the report. Every claim in the implementation report that I could check turned out to be true, including the ones that are easy to fake: the spec-first failure output, the pinned action versions, the clean-database path and the CI-without-`.env` path. The five findings below are all in the learning chapters or are advisory; none of them is a `blocker` or a `major`, and none of them touches application code.

## Checks run

```
# Environment
ruby -v                                   ruby 3.4.3 (2025-04-14 revision d0b7e5b6a0) +PRISM [x86_64-darwin25]
apps/api $ bin/rails -v                   Rails 8.1.3.1
docker compose ps                         tintara-lab-db-1  postgres:18  Up (healthy)  0.0.0.0:5432->5432/tcp
docker compose exec db psql -c "select version();"
                                          PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2) on x86_64-pc-linux-gnu

# A. Functional
apps/api $ bundle install                 Bundle complete! 16 Gemfile dependencies, 105 gems now installed.
apps/api $ bin/rails db:prepare           ok
apps/api $ bundle exec rspec              5 examples, 0 failures
apps/api $ bundle exec rubocop            28 files inspected, no offenses detected

# A2. Clean-database path
apps/api $ bin/rails db:drop db:prepare   Dropped/Created tintara_lab_development and tintara_lab_test
docker compose exec db psql -c '\l'       postgres, template0, template1, tintara_dev,
                                          tintara_lab_development, tintara_lab_test   (no cache/queue database)
apps/api $ bin/rails runner '...tables'   16 tables, incl. solid_cache_entries and the 14 solid_queue_* tables
apps/api $ RAILS_ENV=test bin/rails runner 'puts ...tables.size'    16
apps/api $ bundle exec rspec              5 examples, 0 failures

# A3/A4. The endpoints (server booted on 3001 to avoid clashing with anything on 3000)
curl -si localhost:3001/api/v1/health     HTTP/1.1 200 OK
                                          content-type: application/json; charset=utf-8
                                          {"status":"ok","time":"2026-09-16T04:30:00Z"}     <- exactly two keys
curl -si localhost:3001/up                HTTP/1.1 200 OK   (different endpoint, rails/health#show)

# A5. Routes
apps/api $ bin/rails routes
  rails_health_check GET  /up(.:format)            rails/health#show
       api_v1_health GET  /api/v1/health(.:format) api/v1/health#show
                                          (two routes, nothing else)

# C3. CI path simulated locally (root .env moved aside, restored and byte-compared afterwards)
apps/api $ env -u POSTGRES_USER -u POSTGRES_PASSWORD RAILS_ENV=test bin/rails db:prepare
                                          PG::ConnectionBad: ... no password supplied     (fails loudly, as intended)
apps/api $ POSTGRES_USER=... POSTGRES_PASSWORD=... POSTGRES_HOST=localhost POSTGRES_PORT=5432 \
           RAILS_ENV=test bin/rails db:drop db:prepare && bundle exec rspec && bundle exec rubocop
                                          Created database 'tintara_lab_test'
                                          5 examples, 0 failures
                                          28 files inspected, no offenses detected
root $ diff .env <backup>                 identical (restored)

# C4. Secrets
git ls-files | grep -Ei 'master\.key|\.env|DS_Store|\.key$'        .env.example      (only)
git ls-files | grep credentials                                    apps/api/config/credentials.yml.enc
git check-ignore -v apps/api/config/master.key                     apps/api/.gitignore:25:/config/*.key
git diff main...HEAD -- apps/api .github | grep -Ei 'password|secret|token|key'
                                          only the CI throwaway credentials and ENV/comment references

# D. CI
gh api repos/actions/checkout/releases/latest    v7.0.1  (2026-07-20); tags: v7.0.1, v7.0.0, v7, v6.1.0, ...
gh api repos/ruby/setup-ruby/releases/latest     v1.323.0 (2026-09-15); only a v1 major line
gh api repos/ruby/setup-ruby/contents/action.yml  inputs: ruby-version, rubygems, bundler, bundler-cache,
                                          working-directory, cache-version, self-hosted, windows-toolchain,
                                          token   -> there is no `ruby-version-file` input
gh run list --branch feature/2-rails-api-skeleton
  981349e  success  RSpec, RuboCop     (PR head)
  af2b459  success  RuboCop, RSpec
  0e187fc  success  RuboCop, RSpec

# E. Spec-first, verified by actually running the spec commit in a detached worktree
git log --oneline main..HEAD              d490ca9 (spec) precedes cdd649e (implementation)
git show --stat d490ca9                   spec/requests/api/v1/health_spec.rb only
git show --stat cdd649e                   health_controller.rb + routes.rb only
git show d490ca9:apps/api/config/routes.rb | grep -c api      0   (no route at the spec commit)
worktree@d490ca9 $ bundle exec rspec      5 examples, 5 failures
                                          "actual collection contained: []" /
                                          "the missing elements were: [\"status\", \"time\"]"

# G. Scope and conventions
git diff --name-only main...HEAD | grep -v '^apps/api/'
  .github/workflows/api.yml · CLAUDE.md · the implementation report · the two learning chapters
git diff main...HEAD -- CLAUDE.md          one line changed: the §7 API line
git diff --stat 981349e^ 981349e -- apps .github docker-compose.yml CLAUDE.md    (empty: docs only)
gh pr view 1                               OPEN, title exact, body follows the template
git log --format='%s' main..HEAD           all six commits prefixed "Feature 2:"
git status --short                         clean at the end of the review
```

## Acceptance criteria verification

| Criterion | Result | Evidence |
|---|---|---|
| Rails 8.1 API-only app on PostgreSQL at `apps/api`, D-063 components skipped/kept | PASS | Rails 8.1.3.1, `config.api_only = true`; no `test/`, `config/cable.yml`, `config/storage.yml`, `config/deploy.yml`, `.kamal/`, `apps/api/.github/`, no jbuilder in the Gemfile; Action Mailer required in `application.rb`, `solid_cache`/`solid_queue`/`brakeman`/`rubocop-rails-omakase` present |
| `db:prepare`, `rspec`, `rubocop` succeed locally | PASS | re-run by QA: ok / 5 examples, 0 failures / 28 files, no offenses |
| `GET /api/v1/health` → `{"status":"ok","time":...}`, 200, JSON | PASS | `curl -si` above; body has exactly two keys |
| Health spec committed before the implementation, both SHAs reported | PASS | `d490ca9` → `cdd649e`; QA ran the suite at `d490ca9` and got 5 failures |
| Solid Cache and Solid Queue on the primary database; clean `db:prepare` works | PASS | `db:drop db:prepare` from empty → 16 tables in the primary schema, in `db/schema.rb` (version `2026_09_15_000002`); `psql \l` shows no cache or queue database |
| Credentials from the root `.env` in development, from the environment in CI, none hard-coded | PASS | `Dotenv::Rails.files` resolves to `<repo>/.env`; CI path simulated with `.env` absent and passed; no literal credential in `database.yml` |
| `.github/workflows/api.yml` with path filter, Postgres 18 service, lint + test jobs, pinned verified actions | PASS | file reviewed; `actions/checkout@v7` and `ruby/setup-ruby@v1` re-verified from their own repositories |
| The workflow runs on the PR and both jobs pass | PASS | run on PR head `981349e`: `success`, jobs `RuboCop` and `RSpec` |
| No secrets committed; `config/master.key` ignored | PASS | `git ls-files` clean; `git check-ignore -v` shows `apps/api/.gitignore:25:/config/*.key` |
| `CLAUDE.md` §7 API line updated, other lines untouched | PASS | the diff against the merge base is that single line |
| PR opened with the exact title, not merged; report committed to the branch | PASS | `gh pr view 1` → OPEN, exact title; report at `af2b459` |
| Nothing outside scope | PASS | see the scope diff above |
| **Extension:** both chapters exist, 10 sections each, README lists them, report has the "Learning chapters (D-064)" section, no code touched | PASS | both chapters have all 10 template sections; `handoff/learning/README.md` on `main` already lists both; `981349e` is documentation-only |

## Decision compliance

| Decision | Compliant? | Notes |
|---|---|---|
| D-000, D-032 | Yes | API-only Rails 8.1.3.1 on PostgreSQL at `apps/api`; Ruby 3.4.3 in `.ruby-version` |
| D-028 | Yes | Ruby 3.4.3, Rails 8.1, API mode, no Redis anywhere in the Gemfile |
| D-030 | Yes | nothing was added to `docker-compose.yml`; the app runs natively against the container |
| D-031 | Yes | `namespace :api { namespace :v1 { ... } }`; the only application route is `/api/v1/health` |
| D-033 | Yes | two jobs, RuboCop and RSpec, path-filtered to `apps/api/**` and the workflow file |
| D-035 | Yes | PR title exact; all six branch commits prefixed `Feature 2:` |
| D-042, D-050 | Yes | spec commit precedes the implementation commit, and the spec genuinely fails at that commit |
| D-051 | Yes | no serializer gem in `Gemfile.lock` (checked for jbuilder, AMS, alba, blueprinter, fast_jsonapi, jsonapi) |
| D-052 | Yes | no `cache:`/`queue:` entries in `database.yml`; `cache.yml` production is `<<: *default`; `production.rb` has no `solid_queue.connects_to`; both schema files are now migrations and their tables are in `db/schema.rb`; `psql \l` confirms no extra database exists |
| D-053 | Yes | the branch adds only its own report and the two chapters under `handoff/` |
| D-055 | Yes | every version in the report matches `Gemfile.lock` exactly (rails 8.1.3.1, pg 1.6.3, puma 8.0.2, solid_cache 1.0.10, solid_queue 1.7.0, rubocop-rails-omakase 1.1.0, rspec-rails 8.0.4, factory_bot_rails 6.5.1, shoulda-matchers 8.0.1, dotenv-rails 3.2.0); both actions re-verified upstream |
| D-058 | Yes | the CI service image is `postgres:18`, matching development |
| D-059 | Yes | nothing secret-shaped is committed; the only credential literals are the CI throwaways |
| D-062 | Yes | `.rubocop.yml` is `inherit_gem: { rubocop-rails-omakase: rubocop.yml }` with only the generator's commented-out example below it — no custom rule is enabled |
| D-063 | Yes | skips and keeps verified file by file (see the criteria table); `--skip-ci` is an addition, judged below |
| D-064 | Yes, with notes | both chapters follow the template and are accurate; see the chapter review and findings 1–4 |
| Scope: nothing from Feature 4 or 5 | Yes | `config/initializers/cors.rb` is still entirely commented out, `rack-cors` is still commented in the Gemfile and absent from `Gemfile.lock`; no CSRF, no rate limiting, no `sessions` table, no model, no migration other than the two Solid ones |

## Spec review

`spec/requests/api/v1/health_spec.rb` has five examples and they cover the behaviour properly:

- **Spec-first is real, not just ordered.** I checked out `d490ca9` in a detached worktree and ran the suite: `5 examples, 5 failures`, and the failures are the right ones — 404 instead of 200, `text/html` instead of `application/json`, `nil` for `status`, `ArgumentError: invalid xmlschema format: nil` for the timestamp. The report's and chapter's quoted output is verbatim correct.
- **Regression sensitivity.** Each example would fail on a plausible regression: a wrong status code, a controller that renders HTML, a renamed or changed `status` value, a `time` that is not ISO 8601, and — this is the valuable one — `expect(response.parsed_body.keys).to match_array(%w[status time])` fails the moment anyone adds a field. That assertion is what keeps the endpoint from growing into an information-disclosure surface, which is exactly the risk a health endpoint carries.
- **Nothing superfluous is asserted.** No brittle assertions on headers, ETag or body ordering.
- **One gap worth naming, not a finding:** nothing asserts that `time` is *close to now*, so a hard-coded constant timestamp would pass. Given the controller is three lines, adding `be_within(5.seconds).of(Time.current)` is optional; I mention it only so the choice is deliberate.
- **`type: :request` is explicit** on the describe block, which is correct because `config.infer_spec_type_from_file_location!` is (as generated) left commented out in `rails_helper.rb`.
- **`rails_helper.rb`** keeps the generated `maintain_test_schema!` block that aborts on pending migrations, has the `spec/support/**/*.rb` require line uncommented, and `spec/support/` holds `config.include FactoryBot::Syntax::Methods` and the shoulda-matchers `:rspec`/`:rails` integration. All three prompt requirements met.
- **Carry-over for Feature 4 (noted, not a finding, as the prompt instructs):** `config/environments/test.rb` sets `config.cache_store = :null_store`. That is the current state and it is the Rails default. Feature 4's rate limiting is backed by Solid Cache, and `rate_limit` specs cannot count anything against a null store, so Feature 4 will have to change the test cache store (`:memory_store`, or `:solid_cache_store` against the test database).

## Learning chapter review

Both chapters are unusually good: they teach rather than restate the report, they explain terms before using them, and their traps sections describe failures that actually happened rather than generic advice. I spot-checked far more than the required eight claims per chapter; below is what I actually verified.

### Chapter 01 — `01-monorepo-bootstrap.md`

Verified against the repository (12 claims):

1. `.gitignore` excerpt (section 5) — **byte-identical** to `ab52b86:.gitignore`, all 24 lines.
2. `.editorconfig` excerpt — byte-identical.
3. `docker-compose.yml` excerpt, including the volume comment — byte-identical to the file on disk.
4. `.env.example` excerpt — byte-identical.
5. `git ls-files | wc -l # 25 files at this point` — `git ls-tree -r ab52b86 | wc -l` → **25**.
6. `git check-ignore -v .env` → `.gitignore:10:.env` — correct, line 10 is right.
7. `apps/.gitkeep` is tracked at `ab52b86` as an empty blob — correct.
8. PR template sections (Summary · Task · Decisions implemented · How it was tested · Implementation report · Checklist) — correct.
9. Repository settings query and its output — re-run live: `{"merge":false,"rebase":false,"squash":true,"title":"PR_TITLE"}`, visibility `public`. Exact match.
10. Branch protection query and its output — re-run live: `{"pr":0,"linear":true,"force":false,"deletions":false,"conversation":true,"admins":false}`. Exact match.
11. `PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2) on x86_64-pc-linux-gnu` — re-run against the container: exact match.
12. **The Postgres 18 volume trap** — verified inside the running container: `$PGDATA` is `/var/lib/postgresql/18/docker` and `/var/lib/postgresql` contains `18`. The chapter's claim, and the reason the volume mounts at the parent, are both correct. This is the single most valuable paragraph in the chapter and it is right.

Technical correctness of the claims the prompt singled out:

- **The git negation rule** (`.vscode/*` + `!.vscode/extensions.json` works, `.vscode/` + the same negation does not) is stated correctly and for the correct reason: git never descends into an excluded *directory*, so a negation inside one is unreachable. The repository proves it from the other direction too — `apps/api/log/.keep` **is** tracked (the root rule is `*.log`, a file pattern, so `log/` is not an excluded directory and the app's `!/log/.keep` works) while `apps/api/tmp/.keep` is **not** (the root rule is a bare `tmp/`, a directory). Same file, two outcomes, exactly as both chapters describe.
- `${VAR:?msg}` versus `${VAR:-default}`, the `$$` escape in the healthcheck, `docker compose down` keeping the volume and `-v` destroying it — all correct.
- The branch-protection/visibility trade-off, the zero-approvals explanation and the `enforce_admins: false` rationale are all accurate and match the live settings and D-053/D-059/D-060.

### Chapter 02 — `02-rails-api-skeleton.md`

Verified against the repository (14 claims):

1. `database.yml` excerpt — byte-identical to the file.
2. The `application.rb` dotenv block, including its comment — byte-identical, and placed after `Bundler.require` and **before** `module Api`.
3. The health spec excerpt — byte-identical to `spec/requests/api/v1/health_spec.rb`.
4. The controller excerpt — byte-identical.
5. The routes excerpt — byte-identical.
6. The whole `api.yml` excerpt — byte-identical to `.github/workflows/api.yml`.
7. The `maintain_test_schema!` excerpt and the claim that `.rspec` contains `--require spec_helper` — both correct.
8. The failure output quoted in step 6 (`actual collection contained: []`, `the missing elements were: ["status", "time"]`) — reproduced exactly by running the suite at `d490ca9`.
9. `git check-ignore -v apps/api/config/master.key` → `apps/api/.gitignore:25:/config/*.key` — line 25 is right.
10. `28 files inspected, no offenses detected`, `5 examples, 0 failures`, `16` tables, and the two-line `bin/rails routes` output — all reproduced exactly.
11. The `rails new` flag table — every skip verified by absence (`test/`, `config/cable.yml`, `config/storage.yml`, `config/deploy.yml`, `.kamal/`, jbuilder, `apps/api/.github/`), every keep verified by presence.
12. **`--skip-ci` behaviour** — verified in `railties-8.1.3.1/.../app_generator.rb`: `cifiles` templates `.github/workflows/ci.yml` and `.github/dependabot.yml` relative to the app root. The chapter's description is exactly right, including that in a single-app repository the generated file would be correct.
13. **`ruby/setup-ruby` has no `ruby-version-file` input** — fetched `action.yml` from the action's repository. Its inputs are `ruby-version`, `rubygems`, `bundler`, `bundler-cache`, `working-directory`, `cache-version`, `self-hosted`, `windows-toolchain`, `token`. `ruby-version` is documented as "Reads from .ruby-version, .tool-versions or mise.toml if unset", and `working-directory` as "The working directory to use for resolving paths for .ruby-version, ...". The chapter is correct, and so is the workflow's comment.
14. **The Solid migrations really are the gems' own templates** — diffed `db/migrate/20260915000001_create_solid_cache_tables.rb` against `solid_cache-1.0.10/.../db/cache_schema.rb` and `...0002_create_solid_queue_tables.rb` against `solid_queue-1.7.0/.../db/queue_schema.rb`. Identical apart from the migration wrapper and RuboCop's array-bracket spacing, exactly as claimed.

Technical correctness of the claims the prompt singled out, plus others I checked:

- **`Dotenv::Rails.files` must be set before the `Application` class** — correct, and I verified the mechanism rather than the comment. `dotenv-3.2.0/lib/dotenv/rails.rb:107` registers `config.before_configuration { load }`, and `railties-8.1.3.1/lib/rails/application.rb:75` runs `ActiveSupport.run_load_hooks(:before_configuration, base)` inside `Rails::Application.inherited` — that is, at the moment `class Application < Rails::Application` is evaluated. An assignment below that line would indeed be silently ignored.
- **"dotenv never overwrites variables that are already set"** — correct: the railtie's default config is `overwrite: false`.
- **"dotenv's `load` ignores a missing file; only `load!` raises"** — correct: `Dotenv.load(*filenames, overwrite: false, ignore: true)` versus `load!`, which is documented as raising `Errno::ENOENT`.
- **`max_connections` is Rails 8.1's name for `pool`** — correct: `ActiveRecord::DatabaseConfigurations::HashConfig` defines `max_connections`, falls back to `:pool`, and deprecates the `pool` alias.
- **`/up` returns HTML and a 500 if the app fails to boot** — correct per `Rails::HealthController` (`rescue_from(Exception) { render_down }`, `format.html { render html: html_status(color: "green") }`).
- **`master.key` / `credentials.yml.enc`** — correct in both directions: committing the key on a world-readable repository compromises everything it protects and the fix is rotation, not deletion; losing the key makes `credentials.yml.enc` permanently unreadable. Both are true and the repository state matches (key ignored, encrypted file tracked).
- **Path filters and required status checks** — the chapter states that `pull_request` path filters are evaluated against the whole PR diff, not the latest push, and that a skipped path-filtered workflow reports *no status at all*. Both are correct, and the first is demonstrated by this very PR: run `35054560655` ran on `981349e`, a commit that touched only `handoff/`.
- **"The only change RuboCop made was array-bracket spacing"** — confirmed by the diff against the gem templates.

**Reproducibility.** A reader following chapter 01 from an empty folder and then chapter 02 would end very close to this repository, but not exactly: findings 1 and 2 below are the two places where a step is missing.

**Index row.** `handoff/learning/README.md` on `main` already lists both chapters with the right titles and filenames, so nothing was needed in the PR. The implementation report's question 4 about this is correct and now moot.

## Findings

| # | Severity | Finding | Location | Steps to reproduce / evidence | Suggested fix |
|---|---|---|---|---|---|
| 1 | minor | Chapter 02 step 5 says that after installing RSpec, `bundle exec rspec` should report `0 examples, 0 failures`. A reader following the chapter in order has never created the databases — `bin/rails db:prepare` is not given as a step anywhere before step 8's `db:drop db:prepare` — so what they actually see is an abort. The statement is true only for someone who already ran `db:prepare`. | `handoff/learning/02-rails-api-skeleton.md`, step 5 ("What you should see") | `RAILS_ENV=test bin/rails db:drop` then `bundle exec rspec` → `connection to server at "::1", port 5432 failed: FATAL: database "tintara_lab_test" does not exist ... 0 examples, 0 failures, 1 error occurred outside of examples` | Add `bin/rails db:prepare` as an explicit command in step 5 (or at the end of step 4, right after the Solid migrations), and keep the `0 examples, 0 failures` expectation after it. It is a one-line addition and it is the difference between the chapter working and the reader debugging. |
| 2 | minor | Chapter 01 step 12 explains the visibility/protection trade-off well but never gives the commands that produced the end state: there is no command to switch the repository to public, and no command that *creates* the protection rule — only the failed `GET` and a later verification query. A reader cannot reproduce the protected `main` the chapter describes. | `handoff/learning/01-monorepo-bootstrap.md`, step 12 | The section contains `gh api repos/.../branches/main/protection` (a read) and the verification `--jq` query; there is no `gh repo edit --visibility public` and no `gh api -X PUT .../protection` with a body. | Add the two commands actually used, or state explicitly that the change was made through the GitHub web UI and name the settings toggled, so the reader knows which path to take. |
| 3 | nit | Chapter 02's "How to verify it yourself" quotes `git log --oneline main..HEAD` with four commits. The branch has six: `af2b459` (the report) and `981349e` (the chapters) are missing. A reader comparing output sees a mismatch. | `handoff/learning/02-rails-api-skeleton.md`, section 8 | `git log --oneline main..HEAD` → six lines | Either add the two commits, or say "the first four commits; the report and this chapter follow". |
| 4 | nit | Chapter 02 step 6 says the five specs fail because "the route does not exist, so the response body is empty". The body is not empty: the response is a 404 `text/html` error page, and `parsed_body.keys` is `[]` because the parsed HTML has no keys. The quoted RSpec output is verbatim correct; only this sentence of narration is loose. | `handoff/learning/02-rails-api-skeleton.md`, step 6 | At `d490ca9`: example 2 fails with `expected: "application/json" got: "text/html"`, i.e. a rendered 404 page | Reword to "the route does not exist, so Rails answers with a 404 HTML page that has no JSON keys at all". |
| 5 | nit | The implementation report's follow-up 3 says `bin/ci` / `config/ci.rb` run "RuboCop, Brakeman, bundler-audit and the (absent) default test task". The generated `config/ci.rb` contains no test step at all — because `--skip-test` was used, the generator never wrote one. Chapter 02 states this correctly; only the report is imprecise. | `handoff/agent-outputs/implementation/feature-002-rails-api-skeleton.md`, "Suggested follow-ups" 3 | `cat apps/api/config/ci.rb` → steps are Setup, Style: Ruby, Security: Gem audit, Security: Brakeman. No test step. | Drop "and the (absent) default test task" from the follow-up. Cosmetic; the follow-up's actual suggestion stands. |

**Advisory, deliberately not filed as findings** (they are decisions for the owner, not defects in this PR — see "Questions for the owner"): the workflow declares no `permissions:` block, and the path filter interacts badly with D-060's plan to make these jobs required status checks.

## Security & conventions

- **Secrets:** nothing secret-shaped is committed. `git ls-files` contains no `master.key`, no `.env` (only `.env.example`, committed in Feature 1 with documented placeholders), no `.DS_Store` and no `*.key`. `config/credentials.yml.enc` is tracked, which is correct and expected, and `config/master.key` is ignored by `apps/api/.gitignore:25:/config/*.key`. I grepped the whole `apps/api` + `.github` diff for password/secret/token/key shapes: the only literals are `tintara_ci` / `tintara_ci_password` in the workflow, which the prompt explicitly allows and which the chapter defends well (single-job database, destroyed with the job, and an explicit rule that nothing real ever goes in that file). The report's question 2 — asking the owner to store `config/master.key` somewhere safe outside the repository — is the right thing to have raised, and I second it.
- **Feature 4 / Feature 5 surface:** none of it is present. `config/initializers/cors.rb` is the generated file with every line commented out, `rack-cors` is commented in the `Gemfile` and absent from `Gemfile.lock`, and there is no CSRF handling, no rate limiting, no session or user table, and no model.
- **Information disclosure:** the health response carries exactly `status` and `time`, with a spec enforcing it. No Rails version, environment name or database state is exposed. Rails' `/up` is untouched and remains a separate endpoint.
- **CI hardening (advisory):** the workflow sets no `permissions:` block, so the job token inherits the repository default. Neither job needs to write anything. On a repository anyone can read (D-059), adding `permissions: contents: read` at the workflow level is a cheap default-deny.
- **Branch name** `feature/2-rails-api-skeleton` — correct. **PR title** is character-for-character `Feature 2: create the Rails API skeleton with RSpec, RuboCop and CI`. **All six commits** are prefixed `Feature 2:`. **PR description** follows `.github/pull_request_template.md` and links `handoff/agent-outputs/implementation/feature-002-rails-api-skeleton.md`. The PR is **OPEN and unmerged**.
- **English only:** every file in the diff, including both chapters, the report and all code comments, is in English.
- **Scope:** the diff touches `apps/api/**`, `.github/workflows/api.yml`, the one `CLAUDE.md` §7 API line, the implementation report and the two chapters — nothing else. The extension commit `981349e` is documentation-only: `git diff --stat 981349e^ 981349e -- apps .github docker-compose.yml CLAUDE.md` is empty.
- **QA hygiene:** this report is untracked and uncommitted, no application code was modified, nothing was pushed to the branch, and the root `.env` was byte-compared after being restored. The databases were left prepared and the working tree clean.

### Judgement on the report's three deviations (prompt G.5)

1. **`--skip-ci` added to `rails new`** — **agree, and it was the right call.** I confirmed in `railties-8.1.3.1/lib/rails/generators/rails/app/app_generator.rb` that `cifiles` writes `.github/workflows/ci.yml` and `.github/dependabot.yml` relative to the app root, i.e. at `apps/api/.github/`. GitHub only reads workflows from the repository root, so those files would never have run. Committing a dead workflow next to a live one is worse than not having it: the next reader would reasonably believe it is what CI does. The prompt put a single root workflow in scope, and the agent flagged the deviation rather than hiding it. Worth recording against D-063 so the reasoning survives.
2. **`storage/` not in `.gitignore`** — **agree.** Rails only writes that entry when Active Storage is installed, and D-063 skips it; there is no `storage/` directory and the Dockerfile does not reference one either (I checked). Adding the line "for completeness" would leave a rule describing a component this app does not have. The agent's framing — say why a checklist item does not apply instead of manufacturing compliance — is exactly right, and the prompt's requirement was to *confirm*, which it did.
3. **`apps/api/tmp/.keep` not tracked** — **agree with both the diagnosis and the decision to leave it.** The root `.gitignore:24:tmp/` excludes `apps/api/tmp/` as a directory, so `apps/api/.gitignore`'s `!/tmp/.keep` is unreachable; `git check-ignore -v apps/api/tmp/.keep` confirms the root rule wins. The contrast with `apps/api/log/.keep`, which *is* tracked because the root rule there is the file pattern `*.log`, proves the mechanism. The practical effect is nil — Rails recreates `tmp/`, `tmp/cache` and `tmp/pids` on boot, and both the server and the suite were verified working — and changing a Feature 1 file was out of scope. The suggested fix (narrow the root rule to `/tmp/`) is correct and is already folded into Feature 3 per the status file.

## Questions for the owner

1. **`permissions:` on the API workflow.** Neither job writes anything, so `permissions: contents: read` at the workflow level would be a free hardening on a repository anyone can read (D-059). It is a one-line addition and could go into this PR or into Feature 3's workflow task alongside `web.yml`. Which do you prefer? I did not file it as a finding because it is a policy choice, not a defect.
2. **Path filters versus required status checks (D-060 carry-over).** The status file plans to make `api.yml` a required check on `main` once it has run there. Be aware of the interaction: a path-filtered workflow that does not run reports *no status*, not a passing one — so once `RuboCop` and `RSpec` are required, a PR touching only `apps/web/**` would sit permanently pending. Chapter 02 already documents this, to its credit. The usual fixes are a small always-running job that reports the check name and short-circuits, or dropping the path filter on the required jobs. Worth deciding before the carry-over is executed rather than after.
3. **D-052, D-062 and D-063 are still `Proposed` in the decision log.** All three are implemented and verified in this PR. The implementation report raised the same point (its question 1). If you accept them, they should move to `Accepted`, and D-063 should record the `--skip-ci` addition described above, since it is a real extension of that decision's scope that the log does not yet mention.
4. **Nothing was unverifiable.** Every claim in the prompt's checklist was checked directly. The only thing I did not re-do is Feature 1's own history, which is out of this PR's scope.

## Verdict

**PASS WITH NOTES.**

No `blocker` and no `major` finding, so nothing must be fixed before merging under D-054. The application code, the configuration, the CI workflow and the specs are correct, independently verified, and within scope. The three deviations are all justified and well reasoned.

The five findings are documentation-quality issues: two `minor` reproducibility gaps in the chapters (findings 1 and 2), and three `nit`s. Under D-054 those are the owner's call. My recommendation is to fix findings **1 and 2** in this PR with a short fix round — chapter 02 step 5 currently tells a reader to expect output they cannot get, and chapter 01 never gives the commands that produced the repository's protection settings, which is precisely the kind of gap D-064 exists to prevent. Findings 3, 4 and 5 are one-line corrections that can ride along in the same round or be dropped entirely.
