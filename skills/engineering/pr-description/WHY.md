# Why `pr-description` exists

## The premise

A PR description is read by people who weren't in the session — a reviewer at 4pm, an on-call
engineer in three weeks, whoever bisects this later. The context that made the change obvious to you
is exactly what they don't have, and it's exactly what evaporates when the session ends.

The default failure isn't an empty description. It's a description that restates the diff. "Updated
`CartDrawer.tsx`" tells a reviewer nothing they couldn't read faster themselves.

## Two modes, on purpose

**When this session did the work**, it draws on its own memory — the constraint discovered halfway
through, the approach abandoned, the reason a seemingly odd choice is right. That material exists
nowhere else and is gone the moment the session is.

**When it didn't**, it derives intent from the diff and commits instead, optionally sharpened by a
ticket id. Weaker, and honest about being weaker — better than a confident fabrication about
motivation it can't know.

## Why it reads the repo's own instructions

Screenshots make a UI change reviewable in five seconds instead of five minutes. But every repo
starts its dev server differently and screenshots differently, so the skill reads `CLAUDE.md`,
`CLAUDE.local.md`, and `AGENTS.md` for how *this* repo does it rather than guessing at `npm run dev`.

If the ticket has a cached payload from `jira-intake`, it uses it — that's the whole point of writing
payloads to disk instead of holding them in context.

## Constraints it obeys

**Drafts, then waits.** Editing a PR description is visible to everyone watching the PR.

## When not to use it

Before the PR exists. It rewrites an existing PR rather than opening one.

## Neighbours

Post-PR. Pairs with `pr-review`; either can run without the other.
