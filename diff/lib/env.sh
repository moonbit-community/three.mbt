# Paths shared by the shell-script harnesses. Source it (bash):
#
#   . "$(dirname "${BASH_SOURCE[0]}")/../../lib/env.sh"
#
# Sets DIFF, REPO, UPSTREAM (THREE_UPSTREAM, default .repos/three.js) and OUT
# (THREE_DIFF_OUT, default diff/.out). Relative values resolve against REPO.
DIFF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$DIFF/.." && pwd)"
_abs() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$REPO" "$1" ;; esac; }
UPSTREAM="$(_abs "${THREE_UPSTREAM:-.repos/three.js}")"
OUT="$(_abs "${THREE_DIFF_OUT:-diff/.out}")"
mkdir -p "$OUT"
export DIFF REPO UPSTREAM OUT
