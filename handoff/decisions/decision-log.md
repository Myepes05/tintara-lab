# Decision Log

Format per entry: ID · Date · Status (Proposed / Pending validation / Accepted / Rejected / Deferred / Superseded) · Decision · Rationale · Alternatives considered and why rejected.

Sources:
- Owner's initial brief (summarized in D-000)
- Owner's discovery answers: `handoff/Answers.md`
- Owner's follow-up answers: `handoff/FinalAnswers.md`
- Mockups: `handoff/PC view mockup.jpeg`, `handoff/mobile view mockup.jpeg` (only these low-resolution versions exist)

---

## D-000 · 2026-09-13 · Validated — Initial inputs from project owner

Validated through D-003 to D-043. Where a later entry differs from this, the later entry wins.

- **Product:** Portfolio web app for a photographer. Public site with no user login; an admin area to customize every piece of content.
- **Architecture:** Monorepo with a Ruby on Rails API backend and a React + TypeScript frontend. No microservices.
- **Database:** PostgreSQL, running in a Docker container during development.
- **Image storage:** Cloudinary on the free plan.
- **Methodology:** Spec-driven development, with RSpec for the API and Jest (TypeScript) for the frontend.
- **CI:** GitHub Actions workflows running lint and tests for both apps.
- **Security:** API rate limiting.
- **Original data model:**
  - LandingPage(image_url, subtitle)
  - Experience(image_url, company_name)
  - Photo(cloudinary_url, metadata) n:1 Album
  - Album(name, description) 1:n AlbumCategory n:1 Category(name)
  - Service(image_url, title, text)
  - AboutMe(image_url, description) 1:n AboutMeTrait(name)
  - Contact(image_url, instagram_link, email, whatsapp), plus a contact form

## D-001 · 2026-09-13 · Superseded by D-037 — Provisional folder name `photographer-portfolio`

## D-002 · 2026-09-13 · Accepted — Handoff folder layout
- **Decision:** `handoff/{decisions, plan, status, prompts/{implementation,qa}, agent-outputs/{implementation,qa}}`.
- **Rationale:** Keeping prompts and outputs split by agent type lets the orchestrator match each QA report to the implementation report it verifies.

---

## Product and UX

### D-003 · Accepted — Single long-scroll public page
- **Decision:** One page with sections in this order: Landing → Field Experience → Portfolio → Services → About Me → Contact (footer).
- **Design rule:** The mockups are the visual reference (typography, palette, spacing, mood). The owner's context overrides the mockups wherever they differ.

### D-004 · Accepted — Language
- **Decision:** Site content is in Spanish, entered by the admin. The public UI's fixed strings are Spanish. Code, identifiers, commits, PRs and all handoff documents are in English, always.

### D-005 · Accepted — Styling
- **Decision:** Tailwind CSS. Material UI only where it makes a big difference, and each such use needs its own decision entry.
- **Rationale:** The owner considers MUI too heavy for general use.

### D-006 · Accepted — Fixed-in-code content
- **Brand and site title:** "Tintara Lab"
- **Photographer name:** "Luisa Sanabria"
- **Location:** "Medellín, Colombia"
- **Hero CTAs:** "Ver portafolio" scrolls to the Portfolio section; "Trabajemos juntos" scrolls to Contact.
- **Other fixed strings:** section headings and fixed UI labels.

### D-007 · Accepted — Mockup sections excluded
- **Excluded:** intro statement block, "Selected Work / Trabajos seleccionados", "Nuestra filosofía", "Del concepto a la imagen" (process) and testimonials.
- **Mockup elements adapted to the brief:**
  - The mockup's "Clients / Experiences" testimonials are replaced by the Field Experience company carousel.
  - The hero slider is replaced by a single image.
  - Navigation lists only the sections in D-003.
  - "Conoce más sobre mí" is dropped because no separate page exists.

### D-008 · Accepted — Singletons
- **Decision:** Landing, About Me and Contact info are each a single record.

### D-009 · Accepted — No admin-controlled ordering; fixed default sort orders
- **Albums:** newest first.
- **Photos in an album:** upload order.
- **Experiences, services and about-me traits:** creation order (oldest first).

### D-010 · Accepted — Minimal fields
- **Albums:** no publish status and no slug.
- **Experiences:** name and logo only.
- **Services:** image, title and text only.
- **Contact info:** fixed fields Instagram, email and WhatsApp. WhatsApp is stored as a phone number, and the frontend builds the `wa.me` link from it.
- **Contact email:** shown publicly and also used as the destination for contact-form notifications.

### D-011 · Deferred — Clicking an album
- **Decision:** No action for now; album cards are display-only. A gallery or lightbox may come later.
- **Consequence:** Albums show their cover photo, name and categories. The public API must still expose album photos so a gallery can be added later without API changes.

### D-012 · Accepted — Categories
- **Rule 1:** Every album must have at least one category.
- **Rule 2:** A category cannot be deleted if any album would be left with no categories. The API returns a validation error naming the affected albums; otherwise deleting a category removes it from its albums.

---

## Contact form and email

### D-013 · Accepted — Contact form
- **Fields:** name, email, project in mind, phone number.
- **Delivery:** Each message is saved to the database, listed in the admin panel, and emailed with Rails Action Mailer to the contact-info email.
- **Admin actions:** mark a message as read; delete it.
- **Spam protection:** honeypot field plus rate limiting. No CAPTCHA.

### D-014 · Accepted — Email transport: Gmail SMTP with an app password, sent through Solid Queue with `deliver_later`
- **Scope:** contact notifications and password reset emails.
- **Credentials:** kept in Rails credentials or environment variables, never committed.
- **Rejected alternative:** Resend, SendGrid and similar providers. They need a verified domain to deliver reliably. Revisit once the domain exists.

### D-015 · Deferred — The Gmail account used to send email
- **Development:** mail is not sent; use Action Mailer previews and deliveries logged to the console or stored in test, until the owner provides the account.

---

## Admin and authentication

### D-016 · Accepted — Authentication built on the Rails 8 authentication generator
- **Decision:** `has_secure_password`, a database-backed `sessions` table, and signed httpOnly cookies. Password reset tokens use `generates_token_for`.
- **Rejected alternative:** Devise. The owner never wanted it; it's heavier and needs extra configuration for API-only mode with cookies.

### D-017 · Accepted — Admin lifecycle and rules
- **Initial admin:** created by a setup script (rake task or seed) with a temporary password.
- **First login:** every admin with a temporary password must change it at first login; the API blocks all other admin actions until they do.
- **Permissions:** all admins have equal permissions.
- **Creating admins:** any admin can create admins with a temporary password.
- **Deleting admins:** an admin can delete other admins, but not themselves and never the last remaining admin.
- **Password recovery:** a "forgot password" email is required.
- **Two-factor authentication:** not required.
- **Location:** the admin UI lives in the same frontend app under `/admin`.

---

## Frontend architecture

### D-018 · Accepted — React Router framework mode with server-side rendering for the public page
- **Decision:**
  - The public page is server-rendered, so the first HTML response contains real content; its data loads through server-side loaders that call the Rails API.
  - The admin area under `/admin` is client-rendered.
  - Stack: React + TypeScript, Vite-based.
- **Rationale:** Google ranking "matters a lot" and the budget is low. Server rendering sends crawlers and social link previews the content itself, at no licensing cost.
- **Rejected alternatives:**
  - A plain client-rendered SPA: admin-edited content reaches crawlers only through JavaScript rendering.
  - Next.js: its async server-component pattern isn't well supported by Jest, which conflicts with D-020, and it's heavier than this site needs.
- **Consequences:**
  - Production needs a Node process for the frontend, which can run on the same server as Rails.
  - The exact React Router version is verified and pinned in the setup phase.

### D-019 · Accepted — SEO baseline
- Server-rendered HTML with `lang="es"`.
- Title and meta description.
- Open Graph and Twitter tags.
- JSON-LD structured data for the business or photographer.
- `sitemap.xml` and `robots.txt`.
- Image alt text.
- Responsive Cloudinary images with explicit dimensions to protect Core Web Vitals.

### D-020 · Accepted — Jest for frontend tests (firm)
- **Tools:** Jest, React Testing Library and jsdom, with a TypeScript transform.
- **Rejected alternative:** Vitest. The owner prefers Jest for its maturity in production.
- **Consequence:** Jest runs independently of Vite, so `import.meta.env` access must go through a config module that tests can mock.

### D-021 · Accepted — pnpm as the frontend package manager
- **Note:** pnpm is not installed on the owner's machine. Corepack 0.34.6 is available, so the setup phase enables pnpm with `corepack enable` and pins the version in `packageManager`.

### D-022 · Rejected — Playwright and end-to-end browser tests
- **Decision:** Not used; the owner explicitly declined.
- **Coverage instead:** RSpec request specs plus Jest and React Testing Library.

---

## Images

### D-023 · Accepted — Cloudinary account and uploads
- **Account:** the owner's existing account, on the free plan.
- **Upload flow:** direct signed uploads from the browser; the API only issues signatures.
- **Bulk upload:** multi-select photo upload when creating or editing albums.

### D-024 · Accepted — Store Cloudinary `public_id` plus dimensions, never URLs
- **Decision:**
  - Every image stores `public_id`, `width` and `height`.
  - Album photos also store an optional `alt_text`, falling back to "<album name> – foto N".
  - URLs are built at render time with `f_auto`, `q_auto` and responsive widths.
  - No EXIF, location or date-taken fields.
- **Rationale:**
  - `public_id` is needed to delete assets and to generate sizes.
  - Width and height prevent layout shift, which affects Core Web Vitals and therefore SEO.
  - Alt text helps SEO and accessibility.
- **Cloudinary quota protections:**
  - An upload preset with an incoming transformation that caps the stored long edge (e.g. 2560 px).
  - A background job deletes Cloudinary assets when their records are deleted.
  - Uploads go to a folder or tag, so abandoned uploads can be cleaned up.

### D-025 · Accepted — Image protection: deterrents only
- **Limitation:** Screenshots can't be blocked by any website, and right-click blocking can be bypassed. The owner accepted this.
- **Measures:**
  - Block the context menu and dragging on images.
  - `-webkit-touch-callout: none` and `user-select: none`.
  - A transparent overlay on images.
  - Public renditions capped at 2000 px on the long edge.
  - Cloudinary strict transformations, if the free plan supports them; to be verified in the setup phase.
- **Rejected:** watermark overlay; the owner declined it.

---

## Data model

### D-026 · Accepted — Album cover as `albums.cover_photo_id`
- **Decision:** The owner chose `albums.cover_photo_id` (nullable foreign key to `photos`) over the orchestrator's proposed `photos.is_cover` flag.
- **Known risks and required mitigations:**
  1. **Circular foreign keys** (`photos.album_id` → albums, `albums.cover_photo_id` → photos). The column must be nullable. Flow: create the album, create its photos, then set the cover. The foreign key uses `ON DELETE SET NULL`.
  2. **Cover from another album.** A model validation must guarantee the cover photo belongs to the same album, backed by a spec.
  3. **Missing cover.** When the cover is null (no cover chosen yet, or the cover photo was deleted), the API assigns the album's first photo in upload order as cover.
  4. **Deleting an album.** Clear `cover_photo_id` before destroying its photos, or rely on the cascade order, and cover this with a spec.
- **Rejected alternative:** `photos.is_cover` with a partial unique index. The owner prefers an explicit reference on the album.

### D-027 · Accepted — Final relational model

| Table | Columns |
|---|---|
| `admins` | email (unique, normalized), password_digest, must_change_password (bool, default true) |
| `sessions` | admin_id, ip_address, user_agent |
| `landing_pages` (singleton) | subtitle, image_public_id, image_width, image_height |
| `experiences` | company_name, logo_public_id, logo_width, logo_height |
| `categories` | name (unique) |
| `albums` | name, description, cover_photo_id (nullable FK → photos, see D-026) |
| `album_categories` | album_id, category_id, unique (album_id, category_id); every album has ≥ 1 (D-012) |
| `photos` | album_id, public_id, width, height, alt_text (nullable) |
| `services` | title, text, image_public_id, image_width, image_height |
| `about_sections` (singleton) | description, image_public_id, image_width, image_height |
| `about_traits` | about_section_id, name |
| `contact_infos` (singleton) | instagram_url, email, whatsapp_phone, image_public_id, image_width, image_height |
| `contact_messages` | name, email, phone, project_description, read_at (nullable) |

- **Singletons:** created by seeds, enforced as one row, and exposed as singular API resources.
- **Rails infrastructure:** Solid Cache and Solid Queue tables live in Postgres.
- **Renames from the owner's model:** "About-me" → `about_sections` and "Contact" → `contact_infos`, to avoid confusion with `contact_messages`.

---

## Backend and platform

### D-028 · Accepted — Ruby 3.4.3 and Rails 8.1 in API mode. No Redis until there is a concrete reason for it.

### D-029 · Accepted — Rate limits
- **Mechanism:** Rails built-in `rate_limit`, backed by Solid Cache, per IP. Blocked requests get a JSON 429 response.

| Endpoint | Limit |
|---|---|
| `POST /api/v1/session` (login) | 5 requests / 3 min |
| `POST /api/v1/passwords` (forgot password) | 5 requests / hour |
| `POST /api/v1/contact_messages` | 5 requests / hour |
| Public `GET` endpoints | 120 requests / min |
| Authenticated admin endpoints | 300 requests / min |
| Cloudinary signature endpoint | 60 requests / min |

- **Rejected alternative:** Rack::Attack. It's an extra dependency and Rails 8 provides equivalent limiting.
- **Production note:** Configure trusted proxies so limits apply to the real client IP.

### D-030 · Accepted — Docker runs only Postgres in development (one docker-compose service)

### D-031 · Accepted — API versioning under `/api/v1`

---

## Monorepo, repository and CI

### D-032 · Accepted — Monorepo layout with both apps under an apps folder
- **Layout:**
  - `apps/api/` — the Rails API
  - `apps/web/` — the React Router frontend
  - `docker-compose.yml` at the root
  - `.github/workflows/api.yml` and `.github/workflows/web.yml`, filtered by path
  - `handoff/`
  - `CLAUDE.md` at the root
- **Owner change:** The owner required both apps under an "Apps" folder; everything else was accepted as proposed.
- **Casing:** lowercase `apps/`, confirmed by the owner 2026-09-13.
- **Rationale:** macOS treats folder names as case-insensitive, while GitHub Actions (Linux), Vercel and Railway are case-sensitive, so a mixed-case path could pass locally and break in CI or at deploy. Lowercase also follows monorepo convention.

### D-033 · Accepted — CI runs lint and tests for both apps only
- **API:** RuboCop and RSpec.
- **Web:** ESLint, TypeScript type-check and Jest.
- **Deferred:** the deployment pipeline.

### D-034 · Accepted — Repository and pull requests
- **Repository:** GitHub repo `tintara-lab`; `main` is the base branch. **Amended 2026-09-15:** the repository was switched from private to open to everyone, so that branch protection could be enabled. See D-059.
- **Pull requests:** every change goes through a branch and a PR opened by the implementation agent.
- **Merging:** only the owner merges, after review, using squash merge.
- **Rejected alternative:** rebase-merge. The owner prefers squash.
- **Tooling:** The gh CLI is installed (2.100.0) and authenticated as `Myepes05` with the `repo` and `workflow` scopes (verified 2026-09-13).

### D-035 · Accepted — PR and commit naming convention
- **Format:** `Feature N: <one-line summary>` for planned work; `fix N: <one-line summary>` for bugs reported by QA or similar.
- **Casing:** exactly as written above.
- **Numbering:** N counts PRs, with a separate sequential counter per type.
- **Squash rule:** Because PRs are squash-merged (D-034), the PR title is the commit that lands on `main` and must follow the format.
- **Commits on a branch:** should use the same `Feature N:` or `fix N:` prefix as their PR, for traceability.
- **Counters:** The last-used numbers are tracked in `handoff/status/current-status.md`. The orchestrator assigns N in each prompt so agents never guess it.

### D-036 · Deferred — Hosting, staging and the deployment pipeline are decided after development
- **Owner's intended hosting (2026-09-13, not final):** the frontend on Vercel; the Rails API and Postgres on Railway. See D-044 for verified constraints.

### D-037 · Accepted — Project, folder and repository name: `tintara-lab`
- **Action:** The folder was renamed from `photographer-portfolio` on 2026-09-13.

### D-038 · Accepted — The owner will buy a domain (about $15/year) at deployment
- **Rationale:** Needed for SEO and branding, and for first-party session cookies (D-039).

### D-039 · Proposed — Network topology: how the browser reaches the API
- **Status:** Under discussion with the owner.
- **Options presented:**
  1. One domain with path routing: `/api` goes to Rails, everything else to Node. Recommended.
  2. Subdomains: `api.` for Rails.
  3. Two unrelated domains. Rejected, because the session cookie would be third-party and blocked.
- **Owner's question:** Would switching to JWT avoid the hosting constraints?
- **Orchestrator's analysis:**
  - **The cookie constraint is small.** Cookies only require the frontend and API to share one registrable domain, and the owner is already buying one (D-038). Both option 1 and option 2 satisfy it.
  - **JWT would remove only that constraint.** It needs no shared domain, but CORS setup is still required.
  - **What JWT costs:**
    - The token must live in JavaScript-readable storage, so any XSS bug could steal an admin token.
    - Logout and revoking access need extra machinery (short expiry plus refresh tokens, or a denylist). Refresh tokens are usually kept in httpOnly cookies, which brings the cookie constraint back.
    - It needs custom auth code instead of the Rails 8 generator (D-016), which means more code and more specs.
  - **Recommendation:** keep cookie sessions (D-017) with option 1 or option 2.
- **Owner's decision:** keep cookie sessions. JWT is rejected.
- **Updated proposal for the Vercel + Railway stack (see D-044):** option 2, subdomains.
  - `tintaralab.com` points to Vercel (React Router SSR).
  - `api.tintaralab.com` points to the Railway Rails service.
  - The browser calls the API with `credentials: 'include'`.
  - Rails CORS (rack-cors) allows exactly the frontend origin from an environment variable, with credentials.
  - The session cookie is httpOnly, Secure, `SameSite=Lax`, and host-only (no `Domain` attribute).
  - CSRF protection: the token comes from an API endpoint in the JSON body (the frontend cannot read the API's cookies) and is sent back in an `X-CSRF-Token` header. The Origin header is also checked.
  - Development mirrors production: `localhost:5173` calls `localhost:3000` directly with CORS. Different ports on localhost count as the same site.
- **Rejected for this stack:** option 1, where Vercel rewrites `/api` to Railway.
  - Every API call would make an extra hop through Vercel.
  - Rails would sit behind two proxies (Vercel and Railway's edge), which makes identifying the real client IP for rate limiting fragile and spoofable.
  - The direct Railway URL would still be public.
- **Status:** Accepted 2026-09-13. The owner chose option 2 (subdomains) with cookie sessions.
- **Also presented and not chosen:** hosting both apps on Railway. It would avoid Vercel Pro and give server-side calls a private network, at the cost of Vercel's CDN and preview deployments. The code stays compatible with it, so it can be revisited at deployment (D-036).

---

## Orchestration

### D-040 · Accepted — Orchestration workflow
- The orchestrator writes each prompt as its own file under `handoff/prompts/{implementation,qa}/`.
- The owner dispatches each agent from a new session.
- The agent writes its report under `handoff/agent-outputs/{implementation,qa}/`.
- The owner verifies the report and discusses it with the orchestrator; the next step starts only after agreement.

### D-041 · Accepted — All documentation is in English, always

### D-042 · Accepted — Spec-driven development
- **Rule:** For each behavior, write the spec (RSpec) or test (Jest) first, then write the implementation to make it pass.
- **Required reporting:** QA agents verify that the specs exist and cover the acceptance criteria. Implementation reports must include the test command outputs.

### D-043 · Accepted — Rate-limit values were delegated to the orchestrator and confirmed by the owner (see D-029)

---

## Hosting research

### D-044 · Research — Vercel + Railway constraints (verified 2026-09-13)
1. **Vercel Hobby is non-commercial only.** Vercel's fair-use guidelines (last updated 2026-07-29) say: "Hobby teams are restricted to non-commercial personal use only." Commercial use includes "Advertising the sale of a product or service" and "Receiving payment to create, update, or host the site". This photographer's site advertises services, so it needs Vercel Pro.
   - Source: https://vercel.com/docs/limits/fair-use-guidelines
   - **Status:** Flagged to the owner (budget impact).
2. **Vercel supports React Router framework mode with SSR.** SSR runs as Vercel Functions, with the optional `@vercel/react-router` preset. `Cache-Control` headers returned by routes are honored by Vercel's CDN.
   - Source: https://vercel.com/docs/frameworks/frontend/react-router
3. **Railway plans:**
   - Free: $0, with $1 of credit per month.
   - Hobby: $5 per month, including $5 of usage.
   - Pro: $20 per month.
   - The plans page does not state an explicit commercial-use restriction on Hobby; it describes Hobby as "for ... personal projects". The terms of service still need checking before deployment.
   - Source: https://docs.railway.com/reference/pricing/plans
4. **The default platform addresses are separate sites for cookies.** `vercel.app` and `up.railway.app` are both on the Public Suffix List (entries verified in the list on 2026-09-13), so browsers treat every `*.vercel.app` and `*.up.railway.app` address as its own site. Without a custom domain, the session cookie is always third-party and gets blocked (Safari and Firefox by default). A custom domain shared by both apps is therefore mandatory for admin login in production.
5. **Consequence for preview deployments:** Vercel preview URLs (`*.vercel.app`) can render the public site, but admin login will not work on them.

### D-045 · Proposed — Server-side calls to the API bypass the per-IP public rate limit and are cached
- **Problem:** On Vercel, SSR requests reach Rails from Vercel's IP addresses, not visitors' IPs. The public `GET` limit of 120 requests per minute per IP (D-029) would throttle the site itself during traffic spikes.
- **Proposed solution:**
  1. The SSR loader sends a secret header, `X-Internal-Token`, taken from an environment variable. Rails exempts requests with a valid token from the per-IP public limit.
  2. The public page route returns `Cache-Control: s-maxage=60, stale-while-revalidate=300`, so Vercel's CDN serves most visits without calling Rails. Admin edits appear within about 1 to 6 minutes.
- **Status:** Accepted 2026-09-13 (the owner chose option A).
- **Rejected alternatives:**
  - B, CDN cache only: query-string variations such as `?utm_source=` bypass the cache, so the site could still throttle itself.
  - C, secret header only: every visit renders fresh, which is slower and costs more.
  - D, raising or removing the public limit: weakens the protection of the public API.
- **Security rules:**
  - The internal token exists only in server environment variables and server-side loaders, never in client bundles.
  - The token is rotatable.
  - A leaked token only bypasses the public per-IP limit; it grants no admin access.
- **Open item:** whether Vercel can clear its cache on demand when the admin saves. Not verified; check at deployment.

---

## Planning and process (orchestrator, 2026-09-13)

### D-046 · Proposed — One aggregated public endpoint for server rendering
- **Decision:**
  - `GET /api/v1/public/site` returns every section the public page needs, with albums including their cover photo and categories.
  - Album photos remain available at `GET /api/v1/public/albums/:id/photos`, for the future gallery (D-011).
- **Rationale:** One Rails call per page render keeps server-side traffic low (D-045), makes page loads faster, and gives the frontend a single loader to test.
- **Rejected alternative:** one endpoint per section. That means six calls per render and six loaders.
- **Status:** Included in the master plan; the owner can object when reviewing the plan.

### D-047 · Accepted — Task granularity and just-in-time prompts
- **Granularity:** one planned task = one implementation prompt = one branch = one PR = one `Feature N`. Each task also gets one QA prompt.
- **Just-in-time prompts:** The orchestrator writes each prompt only after the previous task's outputs are reviewed, so prompts reflect what was actually built. The master plan lists every task in advance.

### D-048 · Accepted — Handoff file naming
- **Implementation prompts:** `handoff/prompts/implementation/feature-NNN-<slug>.md`
- **QA prompts:** `handoff/prompts/qa/qa-feature-NNN-<slug>.md`
- **Implementation outputs:** `handoff/agent-outputs/implementation/feature-NNN-<slug>.md`
- **QA outputs:** `handoff/agent-outputs/qa/qa-feature-NNN-<slug>.md`
- **Fix tasks:** the same patterns with `fix-NNN`.
- **Numbering:** `NNN` is zero-padded (`001`) so files sort correctly. PR titles use the owner's unpadded format (`Feature 1:`).
- **Branches:** `feature/N-<slug>` and `fix/N-<slug>`.

### D-049 · Accepted — `Feature 1` is committed directly to `main`
- **Rationale:** A PR needs a base branch, and `main` doesn't exist until the first commit. This is the only exception to D-034.
- **Commit message:** the owner's own example, "Feature 1: push the first commit of the monorepo".

### D-050 · Accepted — Evidence of spec-first work
- **Rule:** Within each branch, specs and tests are committed in a commit that comes before the implementation commit(s) for that behavior. The branch history then shows spec-first work (D-042).
- **Required reporting:** Implementation reports list their spec commits; QA checks the commit order.

### D-051 · Accepted — Contract-first API
- **Rule:** Before Phase 3 prompts are written, the orchestrator writes `handoff/plan/api-contract.md` with endpoints, request and response shapes, error format, status codes and rate limits. Backend and frontend tasks both build against it, and any change to it is recorded as a decision.

### D-052 · Proposed — Solid Cache and Solid Queue use the primary Postgres database
- **Rationale:** One database on Railway is simpler and cheaper to run.
- **Rejected alternative:** the Rails 8 default of separate cache, queue and cable databases. It adds configuration and migrations to manage with no benefit at this traffic level.
- **Status:** Implemented in Feature 2 unless the owner objects.

### D-053 · Accepted — Handoff-only changes are committed directly to `main` as `docs N: <brief summary>`
- **What goes where:**
  - **Code** (anything outside `handoff/`, plus `CLAUDE.md` changes that belong to a task) goes only through PRs.
  - **Handoff-only changes** (prompts, status, decisions, plan, templates, QA reports) are committed straight to `main` by the orchestrator, only with the owner's approval.
  - **An implementation report** is committed inside its own PR.
- **Numbering:** `docs` has its own sequential counter. N counts commits, because docs changes have no PRs. Counters are tracked in the status file.
- **Clean working tree:** before an agent is dispatched, all pending handoff changes must be committed, so every branch starts from an up-to-date `main`.
- **QA reports:** a QA agent writes its report as an untracked file and does not commit it. The orchestrator commits it with `docs N`.
- **Rationale:** Branches only add uniquely named report files, so they never conflict with the status and decision files the orchestrator edits continuously.
- **Rejected alternatives:**
  - B, handoff changes carried in the next feature PR: likely conflicts and error-prone stash handling.
  - C, handoff not in git: no history or backup.

### D-054 · Accepted — QA findings on an open PR are fixed in the same PR before merging
- **Flow:**
  1. The QA report returns FAIL, or findings the owner wants fixed.
  2. The orchestrator writes a fix-round prompt: `handoff/prompts/implementation/feature-NNN-<slug>-fix-rK.md`, where K is the round number.
  3. The implementation agent pushes commits to the same branch, prefixed `Feature N: fix <finding>`, and updates its report in the PR with a "Fix round K" section.
  4. The orchestrator writes a re-check prompt: `handoff/prompts/qa/qa-feature-NNN-<slug>-rK.md`. The QA report uses the same name.
  5. The owner squash-merges once QA passes.
- **Which findings block:** blocker and major findings must be fixed before merging. For minor and nit findings, the owner decides at review whether to fix them now or record them as follow-ups.
- **`fix N` PRs** are reserved for bugs found in code already merged, e.g. by the Feature 24 sweep or later.
- **Rationale:** `main` never contains known bugs.
- **Rejected alternatives:**
  - B, merge first and then open a `fix N` PR: `main` would hold known bugs.
  - C, a fix PR into the feature branch: the squash merge erases `fix N` from `main`'s history.

### D-055 · Accepted — Tool and library versions are verified, never guessed
- **Rule:** Implementation agents check the current stable versions (React Router, Tailwind, Jest, gems, the Postgres image), pin them, and report the versions in their output.

### D-056 · Accepted — `handoff/templates/` folder
- **Contents:** templates for prompts and agent outputs, so every agent writes in the same shape and future orchestrators can compare reports.

### D-057 · Research — Branch protection on the private repo
- **Note:** GitHub branch protection for private repos may require a paid GitHub plan (not verified yet). Feature 1 checks whether it's available and reports back without configuring anything. Until protection exists, "only the owner merges" is a convention written into `CLAUDE.md`.

---

## Feature 1 outcomes (2026-09-15)

### D-058 · Accepted — Development uses Postgres 18
- **Decision:** `docker-compose.yml` pins `postgres:18` (verified running 18.6).
- **Owner's answer to the Feature 1 question:** stay on 18; if the hosting provider's default version differs at deployment, deal with it then.
- **Known caveat (D-036):** Railway's Postgres template image tag `:latest` currently resolves to Postgres 16, per the template repository's build workflow. At deployment, select the `:18` image explicitly so development and production match.

### D-059 · Accepted by the owner, flagged by the orchestrator — Repository visibility changed to open, and `main` protected
- **What happened (2026-09-15):** The owner directed the Feature 1 agent to switch `tintara-lab` from private to readable by everyone, so that GitHub's branch protection could be enabled. Protection is now active on `main`.
- **Why it was needed:** Branch protection and rulesets are gated on the owner's GitHub plan (`gh api user` reports `plan: null`); the API returned 403 "Upgrade to GitHub Pro or make this repository public".
- **Protection configured:** pull request required (0 approvals, because a single account cannot approve its own PR), stale approvals dismissed, conversation resolution required, linear history required, force pushes and deletions blocked, administrators **not** included (deliberate: D-053 has the orchestrator committing `docs N` straight to `main`).
- **Alternative that was offered and declined:** GitHub Pro (about $4/month), which allows protection on a private repository.
- **Consequences now in effect:**
  - Everything in `handoff/` is world-readable, including the photographer's real name and city, both mockup images, the discovery answers and the whole business plan, plus the owner's email address in `FinalAnswers.md` and in the status file. It is in the first commit, so the history carries it even if the files change later.
  - Any secret committed by mistake from now on must be treated as compromised the instant it is pushed.
  - Strangers can open issues and pull requests. Issues are currently enabled.
  - GitHub Actions minutes are free for repositories readable by everyone, which removes any CI usage cost.
- **Orchestrator's concern (raised 2026-09-13 in the agent session and again 2026-09-15):** the exposed data includes a third party's personal information (the photographer). Whether she agreed to it is unknown. The orchestrator recommends reverting to private, and either paying for GitHub Pro or relying on the convention that only the owner merges.
- **Owner's answer (2026-09-15):** keep the current visibility. Reverting to private may be reconsidered later.
- **Status:** Accepted, with the orchestrator's concern on record.

### D-060 · Accepted — Branch protection is now configured (supersedes the research note in D-057)
- Required status checks are not set yet. Once `api.yml` (Feature 2) and `web.yml` (Feature 3) have run on `main`, add them as required checks.

### D-061 · Proposed — QA agents are dispatched only for tasks that produce application code
- **Decision:** Scaffolding and configuration tasks with no application code and no specs (such as Feature 1) are verified by the orchestrator directly, and the verification is recorded in the status file. Tasks that produce application code or specs always get a QA agent.
- **Rationale:** A QA agent's value is in independently re-deriving behavior from specs. For Feature 1 the deliverables are files and repository settings, which the orchestrator can verify in a minute with direct commands, and did.
- **Status:** Accepted by the owner 2026-09-15. Feature 1 had no QA agent; the orchestrator's verification is recorded in the status file. QA agents resume with Feature 2.

### D-062 · Proposed — RuboCop uses the Rails 8 default `rubocop-rails-omakase` configuration
- **Decision:** Keep the linting setup Rails 8 generates, with no extra style plugins for now.
- **Rationale:** Zero configuration, it is the convention the framework ships, and it avoids spending review time on style debates. Rules can be tightened later if something specific justifies it.
- **Rejected alternative:** A custom `rubocop-rails` plus `rubocop-rspec` setup. More configuration to maintain, and it tends to produce large mechanical diffs.
- **Status:** Implemented in Feature 2 unless the owner objects.

### D-063 · Proposed — Rails components skipped in Feature 2
- **Skipped:** Action Cable (no realtime features), Active Storage (images go directly to Cloudinary, D-023), Action Mailbox (no inbound mail), the Rails default test framework (RSpec is used, D-000), Jbuilder (the serialization approach is decided with the API contract, D-051), and Kamal (deployment is deferred and the target is Railway, D-036).
- **Kept:** Action Mailer (password reset and contact notifications, D-014), Solid Cache and Solid Queue (D-052), Brakeman and RuboCop (Rails 8 defaults).
- **Rationale:** Every component kept has a decided use; skipping the rest keeps migrations, configuration and the dependency surface small.
- **Status:** Implemented in Feature 2 unless the owner objects.

### D-064 · Accepted — `handoff/learning/`: a teaching chapter per implementation task
- **Owner's goal (2026-09-15):** be able to build an app like this alone afterwards, from a written, detailed record of how it was done and why.
- **Decision:**
  - Each implementation task produces `handoff/learning/NN-<slug>.md`, written with `handoff/templates/learning-chapter.md`.
  - The author is the **implementation agent that did the work**, and the chapter is committed inside its own PR, alongside its report.
  - The QA agent verifies the chapter against the PR: commands, file contents, technical correctness, reproducibility.
  - `handoff/learning/README.md` indexes the chapters.
- **Chapter content:** what is being built and why, concepts explained from scratch, the real step-by-step sequence, annotated walkthroughs of the important files, the decisions with their rejected alternatives, the traps and mistakes, self-verification commands, and a glossary.
- **Rationale:** Reports are written for verification, not for teaching, and they assume context a learner does not have. The implementation agent is the only one that knows what it tried, rejected and avoided; a documentation agent writing later from the diff would have to guess at that.
- **Rejected alternatives:**
  - A separate documentation agent per task: an extra session each time, and it would infer intent from the diff instead of knowing it.
  - The orchestrator writing the chapters: it does not see the implementation work first-hand, and it would burn orchestration context.
  - Deriving a guide at the end of the project: the details that matter (what broke, what was almost done wrong) are forgotten by then.
- **Backfill:** Features 1 and 2 finished before this decision, so their chapters are written retroactively (see the status file).
