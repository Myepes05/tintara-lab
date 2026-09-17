# QA — Feature 3: create the React Router web skeleton with Jest, ESLint and CI

**Type:** QA · **Target:** PR #2 https://github.com/Myepes05/tintara-lab/pull/2, branch `feature/3-web-skeleton`
**Implementation prompt:** `handoff/prompts/implementation/feature-003-web-skeleton.md`
**Implementation report:** `handoff/agent-outputs/implementation/feature-003-web-skeleton.md` (on the branch)
**Report file:** `handoff/agent-outputs/qa/qa-feature-003-web-skeleton.md` (use `handoff/templates/qa-output.md`)

## Rules
- **Do not modify** application code, configuration, workflows, the report or the chapter. Do not push to the branch.
- Leave your report **untracked**, and **end your session on `main`** with `git switch main` (CLAUDE.md §5, D-068). Untracked `apps/web/build/` and `apps/web/.react-router/` will appear on `main` until this PR merges; leave them alone.
- Verify everything yourself. The implementation report is a claim, not evidence.
- Classify findings: `blocker`, `major`, `minor`, `nit`. Say explicitly when an area is clean.

## Before you start
1. Read `CLAUDE.md`, including the new "One shared checkout" subsection of §5 and §7b.
2. Read the implementation prompt and the report.
3. Read these decisions: D-005, D-018, D-020, D-021, D-033, D-039, D-045, D-050, D-055, D-059, D-064, D-065, D-066, D-067, D-068, D-069.
4. **D-069 already accepts the report's ten deviations.** Don't re-file them as findings. You may still report that a deviation is *implemented* incorrectly, or that one of the reasons given for it is false.
5. `git switch feature/3-web-skeleton`. Node 24 and corepack are installed on this machine; run `corepack enable` if `pnpm -v` fails.

## A. Functional verification
From `apps/web`:
1. `pnpm install --frozen-lockfile`, `pnpm lint`, `pnpm format:check`, `pnpm typecheck`, `pnpm test`, `pnpm build`. All must pass with zero warnings. Record the real counts.
2. **Server rendering:** start the production server and fetch `/` with `curl`, **without** a browser. The initial HTML must already contain the heading and paragraph text. Check that `<html lang="es">` and `<title>Tintara Lab</title>` are present.
3. `pnpm dev` starts, and the page renders.
4. The Tailwind utility class used on the page actually appears in the built CSS.

## B. The server/client boundary (D-039, D-045) — the most important check
1. Read `app/config/`. Confirm that `client-env.ts` is the only file reading `import.meta.env`, and that no component reads the environment directly.
2. **Prove the build-time guarantee yourself.** Temporarily import `server-config.server.ts` from a client module (for example the `SiteShell` component), run `pnpm build`, and confirm the build **fails**, with the error naming the `.server` module. Then revert and confirm `git status` is clean. Record the exact error text.
3. After a normal build, search `build/client` for `API_INTERNAL`, `readServerConfig`, `getServerConfig` and any value from `.env.example`. There must be no match.
4. Check what happens when a `VITE_`-prefixed variable is set: it **is** exposed to the client by design. Confirm that `.env.example` warns clearly against ever prefixing the server-only variables with `VITE_`.
5. Confirm `readServerConfig` throws, naming each missing variable, and treats blank values as missing.
6. `apps/web/.env.example` documents all three variables with placeholders only. No `.env` is tracked anywhere.

## C. Tests (D-020, D-042, D-050)
1. The spec commit `204cf7e` precedes the implementation commit `3e1052e`. Check that the tests in `204cf7e` **fail** at that commit, by checking it out, installing and running `pnpm test`. A spec committed first that already passed proves nothing.
2. Read every test. Are they meaningful? Would each fail if the behaviour regressed? Are the server-config edge cases (missing, blank, several missing) covered?
3. Is it Jest, not Vitest, everywhere? Review `jest.config.js`, `tsconfig.jest.json` and the `test/` stubs. Is every piece needed? The report says two overrides were removed as unnecessary; confirm what remains is used.

## D. Tooling and versions (D-021, D-055)
1. pnpm is pinned in `packageManager`, with its integrity hash. The lockfile is committed. No `package-lock.json` or `yarn.lock` exists.
2. Spot-check at least five version claims in the report's table against the npm registry, including the two "not newest" claims: React Router 8.4.0's publication time, and TypeScript 7's exclusion from the `typescript-eslint` and `ts-jest` peer ranges.
3. `pnpm-workspace.yaml` denies install scripts. Confirm what it allows, if anything, and whether that is justified.
4. ESLint and Prettier don't conflict, and `pnpm lint` produces **no output**, not just a zero exit code.

## E. CI (D-033, D-065, D-066)
1. `web.yml`: `permissions: contents: read`; `pull_request` with no path filter; `push` to `main` with the path filter; Node from `.node-version`; corepack; pnpm store cached; jobs `ESLint`, `TypeScript`, `Jest`, `Build`.
2. `api.yml`: `pull_request` path filter removed, `push` path filter kept, nothing else changed.
3. Pinned actions exist upstream at the pinned versions (check their repositories, not the report).
4. `gh pr checks 2`: all six checks passed on the **current head** commit.
5. Consider: once the six checks are required (D-070), will any PR be unable to satisfy them? Think about PRs that touch only `handoff/` or only one app.

## F. Root `.gitignore` and `apps/api`
1. `tmp/` is now `/tmp/`, and a commented `*.key` section exists.
2. `git diff --stat main...HEAD -- apps/api` shows only the two empty `.keep` files (accepted in D-069).
3. Confirm the root `*.key` rule works, using the technique from the report's deviation 7, then restore everything and check `git status`.
4. Nothing under `apps/api/tmp/` other than the two `.keep` files is tracked.

## G. Learning chapter 03 (D-064, D-067)
The chapter is long (about 1,300 lines). Prioritize:
1. **Accuracy:** spot-check at least 10 concrete claims against the repository, and list them: commands, file excerpts, error messages, versions.
2. **The Jest section:** every error message in its "six real failures" table must be plausible for the configuration it describes. Reproduce at least two of them by temporarily removing the relevant configuration, then restore it.
3. **Reproducibility (D-067):** start from chapter 02's end state. Would a reader get Node 24.14.0, corepack and pnpm working from the chapter's instructions alone? Are the directories of each step clear? Is every file the reader must create given in full?
4. **Technical correctness** of the `.server` boundary explanation and the D-065 trigger explanation.
5. The template's 10 sections are present, and the index row exists in `handoff/learning/README.md`.

A chapter that states something untrue is a `major` finding.

## H. Conventions and scope
1. Branch name, PR title exactly `Feature 3: create the React Router web skeleton with Jest, ESLint and CI`, and all commits prefixed `Feature 3:`.
2. The PR description follows the template and links the report.
3. English everywhere, except the Spanish user-facing strings. Note: `root.tsx`'s `ErrorBoundary` still has English template text; the report lists it as a follow-up. Record whether you agree it can wait.
4. `CLAUDE.md` diff: only the §7 Web line.
5. Nothing outside the scope: no API calls, no loaders fetching data, no design, no admin routes.

## Verdict
`PASS`, `PASS WITH NOTES` or `FAIL`, with justification. `blocker` and `major` findings are fixed in this PR before merging (D-054).

## Final step
`git switch main` and confirm `git status` shows only your untracked report plus the untracked `apps/web` build folders.
