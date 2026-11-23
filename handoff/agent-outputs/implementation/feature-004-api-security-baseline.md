# Implementation Report — Feature 4: add the API security baseline with CORS, CSRF, rate limits and JSON errors

- **Date:** 2026-11-22
- **Branch:** `feature/4-api-security-baseline`
- **PR:** https://github.com/Myepes05/tintara-lab/pull/3
- **Status:** Completed. Every requirement is implemented and specified, and all six checks pass. Two findings need the owner (questions 1 and 2), and one verification step was blocked by this machine's Docker (deviation 4).
- **Decisions applied:** D-016, D-029, D-031, D-039, D-045, D-050, D-052, D-053, D-055, D-064, D-065, D-066, D-067, D-068, D-078, D-079, D-080, D-081

## Summary
The API now has a cookie session in API mode (`_tintara_session`: HttpOnly, SameSite=Lax, host-only, Secure in production), CORS for exactly `FRONTEND_ORIGIN` with credentials and `Retry-After` exposed, and `GET /api/v1/csrf_token`. Every request other than `GET`, `HEAD` and `OPTIONS` needs an `Origin` equal to `FRONTEND_ORIGIN` (checked first) and a valid `X-CSRF-Token`. All errors use the D-078 shape, and a catch-all answers JSON 404 for any unknown path or method under `/api`. Rate limits are built on Rails' `rate_limit`, with one declaration per tier and a shared scope per tier; the public GET tier (120/min, internal-token exemption) is applied to the token endpoint. A middleware in front of `ActionDispatch::RemoteIp` removes spoofable forwarding headers, using the same trusted list as `RemoteIp`. `FRONTEND_ORIGIN` and `API_INTERNAL_TOKEN` are required at boot.

Two problems surfaced that the prompt didn't anticipate:
- **`main` can't decode JSON.** `Gemfile.lock` pairs Rails 8.1.3.1 with json 3.0.2, so `ActiveSupport::JSON.decode` raises on every call. That breaks every JSON request body and every signed or encrypted cookie, including the session. Fixed here with a regression spec and a json pin (deviation 1, question 1).
- **rack-cors 3.0.0 copies `X-Origin` into a missing `Origin`**, which would have bypassed the D-079 missing-Origin rule. A small middleware removes the header first (deviation 2).

## Changes
| File / area | Change |
|---|---|
| `apps/api/Gemfile`, `Gemfile.lock` | `gem "rack-cors", "~> 3.0"` (locks 3.0.0); `gem "json", "~> 2.21", ">= 2.21.2"` (json 3.0.2 → 2.21.2, see deviation 1) |
| `apps/api/lib/api_security.rb` | `ApiSecurity` module, `ApiSecurity.config`, `ConfigurationError`; requires the files below |
| `apps/api/lib/api_security/configuration.rb` | Reads `FRONTEND_ORIGIN`, `API_INTERNAL_TOKEN`, `TRUSTED_PROXIES` from an env hash; required/blank/invalid-entry errors; Rails' defaults + entries; constant-time token match; redacted `inspect` |
| `apps/api/lib/api_security/session_cookie.rb` | Session cookie options, every attribute explicit |
| `apps/api/lib/api_security/trusted_proxies.rb` | The single effective trusted list (an `Enumerable` that reads `ApiSecurity.config`), plus `trust?` for a peer address |
| `apps/api/lib/api_security/client_ip_sanitizer.rb` | Middleware before `RemoteIp`: always removes `HTTP_CLIENT_IP` and `HTTP_FORWARDED`; removes `HTTP_X_FORWARDED_FOR` unless `REMOTE_ADDR` is trusted |
| `apps/api/lib/api_security/x_origin_remover.rb` | Middleware before `Rack::Cors`: removes `HTTP_X_ORIGIN` |
| `apps/api/config/application.rb` | Requires `lib/api_security`, has Zeitwerk ignore it, reads the configuration, adds cookie and session middleware, sets `trusted_proxies`, inserts the sanitizer |
| `apps/api/config/initializers/cors.rb` | rack-cors: one origin (exact comparison), `%r{\A/api(/|\z)}`, credentials, the seven methods, three headers, `expose: Retry-After`; `XOriginRemover` first |
| `apps/api/config/environments/test.rb` | `:null_store` → `:memory_store`; `allow_forgery_protection` `false` → `true`, with a comment saying it only reaches `ActionController::Base` |
| `apps/api/config/routes.rb` | `get "csrf_token"` in `api/v1`; `match "api(/*unmatched)", via: :all, format: false` after the namespace |
| `apps/api/app/controllers/application_controller.rb` | Includes `ActionController::Cookies`, `JsonErrors`, `RequestProtection`, `RateLimitTiers` |
| `apps/api/app/controllers/concerns/json_errors.rb` | `render_error(code, status:, message:, details: nil)`; `bad_request` and `not_found` rescues |
| `apps/api/app/controllers/concerns/request_protection.rb` | Forgery protection on, Rails' origin check off, `verify_request_origin` before `protect_from_forgery with: :exception`, token from the header only, two 403 renderers |
| `apps/api/app/controllers/concerns/rate_limit_tiers.rb` | `limit_requests(scope:, to:, within:, **options)`, `limit_public_get_requests`, JSON 429 with `Retry-After` |
| `apps/api/app/controllers/api/errors_controller.rb` | Catch-all 404, inherits `ActionController::API` directly (no checks, no session) |
| `apps/api/app/controllers/api/v1/csrf_tokens_controller.rb` | `GET /api/v1/csrf_token`, public GET tier |
| `apps/api/spec/...` | 9 new spec files and 3 support files (140 examples in total, 5 of them the existing health specs); `rails_helper.rb` clears `Rails.cache` before every example |
| `.env.example` (root) | Documents `FRONTEND_ORIGIN`, `API_INTERNAL_TOKEN`, `TRUSTED_PROXIES` |
| `.github/workflows/api.yml` | Two lines in the `test` job's `env:`; later, `runs-on: ubuntu-24.04` for both jobs, with a comment (deviation 8, chosen by the owner) |
| `CLAUDE.md` §7 | API line: the two required variables |
| `handoff/learning/04-api-security-baseline.md`, `handoff/learning/README.md` | Chapter 04 and its index row |

## Versions pinned (D-055)
| Tool / library | Version | Source verified |
|---|---|---|
| Ruby / Rails | 3.4.3 / 8.1.3.1 (unchanged) | `ruby -v`, `bin/rails -v` |
| rack-cors | 3.0.0 (`~> 3.0`) | RubyGems API (`/api/v1/versions/rack-cors.json`: 3.0.0, 2025-05-16, latest); `gem fetch` SHA-256 `7b95be61db39606906b61b83bd7203fa802b0ceaaad8fcb2fef39e097bf53f68` matches RubyGems; source read before use |
| json | 2.21.2 (`~> 2.21, >= 2.21.2`), was 3.0.2 | RubyGems API: newest 2.x (2026-07-31); `bundler-audit` json advisories are all patched at or below 2.21.2 |
| Rack / Puma / Solid Cache | 3.2.7 / 8.0.2 / 1.0.10 (unchanged) | `Gemfile.lock`; sources read for D-081 behaviour |

**Rails `rate_limit` options used** (from `actionpack-8.1.3.1/lib/action_controller/metal/rate_limiting.rb`):
- Line 66: `def rate_limit(to:, within:, by: -> { request.remote_ip }, with: -> { raise TooManyRequests }, store: cache_store, name: nil, scope: nil, **options)`, with `**options` passed to `before_action`.
- Line 75: the key `["rate-limit", scope, name, by].compact.join(":")`. Line 76: `store.increment(cache_key, 1, expires_in: within)`. Line 77: `if count && count > to`.
- Used: `to:`, `within:`, `by:` (explicitly `request.remote_ip`), `with:` (JSON 429), `store:` (`Rails.cache`, explicitly), `scope:` (one per tier), and `if:`/`unless:`/`only:` through `**options`.

**Fixed window, verified:** `MemoryStore#modify_value` keeps `entry.expires_at`, and Solid Cache's `adjusted_entry` passes `expires_at: entry.expires_at`. Neither extends the window on increment, so a client that keeps retrying is not blocked forever. A spec (`gives a new allowance when the window ends, even to a client that kept trying`) proves it for the test store. A production boot proved counting on the real `SolidCache::Store` (see the commands below).

## Spec-first evidence (D-050)
| Spec commit | Implementation commit | Behavior |
|---|---|---|
| `5d7081a` Feature 4: add specs for the API security baseline | `2a9cb97` Feature 4: implement the API security baseline | Everything in requirements 1 to 7 |
| `0ed2df0` Feature 4: add specs for JSON decoding, broken by json 3 on Rails 8.1.3.1, corrected by `783b644` (spec bug: a bare Hash is read as cookie options) | `1b9de3e` Feature 4: fix JSON decoding by holding json below 3 until Rails 8.1.4 | JSON request bodies, encrypted cookies |

```
$ git log --oneline main..HEAD        (before the report commit)
2652c4e Feature 4: fix the API CI jobs to run on ubuntu-24.04
2a9cb97 Feature 4: implement the API security baseline
1b9de3e Feature 4: fix JSON decoding by holding json below 3 until Rails 8.1.4
783b644 Feature 4: correct the encrypted cookie spec to pass the value as an option
0ed2df0 Feature 4: add specs for JSON decoding, broken by json 3 on Rails 8.1.3.1
5d7081a Feature 4: add specs for the API security baseline
```

**Red run at `5d7081a`** (`bundle exec rspec`, with `FRONTEND_ORIGIN` and `API_INTERNAL_TOKEN` exported): `138 examples, 115 failures`, 11.7 s. Grouped failure causes:
```
32 uninitialized constant ApiSecurity (22) / SecurityHelpers::ApiSecurity (10)
14 expected the response to have status code :forbidden (403) but it was :ok (200)
13 request 1 got 404                              (no /api/v1/csrf_token)
11 expected: "application/json"                   (HTML 404 pages)
10 expected: "http://localhost:5173"              (no CORS headers)
 6 expected ... :ok (200) but it was :not_found (404)
 5 undefined local variable or method 'limit_public_get_requests'
 4 expected: value != "198.51.100.7"             (blank/unparsable peer trusted XFF)
 4 IpSpoofAttackError (raised / "expected no Exception")
 2 undefined method 'render_error'
 ... and single cookie, header and middleware-order expectations
```
The 23 that passed at `5d7081a` were all expected to: the 5 health specs; GET/HEAD/OPTIONS "not blocked"; the "valid token + correct Origin succeeds" cases (no protection existed yet); "accepts a JSON request" (its handler reads no parameter); `/up` and health "not limited"; three trusted-peer `X-Forwarded-For` cases (Rails' default behaviour, already right); the foreign-origin, non-`/api` and `X-Internal-Token` preflights (no CORS at all); and HEAD on the catch-all.

**Red run of the JSON specs** at `0ed2df0` and again at `783b644` (clean export of each, json 3.0.2): `2 examples, 2 failures` (`:bad_request (400)` and `ArgumentError: wrong number of arguments (given 2, expected 1)`). Full suite at `783b644`: `140 examples, 117 failures`.

## Commands run and results
```
$ ruby -v
ruby 3.4.3 (2025-04-14 revision d0b7e5b6a0) +PRISM [x86_64-darwin25]
$ bin/rails -v
Rails 8.1.3.1

# on main, before branching
$ bundle exec rspec            5 examples, 0 failures
$ bundle exec rubocop          28 files inspected, no offenses detected

# on the branch (FRONTEND_ORIGIN=http://localhost:5173, API_INTERNAL_TOKEN set)
$ bundle exec rspec
140 examples, 0 failures       (Finished in 5.48 seconds)
$ bundle exec rspec --order rand
140 examples, 0 failures       (Randomized with seed 13396)
$ CI=1 bundle exec rspec       (eager loading, as in CI)
140 examples, 0 failures
$ bundle exec rubocop
51 files inspected, no offenses detected

$ bundle exec rails runner 'puts Rails.application.config.middleware.map(&:inspect)' | cat -n
     1	ApiSecurity::XOriginRemover
     2	Rack::Cors
     3	ActionDispatch::HostAuthorization
     4	Rack::Sendfile
     5	ActionDispatch::Static
     6	ActionDispatch::Executor
     7	ActionDispatch::ServerTiming
     8	ActiveSupport::Cache::Strategy::LocalCache::Middleware
     9	Rack::Runtime
    10	ActionDispatch::RequestId
    11	ApiSecurity::ClientIpSanitizer
    12	ActionDispatch::RemoteIp
    13	Rails::Rack::Logger
    14	ActionDispatch::ShowExceptions
    15	ActionDispatch::DebugExceptions
    16	ActionDispatch::ActionableExceptions
    17	ActionDispatch::Reloader
    18	ActionDispatch::Callbacks
    19	ActiveRecord::Migration::CheckPending
    20	Rack::Head
    21	Rack::ConditionalGet
    22	Rack::ETag
    23	ActionDispatch::Cookies
    24	ActionDispatch::Session::CookieStore

$ bin/rails routes
            Prefix Verb URI Pattern                  Controller#Action
rails_health_check GET  /up(.:format)                rails/health#show
     api_v1_health GET  /api/v1/health(.:format)     api/v1/health#show
 api_v1_csrf_token GET  /api/v1/csrf_token(.:format) api/v1/csrf_tokens#show
                        /api(/*unmatched)            api/errors#not_found

# boot checks (no variables in the root .env on this machine)
$ bin/rails db:prepare
ApiSecurity::ConfigurationError: FRONTEND_ORIGIN is missing or blank. Set it in the environment (in development, the repository-root .env; see .env.example).
$ API_INTERNAL_TOKEN=x bin/rails about        ... FRONTEND_ORIGIN is missing or blank ...
$ FRONTEND_ORIGIN=x bin/rails about           ... API_INTERNAL_TOKEN is missing or blank ...
$ FRONTEND_ORIGIN=x API_INTERNAL_TOKEN=y TRUSTED_PROXIES=10.0.0.1,bogus bin/rails about
... TRUSTED_PROXIES contains "bogus", which is not an IP address or CIDR. (ApiSecurity::ConfigurationError)
$ bin/rails db:prepare        (with the variables)   exit 0

# bin/rails server, then:
$ curl -si -X OPTIONS http://localhost:3000/api/v1/csrf_token -H 'Origin: http://localhost:5173' -H 'Access-Control-Request-Method: POST' -H 'Access-Control-Request-Headers: x-csrf-token'
HTTP/1.1 200 OK
access-control-allow-origin: http://localhost:5173
access-control-allow-methods: GET, POST, PATCH, PUT, DELETE, OPTIONS, HEAD
access-control-expose-headers: Retry-After
access-control-max-age: 7200
access-control-allow-credentials: true
access-control-allow-headers: x-csrf-token
content-length: 0

$ curl -si http://localhost:3000/api/v1/csrf_token -H 'Origin: http://localhost:5173'
HTTP/1.1 200 OK
access-control-allow-origin: http://localhost:5173
access-control-expose-headers: Retry-After
access-control-allow-credentials: true
content-type: application/json; charset=utf-8
vary: Accept, Origin
set-cookie: _tintara_session=...; path=/; httponly; samesite=lax
cache-control: max-age=0, private, must-revalidate
{"csrf_token":"Pciyp3D7dkznmIuhfUp79nUsXiwzeiBtViVPOnoiqcExPjl74vGIFrt527i6lg3zZLOfXdcK0LumTqixwIQthQ"}

$ curl -si -X POST http://localhost:3000/api/v1/does-not-exist
HTTP/1.1 404 Not Found
content-type: application/json; charset=utf-8
{"error":{"code":"not_found","message":"The requested resource was not found."}}

$ curl -si http://localhost:3000/api/v1/nope
HTTP/1.1 404 Not Found
content-type: application/json; charset=utf-8
{"error":{"code":"not_found","message":"The requested resource was not found."}}

# rate limit through the real server (curl's peer, loopback, is a trusted proxy, so X-Forwarded-For sets the key)
$ for i in {1..121}; do curl ... -H 'X-Forwarded-For: 198.51.100.50' .../api/v1/csrf_token; done | sort | uniq -c
 120 200
   1 429
HTTP/1.1 429 Too Many Requests
access-control-allow-origin: http://localhost:5173
access-control-expose-headers: Retry-After
retry-after: 60
{"error":{"code":"rate_limited","message":"Too many requests. Try again later."}}

# production boot (clean export of the branch, RAILS_ENV=production, random SECRET_KEY_BASE,
# throwaway database tintara_f4_verify_prod on the dev Postgres, dropped afterwards)
$ bin/rails db:prepare (without the variables)   ApiSecurity::ConfigurationError: FRONTEND_ORIGIN is missing or blank ...
$ bin/rails db:prepare (with them)               ok
$ curl -si http://localhost:3001/api/v1/csrf_token -H 'Origin: https://www.example.test'
HTTP/1.1 200 OK
access-control-allow-origin: https://www.example.test
set-cookie: _tintara_session=...; path=/; secure; httponly; samesite=lax
121 requests:  120 200, 1 429 (retry-after: 60, D-078 body)
store: SolidCache::Store, counter value 122 after the last call

# Dockerfile build steps, clean export, neither variable set
$ bundle exec bootsnap precompile -j 1 --gemfile      exit 0
$ bundle exec bootsnap precompile -j 1 app/ lib/      exit 0
```

### Final verification (prompt commands), on `2652c4e`, before the commit that adds this report
```
$ git status --porcelain --untracked-files=all
 M handoff/learning/README.md
?? handoff/learning/04-api-security-baseline.md
(only the report, chapter 04 and its index row, committed next)

$ git diff --stat main...HEAD -- apps/web .github/workflows/web.yml
(empty)

$ gh pr view --json title,url,state
{"state":"OPEN","title":"Feature 4: add the API security baseline with CORS, CSRF, rate limits and JSON errors","url":"https://github.com/Myepes05/tintara-lab/pull/3"}

$ gh pr checks
API RSpec	pass	59s
API RuboCop	pass	48s
Web Build	pass	13s
Web ESLint	pass	14s
Web Jest	pass	24s
Web TypeScript	pass	16s
```

### Mutation check
Thirty deliberate breakages were applied one at a time to a scratch copy of `apps/api`, each followed by `bundle exec rspec --fail-fast`. **All thirty were caught.** Script, as run (`python3 -I mutants.py <copy of apps/api>`):

```python
import subprocess,sys,os,re
root=sys.argv[1]
c='app/controllers/concerns/'
M=[
('no X-Origin remover','config/initializers/cors.rb','Rails.application.config.middleware.insert_before 0, ApiSecurity::XOriginRemover',''),
('keep Client-IP','lib/api_security/client_ip_sanitizer.rb','      env.delete("HTTP_CLIENT_IP")\n',''),
('keep Forwarded','lib/api_security/client_ip_sanitizer.rb','      env.delete("HTTP_FORWARDED")\n',''),
('trust every peer','lib/api_security/client_ip_sanitizer.rb',' unless @trusted_proxies.trust?(env["REMOTE_ADDR"])',' if false'),
('drop XFF always','lib/api_security/client_ip_sanitizer.rb',' unless @trusted_proxies.trust?(env["REMOTE_ADDR"])',''),
('replace defaults','lib/api_security/configuration.rb','(ActionDispatch::RemoteIp::TRUSTED_PROXIES + parse_proxies(trusted_proxies))','parse_proxies(trusted_proxies)'),
('RemoteIp own list','config/application.rb','    config.action_dispatch.trusted_proxies = ApiSecurity::TrustedProxies\n',''),
('per-controller scope',c+'rate_limit_tiers.rb','scope: scope, store','scope: nil, store'),
('no exemption',c+'rate_limit_tiers.rb','unless: -> { ApiSecurity','unless: -> { false && ApiSecurity'),
('empty token matches','lib/api_security/configuration.rb','return false if internal_token.blank? || candidate.nil?','return false if candidate.nil?'),
('limit all methods',c+'rate_limit_tiers.rb','                     if: -> { request.get? || request.head? },\n',''),
('no Retry-After',c+'rate_limit_tiers.rb','      response.set_header("Retry-After", retry_after.to_i.to_s)\n',''),
('not exposed','config/initializers/cors.rb','expose: %w[Retry-After]','expose: []'),
('no credentials','config/initializers/cors.rb','credentials: true','credentials: false'),
('any origin','config/initializers/cors.rb','origin == ApiSecurity.config.frontend_origin','true'),
('string path','config/initializers/cors.rb','resource %r{\\A/api(/|\\z)}','resource "/api/*"'),
('Origin optional',c+'request_protection.rb','render_invalid_origin unless request.origin','render_invalid_origin unless request.origin.nil? || request.origin'),
('token first',c+'request_protection.rb','    before_action :verify_request_origin\n    protect_from_forgery with: :exception\n','    protect_from_forgery with: :exception\n    before_action :verify_request_origin\n'),
('Rails origin check',c+'request_protection.rb','self.forgery_protection_origin_check = false','self.forgery_protection_origin_check = true'),
('protection off',c+'request_protection.rb','self.allow_forgery_protection = true','self.allow_forgery_protection = false'),
('param token',c+'request_protection.rb','[ request.x_csrf_token ]','super'),
('OPTIONS checked',c+'request_protection.rb',' || request.options?',''),
('details kept',c+'json_errors.rb','details: details.presence','details: details'),
('catch-all inherits protection','app/controllers/api/errors_controller.rb','< ActionController::API\n    include JsonErrors','< ApplicationController'),
('null store','config/environments/test.rb',':memory_store',':null_store'),
('no cache clear','spec/rails_helper.rb','config.before { Rails.cache.clear }',''),
('not httponly','lib/api_security/session_cookie.rb','httponly: true','httponly: false'),
('never secure','lib/api_security/session_cookie.rb','secure: environment.to_s == "production"','secure: false'),
('no session middleware','config/application.rb','    config.middleware.use config.session_store, config.session_options\n',''),
('leaky inspect','lib/api_security/configuration.rb','frontend_origin=#{frontend_origin.inspect}>','#{instance_variables.map { |v| instance_variable_get(v) }}>'),
]
env={**os.environ,'DISABLE_BOOTSNAP_COMPILE_CACHE':'1'}
for name,f,a,b in M:
    p=os.path.join(root,f); s=open(p).read()
    assert s.count(a)==1,(name,s.count(a))
    open(p,'w').write(s.replace(a,b))
    try: r=subprocess.run(['bundle','exec','rspec','--fail-fast'],cwd=root,env=env,capture_output=True,text=True,timeout=90)
    finally: open(p,'w').write(s)
    m=re.search(r'\d+ examples, \d+ failures?.*',r.stdout)
    print('CAUGHT ' if r.returncode else 'MISSED ',name,'|',m.group(0) if m else r.stdout[-200:],flush=True)
```

Result lines, in order:
```
CAUGHT  no X-Origin remover | 94 examples, 1 failure
CAUGHT  keep Client-IP | 27 examples, 1 failure
CAUGHT  keep Forwarded | 30 examples, 1 failure
CAUGHT  trust every peer | 24 examples, 1 failure
CAUGHT  drop XFF always | 38 examples, 1 failure
CAUGHT  replace defaults | 10 examples, 1 failure
CAUGHT  RemoteIp own list | 23 examples, 1 failure
CAUGHT  per-controller scope | 122 examples, 1 failure
CAUGHT  no exemption | 118 examples, 1 failure
CAUGHT  empty token matches | 121 examples, 1 failure
CAUGHT  limit all methods | 124 examples, 1 failure
CAUGHT  no Retry-After | 113 examples, 1 failure
CAUGHT  not exposed | 70 examples, 1 failure
CAUGHT  no credentials | 57 examples, 1 failure
CAUGHT  any origin | 55 examples, 1 failure
CAUGHT  string path | 56 examples, 1 failure
CAUGHT  Origin optional | 94 examples, 1 failure
CAUGHT  token first | 95 examples, 1 failure
CAUGHT  Rails origin check | 89 examples, 1 failure
CAUGHT  protection off | 90 examples, 1 failure
CAUGHT  param token | 92 examples, 1 failure
CAUGHT  OPTIONS checked | 98 examples, 1 failure
CAUGHT  details kept | 88 examples, 1 failure
CAUGHT  catch-all inherits protection | 74 examples, 1 failure
CAUGHT  null store | 25 examples, 1 failure
CAUGHT  no cache clear | 26 examples, 1 failure
CAUGHT  not httponly | 18 examples, 1 failure
CAUGHT  never secure | 18 examples, 1 failure
CAUGHT  no session middleware | 90 examples, 1 failure
CAUGHT  leaky inspect | 8 examples, 1 failure
```

## Error codes (D-078), for the API contract (D-051)
Shape: `{ "error": { "code": "<code>", "message": "<message>", "details": { ... } } }`. `details` is omitted when empty, and none of these codes sets it.

| Code | Status | Message | When |
|---|---|---|---|
| `invalid_origin` | 403 | `The request origin is not allowed.` | A method other than GET, HEAD and OPTIONS whose `Origin` is missing or not exactly `FRONTEND_ORIGIN`. Checked before the token |
| `invalid_csrf_token` | 403 | `The CSRF token is missing or invalid.` | `X-CSRF-Token` missing, wrong, or from another session (`ActionController::InvalidAuthenticityToken`). A token in the `authenticity_token` parameter isn't accepted |
| `rate_limited` | 429 | `Too many requests. Try again later.` | A tier's limit exceeded; `Retry-After` is the window in seconds (`60` for the public tier) |
| `bad_request` | 400 | `The request is invalid or missing a required parameter.` | `ActionController::ParameterMissing` |
| `not_found` | 404 | `The requested resource was not found.` | `ActiveRecord::RecordNotFound` (the model isn't named), and any path or method under `/api` that has no route |

`render_error(code, status:, message:, details: nil)` is available to every controller that includes `JsonErrors` (all controllers through `ApplicationController`).

## Environment variables (D-080)
| Variable | Required | Rule | Development | CI (`api.yml`, test job) |
|---|---|---|---|---|
| `FRONTEND_ORIGIN` | Yes, every environment | Missing or blank stops boot with `FRONTEND_ORIGIN is missing or blank ...`. Compared with `==` for CORS and the Origin check: scheme, host and port, no trailing slash | `http://localhost:5173` | `http://localhost:5173` |
| `API_INTERNAL_TOKEN` | Yes, every environment | Missing or blank stops boot. Compared with `secure_compare` against `X-Internal-Token`; a match skips only the public GET tier; an empty value never matches | Random; must equal `API_INTERNAL_TOKEN` in `apps/web/.env` | `tintara_ci_internal_token` |
| `TRUSTED_PROXIES` | No | Comma-separated IPs or CIDRs, spaces ignored, **added** to Rails' defaults (`127.0.0.0/8`, `::1`, `fc00::/7`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`, `fe80::/10`). Unset or empty: defaults only. An invalid entry stops boot, naming it | empty | not set |

The variables are read once, in `config/application.rb`, into `ApiSecurity.config`. Code reads them only from there, and specs replace them with `use_api_security(...)` (one stub).

**Note for the owner:** this machine's root `.env` has neither required variable, and I didn't edit it (it is your local file). I passed them on the command line for every run. Until you add them (`.env.example` has them, chapter 04 section 3 gives a command), `bin/rails` commands stop with the error above.

## Acceptance criteria
- [x] Every requirement is implemented, each with a spec committed first: `5d7081a` before `2a9cb97`, and `0ed2df0`/`783b644` before `1b9de3e`.
- [x] `bundle exec rspec` (140, 0 failures) and `bundle exec rubocop` (51 files, no offenses) pass locally. Outputs above.
- [x] All six required checks pass on the PR. On `2652c4e`: `API RuboCop`, `API RSpec`, `Web Build`, `Web ESLint`, `Web Jest`, `Web TypeScript` all `pass`. The first run on `2a9cb97` failed in both API jobs' "Set up Ruby" (deviation 8).
- [x] rack-cors 3.0.0 verified on RubyGems and pinned `~> 3.0`. The Rails `rate_limit` options are cited from source above.
- [x] The root `.env.example` documents the three variables. No `.env` or real token is committed (`git status --porcelain --untracked-files=all` is empty; the only token in the repository is the CI test value and the example placeholder).
- [ ] `api.yml` changes only in the `test` job's `env:`: **not met, by the owner's choice.** The two variables (and a comment) are in the job `env:`, but both jobs also moved from `ubuntu-latest` to `ubuntu-24.04` (deviation 8). Triggers and permissions are unchanged.
- [x] Every error code, status and message is listed, and every variable with its rule.
- [x] Chapter 04 is written and indexed. It covers CORS vs CSRF vs SameSite (section 2 table), Rails' origin check (step 1, section 5, trap 6), the counter isolation (section 5), why `trusted_proxies` alone doesn't stop spoofing (section 5), and the fail-open risk (trap 15). Reproducibility: it starts from chapter 03's end state and gives the command that adds the new `.env` variables. Every file listing in section 5 was generated from the committed file by a script, not retyped.
- [x] PR opened with the exact title; report and chapter committed to the branch; not merged.
- [x] Nothing in `apps/web` or `web.yml` (`git diff --stat main...HEAD -- apps/web .github/workflows/web.yml` is empty). One dependency pin outside the plan: deviation 1.
- [x] Session ends on `main`.

## Deviations from the prompt
1. **json held below 3 (`gem "json", "~> 2.21", ">= 2.21.2"`).** Not in the prompt, but required by it: the session cookie (requirement 1) is an encrypted cookie, and Rails 8.1.3.1 can't read one with json 3.0.2, the version already locked on `main`. The bug also breaks every JSON request body, on `main` today. It was proved on a clean export of `main` (`ActiveSupport::JSON.decode('{"a":1}')` → `ArgumentError: wrong number of arguments (given 2, expected 1)`; a JSON POST → `ParseError`; an encrypted cookie read → the same `ArgumentError`). It went in as the smallest change: one transitive gem, a regression spec first (`spec/requests/api/json_body_spec.rb`), and its own commit (`1b9de3e`) that can be reverted alone. The real fix is Rails 8.1.4.1 (question 1). If you would rather fix it as `fix 1` on `main` first, `1b9de3e` and the JSON spec commits can move there as they are.
2. **`ApiSecurity::XOriginRemover` middleware.** rack-cors 3.0.0 runs `env[HTTP_ORIGIN] ||= env[HTTP_X_ORIGIN] if env[HTTP_X_ORIGIN]` (`lib/rack/cors.rb:67`) before Rails sees the request, so a request without `Origin` but with `X-Origin: <frontend>` would pass requirement 3.3. D-079 says a missing `Origin` is refused, so the header is removed in front of rack-cors, with a spec. This is a conflict between the documentation-follows rule and D-079, and I resolved it toward D-079, which requires an exact `Origin`. Please confirm.
3. **`config.action_controller.allow_forgery_protection` in `test.rb` is set to `true`, not just removed, and the real switch is in the controller.** Rails applies `config.action_controller.*` with `send(k, v) if respond_to?(k)` (`action_controller/railtie.rb:93`), and `ActionController::API` doesn't respond to `allow_forgery_protection=` when that runs. Proved in the test environment: `{test_config: false}`, `{api_allow: true, base_allow: false}`. The old `false` never reached our controllers, so `RequestProtection` sets `allow_forgery_protection = true` and `forgery_protection_origin_check = false` on the controller class. The `test.rb` line now says `true` with a comment explaining that it only reaches `ActionController::Base`, rather than a setting that looks meaningful and isn't.
4. **The Docker image was not built.** Every pull from Docker Hub, including the Dockerfile's `docker/dockerfile:1` frontend, hung with no output for over five minutes behind Docker Desktop's proxy (`HTTPProxy=http.docker.internal:3128`), while `curl` reached `registry-1.docker.io` directly (401, as expected). I stopped after two attempts. What I verified instead: the Dockerfile's build steps don't boot Rails (both `bootsnap precompile` steps exit 0 with neither variable set), and the production behaviour, from a `RAILS_ENV=production` boot on a clean export (results above). The Dockerfile is unchanged. A container started without the two variables will stop in `bin/docker-entrypoint`'s `db:prepare`, by design.
5. **The public GET tier counts only `GET` and `HEAD`** (`if: -> { request.get? || request.head? }`). The prompt names it the "public GET tier" but doesn't say what happens if a controller in the tier has a `POST`. Without the condition, a `POST` would spend the GET allowance. It has a spec. Remove it if you prefer the tier to count every method.
6. **Specs beyond the list.** Added because they guard behaviour the implementation depends on: every mutating verb (not only `POST`); token from another session; token as a parameter refused; `X-Origin`; similar-looking origins (`/` suffix, uppercase, `.evil` suffix); the window resetting for a client that kept retrying; the GET-only tier; the exemption not applying to another tier; the catch-all creating no session and ignoring a malformed body; `/apiary` outside CORS; `X-Internal-Token` not allowed in a preflight; the redacted `inspect`; and the two JSON-decoding examples.
7. **Test endpoints live under `/test/...`, not under `/api`.** Routes drawn by a spec are appended after the `/api` catch-all, which would answer first. The protections under test belong to `ApplicationController`, so the path doesn't change what is tested. They are drawn per example and removed with `reload_routes!`.
8. **`runs-on: ubuntu-24.04` for both API jobs (commit `2652c4e`).** The first CI run failed in "Set up Ruby" for both API jobs: `Error: Unavailable version 3.4.3 for ruby on ubuntu-26.04`. `ubuntu-latest` had moved to Ubuntu 26.04 (`Image: ubuntu-26.04`, `Version: 20261116.202.1`) after `main`'s last API run (2026-10-23, success), and `ruby/ruby-builder`'s toolcache release has `ruby-3.4.3-ubuntu-22.04` and `-24.04` builds but none for 26.04. That conflicted with requirement 7.4 ("change nothing else in the workflow") and with D-028 (Ruby 3.4.3), so I stopped and asked. The owner chose pinning the runner over changing Ruby. The re-run on `2652c4e` passed all six checks (`140 examples, 0 failures` and `51 files inspected, no offenses detected` on `Image: ubuntu-24.04`). **`main` still has `ubuntu-latest` and will fail the same way on its next API run until this PR merges.** `web.yml` also uses `ubuntu-latest`, but it passed (it doesn't install Ruby) and is out of scope.
9. **`handoff/learning/README.md` says "The table above is updated by the orchestrator"**, while `CLAUDE.md` §7b tells the implementation agent to add the row. I followed `CLAUDE.md` and the prompt, and added the row.

## Learning chapter
- **File:** `handoff/learning/04-api-security-baseline.md`
- **Index updated:** yes
- **Traps documented:** json 3 vs Rails 8.1.3.1 on `main`; `config.action_controller` not reaching `ActionController::API`; rack-cors `X-Origin`, string origins and `"/api/*"`; per-controller rate-limit scope; Rails' origin check; token accepted from parameters; `127.0.0.1` hiding spoofing in specs; `IPAddr` raising and `::ffff:` mapping; `trusted_proxies` replacing defaults; `insert_before 0` order; a slow red run from a helper; the encrypted-cookie Hash trap; test routes vs the catch-all; fail-open; bundler-audit; what was deliberately not done.

## Questions for the owner
1. **Upgrade Rails to 8.1.4.1, and when?** It fixes the json incompatibility (the pin and its comment can then go; `json_body_spec.rb` stays as the guard). `bundle exec bundler-audit check` also reports advisories on `main` that 8.1.4.1 fixes. Most are in components this app doesn't load (Active Storage, Action Mailbox, Action View helpers). One High advisory is close to this feature: **GHSA-2gff-2mmg-m73p, "Possible IP spoofing in Action Dispatch RemoteIp"** (Rack 3 prefers a client-supplied `Forwarded` header). This branch is not exposed to it, because `ClientIpSanitizer` always deletes `Forwarded`, which is the advisory's own mitigation, and a spec proves it. Other gems with advisories on `main`: rack 3.2.7 (fixed in >= 3.2.8), puma 8.0.2 (>= 8.0.4), nokogiri, loofah, crass, rails-html-sanitizer, msgpack. This looks like a `fix N` task or an addition to the next prompt; I changed none of them.
2. **Should D-078 cover errors raised outside a controller action?** These still use Rails' default JSON error body (`{"status":...,"error":...,"exception":...}` in development), not D-078, and none is in the prompt's list: an invalid UTF-8 path such as `/api/%FF` (400 `ActionController::BadRequest`); an unparsable `Accept` header (406, even on the catch-all); a malformed JSON body read by an action (400 `ParseError`); a conflicting query string read by an action (400); and any 500. Making them D-078 needs `config.exceptions_app` or a rescue middleware. That is a design choice, so I didn't make it. Puma itself answers unknown verbs such as `PROPFIND` with 501 before Rails sees them.
3. **IPv4-mapped peers (deployment check).** `IPAddr.new("10.0.0.0/8") === "::ffff:10.0.0.5"` is `false`, in Rails' `RemoteIp` and so in the sanitizer, which uses the same comparison. If Puma ever binds `::` (its own default when IPv6 is available; `bin/rails server` binds `0.0.0.0` in production), a proxy on a private IPv4 address would appear as `::ffff:...` and count as untrusted. That fails safe (no spoofing, but all visitors share the proxy's counter). Worth adding to the D-081 Railway check.
4. **Deviation 2 (`X-Origin`)**: confirm that removing the header is what you want.

## Suggested follow-ups (not implemented)
- Upgrade Rails and the gems in question 1; then remove the json pin.
- Run `bundler-audit` and Brakeman in CI (already in the status carry-over notes). They would have flagged question 1 automatically.
- `FRONTEND_ORIGIN` with a trailing slash or a path never matches anything, silently. A boot-time format check (scheme + host + optional port) would catch it. Not added, because the prompt defines only the missing and blank errors.
- `TRUSTED_PROXIES=0.0.0.0/0` (or `::/0`) is accepted and would trust every peer, re-opening spoofing. Consider refusing it at boot.
- Feature 5: rotate the session on login (`reset_session`), so a token issued before login doesn't stay valid in the admin session.
- Feature 5 onward: per-IPv6-address limits can be rotated across a /64 by one client. Consider keying IPv6 by prefix if abuse appears.

## How to verify manually
1. Add `FRONTEND_ORIGIN=http://localhost:5173` and `API_INTERNAL_TOKEN=<random>` to the root `.env` (see `.env.example`).
2. From `apps/api`: `bundle install`, `bin/rails db:prepare`, `bundle exec rspec` (140 examples, 0 failures), `bundle exec rubocop`.
3. `bin/rails server`, then run the four `curl` commands from the prompt's verification section; expected output is above.
4. Remove `FRONTEND_ORIGIN` from `.env` and run `bin/rails about`: it stops with `FRONTEND_ORIGIN is missing or blank`.
5. `git log --oneline main..feature/4-api-security-baseline`: the spec commits come before `1b9de3e` and `2a9cb97`.
