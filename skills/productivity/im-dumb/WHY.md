# Why `im-dumb` exists

## The premise

Default assistant output is written for someone who already speaks the domain. That's the right
default most of the time, but it's the wrong register the moment a person just wants the gist —
they don't want to parse jargon to find out what actually happened or what to do next. Asking
"can you explain that more simply" mid-conversation works, but it's friction the person has to
remember to add every time, and the re-explanation they get back is inconsistent in tone.

`im-dumb` makes "explain it like a person, not a spec" a single, repeatable command instead of a
one-off request that has to be re-negotiated each time.

## Why plain language, not shorter language

This is the inverse of [`terse`](../terse/SKILL.md). Terse compresses for someone who already has the context and
wants fewer words. This skill expands and simplifies for someone who wants the *same* information
carried by different, friendlier words — plain vocabulary, short sentences, emojis as visual
anchors. Optimizing for scan-and-absorb, not for token count.

## Why artifacts are the exception, not the default

A wall of chat text defeats the purpose of an "easy to read" skill just as much as jargon does.
But firing off a designed HTML page for every three-sentence answer is worse — it adds a click
where none was needed. The artifact path is reserved for the case where the source material is
genuinely large and a real page layout (headers, cards, visual grouping) would help more than a
chat message ever could. Below that bar, chat is the plain-language reader's home turf.

## Why it's user-invoked

This skill changes voice completely — from technical assistant to plain-spoken friend. That's a
deliberate mode switch the person has to choose, not something that should fire on its own
whenever a response looks complicated. Its `name` and `description` cost nothing until called.

## When not to use

When the person wants the technical depth restored — that's just the normal, ungated response, no
skill needed. And not for content that's already plain (a one-line yes/no answer doesn't need
translating).
