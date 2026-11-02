# Step 9 — verify the PR as it now stands

A fix is new code that nobody has run against the whole PR. Each fix was checked on its own — its
test, its files — and that is exactly how a PR ships broken: fix A passes, fix B passes, and A and
B together break the feature the PR was for. **Green is a statement about the tree you hand over,
not about the fixes one at a time.** So the last thing before a verdict is one pass over the final
state, from cold, and nothing is green until it passes.

Runs whenever this review or the loop changed code. A review that only commented changed nothing:
skip this step and say nothing about it.

**Verify the tree, not the transcript.** Everything below runs at one SHA, `<final>`, on a clean
tree. Earlier results — a fixer's GREEN, step 3's machine run, a round's re-review — are not
evidence here. They were true of a different tree.

```bash
git status --porcelain        # must be empty; a dirty tree is not a state anyone can ship
git rev-parse HEAD            # <final>
```

`<start>` is the SHA before the first fix: the loop's preflight records it, and for a single review
it is `HEAD` when step 8 began. **The baseline** is step 2's build and test result, kept in
`<scratch>/pr-<n>-baseline.txt`; when step 2 took CI's word instead of running locally, run the
same commands at `<start>` first, so both sides of the comparison come from this machine.

## The four checks

Run V1 and V2 first, together — they are free. Spawn V3 and V4 in one message once they are back.

### V1. The machine, whole

The repo's full build and full test suite, plus analyzers, exactly as step 2 ran them — never the
narrowed commands a fixer used. Compare against step 2's baseline:

- every build error, analyzer warning and failing test is listed by name;
- **anything that passed at the baseline and fails now** is a fix's breakage. It is the headline
  failure of this step.
- anything that failed at the baseline was already a finding; it passes now or that finding is not
  fixed, whatever the ledger says.

A test that fails once and passes on one rerun is flaky. Name it in the report; it does not fail
the step. Twice is not flaky.

### V2. Every fix still holds

Run every regression test the fixes added, together, at `<final>`. Each one went green in its own
round; a later fix can quietly undo it. One that fails now means its finding is open again — and in
the loop, that is the oscillation pr-review-loop step 5 describes, caught after the fact.

Fixes with no test have nothing to run here. They lean on V3.

### V3. The fixes, read together, against what the PR is for

One `pr-review-finder` over the **cumulative fix diff**, `<start>..<final>`. Never inline: the
session that wrote or chose the fixes is the worst judge of them.

- **Single review** — always. The fixes have not been reviewed by anyone yet.
- **The loop** — only when more than one round committed. One round's commit was already
  re-reviewed whole; two or more were each reviewed alone, and how they meet was not.

Write the diff to `<scratch>/pr-<n>-fixes.diff` and give the finder step 5's prompt, with the
round-1 intent brief, digest, usage map, **Decisions in the code** and counterpart, and two changes:

> Your area is not a feature; it is the fixes a review applied to this PR. The PR's own change is
> `<fixed-point>..<start>` and was reviewed already — read it as context, not as the target.
>
> Two questions only:
> 1. **Does the PR still do what its Stated intent says?** A fix that makes a finding go away by
>    making the feature not run is the defect to find. Trace the stated behaviour through the fixed
>    code, end to end.
> 2. **Do the fixes break each other?** Two fixes on one path, a fix that changes a contract another
>    fix relies on, a guard added in one place and assumed absent in another.
>
> **Fixes applied, one line each:** `<id> · path:line · <title> · <the fix's CHANGE sentence>`

Every candidate it returns goes to one `pr-review-verifier`, all in one message, exactly as step 6.
Confirmed with a `REPRO` → a verify failure. Then 7a and 7c rule on it like any other finding —
a regression nobody meets is not one.

### V4. The premise, in the app

Only when a live check was approved. Run `pr-review-live-checker` once more, at `<final>`, on the
**premise** from [live-check.md](./live-check.md) step 0 — the claim the PR makes, not the findings.
The fixes changed the code under that claim; the earlier premise check saw the old code. The app
stays up from the earlier run when it can; restart it when a fix touched how it starts.

Not reproduced in the app, when it worked before the fixes → a verify failure. Its effect sentence
is what the user does and what they now see.

## Green, or not

**Verify passes** when every one of these holds at `<final>`:

- V1: build green, full suite green (flakes named), no analyzer warning the baseline did not have;
- V2: every regression test green;
- V3: no confirmed finding that survives 7a — or V3 did not need to run;
- V4: the premise still holds — or no live check was approved.

Only then can the verdict be **✅ Approve**, and only then may anything be pushed. Say it in the
facts row: `🔬 verify **passed** at <final short sha>`, and name what ran — `V1 V2 V3`, `V1 V2 V4`.

**Verify fails** → nothing is pushed and the verdict is not Approve. What happens next depends on
who ran the fixes. Either way, report a failure in the same shape as any finding — effect first —
so the user sees what the fix broke:

- **The loop** — every failure becomes a finding with a new id, `V<k>-1`, `V<k>-2`, …, `open` in the
  ledger, its failing line or the skeptic's `REPRO` as its Repro. A V1 or V2 failure is its own red,
  as loop step 3 says. Back to loop step 2. The round cap still holds; verify does not reset it.
- **A single review** — it does not loop. Find the fix that caused each failure: revert one fix at a
  time — each fix is its own commit (step 8), so `git revert --no-commit <fix sha>` — rerun the
  failing check, then `git reset --hard <final>` to restore. The fix
  whose removal turns it green is the cause. Revert that fix for good, put its finding back in
  **Change before merge** with `↳ fix reverted: <the failure it caused>`, and **run verify again**
  on the new `<final>`. When no single fix is the cause, revert them all, and say the fixes
  interacted. Then recommend `/pr-review-loop`, which can rework them.

Never push a tree that failed verify, and never call it green. A reverted fix and an honest
**Request changes** costs an afternoon; a broken main costs a week.

## Pushed

When the fixes are pushed, CI runs on a machine this review did not. It gets the last word:

```bash
gh pr checks <n> --watch --fail-fast
```

Run it in the background. Until it returns, the verdict line says `✅ Approve — verify passed
locally; CI pending on <sha>`. Red CI is a verify failure, handled as above — in the loop a new
round, in a single review a revert and a follow-up push — and the verdict is restated in one line.
