#!/usr/bin/env bash
# The git tree id of the working tree as it stands — tracked edits and new untracked files,
# ignored files left out — without touching the real index. Equal ids mean identical trees.
#
#   tree-id.sh            # working tree
#   tree-id.sh <rev>      # a commit's tree, for comparing
#
# Run from the repo root.
set -euo pipefail

if [ $# -gt 0 ]; then git rev-parse "$1^{tree}"; exit; fi
tmp=$(mktemp); rm -f "$tmp"
trap 'rm -f "$tmp"' EXIT
GIT_INDEX_FILE=$tmp git read-tree HEAD
GIT_INDEX_FILE=$tmp git add -A
GIT_INDEX_FILE=$tmp git write-tree
