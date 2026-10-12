#!/usr/bin/env bash
# Ledger operations for good-night-have-fun.
#
# The ledger is the run's memory. The Orchestrator re-reads it each wave instead
# of carrying ticket state in its context, which is what keeps a sixteen-ticket
# night costing about what a four-ticket night costs.
#
# Mutations go through this script rather than being rewritten from memory: an
# LLM six hours into a run rewriting a JSON blob by hand is a corruption path.
#
# Usage:
#   ledger.sh init   <dir> <graph.json> <gate-cmd> <base-branch> <integration-branch>
#   ledger.sh set    <dir> <ticket> <field> <value>   # value is JSON
#   ledger.sh ready  <dir>                            # tickets whose blockers are all merged
#   ledger.sh prune  <dir> <ticket>                   # mark its pending dependents blocked
#   ledger.sh close  <dir> <integration-sha>          # staged: branch finished phases' boundaries
#   ledger.sh phases <dir>                            # staged: "<k> <tags> <head> <base>" per PR
#   ledger.sh tally  <dir>                            # one-line summary counts

set -uo pipefail

# Marks every pending transitive dependent of ticket $n with status $s. A
# blocked subtree must end the night terminal: left `pending`, its tickets are
# never ready and never counted, and the run looks unfinished rather than done.
PRUNE='
  def dependents($t; $n):
    [ $t[] | select(any(.blocked_by[]; . == $n)) | .number ] as $d
    | $d + ([ $d[] as $x | dependents($t; $x) ] | add // []);
  def prune($n; $s):
    .tickets as $t
    | reduce (dependents($t; $n) | unique[]) as $d (.;
        if .tickets[$d|tostring].status == "pending"
        then .tickets[$d|tostring].status = $s else . end);
'
cmd="${1:?subcommand required}"; dir="${2:?run directory required}"
L="$dir/ledger.json"

case "$cmd" in
  init)
    graph="${3:?graph.json required}"; gate="${4-}"; base="${5:?base branch required}"; integ="${6:?integration branch required}"
    # Never clobber a previous run's record; SKILL.md §1.1 decides what to do.
    [ ! -e "$L" ] || { printf 'FATAL: %s already exists; refusing to overwrite a previous run.\n' "$L" >&2; exit 1; }
    # Build into a temp file: without set -e a failed jq would otherwise leave
    # an empty ledger behind and still report success.
    tmp=$(mktemp)
    jq --arg gate "$gate" --arg base "$base" --arg integ "$integ" \
      "$PRUNE"'{
         spec, repo, order,
         gate: (if $gate == "" then null else $gate end),
         base_branch: $base,
         integration_branch: $integ,
         started_at: (now | todate),
         # More than one phase rank is a staged deploy: one stacked PR per
         # phase, so the run finishes a phase before starting the next.
         staged: ([.nodes[].phase_rank | select(. != null)] | unique | length > 1),
         phases: (.nodes as $ns
           | [.nodes[].phase_rank | select(. != null)] | unique
           | if length > 1 then to_entries | map(.value as $rk | {
               index: (.key + 1), rank: $rk,
               tags: ([$ns[] | select(.phase_rank == $rk) | .phase] | unique | join(" / ")),
               closed: false, merged: 0, sha: null, branch: null })
             else [] end),
         tickets: (.nodes | map({
           key: (.number|tostring),
           value: {
             number, title, phase, phase_rank,
             status: "pending",
             blocked_by: [],
             external_blocked_by: [],
             attempts: 0,
             model: null,
             branch: null,
             envelope: null
           }}) | from_entries),
         edges,
         external_blocks: (.external_blocks // [])
       }
       | .tickets = (reduce .edges[] as $e (.tickets;
           .[$e.ticket|tostring].blocked_by += [$e.blocked_by]))
       # An open blocker outside this run never merges, so the ticket can never
       # become ready. Mark it now, and its whole subtree with it.
       | .tickets = (reduce .external_blocks[] as $x (.tickets;
           .[$x.ticket|tostring] |= (.status = "blocked_external"
                                     | .external_blocked_by += [$x.blocked_by])))
       | reduce (.external_blocks | map(.ticket) | unique[]) as $x (.;
           prune($x; "blocked_by_external"))' \
      "$graph" > "$tmp" \
      || { rm -f "$tmp"; printf 'FATAL: could not build the ledger from %s\n' "$graph" >&2; exit 1; }
    mv "$tmp" "$L" || { rm -f "$tmp"; printf 'FATAL: could not write %s\n' "$L" >&2; exit 1; }
    printf '%s\n' "$L"
    ;;

  set)
    t="${3:?ticket required}"; field="${4:?field required}"; value="${5:?value required}"
    tmp=$(mktemp)
    # Reject what would silently corrupt the run: a ticket that is not in the
    # graph (it would appear in tally) or a status nothing downstream knows.
    jq --arg t "$t" --arg f "$field" --argjson v "$value" '
      if .tickets[$t] == null then error("unknown ticket: \($t)")
      elif $f == "status" and ($v | IN("pending", "merged", "failed", "needs_human",
                                       "blocked_by_failure", "blocked_by_human",
                                       "blocked_external", "blocked_by_external") | not)
        then error("unknown status: \($v)")
      else .tickets[$t][$f] = $v end' "$L" > "$tmp" \
      || { rm -f "$tmp"; exit 1; }
    mv "$tmp" "$L" || { rm -f "$tmp"; printf 'FATAL: could not write %s\n' "$L" >&2; exit 1; }
    ;;

  prune)
    # The dependents' status follows from why the ticket stopped. A failed,
    # human-blocked or externally blocked ticket prunes its subtree instead of
    # halting the run.
    t="${3:?ticket required}"
    case "$t" in ''|*[!0-9]*) printf 'ticket must be a number, got %s\n' "$t" >&2; exit 2 ;; esac
    tmp=$(mktemp)
    jq --argjson n "$t" "$PRUNE"'
      (.tickets[$n|tostring].status // error("unknown ticket: \($n)")) as $st
      | ({ failed: "blocked_by_failure", blocked_by_failure: "blocked_by_failure",
           needs_human: "blocked_by_human", blocked_by_human: "blocked_by_human",
           blocked_external: "blocked_by_external", blocked_by_external: "blocked_by_external" }[$st]
         // error("ticket \($n) is \($st); only a failed or blocked ticket prunes")) as $s
      | prune($n; $s)' "$L" > "$tmp" \
      || { rm -f "$tmp"; exit 1; }
    mv "$tmp" "$L" || { rm -f "$tmp"; printf 'FATAL: could not write %s\n' "$L" >&2; exit 1; }
    ;;

  ready)
    # A ticket is ready when it is pending and every blocker has merged.
    # Emitted in topological order, so "take up to 3" takes the earliest.
    # In a staged run only the earliest phase with pending work is offered: a
    # phase's boundary is a commit, and it only exists if nothing from a later
    # phase merges before the phase finishes.
    jq -r '
      .tickets as $t
      | (if .staged then [ $t[] | select(.status == "pending") | .phase_rank ] | min
         else null end) as $open
      | if $open != null and any(.phases[]; .rank < $open and (.closed | not))
        then error("a finished phase has no recorded boundary; run ledger.sh close first")
        else . end
      | .order[] | $t[tostring]
      | select(.status == "pending")
      | select($open == null or .phase_rank == $open)
      | select([ .blocked_by[] | $t[tostring].status ] | all(. == "merged"))
      | .number' "$L"
    ;;

  close)
    # Run inside wt-integration with its head, before every wave and once before
    # landing. Closes, in order, each phase with no pending ticket left, and
    # creates a boundary branch at the head for each one where something merged.
    # Prints "<branch> <sha>" for each branch it created. A phase where nothing
    # merged gets no branch and no PR.
    sha="${3:?integration sha required}"
    case "$sha" in *[!0-9a-f]*|'') printf 'sha must be hex, got %s\n' "$sha" >&2; exit 2 ;; esac
    [ ${#sha} -eq 40 ] || { printf 'sha must be the full 40-character sha, got %s\n' "$sha" >&2; exit 2; }
    git rev-parse --verify -q "$sha^{commit}" >/dev/null \
      || { printf 'FATAL: %s is not a commit in this repository; run close inside wt-integration\n' "$sha" >&2; exit 1; }
    tmp=$(mktemp)
    jq --arg sha "$sha" '
      reduce range(0; .phases | length) as $i (.;
        .phases[$i].rank as $r
        | if .phases[$i].closed then .
          elif (.phases[:$i] | all(.closed))
               and ([ .tickets[] | select(.phase_rank == $r and .status == "pending") ] | length == 0)
          then ([ .tickets[] | select(.phase_rank == $r and .status == "merged") ] | length) as $m
            | .phases[$i] += { closed: true, merged: $m,
                               sha: (if $m > 0 then $sha else null end),
                               branch: (if $m > 0 then "\(.integration_branch)-phase-\(.phases[$i].index)"
                                        else null end) }
          else . end)' "$L" > "$tmp" \
      || { rm -f "$tmp"; exit 1; }
    new=$(jq -r --slurpfile old "$L" '
      ($old[0].phases | map(select(.closed) | .index)) as $was
      | .phases[] | select(.closed and .branch != null and (.index | IN($was[]) | not))
      | "\(.branch) \(.sha)"' "$tmp") || { rm -f "$tmp"; exit 1; }
    # Create every ref before recording any phase as closed. A phase marked
    # closed is never emitted again, so a ledger that runs ahead of git would
    # land a stacked PR from a missing or stale branch. A branch already at the
    # boundary is accepted, so a close that failed halfway can simply be re-run.
    while read -r b bsha; do
      [ -n "$b" ] || continue
      if cur=$(git rev-parse --verify -q "refs/heads/$b"); then
        [ "$cur" = "$bsha" ] || { rm -f "$tmp"; printf 'FATAL: %s already exists at %s, not at the phase boundary %s. Delete it and re-run close; the ledger is unchanged.\n' "$b" "$cur" "$bsha" >&2; exit 1; }
      else
        git branch "$b" "$bsha" \
          || { rm -f "$tmp"; printf 'FATAL: could not create %s at %s; the ledger is unchanged.\n' "$b" "$bsha" >&2; exit 1; }
      fi
    done <<< "$new"
    mv "$tmp" "$L" || { rm -f "$tmp"; printf 'FATAL: could not write %s\n' "$L" >&2; exit 1; }
    [ -z "$new" ] || printf '%s\n' "$new"
    ;;

  phases)
    # One line per stacked PR, in merge order: index, tags, head, base. Each PR
    # is based on the previous phase that shipped anything, the first on the
    # base branch.
    jq -r '
      if any(.phases[]; .closed | not)
      then error("unclosed phase; run ledger.sh close with the integration head first")
      else . end
      | .base_branch as $b
      | reduce (.phases[] | select(.branch != null)) as $p ({base: $b, out: []};
          .out += [ "\($p.index)\t\($p.tags)\t\($p.branch)\t\(.base)" ] | .base = $p.branch)
      | .out[]' "$L"
    ;;

  tally)
    jq -r '[.tickets[].status]
      | ((map(select(. == "merged")) | length | tostring) + " shipped · ")
      + ((map(select(. == "failed")) | length | tostring) + " failed · ")
      + ((map(select(. != "merged" and . != "failed" and . != "pending")) | length | tostring) + " need you")' "$L"
    ;;

  *) printf 'unknown subcommand: %s\n' "$cmd" >&2; exit 2 ;;
esac
