# Why `pre-implement` exists

## The premise

Model and reasoning effort are real levers with real costs, and the right setting differs per slice
of work. Boilerplate and tests on Opus at high effort is waste. A gnarly concurrency bug on a fast
model is a wasted afternoon and two failed fixes. Nobody makes this call deliberately unless
something asks them to.

## Why it's deliberately tiny

It reads **only** issue `<N>` and its blocking edges. It explicitly does *not* re-read the spec, the
ADRs, or the ticket directory.

That's not laziness — it's a test. A vertical slice is supposed to be independently grabbable. If
the ticket isn't self-contained enough to size from its own text, **that is the finding**, and it's
worth more than a confident guess assembled from four other documents. Re-reading everything would
hide the defect and cost most of a smart-zone budget to do it.

Effort defaults to **medium**, because the ambiguity was already removed upstream by grilling, the
spec, and the tickets. If a slice still feels under-determined at implementation time, the pipeline
leaked somewhere earlier.

## Its output is ephemeral on purpose

Four lines: which model, which effort, `/clear`, then `/implement <N>`. It advises a human
immediately before a reset, so nothing needs to persist. Writing a file would only create something
to go stale.

## When not to use it

Mid-slice. It's a decision made once, before the session that does the work. Re-running it after
implementation has started means the decision was already made by default.

## Neighbours

Runs per unblocked slice, after `to-tickets` and a `/clear`. Hands off to `/clear`, then `implement`.
