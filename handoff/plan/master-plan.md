# Master Plan — Tintara Lab

**Version:** 1 · **Date:** 2026-09-13 · **Status:** Draft, waiting for the owner's review

Each task (Feature N) produces one implementation prompt, one branch, one PR, one implementation report, and one QA prompt and report (D-047). Prompts are written just in time, after the previous task is reviewed. Feature numbers below are planned; if tasks are split, merged or reordered, the status file holds the real counters and this plan is updated.

## Workflow per task
1. The orchestrator writes the implementation prompt.
2. The owner dispatches the implementation agent.
3. The agent opens a PR and writes its report.
4. The orchestrator writes the QA prompt.
5. The owner dispatches the QA agent, which writes its report.
6. The owner and the orchestrator review both reports.
7. Fix loop, if needed: fix-round prompt → fixes pushed to the same PR → QA re-check (D-054).
8. The owner squash-merges.
9. The orchestrator updates the status and writes the next prompt.

---

## Phase 1 — Foundation
**Goal:** repo, tooling and CI for both apps, with nothing product-specific yet.

| # | Task | Summary | Key decisions |
|---|---|---|---|
| Feature 1 | Monorepo bootstrap | `git init`; root `.gitignore`, `.editorconfig`, `README.md`, PR template; `docker-compose.yml` with Postgres (pinned major version, healthcheck, `.env.example`); `apps/` placeholder; commit handoff and `CLAUDE.md`; create the private GitHub repo `tintara-lab` and push `main` directly; check whether branch protection is available (report only) | D-018, D-030, D-032, D-034, D-037, D-049, D-057 |
| Feature 2 | Rails API skeleton + API CI | `rails new` in API mode with Postgres at `apps/api` (Ruby 3.4.3, Rails 8.1); RSpec, FactoryBot, shoulda-matchers, RuboCop; Solid Cache and Queue in the primary database; `GET /api/v1/health` with a spec; `.env.example`; `.github/workflows/api.yml` (RuboCop + RSpec with a Postgres service, path filter `apps/api/**`) | D-028, D-030, D-031, D-033, D-052 |
| Feature 3 | Web skeleton + web CI | React Router framework mode (SSR) at `apps/web` with pnpm through corepack; strict TypeScript; Tailwind; ESLint + Prettier; Jest + React Testing Library + jsdom with a TypeScript transform; env config module; one sample route test; `.github/workflows/web.yml` (lint, typecheck, Jest, path filter `apps/web/**`) | D-005, D-018, D-020, D-021, D-022, D-033 |

**Exit criteria:** both CI workflows are green on `main`; `docker compose up` gives a working database for the API; `CLAUDE.md` §7 has the real commands.

---

## Phase 2 — API security and authentication
**Goal:** a secure API foundation that everything else builds on.

| # | Task | Summary | Key decisions |
|---|---|---|---|
| Feature 4 | Security baseline | Cookie and session middleware in API mode; rack-cors with credentials, origin from an env var; CSRF token endpoint + `X-CSRF-Token` + Origin check; standard JSON error format; rate-limit infrastructure (Solid Cache store, JSON 429, `X-Internal-Token` exemption for public endpoints, trusted-proxy config); a test cache store that supports rate-limit specs | D-029, D-039, D-045 |
| Feature 5 | Admin authentication | `admins` + `sessions` (based on the Rails 8 generator, adapted for API mode); login, logout and current-admin endpoints; `must_change_password` blocks other admin actions until the password is changed; change-password endpoint; setup rake task for the initial admin; login rate limit | D-016, D-017, D-029 |
| Feature 6 | Password reset + mail infrastructure | Forgot and reset endpoints with `generates_token_for`; mailer + previews; Solid Queue `deliver_later`; SMTP settings through env vars (no real account yet); rate limit | D-014, D-015, D-017, D-029 |
| Feature 7 | Admin management | Admin endpoints: list, create (temporary password + `must_change_password`), delete (not self, not the last admin) | D-017 |

**Exit criteria:** every auth flow is covered by request specs; rate limits and CORS/CSRF are proven by specs.

---

## Orchestrator checkpoint — API contract (before Phase 3)
The orchestrator writes `handoff/plan/api-contract.md` (D-051): every endpoint, its payloads, status codes, error shapes, rate limits, and the JSON serialization approach. The owner reviews it.

---

## Phase 3 — Content API
**Goal:** every content resource, built against the contract.

| # | Task | Summary | Key decisions |
|---|---|---|---|
| Feature 8 | Cloudinary integration | Admin endpoint that issues signed upload parameters (folder or tag, preset with a 2560 px incoming cap); server-side verification of Cloudinary's upload response signature before saving a `public_id`; reusable image-attributes validation; job that deletes the Cloudinary asset when its record is destroyed; check whether strict transformations are available on the free plan (report) | D-023, D-024, D-025, D-029 |
| Feature 9 | Singleton sections | `landing_pages`, `about_sections` + `about_traits`, `contact_infos`: models, one-row enforcement, seeds, admin show and update endpoints (traits add and remove) | D-008, D-010, D-027 |
| Feature 10 | Experiences & services | Models; admin CRUD; creation-order sorting | D-009, D-010, D-027 |
| Feature 11 | Portfolio | `categories`, `albums`, `album_categories`, `photos`; `cover_photo_id` rules (same album, auto-assign first photo, `SET NULL`, safe album deletion); at least one category per album; category deletion guard; bulk photo creation; admin CRUD; sort orders | D-009, D-012, D-024, D-026, D-027 |
| Feature 12 | Contact messages | Public create with honeypot + rate limit; notification mail to the contact-info email via `deliver_later`; admin list, mark as read, delete | D-010, D-013, D-014, D-029 |
| Feature 13 | Public site endpoints | `GET /api/v1/public/site` (everything the page needs in one call) and `GET /api/v1/public/albums/:id/photos`; public rate limit with internal-token exemption; query-count specs (no N+1) | D-011, D-029, D-045, D-046 |

**Exit criteria:** the contract is fully implemented and every endpoint has request specs; seeds produce a complete demo dataset.

---

## Orchestrator checkpoint — Jest and React Router spike (before Phase 4, D-074)
A short task proving that Jest can render real React Router components (`Link`, `createRoutesStub`) by transforming `react-router` from `node_modules` (option b), with Jest ESM mode as the fallback. It removes the Feature 3 `jest.mock` workaround. If neither option works, D-020 goes back to the owner before any Phase 4 prompt is written. This task takes the next Feature number when it runs.

---

## Phase 4 — Public site (web)
**Goal:** the server-rendered public page, faithful to the mockups within the brief's scope.

| # | Task | Summary | Key decisions |
|---|---|---|---|
| Feature 14 | Design system & app shell | Tailwind theme tokens from the mockups (palette, fonts, spacing); base components; header with section anchors + mobile menu; footer shell; API clients (server: internal URL + token; browser: public URL + credentials + CSRF); Cloudinary URL helper (2000 px cap, `f_auto`, `q_auto`, `srcset`); `ProtectedImage` component | D-003, D-005, D-006, D-007, D-024, D-025 |
| Feature 15 | Home loader, Landing, Field Experience | `/` loader calling `public/site`; `Cache-Control` header; Landing hero (fixed texts, admin subtitle, CTAs scroll to sections); experiences carousel | D-003, D-006, D-018, D-045, D-046 |
| Feature 16 | Portfolio & Services sections | Album grid with category filter (cards take no action); services list | D-009, D-011 |
| Feature 17 | About & Contact sections | About (photo, traits, description, fixed name); contact section with form (validation, honeypot, 429 handling, success and error states) and Instagram, email and WhatsApp links | D-006, D-010, D-013 |
| Feature 18 | SEO & performance | Meta, Open Graph, JSON-LD, `sitemap.xml`, `robots.txt`, `lang="es"`, image dimensions and lazy loading; performance review report | D-019 |

**Exit criteria:** the public page renders fully from the server with seed data, on desktop and mobile layouts.

---

## Phase 5 — Admin panel (web)
**Goal:** admins can manage all content without developer help.

| # | Task | Summary | Key decisions |
|---|---|---|---|
| Feature 19 | Admin shell & auth UI | `/admin` client-rendered routes; login; auth guard; forced password change; forgot and reset password pages; logout; admin layout | D-012, D-017, D-018, D-039 |
| Feature 20 | Upload component & singleton editors | Signed-upload component (single + multiple, progress, errors); editors for landing, about (+ traits) and contact info | D-008, D-023, D-024 |
| Feature 21 | Experiences & services admin | CRUD screens | D-010 |
| Feature 22 | Portfolio admin | Category management (with the deletion guard message); album create and edit with bulk photo upload, category selection, cover selection, photo deletion | D-012, D-023, D-026 |
| Feature 23 | Inbox & admin management | Contact messages (read and unread, delete); admin users (create with temporary password, delete with rules) | D-013, D-017 |

**Exit criteria:** every section of the public page can be fully edited from `/admin`.

---

## Phase 6 — Hardening
| # | Task | Summary |
|---|---|---|
| Feature 24 | End-to-end QA sweep | A cross-cutting QA pass over the whole app: security (headers, cookies, CORS/CSRF, rate limits, secrets), accessibility, responsive layout, error states, and a documentation check. Produces a findings list that becomes fix tasks |

---

## Phase 7 — Deployment (deferred, D-036)
Planned after Phase 6. Known inputs:
- Vercel (Pro) for web; Railway for API + Postgres.
- The custom domain with `api.` subdomain (D-038, D-039).
- The Railway Hobby terms still need checking (D-044).
- The deployment CI pipeline.

---

## Dependencies at a glance
```
F1 → F2 → F4 → F5 → F6 → F7 → [API contract] → F8 → F9 → F10 → F11 → F12 → F13
F1 → F3 ─────────────────────────────────────────────────────────────────────┐
                                           F13 + F3 → F14 → F15 → F16 → F17 → F18
                                                  F18 → F19 → F20 → F21 → F22 → F23 → F24
```
F2 and F3 are independent of each other. They're still run one at a time, because the owner reviews each task before the next.
