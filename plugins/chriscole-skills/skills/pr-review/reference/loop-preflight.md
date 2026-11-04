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
- **where the fixes land** — local commits only (the default, always safe), or push at the end.
  Never push mid-loop.

Then return to SKILL.md step 2. Steps 2 to 7 run as written, step 8 asks nothing, and the loop
starts at [loop.md](./loop.md) L1.

**Chosen at step 8** — the user is here, so the step-8 question already covered where the fixes
land. Run the three checks above, then loop.md L1.
