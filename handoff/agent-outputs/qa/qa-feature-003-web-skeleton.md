# QA Report — Feature 3: create the React Router web skeleton with Jest, ESLint and CI

- **Date:** 2026-09-17
- **PR / branch:** https://github.com/Myepes05/tintara-lab/pull/2 · `feature/3-web-skeleton`
- **Commit reviewed:** `acb3ba3e2dbe4ad7400b6ccd8c258c395ee360df`
- **Verdict:** **FAIL**. There is one `major` finding (F-1), and D-054 requires it to be fixed before merging. The fix is small. Everything else is solid: build, SSR, the `.server` boundary, tests, CI, versions and `.gitignore` all check out. The remaining findings are `minor` or `nit`.

**Severity rule used for the chapter.** The prompt says an untrue statement in the chapter is `major`. I applied that to statements that would mislead a reader about how the system works, or that contradict a project rule. Inaccuracies in quoted output, rendering defects and incomplete listings are rated `minor`, and each one says why.

## Checks run
```
# Setup
git switch feature/3-web-skeleton; git pull            -> up to date, clean, HEAD acb3ba3
node -v / corepack --version / pnpm -v                 -> v24.14.0 / 0.34.6 / 12.4.2

# A. Functional (apps/web)
pnpm install --frozen-lockfile     -> "Lockfile passes supply-chain policies", "Lockfile is up to date", Done
pnpm lint                          -> exit 0; only pnpm's "$ eslint . --max-warnings=0" echo line
./node_modules/.bin/eslint . --max-warnings=0 | wc -c   -> 0 (truly empty)
eslint . --format json             -> 20 files, 0 errors, 0 warnings
pnpm format:check                  -> All matched files use Prettier code style!
pnpm typecheck                     -> exit 0, no output
pnpm test                          -> Test Suites: 3 passed, 3 total · Tests: 12 passed, 12 total (2 + 4 + 6)
pnpm build                         -> exit 0; no warnings or deprecations in the log (client + ssr environments)
PORT=3187 pnpm start; curl -si /   -> 200; <html lang="es">; <title>Tintara Lab</title>;
                                      <main class="mx-auto flex min-h-screen max-w-3xl flex-col gap-6 p-8"><h1 class="text-3xl font-semibold">Tintara Lab</h1><p>Sitio en construcción.</p></main>
curl /nope                         -> 404 (template ErrorBoundary, English text)
Tailwind: grep in build/client/assets/*.css -> max-w-3xl, text-3xl, font-semibold, min-h-screen, gap-6, p-8, mx-auto: 1 each; control .text-9xl: 0
pnpm dev --port 5199 --strictPort; curl / -> lang="es", title, h1 and paragraph rendered; /app/app.css served with max-w-3xl

# B. Server/client boundary
grep import.meta.env app test *.ts *.js -> app/config/client-env.ts:20 AND app/root.tsx:46 (import.meta.env.DEV)   <- F-1
Negative experiment: SiteShell imports ~/config/server-config.server and renders the token -> pnpm build exit 1:
    [plugin react-router:dot-server]
    Error: Server-only module referenced by client
        '~/config/server-config.server' imported by 'app/components/site-shell.tsx'
      See https://reactrouter.com/explanation/code-splitting#removal-of-server-code
  reverted with git checkout; git status clean
Normal build, grep -rl in build/client for API_INTERNAL, readServerConfig, getServerConfig,
  replace-me-with-a-random-value, VITE_PUBLIC_API_BASE_URL, server-config, localhost:3000 -> 0 matches each
VITE_ exposure (temporary edits, reverted):
  home.tsx renders publicConfig.apiBaseUrl, VITE_PUBLIC_API_BASE_URL=https://api.example.test -> value found in build/client/assets/home-*.js
  VITE_API_INTERNAL_TOKEN=leak-test-123 set but not referenced by code  -> not in bundle
  API_INTERNAL_TOKEN=plain-secret-456 (no prefix)                        -> not in build/ at all
  a whole-object read, JSON.stringify(import.meta.env)                  -> leak-test-123 IS in the client bundle
  after revert and rebuild: build clean, git status clean
readServerConfig (node, direct import):
  {} -> "Missing required server environment variables: API_INTERNAL_URL, API_INTERNAL_TOKEN. See apps/web/.env.example. These values are server-only and must never be given a VITE_ prefix."
  URL only / TOKEN "" / URL "\t " -> throws naming the single missing variable (blank treated as missing)
  " http://a " -> trimmed value returned
git ls-files | grep .env -> .env.example, apps/web/.env.example (no .env); only key-like tracked file is apps/api/config/credentials.yml.enc (encrypted, from Feature 2)

# C. Tests
git archive 204cf7e apps/web -> scratch; pnpm install; pnpm test ->
  FAIL public-config.test.ts   TS2307 Cannot find module '~/config/public-config'
  FAIL server-config.test.ts   TS2307 Cannot find module '~/config/server-config.server'
  FAIL site-shell.test.tsx     TS2307 Cannot find module '~/components/site-shell'
  Test Suites: 3 failed, 3 total
Mutation testing on a scratch copy of HEAD (11 mutations, each reverted): every one fails the suite
  h1->h2, children outside main, heading ignored, public no trim, public default changed, public ignores env,
  server no blank check (2 fail), server only first missing, server values swapped, server never throws (5 fail),
  only URL required (3 fail)
Configuration ablation (scratch copy, one piece removed at a time):
  no client-env mapper       -> TS1343 import.meta ...            (needed)
  mappers in reverse order   -> TS1343                           (order matters, as commented)
  no ~/* mapper              -> Cannot find module '~/config/public-config' from ...  (needed)
  no testEnvironment         -> ReferenceError: document is not defined + "Consider using the "jsdom" test environment"  (needed)
  no setupFilesAfterEnv      -> TypeError: expect(...).toHaveTextContent is not a function  (needed)
  no transform               -> "Must use import to load ES Module: …/test/setup-jest.ts"   (needed; see F-2)
  ts-jest with app tsconfig  -> TS1295 ... under 'verbatimModuleSyntax'                        (needed)
  no verbatimModuleSyntax:false -> TS1295                                                      (needed)
  no "module": "CommonJS"    -> 12 passed                                                     (NOT needed; F-3)
  no "module" AND no client-env mapper -> TS1343 (so ts-jest still emits CommonJS on its own)
  no .css mapper             -> 12 passed (no test imports CSS)                               (unused today; F-6)
  no image mapper            -> 12 passed (no test imports an image)                          (unused today; F-6)
  "jest" removed from tsconfig types -> pnpm typecheck still exit 0 (jest-dom's types reference @types/jest; F-6)
ts-jest 29.4.12 source, dist/legacy/compiler/ts-compiler.js:138-146: when not in ESM mode, fixupCompilerOptionsForModuleKind returns module: CommonJS

# D. Tooling and versions
packageManager hash sha512.08adc661…b07c9 == hex of `npm view pnpm@12.4.2 dist.integrity` (identical)
git ls-files: apps/web/pnpm-lock.yaml only; no package-lock.json / yarn.lock anywhere
npm view react-router time: 8.3.1 2026-08-28T14:47Z · 8.4.0 2026-09-15T15:23:42Z (latest tag 8.4.0)
npm view @types/node time: 24.13.4 2026-09-09T18:10Z · 24.13.5 2026-09-15T20:37Z
npm view typescript-eslint@8.70.0 peerDependencies.typescript -> ">=4.8.4 <6.1.0"; latest typescript-eslint is 8.70.0
npm view ts-jest@29.4.12 peerDependencies.typescript -> ">=4.3 <7"; latest ts-jest is 29.4.12; typescript latest 7.0.2
Current latest matches the pin: pnpm 12.4.2, create-react-router 8.4.0, jest / jest-environment-jsdom 30.5.1, tailwindcss and
  @tailwindcss/vite 4.3.3, vite 8.3.0, react 19.3.0, eslint 10.10.0, @eslint/js 10.0.1, RTL 16.3.3, @testing-library/dom 10.4.2,
  jest-dom 7.0.1, react-hooks 7.1.1, eslint-config-prettier 10.1.8, isbot 5.2.2, @types/jest 30.0.0
  (prettier 3.9.7 appeared 2026-09-16T08:23Z, after the pin; 3.9.6 was latest at implementation time)
node_modules/eslint/package.json (10.10.0): no @eslint/js dependency (the chapter's claim holds)
pnpm-workspace.yaml: allowBuilds denies @parcel/watcher and unrs-resolver, allows nothing;
  `pnpm why` traces both to jest-* packages; the full suite passes with both denied
Could not confirm pnpm 12's minimumReleaseAge default from the docs (the settings page does not show it); the install
  output "Lockfile passes supply-chain policies" confirms the policy is active

# E. CI
web.yml: permissions contents: read; pull_request [main], no paths; push [main] with apps/web/** + web.yml paths;
  node-version-file apps/web/.node-version; corepack enable; pnpm store path + actions/cache@v6; jobs ESLint (+format:check),
  TypeScript, Jest, Build
git diff main...HEAD -- api.yml: comment added, 3 pull_request paths lines removed; nothing else
gh api repos/actions/{checkout,setup-node}/git/ref/tags/v7, actions/cache .../tags/v6 -> all exist;
  releases/latest: checkout v7.0.1, setup-node v7.0.0, cache v6.1.0
gh pr checks 2 -> Build, ESLint, Jest, RSpec, RuboCop, TypeScript: pass; runs 35100955919 / 35100956041 are on head acb3ba3
gh pr view 2 -> mergeable MERGEABLE, mergeStateStatus CLEAN
Live protection vs the report's PUT payload: every field identical; required_status_checks currently null; GitHub Actions app id 15368 confirmed

# F. .gitignore and apps/api
git diff --stat main...HEAD -- apps/api -> apps/api/tmp/.keep, apps/api/tmp/pids/.keep only (both 0 bytes)
git ls-files apps/api/tmp -> exactly those two
git check-ignore -v apps/api/config/master.key -> apps/api/.gitignore:25:/config/*.key
git check-ignore -v apps/web/anything.key deep/a/b/x.key -> .gitignore:31:*.key (both)
git check-ignore -v tmp/foo apps/api/tmp/foo -> .gitignore:25:/tmp/ ; apps/api/.gitignore:15:/tmp/*
mv apps/api/.gitignore aside -> .gitignore:31:*.key apps/api/config/master.key; restored; git status --porcelain --untracked-files=all empty

# G. Chapter
Ran chapter step 1 (npx create-react-router@8.4.0 …) in scratch: same file list; react-router.config.ts, vite.config.ts,
  routes.ts, .gitignore identical to the repo; root.tsx differs only by the links block and lang; tsconfig only by "jest";
  template ships typescript ^5.9.3 and @types/node ^22
Ran step 2 (rm, .node-version, corepack use pnpm@12.4.2) -> Done, packageManager with the same hash; no pnpm-workspace.yaml created
Ran step 3 with package.json and pnpm-workspace.yaml copied from the chapter -> valid JSON, pnpm install Done, no errors
Verbatim comparison, repo file vs chapter: 23 of 25 files appear verbatim; jest.config.js differs in comment wrapping (F-7);
  web.yml only the first 68 of 166 lines are given (F-5)
Step 9 route-level negative experiment -> error text identical to the chapter
Step 9 loader experiment -> build 0, build/client clean, build/server/index.js contains API_INTERNAL_TOKEN;
  serving it without variables -> GET / 500 with the "Missing required server environment variables" message (matches §5)
Planted `const unused = 1;` -> "'unused' is assigned a value but never used  @typescript-eslint/no-unused-vars"
pnpm clean --help -> "-l, --lockfile  Also remove pnpm-lock.yaml files" (trap 2's command exists)
Markdown fences: line 1129 "``` Commit it as …" is not a closing fence (F-4)

# H. Conventions
12 commits main..HEAD, all "Feature 3: …", all authored by Myepes05, English
PR title exact; PR body vs .github/pull_request_template.md (F-8)
git diff main...HEAD -- CLAUDE.md -> only the §7 Web line
grep for fetch(/loader/action/admin/cloudinary in apps/web/app -> only a doc comment
```

## Acceptance criteria verification
| Criterion | Result | Evidence |
|---|---|---|
| Server-rendered React Router app in strict TS, Tailwind working | Pass | `ssr: true`, `"strict": true`; curl shows the content in the first HTML response; the classes are in the built CSS |
| pnpm used throughout and pinned | Pass | `packageManager` with a hash that matches the registry; one lockfile only |
| lint, typecheck, test pass locally, outputs in report | Pass | Re-run above: 0 findings, 0 type errors, 12/12 |
| Tests committed before the code they cover | Pass | `204cf7e` → `3e1052e`; all 3 suites fail at `204cf7e` (TS2307) |
| `/` server-rendered, with evidence | Pass | curl without a browser (A.2) |
| Config module keeps server-only values out of the client bundle; mechanism explained and verified | Pass, with F-1 | Build fails on a client import; bundle grep clean. But `client-env.ts` is not the only `import.meta.env` reader (F-1) |
| `.env.example` documents every variable; no `.env` committed | Pass | 3 variables, placeholders only; nothing tracked |
| `web.yml` least privilege + D-065; `api.yml` updated | Pass | E.1 and E.2 |
| Root `.gitignore`: `/tmp/` and `*.key`, verified | Pass | F.1 to F.3 |
| CI green on the PR for both workflows | Pass | 6/6 on `acb3ba3` |
| Required-status-checks command in report, not executed | Pass | `required_status_checks` still null; the payload matches the live settings |
| `CLAUDE.md` §7 Web line only | Pass | H.4 |
| Chapter 03 written, reproducible, indexed | Pass with findings | F-2, F-3, F-4, F-5; README row present |
| PR opened with exact title, not merged | Pass | `OPEN` |
| Nothing outside scope | Pass (accepted deviation) | Only the two empty `.keep` files in `apps/api` (D-069) |

## Decision compliance
| Decision | Compliant? | Notes |
|---|---|---|
| D-005 | Yes | Tailwind 4 via `@tailwindcss/vite`; no MUI |
| D-018 | Yes | SSR verified with curl |
| D-020 | Partly | Jest + RTL + jsdom + ts-jest, no Vitest anywhere. But `root.tsx` reads `import.meta.env.DEV` directly in a component, against CLAUDE.md §6 (F-1) |
| D-021 | Yes | corepack, `packageManager` with hash |
| D-033 / D-069 | Yes | Four web jobs; Build accepted in D-069 |
| D-039 / D-045 | Yes | The `.server` boundary is enforced by the build (verified both ways). No `Cache-Control` yet, correctly deferred to Phase 4 |
| D-050 / D-042 | Yes | Spec commit first and failing for the right reason |
| D-055 | Yes | Versions spot-checked (D above); the two "not newest" claims are true |
| D-059 | Yes | Nothing sensitive added; placeholders only |
| D-064 / D-067 | Mostly | Accurate and largely reproducible (steps 1–3 re-run); F-2 to F-5 |
| D-065 | Yes | Both workflows: no PR path filter, push filter kept |
| D-066 | Yes | `contents: read` in both |
| D-068 | Yes | Implementation agent left the checkout on `main` (as found at session start) |
| D-069 | Yes | The accepted deviations are implemented as described; none re-filed. The reasons given for deviations 1 and 2 were verified true |

## Spec review
- **Order:** `204cf7e` (specs, Jest setup, types-only `env-types.ts`) comes before `3e1052e` (implementation). At `204cf7e` all three suites fail with `TS2307` because the modules under test are missing, not because of configuration. That is the right way to fail.
- **Meaningful?** Yes. All 11 behavioural mutations I tried were caught. The server-config edge cases are covered: each variable missing, each variable blank, and both missing in one message. Blank and absent public values are covered too.
- **Gaps (nit, F-9):** nothing asserts that `readServerConfig` trims the returned values; the test inputs have no surrounding whitespace, so dropping the `.trim()` on return would pass. `getServerConfig()` caching and the `home.tsx` route (`meta` title, Spanish text) are untested. None of these is required by the prompt.
- **Jest, not Vitest:** confirmed everywhere. Every piece of `jest.config.js` / `tsconfig.jest.json` is needed except the `"module": "CommonJS"` override (F-3) and the CSS/image mappers, which no current test exercises (F-6).

## Learning chapter review
- **Template sections:** all 10 present. The index row is in `handoff/learning/README.md`.
- **Accuracy, 20 claims spot-checked:**
  1. Generator command and its file list: ✓ (re-run)
  2. `react-router.config.ts` / `vite.config.ts` "unchanged from the template": ✓
  3. `root.tsx` edits are only the links block and `lang`: ✓
  4. The template ships TypeScript `^5.9.3` and `@types/node ^22`: ✓
  5. `corepack use` writes the hash: ✓ (matches the registry integrity)
  6. The step 3 `package.json` + `pnpm-workspace.yaml` install cleanly: ✓
  7. The peer ranges of typescript-eslint / ts-jest: ✓
  8. The 8.4.0 and `@types/node` 24.13.5 publication times: ✓
  9. Jest failure table rows 2–6: ✓ reproduced; row 1: path wrong (F-2)
  10. Step 9 negative error text: ✓ verbatim
  11. Step 9 loader experiment: ✓
  12. Step 8 curl output and Tailwind grep: ✓
  13. "lists 20 files" and the planted-error message: ✓
  14. `.gitignore:31:*.key` and the nearest-rule behaviour: ✓
  15. `pnpm why` leads to Jest: ✓
  16. `pnpm clean --lockfile` exists: ✓
  17. ESLint 10 has no `@eslint/js` dependency: ✓
  18. A loader without the variables returns 500: ✓
  19. A PR template exists (step 14): ✓
  20. The Feature 4 / Phase 4 / Feature 19 references match the master plan: ✓
- **Jest section:** excellent and mostly verified. I reproduced all six failures (the prompt asked for at least two). Two corrections are needed: F-2 (the wrong file in the row 1 error) and F-3 (`module: CommonJS` is presented as a needed override, but ts-jest forces it anyway).
- **Reproducibility (D-067):**
  - **What works:** Node 24.14.0 via nvm, `corepack enable`, and the pnpm steps are explained. Steps 1–3 reproduce exactly. The directory for each step is stated.
  - **Gaps:** `web.yml` is not given in full (F-5), and the step 13/14 markdown is broken (F-4).
  - **Borderline, not filed:** the chapter tells a reader without nvm to run `nvm install` but not how to install nvm. Chapter 01 only recorded that Node was present.
- **Technical correctness:**
  - **The `.server` explanation** is correct and matches both the observed errors and React Router's docs.
  - **The D-065 explanation** is correct: a path-skipped workflow leaves a required check pending, and the PR is blocked.
  - **One inconsistency:** step 7 says `client-env.ts` is "the only place in the app that reads `import.meta.env`", while §5 correctly says `root.tsx` reads `import.meta.env.DEV` (F-1).

## Findings
| # | Severity | Finding | Location | Steps to reproduce / evidence | Suggested fix |
|---|---|---|---|---|---|
| F-1 | **major** | A component reads `import.meta.env` directly, and the "only reader" claim is false. `ErrorBoundary` uses `import.meta.env.DEV`, which breaks CLAUDE.md §6 ("never with `import.meta.env` directly in components") and QA check B.1. The false claim is repeated in `client-env.ts:4`, the report's summary, the PR body and chapter step 7 (line 656); chapter §5 (line 1232) contradicts step 7. Practical effect: `root.tsx` cannot be imported by any Jest test (TS1343). | `apps/web/app/root.tsx:46`; `app/config/client-env.ts:4`; chapter lines 656, 662, 1232 | `grep -rn 'import\.meta\.env' apps/web/app` shows `root.tsx:46` alongside `client-env.ts:20` | Expose the flag through the config module: add `DEV` (or `isDev`) to `ClientEnv`, `client-env.ts` and the Jest stub, and have `ErrorBoundary` read it from there. Then the claim is true; update chapter §5 to match. Translating the English strings can still wait (see H.3). |
| F-2 | minor | Chapter Jest table row 1 quotes the wrong file. With no transform, the failing file is the setup file, not the test. Rated minor because the diagnosis is right and only the path in the quoted output is wrong. | chapter line 294 | Remove `transform` from `jest.config.js` and run `pnpm exec jest app/config/public-config.test.ts`. Output: `Must use import to load ES Module: …/test/setup-jest.ts` | Quote `…/test/setup-jest.ts`, and add one sentence saying the setup file is loaded first |
| F-3 | minor | `"module": "CommonJS"` in `tsconfig.jest.json` is redundant. ts-jest 29.4.12 forces CommonJS outside ESM mode, so both the file's comment and the chapter wrongly say this override is needed. The report says unneeded overrides were removed, yet this one remains. | `apps/web/tsconfig.jest.json:4-10`; chapter lines 371–383 | Without it, 12 tests pass. Without it and without the client-env mapper, TS1343 still appears, so the output is still CommonJS. Source: `node_modules/ts-jest/dist/legacy/compiler/ts-compiler.js:138-146` | Either remove it, or keep it and reword: "ts-jest emits CommonJS anyway outside ESM mode; stated here for clarity. The override that matters is `verbatimModuleSyntax: false`." |
| F-4 | minor | Broken markdown fence in step 13. Line 1129 starts with a triple backtick followed by text, which is not a valid closing fence, so the code block runs on to line 1137 and swallows the "Step 14" heading and its prose. | chapter line 1129 | View the file rendered on GitHub | Put the closing fence on its own line and the "Commit it as …" sentence on the next line |
| F-5 | minor | `web.yml` is not given in full (D-067 asks for every file the reader creates). Missing: the other three jobs, the Build job's comment, and the step names `Type-check`, `Run the tests` and `Build for production`. The chapter also says `api.yml` gets "the same explanatory comment", but the real one differs ("a merged web or docs change … API suite"). Rated minor because a reader can rebuild a working file from the table. | chapter lines 1049–1057, 1074 | Verbatim comparison: only the first 68 of 166 lines of `web.yml` appear in the chapter | Include the whole `web.yml` (or the three remaining jobs), and quote the `api.yml` comment |
| F-6 | nit | Some Jest and tsconfig pieces are unused today. Nothing imports CSS or images in a test, so the `.css` and image mappers and their stubs are never used. `"jest"` in `tsconfig.json` `types` is not needed by `tsc` today either, because `@testing-library/jest-dom`'s types already reference `@types/jest` (`tsc --explainFiles`). The chapter (line 1236) says this entry is what makes `tsc` understand the globals. | `jest.config.js:31-32`; `test/stubs/{style,asset}.ts`; `tsconfig.json:10`; chapter line 1236 | Remove each one: 12 tests pass and `tsc` exits 0 | Keeping them as forward-looking is fine (the first component importing CSS will need the mapper). Say so in the chapter, and reword line 1236 to "makes the dependency explicit" |
| F-7 | nit | The committed `jest.config.js` comment has an unwrapped 120+ character line (from `3acbef2`), and the chapter shows a differently wrapped version | `apps/web/jest.config.js:16`; chapter lines 328–332 | Verbatim comparison fails at line 16 | Rewrap the file to match the chapter |
| F-8 | nit | The PR body doesn't follow `.github/pull_request_template.md`: it has no "Task" section with the prompt link and no "Checklist". The report is given as a path, not a link. It does satisfy CLAUDE.md §5's four items. | PR #2 description | `gh pr view 2 --json body` | Edit the PR body to the template shape |
| F-9 | nit | Small untested behaviours: trimming of returned server values, `getServerConfig()` caching, and the `home.tsx` `meta` title / text | `server-config.server.ts:50-53, 66-69`; `routes/home.tsx` | Dropping `.trim()` on the returned values leaves all tests green (no test input has surrounding whitespace) | Add `" http://x "` → `"http://x"` to the server-config spec. Route tests can come with Phase 4 |
| F-10 | nit | `.env.example` warns "Never give a secret a VITE_ prefix" in general but doesn't name `API_INTERNAL_URL` / `API_INTERNAL_TOKEN` (the runtime error message does). Also undocumented: reading `import.meta.env` as a whole object inlines **every** `VITE_` variable, including a wrongly prefixed secret that no code references. | `apps/web/.env.example:8-16`; `client-env.ts:17-19` | A temporary `JSON.stringify(import.meta.env)` plus `VITE_API_INTERNAL_TOKEN=leak-test-123` put the value in `build/client` | One sentence in `.env.example` naming the two variables; one sentence in `client-env.ts` / chapter trap 8 about whole-object reads |

## Security & conventions
- **Secrets:**
  - No `.env`, key or build output is tracked.
  - `.env.example` holds placeholders only.
  - The internal token cannot reach the client bundle through an import, as proven both ways.
  - A `VITE_`-prefixed secret would be exposed only if code referenced it (or read the whole object, F-10). `readServerConfig`'s error message warns against that prefix.
- **Install-time code:** `allowBuilds` denies both scripts, allows none, and the suite passes without them. Justified.
- **CI:**
  - Least-privilege token in both workflows.
  - The action tags exist upstream.
  - `ruby/setup-ruby@v1` is a branch, not a tag, and is unchanged by this PR.
- **E.5, can a PR fail to satisfy the six required checks?** No, not for normal PRs to `main`. PRs touching only `handoff/`, only `apps/web` or only `apps/api` run both workflows, because `pull_request` has no path filter. Edge cases that would stay pending:
  - PRs with merge conflicts: `pull_request` workflows don't run until the conflict is resolved.
  - Fork PRs awaiting approval.
  - Commits with `[skip ci]`.

  All are expected behaviour. `docs N` commits go straight to `main` with `enforce_admins: false`, so they are unaffected.
- **Check names (suggestion):** the generic check names `Build` and `Jest` would also be satisfied by any future Actions job with the same name, for example a deploy workflow's `Build`. Consider unique names (`Web build`, …) before requiring them, or keep job names unique across workflows.
- **Conventions:**
  - Branch name, PR title and all 12 commit prefixes are correct.
  - English everywhere. The Spanish text is user-facing, apart from the test fixtures "Contenido …", which is acceptable.
  - The `CLAUDE.md` diff is the Web line only.
  - Scope: no loaders, no API calls, no admin routes, no design.
- **H.3, `ErrorBoundary`'s English text:** I agree it can wait for Feature 14/18. Nothing is deployed, and the text is template placeholder content. F-1 concerns only the environment read in that component, not its language.
- **Merge state:** `MERGEABLE` / `CLEAN` against the current `main` (which already contains `docs 7`'s `CLAUDE.md` changes).

## Questions for the owner
1. **F-1 severity.** I rated it `major` because it breaks an explicit CLAUDE.md §6 rule and falsifies the central "only reader" claim that section B checks. The code comes from the template, reads Vite's built-in `DEV` flag (not a project variable), and chapter §5 discloses it. If you consider that disclosure sufficient, it could be downgraded to `minor`, and the verdict would become PASS WITH NOTES.
2. **F-3 and F-6.** Do you prefer removing the redundant or unused configuration now, or keeping it with corrected comments?
3. **Check names.** Rename the generic check names (`Build`, `Jest`) before running the D-070 command? Renaming later would require updating the protection settings.
