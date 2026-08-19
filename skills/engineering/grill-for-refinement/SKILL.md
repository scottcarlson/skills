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

Scan the description and comments for links and fetch what's behind them to sharpen your questions — a prior spike doc or a design gap surfaces much better refinement questions than the ticket text alone:

- **Figma** (`figma.com` links) → **Figma MCP**: `get_design_context`, `get_screenshot`, `get_metadata`.
- **Notion** (`notion.so` links, e.g. a prior spike write-up) → **Notion MCP**: `notion-fetch` on the link (or `notion-search` if it isn't directly fetchable).
- **Google Docs / Sheets / Drive** (`docs.google.com`, `sheets.google.com`, `drive.google.com` links, e.g. a Google Chat/Gemini summary doc) → **Google Drive MCP**: `get_file_metadata` then `read_file_content` or `download_file_content`.

Best-effort only: if a link 404s or access is denied, note that in your own context and move on — don't let it block the interview.

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
