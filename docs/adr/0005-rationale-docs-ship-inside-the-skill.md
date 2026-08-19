---
status: accepted
---

# Every skill carries a `WHY.md` inside its own folder

Each skill directory contains a `WHY.md` alongside `SKILL.md`: the premise the skill was built
on, the specific failure it prevents, the constraints it obeys, when not to reach for it, and
how it joins the pipeline on either side. `SKILL.md` points at it in one line. The README links
the same files on GitHub.

## Why inside the skill folder rather than `docs/`

Matt Pocock mirrors his skills into `docs/<bucket>/<skill>.md`, but that exists to feed a
website. These files have a second job: letting a future agent session recover a skill's premise
while working in an unrelated repository. The installer copies **only the skill folder**, so a
`docs/` page would exist on GitHub alone and could never do that job. Placing the file inside
the skill folder makes it ship, and it matches the convention that a skill's reference docs live
inside the skill that owns them.

## Why rationale only, and not full documentation

`SKILL.md` is already the operational spec — arguments, steps, outputs. Duplicating any of that
into a second file guarantees the two drift. The genuine gap is *why*, which `SKILL.md`
deliberately omits in order to stay short enough to load cheaply.

## Consequences

- These seven files are where the reasoning behind the pipeline survives. Without them the
  design intent lives only in a session handoff document that is not committed.
- A skill is not finished until its `WHY.md` exists. The CI validator does not enforce this,
  because a missing `WHY.md` breaks nobody's install — but a skill without one is undocumented.
