# Feature 2 — extension: ignore key files repository-wide

**Type:** Implementation (extension of the open Feature 2 PR) · **Phase:** 1 — Foundation
**Branch:** `feature/2-rails-api-skeleton` (the branch you are on) · **PR:** #1 — add to it, do not merge
**Commit prefix:** `Feature 2:`
**Size:** one line of `.gitignore`, plus verification. Nothing else.

## The problem the orchestrator found
`apps/api/.gitignore` ignores `/config/*.key`, which protects `config/master.key` **while that file exists in the working tree**. It only exists on your branch. On `main` today, where `apps/api/.gitignore` is not tracked yet, git reports:

```
$ git status --porcelain --untracked-files=all apps/api
?? apps/api/config/master.key
```

So on `main` the key is an ordinary untracked file, and a single `git add -A` would stage it. The repository is readable by everyone (D-059), so pushing that would publish the key that decrypts `config/credentials.yml.enc`. The remedy would then be rotating every secret, not deleting the commit.

This will stop being reachable once your PR merges, but the same gap returns for any future app directory, and the protection should not depend on which branch is checked out.

## What to do
1. Add a repository-wide rule for private keys to the **root** `.gitignore`, in its own commented section. It must cover `master.key` and any other `*.key` file, at any depth.
2. Do **not** remove or weaken `apps/api/.gitignore`'s own `/config/*.key` rule. Defense in depth is intended here.
3. Verify, from the repository root:
   ```sh
   git check-ignore -v apps/api/config/master.key      # must now match the ROOT .gitignore rule
   git status --porcelain --untracked-files=all         # apps/api/config/master.key must NOT appear
   git ls-files | grep -i "\.key$" || echo "no key files tracked"
   ```
   Also confirm from `main`'s perspective that the rule would have caught it: explain in your report which rule matches and why it now wins.
4. Consider whether any other credential-shaped file has the same branch-dependent gap (for example `.env` files inside app directories). If you find one, report it; fix only if it is the same one-line kind of change and say so clearly.

## Then update the documentation you already wrote
- **Chapter 01** (`handoff/learning/01-monorepo-bootstrap.md`): the `.gitignore` walkthrough and the traps section should include this rule and the reasoning — an ignore rule that lives inside a subdirectory only protects you when that subdirectory's `.gitignore` is present on the branch you have checked out.
- **Chapter 02** (`handoff/learning/02-rails-api-skeleton.md`): its `master.key` trap should reference the root-level rule as the actual protection.
- **Your implementation report:** add a short "Fix round: repository-wide key ignore" section with the verification output.

## Out of scope
- Any change to application code, `docker-compose.yml`, the CI workflow or Rails configuration.
- Any change to the decision log, status, plan or prompts.
- Rebasing, merging `main`, or merging the PR.

## Acceptance criteria
- [ ] The root `.gitignore` ignores `*.key` files repository-wide, in a commented section
- [ ] `apps/api/.gitignore` is unchanged
- [ ] `git check-ignore -v apps/api/config/master.key` matches the root rule, with the output in the report
- [ ] No `.key` file is tracked anywhere
- [ ] Chapters 01 and 02 updated to describe the rule and why it exists
- [ ] Report updated with the fix-round section
- [ ] Committed to `feature/2-rails-api-skeleton` with a `Feature 2:` prefix and pushed to PR #1; not merged
- [ ] `git diff main...HEAD -- apps .github docker-compose.yml` shows no new changes beyond your earlier Feature 2 commits
