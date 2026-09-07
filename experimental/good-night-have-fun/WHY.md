# Why `good-night-have-fun` exists

## The premise

The front of the pipeline is solved. `/grill-with-docs` → `/to-spec` → `/to-tickets` reliably turns
a vague intention into a spec and a set of vertical slices, each declaring its blocking edges. What
follows is the part that does not scale: a human sitting in front of a terminal, running
`/pre-implement`, `/clear`, `/implement`, `/code-review` — once per ticket, sixteen times, each in a
fresh session, each requiring them to be awake.

That loop is almost entirely mechanical. The tickets already carry their order. The repo already
knows what green means. The only genuinely human step is deciding whether the result is any good,
and that decision is better made against a finished PR in the morning than against a diff at
midnight.

This skill runs the loop while you sleep.

## The failure it prevents

**Context rot ending the night halfway through.** The naive version of this — one session that
reads every ticket, writes every implementation, and remembers every result — degrades past
usefulness somewhere around ticket five. The Orchestrator's context is the scarce resource, and
every design decision here is downstream of protecting it: subagents spun up and torn down per
ticket, payloads written to disk and digests returned, a ledger re-read each wave instead of a
history carried forward. A sixteen-ticket night should cost roughly what a four-ticket night costs,
and it does, because the Orchestrator never accumulates.

**Waking up to confident garbage.** An unattended run that cannot tell whether its work is correct
will still produce a PR, and that PR will look finished. So the gate is resolved once, before
anyone walks away; the baseline is captured so a repo that starts red does not poison every verdict;
and a ticket that lands with no gate available is stamped `⚠️ UNVERIFIED` in the PR body itself,
where it cannot be missed.

**One bad ticket costing the whole night.** A failure that halts the run wastes the seven hours it
had left. Worktree-per-ticket makes the revert free — delete the directory and nothing else was
ever touched — so a failed ticket costs its own subtree and nothing more.

**Being asked a question at 3am.** Nobody is there. So subagents decide autonomously and record the
decision rather than stopping, and everything that *could* require a human — auth, a corrupt
dependency graph, an unresolvable gate, a ticket only a human can do — is forced to surface during
preflight, while the user is still watching.

## The decisions worth knowing about

**The spec issue is the argument, not a label.** A label answers "which issues are agent-ready" but
not "which belong together" or "in what order". The spec answers all three, and it is an artifact
the pipeline already produced. Membership comes from timeline cross-references confirmed by a
`Spec: #N` line in the ticket body; order comes from `## Blocked by`.

**Declared dependencies only — never inferred.** The edges are in the tickets. Inferring them costs
Orchestrator context and produces a graph nobody can audit. Where the declared data is corrupt, the
run stops rather than guessing: a wrong order silently produces cleanup tickets that run before the
work they clean up after, and that is indistinguishable from success until you read the diff.

**Matt Pocock's skills are read, not restated.** `implement` and `pre-implement` are user-invoked,
so no skill can call them. Rather than copying their protocols into this one — which would need
re-syncing every time he ships — subagents read the installed `SKILL.md` off disk and follow it.
The coupling is to a file path, it is checked in preflight, and it means his improvements arrive
for free.

**Wall-clock is spent freely; context is not.** Real dependency installs per worktree instead of
symlinks, a code review per ticket, the gate re-run after every merge. An overnight run has hours
and hours to spare and very little context to spare, so every trade goes the same way.

## When not to use it

- **When the tickets have not been through `/to-tickets`.** No `## Blocked by` sections means no
  graph, and this skill will refuse rather than invent an order.
- **When the work is genuinely under-specified.** This runs slices that survived grilling. A ticket
  with an open design question in it will get an autonomous answer, and that answer will be a
  coin flip.
- **When the repo has no way to tell whether it is working.** It will run ungated and say so, but a
  night of unverifiable output is worth less than a night of sleep.
- **When you need one ticket done well right now.** Use `/pre-implement` and `/implement`. This skill
  is for volume and for hours you were not going to be awake for anyway.
