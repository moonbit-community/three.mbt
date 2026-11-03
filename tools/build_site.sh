#!/usr/bin/env bash
# Builds the public demo site into _site/ (or $1): the gallery page, the four demos with
# their MoonBit bundles, and the upstream assets they load (models, skies, textures, the
# Draco decoder). Needs `moon` and the upstream checkout (tools/fetch_upstream.sh).
#
#   tools/build_site.sh [out_dir]
#   python3 -m http.server -d _site 8080     # preview
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-$root/_site}"
upstream="${THREE_UPSTREAM:-$root/.repos/three.js}/examples"
demos=(ocean showroom fluid galaxy)

[[ -d "$upstream" ]] || { echo "missing $upstream: run tools/fetch_upstream.sh" >&2; exit 1; }

rm -rf "$out"
mkdir -p "$out/gallery"

# The gallery, the shared shell, and assets.js pointing at the bundled copies.
cp "$root/examples/index.html" "$root/examples/shell.css" "$root/examples/shell.js" "$out/"
cp "$root/examples/gallery/"*.jpg "$out/gallery/"
cat > "$out/assets.js" <<'EOF'
// The site bundles the assets the demos load (tools/build_site.sh).
export const ASSETS = '../assets/';
EOF

# Each demo: its page and its bundle as main.js (debug build: release JS builds currently
# hit a compiler ordering bug, see repro/release_hoist_cycle).
for demo in "${demos[@]}"; do
  (cd "$root/examples/$demo" && moon build --target js >/dev/null)
  mkdir -p "$out/$demo"
  cp "$root/examples/$demo/index.html" "$out/$demo/"
  cp "$root/examples/$demo/_build/js/debug/build/moonbit-community/three-$demo/main/main.js" "$out/$demo/main.js"
done

# The upstream assets the demos reference, at the same paths below assets/.
assets=(
  textures/equirectangular/venice_sunset_1k.hdr
  textures/equirectangular/royal_esplanade_2k.hdr.jpg
  textures/waternormals.jpg
  models/gltf/duck.glb
  models/gltf/DamagedHelmet/glTF
  jsm/libs/draco/gltf
)
for path in "${assets[@]}"; do
  mkdir -p "$out/assets/$(dirname "$path")"
  cp -R "$upstream/$path" "$out/assets/$path"
done

touch "$out/.nojekyll"
echo "site: $out ($(du -sh "$out" | cut -f1))"
