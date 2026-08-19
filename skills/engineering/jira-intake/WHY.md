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
