# Changelog

All notable changes to these three skills are recorded here. Versioning applies to the trio as a
set, since they ship and update together.

## [1.0.1] - 2026-07-28

Fixes the entry point. `1.0.0`'s README and `ultracode-epic/SKILL.md` both told a user with only
an idea to run `/ultraplan-wave` first and treated `/ultracode-epic` as just the multi-wave
runner at the end. That buried the skill people were actually asking to try, and it meant
`/ultracode-epic` stopped and told a human to go type a different command by hand instead of
getting the plan written itself.

- `ultracode-epic` — now the documented entry point. §1 invokes `/ultraplan-wave` itself when
  `ENTRY-POINT.md` or `IMPLEMENTATION-PLAN.md` is missing, instead of stopping and telling the
  human to run it manually. It still refuses to author the plan's content itself, same as
  before; invoking the planner isn't the same as writing the plan.
- `README.md` — "Try it" now opens with `/ultracode-epic` instead of `/ultraplan-wave`, and the
  skill list leads with `/ultracode-epic (start here)`.

## [1.0.0] - 2026-07-28

Initial public release.

- `ultraplan-wave` — writes `ENTRY-POINT.md` + `IMPLEMENTATION-PLAN.md` for a multi-agent build.
  Adds a light intake step (§0.5) for when there's no existing task list: five questions, under
  5 minutes, to produce the task list the rest of the skill surveys code against.
- `ultracode-wave` — runs one wave end to end. Validated on pokta-care Wave 1 (2026-07-27):
  4 agents, 437 → 602 tests, zero collisions. Fixed on this release: `git checkout -b` on an
  existing integration branch no longer fails outright (§1); an unquoted path variable in the
  worktree-install log example is now quoted; typecheck/test commands are noted as
  project-equivalent, not pnpm-specific.
- `ultracode-epic` — runs every wave in a plan back to back, deciding each boundary against a
  gate contract frozen before wave 1. Not yet validated as its own multi-wave loop.
- `install.sh` — validates all source files exist before touching `~/.claude/skills/`, backs up
  an existing install instead of deleting it before copying, and adds `--yes` and `--uninstall`.
