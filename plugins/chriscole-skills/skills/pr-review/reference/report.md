# Step 7d: write the report

**The report answers one question: can this merge?** A title saying what the PR does, then the answer, then only what someone has to act on. A reader who does everything the report says has a mergeable PR, and nothing in the report exists that they cannot act on.

##### Write it so a tired person understands it

The author is reading this at the end of their day, on a phone, on a change they wrote three days ago. Write for them.

**Say what happens before you say why.** Every finding has an effect a person can picture and a mechanism only the code explains. The effect comes first, in its own sentence, and it is the sentence someone who has never opened this repo can still act on.

| Don't | Do |
|---|---|
| "The broadcast reads a snapshot taken before the mutation." | "A second author keeps seeing the old order until they reload." |
| "`reorderMomentsChain` is non-atomic." | "The drag sticks about half the time. The other half it springs back." |
| "Null dereference on the deleted-entity path." | "Open a moment someone else just deleted and the editor goes blank." |
| "The lookup is not locale-aware." | "An en-GB project shows American spelling." |

**Rules that make that happen:**

- **One idea per sentence. Twenty words at most.** Active voice, present tense. Two short sentences always beat one correct long one.
- **Name a person and what they are doing.** "An author dragging a moment", "a learner halfway through a module", "whoever deploys this next". Not "the caller", "the consumer", "the client".
- **Use the repo's nouns and no others.** The repo's glossary is the vocabulary — `CONTEXT.md`, `GLOSSARY.md`, or whatever the profile names. Define anything it omits in one clause, the first time. If you invented the word, it was probably not worth saying.
- **Keep code-internal words out of the effect sentence.** Payload, snapshot, invariant, idempotent, propagate, hydrate, dereference, non-atomic, race — these describe the machine, not the person. They belong in the mechanism sentence, once, or nowhere.
- **Prefer the concrete.** "Loses the order" over "fails to persist state". "Twice in a row" over "under concurrent invocation". "Half the time" over "intermittently".
- **No hedging.** "May potentially fail under certain conditions" says nothing. Say when it fails, or find out.

**The test before you post:** read the effect sentence to somebody who has never seen this code. If they cannot tell you whether it matters, it is still written for the compiler. Rewrite it.

**Layout is part of the answer.** A reviewer scans before they read, so the shape has to survive a three-second glance: verdict, then the facts row, then numbered work. Emoji mark sections and statuses, nothing else — never inside a sentence, never on a bullet, never more than one per heading. They help the eye find a section. They are not decoration.

```
# <what this PR does — one plain-language sentence, no more than fifteen words>

<one sentence more, only when the title alone leaves the reader guessing what it is for>

## ✅ Approve — <one sentence saying why>

`<fixed-point>` → `HEAD` · **<N>** commits · **<F>** files
🔨 build **passed** · 🧪 tests **passed** · 📐 tripwires **clear** · 🖥️ live check **passed** (dummy)

---

## 🛠️ Change before merge · <n>

### 1. <plain-language title — what goes wrong, not what the code does>

`path:line` · <breaks a house rule | not what the PR says it does> · <new here | older than the branch>

- **What happens** — <who is doing what, and what they see — one sentence, no code words>
- **Why** — <the mechanism, one sentence — this is where the code words go>
- **Repro** — <the state and steps that set it off — the skeptic's own words>
- **Fix** — <one sentence>
- **Decided** — <the choice made, plain words> ↳ *basis:* <the evidence, short> · *instead of* <the rejected option>
- **PR says** — "<the declaring sentence>" — <why it still stands>

### 2. <title>

…

---

## ⚖️ Decided for you · <n>

Ruled fine as it is. Reply with the number to overrule one.

- **<k>. `path:line`** — <the decision, in plain words>
  ↳ *basis:* <the evidence, short> · *instead of* <the rejected option>

---

## 🤔 Needs your decision · <n>

Only you can make these calls.

- **<k>. `path:line`** — <the question, with its options, in plain words>
  ↳ *because* <irreversible | security | no evidence either way | the profile says ask>

---

## 📌 Worth its own PR · <n>

Pre-existing, and this change works without them. None of it blocks the merge.

- **`path:line`** — <what happens, plain words> — <who sees it, and when>
  ↳ *present since* <before this branch | commit>

---

🗂️ Discarded reasoning: `<path>`
```

Rules for the shape:

- **The H1 says what the PR does, and it is the first thing on the page.** One plain-language sentence, fifteen words at most — the **Goal** from the intent brief, in the author's terms, written so a reader who has not opened the branch knows what they are being asked to merge. Add one sentence under it only when the title alone leaves them guessing what it is for. Not a list of files, not a summary of the findings, not the PR description pasted back. Write it even when the verdict is an approve — it is what gets read when someone opens this review a month from now. A heading, not a blockquote: a terminal renders a blockquote dim and indented, and the one line everybody needs is the one line nobody should have to hunt for.
- **The verdict is the H2 directly under the title, and it carries its own reason.** `## ✅ Approve` or `## 🛑 Request changes`, then an em dash and one sentence. Subject first, ruling second — a reader who stops after those two headings has both what this is and whether it can merge.
- **The facts row is two lines, never a paragraph.** Range and counts on the first, machine results on the second, separated by `·`. Include only the checks that ran — drop `🖥️ live check` when there was none, add the findings tally to it when step 6b ran (`🖥️ live check **passed** (staging), 2 of 3 findings reproduced`), and write `🧪 tests **not run**` rather than leaving tests out. Mark a failure with ❌ and keep the same line.
- **Findings are H3 and numbered**, so `#2` is a thing a person can say in a reply.
- **No tables anywhere in the report.** Most of this is read in a terminal, where a markdown table wraps into rubble at the first long sentence. Labelled bullets say the same thing and survive any width.
- **The labelled bullets are the finding.** `What happens`, `Why`, `Repro`, `Fix` — always, in that order, one bullet each, label bolded and an em dash after it. Effect first, mechanism second: someone reading only the first bullet should still learn what is broken. `Repro` is the skeptic's line, copied, because the author will check it before they fix anything. `Decided` only when step 6c chose the fix among real alternatives — the basis in a few words and the rejected option, so overruling it takes one reply. `PR says` only when the PR declared the behaviour. No other labels, and nothing outside the bullets.
- **Decided for you and Needs your decision are numbered with the findings**, continuing the count, so "overrule 4" is a thing a person can say.
- **Titles are plain language.** "The drag springs back half the time", not "Non-atomic reorder chain". The title is what gets quoted in Slack.
- **`---` between sections only**, not between findings. The headings already separate those.
- **One section, one emoji**: ✅ 🛑 for the verdict, 🛠️ ⚖️ 🤔 📌 for the four lists, 🗂️ for the footer, and the four in the facts row. That is the whole vocabulary. Do not invent more, and do not put any of them in a finding's sentences.

Omit any heading whose list is empty, and its rule with it. A **Worth its own PR** or **Decided for you** list does not hold back an approve; a **Needs your decision** item about this PR's own code does. **Approve** when nothing this PR caused has to change before merge; say what backs it in the same sentence — build green, tests green, tripwires clear. That is a stronger statement than an empty list, and it is the honest one.

Nothing else goes in the report. No counts of what was dropped, no refuted claims, no observations without a consequence, no account of the method. The reader wants the verdict and the work.

A **Worth its own PR** entry clears the same bar as any other: name what breaks, name who meets it. That section is for defects the reading turned up, not a home for the observations the bar already rejected.

**If the repo's profile says no emoji, drop them and change nothing else.** The structure does the work; the markers only help the eye find it. Same headings, same bullets, same rules — plain `Approve` and `Request changes`, and `passed` / `failed` in the facts row.
