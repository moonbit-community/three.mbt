# Classic WebGLRenderer on a recording mock WebGL 2 context (diff/core/webgl)

Node has no WebGL. `harness/mock_gl.cjs` is a recording mock context: every `gl.*` call
is logged with its arguments (objects numbered in creation order), and the options
(see the comment in `harness/mock_gl_body.js`) set the answers to queries, extensions,
shader compile/link status and program uniforms. The same source is embedded in
`src/renderers/webgl/webgl_mock_gl_test.mbt`, so the MoonBit side of each scenario is an
ordinary test that also runs in `moon test`.

    cd diff/core/webgl
    node harness/run_diff.mjs [--repo <checkout>] [--file <test file>] [name ...]

runs every `*_test.mbt` of `src/renderers/webgl` that calls `emit_log` (plus the
`*_diff_wbtest.mbt` files of `src/addons/objects`, the `a6_*` scenarios) with
`WEBGL_DIFF=1`, runs the upstream scenarios `harness/scenarios/<name>.mjs` (driving the
modules of `$THREE_UPSTREAM/src`, default `.repos/three.js`) and compares the logs entry by
entry, printing the first mismatch. Expected: `52 ok, 0 failed` (check `webgl` of
`node diff/run_all.mjs`; the old scratchpad script counted the `ok` lines, 52).

Other users of the mock: the WebGL fallback harness (diff/core/g10), the GLSL scenarios of
the shader harness (diff/core/webgpu/shader_diff/upstream_g10.mjs and the a4/a5/a6
children), the TSL add-on tests in src/addons (which load `harness/mock_gl.cjs` by walking up
from the module root), and diff/addons/tsl/a5/webgl_nodes.

Writing a scenario: `mock_gl(options=...)`, drive the modules, record non-GL results with
`mock_note(gl, label, JsValue)` / `note_int` etc., end with `emit_log("<name>", gl)`. Write
`harness/scenarios/<name>.mjs` doing the same steps on upstream with `gl.__note( label,
value )` and returning `gl.__log`. Shared pieces: `scenarios/renderer_common.cjs`,
`programs_common.cjs`, `a6_common.cjs`, `harness/group3_util.mjs`, `harness/xr_util.mjs`
(+ `harness/mock_xr.cjs`, the mock XR session).

## Tools (`tools/`)

- `gl_spec.mjs`: the bound WebGL 2 API (methods, extension methods, handles, constants).
- `node tools/gen_bindings.mjs ../../../src/renderers/webgl` regenerates `gl_context.mbt`
  and `gl_constants.mbt` (then `moonfmt -w` them).
- `node tools/gen_mock.mjs [--check]` regenerates `harness/mock_gl.cjs` and
  `src/renderers/webgl/webgl_mock_gl_test.mbt`; then `node tools/gen_g10_mock.mjs` (repo
  root) copies the latter to `src/renderers/webgl_fallback/g10_mock_gl_test.mbt`. Both have
  `--check` (CI).
- `node tools/check_coverage.mjs <three.js/src> <repo>/src/renderers/webgl` checks that
  every `gl.*` method, constant and extension method upstream uses is bound;
  `check_xr_coverage.mjs` does the same for WebXR; `node tools/check_constants.mjs
  <typescript>/lib/lib.dom.d.ts` checks the constant values (needs a TypeScript checkout);
  `gl_usage.mjs <three.js/src>` prints what upstream uses.
