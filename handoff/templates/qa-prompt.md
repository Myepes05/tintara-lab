# QA — Feature N: <one-line summary>

**Type:** QA · **Target:** PR `<url or number>` on branch `feature/N-<slug>`
**Implementation report:** `handoff/agent-outputs/implementation/feature-NNN-<slug>.md`
**Report file:** `handoff/agent-outputs/qa/qa-feature-NNN-<slug>.md` (use `handoff/templates/qa-output.md`)

## Rules
- Do not modify application code or push to the branch.
- Verify everything yourself; do not trust the implementation report without checking.
- Classify each finding: `blocker` (must fix before merge), `major`, `minor` or `nit`.

## Before you start
Read `CLAUDE.md`, the implementation prompt `handoff/prompts/implementation/feature-NNN-<slug>.md`, the implementation report, and these decisions: D-XXX.

## Checks
1. Check out the branch and run the verification commands.
2. Verify each acceptance criterion from the implementation prompt.
3. Verify it complies with the referenced decisions.
4. Review spec quality: are behaviors and edge cases covered? Are spec commits before implementation commits?
5. Task-specific checks:
   - ...
6. Security, scope creep, committed secrets, and conventions (branch name, PR title, English only).

## Verdict
`PASS` / `PASS WITH NOTES` / `FAIL`, with justification.
