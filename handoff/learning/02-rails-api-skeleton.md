# Chapter 02 — The Rails API skeleton: RSpec, RuboCop and CI

**Task:** Feature 2 · **Decisions:** D-028, D-031, D-033, D-042, D-050, D-052, D-055, D-058, D-062, D-063, D-066 · **Code:** PR [#1](https://github.com/Myepes05/tintara-lab/pull/1)

## 1. What we are building in this chapter

At the end of this chapter, `apps/api` holds a Rails 8.1 API-only application that connects to the Postgres container from chapter 01, has RSpec and RuboCop running clean, answers one endpoint — `GET /api/v1/health` — and is checked automatically by GitHub Actions on every pull request.

One endpoint sounds like very little for a chapter this long. It is the point: the endpoint is a thread pulled through the entire stack. If `/api/v1/health` returns `{"status":"ok"}` in CI, then the app boots, the database configuration is right, the routes are versioned correctly, the specs run, the linter passes, and the workflow's Postgres service works. Everything after this builds on machinery that is already proven.

## 2. What you need to know first

- **Rails.** A Ruby web framework organised around conventions: files in expected places are wired together without configuration. `bin/rails` is the project's own command-line entry point.
- **API-only app.** A Rails app generated with `--api`: no HTML views, no cookies-and-forms middleware, no asset pipeline. It renders JSON. Rails calls this `config.api_only = true`. Our frontend is a separate React application (chapter 03), so the API never renders a page.
- **Gem / Gemfile / Gemfile.lock / Bundler.** A gem is a Ruby library. The `Gemfile` lists which ones the app wants; Bundler resolves them and writes the exact resolved versions into `Gemfile.lock`, which is committed so every machine and CI install identical versions. `bundle exec <cmd>` runs a command with exactly those versions.
- **Migration / schema.** A migration is a Ruby file describing a change to the database (create this table, add this column). `db/schema.rb` is the generated snapshot of the resulting structure, committed so a new database can be built in one step.
- **RSpec.** The testing framework used here instead of Rails' built-in Minitest. A *spec* is a test file; a *request spec* boots the app and makes a real HTTP request through the full stack.
- **FactoryBot.** Builds test records ("give me a valid Album") so tests do not hand-assemble data. **shoulda-matchers** gives one-line assertions for common Rails behaviour, for example `it { is_expected.to validate_presence_of(:title) }`. Neither is used yet — no models exist — but both are wired now so the first model can use them immediately.
- **RuboCop.** Ruby's linter and formatter: it enforces a style so reviews argue about behaviour instead of spacing.
- **Continuous integration (CI).** A service that runs your lint and tests automatically on every change. Here it is **GitHub Actions**: YAML files in `.github/workflows/` describing *jobs* made of *steps*, run on a fresh virtual machine GitHub provides.
- **Service container.** In GitHub Actions, an extra container started alongside the job — for us a Postgres, so the specs have a real database.
- **Environment variable.** Same idea as chapter 01: configuration passed in from outside the code. Ruby reads them through `ENV`.

## 3. Starting point

The repository exactly as chapter 01 left it: one commit on `main`, a working `docker compose` Postgres, root scaffolding, and an `apps/` directory containing only `.gitkeep`. No Ruby code anywhere.

Before starting, get the branch, the database and the Ruby toolchain into the state the rest of this chapter assumes. All of this runs **from the repository root**:

```sh
git status                       # clean
git pull
git checkout -b feature/2-rails-api-skeleton

cp .env.example .env             # only if chapter 01 did not leave you one
docker compose up -d
docker compose ps                # wait until the db service says (healthy)

ruby -v                          # ruby 3.4.3
gem install rails -v "~> 8.1"    # see below
rails -v                         # Rails 8.1.3.1
```

- **Why `gem install rails` is here.** Chapter 01 verified that Ruby was installed; it never installed Rails, because there was no Rails app yet. `rails new` in step 1 comes from the `rails` gem, installed once for the whole machine rather than per project — a project's own Rails version is then pinned in its `Gemfile` and used through `bundle exec`. If `rails -v` already prints a `8.1.x` version, skip the install.
- **Why the container must be healthy before you go on.** `docker compose up -d` returns as soon as the container *starts*, which is a second or two before Postgres accepts connections. Step 4 ends by creating databases; starting it against a container that is still booting produces a connection error that looks like a configuration mistake.
- Ruby 3.4.3 and Rails 8.1 are fixed by D-028. Check what is actually installed rather than assuming — D-055 exists because "should be fine" is how a project acquires a dependency nobody chose.

Steps 1 and 9 run from the repository root; steps 2 to 8 run from `apps/api`. Each step says where it is, so you can pick the chapter up in the middle.

## 4. Step by step

### Step 1 — Generate the application

- **Where:** the repository root.
- **Command:**
  ```sh
  rails new apps/api --api --database=postgresql \
    --skip-test --skip-action-cable --skip-active-storage --skip-action-mailbox \
    --skip-jbuilder --skip-kamal --skip-ci

  rm -rf apps/api/.git            # see the note below; this is not optional
  ```
- **What it does:** creates the whole Rails application inside `apps/api` and runs `bundle install`.
- **Flag by flag** (the skips are D-063; each one is a component with a decided reason not to exist here):

  | Flag | What it removes | Why we do not need it |
  |---|---|---|
  | `--api` | Views, helpers, asset pipeline, browser middleware (cookies, sessions, flash) | The frontend is a separate React app; this app only renders JSON |
  | `--database=postgresql` | — (chooses the adapter) | Matches the container from chapter 01 and production |
  | `--skip-test` | Rails' built-in Minitest setup and the `test/` directory | RSpec is the project's framework; keeping both would mean two test suites and two conventions |
  | `--skip-action-cable` | WebSockets | Nothing in this product is realtime |
  | `--skip-active-storage` | Rails' file-attachment system and its three tables | Images go directly to Cloudinary from the browser; the API only stores identifiers and issues upload signatures (D-023) |
  | `--skip-action-mailbox` | Receiving inbound email | The app sends mail (contact notifications, password resets) but never receives any |
  | `--skip-jbuilder` | A template language for building JSON | How responses are serialized is decided together with the API contract (D-051); adding a tool before the decision prejudges it |
  | `--skip-kamal` | Kamal deployment configuration | Deployment is deferred and the intended target is Railway, not Kamal (D-036) |
  | `--skip-ci` | `apps/api/.github/workflows/ci.yml` and `apps/api/.github/dependabot.yml` | **This one is not in D-063 — I added it.** Rails 8.1 generates a CI workflow *inside the app directory*, and GitHub only ever reads workflows from `.github/workflows/` at the **repository root**. In a monorepo that generated file never runs: it is a dead file that looks alive, and a future reader would reasonably assume it is what CI does. We write the real workflow at the root in step 9 |

- **Kept on purpose:** Action Mailer (D-014), Solid Cache and Solid Queue (D-052), Brakeman and RuboCop, plus the generated `.ruby-version`, `Dockerfile` and `.dockerignore`.
- **What you should see:** a long list of `create` lines, then `bundle install`, then `rails solid_cache:install solid_queue:install`.

> **Do this from the repository root and expect a nested `.git`.** `rails new` runs `git init` in the new directory unless you pass `--skip-git`. Inside an existing repository that produces a repository inside a repository, which breaks `git status` in confusing ways. Delete it: `rm -rf apps/api/.git`. Do **not** reach for `--skip-git` to avoid it — that flag also skips generating `.gitignore` and `.gitattributes`, and Rails' `.gitignore` is the thing keeping your credentials key out of the repository. Generate them, delete the nested repo. (I learned this the tidy way round: I used `--skip-git` first, found `apps/api/.gitignore` missing, and regenerated.)

### Step 2 — Add the remaining gems

- **Where:** from here to step 8, `apps/api`:
  ```sh
  cd apps/api
  ```
- **File:** additions to `apps/api/Gemfile`, inside the existing `group :development, :test do` block:
  ```ruby
    # Loads the repository-root .env so development and test share one set of
    # credentials [https://github.com/bkeepers/dotenv]
    gem "dotenv-rails", "~> 3.2"

    # Testing framework [https://github.com/rspec/rspec-rails]
    gem "rspec-rails", "~> 8.0"

    # Fixtures replacement [https://github.com/thoughtbot/factory_bot_rails]
    gem "factory_bot_rails", "~> 6.5"
  end

  group :test do
    # One-liner matchers for common Rails behavior [https://github.com/thoughtbot/shoulda-matchers]
    gem "shoulda-matchers", "~> 8.0"
  end
  ```
- **What `group` means:** gems in `:development, :test` are not installed or loaded in production. Test tooling has no business being loadable on a production server, and `dotenv` must not be there either — production gets its configuration from the platform, not from a file.
- **Why `~>`:** the "pessimistic" version constraint. `~> 8.0` accepts 8.0, 8.1, 8.9 but never 9.0 — patches and features, never a breaking major. Versions were checked against RubyGems rather than remembered (D-055): rspec-rails 8.0.4, factory_bot_rails 6.5.1, shoulda-matchers 8.0.1, dotenv-rails 3.2.0.
- **Command:** `bundle install`.

### Step 3 — Point the app at the container, without copying credentials

- **File:** `apps/api/config/database.yml` — replace the generated file with the version annotated in section 5.
- **What it reads:** the `POSTGRES_USER`, `POSTGRES_PASSWORD` and `POSTGRES_PORT` you already have in the repository-root `.env` from chapter 01. Nothing new is added to that file here; if you skipped the `cp .env.example .env` at the top of this chapter, do it now.
- **File:** `apps/api/config/application.rb`, inserted immediately after `Bundler.require(*Rails.groups)`:
  ```ruby
  # In development and test, read the repository-root .env, the single place where
  # the Postgres container credentials are defined. dotenv never overwrites
  # variables that are already set, so CI keeps using its own environment.
  if defined?(Dotenv::Rails)
    Dotenv::Rails.files = [ File.expand_path("../../../.env", __dir__) ]
  end
  ```
- **What it does:** `database.yml` reads `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER` and `POSTGRES_PASSWORD` from the environment. The dotenv line tells the gem to load the `.env` at the **repository root** — the same file `docker compose` reads — instead of its default, an `.env` next to the Rails app.
- **Why this way:** the alternative is a second `.env` inside `apps/api`, which means the container's password exists in two files that must be kept in step by hand. The first time they drift, you get a connection error whose cause is invisible. One file, two readers.
- **Why those three details matter:**
  - `File.expand_path("../../../.env", __dir__)` — `__dir__` is `apps/api/config`, so three levels up is the repository root. It is relative to the file, not to the shell's working directory, so it works whether you run `bin/rails` from `apps/api` or from anywhere else.
  - **The placement is not arbitrary.** `Dotenv::Rails.files` must be assigned *before* `class Application < Rails::Application` is evaluated, because defining that class is what triggers Rails' `before_configuration` hooks, which is when dotenv loads the files. Put the assignment below the class and it runs too late, silently doing nothing.
  - `if defined?(Dotenv::Rails)` — the gem only exists in development and test, so in production this block simply does not run.
- **The CI half of the promise:** dotenv **never overwrites a variable that is already set**. In GitHub Actions there is no root `.env` at all, and the same variables arrive from the workflow's environment. Same `database.yml`, two sources, no conditional code.

### Step 4 — Put Solid Cache and Solid Queue on the primary database

This is the biggest departure from what Rails generates, and it gets its own explanation in section 5. In short: Rails 8 wants three databases; we want one (D-052). Section 5 lists four changes — three file edits and the move of the Solid tables into migrations — and this step ends by creating the databases.

- **The three file edits** are described in full in section 5: drop the `cache:` and `queue:` connections from `config/database.yml` production, drop `database: cache` from `config/cache.yml` production, and delete the `config.solid_queue.connects_to` line from `config/environments/production.rb`.
- **The migrations.** `rails new` already ran the Solid installers for you, so `db/cache_schema.rb` and `db/queue_schema.rb` are sitting in the app — they are verbatim copies of the gems' own templates. Turn each into an ordinary migration and delete the original:
  ```sh
  # For each of the two files: create db/migrate/<timestamp>_create_solid_<x>_tables.rb
  # containing the schema file's body, wrapped in a migration class.
  ls db/cache_schema.rb db/queue_schema.rb      # the source files
  ls db/migrate/                                # where they must end up
  rm db/cache_schema.rb db/queue_schema.rb      # only after the migrations exist
  ```
  In this repository the result is `db/migrate/20260915000001_create_solid_cache_tables.rb` and `db/migrate/20260915000002_create_solid_queue_tables.rb`; section 5 shows the wrapper. Copy the bodies, never retype them — the tables have to be exactly what the gems expect.
- **Then create the databases:**
  ```sh
  bin/rails db:prepare
  ```
- **What `db:prepare` does:** creates each database if it is missing, loads `db/schema.rb` into it, and runs any migration that has not run yet — so it works both on an empty machine and on an existing one. Run from development it prepares the **test** database as well, which is why one command is enough here.
- **What you should see** — the two databases, then your two migrations, which is also what writes `db/schema.rb` for the first time:
  ```
  Created database 'tintara_lab_development'
  Created database 'tintara_lab_test'
  == 20260915000001 CreateSolidCacheTables: migrating ===========================
  -- create_table("solid_cache_entries", {force: :cascade})
     -> 0.0103s
  == 20260915000001 CreateSolidCacheTables: migrated (0.0103s) ==================

  == 20260915000002 CreateSolidQueueTables: migrating ===========================
  ... 13 create_table and 8 add_foreign_key lines ...
  == 20260915000002 CreateSolidQueueTables: migrated (0.1549s) ==================
  ```
  and then **the same two migrations a second time**, against the test database. That repetition is not a bug and it is the whole reason one command suffices: `db:prepare` handles development and test together. On later runs, once `db/schema.rb` exists, it loads the schema instead and the migration lines do not appear at all.
- **Why this is the point at which it belongs.** Up to now nothing has touched Postgres, so nothing could have failed. From step 5 on, every command needs a database: RSpec boots the app in the test environment and connects. Run `bundle exec rspec` before this and you get a connection error, not an empty suite.

### Step 5 — Install RSpec and its companions

- **Command:**
  ```sh
  bin/rails generate rspec:install
  ```
  creates `.rspec`, `spec/spec_helper.rb` and `spec/rails_helper.rb`.
- **Then, in `spec/rails_helper.rb`, uncomment the support-file line** so it reads:
  ```ruby
  Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }
  ```
- **File:** `spec/support/factory_bot.rb`
  ```ruby
  # Lets specs call `create` and `build` without the FactoryBot prefix.
  RSpec.configure do |config|
    config.include FactoryBot::Syntax::Methods
  end
  ```
- **File:** `spec/support/shoulda_matchers.rb`
  ```ruby
  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
  ```
- **Why this way:** configuration lives in small files under `spec/support/` rather than piling up inside `rails_helper.rb`, so each concern can be read, moved or deleted on its own.
- **What you should see:** `bundle exec rspec` reports `0 examples, 0 failures`. An empty suite that runs is a real milestone — it proves the app boots in the test environment and reaches the test database. That second half only holds because step 4 ended with `bin/rails db:prepare`; without it this command aborts with `connection to server ... failed: FATAL: database "tintara_lab_test" does not exist`.
- **Commit the scaffold** before writing any spec, so the spec-first evidence in the next two steps is unambiguous:
  ```sh
  git add .      # you are in apps/api, so this stages the app and nothing else
  git commit -m "Feature 2: scaffold the Rails 8.1 API app with RSpec, RuboCop and Postgres"
  ```
  `git` works from any subdirectory of the repository, so the paths in this step and the next two are relative to `apps/api`, not to the repository root.

### Step 6 — Write the spec first, and watch it fail

- **File:** `apps/api/spec/requests/api/v1/health_spec.rb`
  ```ruby
  require "rails_helper"

  RSpec.describe "GET /api/v1/health", type: :request do
    before { get "/api/v1/health" }

    it "responds with 200 OK" do
      expect(response).to have_http_status(:ok)
    end

    it "responds with JSON" do
      expect(response.media_type).to eq("application/json")
    end

    it "reports the status as ok" do
      expect(response.parsed_body["status"]).to eq("ok")
    end

    it "reports a parsable timestamp" do
      expect { Time.iso8601(response.parsed_body["time"]) }.not_to raise_error
    end

    it "exposes nothing but the status and the time" do
      expect(response.parsed_body.keys).to match_array(%w[status time])
    end
  end
  ```
- **Command:** `bundle exec rspec`
- **What you should see — and this is the step, not a mishap:**
  ```
  5 examples, 5 failures
  ...
  actual collection contained:    []
  the missing elements were:      ["status", "time"]
  ```
  Five failures, and they fail for the *right reason*: the route does not exist, so Rails answers the request with its 404 error page. The body is not empty — it is about 67 KB of HTML — but `response.parsed_body` parses a `text/html` response into a Nokogiri document, and a document has no JSON keys, so `parsed_body.keys` is `[]` and `parsed_body["status"]` is `nil`. The other failures say the same thing from different angles: `expected: "application/json" got: "text/html"`, and a 404 where a 200 was expected.

  That distinction is what the step is for. A spec that passes before the feature exists is testing nothing — it happens more often than anyone admits, usually because a matcher is too loose or the request never actually ran. Seeing red first, and reading *why* it is red, is the only cheap proof that the spec is wired to the thing it claims to check. A 404 HTML page is the *right* red: the request reached the routing stack and was rejected there, rather than blowing up earlier in a way that would have hidden whether the spec works at all.
- **Then commit the spec on its own:**
  ```sh
  git add spec/requests && git commit -m "Feature 2: add specs for the health endpoint"
  ```
- **Why the separate commit:** D-042 requires spec-first work; D-050 requires *evidence* of it. A branch where the spec commit precedes the implementation commit proves the order was real. If both arrive in one commit, nobody — including you, next month — can tell which was written first.

### Step 7 — Implement until it passes

- **File:** `apps/api/config/routes.rb`, added below the generated `/up` route:
  ```ruby
    # The application API lives under /api/v1 (D-031).
    namespace :api do
      namespace :v1 do
        get "health", to: "health#show"
      end
    end
  ```
- **File:** `apps/api/app/controllers/api/v1/health_controller.rb`
  ```ruby
  module Api
    module V1
      # Confirms that the API boots and can answer a request. It deliberately
      # returns nothing beyond the status and the current time.
      class HealthController < ApplicationController
        def show
          render json: { status: "ok", time: Time.current.utc.iso8601 }
        end
      end
    end
  end
  ```
- **What `namespace` does:** it maps the URL prefix, the module nesting and the directory layout together. `namespace :api { namespace :v1 { ... } }` means the URL `/api/v1/health`, the class `Api::V1::HealthController`, and the file `app/controllers/api/v1/health_controller.rb`. Rails finds the class from the path by convention; get the directory wrong and you get an uninitialized-constant error rather than a routing error.
- **Why versioned** (D-031): `/api/v1/...` means a future breaking change can ship as `/api/v2/...` while old clients keep working. Retrofitting a version prefix onto a live API is a coordinated migration; putting it there from the first endpoint costs nothing.
- **Why the response is so bare:** it says `status` and `time` and nothing else. Health endpoints are unauthenticated and, on a public repository and a public host, world-visible. The tempting version reports the Rails version, the environment name, the database status, the migration count — and hands an attacker a free inventory of what you run and how old it is. The fifth example in the spec (`exposes nothing but the status and the time`) exists to keep a well-meaning future addition out.
- **Command:** `bundle exec rspec` → `5 examples, 0 failures`.
- **Then commit:**
  ```sh
  git add config/routes.rb app/controllers/api/v1/health_controller.rb
  git commit -m "Feature 2: implement the health endpoint under /api/v1"
  ```

### Step 8 — Check it by hand, and from a genuinely empty database

- **Commands** (still in `apps/api`; `bin/rails server` does not return, so run the `curl` in a second terminal and stop the server with Ctrl-C when you are done):
  ```sh
  bin/rails server
  ```
  ```sh
  curl -si localhost:3000/api/v1/health
  ```
- **What you should see:**
  ```
  HTTP/1.1 200 OK
  content-type: application/json; charset=utf-8
  ...
  {"status":"ok","time":"2026-09-16T03:43:54Z"}
  ```
- **Then prove a clean machine works:**
  ```sh
  bin/rails db:drop db:prepare
  bin/rails runner 'puts ActiveRecord::Base.connection.tables.sort.join(", ")'
  ```
  All 16 tables come back, Solid Cache and Solid Queue included. Specs passing against a database you have been incrementally migrating for an hour says nothing about whether a new contributor — or CI — can build it from nothing. Drop it and watch it rebuild.

### Step 9 — The CI workflow

- **Where:** back at the repository root — the workflow does **not** live inside the app.
  ```sh
  cd ../..
  ```
- **File:** `.github/workflows/api.yml` at the **repository root** (annotated in section 5).
- **What it does:** on every pull request into `main` and every push to `main` that touches `apps/api/**`, GitHub runs two jobs on fresh machines: RuboCop, and RSpec against a Postgres 18 service container.
- **Command to confirm the YAML parses before pushing:**
  ```sh
  ruby -ryaml -e "YAML.safe_load_file('.github/workflows/api.yml', aliases: true); puts 'YAML OK'"
  ```
- **Then commit it**, along with the `CLAUDE.md` §7 API line that this task also fills in:
  ```sh
  git add .github/workflows/api.yml CLAUDE.md
  git commit -m "Feature 2: add the API CI workflow and document the commands"
  ```
- **What you should see** after pushing and opening the pull request:
  ```sh
  $ gh run list --branch feature/2-rails-api-skeleton --limit 1
  completed  success  Feature 2: ...  API  feature/2-rails-api-skeleton  pull_request  35052956324  1m8s
  ```

### Step 10 — Open the pull request, do not merge

From the repository root, with `git status` clean — every step above ended in a commit:

```sh
git status                                        # nothing uncommitted
git push -u origin feature/2-rails-api-skeleton

cp .github/pull_request_template.md /tmp/pr-body.md
$EDITOR /tmp/pr-body.md                           # fill in every section

gh pr create --base main \
  --title "Feature 2: create the Rails API skeleton with RSpec, RuboCop and CI" \
  --body-file /tmp/pr-body.md
```

The template is the one chapter 01 committed: Summary, Task, Decisions implemented, How it was tested, Implementation report, Checklist. `gh pr create` does not read it for you, so filling a copy by hand and passing it with `--body-file` is how you get the same body every time — typing it into `--body` inline loses the structure the first time someone is in a hurry.

The title is the squash commit that will land on `main` (chapter 01, step 11), so it must match the convention exactly. Merging is the owner's job, after review and QA.

## 5. The important files, explained

### `config/database.yml`

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  max_connections: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  host: <%= ENV.fetch("POSTGRES_HOST", "localhost") %>
  port: <%= ENV.fetch("POSTGRES_PORT", 5432) %>
  username: <%= ENV["POSTGRES_USER"] %>
  password: <%= ENV["POSTGRES_PASSWORD"] %>

development:
  <<: *default
  database: tintara_lab_development

test:
  <<: *default
  database: tintara_lab_test

production:
  adapter: postgresql
  encoding: unicode
  max_connections: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  url: <%= ENV["DATABASE_URL"] %>
```

- **`<%= ... %>`** — the file is run through ERB, Ruby's template language, before being parsed as YAML. That is how environment variables get in.
- **`&default` and `<<: *default`** — YAML anchors: define a block once, merge it into others. Two databases, one connection definition.
- **`host` and `port` have defaults, credentials do not.** `ENV.fetch("POSTGRES_PORT", 5432)` falls back to 5432; `ENV["POSTGRES_USER"]` returns `nil` when unset, and a `nil` username fails the connection with a clear error. Same reasoning as the compose file in chapter 01: defaults for things with an obvious correct value, silence-then-failure for things that must be supplied deliberately. **No credential appears anywhere in this file.**
- **`POSTGRES_PORT` is the same variable `docker-compose.yml` uses.** Change it once in the root `.env` and both the container and Rails follow. That is the whole reason the app reads the root file.
- **`max_connections`** — Rails 8.1's name for what older versions called `pool`: how many connections this process keeps. It tracks `RAILS_MAX_THREADS` so the pool matches the web server's thread count.
- **Separate `tintara_lab_development` and `tintara_lab_test` databases** — the test database is wiped and rebuilt constantly. Pointing both at one database means your development data disappears the first time you run the suite.
- **Production is a single `url`.** The host supplies `DATABASE_URL`; nothing else is declared, which is the other half of the Solid Cache and Solid Queue decision below.

### Solid Cache and Solid Queue on one database (D-052)

**What they are.** Rails 8 ships two "Solid" components that replace services you would otherwise run separately. **Solid Cache** is a cache store (`Rails.cache`) backed by a database table instead of Redis or Memcached. **Solid Queue** is a background-job backend: when code calls `deliver_later` to send an email, the job is written to a table and a separate worker process picks it up. Both trade a little raw speed for one fewer service to run, pay for and monitor — which is why this project has no Redis at all (D-028).

**What Rails 8 does by default.** It assumes each gets its own database. Out of the generator you get:
- three connections in `config/database.yml` production: `primary`, `cache` and `queue`, each with its own `migrations_paths`;
- `config/cache.yml` production saying `database: cache`;
- `config/environments/production.rb` containing `config.solid_queue.connects_to = { database: { writing: :queue } }`;
- the tables kept *outside* the normal migration flow, in standalone files `db/cache_schema.rb` and `db/queue_schema.rb`.

**What we changed, and why.** One Postgres on the host is simpler and cheaper, and at this traffic level — a photographer's portfolio — three databases buy nothing but three things to provision, back up and forget to migrate. Four edits:

1. **`config/database.yml`** production declares one connection from `DATABASE_URL`; the `cache:` and `queue:` entries are gone.
2. **`config/cache.yml`** production no longer says `database: cache`, so Solid Cache uses the app's own connection:
   ```yaml
   production:
     <<: *default
   ```
3. **`config/environments/production.rb`** no longer sets `config.solid_queue.connects_to`, so Solid Queue writes to the primary connection too.
4. **The tables become ordinary migrations.** `db/cache_schema.rb` and `db/queue_schema.rb` were copied verbatim into `db/migrate/20260915000001_create_solid_cache_tables.rb` and `db/migrate/20260915000002_create_solid_queue_tables.rb`, wrapped in a migration class, and the schema files deleted:
   ```ruby
   class CreateSolidCacheTables < ActiveRecord::Migration[8.1]
     def change
       create_table "solid_cache_entries", force: :cascade do |t|
         t.binary "key", limit: 1024, null: false
         ...
       end
     end
   end
   ```
   The contents were taken from the installed gems' own templates (`solid_cache-1.0.10/lib/generators/.../db/cache_schema.rb` and the equivalent for `solid_queue-1.7.0`), not retyped, so the tables are exactly what the gems expect. The only change RuboCop made was array-bracket spacing.

**Why the migrations step is required, not cosmetic.** Those standalone schema files are only loaded when Rails prepares the database they name. Delete the `cache` and `queue` connections without moving their tables and `db:prepare` produces an app that boots fine and fails the first time a job is enqueued, with a missing-table error. Once they are migrations, the tables are part of `db/schema.rb`, and `bin/rails db:prepare` builds all 16 tables from an empty database in one step.

**One more line, in `config/environments/test.rb`:**
```ruby
  # Jobs run through the Active Job test adapter, so specs never need a
  # Solid Queue worker (D-052).
  config.active_job.queue_adapter = :test
```
The test adapter records enqueued jobs in memory instead of writing them to a table for a worker to pick up. Without it, a spec that triggers an email would either wait for a worker nobody started, or pass while quietly doing nothing.

### `spec/rails_helper.rb` (the parts that matter)

```ruby
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
```

`maintain_test_schema!` compares the test database against `db/schema.rb` and reloads it when they differ; if there are migrations that were never run, the suite **aborts with a loud message** instead of running against a stale database. This is generated code, kept deliberately: green tests on the wrong schema are worse than no tests.

`.rspec` contains `--require spec_helper`, so `spec_helper.rb` (framework-level settings, no Rails) loads for everything. Specs that need the app require `rails_helper` themselves, as the health spec does on its first line.

### `.github/workflows/api.yml`

```yaml
name: API

on:
  push:
    branches: [ main ]
    paths:
      - "apps/api/**"
      - ".github/workflows/api.yml"
  pull_request:
    branches: [ main ]
    paths:
      - "apps/api/**"
      - ".github/workflows/api.yml"

# Least privilege for the job token: neither job writes anything back to the
# repository, and this repository is readable by everyone (D-059, D-066).
permissions:
  contents: read

defaults:
  run:
    working-directory: apps/api

jobs:
  lint:
    name: RuboCop
    runs-on: ubuntu-latest
    steps:
      - name: Check out the repository
        uses: actions/checkout@v7

      # ruby-version is omitted on purpose: setup-ruby then reads
      # apps/api/.ruby-version, resolved from working-directory.
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
          working-directory: apps/api

      - name: Lint
        run: bundle exec rubocop

  test:
    name: RSpec
    runs-on: ubuntu-latest

    # Throwaway credentials for the service container below. They exist only
    # for the lifetime of this job and grant access to nothing else.
    env:
      POSTGRES_USER: tintara_ci
      POSTGRES_PASSWORD: tintara_ci_password
      POSTGRES_HOST: localhost
      POSTGRES_PORT: 5432
      RAILS_ENV: test

    services:
      postgres:
        image: postgres:18
        env:
          POSTGRES_USER: tintara_ci
          POSTGRES_PASSWORD: tintara_ci_password
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U tintara_ci"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10

    steps:
      - name: Check out the repository
        uses: actions/checkout@v7

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
          working-directory: apps/api

      - name: Prepare the test database
        run: bin/rails db:prepare

      - name: Run the specs
        run: bundle exec rspec
```

Section by section:

- **`on:`** — the triggers. Pull requests targeting `main` (so nothing merges unverified) and pushes to `main` (so the branch everyone builds on is always known-good).
- **`paths:`** — the monorepo essential. Without it, every frontend-only change would run the Ruby suite and every backend change would run the JavaScript one: slower feedback, and a wall of irrelevant green checks that trains people to ignore them. The workflow file lists **itself** in the filter, because a change to the workflow must be tested by the workflow. Two details worth knowing: for `pull_request` events GitHub evaluates the filter against every file changed in the whole pull request, not just the latest push — which is why adding this chapter to PR #1 re-ran the API workflow even though the commit touched only `handoff/`. And a path-filtered workflow that does not run reports *no status at all* rather than a passing one, which matters when you later make it a required status check (D-060).
- **`permissions:` — the job token, and why it is turned down (D-066).** Every workflow run is handed an automatic credential, `GITHUB_TOKEN`: a short-lived token, created for that run and revoked when it ends, that authenticates as the workflow against this repository's API. It is what lets a workflow push a commit, comment on a pull request, publish a release or a package. You never create it and it is always there, which is exactly why it is easy to forget it exists.

  How much that token can do, when a workflow says nothing, is **a repository setting rather than a property of the workflow** — Settings → Actions → General → Workflow permissions, readable from the command line:

  ```sh
  $ gh api repos/Myepes05/tintara-lab/actions/permissions/workflow
  {"default_workflow_permissions":"read","can_approve_pull_request_reviews":false}
  ```

  Here it is already `read`, which is the safe value. That is worth being precise about: the line below is not fixing a permissive token, it is making the safe one **independent of a setting that lives outside the file**. Anyone with admin access can flip that setting to `write`, and every workflow that declared nothing silently gets a writable token, with no commit and no review anywhere. A workflow that declares its own permissions is unaffected.

  Neither job here writes anything — they check out the code, install gems, and run two commands that only read. So the workflow says so:

  ```yaml
  permissions:
    contents: read
  ```

  Naming even one scope switches the token to **default-deny**: every scope you did not list becomes `none`, so this token can read the repository's contents and do nothing else. Declared at the top level it applies to both jobs; a `permissions:` block inside a single job overrides it for that job, which is how you would grant, say, `pull-requests: write` to one job that posts a comment without widening the rest.

  **Why bother on a small project.** The token is only as trustworthy as everything the run executes, and a CI run executes a great deal of third-party code: two actions, plus every gem `bundle install` resolves. A compromised dependency in a run whose token can write is a path to a commit on `main`; the same dependency in a run whose token can only read has nowhere to go. This repository is readable by everyone (D-059), so its source, its workflows and the shape of its dependencies are public knowledge — there is no obscurity to lean on. The line costs nothing, it is not a response to any incident, and it is the habit that matters: **give a workflow the narrowest token that lets it do its job.** `web.yml` in chapter 03 declares the same thing from the start.

  **Where this was missed the first time.** The workflow shipped without this block and QA flagged it as advisory rather than a defect — correctly, since nothing was broken. It was added in a follow-up round once the owner decided it (D-066). Worth noticing as a pattern: the things that are easiest to leave out of a workflow are the ones nothing fails without.
- **`defaults.run.working-directory: apps/api`** — every `run` step executes inside the app directory, so the steps read `bundle exec rspec` rather than a `cd` prefix on each line. It applies only to `run` steps, not to `uses:` steps — which is why `setup-ruby` needs its own `working-directory` input.
- **Two jobs, `lint` and `test`.** They run in parallel on separate machines. You learn "the style is wrong" and "the behaviour is wrong" at the same time instead of one after the other, and a red X names which kind of problem it is before you open anything.
- **`actions/checkout@v7`** — copies your repository onto the runner. Nothing is there by default.
- **Pinned action versions, verified rather than remembered** (D-055). The majors were read from the actions' own repositories at the time of writing:
  ```sh
  gh api repos/actions/checkout/releases/latest --jq .tag_name   # v7.0.1
  gh api repos/ruby/setup-ruby/releases/latest  --jq .tag_name   # v1.323.0
  ```
  A major tag like `v7` keeps receiving that major's fixes. An unpinned `@main` would let a third party change what runs in your CI without a commit in your repository.
- **`ruby/setup-ruby@v1` with no `ruby-version`** — deliberate, and it surprised me. This action has **no `ruby-version-file` input** at all; its `action.yml` documents that `ruby-version` defaults to reading `.ruby-version`, `.tool-versions` or `mise.toml` resolved against `working-directory`. Setting `working-directory: apps/api` therefore *is* how you say "use `apps/api/.ruby-version`". Inventing a `ruby-version-file:` key, as several Ruby CI examples online show, gets you an unknown-input warning and the wrong Ruby. Reading the action's own `action.yml` took thirty seconds and settled it.
- **`bundler-cache: true`** — runs `bundle install` and caches the result keyed on `Gemfile.lock`, so later runs take seconds.
- **`services:`** — the Postgres container for this job. The **healthcheck is not optional here**: without it the steps start the moment the container starts, and `db:prepare` races the database's startup. It is the same `pg_isready` idea as chapter 01's compose file, expressed in Docker's flag syntax because Actions passes `options` straight to `docker run`.
- **`ports: - 5432:5432`** — publishes the service's port onto the runner, so `POSTGRES_HOST: localhost` reaches it.
- **Credentials in plain sight, on purpose.** `tintara_ci` / `tintara_ci_password` are written directly in the file. They are not a secret and must not be treated as one: they belong to a database that is created inside one job and destroyed with it, reachable only from that runner, holding nothing but test fixtures. Putting them in GitHub Secrets would add ceremony, make the workflow unreadable to anyone who has not been granted access, and — worst — blur the line so that one day something that *is* a secret gets written here "because the other one was". The rule stays sharp: **nothing real is ever in this file.** Real credentials (Cloudinary, SMTP) arrive as GitHub Secrets or platform environment variables, and the app reads them through `ENV` exactly as it does here.
- **`RAILS_ENV: test`** at the job level, so both `db:prepare` and `rspec` act on the test database.

## 6. Decisions behind this chapter

| Decision | What we chose | What we rejected | Why |
|---|---|---|---|
| D-028 | Ruby 3.4.3, Rails 8.1, API mode | A full Rails app; adding Redis | The frontend is separate; Rails 8 covers cache and jobs on Postgres |
| D-063 | Skip Action Cable, Active Storage, Action Mailbox, Minitest, Jbuilder, Kamal | Generating everything and deleting later | Each skipped component has a decided reason not to exist; fewer moving parts, fewer tables, smaller dependency surface |
| D-031 | Routes under `/api/v1` from the first endpoint | An unversioned `/api` | A future breaking change ships as `v2` while old clients keep working; retrofitting a prefix is a migration |
| D-052 | Solid Cache and Solid Queue on the primary database | Rails 8's separate `cache` and `queue` databases | One database to provision, back up and migrate; nothing at this scale needs three |
| D-042, D-050 | Spec written and committed before the implementation | Writing tests afterwards, or in the same commit | A test written after the code tends to assert what the code does; the commit order is the only durable evidence of the discipline |
| D-062 | RuboCop as Rails 8 ships it (`rubocop-rails-omakase`) | A custom `rubocop-rails` + `rubocop-rspec` configuration | Zero configuration, framework convention, no review time spent on style debates; rules can be tightened later with a reason |
| D-033 | CI runs lint and tests only, path-filtered per app | One workflow for the whole monorepo; adding deployment now | Fast, relevant feedback; deployment is a separate decision (D-036) |
| D-066 | `permissions: contents: read` declared at workflow level | Relying on the repository's default token permission | Neither job writes; declaring it makes the narrow token part of the file instead of a setting someone can flip elsewhere |
| D-055 | Versions verified from RubyGems and the actions' repositories, and reported | Copying versions from memory or a tutorial | Half of CI folklore is two majors out of date |
| D-058 | Postgres 18 service in CI, matching development | Whatever image an example used | Development, CI and production should not differ in a major database version |

## 7. Traps, mistakes and things we avoided

**1. `rails new` creates a git repository inside your git repository.** Covered in step 1. Delete `apps/api/.git`; do not reach for `--skip-git`, which also skips `.gitignore` and `.gitattributes`. I hit this in the reverse order — used `--skip-git`, noticed `apps/api/.gitignore` was missing, and regenerated — which is how the second trap surfaced at all.

**2. Rails generates a CI workflow that can never run.** `apps/api/.github/workflows/ci.yml` looks like working CI and is inert, because GitHub only reads workflows from the repository root. `--skip-ci` removes it. This is a monorepo-specific trap: in a single-app repository the generated file is exactly right.

**3. The root `.gitignore` outranks the app's own negation, and `tmp/.keep` is not tracked.** Rails' `apps/api/.gitignore` says `/tmp/*` then `!/tmp/.keep`, intending to keep the empty directory in git. It does not work here, because chapter 01's root `.gitignore` contains a bare `tmp/`, which excludes `apps/api/tmp/` as a **directory**. Git never descends into an excluded directory, so the negation inside the nested file is unreachable — the same rule as chapter 01's `.vscode/*` versus `.vscode/`, arriving from the other side. The practical effect is small (Rails recreates `tmp/`, `tmp/cache` and `tmp/pids` on boot; the server and the specs were both verified), so it was left alone rather than fixed: changing a file from another task was outside this task's scope, and it is recorded as a follow-up instead. The fix, when someone takes it, is to narrow the root rule to `/tmp/` — with a leading slash it matches only the repository root's own `tmp/`, and each app's `.gitignore` governs its own.

**4. `storage/` is not in `.gitignore`, and should not be.** The task description asked to confirm it was ignored. Rails only adds that entry when Active Storage is present, and we skipped Active Storage (D-063), so no `storage/` directory exists. Adding the line "to be safe" would leave a rule describing a component this app does not have, which is the kind of thing that convinces a future reader that Active Storage was once installed. When a checklist item does not apply, say why instead of manufacturing compliance.

**5. `bin/rails db:prepare` on a database you have been using proves nothing.** Drop it and rebuild: `bin/rails db:drop db:prepare`. This is what caught whether the Solid Cache and Solid Queue migrations were really wired into the primary schema. A migration that exists but is never run on a fresh database is a bug waiting for your first deploy.

**6. Test the CI path locally before pushing.** Before opening the pull request I moved the root `.env` aside, exported the same variables by hand, and ran `db:prepare` and `rspec` — which is exactly what CI does. It confirmed the dotenv wiring degrades correctly when the file is absent (dotenv's `load` ignores a missing file; only `load!` raises) and that nothing secretly depended on the file existing. The alternative is discovering it through a red pull request and a five-minute feedback loop per attempt.

**7. `Dotenv::Rails.files` must be set before the `Application` class is defined.** Defining `class Application < Rails::Application` is what fires the `before_configuration` hooks that dotenv uses to load files. Assign the setting after that line and it is simply ignored — no error, no warning, just an app that cannot find the database and a configuration line that looks correct.

**8. `ruby/setup-ruby` has no `ruby-version-file` input.** Read `action.yml` from the action's repository rather than copying a workflow from a blog post. Inputs get invented in examples and the action ignores what it does not know.

**9. Solid Cache and Solid Queue keep their tables outside `db/migrate`.** Removing their separate databases without moving those schema files produces an app that boots and then fails the first time a job is enqueued. The failure lands far from the change that caused it.

**10. `config/master.key` must never be committed — and losing it is also a real cost.** `rails new` generates two files: `config/credentials.yml.enc`, an encrypted file for secrets, and `config/master.key`, the key that decrypts it. The key is ignored by Rails' own `.gitignore` rule `/config/*.key`; the encrypted file **is** committed, which is the whole design — secrets travel in the repository, safely, and only holders of the key can read them. Verify rather than trust:
   ```sh
   $ git check-ignore -v apps/api/config/master.key
   apps/api/.gitignore:25:/config/*.key   apps/api/config/master.key
   ```
   Two ways to get this wrong. Commit the key on a repository anyone can read (D-059) and every secret in the encrypted file is compromised the moment it is pushed — the fix is to rotate the credentials, not to delete the file. Or lose the key — it exists on exactly one machine and is in no backup by default — and `credentials.yml.enc` becomes permanently unreadable; the only way forward is to delete it and start over. Copy the key somewhere safe outside the repository now, while it protects nothing more than a generated `secret_key_base`.

**11. A health endpoint is an information-disclosure surface.** Ours returns `status` and `time`, and a spec asserts that nothing else appears. Rails' generated `/up` (kept, untouched) is a different thing: it returns HTML and a 500 if the app fails to boot, and it exists for load balancers and uptime monitors. Ours is the API's own contract under `/api/v1`, and versioned with it.

**12. A chapter can be accurate line by line and still not work.** This one was. Every command in it ran, every output was real — but the author's machine already had a `rails` gem installed and databases created, so those steps were never written down, and a reader following in order hit a connection error where the chapter promised `0 examples, 0 failures`. QA caught it by trying to reproduce the chapter rather than by reading it, and the project turned it into a rule (**D-067**): a chapter must be followable from the previous chapter's end state, and where the author had state the reader lacks — a container, a gem, a database, an environment variable — the chapter has to say how the reader gets it. The habit that prevents it is cheap: after writing, re-read the steps as someone who has only finished the previous chapter, and ask of every command what it silently assumes.

**Deliberately not done:** authentication and sessions (Feature 5); CORS, CSRF, rate limiting and the shared error format (Feature 4); any domain model, migration or seed (Phase 3); serializers, which are decided together with the API contract (D-051). Also present but unused: `bin/ci` and `config/ci.rb` ship with Rails 8.1 and run setup, RuboCop, bundler-audit and Brakeman locally — and no test step, because `--skip-test` meant the generator never wrote one; Brakeman and bundler-audit are installed but not yet run in CI, which is a recorded follow-up rather than an oversight.

## 8. How to verify it yourself

```sh
# From the repository root
docker compose up -d

cd apps/api
bundle install
bin/rails db:prepare

bundle exec rspec      # 5 examples, 0 failures
bundle exec rubocop    # 28 files inspected, no offenses detected

bin/rails server
curl -si localhost:3000/api/v1/health
# HTTP/1.1 200 OK
# content-type: application/json; charset=utf-8
# {"status":"ok","time":"2026-09-16T03:43:54Z"}

# The clean-database path
bin/rails db:drop db:prepare
bin/rails runner 'puts ActiveRecord::Base.connection.tables.size'   # 16

# Routes: both health endpoints, doing different jobs
bin/rails routes | grep -i "health\|up"
# rails_health_check GET  /up(.:format)            rails/health#show
#      api_v1_health GET  /api/v1/health(.:format) api/v1/health#show

# Spec-first evidence: the spec commit precedes the implementation commit.
# These are the branch's first four commits, oldest last; the implementation
# report, these chapters and the QA fix round follow them.
cd ../.. && git log --oneline main..HEAD | tail -4
# 0e187fc Feature 2: add the API CI workflow and document the commands
# cdd649e Feature 2: implement the health endpoint under /api/v1
# d490ca9 Feature 2: add specs for the health endpoint
# 7d916c7 Feature 2: scaffold the Rails 8.1 API app with RSpec, RuboCop and Postgres

# Nothing dangerous is tracked
git check-ignore -v apps/api/config/master.key
git status --short          # empty
```

If `rspec` fails with a connection error, the container is not running or `POSTGRES_PORT` in the root `.env` does not match what Docker published (`docker compose ps`). If it aborts complaining about pending migrations, that is `maintain_test_schema!` doing its job: run `bin/rails db:prepare`.

## 9. What comes next

The API can answer one deliberately trivial request. It has no models, no authentication, no CORS headers and no rate limiting, so a browser on another origin cannot usefully call it yet.

- **Chapter 03 / Feature 3** builds `apps/web`: the React Router frontend, its own toolchain and its own path-filtered workflow, mirroring this one.
- **Feature 4** adds the API's security and shared behaviour: CORS, CSRF tokens, rate limiting (D-029, D-039, D-045) and a single error format.
- **Feature 5** adds authentication with Rails 8's own generator — no Devise — sessions and admins (D-016, D-017, D-039).
- **Phase 3** brings the domain model and the API contract (D-051), which is also where the serialization question that `--skip-jbuilder` deliberately left open gets answered.

Two loose ends from this chapter are recorded rather than done: adding `api.yml` as a required status check on `main` once it has run there (D-060), and running Brakeman and bundler-audit in CI once there is real code to scan.

## 10. Glossary

- **API-only app** — a Rails app with no views or browser middleware, rendering JSON (`config.api_only = true`).
- **Bundler / `Gemfile` / `Gemfile.lock`** — Ruby's dependency manager / the list of wanted gems / the exact resolved versions, committed.
- **`bundle exec`** — runs a command using exactly the locked gem versions.
- **ERB** — Ruby's templating, used inside `database.yml` so it can read `ENV`.
- **FactoryBot** — builds test records; **shoulda-matchers** — one-line matchers for common Rails behaviour.
- **GitHub Actions: workflow / job / step / runner** — a YAML file describing work / one machine's worth of it / one command in it / the virtual machine it runs on.
- **`GITHUB_TOKEN` / `permissions:`** — the short-lived credential every workflow run is given, authenticating as the workflow against its own repository / the block that narrows what it may do. Naming any scope turns the token default-deny for all the others.
- **Migration / `db/schema.rb`** — a described database change / the generated snapshot of the result.
- **Namespace (routing)** — maps a URL prefix, a Ruby module and a directory together (`/api/v1` → `Api::V1::` → `app/controllers/api/v1/`).
- **Path filter** — a CI trigger condition limiting a workflow to changes under certain paths.
- **Pessimistic constraint (`~>`)** — accepts later patches and minors, never the next major.
- **Request spec** — an RSpec test that makes a real HTTP request through the whole app.
- **RuboCop / omakase** — Ruby's linter / the zero-configuration style Rails ships with.
- **Service container** — an extra container (here Postgres) started alongside a CI job.
- **Solid Cache / Solid Queue** — Rails 8's database-backed cache store and background-job backend.
- **`config/master.key` / `credentials.yml.enc`** — the decryption key, never committed / the encrypted secrets file, committed.
