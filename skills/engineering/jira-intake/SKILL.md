---
name: jira-intake
description: Entry point for starting work on a new story, task, bug, or spike. Fans out one subagent per context source (JIRA ticket, Figma, images, notes) so raw payloads land on disk instead of in the main context window, then folds back a short brief and hands you the next command. Invoke with a JIRA ticket id, e.g. `/jira-intake ABC-123`.
disable-model-invocation: true
---

# JIRA Intake

*Why this skill exists, the failure it prevents, and when not to use it: [WHY.md](./WHY.md).*

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

### 2b. Recommend renaming this session — without pausing

Print the exact command, with the real ticket id substituted, so I can copy and paste it whenever I like:

```
/rename ABC-123 [INTAKE]
```

Use the upper-cased ticket id resolved in step 1 in place of `ABC-123`. This is a recommendation only: **do not stop, wait, or ask for confirmation** — go straight on to step 3 in the same turn. The point is that this session is identifiable, not that intake is gated on it.

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

### 5. Ask three questions: planning path, run mode, and continue-or-handoff

Before doing anything else, ask all three together, leading each with your recommendation so I can accept it in a word.

**Planning path** — does this need a planning session, and which kind? Recommend one from the brief, with a one-line why:

> **Grilling** (`/grill-with-docs`), **wayfinder** (`/wayfinder`), or **neither** (straight to `/pre-implement` → `/implement`)?

- **Grilling** — one coherent feature, bug, or spike that a single relentless interview can sharpen. **This is the common case; recommend it unless the ticket genuinely resists it.**
- **Wayfinder** — too big to hold in one session, or carrying enough unknowns that it needs a map of decision tickets resolved one at a time.
- **Neither** — small, already-unambiguous work (a contained bug, a copy change) where an interview would only restate the ticket. No planning session, no planning protocol, no model switch. `/pre-implement` sizes one GitHub issue, so if none exists for this work yet, `/to-tickets` cuts a single one first — and GNHF always needs `/to-tickets`.

Grilling or wayfinder brings in [the planning protocol](#the-planning-protocol).

**Run mode** — how will the tickets be worked once planning is done?

> Will this be a **manual** run (you drive `/pre-implement` → `/implement` → `/code-review` per slice) or a **GNHF** run (`/good-night-have-fun` works the tickets overnight, AFK)?

Manual is the default if I don't say. **GNHF** adds the AFK planning requirements below to whichever handoff I pick.

**Session** —

> Continue in this session (`/compact` then carry on here), or create a **handoff document** for a completely fresh session?

- **Continue here** → go to step 6a.
- **Handoff document** → go to step 6b.

### The GNHF planning requirements

Only when I chose **GNHF**. Nobody will be at the keyboard between the first ticket and the morning, so `/to-spec` and `/to-tickets` must be built to do as much as can **safely** be done without a human in the loop, leaving me a PR and a summary rather than a queue of questions:

- **Resolve open decisions during planning.** Anything left open, a ticket's agent will decide alone. Where a decision can't be settled, the ticket states its recommended answer.
- **Tickets must be agent-completable**: acceptance criteria verifiable by the repo's gate, seams and test targets named, no "decide X" or "confirm with Y" inside the ticket body.
- **Every ticket carries a `## Parent` section naming the spec and a `## Blocked by` section** (`- #<n>` lines, or an explicit "none"). Keep blocking edges honest and few so work runs in parallel and one failure prunes little.
- **Put human-only work in its own ticket**, labelled `needs-human` and **not** `ready-for-agent` — third-party admin UIs, manual asset uploads, production-data checks, anything needing a judgment call the spec can't make. Minimise what depends on it.
- **Check the target repo's `AGENTS.md`/`CLAUDE.md` has an `## Agent verification gate` block** (`run:`, `skip:`, optionally `install:`). If it doesn't, say so now — otherwise the run is ungated and every ticket ships stamped `⚠️ UNVERIFIED`.
- **ADRs written before the reset**, as always — nobody is awake to re-argue a rejected option.
- **Leave planning's doc changes uncommitted.** ADRs, `CONTEXT.md`, `AGENTS.md`/`CLAUDE.md`, README and any other doc that grilling touches stay in the working tree: **do not commit or push them, and above all not to the base branch**. The work isn't implemented yet and the decisions can still change. `/good-night-have-fun` picks them up and commits them as the first commit on its integration branch, so they ship in the same PR as the code they describe. (Code changes must not be left uncommitted — that still fails preflight.)

The run itself is `/good-night-have-fun "GitHub issue #<spec>"` after `/to-tickets` and a `/clear`; I must stay for its preflight. Name that as the next step once `/to-tickets` is done.

### The planning protocol

Only when the planning path is **grilling** or **wayfinder** (not when neither is needed). It exists because one planner has one set of blind spots, and because a planning session that reads its own sources fills its window and drifts into the dumb zone long before it finishes. Write it in full to `PLANNING-PROTOCOL.md` in the ticket directory (first line: `path: grilling` or `path: wayfinder`) — a `/compact` summary is lossy, and wayfinder ticket sessions start fresh, so this file is how the protocol reaches them.

**Is Gemini available?** Check once, here, and record the answer in `PLANNING-PROTOCOL.md`:

```
command -v agy && agy models | grep -E '^gemini-4-(neon|carbon)-high'
```

The planning session re-checks before its first wave. If Gemini isn't available, the independent-planner section below doesn't apply — say so once and plan as before, single-planner; everything else in the protocol still holds.

**1. Independent planners, every wave.** The orchestrating session is planner A. Gemini is planner B:

| Path | Planner A (orchestrator) | Planner B (Gemini via `agy`) |
| --- | --- | --- |
| Grilling | Opus, `high` or `xhigh` | Gemini 4 Neon, high thinking — `--model gemini-4-neon-high` |
| Wayfinder | Fable | Gemini 4 Carbon, high thinking — `--model gemini-4-carbon-high` (Carbon's top tier; it has no `xhigh`) |

For **each wave** — each round of questions, recommendations, or decisions put to me:

- Write a self-contained **wave brief** to the ticket directory: the decisions so far, the relevant digests, and what this wave must settle. Not your own leanings.
- Form planner A's position **before** reading planner B's.
- Run planner B blind, headless, and read-only, with the brief inline, in a fresh call per wave (no `--conversation`, so it doesn't rot either):

  ```
  agy -p "$(cat <wave-brief>)" --model <planner-b-model> --mode plan --output-format json
  ```

  Open the brief with "Everything you need is in this prompt; do not run commands or read files." — in `--mode plan` its shell is denied, and pointing it at a file instead of inlining makes it stop without answering. Read the `response` field. Never pass `--dangerously-skip-permissions`. On error, one retry; then carry on single-planner for that wave and say so.
- **Compare, then ask me.** Where they agree, recommend with that confidence. Where they differ, show me both positions and which one you recommend and why — settled on the merits, not by which model said it. A question or option only one planner raised still gets asked if it earns it.

**Codex as third reviewer or tie-breaker** (`codex:codex-rescue`), when the orchestrator judges it necessary — not every wave. Reach for it when the planners split on a consequential or hard-to-reverse decision, or agree so readily you suspect a shared blind spot. For an independent third view, give it the same wave brief blind; to adjudicate a split, give it the brief plus both positions. You still decide what to recommend.

**2. Subagents, as much as possible.** The main window holds digests and decisions, nothing else; treat ~100K tokens as the ceiling. Code sweeps, doc and ADR reads, issue bodies, research, prototypes and the intake digests go to subagents that write payloads to disk and return short digests — each prompt opening by telling the subagent to invoke the `terse` skill. If the window is filling anyway, write state to disk and reset rather than push on.

**3. Wayfinder structure** (wayfinder only). Shape the map the way it has worked before:

- **One `wayfinder:map` issue**, every planning ticket a **native sub-issue** of it, and blocking edges as **native blocked-by links**. Labels `wayfinder:map`, `wayfinder:grilling` (HITL), `wayfinder:research` (AFK), `wayfinder:prototype` (HITL), `wayfinder:task` — give each a description saying what it's for.
- **Map body:** `## Destination` / `## Notes` / `## Decisions so far` (one line per closed ticket: `[title](link): gist`) / `## Not yet specified` / `## Out of scope`. In `## Notes`, carry the terms used, the decisions settled before charting ("do not reopen these on a ticket"), and a **"How every ticket is worked"** section restating this protocol — the ticket directory is local-only, the map is what every ticket session reads.
- **Ticket body:** `## Question` / `## What we already know` (each bullet ending with its source) / `## Done when` (a `- [ ]` checklist whose last item is the resolution comment). Don't edit planner positions or my rulings into the body afterwards — they go in the resolution comment, or body and comments end up disagreeing.
- **One ticket, one session.** Work each ticket in its own fresh, narrowly scoped session; the granularity is what keeps each one out of the dumb zone. A **tie-together grilling ticket**, blocked by the decision tickets it depends on, synthesises their answers into the waves or follow-on maps.
- **Waves:** a wave is one `/to-spec` → `/to-tickets` round turning part of the map into build tickets. Make every wave's spec a **native sub-issue of the map** too, so the map's progress counter tells the truth, and give its build tickets `## Parent` naming the spec and the map.
- **Record a scope change once** — on the map's `## Decisions so far` — and link to it elsewhere, rather than restating it on three tickets. Refer to tickets by linked title. If a ticket cites an ADR that isn't pushed yet, say so.
- **Close the map** when its destination is met, and close or update date-bound tickets once their date passes.

**4. Closing a ticketed wayfinder session.** Before a ticket's session ends:

1. **Post a resolution comment on its own issue:** `## Resolution` (one-paragraph gist), who decided and when, `### Answer` (numbered), `### Where the planners differed` (if both ran), `### Records` (ADRs, docs, commits — say if not yet pushed), `### Passed on` (tickets created, input for other tickets, anything not verified).
2. **Update related tickets.** Comment on every open ticket this one answers, unblocks, or changes the context of — "Input from [title](link), now closed:" plus only what that ticket needs. Relevant information, not a broadcast.
3. **Add the gist line** to the map's `## Decisions so far`.
4. **Close its own issue** (`gh issue close <n> --reason completed`).

### 6a. Hand off — same session, all five reminders every time

End with exactly these, in order:

1. **`/compact` now.** Required, not optional. Intake's job is done and everything of substance is on disk; planning must start in a clean window. Do not let me walk into grilling on top of intake's leftovers.
2. **The next command**, for the planning path I chose in step 5: `/grill-with-docs`, `/wayfinder`, or — for neither — `/pre-implement <issue>` (after `/to-tickets` if there's no issue yet), then `/implement`.
3. **Which model to plan on** (skip for neither — `/pre-implement` makes the model call) — planning rewards reasoning effort because it works on under-determined problems. (Implementation later does not; `/pre-implement` handles that call.)
   - **Grilling** → Opus at `high` or `xhigh` is fine.
   - **Wayfinder** → **Fable** — it's the long-horizon, long-context session that has to hold a map together across many tickets.
4. **Standing reminders for that planning session**, carried forward because nothing downstream restates them:
   - **Write any missing ADRs before the next reset.** An ADR's value is the argument — the option rejected and why — and that's exactly what a reset destroys. Check `docs/adr/` on the filesystem for what already exists; write what's missing, matching the existing format.
   - **Keep the interview on the code and the acceptance criteria** — not commit hygiene, review process, or other delivery mechanics. Those belong to later skills.
   - **Don't produce logic code during planning.** That's `implement`'s job, after `to-tickets` has sliced the work.
   - **If grilling or wayfinder:** write [the planning protocol](#the-planning-protocol) to `PLANNING-PROTOCOL.md` and tell me to have the planning session read it before its first wave. Say whether Gemini is available and, if so, which planner B the session will run.
   - **If GNHF:** restate [the GNHF planning requirements](#the-gnhf-planning-requirements) in full, and **also write them to `RUN-MODE.md`** in the ticket directory (first line: `mode: gnhf`), because a `/compact` summary is lossy and this is the one reminder that must reach `/to-spec` and `/to-tickets` intact. Tell me to have the planning session read it.
5. **Rename this session** — it is about to carry both phases. Print the command with the real ticket id substituted so I can copy and paste it (`WAYFINDER` instead of `GRILLING` for a wayfinder session, `PLANNING` if neither):

   ```
   /rename ABC-123 [INTAKE + GRILLING]
   ```

Then stop. Do not begin planning here.

### 6b. Hand off — fresh-session handoff document

Write a detailed `HANDOFF.md` into the ticket directory (`.ig.jira-tickets/<id>-<slug>/` — never `/tmp` or any other scratch location; it must survive and be discoverable by a future session). Include:

- The brief from step 4 in full, not summarized further.
- The free-text framing from the initiating prompt, called out explicitly.
- The planning path I chose in step 5 and why — grilling, wayfinder, or neither — with the next command and the model to plan on (6a.2–6a.3).
- If grilling or wayfinder: a pointer to `PLANNING-PROTOCOL.md` (write it, per [the planning protocol](#the-planning-protocol)), whether Gemini is available, and which planner B the session will run.
- Pointers to every digest on disk (`TICKET.md`, `FIGMA-NOTES.md`, `IMAGE-NOTES.md`, `NOTES-DIGEST.md`, `INITIAL-PROMPT.md`) — whichever exist — so the fresh session pulls detail on demand instead of re-fetching.
- Open questions and gaps flagged during intake.
- The same standing reminders as 6a.4 (ADRs, keep the interview on code/AC, don't produce logic code during planning), since nothing downstream restates them.
- **Run mode: manual or GNHF.** If GNHF, include the [GNHF planning requirements](#the-gnhf-planning-requirements) in full, as a section the fresh session cannot miss, and state that `/to-spec` and `/to-tickets` must honour them. That includes the rule that doc changes from grilling are left uncommitted for GNHF to commit, never pushed to the base branch.

Then give me a **ready-to-paste prompt for the new session**. It must:

- Point at the handoff document's path and tell the new session to read it first.
- Name the next command (`/grill-with-docs`, `/wayfinder`, or for neither `/pre-implement` — after `/to-tickets` if there's no issue yet) and the ticket id, and say which model to open the new session on (Opus at `high`/`xhigh` for grilling, Fable for wayfinder).
- If grilling or wayfinder: tell the new session to read `PLANNING-PROTOCOL.md` before its first wave, and to follow it — independent planners per wave, Codex when it judges a third view necessary, subagents for every bulk read, and (wayfinder) the map structure and close-out steps.
- State the run mode. If GNHF, say the planning must be AFK-ready, that doc changes from grilling stay uncommitted (no commit or push to the base branch), and point at the handoff's GNHF section.
- Surface any additional context, nuance, or clarification from *this* conversation that didn't make it into `HANDOFF.md` or the digests — anything said in passing, any ambiguity I should resolve up front, anything the new session would otherwise have to ask me to repeat.

Finally, remind me to rename the **new** session once it opens, and print the command with the real ticket id substituted so I can copy and paste it (`WAYFINDER` instead of `GRILLING` for a wayfinder session, `PLANNING` if neither):

```
/rename ABC-123 [GRILLING]
```

This session keeps its `[INTAKE]` name — the planning happens elsewhere.

Then stop. Do not begin planning here, and do not `/compact` — this session's job ends with the handoff document and the prompt.
