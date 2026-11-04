# Loop step L7 — verify the PR as it now stands

Each fix was checked alone. The PR the user ships is all of them at once, and that is where it
breaks: fix A passes, fix B passes, and together they stop the feature working. **Green describes
the tree you hand over.** So the last thing before a verdict is one pass over the final commit, and
nothing is green until it passes.

Skip this step when nothing was fixed.

**Verify the tree, not the transcript.** Everything runs at one SHA, `<final>`, on a clean tree.
Results from before it — a fixer's GREEN, a round's machine run — came from a different tree.

```bash
git status --porcelain        # must be empty
git rev-parse HEAD            # <final>
```

A loop that stopped can leave uncommitted hunks behind: `git stash push -u` them first, and
`git stash pop` after. `<start>` is the SHA before the first fix — the loop's preflight (L0)
records it.

**Spend it in order of cost.** V1 is a shell run; V2 and V3 are agents and run only when they can
find something V1 cannot. Spawn V2 and V3 in one message, after V1 is green — a red V1 already
fails the step, and the agents would read a tree about to change.

## V1. The machine, whole

The repo's full build, full suite and analyzers, filtered exactly as step 2 does — never a fixer's
narrowed command. Then check two things in the output:

- **Every fix's regression test ran and passed.** They are in the suite, so this costs nothing
  extra; it catches a later fix quietly undoing an earlier one. A fix test that did not run at all
  is a failure — the suite does not pick it up, and nothing guards that fix.
- **Nothing is red.** Step 2 reported every failure as a finding, so none should be left.

Only when something is red: tell whether the fixes caused it. When step 2 has the local result in
`<scratch>/pr-<n>-baseline.txt`, compare. When step 2 took CI's word, run the failing tests alone at
`<start>` — not the whole suite. Passed at `<start>`, fails now → a fix broke it. That is the
headline failure of this step. Red at the baseline or at `<start>` too → the fixes did not cause
it: it is an open finding the ledger already holds, reported under **Change before merge**, and it
does not fail verify — but the verdict stays **Request changes** while it is red.

A test that fails once and passes on one rerun is flaky: name it in the report, it does not fail
the step. Twice is not flaky.

## V2. The fixes, read together

One `pr-review-finder` over the cumulative fix diff, `<start>..<final>`. Never inline — the session
that made the fixes is the worst judge of them. Runs only when the fixes have a way to collide that
nobody has read: **two or more rounds committed**, on the first verify only. One round's commits
were re-reviewed together in L5; a round started by a verify failure is re-reviewed there too.

Write the diff to `<scratch>/pr-<n>-fixes.diff`. The prompt is short on purpose — the fixes are
small, and step 5's full paste would cost more than the reading:

> Read `<scratch>/pr-<n>-fixes.diff`, in `<repo path>`. It is not the PR; it is the fixes a review
> applied to it. The PR itself is `<fixed-point>..<start>`, reviewed already — context, not target.
>
> Two questions only:
> 1. **Does the PR still do what its Stated intent says?** A fix that removes a finding by stopping
>    the feature from running is the defect to find. Trace the stated behaviour through the fixed
>    code, end to end.
> 2. **Do the fixes break each other?** Two fixes on one path, a contract one changes and another
>    relies on, a guard one adds and another assumes absent.
>
> **Stated intent, verbatim:** <the round-1 block, whole>
> **Decisions in the code, for these files:** <the 4b entries, or "none">
> **Callers of these files:** <the usage map lines for them>
> **Fixes:** `<id> · path:line · <title> · <the fix's one-sentence change>`, one per line
> **Counterpart:** <only when a fix crossed the boundary — `<path>`, `<version>`, the fixer's citation>
>
> Return the schema from your instructions and nothing else.

Each candidate goes to one `pr-review-verifier`, all in one message, as step 6 — at most the four
of highest consequence; a focused read of a small diff that returns more is guessing. Confirmed with
a `REPRO`, and through 7a → a verify failure.

## V3. The premise, in the app

Only when a live check was approved, and only once — at `<final>`, not per fix and not per round.
One `pr-review-live-checker` gets the **premise** from [live-check.md](./live-check.md) step 0 and
every fixed finding the app can show, in one list: one app, one login, one driver. Reuse the
running app; restart it only when a fix touched how it starts.

Premise no longer holds, or a fixed finding reproduces → a verify failure.

## Green, or not

**Passes** when, at `<final>`: V1 is green with every fix test in it (flakes named), and V2 and V3
found nothing — or had no reason to run. Only then is the verdict **✅ Approve**, and only then is
anything pushed. Facts row: `🔬 verify **passed** at <final short sha>`, with what ran — `V1`,
`V1 V2`, `V1 V2 V3`.

**Fails** → nothing is pushed, the verdict is not Approve, and every failure is reported like any
finding, effect first, so the user sees what the fix broke. Then:

- **Rounds left** — each failure becomes a finding, `V<k>-1`, `V<k>-2`, …, `open`, its failing line
  or the skeptic's `REPRO` as its Repro. A V1 failure is its own red, as loop L3 says. Back to loop
  L2; the round cap still holds.
- **No round left** — the cap is reached, or the loop stopped. See below.

## No round left

Each fixer group is its own commit (L4), so find the cause with the failing check alone:
`git revert --no-commit <group sha>`, rerun it, `git reset --hard <final>`; one group at a time,
newest first. The group whose removal turns it green is the cause. Do this for each failing check
the fixes caused, not only the first.

**Report only — revert nothing the user has not seen.** Each cause goes in the report under
**Change before merge**, naming its commit and what it broke; its findings go back to `open`. The
verdict says the loop's own commits broke something, and loop.md L8's question asks whether to
revert them. On a yes, `git revert <group sha>` — a new commit, so nothing is lost — mark the
findings `↳ fix reverted: <what it broke>`, and rerun **V1 only** on the new `<final>`: removing a
fix cannot create what V2 or V3 look for. No single group is the cause → the fixes interact; see
failure-modes.

A stopped loop that leaves the tree no worse than `<start>` is still not green: the verdict is
**Request changes**, naming what is left.

Never push a tree that failed verify, and never call it green. A reverted fix and an honest
**Request changes** costs an afternoon; a broken main costs a week.

## Pushed

CI runs on a machine this review did not, and it gets the last word. In the background, so it
costs no turns while it runs:

```bash
gh pr checks <n> --watch --fail-fast
```

Until it returns, the verdict reads `✅ Approve — verify passed locally; CI pending on <sha>`. Red
CI is a verify failure, handled as above, and the verdict is restated in one line.
