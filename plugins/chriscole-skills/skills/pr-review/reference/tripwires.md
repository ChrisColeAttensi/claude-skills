# Tripwires

A tripwire is a rule this repo has already written down, where breaking it is expensive and
checking it is nearly free. You check them yourself, in the main session, before any agent
runs. They are the highest-yield tokens in the whole review: a grep against the diff, and
the answer is a fact rather than a judgement.

Derive them from the repo, not from memory. Read once, at the start:

- `CLAUDE.md` / `AGENTS.md` at the root, and any nested ones under the touched directories.
- What those files point at: `CONTEXT.md`, `docs/adr/`, `docs/agents/`, contributing guides.
- The repo's own checklist skills. A skill that exists because a change type keeps going
  wrong is a tripwire list someone already wrote for you.

Then keep the ones the diff can actually trip. A tripwire for a file this PR does not touch
costs nothing to skip.

## What makes a good tripwire

Three properties, all of them required:

- **Written down.** It cites a rule in the repo's own docs, so a finding quotes the repo
  rather than your opinion.
- **Cheap to check.** A `git diff` grep, a file-existence test, a name pattern. If it needs
  judgement about behaviour, it belongs to the finder instead.
- **Expensive to miss.** Data corruption, a broken release, a migration that never ran, a
  clone that silently loses a field. Style breaches are not tripwires — the analyzers own
  those, and they never forget.

## Worked example, from this Creator repo

Illustrative, not a fixed list. Re-derive per repo, and update as the docs move.

| Signal in the diff | Rule | Cheap check |
|---|---|---|
| New or changed property on a persisted model (`Creator.Models/**`) | Commits that change persisted shape carry `!` after type/scope, and must ship to stable and insider together | `git log --format=%s <base>..HEAD` — does a subject carry `!`? |
| New persisted field with existing rows | Existing documents need a backfill (`/writing-db-migrations`) | Any new file under the migrations directory in this diff? |
| New entity type, or a new property on one | Cloners and dependency tracking stay in sync (`/modifying-entity-models`) | Does the diff touch the cloner and dependency-graph files for that entity? |
| New `DeploymentType` / deployment record | A 12+ file checklist (`/adding-deployment-type`) | Count the files the checklist names against the files in the diff |
| New tool project | Only Home tools may depend on other Tool projects; prefer `Creator.Business.Abstractions` | Grep the new `.csproj` for `Creator.Tools.*` and `Creator.Business` references |
| New `async` method in a public signature | Async signatures take `CancellationToken cancellationToken = default` | Grep added lines for `async Task` without `CancellationToken` |
| New test | `TestContext.Current.CancellationToken`, never `CancellationToken.None` | Grep added test lines for `CancellationToken.None` |

## How a tripwire becomes a finding

A tripped tripwire skips the finder and goes almost straight to the report. It still needs
one thing: a consequence, in the repo's own terms. "The commit has no `!` marker" is a fact;
"an old client will write `null` over this field on round-trip, and the repo's own rule
exists to prevent exactly that" is a finding.

Tripwires do not need verification — the check was deterministic, so there is nothing for a
skeptic to refute. Send them to the report directly, and say in the report that they came
from the repo's documented rules rather than from a reading of the code.
