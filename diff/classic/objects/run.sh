#!/usr/bin/env bash
# Raycast / bounds / frustum / skinning / skeleton / BatchedMesh scenarios of the
# src/core objects vs upstream.
#   run.sh [seed] [scale]      (default: seed 1, scale 1 = 3050 scenarios)
# gen.mjs writes the scenarios, run_upstream.mjs and the MoonBit runner (mbt/diff) each
# write their results, compare.mjs compares them. Files go to $THREE_DIFF_OUT/classic_objects.
# OBJECTS_RUNNER=<diff.js> runs another build of the MoonBit side (mutate.py).
set -eo pipefail
cd "$(dirname "$0")"
. ../../lib/env.sh
O="$OUT/classic_objects"; mkdir -p "$O"
RUNNER="${OBJECTS_RUNNER:-mbt/_build/js/debug/build/moonbit-community/three-diff-objects/diff/diff.js}"
[ -n "$SKIP_BUILD" ] || [ -n "$OBJECTS_RUNNER" ] || (cd mbt && moon build --target js 2>&1 | grep -E "^Error" -A6 || true)
node gen.mjs "$O/scenarios.json" "${1:-1}" "${2:-1}"
node run_upstream.mjs "$O/scenarios.json" "$O/upstream.json"
node "$RUNNER" "$O/scenarios.json" "$O/port.json"
node compare.mjs "$O/scenarios.json" "$O/upstream.json" "$O/port.json"
