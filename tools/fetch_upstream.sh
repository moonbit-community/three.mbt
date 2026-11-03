#!/usr/bin/env bash
# Shallow-clones upstream three.js at the commit the port targets into .repos/three.js
# (or $THREE_UPSTREAM). Idempotent: an existing checkout at the right commit is kept.
#
#   tools/fetch_upstream.sh            # the pinned commit
#   THREE_REF=r187 tools/fetch_upstream.sh   # another tag/commit (harness counts may differ)
#
# The port and every differential harness were verified against THREE_COMMIT below: the
# `dev` branch on 2026-11-01, whose REVISION is '187'. It is NOT the r187 release tag
# (7e89746, 2026-10-30): the two differ in about ten src files (VelocityNode, PassNode,
# RenderContext, Textures, ...), and the port follows the dev commit.
#
# Upstream commits its build/ bundles (build/three.module.js, three.webgpu.js, ...), so no
# upstream build step or npm install is needed: the harnesses import upstream's src/,
# build/ and examples/jsm (including the vendored examples/jsm/libs decoders) directly.
set -euo pipefail

THREE_COMMIT=8086b3fda07a70bffad7ee39265c9617994ec482
REF="${THREE_REF:-$THREE_COMMIT}"
URL="${THREE_URL:-https://github.com/mrdoob/three.js.git}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${THREE_UPSTREAM:-.repos/three.js}" in
  /*) DEST="${THREE_UPSTREAM}" ;;
  *) DEST="$ROOT/${THREE_UPSTREAM:-.repos/three.js}" ;;
esac

if [ -d "$DEST/.git" ]; then
  have="$(git -C "$DEST" rev-parse HEAD)"
  want="$(git -C "$DEST" rev-parse --verify --quiet "$REF^{commit}" 2>/dev/null || true)"
  if [ -n "$want" ] && [ "$have" = "$want" ]; then
    echo "upstream at $DEST is already at $have"
    exit 0
  fi
  echo "updating $DEST ($have) to $REF"
else
  mkdir -p "$DEST"
  git -C "$DEST" init -q
  git -C "$DEST" remote add origin "$URL"
fi

# A commit id can be fetched directly from GitHub; a tag name is fetched as a tag.
if [[ "$REF" =~ ^[0-9a-f]{40}$ ]]; then
  git -C "$DEST" fetch -q --depth 1 origin "$REF"
else
  git -C "$DEST" fetch -q --depth 1 origin "refs/tags/$REF:refs/tags/$REF"
fi
git -C "$DEST" -c advice.detachedHead=false checkout -q --force FETCH_HEAD
echo "upstream at $DEST: $(git -C "$DEST" log -1 --format='%h %cd %s' --date=short)"

for f in build/three.module.js build/three.webgpu.js build/three.core.js src/Three.js examples/jsm/libs/draco/draco_decoder.js; do
  [ -e "$DEST/$f" ] || { echo "missing $f in upstream checkout" >&2; exit 1; }
done
