# Feature 2 — fix round 1: QA findings and workflow permissions

**Type:** Implementation (fix round on the open Feature 2 PR, D-054) · **Phase:** 1 — Foundation
**Branch:** `feature/2-rails-api-skeleton` (the branch you are on) · **PR:** #1 — add to it, do not merge
**Commit prefix:** `Feature 2: fix ...`
**QA report:** `handoff/agent-outputs/qa/qa-feature-002-rails-api-skeleton.md` (untracked; read it first)

## Context
QA returned **PASS WITH NOTES**: no blocker and no major finding, so nothing here is required by D-054. The owner chose to fix all five findings plus one hardening item, because four of them are in teaching material the project exists to produce (D-064, D-067).

Do not re-litigate the findings. If you disagree with one, implement it anyway and say why in your report.

## Task 1 — Chapter 02 step 5 is not reproducible (QA finding 1, `minor`)
`handoff/learning/02-rails-api-skeleton.md`, step 5 tells the reader to expect `0 examples, 0 failures` after installing RSpec. A reader following the chapter in order has never created the databases, so they get a connection error instead.

- Add `bin/rails db:prepare` as an explicit step, with a one-line explanation of what it does, placed where a reader needs it: after the Solid Cache and Solid Queue migrations exist and before the first `rspec` run.
- Keep the `0 examples, 0 failures` expectation after that command.
- Then re-read steps 1 to 10 as a whole, from the point of view of someone starting from chapter 01's end state, and fix **any other** place where you assumed state the reader does not have: a running container, an installed gem, an existing database, an environment variable. This is the general rule now recorded as **D-067**; finding 1 is one instance of it, and QA only checked the one it happened to trip over.

## Task 2 — Chapter 01 step 12 has no reproducible path (QA finding 2, `minor`)
`handoff/learning/01-monorepo-bootstrap.md`, step 12 explains the visibility and branch-protection trade-off well, but never gives the commands that produced the end state.

- Add the commands that were actually used. The Feature 1 report's addendum has them verbatim: the `gh repo edit` visibility change and the `gh api -X PUT .../branches/main/protection` call, plus the verification query. Use the report as your source; do not invent a payload.
- Keep the existing framing: the trade-off, the alternative that existed (a paid plan), and what became published. Then say plainly that a reader who keeps the repository private and pays for a plan runs the same protection command without the visibility step.
- State the protection settings the payload produces, and why administrators are deliberately not included (D-053).

## Task 3 — Chapter 02 commit list is stale (QA finding 3, `nit`)
Section 8 quotes `git log --oneline main..HEAD` with four commits; the branch now has more. Either list them all, or say "the first four commits; the report, the chapters and this fix round follow". Prefer the second: it stays true as the branch grows.

## Task 4 — Chapter 02 step 6 narration is loose (QA finding 4, `nit`)
It says the specs fail because "the route does not exist, so the response body is empty". The body is a 404 HTML error page; `parsed_body.keys` is empty because parsed HTML has no keys. Reword to match what actually happens. The quoted RSpec output is correct; leave it.

## Task 5 — Implementation report imprecision (QA finding 5, `nit`)
In `handoff/agent-outputs/implementation/feature-002-rails-api-skeleton.md`, follow-up 3 says `bin/ci` runs "RuboCop, Brakeman, bundler-audit and the (absent) default test task". `config/ci.rb` has no test step at all, because `--skip-test` was used. Drop that clause; the follow-up's actual suggestion stands.

## Task 6 — Least-privilege token in the API workflow (D-066)
Add to `.github/workflows/api.yml`, at the **workflow level** (not per job):

```yaml
permissions:
  contents: read
```

Neither job writes anything, and the repository is readable by everyone (D-059), so the job token should be default-deny. Place it with a short comment saying why. Then update chapter 02's workflow walkthrough to cover it: what the token is, what it can do by default, and why least privilege matters here.

## Explicitly NOT in this round
- **Path filters and required status checks.** QA's question 2 is real, and the owner decided it as **D-065**: pull requests run both workflows with no path filters, pushes to `main` keep them. That change is applied in Feature 3, together with `web.yml`. Do not change the triggers now.
- The root `.gitignore` `tmp/` and `*.key` rules: also Feature 3 (D-065 note in the status file).
- Any application code, Rails configuration, specs or `docker-compose.yml`.

## Report
Add a section "**Fix round 1**" to your implementation report:
- a row per finding: what you changed and where
- the chapter-wide reproducibility re-read from task 1: what else you found, or explicitly "nothing else found"
- the workflow permissions change and the CI run that proves the workflow still passes
- anything you disagreed with, and why you did it anyway

## Acceptance criteria
- [ ] Findings 1 to 5 addressed as described
- [ ] Chapter 02 re-read end to end for reader-state assumptions (D-067), with the result stated in the report
- [ ] `permissions: contents: read` at workflow level in `api.yml`, explained in chapter 02
- [ ] No change to application code, Rails config, specs, `docker-compose.yml`, workflow triggers or the root `.gitignore`
- [ ] `bundle exec rspec` and `bundle exec rubocop` still pass locally, with output in the report
- [ ] CI green on the new head commit (link the run)
- [ ] Commits prefixed `Feature 2: fix ...`, pushed to PR #1, not merged

## Verification
```
git log --oneline main..HEAD
git diff --stat main...HEAD -- apps docker-compose.yml
git diff main...HEAD -- .github/workflows/api.yml
cd apps/api && bundle exec rspec && bundle exec rubocop
gh run list --branch feature/2-rails-api-skeleton --limit 3
```
The second command must show no new changes beyond your earlier Feature 2 commits.
