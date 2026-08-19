# Changelog

Hand-written. There are no version numbers: skills are distributed by the `skills` CLI, which
compares git tree hashes rather than versions, so a version number here would be read by nothing.
Entries are dated and describe what changed for someone who has these skills installed.

## 2026-08-19

Initial release. Seven skills extracted from a personal `~/.claude/skills/` directory and packaged
for distribution, plus `setup-scott-carlson-skills` written from scratch to configure a machine
for them.

- `jira-intake` — entry point for new work; fans out subagents so payloads land on disk
- `to-adr` — capture decisions as ADRs before a reset destroys the argument behind them
- `pre-implement` — name the model and effort for one slice, then get out of the way
- `grill-for-refinement` — sharpen a single ticket to refinement-ready, and comment on it
- `pr-description` — write or rewrite a scannable description for an existing PR
- `pr-review` — review, fix, and open a follow-up PR, with Codex peer-reviewing the review
- `terse` — low-token communication mode; the load-bearing primitive for the whole set
- `setup-scott-carlson-skills` — check prerequisites, install subagents, scaffold repo config
