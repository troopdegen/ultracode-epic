# ultracode-epic

Three Claude Code skills for running multi-agent builds without losing the human in the loop:
you write a plan once, dispatch agents wave by wave, and freeze a gate contract up front so an
unattended run can never cross a boundary nobody agreed to.

- **`/ultraplan-wave`** — writes the spec: `ENTRY-POINT.md` + `IMPLEMENTATION-PLAN.md`, including
  the file-ownership collision table that makes parallel agents safe to run at all.
- **`/ultracode-wave`** — runs one wave end to end: branch, worktrees, dispatch, verify, merge,
  stop at a human gate. **Validated:** pokta-care Wave 1, 4 agents, 437 → 602 tests, zero
  collisions.
- **`/ultracode-epic`** — runs every wave in a plan back to back in one session, deciding at each
  boundary whether to cross or stop, against a gate contract frozen before the first wave
  dispatches. **Not yet validated as its own loop** — see [Provenance](#provenance).

They ship together. `/ultracode-epic` calls `/ultracode-wave`, which refuses to run without the
files `/ultraplan-wave` produces. Installing just one of the three gives you a skill that
immediately tells you to go run a different one.

## Install

Mac and Linux. Windows: use WSL.

```bash
git clone https://github.com/troopdegen/ultracode-epic.git
cd ultracode-epic
./install.sh
```

This copies all three skills into `~/.claude/skills/`. If Claude Code is already running, start
a new session — it won't pick up newly installed skills mid-session.

To update later: `git pull && ./install.sh` (see [CHANGELOG.md](CHANGELOG.md) for what changed).

## Try it

```
/ultraplan-wave
```

If you don't already have a task list or design doc, `/ultraplan-wave` will ask you a handful of
quick questions first — what you're building, your stack, whether this is greenfield or an
existing codebase, roughly how big the change is, and anything off-limits (production, secrets,
regulated data). Under 5 minutes. It turns your answers into the plan the rest of the pipeline
executes against.

Once the plan exists, `/ultracode-wave 1` runs the first wave. `/ultracode-epic` runs all of them
in sequence if the plan has more than one.

## What it costs

A single 4-agent wave runs roughly **~875k subagent tokens and ~30 minutes wall clock** on a
mature codebase (the validated reference run). On pay-as-you-go API pricing that's on the order
of low-to-mid single-digit dollars per wave; if you're on a Claude subscription plan with Code
included, it draws from that instead. Exact cost depends on model, plan, and how much of the
codebase gets read — treat the token figure as the source of truth and the dollar range as a
rough translation, not a quote.

`/ultracode-epic` will state the wave × agent count and where it stops even if everything passes,
and ask for an explicit go-ahead before dispatching wave 1.

## What a stop looks like

Every wave and every epic gate can stop instead of proceeding — that's deliberate, not a failure
mode. Here's a realistic excerpt from an `EPIC-LEDGER.md` after a gate held:

```markdown
## Run record

### Gate 1 → 2 — HELD (2026-07-28)
Contract row: `1 → 2 | HUMAN | — | —`
Reason: contract row is HUMAN by design — a human reviews wave 1's diff before wave 2 dispatches.
Evidence: n/a (HUMAN gates have no evidence command; that's what makes them HUMAN)
Circuit breakers checked: sensitive-data scan (clean), lockfile diff (clean), test count (602,
  up from 437 baseline — no regressions)
Integration state: branch `study-machine`, 4 commits merged, nothing pushed to main

STOPPED. Waiting on human review of wave 1 before wave 2 can be authorized.
```

Nothing "went wrong" here — a `HUMAN` gate held because that's what the frozen contract said it
would do. `AUTO` gates hold the same way when their evidence command fails to run or returns
something other than the recorded pass condition.

## Provenance

`/ultracode-wave` is validated: pokta-care Wave 1, 2026-07-27, 4 agents, 437 → 602 tests, zero
collisions. `/ultracode-epic` (the epic-level loop across multiple waves) is derived from that
run's failure protocol plus one pre-flight check on a second project — it has not yet completed
a full multi-wave epic end to end. Treat it as the newest, least-proven piece of the three.

## Coming soon

A recorded run (asciinema or video) showing a real epic end to end — gate contract freezing,
agents dispatching, a `HELD` gate actually stopping. Tracked, not yet done.

## License

MIT — see [LICENSE](LICENSE).
