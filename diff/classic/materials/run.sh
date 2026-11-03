#!/usr/bin/env bash
# Regenerates the MoonBit dump from the Material struct, builds it against the repo and
# compares it with upstream. Optional argument: how many failures to print (default 40).
set -eo pipefail
cd "$(dirname "$0")"
python3 gen_harness.py
(cd mbt && moon build --target js 2>&1 | grep -E "^Error" -A6 || true)
node diff.mjs mbt/_build/js/debug/build/bobzhang/three-diff-materials/harness/harness.js "${1:-40}" 2>&1 | cut -c1-240
