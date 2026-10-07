# Why `pr-review` exists

## The premise

Any single reviewer has one fixed set of blind spots — and that's as true of a model as it is of a
person. A model reviewing a diff alone produces findings that are individually plausible and
collectively unbalanced: three nitpicks about naming, silence on the race condition.

The fix isn't a better prompt. It's more than one perspective, and something adversarial between the
findings and the code.

## Three passes before anything is written

1. **GitHub Copilot's review comments**, folded in if it has run one. Already there, already paid for,
   and it catches a different class of thing.
2. **An independent review**, done without deferring to Copilot's findings — reading them first would
   just anchor to them.
3. **Codex peer-reviews the combined findings.** This is the load-bearing step. It's cheap to generate
   a confident, wrong finding, and expensive to have one land in a teammate's PR. A second model
   trying to refute each finding kills the plausible-but-wrong ones before they cost anyone time.

Only then does anything get implemented.

## Why fixes land as a follow-up PR

One commit per change, in a new PR targeting the original — not force-pushed over someone's branch.
The author keeps the ability to read each fix in isolation, take some and reject others, and see what
changed since they last looked. Rewriting their history to "help" removes all of that.

Every Copilot comment on the original PR gets a reply — a fix link if acted on, a concrete reason if
not. The author resolves threads when the follow-up merges; an unanswered thread leaves them guessing
whether it was seen, ignored, or missed.

The description is structured (critical / architectural / cleanup / peer-reviewed / context) because a
flat list of fifteen fixes gets skimmed and merged, which defeats the point of reviewing.

## Constraints it obeys

**Confirms before opening the PR or replying.** Both are team-visible and it's someone else's branch.

## When not to use it

On your own uncommitted work — use `code-review` for that. This skill is shaped around a PR that
exists and an author who isn't you.

## Neighbours

Post-PR. `code-review` is the real review during implementation; this is the review of a PR.
