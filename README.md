# three.mbt

A faithful port of [three.js](https://github.com/mrdoob/three.js) (r187) to
[MoonBit](https://www.moonbitlang.com/), on MoonBit's JS backend. It is a rewrite, not
bindings: upstream's structure, behaviour and output, with snake_case names.

- **The whole of upstream `src`**:
  - math, the scene graph, geometries, materials, animation, loaders, helpers, audio and
    WebXR;
  - `WebGLRenderer` with its shader library;
  - the node system and TSL, node materials, `WebGPURenderer` and its WebGL 2 fallback.
- **Tier-1 add-ons** (`src/addons`):
  - the controls (Orbit, Map, Trackball, Arcball, Fly, FirstPerson, PointerLock, Drag,
    Transform);
  - `GLTFLoader` with Draco, KTX2 and meshopt;
  - the HDR, RGBE, EXR, UltraHDR and HDR cube loaders;
  - every TSL post-processing node (bloom, SMAA, SSAO, GTAO, SSR, depth of field, TRAA,
    outline, ...);
  - Sky, Water, Reflector, Refractor, Lensflare, MarchingCubes and the other objects;
  - RoomEnvironment;
  - the key utils.

## Verified against upstream

Every layer is compared with upstream three.js running the same scenario, not only unit
tested:

- **Generated shaders:** WGSL and GLSL, byte for byte (1846 scenarios).
- **Renderer calls on recording mock WebGL 2 / WebGPU contexts:** compared entry for
  entry, including every shader source and uniform upload.
- **Loader output:** scene graphs, materials, attribute and texture bytes. glTF uses 50 of
  upstream's sample models; EXR covers every compression.
- **Controls:** replayed pointer, touch, wheel and key events, about 112k entries.
- **Real GPU pixels, in a browser:** 44 WebGPU scenes, the same on the WebGL fallback,
  21 classic scenes and 5 glTF models, all byte-identical to upstream.

`moon test` runs the ported unit tests (1826). `diff/` holds the differential harnesses,
which run in plain Node (`node diff/run_all.mjs`; see [diff/README.md](diff/README.md)),
and CI runs both. [PORTING.md](PORTING.md) records the conventions, the design decisions,
the measured status and the known gaps.

## Using it

```moonbit
let renderer = @webgpu.WebGPURenderer::new(canvas~)
let scene = @core.Scene::new()
let camera = @core.PerspectiveCamera::new(fov=50.0, aspect=16.0 / 9.0)
camera.position.set(0.0, 0.0, 3.0) |> ignore
let material = @nodes.MeshStandardNodeMaterial::new()
@nodes.NodeMaterial::of(material).unwrap().color_node = Some(
  @nodes.mix(@nodes.color(0x3355ff), @nodes.color(0xff6633), @nodes.uv().x()),
)
scene.add(@core.Mesh::new(geometry=@geometries.BoxGeometry::new(), material=Single(material)))
|> ignore
renderer.init(on_done=fn(_) {
  renderer.set_animation_loop(Some(fn(_, _) { renderer.render(scene, camera) }))
})
```

`bobzhang/three/webgpu` (imported as `@three`) re-exports `WebGPURenderer`, the node
materials and TSL from one place.

## Examples

Each example is its own module next to the port: `moon build --target js` in its
directory, serve the repository root, and open its `index.html`.

- [examples/ocean](examples/ocean): golden hour on the sea. SkyMesh, WaterMesh, a
  Draco-compressed glTF flotilla, PMREM re-baked as the sun moves, and bloom.
- [examples/showroom](examples/showroom): DamagedHelmet under an HDR sky, with
  OrbitControls and TSL bloom.
- [examples/galaxy](examples/galaxy): 131k stars simulated by TSL compute shaders.
- [examples/pixel_compare](examples/pixel_compare): the pages that render the same scenes
  with upstream and with the port and compare the pixels.

## Development

```sh
tools/fetch_upstream.sh          # upstream three.js at the commit the port targets
moon check --target js
moon test --target js
node diff/run_all.mjs            # differential harnesses against upstream
```

Use debug builds for now. Release JS builds can fail at load because of a MoonBit compiler
ordering bug; [repro/release_hoist_cycle](repro/release_hoist_cycle) has the minimal
repro.

## License

MIT, as three.js: see [LICENSE](LICENSE). The port follows upstream's code closely, and
upstream's copyright notice applies.
