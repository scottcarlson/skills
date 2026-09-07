#!/usr/bin/env bash
#
# sync-skills.sh
#
# Dev-only authoring helper. NOT an installer for end users, who should run:
#
#   npx skills@latest add scottcarlson/skills
#
# Copies every skill in this repo over the installed copy in the canonical
# skills directory, then makes sure each one is linked into the per-agent
# directories. Run it after editing a skill, then restart your session.
#
# Why copy instead of symlink: agent skill discovery does not reliably follow
# a symlink that resolves outside the canonical skills tree. Linking straight
# at a repo checkout makes the skills silently vanish from a fresh session.
# The copy reproduces exactly what the installer would have written.

#
# By default only skills/ is synced — that is the tree the installer ships, and
# staged work deliberately stays out of it (ADR-0002). Pass --experimental to
# also sync experimental/, which you need in order to test a staged skill at
# all: an unsynced skill cannot be invoked, so there is no way to author one
# without this.

set -euo pipefail

include_experimental=0
for arg in "$@"; do
  case "$arg" in
    --experimental) include_experimental=1 ;;
    -h|--help)
      echo "usage: sync-skills.sh [--experimental]"
      echo "  --experimental  also sync staged skills from experimental/"
      exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skills_root="${repo_root}/skills"
experimental_root="${repo_root}/experimental"
canonical="${HOME}/.agents/skills"
agent_dirs=("${HOME}/.claude/skills")

if [[ ! -d "${skills_root}" ]]; then
  echo "No skills/ directory at ${skills_root}; nothing to sync."
  exit 0
fi

if [[ ! -d "${canonical}" ]]; then
  echo "ERROR: canonical skills directory ${canonical} does not exist."
  echo "Install something with 'npx skills@latest add' first."
  exit 1
fi

if [[ ! -w "${canonical}" ]]; then
  echo "ERROR: ${canonical} is not writable."
  exit 1
fi

synced=0

while IFS= read -r skill_md; do
  skill_dir="$(dirname "${skill_md}")"
  skill_name="$(basename "${skill_dir}")"
  target="${canonical}/${skill_name}"

  # A symlink here is the old broken authoring setup, or another repo's link.
  # Replace it with a real directory rather than writing through it.
  if [[ -L "${target}" ]]; then
    echo "NOTE: replacing symlink ${target} with a real directory"
    rm "${target}"
  fi

  rm -rf "${target}"
  cp -R "${skill_dir}" "${target}"
  echo "SYNCED: ${skill_name}"
  synced=$((synced + 1))

  # Per-agent directories hold relative links into the canonical tree.
  for agent_dir in "${agent_dirs[@]}"; do
    [[ -d "${agent_dir}" && -w "${agent_dir}" ]] || continue
    link_path="${agent_dir}/${skill_name}"
    if [[ -e "${link_path}" && ! -L "${link_path}" ]]; then
      echo "WARN: ${link_path} exists and is not a symlink; left alone."
      continue
    fi
    ln -sfn "../../.agents/skills/${skill_name}" "${link_path}"
  done
done < <(
  # skills/<category>/<name>/SKILL.md
  find "${skills_root}" -mindepth 3 -maxdepth 3 -type f -name "SKILL.md"
  # experimental/<name>/SKILL.md — no category level; staging is flat.
  if [[ "${include_experimental}" -eq 1 && -d "${experimental_root}" ]]; then
    find "${experimental_root}" -mindepth 2 -maxdepth 2 -type f -name "SKILL.md"
  fi
)

echo ""
echo "Summary: ${synced} synced. Restart your session to pick up changes."
if [[ "${include_experimental}" -eq 0 && -d "${experimental_root}" ]]; then
  staged="$(find "${experimental_root}" -mindepth 2 -maxdepth 2 -type f -name "SKILL.md" | wc -l | tr -d ' ')"
  if [[ "${staged}" -gt 0 ]]; then
    echo "Note: ${staged} staged skill(s) in experimental/ were NOT synced."
    echo "      Re-run with --experimental to test them locally."
  fi
fi
