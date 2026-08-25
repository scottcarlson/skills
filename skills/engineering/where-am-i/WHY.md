# Why `where-am-i` exists

## The premise

Every session that resumes a multi-slice effort — a fresh, cleared session, or the middle of the
grilling session that's driving the pipeline slice by slice — re-derives tracker state from
scratch by paging through issues. Two facts matter most for pacing an AFK/HITL workflow, and
nobody computes either by hand: what's safe to fire off concurrently, and what human work is
available right now while agents churn on the rest. Without them, the human either idles waiting
on an agent or works the frontier serially instead of in parallel, and a high-leverage HITL
decision (the one blocking three other tickets, not one) looks the same as a low-leverage one
until someone counts.

## Why it's read-only

It writes nothing back to the tracker — no labeling, claiming, closing, or drafting. A status
skill that also acts hides the moment it made a judgment call that should have been the human's,
and it can't be re-run cheaply to check "did anything change" if running it changes something. It
should be safe to invoke as often as the tracker itself changes.

## Why it delegates the fetch

A live effort can run to dozens of issues once labels, assignees, dependencies, and bodies are
counted. Reading all of that into the driving session just to throw most of it away is the exact
bulk-read mistake `jira-intake` avoids for tickets and Figma frames — a subagent fetches, this
session only sees the digest.

## Its output is ephemeral on purpose

A status map is only true at the moment it's rendered. Writing it to a file would create something
that goes stale the next time an issue closes; the fix is to re-run the skill, not to diff a saved
copy.

## When not to use

Mid-slice, while a single already-claimed issue is being sized or built — that's `/pre-implement`
and `implement`'s job on an issue you've already chosen. And before `/to-tickets` or `/wayfinder`
has published anything: there's no tracker state yet to map.

## Neighbours

Runs any number of times after `/to-tickets` or `/wayfinder` has published tickets, anywhere in
the per-slice loop. Complements `/pre-implement`, which sizes one slice you've already picked —
`where-am-i` is how you pick it.
