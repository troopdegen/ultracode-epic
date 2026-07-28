---
name: ultracode-epic
description: Run every wave of an ultracode epic back to back in one session — freeze a gate contract before anything runs, drive /ultracode-wave once per wave, decide at each boundary whether to cross or stop, and keep a ledger that survives compaction. Use when the user says "run the whole epic", "run all the waves", "run waves 0 through N", or invokes /ultracode-epic against an ultraplan directory. Drives /ultracode-wave; does not replace it.
---

# ultracode-epic — every wave, one session, gates honoured

You are the **epic driver**. You do not write feature code, you do not dispatch agents, and you
do not verify branches — `/ultracode-wave` does all three. You own exactly one thing: **what
happens between waves.**

That is a narrow job with a wide blast radius. A wave that stops is safe by construction. A wave
that continues because nobody was watching is where an unattended run does something a human
would not have authorised — and the damage is discovered three waves later, in a merged branch,
with the evidence of who decided it living only in a context window that has since been
summarised.

So the whole skill is one idea: **the decision to cross a gate is made before the results exist,
in writing, on disk.**

> **Provenance.** `/ultracode-wave` is validated — pokta-care Wave 1, 2026-07-27, 4 agents,
> 437 → 602 tests. **This epic-level loop is not.** Its rules are derived from that run's failure
> protocol plus the first epic pre-flight (pokta-care Epic 2, 2026-07-28), which found an
> uncrossable gate before any tokens were spent. Where a rule has no scar behind it yet, it says
> so. Do not present this skill's output as validated process.

---

## 0. What this is, and what it is not

| Skill | Owns |
|---|---|
| `/ultraplan-wave` | Writes `ENTRY-POINT.md` + `IMPLEMENTATION-PLAN.md` |
| `/ultracode-wave` | Runs **one** wave: branch, baseline, worktrees, dispatch, verify, merge, report, stop |
| **`/ultracode-epic`** | **Runs the waves in order and decides each boundary** |

**Invoke `/ultracode-wave` for each wave. Do not reimplement its process here.** It is the source
of truth for dispatch, verification and merge, and a second copy of that process will drift from
it silently. If you find yourself writing a worktree command, you are in the wrong skill.

`/ultracode-wave` **will stop at its plan's gate** — that is its §7 and it is correct. This skill
is what reads the frozen contract and decides whether that stop is honoured or was pre-cleared.
It never overrides a stop it did not pre-authorise in writing.

**This skill does not make an epic safe to run unattended. It makes the unattended part
auditable and the attended part explicit.** Those are different claims, and only the second one
is true by construction.

---

## 1. Inputs

| Input | Typically | If missing |
|---|---|---|
| Entry point | `<plan-dir>/ENTRY-POINT.md` | **Stop.** Run `/ultraplan-wave`. |
| Implementation plan | `<plan-dir>/IMPLEMENTATION-PLAN.md` | **Stop.** Same. |
| Wave list | The plan's wave structure | **Stop and ask.** Never infer it from agent count. |
| Gate contract | You write it, §2 | Written with the user before wave 1 |

Read the entry point and the plan **in full**, plus every context file the entry point lists,
before writing the contract. You are about to pre-authorise decisions in a domain you have only
skimmed otherwise.

**Refuse to author the plan on the way to executing it**, for the same reason `/ultracode-wave`
refuses: a plan the executor wrote for itself is a rationalisation, and the gates are precisely
the part the thing being judged should not write. This applies doubly here — you are not only
executing the gates, you are deciding which of them a human sees.

---

## 2. The gate contract — write it before anything runs, then freeze it

This is the artifact. Everything else in this skill serves it.

For **every** wave boundary in the plan, produce one row, **with the user, before the epic's
first wave dispatches**:

| Gate | Decision | Mechanical condition | Evidence command |
|---|---|---|---|
| 0 → 1 | `AUTO` | spike returns `status: DONE` and `redesignRequired: false` | the structured report field |
| 1 → 2 | `HUMAN` | — | — |
| 2 → done | `HUMAN` | terminal; human deploys | — |

**Three rules, and the first is the whole point:**

1. **The condition must be mechanical** — a command's exit status, a number compared to a
   recorded baseline, or a named field in an agent's structured report. **Never a reading of
   prose.** "AUTO if the spike looks clean" makes you the judge of whether your own next wave
   should run, which is the exact conflict `/ultraplan-wave` exists to prevent. **If you cannot
   state the condition as something a command decides, the gate is `HUMAN`.** That is not a
   failure to automate; it is the correct classification.

2. **The user sets each row, not you.** You propose, they decide. Propose `HUMAN` when unsure —
   an over-cautious contract costs one message, an over-permissive one costs a wave.

3. **Freeze it, and the freeze is a ratchet that only tightens.** A gate rewritten after you
   have seen the results is fitted to the results — the same reason `/ultracode-wave` §3 writes
   its checklist before the agents report, one level up and with more at stake, because here
   nobody is watching when you edit it.

   **Each row freezes before the wave it JUDGES dispatches**, not before the epic. Gate 0 → 1
   judges wave 0, so it freezes before wave 0 runs; gate 1 → 2 judges wave 1, so an earlier
   wave's findings may legitimately inform it without fitting it to anything it grades.

   To keep that from becoming a loophole, two things freeze at **epic start, for every row**:
   **the `AUTO`/`HUMAN` decision, and the evidence command.** Afterwards a row may change in
   exactly two ways:

   - **downgrade `AUTO` → `HUMAN`** — always allowed, at any point, by anyone
   - **fill a blank that an earlier wave was explicitly commissioned to supply** — and the blank
     must be written into the contract as a blank *at freeze time*, saying which wave fills it
     and that it may only narrow the requirement

   Anything else — widening a condition, swapping an evidence command, promoting `HUMAN` to
   `AUTO` — **is not an edit, it is a new contract, and it needs the user.** If a gate's
   condition turns out to be a bad proxy mid-run, **stop and say so. Do not rewrite the bar.**

Write the contract into `<plan-dir>/EPIC-LEDGER.md` under a heading that says it is frozen and
the date it froze. That file is also the run record (§6).

### When the plan's gates are prose

They usually are. `/ultraplan-wave` §7 asks for "checks, not intentions", but a plan written
before this skill existed states gates as paragraphs.

**Convert them with the user, one at a time. Do not interpret a paragraph into an `AUTO`
condition on your own** — that is authoring the gate you are judged by, wearing a translation
costume.

> **Upstream fix worth making once:** have `/ultraplan-wave` emit each gate as
> `AUTO if <condition>` or `HUMAN`, so this conversion stops being necessary. Until then it is
> the most expensive part of the setup, and it is the part where the value is.

---

## 3. Circuit breakers — unconditional, and they end the epic

These override every `AUTO` in the contract. They are not gate failures that fail a wave; they
**end the run** and hand back to the human.

| Breaker | Why it ends the epic, not just the wave |
|---|---|
| **Sensitive-data or secret hit** in any diff or commit message | A force-push does not remediate. Every further git operation makes it worse. |
| **Dependency or lockfile change** by any agent | Parallel worktrees make lockfile conflicts expensive, and nobody asked for the dependency. |
| **Agent returns `BLOCKED` or `NEEDS_CONTEXT`** | The answer is information the driver does not have. Guessing it is how a wave builds against a wrong premise. |
| **Test count fell** in any package | Find the deleted or skipped test by name. This is never a rounding difference. |
| **A merge broke the build** | `/ultracode-wave` reverts and redispatches that agent. If the redispatch also breaks, the plan is wrong, not the agent. |
| **Undeclared lane crossing, or two agents on one file** | The collision table failed. It must be fixed by a human before more agents run against it. |
| **Provider spend, deployment, production access, or regulated data** beyond what the entry point pre-authorises | The entry point's "where you stop and ask" list is a circuit breaker, not advice. |

Restate the project's own list from the entry point into the ledger verbatim. **Do not summarise
safety rules into a table row** — copy them.

The failure protocol in `/ultracode-wave` still applies inside a wave. This table is what happens
when that protocol fires and there is no human in the room.

---

## 4. Pre-flight — prove every `AUTO` gate is crossable *today*

**Run this before dispatching wave 1. It is the cheapest hour in the epic.**

For each `AUTO` row, ask two questions and answer them by running something:

1. **Does the thing this gate checks exist yet, in a form this session can reach?**
2. **Can this session run the evidence command without crossing a circuit breaker?**

> **The scar, and it is why this section exists.** An epic's primary gate read: *"`curl` the
> service with a synthetic note and get a structured record back — this is the gate, not 'the
> tests pass'."* Excellent gate. Uncrossable: the repo had `.env.example` and no `.env`, no
> `node_modules`, and the deployed service ran pre-wave code that the same plan forbade
> redeploying. **There was nothing to curl.** Marked `AUTO`, that gate would have run two waves
> and ~1M tokens to discover a stop that four read-only commands found in five minutes.

A gate that cannot be crossed is not a bug in the plan — it is usually a **human handoff the plan
correctly demands**. Say which one, and what would close it (*"a local `.env` with the Supabase
URL and one provider key turns this from a mid-epic stop into a terminal one"*), then let the
user choose. Do not close it yourself: the things that unblock gates are secrets, deployments and
spend, which are the four items on every stop-and-ask list ever written.

Downgrade any gate that fails pre-flight to `HUMAN` in the contract. Under §2's ratchet a
downgrade is always permitted — but doing it *here*, before the row freezes, is what keeps the
contract honest rather than merely legal.

**Pre-flight for a later gate can be commissioned from an earlier wave.** If a gate's
crossability depends on a fact only wave N can establish, write it into the contract as a
**named blank** — which wave fills it, and that it may only narrow the requirement. That is the
one thing §2 lets you leave open, and it is open because you declared it, not because you
deferred it.

---

## 5. The loop

```
freeze contract  →  pre-flight  →  ack cost (§8)
   │
   ├─ for each wave N in plan order:
   │     invoke /ultracode-wave N          ← it dispatches, verifies, merges, reports, stops
   │     re-run gate N's evidence yourself ← §6
   │     check circuit breakers            ← §3
   │     append to EPIC-LEDGER.md          ← §7
   │     contract says AUTO and clean? → next wave
   │     otherwise                        → STOP, write the epic report, hand back
   │
   └─ all waves crossed → epic report, hand back at the terminal gate
```

**Sequential only. Never overlap two waves.** The wave boundaries exist because a later wave
asserts against an artifact an earlier one creates — that is `/ultraplan-wave` §3, and a plan
that got it wrong had to pull an agent out mid-wave. An epic driver that starts wave N+1 "since
the agents have spare capacity" reintroduces exactly that bug at a level where nobody is
watching for it.

**Each wave's dispatch is a `Workflow`; each gate is decided in the session.** This split is not
stylistic. A `Workflow` script cannot pause to ask a human — a script that reaches a judgment
gate either invents an answer or dies. So the parallel, deterministic part (dispatch) goes in the
script, and the part that might need a person stays where a person can be reached.

**Re-read the ledger at the top of every wave.** Not your recollection of it. See §7.

---

## 6. Crossing a gate

**Re-run the gate's evidence command yourself. The wave report is evidence, not a verdict.**

`/ultracode-wave` §5 already refuses to trust an agent's claims and re-runs them. A driver that
crosses a gate on the strength of the wave report reintroduces that same trust problem one level
up — and this time there is no human reading the report before the next dispatch.

Record, in the ledger, for every gate:

- the decision (`CROSSED` / `HELD`)
- the contract row it was decided by, quoted
- **the command that was run and its actual output**, not "verified"
- every circuit breaker checked, and that it was checked
- integration state: branch, merge commits, what is pushed and what is not

A `CROSSED` row with no command output in it is indistinguishable from a guess, and in three
waves' time you will not be able to tell them apart either.

**When a gate is `HELD`: stop.** Write the epic report and hand back. Do not ask "shall I
continue?" and then continue on a general-sounding answer — a held gate is held until the human
addresses the specific thing that held it.

---

## 7. State that survives compaction

**An epic will be summarised mid-run. Plan for it.**

Multiple waves in one session is exactly the shape of conversation that gets compacted, and the
gate contract is the single thing that must not be lost. If it lives only in context, a
compaction quietly turns a `HUMAN` gate into a `HELD` you no longer remember agreeing to — or
worse, into a crossing.

So: **`<plan-dir>/EPIC-LEDGER.md`, written after every wave and after every gate decision.**

```markdown
# EPIC <name> — ledger

## Contract — FROZEN <date>          ← §2 table. Never edited after wave 1.
## Circuit breakers                  ← §3, project's own list verbatim
## Pre-flight — <date>               ← §4 results, per AUTO gate
## Baseline                          ← per-package test + file counts, from wave 1's §1
## Run record                        ← append-only, one block per wave and per gate
```

Two rules:

1. **Append, never rewrite.** A ledger you edit to match the current state is not a ledger,
   for the same reason an audit log you edit to match current state is not an audit log.
2. **Re-read it at the top of every wave**, and treat it as more authoritative than your own
   summary of the run. If the ledger and your recollection disagree, **the ledger is right and
   you have been compacted.**

---

## 8. Cost, and the acknowledgement you need before starting

State the numbers **before** dispatching wave 1, and get an explicit go:

- **waves × agents**, from the plan
- **estimated tokens** — the validated reference is ~875k subagent tokens and ~30 minutes wall
  clock for a four-agent wave on a mature codebase. Scale from that.
- **which gates are `AUTO`**, in one line each
- **where it will stop even if everything passes** — usually the terminal gate

> An epic is the first workflow in this family that can spend seven figures of tokens without a
> human turn in between. Saying so is not ceremony; it is the last cheap moment to change scope.

**The binding constraint is the driver's context, not tokens.** Three waves of reports, diffs,
verification output and merge logs is a lot of orchestrator context, and every compaction is a
chance to lose the contract. If the plan has more than ~4 waves, say plainly that the run will
be compacted at least once and that §7 is what stands between that and a silent gate crossing.

---

## 9. The epic report

Per-wave reports are `/ultracode-wave`'s job (`WAVE-<N>-REPORT.md`) and this skill does not
duplicate them. Write `<plan-dir>/EPIC-REPORT.md` at the stop, whether that stop is the end or a
held gate:

1. **Where it got to** — waves run, waves not run, and why it stopped.
2. **Every gate decision** — crossed or held, the contract row, the evidence. In order.
3. **The autonomy audit** — for each `AUTO` crossing: *what a human would have seen at that
   moment.* This is the section that makes an unattended run reviewable, and it is the reason a
   human can trust the next one. An unattended run nobody can audit is worse than an attended
   run, because it looks the same as a careful one.
4. **Circuit breakers that fired**, or plainly: none fired, and here is what was checked.
5. **Decisions the human owns now** — numbered, each decidable without re-reading the thread.
6. **Where the work is** — branches, worktrees, merge commits, pushed vs not.
7. **What the contract got wrong** — any gate whose condition proved to be a bad proxy. This is
   the input to the next epic's contract and the only way this skill improves.

State plainly what is unverified. Hold yourself to the bar you set for the agents.

---

## Failure protocol — epic level

Wave-level failures are handled by `/ultracode-wave`. These are the ones that reach the driver.

| Symptom | Action |
|---|---|
| Circuit breaker fires | **End the epic.** Report, hand back. Do not run the next wave. |
| `AUTO` gate's evidence command fails to run | Treat as `HELD`, not as a pass. An unrunnable check is not a passing check. |
| Gate condition turns out to be a bad proxy | **Stop.** Report it. Never edit the frozen contract to fix it mid-run. |
| A wave returns `DONE_WITH_CONCERNS` | Read the concerns before crossing. They are the highest-value field in the report — in the validated run all four agents filed them and they caught a wrong gate criterion, an unowned file, and a measurement error. |
| Plan turns out to be wrong mid-epic | Stop at the current gate. Re-planning is `/ultraplan-wave`'s job and it is a human decision. |
| Compaction, and the ledger disagrees with you | The ledger wins. Re-read it in full before doing anything else. |

---

## Resuming

The epic is idempotent at the wave boundary, because `/ultracode-wave` is idempotent at the wave
level.

To resume: read `EPIC-LEDGER.md` first — **the contract is still frozen and still binding**, and
a resumed run that renegotiates it has defeated the point. Start at the first wave with no
`CROSSED` record. To re-run a single agent inside a wave, that is `/ultracode-wave`'s
re-dispatch, not an epic restart.

Clean up worktrees only after the epic ends, not per wave — a held gate is often diagnosed from
the previous wave's worktree.
