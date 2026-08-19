---
name: jira-intake
description: Entry point for starting work on a new story, task, bug, or spike. Fans out one subagent per context source (JIRA ticket, Figma, images, notes) so raw payloads land on disk instead of in the main context window, then folds back a short brief and hands you the next command. Invoke with a JIRA ticket id, e.g. `/jira-intake ABC-123`.
disable-model-invocation: true
---

# JIRA Intake

Gather everything known about a JIRA ticket into a **short brief**, while the bulk — ticket export, Figma frames, screenshots, transcripts — stays on disk. This skill gathers and hands off. It does not plan, spec, or write code.

The argument is a ticket id (e.g. `ABC-123`), optionally followed by **free-text framing** — often the sharpest steer for the whole effort. Treat the whole invoking message as the initiating prompt and give that framing first-class weight against the exported ticket.

## The hard rule

**Raw source material must never enter your context.** You read digests, not sources. Concretely: you do not call `getJiraIssue`, `get_design_context`, or `get_screenshot` yourself, and you do not `Read` an image or a transcript. A subagent does that, writes the full payload to the ticket directory, and returns a digest. Breaking this rule is the single biggest cause of intake blowing past the ~100K smart-zone line.

## Process

### 0. Check reasoning effort

Gathering, not deep reasoning — **medium** is right. If the active effort is not medium, say what it is and **wait for my confirmation** before continuing.

### 1. Resolve the ticket id and directory

The id is the token shaped like `ABC-123`. Use the upper-cased form for lookups, lower-cased for the directory. Look under `.ig.jira-tickets/` at the repo root for a child directory starting with `<id>-`:

- **One match** → that's it. **Several** → list them, ask. **None** → create `.ig.jira-tickets/<id>-<short-slug>/`.
- **No id given** → list the child directories and ask which ticket. With no id and no context, skip to step 4.

### 2. Save the initiating prompt

Write the full invoking message **verbatim** to `INITIAL-PROMPT.md` in the ticket directory. It exists to survive the `/compact` that follows this skill. If it already exists with materially different content, confirm before overwriting.

### 3. Fan out — one subagent per source, in parallel

Launch these in a **single message** so they run concurrently. Skip any whose source doesn't exist. Every prompt opens with: *"Invoke the `terse` skill. Report a digest of at most 10 lines — no preamble, no restatement of the task."*

| Subagent | Source | Writes to disk | Returns |
| --- | --- | --- | --- |
| `general-purpose` | **Ticket** — Atlassian (Rovo) MCP: `getJiraIssue`, plus `getAccessibleAtlassianResources` for the `cloudId` and `getJiraIssueRemoteIssueLinks` for attachments/remote links | `TICKET.md` (metadata, description, all comments, links — overwrite any existing cache; the live ticket wins) | What's being asked, constraints and decisions buried in comments, every `figma.com` or doc URL found, and **which source it used** — live MCP, or the cached `TICKET.md`/`JIRA-TICKET.md` fallback if the MCP was unreachable |
| `exhaustive-reasoner` | **Figma** — for each `figma.com` link, `get_design_context` / `get_screenshot` / `get_metadata` | `FIGMA-NOTES.md` | What the design actually specifies: layout, states, breakpoints, tokens, and anything that contradicts the ticket text |
| `exhaustive-reasoner` | **Images** — before/after screenshots and mockups in the directory | `IMAGE-NOTES.md` | What each image shows and what it implies for implementation |
| `general-purpose` | **Notes** — Slack exports, Meet transcripts, other markdown/text in the directory | `NOTES-DIGEST.md` | Decisions already made, constraints stated, open threads |

`exhaustive-reasoner` is a locally defined subagent, not a built-in — `/setup-scott-carlson-skills` installs it. If it isn't available on this machine, use `general-purpose` for those two rows instead; the digests come back thinner but nothing breaks.

The Figma link list comes from the ticket subagent, so the Figma subagent may need a second round once that returns — launch it then rather than guessing at links. Only use Figma's *writing* tools (or `/figma-use`) if the ticket actually asks you to push design back into Figma.

If a subagent reports its source was unavailable, say so plainly and carry on with what you have — flag any gap so planning accounts for it.

### 4. Brief

Produce a **concise context brief** (aim for under 30 lines) from the digests: what the ticket asks for, key constraints, what the design implies, open questions. Weave my **free-text framing** in as a primary input and **reconcile it against the export** — where it narrows scope, names patterns to reuse, or contradicts the ticket, call that out explicitly so planning targets the real intent.

Note where the detail lives (`TICKET.md`, `FIGMA-NOTES.md`, …) so any later session can pull it on demand instead of re-fetching.

### 5. Hand off — all three reminders, every time

End with exactly these, in order:

1. **`/compact` now.** Required, not optional. Intake's job is done and everything of substance is on disk; planning must start in a clean window. Do not let me walk into grilling on top of intake's leftovers.
2. **Switch to Opus at `high` or `xhigh` effort** for planning — grilling, `/to-spec`, and `/to-tickets` all reward reasoning effort, because they work on under-determined problems. (Implementation later does not; `/pre-implement` handles that call.)
3. **Which planning skill**, with a one-line why:
   - **`/grill-with-docs`** — one coherent feature, bug, or spike that a single relentless interview can sharpen. **This is the common case; recommend it unless the ticket genuinely resists it.**
   - **`/wayfinder`** — too big to hold in one session, or carrying enough unknowns that it needs a map of decision tickets resolved one at a time.

Then stop. Do not begin planning here.
