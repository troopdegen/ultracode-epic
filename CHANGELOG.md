# Changelog

All notable changes to these three skills are recorded here. Versioning applies to the trio as a
set, since they ship and update together.

## [1.0.0] - 2026-07-28

Initial public release.

- `ultraplan-wave` — writes `ENTRY-POINT.md` + `IMPLEMENTATION-PLAN.md` for a multi-agent build.
  Adds a light intake step (§0.5) for when there's no existing task list: five questions, under
  5 minutes, to produce the task list the rest of the skill surveys code against.
- `ultracode-wave` — runs one wave end to end. Validated on pokta-care Wave 1 (2026-07-27):
  4 agents, 437 → 602 tests, zero collisions.
- `ultracode-epic` — runs every wave in a plan back to back, deciding each boundary against a
  gate contract frozen before wave 1. Not yet validated as its own multi-wave loop.
