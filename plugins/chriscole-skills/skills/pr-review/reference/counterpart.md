# Step 4b: the counterpart

The other side of a boundary this change crosses. The behaviour a finding turns on often lives in
another codebase: what a service does with a request, how a consumer reads a record, what a library
does with an edge case. The counterpart can be a sibling clone, a vendored copy, or a dependency's
installed source — the profile says where, and which version matters. When the profile says when a
counterpart is needed, follow it: a diff outside its cases gets no block.

Locate it once. For a git clone, read the version named without touching its checkout:

```bash
git -C <counterpart path> fetch -q origin <branch>
git -C <counterpart path> grep -n <names that cross the boundary: endpoints, message types, field names> origin/<branch> | head -40
```

Read only — never check out, never edit. Paste the profile's where-to-look lines and these hits as
a **counterpart** block into every agent.

**A parity claim the profile does not cover** has no where-to-look. Find the source in this order,
and stop at the first hit: a clone named after the system beside this repo's main checkout
(`$(git rev-parse --git-common-dir)/../..`); the dependency's installed or vendored source; the repo
the PR body or a linked ticket names, read with `gh api repos/<owner>/<name>/contents/<path>`. Ask
the user nothing for it. Nothing found → the block says **not found**, every verdict that turns on
the system is unsettled, and the report's facts row says `🔌 counterpart **not read**`.
