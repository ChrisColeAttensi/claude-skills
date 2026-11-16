#!/usr/bin/env bash
# Step 4b's three shell facts, in one run: usage map, omission check, decisions in the code.
#
#   surroundings.sh <fixed-point> [search-root]
#
# Run from the repo root. search-root defaults to the whole repo (tracked files only).
# Prints three labelled sections; paste them per area into the agents' prompts.
set -uo pipefail

fp=${1:?usage: surroundings.sh <fixed-point> [search-root]}
root=${2:-}
[ -z "$root" ] && root=.
# git grep: tracked files only, so node_modules and build output never match. Docs and styles are not callers.
skip=(':!*.md' ':!*.css' ':!*.scss' ':!*.lock' ':!*.snap')

changed=$(git diff --name-only "$fp"...HEAD)
n=$(printf '%s\n' "$changed" | grep -c . || true)

# At most six per line; a seventh hit means the list was cut.
cap6() { awk 'NR<=6 { printf "%s ", $0 } NR==7 { printf "(more) " }'; }

echo "## Usage map — importers found per changed file, at most six; (more) means the list stopped there, an empty line means none found"
printf '%s\n' "$changed" | while read -r f; do
  [ -z "$f" ] && continue
  b=$(basename "$f"); b="${b%.*}"
  printf '%s <- ' "$f"
  git grep -lw -- "$b" -- "$root" "${skip[@]}" 2>/dev/null | grep -vx "$f" | cap6
  echo
done

names=$(git diff "$fp"...HEAD | grep '^+' \
  | grep -oE 'export (default )?(async )?(function|const|let|class|type|interface|enum) [A-Za-z_][A-Za-z0-9_]*' \
  | awk '{print $NF}' | sort -u)
echo
echo "## Newly exported names — files that use each, outside its own; an empty line means none found"
if [ -z "$names" ]; then
  echo "(none — reads ES-module export syntax only; in other languages, not checked)"
else
  printf '%s\n' "$names" | while read -r name; do
    printf '%s <- ' "$name"
    git grep -lw -- "$name" -- "$root" "${skip[@]}" 2>/dev/null \
      | grep -vxF -f <(git grep -lE "export .*\b$name\b" -- "$root" 2>/dev/null) | cap6
    echo
  done
fi

echo
echo "## Normally changes alongside these files, and did not this time (history of the first ten changed files)"
if [ "$n" -gt 40 ]; then
  echo "(skipped: $n files changed, over 40)"
else
  printf '%s\n' "$changed" | head -10 | while read -r f; do
    [ -z "$f" ] && continue
    git log --format='%H' -n 15 "$fp" -- "$f" | while read -r c; do git show --name-only --format= "$c"; done
  done | grep . | grep -vxF -f <(printf '%s\n' "$changed") | sort | uniq -c | sort -rn | head -15
fi

echo
echo "## Decisions in the code — added comments that state a choice"
git diff -U0 "$fp"...HEAD | awk '
  /^\+\+\+ / { file = substr($0, 7) }
  /^\+[^+]/ && tolower($0) ~ /(\/\/|#|--|\/?\*|<!--).*(deliberate|on purpose|intentional|by design|never|always|instead of|rather than|stays|keeps|must not|so that|so we|we accept|as entered|on the assumption|by choice|we want|we chose)/ \
    { print file ": " substr($0, 2) }' | head -150
