# ultracode-epic

Three Claude Code skills for running multi-agent builds without losing the human in the loop:
you write a plan once, dispatch agents wave by wave, and freeze a gate contract up front so an
unattended run is instructed never to cross a boundary nobody agreed to — and if it ever did,
the ledger these skills write makes the violation visible, not silent.

**This is prompt-enforced, not code-enforced.** These are instructions to an AI agent, not a
sandboxed runtime. The agent creates git branches and worktrees, installs dependencies, runs
your test suite, and merges code, inside the repo you point it at. Clone this into a repo you
can afford to have modified, and commit or stash anything uncommitted before you start — the
skills assume a clean tree to diff against.

**Prerequisites:** [Claude Code](https://claude.com/claude-code) with custom skill support and
the `Agent`/`Workflow` tooling these skills use to dispatch subagents (current Claude Code
ships with both). Git. Whatever build/test tooling your target project already uses.

- **`/ultracode-epic`** (start here) — the entry point. Checks for a plan, invokes
  `/ultraplan-wave` to write one if it's missing, then runs every wave back to back in one
  session, deciding at each boundary whether to cross or stop, against a gate contract frozen
  before the first wave dispatches. **Not yet validated as its own loop** — see
  [Provenance](#provenance).
- **`/ultraplan-wave`** — writes the spec: `ENTRY-POINT.md` + `IMPLEMENTATION-PLAN.md`, including
  the file-ownership collision table that makes parallel agents safe to run at all.
- **`/ultracode-wave`** — runs one wave end to end: branch, worktrees, dispatch, verify, merge,
  stop at a human gate. **Validated:** pokta-care Wave 1, 4 agents, 437 → 602 tests, zero
  collisions.

They ship together. `/ultracode-epic` invokes `/ultraplan-wave` when there's no plan yet, and
calls `/ultracode-wave` once per wave, which refuses to run without the files `/ultraplan-wave`
produces. Installing just one of the three gives you a skill that immediately tells you to go
run a different one.

## Install

Mac and Linux. Windows: use WSL.

```bash
git clone https://github.com/troopdegen/ultracode-epic.git
cd ultracode-epic
./install.sh
```

This copies all three skills into `~/.claude/skills/`. If Claude Code is already running, start
a new session — it won't pick up newly installed skills mid-session.

**Smoke test:** in the new session, type `/ultracode-epic` and confirm it appears in the skill
list before you rely on it for anything real.

To update later: `git pull && ./install.sh` (see [CHANGELOG.md](CHANGELOG.md) for what changed).

To remove: `rm -rf ~/.claude/skills/{ultraplan-wave,ultracode-wave,ultracode-epic}`, or
`./install.sh --uninstall` from your clone.

## Try it

Run this **from inside the repo you actually want to build in** — not from inside this
skills repo, and not from your home directory. These skills write files relative to your
current working directory.

```
/ultracode-epic
```

Start there even if all you have is an idea. `/ultracode-epic` checks for a plan first; if
there isn't one, it invokes `/ultraplan-wave` for you. If you don't already have a task list or
design doc, `/ultraplan-wave` will ask you a handful of quick questions — what you're building,
your stack, whether this is greenfield or an existing codebase, roughly how big the change is,
and anything off-limits (production, secrets, regulated data). Under 5 minutes. It turns your
answers into the plan the rest of the pipeline executes against, and writes two files into your
target repo — `ENTRY-POINT.md` and `IMPLEMENTATION-PLAN.md`, by default in the directory you ran
it from (say where you'd rather have them if you want somewhere else).

Once the plan exists, `/ultracode-epic` freezes a gate contract with you and runs the waves in
order, calling `/ultracode-wave` once per wave and stopping at each gate. If you'd rather drive
one wave at a time yourself instead of the whole epic, `/ultracode-wave 1` runs just the first.

## What it costs

A single 4-agent wave ran **~875k subagent tokens and ~30 minutes wall clock** on the one
mature codebase this has been measured on so far — treat that as one data point, not a
guarantee. Translate the token figure into a dollar estimate yourself using
[Anthropic's current pricing](https://www.anthropic.com/pricing) for whatever model your
Claude Code session is using; how that usage is billed (pay-as-you-go vs. a subscription
plan with Code included) depends on your own plan, and this project makes no claim about it.

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

`/ultracode-wave` has run successfully once, on a personal project (pokta-care), on
2026-07-27: 4 agents, 437 → 602 tests, zero collisions. That's a real result, but it's a
single anecdotal run with no public report or artifact attached — one data point, not a
benchmark. `/ultracode-epic` (the epic-level loop across multiple waves) is derived from that
run's failure protocol plus one pre-flight check on a second project — it has not yet
completed a full multi-wave epic end to end. Treat it as the newest, least-proven piece of
the three, and expect rough edges on codebases and stacks it hasn't touched yet (built and
run so far on a Node/pnpm project — other stacks are untested, not unsupported).

## Coming soon

A recorded run (asciinema or video) showing a real epic end to end — gate contract freezing,
agents dispatching, a `HELD` gate actually stopping. Tracked, not yet done.

## License

MIT — see [LICENSE](LICENSE).
