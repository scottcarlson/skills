# Scott Carlson's Skills

Eight Claude Code skills for getting real work through a delivery pipeline without wrecking the
context window on the way.

They are **connective tissue around [Matt Pocock's skills](https://github.com/mattpocock/skills)**,
not a replacement for them — they fill the gaps at the front (getting real-world context in cheaply),
the middle (capturing rationale before a reset destroys it), and the back (PR hygiene). His skills do
the planning and the building. **Install his first.**

---

## The premise everything here is built on

A model's *usable* intelligence degrades well before its context window fills. On a large-window
model, the smart zone is roughly the first **~100K tokens**. Past that you still get answers — they're
just worse. The million-token window didn't fix this; it shipped a lot more room to be bad in.

Two rules fall out, and they are the design DNA of every skill in this repo:

**1. Raw material never enters the main window.** Ticket exports, Figma frames, screenshots,
transcripts, long diffs — a subagent reads them, writes the payload to disk, and returns a short
digest. The digest is what the main session sees.

**2. Reset aggressively, and know which reset.** `/compact` keeps a lossy summary, so rationale
survives. `/clear` keeps nothing. Compact when the next step needs continuity; clear when the next
step reads from artifacts on disk.

If those two rules sound like overkill, that's the tell that you haven't hit the wall yet. Every
prohibition in these skills — and `jira-intake` in particular is written as a prohibition, not a
preference — exists because the polite version got rationalised away in the moment.

## The pipeline

```
/jira-intake ABC-123 "framing"        ← here.   Entry point for new work.
        │   fans out parallel subagents — ticket / Figma / images / notes
        │   payloads land on disk, a <30-line brief comes back
        ▼
/compact                               the pipeline's only compact
        │   ↳ switch to Opus at high/xhigh — planning is under-determined work
        ▼
/grill-with-docs   or   /wayfinder    ← mattpocock/skills.  Planning.
        ▼
/to-spec  →  /to-tickets              ← mattpocock/skills.  Tracer-bullet slices.
        │   write any missing ADRs now — jira-intake's handoff reminder, before the reset
        ▼
/clear
        │
   ┌────┴────────────────── per unblocked slice ───────────────────────┐
   │  /where-am-i [spec#]   ← here.   Which slice, and what's HITL.    │
   │  /pre-implement <N>    ← here.   Model + effort.                  │
   │  /clear                                                           │
   │  implement "GitHub issue #<N>"   ← mattpocock/skills.             │
   │  /clear                                                           │
   │  /code-review          ← mattpocock/skills.                       │
   └───────────────────────────────────────────────────────────────────┘
        ▼
/pr-description   and/or   /pr-review  ← here.   Post-PR.
```

**There is deliberately no conductor skill.** A wrapper holding the whole pipeline in context was
built and retired: standing policy belongs in `CLAUDE.md`, and paying tokens on every invocation to
restate something always true is the anti-pattern this repo is about. Instead, **every skill ends by
naming the next command and the reset that precedes it.** That's what makes a typed pipeline work
without anything orchestrating it.

`grill-for-refinement` sits outside this flow — it sharpens a ticket *before* it's ready for intake.

## Install

```bash
npx skills@latest add scottcarlson/skills
```

Pick the skills and agents from the interactive prompts. Then, once:

```
/setup-scott-carlson-skills
```

That step is not optional decoration. It verifies the Matt Pocock skills these depend on are actually
installed, installs the four subagent definitions `jira-intake` dispatches to, adds the standing
context policy to your `CLAUDE.md` (showing you the diff first), and stops ticket payloads from being
committed. Skip it and the pipeline dead-ends at its first handoff — silently, mid-session, after
you've already spent the context.

> The `skills` CLI is [`vercel-labs/skills`](https://github.com/vercel-labs/skills). This repo
> publishes nothing to npm and ships no installer of its own; it's a GitHub repository that CLI reads.

## Prerequisites

| Prerequisite | Required by | Without it |
| --- | --- | --- |
| [`mattpocock/skills`](https://github.com/mattpocock/skills) | all of it | `grill-for-refinement` breaks outright; the pipeline dead-ends at planning and at implementation |
| Atlassian (Rovo) MCP | `jira-intake`, `grill-for-refinement` | those two can't run |
| Figma MCP | `jira-intake`, `pr-description` | design context and Figma screenshots skipped; both still work |
| `gh` CLI, authenticated | `where-am-i`, `pre-implement`, `pr-description`, `pr-review` | those four can't run |
| Codex | `pr-review` | loses its peer-review step |
| A Fable-capable plan | `exhaustive-reasoner` as shipped | `/setup-scott-carlson-skills` offers to rewrite it to Opus |

`terse` needs nothing.

## The skills

Each skill's `SKILL.md` is its operational spec. Each `WHY.md` is the reasoning — the premise, the
failure it prevents, and when *not* to reach for it. Start with the `WHY.md` if you're deciding
whether you want the skill at all.

| Skill | What it's for | |
| --- | --- | --- |
| **`jira-intake`** | Entry point for new work. Fans out one subagent per context source so raw payload lands on disk instead of your context window, then hands you the next command — including the reminder to commit ADRs *before* a reset destroys the arguments behind them. | [why](./skills/engineering/jira-intake/WHY.md) |
| **`where-am-i`** | Maps this repo's issues into done / blocked / ready-for-agent / ready-for-you, so you know what to run concurrently and what HITL work to take while agents churn. Read-only. | [why](./skills/engineering/where-am-i/WHY.md) |
| **`pre-implement`** | Names the model and reasoning effort for one slice, from that slice alone. If the ticket can't be sized from its own text, that's the finding. | [why](./skills/engineering/pre-implement/WHY.md) |
| **`grill-for-refinement`** | Sharpens a single ticket to refinement-ready with a refinement lens, not an implementation one. Drafts a comment; posts on your confirmation. | [why](./skills/engineering/grill-for-refinement/WHY.md) |
| **`pr-description`** | Writes or rewrites a scannable description for an existing PR, using the session's own memory of the work when it did the work. | [why](./skills/engineering/pr-description/WHY.md) |
| **`pr-review`** | Reviews a PR, folds in Copilot's findings, has Codex peer-review the combined set, then opens a follow-up PR with fixes one commit at a time. | [why](./skills/engineering/pr-review/WHY.md) |
| **`terse`** | Low-token communication mode. Looks like a style preference; it's the load-bearing context primitive for everything else here. | [why](./skills/productivity/terse/WHY.md) |
| **`setup-scott-carlson-skills`** | Run once. Checks prerequisites, installs the subagents, adds the standing policy, keeps payloads out of git. | [why](./skills/engineering/setup-scott-carlson-skills/WHY.md) |

Three through-lines worth knowing before you use any of them:

- **Anything team-visible is drafted first.** `grill-for-refinement` posts a ticket comment,
  `pr-review` opens a PR, `pr-description` edits one. All three show you the full text and wait.
- **Digest in, payload on disk.** `jira-intake` is the reference implementation of rule 1.
- **The skill tells you the next command.** Including which reset comes first.

## Updating

```bash
npx skills@latest update
```

Run it yourself, periodically. **Nothing notifies you** when this repo changes — that's the trade
made in [ADR-0001](./docs/adr/0001-npx-only-distribution.md) by choosing this channel over a Claude
Code plugin.

> ### ⚠️ Don't edit installed skills
>
> Fork this repo instead. The CLI compares the *upstream* hash against the hash recorded at install
> time and never inspects your installed files. So local edits are neither preserved nor repaired:
>
> - When upstream **has** changed, your edits are overwritten with no prompt.
> - When upstream **hasn't** changed, the skill is skipped and your edit survives forever — quietly
>   diverging from what everyone else is running.
>
> "Just run update to get back in sync" is false. ADR-0001 has a worked example of a real skill that
> `update` will never repair.

## Contributing / authoring

[`CLAUDE.md`](./CLAUDE.md) has the authoring conventions, [`CONTEXT.md`](./CONTEXT.md) the vocabulary,
and [`docs/adr/`](./docs/adr/) the reasoning behind the repo's shape.

```bash
node scripts/validate-skills.mjs   # run before committing
./scripts/sync-skills.sh          # copy skills into ~/.agents and link them for authoring
```

## Credit

The pipeline these skills plug into, the grilling and spec-and-tickets flow, and most of the thinking
about where a context window actually fails, are [Matt Pocock's](https://www.aihero.dev/skills). This
repo is the connective tissue, not the machine.

## License

MIT
