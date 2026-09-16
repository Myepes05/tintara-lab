# Learning — How this app was built, step by step

A chapter per implementation task, written by the agent that did the work, so the owner can rebuild an app like this without the agents.

**Audience:** a developer who knows how to program but has not built this particular stack (Rails API + React Router SSR + Postgres + Cloudinary + CI) end to end.

**These chapters are teaching material, not status reports.** Reports in `agent-outputs/` prove that the work was done. Chapters explain how to do it and why it was done that way.

| Chapter | Task | File |
|---|---|---|
| 01 | Feature 1 — Monorepo bootstrap: git, Docker Postgres, GitHub repo | `01-monorepo-bootstrap.md` |
| 02 | Feature 2 — Rails API skeleton: RSpec, RuboCop, CI | `02-rails-api-skeleton.md` |

Chapters are added as tasks land. The table above is updated by the orchestrator.

## Rules for chapters
- Written in English (D-041), in plain language, explaining terms the first time they appear.
- Real commands and real file contents from this repository, never invented examples.
- Every decision explained: what was chosen, what was rejected, and why. Link the decision IDs.
- Include the mistakes, dead ends and traps found along the way. That is the part no tutorial online has.
- A reader must be able to follow the chapter and reach the same result.
