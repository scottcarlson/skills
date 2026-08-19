---
name: pr-review
description: Review an existing GitHub pull request — incorporating GitHub Copilot's review comments if it's run one, and optionally sharpened by a JIRA ticket's full context (Figma/Notion links included) — then open a follow-up PR back into it with fixes applied one-commit-per-change and a scannable, emoji'd description. Codex peer-reviews the review (including Copilot's findings) before anything gets written. Invoke with a PR id (`#123`, `PR-123`, `PR123`, a number, or a PR URL), optionally a JIRA ticket id (`ABC-123`), and optionally a free-text context note in quotes.
disable-model-invocation: true
---

# PR Review → Fix → Follow-up PR

Takes an existing GitHub PR, reviews it (optionally sharpened by a JIRA ticket's full context), folds in GitHub Copilot's review comments, gets the combined findings peer-reviewed by Codex, then implements the survivors as one commit per change on a new branch and opens a follow-up PR **back into the original PR's branch** — with a description built to be skimmed in ten seconds, not read top to bottom.

This creates branches, commits, pushes, and opens a PR — all team-visible, hard-to-reverse actions. Confirm with me before the push/PR-creation step (see step 8); never run this end-to-end unattended.

## Process

### 0. Model and effort check

This is a full code-review-plus-implementation pass — run it underpowered and the review is shallow and the fixes are sloppy. Check the active model and reasoning effort. If the model isn't Opus 5 or the effort isn't `high`/`xhigh`, tell me what's currently set and **wait for my confirmation** before continuing — I may want to switch first, or may have a reason to keep the current setup.

### 1. Parse the arguments

- **PR id** (required): accept `#123`, `PR123`, `PR-123`, a bare `123`, or a full `github.com/.../pull/123` URL. Normalize to the bare number.
- **JIRA id** (optional): a second token shaped like `ABC-123`. If present, this ticket sharpens the review; if absent, the PR is reviewed on its own merits — skip step 4 with no spec brief.
- **Context note** (optional): whatever text is left after pulling out the PR id and JIRA id, quotes stripped. Treat it as a standing instruction layered on top of the defaults in every step below — e.g. "focus on the payment logic," "skip nice-to-haves," "don't touch the test files," "keep the description short." Re-check it at each step rather than reading it once and forgetting it; it can shape review scope (step 5), which categories you bother assigning (step 7), what you're willing to touch (step 8), and tone (step 10).

If the PR id is missing or ambiguous, ask before doing anything else.

### 2. Resolve the repo and fetch the PR

Confirm the current directory is a git repo with a GitHub remote (`gh repo view`). Then pull the PR's metadata:

```
gh pr view <num> --json number,title,body,headRefName,baseRefName,headRepositoryOwner,url,author,state
gh pr diff <num>
```

Note `headRefName` (the PR's branch — your new branch forks from here and your follow-up PR targets here, **not** `main`) and whether `headRepositoryOwner` differs from this repo's owner (a fork — flag this now, see the caveat in step 8). Completion: you can state the PR's title, branch, and diff in one sentence.

### 3. Check for a GitHub Copilot review

Before reviewing anything yourself, check whether Copilot has already reviewed this PR — its findings are a review input, not optional flavor, so they need to exist before step 6 can fold them in.

```
gh pr view <num> --json reviews,reviewRequests --jq '.reviews[].author.login, .reviewRequests[].login'
```

(Bot logins vary slightly by GitHub instance/version — grep the output case-insensitively for `copilot`.)

- **Copilot appears in `reviews`** → it's run. Continue to step 4.
- **Copilot appears in `reviewRequests` but not `reviews`** → it's been requested but hasn't finished. Tell me it's still pending and wait — don't proceed on a partial review.
- **Copilot appears in neither** → **stop and tell me to request it**: open the PR on GitHub, open the Reviewers panel, and add Copilot as a reviewer (or, if this CLI/org supports it, `gh pr edit <num> --add-reviewer copilot-pull-request-reviewer`). Wait for me to confirm it's done, or for it to show up in `reviews`, before continuing — don't review the PR yourself in the meantime and then bolt Copilot's take on after the fact.

Completion: Copilot's review is present in `reviews`, or I've explicitly told you to proceed without it.

### 4. Gather JIRA context (only if a JIRA id was given)

Follow the same sourcing order as `/jira-intake`:

1. Check `.ig.jira-tickets/<id-lowercased>-*/` at the repo root for a cached `TICKET.md`/`JIRA-TICKET.md` and any supplemental assets (Figma links, Slack/Meet notes, before/after images).
2. Fetch the ticket live via the Atlassian MCP (`getJiraIssue`; `getAccessibleAtlassianResources` first if you need the `cloudId`). This live fetch wins over the cache when both exist.
3. Scan the ticket body and any linked docs for `figma.com` links → pull via the Figma MCP (`get_design_context`, `get_screenshot`). Scan for Notion links → pull via the Notion MCP (`notion-fetch`).
4. If the MCP is unreachable, fall back to the cached export and say so plainly.

Distill this into a short **spec brief**: what the ticket asks for, key constraints, what the design implies. This is your Spec-axis source for step 5 — don't let the review skill re-derive it from scratch.

### 5. Check out the PR and review it yourself

```
gh pr checkout <num>
git checkout -b review/pr-<num>
```

(If this repo has no write access to a fork's branch, `checkout` still works locally — you just can't push a branch into the fork later; see step 8's caveat.)

Diff against the merge-base with the PR's base branch: `git diff origin/<baseRefName>...HEAD`.

Run the same **two-axis method as the `code-review` skill** — Standards and Spec, in parallel sub-agents, using its smell baseline for the Standards axis. Override its own spec-discovery step: your spec source is already resolved —

- **If a JIRA id was given:** the spec brief from step 4.
- **If not:** the PR's own title/description — reviewing "does this PR do what it says it does," not against any external spec.

Completion: two findings lists (Standards, Spec), each finding citing a file/line and the specific rule or expectation it fails.

### 6. Fold in Copilot's findings

Pull Copilot's actual comments, not just the fact that it reviewed:

```
gh api repos/{owner}/{repo}/pulls/<num>/comments --paginate
gh api repos/{owner}/{repo}/pulls/<num>/reviews
```

Filter both to the Copilot bot's entries. For each Copilot comment, do your own sanity check before it joins the pile — read the referenced hunk yourself and form an independent view of whether it's right, overstated, or off-base. Add it to the combined findings list as its own entry, tagged `source: copilot`, alongside your `source: standards`/`source: spec` findings from step 5. Note your own preliminary verdict on each — this isn't the final word (Codex checks it too in step 7), but don't forward a Copilot comment you already think is wrong without flagging that.

Completion: one combined findings list, every entry tagged with its source (`standards`, `spec`, or `copilot`) and your preliminary take on the Copilot-sourced ones.

### 7. Have Codex peer-review the combined findings

Before acting on anything from steps 5–6, get an independent read on the *entire* combined list — your own findings and Copilot's — this catches false positives and blind spots before they become commits. Send Codex (`codex:codex-rescue`) the full list plus the diff and ask it to:

- flag any finding — yours or Copilot's — it thinks is wrong, overstated, or not worth fixing, with reasoning;
- flag anything real it thinks was missed;
- give a one-line verdict per finding: keep, drop, or modify.

Reconcile: for each finding, if Codex disputes it, weigh its reasoning against your own (and, for Copilot findings, your step-6 preliminary take) and decide — you're the final judge, not a pass-through, on every source including Copilot's. Keep code, identifiers, and the finding list itself full-fidelity in Codex's response; only the surrounding commentary should be caveman-terse (per the low-token delegation contract other skills here use).

While reconciling, also assign each surviving finding a **category** — this is what lets me and other reviewers tell a must-fix from a nice-to-have at a glance, and group cherry-picks by concern. Don't force a fixed taxonomy; pick categories that fit what actually turned up, but always keep hard-blockers separate from optional polish and break out anything that reshapes structure rather than patches a spot. A set that usually covers it:

- 🚨 **Critical** — bugs, security holes, correctness issues; would block merge on its own.
- 🏗️ **Architectural** — bigger-picture design/structure improvements, not a one-line fix.
- ⚡ **Performance** — measurable efficiency issues.
- 🧹 **Cleanup** — dead code, naming, style, minor duplication.
- 💡 **Nice-to-have** — worth doing, nobody's blocked without it.

Collapse or rename these freely (e.g. skip Performance if nothing qualifies, or add a Testing category if gaps turned up) — the goal is categories that actually earn their keep for *this* PR, not a checklist to fill.

Completion: a final, reconciled list of findings you're actually going to fix, each tagged by source **and** category, with a one-line note on why it survived (or why you or Codex overrode it).

### 8. Implement the fixes — one commit per change

For each surviving finding, make the change and commit it on its own — never batch unrelated fixes into one commit, and never fold two categories into one commit even if they touch the same file. This is what lets someone cherry-pick "just the critical fixes" or skip the nice-to-haves cleanly. Order the commits by category severity (Critical first, then Architectural, then the rest) so the log itself reads most-important-first. Commit message: a plain description of the fix, e.g. `fix: guard against nil pointer in pagination cursor`. Don't reference the PR-review process, Copilot, or the category label in the commit message itself (that belongs in the follow-up PR's description, not git history).

Completion: `git log origin/<baseRefName>..HEAD --oneline` shows exactly one commit per surviving finding, ordered by category severity.

### 9. Confirm, then push and open the follow-up PR

**Stop here and show me:** the commit list from step 8, and the drafted PR description (step 10). Wait for my go-ahead before pushing or opening anything — this is the team-visible, hard-to-reverse step.

Once confirmed:

```
git push -u origin review/pr-<num>
gh pr create --base <headRefName> --head review/pr-<num> --title "<title>" --body-file <path>
```

**Fork caveat:** if step 2 flagged the original PR as coming from a fork you don't have push access to, `git push` here will fail. Tell me and offer the fallback: post the findings and diff as a **comment on the original PR** (`gh pr comment <num> --body-file <path>`) instead of a follow-up PR.

### 10. Write the follow-up PR description

Optimize for skimming, not reading — lead with what's a must-fix, let categories do the sorting so nobody has to read the whole thing to find the one blocking issue. Structure:

```markdown
## 🔍 Follow-up review for #<num>

One or two sentences: what this PR reviewed and the overall take — call out up front if there's anything in 🚨 Critical.

### 🚨 Critical
- **<short title>** — <one-line what/why>
  <details><summary>Details</summary>

  Technical specifics: what was wrong, the fix, file(s) touched.

  </details>

### 🏗️ Architectural
- 🤖 **<short title>** *(from Copilot's review)* — <one-line what/why>
  <details><summary>Details</summary>

  Copilot's original comment, why it held up, the fix.

  </details>

### 🧹 Cleanup
- **<short title>** — <one-line what/why>
  <details><summary>Details</summary>

  ...

  </details>

### 🤝 Peer-reviewed by Codex
One or two lines: what Codex flagged, what got kept vs. dropped as a result — across your findings and Copilot's.

### 📋 Context
- Original PR: #<num>
- JIRA: <id> (omit this line if none was given)
```

One category section per category that survived step 7, in severity order, each holding its bullets in commit order. Omit any category with nothing in it — don't print an empty "Performance" section for symmetry. Mark Copilot-sourced bullets with the 🤖 *(from Copilot's review)* tag so credit is visible at a glance regardless of which category they landed in. Keep each top-level bullet to one line; everything technical (diff snippets, reasoning, alternatives considered) goes inside its `<details>` dropdown so the description reads as a scannable list first, deep-dive second.
