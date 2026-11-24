---
name: grill-for-refinement
description: Sharpen a single JIRA ticket to refinement-ready. Interviews you with a refinement lens — acceptance criteria, edge cases, scope, definition of done — rather than an implementation lens, then drafts a summary comment and posts it once you confirm. Invoke with a ticket id, e.g. `/grill-for-refinement ABC-123`.
---

# Grill for Refinement

*Why this skill exists, the failure it prevents, and when not to use it: [WHY.md](./WHY.md).*

Interview me about a single JIRA ticket to sharpen it before a team refinement meeting — purely ephemeral, no local files: fetch live, grill, draft a comment, post on confirmation.

The argument is a JIRA ticket id (e.g. `ABC-123`). If it's missing from the invocation, ask me for it before doing anything else.

## Process

### 1. Fetch the ticket

Fetch the ticket live via the **Atlassian MCP** `getJiraIssue` (call `getAccessibleAtlassianResources` first if you need the `cloudId`). Capture summary, description, status, issue type, labels, and all comments — this is the source of truth for the interview.

This skill has no local fallback — if the MCP is unreachable or the id isn't found, say so plainly and stop rather than guessing at ticket content.

### 2. Pull in linked context (best-effort)

Scan the description and comments for links and fetch what's behind them to sharpen your questions — a prior spike doc or a design gap surfaces much better refinement questions than the ticket text alone. Fetch through subagents, one per link, launched in a single message — each prompt opening by telling the subagent to invoke the `terse` skill and return a digest of what the source implies for refinement. Raw Figma frames, screenshots and long docs never enter your own context; you interview from digests.

- **Figma** (`figma.com` links) → **Figma MCP**: `get_design_context`, `get_screenshot`, `get_metadata`.
- **Notion** (`notion.so` links, e.g. a prior spike write-up) → **Notion MCP**: `notion-fetch` on the link (or `notion-search` if it isn't directly fetchable).
- **Google Docs / Sheets / Drive** (`docs.google.com`, `sheets.google.com`, `drive.google.com` links, e.g. a Google Chat/Gemini summary doc) → **Google Drive MCP**: `get_file_metadata` then `read_file_content` or `download_file_content`.

Best-effort only: if a link 404s or access is denied, note that in your own context and move on — don't let it block the interview.

### 2b. Check for an independent second planner

Check whether Gemini 4 Neon is connected:

```
command -v agy && agy models | grep -q '^gemini-4-neon-high'
```

If it isn't, say so in one line and run step 3 single-planner, exactly as before. If it is, Neon at high thinking is planner B for every round of step 3 — you are planner A.

### 3. Grill — refinement lens, not implementation

Call the Skill tool with `"grilling"` and run the interview by its mechanics. Don't restate them here — whatever version is installed defines how the interview runs, and this skill should never need re-syncing when that changes.

This skill owns the **lens**, not the mechanics.

Keep questions scoped to **refinement**, not implementation — don't ask how something should be built in code unless the ticket itself explicitly raises a technical concern. Draw on whatever's actually thin on *this* ticket (informed by step 2's context) rather than working a canned checklist top to bottom. Typical refinement gaps to probe:

- Are the acceptance criteria complete, specific, and testable?
- Edge cases and error/empty states the ticket doesn't address
- Scope boundaries — what's explicitly out vs. silently assumed
- Dependencies on other tickets, teams, data, or third-party services
- Definition of done — does it include tests, docs, rollout/flagging, analytics?
- UX or business-rule ambiguities the design/linked docs don't resolve
- Whether this is sized right, or is hiding more than one ticket
- If a linked spike/Notion doc exists — does the ticket still reflect its conclusions, or has something drifted?

If the ticket is already solid and nothing substantive surfaces, say so plainly rather than manufacturing filler questions.

**Two planners per round, when Neon is available.** This changes what goes *into* each round, not how `grilling` runs it. Before putting a round to me:

1. Write a self-contained **round brief** to `$TMPDIR` (not the repo — this skill leaves no files behind): the ticket text, the step 2 digests, the refinement lens above, and what's been resolved or left open so far. Not your own draft questions.
2. Draft planner A's round — questions and recommended answers — **before** reading planner B's.
3. Run planner B blind, headless and read-only, with the brief inline, in a fresh call per round:

   ```
   agy -p "$(cat <round-brief>)" --model gemini-4-neon-high --mode plan --output-format json
   ```

   Open the brief with "Everything you need is in this prompt; do not run commands or read files." — in `--mode plan` its shell is denied, and pointing it at a file instead of inlining makes it stop without answering. Read the `response` field. Never pass `--dangerously-skip-permissions`. On error, one retry; then run that round single-planner and say so.
4. **Merge, then ask.** Dedupe the two lists. A question only one planner raised goes in if it earns it under the lens. Where both recommend the same answer, say so; where they differ, show me both and which you'd take and why. Hold planner B to the refinement lens too — drop implementation questions it raises unless the ticket invites them.

**Codex as a third view or tie-breaker** (`codex:codex-rescue`), only when you judge it worth it — the planners split on something that changes scope or acceptance criteria, or agree so readily you suspect a shared blind spot. Give it the round brief blind for a third view, or the brief plus both positions to adjudicate. You still decide what to put to me.

Delete the round briefs when the session ends.

### 4. Route each answer

For every question asked:

- **I answer it** → record it as a resolved point (question + my answer).
- **I can't answer it** → record it as an open item for the team to discuss at refinement.

### 5. Draft the comment, confirm, then post

At the end of the session, draft **one** comment combining both lists (omit either section if it's empty):

```markdown
**Refinement notes**

Resolved during ai pre-refinement:
- Q: <question> — A: <my answer>
- Q: <question> — A: <my answer>

Open questions for team refinement:
- <question the team needs to answer>
- <question the team needs to answer>
```

Show me the full draft and **wait for my go-ahead** — posting a comment is visible to the whole team, so never post without confirmation. Once I confirm, post it via the Atlassian MCP `addCommentToJiraIssue`. If I ask for changes, revise and re-confirm before posting.
