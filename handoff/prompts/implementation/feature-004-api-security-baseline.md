# Feature 4: add the API security baseline with CORS, CSRF, rate limits and JSON errors

**Type:** Implementation · **Phase:** 2 — API security and authentication
**Branch:** `feature/4-api-security-baseline`
**PR title (exact):** `Feature 4: add the API security baseline with CORS, CSRF, rate limits and JSON errors`
**Report file:** `handoff/agent-outputs/implementation/feature-004-api-security-baseline.md` (use `handoff/templates/implementation-output.md`)
**Learning chapter:** `handoff/learning/04-api-security-baseline.md` (use `handoff/templates/learning-chapter.md`, see CLAUDE.md §7b and D-067)
**Working directory:** `/Users/miguelangel/Documents/projects/tintara-lab`

## Before you start
1. Read `CLAUDE.md` completely, especially §4, §5 and §6.
2. Read `handoff/status/current-status.md`, including the Feature 4 carry-over note.
3. Read these decisions: D-016, D-029, D-031, D-039, D-045, D-050, D-052, D-053, D-055, D-064, D-065, D-066, D-067, D-068, D-078, D-079, D-080.
4. Read `handoff/learning/02-rails-api-skeleton.md`. Your chapter continues the API from where it ends.
5. Confirm `main` is clean and up to date (Feature 3 is merged as `a528d21`), start Postgres (`docker compose up -d`), and check that `bundle exec rspec` and `bundle exec rubocop` pass on `main` before you branch.

Depends on: Feature 2 (the Rails API and `api.yml`). Feature 3's `apps/web/.env.example` already names `API_INTERNAL_TOKEN` on the web side.

## Goal
Give the API the security foundation every later endpoint relies on: cookies and a session in API mode, CORS for the one frontend origin, CSRF protection with an Origin check, one JSON error format, and rate-limit infrastructure with the internal-token exemption. No product endpoints yet; Feature 5 builds admin authentication on top of this.

**Branch protection is now live on `main` (D-070):** your PR cannot merge until `API RuboCop`, `API RSpec`, `Web ESLint`, `Web TypeScript`, `Web Jest` and `Web Build` all pass.

## Scope
### In scope
- Cookie and cookie-store session middleware in API mode
- `rack-cors` with credentials for exactly `FRONTEND_ORIGIN`
- `GET /api/v1/csrf_token`, forgery protection with `X-CSRF-Token`, and the custom Origin check
- The D-078 error format: a reusable way to render it, the Feature 4 codes, and a JSON 404 for unknown `/api` paths
- Rate-limit infrastructure, the public `GET` tier, the internal-token exemption, `Retry-After`, a test cache store that supports limits
- Trusted proxies from `TRUSTED_PROXIES`
- Boot-time configuration for `FRONTEND_ORIGIN`, `API_INTERNAL_TOKEN` and `TRUSTED_PROXIES`, documented in the root `.env.example`
- Test values for the required variables in `.github/workflows/api.yml` (job environment only)
- The `CLAUDE.md` §7 API line, only if the local setup steps change (for example, new required `.env` variables)

### Out of scope (do NOT do)
- `admins`, `sessions` table, login, logout, password reset, the Rails authentication generator (Features 5 and 6)
- Any product endpoint, public or admin, and the per-endpoint limits other than the public tier (login, forgot password, contact, Cloudinary, admin)
- A production endpoint that exists only to test CSRF or rate limits; test endpoints live in the spec suite
- Anything in `apps/web`, `web.yml`, or workflow triggers and permissions
- Deployment configuration, the real Railway proxy ranges, Brakeman or bundler-audit in CI

## Requirements

### 1. Cookies and the session (D-016, D-039, D-079)
1. Add the cookie middleware and the cookie-store session middleware back into the API-mode stack, and include what `ApplicationController` needs to use cookies and forgery protection.
2. Session cookie: key `_tintara_session`, `httponly`, `same_site: :lax`, no `domain` (host-only), `secure` only in production. Set every attribute explicitly, even where it matches a Rails default, so the configuration documents itself.
3. Nothing else goes in the session. No `cookies.signed[:session_id]`; that is Feature 5.

### 2. CORS (D-039)
1. Add the `rack-cors` gem. Verify and pin its current version (D-055), and report it.
2. Allow exactly one origin, `FRONTEND_ORIGIN`, for `/api/*`, with `credentials: true`. Allow the methods the API will use (`GET`, `POST`, `PATCH`, `PUT`, `DELETE`, `OPTIONS`, `HEAD`) and the request headers `Content-Type`, `Accept` and `X-CSRF-Token`.
3. No wildcard origins, no regular expressions, no list of origins.

### 3. CSRF and the Origin check (D-039, D-079)
1. `GET /api/v1/csrf_token` returns `200` with `{ "csrf_token": "<token>" }` and nothing else. It is subject to the public `GET` tier (requirement 5).
2. Forgery protection raises on an invalid or missing token. The token is read from `X-CSRF-Token`. A failure renders 403 `invalid_csrf_token`.
3. **Origin check:** for every method other than `GET`, `HEAD` and `OPTIONS`, `Origin` must equal `FRONTEND_ORIGIN` exactly. A wrong or missing `Origin` renders 403 `invalid_origin`. The Origin check runs **before** token verification.
4. Rails' built-in `forgery_protection_origin_check` compares `Origin` with the API's own host, so it would reject every legitimate cross-origin request. Disable it, and explain in the chapter why the custom check replaces it.
5. **Keep forgery protection on in the test environment** (`config/environments/test.rb` currently turns it off). Add a spec helper that fetches a token from `/api/v1/csrf_token` and returns the headers a mutating request needs (`X-CSRF-Token` and `Origin`), so later features can use it in one line.

### 4. JSON errors (D-078)
1. One reusable way for any controller to render `{ "error": { "code", "message", "details"? } }` with a given status. `details` is omitted when it is empty.
2. Codes and statuses: `invalid_origin` 403, `invalid_csrf_token` 403, `rate_limited` 429, `bad_request` 400 (`ActionController::ParameterMissing`), `not_found` 404 (`ActiveRecord::RecordNotFound`, and any unknown path under `/api`). Messages are English sentences.
3. The `/api` catch-all returns 404 `not_found` for every method, before the Origin and token checks (an unknown path has nothing to protect). It must not swallow `/up`, `/api/v1/health`, or CORS preflight requests.
4. List every code, status and message in the report, so the API contract (D-051) can copy them.

### 5. Rate limits (D-029, D-045, D-080)
1. Build the mechanism once, so that each later task adds a D-029 limit with one declaration. Verify the current Rails 8.1 `rate_limit` options from the Rails source or guides (D-055), and use them rather than re-implementing counting.
2. Key: `request.remote_ip`. Store: `Rails.cache` (`config/environments/production.rb` already uses Solid Cache, D-052).
3. A blocked request gets 429 `rate_limited` in the D-078 shape, with `Retry-After` set to the window length in seconds.
4. **Public `GET` tier:** 120 requests per minute per IP. Apply it to `GET /api/v1/csrf_token` now. Feature 13 applies it to `/api/v1/public/...`.
5. **Internal-token exemption:** a request whose `X-Internal-Token` equals `API_INTERNAL_TOKEN`, compared with `ActiveSupport::SecurityUtils.secure_compare`, skips the public tier only. A wrong token is an ordinary request, not an error. An empty configured token never matches. The exemption must not be reusable by other tiers by accident.
6. `GET /api/v1/health` and `/up` are not rate limited.
7. **Test store:** replace `:null_store` in `config/environments/test.rb` with `:memory_store`, and clear the cache before every example in `spec/rails_helper.rb`, so no counter leaks between examples.

### 6. Trusted proxies (D-029, D-080)
1. Read `TRUSTED_PROXIES` (optional, comma-separated IPs or CIDRs) and **add** its entries to Rails' default trusted proxies. Don't replace the defaults. An unset or empty variable leaves the defaults unchanged.
2. An invalid entry fails loudly at boot, naming the bad value.

### 7. Configuration (D-080)
1. Read `FRONTEND_ORIGIN`, `API_INTERNAL_TOKEN` and `TRUSTED_PROXIES` once at boot, in one place that the rest of the code uses. Specs must be able to change the values without editing `ENV` in many places.
2. `FRONTEND_ORIGIN` and `API_INTERNAL_TOKEN` are required in every environment. A missing or blank value stops boot with a message naming the variable.
3. Root `.env.example`: document all three, with what each does and a safe placeholder. In development, `FRONTEND_ORIGIN=http://localhost:5173`, and `API_INTERNAL_TOKEN` must equal the value in `apps/web/.env`. Say so in the comment.
4. `.github/workflows/api.yml`: add test values for the two required variables to the job environment. Change nothing else in the workflow.
5. Check that `bin/rails db:prepare`, `bin/rails server` and the Dockerfile's build steps still work with the new boot checks. Report what you checked; don't change the Dockerfile unless the build actually breaks, and if it does, report it as a deviation.

## Specs to write first (D-050)
Commit these before the implementation, as request specs where possible. They will fail until the implementation lands; record the failing run and the SHA.
- **CORS:** a preflight from `FRONTEND_ORIGIN` gets `Access-Control-Allow-Origin` with that exact origin and `Access-Control-Allow-Credentials: true`, and allows `X-CSRF-Token`. A preflight from another origin gets no `Access-Control-Allow-Origin`.
- **Session cookie:** the `Set-Cookie` from `GET /api/v1/csrf_token` names `_tintara_session` with `HttpOnly` and `SameSite=Lax`, and no `Domain`. Prove the production `secure` setting with whatever the Rails test setup allows, and explain the method in the report.
- **CSRF token endpoint:** `200`, JSON, exactly one key `csrf_token`, a non-empty string.
- **Forgery protection,** against a test-only `POST` endpoint defined in the spec suite:
  - valid token + correct `Origin` → success
  - no token → 403 `invalid_csrf_token`
  - wrong token → 403 `invalid_csrf_token`
  - correct token + wrong `Origin` → 403 `invalid_origin`
  - correct token + missing `Origin` → 403 `invalid_origin`
  - a `GET` with no token and no `Origin` → not blocked
- **Errors:** an unknown `/api/v1/...` path → 404 `not_found`, for `GET` and for a `POST` with no token or `Origin`. A missing required parameter → 400 `bad_request`. A missing record → 404 `not_found`. Every error body has exactly the D-078 keys.
- **Rate limit,** on `GET /api/v1/csrf_token`:
  - 120 requests from one IP succeed, and the 121st gets 429 `rate_limited` with `Retry-After`
  - a second IP is not affected by the first IP's count
  - with a valid `X-Internal-Token`, request 121 still succeeds
  - with a wrong `X-Internal-Token`, request 121 is blocked
  - the counter does not leak into the next example
- **Not limited:** `GET /api/v1/health` succeeds past 120 requests.
- **Trusted proxies:** `X-Forwarded-For` from an untrusted peer does not change the rate-limit key. From a peer listed in `TRUSTED_PROXIES`, it does.
- **Configuration:** a missing `FRONTEND_ORIGIN` or `API_INTERNAL_TOKEN` raises with the variable's name, and an invalid `TRUSTED_PROXIES` entry raises with the bad value. Test the configuration code directly; don't boot a second Rails process.

The existing health specs must still pass unchanged.

## Acceptance criteria
- [ ] Every requirement above is implemented, and each has a spec that was committed first (SHAs in the report)
- [ ] `bundle exec rspec` and `bundle exec rubocop` pass locally, with outputs in the report
- [ ] All six required checks pass on the PR (`gh pr checks <PR>`)
- [ ] The `rack-cors` version is verified and pinned; the Rails `rate_limit` options used are cited from source or the guides
- [ ] Root `.env.example` documents the three variables; no `.env` or real token is committed
- [ ] `api.yml` changes only in its job environment
- [ ] The report lists every error code, status and message (D-078), and every environment variable with its rule
- [ ] Chapter 04 is written, reproducible from chapter 03's end state, and indexed in `handoff/learning/README.md`. It explains CORS vs CSRF vs SameSite (what each one stops, and why all three are needed here), why Rails' own origin check is disabled, and how the rate-limit specs avoid sharing counters
- [ ] PR opened with the exact title, report and chapter committed to the branch, not merged
- [ ] Nothing outside the scope was touched, in particular nothing in `apps/web` or `web.yml`
- [ ] Session ends on `main` (D-068)

## Verification commands (include outputs or summaries in the report)
```
cd apps/api && ruby -v && bin/rails -v && bundle exec rspec && bundle exec rubocop
bundle exec rails runner 'puts Rails.application.config.middleware.map(&:inspect)' | grep -nE 'Cors|Cookies|Session'
# with bin/rails server running and the root .env loaded:
curl -si -X OPTIONS http://localhost:3000/api/v1/csrf_token -H 'Origin: http://localhost:5173' -H 'Access-Control-Request-Method: POST' -H 'Access-Control-Request-Headers: x-csrf-token'
curl -si http://localhost:3000/api/v1/csrf_token -H 'Origin: http://localhost:5173'
curl -si -X POST http://localhost:3000/api/v1/does-not-exist
curl -si http://localhost:3000/api/v1/nope
cd ../.. && git status --porcelain --untracked-files=all
git log --oneline main..HEAD
git diff --stat main...HEAD -- apps/web .github/workflows/web.yml
gh pr view --json title,url,state && gh pr checks
```
`git diff --stat main...HEAD -- apps/web .github/workflows/web.yml` must be empty.

## Questions
If the current Rails 8.1 or `rack-cors` documentation contradicts anything in this prompt (for example, how `rate_limit` exposes the store, the `Retry-After` header or a skip condition, or how API mode restores cookies and sessions), follow the documentation, and record the conflict under "Questions for the owner". Never invent a configuration that you have not seen work. If a requirement would contradict D-078, D-079 or D-080, stop and ask instead of choosing.
