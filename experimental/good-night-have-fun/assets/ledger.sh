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
#   ledger.sh tally  <dir>                            # one-line summary counts

set -uo pipefail
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
      '{
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
       # become ready. Mark it now; `ready` then holds its whole subtree too.
       | .tickets = (reduce .external_blocks[] as $x (.tickets;
           .[$x.ticket|tostring] |= (.status = "blocked_external"
                                     | .external_blocked_by += [$x.blocked_by])))' \
      "$graph" > "$tmp" \
      || { rm -f "$tmp"; printf 'FATAL: could not build the ledger from %s\n' "$graph" >&2; exit 1; }
    mv "$tmp" "$L"
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
                                       "blocked_by_failure", "blocked_external") | not)
        then error("unknown status: \($v)")
      else .tickets[$t][$f] = $v end' "$L" > "$tmp" \
      || { rm -f "$tmp"; exit 1; }
    mv "$tmp" "$L"
    ;;

  ready)
    # A ticket is ready when it is pending and every blocker has merged.
    # needs_human and failed blockers deliberately do NOT unblock: they prune
    # their subtree instead of halting the run.
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
      + ((map(select(. == "needs_human" or . == "blocked_by_failure" or . == "blocked_external")) | length | tostring) + " need you")' "$L"
    ;;

  *) printf 'unknown subcommand: %s\n' "$cmd" >&2; exit 2 ;;
esac
