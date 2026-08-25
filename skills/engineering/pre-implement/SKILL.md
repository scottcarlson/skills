---
name: pre-implement
description: Sizes one vertical slice and tells you the cheapest model and effort that will actually finish it, then sends you to a fresh session. Invoke with the issue/slice number, e.g. `/pre-implement 3`.
disable-model-invocation: true
---

# Pre-Implement

*Why this skill exists, the failure it prevents, and when not to use it: [WHY.md](./WHY.md).*

One job: **read one slice, name the minimum model and effort it needs, then get out of the way.** You do not plan it, explore for it, or start it.

## Process

### 1. Read the slice — only the slice

Fetch issue `<N>` (`gh issue view <N>`, or the local issue file). Read that issue and its blocking edges. Do **not** re-read the spec, the ADRs, or the ticket directory: a vertical slice is written to be independently grabbable, and if this one isn't self-contained enough to size from its own text, **that is the finding** — say so, because the slice needs fixing more than it needs a model recommendation.

### 2. Pick the model

| | |
| --- | --- |
| **Sonnet** | Documentation, boilerplate, tests, formatting, repetitive edits, straightforward implementation against a clear pattern that already exists in the codebase. |
| **Opus** | Complex code changes, architecture, algorithm design, gnarly debugging, decisions the spec left genuinely open. |

Defaults, not rules — judge the actual slice. A slice that says "copy the existing pattern in X to Y" is Sonnet work no matter how important the feature is. A slice touching a seam nothing else touches is Opus work no matter how few lines it is.

### 3. Pick the effort

Default **medium**. Reasoning effort pays off on under-determined problems, and a slice that survived grilling → spec → slicing has had most of its ambiguity removed already. Going high here mostly buys deliberation over choices that were made days ago.

Go higher only if the slice itself is still under-determined — an unresolved trade-off in the body, an unfamiliar API, a performance target with no known approach.

### 4. Report — four lines, then stop

1. **Model + effort**, with a one-line why.
2. **`/clear`** before starting. Non-negotiable: implementation must begin in a clean window.
3. **`/implement "GitHub issue #<N>"`** as the command to run in the new session — spell out "GitHub issue" so it can't be mistaken for a JIRA ticket number; vertical slices live here, not in JIRA.
4. Anything in the slice that looks **under-specified or mis-sliced**, if you found it in step 1.

Then stop. Do not clear, and do not start implementing.
