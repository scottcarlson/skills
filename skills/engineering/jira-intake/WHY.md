# Why `jira-intake` exists

## The premise

A model's *usable* intelligence degrades well before its context window fills. On a large-window
model the smart zone is roughly the first 100K tokens; past that you still get answers, they're just
worse. A million-token window didn't fix this — it shipped a lot more room to be bad in.

Starting work on a real ticket is the single worst offender. A ticket export, three Figma frames,
two before/after screenshots and a Slack thread will spend 30–60K tokens of that smart zone
*before any thinking has happened*. The planning that follows then runs in the degraded region,
which is exactly backwards: planning is the part that most needs the model at full strength.

## What it does about it

Raw material never enters the main window. One subagent per source reads it, writes the payload to
disk, and returns a digest of at most ten lines. The main session sees only digests, and folds them
into a brief under thirty lines.

This is why the skill carries a **hard prohibition** rather than a preference: the main session must
never call `getJiraIssue`, `get_design_context`, or `get_screenshot`, and must never `Read` an image
or a transcript. Stated as a preference, it gets rationalised away in the moment — "it's only one
screenshot." The prohibition is the skill.

Two details that look incidental and aren't:

- **Subagents are launched in a single message**, so they run concurrently rather than serially.
- **The invoking prompt is written verbatim to `INITIAL-PROMPT.md`** before anything else. The skill
  ends by telling you to `/compact`, and free-text framing supplied at invocation is often the
  sharpest steer on the whole effort. It must survive the reset, so it goes to disk.

## Constraints it obeys

Every delegation prompt opens by telling the subagent to invoke `terse`, so that skill's own text
loads in the subagent's context rather than the caller's. Digests fold back cheap.

The skill ends by naming the next command and the reset that precedes it. That's what lets a typed
pipeline work without a conductor skill holding it all in context.

## Known wrinkle

Figma links usually live in the JIRA body, so the ticket subagent has to return before the Figma
subagent knows what to fetch. Intake is two rounds, not one, whenever that's the case. Launching the
Figma agent on guessed links is worse than waiting.

## When not to use it

When there's no ticket, or when you already hold the context and just want to plan — go straight to
`grill-with-docs`. This skill's whole value is cheap context acquisition; with nothing to acquire
it's pure overhead.

## Neighbours

Entry point. Hands off to `/compact`, then `grill-with-docs` for one coherent feature, or
`wayfinder` when the work won't fit a single session.

Its handoff also carries the standing reminder to write ADRs before that planning session resets —
a job a dedicated `to-adr` skill used to own as a separate pipeline step. Folded in here instead:
it's one line the model already needs to see at handoff time, and a whole extra skill for one line
was more ceremony than the reminder was worth.

## The planning protocol

When the handoff is to grilling or wayfinder, intake also writes `PLANNING-PROTOCOL.md`: two
independent planners per wave (the orchestrator, plus Gemini — Neon for grilling, Carbon for
wayfinder — when `agy` has it connected), Codex as a third view or tie-breaker when the orchestrator
judges it worth it, subagents for every bulk read, and for wayfinder a map shape and a close-out
routine. Same premise as `pr-review`: one planner has one set of blind spots, and a planner that sees
the other's answer first just agrees with it, so planner B is run blind on a written brief.

The wayfinder shape is lifted from two real runs — a finished migration and a theme rebuild still in
flight. What worked there is kept (one map with native sub-issues, a "Decisions so far" index,
resolution comments, heads-up comments on dependent tickets); what went wrong is turned into rules
(wave specs that weren't sub-issues so the map's counter lied, scope changes restated on three
tickets, rulings edited into ticket bodies until body and comments disagreed, a map left open after
its destination was met). It's written to disk rather than left in the handoff text because
wayfinder ticket sessions start fresh, and the map's own Notes restate it because the ticket
directory is local-only.

Fable is recommended for wayfinder and Opus is fine for grilling because the two sessions fail
differently: grilling is one dense interview, wayfinder is a long-lived map held together across many
tickets. And sometimes neither is needed — an interview over a small, unambiguous ticket only restates
it — so intake asks which path it is, alongside run mode and continue-or-handoff, with "neither"
going straight to `/pre-implement` → `/implement`. It's asked rather than announced because the
answer decides whether the planning protocol, the model switch and the rename apply at all.

## Run mode

Intake also asks whether the run will be manual or GNHF (`good-night-have-fun`). That has to be
decided here, because the planning that follows is shaped by it: an overnight run has no human to
answer a question a ticket left open, so `to-spec` and `to-tickets` must be told up front to settle
what they can. Intake is the last place the answer can be carried forward before a `/compact` or a
fresh session erases the context that would have supplied it.
