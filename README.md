# 🛠️ Scott Carlson's Skills

Ten Claude Code skills for getting real work through a delivery pipeline — by hand or overnight —
without wrecking the context window on the way.

They're **connective tissue around [Matt Pocock's skills](https://github.com/mattpocock/skills)**,
not a replacement. They fill the gaps at the front (cheap real-world context), the middle (rationale
captured before a reset destroys it), the back (PR hygiene), and the overnight run. His skills do
the planning and the building. **Install his first.**

---

## 🧠 The premise

A model's *usable* intelligence degrades well before its context window fills — roughly past the
first **~100K tokens**. You still get answers; they're just worse. Two rules fall out, and they're
the design DNA of every skill here:

1. **Raw material never enters the main window.** Ticket exports, Figma frames, screenshots, diffs —
   a subagent reads them, writes the payload to disk, and returns a short digest.
2. **Reset aggressively, and know which reset.** `/compact` keeps a lossy summary (continuity).
   `/clear` keeps nothing (the next step reads from disk).

If that sounds like overkill, you haven't hit the wall yet. Every prohibition in these skills exists
because the polite version got rationalised away in the moment.

## 🚦 The pipeline

Intake, planning, and ticketing are the same either way. **You pick how the tickets get worked** —
`/jira-intake` asks up front, because an overnight run changes how planning has to be done.

```
/jira-intake ABC-123 "framing"        ← here.   Asks: manual run, or GNHF?
        │   parallel subagents — ticket / Figma / images / notes → disk
        │   a <30-line brief comes back
        ▼
/compact                               the pipeline's only compact
        │   ↳ switch to Opus at high/xhigh
        ▼
/grill-with-docs   or   /wayfinder    ← mattpocock/skills.  Planning.
        ▼
/to-spec  →  /to-tickets              ← mattpocock/skills.  Tracer-bullet slices.
        │   write any missing ADRs now, before the reset
        │   GNHF run? Tickets must be finishable with no human in the loop.
        ▼
/clear
        │
   ┌────┴─────── PATH A · manual ────────┐   ┌──────── PATH B · overnight ────────┐
   │ per unblocked slice:                │   │ /good-night-have-fun               │
   │  /where-am-i      which slice?      │   │     "GitHub issue #<spec>"         │
   │  /pre-implement N model + effort    │   │                                    │
   │  /clear                             │   │  preflight (you're awake) → walk   │
   │  /implement N     ← mattpocock      │   │  away → waves of ≤3 tickets in     │
   │  /clear                             │   │  worktrees → gate → merge → one PR │
   │  /code-review     ← mattpocock      │   │                                    │
   └─────────────────────────────────────┘   │  morning: read SUMMARY.md          │
                                             └────────────────────────────────────┘
        ▼
/pr-description   and/or   /pr-review  ← here.   Post-PR.
```

### 🌙 Path B in a nutshell

`/good-night-have-fun` takes a spec issue and does Path A's per-slice loop for you, concurrently:

- **Preflight while you're awake.** Auth, clean tree, dependency graph, verification gate, baseline
  failures, triage. Anything that can fail, fails *here* — not at 3am.
- **Then it runs alone.** Unblocked tickets go to subagents in git worktrees, each gated against the
  baseline and code-reviewed, merged one at a time. Two failures on a ticket means revert and move on.
- **You get a PR and a summary.** `SUMMARY.md` leads with **Needs you**, then **Failed**, then
  **Decisions made autonomously** — audit those before trusting the PR.

It only works if planning was done for it: tickets need `## Parent` and `## Blocked by` sections,
human-only work isolated as `needs-human` tickets, and a verification gate in the repo's `AGENTS.md`
or `CLAUDE.md`. Choose GNHF at intake and `jira-intake` carries those rules into `/to-spec` and
`/to-tickets` for you. Failed and `needs-human` tickets fall back to Path A.

### 🧩 No conductor skill — on purpose

A wrapper holding the whole pipeline in context was built and retired: standing policy belongs in
`CLAUDE.md`, and paying tokens each invocation to restate something always true is the anti-pattern
this repo is about. Instead, **every skill ends by naming the next command and the reset before it.**

`grill-for-refinement` sits outside the flow — it sharpens a ticket *before* it's ready for intake.

## 📦 Install

```bash
npx skills@latest add scottcarlson/skills
```

Pick skills and agents from the prompts, then run once:

```
/setup-scott-carlson-skills
```

**Not optional.** It verifies Matt Pocock's skills are installed, installs the subagents
`jira-intake` dispatches to, adds the standing context policy to your `CLAUDE.md` (diff shown first),
and keeps ticket payloads out of git. Skip it and the pipeline dead-ends at its first handoff,
mid-session, after you've spent the context.

> The `skills` CLI is [`vercel-labs/skills`](https://github.com/vercel-labs/skills). This repo
> publishes nothing to npm and ships no installer of its own.

## ✅ Prerequisites

| Prerequisite | Required by | Without it |
| --- | --- | --- |
| [`mattpocock/skills`](https://github.com/mattpocock/skills) | everything | `grill-for-refinement` breaks; pipeline dead-ends at planning and implementation |
| Atlassian (Rovo) MCP | `jira-intake`, `grill-for-refinement` | those two can't run |
| Figma MCP | `jira-intake`, `pr-description` | design context skipped; both still work |
| `gh` CLI, authenticated | `where-am-i`, `pre-implement`, `good-night-have-fun`, `pr-description`, `pr-review` | those can't run |
| Codex | `pr-review` | loses its peer-review step |
| A Fable-capable plan | `exhaustive-reasoner` as shipped | setup offers to rewrite it to Opus |

`terse` and `im-dumb` need nothing.

## 🧰 The skills

Each `SKILL.md` is the operational spec; each `WHY.md` is the reasoning — the failure it prevents and
when *not* to use it. Read the `WHY.md` first if you're deciding whether you want a skill at all.

| Skill | What it's for | |
| --- | --- | --- |
| 🎫 **`jira-intake`** | Entry point. Fans out one subagent per context source, asks manual vs GNHF, and hands you the next command — including the reminder to write ADRs *before* a reset destroys them. | [why](./skills/engineering/jira-intake/WHY.md) |
| 🌙 **`good-night-have-fun`** | Overnight orchestrator. Works a spec's `ready-for-agent` tickets in parallel worktrees, reverts what it can't land, leaves a PR and a summary. | [why](./skills/engineering/good-night-have-fun/WHY.md) |
| 🗺️ **`where-am-i`** | Maps issues into done / blocked / ready-for-agent / ready-for-you, so you know what to run concurrently. Read-only. | [why](./skills/engineering/where-am-i/WHY.md) |
| 📏 **`pre-implement`** | Names the model and effort for one slice, from that slice alone. If it can't be sized from its own text, that's the finding. | [why](./skills/engineering/pre-implement/WHY.md) |
| 🔍 **`grill-for-refinement`** | Sharpens one ticket to refinement-ready. Drafts a comment; posts on your confirmation. | [why](./skills/engineering/grill-for-refinement/WHY.md) |
| 📝 **`pr-description`** | Writes or rewrites a scannable description for an existing PR. | [why](./skills/engineering/pr-description/WHY.md) |
| 👀 **`pr-review`** | Reviews a PR, folds in Copilot's findings, has Codex peer-review them, then opens a follow-up PR with fixes. | [why](./skills/engineering/pr-review/WHY.md) |
| ✂️ **`terse`** | Low-token mode. Looks like a style preference; it's the load-bearing context primitive for the rest. | [why](./skills/productivity/terse/WHY.md) |
| 🧸 **`im-dumb`** | Re-explains the last response (or a follow-up) in plain, friendly language. | [why](./skills/productivity/im-dumb/WHY.md) |
| ⚙️ **`setup-scott-carlson-skills`** | Run once. Checks prerequisites, installs subagents, adds the standing policy. | [why](./skills/engineering/setup-scott-carlson-skills/WHY.md) |

Three through-lines:

- **Team-visible actions are drafted first.** Ticket comments, PRs, and PR edits show full text and wait.
- **Digest in, payload on disk.** `jira-intake` is the reference implementation of rule 1.
- **The skill tells you the next command**, including which reset comes first.

## 🔄 Updating

```bash
npx skills@latest update
```

Run it periodically. **Nothing notifies you** when this repo changes — the trade made in [ADR-0001](./docs/adr/0001-npx-only-distribution.md) by choosing this channel over a Claude Code plugin.

> ### ⚠️ Don't edit installed skills
>
> Fork this repo instead. The CLI compares the *upstream* hash to the hash recorded at install time
> and never inspects your installed files, so local edits are neither preserved nor repaired:
>
> - Upstream **changed** → your edits are overwritten, no prompt.
> - Upstream **unchanged** → the skill is skipped and your edit quietly diverges forever.
>
> "Just run update to get back in sync" is false — ADR-0001 has a worked example.

## 🤝 Contributing

[`CLAUDE.md`](./CLAUDE.md) has the authoring conventions, [`CONTEXT.md`](./CONTEXT.md) the vocabulary,
and [`docs/adr/`](./docs/adr/) the reasoning behind the repo's shape.

```bash
node scripts/validate-skills.mjs   # run before committing
./scripts/sync-skills.sh          # copy skills into ~/.agents and link them for authoring
```

## 🙏 Credit

The pipeline these skills plug into, the grilling and spec-and-tickets flow, and most of the thinking
about where a context window actually fails, are [Matt Pocock's](https://www.aihero.dev/skills). This
repo is the connective tissue, not the machine.

## 📄 License

MIT
