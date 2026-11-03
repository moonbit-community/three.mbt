#!/usr/bin/env bash
# CameraUtils.frameCorners: upstream (upstream.mjs) against the port
# (src/addons/utils/camera_utils_test.mbt with CAMERA_UTILS_DIFF=1), value for value (JS
# number strings).
#   bash compare.sh [three.mbt checkout, default: this repository]
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$D/../../../../lib/env.sh"
M="${1:-$REPO}"
O="$OUT/addons_a5_camera_utils"; mkdir -p "$O"
node "$D/upstream.mjs" > "$O/up.txt" || { echo "upstream failed"; exit 1; }
(cd "$M" && CAMERA_UTILS_DIFF=1 moon test --target js src/addons/utils/camera_utils_test.mbt 2>&1) | grep '^@@CAM ' | sed 's/^@@CAM //' > "$O/mb.txt"
n=$(wc -l < "$O/up.txt" | tr -d ' ')
if [ "$n" -gt 0 ] && cmp -s "$O/up.txt" "$O/mb.txt"; then echo "camera_utils: $n cases identical"; else echo "camera_utils: DIFFERENT ($n upstream cases)"; diff "$O/up.txt" "$O/mb.txt" | head -5; exit 1; fi
