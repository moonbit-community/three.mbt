# Differential harnesses

Every harness here runs the same scenario on upstream three.js (`.repos/three.js`, from
`tools/fetch_upstream.sh`) and on the MoonBit port, in plain Node, and compares the two
results: call logs on recording mock WebGL 2 / WebGPU / Web Audio contexts, generated
shader text byte for byte, scene graphs, attribute and texture bytes, JSON text, numbers
with `Object.is`. They complement `moon test` (the ported unit tests), which CI runs
separately.

```sh
tools/fetch_upstream.sh            # once: upstream three.js at the commit the port targets
node diff/run_all.mjs              # every check (fast default, about 7 min warm)
node diff/run_all.mjs --full       # + the long ones (all EXR corrupt inputs, hang probes)
node diff/run_all.mjs --list       # what would run
node diff/run_all.mjs --only g9,hdr   # areas (core, classic, addons), names or name prefixes
node diff/run_all.mjs --no-build   # skip rebuilding the MoonBit sides
```

`run_all.mjs` rebuilds the MoonBit side of each selected check (`moon build --target js`
in its module), runs it, prints one line per check and exits 1 on any mismatch, failure or
timeout. The full output of each check is in `diff/.out/logs/<name>.log`.

Requirements: `moon` (and `moonfmt` for the generator checks), Node 22 or newer,
`python3` (materials' generator, the injection tools), `bash`, `tar`/`xz` (EXR fixtures).
No npm packages: upstream's `build/`, `src/` and the decoders vendored in
`examples/jsm/libs` (Draco, Basis, ktx-parse, zstddec, meshopt, fflate) are used directly.

Pixel comparisons need a real GPU and a browser and stay manual: see
`examples/pixel_compare` (`index.html`, `webgpu.html`, `?webgl=1`, `gltf.html`). The
mock-GPU / mock-GL logs of the same scenes are the `g9_pixel*` checks here.

## Paths and environment

| variable | default | |
| --- | --- | --- |
| `THREE_UPSTREAM` | `.repos/three.js` | upstream checkout |
| `THREE_DIFF_OUT` | `diff/.out` | generated outputs, logs, fixtures, scratch copies (gitignored) |

Relative values resolve against the repository root. Scripts get these paths from
`diff/lib/env.mjs`, `env.sh` or `env.py`; nothing in `diff/` holds an absolute path. A
harness writes only under `OUT/<area>_<harness>/`.

The MoonBit side of a harness is a small module in the harness directory whose
`moon.work` lists `.` and the repository root (as `examples/` do), so it builds against
the real `src/`. Some harnesses have no module of their own: their MoonBit side is a
`*_diff_test.mbt` / `*_shader_diff_test.mbt` file in `src/`, run by `moon test` with an
environment flag (`SHADER_DIFF=1`, `WEBGL_DIFF=1`, `G6_DIFF=1`, `A6_DIFF=1`, ...) that
makes it print its records; without the flag these files are ordinary tests.

## Layout and checks

Old name = the directory the harness was developed in (as referenced in older notes).

### core (`diff/core`)

| dir (old name) | check | compares | expected |
| --- | --- | --- | --- |
| `webgl` (webgl_foundation) | `webgl` | classic `WebGLRenderer` and its modules on the recording mock WebGL 2 context (`harness/mock_gl_body.js`), incl. WebXR and the a6 objects' WebGL variants; `src/renderers/webgl/*_test.mbt` with `WEBGL_DIFF=1` vs `harness/scenarios/*.mjs`. `tools/`: the gl spec, binding and mock generators | `52 ok, 0 failed` |
| `webgpu` (webgpu_foundation/harness) | `shader` | WGSL/GLSL/base-builder shader text of every group (G1-G10, A4-A6) byte for byte: every `src/**/*shader_diff_test.mbt` (`SHADER_DIFF=1`) vs `shader_diff/upstream*.mjs` (A4/A5/A6 groups in child processes, `shader_diff/a4,a5,a6`). Also the generated mock GPU (`mock_gpu_body.js`) | `1846 identical, 0 different or missing` |
| `g6` (g6_diff) | `g6` | `Renderer`, Backend, Background, Lighting, pipelines on a stub backend (call logs) | `11 passed, 0 failed` |
| `g7` (g7_diff) | `g7` | renderer data classes, bindings, render objects, cache keys | `18 passed, 0 failed` |
| `g9` (g9_diff) | `g9` | `WebGPURenderer` on the recording mock GPU, incl. every WGSL module | `30/30 identical` |
| | `g9_pixel` | the 44 `examples/pixel_compare` WebGPU scenes' call logs, mock GPU | `44/44 identical` |
| | `g9_pixel_webgl` | the same scenes with `forceWebGL`, mock WebGL 2 | `44/44 identical` |
| | `g9_a4` | A4 TSL display add-ons' render pipelines, mock GPU | `32/32 identical` |
| | `g9_a5` | A5 TSL add-ons (lighting, passes, temporal), mock GPU | `20/20 identical` |
| `g10` (g10_diff) | `g10` | WebGL fallback (`WebGLBackend`, `GLSLNodeBuilder`) on mock WebGL 2 | `28/28 scenarios identical` |
| `nodeids` (nodeids) | | bug injection for the module-level node id table only (see below) | |

### classic (`diff/classic`, old names `<name>_diff`)

| dir | check | compares | expected |
| --- | --- | --- | --- |
| `materials` | `materials` | constructors, setters, copy/clone, toJSON/fromJSON, uniforms of the 18 material classes | `8077 checks, 0 failures (fromJSON: 1 upstream null held as NaN by the port)` |
| `cameras_lights` | `cameras_lights` | cameras, lights, shadows and scenes: one JSON line per observation | `49527 lines, IDENTICAL` |
| `loaders` | `loaders` | ObjectLoader / BufferGeometryLoader / MaterialLoader round trips of upstream-built scenes (fixtures regenerated each run), mock fetch/Image loader paths | `196 passed, 0 failed, 0 known core gaps` |
| `animation` | `animation` | mixer, actions, fades/warps, loops, bindings, AnimationUtils; logs compared with `Object.is` | `16/16 scenarios match, 141486 log entries compared` |
| | `animation_random` | 300 seeded random scenarios | `516/516 scenarios match, 356452 log entries compared` |
| `helpers` | `helpers` | every helper's geometry, materials and updates | `entries: mbt 15685, upstream 15685, typed arrays 346, mismatches 0` |
| `audio` | `audio` | `src/audio` on a mock Web Audio context (`AUDIO_DIFF=1`) | `11/11 scenarios match (864 entries)` |
| | `audio_bindings` | every Web Audio member upstream uses is bound | `63/63 upstream members bound, 68 extern "js" functions` |
| `geometries` | `geometries` | a 77k-case parameter grid over every geometry class | `cases=77461 pass=76397 bothThrow=1064 fail=0` |
| `geometry_gaps` | `geometry_gaps` | toJSON of transformed geometries, copy() across classes, lazily serialized parameters | `cases=1468 match=1468 (bothThrow=375) mismatch=0, TOTAL mismatch=0` |
| `extras` | `extras` | curves, earcut, ShapeUtils/ShapePath, fonts, TextureUtils, DataUtils, Interpolations | `233633 compared, 5584 both threw, 0 mismatches` |
| `objects` | `classic_objects` | raycasts on every object kind, Box3/frustum tests, skinning, skeletons, BatchedMesh (3050 seeded scenarios) | `3050/3050 scenarios identical, 1562410 scalar values compared` |
| `shaders` | `shaders` | ShaderChunk, ShaderLib, UniformsLib, VSM, DFG LUT (strings, values, key order, aliasing) | `shaders: 251 strings (217162 code units), 619 uniform values, 1805 numbers, 0 differences` |
| | `shaders_fuzz` | string literals through `tools/gen_shaders.mjs`, built and read back | `398 cases, 0 differ` |
| `json_uuid` | `json_uuid` | JSON number writing, uuid/id draw order, non-finite round trips | `126 passed, 0 failed (93 fresh, 17 nonfinite scenes)` |

### addons (`diff/addons`)

| dir (old name) | check | compares | expected |
| --- | --- | --- | --- |
| `controls` (a1_controls) | `controls` | the 9 controls: pointer/touch/wheel/key scripts replayed into both; camera, state, events, listeners after each event | `27/27 scenarios identical, 111739 entries` |
| `gltf` (a2_gltf) | `gltf` | GLTFLoader: 50 example models, 13 generated fixtures, plugin and no-decoder runs | `67 passed, 0 failed` |
| | `gltf_utils` | BufferGeometryUtils, SkeletonUtils | `cases: 1384, pass: 1384, fail: 0 (both threw: 0)` |
| | `gltf_draco` | DRACOLoader, real wasm decoder, every Draco primitive of 15 GLBs | `4190 log entries compared (671 geometry summaries), 0 mismatches` |
| | `gltf_ktx2` | KTX2Loader, ktx-parse, zstddec, WorkerPool, ColorSpaces, real Basis transcoder | `59/59 checks identical` |
| `hdr` (a3_hdr) | `hdr_fflate` | fflate `unzlibSync` on random, corrupt and EXR zlib streams | `fflate: 2631 identical, 0 mismatches` |
| | `hdr_loaders` | HDR, RGBE, EXR (415 generated files: all compressions, tiled, mip, multi-part, deep), UltraHDR, HDRCubeTexture | `2716 identical, 0 mismatches` |
| | `hdr_corrupt_sample` | every 10th corrupt input | `corrupt: 226 identical, 0 mismatches (226 cases, every 10th of 2251)` |
| | `hdr_corrupt` (`--full`) | all 2251 truncated / bit-flipped HDR and EXR inputs, one process each | `corrupt: 2251 identical, 0 mismatches (2251 cases)` |
| | `hdr_hangs` (`--full`) | the EXRs upstream never finishes parsing hang in the same frames in the port | `hangs: 2 files, port hangs in the same frames on 2, same as hangs.json` |
| `tsl/a4` (a4) | | A4 bug-injection tools only; A4's checks are `shader` (groups a4_*) and `g9_a4` | |
| `tsl/a5` (a5) | `a5_webgl_nodes` | WebGLNodesHandler: node materials on the classic renderer, mock GL | `10 identical, 0 different or missing` |
| | `a5_simplex` | SimplexNoise bit for bit | `simplex: 12394 lines identical` |
| | `a5_camera_utils` | CameraUtils.frameCorners | `camera_utils: 84 cases identical` |
| `objects` (a6_obj) | `a6_objects_gpu` | SkyMesh, WaterMesh, Water2Mesh, LensflareMesh on the mock GPU | `4 identical, 0 different` |
| `utils_env` (a6_utils_env) | `a6_utils_env` | SortUtils, ColorUtils, GeometryUtils, SceneUtils, Room/DebugEnvironment records | `17 identical, 0 different or missing` |
| | `a6_utils_env_gpu` | WebGPUTextureUtils and PMREM'd environments, mock GPU | `3 identical, 0 different` |

Each directory has a `checks.mjs` (what `run_all` runs) and most have a README with the
harness's own options (single scenarios, `--show`, dumps). To run one harness by hand,
use the `cwd` and `cmd` of its entry (`node diff/run_all.mjs --list` prints them).

### Fixtures

Almost everything is generated at run time into `diff/.out`: the loaders' and glTF
fixtures from upstream (`loaders/run.mjs`, `gltf/gltf_diff/gen_fixtures.mjs`), the controls'
upstream copies, the EXR corrupt inputs. The one committed binary fixture is
`addons/hdr/fixtures/exr.tar.xz` (2.4 MB): the 415 generated EXRs, 337 of them written
by the OpenEXR CLI (which CI does not have) and 78 by `gen_exr.mjs` in Node (committed too,
because node:zlib's output differs between Node versions). See `addons/hdr/README` for
regenerating the archive (needs OpenEXR >= 3.3).

### Adding a check

Export it from the directory's `checks.mjs`:

```js
export default [ {
	name: 'g9',                     // unique; --only matches it (or a prefix of it)
	area: 'core',                   // core | classic | addons
	order: 30,                      // order within the area
	title: 'G9 WebGPU',
	build: [ 'mbt' ],               // module dirs to `moon build --target js` first
	cwd: '.',                       // relative to checks.mjs
	cmd: [ 'node', 'harness/run.mjs', '--quiet' ],
	summary: /identical/,           // last matching output line, or ( out ) => string
	expect: '30/30 identical',      // the summary must equal this exactly
	timeout: 1800,                  // seconds
	full: false,                    // true: only with --full
	// exitCode: 0 (default) or 'any'; env: { ... }
} ];
```

## Bug injection

Each harness was validated by injecting plausible bugs into the port and checking that the
harness catches them. The tools stay, opt-in (never run by `run_all` or CI). They edit the
real files under `src/` through `diff/lib/inject.py` (`patched()` restores the file on
success, exception, Ctrl-C and SIGTERM, and keeps a copy in `diff/.out/inject_backup`) or
work on a temporary copy under `diff/.out`. After a hard kill, restore with
`python3 diff/lib/inject.py --restore`. Do not run them while other harnesses use the same
checkout. `INJECT_DRY_RUN=1` only checks that every pattern still applies.

| tool | target | bugs |
| --- | --- | --- |
| `core/nodeids/inject.py [shift\|swap\|counter]` | node id table / counters | 3 |
| `core/g6/harness/inject.py [n...]` | G6 renderer files | 23 |
| `core/g7/harness/inject.py [n...]` | G7 data classes | 24 |
| `core/g9/harness/inject.py [n...]` | WebGPU backend | 32 |
| `core/g10/inject/inject.py [n...]` | WebGL fallback | 31 |
| `classic/materials/mutate.py` | `src/core` materials | 8 |
| `classic/animation/mutate.mjs [--restore]` | `src/animation` | 33 |
| `classic/loaders/mutate.py` | copy of `src/loaders` under OUT | 30 |
| `classic/geometries/mutate.py`, `mutants_extra.py` | copy under OUT | 31 |
| `classic/geometry_gaps/mutate.py` | copy under OUT | 12 |
| `classic/objects/mutate.py [file old new]` | copy of math+core under OUT | 4 (+ ad hoc) |
| `classic/helpers/mutate.py` | `src/helpers` | 21 |
| `classic/audio/tools/inject_bugs.mjs` | `src/audio` | 31 |
| `classic/extras/mutants.py` | copy under OUT | 10 |
| `classic/shaders/inject.sh` (+ `sandbox.sh`, needs perl) | copy under OUT | 19 |
| `addons/controls/inject.py` | `src/addons/controls` | 31 |
| `addons/gltf/{gltf_diff,utils_diff,draco_diff}/inject.py`, `ktx2_diff/tools/inject.py` | loaders, utils, libs | 26, 21, 15, 16 |
| `addons/hdr/inject.py [bug]` | HDR/EXR loaders, fflate | 33 |
| `addons/tsl/a4/inject_{basic,blur,ao,ssr}.py`, `inject_pass.sh` | `src/addons/tsl` display nodes | 10, 7, 12, 8, + pass |
| `addons/tsl/a5/inject_{g9,shader,passes}.py`, `inject_one.py <group> <file> <old> <new>`, `webgl_nodes/inject.py` | `src/addons/tsl`, utils, math | 16, 10, -, ad hoc, 7 |
| `addons/objects/inject.py` | `src/addons/objects` | 20 |
| `addons/utils_env/inject.py` | `src/addons/{utils,environments}` | 14 |

Each reports, per bug, whether the harness caught it.

## Generators

Several sources in `src/` are generated, and CI checks that they are current
(`--check`): `tools/gen_fn_layout_names.mjs`, `tools/gen_module_node_ids.mjs`,
`tools/check_webgpu_exports.mjs`, `tools/check_gpu_coverage.mjs`, `tools/gen_gpu_mock.mjs`
(the mock GPU, `diff/core/webgpu/mock_gpu*.js` and its copy in `src/renderers/gpu`),
`tools/gen_g10_mock.mjs`, `tools/gen_glsl_tables.mjs` and
`diff/core/webgl/tools/gen_mock.mjs` (the mock WebGL 2 context and its copy in
`src/renderers/webgl`), `addons/gltf/ktx2_diff/tools/gen_{ktx2_loader,zstddec}.py` and
`addons/gltf/draco_diff/gen_worker.mjs`. Others regenerate committed files and are run by hand:
`diff/core/webgl/tools/gen_bindings.mjs` (WebGL bindings), `classic/materials/gen_harness.py`,
`classic/extras/gen_tests.py`, `classic/audio/tools/gen_mock.mjs`,
`addons/objects/gen_{shaders,tables}.mjs`.
