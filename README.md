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

Then restart Claude Code. `/chriscole-skills:pr-review` (and `/chriscole-skills:pr-review loop`) and the subagents it spawns are
available everywhere, in every repo.

To pick up later changes: `/plugin update chriscole-skills@chriscole`.

## Layout

One plugin, `chriscole-skills`, holding everything. Skills are namespaced by **plugin** name, not
marketplace name, so a skill here is invoked as `chriscole-skills:<skill>`. That is also why new
skills go inside this plugin rather than beside it: adding one needs no new install on any machine.

| Path | Contents |
|---|---|
| `plugins/chriscole-skills/skills/pr-review/` | The `pr-review` skill. Its fix loop lives in `reference/loop.md`: fix test-first in subagents, prove each fix, re-review, then verify the whole PR before calling it green — one round on "fix", or until green with `/pr-review loop`. |
| `plugins/chriscole-skills/agents/` | `pr-review-finder`, `pr-review-verifier`, `pr-review-live-checker`, `pr-review-decider` and `pr-review-fixer` — the subagents pr-review spawns. They move with the skill; the skill is broken without them. |
| `scripts/review-stats.py` | Cost and latency of one `/pr-review` run, read back from its session transcript. Per-agent turns, tokens and minutes. |

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

## pr-review: why it splits finders

Measured on one 14-file PR, against a single-finder run of the same diff: three finders cut the
critical path from 23.6 to 10.0 minutes (finding alone, 22.6 to 8.4) and found six confirmed
defects against three, for about 1.4x the tokens. Each finder still reads the siblings it needs, so
turns go up, not down. The split buys latency and recall, not economy. Agents also do not batch
tool calls: over 87 finder calls under an explicit batching rule, none were batched.

## pr-review: which model runs which agent

`pr-review-live-checker` runs on Sonnet. Against planted bugs with known answers — dummy mode
(3 runs each) and a real staging project (2 runs each, read-only) — Opus and Sonnet both got
every premise point and every finding right (24/24 premise points, 35/35 findings each), at about
the same tokens and slightly faster for Sonnet. Haiku, run once, reported a false repro
(it never checked the search box held what it typed) and used 2–3x the tokens. Both Opus and
Sonnet mislabelled the overall premise verdict until `partial` was defined in the agent.

`pr-review-verifier` stays on Opus. Replaying 29 past claims at their commits, with a blind Opus
judge on disagreements: Opus 28/29, Sonnet 26/29, Haiku 25/29 — Haiku's misses dismissed real
bugs, and it used about 2x the tokens. Sonnet's gap is within noise at this sample; rerun with a
larger one before moving it.
