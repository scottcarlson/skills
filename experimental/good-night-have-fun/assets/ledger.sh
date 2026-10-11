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
         tickets: (.nodes | map({
           key: (.number|tostring),
           value: {
             number, title, phase,
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
    jq -r '
      .tickets as $t
      | .order[] | $t[tostring]
      | select(.status == "pending")
      | select([ .blocked_by[] | $t[tostring].status ] | all(. == "merged"))
      | .number' "$L"
    ;;

  tally)
    jq -r '[.tickets[].status]
      | ((map(select(. == "merged")) | length | tostring) + " shipped · ")
      + ((map(select(. == "failed")) | length | tostring) + " failed · ")
      + ((map(select(. != "merged" and . != "failed" and . != "pending")) | length | tostring) + " need you")' "$L"
    ;;

  *) printf 'unknown subcommand: %s\n' "$cmd" >&2; exit 2 ;;
esac
