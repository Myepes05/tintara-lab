# Tintara Lab

Tintara Lab is a portfolio web app for a photographer (Luisa Sanabria, Medellín, Colombia). The public site is one long server-rendered page in Spanish: Landing → Field Experience → Portfolio → Services → About Me → Contact. It has no visitor login. An admin area under `/admin` lets admins edit all content. The monorepo holds a Rails 8.1 API (`apps/api`) and a React Router framework-mode app in TypeScript (`apps/web`). Data lives in PostgreSQL (Docker in development) and images in Cloudinary (direct signed uploads).

## Repository structure

```
apps/
  api/                 Rails 8.1 API (coming in Feature 2)
  web/                 React Router app in TypeScript (coming in Feature 3)
docker-compose.yml     Local Postgres for development
handoff/               Project memory: decisions, plan, status, prompts, agent reports
CLAUDE.md              Instructions for every agent working in this repository
```

## Prerequisites

Versions verified on the development machine:

| Tool | Version |
|---|---|
| Ruby (via rbenv) | 3.4.3 |
| Node | 24 (24.14.0) |
| Corepack | 0.34.6 |
| Docker | 29.2.1 |
| gh (GitHub CLI) | 2.100.0 |

## Getting started

1. Create your local environment file and adjust the values if needed (for example, `POSTGRES_PORT` if 5432 is taken):
   ```sh
   cp .env.example .env
   ```
2. Start Postgres:
   ```sh
   docker compose up -d
   ```
3. Check that the database is healthy:
   ```sh
   docker compose ps
   docker compose exec db pg_isready
   ```
4. Stop it when you're done (data is kept in the `db_data` volume):
   ```sh
   docker compose down
   ```

## How work is organized

Read `CLAUDE.md` for the full protocol; `handoff/` is the project's source of truth.

- Every decision is recorded in `handoff/decisions/decision-log.md` with an ID (D-XXX).
- Each task has a prompt in `handoff/prompts/` and a report in `handoff/agent-outputs/`.
- One task = one branch = one PR, titled `Feature N: ...` or `fix N: ...`; the owner squash-merges.
- Specs are committed before the implementation they cover.
- All code and documentation are in English; site content is in Spanish.
