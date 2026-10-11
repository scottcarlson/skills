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
| **Ledger** | `ledger.json` in the run directory. The run's memory. Read and write it only through `assets/ledger.sh`. |
| **Envelope** | One ticket's `envelope-<n>.json`. What a subagent returns. |

---

# Phase 1 — Preflight

Everything here runs **before the user walks away**. Print progress as you go; they are watching.

A **hard fail** means: stop, explain what is wrong in one line, say what would fix it, and do not
start the run. Hard-failing at 11pm is cheap. Discovering the same problem at 3am costs the night.

### 1.1 Resolve the spec and the run directory

The argument holds a number, e.g. `"GitHub issue #356"`. That is the spec issue.

Look under `.ig.good-night/` at the repo root for a directory starting with `gh-<spec>-`. One
match, reuse it — unless it already holds a `ledger.json`: a previous run used it, and starting
over would overwrite that run's record and re-dispatch tickets it already merged. **Hard fail**,
print its `started_at` and `assets/ledger.sh tally`, and tell the user to rename or delete the
directory to start fresh. Resuming a run is not supported. None, create
`.ig.good-night/gh-<spec>-<slug>/`. Write the invoking message verbatim to `INITIAL-PROMPT.md`
inside it.

The `<slug>` comes from the spec title, and the same one is used everywhere — the run directory and
every `gnhf/` branch. Titles routinely hold characters a git ref rejects (`:`, `/`, `?`, `*`), and
a bad ref would only surface at `git worktree add -b`, after the user has walked away. Derive it
mechanically, never by hand:

```bash
printf '%s' "<spec title>" | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40 | sed -E 's/-+$//'
```

Use `spec` if that comes out empty, then **hard fail** unless
`git check-ref-format --branch gnhf/<spec>-<slug>` accepts it.

Confirm `.gitignore` covers `.ig.*`. If it does not, **hard fail**: tell the user to run
`/setup-scott-carlson-skills`, which owns that line. This skill does not write `.gitignore`.

### 1.2 Environment

Run `assets/preflight.sh` and keep its JSON stdout: `repo` and `base_branch` feed every step below.
It checks, and **hard fails** on any of:

- `gh auth status` — authenticated, with `repo` scope. A fine-grained or app token reports no
  scopes, so for those this is a warning instead.
- Working tree clean. Uncommitted changes would be swept into the first worktree.
- Remote reachable, and the base branch resolved from `gh repo view --json defaultBranchRef`.
  Never assume `main`.
- `git worktree` usable.

It **warns but does not fail** if `~/.agents/skills/implement/SKILL.md` or
`~/.agents/skills/pre-implement/SKILL.md` is unreadable — see [§1.6](#16-triage-and-size) and
[§2.2](#22-implement-one-ticket) for what happens then.

### 1.3 Build the dependency graph

Run `assets/graph.sh <spec> <repo> <run-dir>`, with `repo` from preflight's output. It writes
`<run-dir>/graph.json`. Do not do this by hand and do not eyeball the output; the script is
deterministic and you are not.

It discovers children by **timeline cross-references on the spec, filtered to issues that name the
spec inside their own `## Parent` section.** Both filters are required: cross-references alone
catch any issue that merely mentions the spec — including the spec's own sibling specs, which
cross-reference each other — and the `ready-for-agent` label alone catches unrelated issues
elsewhere in the repo.

The `## Parent` section's format varies by vintage of the ticket generator: `Spec: #356 · ADR 0017`
and a bare `#27` are both in the wild. Match the spec number **anywhere inside that section** and
nowhere else. Anchoring on a `Spec:` prefix finds zero children on older repos, which is
indistinguishable from "this spec has no work left".

It parses each child's `## Blocked by` section into edges. Values are `- #<n>` lines, or a literal
saying there are none. Any other non-blank line is a hard fail rather than a guess.

**Hard fail on any of:**

- **An unexpanded placeholder** — a `#$` sequence in a `## Blocked by` section. This means the
  ticket-generation step wrote a shell variable instead of an issue number. The graph is corrupt,
  and parsing it anyway produces a confident, wrong order in which cleanup tickets run before the
  work they clean up after. Name the affected issues and stop.
- **A cycle.**
- **An edge pointing at an issue that does not exist.**
- **A ticket with no `## Blocked by` section.** Its dependencies are unknown, not empty; treating
  it as a root would run it before whatever it depends on.
- **A phase-tag contradiction.** Tickets carry a phase in their `## Parent` line — `**PR1**`,
  `**PR2**`, `**cleanup**`, and so on. Phase order and `## Blocked by` encode the same constraint
  from two angles, and they are written by hand independently. If an edge runs backwards against
  phase order, one of the two is wrong and there is no way to tell which at 3am. Stop.

A blocker that sits *outside* the graph is **not** an error, and this distinction matters because
specs are routinely half-worked:

- **Blocker is closed as completed** (or is a merged PR) → already satisfied. Drop the edge and
  carry on. Failing here would refuse to run any spec that had been partly completed, which is
  most of them.
- **Blocker is open but not a `ready-for-agent` child of this spec, was closed as not planned or
  duplicate, or is a PR closed without merging** → a genuine external block: the work it stood
  for has not been done.
  Record it, mark the ticket blocked, prune its subtree, and **keep going.**

When nothing runnable is found, say *which* of these it was: all children closed (the spec is
done), children open but unlabelled, or nothing declaring this spec as parent (it may be a
companion spec whose tickets hang off a sibling). One generic "no tickets found" sends the user
looking in the wrong place.

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

Resolve the **install command** once alongside it, from the same sources in the same order: an
`install:` line in that block, else the lockfile (`package-lock.json` → `npm ci`, `pnpm-lock.yaml` →
`pnpm install --frozen-lockfile`, `yarn.lock` → `yarn install` with its frozen-lockfile flag, and so
on). Running it during [§1.5](#15-capture-the-baseline) is what proves it works before anyone walks
away; a ticket worktree must never be the first place it fails.

### 1.5 Capture the baseline

Create the integration branch `gnhf/<spec>-<slug>` from `origin/<base_branch>` in its own worktree:

```bash
git worktree add .ig.good-night/gh-<spec>-<slug>/wt-integration -b gnhf/<spec>-<slug> origin/<base_branch>
```

The user's primary tree is never checked out or merged into — it may be on any branch, holding
anything. Every merge and every post-merge gate run in [§2.4](#24-merge-one-at-a-time) happens in
`wt-integration`.

Run the install command there, then the gate, and record every failure to `baseline.json`.

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

Create the ledger, passing an empty gate string when ungated:

```bash
assets/ledger.sh init <run-dir> <run-dir>/graph.json "<gate>" <base_branch> gnhf/<spec>-<slug>
```

Then mark each human-blocked ticket from [§1.6](#16-triage-and-size) with
`assets/ledger.sh set <run-dir> <n> status '"needs_human"'` — `set` takes a JSON value, so strings
carry their own quotes. Statuses are `pending`, `merged`, `failed`, `needs_human`,
`blocked_by_failure`, and `blocked_external` (set by `init` from the graph). Record `attempts`,
`branch`, `model`, and `envelope` the same way as they become known.

Then print, compactly:

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

Take up to **3** tickets from `assets/ledger.sh ready <run-dir>` — pending, every blocker merged.
For each, in parallel:

```bash
git worktree add .ig.good-night/gh-<spec>-<slug>/wt-<n> -b gnhf/<spec>/<n>-<slug> <integration-branch>
```

Then run the install command resolved in [§1.4](#14-resolve-the-gate) inside the worktree. Do it properly — do not symlink
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

Then, still inside the subagent, run the gate. Then call the Skill tool with `"code-review"` on the
ticket's changes before it is offered for merge. Overnight machine time is cheap, and a review
finding caught here is one that never contaminates the integration branch.

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

Route on `status`: `green` goes to [§2.4](#24-merge-one-at-a-time), `failed` to
[§2.6](#26-failure-protocol). **`needs_human`** — the ticket hit something only a person can
decide — is neither:

- Push the ticket branch if it has commits, so the human starts from the partial work, then remove
  the worktree.
- `ledger.sh set` the status to `"needs_human"`, and carry `failure_reason` into the summary's
  **Needs you** section as the question to answer.
- Do not retry it; a second attempt cannot answer a question the first could not. Its subtree
  waits, exactly as for a ticket triaged `NEEDS_HUMAN` in [§1.6](#16-triage-and-size) — `ready`
  never offers a ticket whose blocker has not merged.

### 2.4 Merge, one at a time

Never merge two tickets at once. Merge inside `wt-integration`. For each green ticket, in order:

1. Push the ticket branch. **Push it even though you are about to merge it** — if the integration
   branch ends up a mess, per-ticket branches are how the user salvages the tickets that went fine.
2. Note the integration branch's SHA, then merge into it.
3. Re-run the gate. **New failures versus baseline mean the merge broke something** — two tickets
   can each pass alone and fail together. Reset the integration branch to the noted SHA and treat
   it as a failed attempt under [§2.6](#26-failure-protocol), re-dispatching from the new
   integration head with the gate output. Never re-capture the baseline over a regression: that
   would turn a ticket adding a failure into the new normal.
4. Only on a green gate: re-capture the baseline, `ledger.sh set` the ticket's status to
   `"merged"`, and remove the worktree.

On a merge conflict, dispatch a resolution subagent and tell it: call the Skill tool with
`"resolving-merge-conflicts"`. If it cannot resolve cleanly, abort the merge and treat the ticket as
failed. Serialising merges is what makes a conflict arrive attached to one identifiable ticket,
while the run still has hours to deal with it — rather than as one un-attributable pile-up at 4am.

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
- Set the ticket's status to `"failed"` in the ledger, and save the gate output beside it in the run
  directory.
- **Prune the subtree** that depended on it and set those tickets to `"blocked_by_failure"`.
- Move on. One bad ticket must never cost the night.

Do not attempt a third time. A third attempt at the same failure means the approach is wrong rather
than the execution, and grinding it unattended just spends money to arrive at the same place.

---

# Phase 3 — Landing

### 3.1 Branches and PRs

**If nothing merged** — every ticket failed or waits on a human — skip this section entirely:
the integration branch has no commits over the base, GitHub rejects a PR with no diff, and a failed
`gh pr create` must not stop the run before the summary is written. Go straight to
[§3.2](#32-the-summary), which says why nothing shipped.

Push the integration branch `gnhf/<spec>-<slug>`. Open **one PR** against the base branch resolved
in preflight.

**Unless the spec demands staged deploys** — signalled by distinct phase tags in the tickets'
`## Parent` lines, e.g. an additive phase, then a gate, then a behavioural phase, then a contract
phase that deletes the old path. That is rare. When it happens, open one stacked PR per phase, each
based on the previous, because shipping a deletion in the same PR as the addition it replaces is a
deploy hazard rather than a review inconvenience.

Create the PR with a placeholder body. Then call the Skill tool with `"pr-description"`, passing the
new PR id. It posts without asking, which is what this run wants. It requires the PR to exist first
— a description cannot be generated for a PR that has not been opened.

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

Send one push notification with the tally from `assets/ledger.sh tally <run-dir>`:

```
9 shipped · 2 failed · 3 need you · PR #401
```

One notification, at the end, only. Never notify mid-run: nothing that happens at 3am is actionable
at 3am, and a phone buzzing about a ticket the run already reverted and moved past is worse than
useless.

### 3.4 Clean up

Remove every remaining worktree. Leave the run directory — it is the record. Leave ticket branches
pushed.
