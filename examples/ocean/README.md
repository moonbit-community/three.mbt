# Golden hour

Sunset on the open sea, written in MoonBit against the port's `WebGPURenderer` and add-ons:

- `SkyMesh`: atmospheric scattering with procedural clouds.
- `WaterMesh`: the reflective water, with scrolling normals and sun glitter.
- `GLTFLoader` + `DRACOLoader`: the Draco-compressed rubber duck (decoded by the vendored
  wasm decoder), cloned into a flotilla that drifts on a ring and rocks with the swell.
- A chrome `TorusKnotGeometry` that mirrors the sky.
- `PMREMGenerator.fromScene`: whenever the sun moves, the sky is re-baked into the scene
  environment so every reflection follows it. Unlike upstream's `webgpu_ocean`, which
  re-bakes only on slider moves and allocates a new target each time, this bakes into
  one reused render target: with a new target per bake every lit material recompiled its
  pipelines twice a second, which showed as a periodic blink.
- `OrbitControls`, kept above the water, and a `RenderPipeline` with TSL `bloom` on the
  glare.

The sun drifts through sunset on its own ("sunset cycle", re-baking at most twice a
second); the sliders move it by hand and set exposure and cloud cover.

## Run

```bash
cd examples/ocean && moon build --target js
```

Then serve the repository root (`python3 -m http.server 8000` from it) and open
`http://localhost:8000/examples/ocean/index.html` in a browser with WebGPU. The page loads
the debug build first because of a release-build compiler bug (see
`repro/release_hoist_cycle`).
