# CLAUDE.md

Authoring conventions for this repository. This is a **skills repository** — its product is the
`skills/` tree, distributed to other people's machines by a CLI this repo does not own.

Read [CONTEXT.md](./CONTEXT.md) for the vocabulary and [docs/adr/](./docs/adr/) for why the repo
is shaped the way it is. ADR-0001 in particular explains what distribution channel was chosen and
what was given up.

## Layout

```
skills/<category>/<skill-name>/
├── SKILL.md            required — the operational spec
├── WHY.md              required — the rationale (ADR-0005)
└── agents/openai.yaml  required — Codex interface + invocation policy
```

Categories in use: `engineering`, `productivity`. Directory name **is** the skill name, kebab-case.

**A skill that isn't ready to ship does not go in `skills/`.** There is no manifest; the installer
finds skills by walking `skills/`, so placement is the only curation mechanism (ADR-0002). Put
work-in-progress in a top-level `in-progress/` directory instead, and promote by moving it.

Never move a shipped skill's directory. The installer records its path verbatim in a lockfile on
every user's machine.

## Frontmatter

Exactly four fields are in use, and no others:

| Field | Meaning |
| --- | --- |
| `name` | Must equal the directory name. |
| `description` | For a model-invoked skill this loads into **every** session — keep it tight. For a user-invoked skill it costs installers nothing and reads as help text, so length is fine. |
| `disable-model-invocation: true` | Makes the skill user-invoked. Omit it and the model will fire the skill on its own. |
| `argument-hint` | Optional, for skills taking an argument. |

There is no `version` field. Versions are not how updates work here.

## Depending on another skill

A dependency is an explicit instruction to call the tool, naming one skill:

> Call the Skill tool with `"domain-modeling"`.

One skill per call — two skills is two instructions. A bare `/skill-name` mention means something
different and is reserved for prose telling the **human** what to type next.

**A user-invoked skill can never be called by another skill.** If a skill needs one to have run
first, the only correct move is to tell the user to run it. This is why there is no conductor
skill in this repo: the pipeline works by each skill naming the next command, not by one skill
driving the others.

Depend on Matt Pocock's skills freely — that is the point of this set — but depend on *behaviour*,
not on wording. Delegate to his skill rather than restating its mechanics, or you will be
re-syncing prose every time he ships.

## Codex

Every skill needs `agents/openai.yaml`. `disable-model-invocation` does not carry to Codex; without
the sidecar's `policy.allow_implicit_invocation: false`, user-invoked skills auto-fire there.

## Before committing

```bash
node scripts/validate-skills.mjs
```

`scripts/sync-skills.sh` copies the repo's skills into `~/.agents/skills` and links them into
`~/.claude/skills` for authoring. Run it after every edit, then restart your session. It is not
an installer.

Do **not** symlink a per-agent skill directory straight at this repo. Skill discovery does not
reliably follow a symlink that resolves outside the canonical skills tree, and the skills vanish
from a fresh session with no error.
