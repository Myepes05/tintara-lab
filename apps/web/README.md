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

| Command | What it does |
|---|---|
| `pnpm install` | Install dependencies from `pnpm-lock.yaml` |
| `pnpm dev` | Development server with hot module replacement, http://localhost:5173 |
| `pnpm build` | Production build into `build/client` and `build/server` |
| `pnpm start` | Serve the production build, http://localhost:3000 |
| `pnpm typecheck` | Generate route types, then run `tsc` |
| `pnpm lint` | ESLint, zero warnings allowed |
| `pnpm format` / `pnpm format:check` | Prettier |
| `pnpm test` | Jest with React Testing Library |

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
