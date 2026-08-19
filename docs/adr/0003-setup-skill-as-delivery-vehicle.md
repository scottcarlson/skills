---
status: accepted
---

# `setup-scott-carlson-skills` delivers everything the installer cannot

The installer materializes skill folders and nothing else — it never writes `~/.claude/agents/`
or any `CLAUDE.md`. But it copies each skill folder *verbatim*, siblings and subdirectories
included. So a skill can carry arbitrary payload and install it. `setup-scott-carlson-skills`
is that skill: it ships the subagent definitions and the standing-policy block as assets inside
its own folder, and writes them on run.

## What it does

1. Checks which of Matt Pocock's required skills are installed and prints the exact
   `npx skills@latest add mattpocock/skills --skill=<name>` commands for the missing ones.
2. Checks the other prerequisites — Atlassian MCP, Figma MCP, `gh`, Codex.
3. Installs the four subagent definitions to `~/.claude/agents/`, offering to rewrite
   `exhaustive-reasoner` from `model: fable` to `model: opus` when Fable is unreachable.
4. Drafts the standing-policy block as a diff against the user's `CLAUDE.md` and appends it
   only on explicit confirmation.
5. Appends `.ig.*` to the repo's `.gitignore` so ticket payloads are never committed.
6. Ends by telling the user to run `/setup-matt-pocock-skills`.

## Consequences

- **It cannot install skills, and it cannot run Matt's setup skill.** A user-invoked skill can
  never be called by another skill, and no skill can reliably install itself into the harness
  running it. Both are phrased as instructions to the user.
- It writes to *global* config, because the pipeline is cross-repo. It says so before writing,
  and never edits a `CLAUDE.md` section it did not author.
- The standing-policy block is the highest-value thing in this repository that is not a skill.
  The skills are an implementation of it; installed without it, they work without the reasoning
  that makes them work.
