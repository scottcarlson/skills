---
name: pr-description
description: Write (or rewrite) a scannable, emoji'd description for an existing GitHub PR — drawing on this session's own memory of the work when it did the work, otherwise deriving intent fresh from the diff/commits, optionally sharpened by a JIRA ticket (Figma/Notion links included), and enriched with screenshots from a local dev server or Figma when available. Checks the repo's CLAUDE.md/CLAUDE.local.md/AGENTS.md for conventions on running the app and taking screenshots. Callable directly or from another skill's own instructions. Invoke with a PR id (`#123`, `PR-123`, `PR123`, a number, or a PR URL), optionally a JIRA id (`ABC-123`), and optionally a free-text context note in quotes.
disable-model-invocation: true
---

# PR Description

Turns an existing PR into a description people actually want to read: a punchy opener, a scannable summary (tables where a list has parallel shape, screenshots where visuals help), and the technical weeds tucked into a collapsible section underneath — not a wall of text up front.

**Callable from another skill.** A calling skill (e.g. a work-completion or ticket-to-PR pipeline) can invoke this directly with its three inputs already resolved — PR id, JIRA id, context note — instead of parsing free text. Default behavior still ends by showing the draft and waiting for a go-ahead before posting (see step 7); a caller that owns its own confirmation moment can say so explicitly and receive just the drafted markdown instead.

This edits an existing PR's description — team-visible, and it overwrites whatever's there now. Confirm with me before step 7's `gh pr edit`.

## Process

### 1. Parse the arguments

- **PR id** (required): `#123`, `PR123`, `PR-123`, a bare `123`, or a full `github.com/.../pull/123` URL. Normalize to the bare number. If a URL was given and it points to a different repo than the current directory's remote, target that repo explicitly (`-R owner/repo`) on every `gh` call below rather than assuming the local remote.
- **JIRA id** (optional): scan the remaining tokens for one shaped like `ABC-123`. If found, it sharpens the write-up (step 3); if absent, skip step 3 — describe the PR on its own merits.
- **Context note** (optional): whatever text is left after pulling out the PR id and JIRA id, quotes stripped. Treat it as a standing instruction layered on top of the defaults below — e.g. "the dev server's running, include screenshots," "keep it short," "don't mention the migration, that's a separate PR." Re-check it at every step below rather than reading it once and forgetting it.

If the PR id is missing, ask before doing anything else.

### 2. Resolve the repo and fetch the PR

```
gh pr view <num> --json number,title,body,headRefName,baseRefName,url,author,state
gh pr diff <num>
```

Also grab the commit list (`gh pr view <num> --json commits` or `git log <base>..<head> --oneline`) — commit messages are often the highest-signal summary of intent available, session context or not.

Note the current `body` before you overwrite it: if it's an unfilled template or empty, replace it wholesale; if it holds boilerplate you didn't author and shouldn't remove (a compliance checklist, an org-required section), preserve those specific pieces and write around them instead of deleting them. Note `state` too — if the PR is already merged or closed, you're still writing a useful historical record, just don't phrase it as "please review."

Completion: you can state the PR's title, branch, diff, and current body's content in one sentence.

### 3. Establish what you actually know

Before drafting anything, decide honestly which of these you're in:

- **You (this session) did the work** — the current branch matches `headRefName`, and you recall writing these commits earlier in this conversation. If so, that lived context — *why* a decision was made, tradeoffs weighed, dead ends hit — is your primary source. Use the diff to verify accuracy and pull concrete file references, not to reconstruct intent you already have.
- **You didn't** — fresh session, someone else's PR, or a different repo entirely. You have no lived context, and shouldn't invent any. Derive intent purely from the diff, commit messages, the PR's own title/description, and (if given) the JIRA brief from step 3 below.

This determines how much of the "why" you can responsibly write versus how much you should stick to describing "what."

### 4. Gather JIRA context (only if a JIRA id was given)

Same sourcing order as `/jira-intake` and `/pr-review`:

1. Check `.ig.jira-tickets/<id-lowercased>-*/` at the repo root for a cached `TICKET.md`/`JIRA-TICKET.md` and any supplemental assets.
2. Fetch the ticket live via the Atlassian MCP (`getJiraIssue`; `getAccessibleAtlassianResources` first for the `cloudId`). Live fetch wins over the cache when both exist.
3. Scan the ticket body and linked docs for `figma.com` links → Figma MCP (`get_design_context`, `get_metadata`); `notion.so` links → Notion MCP (`notion-fetch`).
4. If the MCP is unreachable, fall back to the cache and say so plainly.

Distill an **intent brief**: what problem this solves, why, and what the design (if any) implies it should look like. This feeds the opener in step 6 and tells you what's worth screenshotting in step 5.

### 5. Check repo conventions for running and screenshotting the app

Best-effort — look at the repo root (and skip quietly if none exist): `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`. You're looking for anything that tells you how *this* project wants to be run and shown off:

- A local dev server start command and port.
- Any documented screenshot tooling or workflow (the project may already have one).
- PR description conventions specific to this repo (a required section, a preferred tone) — fold these in rather than overriding them.
- Testing conventions — if the repo has no test suite, don't draft a "Testing" section implying one exists.

Note plainly what you found (or didn't) — this is input to step 6, not a report you show me.

### 6. Decide on visuals — dev server, Figma, or neither

Only chase visuals if the diff actually touches something visible (templates, components, styles) — don't manufacture a screenshot section for a backend-only PR.

- **Local dev server:** check the context note for an explicit signal (e.g. "the dev server's running"), and check step 5's findings for how to start one. Then check whether a browser-automation or screenshot tool is actually connected this session (`ToolSearch` for something like "screenshot browser navigate" — don't assume one exists just because other repos have used one). If a server's reachable and a screenshot tool is available, capture the relevant route(s) — before/after, or desktop/mobile, whatever the change calls for.
- **Figma:** if step 4 turned up a linked Figma file, pull a design screenshot via the Figma MCP `get_screenshot` — useful either alongside a live capture (design vs. built) or on its own if no dev server is reachable.
- **Neither available:** skip screenshots and say so plainly in your own notes. Don't fabricate a placeholder or claim a capture you didn't take.

**Hosting captured images:** `gh` has no native "attach an image to a PR body" command. Follow the working pattern: save captures locally, then commit them to a dedicated media branch (e.g. `pr-media-<num>` or reuse one already used for this ticket) — don't push yet, that happens together with the description update in step 7. Reference them in the draft via `https://github.com/<owner>/<repo>/raw/<branch>/<path>`.

Completion: either a set of captured images with a hosting branch staged locally, or an explicit, honest note that none were available.

### 7. Draft, confirm, then update the PR

Draft the description. Adapt structure to what this PR actually has — don't force a section that doesn't apply:

```markdown
## <emoji> <punchy one-line title>

<1-3 sentences: what this does and why. Pull the "why" from step 3/4 if you have it; stick to "what" if you don't.>

### <emoji> What's new / changed
<A table when the changes have parallel shape (emoji | short bold label | one-line description) —
it scans faster than a bullet list. Plain bullets when they don't. Skip entirely if the diff is too
small to need summarizing.>

### 📸 Screenshots
<Only if step 6 produced any. One collapsible per feature/section if there are several:>
<details>
<summary><b>Section name</b> — one-line what it shows</summary>

<img src="https://github.com/<owner>/<repo>/raw/<media-branch>/<file>.png" width="900">

</details>

<details>
<summary>🔧 Technical details</summary>

Whatever would overwhelm a first read: architecture notes, key files touched, tricky bits, tradeoffs,
testing performed, rollout/migration notes. This is where the depth lives.

</details>

### 📋 Context
<Only the links that exist — omit any that don't:>
- JIRA: <id>
- Figma: <link>
```

**Stop here and show me** the full draft, plus a one-line note on anything from the current body you're preserving (step 2) and anything you skipped for lack of availability (screenshots, a why-section, etc.). Wait for my go-ahead — this overwrites a team-visible PR description.

If this skill was invoked by another skill that said it owns confirmation itself, hand back the drafted markdown (and the staged media branch, if any) instead of stopping here — it will confirm and post on its own schedule.

Once confirmed:

```
git push -u origin <media-branch>   # only if step 6 staged screenshots
gh pr edit <num> --body-file <path>
```
