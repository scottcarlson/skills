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
planning_docs=()

emit_and_exit() {
  jq -n \
    --arg base_branch "$base_branch" \
    --arg repo "$repo" \
    --argjson fatal "$(printf '%s\n' "${fatal[@]+"${fatal[@]}"}" | jq -R . | jq -s 'map(select(. != ""))')" \
    --argjson warn "$(printf '%s\n' "${warn[@]+"${warn[@]}"}" | jq -R . | jq -s 'map(select(. != ""))')" \
    --argjson planning_docs "$(printf '%s\n' "${planning_docs[@]+"${planning_docs[@]}"}" | jq -R . | jq -s 'map(select(. != ""))')" \
    '{repo: $repo, base_branch: $base_branch, planning_docs: $planning_docs, fatal: $fatal, warn: $warn, ok: ($fatal | length == 0)}'
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
  # Classic tokens list their scopes; fine-grained and app tokens print
  # "none" or nothing, so absence there is unknowable rather than missing.
  scopes=$(gh auth status --active 2>&1 | grep 'Token scopes:' | head -1)
  if printf '%s' "$scopes" | grep -q "'"; then
    printf '%s' "$scopes" | grep -q "'repo'" \
      || fatal+=("\`gh\` token lacks the \`repo\` scope; issue comments and PR creation will fail. Run \`gh auth refresh -s repo\`.")
  else
    warn+=("Could not read \`gh\` token scopes (fine-grained or app token?); confirm it can comment on issues and open PRs.")
  fi
fi

# Code changes in a dirty tree would land in someone's PR, so they are fatal. Docs the planning
# session wrote (ADRs, CONTEXT, AGENTS, README, anything under docs/) are the one exception: they
# are reported in `planning_docs` and the skill commits them first on the integration branch.
# Renames ("old -> new") are never treated as docs.
while IFS= read -r line; do
  [ -n "$line" ] || continue
  path="${line:3}"
  case "$path" in
    *" -> "*) fatal+=("Working tree is not clean (\`$path\`). Commit or stash before starting an unattended run."); break ;;
    *.md|*.mdx|docs/*|*/docs/*) planning_docs+=("$path") ;;
    *) fatal+=("Working tree has uncommitted non-doc changes (\`$path\`). Commit or stash before starting an unattended run."); break ;;
  esac
done < <(git status --porcelain --untracked-files=all 2>/dev/null)

# Never assume main.
if base_branch=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null) \
   && [ -n "$base_branch" ]; then
  git fetch --quiet origin "$base_branch" 2>/dev/null \
    || fatal+=("Cannot fetch \`origin/$base_branch\`. Remote unreachable?")
else
  base_branch=""
  fatal+=("Could not resolve the default branch from \`gh repo view\`.")
fi

# graph.sh needs owner/repo; an empty value would only surface after hand-over.
repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null) || repo=""
[ -n "$repo" ] || fatal+=("Could not resolve owner/repo from \`gh repo view\`.")

git worktree list >/dev/null 2>&1 \
  || fatal+=("\`git worktree\` is unavailable; this git is too old.")

# The run writes payloads to .ig.good-night/. That rule is owned by
# /setup-scott-carlson-skills, not by this skill.
# Ask git rather than grepping .gitignore: `/.ig.*`, `.ig.*/` and a global
# excludes file all count.
if git -C "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" \
     check-ignore -q .ig.good-night/probe 2>/dev/null; then
  :
else
  fatal+=("\`.gitignore\` does not cover \`.ig.*\`. Run \`/setup-scott-carlson-skills\` in this repo first.")
fi

# The implement and pre-implement protocols are read off disk, not invoked. Missing is survivable;
# the skill falls back to a minimal built-in protocol and says so.
for s in implement pre-implement; do
  [ -r "$HOME/.agents/skills/$s/SKILL.md" ] \
    || warn+=("\`~/.agents/skills/$s/SKILL.md\` is unreadable; subagents will use the built-in fallback protocol.")
done

emit_and_exit
