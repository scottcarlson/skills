# Why `setup-scott-carlson-skills` exists

## The premise

Two facts about the distribution channel, and everything here follows from them.

**One: the installer copies skill folders and nothing else.** It never writes `~/.claude/agents/` and
never touches a `CLAUDE.md`. So anything a skill needs that isn't a skill has no way to reach a new
machine on its own.

**Two: it copies the whole folder, verbatim** — siblings, subdirectories, scripts, all of it. So a
skill can carry arbitrary payload and install it.

This skill is the consequence: it's the delivery vehicle for the three things the installer can't
deliver, and it exists because there is no other way to get them there.

## What it delivers, and why each matters

**The dependency check.** These skills are connective tissue around Matt Pocock's skills, not a
standalone suite. `grill-for-refinement` calls `grilling`; `jira-intake` and `pre-implement` hand off
to `grill-with-docs`, `wayfinder`, `to-spec`, `to-tickets`, and `implement`. Install these alone and
the pipeline dead-ends at the first handoff — silently, mid-session, after you've already spent the
context. The check moves that failure to install time.

There's a trap it exists to avoid: several of those skills are user-invoked, so they're **hidden from
the skill list even when correctly installed**. Checking the list rather than the filesystem reports
them missing when they're present.

**The subagent definitions.** `jira-intake` dispatches to `exhaustive-reasoner`. Without a definition,
that's a failed dispatch. And `exhaustive-reasoner` ships as `model: fable` — on a plan without Fable
it's *worse* than missing, because it fails mid-run rather than at setup. Hence the explicit check and
the offered rewrite to `model: opus`.

**The standing policy.** The highest-value thing in this repository that isn't a skill. The pipeline
assumes a context discipline — the ~100K ceiling, bulk reads to subagents, the escalation ladder after
two failed fixes, never trusting a self-reported pass — that lives in `CLAUDE.md` deliberately, so
that `implement` and everything else inherit it for free. Install only the skills and you get the
mechanics without the reasoning that makes them work.

**The gitignore line.** `jira-intake` writes raw ticket exports and image notes to disk by design.
Without `.ig.*` ignored, the first run commits them.

## The two hard limits

**It cannot install skills.** No skill can reliably install skills into the harness running it. So it
prints commands and the user runs them.

**It cannot run `/setup-matt-pocock-skills`.** That skill is user-invoked, and a user-invoked skill can
never be called by another skill. So the handoff is a sentence addressed to the human.

Both limits are structural, not oversights. Trying to route around either produces a skill that fails
in a way its author never sees.

## Why it writes to global config, and asks first

The pipeline is used across every repo, so per-repo agent definitions and policy would need
re-installing constantly. Only the gitignore line is per-repo.

But global config is a file the user owns and didn't ask to have rewritten. So the policy block is
shown as a diff and appended only on an explicit yes, wrapped in markers so a later run can update it
in place without touching anything around it. Existing agent definitions are never overwritten.

## When not to use it

Once per machine, and again only if you want to re-check prerequisites or add the policy to a
`CLAUDE.md` that didn't exist the first time.
