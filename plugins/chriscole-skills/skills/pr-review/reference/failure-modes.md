# Failure modes

Each entry is a situation, then what to do about it. Do not improvise past one of these.


- **An agent definition is missing** (`pr-review-finder`, `pr-review-verifier` are not in the agent list — they ship alongside this skill, in the same plugin or in `~/.claude/agents/`) → spawn `general-purpose` and paste the missing contract into the prompt. Say in the report that reasoning effort was uncontrolled: effort is a frontmatter field, and the `Agent` tool has no argument for it.
- **The build takes too long, or does not run here** → say so and continue. Do not have an agent guess at compile errors; a model speculating about whether code builds is the least reliable finding you can produce.
- **Every finding gets refuted** → report that honestly, and do not resurrect one to fill the page. A refuted finding is the system working. If it happens on every PR, the finder's bar is too low — check whether it is reporting smells with a consequence bolted on.
- **A skeptic confirms a finding by widening it** → its verdict does not apply to the claim you asked about. Treat the claim as refuted, and put the wider version through its own verification rather than reporting it on the strength of the old one.
- **The finder returns prose instead of the schema** → re-run that one agent. Do not hand-convert its prose; the schema fields are the discipline, and a defect with no stated consequence is the thing being filtered out.
- **The PR has no description** → say so. Nothing can be dropped as declared intent, and the spec axis has only the code and the tickets to judge against. Do not soften the report to compensate.
- **The profile names a command or skill that does not exist here** → say so in one line and continue without it. A profile can rot; a review that stops because of it is worse than one that says which check it could not run.
- **A profile pass wants something interactive** — a login, a credential, a click — → never supply it yourself. Ask the user to do that one thing, then carry on. If they decline, the pass is skipped and the report says so.
- **7a dropped everything** → check you were not demanding proof of an incident. The test is whether a person can meet the fault, not whether one already has. "No bug report exists" is not a refutation, and neither is "the tests pass".
- **The usage map is empty for a changed file** → say so and let the finder judge it. Dead code is a real answer, and so is "the grep missed a dynamic import". Do not treat an empty line as proof that nothing calls it.
- **Every confirmed finding has a vague `REPRO`** → the skeptics are agreeing rather than testing. Re-run the worst one with the repro requirement quoted back at it.
- **Empty diff** → wrong fixed point, or a stale `pr-review.last-*` from a force-push. Check `git log --oneline <fixed-point>..HEAD`, and clear the config value if the branch was rewritten.
