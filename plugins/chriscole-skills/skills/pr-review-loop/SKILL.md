---
name: pr-review-loop
description: Run /pr-review, then fix what it found in subagents, prove each fix with a skeptic, and review the fixes — round after round until the review comes back green or the loop hits something only a person can decide.
disable-model-invocation: true
model: opus
---

## The shape of it

| Step | What happens | Where |
|---|---|---|
| 0 | Preflight: target, clean tree, one round of questions | main session |
| 1 | **Review** — pr-review steps 0 to 7, whole PR | main session + its agents |
| 2 | **Fix** — one fixer per file-disjoint group, all at once | agents |
| 3 | **Prove** — machine checks, then one skeptic per fix, all at once | main session + agents |
| 4 | Commit the round | main session |
| 5 | **Re-review** — pr-review on this round's commit only | main session + its agents |
| 6 | Green, stuck, or another round | main session |
| 7 | Report, then deliver | main session |

## Why it is built this way

`/pr-review` ends by asking whether to fix. When every finding is a contained edit and the checks run locally, the answer is almost always yes — and then somebody has to check the fixes, and then check that the fixes did not break something else. That is a loop, and a loop is what this skill runs.

Three things it must not do, and the design follows from them:

- **Mark its own homework.** The agent that wrote a fix is the worst judge of it. So a fix is proved by the same skeptic that confirmed the defect, asked the same question against the new code. Refuted now means fixed.
- **Hide new damage.** A fix is new code. So every round's commit goes back through the full review — finders, skeptics, rulings — not just the checks.
- **Spin.** A loop with no exit burns money politely. So every finding has an attempt budget, the loop has a round cap, and anything that needs a person stops the loop instead of being guessed at.

**Subagents cannot spawn subagents.** That is why the review itself runs in this session and not in an agent: pr-review fans out to finders and skeptics, and only the main session can do that. Fixing and proving are the work that goes to agents.

**pr-review cannot be invoked as a skill from here** — it sets `disable-model-invocation`. Read it and follow it: [../pr-review/SKILL.md](../pr-review/SKILL.md). Everything it says holds, except the overrides below.

## Process

**Models.** Same rule as pr-review: leave the `Agent` tool's `model` argument off every spawn, unless the invoker named a model — then pass it on every spawn, including the fixers.

### 0. Preflight

Resolve the target exactly as pr-review step 1 does. Then, before any agent runs:

- **The branch must be checked out here.** If the PR's head is not the current branch, ask before `gh pr checkout <n>` — it changes the user's working tree.
- **The working tree must be clean.** `git status --porcelain` empty. Otherwise stop and say so: this loop commits, and it must never sweep the user's unfinished work into a commit.
- **Record the start:** `git rev-parse HEAD` is `<start>`. Every commit after it is the loop's own.

Then ask everything the loop will need, **once, together**, so it can run unattended afterwards:

- any `ask-first` pass the repo's profile would fire, and the live check if there is one — one yes covers every round, and the app stays up across them;
- **where the fixes land** — local commits only (the default, always safe), or push at the end. Never push mid-loop.

### 1. Review

Run pr-review steps 0 to 7, on the whole PR, as written. Print the report, whole, as pr-review says to.

**Overrides for the loop:**

- **Skip pr-review step 8.** No fix-or-comment question; the loop is the answer to it.
- **Keep the intent brief, the standards digest and the usage map** from this round. Later rounds reuse them rather than rebuilding.
- **Keep a ledger** in `<scratch>/pr-<n>-loop.md`. One line per finding, for the whole loop: `#<id> · path:line · <title> · <state> · attempts <k>`. States: `open`, `fixed`, `needs-decision`, `stuck`, `adjacent`. Give each finding a stable id now (`R1-1`, `R1-2`, …) and never renumber.

**What the loop fixes** — only **Change before merge**. **Needs your decision** goes straight to `needs-decision`; nobody in the loop gets to decide it. **Worth its own PR** goes to `adjacent` and stays out, as pr-review's deliver step says: a fix to code this PR did not touch grows the diff the author has to defend.

Nothing in Change before merge, build and tests green → the PR is already green. Skip to step 7.

### 2. Fix

**Group the open findings by file.** Two findings that touch the same file, or a file and its direct caller, are one group. Groups must be disjoint — two fixers never hold the same file, because nothing stops one overwriting the other.

Spawn one `pr-review-fixer` per group, **all in a single message**. The agent definition holds the contract; the prompt carries the specifics:

> Fix these confirmed defects in `<repo path>`. Your files: `<paths>`. Touch nothing else.
>
> **Finding <id>:** <title>
> `path:line`
> - **What happens** — <copied from the report>
> - **Why** — <copied>
> - **Repro** — <the skeptic's REPRO, copied>
> - **Fix** — <copied>
>
> <next finding in the group…>
>
> **Checks for these files:**
> ```
> <the build and test commands pr-review step 2 found, narrowed to these files' project or module>
> ```
>
> **Standards digest for these files:**
> ```
> <the round-1 digest entries for these paths>
> ```
>
> **Stated intent — verbatim, so the fix does not undo a decision the author made:**
> ```
> <the round-1 Stated intent block, whole>
> ```
>
> Return the schema from your instructions and nothing else.

Copy the finding's bullets, do not re-summarise them. On a second attempt, add the reason the first one failed — the skeptic's `REPRO` against the fixed code, or the failing check line — under the finding, as **Last attempt failed because:**.

Apply the returns: `fixed` → step 3 proves it. `needs-decision` → the ledger, with the fixer's `NOTE` as the question. `failed` → counts as an attempt; back to step 2 next round.

### 3. Prove

**Machine first.** Run the repo's build and the full test suite, filtered, exactly as pr-review step 2 does. Fixers ran the narrow checks; this is the one that catches a fix in one group breaking another.

A failure is a finding of its own, needs no skeptic, and joins the next round's fix list with the failing line as its `Repro`. Do not commit a red tree as if it were a round — go straight back to step 2 with it.

**Then one skeptic per fixed finding**, all in a single message. Reuse `pr-review-verifier` — it already knows how to try a claim against code. Same claim as before, against the code as it now stands:

> Try to refute this claim about `<repo path>`, as the code stands in the working tree now.
>
> **Claim:** <the original defect sentence>
> **Consequence claimed:** <what breaks and when>
> **Where:** `<path>:<line>`
> **The repro that confirmed it before:** <the original REPRO>
>
> The code was changed to address this. The change:
> ```diff
> <git diff -- <the fixer's FILES>, for this finding's hunks>
> ```
>
> Run the repro against the code as it is now. **Refuted** means the repro no longer reaches the fault — then `WHY` names the line in the change that stops it. Refuted for any other reason (unreachable, already handled elsewhere) is a different answer: say so in `CORRECTION`.

Apply the verdicts:

- **refuted, with `WHY` naming a line in the change** → `fixed`.
- **refuted for another reason** → `fixed` is not earned; the original finding was wrong or the fix is incidental. Mark it `fixed`, but log the `CORRECTION` in the discarded file so the next round's finders look at that code fresh.
- **confirmed** → the fix did not take. Revert that finding's hunks (`git checkout -- <files>` only when the group had one finding; otherwise hand the skeptic's `REPRO` to the next fixer and let it rework), add one attempt, back to `open`.
- **unsettled** → `needs-decision`, with what would settle it.

A live check was approved → after the skeptics, run pr-review step 6b's live checker once on the fixed findings the app can show. Reproduced in the app means not fixed, whatever the skeptic said.

### 4. Commit the round

Only the fixers' files, never `git add -A`:

```bash
git add <every FILES path from fixed findings>
git commit -m "fix(review): <short titles, or 'round <k>: <n> findings'>"
```

Follow the repo's commit convention when it has one (`git log --format=%s -15` shows it). Record `<round-k-sha>`. Nothing fixed this round → no commit, and say so.

### 5. Re-review the round

Run pr-review steps 1 to 7 again, **narrowed to this round's commit**: fixed point = the SHA before it. That is pr-review's incremental review, and the narrowing is real — the loop's fixes are the only new code, and round 1 already covered the rest.

Reuse round 1's intent brief, digest and usage map instead of rebuilding them. Add one thing to every finder's prompt, under **Already raised**: every ledger entry for its files, with its state, so nobody re-reports a fixed finding as new or rediscovers an `adjacent` one.

New confirmed findings get new ids (`R2-1`, …) and go into the ledger as `open`.

**Oscillation:** a new finding that is the original fault of an earlier `fixed` one, come back in another shape, means two fixes are fighting. Mark both `stuck` and stop fixing that code.

### 6. Green, stuck, or another round

**Green** — every one of these:

- no `open` finding left;
- build and tests pass on the last commit;
- the last re-review returned no Change before merge.

**Stop, not green** — any one of these:

- a finding has failed **two** attempts → `stuck`;
- **four** rounds have run;
- every remaining finding is `needs-decision` or `stuck`.

Otherwise, back to step 2 with the `open` findings.

Say one line per round as it ends, in the user's terms, so the transcript shows where the loop is: `Round 2: fixed 3 of 4, 1 new finding from the re-review, build green.`

### 7. Report, then deliver

The final report is pr-review's 7d report **for the whole PR as it now stands**, `<base>` → `HEAD`, with the verdict reflecting the end state. Round 1 covered the original change and every later round covered its own commit, so together they cover everything. Say so in the facts row: `🔁 <k> rounds · <n> fixed in <c> commits`.

Then two sections the 7d template does not have, in the same shape and voice:

- **🔧 Fixed by the loop · <n>** — one bullet per fixed finding: the plain-language title, then `↳ <commit short sha> · <the fixer's CHANGE sentence>`.
- **🤔 Needs your decision** — pr-review's own section, now also holding the fixers' `needs-decision` questions and every `stuck` finding with both attempts' reasons in one line each.

The verdict is **✅ Approve** only when the loop ended green. Otherwise **🛑 Request changes**, and the reason names what is left.

Print it whole, before any question. Then follow pr-review's [deliver step](../pr-review/reference/deliver.md) with the loop's answers already in hand: push if the user chose that at preflight (still ask first when the branch is not theirs), offer the PR comment, and record `pr-review.last-<n>`.

Write the ledger's last state into the discarded-reasoning file, and point at it in the footer.

## When something goes wrong

pr-review's [failure modes](../pr-review/reference/failure-modes.md) hold. The loop adds:

- **`pr-review-fixer` is missing** → spawn `general-purpose` with the fixer's contract pasted in, and say so, as pr-review does for its own agents.
- **A fixer edited a file outside its set** → revert that file, mark the finding `failed`, and do not let it count against a group that did nothing wrong.
- **The tree is dirty mid-loop for a reason the loop did not cause** — the user is editing too → stop. Say what changed and ask. Never commit over it.
- **The build does not run here** → the loop cannot prove anything. Run round 1, then stop and fall back to pr-review's own step 8.
- **Every fix is refuted for another reason** → the round-1 findings were weaker than they looked. Stop after that round and say so; do not keep fixing what was not broken.
