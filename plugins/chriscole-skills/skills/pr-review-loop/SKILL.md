---
name: pr-review-loop
description: Run /pr-review, then fix what it found in subagents test-first (red, then green), prove each fix with a skeptic, and review the fixes — round after round until the review comes back green or the loop hits something only a person can decide.
disable-model-invocation: true
model: opus
---

## The shape of it

| Step | What happens | Where |
|---|---|---|
| 0 | Preflight: target, clean tree, one round of questions | main session |
| 1 | **Review** — pr-review steps 0 to 7, whole PR | main session + its agents |
| 2 | **Fix** — test first: one fixer per file-disjoint group, all at once, red then green | agents |
| 2b | **Decide** — every choice a fixer handed back, one decider each | agents |
| 3 | **Prove** — red check without the fix, machine checks, then one skeptic per fix | main session + agents |
| 4 | Commit the round | main session |
| 5 | **Re-review** — pr-review on this round's commit only | main session + its agents |
| 6 | Green, stuck, or another round | main session |
| 7 | Report, then deliver | main session |

## Why it is built this way

`/pr-review` ends by asking whether to fix. When every finding is a contained edit and the checks run locally, the answer is almost always yes — and then somebody has to check the fixes, and then check that the fixes did not break something else. That is a loop, and a loop is what this skill runs.

Three things it must not do, and the design follows from them:

- **Mark its own homework.** The agent that wrote a fix is the worst judge of it. So every fix is test-driven — a test that fails on the defect is written and seen red before the fix, and seen green after — and the loop itself re-runs that test with the fix taken out, to see it fail for the right reason. Then the same skeptic that confirmed the defect is asked the same question against the new code. Red without the fix, green with it, and refuted now means fixed.
- **Hide new damage.** A fix is new code. So every round's commit goes back through the full review — finders, skeptics, rulings — not just the checks.
- **Spin.** A loop with no exit burns money politely. So every finding has an attempt budget and the loop has a round cap.

**And it must not stall on questions.** A fix that needs a choice goes to `pr-review-decider`, which settles it from the repo's own evidence — intent, written rules, the user's past overrules, precedent, then the safe default — and the finding comes back with its answer. Only a question that clears the decider's bar (irreversible, security, or user-visible with no evidence either way) waits for the user, and even that is set aside rather than stopping the loop. Everything else keeps moving; the user gets the leftover questions together, once, at the end.

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
- **Keep a ledger** in `<scratch>/pr-<n>-loop.md`. One line per finding, for the whole loop: `#<id> · path:line · <title> · <state> · attempts <k>`. States: `open`, `fixed`, `ruled-fine`, `escalated`, `stuck`, `adjacent`, `dropped`. An `open` finding may carry a decision; copy its **Decided** line into the ledger entry. Give each finding a stable id now (`R1-1`, `R1-2`, …) and never renumber.

**What the loop fixes** — only **Change before merge**, decided ones included. pr-review's step 6c has already run, so **Decided for you** goes in as `ruled-fine` and **Needs your decision** as `escalated` — that one already cleared the bar, and nobody in the loop gets to decide it. **Worth its own PR** goes to `adjacent` and stays out, as pr-review's deliver step says: a fix to code this PR did not touch grows the diff the author has to defend.

Nothing in Change before merge, build and tests green → the PR is already green. Skip to step 7.

### 2. Fix

**Group the open findings by file.** Two findings that touch the same file, or a file and its direct caller, are one group. Groups must be disjoint — two fixers never hold the same file, because nothing stops one overwriting the other.

Spawn one `pr-review-fixer` per group, **all in a single message**. The agent definition holds the contract — red, then green, per finding; the prompt carries the specifics:

> Fix these confirmed defects in `<repo path>`, test first: for each one, write a test from its Repro, run it and see it fail for the finding's reason, then make the smallest change that turns it green. Your files: `<paths>`, plus their test files. Touch nothing else.
>
> **Finding <id>:** <title>
> `path:line`
> - **What happens** — <copied from the report>
> - **Why** — <copied>
> - **Repro** — <the skeptic's REPRO, copied>
> - **Fix** — <copied>
> - **Decided** — <copied, when the finding has one>
>
> <next finding in the group…>
>
> **Checks for these files:**
> ```
> <the build and test commands pr-review step 2 found, narrowed to these files' project or module>
> ```
>
> **Existing tests for these files:** `<test paths, or "none — nearest tests for this project: <path>">`
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

Copy the finding's bullets, do not re-summarise them. Groups include their test files: two groups never share a test file either. On a second attempt, add the reason the first one failed — the skeptic's `REPRO` against the fixed code, the red check that passed, or the failing check line — under the finding, as **Last attempt failed because:**. The next fixer starts from red again.

Apply the returns: `fixed` with `RED` and `GREEN` filled in → step 3 proves it. `fixed` with `RED: none` → step 3 proves it without the red check, and the finding carries `no test` in the ledger and the report. `fixed` with a test but no `RED` line — the fixer did not see it fail — is not test-driven: treat it as `failed`, with that as the reason. `needs-decision` → step 2b, with the fixer's `OPTIONS`. `failed` → counts as an attempt; back to step 2 next round.

### 2b. Decide

Only when a fixer returned `needs-decision`, or a step-3 skeptic left a fix unsettled last round. All the fixers have returned by now, so the tree is quiet and a decider's probe cannot collide with an edit.

Spawn one `pr-review-decider` per question, **all in a single message**, with pr-review step 6c's prompt: the question is the fixer's `NOTE`, the competing shapes are its `OPTIONS`, and the intent brief, digest and overrides log are round 1's. Apply what comes back:

- **decided, `CHANGE: needed`** → back to `open`, with the decision as its **Decided** line. It is fixed next round, and this round **does not count as an attempt** — the fixer did its job by asking.
- **decided, `CHANGE: none`** → `ruled-fine`. Nothing to fix.
- **settled confirmed** → stays `open`, with the decider's `REPRO`. **Settled refuted** → `dropped`, with the evidence in the discarded file.
- **escalate** → `escalated`. Check it against the bar exactly as step 6c says, then set it aside. The loop goes on without it.

A finding a fixer sends back to 2b a second time, after it already had a decision, is `stuck`: the decision did not make it fixable.

### 3. Prove

**Red check first — the loop's own, not the fixer's word.** For each fixed finding with a test, take the fix out and run the test, so the test is proved to catch the defect and not just to pass. All fixers have returned, so the tree is quiet:

```bash
git diff -- <the finding's non-test FILES> > <scratch>/<id>.fix.patch
git checkout -- <the finding's non-test FILES>
<the fixer's RUN command> 2>&1 | tail -30   # must FAIL, for the finding's reason
git apply <scratch>/<id>.fix.patch
<the fixer's RUN command> 2>&1 | tail -30   # must PASS
```

Do it one finding at a time, and only when that finding's non-test files hold no other finding's hunks; otherwise revert the whole group's non-test files together and expect every one of the group's tests to fail. Check the patch re-applied (`git diff --stat` matches before) before moving on.

- **Fails without the fix, for the finding's reason; passes with it** → red-green holds. On to the machine checks.
- **Passes without the fix** → the test does not reach the defect, so it proves nothing. Not fixed: one attempt, back to `open`, with "test passes without the fix" as the reason.
- **Fails without the fix for another reason** (compile error, missing import) → same: the test is not red for the right reason.

**Machine next.** Run the repo's build and the full test suite, filtered, exactly as pr-review step 2 does. Fixers ran the narrow checks; this is the one that catches a fix in one group breaking another.

A failure is a finding of its own, needs no skeptic, and joins the next round's fix list with the failing line as its `Repro` — the failing test is already its red, so its fixer goes straight to green. Do not commit a red tree as if it were a round — go straight back to step 2 with it.

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
> <git diff -- <the fixer's FILES>, for this finding's hunks, test included>
> ```
>
> **The regression test:** `<TEST>`, run with `<RUN>`. It failed without the change and passes with it. Judge whether it actually exercises the claim — a test that asserts something next to the fault proves nothing.
>
> Run the repro against the code as it is now. **Refuted** means the repro no longer reaches the fault — then `WHY` names the line in the change that stops it. Refuted for any other reason (unreachable, already handled elsewhere) is a different answer: say so in `CORRECTION`.

Apply the verdicts:

- **refuted, with `WHY` naming a line in the change** → `fixed`.
- **refuted for another reason** → `fixed` is not earned; the original finding was wrong or the fix is incidental. Mark it `fixed`, but log the `CORRECTION` in the discarded file so the next round's finders look at that code fresh.
- **confirmed** → the fix did not take, and the test that went green missed it. Revert that finding's hunks, test included (`git checkout -- <files>` only when the group had one finding; otherwise hand the skeptic's `REPRO` to the next fixer and let it rework), add one attempt, back to `open`. The **Last attempt failed because** line says the old test passed while the fault remained, so the next test is written from the skeptic's REPRO.
- **unsettled** → step 2b next round, with what would settle it.

A live check was approved → after the skeptics, run pr-review step 6b's live checker once on the fixed findings the app can show. Reproduced in the app means not fixed, whatever the skeptic said.

### 4. Commit the round

Only the fixers' files — the fix and its test together, so the commit carries its own proof — never `git add -A`:

```bash
git add <every FILES path and TEST file from fixed findings>
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
- every remaining finding is `escalated` or `stuck`.

Otherwise, back to step 2 with the `open` findings.

Say one line per round as it ends, in the user's terms, so the transcript shows where the loop is: `Round 2: fixed 3 of 4, 1 new finding from the re-review, build green.`

### 7. Report, then deliver

The final report is pr-review's 7d report **for the whole PR as it now stands**, `<base>` → `HEAD`, with the verdict reflecting the end state. Round 1 covered the original change and every later round covered its own commit, so together they cover everything. Say so in the facts row: `🔁 <k> rounds · <n> fixed in <c> commits`.

Then two sections the 7d template does not have, in the same shape and voice:

- **🔧 Fixed by the loop · <n>** — one bullet per fixed finding: the plain-language title, then `↳ <commit short sha> · <the fixer's CHANGE sentence>`, then `↳ test: <TEST> · red → green`. A finding fixed without a test says `↳ ⚠️ no test — <why>` instead, so the user knows which fixes rest on the skeptic alone.
- **⚖️ Decided for you** — pr-review's own section, now also holding every `ruled-fine` decision from step 2b. Every **Decided** line on a fixed finding stays visible in its Fixed-by-the-loop bullet, as `↳ decided: <decision> · basis: <basis>`, so it can still be overruled.
- **🤔 Needs your decision** — pr-review's own section: every `escalated` question, and every `stuck` finding with both attempts' reasons in one line each.

The verdict is **✅ Approve** only when the loop ended green. Otherwise **🛑 Request changes**, and the reason names what is left.

Print it whole, before any question. When **Needs your decision** is not empty, the first question is for those: once the user answers, their answers become **Decided** lines and the loop runs again from step 2 — same ledger, same round cap reset to two more rounds. An overrule of anything in **Decided for you** or a Fixed-by-the-loop decision is handled the same way, and logged as pr-review's deliver step says. Then follow pr-review's [deliver step](../pr-review/reference/deliver.md) with the loop's answers already in hand: push if the user chose that at preflight (still ask first when the branch is not theirs), offer the PR comment, and record `pr-review.last-<n>`.

Write the ledger's last state into the discarded-reasoning file, and point at it in the footer.

## When something goes wrong

pr-review's [failure modes](../pr-review/reference/failure-modes.md) hold. The loop adds:

- **`pr-review-fixer` is missing** → spawn `general-purpose` with the fixer's contract pasted in, and say so, as pr-review does for its own agents.
- **A fixer edited a file outside its set** → revert that file, mark the finding `failed`, and do not let it count against a group that did nothing wrong.
- **The tree is dirty mid-loop for a reason the loop did not cause** — the user is editing too → stop. Say what changed and ask. Never commit over it.
- **The build does not run here** → the loop cannot prove anything. Run round 1, then stop and fall back to pr-review's own step 8.
- **The fix's patch does not re-apply after the red check** → stop. Restore from `<scratch>/<id>.fix.patch` by hand if it can be, say what happened, and never commit a tree the red check left half-reverted.
- **Every fix is refuted for another reason** → the round-1 findings were weaker than they looked. Stop after that round and say so; do not keep fixing what was not broken.
