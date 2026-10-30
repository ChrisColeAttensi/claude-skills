# Step 6c: decide

A review that ends in a list of questions has handed its hardest work back to the user. Most of those questions have an answer in the repo — in the dependency's source, a probe test, the commit that added the guard, or the five other places this codebase already made the same call. Go and get it. **The default is to decide, and show the reasoning so a wrong call costs one line to overrule.** The user is asked only what genuinely needs them.

**What counts as an open question:**

- every **unsettled** verdict from step 6, and every finding 6b sent here;
- every confirmed finding whose fix has **more than one reasonable shape** with different effects — the finder's or skeptic's `Fix` names a choice ("either reject it or default it"), or the right behaviour is a product call rather than a correction.

A confirmed finding with one obvious fix is not a question. Leave it alone.

**Spawn one `pr-review-decider` per question, all in a single message.** The agent definition holds the evidence ladder and the escalation bar. The prompt carries:

> Answer this open question about `<repo path>`. Scratch directory for probes: `<scratch>`.
>
> **Question:** <the claim and what is unknown about it, or the fix and its competing shapes>
> **Where:** `<path>:<line>`
> **What would settle it:** <the skeptic's note, or "a choice, not a fact">
>
> ```diff
> <the hunk, plus enough surrounding lines to judge it>
> ```
>
> **Stated intent — verbatim:**
> ```
> <the brief's Stated intent block, whole>
> ```
>
> **Written rules that apply:**
> ```
> <the digest entries for this path>
> ```
>
> **Profile decision policy:** <quoted, or "none">
>
> **Overrides log — decisions this user has overruled before:**
> ```
> <the overrides log, filtered to this topic and path's area, or "none">
> ```
>
> Live check: <"not approved", or the URL, mode and driver from step 0>
>
> Return the schema from your instructions and nothing else.

The overrides log lives in the repo's git directory, so it follows the clone and never gets committed:

```bash
cat "$(git rev-parse --git-common-dir)/pr-review-overrides.md" 2>/dev/null
```

**Apply what comes back:**

- **settled confirmed** → a finding like any other, with the decider's `REPRO`. It goes through 7a to 7c.
- **settled refuted** → dropped, into the discarded file with the evidence.
- **decided, `CHANGE: needed`** → a Change-before-merge finding, carrying the decision. It gets a **Decided** bullet in the report.
- **decided, `CHANGE: none`** → the report's **Decided for you** section, so the user can see what was ruled fine and why.
- **escalate** → **Needs your decision**, with the decider's `QUESTION` and the bar it cleared.

**Check the escalations before you accept them.** An escalation whose `ESCALATE` reason does not match the evidence in its own return — no irreversible effect named, no security surface, precedent cited and still "no evidence" — is the decider being cautious, not careful. Send it back once, with the bar quoted. A decision that touches security or something irreversible goes to **Needs your decision** whatever the decider said: those are never decided for the user.

**Check the decisions too, cheaply.** A `precedent` basis has to cite at least two `path:line` sites that agree. One site is an anecdote: treat the basis as `default`, which is still a decision, and say so.

No open questions: skip this step and say nothing about it.
