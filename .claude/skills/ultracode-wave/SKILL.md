---
name: ultracode-wave
description: Run one wave of a multi-agent "ultracode" build end-to-end — load the plan, cut the integration branch, verify the baseline, create worktrees in the correct repo, dispatch parallel agents against numbered tasks, verify their claims rather than trust them, merge one at a time, and stop at a human review gate with a written report. Use when the user invokes /ultracode-wave, says "run wave N", "dispatch the next wave", or points at an ultraplan ENTRY-POINT.md and asks you to execute it. Validated on pokta-care Wave 1 (2026-07-27): 4 agents, 437 → 602 tests, zero collisions.
---

# ultracode-wave — one wave, end to end

You are the **orchestrator**. You do not write feature code. You read the plan, prepare
isolation, dispatch agents, **verify what comes back**, merge it, and stop where a human
decision is required.

This skill encodes a process that has been run and validated. Every rule below exists
because something went wrong or nearly did. The "why" lines are not commentary — they are
the reason the rule survives.

---

## 0. Inputs

The skill needs three things. If any is missing, **stop and ask** rather than inventing it.

| Input | Typically | Purpose |
|---|---|---|
| Entry point | `.../docs/ultraplan/ENTRY-POINT.md` | Framing, mission, hard constraints, where to stop |
| Implementation plan | `.../docs/ultraplan/IMPLEMENTATION-PLAN.md` | Wave structure, agent assignments, **file-ownership collision table**, definition of done, gates |
| Wave number | `N` | Which wave to run |

> **The two files are produced by `/ultraplan-wave`.** If they do not exist, run that first —
> do not write them yourself on the way to executing them. A plan the executor authored is not
> a specification, it is a rationalisation, and the collision table and gates are exactly the
> things the thing being judged should not have written.

Read the entry point **and** the plan in full, plus every context file the entry point
lists, before dispatching anything. The entry point is framing; the plan is the
specification. Working from framing alone produces confident, wrong agents.

If the plan names a task file (`TASKS.md`, tick, issues), read it. **Every agent prompt
must cite task numbers**, and the final report maps task → what was actually built. A wave
that cannot be traced back to tickets is not reviewable.

---

## 1. Branch and baseline

```bash
cd <CODE_REPO>
git checkout <main> && git pull --ff-only
git checkout -b <integration-branch>      # e.g. study-machine; reuse if it exists
```

Then **verify the baseline is green and record the numbers**:

```bash
pnpm typecheck
pnpm test            # or the project's equivalent
```

Capture **per-package test counts and file counts**, not a total. Put them in the dispatch
prompt so every agent's "before" number can be checked against reality.

> **If the baseline is red on a fresh main, stop and report. Do not build on red.**
> You will not be able to tell an agent's breakage from pre-existing breakage later.

If the runner caches (turbo, nx), force a real run — `pnpm test -- --force` — or you will
record a cached number and compare against a live one.

---

## 2. Worktrees — in the *code* repo, by hand

**This is the single most important mechanical detail, and the harness gets it wrong.**

`Agent`/`Workflow` `isolation: "worktree"` forks **the repo the session is rooted in**. In an
internOS-style layout the session sits in the *project* repo and the code lives in a nested,
gitignored `code/<name>/` repo. An agent given harness isolation would get a worktree with
**no code in it at all**.

So create them yourself, in the right repo:

```bash
cd <CODE_REPO>
mkdir -p ../.worktrees
for b in <lane-a> <lane-b> <lane-c>; do
  git worktree add -b <prefix>/$b ../.worktrees/$b <integration-branch>
done
git worktree list      # confirm
```

Place them somewhere the *outer* repo ignores (in internOS, `code/*` is already ignored) so
they never appear in the project repo's status.

**Install dependencies in each worktree, in parallel, before dispatch.** A pnpm/npm workspace
worktree has no `node_modules`. Agents that install concurrently mid-run race each other.

```bash
for d in <dirs>; do (cd $d && pnpm install --frozen-lockfile > /tmp/i-$d.log 2>&1 && echo "$d ok") & done; wait
```

**Doc-only agents that work in a different repo** (a manuscript lane, an internOS docs lane)
get a worktree of *that* repo, in a scratch directory. They have no test suite; say so in
their prompt and in the report schema, or they will fabricate test numbers to fill the field.

---

## 3. Author the gate checklist BEFORE dispatching

Write `GATE-<N>-CHECKLIST.md` while the agents are still running — ideally before they
report.

> **Why:** a bar written after you see the results is fitted to the results. Writing it
> first is the only way "the merge is green" means anything.

It must contain, as **commands whose output decides pass/fail**, not prose:

- the recorded baseline, and the rule that **no package may go down**
- per-agent allowed paths and instant-fail paths, straight from the plan's collision table
- a secrets/PHI scan appropriate to the project (see §5)
- dependency-change check (`package.json`, lockfile)
- definition-of-done greps (`console.log`, `TODO` without a ticket)
- anything domain-critical the plan names (migration markers, schema invariants, frozen
  identifiers)
- an explicit **"what does NOT gate this wave"** list, so resolved items are not re-raised
- a failure protocol: what to revert, what to reject outright, what to escalate

Then **use it**. A checklist you wrote and skipped is worse than none.

**Check every criterion is satisfiable by THIS wave before you dispatch.** A gate item whose
deliverable belongs to a later wave, or to a file only the orchestrator may edit, cannot be
met by the agents you are about to send — it will come back as a false failure and cost a
round trip. In the validated run, gate 8.2 required an `eval:arms` script that needed a
`package.json` entry (orchestrator-only) for a task assigned to Wave 3. Read your own
checklist once as if you were the agent being judged by it.

**Put the checklist path in the agent prompts.** Agents that can read the bar they are judged
against will tell you when the bar is wrong — which is how both of the flaws above were found.

---

## 4. Dispatch

Use `Workflow` with one `parallel()` of agents when the wave is a barrier (you need all
reports before the gate) — which is the normal case for a wave.

**Omit `model` and `effort`.** Agents inherit the session's model and effort, which is what you
want: the orchestrator and the fleet stay on the same tier, and the session is where that choice
is already made. Set them only when you are highly confident a different tier fits a specific
stage — and prefer raising the session instead.

Each agent prompt contains, in this order:

1. **Its identity and worktree absolute path**, and "work only here".
2. **Its exclusive file ownership**, and the files it must *not* touch, naming the agent that
   owns them and the wave they land in.
3. **Its section of the plan, with task numbers.**
4. **The project's non-negotiable constraints, verbatim.** Do not summarise them. Do not
   paraphrase safety rules.
5. **The recorded baseline numbers.**
6. **The definition of done.**
7. **Git discipline: commit on your own branch; never merge, never push, never touch main or
   the integration branch.**

Force a **structured report** via `schema`, so prose cannot hide a missing number:

```
status        DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
tasks[]       one line per task number — what was ACTUALLY built
tests         { before, after, typecheckClean, detail }
files[]       every path touched
commits[]     subject lines
deviations    where it departed from the plan, and why
concerns      what it thinks is wrong with the PLAN itself
notDone       anything assigned and not built, and why
integrationNotes  what the next wave needs to wire it in
```

`concerns` and `deviations` are where the value is. In the validated run, every one of the
four agents returned `DONE_WITH_CONCERNS`, and their concerns caught a wrong gate criterion,
an unowned file, and a corpus measurement error. **An agent that reports a flat DONE with no
concerns has usually not looked.**

Tell agents explicitly: **if a task turns out to be already done or wrong, say so and stop
rather than building it anyway.**

---

## 5. Verify — do not trust the report

The reports are evidence, not conclusions. Run these yourself, per branch, **before any
merge**.

```bash
cd <worktree>
git diff --name-only <integration-branch>...HEAD       # ownership — THREE dots
git log --oneline <integration-branch>..HEAD           # scoped commits, why-not-what
pnpm typecheck && pnpm test -- --force                 # confirm the claimed numbers
```

> **Three dots, not two, for ownership.** `git diff A..B` compares the two *tips*;
> `git diff A...B` compares B against the **merge base**. The moment the integration branch
> gains a commit after the agents branched — an orchestrator doc fix is enough — two-dot diff
> attributes *your* files to *them*, and the ownership check falsely rejects an innocent
> agent. This was found in Wave 2 by an agent reading the gate checklist it was being judged
> against and noticing the checklist was wrong. Two-dot happens to be correct only while the
> integration branch is frozen, which is exactly when you will not notice.

**Ownership.** Cross-check every changed path against the collision table. Agents cross lanes
for legitimate reasons — a task explicitly asks for a change that lives in another agent's
file. Accept a *declared* crossing into an unowned or later-wave file; reject an undeclared
one, and reject any overlap between two agents in the same wave.

**Dependencies.** Any `package.json` / lockfile change is a stop-and-ask. Parallel worktrees
make lockfile conflicts expensive.

**Secrets / sensitive data.** If the project handles regulated data, scan the **full diff and
every commit message** on every branch — not just the final tree, because a rewritten file
still leaves the original in history. Normalise before matching (case, accents), match whole
words, and **triage token hits by hand**: common words and placeholder names ("Juan Pérez" is
the Spanish "John Doe") will hit. Report counts, never the matched values.

**Test counts.** Compare against the recorded baseline. A count that fell is a fail — find
the deleted or skipped test by name.

**Domain invariants.** Whatever the plan says must be structurally true, assert it against
the artifact, not the description of it. If a plan says "reuse this exact derivation",
**verify the derivation empirically before you hand it to an agent** — in the validated run,
hashing a filename with vs without its extension was the difference between 110/110 and 0/110
against a frozen pre-registration, and the plan's sentence was ambiguous.

---

## 6. Merge

One agent at a time. Never two at once.

```bash
git checkout <integration-branch>
git merge --no-ff <agent-branch> -m "Merge <A>: <what and which tasks>"
pnpm typecheck && pnpm test -- --force
```

Re-run the suite **after each merge**, not once at the end — otherwise you cannot attribute a
break.

**If a merge breaks the build: revert it and send the agent back. Do not repair it inside the
integration branch.** Repairing there destroys the evidence of which agent was wrong and
leaves the agent's branch still broken.

---

## 7. Report, then stop

Write `WAVE-<N>-REPORT.md` next to the plan. Structure that worked:

1. **Result** — baseline vs now, per package, with the delta.
2. **Gate conditions** — each with PASS/FAIL and *how it was checked*.
3. **The check that mattered most** — name the one that would have been silent.
4. **Decisions the human owns** — numbered, each with enough context to decide without
   re-reading the thread. This is the section they will actually act on.
5. **Deviations accepted, and why** — a table.
6. **Carried into the next wave** — integration notes, ownership transfers, corrections.
7. **Human-track items** — named once, explicitly *not* blockers.
8. **Where the work is** — branches, worktrees, what is pushed and what is not.

Then **stop at the plan's gate**. Do not cross it because the work is going well. Typical
gates: applying anything to production, spending money, launching a long job, changing a
governing decision, anything touching regulated data.

State plainly what is unverified. "Tests pass" without numbers is not a report — hold
yourself to the same bar you set for the agents.

---

## Failure protocol

| Symptom | Action |
|---|---|
| Merge breaks the build | Revert the merge, send the agent back with the failing output |
| Agent wrote outside its lane, undeclared | Reject the branch |
| Two agents touched the same file | Reject both; the collision table failed, fix it before redispatch |
| Sensitive-data hit | Stop everything. Do not merge, do not push. Escalate before any further git operation — a force-push does not remediate |
| Dependency added | Reject; ask what it was for |
| Test count fell | Fail; name the missing test |
| Agent returns `BLOCKED` / `NEEDS_CONTEXT` | Answer it and redispatch that agent alone — do not rerun the wave |

---

## Cost and scale

A four-agent wave on a mature codebase ran ~875k subagent tokens and ~30 minutes wall clock.
Scale the agent count to the wave, not to enthusiasm; the collision table is what bounds safe
parallelism, so **more agents than disjoint file sets is not faster, it is just conflicts**.

Serialise where the plan says to. In the validated run, one lane owned a file in wave N and
handed it to another lane in wave N+1 — that hand-off is a plan fact, not a scheduling
detail, and it belongs in both agents' prompts.

---

## Re-running

The skill is idempotent at the wave level. To re-run one agent, redispatch that agent alone
against a fresh worktree from the current integration branch. To resume an interrupted
`Workflow`, use `resumeFromRunId` — unchanged agent calls replay from cache.

Clean up worktrees only after the wave is merged and reported:

```bash
git worktree remove ../.worktrees/<name>     # or leave them for inspection
```
