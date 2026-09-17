# Feature 3: create the React Router web skeleton with Jest, ESLint and CI

**Type:** Implementation · **Phase:** 1 — Foundation
**Branch:** `feature/3-web-skeleton`
**PR title (exact):** `Feature 3: create the React Router web skeleton with Jest, ESLint and CI`
**Report file:** `handoff/agent-outputs/implementation/feature-003-web-skeleton.md` (use `handoff/templates/implementation-output.md`)
**Learning chapter:** `handoff/learning/03-web-skeleton.md` (use `handoff/templates/learning-chapter.md`, see CLAUDE.md §7b and D-067)
**Working directory:** `/Users/miguelangel/Documents/projects/tintara-lab`

## Before you start
1. Read `CLAUDE.md` completely, especially §4, §6 and §7b.
2. Read `handoff/status/current-status.md`.
3. Read these decisions: D-005, D-018, D-019, D-020, D-021, D-024, D-025, D-032, D-033, D-039, D-041, D-045, D-046, D-050, D-053, D-055, D-059, D-064, D-065, D-066, D-067.
4. Read `handoff/learning/02-rails-api-skeleton.md`. Your chapter continues from it, and its CI walkthrough is the pattern to follow.
5. Confirm `main` is clean and up to date, and that PR #1 is merged (`apps/api` must exist on `main`). Branch from up-to-date `main`.

Depends on: Feature 1 (repo, Postgres), Feature 2 (API, `api.yml` as the workflow pattern).

## Goal
Create the frontend application at `apps/web`: React Router in framework mode with server-side rendering, TypeScript, Tailwind, ESLint and Prettier, and Jest with React Testing Library. Add its CI workflow, align both workflows with D-065 and D-066, and fix two root `.gitignore` rules.

## Scope
### In scope
- The React Router app at `apps/web`, server-rendered, TypeScript strict
- pnpm through corepack, with the version pinned in `package.json`
- Tailwind
- ESLint and Prettier
- Jest, React Testing Library, jsdom, plus one real test
- A typed environment-config module (see requirement 6)
- `.github/workflows/web.yml`, and the D-065/D-066 changes to `api.yml`
- Two root `.gitignore` fixes (requirement 9)
- The Web line of `CLAUDE.md` §7
- Learning chapter 03

### Out of scope (do NOT do)
- Any page design, section, component or content of the real site (Phase 4)
- Any call to the Rails API, any loader that fetches real data, any admin route
- Cloudinary, SEO tags, sitemap, fonts, colors from the mockups
- Anything inside `apps/api`
- Configuring required status checks on `main` (report the command instead, requirement 10)
- Editing any `handoff/` file other than your report and your chapter

## Requirements

### 1. Create the app
- Use the current stable **React Router framework mode** setup, verified from its official documentation, with server-side rendering **on** (D-018). Record the exact command and the versions you pinned (D-055).
- The app lives at `apps/web`. If the generator creates its own git repository, remove it (chapter 02, trap 1, describes the same problem for Rails).
- **pnpm** (D-021): enable it through corepack, and pin the version in `package.json` via `packageManager`. Do not install pnpm globally another way.
- TypeScript in **strict** mode.

### 2. Tailwind (D-005)
- Install and wire Tailwind for this app, following its current official instructions for a Vite-based React Router project.
- No design tokens, palette or fonts yet: that is Feature 14. One utility class proving it compiles is enough.
- Do **not** add Material UI.

### 3. ESLint and Prettier
- ESLint with the TypeScript and React configuration appropriate to the versions you installed, and Prettier for formatting, with no rule conflicts between them.
- Scripts in `package.json`: `lint`, `typecheck`, `test`, `build`, `dev`, and whatever the framework needs to serve a production build.
- `pnpm lint` and `pnpm typecheck` must both pass with zero warnings.

### 4. Jest (D-020, firm — Vitest is not an option)
- Jest with React Testing Library and jsdom, plus a TypeScript transform.
- Expect friction: the framework's tooling is built around Vite, and Jest is not. Solve it, and **document how in your chapter** — this is one of the most useful things chapter 03 can teach.
- `pnpm test` runs the suite and must pass.

### 5. Spec first (D-042, D-050)
Write and commit the test **before** the code it covers. The behavior to cover:
- A small presentational component (for example a `SiteShell` or `Placeholder` that renders a heading and its children) rendered through React Testing Library.
- The environment-config module from requirement 6: it returns the configured values, and it fails loudly when a required server-side variable is missing.

Trivial tests that assert nothing meaningful are worse than none. The commit order must show specs first.

### 6. Environment configuration module
The browser must never see server-only values (D-039, D-045). Create one module that centralizes configuration, so no component ever reads environment variables directly (D-020 requires this for testability too).

- **Server-only values:** `API_INTERNAL_URL` (where server-side loaders will call Rails) and `API_INTERNAL_TOKEN` (the rate-limit exemption header of D-045). These must never reach the client bundle. Make that structurally impossible, not merely a convention, using the framework's own server/client module conventions, and explain the mechanism in your chapter.
- **Client-visible value:** the public API base URL the browser will use (D-039: a same-site subdomain in production). Give it a development default.
- Reading a missing required value fails with a clear message naming the variable.
- Provide `apps/web/.env.example` with every variable documented. Never commit `.env`.
- No real values: nothing is deployed yet, and nothing calls the API in this task.

### 7. One route
- A single route at `/` rendering the component from requirement 5. Placeholder content only, no design.
- It must be **server-rendered**: prove it, for example by showing that the initial HTML response already contains the text, and put that evidence in your report and chapter.

### 8. CI (D-033, D-065, D-066)
Create `.github/workflows/web.yml` following the structure of `api.yml`:
- Jobs: `lint` (ESLint), `typecheck` (tsc), `test` (Jest). A `build` step belongs wherever you justify it.
- Node from a pinned version, pnpm through corepack, with the pnpm store cached.
- `permissions: contents: read` at workflow level (D-066).
- **Triggers (D-065):** `pull_request` targeting `main` with **no path filters**; `push` to `main` **with** the path filter. Apply the same change to `api.yml`: remove the path filter from its `pull_request` trigger, keep it on `push`.
  - The reason is in D-065: a path-filtered workflow that does not run reports *no status*, not a pass, so a required check would leave unrelated PRs pending forever.
- Pin every action to a current major version verified from its own repository, and cite the sources (D-055).

### 9. Root `.gitignore` fixes
1. Narrow `tmp/` to `/tmp/`, so it matches only the repository root's own `tmp/` and each app's `.gitignore` governs its own. This makes `apps/api/tmp/.keep` trackable again, as chapter 02's trap 3 predicted. **If that file becomes trackable, commit it**, and say so in your report.
2. Add a repository-wide rule ignoring `*.key` files at any depth, in its own commented section. `apps/api/.gitignore` keeps its own `/config/*.key` rule; the duplication is intentional defense in depth, because an ignore rule only protects you when the file declaring it is present on the branch you have checked out.

Verify both: `git check-ignore -v apps/api/config/master.key` must now match the root rule, and `git status --porcelain --untracked-files=all` must not list any key file.

### 10. Required status checks (report only, do NOT configure)
Once `web.yml` and `api.yml` have run on `main`, those checks can be required by branch protection (D-060). You cannot do this yet, because the workflows have not run on `main` from this branch. In your report, give the exact `gh api` command that would add them, with the check names as GitHub will report them, so the owner can run it after merging.

### 11. `CLAUDE.md` §7
Update only the **Web** line with the real commands: install, dev server, test, lint, typecheck, build. Leave the Postgres and API lines untouched.

### 12. Learning chapter 03 (D-064, D-067)
`handoff/learning/03-web-skeleton.md`, continuing from chapter 02's end state. Beyond the template's sections, it must teach:
- What server-side rendering means here, why this project needs it (D-018: Google ranking), and how it differs from a plain single-page app.
- Why the admin area will be client-rendered instead, and that it arrives in Feature 19.
- **How Jest was made to work in a Vite-based project**, in detail: what breaks, why, and what each piece of configuration does. A reader hits this wall in any Vite project, and the answer is scattered across the internet.
- The server/client boundary of requirement 6: how the framework keeps server-only values out of the browser bundle, and how a reader verifies it rather than trusting it.
- The workflow trigger rule of D-065, with the failure it prevents.
- **Before you finish, re-read your own chapter as a reader who has only completed chapter 02** (D-067). State in your report what that pass found. Chapter 02's fix round found seven assumed-state gaps that way; assume yours has some too.

## Acceptance criteria
- [ ] `apps/web` holds a server-rendered React Router app in strict TypeScript, with Tailwind working
- [ ] pnpm is used throughout and pinned in `package.json`
- [ ] `pnpm lint`, `pnpm typecheck` and `pnpm test` all pass locally, with outputs in the report
- [ ] Tests were committed before the code they cover, with both SHAs in the report
- [ ] The `/` route is server-rendered, with evidence that the initial HTML contains the rendered text
- [ ] The config module keeps server-only values out of the client bundle, with the mechanism explained and verified
- [ ] `apps/web/.env.example` documents every variable; no `.env` is committed
- [ ] `web.yml` exists with least-privilege permissions and the D-065 trigger pattern; `api.yml` updated to match
- [ ] Root `.gitignore`: `/tmp/` narrowed and `*.key` added, both verified
- [ ] CI green on the PR for both workflows (link the runs)
- [ ] The required-status-checks command is in the report, not executed
- [ ] `CLAUDE.md` §7 Web line updated; other lines untouched
- [ ] Chapter 03 written, reproducible from chapter 02's end state, indexed in `handoff/learning/README.md`
- [ ] PR opened with the exact title, report and chapter committed to the branch, not merged
- [ ] Nothing outside the scope was touched, in particular nothing in `apps/api`

## Verification commands (include outputs or summaries in the report)
```
node -v && corepack --version && (cd apps/web && pnpm -v)
cd apps/web && pnpm install --frozen-lockfile && pnpm lint && pnpm typecheck && pnpm test && pnpm build
# server-rendering evidence: start the production server and inspect the initial HTML
cd ../.. && git check-ignore -v apps/api/config/master.key
git status --porcelain --untracked-files=all
git log --oneline main..HEAD
git diff --stat main...HEAD -- apps/api
gh pr view --json title,url,state
gh run list --branch feature/3-web-skeleton --limit 6
```
`git diff --stat main...HEAD -- apps/api` must be empty.

## Questions
If the current React Router, Tailwind or Jest documentation contradicts anything in this prompt, follow the documentation, and record the conflict under "Questions for the owner". Never invent a configuration that you have not seen work.
