# Showroom

The DamagedHelmet glTF under an HDR sunset, rendered by the MoonBit port's
`WebGPURenderer` with the ported add-ons:

- `GLTFLoader` loads the model (textures, PBR materials, emissive map).
- `HDRLoader` loads `venice_sunset_1k.hdr`. As `scene.environment` it lights the
  materials through PMREM; as a blurred `scene.background` it frames the model.
- `OrbitControls` gives drag/zoom/pan with damping, auto-rotating until you take over.
- A `RenderPipeline` adds TSL `bloom` to the scene pass, so the emissive visor and panels
  glow. The bloom strength is a uniform driven by the slider.

## Run

```bash
cd examples/showroom && moon build --target js
```

Then serve the repository root (`python3 -m http.server 8000` from it) and open
`http://localhost:8000/examples/showroom/index.html` in a browser with WebGPU; without it
the renderer falls back to WebGL 2. The page loads the debug build first because of a
release-build compiler bug (see `repro/release_hoist_cycle`).
