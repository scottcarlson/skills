#!/usr/bin/env bash
# Environment preflight for good-night-have-fun.
#
# Every check here answers one question: can this run finish without a human?
# Anything that would need the user is a FATAL, and FATAL means stop while they
# are still awake to fix it.
#
# Usage: preflight.sh
# Emits a JSON object on stdout. Exits 1 if any check is fatal.

set -uo pipefail

fatal=()
warn=()
base_branch=""
repo=""

emit_and_exit() {
  jq -n \
    --arg base_branch "$base_branch" \
    --arg repo "$repo" \
    --argjson fatal "$(printf '%s\n' "${fatal[@]+"${fatal[@]}"}" | jq -R . | jq -s 'map(select(. != ""))')" \
    --argjson warn "$(printf '%s\n' "${warn[@]+"${warn[@]}"}" | jq -R . | jq -s 'map(select(. != ""))')" \
    '{repo: $repo, base_branch: $base_branch, fatal: $fatal, warn: $warn, ok: ($fatal | length == 0)}'
  [ ${#fatal[@]} -eq 0 ] || exit 1
  exit 0
}

for bin in gh jq git tsort; do
  command -v "$bin" >/dev/null 2>&1 || fatal+=("\`$bin\` is not installed.")
done
# Without jq there is no way to emit the report at all.
command -v jq >/dev/null 2>&1 || { printf 'FATAL: jq is not installed.\n' >&2; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fatal+=("Not inside a git work tree.")

# gh auth. The `repo` scope is what lets us comment on issues and open PRs.
if ! gh auth status >/dev/null 2>&1; then
  fatal+=("\`gh\` is not authenticated. Run \`gh auth login\`.")
else
  gh auth status 2>&1 | grep -q "'repo'" \
    || warn+=("\`gh\` token may lack the \`repo\` scope; issue comments and PR creation could fail.")
fi

# A dirty tree would be swept into the first worktree and land in someone's PR.
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  fatal+=("Working tree is not clean. Commit or stash before starting an unattended run.")
fi

# Never assume main.
if base_branch=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null) \
   && [ -n "$base_branch" ]; then
  git fetch --quiet origin "$base_branch" 2>/dev/null \
    || fatal+=("Cannot fetch \`origin/$base_branch\`. Remote unreachable?")
else
  base_branch=""
  fatal+=("Could not resolve the default branch from \`gh repo view\`.")
fi

repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null) || repo=""

git worktree list >/dev/null 2>&1 \
  || fatal+=("\`git worktree\` is unavailable; this git is too old.")

# The run writes payloads to .ig.good-night/. That rule is owned by
# /setup-scott-carlson-skills, not by this skill.
if [ -f .gitignore ] && grep -qE '^\.ig\.\*' .gitignore; then
  :
else
  fatal+=("\`.gitignore\` does not cover \`.ig.*\`. Run \`/setup-scott-carlson-skills\` in this repo first.")
fi

# Matt Pocock's protocols are read off disk, not invoked. Missing is survivable;
# the skill falls back to a minimal built-in protocol and says so.
for s in implement pre-implement; do
  [ -r "$HOME/.agents/skills/$s/SKILL.md" ] \
    || warn+=("\`~/.agents/skills/$s/SKILL.md\` is unreadable; subagents will use the built-in fallback protocol.")
done

emit_and_exit
