# Feature 2 — extension: write the learning chapters for Features 1 and 2

**Type:** Implementation (extension of the open Feature 2 PR) · **Phase:** 1 — Foundation
**Branch:** `feature/2-rails-api-skeleton` (the branch you are already on)
**PR:** https://github.com/Myepes05/tintara-lab/pull/1 — add to it, do not open a new one, do not merge
**Commit prefix:** `Feature 2:` (same as your other commits)
**Deliverables:** `handoff/learning/01-monorepo-bootstrap.md` and `handoff/learning/02-rails-api-skeleton.md`

## Why this exists
The owner wants to be able to build an app like this by himself afterwards. A new decision, **D-064**, adds `handoff/learning/`: one teaching chapter per implementation task, written by the agent that did the work. Features 1 and 2 were finished before that decision, so their chapters are written now. You are asked for both because you have first-hand context on Feature 2 and the Feature 1 result is fully documented and present in the repository.

From Feature 3 onward, each implementation prompt includes its own chapter, so this is a one-time backfill.

## Before you start
1. Re-read `CLAUDE.md`, especially the new **§7b, The learning chapter**, and the updated §2, §3 and §5.
2. Read `handoff/templates/learning-chapter.md`. It is the required structure.
3. Read `handoff/learning/README.md`. It holds the rules and the index.
4. Read `handoff/decisions/decision-log.md`, entry **D-064**, plus the entries each chapter has to explain.
5. Read `handoff/agent-outputs/implementation/feature-001-monorepo-bootstrap.md`. It is your main source for chapter 01, together with the files themselves.
6. `git pull origin main` is **not** needed. `main` moved ahead of your branch with a `docs 1` commit and this session's handoff changes are still local and uncommitted; do not rebase or merge `main` into your branch. Work on your branch as it is.

## Audience
A developer who can program, but who has never set up this stack end to end: a monorepo, Docker Postgres, a Rails 8 API-only app, RSpec, RuboCop, GitHub Actions. Assume no knowledge of Rails conventions, Docker Compose or GitHub Actions syntax. Explain every term the first time it appears.

## Hard rules
1. **Teach, don't report.** Your report proves the work was done. The chapter explains how someone else would do it, and why. Don't restate the report; rewrite the knowledge for a learner.
2. **Everything real.** Every command, file path and file excerpt must be the actual one in this repository. Never invent an illustrative example. If you quote a file, quote what it contains.
3. **Reproducible.** A reader starting from an empty folder must be able to follow chapter 01, then chapter 02, and end with the same repository. Order the steps as they should be done, which is not always the order they happened.
4. **Explain the "why not".** For every meaningful choice, say what was rejected and why. Link the decision IDs (D-XXX) so a reader can read the full reasoning.
5. **No invented history.** If you don't know whether something was tried in Feature 1, don't claim it was. Document what the files and the report show.

## Chapter 01 — `handoff/learning/01-monorepo-bootstrap.md`
Cover the Feature 1 work: turning a folder into a repository with root scaffolding, a Postgres container and a GitHub repository.

Must explain, at minimum:
- What a monorepo is here, and why one repo holds both apps (D-032), with lowercase `apps/` and why casing matters across macOS, Linux CI and hosting platforms.
- `git init -b main`, and why the base branch is set explicitly.
- Every root file and what it's for: `.gitignore` (including the `.vscode/*` plus `!.vscode/extensions.json` pattern and why a plain `.vscode/` would break the exception), `.editorconfig`, `README.md`, `.env.example`, `.github/pull_request_template.md`, `apps/.gitkeep` and why empty directories need a placeholder in git.
- `docker-compose.yml` line by line: what Docker Compose is, what the `db` service does, why the image is pinned to a major version rather than `latest`, how `${POSTGRES_USER:?...}` fails loudly when `.env` is missing, why the host port is configurable, what the healthcheck does and why it matters, what a named volume is and where the data actually lives.
- **The Postgres 18 volume trap:** the official image changed where the data directory lives, so the volume mounts at `/var/lib/postgresql` and not the path most tutorials still show.
- The `.env` and `.env.example` split, and why one is committed and the other never is.
- Creating the GitHub repository with `gh`, and configuring squash-only merges with the PR title as the commit message, and how that enforces the project's commit convention (D-034, D-035).
- **Branch protection and repository visibility (D-059, D-060):** protection was not available on a private repository under the owner's plan, the repository was therefore switched to being readable by everyone, and what that trade-off means, including that anything committed becomes published permanently. Present it as the decision it was, with the alternative that existed (a paid plan).
- Why administrators are deliberately excluded from the protection rule, and how that keeps direct `docs N` commits working (D-053).

## Chapter 02 — `handoff/learning/02-rails-api-skeleton.md`
Cover your own Feature 2 work.

Must explain, at minimum:
- What an API-only Rails app is, and how it differs from a full Rails app.
- The `rails new` command you ran, **flag by flag**: what each skip removes, and why this project doesn't need it (D-063). Include `--skip-ci` and the reason you added it: Rails generates a workflow inside `apps/api`, where GitHub would never run it.
- How `config/database.yml` reads the environment, how the root `.env` is loaded from `apps/api`, and why credentials are never written into a second file.
- **Solid Cache and Solid Queue on one database (D-052):** what these components are, what Rails 8 does by default, exactly what you changed, and why one database is the right call at this size.
- RSpec, FactoryBot and shoulda-matchers: what each is for, how they're wired, and what `rails_helper` does.
- **Spec-driven development in practice:** show that the spec commit (`d490ca9`) precedes the implementation commit (`cdd649e`), explain why the order is enforced, and what writing the health spec first actually felt like: the failure you saw before the endpoint existed, and why that failure is the point.
- The health endpoint: routing under `/api/v1` (D-031), the controller, why the response deliberately exposes nothing beyond status and time, and how it differs from the Rails default `/up`.
- The CI workflow, section by section: what GitHub Actions is, triggers, why path filters exist in a monorepo, why lint and test are separate jobs, what a service container is and why the Postgres service needs a health check, why actions are pinned to verified versions, and how CI gets its database credentials without any secret.
- **The traps you hit**, including the ones in your report's deviations: the root `.gitignore` `tmp/` rule outranking `apps/api/.gitignore`'s `!/tmp/.keep` negation and why git behaves that way; `storage/` not existing because Active Storage is skipped; and anything else that failed or surprised you on the first attempt. Write these honestly, they are the most valuable part of the chapter.
- **`config/master.key`:** what it is, why it's ignored, why `credentials.yml.enc` is committed, and that losing the key means losing the ability to read the credentials file.

## Also required
- Add both rows to the table in `handoff/learning/README.md` if they are missing or inaccurate.
- Update your implementation report `handoff/agent-outputs/implementation/feature-002-rails-api-skeleton.md`: add a section "Learning chapters (D-064)" naming both files, saying that chapter 01 was backfilled from the Feature 1 report and the repository state, and listing the traps each chapter documents.

## Out of scope
- Any change to application code, configuration or the CI workflow. This task writes documentation only.
- Any change to the decision log, the status file, the plan or any prompt.
- Rebasing, merging `main`, merging the PR, or opening a new PR.
- Fixing the follow-ups from your report, such as the root `.gitignore` `tmp/` rule. Mention it in chapter 02 as a trap; don't change it.

## Acceptance criteria
- [ ] `handoff/learning/01-monorepo-bootstrap.md` exists, follows the template's 10 sections, and covers every point listed above
- [ ] `handoff/learning/02-rails-api-skeleton.md` exists, follows the template's 10 sections, and covers every point listed above
- [ ] Every command and file excerpt matches this repository exactly
- [ ] Each chapter's "Traps, mistakes and things we avoided" section is substantive, not filler
- [ ] Decisions are explained with their rejected alternatives and linked by ID
- [ ] `handoff/learning/README.md` lists both chapters
- [ ] The implementation report has the "Learning chapters (D-064)" section
- [ ] Both chapters and the report update are committed to `feature/2-rails-api-skeleton` with `Feature 2:` prefixes and pushed to PR #1
- [ ] No application code, configuration or workflow file changed (`git diff` on those paths is empty)
- [ ] The PR is not merged

## Verification before you finish
```
git log --oneline main..HEAD
git diff --stat main..HEAD -- apps .github docker-compose.yml
git status --short
gh pr view 1 --json title,state,url
```
The second command must show no changes beyond what your earlier Feature 2 commits already introduced.

## Questions
If a point above can't be documented truthfully, because you don't know what happened in Feature 1 or the repository contradicts the report, don't invent it. Write what the evidence supports, and list the gap under "Questions for the owner" in your report.
