# Step 8 — fix or comment

With small findings, a comment is ceremony wrapped around work we could just do.

**Whose branch it is does not enter this decision.** Not the author, not the remote, not whether we can push. Ask only:

- Is every finding a contained edit — a few files, no open design decision?
- Do the repo's checks run locally, so we can prove the fix?

Both yes, fixing wins. Otherwise comment: a finding that needs the author's decision, or a fix that reshapes the change.

**Worth-its-own-PR findings sit outside this decision.** Each one is the user's call: fold it into this branch, or raise it as its own work. Leave them out of the fix batch and the PR comment until the user picks them — a fix to code this PR did not touch grows the diff the author has to defend.

Recommend one in a sentence, with the reason. Then ask: fix these now, post the comment, or fix and post a short note? Ask about the nearby list separately, and name the tracker if the repo has one.

Where the fix **lands** is a separate question, answered after the user picks — never a reason not to do the work. Editing and running checks is local and reversible on any branch. Push when the branch takes our push; otherwise offer `git format-patch`, a branch to pull, or a diff in the comment. Ask before pushing to a branch that is not ours.

**On fix** — one finding at a time, run the checks, report per finding what changed. Anything left alone goes into the comment with the reason.

**On comment** — the same plain language, and **the same layout as 7d**, with three changes for the thread:

- **Demote every heading one level.** `## ✅ Approve` rather than `#`, because GitHub already gives the comment a frame. Everything else keeps its shape — the facts row, the numbered H4 findings, the two-column tables, the rules.
- **Open with one sentence naming the fixed point**, under the verdict heading, so nobody reads a narrowed review as a full one.
- **Drop the 🗂️ footer.** That file is for us, not for the thread.

Quote the author back to themselves on any declared finding and say why it still stands. Show the full draft, then ask before posting.

```bash
gh pr comment <number> --body-file <file>
```

Write the body to a scratch file first, so the markdown survives the shell.

Finally, record where this review reached, so the next one starts here:

```bash
git config --local pr-review.last-<pr-number> $(git rev-parse HEAD)
```

