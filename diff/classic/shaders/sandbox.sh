# Sourced by inject.sh. try_mutant <name> <file> <tool> <expr> applies one
# mutation (tool: sed -E or perl -0) to a sandbox copy of the port under
# $OUT/classic_shaders/inj (moon.mod, src/math, src/core, src/renderers/shaders without
# tests, plus this harness's dump package as src/dump), never to the repository, builds it
# and runs compare.mjs on it. INJECT_DRY_RUN=1 only checks that each mutation applies.
H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$H/../../lib/env.sh"
S=src/renderers/shaders
INJ="$OUT/classic_shaders/inj"
caught=0; total=0
try_mutant() { # name file tool expr
  rm -rf "$INJ"; mkdir -p "$INJ/src/renderers"
  cp "$REPO/moon.mod" "$INJ/"
  cp -R "$REPO/src/math" "$REPO/src/core" "$INJ/src/"
  cp -R "$REPO/$S" "$INJ/src/renderers/"
  rm -f "$INJ/$S/"*_test.mbt
  cp -R "$H/dump" "$INJ/src/dump"
  local f="$INJ/$S/$2"
  local before after bytes
  before=$(cksum < "$f")
  case "$3" in
    sed) sed -i.orig -E "$4" "$f" && rm -f "$f.orig" ;;
    perl) perl -0pi -e "$4" "$f" ;;
  esac
  after=$(cksum < "$f")
  total=$((total + 1))
  [ "$before" = "$after" ] && { echo "$1: MUTATION DID NOT APPLY"; return; }
  if [ "${INJECT_DRY_RUN:-}" = 1 ]; then echo "$1: applies"; return; fi
  bytes=$(cmp -l "$REPO/$S/$2" "$f" 2>/dev/null | wc -l | tr -d ' ')
  local out code
  out=$( (cd "$INJ" && moon build --target js 2>&1 | grep -E -A6 "^Error" | head -20) ; node "$H/compare.mjs" "$INJ/_build/js/debug/build/dump/dump.js" 2>&1); code=$?
  [ $code -ne 0 ] && caught=$((caught + 1))
  echo "== $1 (exit $code, $bytes bytes differ in source): $(echo "$out" | grep -E 'DIFFERENCES')"
  echo "$out" | grep -E '^DIFF|^Error' | head -2 | cut -c1-170
}
finish() { rm -rf "$INJ"; if [ "${INJECT_DRY_RUN:-}" = 1 ]; then echo "$total mutations checked"; else echo "$caught/$total mutations caught"; fi; }
