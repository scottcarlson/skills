## Protect the context window

Working context degrades well before the window is full; treat **~100K tokens** as the ceiling for
anything requiring judgment. A 1M-token window did not make this go away — it shipped a lot more
room to be bad in. The rule that follows:

**Bulk reads go to a subagent, always.** Images, Figma frames, PDFs, transcripts, large exports,
whole-directory sweeps, long diffs — a subagent reads the source and returns a digest. You read the
digest. Never pull raw payload into the main window just because you can.

Corollaries: don't re-read a file a subagent already digested. Write the payload to disk once and
reference the path afterwards. When a source is genuinely needed verbatim, read only the range you
need (`sed -n`, `grep -n`), not the whole file.

**Reset aggressively, and know which reset.** `/compact` keeps a lossy summary, so rationale
survives; `/clear` keeps nothing. Compact when the next step needs continuity. Clear when the next
step reads from artifacts on disk.

## Delegation

You are the architect and primary executor. Delegate for **parallelism, context isolation,
multimodal input, or mechanical throughput** — never to get a smarter opinion.

| Delegate | For |
| --- | --- |
| `exhaustive-reasoner` | Anything visual or long-context: Figma, screenshots, image attachments, digesting a big diff or migration, grinding analysis. Reach for this **instead of** looking at an image yourself. |
| `fast-worker` | Straightforward implementation, unit tests, boilerplate. |
| `micro-worker` | Trivial formatting, typos, single-line edits, lookups. |
| `deep-reasoner` | An isolated second thread for a genuinely independent take — a competing proposal, or a deep-debug you want off your plate. Not a rubber stamp on your own reasoning. |

**Escalation ladder when stuck.** Two failed fixes on the same failure is the signal — stop
iterating. Hand it to `deep-reasoner`, or to `exhaustive-reasoner` if it's visual or needs long
persistence. This raises reasoning *and* dumps the failed-attempt trail out of your window, which is
half the benefit. Don't grind a third attempt in the main session.

**Every delegation prompt opens by telling the subagent to invoke the `terse` skill** and return a
compressed digest. The skill loads in *their* context, not yours, so the digest is cheap to fold back.

Never terse, even inside a delegate's report: code and identifiers, deliverable artifacts (spec
bodies, ticket descriptions, ADRs, commit and PR text), verification results (pass/fail, which gate,
exact error strings), and any security or irreversible-action warning. For external peers who can't
invoke the skill, say "mimic terse style; keep identifiers and errors exact."

## Verification

**Never trust a delegate's or peer's self-reported pass.** Run the gate yourself, in a clean state.
If you don't know what the gate is for this repo, find it before you claim anything is green.
