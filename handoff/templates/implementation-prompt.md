# Feature N: <one-line summary>

**Type:** Implementation · **Phase:** X · **Branch:** `feature/N-<slug>` · **PR title:** `Feature N: <summary>`
**Report file:** `handoff/agent-outputs/implementation/feature-NNN-<slug>.md` (use `handoff/templates/implementation-output.md`)
**Learning chapter:** `handoff/learning/NN-<slug>.md` (use `handoff/templates/learning-chapter.md`, see CLAUDE.md §7b)

## Before you start
Read `CLAUDE.md`, `handoff/status/current-status.md`, and these decisions: D-XXX, D-YYY.
Depends on: <previous tasks and their reports>.

## Goal
<What this task delivers and why.>

## Scope
### In scope
- ...
### Out of scope (do NOT do)
- ...

## Requirements
<Numbered, precise requirements with the decision ID each one comes from.>

## Specs to write first
<The behaviors that must be covered by specs before implementing.>

## Acceptance criteria
- [ ] ...
- [ ] Lint and tests pass locally (outputs included in the report)
- [ ] Spec commit(s) come before implementation commit(s)
- [ ] Learning chapter written, reproducible, and its row added to `handoff/learning/README.md`
- [ ] PR opened with the exact title; not merged

## Verification commands
```
<commands the agent must run and report>
```

## Questions
If anything is unclear or missing, don't assume. List it under "Questions for the owner" in your report, and stop if it blocks you.
