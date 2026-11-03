#!/usr/bin/env bash
# SimplexNoise: upstream (upstream.mjs) against the port (src/addons/math/simplex_noise_test.mbt
# with SIMPLEX_DIFF=1), line for line: `<kind> <index> <hex bits>` over seeded point sets.
#   bash compare.sh [three.mbt checkout, default: this repository]
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$D/../../../../lib/env.sh"
M="${1:-$REPO}"
O="$OUT/addons_a5_simplex"; mkdir -p "$O"
node "$D/upstream.mjs" > "$O/up.txt" || { echo "upstream failed"; exit 1; }
(cd "$M" && SIMPLEX_DIFF=1 moon test --target js src/addons/math/simplex_noise_test.mbt 2>&1) | grep '^@@SIMPLEX ' | sed 's/^@@SIMPLEX //' > "$O/mb.txt"
n=$(wc -l < "$O/up.txt" | tr -d ' ')
if [ "$n" -gt 0 ] && cmp -s "$O/up.txt" "$O/mb.txt"; then echo "simplex: $n lines identical"; else echo "simplex: DIFFERENT ($n upstream lines, $(wc -l < "$O/mb.txt" | tr -d ' ') port lines)"; diff "$O/up.txt" "$O/mb.txt" | head -10; exit 1; fi
