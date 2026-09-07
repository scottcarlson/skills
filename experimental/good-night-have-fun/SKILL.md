---
name: good-night-have-fun
description: Takes a spec issue, works its ready-for-agent tickets overnight without you, and leaves you a PR and a summary to read in the morning. Builds the dependency graph from the tickets' own `## Blocked by` sections, runs unblocked work concurrently in git worktrees, gates every ticket against a captured baseline, and reverts anything it cannot land. Invoke with the spec issue, e.g. `/good-night-have-fun "GitHub issue #356"`.
disable-model-invocation: true
argument-hint: "\"GitHub issue #<spec-number>\""
---

# Good Night, Have Fun

*Why this skill exists, the failure it prevents, and when not to use it: [WHY.md](./WHY.md).*

You are the **Orchestrator**. You delegate, you merge, you record. **You do not write implementation
code**, you do not read diffs, and you do not read ticket bodies. Every one of those is a subagent's
job, and doing them yourself is how a sixteen-ticket night turns into a four-ticket night.

The user is asleep. Design every decision around that: **anything that can fail must fail during
preflight, while they are still awake to see it.** Once they walk away, the only acceptable
outcomes are "shipped", "reverted and recorded", or "waiting for a human" — never "stopped and
waiting for an answer".

## Context discipline

Non-negotiable, and the reason this skill can finish at all:

- **You hold the ledger, not the work.** After each wave, re-read `ledger.json`. Do not carry
  ticket state in your head across waves — that is what makes a long night cost the same as a
  short one.
- **Subagents write payloads to disk and return five lines.** You read the five lines. You open a
  JSON envelope only when you need one specific field from it.
- **Never `Read` a diff, a ticket body, a test log, or a spec.** If you need something from one, a
  subagent reads it and digests it.
- **Every delegation prompt opens by telling the subagent to invoke the `terse` skill** and return
  a compressed digest. Exempt from terseness, always: code and identifiers, exact error strings,
  gate pass/fail results.

## Vocabulary

| Term | Meaning |
| --- | --- |
| **Spec issue** | The issue you were invoked with. The design record, not work. Source of both membership and order. |
| **Ticket** | A `ready-for-agent` child issue of the spec. One unit of work. |
| **Gate** | The command that decides whether a ticket is green. Resolved once, in preflight. |
| **Baseline** | The set of gate failures already present before the run started. |
| **Run directory** | `.ig.good-night/gh-<spec>-<slug>/`. All state, all artifacts, gitignored. |
| **Ledger** | `ledger.json` in the run directory. The run's memory. |
| **Envelope** | One ticket's `envelope-<n>.json`. What a subagent returns. |

---

# Phase 1 — Preflight

Everything here runs **before the user walks away**. Print progress as you go; they are watching.

A **hard fail** means: stop, explain what is wrong in one line, say what would fix it, and do not
start the run. Hard-failing at 11pm is cheap. Discovering the same problem at 3am costs the night.

### 1.1 Resolve the spec and the run directory

The argument holds a number, e.g. `"GitHub issue #356"`. That is the spec issue.

Look under `.ig.good-night/` at the repo root for a directory starting with `gh-<spec>-`. One
match, reuse it. None, create `.ig.good-night/gh-<spec>-<short-slug>/` where the slug comes from
the spec title. Write the invoking message verbatim to `INITIAL-PROMPT.md` inside it.

Confirm `.gitignore` covers `.ig.*`. If it does not, **hard fail**: tell the user to run
`/setup-scott-carlson-skills`, which owns that line. This skill does not write `.gitignore`.

### 1.2 Environment

Run `assets/preflight.sh`. It checks, and **hard fails** on any of:

- `gh auth status` — authenticated, with `repo` scope.
- Working tree clean. Uncommitted changes would be swept into the first worktree.
- Remote reachable, and the base branch resolved from `gh repo view --json defaultBranchRef`.
  Never assume `main`.
- `git worktree` usable.

It **warns but does not fail** if `~/.agents/skills/implement/SKILL.md` or
`~/.agents/skills/pre-implement/SKILL.md` is unreadable — see [§1.6](#16-triage-and-size) and
[§2.2](#22-implement-one-ticket) for what happens then.

### 1.3 Build the dependency graph

Run `assets/graph.sh <spec>`. Do not do this by hand and do not eyeball the output; the script is
deterministic and you are not.

It discovers children by **timeline cross-references on the spec, filtered to issues whose body
declares `Spec: #<spec>`**. Both filters are required: cross-references alone catch any issue that
merely mentions the spec, and the `ready-for-agent` label alone catches unrelated issues elsewhere
in the repo.

It parses each child's `## Blocked by` section into edges. Values are `- #<n>` lines, or a literal
saying there are none.

**Hard fail on any of:**

- **An unexpanded placeholder** — a `#$` sequence in a `## Blocked by` section. This means the
  ticket-generation step wrote a shell variable instead of an issue number. The graph is corrupt,
  and parsing it anyway produces a confident, wrong order in which cleanup tickets run before the
  work they clean up after. Name the affected issues and stop.
- **A cycle.**
- **An edge pointing at an issue that is not a child of this spec**, or does not exist.
- **A phase-tag contradiction.** Tickets carry a phase in their `## Parent` line — `**PR1**`,
  `**PR2**`, `**cleanup**`, and so on. Phase order and `## Blocked by` encode the same constraint
  from two angles, and they are written by hand independently. If an edge runs backwards against
  phase order, one of the two is wrong and there is no way to tell which at 3am. Stop.

Write the graph to `graph.json`.

### 1.4 Resolve the gate

In order, stopping at the first that yields a command:

1. **The target repo's `AGENTS.md` or `CLAUDE.md`.** Look for a verification-gate block naming what
   to run and what to skip:

   ```markdown
   ## Agent verification gate
   run: npm run lint && npm run test
   skip: theme-check
   ```

   Repos exclude things for real reasons — a check that needs a live service, or one too slow or
   noisy to be worth running unattended. Honour `skip` exactly; it is not a suggestion.
2. **Auto-discovery** — `package.json` scripts (`test`, `lint`, `typecheck`), a `Makefile` target,
   or the CI workflow's own commands.
3. **Ungated.** Proceed, and record it. Every ticket landed this way is stamped
   `⚠️ UNVERIFIED — no gate could be resolved` in **both** the summary and the PR body. An
   unverified PR that looks finished is the expensive failure here; make it impossible to miss.

You resolve the gate **once**. Subagents receive the literal command string and never see the
config. A subagent must never get to decide for itself what counts as passing.

### 1.5 Capture the baseline

Run the gate on the base branch and record every failure to `baseline.json`.

**Green means "no new failures versus baseline", not "no failures".** A red starting tree is common
and must not cost the night — but a ticket may never *add* a failure. Re-capture the baseline after
every merge, so a ticket that happens to repair the tree has its improvement picked up
automatically, with nothing in this skill knowing that ticket was special.

### 1.6 Triage and size

One subagent per ticket, in parallel, `model: haiku`. Each reads exactly one ticket and returns:

- **`EXECUTABLE` or `NEEDS_HUMAN`.** An explicit `needs-human` label is authoritative and skips the
  judgment. Otherwise classify: work requiring a human to click through a third-party admin UI,
  upload or delete assets by hand, verify production data, or make a call the ticket left open is
  `NEEDS_HUMAN`. **`ready-for-agent` does not mean an agent can do it** — that label survives from
  ticket generation and routinely sits on spikes, ops chores, and production data gates.
- **Model and effort**, applying the rubric in `~/.agents/skills/pre-implement/SKILL.md`. Read that
  file; do not restate it here and do not invent your own rubric. If it is unreadable, default
  every ticket to `sonnet` / medium effort and note it.

You pass the returned model straight into the Agent call for that ticket. The recommendation is
actionable, not advisory.

A `NEEDS_HUMAN` ticket **does not stop the run**. It prunes its own subtree — anything blocked by
it waits for the user — and every other branch of the graph proceeds.

### 1.7 Print the plan and hand over the night

Write `ledger.json`, then print, compactly:

- Execution order, with the model chosen per ticket.
- What is human-blocked, and what that prunes.
- The gate command, or the ungated warning.
- Baseline failure count.
- Branch names, and the PR(s) that will be opened.

Then say plainly that the run is starting and the user can walk away. **This is the last moment
anyone is watching.**

---

# Phase 2 — The run loop

Work is bounded by construction: a finite graph, at most two attempts per ticket. There is no
runaway to guard against and therefore no wave cap. Keep going until the graph is exhausted.

### 2.1 Dispatch a wave

Take up to **3** tickets whose blockers are all merged. For each, in parallel:

```bash
git worktree add .ig.good-night/gh-<spec>-<slug>/wt-<n> -b gnhf/<spec>/<n>-<slug> <integration-branch>
```

Then run the repo's install command inside the worktree. Do it properly — do not symlink
`node_modules` from the primary tree. Symlinking is faster and quietly wrong the moment two tickets
touch dependencies, and **you have all night; wall-clock is the one resource this run has in
abundance.** Trade it for correctness every time.

### 2.2 Implement one ticket

One subagent per ticket, at the model triage chose, told to invoke `terse` first. Its prompt gives
it: the worktree path, the ticket number, the gate command, the baseline, and the envelope path.

The subagent **reads `~/.agents/skills/implement/SKILL.md` and follows it as its protocol.** It
cannot invoke that skill — it is user-invoked — but it can read the file, and that is the point:
this skill restates none of Matt Pocock's implementation protocol, so his skill can change without
anything here needing to be re-synced. If the file is unreadable, fall back to: write the test
first at the seams the ticket names, typecheck as you go, run the gate at the end.

Then, still inside the subagent: run the gate, and run `code-review` on the ticket's changes before
it is offered for merge. Overnight machine time is cheap, and a review finding caught here is one
that never contaminates the integration branch.

Rules the subagent is given explicitly:

- **Decide autonomously; report every decision.** When the ticket leaves something open, follow its
  own recommendation, or the codebase's existing pattern, and keep going. Never stop to ask. But
  record the question *and* the answer *and* the reason in `decisions[]` — an unrecorded autonomous
  decision is indistinguishable from a bug in the morning.
- **Never spawn your own subagent.** If the work needs one, say so in the envelope and return; the
  Orchestrator spawns it. State stays centralised.
- **Stay inside your worktree.** Never `git push`, never touch another worktree, never switch
  branches.

### 2.3 The envelope

The subagent writes `envelope-<n>.json` into the run directory and returns **five terse lines plus
the path**. Schema:

```json
{
  "ticket": 359,
  "status": "green | failed | needs_human",
  "branch": "gnhf/356/359-store-profile-module",
  "gate": { "result": "pass | fail | unverified", "new_failures": [], "output_tail": "" },
  "decisions": [{ "question": "", "decision": "", "why": "" }],
  "discovered_context": [{ "affects": [361], "note": "" }],
  "review_findings": [],
  "files_touched": [],
  "failure_reason": null
}
```

### 2.4 Merge, one at a time

Never merge two tickets at once. For each green ticket, in order:

1. Push the ticket branch. **Push it even though you are about to merge it** — if the integration
   branch ends up a mess, per-ticket branches are how the user salvages the tickets that went fine.
2. Merge into the integration branch.
3. Re-run the gate. Re-capture the baseline.
4. Remove the worktree.

On a merge conflict: dispatch a resolution subagent pointed at the `resolving-merge-conflicts`
skill. If it cannot resolve cleanly, abort the merge and treat the ticket as failed. Serialising
merges is what makes a conflict arrive attached to one identifiable ticket, while the run still has
hours to deal with it — rather than as one un-attributable pile-up at 4am.

### 2.5 Propagate what was learned

When an envelope carries `discovered_context`, dispatch a `haiku` subagent to **post a comment** on
each affected unstarted ticket, attributed to the run.

Comment, never edit the body. The bodies were authored by a ticket-generation skill this repo does
not control; appending to them couples this skill to someone else's format and destroys a clean
diff. A comment is timestamped, attributed, and additive.

### 2.6 Failure protocol

First failure: retry **once**, giving the subagent the previous attempt's gate output and failure
reason.

Second failure: stop on that ticket.

- `git worktree remove --force` the worktree, and delete the local branch. **That is the revert** —
  the work only ever existed in its own worktree, so nothing else is touched and there is nothing
  to unpick.
- Record the failure and the gate output in the ledger.
- **Prune the subtree** that depended on it and mark those tickets blocked-by-failure.
- Move on. One bad ticket must never cost the night.

Do not attempt a third time. A third attempt at the same failure means the approach is wrong rather
than the execution, and grinding it unattended just spends money to arrive at the same place.

---

# Phase 3 — Landing

### 3.1 Branches and PRs

Push the integration branch `gnhf/<spec>-<slug>`. Open **one PR** against the base branch resolved
in preflight.

**Unless the spec demands staged deploys** — signalled by distinct phase tags in the tickets'
`## Parent` lines, e.g. an additive phase, then a gate, then a behavioural phase, then a contract
phase that deletes the old path. That is rare. When it happens, open one stacked PR per phase, each
based on the previous, because shipping a deletion in the same PR as the addition it replaces is a
deploy hazard rather than a review inconvenience.

Create the PR with a placeholder body, then call the `pr-description` skill with the new PR id. It
posts without asking, which is what this run wants. It requires the PR to exist first — a
description cannot be generated for a PR that has not been opened.

Add the `⚠️ UNVERIFIED` stamp to the PR body for any ungated ticket.

### 3.2 The summary

Write `SUMMARY.md` to the run directory **and** post it as a comment on the spec issue. The file is
what the user reads over coffee; the comment survives the run directory being cleaned and is
visible to anyone else looking at the spec.

Order matters. **Lead with what needs a human, not with what went well:**

1. **Needs you** — human-blocked tickets, and what each unblocks.
2. **Failed** — ticket, what was tried, the exact error, what was reverted.
3. **Decisions made autonomously** — question, decision, why. Grouped by ticket.
4. **Shipped** — ticket, one line, review findings.
5. **PR links**, and any `⚠️ UNVERIFIED` tickets.

Keep it scannable. It is read by someone holding a coffee, not debugging.

### 3.3 Notify

Send one push notification with the tally:

```
9 shipped · 2 failed · 3 need you · PR #401
```

One notification, at the end, only. Never notify mid-run: nothing that happens at 3am is actionable
at 3am, and a phone buzzing about a ticket the run already reverted and moved past is worse than
useless.

### 3.4 Clean up

Remove every remaining worktree. Leave the run directory — it is the record. Leave ticket branches
pushed.
