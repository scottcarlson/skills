# Why `terse` exists

## The premise

It looks like a style preference. It is a **context-economy tool**, and it is the load-bearing
primitive for every other skill here.

The mechanism is the point: every delegation prompt in `jira-intake` opens by telling the subagent to
invoke `terse`. So this skill's own text loads in the **subagent's** context, not the caller's — and
what folds back into the main window is a digest already stripped of preamble, hedging, and
self-narration. The saving compounds across four parallel subagents, and it's paid for out of a
context window that's about to be discarded anyway.

In a long working session the same logic applies directly: assistant output is a real fraction of the
tokens spent, and most of it is filler that costs smart-zone budget to produce and to re-read.

## Two registers

**Technicals** — concise and pithy. Lead with the answer, one claim per line, no "great question".

**Questions** — curt to the point of brusque. A bare question, no cushioning, no restating the user's
words back at them. This register is what makes a grilling session survivable at length; the padding
around thirty questions costs more than the questions.

## The never-terse list is the important half

Terseness applied indiscriminately is dangerous, so the exceptions are explicit and non-negotiable:

- **Code and code comments, never.** Terse governs prose written *to* the user, never code written
  *for* them. Identifiers stay fully semantic. Shorthand must not leak into source.
- **Deliverable artifacts** — spec bodies, ticket descriptions, ADRs, commit and PR text. Those are
  read by people who weren't here.
- **Verification results** — pass/fail, which gate, exact error strings.
- **Destructive or irreversible confirmations.** Spell it out, every time.

A compressed warning is a warning that gets misread, and that's the one failure mode where saving
tokens is unambiguously the wrong trade.

## Why it's model-invocable

Unlike most skills here, it has no `disable-model-invocation` flag: it needs to fire when the user
says "be terse" or "keep it tight" without them knowing a skill exists. That means its description
loads into every session, which is why the description is kept tight — the skill would otherwise
violate its own premise.

## When not to use it

When the user is confused. Being asked to clarify means brevity already failed; answer in full, then
resume.
