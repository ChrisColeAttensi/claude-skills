# claude-skills

Personal Claude Code skills, packaged as a plugin marketplace so they can be installed on any
machine instead of hand-copied into `~/.claude/`.

Private repo — installing needs a `git` that can clone it (the `gh` credential helper is enough:
`gh auth setup-git`).

## Install on a new machine

```
/plugin marketplace add ChrisColeAttensi/claude-skills
/plugin install chriscole-skills@chriscole
```

Then restart Claude Code. `/chriscole-skills:pr-review` and the two subagents it spawns are
available everywhere, in every repo.

To pick up later changes: `/plugin update chriscole-skills@chriscole`.

## Layout

One plugin, `chriscole-skills`, holding everything. Skills are namespaced by **plugin** name, not
marketplace name, so a skill here is invoked as `chriscole-skills:<skill>`. That is also why new
skills go inside this plugin rather than beside it: adding one needs no new install on any machine.

| Path | Contents |
|---|---|
| `plugins/chriscole-skills/skills/pr-review/` | The `pr-review` skill |
| `plugins/chriscole-skills/agents/` | `pr-review-finder`, `pr-review-verifier` — the subagents pr-review spawns. They move with the skill; it is broken without them. |

## Editing a skill

Edit here, bump `version` in **both** `plugin.json` and the marketplace entry (they must agree, and
without a bump nobody sees the change), commit, push. On each machine,
`claude plugin update chriscole-skills@chriscole`.

Do **not** also keep a copy in `~/.claude/skills/` — two definitions of the same skill name
collide. If a machine has an old hand-installed copy, delete it after installing the plugin.

## Adding a skill

Drop it in `plugins/chriscole-skills/skills/<name>/SKILL.md`, agents in
`plugins/chriscole-skills/agents/`, bump the version in both manifests, push.

A separate plugin is only worth it for something you'd want to install or disable on its own; it
gets its own namespace prefix and its own entry in `.claude-plugin/marketplace.json`.

## Renames

`renames` in `marketplace.json` maps a former plugin name to its current one so installed machines
migrate themselves. `pr-review` → `chriscole-skills` is there from the v1.0.0 naming, which
stuttered as `pr-review:pr-review`.
