# Scott Carlson's Skills

A public, distributable set of Claude Code skills that act as connective tissue around
Matt Pocock's engineering skills — filling the gaps at the front of the delivery pipeline
(getting real-world context in cheaply), the middle (capturing rationale before a reset
destroys it), and the back (PR hygiene).

## Language

### Skills

**Skill**:
A directory containing a `SKILL.md` whose frontmatter names it and describes when to use it.
The unit of distribution in this repo.
_Avoid_: command, prompt, macro

**Model-invoked skill**:
A skill whose `name` and `description` load into every session, so the model may fire it on
its own. The description is a per-session token cost paid by everyone who installs it.
_Avoid_: auto skill, implicit skill

**User-invoked skill**:
A skill carrying `disable-model-invocation: true`. It is hidden from the session's skill list
entirely until a human types it, and therefore costs installed users nothing until used.
A user-invoked skill can never be called by another skill.
_Avoid_: manual skill, explicit skill

**Promoted skill**:
A skill that ships to installers. Lives under a category directory inside `skills/`.
_Avoid_: published, released, curated

**Rationale doc**:
A skill's `WHY.md` — the premise it was built on and the failure it prevents. Ships inside the
skill folder so it is readable on any machine that installed the skill, not just from GitHub.
Never contains operational instructions; those belong in `SKILL.md`.
_Avoid_: docs, notes, README

**Staged skill**:
A skill still being written, kept outside `skills/` so the installer's directory walk never
finds it. Placement is the curation mechanism; there is no manifest.
_Avoid_: draft, experimental, WIP

### Distribution

**Installer**:
The third-party `skills` CLI (`vercel-labs/skills`), invoked as `npx skills@latest`. This repo
publishes nothing and owns no installer; it is a GitHub repository the CLI reads.
_Avoid_: package manager, our CLI

**Canonical skills directory**:
`~/.agents/skills/` (global) or `<repo>/.agents/skills/` (project) — where the installer writes
the real copy of a skill. Each agent's own skills directory is a symlink farm pointed at it.
_Avoid_: install dir, skills folder

**Skill folder hash**:
The git tree hash of a skill's directory, recorded at install time. The installer flags a skill
for update when the current upstream hash differs from the recorded one.
_Avoid_: version, checksum

**Drift**:
A local edit to an installed third-party skill. Invisible to the installer, which compares
upstream-to-upstream and never inspects installed files, so drift is destroyed without warning
on the next update.
_Avoid_: local change, patch, fork

### The pipeline

**Dumb zone**:
The region of a context window past roughly the first 100K tokens, where a model still answers
but answers worse. The premise every skill here is designed against.
_Avoid_: context rot, degradation

**Payload**:
Raw source material — a ticket export, Figma frame, screenshot, transcript, long diff. Payload
is written to disk by a subagent and must never enter the main session's context window.
_Avoid_: context, source, input

**Digest**:
The short summary a subagent returns in place of a payload. What the main session is allowed
to see.
_Avoid_: summary, report, brief

**Setup skill**:
A user-invoked skill that configures a machine or repo for the others — checking prerequisites,
installing subagent definitions, and scaffolding per-repo configuration. Also the delivery
vehicle for anything the installer cannot carry.
_Avoid_: bootstrap, init, wizard
