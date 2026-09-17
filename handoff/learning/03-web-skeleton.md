# Chapter 03 — The React Router web skeleton: server rendering, Jest, ESLint and CI

**Task:** Feature 3 · **Decisions:** D-005, D-018, D-019, D-020, D-021, D-032, D-033, D-039, D-045, D-050, D-055, D-065, D-066, D-067, D-071 · **Code:** PR [#2](https://github.com/Myepes05/tintara-lab/pull/2)

## 1. What we are building in this chapter

By the end of this chapter, `apps/web` holds the frontend: a React Router app in framework mode that renders its one page, `/`, **on the server**. It is written in strict TypeScript, styled with Tailwind, linted with ESLint, formatted with Prettier and tested with Jest. A second GitHub Actions workflow, `web.yml`, checks all of that on every pull request.

The page itself is deliberately empty: a heading, "Tintara Lab", and one placeholder sentence. The work in this chapter is the machinery around it:

- **Jest in a project built with Vite.** Vite is the tool that builds the app; Jest does not use it. Section 4, step 6, and section 7 explain what breaks and how each piece of configuration fixes it.
- **A server/client boundary.** Server-only values, above all the internal API token, can never reach the browser, and the build enforces that rather than a convention.
- **A trigger rule for both workflows** that keeps required checks from blocking unrelated pull requests forever.

## 2. What you need to know first

- **React.** A JavaScript library that builds a user interface from *components*: functions that return a description of the markup (JSX, the HTML-like syntax inside `.tsx` files).
- **Single-page app (SPA).** The server sends an almost empty HTML file plus a JavaScript bundle; the browser runs the JavaScript, which then builds the page. Until that script runs, the page has no content.
- **Server-side rendering (SSR).** The server runs the same React components and sends the finished HTML. The browser shows it immediately, then downloads the JavaScript and *hydrates* the page, which means attaching the interactive behaviour to HTML that is already there.
- **React Router, framework mode.** React Router started as a library that maps URLs to components. In *framework mode* it is also the build tool and the server: it reads a list of routes, renders them on the server, splits the code per route, and gives each route a `loader` (code that fetches data on the server before rendering) and an `action` (code that handles form submissions). This is the successor of the Remix framework.
- **Vite.** The build tool underneath React Router. It compiles TypeScript and JSX, bundles the code for the browser, and runs the development server. It is configured through *plugins*: here, React Router's plugin and Tailwind's.
- **Bundle / client bundle / module graph.** A bundle is the set of JavaScript files a build produces. The *client bundle* is the one sent to browsers, and anyone can download and read it. A *module graph* is the tree of files reachable by following `import` statements from an entry point. Whatever is in the client module graph ends up in the client bundle.
- **Environment variable.** Configuration passed from outside the code, as in chapters 01 and 02. In Node it is read with `process.env.NAME`. Vite adds a second mechanism, `import.meta.env.NAME`, whose values are **copied into the bundle when you build it**.
- **pnpm and corepack.** pnpm is a Node package manager, like npm, that stores each package once on disk and links it into projects. corepack ships with Node and installs the exact package-manager version a project declares, so nobody installs pnpm by hand (D-021).
- **`package.json` / `pnpm-lock.yaml`.** The list of dependencies a project wants, and the exact resolved versions, committed so that every machine installs the same ones. This is the Node equivalent of `Gemfile` and `Gemfile.lock` from chapter 02.
- **TypeScript and `tsc`.** TypeScript is JavaScript with types; `tsc` is its compiler. Vite strips the types without checking them, so a separate `tsc` run is what actually catches type errors.
- **Tailwind CSS.** A CSS framework made of small *utility classes* (`text-3xl`, `p-8`) that you combine in the markup. At build time it scans the source files and emits only the classes they use.
- **Jest.** A JavaScript test runner. **jsdom** is a browser-like DOM implemented in Node, so components can be rendered without a real browser. **React Testing Library (RTL)** renders components into that DOM and finds elements the way a user would, by role and text.
- **ESLint and Prettier.** ESLint finds code mistakes (unused variables, misused React hooks); Prettier formats code. They overlap on formatting, so one of them has to yield.
- **CommonJS and ES modules.** Two JavaScript module systems. CommonJS uses `require()` and `module.exports` and is Node's original system; ES modules (ESM) use `import`/`export`. Vite works in ESM. Jest, by default, runs tests as CommonJS. That mismatch is behind most of step 6.

## 3. Starting point

The repository as chapter 02 left it, with PR #1 merged: `apps/api` holds the Rails API, `.github/workflows/api.yml` runs RuboCop and RSpec, and there is no `apps/web`. Nothing in this chapter needs Postgres or Rails to be running.

Before starting, run this from the **repository root**:

```sh
git checkout main
git status                       # clean
git pull                         # must include "Feature 2: create the Rails API skeleton ..."
ls apps                          # api   (and nothing named web)
git checkout -b feature/3-web-skeleton

node -v                          # v24.14.0
corepack --version               # 0.34.6
corepack enable                  # installs the pnpm shim next to node
```

- **Node was checked in chapter 01, but nothing installed it for this project.** This machine had Node 24.14.0 through nvm (the Node version manager). If `node -v` prints something else, run `nvm install 24.14.0` and `nvm use 24.14.0`. Stay on Node 24: corepack is bundled with it, and newer Node lines have stopped bundling corepack.
- **`corepack enable` is a once-per-machine step.** It creates a `pnpm` command that, inside a project, runs exactly the pnpm version the project's `package.json` declares. Do **not** install pnpm with `npm install -g pnpm` or Homebrew: that pnpm ignores the pin, and you end up with two pnpm versions on one machine (D-021). Right after `corepack enable`, running `pnpm -v` outside a project downloads corepack's default pnpm; that is expected.

Steps 1, 11, 12, 13 and 14 run from the repository root. Steps 2 to 10 run from `apps/web`. Each step says where it runs.

## 4. Step by step

### Step 1 — Generate the app (repository root)

```sh
npx --yes create-react-router@8.4.0 apps/web \
  --no-git-init --no-install --no-agent-skills \
  --package-manager pnpm --yes
```

- **What it does:** copies React Router's default template into `apps/web`. The template already contains framework mode with server rendering on, TypeScript in strict mode, and Tailwind CSS 4 wired into Vite. That is why this chapter has no separate "install Tailwind" step.
- **Why these flags:**
  - `--no-git-init`: the generator would otherwise create a `.git` directory inside `apps/web`, a repository nested inside ours. That is the same trap as chapter 02's `rails new` (trap 1 there).
  - `--no-install`: we pin versions before installing anything (step 3).
  - `--no-agent-skills`: skips an optional AI-assistant instruction file that this project does not use.
  - `--package-manager pnpm`: makes the generator's printed hints use pnpm.
  - `--yes`: accepts the defaults without prompting.
- **The documented command** on reactrouter.com is `npx create-react-router@latest my-react-router-app`. We pin `@8.4.0`, the version that was current, so the command gives the same result tomorrow.
- **What you should see:** `✔ Template copied`, then `That's it!`, and these files: `.dockerignore`, `.gitignore`, `Dockerfile`, `README.md`, `app/` (`app.css`, `root.tsx`, `routes.ts`, `routes/home.tsx`, `welcome/`), `package.json`, `public/favicon.ico`, `react-router.config.ts`, `tsconfig.json`, `vite.config.ts`.

Two generated files matter right away:

```ts
// react-router.config.ts (unchanged from the template)
import type { Config } from "@react-router/dev/config";

export default {
  // Config options...
  // Server-side render by default, to enable SPA mode set this to `false`
  ssr: true,
} satisfies Config;
```

`ssr: true` is D-018 in one line. It is also React Router's default, so the line only documents the choice.

```ts
// vite.config.ts (unchanged from the template)
import { reactRouter } from "@react-router/dev/vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [tailwindcss(), reactRouter()],
  resolve: {
    tsconfigPaths: true,
  },
});
```

This is the setup from Tailwind's official "Using Vite" guide: the `@tailwindcss/vite` plugin, plus `@import "tailwindcss";` in the CSS file. `resolve.tsconfigPaths` makes Vite honour the `~/*` path alias declared in `tsconfig.json`, so `~/components/site-shell` means `app/components/site-shell`.

### Step 2 — Remove what does not belong, pin Node and pnpm (`apps/web`)

```sh
cd apps/web
rm Dockerfile .dockerignore
echo "24.14.0" > .node-version
corepack use pnpm@12.4.2
```

- **Why the Dockerfile goes:** it runs `npm ci` and copies `package-lock.json`, a file that never exists in a pnpm project, so it could not build this app. And hosting is not decided yet (D-036). D-030 limits Docker to Postgres in development. A Dockerfile nobody has ever built would only look like a deployment decision.
- **`.node-version`** mirrors `apps/api/.ruby-version`: one file that states the runtime, which CI reads too (step 11).
- **`corepack use pnpm@12.4.2`** writes `"packageManager": "pnpm@12.4.2+sha512.08adc…"` into `package.json` and runs a first install. The `+sha512…` suffix is an integrity hash: corepack refuses a downloaded pnpm whose contents do not match it. pnpm 12.4.2 was the latest release (`npm view pnpm version`).
- **What you should see:** the install ends with `Done in …s using pnpm v12.4.2`. pnpm 12 may also create a `pnpm-workspace.yaml`, its settings file. Step 3 gives that file its final content either way.

### Step 3 — Pin every dependency and deny install scripts (`apps/web`)

The template declares loose ranges (`"react-router": "^8"`). D-055 asks for pinned, verified versions, so `package.json` was rewritten with exact versions. This is its content at this step. The only difference from the final file is that `@eslint/js` is added in step 10:

```json
{
  "name": "@tintara-lab/web",
  "private": true,
  "type": "module",
  "packageManager": "pnpm@12.4.2+sha512.08adc6613180275c7c9edada39dcf08c9c61ad4e7eaf330a4f3461f102b0f907423454d117f98e72d47fef0616070644d7bffc973a6a57f5090a6d7c368b07c9",
  "engines": {
    "node": ">=24.14.0"
  },
  "scripts": {
    "dev": "react-router dev",
    "build": "react-router build",
    "start": "react-router-serve ./build/server/index.js",
    "typecheck": "react-router typegen && tsc",
    "lint": "eslint . --max-warnings=0",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "test": "react-router typegen && jest"
  },
  "dependencies": {
    "@react-router/node": "8.3.1",
    "@react-router/serve": "8.3.1",
    "isbot": "5.2.2",
    "react": "19.3.0",
    "react-dom": "19.3.0",
    "react-router": "8.3.1"
  },
  "devDependencies": {
    "@react-router/dev": "8.3.1",
    "@tailwindcss/vite": "4.3.3",
    "@testing-library/dom": "10.4.2",
    "@testing-library/jest-dom": "7.0.1",
    "@testing-library/react": "16.3.3",
    "@types/jest": "30.0.0",
    "@types/node": "24.13.4",
    "@types/react": "19.3.0",
    "@types/react-dom": "19.3.0",
    "eslint": "10.10.0",
    "eslint-config-prettier": "10.1.8",
    "eslint-plugin-react-hooks": "7.1.1",
    "jest": "30.5.1",
    "jest-environment-jsdom": "30.5.1",
    "prettier": "3.9.6",
    "tailwindcss": "4.3.3",
    "ts-jest": "29.4.12",
    "typescript": "5.9.3",
    "typescript-eslint": "8.70.0",
    "vite": "8.3.0"
  }
}
```

Then create `pnpm-workspace.yaml` (or replace its content, if step 2 created it) with:

```yaml
# pnpm settings for this package (pnpm 12 reads its configuration from here,
# not from package.json).

# Deny every dependency's install-time build script. Both entries below come
# from Jest 30 and both ship prebuilt platform binaries, so nothing needs to
# compile at install time. Denying them keeps `pnpm install` from executing
# third-party code on developer machines and in CI.
allowBuilds:
  "@parcel/watcher": false
  unrs-resolver: false
```

and install:

```sh
pnpm install
```

- **What the scripts do:** `dev` starts the development server, `build` writes `build/client` (browser files) and `build/server` (the server entry), and `start` serves that build with React Router's own small Node server. `typecheck` first runs `react-router typegen`, which generates the per-route types that files like `root.tsx` import from `./+types/root`, and then `tsc`. `test` runs `react-router typegen` before Jest for the same reason: step 6 adds a test that imports `root.tsx`, ts-jest type-checks it, and the generated `./+types/root` must exist. A fresh checkout, like CI's, does not have it (trap 16). `lint`, `format`, `format:check` and `test` are covered in steps 6 and 10.
- **How each version was chosen.** Each one was looked up with `npm view <package> version`, and the peer requirements were checked with `npm view <package> peerDependencies`. Three versions are deliberately *not* the newest release:
  - **`react-router` and the `@react-router/*` packages at 8.3.1, not 8.4.0.** 8.4.0 had been published the day before. pnpm 12 has a supply-chain rule, `minimumReleaseAge`, which by default refuses any version published within the last 24 hours. A brand-new release is when a hijacked package does its damage. The same rule held `@types/node` at 24.13.4 instead of 24.13.5. See trap 2 for what happens when you pin the newer version anyway.
  - **`typescript` at 5.9.3, not 7.0.2.** `typescript-eslint` 8.70 declares `typescript: ">=4.8.4 <6.1.0"` and `ts-jest` 29.4 declares `typescript: ">=4.3 <7"`. TypeScript 7 would install without complaint and then break the lint and test tooling. 5.9.3 is also what the template itself ships.
  - **`@types/node` at 24.x**, matching the Node version in `.node-version`. The template's `^22` described a Node we do not run.
- **Why deny the build scripts:** some packages run a script when they are installed. That is arbitrary code from the internet running on your machine. pnpm 12 refuses to run such scripts until each package is explicitly allowed or denied. Here both packages come from Jest (`pnpm why @parcel/watcher` and `pnpm why unrs-resolver` both lead to `jest`). Both ship precompiled binaries, and the whole suite passes with their scripts denied, so `false` is the safe answer.
- **What you should see:** the list of added packages, then `Done in …s using pnpm v12.4.2`, with no error. `pnpm-lock.yaml` now exists, and `node_modules/` and `.react-router/` are git-ignored by the generated `apps/web/.gitignore`.

### Step 4 — Replace the template README and commit the scaffold

The generated `README.md` is a template advertisement: it gives `npm` commands and Docker deployment steps, none of which apply here. Replace its whole content with this project's own:

````markdown
# apps/web — Tintara Lab frontend

React Router in framework mode (server-side rendering on, D-018), TypeScript in
strict mode, Tailwind CSS (D-005), ESLint, Prettier, and Jest with React Testing
Library (D-020). The package manager is pnpm, enabled through corepack (D-021).

The public page at `/` is server-rendered so that crawlers receive real HTML.
The admin area under `/admin` will be client-rendered and arrives in a later
feature.

## Requirements

- Node — the version in `.node-version`
- corepack (ships with Node): `corepack enable` once per machine

## Commands

Run all of these from `apps/web`.

| Command                             | What it does                                                          |
| ----------------------------------- | --------------------------------------------------------------------- |
| `pnpm install`                      | Install dependencies from `pnpm-lock.yaml`                            |
| `pnpm dev`                          | Development server with hot module replacement, http://localhost:5173 |
| `pnpm build`                        | Production build into `build/client` and `build/server`               |
| `pnpm start`                        | Serve the production build, http://localhost:3000                     |
| `pnpm typecheck`                    | Generate route types, then run `tsc`                                  |
| `pnpm lint`                         | ESLint, zero warnings allowed                                         |
| `pnpm format` / `pnpm format:check` | Prettier                                                              |
| `pnpm test`                         | Jest with React Testing Library                                       |

## Environment

`apps/web/.env.example` documents every variable this app knows about. Copy it to
`apps/web/.env` (git-ignored) and fill in what you need.

Two kinds of value live there, and they reach the app by different routes:

- **`VITE_`-prefixed values are public.** Vite reads them from `.env` and inlines
  them into the browser bundle at build time. Never put a secret behind a `VITE_`
  name.
- **Everything else is server-only** and is read from the process environment
  (`process.env`) by a `.server` module. Vite does not load `.env` into
  `process.env`, so in development you export these in your shell; in production
  the hosting platform supplies them.

Nothing in this app calls the Rails API yet, so the defaults in `.env.example`
are enough to run everything above.
````

Then, from the repository root:

```sh
git add apps/web
git commit -m "Feature 3: scaffold the React Router app at apps/web with pnpm and Tailwind"
```

`git status` before committing must show only files under `apps/web/`: no `node_modules`, `.react-router` or `build` directories.

### Step 5 — Try the template once (optional, `apps/web`)

```sh
pnpm dev
```

The template's welcome page appears at http://localhost:5173. Stop the server with Ctrl-C. Step 7 replaces that page.

### Step 6 — Set up Jest and write the specs first (`apps/web`)

D-042 and D-050 require the specs to be committed before the code they cover. Jest itself has to work first, though, and Jest is where a Vite project fights back. Here is why, before the files.

**Why Jest and Vite do not get along.** When you run `pnpm dev` or `pnpm build`, Vite does a lot of work that is easy to forget is happening:

1. it compiles TypeScript and JSX;
2. it resolves the `~/*` alias;
3. it lets you `import "./app.css"` or `import logo from "./logo.svg"`, even though Node cannot import either;
4. it replaces `import.meta.env.VITE_…` with literal values;
5. it works entirely in ES modules.

Jest uses none of that. It has its own module loader, runs test files as CommonJS unless you opt into its experimental ESM mode, and has never heard of `import.meta.env`. Each Vite behaviour your code relies on must therefore be recreated for Jest, or kept out of Jest's way. The configuration below does exactly that, one line per behaviour.

**What actually happens without each piece.** All four runs below were made on purpose against `app/config/public-config.test.ts`:

| Missing piece | Error you get |
|---|---|
| No transform at all (Jest defaults) | `Must use import to load ES Module: …/test/setup-jest.ts` — "The file contains ESM syntax (import/export) that could not be executed as CommonJS" |
| ts-jest, but with the app's own `tsconfig.json` | `TS1295: ECMAScript imports and exports cannot be written in a CommonJS file under 'verbatimModuleSyntax'` |
| The Jest tsconfig, but no stub for `client-env` | `TS1343: The 'import.meta' meta-property is only allowed when the '--module' option is 'es2020', 'es2022', 'esnext', …` |
| No `~/*` mapping | `Cannot find module '~/config/public-config' from 'app/config/public-config.test.ts'` |

Row 1 names the setup file, not the test, because Jest loads the `setupFilesAfterEnv` file (below) before any test file. Without a transform, that is the first TypeScript file Jest tries to run, so it is the first one that fails.

Two more failures show up on the component spec:

| Missing piece | Error you get |
|---|---|
| `testEnvironment` left at its default, `node` | `ReferenceError: document is not defined`, and Jest itself suggests "Consider using the "jsdom" test environment" |
| No jest-dom setup file | `TypeError: expect(...).toHaveTextContent is not a function` |

Now the files. First, declare Jest's global functions (`describe`, `it`, `expect`) for TypeScript, because `tsc` checks the test files too. In `tsconfig.json`, change one line:

```json
    "types": ["node", "vite/client", "jest"],
```

Today `tsc` would accept those globals even without this entry: `@testing-library/jest-dom`'s own type declarations reference `@types/jest`, which `tsc --explainFiles` shows. Listing `"jest"` makes the dependency explicit instead of relying on that side effect, which would break silently if jest-dom ever changed.

`jest.config.js`, the whole file:

```js
/**
 * Jest configuration.
 *
 * This project builds with Vite (through React Router's framework mode) but
 * tests with Jest (D-020). The two do not share a module pipeline, so every
 * Vite-specific behaviour the app relies on has to be reproduced here:
 *
 *  - Vite compiles TypeScript and JSX; Jest needs an explicit transform, so
 *    ts-jest compiles each test and each module it pulls in.
 *  - Vite resolves the `~/*` alias from tsconfig.json; Jest resolves modules
 *    itself, so the alias is repeated in moduleNameMapper.
 *  - Vite can import CSS and SVG files as modules; Node cannot, so those
 *    imports are mapped to inert stubs.
 *  - Vite replaces `import.meta.env` at build time. ts-jest compiles to
 *    CommonJS, and TypeScript refuses to compile `import.meta` for CommonJS
 *    (error TS1343), so the single module that reads it is mapped to a stub.
 *    Everything that interprets those values lives in plain modules that
 *    tests can call directly.
 *
 * @type {import('jest').Config}
 */
export default {
  testEnvironment: "jsdom",
  roots: ["<rootDir>/app"],
  setupFilesAfterEnv: ["<rootDir>/test/setup-jest.ts"],

  // Order matters: the first pattern that matches wins, so the specific
  // client-env mapping has to come before the general `~/*` alias.
  moduleNameMapper: {
    "^~/config/client-env$": "<rootDir>/test/stubs/client-env.ts",
    "^~/(.*)$": "<rootDir>/app/$1",
    // Needed since app/root.test.tsx: root.tsx imports app.css.
    "\\.css$": "<rootDir>/test/stubs/style.ts",
    // Not used by any test yet. It is ready for the first component that
    // imports an image (Phase 4).
    "\\.(svg|png|jpe?g|gif|webp|avif|ico)$": "<rootDir>/test/stubs/asset.ts",
  },

  transform: {
    "^.+\\.tsx?$": ["ts-jest", { tsconfig: "<rootDir>/tsconfig.jest.json" }],
  },
};
```

Line by line:

- **The file is `.js`, but it uses `export default`.** `package.json` says `"type": "module"`, so Node treats `.js` files as ES modules, and Jest 30 loads an ESM config file natively. A `jest.config.ts` would need `ts-node` installed as well, which is one more dependency for no gain.
- **`testEnvironment: "jsdom"`** gives every test a `document` and a `window`. It is a separate package, `jest-environment-jsdom`, since Jest 28.
- **`roots`** limits the search for test files to `app/`, so Jest never scans `build/` or `node_modules/`.
- **`setupFilesAfterEnv`** runs `test/setup-jest.ts` before each test file (see below).
- **`moduleNameMapper`** is Jest's version of Vite's resolver: a regular expression on the import path, mapped to a real file. The comment about order is not decoration: `~/config/client-env` also matches `^~/(.*)$`, so the more specific rule has to come first.
- **The CSS and image mappings** each carry a comment saying who needs them. The CSS one has been needed since the `ErrorBoundary` spec below, because `root.tsx` imports `app.css`; without it, Jest stops with `SyntaxError: Invalid or unexpected token` at `app/app.css`. No test imports an image yet. That mapping is kept for the first component that does (Phase 4), and its comment says exactly that.
- **`transform`** sends every `.ts` and `.tsx` file through ts-jest, which compiles it with the TypeScript compiler, type errors included. That is why the missing-module errors in the table above appear as `TS…` codes.

`tsconfig.jest.json`, the settings ts-jest uses:

```jsonc
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    // ts-jest hands Jest CommonJS, because Jest runs test files as CommonJS
    // unless it is put into its experimental ESM mode. ts-jest sets `module`
    // to CommonJS by itself outside that mode, so this file does not repeat
    // it. The one setting that has to change is verbatimModuleSyntax: the app
    // turns it on, and it forbids writing `import`/`export` in a file that is
    // emitted as CommonJS.
    "verbatimModuleSyntax": false
  }
}
```

It inherits everything else, including `strict`, `jsx` and the `~/*` paths, from the app's `tsconfig.json`, and overrides one setting: `verbatimModuleSyntax: false`. Remove that line and ts-jest fails with `TS1295`, the second row of the first table.

You might expect `"module": "CommonJS"` here as well, and the first version of this file had it. It did nothing. Outside Jest's ESM mode, ts-jest replaces `module` with CommonJS on its own (ts-jest 29.4.12, `fixupCompilerOptionsForModuleKind` in `dist/legacy/compiler/ts-compiler.js`). You can see that it still emits CommonJS without the line: remove the `client-env` mapping and `TS1343` appears, which happens only for a CommonJS emit. The first draft also overrode `moduleResolution` and `isolatedModules`. All three overrides were removed after testing showed they changed nothing.

The setup file and the three stubs:

```ts
// test/setup-jest.ts
// Adds the DOM-aware matchers (toBeInTheDocument, toHaveTextContent, ...) to
// Jest's global expect. Loaded once per test file through setupFilesAfterEnv.
import "@testing-library/jest-dom";
```

```ts
// test/stubs/style.ts
// Vite can import a stylesheet as a module; Node cannot. Jest maps every .css
// import to this file so that importing a component does not crash. The first
// test that needs it is app/root.test.tsx, because root.tsx imports app.css.
export default {};
```

```ts
// test/stubs/asset.ts
// Vite turns an image import into a URL string. Jest maps every image import to
// this file so components that render one still render something predictable.
// No test imports an image yet; this is ready for the first component that
// does (Phase 4).
export default "test-file-stub";
```

```ts
// test/stubs/client-env.ts
import type { ClientEnv } from "~/config/env-types";

/**
 * Stands in for app/config/client-env.ts inside Jest.
 *
 * The real module's only job is to hand over `import.meta.env`, which
 * TypeScript refuses to compile to CommonJS (TS1343). Configuration tests never
 * assert against this object: they call readPublicConfig() with an explicit
 * environment instead, which is exactly the testability D-020 asks for.
 *
 * DEV defaults to false, like a production build. A component test that needs
 * development behaviour switches it for one test with
 * `jest.replaceProperty(clientEnv, "DEV", true)`.
 */
export const clientEnv: ClientEnv = { DEV: false };
```

**Why a stub, and not a Babel plugin or Jest's ESM mode?** There are two other well-known routes. One is a Babel plugin that rewrites `import.meta.env`, which means adding Babel and a plugin. The other is running Jest in its experimental ESM mode (`node --experimental-vm-modules`), which is still labelled experimental. Both push the problem into tooling. The stub keeps it inside the app's own design instead: **one** module reads `import.meta.env`, and everything that interprets the values takes them as a parameter. D-020 asked for exactly that shape ("a config module that tests can mock"), and it costs one mapping line.

The types module the specs are written against, `app/config/env-types.ts`:

```ts
/**
 * The shapes of the two environments this app reads from. Keeping them in their
 * own module lets the server-only and client-visible configuration modules
 * share types without importing each other's code.
 */

/**
 * The values Vite inlines into the browser bundle. Vite only exposes project
 * variables whose names start with VITE_, plus a few built-in ones such as DEV,
 * which is the reason every value here is public by definition: it ends up in a
 * file anyone can download.
 */
export interface ClientEnv {
  /** Vite's built-in flag: true under `pnpm dev`, false in a production build. */
  DEV: boolean;
  VITE_PUBLIC_API_BASE_URL?: string;
}

/**
 * A process environment, as a server-only module sees it. `process.env` is
 * assignable to this type.
 */
export type ServerEnv = Record<string, string | undefined>;
```

And the four specs. `app/components/site-shell.test.tsx`:

```tsx
import { render, screen, within } from "@testing-library/react";

import { SiteShell } from "~/components/site-shell";

describe("SiteShell", () => {
  it("renders its heading as the page's level-one heading", () => {
    render(<SiteShell heading="Tintara Lab">Contenido</SiteShell>);

    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "Tintara Lab",
    );
  });

  it("renders its children inside the main landmark", () => {
    render(
      <SiteShell heading="Tintara Lab">
        <p>Contenido de prueba</p>
      </SiteShell>,
    );

    const main = screen.getByRole("main");

    expect(within(main).getByText("Contenido de prueba")).toBeInTheDocument();
  });
});
```

`getByRole` finds elements by their accessibility role, the way a screen reader does. A `<main>` element has the role `main`, and an `<h1>` has the role `heading` at level 1. `getByRole` throws if nothing matches, so each test fails loudly if the structure changes.

`app/config/public-config.test.ts`:

```ts
import {
  DEFAULT_PUBLIC_API_BASE_URL,
  readPublicConfig,
} from "~/config/public-config";

describe("readPublicConfig", () => {
  it("returns the configured public API base URL", () => {
    const config = readPublicConfig({
      VITE_PUBLIC_API_BASE_URL: "https://api.tintaralab.com",
    });

    expect(config.apiBaseUrl).toBe("https://api.tintaralab.com");
  });

  it("falls back to the development default when the variable is absent", () => {
    expect(readPublicConfig({}).apiBaseUrl).toBe(DEFAULT_PUBLIC_API_BASE_URL);
  });

  it("falls back to the development default when the variable is blank", () => {
    expect(
      readPublicConfig({ VITE_PUBLIC_API_BASE_URL: "   " }).apiBaseUrl,
    ).toBe(DEFAULT_PUBLIC_API_BASE_URL);
  });

  it("points the development default at the local Rails server", () => {
    expect(DEFAULT_PUBLIC_API_BASE_URL).toBe("http://localhost:3000");
  });
});
```

`app/config/server-config.test.ts`:

```ts
import type { ServerEnv } from "~/config/env-types";
import { readServerConfig } from "~/config/server-config.server";

const completeEnv: ServerEnv = {
  API_INTERNAL_URL: "http://localhost:3000",
  API_INTERNAL_TOKEN: "a-development-token",
};

describe("readServerConfig", () => {
  it("returns the server-only values it was given", () => {
    const config = readServerConfig(completeEnv);

    expect(config).toEqual({
      apiInternalUrl: "http://localhost:3000",
      apiInternalToken: "a-development-token",
    });
  });

  it.each(["API_INTERNAL_URL", "API_INTERNAL_TOKEN"])(
    "throws an error naming %s when it is missing",
    (variable) => {
      const env: ServerEnv = { ...completeEnv };
      delete env[variable];

      expect(() => readServerConfig(env)).toThrow(variable);
    },
  );

  it.each(["API_INTERNAL_URL", "API_INTERNAL_TOKEN"])(
    "treats a blank %s as missing",
    (variable) => {
      const env: ServerEnv = { ...completeEnv, [variable]: "   " };

      expect(() => readServerConfig(env)).toThrow(variable);
    },
  );

  it("names every missing variable in one error", () => {
    expect(() => readServerConfig({})).toThrow(
      /API_INTERNAL_URL.*API_INTERNAL_TOKEN/s,
    );
  });

  it("trims surrounding whitespace from the values it returns", () => {
    const config = readServerConfig({
      API_INTERNAL_URL: " http://x ",
      API_INTERNAL_TOKEN: "\ta-development-token\n",
    });

    expect(config).toEqual({
      apiInternalUrl: "http://x",
      apiInternalToken: "a-development-token",
    });
  });
});

describe("getServerConfig", () => {
  const originalEnv = process.env;

  beforeEach(() => {
    // A fresh copy of the module, so its cache starts empty in every test.
    jest.resetModules();
    process.env = {
      ...originalEnv,
      API_INTERNAL_URL: "http://first",
      API_INTERNAL_TOKEN: "first-token",
    };
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it("reads the process environment once and reuses the result", async () => {
    const { getServerConfig } = await import("~/config/server-config.server");

    const first = getServerConfig();
    process.env.API_INTERNAL_URL = "http://second";

    expect(getServerConfig()).toBe(first);
    expect(getServerConfig().apiInternalUrl).toBe("http://first");
  });
});
```

`it.each` runs the same test once per value, and `%s` in the title is replaced by that value. `toThrow("API_INTERNAL_URL")` passes when the error message *contains* that text. That is the check for "fails with a clear message naming the variable".

The last two tests pin down behaviour that is easy to break without noticing. The trimming test feeds values with surrounding whitespace, because the first test's clean values would still pass if the `.trim()` on the returned values were dropped. The `getServerConfig` test checks the cache: it reads the environment, changes `process.env`, and expects the same object back. `jest.resetModules()` makes the `await import(...)` load a fresh copy of the module in each test, so the cache always starts empty. This is the one test that has to replace `process.env`, and it restores the original in `afterEach`.

The fourth spec, `app/root.test.tsx`, covers the template's `ErrorBoundary`. It must show the error's message and stack trace in development and hide them otherwise:

```tsx
import { render, screen } from "@testing-library/react";

import { clientEnv } from "~/config/client-env";
import { ErrorBoundary } from "~/root";
import type { Route } from "./+types/root";

// react-router 8 ships only ES modules, and Jest runs tests as CommonJS, so the
// real package cannot be loaded here: Jest stops with "Must use import to load
// ES Module". This factory replaces it without ever loading it. ErrorBoundary
// uses only isRouteErrorResponse, copied from react-router 8.3.1
// (dist/production/lib/router/utils.js); the document components the other
// exports of root.tsx render are not needed by these tests.
jest.mock("react-router", () => ({
  isRouteErrorResponse: (error: unknown) => {
    const candidate = error as Record<string, unknown> | null | undefined;
    return (
      candidate != null &&
      typeof candidate.status === "number" &&
      typeof candidate.statusText === "string" &&
      typeof candidate.internal === "boolean" &&
      "data" in candidate
    );
  },
}));

// The boundary only reads `error`; the other props React Router passes are
// irrelevant to what it renders.
function renderBoundary(error: unknown) {
  const props = { error } as Route.ErrorBoundaryProps;
  render(<ErrorBoundary {...props} />);
}

function thrownError() {
  const error = new Error("Something broke");
  error.stack = "Error: Something broke\n    at the component that threw";
  return error;
}

describe("ErrorBoundary", () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it("shows the error message and stack trace in development", () => {
    jest.replaceProperty(clientEnv, "DEV", true);

    renderBoundary(thrownError());

    expect(screen.getByText("Something broke")).toBeInTheDocument();
    expect(screen.getByText(/at the component that threw/)).toBeInTheDocument();
  });

  it("hides the error message and stack trace outside development", () => {
    jest.replaceProperty(clientEnv, "DEV", false);

    renderBoundary(thrownError());

    expect(
      screen.getByText("An unexpected error occurred."),
    ).toBeInTheDocument();
    expect(screen.queryByText("Something broke")).not.toBeInTheDocument();
    expect(
      screen.queryByText(/at the component that threw/),
    ).not.toBeInTheDocument();
  });
});
```

Three things in it need explaining:

- **`jest.mock("react-router", factory)`.** `root.tsx` imports from `react-router`, and react-router 8 ships only ES modules, so Jest cannot load it (trap 15). `jest.mock` with a factory gives every import of `react-router` in this test file the factory's object instead, and the real package is never loaded. ts-jest moves the call above the imports, so it takes effect before `root.tsx` is loaded. The factory holds only what `ErrorBoundary` calls, `isRouteErrorResponse`, copied from react-router's source so it behaves the same way.
- **`jest.replaceProperty(clientEnv, "DEV", true)`.** `clientEnv` here is the Jest stub, the same object `root.tsx` receives, because both import `~/config/client-env`. `replaceProperty` swaps one property for one test, and `jest.restoreAllMocks()` in `afterEach` puts the stub's `false` back.
- **`{ error } as Route.ErrorBoundaryProps`.** React Router passes the boundary more props than `error`, but the boundary reads only `error`. The cast states that on purpose. The `Route` type comes from `react-router typegen`, which is why `pnpm test` runs typegen first (trap 16).

Run the suite. It must fail, and it must fail for the right reason:

```sh
pnpm test
```

```
$ react-router typegen && jest
FAIL app/config/server-config.test.ts
    app/config/server-config.test.ts:2:34 - error TS2307: Cannot find module '~/config/server-config.server' or its corresponding type declarations.
    app/config/server-config.test.ts:75:46 - error TS2307: Cannot find module '~/config/server-config.server' or its corresponding type declarations.
FAIL app/config/public-config.test.ts
    app/config/public-config.test.ts:4:8 - error TS2307: Cannot find module '~/config/public-config' or its corresponding type declarations.
FAIL app/root.test.tsx
    app/root.test.tsx:3:27 - error TS2307: Cannot find module '~/config/client-env' or its corresponding type declarations.
FAIL app/components/site-shell.test.tsx
    app/components/site-shell.test.tsx:3:27 - error TS2307: Cannot find module '~/components/site-shell' or its corresponding type declarations.
…
Test Suites: 4 failed, 4 total
```

Every suite fails because a module it imports does not exist yet. For `root.test.tsx` that module is `~/config/client-env`. ts-jest type-checks that import through `tsconfig.json`'s `~/*` path, not through Jest's mapping, so the stub alone does not satisfy it. None fails because of Jest configuration. That tells you the machinery works. (In the pull request, `client-env.ts` already existed when the `ErrorBoundary` spec was added, so there it failed with `TS1343` at `root.tsx:46`, the direct `import.meta.env.DEV` read. That is the right kind of failure too.) Commit from the repository root:

```sh
git add apps/web
git commit -m "Feature 3: add specs for the site shell and the environment configuration"
```

### Step 7 — Implement until the specs pass (`apps/web`)

**The component**, `app/components/site-shell.tsx`:

```tsx
import type { ReactNode } from "react";

interface SiteShellProps {
  /** Rendered as the page's only level-one heading. */
  heading: string;
  children: ReactNode;
}

/**
 * The outer frame of a page: one main landmark and one level-one heading.
 *
 * Deliberately unstyled beyond spacing. The palette, typography and layout of
 * the real site come from the mockups in a later feature, and guessing at them
 * here would mean writing code that has to be thrown away.
 */
export function SiteShell({ heading, children }: SiteShellProps) {
  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col gap-6 p-8">
      <h1 className="text-3xl font-semibold">{heading}</h1>
      {children}
    </main>
  );
}
```

The class names are the "one utility class proving Tailwind compiles"; step 8 checks that they reach the built CSS.

**The route**, `app/routes/home.tsx`, replacing the template's welcome page:

```tsx
import { SiteShell } from "~/components/site-shell";

export function meta() {
  return [{ title: "Tintara Lab" }];
}

export default function Home() {
  return (
    <SiteShell heading="Tintara Lab">
      <p>Sitio en construcción.</p>
    </SiteShell>
  );
}
```

`app/routes.ts` is unchanged from the template: `index("routes/home.tsx")` maps `/` to this file. Then remove the template's leftovers:

```sh
rm -r app/welcome
```

In `app/root.tsx`, delete the whole `export const links …` block, which loaded the Inter font from Google Fonts, and change `<html lang="en">` to `<html lang="es">`. Then make `ErrorBoundary` read the development flag through the config module instead of `import.meta.env`. Import it above the route types:

```tsx
import { clientEnv } from "~/config/client-env";
import type { Route } from "./+types/root";
import "./app.css";
```

and change the condition in `ErrorBoundary` from `import.meta.env.DEV && …` to:

```tsx
  } else if (clientEnv.DEV && error && error instanceof Error) {
```

Section 5 explains why. Replace `app/app.css` with:

```css
/* Tailwind CSS v4 needs no config file: this single import loads the engine and
   scans the project for utility classes. The palette, fonts and design tokens
   of the real site are a later feature; nothing is customised here yet. */
@import "tailwindcss";
```

Fonts and design tokens belong to the design feature, so the template's font choices are removed rather than kept by accident. `lang="es"` is the one piece of the SEO baseline (D-019) applied now, because leaving it as `en` would mean deliberately shipping wrong markup for a Spanish site (D-004).

**The configuration modules.** There are three, one per job.

`app/config/client-env.ts` is the only module in the app that reads `import.meta.env`, including Vite's built-in `DEV` flag that `ErrorBoundary` uses:

```ts
import type { ClientEnv } from "./env-types";

/**
 * The only module in this app that reads `import.meta.env`. (The type
 * declaration in app/vite-env.d.ts names it too, but reads nothing.)
 *
 * Vite replaces `import.meta.env.*` with literal values at build time, so
 * everything reachable from here is public. Isolating that read in one file has
 * two consequences that matter:
 *
 *  - No component ever reads an environment value directly (D-020); components
 *    such as root.tsx's ErrorBoundary import `clientEnv` instead, so tests can
 *    replace a value, and the logic that interprets these values can be
 *    unit-tested with plain objects.
 *  - Jest runs tests as CommonJS, and TypeScript will not compile
 *    `import.meta` to CommonJS, so Jest only has to replace this one module
 *    (see jest.config.js).
 */
export const clientEnv: ClientEnv = {
  // Each value is read by its full name: Vite replaces an expression such as
  // `import.meta.env.VITE_PUBLIC_API_BASE_URL` with a literal, and naming it
  // here keeps exactly that value, and nothing else, in the bundle. Reading
  // `import.meta.env` as a whole object would instead inline every VITE_
  // variable, including a wrongly prefixed secret that no code references.
  DEV: import.meta.env.DEV,
  VITE_PUBLIC_API_BASE_URL: import.meta.env.VITE_PUBLIC_API_BASE_URL,
};
```

`app/config/public-config.ts` interprets those values:

```ts
import { clientEnv } from "~/config/client-env";
import type { ClientEnv } from "./env-types";

/**
 * Where the browser reaches the Rails API in development. Production overrides
 * it with the API subdomain of D-039, supplied as VITE_PUBLIC_API_BASE_URL.
 */
export const DEFAULT_PUBLIC_API_BASE_URL = "http://localhost:3000";

export interface PublicConfig {
  /** Base URL the browser uses for its own API calls, with no trailing path. */
  apiBaseUrl: string;
}

/**
 * Interprets a client environment. Exported separately from `publicConfig` so
 * tests can pass an environment in rather than mutate a global one (D-020).
 *
 * A missing value is not an error here: this one is public and has a sensible
 * development default. Server-only values behave the opposite way; see
 * server-config.server.ts.
 *
 * It accepts only the variable it interprets, so a test does not have to invent
 * the rest of the client environment.
 */
export function readPublicConfig(
  env: Pick<ClientEnv, "VITE_PUBLIC_API_BASE_URL">,
): PublicConfig {
  const configured = env.VITE_PUBLIC_API_BASE_URL?.trim();

  return {
    apiBaseUrl:
      configured && configured.length > 0
        ? configured
        : DEFAULT_PUBLIC_API_BASE_URL,
  };
}

/** The configuration of the running app. Safe to import from any module. */
export const publicConfig = readPublicConfig(clientEnv);
```

`readPublicConfig` accepts `Pick<ClientEnv, "VITE_PUBLIC_API_BASE_URL">`, only the variable it reads. With the whole `ClientEnv`, every test would have to invent a `DEV` value that has nothing to do with the URL.

`app/config/server-config.server.ts` holds the server-only values. Section 5 walks through it; create it with the content shown there.

**Typing `import.meta.env`.** The first draft of `client-env.ts` assigned the whole object, `export const clientEnv: ClientEnv = import.meta.env;`, and `pnpm typecheck` rejected it:

```
app/config/client-env.ts(15,14): error TS2559: Type 'ImportMetaEnv' has no properties in common with type 'ClientEnv'.
```

Reading the variable by its full name, as in the version above, fixes that error, and it is also the form Vite replaces reliably at build time. It leaves a quieter problem, though. Vite's own `ImportMetaEnv` type (in `node_modules/vite/types/importMeta.d.ts`) lets any unknown name through as `any`, so a typo in the variable name would still type-check. Vite's documented fix is to declare the variables you use in a declaration file, which makes the value `string | undefined`. Create `app/vite-env.d.ts`:

```ts
/**
 * Declares the VITE_ variables this app reads, so `import.meta.env` is typed.
 * This is Vite's documented way to extend its ImportMetaEnv interface; the base
 * interface comes from the "vite/client" entry in tsconfig.json's `types`.
 * Keep it in step with ClientEnv in app/config/env-types.ts.
 */
interface ImportMetaEnv {
  readonly VITE_PUBLIC_API_BASE_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

`DEV` is not declared in this file: `vite/client` already types it as a `boolean`.

**The environment example**, `apps/web/.env.example`. It is committed and documents every variable:

```sh
# apps/web environment variables.
#
# Copy this file to apps/web/.env and adjust it. .env is git-ignored; this
# example file is the only one that is ever committed (CLAUDE.md, rule 4).
#
# Two kinds of value live here and they reach the app differently:
#
#   VITE_*   Read by Vite from this file and inlined into the browser bundle at
#            build time. Anyone who opens the site can read them. Never give a
#            secret a VITE_ prefix: API_INTERNAL_URL and API_INTERNAL_TOKEN
#            below must keep exactly those names.
#
#   everything else
#            Read from the process environment by a `.server` module, which the
#            build refuses to include in the browser bundle. Vite does NOT load
#            this file into process.env, so in development you export these in
#            your shell; in production the hosting platform supplies them.
#
# Nothing in this app calls the Rails API yet, so the app runs without setting
# any of them. The placeholders below are development values, never real ones.

# --- Public, inlined into the browser bundle ------------------------------

# Base URL the browser uses for its own calls to the Rails API, with no
# trailing slash and no path. Development mirrors production by calling Rails
# directly across origins with credentials (D-039); in production this becomes
# the API subdomain, for example https://api.tintaralab.com.
# Optional: defaults to http://localhost:3000.
VITE_PUBLIC_API_BASE_URL=http://localhost:3000

# --- Server-only, never sent to the browser -------------------------------

# Where server-side loaders call Rails when rendering the public page on the
# server (D-018, D-046). On a single host this can be an internal address that
# is not reachable from the internet.
# Required as soon as a loader calls the API.
API_INTERNAL_URL=http://localhost:3000

# Sent as the X-Internal-Token header on those server-side calls. Rails uses it
# to exempt its own site's rendering traffic from the public per-IP rate limit
# (D-045). It is a secret and it is rotatable; a leaked token only bypasses that
# rate limit and grants no admin access.
# Required as soon as a loader calls the API. Generate one with:
#   node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
API_INTERNAL_TOKEN=replace-me-with-a-random-value
```

In short:

| Variable | Kind | Default / placeholder | Used for |
|---|---|---|---|
| `VITE_PUBLIC_API_BASE_URL` | public, inlined into the bundle | `http://localhost:3000` (optional) | the browser's own calls to Rails (D-039) |
| `API_INTERNAL_URL` | server-only | `http://localhost:3000` | server-side loaders calling Rails (D-018, D-046) |
| `API_INTERNAL_TOKEN` | server-only, **secret** | `replace-me-with-a-random-value` | the `X-Internal-Token` header (D-045) |

The file also explains a point that trips people up: **Vite reads `.env` only for `VITE_` variables and does not put anything into `process.env`.** Server-only values come from the real process environment, which you export in your shell during development and which the hosting platform sets in production. Nothing reads them yet, so the app runs without a `.env` file at all.

Now everything passes:

```sh
pnpm test          # Test Suites: 4 passed, 4 total · Tests: 16 passed, 16 total
pnpm typecheck     # no output after "react-router typegen && tsc"
grep -rln 'import\.meta\.env' app
                   # app/config/client-env.ts
                   # app/vite-env.d.ts
```

The `grep` checks the `CLAUDE.md` §6 rule: only the config module reads `import.meta.env`. The declaration file names it but reads nothing.

Commit from the repository root: `git add apps/web && git commit -m "Feature 3: implement the site shell, the environment configuration and the home route"`.

### Step 8 — Prove the page is server-rendered (`apps/web`)

A page can look identical in the browser whether it was rendered on the server or by JavaScript afterwards. To tell them apart, look at the **first HTML response**, before any JavaScript runs. `curl` downloads it without running scripts:

```sh
pnpm build
PORT=3100 pnpm start &
sleep 2                    # give the server a moment to start listening
curl -s http://localhost:3100/ | grep -oE '<html lang="es"|<title>[^<]*</title>|<h1[^>]*>[^<]*</h1>|<p>Sitio[^<]*</p>'
```

```
<html lang="es"
<title>Tintara Lab</title>
<h1 class="text-3xl font-semibold">Tintara Lab</h1>
<p>Sitio en construcción.</p>
```

The heading and the paragraph are in the raw HTML. A single-page app would return an almost empty `<body>` here, with the content arriving later from JavaScript. That is what a search engine crawler or a WhatsApp link preview would see, and it is why D-018 chose server rendering.

- **Why `PORT=3100`:** `react-router-serve` prefers port 3000, and if 3000 is taken (for example by `bin/rails server` from chapter 02) it silently picks a **random** free port and prints it. Setting `PORT` makes the port predictable. The server prints `[react-router-serve] http://localhost:3100`.
- Check that Tailwind emitted the classes the component uses: `grep -oE '\.max-w-3xl|\.text-3xl|\.font-semibold' build/client/assets/*.css | sort -u` prints all three.
- Stop the server afterwards with `kill %1`, or `pkill -f react-router-serve`.

### Step 9 — Prove the server/client boundary, rather than trusting it (`apps/web`)

**How the boundary works.** In framework mode, a route file is used twice. The server build imports all of it. The client build imports it too, but first React Router's Vite plugin **removes the server-only exports**: `loader`, `action`, `middleware` and `headers`. Then any import used only by those exports is removed as well. On top of that, any file whose name contains `.server` (or any directory named `.server`) is **forbidden** in the client module graph: if one is still reachable after the removal, the build stops with an error. That is why the file is named `server-config.server.ts`. The name makes "never import this from browser code" a rule the build checks, not a rule people have to remember. React Router documents this under "`.server` modules".

**Verify it in three ways.**

1. *Nothing server-only reached the browser files:*

   ```sh
   grep -rlE 'API_INTERNAL|readServerConfig' build/client || echo "none found in build/client"
   ```

   This prints `none found in build/client`.

2. *A client import breaks the build.* Temporarily edit `app/routes/home.tsx` so the **component** uses the server module:

   ```tsx
   import { SiteShell } from "~/components/site-shell";
   import { getServerConfig } from "~/config/server-config.server";

   export function meta() {
     return [{ title: "Tintara Lab" }];
   }

   export default function Home() {
     return (
       <SiteShell heading="Tintara Lab">
         <p>{getServerConfig().apiInternalToken}</p>
       </SiteShell>
     );
   }
   ```

   `pnpm build` then fails:

   ```
   [plugin react-router:dot-server]
   Error: Server-only module referenced by client

       '~/config/server-config.server' imported by route 'app/routes/home.tsx'

     React Router automatically removes server-code from these exports:
       `loader`, `action`, `middleware`, `headers`

     But other route exports in 'app/routes/home.tsx' depend on '~/config/server-config.server'.
   ```

3. *A loader import is allowed and stays on the server.* Change the same file so that only a `loader` uses it:

   ```tsx
   import { SiteShell } from "~/components/site-shell";
   import { getServerConfig } from "~/config/server-config.server";

   export function loader() {
     return { hasToken: getServerConfig().apiInternalToken.length > 0 };
   }

   export default function Home() {
     return (
       <SiteShell heading="Tintara Lab">
         <p>Sitio en construcción.</p>
       </SiteShell>
     );
   }
   ```

   `pnpm build` succeeds. `grep -rlE 'API_INTERNAL|getServerConfig' build/client` finds nothing, and `grep -l API_INTERNAL_TOKEN build/server/index.js` finds the server build. The code exists on exactly one side.

Afterwards, **restore `home.tsx`** to the step 7 version (`git checkout app/routes/home.tsx`) and run `pnpm build` again. The committed route does not use the server module at all, because nothing calls the API yet.

### Step 10 — ESLint and Prettier (`apps/web`)

```sh
pnpm add -D --save-exact @eslint/js@10.0.1
```

`@eslint/js` holds ESLint's own recommended rules. ESLint 10 no longer bundles them. `eslint.config.js`:

```js
// ESLint flat configuration (the only format ESLint 10 reads).
//
// Layers, applied in order:
//  1. @eslint/js recommended: core JavaScript mistakes.
//  2. typescript-eslint recommended: TypeScript-aware versions of those rules,
//     and it switches off core rules that TypeScript already enforces.
//  3. react-hooks recommended: the Rules of Hooks, which no type checker catches.
//  4. eslint-config-prettier, last: turns off every rule that only concerns
//     formatting, so ESLint and Prettier can never disagree. Formatting is
//     Prettier's job alone (`pnpm format:check`).
import js from "@eslint/js";
import prettier from "eslint-config-prettier";
import reactHooks from "eslint-plugin-react-hooks";
import { defineConfig, globalIgnores } from "eslint/config";
import tseslint from "typescript-eslint";

export default defineConfig([
  // Generated or installed output, never linted.
  globalIgnores(["build/", ".react-router/", "coverage/", "node_modules/"]),

  js.configs.recommended,
  tseslint.configs.recommended,
  reactHooks.configs.flat.recommended,
  prettier,
]);
```

- **"Flat config"** is ESLint's configuration format: one JavaScript file exporting an array of layers, where later layers override earlier ones. That is why `prettier` must come last.
- **`reactHooks.configs.flat.recommended`**: the plugin exports both old-style and flat configs. The flat one sits under `configs.flat`, which was confirmed by printing `Object.keys(hooks.configs)` from the installed package, not guessed.
- **No `eslint-plugin-react`.** Its main value was rules for the old JSX transform; with the automatic JSX runtime (`"jsx": "react-jsx"`), TypeScript and the hooks plugin cover what matters here.

Prettier needs two small files: `.prettierrc.json`, containing `{}` (Prettier's defaults, which the template's code already follows), and `.prettierignore`:

```
# Generated or installed output
build/
.react-router/
coverage/
node_modules/

# Written by pnpm; reformatting it would only create churn
pnpm-lock.yaml
```

Run them:

```sh
pnpm format        # rewrites any file Prettier would format differently
pnpm format:check  # All matched files use Prettier code style!
pnpm lint          # no output after "eslint . --max-warnings=0"
```

`--max-warnings=0` turns every warning into a failure, which is how "zero warnings" becomes something CI can enforce. **An empty lint output proves nothing on its own.** Check that ESLint actually lints your files: `pnpm exec eslint . --format json` lists 20 files. Then plant a mistake, for example an unused `const` in a new file under `app/`, and watch `pnpm lint` report `'unused' is assigned a value but never used  @typescript-eslint/no-unused-vars`. Delete the file afterwards.

Commit: `git add apps/web && git commit -m "Feature 3: add ESLint and Prettier"`.

### Step 11 — The CI workflow, and the trigger rule (repository root)

Create `.github/workflows/web.yml`, the whole file:

```yaml
name: Web

# D-065: pull requests run this workflow unconditionally, so every required
# check always reports a status. A path-filtered workflow that does not run
# reports nothing at all, and a required check with no status blocks the PR
# forever. Pushes to main keep the path filter: a merged API or docs change
# does not need the web suite re-run.
on:
  push:
    branches: [ main ]
    paths:
      - "apps/web/**"
      - ".github/workflows/web.yml"
  pull_request:
    branches: [ main ]

# Least privilege for the job token: no job writes anything back to the
# repository, and this repository is readable by everyone (D-059, D-066).
permissions:
  contents: read

defaults:
  run:
    working-directory: apps/web

# Every job repeats the same five setup steps on purpose, like api.yml does:
# jobs run on separate machines, and GitHub reports each one as its own check.
jobs:
  lint:
    name: Web ESLint
    runs-on: ubuntu-latest
    steps:
      - name: Check out the repository
        uses: actions/checkout@v7

      # The Node version comes from apps/web/.node-version, the same file
      # developers use locally.
      - name: Set up Node
        uses: actions/setup-node@v7
        with:
          node-version-file: apps/web/.node-version

      # corepack reads packageManager from package.json and provides exactly
      # that pnpm version (D-021). It must run after setup-node, so the shim
      # lands in the Node installation that is actually on PATH.
      - name: Enable pnpm through corepack
        run: corepack enable

      - name: Locate the pnpm store
        id: pnpm-store
        run: echo "path=$(pnpm store path --silent)" >> "$GITHUB_OUTPUT"

      - name: Cache the pnpm store
        uses: actions/cache@v6
        with:
          path: ${{ steps.pnpm-store.outputs.path }}
          key: pnpm-store-${{ runner.os }}-${{ hashFiles('apps/web/pnpm-lock.yaml') }}
          restore-keys: pnpm-store-${{ runner.os }}-

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Lint
        run: pnpm lint

      - name: Check formatting
        run: pnpm format:check

  typecheck:
    name: Web TypeScript
    runs-on: ubuntu-latest
    steps:
      - name: Check out the repository
        uses: actions/checkout@v7

      - name: Set up Node
        uses: actions/setup-node@v7
        with:
          node-version-file: apps/web/.node-version

      - name: Enable pnpm through corepack
        run: corepack enable

      - name: Locate the pnpm store
        id: pnpm-store
        run: echo "path=$(pnpm store path --silent)" >> "$GITHUB_OUTPUT"

      - name: Cache the pnpm store
        uses: actions/cache@v6
        with:
          path: ${{ steps.pnpm-store.outputs.path }}
          key: pnpm-store-${{ runner.os }}-${{ hashFiles('apps/web/pnpm-lock.yaml') }}
          restore-keys: pnpm-store-${{ runner.os }}-

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Type-check
        run: pnpm typecheck

  test:
    name: Web Jest
    runs-on: ubuntu-latest
    steps:
      - name: Check out the repository
        uses: actions/checkout@v7

      - name: Set up Node
        uses: actions/setup-node@v7
        with:
          node-version-file: apps/web/.node-version

      - name: Enable pnpm through corepack
        run: corepack enable

      - name: Locate the pnpm store
        id: pnpm-store
        run: echo "path=$(pnpm store path --silent)" >> "$GITHUB_OUTPUT"

      - name: Cache the pnpm store
        uses: actions/cache@v6
        with:
          path: ${{ steps.pnpm-store.outputs.path }}
          key: pnpm-store-${{ runner.os }}-${{ hashFiles('apps/web/pnpm-lock.yaml') }}
          restore-keys: pnpm-store-${{ runner.os }}-

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Run the tests
        run: pnpm test

  # Not in D-033's list, and added on purpose: the rule that keeps server-only
  # modules out of the browser bundle (D-039, D-045) is enforced by the build,
  # and by nothing else. Without this job, a PR that breaks it would pass CI.
  build:
    name: Web Build
    runs-on: ubuntu-latest
    steps:
      - name: Check out the repository
        uses: actions/checkout@v7

      - name: Set up Node
        uses: actions/setup-node@v7
        with:
          node-version-file: apps/web/.node-version

      - name: Enable pnpm through corepack
        run: corepack enable

      - name: Locate the pnpm store
        id: pnpm-store
        run: echo "path=$(pnpm store path --silent)" >> "$GITHUB_OUTPUT"

      - name: Cache the pnpm store
        uses: actions/cache@v6
        with:
          path: ${{ steps.pnpm-store.outputs.path }}
          key: pnpm-store-${{ runner.os }}-${{ hashFiles('apps/web/pnpm-lock.yaml') }}
          restore-keys: pnpm-store-${{ runner.os }}-

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build for production
        run: pnpm build
```

The four jobs repeat the same setup steps and differ only in their id, their `name:` and their last steps:

| Job id | Check name | Last steps |
|---|---|---|
| `lint` | `Web ESLint` | `pnpm lint`, then `pnpm format:check` |
| `typecheck` | `Web TypeScript` | `pnpm typecheck` |
| `test` | `Web Jest` | `pnpm test` |
| `build` | `Web Build` | `pnpm build` |

**Why every check name starts with `Web` (D-071).** GitHub reports each job's `name:` as a check, and a required check (step 14 and section 9) is matched by that name within the GitHub Actions app. A generic name like `Build` would be satisfied by *any* job of *any* workflow in this repository called `Build`, for example a future deploy workflow's, even if the web build never ran. The app prefix makes every name unique. The first version of this workflow used bare names; they were renamed before becoming required, because renaming a required check later means changing the branch protection at the same moment.

The `build` job's comment says why it exists: it is not in D-033's list, and it was added on purpose, because the build is **the only thing** that enforces the `.server` boundary from step 9. Without the job, a PR that leaks the token into client code would pass CI.

What the setup steps do:

- **`actions/setup-node@v7` with `node-version-file`** installs the Node version from `.node-version`, so CI and your machine cannot drift apart.
- **`corepack enable` after setup-node.** corepack creates the `pnpm` shim next to the `node` that is currently on `PATH`. Running it after setup-node puts the shim in the Node installation the rest of the job uses.
- **Caching the pnpm store explicitly.** setup-node has a built-in `cache: pnpm` option, but it needs `pnpm` to exist *before* setup-node runs, and with corepack it does not exist yet. So the workflow asks pnpm where its store is (`pnpm store path`) and caches that directory with `actions/cache@v6`. The key is derived from the lockfile's hash: a new lockfile means a new cache, and `restore-keys` still lets it start from the most recent older one. The first run logs `Cache not found`, and later runs restore it.
- **`pnpm install --frozen-lockfile`** fails instead of silently updating the lockfile if it does not match `package.json`. It is the pnpm equivalent of `bundle install` with a frozen Gemfile.lock.
- **Pinned versions.** Each action's latest release was read from its own repository with `gh api repos/<owner>/<repo>/releases/latest`: `actions/checkout` v7.0.1, `actions/setup-node` v7.0.0, `actions/cache` v6.1.0. The workflow pins the major version (`@v7`, `@v6`), which moves only within that major, as `api.yml` already does.

**The trigger rule (D-065), and the failure it prevents.** Chapter 02's `api.yml` filtered *both* triggers by path. Consider what happens once `RuboCop` and `RSpec` are **required checks** on `main`, meaning GitHub refuses to merge a PR until they pass:

1. Open a PR that only touches `apps/web/**`.
2. `api.yml`'s path filter does not match, so the workflow never starts.
3. A workflow that never starts reports **no status at all**. That is not a pass, and not a skip either.
4. GitHub waits for the required `RuboCop` and `RSpec` statuses, which never arrive. The PR shows "Expected — Waiting for status to be reported" forever and cannot be merged.

The fix: `pull_request` has **no** path filter, so both workflows run on every PR and every required check always reports. `push` to `main` keeps the filter, because after a merge nothing is gating and re-running an unaffected suite is wasted time. Apply the same change to `api.yml`: delete the three `paths:` lines under `pull_request:`, and add this comment above `on:`. Only its last sentence differs from `web.yml`'s:

```yaml
# D-065: pull requests run this workflow unconditionally, so every required
# check always reports a status. A path-filtered workflow that does not run
# reports nothing at all, and a required check with no status blocks the PR
# forever. Pushes to main keep the path filter: a merged web or docs change
# does not need the API suite re-run.
```

Its `push:` block stays as it was. In the same file, rename the two jobs, as D-071 requires: `name: RuboCop` becomes `name: API RuboCop`, and `name: RSpec` becomes `name: API RSpec`. The job ids, `lint` and `test`, stay as they are.

Commit: `git add .github/workflows && git commit -m "Feature 3: add the web workflow and apply D-065 to api.yml"`.

### Step 12 — Fix two root `.gitignore` rules (repository root)

Replace the last section of the root `.gitignore` (it was `# Temporary files` followed by `tmp/`) with:

```gitignore
# Temporary files at the repository root only. Each app's own .gitignore
# governs its own tmp/ (apps/api tracks tmp/.keep, for example).
/tmp/

# Private keys, at any depth. apps/api/.gitignore also ignores
# /config/*.key; the duplication is deliberate. An ignore rule only protects you
# while the file that declares it is on the branch you have checked out, and
# this one is on every branch cut from main.
*.key
```

- **`tmp/` → `/tmp/`.** In a `.gitignore`, a pattern without a leading slash matches at **any depth**, so `tmp/` also swallowed `apps/api/tmp/`. That includes the empty `.keep` placeholder files Rails deliberately un-ignores, so the directories exist in a fresh clone. A leading `/` anchors the pattern to the directory of the `.gitignore` that declares it, here the repository root. Chapter 02's trap 3 predicted this.
- **After the change**, `git status --porcelain --untracked-files=all` shows two newly trackable files: `?? apps/api/tmp/.keep` and `?? apps/api/tmp/pids/.keep`. Both are empty and both are exactly what Rails' own `apps/api/.gitignore` intends to keep (`!/tmp/.keep`, `!/tmp/pids/.keep`), so commit them.
- **`*.key` at the root.** `apps/api/.gitignore` already ignores `/config/*.key`, but only on branches where that file exists. Before PR #1 merged, `main` had no `apps/api/.gitignore`, so a `master.key` lying in the working tree while `main` was checked out was one `git add -A` away from being committed. A root rule is present on every branch.

Verify:

```sh
git check-ignore -v apps/api/config/master.key
# apps/api/.gitignore:25:/config/*.key	apps/api/config/master.key
git check-ignore -v apps/web/anything.key
# .gitignore:31:*.key	apps/web/anything.key
```

The first line names the **app's** rule, not the root one, and that is correct: when several `.gitignore` files match, git reports the one closest to the file. To see the root rule protecting `master.key` on its own, move the app's file aside for a moment:

```sh
mv apps/api/.gitignore /tmp/api.gitignore
git check-ignore -v apps/api/config/master.key   # .gitignore:31:*.key	apps/api/config/master.key
mv /tmp/api.gitignore apps/api/.gitignore
git status --porcelain apps/api/.gitignore       # empty: restored
```

Commit:

```sh
git add .gitignore apps/api/tmp/.keep apps/api/tmp/pids/.keep
git commit -m "Feature 3: narrow the root tmp rule and ignore key files repository-wide"
```

### Step 13 — Record the commands in `CLAUDE.md` (repository root)

Replace the `- **Web:** _defined by Feature 3_` line in section 7 with the real commands, and leave the Postgres and API lines untouched:

```markdown
- **Web** (from `apps/web`, after `corepack enable` once per machine; Node from `apps/web/.node-version`): install `pnpm install` · dev server `pnpm dev` (http://localhost:5173) · specs `pnpm test` · lint `pnpm lint` and `pnpm format:check` · typecheck `pnpm typecheck` · build `pnpm build` · serve the build `pnpm start` (port 3000, or a random free port if 3000 is taken; it prints the URL; `PORT=<port> pnpm start` fixes it). Variables are documented in `apps/web/.env.example`; nothing requires them yet.
```

Commit it as `Feature 3: fill in the Web line of CLAUDE.md section 7`.

### Step 14 — Push and open the pull request (repository root)

```sh
git push -u origin feature/3-web-skeleton
gh pr create --base main --head feature/3-web-skeleton \
  --title "Feature 3: create the React Router web skeleton with Jest, ESLint and CI"
```

`gh` asks for a body; the project's PR template lists what goes in it. Then watch the checks:

```sh
gh pr checks 2
```

There are six checks: `API RuboCop` and `API RSpec` from `api.yml`, which **run on this PR even though it barely touches `apps/api`** (that is D-065 working), plus `Web ESLint`, `Web TypeScript`, `Web Jest` and `Web Build` from `web.yml`. All six pass. Do not merge; the owner does that.

## 5. The important files, explained

### `app/config/server-config.server.ts`

```ts
import type { ServerEnv } from "./env-types";

/**
 * Server-only configuration.
 *
 * The `.server` in this file name is not decoration: React Router's Vite plugin
 * fails the build if anything in the client module graph reaches a `.server`
 * file. That turns "do not leak the internal token to the browser" from a rule
 * people have to remember into a rule the build enforces (D-039, D-045).
 *
 * Nothing calls the API yet, so no module imports this one at runtime. The
 * guarantee is verified in `handoff/learning/03-web-skeleton.md`, which shows
 * the build failing when a client module imports it on purpose.
 */

export interface ServerConfig {
  /** Where server-side loaders call Rails (D-018, D-046). */
  apiInternalUrl: string;
  /** The X-Internal-Token value that exempts SSR calls from the public
   *  per-IP rate limit (D-045). A secret: never expose it to the browser. */
  apiInternalToken: string;
}

const REQUIRED_VARIABLES = ["API_INTERNAL_URL", "API_INTERNAL_TOKEN"] as const;

/**
 * Reads and validates the server-only environment.
 *
 * Every required variable must be present and non-blank. A missing one throws
 * immediately and names every variable that is missing, because the alternative
 * — an undefined value travelling into a fetch call — surfaces much later as an
 * unrelated error. `env` is a parameter so tests never have to mutate
 * `process.env`.
 */
export function readServerConfig(env: ServerEnv = process.env): ServerConfig {
  const missing = REQUIRED_VARIABLES.filter(
    (name) => (env[name] ?? "").trim().length === 0,
  );

  if (missing.length > 0) {
    throw new Error(
      `Missing required server environment ${
        missing.length === 1 ? "variable" : "variables"
      }: ${missing.join(", ")}. ` +
        `See apps/web/.env.example. These values are server-only and must never ` +
        `be given a VITE_ prefix.`,
    );
  }

  return {
    apiInternalUrl: (env.API_INTERNAL_URL as string).trim(),
    apiInternalToken: (env.API_INTERNAL_TOKEN as string).trim(),
  };
}

let cached: ServerConfig | undefined;

/**
 * The configuration of the running server, read once.
 *
 * Deliberately a function rather than a module-level constant: a constant would
 * be evaluated when the module is first imported, which would make the server
 * refuse to start — and `pnpm test` refuse to import this file — in every
 * environment that has not set the variables yet.
 */
export function getServerConfig(): ServerConfig {
  cached ??= readServerConfig();
  return cached;
}
```

- **`env: ServerEnv = process.env`.** The default value is the real environment; tests pass a plain object instead. This is what "a config module tests can use" means in practice.
- **`as const`** makes the array's type the two literal names rather than `string[]`, so a typo in either name elsewhere is a type error.
- **Collecting every missing name before throwing** saves the fix-one-restart-find-the-next loop. The message points to `.env.example` and warns against the most likely wrong fix: making the variable "work" by renaming it `VITE_…`, which would publish the token.
- **The `as string` casts** are safe only because the check above has just proven both values are non-blank. TypeScript cannot follow that proof through the `filter`.
- **`getServerConfig()` is lazy.** A module-level `export const serverConfig = readServerConfig()` looks tidier, but it would throw the moment any file imports the module. That includes the test file, and the production server at startup whenever the variables are not set, which is every environment today.
- **Why not a loader right now.** A loader that calls `getServerConfig()` would make `/` fail with a 500 on any machine without the variables, and the task forbids loaders that fetch data. Step 9 shows both sides of the boundary without committing either experiment.

### `app/root.tsx` (the parts that matter)

`Layout` renders the whole HTML document, `<html lang="es">`, `<head>` and `<body>`, on the server for every request. `<Meta />` and `<Links />` output each route's `meta()` and `links()` results, which is how `<title>Tintara Lab</title>` from `home.tsx` reached the HTML in step 8. `<Scripts />` adds the client bundle that hydrates the page. `ErrorBoundary` is the template's error page. Its text is still the template's English; a later feature translates it. One line changed. The template read `import.meta.env.DEV` directly, which broke the project rule that components read environment values only through the config module (`CLAUDE.md` §6). It also made `root.tsx` impossible to import in a test, because of `TS1343`. Now `DEV` travels like any other value: `ClientEnv` declares it, `client-env.ts` reads it by its full name, the Jest stub sets it to `false`, and `root.test.tsx` switches it with `jest.replaceProperty`.

### `tsconfig.json` (what changed and what was already right)

The template already had `"strict": true`, the `~/*` path, and `.server`/`.client` directories in `include`. The only change is `"jest"` in `types`. It makes the test files' dependency on Jest's global `describe`, `it` and `expect` explicit. `tsc` does not need it today, because jest-dom's types already pull in `@types/jest` (step 6), but that is a side effect nobody chose. The cost is that those names also type-check in application code, where they do not exist at runtime. The alternative was a second tsconfig just for tests plus a second `tsc` run, which is more moving parts for a small project.

### `.github/workflows/api.yml` (what changed)

The trigger block: the comment above `on:` was added, and the three `paths:` lines under `pull_request:` were removed. And the two job names: `RuboCop` became `API RuboCop` and `RSpec` became `API RSpec` (D-071). `permissions: contents: read` was already there from Feature 2's fix round (D-066).

## 6. Decisions behind this chapter

| Decision | What we chose | What we rejected | Why |
|---|---|---|---|
| D-018 | React Router framework mode, `ssr: true`, for the public page | Plain SPA; Next.js | Crawlers and link previews get real HTML; Next.js server components fight Jest |
| D-020 | Jest + RTL + jsdom, with one stubbed `client-env` module and a `jest.mock` stand-in for the ESM-only react-router | Vitest; Babel plugin for `import.meta`; Jest's experimental ESM mode | Owner's firm choice; the stub keeps the fix inside the app's design instead of more tooling |
| D-021 | pnpm 12.4.2 through corepack, pinned with its hash | Global pnpm install | One version per project, verified by hash |
| D-055 | Exact versions; react-router 8.3.1, TypeScript 5.9.3 | Newest-of-everything (8.4.0, TS 7.0.2) | 8.4.0 was under pnpm's 24-hour release-age rule; TS 7 is outside typescript-eslint's and ts-jest's supported ranges |
| D-005 | Tailwind 4 via `@tailwindcss/vite`, no customisation | Material UI; adding tokens now | Design is a later feature |
| D-039, D-045 | `.server` module for `API_INTERNAL_*`, `VITE_` for the public URL | A naming convention alone | The build enforces the boundary |
| D-033 + this chapter | ESLint (+ Prettier check), TypeScript, Jest **and Build** jobs | Lint/typecheck/test only | Only the build checks the `.server` boundary |
| D-065 | No path filter on `pull_request`; filter kept on `push` | "Skip" companion jobs; not requiring checks | Required checks always report; simplest correct setup |
| D-066 | `permissions: contents: read` | Default token permissions | No job writes anything |
| D-071 | App-prefixed check names (`Web Build`, `API RSpec`, …) | Bare job names (`Build`, `RSpec`) | A required check is matched by name; a generic name could be satisfied by an unrelated job |
| — | Dockerfile removed | Keeping the template's | It assumed npm and could not build; hosting is deferred (D-036) |
| D-019 (partial) | `lang="es"` only | Template's `lang="en"`; full SEO now | Correct language is not optional; the rest of the SEO baseline is a later feature |

## 7. Traps, mistakes and things we avoided

1. **`^8` silently resolved to 8.3.1, not the 8.4.0 that `npm view` reported.** It looked like a stale cache. It was pnpm 12's `minimumReleaseAge` rule skipping a version published hours earlier. Reading the install output, and not just the version you expected, is what reveals this.
2. **Pinning the too-new version exactly made pnpm quietly exempt it.** Writing `"react-router": "8.4.0"` did not fail at first. pnpm added `minimumReleaseAgeExclude` entries for 8.4.0 and `@types/node` 24.13.5 to `pnpm-workspace.yaml`, which switches off the supply-chain check for exactly those packages. After those lines were deleted and the pins moved back, the next install failed with "The lockfile contains entries that the active policies reject". The fix was `pnpm clean --lockfile` followed by `pnpm install`. If you ever see `minimumReleaseAgeExclude` in a diff, ask why it is there.
3. **pnpm 12 does not read settings from `package.json`.** A `"pnpm": { "onlyBuiltDependencies": [] }` field was tried first, and it did nothing. CI later printed `[WARN] The "pnpm" field in package.json is no longer read by pnpm`. Settings live in `pnpm-workspace.yaml`, even in a single-package project, and the build-script setting is now called `allowBuilds`.
4. **`ERR_PNPM_IGNORED_BUILDS` fails the install.** pnpm 12 treats an undecided build script as an error. Decide explicitly, `true` or `false`, per package. The placeholder pnpm writes, `set this to true or false`, is not a valid answer.
5. **Rewriting `package.json` by hand dropped corepack's integrity hash.** `corepack use` writes `pnpm@12.4.2+sha512.…`; the first hand-written file had only `pnpm@12.4.2`. Both work, but the hash is what lets corepack reject a tampered download, so it was restored.
6. **TypeScript 7 is "latest" and still wrong here.** Always read the peer ranges of your lint and test tooling (`npm view typescript-eslint peerDependencies`) before upgrading the compiler.
7. **The Jest wall.** See the two tables in step 6. The most confusing error is `TS1295` under `verbatimModuleSyntax`: it looks like a problem in your code, but it comes from compiling ES-module source to CommonJS for Jest. The fix is a Jest-only tsconfig, not a change to the app's settings.
8. **`import.meta.env` is loosely typed by default.** Assigning the whole `import.meta.env` object to your own interface fails with `TS2559 … has no properties in common`. Reading a variable by its full name compiles, but as `any`, so a misspelled name compiles too. Read each variable by its full name *and* declare it in `app/vite-env.d.ts`. Reading by full name also matters for safety. Code that reads `import.meta.env` as a whole object, for example `JSON.stringify(import.meta.env)`, makes Vite inline **every** `VITE_` variable into the bundle, including a wrongly prefixed secret that no code references. QA proved it with a throwaway `VITE_API_INTERNAL_TOKEN`.
9. **Vite does not load `.env` into `process.env`.** Only `VITE_` names are read, and only into `import.meta.env`. Server-only values must come from the real process environment. It is easy to believe the opposite because `pnpm dev` "reads .env".
10. **A server module imported by nothing proves nothing.** `pnpm build` passing with an unused `.server` file shows only that nothing imports it. The negative experiment in step 9 is what shows the guard works.
11. **`react-router-serve` changes port silently.** With Rails on 3000, it picks a random free port. Set `PORT`.
12. **`git check-ignore -v` reports the nearest rule, not every rule.** Seeing the app-level rule for `master.key` does not mean the root rule is missing. Test the root rule on its own (step 12).
13. **Narrowing `tmp/` made two files appear, not one.** `apps/api/tmp/pids/.keep` became trackable too, because Rails un-ignores it the same way as `tmp/.keep`.
14. **An empty lint run is not proof.** Confirm that the files are linted and that a planted error is caught (step 10).
15. **An ESM-only dependency stops Jest.** react-router 8 ships only ES modules (`"type": "module"` and no `require` entry in its `exports`). The first time a test imported `root.tsx`, Jest stopped with `Must use import to load ES Module: …/react-router/dist/production/index.js`. Jest's message offers three ways out, and none is small:
    - Running Node with `--experimental-vm-modules` got past that error and straight into the next, `ReferenceError: TextEncoder is not defined` inside react-router, under an "experimental feature" warning.
    - Letting Jest transform `node_modules` would mean compiling react-router's JavaScript too, with ts-jest or an added Babel.
    - The option the error does not mention is the one used: the test replaces the package with `jest.mock` (step 6). That works while a test needs one small, pure function from react-router. Phase 4's route tests will need more of it (`Link`, `useLoaderData`), so the project has to choose how Jest loads react-router before then. The Feature 3 report raises that question.
16. **Type-only imports still need their files under ts-jest.** `import type { Route } from "./+types/root"` disappears from the compiled JavaScript, but ts-jest type-checks first. On a fresh checkout, where `react-router typegen` has never run, the suite fails with `TS2307: Cannot find module './+types/root'`. On a machine that ran `pnpm typecheck` or `pnpm dev` before, `.react-router/` already exists and the suite passes, so the failure would have appeared only in CI. That is why `pnpm test` runs typegen first.
17. **Reading a flag through an object costs dead-code removal.** In the template, `import.meta.env.DEV` became the literal `false` in the production build, and the minifier deleted `ErrorBoundary`'s development-only branch; the built `root-*.js` did not contain `.stack` at all. `clientEnv.DEV` is a property read at runtime (the build contains `{DEV:!1,…}`), so that branch now ships and never runs. Behaviour is identical and the bundle is a few bytes larger. That is the price of testability, and it is small.
18. **Configuration that does nothing still teaches something wrong.** The first `tsconfig.jest.json` set `"module": "CommonJS"`, and its comment said Jest needed it. QA removed it on a scratch copy and every test still passed, because ts-jest forces CommonJS on its own. Test each override by removing it, as the tables in step 6 do.
19. **`git checkout <file>` discards your own edits too.** During the fix round, a throwaway experiment was undone with `git checkout jest.config.js tsconfig.jest.json`, and that also wiped the uncommitted fixes in those two files, which had to be applied again. Commit or `git stash` your work before experimenting on the same files.
20. **Deliberately not done:** no API calls or data loaders, no tests for the `home.tsx` route yet (Phase 4), no admin routes, no Cloudinary, no SEO tags beyond `lang`, no fonts or colours from the mockups, no `eslint-plugin-react`, no Dockerfile, no development `.env` loader for server-only values (nothing reads them yet), and no required-status-check configuration (step 14 and section 9).

## 8. How to verify it yourself

From `apps/web`:

```sh
node -v && corepack --version && pnpm -v      # v24.14.0 · 0.34.6 · 12.4.2
pnpm install --frozen-lockfile                 # Lockfile is up to date … Done
pnpm lint                                      # no findings
pnpm format:check                              # All matched files use Prettier code style!
pnpm typecheck                                 # no errors
pnpm test                                      # Test Suites: 4 passed · Tests: 16 passed
grep -rln 'import\.meta\.env' app              # app/config/client-env.ts, app/vite-env.d.ts
pnpm build                                     # ✓ built … (client and ssr environments)
PORT=3100 pnpm start &
sleep 2
curl -s http://localhost:3100/ | grep -o '<h1[^>]*>[^<]*</h1>'
                                               # <h1 class="text-3xl font-semibold">Tintara Lab</h1>
grep -rlE 'API_INTERNAL|readServerConfig' build/client || echo "none found in build/client"
kill %1
```

From the repository root:

```sh
git check-ignore -v apps/web/anything.key      # .gitignore:31:*.key …
git ls-files apps/api/tmp                      # apps/api/tmp/.keep, apps/api/tmp/pids/.keep
git status --porcelain --untracked-files=all   # empty: no key file, no .env, no build output
gh pr checks 2                                 # API RuboCop, API RSpec, Web ESLint, Web TypeScript, Web Jest, Web Build: pass
```

## 9. What comes next

- **Required status checks.** After this PR merges and both workflows have run on `main`, the owner adds `API RuboCop`, `API RSpec`, `Web ESLint`, `Web TypeScript`, `Web Jest` and `Web Build` as required checks on `main` (D-060, D-070, D-071). The exact command is in the Feature 3 report. D-065 is what makes this safe.
- **Feature 4** adds the API's security baseline (CORS, CSRF, rate limits, including the `X-Internal-Token` exemption this chapter's `API_INTERNAL_TOKEN` will carry).
- **Phase 4** builds the real public page: the single `GET /api/v1/public/site` loader (D-046), which is the first real user of `getServerConfig()`, the `Cache-Control` header (D-045), and the sections and design from the mockups. The SEO baseline (D-019) comes with it.
- **Feature 19** brings the admin area under `/admin`. It will be **client-rendered**: admins need no search ranking, their pages depend on a logged-in session cookie that only the browser holds, and every admin screen fetches its own data from the API with `credentials: 'include'`, using `publicConfig.apiBaseUrl` from this chapter.

## 10. Glossary

- **Client bundle / module graph** — the JavaScript files sent to browsers / the tree of files reachable through imports from an entry point.
- **corepack / `packageManager`** — Node's package-manager manager / the `package.json` field naming the exact pnpm version, with an integrity hash.
- **Flat config** — ESLint's configuration format: an array of layers in `eslint.config.js`.
- **Framework mode (React Router)** — React Router acting as build tool and server, with route modules, loaders and actions.
- **Hydration** — attaching React's behaviour to HTML that the server already rendered.
- **`import.meta.env` / `VITE_` prefix** — Vite's build-time environment object / the prefix a variable needs to be exposed, and published, through it.
- **jsdom / React Testing Library / jest-dom** — a DOM in Node / rendering and querying components like a user / extra DOM matchers for `expect`.
- **Loader** — a route export that runs only on the server before rendering; removed from the client build.
- **`jest.mock` (test double)** — a stand-in for a real module inside a test: with a factory, every import of that module in the test file receives the factory's object, and the real module is never loaded.
- **`minimumReleaseAge`** — pnpm's rule refusing versions published too recently (24 hours by default here).
- **`moduleNameMapper`** — Jest's table of import-path regular expressions mapped to replacement files.
- **Required status check** — a CI check that must report success before GitHub allows a merge.
- **`.server` module** — a file or directory whose name contains `.server`; the build fails if client code reaches it.
- **Server-side rendering (SSR) / single-page app (SPA)** — HTML produced on the server per request / HTML produced by JavaScript in the browser.
- **ts-jest** — a Jest transform that compiles TypeScript with the real TypeScript compiler.
- **`verbatimModuleSyntax`** — a TypeScript option that keeps import/export statements exactly as written; incompatible with a CommonJS emit.
