# Changelog

Hand-written. There are no version numbers: skills are distributed by the `skills` CLI, which
compares git tree hashes rather than versions, so a version number here would be read by nothing.
Entries are dated and describe what changed for someone who has these skills installed.

## 2026-08-25

Removed `to-adr` as a standalone skill. Its one job — reminding you to write ADRs before a reset
destroys the argument behind them — is now a line in `jira-intake`'s handoff instead of a whole
separate pipeline step. That handoff also now reminds the planning session to stay on the code and
acceptance criteria (not commit hygiene or other delivery mechanics) and to leave logic code to
`implement`.

- `to-adr` removed; superseded by reminders in `jira-intake`'s step 5 handoff
- `jira-intake` — handoff now carries three standing reminders for the planning session it hands off to
- `setup-scott-carlson-skills` — dropped the `domain-modeling` dependency check, no longer called directly by anything in this repo

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

## 2026-08-21

- Replaced `scripts/link-skills.sh` with `scripts/sync-skills.sh`. The old script symlinked the
  per-agent skill directories straight at this repo, which made every linked skill disappear from
  fresh sessions — skill discovery does not reliably follow a symlink resolving outside the
  canonical skills tree, and it fails silently. The new script copies into `~/.agents/skills`
  instead, reproducing what the installer writes.
