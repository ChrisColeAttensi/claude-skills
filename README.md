# claude-skills

Personal Claude Code skills, packaged as a plugin marketplace so they can be installed on any
machine instead of hand-copied into `~/.claude/`.

Private repo — installing needs a `git` that can clone it (the `gh` credential helper is enough:
`gh auth setup-git`).

## Install on a new machine

```
/plugin marketplace add ChrisColeAttensi/claude-skills
/plugin install pr-review@chriscole
```

Then restart Claude Code. `/pr-review` and the two subagents it spawns are available everywhere,
in every repo.

To pick up later changes: `/plugin update pr-review@chriscole`.

## Plugins

| Plugin | Contents |
|---|---|
| `pr-review` | The `pr-review` skill (`skills/pr-review/`) plus the `pr-review-finder` and `pr-review-verifier` subagents it spawns (`agents/`). All three move together — the skill is broken without the agents. |

## Editing a skill

Edit here, commit, push. On each machine, `/plugin update` pulls it.

Do **not** also keep a copy in `~/.claude/skills/` — two definitions of the same skill name
collide. If a machine has the old hand-installed copy, delete
`~/.claude/skills/pr-review/` and `~/.claude/agents/pr-review-{finder,verifier}.md` after
installing the plugin.

## Adding another skill

1. `plugins/<name>/.claude-plugin/plugin.json` — name, description, version, author.
2. Skills go in `plugins/<name>/skills/<skill-name>/SKILL.md`, agents in `plugins/<name>/agents/`.
3. Add an entry to the `plugins` array in `.claude-plugin/marketplace.json`.

An existing plugin can hold several skills; a new plugin is for things you'd want to install
independently.
