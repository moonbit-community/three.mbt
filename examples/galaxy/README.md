# GPU particle galaxy

131,072 stars simulated entirely on the GPU by TSL compute shaders, written in MoonBit
against the port's `WebGPURenderer` (one import: `bobzhang/three/webgpu` as `@three`).

- **Seeding** (`seed_kernel`): a compute pass places each star on a three-armed spiral disk
  from per-particle hashes and gives it the circular orbital speed of the central mass.
- **Simulation** (`step_kernel`, every frame): gravity of the central mass and of three
  wandering attractors, a pull back to the disk plane, relaxation towards circular orbits
  (radial motion damped, tangential speed eased to `sqrt(G / r)`), a soft leash beyond
  radius 4, a speed limit, then integration. The attractors circle slower than the stars
  around them, which winds the disk into arms and tidal streams.
- **Rendering**: an `InstancedMesh` of `SpriteNodeMaterial` quads reading the position
  buffer through `positionNode`, additive soft discs coloured by radius (gold core, pink
  arms, blue rim) and brightened by speed. Three glow sprites mark the attractors; their
  CPU path mirrors the shader's.

Controls: drag to orbit, scroll to zoom, hold the right mouse button or Space to make
every attractor repel. Let go and the stars fall back and the disk re-forms.

## Run

```bash
cd examples/galaxy && moon build --target js
```

Then serve the repository root (for example `python3 -m http.server 8000` from it) and
open `http://localhost:8000/examples/galaxy/index.html` in a browser with WebGPU. Without
WebGPU, `WebGPURenderer` falls back to its WebGL 2 backend (compute then runs through
transform feedback); the HUD names the backend in use.

The page loads the debug build first: the release build can currently fail at load because
of a compiler ordering bug (see `repro/release_hoist_cycle`).
