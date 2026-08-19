# Why `to-adr` exists

## The premise

An ADR's value is the **argument**, not the outcome. "We chose Postgres" is nearly worthless six
months later. "We chose Postgres over DynamoDB because the read model needs ad-hoc joins we couldn't
predict" is what stops someone re-litigating it, or worse, quietly reversing it.

Arguments are exactly what a context reset destroys. `/compact` keeps a lossy summary — outcomes
survive, reasoning doesn't. And the artifacts on disk are no help: a spec records *what* was decided
and tickets record *what to build*. Neither records what the decision beat.

So there is exactly one moment when writing an ADR is cheap and accurate: immediately after
`to-tickets`, while the losing options are still in context. Before any reset. **The timing is the
entire skill.**

## Why it isn't already handled

`domain-modeling` offers ADRs, but under guidance to do so *sparingly* — three conditions, all of
which must hold. That bias is correct in general and reliably under-triggers in practice, precisely
during a long planning session where the most ADR-worthy decisions get made. This skill exists to
be the gate that doesn't rely on a judgement call going the right way.

It also checks `docs/adr/` **on the filesystem** rather than recalling whether an ADR got written.
Late in a long session, recall on that question is unreliable, and the failure is silent.

## What it does

Lists the decisions this session crystallised, reads `docs/adr/` to see which already have a
committed ADR, writes only what's missing, and updates the glossary. It delegates the writing to
`domain-modeling` via the Skill tool, but the gate is its own: nothing advances until the files
exist.

## When not to use it

When nothing was actually decided against an alternative. A session that only discovered facts has
nothing to record — an ADR with no rejected option is a changelog entry wearing a costume.

## Neighbours

Runs immediately after `to-tickets`. Hands off to `/clear`, then `pre-implement`.
