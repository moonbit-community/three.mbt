# Pixel comparison: three.js vs three.mbt

Renders 13 fixed scenes with upstream three.js (r187, straight from
`.repos/three.js/src/Three.js` as ES modules, no build step) and with the MoonBit port,
reads both frames back with `readPixels`, and compares them channel by channel.

Scenes: `unlit_box`, `lights_directional`, `lights_point`, `lights_spot`,
`lights_hemisphere` (Lambert, Phong and Standard spheres under each light), `shadow`,
`data_texture`, `fog`, `skinned_morph`, `instancing`, `lines_points`, `transparent`,
`render_to_texture`. Canvas 128x96, pixel ratio 1, `antialias: false`,
`preserveDrawingBuffer: true`, one frame each, no animation.

Objects add-on scenes (4, `examples/jsm/objects` on WebGLRenderer): `addon_reflector`
(a `Reflector` floor under a box and a sphere), `addon_refractor` (a `Refractor` pane in
front of three boxes), `addon_sky_water` (`Sky` and `Water` with a generated normal map,
ACES tone mapping) and `addon_lensflare_cubes` (`MarchingCubes` metaballs and a `Lensflare`
with three elements). They are in `objects_scenes.js` / `main/objects_scenes.mbt`; `build`
falls through to them, and `index.html`'s import map points the add-ons' `three` import at
the page's `src/Three.js`. Their GL calls (shader sources, uniforms, the internal renders)
are checked against upstream by the `a6_*` mock-GL scenarios of the diff/core/webgl harness.

## Files

- `main/main.mbt`: the scenes built with the port (a MoonBit main package, JS backend,
  exported as an ES module: `scene_names`, `render_scene`, `release_scene`).
- `scenes.js`: the same scenes built with upstream three.js, line for line.
- `index.html`: runs both, shows the frames, the amplified difference, max / mean channel
  difference and PASS/FAIL per scene.
- `moon.mod`, `moon.work`: a separate module that builds against the repository root
  through a workspace (local path dependencies need `moon.work`).

## Run

```sh
cd examples/pixel_compare
moon build --target js          # writes _build/js/debug/build/bobzhang/three-pixel-compare/main/main.js
cd ../..                        # serve the repository root, so the page can load .repos/three.js
python3 -m http.server 8000
```

Open <http://localhost:8000/examples/pixel_compare/index.html> in a browser with WebGL 2.
(`moon build --target js --release` also works; the page tries the debug output first,
then `_build/js/release/...`.)

## Results

The page sets `window.__pixelResults` to a JSON-serializable object and prints it in a
`<pre>` at the bottom:

```json
{
  "width": 128, "height": 96, "pixelRatio": 1,
  "threshold": { "tolerance": 2, "maxBadFraction": 0.001, "maxMean": 0.1 },
  "scenes": [ { "name": "unlit_box", "max": 0, "mean": 0, "badPixels": 0,
                "badFraction": 0, "pass": true, "error": null }, ... ],
  "allPass": true, "done": true, "error": null
}
```

Wait for `done: true`, e.g. `JSON.stringify(window.__pixelResults)` from automation.

## Threshold

A scene passes when the mean absolute channel difference is at most 0.1 and at most 0.1%
of its pixels (12 of 12288) have any channel off by more than 2.

Both sides should produce the same frame: the mock-GL differential tests check that the
port issues the same GL calls as upstream, including shader sources and every uniform
value, and the scene code on the two sides is a line-for-line mirror. On one GPU the result
is then expected to be bit-identical. The tolerance leaves room for what can still differ:
the port's own math library (e.g. trigonometry in geometry generators) can move a vertex by
an ulp and flip coverage of an isolated edge pixel, which may differ by up to 255 in one
channel. So `max` is reported but not used as a criterion. A real porting bug (a wrong
uniform, state, or draw order) changes whole regions, i.e. hundreds or thousands of pixels
and a clearly higher mean. For example, never uploading the light uniforms makes every lit
scene fail with 1000 to 8000 bad pixels while the unlit scenes still pass.

## WebGPU renderer (`webgpu.html`)

`webgpu.html` compares upstream's `WebGPURenderer` with the port's (`webgpu/main.mbt`,
mirroring `webgpu_scenes.js` line for line). Each scene renders at 128×96 into a render
target, is read back with `readRenderTargetPixelsAsync`, and must be byte-identical
(`differing: 0`); there is no tolerance. Open
`http://localhost:8000/examples/pixel_compare/webgpu.html` for the WebGPU backend and
`webgpu.html?webgl=1` for the WebGL fallback (`forceWebGL: true`) on both sides. Results are
in `window.__pixelResults` once `done` is true.

A page that gets no animation frames (a hidden or embedded pane) would stall WebGL
readbacks, because both renderers poll the fence with `requestAnimationFrame`; the page
probes for a frame and falls back to a 16 ms timer for both sides.

The port side imports one package, the `bobzhang/three/webgpu` facade as `@three`, so
`new THREE.Mesh( ... )` is `@three.Mesh::new(...)` and `TSL.uv()` is `@three.uv()`.

Scenes (20): `unlit_box`, `lit_spheres`, `data_texture`, `instancing`, `lines_points`,
`transparent`, and the ones that only a GPU can check:

- `shadow_directional` (PCF), `shadow_spot`, `shadow_point` (cube shadow map): a box on a
  ground plane, `renderer.shadowMap.enabled`;
- `pmrem_env`: MeshStandard (metal) and MeshPhysical (clearcoat) spheres lit by a
  half-float equirectangular `scene.environment`, which goes through PMREM;
- `cube_background`: a `CubeTexture` of six DataTexture faces as background and as a
  MeshBasic `envMap`;
- `post_pass`: a `RenderPipeline` whose output is `pass( scene, camera )` mixed with its
  luminance by `step( 0.5, uv().x )`;
- `tone_mapping`: ACES filmic tone mapping, exposure 1.5 and sRGB output, written to the
  target through `setOutputRenderTarget( target )` (the framebuffer target + output pass);
- `tsl_material`: a `Fn` checker `colorNode` and an `mx_noise_float` displacement
  `positionNode`;
- `compute_instances`: a compute `Fn` writes an `instancedArray`, an InstancedMesh reads it
  with `positionNode = positionLocal.add( positions.toAttribute() )`;
- `msaa_target`: the render target has `samples: 4`;
- `skinned_morph`: a morph target and a two-bone SkinnedMesh;
- `fog`: `scene.fog` with a background color;
- `texture_formats`: Float and HalfFloat DataTextures and a mipmapped CanvasTexture drawn
  procedurally on a 2D canvas;
- `sprites`: SpriteNodeMaterial with a color, a `rotationNode` and a transparent map.

Add-on scenes (9, the display add-ons of `examples/jsm/tsl/display`): `addon_fxaa`,
`addon_gaussian_blur`, `addon_sobel`, `addon_rgb_shift`, `addon_dof`, `addon_gtao` (an MRT
normal pass), `addon_ssr` (MRT normal + metalness/roughness), `addon_pixelation`,
`addon_ssaa` (sample level 2): a standard box, metallic sphere and glossy ground through a
RenderPipeline whose output is the add-on node. `webgpu_scenes.js` imports each scene's
add-on modules (`ADDON_MODULES`) before building it, and the MoonBit side calls their
`load_*()` at the same point (`load_addons`); the add-ons' bare `three/webgpu` / `three/tsl`
imports resolve through the import map in `webgpu.html` (under Node, through the A4 resolve
hooks the G9 pixel runners register).

Objects add-on scenes (4, the WebGPU variants of `examples/jsm/objects`):
`addon_sky_mesh` (`SkyMesh` with clouds), `addon_water_mesh` (`WaterMesh` reflecting a box
through its `reflector()`), `addon_water2_mesh` (Water2Mesh.js's `WaterMesh`: reflector plus
viewport refraction) and `addon_lensflare_mesh` (`LensflareMesh` with three elements). They
are in `webgpu_objects_scenes.js` / `webgpu/objects_scenes.mbt`; `buildAddon` / `build_addon`
fall through to them. These scenes read `time` / NodeFrame's delta time, so the mock
runners give both sides one deterministic `performance.now` for them
(`installObjectsClock` in the G9 harness's pixel_common.mjs); in a browser the two
renderers' clocks differ by microseconds, far below a visible change.

A5 add-on scenes (11, `examples/jsm/tsl/display`, `tsl/lighting`, `tsl/shadows`):
`addon_bloom`, `addon_smaa`, `addon_ssao` (MRT normal pass), `addon_outline` (the box
selected, visible and hidden edges), `addon_film` (intensity 0: the grain reads `time`),
`addon_chromatic_aberration`, `addon_lut3d` (an 8³ Data3DTexture), `addon_after_image` (4
frames, the box moving), `addon_traa` (5 jittered frames, MRT velocity), `addon_tile_shadow`
(`TileShadowNode` 2x2 on the directional light) and `addon_dynamic_lights` (a Lighting whose
nodes are `DynamicLightsNode`s, three point lights and a spot). They are in
`webgpu_a5_scenes.js` / `webgpu/a5_scenes.mbt`; `buildAddon` / `build_addon` fall through to
them. Multi-frame scenes advance one animation frame between renders (`a5Tick`, the body of
Animation's `update`), since requestAnimationFrame cannot fire inside the synchronous render.
SMAA's area and search images decode asynchronously, so both sides render before they have
loaded.

All images are generated (DataTexture or 2D canvas); nothing is fetched. A scene is
`view( scene, camera, { samples, before, render } )`: `before( renderer, target )` runs
after `init` (shadow settings, tone mapping, a compute pass), `render( renderer )` replaces
`renderer.render( scene, camera )` (the RenderPipeline).

Before a browser run, both sides of every scene are compared on recording mocks (the G9
harness, `diff/core/g9/harness/run_pixel.mjs`): with the mock GPU, and with
`--webgl` on the mock WebGL 2 context (`forceWebGL: true`). Each scene's log (every GPU/GL
call with its arguments, WGSL/GLSL sources and uniform uploads) must be identical.
