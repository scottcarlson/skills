---
name: to-adr
description: Capture this session's crystallized decisions as committed ADRs before the context is cleared. Checks docs/adr/ on the filesystem for what already exists, writes only what's missing, and updates the glossary. Run immediately after /to-tickets, while the arguments behind the decisions are still in context.
disable-model-invocation: true
---

# To ADR

*Why this skill exists, the failure it prevents, and when not to use it: [WHY.md](./WHY.md).*

Land this session's decisions in `docs/adr/` **before the context that produced them is destroyed.**

## Why this runs now and not after a compact

An ADR's value is the *argument* — the trade-off weighed, the option rejected and why. A `/compact` keeps outcomes and drops arguments, and the spec and tickets on disk record *what* was decided, never *what it beat*. So this is the last moment the real input exists. Run it straight after `/to-tickets`, before any reset.

## Process

### 1. List what this session decided

From the grilling / wayfinding, the spec, and the tickets, list the decisions that got resolved. Include the ones that were resolved by **rejecting** something — those are the most valuable and the easiest to lose.

### 2. Check the filesystem, not your memory

Read `docs/adr/` and see which of those decisions already has a committed ADR. Check the directory; do not rely on recall of whether `/grill-with-docs` wrote one. It routinely doesn't — `/domain-modeling`'s "offer ADRs sparingly" guidance biases toward under-triggering, and that bias is the whole reason this skill exists.

### 3. Write the missing ones

A decision earns an ADR when it **names a trade-off**, **constrains future work**, or **would surprise a newcomer** reading the code. When in doubt, write it — under-triggering is the failure mode here, not over-triggering.

Match the existing files in `docs/adr/` for numbering, filename shape, and structure (`NNNN-kebab-case-title.md`). Each one states: the context that forced a choice, the decision, the alternatives rejected **and why**, and the consequences. Keep ADR prose **full and semantic** — never terse. These are read by humans months later, and by agents with no other source for the reasoning.

Also add any new domain terms to `CONTEXT.md` at the repo root.

Call the Skill tool with `"domain-modeling"` to do the writing if it helps, but the gate is this skill's: nothing advances until the files exist.

### 4. Report and hand off

List the ADRs you wrote and the ones already present. Then tell me:

1. **`/clear`** — not `/compact`. Planning is over; implementation reads from the tickets, and Matt's model is that a well-sliced issue carries its own context. Nothing from this session needs to travel.
2. Then **`/pre-implement <issue-number>`** for the first unblocked slice.
