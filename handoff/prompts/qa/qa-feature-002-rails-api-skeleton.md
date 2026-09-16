# QA — Feature 2: create the Rails API skeleton with RSpec, RuboCop and CI

**Type:** QA · **Target:** PR #1 https://github.com/Myepes05/tintara-lab/pull/1, branch `feature/2-rails-api-skeleton`
**Implementation prompts:** `handoff/prompts/implementation/feature-002-rails-api-skeleton.md` and the extension `handoff/prompts/implementation/feature-002-rails-api-skeleton-ext-learning.md`
**Implementation report:** `handoff/agent-outputs/implementation/feature-002-rails-api-skeleton.md`
**Report file:** `handoff/agent-outputs/qa/qa-feature-002-rails-api-skeleton.md` (use `handoff/templates/qa-output.md`)

## Rules
- **Do not modify application code, configuration, workflows or chapters.** Do not push to the branch. Do not commit your report; leave it untracked and switch back to `main` when you finish (CLAUDE.md §5).
- Verify everything yourself. The implementation report is a claim, not evidence.
- Classify findings: `blocker` (must fix before merge), `major`, `minor`, `nit`.
- If you find nothing wrong in an area, say so explicitly. A report that only lists problems hides what was actually checked.

## Before you start
1. Read `CLAUDE.md`, especially §4 (rules), §6 (architecture) and §7b (learning chapters).
2. Read both implementation prompts and the implementation report.
3. Read these decisions: D-028, D-030, D-031, D-033, D-035, D-042, D-050, D-051, D-052, D-053, D-055, D-058, D-059, D-063, D-064.
4. Check out the branch. Start Docker Desktop, then `docker compose up -d` from the repo root.

## A. Functional verification
1. From `apps/api`: `bundle install`, `bin/rails db:prepare`, `bundle exec rspec`, `bundle exec rubocop`. All must pass. Record the real counts (examples, failures, offenses).
2. **Clean-database path:** `bin/rails db:drop db:prepare` then `bundle exec rspec` again. The Solid Cache and Solid Queue tables must be created from scratch in the primary database, with no separate cache or queue database anywhere.
3. Boot the server and call `GET /api/v1/health`. Verify: 200, JSON content type, `status` is `ok`, `time` parses, and **no other keys**.
4. Confirm Rails' own `/up` still works and is a different endpoint.
5. `bin/rails routes` must show only these two health routes and nothing unexpected.

## B. Decision compliance
| Check | Decision |
|---|---|
| API-only Rails 8.1 app on PostgreSQL at `apps/api` | D-000, D-032 |
| Endpoint namespaced under `/api/v1` | D-031 |
| Solid Cache and Solid Queue on the **primary** database; no `cache`/`queue` database entries; their tables in `db/schema.rb` | D-052 |
| Skipped: Action Cable, Active Storage, Action Mailbox, default test framework, Jbuilder, Kamal. Kept: Action Mailer, Solid Cache, Solid Queue, Brakeman, RuboCop | D-063 |
| RuboCop inherits `rubocop-rails-omakase` with no custom rules | D-062 |
| No serializer library added | D-051 |
| Nothing from Feature 4 or 5 (CORS config beyond the generated commented file, CSRF, rate limiting, auth, models) | scope |

For the last row: `config/initializers/cors.rb` is generated commented-out by Rails. Confirm it is still inert and no CORS gem is configured.

## C. Configuration and secrets
1. `config/database.yml`: no credentials in the file, values from the environment, development and test databases distinct, production reading `DATABASE_URL`.
2. **Dotenv wiring:** the root `.env` is read from `apps/api`, and `Dotenv::Rails.files` is assigned **before** the `Application` class is defined. Verify the ordering matters by checking the file, not by trusting the comment.
3. **Simulate CI locally:** move the root `.env` aside, export `POSTGRES_*` by hand, and run `bin/rails db:prepare` and `bundle exec rspec` from `apps/api`. Nothing may depend on the file existing. Restore `.env` afterwards.
4. `git ls-files` must **not** contain `config/master.key`, any `.env`, or `.DS_Store`. `config/credentials.yml.enc` **is** expected to be tracked; confirm `git check-ignore -v apps/api/config/master.key` shows the ignore rule.
5. Search the diff for anything secret-shaped. The repository is readable by everyone (D-059), so this matters more than usual. The CI workflow's throwaway Postgres credentials are acceptable; judge whether anything else is.

## D. CI workflow (`.github/workflows/api.yml`)
1. Triggers on pull requests to `main` and pushes to `main`, with path filters `apps/api/**` and the workflow file itself.
2. Separate `lint` and `test` jobs.
3. Postgres **18** service with a health check; the job waits for it.
4. Ruby resolved from `apps/api/.ruby-version`, bundler caching on, `working-directory` set.
5. **Verify the pinned action versions exist and are current**, from the actions' own repositories, not from the report: `actions/checkout` and `ruby/setup-ruby`. Note whether the pin is a sensible major-version pin for each action's own release convention.
6. Confirm the workflow actually ran and passed on the PR head commit: `gh run list --branch feature/2-rails-api-skeleton`. A green CI claim in the report is not evidence.
7. Consider whether the path filters would skip CI in a case where it should run.

## E. Spec quality (D-042, D-050)
1. `git log --oneline main..HEAD`: the spec commit `d490ca9` must precede the implementation commit `cdd649e`.
2. Read `spec/requests/api/v1/health_spec.rb`. Does it cover the behavior, including that nothing extra is exposed? Would it fail if the implementation regressed? Is anything asserted that doesn't matter?
3. `spec/rails_helper.rb` and the support files: FactoryBot syntax methods, shoulda-matchers, `maintain_test_schema!`.
4. **Note for later, not a finding:** `config/environments/test.rb` sets `config.cache_store = :null_store`. Feature 4 needs a cache store that can hold rate-limit counters in test. Confirm this is the current state and flag it as a carry-over.

## F. Learning chapters (D-064)
Both chapters were written by the same agent: `handoff/learning/01-monorepo-bootstrap.md` (Feature 1, backfilled) and `handoff/learning/02-rails-api-skeleton.md` (Feature 2).

For **each** chapter:
1. **Accuracy:** every command, file path, file excerpt, commit SHA and output must match this repository. Spot-check at least 8 concrete claims per chapter against the real files, and list which ones you checked.
2. **Technical correctness:** the explanations must be true. Pay attention to the claims that are easy to get wrong, for example:
   - the git rule about negations inside an excluded directory (`.vscode/*` and `tmp/.keep`)
   - the Postgres 18 volume path
   - `Dotenv::Rails.files` having to be set before the `Application` class
   - what `ruby/setup-ruby` reads when `ruby-version` is omitted
   - what losing `config/master.key` costs, and what committing it would cost
3. **Reproducibility:** could a reader who follows chapter 01 from an empty folder, then chapter 02, reach this repository's state? Look for missing steps, wrong ordering, and steps that only work because of something the chapter never mentions.
4. **Teaching quality:** are terms explained before use? Is the "Traps, mistakes and things we avoided" section substantive rather than filler?
5. **Structure:** the 10 sections of `handoff/templates/learning-chapter.md` are present, and `handoff/learning/README.md` lists both chapters.

A chapter that states something untrue is a `major` finding, even when the code is correct: it teaches the owner the wrong thing.

## G. Conventions and scope
1. Branch name, PR title exactly `Feature 2: create the Rails API skeleton with RSpec, RuboCop and CI`, commits prefixed `Feature 2:`.
2. The PR description follows the template and links the report.
3. English everywhere.
4. **Scope:** `git diff --stat main...HEAD`. Nothing outside `apps/api`, `.github/workflows/api.yml`, `CLAUDE.md` §7, the implementation report and the two chapters. In particular the extension task was documentation-only: confirm the learning commit `981349e` touched no code.
5. The report's three deviations (`--skip-ci`, `storage/`, `tmp/.keep`) are each justified. Judge whether you agree, and say so.

## Verdict
`PASS`, `PASS WITH NOTES` or `FAIL`, with justification. Remember: `blocker` and `major` findings get fixed in this same PR before the owner merges (D-054).

## Questions
Anything you can't verify, or that looks like a decision rather than a defect, goes under "Questions for the owner" instead of being reported as a finding.
