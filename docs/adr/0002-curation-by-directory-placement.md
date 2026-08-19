---
status: accepted
---

# Curate by directory placement, with no `.claude-plugin/` manifest

Skills that ship live under `skills/<category>/<name>/`. Anything unfinished lives outside
`skills/` entirely, where the installer's directory walk cannot reach it. There is no manifest.

## Context

The `skills` CLI discovers skills two ways: a depth-limited walk of `skills/`, or — if
`.claude-plugin/plugin.json` exists — the explicit path list inside it, which bypasses the walk.
Matt's manifest names 25 of his 35 skills; that is how his `in-progress/` and `deprecated/`
buckets stay out of the installer's picker.

Shipping a manifest purely for curation would mean carrying a `.claude-plugin/` directory
nobody installs from, plus a version-drift check to keep two version numbers aligned, plus the
standing invitation to re-adopt the plugin route rejected in ADR-0001. Placing unfinished work
outside `skills/` achieves the same curation with nothing to keep in sync.

## Consequences

- Categories are adopted from day one despite there being only seven skills, because the
  installer records `skillPath` verbatim in its lockfile — moving a skill later is a path
  change with unclear update semantics. Layout churn is the expensive thing, not layout.
- Promoting a staged skill means moving it into `skills/<category>/`, which is the whole
  promotion ceremony.
