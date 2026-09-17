# Implementation Report — Feature 3: create the React Router web skeleton with Jest, ESLint and CI

- **Date:** 2026-09-16 · fix round 1: 2026-09-17
- **Branch:** `feature/3-web-skeleton`
- **PR:** https://github.com/Myepes05/tintara-lab/pull/2 (open, not merged)
- **Status:** Completed
- **Decisions applied:** D-005, D-018, D-019 (`lang="es"` only, see deviation 4), D-020, D-021, D-032, D-033, D-039, D-045, D-050, D-053, D-055, D-064, D-065, D-066, D-067 · fix round 1: D-050, D-054, D-068, D-070, D-071, D-072

## Summary
`apps/web` now holds a React Router 8.3.1 framework-mode app with server-side rendering on. It uses strict TypeScript 5.9.3 and Tailwind CSS 4.3.3, and is managed with pnpm 12.4.2 through corepack (pinned in `packageManager` with its integrity hash). Jest 30 with ts-jest, jsdom and React Testing Library runs 16 tests (12 before fix round 1). ESLint 10 and Prettier 3 pass with zero warnings. The `/` route renders a `SiteShell` component, and its first HTML response already contains the heading and the paragraph. Configuration lives in `app/config/`:
- `client-env.ts` is the only reader of `import.meta.env`. That includes Vite's `DEV` flag, which `root.tsx`'s `ErrorBoundary` now reads through it. Before fix round 1, `ErrorBoundary` read `import.meta.env.DEV` directly, so this claim was false (QA F-1).
- `public-config.ts` holds the public API base URL, with a development default.
- `server-config.server.ts` holds `API_INTERNAL_URL` and `API_INTERNAL_TOKEN`. The `.server` suffix makes the build fail if client code reaches that file, and a missing value throws an error naming it.

`web.yml` has four jobs: `Web ESLint` (plus a Prettier check), `Web TypeScript`, `Web Jest` and `Web Build`. The `Web`/`API` prefixes on all six check names come from fix round 1 (D-071). Both workflows now follow D-065 and D-066. The root `.gitignore` has `/tmp/` and a repo-wide `*.key` rule. The `CLAUDE.md` §7 Web line is filled in, and chapter 03 is written.

## Changes
| File / area | Change |
|---|---|
| `apps/web/` (new) | App generated with `create-react-router@8.4.0` (default template), then: exact version pins, `pnpm-workspace.yaml` denying install scripts, `.node-version` (24.14.0), rewritten `README.md`, `Dockerfile` and `.dockerignore` removed, `app/welcome/` removed |
| `apps/web/app/components/site-shell.tsx` (+ test) | `main` landmark plus one `h1`, with children |
| `apps/web/app/routes/home.tsx` | Renders `SiteShell` ("Tintara Lab" / "Sitio en construcción."); `meta` sets the title "Tintara Lab" |
| `apps/web/app/root.tsx` | Google Fonts `links` export removed; `<html lang="es">` |
| `apps/web/app/app.css` | Only `@import "tailwindcss";` (template font theme and colours removed) |
| `apps/web/app/config/` | `env-types.ts`, `client-env.ts`, `public-config.ts` (+ test), `server-config.server.ts` (+ test) |
| `apps/web/app/vite-env.d.ts` | Declares `VITE_PUBLIC_API_BASE_URL` on Vite's `ImportMetaEnv` |
| `apps/web/.env.example` | Documents `VITE_PUBLIC_API_BASE_URL`, `API_INTERNAL_URL` and `API_INTERNAL_TOKEN`, with placeholders only |
| `apps/web/jest.config.js`, `tsconfig.jest.json`, `test/` | Jest setup: ts-jest to CommonJS, jsdom, jest-dom setup, stubs for CSS, images and `client-env` |
| `apps/web/tsconfig.json` | Adds `"jest"` to `types` (already `strict`) |
| `apps/web/eslint.config.js`, `.prettierrc.json`, `.prettierignore` | ESLint flat config and Prettier |
| `.github/workflows/web.yml` (new) | Jobs `Web ESLint`, `Web TypeScript`, `Web Jest`, `Web Build` (renamed in fix round 1); `contents: read`; D-065 triggers; Node from `.node-version`; corepack; cached pnpm store |
| `.github/workflows/api.yml` | Path filter removed from `pull_request` (kept on `push`), plus an explanatory comment; jobs renamed `API RuboCop` and `API RSpec` in fix round 1 |
| `.gitignore` | `tmp/` → `/tmp/`; new commented `*.key` section |
| `apps/api/tmp/.keep`, `apps/api/tmp/pids/.keep` | Now trackable, committed (both empty); see deviation 6 |
| `CLAUDE.md` §7 | Web line only |
| `handoff/learning/03-web-skeleton.md`, `handoff/learning/README.md` | Chapter 03 and its index row |

## Versions pinned (D-055)
| Tool / library | Version | Source verified |
|---|---|---|
| Node | 24.14.0 (`.node-version`) | `node -v` |
| corepack | 0.34.6 | `corepack --version` |
| pnpm | 12.4.2 (`packageManager` with `+sha512` hash) | `npm view pnpm version`; hash written by `corepack use pnpm@12.4.2` |
| create-react-router | 8.4.0 (generator only) | `npm view create-react-router version`; command from reactrouter.com/start/framework/installation |
| react-router, @react-router/{dev,node,serve} | 8.3.1 | npm registry. 8.4.0 is the latest but was published 2026-09-15T15:23Z, inside pnpm's 24 h `minimumReleaseAge` window (see deviation 1) |
| react, react-dom, @types/react, @types/react-dom | 19.3.0 | npm registry |
| isbot | 5.2.2 | npm registry |
| vite | 8.3.0 | npm registry |
| tailwindcss, @tailwindcss/vite | 4.3.3 | npm registry; setup per tailwindcss.com/docs/installation/using-vite |
| typescript | 5.9.3 | npm registry. The latest is 7.0.2, but `typescript-eslint@8.70.0` requires `>=4.8.4 <6.1.0` and `ts-jest@29.4.12` requires `>=4.3 <7` (`npm view … peerDependencies`) |
| @types/node | 24.13.4 | npm registry. 24.13.5 was published 2026-09-15T20:37Z, inside the release-age window |
| jest, jest-environment-jsdom | 30.5.1 | npm registry |
| ts-jest | 29.4.12 | npm registry; peer `jest ^29 \|\| ^30` |
| @types/jest | 30.0.0 | npm registry |
| @testing-library/react / dom / jest-dom | 16.3.3 / 10.4.2 / 7.0.1 | npm registry; jest-dom `exports` inspected in `node_modules` |
| eslint, @eslint/js | 10.10.0, 10.0.1 | npm registry |
| typescript-eslint | 8.70.0 | npm registry; peer `eslint ^8.57 \|\| ^9 \|\| ^10` |
| eslint-plugin-react-hooks | 7.1.1 | npm registry; flat config key `configs.flat.recommended` checked in the installed package |
| eslint-config-prettier | 10.1.8 | npm registry |
| prettier | 3.9.6 | npm registry |
| actions/checkout | `@v7` (latest v7.0.1) | `gh api repos/actions/checkout/releases/latest` |
| actions/setup-node | `@v7` (latest v7.0.0) | `gh api repos/actions/setup-node/releases/latest`; `action.yml` at v7.0.0 read for `node-version-file` and `cache` |
| actions/cache | `@v6` (latest v6.1.0) | `gh api repos/actions/cache/releases/latest`; `action.yml` at v6.1.0 read for `path`, `key`, `restore-keys` |

## Spec-first evidence (D-050)
| Spec commit | Implementation commit | Behavior |
|---|---|---|
| `204cf7e` Feature 3: add specs for the site shell and the environment configuration | `3e1052e` Feature 3: implement the site shell, the environment configuration and the home route | `SiteShell` renders the `h1` heading and its children inside `main` |
| `204cf7e` (same) | `3e1052e` (same) | `readPublicConfig` returns the configured URL, or `http://localhost:3000` when the value is absent or blank |
| `204cf7e` (same) | `3e1052e` (same) | `readServerConfig` returns both values, and throws naming each missing or blank variable (and all of them at once) |

At `204cf7e`, `pnpm test` fails all three suites with `TS2307: Cannot find module …` for the modules under test. The spec commit also carries the Jest infrastructure and `app/config/env-types.ts` (types only, no behaviour), which the specs are written against.

Full branch history (`git log --oneline main..HEAD`, before the report commit):
```
3acbef2 Feature 3: state the exact import.meta failure in the Jest comments
4a26d62 Feature 3: keep only the tsconfig overrides Jest actually needs
0c1efe4 Feature 3: drop the unused pnpm field from package.json
88a4d94 Feature 3: pin pnpm together with its integrity hash
0509cc6 Feature 3: fill in the Web line of CLAUDE.md section 7
0009cc1 Feature 3: narrow the root tmp rule and ignore key files repository-wide
1de916c Feature 3: add the web workflow and apply D-065 to api.yml
e056ef9 Feature 3: add ESLint and Prettier
3e1052e Feature 3: implement the site shell, the environment configuration and the home route
204cf7e Feature 3: add specs for the site shell and the environment configuration
e4ecbcb Feature 3: scaffold the React Router app at apps/web with pnpm and Tailwind
```

## Commands run and results
```
$ node -v && corepack --version && (cd apps/web && pnpm -v)
v24.14.0
0.34.6
12.4.2

$ cd apps/web && pnpm install --frozen-lockfile
Lockfile is up to date, resolution step is skipped
Done in 30ms using pnpm v12.4.2

$ pnpm lint
$ eslint . --max-warnings=0            (no findings; 20 files linted per `eslint . --format json`;
                                        a planted unused const was reported as
                                        @typescript-eslint/no-unused-vars, then removed)
$ pnpm format:check
All matched files use Prettier code style!
$ pnpm typecheck
$ react-router typegen && tsc          (no errors)
$ pnpm test
Test Suites: 3 passed, 3 total
Tests:       12 passed, 12 total
Snapshots:   0 total
$ pnpm build
vite v8.3.0 building client environment for production...
✓ built in 412ms
vite v8.3.0 building ssr environment for production...
✓ built in 58ms
```

The same six commands also pass on a fresh `git clone` of the pushed branch into a scratch directory.

**Server-rendering evidence** (`pnpm build`, then `PORT=3100 pnpm start`, then `curl -i http://localhost:3100/`):
```
HTTP/1.1 200 OK
content-type: text/html; charset=utf-8

<!DOCTYPE html><html lang="es"><head>…<title>Tintara Lab</title>…<link rel="stylesheet" href="/assets/root-DYt92AA7.css"/></head><body><main class="mx-auto flex min-h-screen max-w-3xl flex-col gap-6 p-8"><h1 class="text-3xl font-semibold">Tintara Lab</h1><p>Sitio en construcción.</p></main><script>…
```
Server log: `[react-router-serve] http://localhost:3100 …` and `GET / 200`. Tailwind check: `grep -oE '\.max-w-3xl|\.text-3xl|\.font-semibold' build/client/assets/*.css` finds all three classes.

**Server/client boundary evidence:**
- Committed build: `grep -rlE 'API_INTERNAL|readServerConfig' build/client` → `none found in build/client`.
- Negative experiment (not committed): with `home.tsx`'s *component* rendering `getServerConfig().apiInternalToken`, `pnpm build` exits with status 1:
  ```
  [plugin react-router:dot-server]
  Error: Server-only module referenced by client
      '~/config/server-config.server' imported by route 'app/routes/home.tsx'
    React Router automatically removes server-code from these exports:
      `loader`, `action`, `middleware`, `headers`
    But other route exports in 'app/routes/home.tsx' depend on '~/config/server-config.server'.
  ```
- Positive experiment (not committed): with only a `loader` using `getServerConfig()`, `pnpm build` exits 0. `build/client` contains neither `API_INTERNAL` nor `getServerConfig`, while `build/server/index.js` contains `API_INTERNAL_TOKEN`.
- Source: reactrouter.com/api/framework-conventions/server-modules. The `react-router.config.ts` reference page confirms that `ssr` defaults to `true`.

**Git checks:**
```
$ git check-ignore -v apps/api/config/master.key
apps/api/.gitignore:25:/config/*.key	apps/api/config/master.key
    (git reports the nearest matching rule; with apps/api/.gitignore moved aside temporarily:)
.gitignore:31:*.key	apps/api/config/master.key
$ git check-ignore -v apps/web/anything.key
.gitignore:31:*.key	apps/web/anything.key
$ git status --porcelain --untracked-files=all
    (before the report commit, only the report, chapter 03 and the README index row; no key file, no .env)
$ git diff --stat main...HEAD -- apps/api
 apps/api/tmp/.keep      | 0
 apps/api/tmp/pids/.keep | 0
 2 files changed, 0 insertions(+), 0 deletions(-)
$ gh pr view 2 --json title,url,state
{"state":"OPEN","title":"Feature 3: create the React Router web skeleton with Jest, ESLint and CI","url":"https://github.com/Myepes05/tintara-lab/pull/2"}
```

**CI** (`gh run list --branch feature/3-web-skeleton`), all green:
| Head | Web | API |
|---|---|---|
| `0509cc6` | [35099868015](https://github.com/Myepes05/tintara-lab/actions/runs/35099868015): success | [35099867958](https://github.com/Myepes05/tintara-lab/actions/runs/35099867958): success |
| `3acbef2` | [35100141861](https://github.com/Myepes05/tintara-lab/actions/runs/35100141861): success | [35100141884](https://github.com/Myepes05/tintara-lab/actions/runs/35100141884): success |

The Web runs report four jobs (`ESLint`, `TypeScript`, `Jest`, `Build`) and the API runs report two (`RuboCop`, `RSpec`); these are the names before fix round 1. The API workflow ran on this PR even though the PR touches `apps/api` only through two empty files; that is D-065 in action. The pnpm cache missed on the first run and was restored on the second (`Cache restored from key: pnpm-store-Linux-8d9732c3…`). The report commit, which changes only `handoff/`, triggers both workflows again. Its results are posted as a PR comment.

## Acceptance criteria
- [x] `apps/web` holds a server-rendered React Router app in strict TypeScript, with Tailwind working. `ssr: true`, `"strict": true`, and the utility classes are present in the built CSS.
- [x] pnpm is used throughout and pinned in `package.json`: `packageManager: pnpm@12.4.2+sha512…`, enabled with corepack, and no global install.
- [x] `pnpm lint`, `pnpm typecheck` and `pnpm test` pass locally, with outputs above.
- [x] Tests were committed before the code they cover: `204cf7e` comes before `3e1052e`.
- [x] The `/` route is server-rendered, with the curl evidence above.
- [x] The config module keeps server-only values out of the client bundle. Mechanism: the `.server` module convention. Verified by bundle grep and by the negative and positive build experiments.
- [x] `apps/web/.env.example` documents every variable, and no `.env` is committed.
- [x] `web.yml` exists with `contents: read` and the D-065 triggers; `api.yml` is updated to match.
- [x] Root `.gitignore`: `/tmp/` narrowed and `*.key` added, both verified (see deviation 7 about the check-ignore output).
- [x] CI is green on the PR for both workflows (runs linked above).
- [x] The required-status-checks command is below and was not executed.
- [x] `CLAUDE.md` §7 Web line updated; the other lines are untouched.
- [x] Chapter 03 written, re-read under D-067 (see "Learning chapter"), and indexed in `handoff/learning/README.md`.
- [x] PR opened with the exact title; report and chapter committed to the branch; not merged.
- [~] Nothing outside the scope was touched, and nothing in `apps/api` changed, **except** the two empty `.keep` files that requirement 9 tells me to commit (deviation 6).

## Required status checks (requirement 10 — NOT executed)
`main` currently has no required status checks (`GET …/protection/required_status_checks` returns `404 Required status checks not enabled`). Because there is no status-check configuration to amend, the command below uses the endpoint that sets the **whole** protection object (`PUT …/protection`). Every other value is copied from the live settings read on 2026-09-16, so the only change is the added checks. Check names are the job `name:` values GitHub reports on PR #2, as renamed in fix round 1 (D-071); see "Fix round 1" for the `gh pr checks 2` output. `15368` is the GitHub Actions app id (`gh api /apps/github-actions --jq .id`), which ties each check to Actions so another app cannot satisfy it.

Run after PR #2 is merged and both workflows have run on `main`:
```sh
gh api --method PUT repos/Myepes05/tintara-lab/branches/main/protection --input - <<'JSON'
{
  "required_status_checks": {
    "strict": false,
    "checks": [
      { "context": "API RuboCop",    "app_id": 15368 },
      { "context": "API RSpec",      "app_id": 15368 },
      { "context": "Web ESLint",     "app_id": 15368 },
      { "context": "Web TypeScript", "app_id": 15368 },
      { "context": "Web Jest",       "app_id": 15368 },
      { "context": "Web Build",      "app_id": 15368 }
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "require_last_push_approval": false,
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON

# Verify
gh api repos/Myepes05/tintara-lab/branches/main/protection/required_status_checks \
  --jq '{strict, checks: [.checks[].context]}'
```
`"strict": false` means a PR does not have to be rebased onto the latest `main` before merging; the owner accepted it (D-070).

## Deviations from the prompt
1. **React Router pinned at 8.3.1, not the newest 8.4.0 (and `@types/node` at 24.13.4, not 24.13.5).** Both newer versions were less than 24 hours old, and pnpm 12's default `minimumReleaseAge` rejects them. Pinning them anyway made pnpm write `minimumReleaseAgeExclude` entries, which disable that supply-chain check for exactly those packages, and CI would have rejected the lockfile the same day. I kept the check on and used the newest versions it accepts. Upgrading to 8.4.x later is a one-line change.
2. **TypeScript 5.9.3, not 7.0.2.** TypeScript 7 is outside the supported peer ranges of `typescript-eslint` and `ts-jest`. 5.9.3 is also what the React Router template ships.
3. **Template files removed or rewritten:** `Dockerfile` and `.dockerignore` (they use npm and `package-lock.json`, so they could never build this app, and hosting is deferred under D-036), `app/welcome/`, the Google Fonts links and the Inter font theme (fonts and design belong to Feature 14), and the template `README.md` (npm and Docker instructions).
4. **`<html lang="es">`** although "SEO tags" are out of scope. It is one attribute. Leaving the template's `lang="en"` would ship wrong markup for a Spanish site (D-004, D-019). The template's `meta` export was also reduced to `title: "Tintara Lab"` (D-006), without a description. Easy to revert if you prefer.
5. **A fourth CI job, `Build`, and a Prettier check inside the `ESLint` job.** D-033 lists lint, typecheck and tests. The prompt allowed a build step "wherever you justify it". The justification: the build is the only thing that enforces the `.server` boundary (D-039, D-045). The Prettier check runs in the lint job so formatting drift fails CI without adding another required check.
6. **`git diff --stat main...HEAD -- apps/api` is not empty.** Requirement 9 says to commit `apps/api/tmp/.keep` once it becomes trackable, but the verification section says that diff must be empty. The two instructions conflict. I followed requirement 9. Narrowing the rule also made `apps/api/tmp/pids/.keep` trackable; Rails' own `apps/api/.gitignore` un-ignores it the same way (`!/tmp/pids/.keep`), so I committed it too. Both files are empty, and no other file under `apps/api` changed.
7. **`git check-ignore -v apps/api/config/master.key` names `apps/api/.gitignore`, not the root rule.** Git reports the nearest matching `.gitignore`, and the app's rule is closer. With `apps/api/.gitignore` moved aside for a moment (then restored, and `git status` was clean for it), the same command prints `.gitignore:31:*.key`. The root rule works; this command just cannot show it while both rules exist.
8. **`handoff/learning/README.md` edited.** The file says the orchestrator updates the table, but CLAUDE.md §7b and this prompt's acceptance criteria tell the implementation agent to add the row. I added only that row.
9. **Commit history has follow-ups after the implementation commit** (`88a4d94`, `0c1efe4`, `4a26d62`, `3acbef2`): restoring corepack's integrity hash, removing a `package.json` `pnpm` field that pnpm 12 ignores (CI warned about it), dropping two `tsconfig.jest.json` overrides that tests showed were unnecessary, and making a code comment precise. None changes behaviour. The PR is squash-merged anyway.
10. **The `.server` module is not imported by any committed code.** The prompt forbids loaders that fetch data, and a loader calling `getServerConfig()` would return a 500 on every machine without the variables. The boundary is therefore proven by the documented experiments, not by a committed import.

## Learning chapter
- **File:** `handoff/learning/03-web-skeleton.md`
- **Index updated:** yes (row 03 in `handoff/learning/README.md`)
- **Traps documented:** pnpm 12's `minimumReleaseAge` and silent `minimumReleaseAgeExclude`; `pnpm-workspace.yaml` replacing the `package.json` `pnpm` field; `ERR_PNPM_IGNORED_BUILDS`; the lost corepack hash; TypeScript 7's peer ranges; a table of six real Jest failures with their exact messages; `import.meta.env` typing; Vite not loading `.env` into `process.env`; `react-router-serve` switching ports silently; `check-ignore` reporting the nearest rule; two `.keep` files instead of one; empty lint output not being proof.
- **D-067 re-read (as a reader who has finished only chapter 02).** The pass found these gaps, and all were fixed:
  1. Step 2 told the reader to expect `ERR_PNPM_IGNORED_BUILDS`, which cannot happen before Jest is installed.
  2. Step 3 said "replace" `pnpm-workspace.yaml`, but the file may not exist yet; it now says "create or replace".
  3. Step 4 pointed at `apps/web/README.md` without giving its content; the content is now inline.
  4. Step 7 summarised `.env.example` without its content; the full file is now inline.
  5. Step 7 claimed a `TS2559` type-check failure that a reader following the final code would never see. It now explains that error as the first draft's, and says why `vite-env.d.ts` is still needed: without it, the variable is typed `any`. I checked this by removing the file and running `tsc`.
  6. Step 8 ran `curl` immediately after starting the server; a `sleep 2` was added there and in section 8.
  7. Step 10 said `pnpm format` would rewrite two files that a reader using the chapter's content already has formatted.
  8. Step 13 described the `CLAUDE.md` line instead of giving it; the exact line is now inline.
  9. A claim about why `corepack enable` must follow `setup-node` described a failure I had not reproduced. It was reworded to what I verified.

  Separately, section 3 now tells the reader how to get Node 24.14.0 (`nvm install`) and why `corepack enable` is needed. Chapter 01 only recorded that Node was present.

## Questions for the owner
1. **Handoff state is out of sync (orchestrator action needed).** When this session started, the local checkout was on `feature/2-rails-api-skeleton`, with an **unpushed** commit `beb2b45 docs 6: verify Feature 2 fix round 1 and add the Feature 3 prompt`. That commit is the only place this task's prompt exists and the only place `current-status.md` records docs 6. It was never committed to `main` (D-053), and `origin/main` is at `af4afec` (PR #1's squash). I branched from up-to-date `main` as the prompt requires and did not touch that commit. The orchestrator should put `docs 6` onto `main`, for example by cherry-picking `beb2b45`.
2. Are the two committed `apps/api/tmp/*.keep` files acceptable, given the "`apps/api` diff must be empty" check (deviation 6)?
3. Should `Build` be a required check as well? The command above includes it.
4. `strict: false` or `true` for the required checks? `true` forces every PR to be up to date with `main` before merging: safer, but more rebasing for a single-maintainer repository.
5. Keep `lang="es"` and the "Tintara Lab" title now, or revert them for the SEO feature (deviation 4)?

## Suggested follow-ups (not implemented)
- **`CLAUDE.md` §6 and D-032 still say both workflows are "path-filtered".** After D-065 that is true only for `push`. The orchestrator may want to update the wording.
- **Development loading of server-only variables.** Vite does not put `.env` into `process.env`. When the first loader needs `API_INTERNAL_*` (the Phase 4 site loader), decide how development supplies them, for example `node --env-file`, or `process.loadEnvFile()` in a server entry.
- **Bump React Router to 8.4.x** (and `@types/node`) once they are past the release-age window, ideally through a dependency-update tool with the same age rule.
- **Node 25+ no longer bundles corepack.** When Node is upgraded past 24, the corepack step in CI and in `CLAUDE.md` needs revisiting.
- **Consider `eslint-plugin-jsx-a11y`** when the real components land (accessibility also supports D-019).
- **`root.tsx`'s `ErrorBoundary` still has the template's English text** ("Oops!"). User-facing strings must be Spanish; this belongs with the design or SEO feature.

## How to verify manually
1. `git fetch && git checkout feature/3-web-skeleton && cd apps/web`
2. `corepack enable` (once), then `pnpm install --frozen-lockfile`
3. `pnpm lint && pnpm format:check && pnpm typecheck && pnpm test && pnpm build`
4. `PORT=3100 pnpm start &`, then `sleep 2`, then `curl -s http://localhost:3100/ | grep -o '<h1[^>]*>[^<]*</h1>'`. Expected: `<h1 class="text-3xl font-semibold">Tintara Lab</h1>`. Stop the server with `kill %1`.
5. `grep -rlE 'API_INTERNAL|readServerConfig' build/client || echo none`. Expected: `none`.
6. Open http://localhost:5173 after `pnpm dev` to see the page in a browser.
7. Follow chapter 03, step 9, to watch the build reject a client import of `server-config.server.ts`.
8. `gh pr checks 2`. Expected: six passing checks.

## Fix round 1

- **Prompt:** `handoff/prompts/implementation/feature-003-web-skeleton-fix-r1.md`
- **QA report:** `handoff/agent-outputs/qa/qa-feature-003-web-skeleton.md` (verdict FAIL, reviewed commit `acb3ba3`)
- **Decisions:** D-050, D-054, D-068, D-070, D-071, D-072
- **Branch / PR:** `feature/3-web-skeleton`, PR #2, pushed, not merged

### Findings and what changed
| # | Change | Where | Commits |
|---|---|---|---|
| F-1 (major) | `DEV` is added to `ClientEnv`, read by its full name in `client-env.ts`, and set to `false` in the Jest stub. `ErrorBoundary` reads `clientEnv.DEV`. A new `root.test.tsx` proves the message and stack trace are shown only when `DEV` is on. The "only reader" claim is now true, and it is stated consistently in the `client-env.ts` comment, this report's summary, the PR body and chapter 03 (step 7 and §5 now agree). | `app/root.tsx`, `app/config/{env-types,client-env,public-config}.ts`, `test/stubs/client-env.ts`, `app/root.test.tsx`, `package.json` (`test` script), chapter 03 | `7eb7df3` (spec), `ff41b9a` (implementation), `e8a7b6b` (chapter) |
| F-2 (minor) | Jest table row 1 now quotes `…/test/setup-jest.ts`, and a sentence explains that the setup file loads before any test file | chapter 03, step 6 | `e8a7b6b` |
| F-3 (minor) | `"module": "CommonJS"` removed from `tsconfig.jest.json`, with a comment saying why ts-jest doesn't need it. The chapter explains that ts-jest forces CommonJS itself (source cited) and that the override that matters is `verbatimModuleSyntax: false`. Suite: 16/16 with `--no-cache`. Ablations re-run: without `verbatimModuleSyntax: false` → `TS1295`; without the `client-env` mapping → `TS1343` (CommonJS is still emitted). | `tsconfig.jest.json`, chapter 03 step 6 | `56f300a`, `e8a7b6b` |
| F-4 (minor) | Closing fence moved to its own line; "Commit it as …" is now its own paragraph | chapter 03, step 13 | `e8a7b6b` |
| F-5 (minor) | The whole `web.yml` is given, byte-identical to the file after the renames. The real `api.yml` trigger comment is quoted, and its one differing sentence is pointed out. | chapter 03, step 11 | `e8a7b6b` |
| F-6 (nit) | Mappers and stubs kept, each with a comment on who needs it. The **CSS mapper is no longer only forward-looking** (see deviation R-2); the image mapper still is (Phase 4). `"jest"` stays in `types`; chapter step 6 and §5 now say it makes the dependency explicit and that `tsc` doesn't need it today. | `jest.config.js`, `test/stubs/{style,asset}.ts`, chapter 03 | `8a2299a`, `e8a7b6b` |
| F-7 (nit) | The long comment line is rewrapped; the chapter's `jest.config.js` listing is byte-identical to the file | `jest.config.js`, chapter 03 | `8a2299a`, `e8a7b6b` |
| F-8 (nit) | PR #2 body rewritten into the shape of `.github/pull_request_template.md` (Summary, Task with prompt links, Decisions implemented, How it was tested, Implementation report link, Checklist) | PR #2 description | `gh pr edit 2` |
| F-9 (nit) | Specs added for trimming (`" http://x "` → `"http://x"`, and a tab/newline-wrapped token) and for `getServerConfig()` caching | `app/config/server-config.test.ts`, chapter 03 step 6 | `bc57c0a` |
| F-10 (nit) | `.env.example`'s warning names `API_INTERNAL_URL` and `API_INTERNAL_TOKEN`. The `client-env.ts` comment and chapter trap 8 explain that a whole-object read of `import.meta.env` inlines every `VITE_` variable. | `.env.example`, `app/config/client-env.ts`, chapter 03 | `cd7adb0`, `ff41b9a`, `e8a7b6b` |
| Q3 / D-071 | All six job `name:` values prefixed; job ids, steps, triggers and permissions untouched. Chapter 03 (steps 11 and 14, §5, §6, §8, §9) uses the new names. Chapter 02 gets a forward note after its `api.yml` listing (deviation R-5). The status-check command above lists the new names. | `.github/workflows/{api,web}.yml`, chapters 02 and 03, this report | `3d50136`, `e8a7b6b` |

### Spec-first evidence (D-050)
| Spec commit | Implementation commit | Behaviour | State at the spec commit |
|---|---|---|---|
| `7eb7df3` Feature 3: fix F-1, add a spec for the ErrorBoundary development flag | `ff41b9a` Feature 3: fix F-1, read the development flag through the config module | `ErrorBoundary` shows `error.message` and `error.stack` only when `DEV` is true | `pnpm test`: only `app/root.test.tsx` fails, with `app/root.tsx:46:14 - error TS1343: The 'import.meta' meta-property is only allowed when the '--module' option is …`; the other 12 tests pass. `pnpm typecheck` fails as expected: `client-env.ts(16,14): error TS2741: Property 'DEV' is missing …` (the type seam is in the spec commit, and the implementation is not) |
| `bc57c0a` Feature 3: fix F-9, add specs for trimmed server values and caching | (behaviour already implemented in `3e1052e`) | `readServerConfig` trims returned values; `getServerConfig` reads the environment once | The specs pass on commit, as expected for behaviour that already existed. Mutation check, each reverted afterwards: removing `.trim()` from `apiInternalUrl` → `1 failed, 7 passed`; `cached ??=` → `cached =` → `1 failed, 7 passed` |

Fix-round history (`git log --oneline acb3ba3..HEAD`, before this report commit):
```
e8a7b6b Feature 3: fix F-1 to F-6 and F-10 in the learning chapters, and record the check renames
3d50136 Feature 3: fix check names, prefix every CI job with its app (D-071)
cd7adb0 Feature 3: fix F-10, name the server-only variables in the VITE_ warning
8a2299a Feature 3: fix F-6 and F-7, state what each Jest mapper is for and rewrap the comment
56f300a Feature 3: fix F-3, drop the module override ts-jest already applies
bc57c0a Feature 3: fix F-9, add specs for trimmed server values and caching
ff41b9a Feature 3: fix F-1, read the development flag through the config module
7eb7df3 Feature 3: fix F-1, add a spec for the ErrorBoundary development flag
```

### Task 1 check: `grep -rn 'import\.meta\.env' apps/web/app`
```
apps/web/app/vite-env.d.ts:2: * Declares the VITE_ variables this app reads, so `import.meta.env` is typed.
apps/web/app/config/client-env.ts:4: * The only module in this app that reads `import.meta.env`. (The type
apps/web/app/config/client-env.ts:7: * Vite replaces `import.meta.env.*` with literal values at build time, so
apps/web/app/config/client-env.ts:21:  // `import.meta.env.VITE_PUBLIC_API_BASE_URL` with a literal, and naming it
apps/web/app/config/client-env.ts:23:  // `import.meta.env` as a whole object would instead inline every VITE_
apps/web/app/config/client-env.ts:25:  DEV: import.meta.env.DEV,
apps/web/app/config/client-env.ts:26:  VITE_PUBLIC_API_BASE_URL: import.meta.env.VITE_PUBLIC_API_BASE_URL,
```
Only `client-env.ts` and the `vite-env.d.ts` declaration match. The only lines that read the object are 25 and 26; the rest are comments.

Production behaviour is unchanged: the client build contains `{DEV:!1,VITE_PUBLIC_API_BASE_URL:void 0}`, and `GET /nope` still returns 404 with the template text. One difference: the build at `acb3ba3` had removed the development-only branch entirely (no `.stack` in `root-*.js`), while it now ships and never runs (chapter trap 17).

### Task 4: fence check
A script parsed every backtick fence with CommonMark rules: a closing fence is a run of at least as many backticks and nothing else on the line. It also reported any `##`/`###` heading that fell inside a code block.
- **Chapter 03 before (`acb3ba3`):** 55 blocks and 110 fence lines, but the `### Step 14` heading sat inside a code block (F-4).
- **Chapter 03 after:** **60 fenced blocks, 120 fence lines**, none unclosed at the end of the file.
  - The only headings inside code are `## Requirements`, `## Commands` and `## Environment`. They belong to the README content in step 4's intended 4-backtick listing.
- **Chapter 02 after the note:** 39 blocks, 78 fence lines, none unclosed, no headings inside code (unchanged).

### Task 5: extraction and comparison
The same script extracted each file listing from chapter 03 and compared it byte for byte with the file in the branch. For the stubs, the setup file and the two config files, it first dropped the leading `// path` comment line the chapter adds. All 27 comparisons returned `OK`:
- `jest.config.js`, `tsconfig.jest.json`, `test/setup-jest.ts`, `test/stubs/{style,asset,client-env}.ts`
- `app/config/{env-types,client-env,public-config,server-config.server}.ts`
- `app/config/{public-config,server-config}.test.ts`, `app/components/site-shell{,.test}.tsx`, `app/root.test.tsx`
- `app/routes/home.tsx`, `app/vite-env.d.ts`, `app/app.css`, `.env.example`, `eslint.config.js`, `.prettierignore`, `README.md`, `react-router.config.ts`, `vite.config.ts`
- **`web.yml`: all 166 lines, identical.**
- **`api.yml` trigger comment (lines 3–7): identical.**
- **`package.json` (step 3):** identical to the final file minus the `@eslint/js` line, which is exactly the difference the chapter states.

The two `root.tsx` snippets in step 7 are excerpts, not listings. They match lines 10–12 and 47 of `app/root.tsx`.

### Task 7: renamed checks
| Workflow | Job id | Old name | New name |
|---|---|---|---|
| `api.yml` | `lint` | `RuboCop` | `API RuboCop` |
| `api.yml` | `test` | `RSpec` | `API RSpec` |
| `web.yml` | `lint` | `ESLint` | `Web ESLint` |
| `web.yml` | `typecheck` | `TypeScript` | `Web TypeScript` |
| `web.yml` | `test` | `Jest` | `Web Jest` |
| `web.yml` | `build` | `Build` | `Web Build` |

YAML parse check (`ruby -ryaml`): `lint=API RuboCop, test=API RSpec` · `lint=Web ESLint, typecheck=Web TypeScript, test=Web Jest, build=Web Build`. The command under "Required status checks" was updated and **not** executed.

`gh pr checks 2` on head `e8a7b6b`:
```
API RSpec	pass	23s	https://github.com/Myepes05/tintara-lab/actions/runs/35243295740/job/105276945127
API RuboCop	pass	11s	https://github.com/Myepes05/tintara-lab/actions/runs/35243295740/job/105276945400
Web Build	pass	19s	https://github.com/Myepes05/tintara-lab/actions/runs/35243295767/job/105276945869
Web ESLint	pass	21s	https://github.com/Myepes05/tintara-lab/actions/runs/35243295767/job/105276945920
Web Jest	pass	24s	https://github.com/Myepes05/tintara-lab/actions/runs/35243295767/job/105276945704
Web TypeScript	pass	21s	https://github.com/Myepes05/tintara-lab/actions/runs/35243295767/job/105276945584
```
Runs: Web [35243295767](https://github.com/Myepes05/tintara-lab/actions/runs/35243295767), API [35243295740](https://github.com/Myepes05/tintara-lab/actions/runs/35243295740), both `success`. The `Web Jest` log shows `$ react-router typegen && jest`, then `Test Suites: 4 passed, 4 total` and `Tests: 16 passed, 16 total`, which confirms that typegen covers CI's fresh checkout (R-1.2). The live protection on `main` was read again on 2026-09-17: every field still matches the payload above, and `required_status_checks` is still `null`. The report-only commit that follows triggers both workflows again.

### Commands run and results (from `apps/web`, after `rm -rf .react-router build`)
```
$ pnpm install --frozen-lockfile
✓ Lockfile passes supply-chain policies (verified 1d ago)
Lockfile is up to date, resolution step is skipped
Done in 43ms using pnpm v12.4.2
$ pnpm lint
$ eslint . --max-warnings=0            exit 0 (eslint --format json: 21 files, 0 errors, 0 warnings)
$ pnpm format:check
All matched files use Prettier code style!
$ pnpm typecheck
$ react-router typegen && tsc          exit 0
$ pnpm test
$ react-router typegen && jest
Test Suites: 4 passed, 4 total
Tests:       16 passed, 16 total        exit 0 (also 16/16 with jest --no-cache)
$ pnpm build
✓ built in 305ms                        (client)
✓ built in 57ms                         (ssr), exit 0, no warnings
$ PORT=3187 pnpm start; curl -s http://localhost:3187/
<html lang="es" · <title>Tintara Lab</title> · <h1 class="text-3xl font-semibold">Tintara Lab</h1> · <p>Sitio en construcción.</p>
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:3187/nope
404
$ grep -rlE 'API_INTERNAL|readServerConfig|getServerConfig' build/client || echo "none found in build/client"
none found in build/client
```

### Deviations in this round
- **R-1. The `ErrorBoundary` test needed three pieces of test infrastructure the prompt didn't list.** Each was reproduced before it was added:
  1. **A `jest.mock("react-router", factory)` in `root.test.tsx`.**
     - **Why:** react-router 8.3.1 ships only ES modules (`"type": "module"`, no `require` export), and importing `root.tsx` made Jest stop with `Must use import to load ES Module: …/react-router/dist/production/index.js`.
     - **Rejected:** Jest's `--experimental-vm-modules` got past that error but then failed with `ReferenceError: TextEncoder is not defined` inside react-router, under an experimental-feature warning. Transforming `node_modules` would mean compiling react-router's JavaScript as well.
     - **What the factory contains:** only `isRouteErrorResponse`, copied from react-router 8.3.1's source. See question R-Q1.
  2. **`"test": "react-router typegen && jest"`.**
     - **Why:** ts-jest type-checks `import type { Route } from "./+types/root"`. With `.react-router/` moved aside, as on CI's fresh checkout (whose Jest job never runs typegen), the suite fails with `TS2307: Cannot find module './+types/root'`.
     - **Scope:** this changes what `pnpm test` does, not the workflow file, whose steps stay untouched as Task 7 requires. It mirrors `typecheck`.
  3. **`readPublicConfig(env: Pick<ClientEnv, "VITE_PUBLIC_API_BASE_URL">)`.** This is type-only. Once `DEV` became a required `ClientEnv` field, the existing public-config spec failed with `TS2345: Property 'DEV' is missing`. The function reads only the URL.
- **R-2. F-6: the CSS mapper is now used.**
  - `root.test.tsx` imports `root.tsx`, which imports `app.css`. Without the mapper, the suite fails with `SyntaxError: Invalid or unexpected token` at `app/app.css:4`.
  - Its comment therefore says it is needed since `root.test.tsx`, not that it is forward-looking. The image mapper is still unused, and its comment says so.
- **R-3. Contents of the spec commit `7eb7df3`.**
  - It carries the test and its type/stub seam (`ClientEnv.DEV`, the stub value, the `Pick` narrowing and the `test` script), so the only Jest failure there is the intended `TS1343`.
  - As a consequence, `pnpm typecheck` fails at that single commit (`client-env.ts` lacks `DEV`). It passes from `ff41b9a` on.
- **R-4. The F-9 specs pass on commit** because they describe behaviour that already existed. The mutation check above shows they are not vacuous.
- **R-5. Chapter 02 gets a note, not a rename inside its `api.yml` listing.**
  - That listing is the file as chapter 02 leaves it: it still has the path filter on `pull_request`, which chapter 03 removes.
  - Renaming only the jobs inside it would describe a file that never existed. A reader following chapter 02 would also get checks named differently from what the chapter shows at that point.
  - Chapter 02 prints no check names as command output (its only CI output is a `gh run list` line naming the workflow, `API`). The note after the listing says both later changes and the new check names.
- **R-6. Step 6's failing output in chapter 03 was re-captured from a real run, not edited by hand.**
  - **How:** a scratch worktree at `204cf7e`, with the final test-side files and the new `test` script copied in, then `pnpm install` and `pnpm test`.
  - **Result:** in the reader's order, `root.test.tsx` fails with `TS2307` on `~/config/client-env` (ts-jest's type check resolves the tsconfig path, not Jest's mapper). In this PR it failed with `TS1343` instead, because `client-env.ts` already existed. The chapter shows the reader's output and explains both.
- **R-7. Process slip, recovered.** While re-running two ablations, I restored files with `git checkout jest.config.js` and `git checkout tsconfig.jest.json`. That also discarded my uncommitted F-3/F-6/F-7 edits to those files. I re-applied them with the same asserted script, re-ran lint, format, typecheck and the uncached suite, and only then committed. Nothing wrong was committed. The chapter records this as trap 19.

### D-067 re-read of chapter 03 after these edits
I re-read the chapter as a reader who has just finished chapter 02, checking whether each edit leaves a step that no longer works in order. Gaps found and closed:
1. **Step 3's `package.json`** had `"test": "jest"`, so a reader on a fresh clone (without the optional step 5 or a `typecheck` run) would hit `TS2307` for `./+types/root` in step 6. It now shows the final script and explains it.
2. **Step 6's expected failure** listed three suites. It now shows the real four-suite output for the reader's order (R-6).
3. **Step 7 didn't say to change `ErrorBoundary`.** A reader would keep the template's `import.meta.env.DEV` and the new spec would fail with `TS1343` forever. It now gives both edits to `root.tsx`.
4. **Step 7's `public-config.ts`** now has the `Pick` signature and explains it. Without that, the step 6 public-config spec fails with `TS2345` once `ClientEnv.DEV` exists (reproduced in R-1).
5. **Step 7's and §8's expected counts** changed from 3/12 to 4/16. A `grep` for `import.meta.env` was added as a checkable result.
6. **Step 11** now gives the whole `web.yml` and the exact `api.yml` edits, job renames included, so a reader reaches the same six check names that steps 14 and §9 name.
7. **The step 13 fence** no longer swallows step 14.

Checked and fine: the new traps 15–19 refer only to steps that exist. The glossary gained `jest.mock`. Section 1's pointer to "step 6 and section 7" still holds.

### Questions for the owner (fix round 1)
- **R-Q1. How should Jest load react-router once Phase 4 tests need real router components (`Link`, `useLoaderData`, route modules)?** The per-test `jest.mock` used here only works while a test needs a small, pure function. Options:
  - **(a)** Keep mocking per test. Cheap, but real router behaviour goes untested.
  - **(b)** Let Jest transform `react-router` through `transformIgnorePatterns`, with ts-jest `allowJs` or an added Babel transform.
  - **(c)** Jest's ESM mode (`--experimental-vm-modules`) plus jsdom polyfills such as `TextEncoder`. It is still experimental.

  I recommend a short spike on (b) before Phase 4, since it keeps D-020's toolchain and exercises the real components. This probably deserves its own decision entry.
- **R-Q2.** Is `pnpm test` running `react-router typegen` first acceptable (R-1.2)? The alternative is a typegen step in the `Web Jest` job, which this round was told not to touch. Doing both would be redundant.

### Suggested follow-ups (fix round 1)
- **`CLAUDE.md` §7's Web line** still reads correctly (`specs pnpm test`). If you want it to mirror the typecheck wording, it could say that `pnpm test` generates route types first.
- **Route tests for `home.tsx`** (`meta` title, Spanish text) are left for Phase 4, as the prompt allows. They will hit R-Q1.
