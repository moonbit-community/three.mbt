#!/usr/bin/env bash
# A4 pass-group bug injection, one bug per call:
#   diff/addons/tsl/a4/inject_pass.sh <file in src/addons/tsl> <old> <new> <shader|mock> [names...]
# Replaces <old> (must occur once) by <new>, runs the shader harness (group pass) or rebuilds
# the G9 MoonBit side and runs the A4 mock-GPU scenarios, then restores the file (also on
# error or Ctrl-C). INJECT_DRY_RUN=1 only checks that <old> occurs once.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/../../../lib/env.sh"
F="$REPO/src/addons/tsl/$1"; OLD="$2"; NEW="$3"; KIND=$4; shift 4
BAK="$OUT/inject_backup/inject_pass_$(basename "$F")"
mkdir -p "$(dirname "$BAK")"
cp "$F" "$BAK"
restore() { cp "$BAK" "$F" && rm -f "$BAK"; }
trap restore EXIT INT TERM
python3 - "$F" "$OLD" "$NEW" "${INJECT_DRY_RUN:-0}" <<'PY' || { echo "PATTERN FAIL"; exit 1; }
import sys
p,o,n,dry=sys.argv[1:5]
s=open(p).read()
assert s.count(o)==1, ('count', s.count(o))
if dry != '1': open(p,'w').write(s.replace(o,n))
PY
[ "${INJECT_DRY_RUN:-0}" = 1 ] && { echo "pattern ok"; exit 0; }
if [ "$KIND" = shader ]; then
  (cd "$DIFF/core/webgpu/shader_diff" && node run_a4.mjs --group pass "$@" 2>&1 | grep -E "^(MISMATCH|MISSING)|identical")
else
  (cd "$DIFF/core/g9/mbt" && moon build --target js 2>&1 | grep -E "^Error" | head -3; cd ../harness && node run_a4.mjs --quiet "$@" 2>&1 | grep -E "^(DIFF|FAIL)|identical" | cut -c1-200)
  restore; trap - EXIT
  (cd "$DIFF/core/g9/mbt" && moon build --target js >/dev/null 2>&1)
fi
