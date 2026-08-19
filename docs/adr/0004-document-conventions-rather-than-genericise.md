---
status: accepted
---

# Document this repo's conventions rather than genericise the skills

These skills are built for a specific stack — Atlassian MCP, Figma MCP, `gh`, Codex — and a
specific way of working. The repository is public and the README is honest about that, but the
skills are not rewritten to accommodate stacks their author does not use. Genericising them for
hypothetical strangers would degrade the thing that makes them good.

## What this does and does not mean

- **Not genericised:** the JIRA dependency, the `.ig.jira-tickets/` payload directory, the
  `docs/adr/` and `CONTEXT.md` layout inherited from `domain-modeling`.
- **Genericised anyway, because it cost nothing:** the `PSD-` ticket prefix appearing as an
  example. All four JIRA-aware skills already parse the prefix by *shape* rather than literal
  match, so the prefix was always dynamic; only the example token changes, to `ABC-123`.
- **Named nowhere:** no employer, team, or internal system appears in any skill or document.

## Consequences

- The README carries a prerequisite matrix naming which MCP servers and CLIs each skill needs,
  rather than degrading gracefully when they are absent.
- Descriptions stay long on the five user-invoked skills, because a user-invoked skill's
  description costs installers nothing and reads as help text. Only the two model-invoked
  skills — `terse` and `grill-for-refinement` — are trimmed for per-session cost.
