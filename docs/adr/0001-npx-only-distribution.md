---
status: accepted
---

# Distribute via the `skills` CLI only, not a Claude Code plugin

Skills are installed with `npx skills@latest add scottcarlson/skills` and updated with
`npx skills@latest update`. This repo publishes nothing to npm and ships no plugin manifest.

## Considered options

**The Claude Code plugin marketplace.** This is now the *primary* route for `mattpocock/skills`,
listed in Anthropic's official marketplace, and it is the only route that auto-updates —
Claude reads `.claude-plugin/plugin.json`'s `version` and pulls new releases down without the
user doing anything. It also delivers a read-only bundle, which makes local drift structurally
impossible.

**Publishing our own npm package** with a real `bin`. This would give full control of the
install and update experience, at the cost of owning a package manager — its releases, its
bugs, its support burden — for seven Markdown files.

**The `skills` CLI** (`vercel-labs/skills`), which Matt uses as his secondary route. Requires
no installer, no npm presence, and no release infrastructure: push a repo in the expected
layout and `owner/repo` becomes the argument.

## Consequences

- **No auto-update.** Installers must run `npx skills@latest update` themselves. Nobody is
  notified when this repo changes; a teammate who installs once and forgets is frozen.
- **Local edits to installed skills are neither preserved nor repaired.** The CLI compares the
  current upstream hash against the hash recorded at install time and never inspects the
  installed files. Two distinct failures follow, and they pull in opposite directions:
  when upstream *has* changed, the CLI re-runs `add … --yes`, whose suppressed prompt destroys
  local edits as collateral; when upstream has *not* changed, the skill is skipped entirely and
  the edit survives forever.

  Worked example, observed 2026-08-18. Four of Matt Pocock's skills had been locally stripped of
  `disable-model-invocation: true`, making them load into every session. Running
  `npx skills@latest update` repaired `grill-me`, `grill-with-docs`, and `handoff` — but only
  because upstream happened to have changed them. `implement` was skipped: its recorded
  `skillFolderHash` still matched upstream, since upstream had not touched the file since
  install. No amount of running `update` will ever fix it.

  So the README cannot say "run update to get back in sync" — that is false. It must say: do
  not edit installed skills; fork the repo instead.
- The install string `scottcarlson/skills` is effectively permanent. Renaming the repository
  invalidates every README, every lockfile entry, and every teammate's installation.
- The plugin route stays available as a purely additive second channel if auto-update later
  proves to matter. Adopting it would not change the repository layout.
