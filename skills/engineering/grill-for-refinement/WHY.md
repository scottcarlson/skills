# Why `grill-for-refinement` exists

## The premise

A ticket arrives at refinement half-formed. The team then spends thirty minutes discovering, live and
expensively, that nobody agreed on the empty state, or that this is really two tickets. Most of that
discovery didn't need the whole team — it needed one person being asked the right questions
beforehand.

## The distinction that is the whole skill

**A refinement lens, not an implementation lens.** Asked to sharpen a ticket, a model will reliably
drift into how to build it — which table, which component, which hook. That's the wrong conversation
and it produces a ticket full of premature technical commitments.

So the questions stay on: are the acceptance criteria testable, what edge and empty states are
unaddressed, what's explicitly out of scope versus silently assumed, what does done include, is this
sized right or hiding two tickets. Implementation questions are in scope only when the ticket itself
raises a technical concern.

## Why it owns the lens but not the mechanics

The interview mechanics — rounds, recommended answers, dependency-ordered questions — belong to
`grilling`, and this skill calls it via the Skill tool rather than restating them. That's deliberate:
those mechanics have already changed once upstream (one-question-at-a-time became rounds), and a copy
would have silently drifted into describing behaviour that no longer exists.

The lens is ours. The interview isn't.

## Why a second planner proposes each round

One model drafting refinement questions has one set of blind spots — it'll probe empty states
thoroughly and never ask whether the ticket is really two. When Gemini 4 Neon is connected via `agy`,
it drafts each round independently from the same brief, and the two lists are merged before you see
them: agreement raises confidence in a recommended answer, divergence becomes a question worth
asking. It runs blind — a planner that reads the other's draft first just agrees with it — and
read-only, on an inline brief written to `$TMPDIR`, so the skill stays ephemeral. Codex is a third
view only when a split actually matters. Without `agy`, the skill runs exactly as before.

Linked context is fetched by subagents that return digests, for the same reason as `jira-intake`:
a few Figma frames and a spike doc would otherwise spend the context the interview needs.

## Constraints it obeys

**Purely ephemeral** — no files in the repo; planner B's round briefs live in `$TMPDIR` and are
deleted at the end. There's nothing worth caching about a ticket you're about to change.

**Posts only on confirmation.** The output is a comment on a ticket the whole team reads. It drafts,
shows the full text, and waits. It also splits what you answered from what the team still has to
discuss, so the comment doesn't imply agreement nobody gave.

## When not to use it

When the ticket is already solid — the skill will tell you so rather than manufacture filler. And
when you're ready to *build*: that's `jira-intake`. This one runs before a ticket is ready for that.

## Neighbours

Outside the delivery pipeline entirely. Feeds a refinement meeting, not a build.
