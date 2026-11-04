#!/usr/bin/env bash
# The lines a change removes or rewrites that the PR's author wrote.
#
#   authors-lines.sh <fixed-point> <start> <rev> [<to>] -- <files...>
#
# <fixed-point>  the PR's base, from step 1 — never a later round's
# <start>        the SHA before the loop's first fix (L0); commits after it are the loop's own
# <rev>          the old side of the change: HEAD for an uncommitted fix, <round-k-base> for a round
# <to>           the new side; omit for the working tree, <round-k-head> for a committed round
#
# Prints `file:line  <blame line>` for each author line touched; nothing means none.
set -euo pipefail

fp=${1:?}; start=${2:?}; rev=${3:?}; shift 3
to=""
if [ "${1:-}" != "--" ]; then to=$1; shift; fi
[ "${1:-}" = "--" ] && shift

loop=$(git rev-list "$start".."$rev" | tr '\n' ' ')

git diff -U0 "$rev" ${to:+"$to"} -- "$@" | awk '
  /^--- a\// { file = substr($0, 7); next }
  /^--- /    { file = ""; next }
  /^@@/ && file != "" {
    split($2, a, ","); line = substr(a[1], 2); count = (2 in a) ? a[2] : 1
    if (count > 0) print file, line, count
  }' | while read -r file line count; do
  git blame -s -l "$fp".."$rev" -L "$line",+"$count" -- "$file" 2>/dev/null \
    | awk -v loop="$loop" -v f="$file" 'substr($0,1,1) != "^" && index(loop, substr($0,1,40)) == 0 { print f ": " $0 }'
done
