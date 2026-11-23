# Chapter 04 — The API security baseline: CORS, CSRF, rate limits and JSON errors

**Task:** Feature 4 · **Decisions:** D-016, D-029, D-031, D-039, D-045, D-050, D-052, D-055, D-078, D-079, D-080, D-081 · **Code:** PR [#3](https://github.com/Myepes05/tintara-lab/pull/3)

## 1. What we are building in this chapter

At the end of chapter 02 the API answered one request, `GET /api/v1/health`, and a browser on another origin could not usefully call it: there were no CORS headers, no cookies, no protection against forged requests and no limits. This chapter builds the security foundation that every later endpoint inherits, before any of those endpoints exist:

- a **session cookie** in API mode, with every attribute chosen deliberately;
- **CORS** for exactly one origin, the frontend;
- **CSRF protection**: a token endpoint, the `X-CSRF-Token` header, and an `Origin` check;
- **one JSON error format** for every error the API returns;
- **rate limits** per client IP, with an exemption for the web app's own server, and the client-IP handling that makes those limits impossible to dodge by sending fake headers.

No product endpoint is added. The only new public route is `GET /api/v1/csrf_token`. Feature 5 builds login on top of all of this.

Two problems turned up along the way that the plan did not foresee. Both are written up as they happened, because they are the most useful part of this chapter: `main` could not parse a JSON request body at all (step 5), and rack-cors quietly accepts a second header in place of `Origin` (section 7, trap 3).

## 2. What you need to know first

- **Origin.** The triple *scheme + host + port* of a URL: `http://localhost:5173` and `http://localhost:3000` are different origins. Browsers send it in the `Origin` request header on cross-origin requests and on every `POST`, `PUT`, `PATCH` and `DELETE`.
- **Site.** Looser than an origin: the *registrable domain* (`tintaralab.com`), ignoring subdomain and port (the scheme counts too). `tintaralab.com` and `api.tintaralab.com` are different origins but the **same site**, and so are `localhost:5173` and `localhost:3000`. This difference is the whole reason section 2's "three defences" below are all needed.
- **Cookie attributes.** `HttpOnly`: JavaScript can't read the cookie. `Secure`: the browser only sends it over HTTPS. `SameSite=Lax`: the browser leaves it off cross-*site* subrequests (a `fetch` or a form `POST` from another site) but still sends it on top-level `GET` navigations. No `Domain` attribute: the cookie is **host-only** and goes back only to the exact host that set it, never to sibling subdomains.
- **Same-origin policy and CORS.** By default a page's JavaScript can *send* a request to another origin but can't *read* the response. CORS (Cross-Origin Resource Sharing) is the server telling the browser which other origins may read its responses, through `Access-Control-Allow-*` headers. CORS never stops a request from reaching the server; it only decides whether the calling page may see the answer.
- **Preflight.** Before a "non-simple" cross-origin request (one with a custom header such as `X-CSRF-Token`, or a JSON body), the browser first sends an `OPTIONS` request asking whether the real one is allowed. If the answer doesn't allow it, the real request is never sent.
- **CSRF (cross-site request forgery).** A page the attacker controls makes the victim's browser send a request to our API. The browser attaches the victim's cookies automatically, so the API would think the victim asked for it. A **CSRF token** is a secret the API hands out and expects back in a header: a forged request can't include it, because the attacker's page can't read it.
- **Middleware.** In a Rack application such as Rails, a request passes through a stack of objects before reaching a controller, and the response goes back out through the same stack. Each one can look at or change the request (`env`, a hash of everything about it) or answer it directly. Order matters, and Rails lets you insert middleware at a precise position.
- **Reverse proxy, `REMOTE_ADDR` and `X-Forwarded-For`.** In production, a proxy (Railway's edge, Thruster inside our Docker image) receives the visitor's connection and opens a new one to Puma. Puma's `REMOTE_ADDR` is then the *proxy's* address, so the proxy reports the visitor's address in an `X-Forwarded-For` header, appending it to the end of the list. Anyone can send that header too.
- **Rate limit, fixed window.** Rails' `rate_limit` counts requests per key (by default the client IP) in a cache entry that expires after the window. The first request creates the entry with a lifetime of, say, 60 seconds; later requests increment it *without* extending that lifetime; once the count passes the limit, requests are refused until the entry expires.
- **Concern.** A Ruby module that a controller `include`s to receive methods, callbacks and class-level declarations (Rails' `ActiveSupport::Concern`). This chapter puts each security behaviour in its own concern, so `ApplicationController` reads as a list.

### Three defences, and why we need all three

| Defence | What it stops | What it doesn't stop |
|---|---|---|
| `SameSite=Lax` cookie | Another **site**'s page making the browser attach our cookie to a `POST` or a `fetch` | A page on the **same site**: any `*.tintaralab.com` subdomain, or any `localhost` port in development. `SameSite` compares sites, not origins |
| CORS for one origin | Any other origin **reading** our responses, so it can never read a CSRF token | Requests being **sent**: a plain HTML form `POST` from any page reaches the API without asking |
| CSRF token in `X-CSRF-Token`, plus the `Origin` check | Any request whose sender couldn't read a token, and any mutating request whose `Origin` isn't exactly the frontend | Nothing on its own if a token leaked, which is why the `Origin` check is a second, independent condition |

The frontend (`tintaralab.com`) and the API (`api.tintaralab.com`) are the same site by design (D-039), so `SameSite` alone protects nothing between subdomains. A page served from any other subdomain is same-site too: its requests would carry our cookie. CORS makes sure that page can't read a token; the token makes sure a request without one fails; and the `Origin` check fails the request even in the unlikely case where the attacker holds a valid cookie-and-token pair, for example their *own* session planted through a cookie set for the parent domain. Each layer covers a hole in the previous one.

## 3. Starting point

The repository as chapter 03 left it, with PR #2 merged and Feature 3's documentation commits on `main`. `apps/api` answers `/up` and `/api/v1/health`; `apps/web` is a server-rendered skeleton that calls nothing yet.

Run from the **repository root**:

```sh
git switch main
git status                         # clean
git pull
git switch -c feature/4-api-security-baseline

docker compose up -d
docker compose ps                  # db ... (healthy)

cd apps/api
bundle install
bin/rails db:prepare
bundle exec rspec                  # 5 examples, 0 failures
bundle exec rubocop                # 28 files inspected, no offenses detected
cd ../..
```

**New environment variables.** From this chapter on, the API refuses to boot without two variables (step 10 explains why). They live in the same root `.env` that holds the Postgres credentials. Append them now, with your own random token. This repository's `.env` is never committed:

```sh
cat >> .env <<EOF

FRONTEND_ORIGIN=http://localhost:5173
API_INTERNAL_TOKEN=$(openssl rand -hex 32)
TRUSTED_PROXIES=
EOF
```

When the web app starts calling the API (Phase 4), `apps/web/.env` must carry the **same** `API_INTERNAL_TOKEN`. If you would rather not touch `.env` while following along, export the two variables in your shell instead: dotenv never overwrites a variable that is already set (chapter 02, step 3).

Steps 1 to 14 run from `apps/api`; step 10 also edits three files at the repository root, by their paths. Step 15 runs from the repository root.

## 4. Step by step

### Step 1 — Read the framework source before designing anything

The decisions behind this chapter (D-078 to D-081) were written by reading the installed gems' source, and so was this step. Every design choice below rests on a line of Rails, Rack, Puma, Solid Cache or rack-cors code, so find them yourself:

```sh
cd apps/api
A=$(bundle show actionpack)/lib
cat $A/action_controller/metal/rate_limiting.rb             # rate_limit and its options
cat $A/action_dispatch/middleware/remote_ip.rb               # how request.remote_ip is chosen
grep -v '^\s*#' $A/action_controller/metal/request_forgery_protection.rb
cat $(bundle show railties)/lib/rails/application/default_middleware_stack.rb
```

What they show, and what each finding changed:

- **`rate_limit`** (Rails 8.1.3.1) is one line:
  ```ruby
  def rate_limit(to:, within:, by: -> { request.remote_ip }, with: -> { raise TooManyRequests }, store: cache_store, name: nil, scope: nil, **options)
    before_action -> { rate_limiting(to: to, within: within, by: by, with: with, store: store, name: name, scope: scope || controller_path) }, **options
  end
  ```
  and the counter's key is `["rate-limit", scope, name, by].compact.join(":")`. Two consequences. The default scope is `controller_path`, so two controllers would each give an IP its own 120 requests: our tiers pass an explicit `scope:` (D-081). And `**options` goes straight to `before_action`, so `only:`, `if:` and `unless:` work, which is how the internal-token exemption is expressed. Nothing has to be re-implemented.
- **`ActionDispatch::RemoteIp`** takes `X-Forwarded-For`, `Client-IP` and `Forwarded` from **any** peer. Its comment says so in capitals: `IF YOU DON'T USE A PROXY, THIS MAKES YOU VULNERABLE TO IP SPOOFING`. `trusted_proxies` only decides which addresses are skipped *inside* those headers. That is why step 7 adds a middleware in front of it.
- **Rails' own origin check** is `request.origin.nil? || request.origin == request.base_url`, which compares `Origin` with the API's own URL. Our frontend's `Origin` can never equal it, and a missing `Origin` passes, which D-079 forbids. It is switched off and replaced (step 8).
- **`request_authenticity_tokens`** returns `[form_authenticity_param, request.x_csrf_token]`: Rails also accepts the token from an `authenticity_token` parameter. D-079 says the header, so step 8 overrides it.
- **The default middleware stack** adds `ActionDispatch::Cookies` and the session store only `unless config.api_only`. API mode has to put them back itself (step 6).

Two more findings came from running code rather than reading it, and both are in section 7. Rails' `config.action_controller` settings don't reach `ActionController::API` (trap 2), and rack-cors copies `X-Origin` into `Origin` (trap 3).

### Step 2 — Verify the one new gem

```sh
gem search '^rack-cors$' --remote --all     # rack-cors (3.0.0, 2.0.2, ...)
curl -s https://rubygems.org/api/v1/versions/rack-cors.json | head -c 400
```

rack-cors 3.0.0 (published 2025-05-16, requires Rack >= 3.0.14) is the current release. Its source was unpacked into a scratch directory and read before writing any configuration (`gem fetch rack-cors -v 3.0.0 && gem unpack rack-cors-3.0.0.gem`). That reading found traps 3 and 4 in section 7.

### Step 3 — Write the specs first, and watch them fail

Every behaviour gets a spec before any implementation (D-042, D-050). The specs are long because security specs have to prove what is refused, not only what is allowed. Their full content is in section 5; create these files with it:

| File | What it proves |
|---|---|
| `spec/support/security_helpers.rb` | Helpers: `csrf_headers`, `get_from(ip)`, `exhaust_public_limit`, `expect_error`, `use_api_security` |
| `spec/support/test_endpoints.rb` | Test-only controllers and routes, drawn inside the spec suite |
| `spec/support/time_helpers.rb` | `freeze_time` and `travel` in specs |
| `spec/requests/api/cors_spec.rb` | Preflights and actual responses, the exact-origin rule, `Retry-After` exposed |
| `spec/requests/api/v1/csrf_token_spec.rb` | The token endpoint and the session cookie's attributes |
| `spec/requests/api/forgery_protection_spec.rb` | Token and `Origin` rules on a test-only endpoint, for every mutating verb |
| `spec/requests/api/errors_spec.rb` | The D-078 shape, the `/api` catch-all, 400 and 404 |
| `spec/requests/api/rate_limit_spec.rb` | 120/minute, the window, the exemption, shared scopes, unlimited endpoints |
| `spec/requests/api/client_ip_spec.rb` | Spoofed headers from untrusted and trusted peers |
| `spec/lib/api_security/configuration_spec.rb` | Boot-time variables and their errors |
| `spec/lib/api_security/session_cookie_spec.rb` | The production `Secure` attribute, without a production boot |

And one line in `spec/rails_helper.rb`, inside `RSpec.configure`, right after `config.use_transactional_fixtures = true`:

```ruby
  # Rate-limit counters live in the cache, so every example starts with an empty
  # one (D-080). Transactional fixtures do not roll back a cache.
  config.before { Rails.cache.clear }
```

Four design points in the spec support files:

- **Test endpoints live in the spec suite, never in `config/routes.rb`** (the prompt forbids production endpoints that exist only for tests). `draw_test_routes` appends routes to the real route set for one example, and `reload_routes!` removes them afterwards. They sit under `/test/...`, not `/api/...`, because appended routes come *after* the `/api` catch-all, which would answer first. The protections under test belong to `ApplicationController`, so the path doesn't matter to them.
- **Test controllers are created per example** with `stub_const("Name", Class.new(ApplicationController) { ... })`. If they were plain classes in `spec/support`, the red run would crash while *loading* the suite (they call `limit_public_get_requests`, which doesn't exist yet), and a suite that can't load proves nothing about which behaviours are missing.
- **`REMOTE_ADDR` is set explicitly** with documentation addresses (`203.0.113.10`, `198.51.100.7`, RFC 5737). A request spec's default peer is `127.0.0.1`, which is in Rails' trusted proxies: specs using it would trust any `X-Forwarded-For` and pass while the spoofing bug was wide open.
- **`exhaust_public_limit` checks every one of its 120 responses inside the loop.** The first version collected the statuses and checked them at the end. Against the unimplemented app, each of 120 requests rendered Rails' 67 KB HTML debug page for a 404, in about 40 examples, and the red run had not finished after two minutes. Checking inside the loop fails at request 1, and the whole red run took 11.7 seconds.

Run it, from `apps/api`, with the two variables from section 3 available:

```sh
bundle exec rspec
```

```
138 examples, 115 failures
```

Read the failures, not only the count; a spec that fails for the wrong reason is as useless as one that passes. They were: `uninitialized constant ApiSecurity` (32, the configuration code doesn't exist), `expected ... :forbidden (403) but it was :ok (200)` (14, no Origin or token check), `request 1 got 404` (13, no `/api/v1/csrf_token`), `undefined local variable or method 'limit_public_get_requests'` (5), and `IpSpoofAttackError` raised from conflicting headers (2), among others. The 23 that already passed were all expected to: the five health specs, the "a GET is not blocked" cases, the `/up` and health "not limited" cases, and preflights from foreign origins (with no CORS at all, nothing is allowed).

```sh
git add spec/rails_helper.rb spec/lib/api_security spec/requests/api \
  spec/support/security_helpers.rb spec/support/test_endpoints.rb spec/support/time_helpers.rb
git commit -m "Feature 4: add specs for the API security baseline"
```

### Step 4 — Add rack-cors

In `apps/api/Gemfile`, the generator left a commented line; replace it:

```ruby
# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem "rack-cors", "~> 3.0"
```

```sh
bundle install      # adds rack-cors (3.0.0) to Gemfile.lock
```

### Step 5 — The bug that was already on `main`: JSON bodies and encrypted cookies

Do this step before the implementation, as it is written here. It is where the problem was found, but not when: with the implementation in place (steps 6 to 10), 26 specs still failed with the same error:

```
ArgumentError:
  wrong number of arguments (given 2, expected 1)
# .../json-3.0.2/lib/json/common.rb:296:in 'parse'
# .../activesupport-8.1.3.1/lib/active_support/json/decoding.rb:25:in 'ActiveSupport::JSON.decode'
# .../activesupport-8.1.3.1/lib/active_support/messages/metadata.rb:129:in '...deserialize_from_json'
```

`bundle exec rspec -b` (full backtraces) is what found it: without `-b`, RSpec filters gem frames out and the error seemed to come from `form_authenticity_token`. The cause:

- `Gemfile.lock` on `main` already had **json 3.0.2**, released on 2026-09-07, eight days before Feature 2 generated the app.
- Rails 8.1.3.1 calls `::JSON.parse(json, options)`, passing the options as a positional hash. json 3.0 accepts keyword arguments only.
- `ActiveSupport::JSON.decode` therefore raises on every call. It is what decodes a JSON request body, and what reads every signed or encrypted cookie, the session included.

Nothing on `main` had exercised either path yet: the health endpoint reads no body and sets no cookie. A clean export of `main` proved the bug was not introduced by this feature:

```
{rails: "8.1.3.1", json: "3.0.2"}
{decode: #<ArgumentError: wrong number of arguments (given 2, expected 1)>}
{json_body: #<ActionDispatch::Http::Parameters::ParseError: ...>, cause: #<ArgumentError: ...>}
{encrypted_cookie: #<ArgumentError: wrong number of arguments (given 2, expected 1)>}
```

Rails fixed it upstream on `8-1-stable` ("Merge pull request #58601 from Earlopain/json-3.0-compat") and shipped the fix in 8.1.4. Two ways out:

1. **Upgrade Rails** to 8.1.4.1: the real fix, but a framework upgrade inside a feature that didn't ask for one.
2. **Hold json below 3**: one transitive gem, nothing else changes. json 2.21.2 is the newest 2.x and is past every json advisory in `bundler-audit`'s database (the newest is patched at `>= 2.21.2`).

This feature takes option 2 and leaves the upgrade to the owner (see section 9). Spec first, as always. The new file is `spec/requests/api/json_body_spec.rb` (section 5):

```sh
bundle exec rspec spec/requests/api/json_body_spec.rb      # 2 examples, 2 failures
git add spec/requests/api/json_body_spec.rb
git commit -m "Feature 4: add specs for JSON decoding, broken by json 3 on Rails 8.1.3.1"
```

Then the pin, in `Gemfile`, below rack-cors:

```ruby
# json 3 breaks ActiveSupport::JSON.decode in Rails 8.1.3.1, and with it JSON
# request bodies and encrypted cookies. Rails 8.1.4 fixes that: remove this
# line when upgrading to it (spec/requests/api/json_body_spec.rb guards it).
gem "json", "~> 2.21", ">= 2.21.2"
```

```sh
bundle update json --conservative     # Note: json version regressed from 3.0.2 to 2.21.2
```

`--conservative` updates json alone and leaves its neighbours where they are. After the pin, the encrypted-cookie example still failed, now with `got: nil`. The spec was wrong, not the code: `jar.encrypted[:example] = { "stored" => true }` treats a Hash as the cookie's *options* and stores no value. Write `{ value: { "stored" => true } }`. That correction was committed on its own, still before the implementation, and the spec was re-run against a clean export of that commit with json 3 to make sure it still failed for the right reason.

### Step 6 — The boot-time module: `lib/api_security`

Everything that must exist while the application boots lives in `lib/api_security/`: the configuration, the session cookie options, the trusted-proxy list and two middleware. Files are in section 5:

- `lib/api_security.rb` defines the module and `ApiSecurity.config`;
- `lib/api_security/configuration.rb` reads and validates the variables;
- `lib/api_security/session_cookie.rb` holds the cookie options;
- `lib/api_security/trusted_proxies.rb` is the single trusted list;
- `lib/api_security/client_ip_sanitizer.rb` and `lib/api_security/x_origin_remover.rb` are the middleware.

**Why `lib/` and a manual `require`, not autoloading.** `config/application.rb` needs these classes while it is still configuring the app, before Rails' autoloader (Zeitwerk) is set up. Middleware are also built once and kept, so they must never be reloaded in development. The Rails guides' advice for that case is to keep them out of the autoloaded paths. So `config/application.rb` does `require_relative "../lib/api_security"` and tells `autoload_lib` to ignore both `api_security.rb` and the `api_security/` directory.

### Step 7 — Wire it into `config/application.rb`

Below the dotenv block, add `require_relative "../lib/api_security"`. In the `autoload_lib` line, add the two ignored paths. Then, after `config.api_only = true`:

```ruby
    # Read once, and stop the boot if a required variable is missing (D-080).
    # dotenv has already loaded the root .env by the time this line runs.
    ApiSecurity.config = ApiSecurity::Configuration.from_env(ENV)

    # API mode leaves cookies and the session out; put them back (D-079).
    config.session_store :cookie_store, **ApiSecurity::SessionCookie.options(Rails.env)
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use config.session_store, config.session_options

    # Client IP (D-081): one trusted list, used by RemoteIp and by the middleware
    # that removes spoofable forwarding headers in front of it.
    config.action_dispatch.trusted_proxies = ApiSecurity::TrustedProxies
    config.middleware.insert_before ActionDispatch::RemoteIp,
                                    ApiSecurity::ClientIpSanitizer,
                                    ApiSecurity::TrustedProxies
```

- **Why this position works for dotenv.** dotenv loads the root `.env` in a hook that runs when `class Application < Rails::Application` is *defined*, which happens before the body executes (chapter 02, trap 7). By the line that reads `ENV`, the file is loaded.
- **Why `TrustedProxies` is an object, not an array.** Both `RemoteIp` and the sanitizer receive the same object, and it reads `ApiSecurity.config.trusted_proxies` on each call. That gives one list built in one place, and specs can swap it with one stub (`use_api_security(trusted_proxies: "192.0.2.0/24")`) that both middleware see. `RemoteIp` only requires its argument to respond to `any?`, which `extend Enumerable` provides.
- **Setting `trusted_proxies` replaces Rails' list.** `RemoteIp`'s own error message says so: "Note that passing an enumerable will *replace* the default set of trusted proxies". So `Configuration` starts from `ActionDispatch::RemoteIp::TRUSTED_PROXIES` and appends the `TRUSTED_PROXIES` entries.

### Step 8 — CORS, the `/api` catch-all and the controllers

`config/initializers/cors.rb` replaces the generator's commented example (file in section 5). Then three concerns in `app/controllers/concerns/`: `json_errors.rb`, `request_protection.rb` and `rate_limit_tiers.rb`. Two controllers: `app/controllers/api/errors_controller.rb` and `app/controllers/api/v1/csrf_tokens_controller.rb`. `ApplicationController` becomes:

```ruby
class ApplicationController < ActionController::API
  include ActionController::Cookies
  include JsonErrors
  include RequestProtection
  include RateLimitTiers
end
```

`ActionController::Cookies` and `ActionController::RequestForgeryProtection` are two of the modules that `ActionController::API` leaves out of `ActionController::Base`. Each is included explicitly, and `RequestProtection` includes the second one itself.

In `config/routes.rb`, add the token route inside the `v1` namespace and the catch-all **after** the namespace:

```ruby
      get "csrf_token", to: "csrf_tokens#show"
```

```ruby
  # Any other path or method under /api is a JSON 404 (D-078). Keep this below
  # every /api route: the first match wins.
  match "api(/*unmatched)", to: "api/errors#not_found", via: :all, format: false
```

- `via: :all` makes the route match every HTTP method, so `POST /api/v1/health` is a 404 too, not a 405 HTML page.
- `api(/*unmatched)` covers both `/api` itself and anything below it. `format: false` stops Rails from splitting `.json` off as a format, so `/api/v1/nope.json` is caught as well.
- `Api::ErrorsController` inherits `ActionController::API`, **not** `ApplicationController`: an unknown path has nothing to protect, so it runs no Origin check, no token check and no rate limit, and it never creates a session.

### Step 9 — The test environment

In `config/environments/test.rb`, replace `config.cache_store = :null_store` (a store that remembers nothing, so every rate limit is a no-op) with:

```ruby
  # A store that really counts, for rate-limit specs (D-080). rails_helper
  # clears it before every example.
  config.cache_store = :memory_store
```

And the forgery-protection line becomes:

```ruby
  # Forgery protection stays on in tests (D-079): specs send a real token with
  # the csrf_headers helper. This line only reaches ActionController::Base; for
  # the API's controllers, RequestProtection turns it on.
  config.action_controller.allow_forgery_protection = true
```

The comment is not decoration: section 7, trap 2, shows that this setting never reached our controllers, even when it said `false`.

### Step 10 — Documentation and CI

- **Root `.env.example`**: the three variables, with a comment each (file in section 5).
- **`.github/workflows/api.yml`**: the `test` job's `env:` gains two test values, and nothing else in the workflow changes at this step:
  ```yaml
      # Required at boot (D-080). Test values, not secrets.
      FRONTEND_ORIGIN: http://localhost:5173
      API_INTERNAL_TOKEN: tintara_ci_internal_token
  ```
  The `lint` job needs nothing: RuboCop reads files and never boots Rails.
- **Later, `runs-on: ubuntu-24.04` for both API jobs** (step 15, and section 7, trap 17). The prompt asked for no other workflow change. This one became necessary only after the PR was opened, and the owner chose it.
- **`CLAUDE.md` §7**, API line: one sentence saying the API won't boot without the two variables in the root `.env`.

**Why the boot fails instead of falling back to a default.** A missing `FRONTEND_ORIGIN` with a default would mean CORS and the Origin check quietly trusting a value nobody chose. A missing `API_INTERNAL_TOKEN` with an empty default would mean either nobody is exempt (the site throttles itself, D-045) or, with a careless comparison, *everybody* is. A loud failure at boot costs one minute of setup and can't reach production unnoticed. The web app's `server-config.server.ts` follows the same rule (chapter 03).

### Step 11 — Run everything, then commit in two pieces

From `apps/api`:

```sh
bundle exec rspec                     # 140 examples, 0 failures
bundle exec rspec --order rand        # 140 examples, 0 failures  (Randomized with seed 13396)
CI=1 bundle exec rspec                # 140 examples, 0 failures  (eager loading, as in CI)
bundle exec rubocop                   # 51 files inspected, no offenses detected
```

`CI=1` matters: `config/environments/test.rb` eager-loads the whole app only when `CI` is set, so a constant that only loads lazily on your machine would break in CI first.

The json pin went into its own commit, so it can be reverted alone when Rails is upgraded. Because `Gemfile` and `Gemfile.lock` also contain the rack-cors lines, that commit was staged from a temporary copy of both files without them (`git update-index --cacheinfo` with a blob from `git hash-object -w`). `git add -p apps/api/Gemfile apps/api/Gemfile.lock`, accepting only the json hunks, gets the same result interactively. Then everything else went into the implementation commit, staged by explicit paths (run from the repository root):

```sh
git commit -m "Feature 4: fix JSON decoding by holding json below 3 until Rails 8.1.4"   # after staging the json hunks
git add .env.example .github/workflows/api.yml CLAUDE.md apps/api/Gemfile apps/api/Gemfile.lock \
  apps/api/app/controllers apps/api/config/application.rb apps/api/config/environments/test.rb \
  apps/api/config/initializers/cors.rb apps/api/config/routes.rb apps/api/lib/api_security.rb apps/api/lib/api_security
git status --short --untracked-files=all     # nothing left unstaged
git commit -m "Feature 4: implement the API security baseline"
```

The branch then reads, newest first:

```
2a9cb97 Feature 4: implement the API security baseline
1b9de3e Feature 4: fix JSON decoding by holding json below 3 until Rails 8.1.4
783b644 Feature 4: correct the encrypted cookie spec to pass the value as an option
0ed2df0 Feature 4: add specs for JSON decoding, broken by json 3 on Rails 8.1.3.1
5d7081a Feature 4: add specs for the API security baseline
```

### Step 12 — Prove the specs would catch a regression

A green suite proves the code satisfies the specs, not that the specs are strict. So the code was broken on purpose, one change at a time, on a scratch copy of `apps/api`, running `bundle exec rspec --fail-fast` after each. Thirty mutations, among them: removing the `X-Origin` middleware, keeping `Client-IP` or `Forwarded`, trusting every peer, replacing Rails' default proxies instead of extending them, giving `RemoteIp` its own list, dropping the shared `scope:`, removing the internal-token exemption, letting an empty token match, limiting `POST`s in the GET tier, dropping `Retry-After` or its CORS exposure, allowing any origin, using the string path `"/api/*"`, accepting a missing `Origin`, checking the token before the `Origin`, turning Rails' origin check back on, accepting the token from a parameter, checking `OPTIONS`, keeping empty `details`, making the catch-all inherit `ApplicationController`, going back to `:null_store`, not clearing the cache between examples, and changing the cookie's attributes. **Every one of the thirty made at least one spec fail.** The script is in the Feature 4 report. If you change these files later, re-run something like it.

### Step 13 — Check it by hand

With Postgres running and the two variables set (section 3):

```sh
bin/rails db:prepare                       # still works with the boot checks
bin/rails server
```

In a second terminal:

```sh
curl -si -X OPTIONS http://localhost:3000/api/v1/csrf_token -H 'Origin: http://localhost:5173' \
  -H 'Access-Control-Request-Method: POST' -H 'Access-Control-Request-Headers: x-csrf-token'
```

```
HTTP/1.1 200 OK
access-control-allow-origin: http://localhost:5173
access-control-allow-methods: GET, POST, PATCH, PUT, DELETE, OPTIONS, HEAD
access-control-expose-headers: Retry-After
access-control-max-age: 7200
access-control-allow-credentials: true
access-control-allow-headers: x-csrf-token
```

```sh
curl -si http://localhost:3000/api/v1/csrf_token -H 'Origin: http://localhost:5173'
```

```
HTTP/1.1 200 OK
access-control-allow-origin: http://localhost:5173
...
set-cookie: _tintara_session=...; path=/; httponly; samesite=lax

{"csrf_token":"Pciyp3D7dkznmIuhfUp79nUsXiwzeiBtViVPOnoiqcExPjl74vGIFrt527i6lg3zZLOfXdcK0LumTqixwIQthQ"}
```

No `secure` in development: the browser would refuse to send a `Secure` cookie to `http://localhost`.

```sh
curl -si -X POST http://localhost:3000/api/v1/does-not-exist
curl -si http://localhost:3000/api/v1/nope
```

Both answer `404` with `{"error":{"code":"not_found","message":"The requested resource was not found."}}`. The `POST` carries no token and no `Origin`, and still gets a 404 rather than a 403: the catch-all runs no checks.

The middleware order:

```sh
bundle exec rails runner 'puts Rails.application.config.middleware.map(&:inspect)' | cat -n
```

```
     1	ApiSecurity::XOriginRemover
     2	Rack::Cors
     ...
    11	ApiSecurity::ClientIpSanitizer
    12	ActionDispatch::RemoteIp
     ...
    23	ActionDispatch::Cookies
    24	ActionDispatch::Session::CookieStore
```

Finally, the rate limit. `curl` connects from `127.0.0.1`, a trusted proxy, so here `X-Forwarded-For` does set the key. That is correct behaviour, and it lets you test as a "visitor":

```sh
for i in {1..121}; do curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'X-Forwarded-For: 198.51.100.50' http://localhost:3000/api/v1/csrf_token; done | sort | uniq -c
#  120 200
#    1 429
```

The 429 carries `retry-after: 60` and the D-078 body `{"error":{"code":"rate_limited","message":"Too many requests. Try again later."}}`. Stop the server with Ctrl-C.

### Step 14 — The Dockerfile and a production boot

The prompt asks whether the new boot checks break the Dockerfile. They can't break the *build*: its steps are `bundle install` and two `bootsnap precompile` runs, and none of them boots Rails. Both bootsnap steps were run on a clean export of the branch with neither variable set, and both exited 0:

```sh
env -u FRONTEND_ORIGIN -u API_INTERNAL_TOKEN bundle exec bootsnap precompile -j 1 --gemfile
env -u FRONTEND_ORIGIN -u API_INTERNAL_TOKEN bundle exec bootsnap precompile -j 1 app/ lib/
```

The *container* is a different matter: `bin/docker-entrypoint` runs `bin/rails db:prepare` before the server, and that boots the app, so a container started without the variables stops at once with `ApiSecurity::ConfigurationError: FRONTEND_ORIGIN is missing or blank`. That is the intended behaviour, and the hosting platform must set both variables.

A full `docker build` was attempted and couldn't run on this machine: every image pull, even the Dockerfile's 1 MB frontend image, hung behind Docker Desktop's proxy (`http.docker.internal:3128`), while the registry itself answered `curl`. So the production behaviour was checked without the container. On a clean export, against a throwaway database (`tintara_f4_verify_prod`, dropped afterwards), with `RAILS_ENV=production`, a random `SECRET_KEY_BASE` and the two variables:

```sh
bin/rails db:prepare
bin/rails server -p 3001
curl -si http://localhost:3001/api/v1/csrf_token -H 'Origin: https://www.example.test'
```

```
HTTP/1.1 200 OK
access-control-allow-origin: https://www.example.test
set-cookie: _tintara_session=...; path=/; secure; httponly; samesite=lax
```

This time the cookie is `secure`. And 121 requests produced `120 200` and `1 429`, with `retry-after: 60`, counted by the real `SolidCache::Store` in Postgres. The production store and the test store agree.

### Step 15 — Push and open the pull request (repository root)

```sh
git push -u origin feature/4-api-security-baseline
gh pr create --base main \
  --title "Feature 4: add the API security baseline with CORS, CSRF, rate limits and JSON errors" \
  --body-file <your filled copy of .github/pull_request_template.md>
gh pr checks <number> --watch
git switch main        # D-068: leave the shared checkout on main
```

All six required checks must pass before the owner can merge (D-070). Only the owner merges.

The first run failed, and not because of this chapter's code. `API RuboCop` and `API RSpec` both stopped in "Set up Ruby" with `Error: Unavailable version 3.4.3 for ruby on ubuntu-26.04`. GitHub had moved `ubuntu-latest` to Ubuntu 26.04 after `main`'s last API run (2026-10-23), and `ruby/setup-ruby` installs prebuilt Rubies: the builder's release lists `ruby-3.4.3-ubuntu-22.04` and `ruby-3.4.3-ubuntu-24.04`, nothing for 26.04. You can check it yourself:

```sh
gh run view <run id> --log-failed | grep -i error
gh api repos/ruby/ruby-builder/releases/tags/toolcache \
  --jq '[.assets[].name | select(startswith("ruby-3.4.3-ubuntu"))]'
```

The options were to pin the runner image or to change the Ruby version that D-028 fixes. The owner chose the runner. Both API jobs now say `runs-on: ubuntu-24.04` (with a comment), in a commit of its own (`2652c4e`). The next run passed all six checks: `140 examples, 0 failures` and `51 files inspected, no offenses detected` on `Image: ubuntu-24.04`.

## 5. The important files, explained

### `lib/api_security/configuration.rb`

```ruby
require "ipaddr"

module ApiSecurity
  # The security settings that come from the environment (D-080).
  class Configuration
    def self.from_env(env)
      new(
        frontend_origin: required(env, "FRONTEND_ORIGIN"),
        internal_token: required(env, "API_INTERNAL_TOKEN"),
        trusted_proxies: env["TRUSTED_PROXIES"]
      )
    end

    def self.required(env, name)
      value = env[name]
      return value if value.present?

      raise ConfigurationError, "#{name} is missing or blank. Set it in the environment " \
                                "(in development, the repository-root .env; see .env.example)."
    end
    private_class_method :required

    attr_reader :frontend_origin, :internal_token, :trusted_proxies

    def initialize(frontend_origin:, internal_token:, trusted_proxies:)
      @frontend_origin = frontend_origin
      @internal_token = internal_token
      # Setting trusted proxies replaces Rails' list, so start from that list.
      @trusted_proxies = (ActionDispatch::RemoteIp::TRUSTED_PROXIES + parse_proxies(trusted_proxies)).freeze
    end

    # An empty configured token never matches, not even an empty header (D-080).
    def internal_token_matches?(candidate)
      return false if internal_token.blank? || candidate.nil?

      ActiveSupport::SecurityUtils.secure_compare(candidate, internal_token)
    end

    # The default inspect would print the token into logs and error reports.
    def inspect
      "#<#{self.class.name} frontend_origin=#{frontend_origin.inspect}>"
    end

    private
      def parse_proxies(list)
        list.to_s.split(",").map(&:strip).reject(&:empty?).map { |entry| parse_proxy(entry) }
      end

      def parse_proxy(entry)
        IPAddr.new(entry)
      rescue IPAddr::Error
        raise ConfigurationError, "TRUSTED_PROXIES contains #{entry.inspect}, which is not an IP address or CIDR."
      end
  end
end
```

- **`from_env(env)` takes the environment as an argument** instead of reading `ENV` inside, so the specs pass a plain Hash and never touch the real environment. That is the prompt's "test the configuration code directly; don't boot a second Rails process".
- **`present?`** rejects `nil`, `""` and `"  "` alike, so a variable left empty in `.env` also stops the boot.
- **The error messages name the variable or the bad value**, never the token.
- **`IPAddr::Error`** is the parent of `InvalidAddressError` and `InvalidPrefixError`, so `"proxy.example.test"`, `"999.0.0.1"` and `"192.0.2.0/33"` all end up in the same message.
- **`internal_token_matches?`** uses `secure_compare`, which takes the same time whether the first byte or the last one differs, so an attacker can't guess the token byte by byte from response times. It still leaks the token's *length*, which a 64-character random value makes harmless. The `blank?` guard means an empty configured token never matches, even an empty header.
- **`inspect` is overridden.** Ruby's default `inspect` prints every instance variable, and objects get inspected in error pages, logs and error-tracking reports. The spec "keeps the token out of inspect" guards it.

### `lib/api_security/trusted_proxies.rb` and `lib/api_security/client_ip_sanitizer.rb`

```ruby
require "ipaddr"

module ApiSecurity
  # The one trusted list (D-081): Rails' defaults plus TRUSTED_PROXIES. Both
  # ClientIpSanitizer and ActionDispatch::RemoteIp read it through this object.
  module TrustedProxies
    extend Enumerable

    def self.each(&)
      ApiSecurity.config.trusted_proxies.each(&)
    end

    # True only for a single, parsable IP address inside the list.
    def self.trust?(address)
      address = address.to_s
      return false if address.include?("/") # a range is not a peer

      ip = IPAddr.new(address)
      any? { |proxy| proxy.include?(ip) }
    rescue IPAddr::Error
      false
    end
  end
end
```

```ruby
module ApiSecurity
  # Runs before ActionDispatch::RemoteIp, which believes forwarding headers from
  # any peer (D-081). After this, the only one left is an X-Forwarded-For that
  # a trusted peer sent, so request.remote_ip is safe as a rate-limit key.
  class ClientIpSanitizer
    def initialize(app, trusted_proxies)
      @app = app
      @trusted_proxies = trusted_proxies
    end

    def call(env)
      env.delete("HTTP_CLIENT_IP")
      env.delete("HTTP_FORWARDED")
      env.delete("HTTP_X_FORWARDED_FOR") unless @trusted_proxies.trust?(env["REMOTE_ADDR"])

      @app.call(env)
    end
  end
end
```

**Why `trusted_proxies` alone doesn't stop spoofing.** `RemoteIp` builds a list from the headers, appends `REMOTE_ADDR`, removes every trusted address and takes the rightmost one left. Suppose a client connects directly from `203.0.113.10` (an untrusted address) and sends `X-Forwarded-For: 198.51.100.1`. The list is `[198.51.100.1, 203.0.113.10]`, nothing is trusted, so the result is `198.51.100.1`, a value the client chose. Sending a different value on every request gives a fresh rate-limit counter each time. D-081's prototype got 1,000 of 1,000 extra requests through that way. `trusted_proxies` never enters into it: it says which addresses to skip in the list, not who may send the list.

The sanitizer fixes it in front of `RemoteIp`:

- `Client-IP` and `Forwarded` are always removed. No proxy we use sets them. Rack *prefers* `Forwarded` over `X-Forwarded-For`, so leaving it would let a client override the address that a real proxy appended. Mixing `Client-IP` and `X-Forwarded-For` makes `RemoteIp` raise `IpSpoofAttackError`, which is a 500.
- `X-Forwarded-For` survives only if the immediate peer is a trusted proxy. Then the proxy has appended the real address at the end, and `RemoteIp` walks the list from the right, skipping trusted addresses, so a forged entry on the left is never reached.
- `trust?` refuses anything that isn't a single valid address. `IPAddr#include?` *raises* on a string like `"not-an-ip"`, and a range such as `"10.0.0.0/8"` is not a peer. So a blank or broken `REMOTE_ADDR` counts as untrusted.

### `lib/api_security/x_origin_remover.rb` and `lib/api_security/session_cookie.rb`

```ruby
module ApiSecurity
  # rack-cors 3.0.0 copies X-Origin into Origin when Origin is missing, which
  # would let a request without Origin pass the Origin check (D-079). The header
  # has to be gone before Rack::Cors runs.
  class XOriginRemover
    def initialize(app)
      @app = app
    end

    def call(env)
      env.delete("HTTP_X_ORIGIN")

      @app.call(env)
    end
  end
end
```

```ruby
module ApiSecurity
  # The session cookie's attributes (D-079). Each is written out, even where it
  # equals a default.
  module SessionCookie
    def self.options(environment)
      {
        key: "_tintara_session",
        path: "/",
        domain: nil, # host-only: never sent to another subdomain
        httponly: true,
        same_site: :lax,
        secure: environment.to_s == "production"
      }
    end
  end
end
```

`secure` is `true` only in production. The `Set-Cookie` in development and test has no `Secure`, and that is a spec: a `Secure` cookie on `http://localhost` would never be sent back, and every token check would fail. The production value is proved in `session_cookie_spec.rb` by building Rails' real `Cookies` and `CookieStore` middleware from `options("production")` and reading the `Set-Cookie` they write for an HTTPS request. That is as close to production as the test environment allows.

### `lib/api_security.rb`

```ruby
# The API security baseline that has to exist at boot (D-078 to D-081).
#
# config/application.rb requires this file by hand and Zeitwerk ignores it:
# middleware and boot configuration must never be reloaded.
module ApiSecurity
  class ConfigurationError < StandardError; end

  class << self
    # Set once at boot, in config/application.rb. Everything else reads it from
    # here, so a spec can replace it in one place.
    attr_accessor :config
  end
end

require_relative "api_security/configuration"
require_relative "api_security/session_cookie"
require_relative "api_security/trusted_proxies"
require_relative "api_security/client_ip_sanitizer"
require_relative "api_security/x_origin_remover"
```

### `config/initializers/cors.rb`

```ruby
# Be sure to restart your server when you modify this file.

# Cross-Origin Resource Sharing for the one frontend (D-039, D-081).
# https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # A comparison, not a string: rack-cors turns a string without a scheme into
    # a regular expression and "*" into a wildcard. This is always exact equality.
    origins { |origin, _env| origin == ApiSecurity.config.frontend_origin }

    # A pattern for the path only, because the string "/api/*" also matches /apiary.
    resource %r{\A/api(/|\z)},
      credentials: true,
      methods: %i[get post patch put delete options head],
      headers: %w[Content-Type Accept X-CSRF-Token],
      expose: %w[Retry-After]
  end
end

# Inserted second, so it ends up first, in front of Rack::Cors.
Rails.application.config.middleware.insert_before 0, ApiSecurity::XOriginRemover
```

- **`origins` with a block.** rack-cors compiles a string such as `"localhost:5173"` (no scheme) into a regular expression that matches *any* scheme, and treats `"*"` as "everyone". A block that compares with `==` is exact by construction, whatever the variable holds. It also reads `ApiSecurity.config` on each request, which is how the spec "follows the configured origin" can change it.
- **A path pattern.** rack-cors turns `"/api/*"` into `/^\/api\/?(.*?)$/`, which also matches `/apiary`. The anchored pattern doesn't.
- **`credentials: true`** adds `Access-Control-Allow-Credentials: true`, without which the browser neither sends the cookie on a `credentials: 'include'` fetch nor shows the response to JavaScript. rack-cors raises if you combine it with `origins "*"`, and that is correct: credentials and a wildcard are refused by browsers too.
- **`headers`** is what a preflight may ask for. `X-Internal-Token` is deliberately absent: only the web app's server sends it, never a browser.
- **`expose: %w[Retry-After]`.** JavaScript on another origin can read only a handful of "safelisted" response headers; `Retry-After` isn't one of them (D-081).
- **Insertion order.** `insert_before 0` puts a middleware first, so the one inserted *last* ends up on top. `XOriginRemover` has to run before `Rack::Cors`, which is why its line comes second.

### `app/controllers/concerns/request_protection.rb`

```ruby
# CSRF protection for an API called from another origin (D-039, D-079).
module RequestProtection
  extend ActiveSupport::Concern

  include ActionController::RequestForgeryProtection

  included do
    # config.action_controller reaches ActionController::Base, but these two
    # settings are silently skipped for ActionController::API, so set them here.
    self.allow_forgery_protection = true
    # Rails' check compares Origin with the API's own host, which a frontend on
    # another origin never matches. verify_request_origin replaces it.
    self.forgery_protection_origin_check = false

    # The order matters: the Origin is checked before the token.
    before_action :verify_request_origin
    protect_from_forgery with: :exception

    rescue_from ActionController::InvalidAuthenticityToken, with: :render_invalid_csrf_token
  end

  private
    def verify_request_origin
      return if request.get? || request.head? || request.options?

      render_invalid_origin unless request.origin == ApiSecurity.config.frontend_origin
    end

    # Rails also accepts an authenticity_token parameter; this API takes only the header.
    def request_authenticity_tokens
      [ request.x_csrf_token ]
    end

    def render_invalid_origin
      render_error "invalid_origin", status: :forbidden, message: "The request origin is not allowed."
    end

    def render_invalid_csrf_token
      render_error "invalid_csrf_token", status: :forbidden, message: "The CSRF token is missing or invalid."
    end
end
```

- **The Origin check runs before the token check.** Both are `before_action`s, and Rails runs them in declaration order; `protect_from_forgery` defaults to `prepend: false`. A request from a foreign origin is refused without Rails ever computing a CSRF token for it. That matters: computing one would write a session cookie in the response.
- **`request.get? || request.head? || request.options?`** are the methods D-079 exempts. Rails' token check itself exempts only `GET` and `HEAD`, so a routed `OPTIONS` action would still need a token. No such route exists, and the spec documents that behaviour.
- **`protect_from_forgery with: :exception`** raises `InvalidAuthenticityToken`, rescued into the 403. The alternative strategies, `:null_session` (run the action with an empty session) and `:reset_session`, would let an unverified request *execute* without a session. An API should refuse it.

### `app/controllers/concerns/rate_limit_tiers.rb`

```ruby
# Rate limits per IP (D-029, D-080, D-081), on top of Rails' rate_limit. A task
# adds a limit with one declaration in its controller:
#
#   limit_requests scope: "login", to: 5, within: 3.minutes, only: :create
#
# The scope names the tier: controllers that use the same one share one count.
module RateLimitTiers
  extend ActiveSupport::Concern

  class_methods do
    def limit_requests(scope:, to:, within:, **options)
      rate_limit to: to, within: within, scope: scope, store: Rails.cache,
                 by: -> { request.remote_ip },
                 with: -> { render_rate_limited(retry_after: within) },
                 **options
    end

    # The exemption is written inline, not as a method, so that no other tier
    # can pick it up by accident (D-045).
    def limit_public_get_requests
      limit_requests scope: "public_get", to: 120, within: 1.minute,
                     if: -> { request.get? || request.head? },
                     unless: -> { ApiSecurity.config.internal_token_matches?(request.headers["X-Internal-Token"]) }
    end
  end

  private
    def render_rate_limited(retry_after:)
      response.set_header("Retry-After", retry_after.to_i.to_s)
      render_error "rate_limited", status: :too_many_requests, message: "Too many requests. Try again later."
    end
end
```

- **`limit_requests` is the one declaration later tasks use.** For example, Feature 5's login: `limit_requests scope: "login", to: 5, within: 3.minutes, only: :create`. Each tier names its scope, so a tier that spans several controllers (the admin tier, 300/min) shares one count automatically.
- **`with:`** replaces Rails' default, which raises `TooManyRequests` and lets Action Dispatch answer with its generic 429 error response, with our D-078 body and `Retry-After`. `within` is captured by the lambda, so each tier reports its own window.
- **The exemption is inline.** A method such as `internal_request?` could be passed as `unless:` to another tier by mistake, and a leaked token would then bypass the login limit. Written inside `limit_public_get_requests`, it can't be.
- **`if: -> { request.get? || request.head? }`**: the tier is the *public GET* tier. If a controller in it ever gains a `POST`, that `POST` doesn't spend the GET allowance.

### `app/controllers/concerns/json_errors.rb` and the two controllers

```ruby
# The one shape of an API error (D-078):
#
#   { "error": { "code": "snake_case", "message": "An English sentence.", "details": { ... } } }
module JsonErrors
  extend ActiveSupport::Concern

  included do
    rescue_from ActionController::ParameterMissing, with: :render_bad_request
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  end

  private
    def render_error(code, status:, message:, details: nil)
      error = { code: code, message: message, details: details.presence }.compact

      render json: { error: error }, status: status
    end

    def render_bad_request
      render_error "bad_request", status: :bad_request,
                                  message: "The request is invalid or missing a required parameter."
    end

    def render_not_found
      render_error "not_found", status: :not_found, message: "The requested resource was not found."
    end
end
```

`details.presence` turns `{}` and `nil` into `nil`, and `.compact` then drops the key, so `details` appears only when there is something in it (D-078). A missing record's own message, `Couldn't find SecretThing with id=1`, is never shown; a spec checks that the model's name doesn't leak.

```ruby
module Api
  # Answers unknown paths under /api. It doesn't inherit ApplicationController:
  # there is nothing to protect, so no Origin check, token or session (D-078).
  class ErrorsController < ActionController::API
    include JsonErrors

    def not_found
      render_not_found
    end
  end
end
```

```ruby
module Api
  module V1
    # Hands the frontend its CSRF token in the body, because the frontend can't
    # read this host's cookies (D-039, D-079).
    class CsrfTokensController < ApplicationController
      limit_public_get_requests

      def show
        render json: { csrf_token: form_authenticity_token }
      end
    end
  end
end
```

`form_authenticity_token` returns a *masked* token: the real secret XORed with a fresh random pad, so the string differs on every call even though it stays valid for the whole session. That defeats compression-based attacks such as BREACH, which recover a secret that repeats unchanged across responses.

### `.env.example` (repository root)

```sh
# Local development only. Copy this file to .env and never commit .env.

# Superuser name for the local Postgres container (development only).
POSTGRES_USER=tintara_dev

# Superuser password for the local Postgres container (development-only placeholder).
POSTGRES_PASSWORD=dev_password_change_me

# Host port mapped to the container's 5432. Change it if 5432 is taken on your machine.
POSTGRES_PORT=5432

# The Rails API reads the variables below once, at boot (D-080). It refuses to
# start, in every environment, without the first two. Restart it after a change.

# Required. The only origin allowed to call the API from a browser (CORS), and
# the exact value the Origin header must have on every request that changes
# something. Scheme, host and port only: no path and no trailing slash.
FRONTEND_ORIGIN=http://localhost:5173

# Required. Secret sent by the web app's server-side rendering as X-Internal-Token
# to skip the public per-IP rate limit, and nothing else (D-045). It must equal
# API_INTERNAL_TOKEN in apps/web/.env. Generate one with: openssl rand -hex 32
API_INTERNAL_TOKEN=replace-me-with-a-random-value

# Optional. Comma-separated IPs or CIDRs of reverse proxies, added to Rails'
# defaults (loopback and private ranges). Only these peers may report a client
# IP with X-Forwarded-For (D-081). Leave it empty in development.
TRUSTED_PROXIES=
```

### The spec support files

```ruby
# Helpers for the API security baseline (D-078 to D-081).
module SecurityHelpers
  # RFC 5737 documentation addresses. None is in Rails' default trusted proxies,
  # unlike 127.0.0.1, which is what request specs use when nothing is set.
  UNTRUSTED_IP = "203.0.113.10"
  OTHER_UNTRUSTED_IP = "203.0.113.20"

  PUBLIC_LIMIT = 120

  def frontend_origin
    ENV.fetch("FRONTEND_ORIGIN")
  end

  def internal_token
    ENV.fetch("API_INTERNAL_TOKEN")
  end

  # Fetches a token, and with it the session cookie, then returns the headers a
  # mutating request needs:
  #
  #   post "/api/v1/things", params: { ... }, headers: csrf_headers, as: :json
  def csrf_headers
    get "/api/v1/csrf_token"

    { "X-CSRF-Token" => response.parsed_body["csrf_token"], "Origin" => frontend_origin }
  end

  def get_from(ip, path = "/api/v1/csrf_token", headers: {})
    get path, headers: headers, env: { "REMOTE_ADDR" => ip }
  end

  # Spends the whole public allowance of one client, and checks that it existed.
  def exhaust_public_limit(ip = UNTRUSTED_IP, path = "/api/v1/csrf_token", headers: {})
    PUBLIC_LIMIT.times do |index|
      get_from(ip, path, headers: headers)
      # Inside the loop, so that a broken endpoint fails at request 1, not after 120.
      expect(response.status).to eq(200), "request #{index + 1} got #{response.status}"
    end
  end

  def expect_error(status, code, message)
    expect(response).to have_http_status(status)
    expect(response.media_type).to eq("application/json")
    expect(JSON.parse(response.body)).to eq("error" => { "code" => code, "message" => message })
  end

  # Replaces the boot configuration for one example, without touching ENV.
  def use_api_security(**overrides)
    settings = {
      frontend_origin: frontend_origin,
      internal_token: internal_token,
      trusted_proxies: ""
    }.merge(overrides)

    allow(ApiSecurity).to receive(:config).and_return(ApiSecurity::Configuration.new(**settings))
  end
end

RSpec.configure do |config|
  config.include SecurityHelpers, type: :request
end
```

```ruby
# Endpoints that exist only inside the spec suite (never in config/routes.rb).
#
# They live outside /api because routes drawn here are appended after the app's
# own, where the /api catch-all would shadow them. The protections under test
# belong to ApplicationController, so the path makes no difference to them.
module TestEndpoints
  def define_test_controller(name, &body)
    stub_const(name, Class.new(ApplicationController, &body))
  end

  def draw_test_routes(&routes)
    application = Rails.application
    application.reload_routes_unless_loaded
    application.routes.disable_clear_and_finalize = true
    application.routes.draw(&routes)
  ensure
    application.routes.disable_clear_and_finalize = false
  end
end

RSpec.shared_context "with test endpoints" do
  include TestEndpoints

  after { Rails.application.reload_routes! }
end
```

```ruby
# freeze_time and travel, for specs about windows and expiry.
RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
  config.after { travel_back }
end
```

### The spec files

These are the specs from steps 3 and 5, in full.

```ruby
require "rails_helper"

RSpec.describe "CORS", type: :request do
  def preflight(path = "/api/v1/csrf_token", origin: frontend_origin, method: "POST", headers: "x-csrf-token")
    options path, headers: {
      "Origin" => origin,
      "Access-Control-Request-Method" => method,
      "Access-Control-Request-Headers" => headers
    }
  end

  describe "a preflight from the frontend origin" do
    it "allows that exact origin, with credentials" do
      preflight

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
      expect(response.headers["Access-Control-Allow-Credentials"]).to eq("true")
    end

    it "allows the X-CSRF-Token header" do
      preflight

      expect(response.headers["Access-Control-Allow-Headers"].to_s.downcase).to include("x-csrf-token")
    end

    it "allows Content-Type and Accept beside the token" do
      preflight(headers: "content-type, accept, x-csrf-token")

      expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
    end

    %w[GET POST PATCH PUT DELETE OPTIONS HEAD].each do |verb|
      it "allows #{verb}" do
        preflight(method: verb)

        expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
        expect(response.headers["Access-Control-Allow-Methods"].to_s.split(", ")).to include(verb)
      end
    end

    it "is answered for a path that the catch-all would otherwise handle" do
      preflight("/api/v1/does-not-exist")

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
    end

    it "does not allow other headers, such as the server-only X-Internal-Token" do
      preflight(headers: "x-internal-token")

      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end

  describe "a preflight from any other origin" do
    it "gets no Access-Control-Allow-Origin, however similar the origin looks" do
      others = [ "https://evil.example", "null", "#{frontend_origin}/", "#{frontend_origin}.evil.example",
                 "#{frontend_origin}0", frontend_origin.upcase ]

      others.each do |origin|
        preflight(origin: origin)

        expect(response.headers["Access-Control-Allow-Origin"]).to be_nil, "allowed #{origin.inspect}"
      end
    end
  end

  it "follows the configured origin, without a second allowed one" do
    use_api_security(frontend_origin: "https://www.example.test")

    preflight(origin: "https://www.example.test")
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://www.example.test")

    preflight(origin: frontend_origin)
    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
  end

  it "does not apply outside /api" do
    %w[/up /apiary].each do |path|
      preflight(path, method: "GET")

      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end

  describe "an actual response to the frontend origin" do
    it "allows credentials and exposes Retry-After" do
      get "/api/v1/csrf_token", headers: { "Origin" => frontend_origin }

      expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
      expect(response.headers["Access-Control-Allow-Credentials"]).to eq("true")
      expect(response.headers["Access-Control-Expose-Headers"]).to eq("Retry-After")
    end

    it "exposes Retry-After on a 429 too" do
      exhaust_public_limit
      get_from(SecurityHelpers::UNTRUSTED_IP, headers: { "Origin" => frontend_origin })

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
      expect(response.headers["Access-Control-Expose-Headers"]).to eq("Retry-After")
    end

    it "lets the frontend read an error" do
      get "/api/v1/does-not-exist", headers: { "Origin" => frontend_origin }

      expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
      expect_error(:not_found, "not_found", "The requested resource was not found.")
    end
  end
end
```

```ruby
require "rails_helper"

RSpec.describe "GET /api/v1/csrf_token", type: :request do
  before { get "/api/v1/csrf_token" }

  it "responds with 200 OK and JSON" do
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
  end

  it "returns exactly one key, a non-empty csrf_token string" do
    expect(response.parsed_body.keys).to eq(%w[csrf_token])
    expect(response.parsed_body["csrf_token"]).to be_a(String).and be_present
  end

  describe "the session cookie" do
    let(:set_cookie) { Array(response.headers["Set-Cookie"]).join("\n") }

    it "is named _tintara_session" do
      expect(set_cookie).to start_with("_tintara_session=")
    end

    it "is HttpOnly and SameSite=Lax" do
      expect(set_cookie).to match(/;\s*httponly(;|$)/i).and match(/;\s*samesite=lax(;|$)/i)
    end

    it "is host-only, for the whole host" do
      expect(set_cookie).to match(/;\s*path=\/(;|$)/i)
      expect(set_cookie).not_to match(/;\s*domain=/i)
    end

    it "is not Secure outside production, so it works on http://localhost" do
      expect(set_cookie).to start_with("_tintara_session=")
      expect(set_cookie).not_to match(/;\s*secure(;|$)/i)
    end

    it "holds the CSRF secret and nothing else" do
      # session_id is the cookie store's own identifier, present in every session.
      expect(request.session.to_hash.keys).to match_array(%w[session_id _csrf_token])
    end
  end
end
```

```ruby
require "rails_helper"

RSpec.describe "Forgery protection and the Origin check", type: :request do
  include_context "with test endpoints"

  before do
    define_test_controller("ProtectedTestController") do
      def handle
        render json: { handled: true }
      end
    end

    draw_test_routes do
      match "/test/protected", to: "protected_test#handle", via: %i[get post put patch delete]
    end
  end

  let(:invalid_origin) { [ :forbidden, "invalid_origin", "The request origin is not allowed." ] }
  let(:invalid_token) { [ :forbidden, "invalid_csrf_token", "The CSRF token is missing or invalid." ] }

  %i[post put patch delete].each do |verb|
    describe verb.to_s.upcase do
      it "succeeds with a valid token and the frontend Origin" do
        public_send(verb, "/test/protected", headers: csrf_headers)

        expect(response).to have_http_status(:ok)
      end

      it "rejects a missing token" do
        public_send(verb, "/test/protected", headers: csrf_headers.except("X-CSRF-Token"))

        expect_error(*invalid_token)
      end

      it "rejects a missing Origin, even with a valid token" do
        public_send(verb, "/test/protected", headers: csrf_headers.except("Origin"))

        expect_error(*invalid_origin)
      end
    end
  end

  it "accepts a JSON request" do
    post "/test/protected", params: { name: "Example" }, headers: csrf_headers, as: :json

    expect(response).to have_http_status(:ok)
  end

  it "rejects a wrong token" do
    post "/test/protected", headers: csrf_headers.merge("X-CSRF-Token" => "wrong")

    expect_error(*invalid_token)
  end

  it "rejects a token that belongs to another session" do
    headers = csrf_headers
    reset!

    post "/test/protected", headers: headers

    expect_error(*invalid_token)
  end

  it "does not read the token from the parameters, only from X-CSRF-Token" do
    headers = csrf_headers

    post "/test/protected", params: { authenticity_token: headers["X-CSRF-Token"] },
                            headers: headers.slice("Origin")

    expect_error(*invalid_token)
  end

  it "rejects any Origin that is not exactly the frontend's, even with a valid token" do
    headers = csrf_headers
    # The API's own origin is in the list: it is what Rails' built-in check would accept.
    others = [ "https://evil.example", "null", "", "#{frontend_origin}/", frontend_origin.upcase,
               "http://www.example.com" ]

    others.each do |origin|
      post "/test/protected", headers: headers.merge("Origin" => origin)

      expect_error(*invalid_origin)
    end
  end

  # rack-cors copies X-Origin into a missing Origin before the app sees the request.
  it "does not accept X-Origin in place of a missing Origin" do
    post "/test/protected", headers: csrf_headers.except("Origin").merge("X-Origin" => frontend_origin)

    expect_error(*invalid_origin)
  end

  it "checks the Origin before the token" do
    post "/test/protected", headers: { "Origin" => "https://evil.example" }

    expect_error(*invalid_origin)
  end

  it "does not block a GET with no token and no Origin" do
    get "/test/protected"

    expect(response).to have_http_status(:ok)
  end

  it "does not block a HEAD with no token and no Origin" do
    head "/test/protected"

    expect(response).to have_http_status(:ok)
  end

  it "does not apply the Origin check to OPTIONS" do
    draw_test_routes { match "/test/options", to: "protected_test#handle", via: :options }

    # Rails itself still asks OPTIONS for a token, so send one and only leave out the Origin.
    options "/test/options", headers: csrf_headers.except("Origin")

    expect(response).to have_http_status(:ok)
  end
end
```

```ruby
require "rails_helper"

RSpec.describe "JSON errors", type: :request do
  include_context "with test endpoints"

  let(:not_found) { [ :not_found, "not_found", "The requested resource was not found." ] }

  describe "an unknown path under /api" do
    %i[get post put patch delete options].each do |verb|
      it "is 404 not_found for #{verb.to_s.upcase}, with no token and no Origin" do
        public_send(verb, "/api/v1/does-not-exist")

        expect_error(*not_found)
      end
    end

    it "is 404 for HEAD" do
      head "/api/v1/does-not-exist"

      expect(response).to have_http_status(:not_found)
    end

    it "is 404 whatever the depth or the extension" do
      %w[/api /api/ /api/nope /api/v1/a/b/c /api/v1/nope.json /api/v2/health].each do |path|
        get path

        expect_error(*not_found)
      end
    end

    it "is 404 for an existing path called with a method it doesn't have" do
      post "/api/v1/health"

      expect_error(*not_found)
    end

    it "is 404 before any token, Origin or body is looked at" do
      post "/api/v1/does-not-exist", params: "{not json",
                                     headers: { "Origin" => "https://evil.example", "Content-Type" => "application/json" }

      expect_error(*not_found)
    end

    it "does not create a session" do
      post "/api/v1/does-not-exist"

      expect_error(*not_found)
      expect(response.headers["Set-Cookie"]).to be_blank
    end

    it "does not swallow /up or the health endpoint" do
      %w[/up /api/v1/health].each do |path|
        get path

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "errors raised by a controller" do
    before do
      define_test_controller("ErrorsTestController") do
        def missing_parameter
          params.require(:name)
        end

        def missing_record
          raise ActiveRecord::RecordNotFound, "Couldn't find SecretThing with id=1"
        end

        def with_details
          render_error "example_code", status: :unprocessable_content, message: "An example.",
                                       details: { name: [ "can't be blank" ] }
        end

        def with_empty_details
          render_error "example_code", status: :unprocessable_content, message: "An example.", details: {}
        end
      end

      draw_test_routes do
        %w[missing_parameter missing_record with_details with_empty_details].each do |action|
          get "/test/errors/#{action}", to: "errors_test##{action}"
        end
      end
    end

    it "renders a missing required parameter as 400 bad_request" do
      get "/test/errors/missing_parameter"

      expect_error(:bad_request, "bad_request", "The request is invalid or missing a required parameter.")
    end

    it "renders a missing record as 404 not_found, without naming the model" do
      get "/test/errors/missing_record"

      expect_error(*not_found)
    end

    it "renders details when there are some" do
      get "/test/errors/with_details"

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)).to eq(
        "error" => { "code" => "example_code", "message" => "An example.", "details" => { "name" => [ "can't be blank" ] } }
      )
    end

    it "omits details when they are empty" do
      get "/test/errors/with_empty_details"

      expect_error(:unprocessable_content, "example_code", "An example.")
    end
  end
end
```

```ruby
require "rails_helper"

RSpec.describe "Rate limits", type: :request do
  let(:client) { SecurityHelpers::UNTRUSTED_IP }
  let(:rate_limited) { [ :too_many_requests, "rate_limited", "Too many requests. Try again later." ] }

  describe "the public GET tier, on GET /api/v1/csrf_token" do
    it "allows 120 requests from one IP and blocks request 121" do
      exhaust_public_limit(client)
      get_from(client)

      expect_error(*rate_limited)
      expect(response.headers["Retry-After"]).to eq("60")
    end

    it "gives a new allowance when the window ends, even to a client that kept trying" do
      freeze_time
      exhaust_public_limit(client)

      travel 59.seconds
      get_from(client)
      expect_error(*rate_limited)

      travel 2.seconds
      get_from(client)
      expect(response).to have_http_status(:ok)
    end

    it "does not count one IP against another" do
      exhaust_public_limit(client)
      get_from(SecurityHelpers::OTHER_UNTRUSTED_IP)

      expect(response).to have_http_status(:ok)
    end

    # The same example twice: in either order, the second one fails if a counter leaks.
    2.times do |run|
      it "starts every example with a full allowance (run #{run + 1})" do
        exhaust_public_limit(client)
        get_from(client)

        expect_error(*rate_limited)
      end
    end

    it "exempts a valid X-Internal-Token" do
      headers = { "X-Internal-Token" => internal_token }
      exhaust_public_limit(client, headers: headers)
      get_from(client, headers: headers)

      expect(response).to have_http_status(:ok)
    end

    it "exempts a valid token even for an IP that is already blocked" do
      exhaust_public_limit(client)
      get_from(client, headers: { "X-Internal-Token" => internal_token })

      expect(response).to have_http_status(:ok)
    end

    it "treats a wrong X-Internal-Token as an ordinary request" do
      headers = { "X-Internal-Token" => "#{internal_token}x" }
      exhaust_public_limit(client, headers: headers)
      get_from(client, headers: headers)

      expect_error(*rate_limited)
    end

    it "never matches an empty configured token" do
      use_api_security(internal_token: "")
      exhaust_public_limit(client, headers: { "X-Internal-Token" => "" })
      get_from(client, headers: { "X-Internal-Token" => "" })

      expect_error(*rate_limited)
    end
  end

  describe "tiers across controllers" do
    include_context "with test endpoints"

    before do
      %w[FirstPublicTestController SecondPublicTestController].each do |name|
        define_test_controller(name) do
          limit_public_get_requests

          def handle
            render json: { handled: true }
          end
        end
      end

      define_test_controller("OtherTierTestController") do
        limit_requests scope: "other_test_tier", to: 2, within: 3.minutes

        def handle
          render json: { handled: true }
        end
      end

      draw_test_routes do
        get "/test/public/first", to: "first_public_test#handle"
        get "/test/public/second", to: "second_public_test#handle"
        post "/test/public/first", to: "first_public_test#handle"
        get "/test/other_tier", to: "other_tier_test#handle"
      end
    end

    it "shares one count between two controllers in the public tier" do
      60.times do
        get_from(client, "/test/public/first")
        expect(response).to have_http_status(:ok)
        get_from(client, "/test/public/second")
        expect(response).to have_http_status(:ok)
      end

      get_from(client, "/test/public/first")
      expect_error(*rate_limited)
      get_from(client, "/test/public/second")
      expect_error(*rate_limited)
    end

    it "shares that count with GET /api/v1/csrf_token" do
      exhaust_public_limit(client, "/test/public/first")
      get_from(client)

      expect_error(*rate_limited)
    end

    it "counts only GET and HEAD requests in the public GET tier" do
      headers = csrf_headers
      exhaust_public_limit(client)

      post "/test/public/first", headers: headers, env: { "REMOTE_ADDR" => client }

      expect(response).to have_http_status(:ok)
    end

    it "keeps separate tiers separate" do
      exhaust_public_limit(client)
      get_from(client, "/test/other_tier")

      expect(response).to have_http_status(:ok)
    end

    it "does not exempt a valid internal token from another tier" do
      headers = { "X-Internal-Token" => internal_token }
      3.times { get_from(client, "/test/other_tier", headers: headers) }

      expect_error(*rate_limited)
      expect(response.headers["Retry-After"]).to eq("180")
    end
  end

  describe "endpoints without a limit" do
    %w[/api/v1/health /up].each do |path|
      it "answers #{path} past 120 requests" do
        exhaust_public_limit(client, path)
        get_from(client, path)

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
```

```ruby
require "rails_helper"

# REMOTE_ADDR is always explicit here: the request-spec default, 127.0.0.1, is a
# trusted proxy and would hide the spoofing these examples exist to catch.
RSpec.describe "Client IP and trusted proxies", type: :request do
  include_context "with test endpoints"

  before do
    define_test_controller("ClientIpTestController") do
      def show
        render json: { ip: request.remote_ip }
      end
    end

    draw_test_routes { get "/test/client_ip", to: "client_ip_test#show" }
  end

  let(:peer) { SecurityHelpers::UNTRUSTED_IP }
  let(:visitor) { "198.51.100.7" }

  def resolved_ip(remote_addr, headers = {})
    get_from(remote_addr, "/test/client_ip", headers: headers)
    expect(response).to have_http_status(:ok)
    response.parsed_body["ip"]
  end

  describe "from an untrusted peer" do
    forgeries = {
      "X-Forwarded-For" => ->(ip) { ip },
      "Client-IP" => ->(ip) { ip },
      "Forwarded" => ->(ip) { "for=#{ip}" }
    }

    forgeries.each do |header, value|
      it "ignores #{header}" do
        expect(resolved_ip(peer, header => value.call(visitor))).to eq(peer)
      end

      it "keeps a blocked client blocked while it rotates #{header}" do
        exhaust_public_limit(peer)

        1.upto(10) do |host|
          get_from(peer, headers: { header => value.call("198.51.100.#{host}") })

          expect(response).to have_http_status(:too_many_requests)
        end
      end

      it "counts requests with a rotating #{header} as one client" do
        SecurityHelpers::PUBLIC_LIMIT.times do |host|
          get_from(peer, headers: { header => value.call("198.51.100.#{host}") })
          expect(response).to have_http_status(:ok)
        end
        get_from(peer)

        expect(response).to have_http_status(:too_many_requests)
      end
    end

    it "ignores all three headers sent together" do
      headers = { "X-Forwarded-For" => visitor, "Client-IP" => "198.51.100.8", "Forwarded" => "for=198.51.100.9" }

      expect(resolved_ip(peer, headers)).to eq(peer)
    end
  end

  describe "a blank or unparsable peer" do
    [ "", "not-an-ip", "10.0.0.0/8", "127.0.0.1, 203.0.113.10" ].each do |remote_addr|
      it "treats #{remote_addr.inspect} as untrusted" do
        expect(resolved_ip(remote_addr, "X-Forwarded-For" => visitor)).not_to eq(visitor)
      end
    end
  end

  shared_examples "a trusted peer" do
    it "lets X-Forwarded-For set the client IP" do
      expect(resolved_ip(proxy, "X-Forwarded-For" => visitor)).to eq(visitor)
    end

    it "lets X-Forwarded-For set the rate-limit key" do
      exhaust_public_limit(proxy, headers: { "X-Forwarded-For" => visitor })

      get_from(proxy, headers: { "X-Forwarded-For" => "198.51.100.8" })
      expect(response).to have_http_status(:ok)

      get_from(visitor)
      expect(response).to have_http_status(:too_many_requests)
    end

    it "ignores a forged leftmost entry when the proxy appended the real address" do
      expect(resolved_ip(proxy, "X-Forwarded-For" => "198.51.100.99, #{visitor}")).to eq(visitor)
    end

    it "skips a trusted proxy at the end of the list" do
      expect(resolved_ip(proxy, "X-Forwarded-For" => "#{visitor}, #{proxy}")).to eq(visitor)
    end

    it "does not let Client-IP override X-Forwarded-For" do
      expect(resolved_ip(proxy, "X-Forwarded-For" => visitor, "Client-IP" => "198.51.100.8")).to eq(visitor)
    end

    it "does not let Forwarded override X-Forwarded-For" do
      expect(resolved_ip(proxy, "X-Forwarded-For" => visitor, "Forwarded" => "for=198.51.100.8")).to eq(visitor)
    end

    it "ignores Client-IP and Forwarded on their own" do
      expect(resolved_ip(proxy, "Client-IP" => visitor)).to eq(proxy)
      expect(resolved_ip(proxy, "Forwarded" => "for=#{visitor}")).to eq(proxy)
    end
  end

  describe "from a peer in Rails' defaults" do
    let(:proxy) { "10.1.2.3" }

    it_behaves_like "a trusted peer"
  end

  describe "from a peer listed in TRUSTED_PROXIES" do
    let(:proxy) { "192.0.2.44" }

    before { use_api_security(trusted_proxies: "192.0.2.0/24") }

    it_behaves_like "a trusted peer"

    it "still trusts Rails' defaults" do
      expect(resolved_ip("127.0.0.1", "X-Forwarded-For" => visitor)).to eq(visitor)
    end
  end

  describe "conflicting Client-IP and X-Forwarded-For" do
    { "untrusted" => "203.0.113.10", "trusted" => "10.1.2.3" }.each do |kind, remote_addr|
      it "never raise IpSpoofAttackError from an #{kind} peer" do
        headers = { "Client-IP" => "198.51.100.8", "X-Forwarded-For" => "198.51.100.7" }

        expect { get_from(remote_addr, "/test/client_ip", headers: headers) }.not_to raise_error
        expect(response).to have_http_status(:ok)
      end
    end
  end

  it "sanitizes immediately before RemoteIp, which uses the same trusted list" do
    stack = Rails.application.middleware.map(&:name)

    expect(stack[stack.index("ActionDispatch::RemoteIp") - 1]).to eq("ApiSecurity::ClientIpSanitizer")
    expect(Rails.configuration.action_dispatch.trusted_proxies).to equal(ApiSecurity::TrustedProxies)
  end
end
```

```ruby
require "rails_helper"

# Rails 8.1.3.1 with json 3.0 raises inside ActiveSupport::JSON.decode, which
# breaks both of these. It is the reason the Gemfile holds json below 3.
RSpec.describe "JSON decoding", type: :request do
  include_context "with test endpoints"

  before do
    stub_const("JsonBodyTestController", Class.new(ActionController::API) do
      def echo
        render json: { name: params[:name] }
      end
    end)

    draw_test_routes { post "/test/json_body", to: "json_body_test#echo" }
  end

  it "parses a JSON request body" do
    post "/test/json_body", params: { name: "Example" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["name"]).to eq("Example")
  end

  it "reads back an encrypted cookie, which is how the session is stored" do
    jar = ActionDispatch::Request.new(Rails.application.env_config.merge(Rack::MockRequest.env_for("/"))).cookie_jar
    jar.encrypted[:example] = { value: { "stored" => true } } # a bare Hash would be read as options

    expect(jar.encrypted[:example]).to eq("stored" => true)
  end
end
```

```ruby
require "rails_helper"

RSpec.describe "ApiSecurity::Configuration" do
  let(:environment) { { "FRONTEND_ORIGIN" => "https://www.example.test", "API_INTERNAL_TOKEN" => "a-test-token" } }
  let(:defaults) { ActionDispatch::RemoteIp::TRUSTED_PROXIES }

  def configuration(env)
    ApiSecurity::Configuration.from_env(env)
  end

  it "reads the required variables" do
    config = configuration(environment)

    expect(config.frontend_origin).to eq("https://www.example.test")
    expect(config.internal_token).to eq("a-test-token")
  end

  %w[FRONTEND_ORIGIN API_INTERNAL_TOKEN].each do |name|
    { "missing" => nil, "empty" => "", "blank" => "  " }.each do |state, value|
      it "raises, naming #{name}, when it is #{state}" do
        expect { configuration(environment.merge(name => value).compact) }
          .to raise_error(an_instance_of(ApiSecurity::ConfigurationError).and(having_attributes(message: /#{name}/)))
      end
    end
  end

  describe "TRUSTED_PROXIES" do
    { "unset" => nil, "empty" => "", "blank" => " " }.each do |state, value|
      it "leaves Rails' defaults unchanged when it is #{state}" do
        config = configuration(environment.merge("TRUSTED_PROXIES" => value).compact)

        expect(config.trusted_proxies).to eq(defaults)
      end
    end

    it "adds IPs and CIDRs to the defaults, ignoring spaces around them" do
      config = configuration(environment.merge("TRUSTED_PROXIES" => "192.0.2.1, 198.51.100.0/24,2001:db8::/32"))
      added = %w[192.0.2.1 198.51.100.0/24 2001:db8::/32].map { |entry| IPAddr.new(entry) }

      expect(config.trusted_proxies).to eq(defaults + added)
    end

    %w[not-an-ip 192.0.2.0/33 999.0.0.1 proxy.example.test].each do |entry|
      it "raises, naming the bad value #{entry}" do
        expect { configuration(environment.merge("TRUSTED_PROXIES" => "192.0.2.1,#{entry}")) }
          .to raise_error(an_instance_of(ApiSecurity::ConfigurationError)
            .and(having_attributes(message: /TRUSTED_PROXIES.*#{Regexp.escape(entry)}/)))
      end
    end
  end

  it "keeps the token out of inspect, which ends up in logs and error reports" do
    expect(configuration(environment).inspect).not_to include("a-test-token")
  end

  it "is read once, at boot" do
    booted = ApiSecurity.config

    expect(booted).to be_a(ApiSecurity::Configuration)
    expect(ApiSecurity.config).to equal(booted)
  end
end
```

```ruby
require "rails_helper"

# The test environment can't be production, so this builds Rails' real cookie
# and session middleware from the options production would receive.
RSpec.describe "ApiSecurity::SessionCookie" do
  def set_cookie_in(environment)
    app = lambda do |env|
      ActionDispatch::Request.new(env).session[:probe] = true
      [ 200, {}, [] ]
    end
    options = ApiSecurity::SessionCookie.options(environment)
    stack = ActionDispatch::Cookies.new(ActionDispatch::Session::CookieStore.new(app, options))
    env = Rails.application.env_config.merge(Rack::MockRequest.env_for("https://api.example.test/"))

    _status, headers, _body = stack.call(env)
    Array(headers["set-cookie"]).join("\n")
  end

  it "sets a Secure, HttpOnly, SameSite=Lax, host-only cookie in production" do
    cookie = set_cookie_in("production")

    expect(cookie).to start_with("_tintara_session=")
    expect(cookie).to match(/;\s*secure(;|$)/i).and match(/;\s*httponly(;|$)/i).and match(/;\s*samesite=lax(;|$)/i)
    expect(cookie).not_to match(/;\s*domain=/i)
  end

  %w[development test].each do |environment|
    it "leaves Secure off in #{environment}" do
      expect(set_cookie_in(environment)).not_to match(/;\s*secure(;|$)/i)
    end
  end

  it "sets every attribute explicitly" do
    expect(ApiSecurity::SessionCookie.options("production")).to eq(
      key: "_tintara_session", path: "/", domain: nil, httponly: true, same_site: :lax, secure: true
    )
  end

  it "is what this application runs with" do
    expect(Rails.configuration.session_options.slice(:key, :path, :domain, :httponly, :same_site, :secure))
      .to eq(ApiSecurity::SessionCookie.options(Rails.env))
  end
end
```

**How the rate-limit specs avoid sharing counters.** Four things, each guarding a different leak:

1. The test cache is a real `:memory_store`, so counters exist at all. With `:null_store` every limit silently passes.
2. `config.before { Rails.cache.clear }` in `rails_helper.rb` empties it before every example. Transactional fixtures roll back the database, not the cache.
3. The example "starts every example with a full allowance" is written **twice** (`2.times do |run|`). Whichever runs second fails if anything carries over, in any order.
4. Each example uses its own `REMOTE_ADDR`. The window example freezes and moves time, and `travel_back` runs after every example.

The mutation check in step 12 confirms points 1 and 2: going back to `:null_store`, or deleting the `clear`, both fail the suite.

## 6. Decisions behind this chapter

| Decision | What we chose | What we rejected | Why |
|---|---|---|---|
| D-078 | `{ error: { code, message, details? } }`, English messages, frontend maps codes to Spanish | RFC 9457 problem+json; a JSON:API `errors` array | One first-party client; fewer fields to keep consistent |
| D-079 | Cookie session in API mode; token from `GET /api/v1/csrf_token` in `X-CSRF-Token`; `Origin` must equal `FRONTEND_ORIGIN`, a missing one is refused | Accepting a missing `Origin` with a valid token; Rails' own origin check | Only non-browser clients omit `Origin`; Rails' check compares with the API's own host |
| D-080 | Rails `rate_limit` keyed by `request.remote_ip`, stored in `Rails.cache`; JSON 429 with `Retry-After`; `:memory_store` in test; variables required at boot | Rack::Attack (D-029); deferring proxy handling to deployment | No extra dependency; proxied requests covered by specs now |
| D-081 | Sanitizing middleware before `RemoteIp`; one explicit scope per tier; `Retry-After` exposed through CORS; fail-open accepted | `trusted_proxies` alone; keying on `REMOTE_ADDR`; failing closed on cache errors | Spoofing proved by prototype; `REMOTE_ADDR` behind a proxy is the proxy |
| D-045 | `X-Internal-Token` exempts only the public tier, compared in constant time | Raising the public limit; CDN cache only | Server rendering must not throttle the site |
| This chapter | Block for `origins`, a regex for the resource path | Strings `"http://..."` and `"/api/*"` | Exact by construction; `"/api/*"` matches `/apiary` |
| This chapter | `XOriginRemover` before rack-cors | Trusting `X-Origin` as rack-cors does | D-079 requires the `Origin` header itself |
| This chapter | `lib/api_security`, required by hand and ignored by Zeitwerk | `app/middleware` with autoloading | Needed during boot; middleware must not reload |
| This chapter | json held at `~> 2.21, >= 2.21.2` | Upgrading Rails to 8.1.4.1 inside this feature | Smallest change that fixes the bug; the upgrade is the owner's call |

## 7. Traps, mistakes and things we avoided

1. **`main` couldn't decode JSON.** Rails 8.1.3.1 and json 3.0.2 are incompatible, and nothing had exercised `ActiveSupport::JSON.decode` until the first cookie (step 5). The lesson is broader than json: a lockfile resolved the week a major version shipped can pair a framework with a dependency release newer than the framework. And a skeleton endpoint that reads no body and sets no cookie can't reveal it. Use `rspec -b` when a backtrace stops inside your own code but the error makes no sense there.
2. **`config.action_controller.*` doesn't reach `ActionController::API`.** Rails applies those settings with `send("#{k}=", v) if respond_to?("#{k}=")`, and when `ActionController::API` loads it doesn't have `allow_forgery_protection=` (forgery protection isn't included yet). The setting is silently skipped. Proved with a runner script in the test environment, while `test.rb` still said `false`:
   ```
   {test_config: false}
   {api_allow: true, api_origin_check: false, base_allow: false}
   ```
   The `false` only ever reached `ActionController::Base`. So `RequestProtection` sets both values on the controller, and the `test.rb` comment says what the line really does.
3. **rack-cors copies `X-Origin` into a missing `Origin`.** Its first line of `call` is `env[HTTP_ORIGIN] ||= env[HTTP_X_ORIGIN] if env[HTTP_X_ORIGIN]`, for backwards compatibility. Since rack-cors runs before Rails, a request with no `Origin` and `X-Origin: http://localhost:5173` would pass our Origin check. Only non-browser clients can send such a request, and those are exactly the clients D-079 refuses by requiring `Origin`. `XOriginRemover` deletes the header first, and a spec sends it.
4. **Two rack-cors strings that don't mean what they look like.** In `origins`, a string without a scheme becomes a regular expression that matches any scheme, and `"*"` means everyone. In `resource`, `"/api/*"` also matches `/apiary`. Both are visible in `lib/rack/cors/resources.rb` and `resource.rb`, and invisible in the README's examples.
5. **`rate_limit` counts per controller by default.** Two controllers in the "same" tier would give each IP 120 requests in each. Hence `scope:` on every tier, and the spec that spreads 120 requests over two test controllers.
6. **Rails' origin check would reject every legitimate request.** It compares `Origin` with the API's own URL (`request.base_url`), so a cross-origin frontend never matches, and it accepts a *missing* `Origin`. Disable it (`forgery_protection_origin_check = false`) and replace it, rather than trying to configure it.
7. **The token is also accepted from a parameter.** By default Rails reads `params[:authenticity_token]` too. Overriding `request_authenticity_tokens` restricts it to the header, and as a side effect a mutating request never has to parse its body before being refused.
8. **`127.0.0.1` hides spoofing bugs in request specs.** It is the default `REMOTE_ADDR` and it is a trusted proxy. Every client-IP and rate-limit spec sets an untrusted address explicitly.
9. **`IPAddr#include?` raises on garbage, and `::ffff:` addresses don't match IPv4 ranges.** `IPAddr.new("127.0.0.0/8") === "junk"` raises `InvalidAddressError`, which is why `trust?` rescues. `IPAddr.new("127.0.0.0/8") === "::ffff:127.0.0.1"` is `false`. Puma 8's default bind is `::` when IPv6 is available, and an IPv4 peer then appears as `::ffff:10.0.0.5`. Behind a proxy on a private address, the proxy would then count as untrusted: every visitor would share its counter. That fails *safe* (no spoofing, but one shared limit). `bin/rails server` binds `0.0.0.0` in production, so it doesn't arise with our Dockerfile, but it is listed as a deployment check.
10. **`trusted_proxies = [...]` replaces Rails' list.** It doesn't add to it. Start from `ActionDispatch::RemoteIp::TRUSTED_PROXIES`.
11. **`insert_before 0` reverses the order.** Two middleware inserted at position 0 end up in the opposite order from the lines that inserted them.
12. **A slow red run is a design smell in the helper, not in the code.** The first version of `exhaust_public_limit` made 120 requests before checking anything; against the missing endpoint, the run didn't finish in two minutes. Fail at the first wrong response.
13. **`cookies.encrypted[:x] = { ... }` with a Hash stores nothing.** The Hash is read as the cookie's options (`value:`, `expires:`, ...). Wrap the value: `{ value: {...} }`. It cost one wrong spec and a correction commit (step 5).
14. **Test routes must not collide with the catch-all.** They are appended after it, so `/api/test/...` would never reach them. They live under `/test/`, and `reload_routes!` after every example removes them.
15. **Fail-open is accepted, not fixed (D-081, point 4).** In production, Solid Cache 1.0.10 rescues transient database errors (timeouts, a lost connection, a deadlock) inside `increment`, logs them and returns `nil`. `rate_limiting` then evaluates `count && count > to` as false and lets the request through. During a short database problem, limits stop limiting. The alternative, refusing every request when the counter can't be read, would turn a brief database fault into a full outage, and it would need custom code around `rate_limit`. Revisit in Feature 24.
16. **`bundler-audit` reports advisories on `main`.** Most are in Rails components this app doesn't load (Active Storage, Action View helpers). One is High and close to this chapter: "Possible IP spoofing in Action Dispatch RemoteIp" (GHSA-2gff-2mmg-m73p). It is exactly D-081's finding that Rack prefers `Forwarded`, and its recommended mitigation is to remove a client-supplied `Forwarded`, which `ClientIpSanitizer` always does. The Rails 8.1.4.1 fix is still worth taking. The report lists the rest for the owner.
17. **`ubuntu-latest` moves under you.** A workflow that passed on `main` in October failed in November without a single change, because the image behind the label changed (step 15). Any setup step that downloads a prebuilt binary per OS version (Ruby, Node, Postgres clients) can break this way. Pinning `ubuntu-24.04` trades that surprise for a deliberate upgrade later. GitHub retires old images too, so the pin needs revisiting, not forgetting.
18. **Deliberately not done.** No `admins`, `sessions` or login (Feature 5). No other D-029 limits (each arrives with its endpoint). No JSON format for errors raised before or outside a controller: an invalid UTF-8 path (400), an unparsable `Accept` header (406) and a `ParseError` on a malformed body still use Rails' defaults. The report asks the owner whether D-078 should cover them. No change to the Dockerfile (step 14). No Rails upgrade.

## 8. How to verify it yourself

From `apps/api`, with Postgres running and the variables from section 3:

```sh
ruby -v                                 # ruby 3.4.3
bin/rails -v                            # Rails 8.1.3.1
bundle exec rspec                       # 140 examples, 0 failures
CI=1 bundle exec rspec                  # 140 examples, 0 failures
bundle exec rubocop                     # 51 files inspected, no offenses detected
bundle exec rails runner 'puts Rails.application.config.middleware.map(&:inspect)' \
  | grep -nE 'Origin|Cors|Cookies|Session|RemoteIp|ClientIp'
# 1:ApiSecurity::XOriginRemover
# 2:Rack::Cors
# 11:ApiSecurity::ClientIpSanitizer
# 12:ActionDispatch::RemoteIp
# 23:ActionDispatch::Cookies
# 24:ActionDispatch::Session::CookieStore
bin/rails routes                        # ... api_v1_csrf_token GET /api/v1/csrf_token(.:format) ...
                                        #     /api(/*unmatched) api/errors#not_found

# The boot checks
FRONTEND_ORIGIN= bin/rails about        # ApiSecurity::ConfigurationError: FRONTEND_ORIGIN is missing or blank ...
TRUSTED_PROXIES=10.0.0.1,bogus bin/rails about
                                        # ... TRUSTED_PROXIES contains "bogus", which is not an IP address or CIDR.
```

`FRONTEND_ORIGIN=` sets the variable to an empty string, and dotenv doesn't overwrite a variable that is already set, even an empty one. That is how you test the blank case without editing `.env`.

Then repeat step 13 with `bin/rails server` and `curl`. From the repository root:

```sh
git log --oneline main..feature/4-api-security-baseline     # spec commits before the implementation
git diff --stat main...feature/4-api-security-baseline -- apps/web .github/workflows/web.yml   # empty
```

## 9. What comes next

- **Feature 5** builds admin authentication on this chapter: the `admins` and `sessions` tables, login with `limit_requests scope: "login", to: 5, within: 3.minutes`, and the signed `session_id` cookie. Its mutating request specs start with `headers: csrf_headers`. Login must also rotate the session (`reset_session`) so a token issued before login can't be reused after it.
- **Feature 13** applies `limit_public_get_requests` to `/api/v1/public/...`. Phase 4's server-side loader sends `X-Internal-Token`.
- **Rails 8.1.4.1** (owner's decision): it fixes the json incompatibility, so the `gem "json"` line and its comment can go, and it fixes the advisories in section 7, trap 16. `spec/requests/api/json_body_spec.rb` stays as the guard.
- **Deployment** (D-036, D-081): confirm what `REMOTE_ADDR` Rails sees on Railway, set `TRUSTED_PROXIES` to the proxy's real ranges, confirm the proxy *appends* to `X-Forwarded-For`, and check the `::ffff:` mapping from trap 9.
- **Feature 24** revisits limits that fail open (trap 15).

## 10. Glossary

- **CORS / preflight** — the server telling the browser which other origins may read its responses / the `OPTIONS` request a browser sends first to ask.
- **CSRF / CSRF token** — a forged request sent with the victim's cookies / a per-session secret the API hands out and expects back in a header.
- **Concern** — a module a controller includes to receive methods, callbacks and class-level declarations.
- **Fail open / fail closed** — when a check can't be performed, allow the request / refuse it.
- **Fixed window** — a rate-limit counter whose lifetime starts with the first request and isn't extended by later ones.
- **Host-only cookie** — a cookie without a `Domain` attribute, sent back only to the exact host that set it.
- **Masked token** — a token XORed with a fresh random pad on each issue, so the same secret never appears twice in a response.
- **Middleware** — an object in the Rack stack that sees every request before the app and every response after it.
- **Origin / site** — scheme + host + port / the registrable domain (plus scheme), ignoring subdomain and port.
- **`REMOTE_ADDR` / `X-Forwarded-For`** — the address of whoever opened the TCP connection to Puma / a header in which proxies list the addresses a request came through.
- **`SameSite=Lax`** — the cookie isn't sent on cross-site subrequests, only on top-level navigations.
- **Scope (rate limit)** — the part of the counter's key naming the tier; controllers with the same scope share one count.
- **Trusted proxy** — an address `RemoteIp` skips when looking for the client, because it is known to be a proxy.
- **Zeitwerk / autoloading** — Rails' loader that finds a class from its file path, and reloads changed code in development.
