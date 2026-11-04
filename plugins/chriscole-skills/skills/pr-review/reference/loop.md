# The fix loop

Every code fix in this skill goes through this file. **Fix once** is one round; **fix until
green** runs rounds until the review comes back clean. Same steps, different round cap.

| Step | What happens | Where |
|---|---|---|
| L0 | Preflight: clean tree, start SHA, one round of questions | main session |
| L1 | Set up the ledger from the report | main session |
| L2 | **Fix** — test first: one fixer per file-disjoint group, all at once, red then green | agents |
| L2b | **Decide** — every choice a fixer handed back, one decider each | agents |
| L3 | **Prove** — red check without the fix, machine checks, then one skeptic per fix | main session + agents |
| L4 | Commit the round, one commit per group | main session |
| L5 | **Re-review** — SKILL.md steps 1 to 7 on this round's commits only | main session + agents |
| L6 | Converged, stuck, or another round | main session |
| L7 | **Verify** — the whole PR at the final commit; only a pass is green | main session + agents |
| L8 | Report, then deliver | main session |

**The round cap.** Fix once: **1**. Fix until green (`/pr-review loop`, or chosen at step 8): **4**.

Review → fix → review → fix … → **verify**. The rounds converge; verify is what makes it green.

## What it must not do

- **Mark its own homework.** The agent that wrote a fix is the worst judge of it. So every fix is
  test-driven — a test that fails on the defect is written and seen red before the fix, and seen
  green after — and the loop re-runs that test with the fix taken out, to see it fail for the right
  reason. Then the same skeptic that confirmed the defect is asked the same question against the
  new code. Red without the fix, green with it, and refuted now means fixed.
- **Hide new damage.** A fix is new code. So every round's commits go back through the full review
  — finders, skeptics, rulings — not just the checks.
- **Ship a broken PR.** No round checks the PR the user will merge: all the rounds at once, against
  what the PR was for. So it ends with [verify.md](./verify.md) on the final commit, and nothing is
  green, or pushed, until it passes.
- **Spin.** Every finding has an attempt budget and the loop has a round cap.
- **Stall on questions.** A fix that needs a choice goes to `pr-review-decider`. Only a question
  that clears the decider's bar waits for the user, and even that is set aside rather than stopping
  the loop; the user gets the leftover questions together, once, at the end.

Subagents cannot spawn subagents, so the review and every fan-out run in the main session. Fixing
and proving are the work that goes to agents.

### L0. Preflight

Under `/pr-review loop` it already ran at step 1: go to L1. Chosen at step 8: read
[loop-preflight.md](./loop-preflight.md) and run its checks, then L1.

**Scripts.** `<skill dir>` is the base directory the skill was loaded from. Two scripts do the
loop's git work, from the repo root:

- `bash <skill dir>/scripts/hold.sh out <patch> <files…>` saves the files' changes to `<patch>` and
  takes them out of the tree, new files included (`git checkout` would leave a new file behind).
  `hold.sh in <patch>` puts them back and fails loudly if they do not re-apply. `hold.sh drop
  <files…>` takes them out and keeps nothing.
- `bash <skill dir>/scripts/authors-lines.sh <fixed-point> <start> <rev> [<to>] -- <files…>` prints
  every line the change removes or rewrites that the PR's author wrote, with its blame. Nothing
  printed means none. `<fixed-point>` is always the PR's, from step 1.

### L1. Set up the ledger

- **Keep the intent brief, the standards digest, the usage map, Decisions in the code and the
  counterpart** from the review. Later rounds reuse them rather than rebuilding.
- **Keep a ledger** in `<scratch>/pr-<n>-loop.md`. One line per finding, for the whole loop:
  `#<id> · path:line · <title> · <state> · attempts <k>`. States: `open`, `held` (a fix saved out of
  the tree, waiting on L2b), `fixed`, `ruled-fine`, `escalated`, `stuck`, `adjacent`, `dropped`. An
  `open` finding may carry a decision; copy its **Decided** line into the ledger entry. Give each
  finding a stable id now (`R1-1`, `R1-2`, …) and never renumber.

**What the loop fixes** — only **Change before merge**, decided ones included. Step 6c has already
run, so **Decided for you** goes in as `ruled-fine` and **Needs your decision** as `escalated` — that
one already cleared the bar, and nobody in the loop gets to decide it. **Worth its own PR** goes to
`adjacent` and stays out, as [deliver.md](./deliver.md) says: a fix to code this PR did not touch
grows the diff the author has to defend. The user may fold some in at step 8; those go in as `open`.

Nothing in Change before merge, build and tests green → the PR is already green, and the loop
changed nothing, so there is nothing to verify. Skip to L8.

### L2. Fix

**Group the open findings by file.** Two findings that touch the same file, or a file and its
direct caller, are one group. Groups must be disjoint — two fixers never hold the same file, because
nothing stops one overwriting the other.

Spawn one `pr-review-fixer` per group, **all in a single message**. The agent definition holds the
contract — red, then green, per finding; the prompt carries the specifics:

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
> <the build and test commands step 2 found, narrowed to these files' project or module>
> ```
>
> **Existing tests for these files:** `<test paths, or "none — nearest tests for this project: <path>">`
>
> **Standards digest for these files:**
> ```
> <the digest entries for these paths>
> ```
>
> **Stated intent — verbatim, so the fix does not undo a decision the author made:**
> ```
> <the Stated intent block, whole>
> ```
>
> **Decisions in the code — comments this PR added in these files that state a choice. Fix inside them; reversing one is `needs-decision`:**
> ```
> <the 4b entries for these paths, or "none">
> ```
>
> **Counterpart — the other system's source, read-only:** `<path>`, version `<branch or tag>`; look in <where to look>. Omit when the review had none.
>
> **Who wrote what:** the PR starts after `<fixed-point>`; the loop's own commits start after `<start>`. A line from a commit in `<fixed-point>..<start>` is the author's; one from after `<start>` is the loop's.
>
> Return the schema from your instructions and nothing else.

Copy the finding's bullets, do not re-summarise them. Groups include their test files: two groups
never share a test file either. On a second attempt, add the reason the first one failed — the
skeptic's `REPRO` against the fixed code, the red check that passed, or the failing check line —
under the finding, as **Last attempt failed because:**. The next fixer starts from red again.

Apply the returns: `fixed` with `RED` and `GREEN` filled in → L3 proves it. `fixed` with
`RED: none` → L3 proves it without the red check, and the finding carries `no test` in the ledger
and the report. `fixed` with a test but no `RED` line — the fixer did not see it fail — is not
test-driven: treat it as `failed`, with that as the reason. `needs-decision` → L2b, with the fixer's
`OPTIONS`. `failed` → counts as an attempt; back to L2 next round.

Two more fields, checked before L3:

- **`REVERSES` is not `none`** → the fix undid a line the author wrote. It is **held**, and goes to
  L2b with "keep the author's line" as one option and the fix as the other — unless every line it
  lists is **covered**.
- **`COUNTERPART: not checked`** on a fix that crosses a boundary, while the review had a
  counterpart → `failed`, with "the other system's handling was not read" as the reason. Without a
  counterpart at all, carry it as `counterpart unchecked` into the ledger and the report.

**Covered** lines need no decision, and only these count:

- the finding's own `Where` line, when what the finding says is wrong is that line's text — a false
  sentence, a wrong value;
- a line the finding's **Decided** line names;
- a carrier edit, where the author's line survives word for word in the new code — a trailing comma
  for an added argument, an expression moved unchanged into a variable.

Anything else is held, even when the decision seems to imply it. "Implied" is where a fix slips
past its decision: a line the decision does not name, rewritten in a way the decision did not say,
is a new choice.

### L2b. Decide

Only when something is waiting on a choice:

- a fixer returned `needs-decision`;
- a fix is **held** because it changes a line the author wrote — its `REVERSES`, L3's author's-lines
  check, or an L3 skeptic's `CORRECTION` naming a decision it undoes;
- an L3 skeptic left a fix unsettled.

The first two from this round's fixers run now; anything L3 raised runs in the next round's L2b.
All the fixers have returned by then, so the tree is quiet and a decider's probe cannot collide
with an edit.

**A held fix is out of the tree until it is decided**, so no skeptic judges it and L4 never
commits it: `hold.sh out <scratch>/<id>.held.patch <the finding's FILES and TEST>`, and
`hold.sh in` the same patch to put it back. When its non-test files hold another finding's hunks
too, hold the whole group, as L3's red check does.

Spawn one `pr-review-decider` per question, **all in a single message**, with
[decide.md](./decide.md)'s prompt: the question is the fixer's `NOTE`, the competing shapes are its
`OPTIONS`, and the intent brief, digest and overrides log are the review's. Apply what comes back:

- **decided, `CHANGE: needed`** → back to `open`, with the decision as its **Decided** line. It is
  fixed next round, and this round **does not count as an attempt** — the fixer did its job by asking.
- **decided, `CHANGE: none`** → `ruled-fine`. Nothing to fix.
- **settled confirmed** → stays `open`, with the decider's `REPRO`. **Settled refuted** → `dropped`,
  with the evidence in the discarded file.
- **escalate** → `escalated`. Check it against the bar exactly as decide.md says, then set it aside.
  The loop goes on without it.

**A held fix is decided by what the decision keeps, not by `CHANGE` alone.** Read its `DECISION`:

- **the fix stands** → `git apply` the held patch next round, and it goes through L3 again with the
  reversal accepted: the author's-lines check treats the lines this decision names as covered, so it
  is not held twice for the same line; the skeptic still sees them, marked covered. The fixer's next
  prompt quotes those lines in the **Decided** line, so they stay covered. The report shows it as
  `changes the author's line`.
- **the author's line stays, and the defect still needs fixing** (`CHANGE: needed`) → discard the
  patch; the finding goes back to `open` with "keep the author's line" in its **Decided** line, so
  the next fixer works inside it.
- **the author's line stays, and the defect is acceptable** (`CHANGE: none`) → discard the patch;
  `ruled-fine`.

A finding a fixer sends back to L2b a second time, after it already had a decision, is `stuck`: the
decision did not make it fixable.

**At the round cap**, a decision that needs another round to apply — `CHANGE: needed`, or a held
fix that stands — leaves the finding `open`, carrying its **Decided** line, for the report.

### L3. Prove

**Red check first — the loop's own, not the fixer's word.** For each fixed finding with a test, take
the fix out and run the test, so the test is proved to catch the defect and not just to pass. All
fixers have returned, so the tree is quiet:

```bash
bash <skill dir>/scripts/hold.sh out <scratch>/<id>.fix.patch <the finding's non-test FILES>
<the fixer's RUN command> 2>&1 | tail -30   # must FAIL, for the finding's reason
bash <skill dir>/scripts/hold.sh in <scratch>/<id>.fix.patch
<the fixer's RUN command> 2>&1 | tail -30   # must PASS
```

Do it one finding at a time, and only when that finding's non-test files hold no other finding's
hunks; otherwise take the whole group's non-test files out together and expect every one of the
group's tests to fail. `hold.sh in` failing is failure-modes' "patch does not re-apply": stop.

- **Fails without the fix, for the finding's reason; passes with it** → red-green holds. On to the
  machine checks.
- **Passes without the fix** → the test does not reach the defect, so it proves nothing. Not fixed:
  one attempt, back to `open`, with "test passes without the fix" as the reason.
- **Fails without the fix for another reason** (compile error, missing import) → same: the test is
  not red for the right reason.

**Then the author's lines — the loop's own check, not the fixer's `REVERSES`.** For each fixed
finding, `authors-lines.sh <fixed-point> <start> HEAD -- <the finding's non-test FILES>` — the fix
is not committed yet, so its old side is `HEAD`.

Any line that comes back and is not in the fixer's `REVERSES` → treat the return as if it had listed
it: the fix is held, as L2b says, unless the line is covered (L2). Covered lines still go into the
skeptic's prompt below, each marked with what covers it, so the skeptic judges the rewrite against
the decision rather than taking it on trust. A fix that is not held and covers nothing changed none
of the author's lines, so the prompt says "none" for it.

**Machine next.** Run the repo's build and the full test suite, filtered, exactly as step 2 does.
Fixers ran the narrow checks; this is the one that catches a fix in one group breaking another.

A failure is a finding of its own, needs no skeptic, and joins the next round's fix list with the
failing line as its `Repro` — the failing test is already its red, so its fixer goes straight to
green. Do not commit a red tree as if it were a round — go straight back to L2 with it. At the round
cap there is no next round: find the group whose fix turns it red (take groups out one at a time,
as the red check does), hold that group's fix out of the tree as L2b does, and report the failure
under **Change before merge**.

**Then one skeptic per fixed finding**, all in a single message. Reuse `pr-review-verifier` — it
already knows how to try a claim against code. Same claim as before, against the code as it now
stands:

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
> **Lines this PR wrote that the change removes or rewrites:** <the author's-lines check above, each with what it said and, when covered, what covers it: "the finding's own line", "named in Decided", or "carrier edit" — or "none">
> **Decided:** <the finding's Decided line, copied — or "none">
> **Stated intent and Decisions in the code:** <the review's blocks for these files>
> **Counterpart:** `<path>`, version `<branch or tag>`; the fixer cited `<COUNTERPART>`. Omit when the review had none.
>
> Two questions. Does the repro still reach the fault? And does the change undo anything the author decided — a line above, the stated intent, a comment? Name any such decision in `CORRECTION`, whatever the verdict.
>
> Run the repro against the code as it is now. **Refuted** means the repro no longer reaches the fault — then `WHY` names the line in the change that stops it. Refuted for any other reason (unreachable, already handled elsewhere) is a different answer: say so in `CORRECTION`.

Apply the verdicts:

- **refuted, with `WHY` naming a line in the change** → `fixed` — unless `CORRECTION` names a
  decision the change undoes: then the fix is held, as L2b says, with "keep the author's decision"
  as an option.
- **refuted for another reason** → `fixed` is not earned; the original finding was wrong or the fix
  is incidental. Mark it `fixed`, but log the `CORRECTION` in the discarded file so the next round's
  finders look at that code fresh.
- **confirmed** → the fix did not take, and the test that went green missed it. Revert that
  finding's hunks, test included: `hold.sh drop <files and TEST>`, so L4 never commits the test
  without its fix. When its files hold another finding's hunks too, revert nothing; those files
  stay out of this round's commit, and the next fixer reworks them from the skeptic's `REPRO`. A
  fixed finding in those files stays `fixed`, and its commit is the round that commits the file. Add
  one attempt, back to `open`. The **Last attempt failed because** line says the old test passed
  while the fault remained, so the next test is written from the skeptic's REPRO.
- **unsettled** → L2b next round, with what would settle it.

A live check was approved → the app is not driven here, round by round. L7's verify drives it once,
at the final commit, on the premise and every fixed finding together. Reproduced in the app there
means not fixed, whatever the skeptic said.

### L4. Commit the round

**One commit per fixer group** — the fix and its test together, so each commit carries its own
proof. Groups are file-disjoint, so this always splits cleanly, and verify can take one group's fix
out by its commit. Only the fixers' files, never `git add -A`:

```bash
git add <the group's FILES paths and TEST files from fixed findings>
git commit -m "fix(review): <the group's short titles>"
```

Held fixes are already out of the tree (L2b), and so are failed ones on their own files (L3). Leave
out any file that also holds an `open` finding's hunks. Before adding, `git status --porcelain` —
not `git diff --stat`, which misses new files — must show only what you are about to add, plus the
files you are leaving out on purpose.

Follow the repo's commit convention when it has one (`git log --format=%s -15` shows it). Record the
round's range: `git rev-parse HEAD` before its first commit is `<round-k-base>`, after its last is
`<round-k-head>`. Nothing fixed this round → no commit, and say so.

### L5. Re-review the round

Run SKILL.md steps 1 to 7 again, **narrowed to this round's commits**: fixed point =
`<round-k-base>`. That is the incremental review, and the narrowing is real — the loop's fixes are
the only new code, and the first review already covered the rest.

Three parts of those steps change for a re-review, so the first review's records survive to L7:

- **Skip step 2.** L3 already ran the machine on this tree, and `<scratch>/pr-<n>-baseline.txt` stays
  the first review's — it is what verify compares against.
- **Append to `<scratch>/pr-<n>-discarded.md`**, under a `Round <k>` heading; never overwrite it.
- **Print no 7d report.** The round's findings go to the ledger, and L6 prints the one-line round
  summary. The only full report is L8's.

Reuse the review's intent brief, digest, usage map, **Decisions in the code** and counterpart
instead of rebuilding them. A round small enough for step 1's inline path still gets them: read the
commits against the stated intent and the decisions list yourself, and run
`authors-lines.sh <fixed-point> <start> <round-k-base> <round-k-head> -- <the round's files>`.
Keep `<fixed-point>` the PR's: the re-review's own fixed point would put every line the author wrote
outside the range, and the check would come back empty. A line already ruled covered, or already
decided, in L3 is not raised again here. A small diff is where a reversed decision hides best. Add
one thing to every finder's prompt, under **Already raised**: every ledger entry for its files, with
its state, so nobody re-reports a fixed finding as new or rediscovers an `adjacent` one.

New confirmed findings get new ids (`R2-1`, …) and go into the ledger as `open`.

**Oscillation:** a new finding that is the original fault of an earlier `fixed` one, come back in
another shape, means two fixes are fighting. Mark both `stuck` and stop fixing that code.

### L6. Converged, stuck, or another round

**Converged** — every one of these. It is not green yet; it goes to L7:

- no `open` finding left;
- build and tests pass on the last commit;
- the last re-review returned no Change before merge.

**Stop, not green** — any one of these:

- a finding has failed **two** attempts → `stuck`;
- the round cap has been reached;
- every remaining finding is `escalated` or `stuck`.

Stopping still goes through L7 when any round committed: the report must say whether the commits the
loop leaves behind broke anything, even when it is not green.

Otherwise, back to L2 with the `open` findings.

Say one line per round as it ends, in the user's terms, so the transcript shows where the loop is:
`Round 2: fixed 3 of 4, 1 new finding from the re-review, build green.`

### L7. Verify

Read [verify.md](./verify.md) and follow it, at the last round's commit, with `<start>` from L0 and
the review's baseline, Stated intent, usage map, **Decisions in the code** and counterpart. Fixed
findings' `TEST` lines are what V1 looks for in the suite's output.

- **Passes** → **green**. On to L8.
- **Fails, after a converged loop with rounds left** → every failure goes into the ledger as
  `V<k>-<n>`, `open`, and the loop goes back to L2 — then L3, L4, L5, L6, and L7 again. Verify does
  not reset the round cap.
- **Fails at the round cap, or after a stop** → no round can follow. verify.md's **No round left**
  section finds the cause and reports it.

Say one line when it ends: `Verify: build and 412 tests green, 6 fix tests green, fixes read
together — no regression.` or what failed.

### L8. Report, then deliver

The final report is step 7d's report **for the whole PR as it now stands**, with
the verdict reflecting the end state — `<fixed-point>` → `HEAD` in the facts row. The first review covered the original change and every later
round covered its own commits, so together they cover everything. Say so in the facts row:
`🔁 <k> rounds · <n> fixed in <c> commits`.

Then the sections the 7d template does not have, in the same shape and voice:

- **🔧 Fixed by the loop · <n>** — one bullet per fixed finding: the plain-language title, then
  `↳ <commit short sha> · <the fixer's CHANGE sentence>`, then `↳ test: <TEST> · red → green`. A
  finding fixed without a test says `↳ ⚠️ no test — <why>` instead, so the user knows which fixes rest
  on the skeptic alone. A fix that crosses a boundary adds
  `↳ counterpart: <path:line> · <what it does with the new value>`, or `↳ ⚠️ counterpart not read`. A
  fix that changed a line the author wrote, with a decision allowing it, adds
  `↳ changes the author's line: "<what it said>" · decided: <decision>`.
- **⚖️ Decided for you** — the 7d section, now also holding every `ruled-fine` decision from L2b.
  Every **Decided** line on a fixed finding stays visible in its Fixed-by-the-loop bullet, as
  `↳ decided: <decision> · basis: <basis>`, so it can still be overruled.
- **🤔 Needs your decision** — the 7d section: every `escalated` question, and every `stuck` finding
  with both attempts' reasons in one line each.

Anything still `open` stays under **🛠️ Change before merge**, with its **Decided** line when it has
one.

The verdict is **✅ Approve** only when the loop ended green — converged, and L7's verify passed at
the commit being reported. The facts row carries `🔬 verify **passed** at <sha>`. Otherwise
**🛑 Request changes**, and the reason names what is left; a verify failure names what the fixes broke.

Print it whole, before any question. Then **one question**, carrying whichever of these apply, in
this order:

1. **Needs your decision** items — once the user answers, their answers become **Decided** lines
   and the loop runs again from L2, same ledger, two more rounds.
2. **A verify failure the loop caused** (verify.md's **No round left**) — revert the named commit,
   or keep it.
3. **After fix once, with anything still open** — fix until green, which runs from L2 with the
   ledger kept and the cap at 4 counting the round already run.
4. **Worth its own PR** items — fold any into this branch (they join the ledger as `open` and the
   loop runs from L2), or leave them for their own work; name the tracker if the repo has one.

An overrule of anything in **Decided for you** or a Fixed-by-the-loop decision is handled like 1,
and logged as [deliver.md](./deliver.md) says.

Then deliver.md's **Closing**: push if the user chose that **and verify passed** (still ask first
when the branch is not theirs), post the comment or short note if that was chosen — otherwise offer
it, once — and record `pr-review.last-<n>`. A loop that did not end green never pushes, whatever
was chosen earlier. After a push, verify.md's **Pushed** section runs: CI on the pushed SHA gets the
last word, and red CI is a verify failure — one more round if the cap allows, otherwise the verdict
is restated as not green.

**A live check's app** stays up across rounds; stop it after L7 has used it.

Write the ledger's last state into the discarded-reasoning file, and point at it in the footer.
