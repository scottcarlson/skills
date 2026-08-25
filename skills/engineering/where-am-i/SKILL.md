---
name: where-am-i
description: Turns this repo's GitHub issues into a status map — done, blocked, ready for an agent, ready for you — and calls out what can run concurrently and what HITL work you can take while agents churn. Works in a fresh session or mid-pipeline. Takes an optional spec or wayfinder-map issue number to scope and re-align. Invoke as `/where-am-i` or `/where-am-i 42`.
disable-model-invocation: true
argument-hint: "[spec-or-map-issue-number]"
---

# Where Am I

*Why this skill exists, the failure it prevents, and when not to use it: [WHY.md](./WHY.md).*

One job: **turn the tracker into a status map.** Read every issue relevant to the current effort, classify it, and report what's done, blocked, ready to hand an agent, and ready to hand a human — plus what's safe to run concurrently right now. It does not triage, plan, size, or implement anything, and it writes nothing back to the tracker.

## Process

### 1. Resolve the repo and the scope

Confirm the current directory is a git repo with a GitHub remote (`gh repo view`).

- **Argument given** (an issue number): treat it as the spec or map to re-align against.
  - If it's labeled `wayfinder:map`, its children are the scope.
  - Otherwise treat it as a plain parent issue — the scope is that issue plus every open or closed issue whose body references it (a `Parent #<N>` line, or a native sub-issue relationship).
- **No argument**: look for exactly one open issue labeled `wayfinder:map` — if found, use it as the scope. Otherwise, list open issues and check whether they share a common `Parent #<N>`; use that as the scope. If you find several unrelated efforts live at once (more than one open map, or issues pointing at different parents), list what you found and ask which one before continuing — don't guess.

### 2. Gather — delegate the bulk read

A live effort can run to dozens of issues once labels, assignees, dependencies, and bodies are all counted. Pulling all of that into this session just to throw most of it away is the same bulk-read mistake every other skill in this pipeline avoids. Dispatch a single `general-purpose` subagent (tell it to invoke the `terse` skill first) to do the fetching and hand back a structured digest, not the raw issues.

The subagent should, for the resolved scope:

```
gh issue list --state all --json number,title,state,labels,assignees,body
```

then, for every **open** issue in scope, its native blocking summary:

```
gh api repos/<owner>/<repo>/issues/<n> --jq '{number, blocked_by: .issue_dependencies_summary.blocked_by}'
```

Where native dependencies aren't available, fall back to parsing a `Blocked by: #<n>, #<n>` line from the issue body — the same convention `/to-tickets` and `/wayfinder` both write.

Have it return one row per issue: `number, title, state, labels, assignee (or none), blocked_by (only the still-open blockers), wayfinder-type (if a wayfinder:<type> label is present)`.

### 3. Classify each issue

Apply these rules in order — first match wins:

| Status | Rule |
| --- | --- |
| **Done** | `state == closed` |
| **In progress** | open, has an assignee |
| **Blocked** | open, unassigned, `blocked_by` is non-empty |
| **Ready for agent** | open, unassigned, no open blockers, labeled `ready-for-agent` or `wayfinder:research` |
| **Ready for you (HITL)** | open, unassigned, no open blockers, labeled `ready-for-human` or `wayfinder:grilling`/`wayfinder:prototype`/`wayfinder:task` |
| **Unclassified** | anything left over — an open, unblocked, unassigned issue with none of the above labels |

Don't guess at an unclassified issue's status from its title. Report it as unclassified and say what label is missing; that's a tracker-hygiene gap worth surfacing, not papering over.

**Leverage.** For each issue currently in **Blocked**, note which of its open blockers are themselves classified **Ready for you (HITL)**. Count, for each such HITL-ready issue, how many blocked issues it gates. This is the number that matters most: resolving a high-count HITL ticket is what turns the next batch of work agent-ready, so it should outrank a low-count one even if both are "ready now."

### 4. Render the table

Order sections the way you'd act on them, not alphabetically or by issue number:

1. **Ready for agent now** — every issue here can be dispatched concurrently, one fresh session per issue. Say so explicitly: "N issues, all independent, all startable now."
2. **Ready for you (HITL)** — what to pick up by hand while the agents run. Sort by leverage (issues-unblocked) descending, and name the count next to each: "resolves → unblocks 3 more."
3. **Blocked** — each with its still-open blocker(s) named.
4. **In progress** — already claimed, and by whom.
5. **Done** — closed issues, for orientation only; keep this one short (count + list of titles is enough, skip the detail columns).
6. **Unclassified**, if any — flag, don't sort into a bucket.

One small table per section (`# | Title | Blocked by / Unblocks | Assignee` — drop whichever columns are empty across the whole section) reads more clearly here than one big table with a Status column, because the sections themselves carry the status.

### 5. Re-align (only when a spec/map number was given)

Sanity-check the parent against its children, and say what you find even when nothing's wrong:

- The parent is closed but children are still open, or vice versa.
- A child references a parent that doesn't match the one given.
- For a wayfinder map: the map's **Destination** no longer matches what the open children are actually working toward.

### 6. Stop

Report the table and any re-align findings. Take no further action — no labeling, claiming, closing, or ticket drafting. If something in the report calls for action, say what and let the user decide.
