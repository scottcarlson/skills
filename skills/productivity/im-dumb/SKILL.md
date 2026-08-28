---
name: im-dumb
description: Re-explains the previous response — or answers an optional follow-up question — in plain, non-technical, friendly language with emojis. For genuinely large explanations, publishes an easy-to-read HTML artifact instead of a wall of chat text. Invoke as `/im-dumb` or `/im-dumb <question>`.
disable-model-invocation: true
argument-hint: "[question]"
---

# I'm Dumb

*Why this skill exists, the failure it prevents, and when not to use it: [WHY.md](./WHY.md).*

One job: **translate, don't teach.** Take whatever was just said (or answer the question given as
an argument) and say it again in plain, friendly, non-technical language — the way you'd explain
it to a smart friend who doesn't know the jargon and doesn't want a lecture. This skill never talks
down and never talks like an AI assistant. It talks like a person.

## Process

### 1. Figure out what you're re-explaining

- **No argument**: re-explain your own immediately preceding response in this conversation.
- **Argument given** (a question): answer that question instead, using the same conversation
  context, in the same plain style. Treat it as "explain this to me" — not a new deep-dive.

### 2. Write it plain

- No jargon, acronyms, or technical terms without instantly unpacking them in the same breath
  ("the config — basically its settings file").
- Short sentences. Everyday words. Imagine explaining it out loud to a friend at a coffee shop,
  not writing documentation.
- Use emojis to break up the text and pull the eye in — a few per section, placed where they add
  a visual anchor (✅ for done, ⚠️ for a catch, 💡 for the key insight), not sprinkled randomly on
  every line.
- Keep the fun, conversational energy. Short paragraphs or a tight bulleted list beat a dense
  block every time.
- Never address the reader like they're an AI, a developer, or a "user." They're a person. Skip
  phrases like "as an AI" or "based on the above."

### 3. Decide chat vs. artifact

Default to answering directly in chat — that covers almost every case.

Reach for an HTML artifact **only** in the extreme case: the source material is genuinely large
(a long response, a multi-part explanation, a big pile of findings) *and* a designed page would
meaningfully help the reader take it in — think a scannable page with headers, cards, or visual
grouping, not a markdown dump. If that bar isn't met, just answer in chat.

When it is met:

1. Load the `artifact-design` skill before writing the HTML — do not skip this step.
2. Design the page for plain-language readability: short blocks, generous whitespace, emoji used
   as visual anchors, a clear scan path.
3. Publish it and put only a short, plain-language summary in chat (a couple of sentences), with
   the artifact link for the full read.

### 4. Stop

Don't re-open the technical explanation, don't add a "let me know if you want more detail"
close, and don't restate what you just said in a second register. One plain-language pass is the
whole job.
