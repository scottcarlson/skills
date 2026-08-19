#!/usr/bin/env bash
#
# link-skills.sh
#
# Dev-only authoring helper. NOT a supported installer for end users.
# End users should install skills with:
#
#   npx skills@latest add scottcarlson/skills
#
# This script symlinks every skill directory in this repo into the local
# agent skill directories ($HOME/.claude/skills and $HOME/.agents/skills)
# so that edits made in the repo take effect immediately, without needing
# to reinstall or copy files.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skills_root="${repo_root}/skills"

targets=(
  "${HOME}/.claude/skills"
  "${HOME}/.agents/skills"
)

linked_count=0
skipped_count=0
warned_count=0

if [[ ! -d "${skills_root}" ]]; then
  echo "No skills/ directory found at ${skills_root}; nothing to link."
  exit 0
fi

# Find every skill directory: skills/<category>/<name>/SKILL.md
while IFS= read -r skill_md; do
  skill_dir="$(dirname "${skill_md}")"
  skill_name="$(basename "${skill_dir}")"

  for target_root in "${targets[@]}"; do
    target_path="${target_root}/${skill_name}"

    # Tolerate a read-only or missing target tree: skip cleanly, don't abort.
    if [[ ! -d "${target_root}" ]]; then
      echo "SKIP: ${target_path} (parent directory ${target_root} does not exist)"
      skipped_count=$((skipped_count + 1))
      continue
    fi

    if [[ ! -w "${target_root}" ]]; then
      echo "SKIP: ${target_path} (parent directory ${target_root} is not writable)"
      skipped_count=$((skipped_count + 1))
      continue
    fi

    if [[ -e "${target_path}" && ! -L "${target_path}" ]]; then
      echo "WARN: ${target_path} already exists and is not a symlink; move it aside and re-run this script."
      warned_count=$((warned_count + 1))
      continue
    fi

    # Either it doesn't exist, or it's an existing symlink to replace.
    ln -sfn "${skill_dir}" "${target_path}"
    echo "LINKED: ${target_path} -> ${skill_dir}"
    linked_count=$((linked_count + 1))
  done
done < <(find "${skills_root}" -mindepth 3 -maxdepth 3 -type f -name "SKILL.md")

echo ""
echo "Summary: ${linked_count} linked, ${skipped_count} skipped, ${warned_count} warned"
