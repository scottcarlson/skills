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
skip_notparent=()
skip_closed=()
skip_notready=()

while read -r n; do
  # `< /dev/null` is load-bearing: gh otherwise eats this loop's stdin and the
  # loop exits after one iteration.
  gh issue view "$n" -R "$REPO" \
    --json number,title,state,labels,body < /dev/null > "$W/i$n.json" 2>/dev/null || continue

  # Two filters. `ready-for-agent` alone sweeps in unrelated issues elsewhere in
  # the repo; the cross-reference alone sweeps in anything that mentions the
  # spec — including its own sibling specs, which cross-reference each other.
  #
  # We look only inside the `## Parent` section, and match the spec number
  # anywhere within it. The section's format varies by vintage of the ticket
  # generator — `Spec: #356 · ADR 0017` and a bare `#27` are both in the wild —
  # so anchoring on a `Spec:` prefix silently finds zero children on older
  # repos, which is indistinguishable from "this spec has no work".
  parent=$(jq -r '.body' "$W/i$n.json" | awk '/^## Parent/{f=1;next} /^## /{f=0} f')
  printf '%s' "$parent" | grep -qE "#$SPEC\b" || { skip_notparent+=("$n"); continue; }

  [ "$(jq -r '.state' "$W/i$n.json")" = "OPEN" ] || { skip_closed+=("$n"); continue; }
  jq -e '.labels | map(.name) | index("ready-for-agent")' "$W/i$n.json" >/dev/null \
    || { skip_notready+=("$n"); continue; }

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

# Distinguish the reasons there is nothing to do. "No work" and "the work is
# finished" and "this is a companion spec whose tickets hang off a sibling" are
# three different situations, and a single generic message sends the user
# looking in the wrong place.
if [ ! -s "$W/nodes.jsonl" ]; then
  msg="no runnable tickets found for #$SPEC."
  [ ${#skip_closed[@]} -gt 0 ] \
    && msg="$msg
  ${#skip_closed[@]} child ticket(s) declare this spec but are CLOSED (${skip_closed[*]}) — this spec looks done."
  [ ${#skip_notready[@]} -gt 0 ] \
    && msg="$msg
  ${#skip_notready[@]} open child ticket(s) lack the \`ready-for-agent\` label (${skip_notready[*]})."
  [ ${#skip_notparent[@]} -gt 0 ] \
    && msg="$msg
  ${#skip_notparent[@]} cross-referenced issue(s) do not name #$SPEC in a '## Parent' section (${skip_notparent[*]}).
  If this spec is one of several companions, its tickets may hang off a sibling spec instead — check those numbers."
  fail "$msg"
fi

if [ ${#placeholders[@]} -gt 0 ]; then
  fail "unresolved template placeholders in '## Blocked by' on issue(s): ${placeholders[*]}.
  The ticket generator wrote a shell variable instead of an issue number. The dependency
  graph cannot be trusted. Fix those issue bodies before running."
fi

# 3. Classify every blocker that is not itself a runnable node in this graph.
#
#    A blocker outside the graph is not automatically an error. Specs are
#    routinely half-finished, so the common case is a blocker that is CLOSED —
#    already satisfied, and the edge should simply be dropped. Failing on those
#    would refuse to run any spec that had been partly worked, which is most of
#    them.
: > "$W/edges_internal.txt"
: > "$W/external_blocks.txt"
while read -r from to; do
  if grep -qE "\"number\": *$from," "$W/nodes.jsonl"; then
    printf '%s %s\n' "$from" "$to" >> "$W/edges_internal.txt"
    continue
  fi
  st=$(gh issue view "$from" -R "$REPO" --json state --jq '.state' < /dev/null 2>/dev/null) || st=""
  case "$st" in
    CLOSED)
      : ;;                                        # satisfied; drop the edge
    OPEN)
      # A real, unsatisfied blocker that this run cannot execute — it is not a
      # ready-for-agent child of this spec. The ticket is externally blocked.
      # Record it and let the run prune that subtree; do not halt the night.
      printf '%s %s\n' "$to" "$from" >> "$W/external_blocks.txt" ;;
    *)
      fail "issue #$to declares a blocker #$from that does not exist in $REPO." ;;
  esac
done < <(sort -u "$W/edges.txt")
mv "$W/edges_internal.txt" "$W/edges.txt"

# 4. Topological sort. tsort fails loudly on a cycle.
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
  --argjson external "$(awk '{printf "{\"ticket\":%s,\"blocked_by\":%s}\n", $1, $2}' "$W/external_blocks.txt" | jq -s 'unique')" \
  --arg spec "$SPEC" --arg repo "$REPO" \
  '{spec: ($spec|tonumber), repo: $repo, nodes: $nodes, edges: $edges,
    order: $order, external_blocks: $external}' \
  > "$OUT/graph.json"

printf 'graph.json written: %s node(s), %s edge(s), %s externally blocked\n' \
  "$(jq '.nodes | length' "$OUT/graph.json")" \
  "$(jq '.edges | length' "$OUT/graph.json")" \
  "$(jq '.external_blocks | length' "$OUT/graph.json")"
