---
name: setup-scott-carlson-skills
description: Configure this machine for Scott Carlson's skills — verify the Matt Pocock skills they depend on are installed, install the subagent definitions they dispatch to, add the standing context policy to CLAUDE.md, and keep ticket payloads out of git. Run once after installing the skills.
disable-model-invocation: true
---

# Setup Scott Carlson's Skills

*Why this skill exists, the failure it prevents, and when not to use it: [WHY.md](./WHY.md).*

These skills are **connective tissue around Matt Pocock's engineering skills** — they fill the gaps
at the front of the delivery pipeline, the middle, and the back. Installed alone they dead-end at
the first handoff. This skill closes that gap, plus the three other things the installer cannot do
for you.

Prompt-driven, not a script. **Explore first, present what you found, confirm, then write.** Never
write to a file the user hasn't seen a draft of.

## 1. Explore

Find everything yourself. Do not ask the user for anything discoverable.

**Which of Matt's skills are installed.** Check the filesystem, not your own skill list —
`to-spec`, `to-tickets`, `wayfinder`, and `implement` are user-invoked, so they are hidden from the
skill list even when correctly installed. Looking for them there will tell you they're missing when
they aren't.

```bash
ls ~/.agents/skills/ 2>/dev/null; ls ~/.claude/skills/ 2>/dev/null
```

Required, and what needs each one:

| Skill | Needed by | How it's used |
| --- | --- | --- |
| `grilling` | `grill-for-refinement` | Called directly via the Skill tool. Hard dependency. |
| `grill-with-docs` | `jira-intake` | Named as the next command after intake — the common case. |
| `wayfinder` | `jira-intake` | Named as the alternative when the work won't fit one session. |
| `to-spec`, `to-tickets` | `jira-intake` | The planning steps intake hands off to. |
| `implement` | `pre-implement` | The command `pre-implement` tells you to run next. |
| `code-review` | the pipeline | Closes each slice. |

**Other prerequisites.** Check what's actually present rather than assuming:

| Prerequisite | Needed by | Check |
| --- | --- | --- |
| Atlassian (Rovo) MCP | `jira-intake`, `grill-for-refinement`; optional for the PR skills | Is `getJiraIssue` among your tools? |
| Figma MCP | `jira-intake` design context; `pr-description` screenshots | Is `get_design_context` among your tools? |
| `gh` CLI, authenticated | `pre-implement`, `pr-description`, `pr-review` | `gh auth status` |
| Codex | `pr-review`'s peer-review step | Is a Codex integration available? |
| A Fable-capable plan | `exhaustive-reasoner` as shipped | See section C. |

**Local state.** `~/.claude/agents/` — which definitions already exist. `~/.claude/CLAUDE.md` — does
it exist, and does it already carry this skill's policy block. The current repo's `.gitignore`.

## 2. Present, then take the sections in order

Summarise what's present and what's missing in a few lines. Then work the sections below one at a
time, leading each with the recommended answer so the user can accept it in a word. Skip any section
exploration already settled.

### Section A — Missing skills from `mattpocock/skills`

You cannot install these yourself: no skill can reliably install skills into the harness running it.
Print the command and let the user run it.

```bash
npx skills@latest add mattpocock/skills
```

The interactive picker is the reliable route — select the missing skills from the list. There is a
`--skill <name>` flag for non-interactive use, but it has been observed being ignored in some
versions, which turns a targeted install into a full one. If the user wants the non-interactive
form, tell them to check what the picker reports before confirming.

Nothing else in this setup depends on the outcome, so continue through the remaining sections either
way — just be clear that the pipeline has a hole until this is done.

### Section B — Prerequisites

Present the matrix from step 1 with what you actually found. For anything missing, say plainly which
skills stop working and which degrade:

- **No Atlassian MCP** → `jira-intake` and `grill-for-refinement` cannot run at all.
- **No Figma MCP** → `jira-intake` skips design context; `pr-description` skips Figma screenshots.
  Both still work.
- **No `gh`** → the two PR skills cannot run; `pre-implement` cannot read the issue.
- **No Codex** → `pr-review` loses its peer-review step. Say so and continue; don't silently skip it.

This section installs nothing. It is a report, and the user decides what to fix.

### Section C — Subagent definitions

`jira-intake` dispatches to `exhaustive-reasoner` for Figma and image reading. The other three are
what the standing policy in Section D refers to; without them that policy names a roster the reader
doesn't have.

Copy from this skill's `assets/agents/` to `~/.claude/agents/`:

- `exhaustive-reasoner.md` — long-context and visual work (`model: fable`)
- `deep-reasoner.md` — an independent second opinion on hard problems (`model: opus`)
- `fast-worker.md` — well-specified implementation (`model: sonnet`)
- `micro-worker.md` — one-line edits and lookups (`model: haiku`)

**Never overwrite an existing definition.** If a file already exists, report it and leave it alone.

**The Fable check.** `exhaustive-reasoner` ships as `model: fable`. If Fable isn't available on this
plan, the agent is worse than absent — it's broken, and the failure surfaces mid-dispatch. Ask, and
on confirmation write it with `model: opus` instead. Note in your summary that you changed it.

Recommended scope is **global** (`~/.claude/agents/`), because the pipeline is used across repos.

### Section D — The standing policy

The single highest-value thing that isn't a skill. The pipeline assumes a context discipline that
lives in `CLAUDE.md`, deliberately, so that `implement` and every other skill pick it up for free.
Install only the skills and you get the mechanics without the reasoning that makes them work.

The block is `assets/claude-md-policy.md`. Wrap it in markers so it can be updated later without
touching anything around it:

```markdown
<!-- scott-carlson-skills:policy -->
...contents of assets/claude-md-policy.md...
<!-- /scott-carlson-skills:policy -->
```

Rules:

- **Show the full diff and wait for an explicit yes.** This edits a file the user owns and did not
  ask you to rewrite.
- Say out loud that the target is **global** `~/.claude/CLAUDE.md` before writing.
- If the markers already exist, replace what's between them. Never append a second copy.
- Never edit a section of `CLAUDE.md` you didn't author.
- If the user already has their own context-window policy, don't fight it — show them the block and
  let them merge by hand.

### Section E — Keep ticket payloads out of git

`jira-intake` writes raw ticket exports, design notes, image notes, and transcripts to
`.ig.jira-tickets/` at the repo root. That's the point: payload on disk, digest in context. But it
must never be committed.

Append to the **current repo's** `.gitignore` if not already covered:

```gitignore
# Agent session payloads — raw context, never repository content
.ig.*
```

This is the one per-repo change in this skill. Everything else is global.

## 3. Finish

Report what you wrote, what you skipped and why, and anything the user still has to do themselves.

Then tell them:

> Run `/setup-matt-pocock-skills` next — it configures this repo's issue tracker, triage labels, and
> domain doc layout, which the planning and implementation skills read.

You cannot run it for them. It is user-invoked, and a user-invoked skill can never be called by
another skill.
