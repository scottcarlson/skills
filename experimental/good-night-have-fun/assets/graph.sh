#!/usr/bin/env bash
# Build the dependency graph for a spec issue's ready-for-agent children.
#
# Deterministic on purpose. The Orchestrator must not eyeball ticket bodies and
# infer an order: a wrong order silently runs cleanup tickets before the work
# they clean up after, and that looks exactly like success until you read the
# diff.
#
# Usage: graph.sh <spec-issue-number> <owner/repo> <out-dir>
# Writes <out-dir>/graph.json. Exits 1 with a FATAL line on stderr if the
# declared graph cannot be trusted.

set -uo pipefail

SPEC="${1:?spec issue number required}"
REPO="${2:?owner/repo required}"
OUT="${3:?output directory required}"
mkdir -p "$OUT"
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

fail() { printf 'FATAL: %s\n' "$1" >&2; exit 1; }

# 1. Discover children.
#
# There is no structural spec -> child link to rely on: native sub-issues,
# dependencies and milestones all go unused by the ticket-generation step. The
# timeline is the only complete source, and it is heuristic — anything that
# mentions the spec shows up — so the `Spec: #N` body check below is required,
# not belt-and-braces.
gh api "repos/$REPO/issues/$SPEC/timeline?per_page=100" --paginate \
  --jq '.[] | select(.event=="cross-referenced") | select(.source.issue.pull_request==null) | .source.issue.number' \
  2>/dev/null | sort -n -u > "$W/children.txt" \
  || fail "could not read the timeline for #$SPEC"

[ -s "$W/children.txt" ] \
  || fail "#$SPEC has no cross-referenced issues. Has /to-tickets run for this spec?"

: > "$W/edges.txt"
: > "$W/nodes.jsonl"
placeholders=()

while read -r n; do
  # `< /dev/null` is load-bearing: gh otherwise eats this loop's stdin and the
  # loop exits after one iteration.
  gh issue view "$n" -R "$REPO" \
    --json number,title,state,labels,body < /dev/null > "$W/i$n.json" 2>/dev/null || continue

  # Two filters. `ready-for-agent` alone sweeps in unrelated issues elsewhere in
  # the repo; the cross-reference alone sweeps in anything that mentions the spec.
  jq -e --arg spec "$SPEC" \
    '(.state == "OPEN")
     and (.labels | map(.name) | index("ready-for-agent"))
     and (.body | test("Spec: #" + $spec + "\\b"))' \
    "$W/i$n.json" >/dev/null || continue

  section=$(jq -r '.body' "$W/i$n.json" | awk '/^## Blocked by/{f=1;next} /^## /{f=0} f')

  # An unexpanded shell variable means the generator wrote `#$N4` instead of an
  # issue number. Parsing anyway yields a garbage order in which the corrupted
  # tickets look rootless and float to the front.
  if printf '%s' "$section" | grep -qE '#\$'; then
    placeholders+=("$n")
  fi

  phase=$(jq -r '.body' "$W/i$n.json" \
    | awk '/^## Parent/{f=1;next} /^## /{f=0} f' \
    | grep -oE '\*\*[^*]+\*\*' | head -1 | tr -d '*')

  jq -c --arg phase "$phase" \
    '{number, title, phase: $phase, labels: [.labels[].name]}' "$W/i$n.json" >> "$W/nodes.jsonl"

  for d in $(printf '%s' "$section" | grep -oE '#[0-9]+' | tr -d '#'); do
    printf '%s %s\n' "$d" "$n" >> "$W/edges.txt"
  done
done < "$W/children.txt"

[ -s "$W/nodes.jsonl" ] \
  || fail "no open \`ready-for-agent\` children of #$SPEC declare \`Spec: #$SPEC\`."

if [ ${#placeholders[@]} -gt 0 ]; then
  fail "unresolved template placeholders in '## Blocked by' on issue(s): ${placeholders[*]}.
  The ticket generator wrote a shell variable instead of an issue number. The dependency
  graph cannot be trusted. Fix those issue bodies before running."
fi

# 3. Every edge must point at a node we actually collected.
while read -r from to; do
  grep -q "\"number\":$from," "$W/nodes.jsonl" || grep -q "\"number\": *$from," "$W/nodes.jsonl" \
    || fail "issue #$to is blocked by #$from, which is not an executable child of #$SPEC."
done < <(sort -u "$W/edges.txt")

# 4. Topological sort. tsort fails loudly on a cycle.
awk '{print $1}' "$W/nodes.jsonl" >/dev/null
jq -r '.number | "ROOT \(.)"' "$W/nodes.jsonl" > "$W/roots.txt"
order=$(cat "$W/edges.txt" "$W/roots.txt" | tsort 2>"$W/tsort.err" | grep -v '^ROOT$') \
  || fail "the dependency graph contains a cycle: $(tr '\n' ' ' < "$W/tsort.err")"

# 5. Phase tags and blocking edges encode the same constraint independently. If
#    they disagree, one is wrong and there is no way to tell which at 3am.
#    A phase we do not recognise ranks as empty and is skipped: an unknown tag
#    is not evidence of a contradiction, and this check must never invent one.
phase_rank() {
  case "$1" in
    *cleanup*)   echo 5 ;;   # matched before PR2 — "cleanup" tags may name a PR
    *gate*)      echo 2 ;;   # e.g. "the gate between PR1 and PR2"
    *PR1*)       echo 1 ;;
    *PR2*)       echo 3 ;;
    *PR[3-9]*)   echo 4 ;;
    *)           echo ""  ;;
  esac
}
while read -r from to; do
  pf=$(phase_rank "$(jq -r --argjson n "$from" 'select(.number==$n) | .phase' "$W/nodes.jsonl" | head -1)")
  pt=$(phase_rank "$(jq -r --argjson n "$to"   'select(.number==$n) | .phase' "$W/nodes.jsonl" | head -1)")
  [ -n "$pf" ] && [ -n "$pt" ] || continue
  [ "$pf" -le "$pt" ] \
    || fail "phase tags contradict the blocking edges: #$to (phase rank $pt) is blocked by
  #$from (phase rank $pf), which runs later. One of the two is wrong; resolve it before starting."
done < <(sort -u "$W/edges.txt")

jq -n \
  --argjson nodes "$(jq -s '.' "$W/nodes.jsonl")" \
  --argjson edges "$(awk '{printf "{\"blocks\":%s,\"blocked\":%s}\n", $2, $1}' "$W/edges.txt" | jq -s 'unique')" \
  --argjson order "$(printf '%s\n' "$order" | jq -R . | jq -s 'map(select(. != "") | tonumber)')" \
  --arg spec "$SPEC" --arg repo "$REPO" \
  '{spec: ($spec|tonumber), repo: $repo, nodes: $nodes, edges: $edges, order: $order}' \
  > "$OUT/graph.json"

printf 'graph.json written: %s node(s), %s edge(s)\n' \
  "$(jq '.nodes | length' "$OUT/graph.json")" "$(jq '.edges | length' "$OUT/graph.json")"
