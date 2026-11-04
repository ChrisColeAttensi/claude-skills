#!/usr/bin/env bash
# Take a fix's hunks out of the working tree, and put them back. New (untracked) files go too.
#
#   hold.sh out  <patch> <files...>   save the files' changes to <patch>, then revert them
#   hold.sh drop <files...>           revert the files' changes, keeping nothing
#   hold.sh in   <patch>              re-apply a saved patch, and check it landed
#
# `git checkout` would leave a new file behind; this does not. Run from the repo root.
set -euo pipefail

mode=${1:?usage: hold.sh out <patch> <files...> | drop <files...> | in <patch>}; shift

take_out() { # $1 = patch path or "" ; rest = files
  local patch=$1; shift
  local new; new=$(git ls-files --others --exclude-standard -- "$@")
  [ -n "$new" ] && git add -N -- $new
  local tmp; tmp=$(mktemp)
  git diff --binary -- "$@" > "$tmp"
  if [ ! -s "$tmp" ]; then
    [ -n "$new" ] && git rm -q --cached -- $new
    rm -f "$tmp"; echo "hold: nothing changed in $*"; [ -n "$patch" ] && : > "$patch"; return 0
  fi
  git apply -R "$tmp"
  [ -n "$new" ] && git rm -q --cached -- $new 2>/dev/null || true
  if [ -n "$patch" ]; then mv "$tmp" "$patch"; echo "hold: saved to $patch and reverted:"; else rm -f "$tmp"; echo "hold: reverted:"; fi
  printf '  %s\n' "$@"
}

case "$mode" in
  out)  patch=${1:?patch path}; shift; take_out "$patch" "$@" ;;
  drop) take_out "" "$@" ;;
  in)
    patch=${1:?patch path}
    if [ ! -s "$patch" ]; then echo "hold: $patch is empty, nothing to apply"; exit 0; fi
    git apply "$patch"
    files=$(git apply --numstat "$patch" | cut -f3)
    git apply -R --check "$patch" 2>/dev/null \
      && echo "hold: re-applied $patch" \
      || { echo "hold: FAILED — $patch did not re-apply cleanly; stop, see failure-modes" >&2; exit 1; }
    printf '  %s\n' $files ;;
  *) echo "hold: unknown mode $mode" >&2; exit 2 ;;
esac
