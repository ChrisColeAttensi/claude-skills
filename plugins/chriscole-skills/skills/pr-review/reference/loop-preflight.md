# Fix loop L0: preflight

Before any fixer runs:

- **The branch must be checked out here.** If the PR's head is not the current branch, ask before
  `gh pr checkout <n>` — it changes the user's working tree.
- **The working tree must be clean.** `git status --porcelain` empty. Otherwise stop and say so:
  the loop commits, and it must never sweep the user's unfinished work into a commit.
- **Record the start:** `git rev-parse HEAD` is `<start>`. Every commit after it is the loop's own.

**Invoked as `/pr-review loop`** — this runs right after step 1 resolves the target, before any
agent, and asks everything the loop will need **once, together**, so it can run unattended:

- any `ask-first` pass the repo's profile would fire, and the live check if there is one — one yes
  covers every round, and the app stays up across them;
- **push when done?** — only on the user's own branch (see deliver.md **Whose push**). Word it so
  commits are never in question: "Fixes are always committed locally. Push them automatically once
  verify passes? (default: no, you push)". A yes is the go-ahead: Closing pushes without asking
  again. On someone else's branch, don't ask here — Closing asks once, after verify, when the
  answer means something. Never push mid-loop.

Then return to SKILL.md step 2. Steps 2 to 7 run as written, step 8 asks nothing, and the loop
starts at [loop.md](./loop.md) L1.

**Chosen at step 8** — the user is here, so the step-8 question already covered whether to push (or left
it to Closing, on someone else's branch). Run the three checks above, then loop.md L1.
