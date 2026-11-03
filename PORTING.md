# Porting three.js to MoonBit

Upstream: `.repos/three.js` (REVISION 187, shallow clone made by `tools/fetch_upstream.sh`:
the `dev` commit 8086b3f of 2026-11-01, which differs from the r187 tag in about ten `src`
files; the port follows the commit). Target: MoonBit JS backend. Differential harnesses:
`diff/` (`node diff/run_all.mjs`, see `diff/README.md`).
One upstream `src/<dir>/Foo.js` maps to one `src/<dir>/foo.mbt` (snake_case).

## Rules

- Keep upstream behaviour and numeric results exactly. Do not "improve" algorithms.
- Keep the mutating, chainable style: methods mutate `self` and return `self`
  where upstream returns `this`.
- Names: `camelCase` becomes `snake_case`, keeping digits attached:
  `applyMatrix4` -> `apply_matrix4`, `setFromQuaternion` -> `set_from_quaternion`,
  `addScaledVector` -> `add_scaled_vector`, `lengthSq` -> `length_sq`.
  Method names are mechanical so packages can call each other before both exist.
- Numbers are `Double`. Types with writable fields are `pub(all) struct Vector3 { mut x : Double ... }`.
  `pub mut` on a field does not work. Types whose field writes must fire a callback
  (`Quaternion`, `Euler`) are `pub struct`, with `set_x`-style setters for other packages.
- Constructors: `Vector3::new(x, y, z)` with required positional arguments, plus
  optional arguments with upstream defaults where a class has many
  (`Foo::new(a? : Double = 0.0)`). `Vector3::new(0.0, 0.0, 0.0)` is the default value.
- `clone` -> `T::clone(self)`, `copy` -> `T::copy(self, other)`, `equals` -> `T::equals(self, other)`.
- Overloads: pick the upstream name for the primary form; suffix the rest
  (`Matrix4::set` takes all 16 values).
- `fromArray(array, offset=0)` / `toArray(array=[], offset=0)` become
  `from_array(self, Array[Double], offset? : Int = 0)` and
  `to_array(self, array? : Array[Double], offset? : Int = 0)`.
- Upstream module-level scratch objects (`_v1`, `_m1`) become private top-level
  lets, reused as upstream does. Prefix them by file (`_box3_v1`), because a package
  has one namespace. Sharing one across files risks aliasing bugs.
- `Double::min`/`max` ignore NaN but JS `Math.min`/`max` propagate it, so bind the JS
  functions. `Double::to_int` saturates where JS `|0` wraps.
- `toJSON` numbers go through `@math.json_number` (NaN, the infinities as `null` and -0 as
  0, as `JSON.stringify` writes them; `Json::stringify` would print bare `Infinity`), and
  readers take `null` as NaN through `@math.json_to_number`, so it is written back as
  `null`. Curves keep 0 for `null` (upstream's arithmetic) and remember it for `toJSON`
  (extras/curve_json_nulls.mbt); typed-array data reads `null` as 0, as the constructors do.
- Validation that upstream reports via `console.warn`/`error` keeps its condition;
  use `println` until `utils` exists. Upstream `throw` becomes `abort`.
- Skip deprecated members, `isFoo` flags, and `Symbol.iterator`, except where other
  code needs them.
- Comments: one short `///` line on public items at most. No JSDoc copies.

## Style

- Each top-level item is preceded by `///|`.
- Core math is imported as `@cmath` (package `moonbitlang/core/math`). In source files
  never use the alias `@math` for it. In black-box tests `@math` is our own package.
  `sqrt`, `abs` are `Double` methods.
- Always run with `--target js`.

## Class hierarchy

MoonBit has no inheritance, and the WebGL renderer leans on `isMesh`-style checks and
on reading about 350 material properties without knowing the concrete class.

- `Object3D` is one struct holding the shared fields plus `kind : Object3DKind`, an
  enum with the subclass data (`Mesh(..)`, `Camera(..)`, `Light(..)`, ...). `isMesh`
  checks become pattern matches, and overrides such as `raycast` dispatch on `kind`.
- `Material` is one flat struct with every property of every material as an `Option`
  or default, plus a `material_type` enum. This mirrors how upstream reads
  `material.map` on any material. `Texture` follows the same pattern.
- Upstream's cycles (`Object3D` -> `Mesh` -> `Material` -> `Texture`, `Light` ->
  `Camera` -> `RenderTarget`) cannot cross packages, so `core`, `textures`,
  `materials`, `objects`, `cameras`, `lights` and `scenes` share one package, `src/core`,
  keeping one file per upstream class. Layers: `math` -> `core` -> `geometries` ->
  `renderers/shaders` -> `renderers/webgl`.
- The goal is a full port of all of three.js, so packages above `core` (`audio`,
  `helpers`, `nodes`, renderers) must be able to extend `Object3D` and `Material`
  through a hook in `core`. The foundation pass in `src/core` defines it.

## `src/core` conventions

- Subclass constructors live on marker types and return the base struct:
  `#external pub type Mesh2`-style markers as in `src/math` interpolants, so
  `PerspectiveCamera::new(..)` returns `Object3D`, `MeshBasicMaterial::new()` returns
  `Material`, `DataTexture::new(..)` returns `Texture`. Subclass methods live on the base
  struct and pull the payload with a match, e.g. `Object3D::update_projection_matrix`.
- Check `src/core/types_*.mbt` for existing payload type names first. Where the payload
  struct already has the class's name, pick a constructor form that compiles, keep it
  `X::new`, and report it.
- Overridable `Object3D` methods dispatch `m` -> `extension.m` -> `m_kind` ->
  `hook_<class>_<m>` or `m_base`. `m_base` is upstream's `super.m`. Fill hook bodies in
  your own class file, keep their signatures, and do not edit `object3d.mbt`.
  Stubs have `_`-prefixed parameters; drop the prefix. List with
  `grep -n 'abort("dispatch arm' src/core/*.mbt`.
- `copy` hooks call `object.copy_base(source, recursive)` first. `to_json` hooks add to
  `data`, which is upstream's `data.object`.
- Types adding a trait also write `pub extend T with Trait::{...}`.
- Scratch lets are prefixed by file (`_mesh_v1`). Test helpers `approx`, `vec3`, `test_pi`,
  `matrix_equals4`, `euler_equals` are in `test_helpers_test.mbt`: reuse, do not redefine.
- Fixed constructor signatures, so groups can call each other before they exist:
  - Every material: `XMaterial::new() -> Material`, no parameters. Callers assign fields.
    `Material::set_values` is ported separately.
  - `Texture::new(image? : TextureImage, mapping? : Int, wrap_s? : Int, wrap_t? : Int,
    mag_filter? : Int, min_filter? : Int, format? : Int, type_? : Int,
    anisotropy? : Int, color_space? : String) -> Texture`, with upstream defaults.
  - `DataTexture::new(data? : TypedArray, width? : Int, height? : Int, format? : Int,
    type_? : Int) -> Texture`, then upstream's remaining arguments as labelled options.
  - `RenderTarget::new(width? : Int, height? : Int, ...) -> RenderTarget`, with upstream's
    options as labelled optional arguments.
  - Objects: `Mesh::new(geometry? : BufferGeometry, material? : MaterialSlot) -> Object3D`,
    the same for `Line`, `LineSegments`, `LineLoop`, `Points`; `Sprite::new(material? :
    Material) -> Object3D`; `Group::new()`, `Bone::new()`, `LOD::new()`, `Scene::new()`.

## `src/renderers/webgl` conventions

Package `moonbit-community/three/renderers/webgl` holds `src/renderers/webgl/*.js`,
`WebGLRenderer.js`, the `WebGL*RenderTarget.js` classes and `extras/PMREMGenerator.js`
(they need `WebGLRenderer`, and the renderer needs them).

### WebGL bindings

- `gl.fooBar( ... )` is `gl.foo_bar( ... )` on `WebGL2RenderingContext`, with `2D`/`3D`
  kept attached: `texImage2D` -> `tex_image2d`, `uniformMatrix4fv` -> `uniform_matrix4fv`,
  `vertexAttribIPointer` -> `vertex_attrib_i_pointer`. Second overloads have their own names:
  `buffer_data_size`, `buffer_sub_data_range`, `tex_image2d_source` (6 arguments),
  `tex_sub_image2d_source` (7), `read_pixels_offset` (PBO), `pixel_storei_bool`,
  `tex_element_image2d_full`. gl_context.mbt and gl_constants.mbt are generated (see
  Tests); add a call to the spec and regenerate rather than editing them.
- `gl.FOO` is the constant `GL_FOO`. WebGL 2 fixes the values, so they are `pub const`s,
  not reads from the context. `gl[ name ]` is `gl.get_constant(name)`. Constants on
  extension objects are `ext.constant("COMPRESSED_RGB_S3TC_DXT1_EXT")`; extension methods
  are methods on `GLExtension` (`multi_draw_arrays_webgl`, `clip_control_ext`, ...).
- Handles are opaque: `GLBuffer`, `GLTexture`, `GLProgram`, `GLShader`, `GLFramebuffer`,
  `GLRenderbuffer`, `GLVertexArrayObject`, `GLUniformLocation`, `GLQuery`, `GLSync`,
  `GLExtension`, `GLActiveInfo`, `GLShaderPrecisionFormat` (`GL` instead of `WebGL` because
  three's `WebGLProgram` is a class in this package). Where upstream passes or gets `null`
  the binding uses `T?`. Option of an external type is boxed, so compare optional handles
  with `same_handle(a, b)`, never `physical_equal`.
- Buffer-source arguments take any `GLData`: core `TypedArray` (passed as the JS value),
  `Array[Double]`, `Array[Int]` (copied), `JsValue`, or an `Option` of those (`None` is
  `null`). DOM sources (`TexImageSource`) are `JsValue`.
- `get_parameter` returns `JsValue`; `get_parameter_int`, `_string`, `_array` convert.
  `js_try(f)` gives upstream's `try { gl.texImage2D( ... ) } catch ( e )`.
- DOM pieces are in dom.mbt (`HTMLCanvasElement`, `create_canvas_element`, 2D contexts,
  `AnimationFrameProvider` for `requestAnimationFrame`, `set_timeout`, `instanceof` checks).

### Module representation

- Each upstream module (closure or class) is one struct with `X::new(...)` taking the
  upstream constructor arguments in order. Closure locals are fields (`mut` when
  reassigned), returned or `this.` functions are `pub fn X::method`, inner helpers are
  private methods. References to other modules are fields of their struct type
  (`WebGLObjects.geometries : WebGLGeometries`). Upstream exposed properties keep their
  names (`info.auto_reset`, `shadow_map.enabled`, `clipping.num_planes`). Module-level JS
  state (`programIdCount`, `_v0`) is a file-prefixed private `let`.
- Listeners added to core objects (`onGeometryDispose`, ...) are closures stored in a
  `mut on_*` field when the struct is built, so `remove_event_listener` gets the same value.
- Modules that take the renderer hold `renderer : WebGLRenderer`. `WebGLRenderer::new`
  builds its struct with every module field set to `uninitialized()` (JS `undefined`, as
  upstream before `initGLContext`), then `init_gl_context` assigns them. Nothing else may
  use `uninitialized()` except test stand-ins and `RenderItem` release (below).
- Per-object state (`properties.get( x )`) uses typed records in webgl_properties.mbt:
  `get_material` -> `MaterialProperties`, `get_texture` -> `TextureProperties`,
  `get_render_target` -> `RenderTargetProperties`, `get_source` -> `SourceProperties`. Keys
  keep upstream's names (`__webgl_texture`, `programs`, `current_program`); `undefined` is
  `None`. Add a missing key to the record (it is foundation code; tell the other groups).
- Other identity-keyed state uses `WeakMap[K, V]` (js_collections.mbt, a real JS `WeakMap`
  keyed by `JsValue::of(key)`), `WeakRef[T]` and `FinalizationRegistry[H]`. Maps that
  upstream keys by `id` in a plain object are `Map[Int, _]` iterated in sorted key order
  (JS orders integer keys).
- `array.sort( f )` is `stable_sort_by(array, f)`: stable, comparator returns `Double`.
  `Math.min`/`max` are `js_math_min`/`js_math_max`.
- Overloads follow the core rule: `set_clear_color(color, alpha?)` and
  `set_clear_color_hex(hex, alpha?)`, `set_viewport(x, y, w, h)` and `set_viewport_vector(v)`.
  Upstream `Promise`s become callbacks (`compile_async(..., on_done)`).
- Uniform values are core `UniformValue`s. `WebGLLightsState` arrays that the renderer
  assigns to uniforms are `Array[UniformValue]` so the uniform and the state share one
  array, as upstream mutates `state.directional` in place after assigning it.
- `WebGLProgramParameters` keeps `shaderName`/`uniforms`/`vertexShader`/`fragmentShader` in
  `shader : ShaderObject`, the object `material.on_before_compile` receives; set
  `shader.parameters = JsValue::of(parameters)` before calling it.
- Render targets: `WebGLRenderTarget::new(width?, height?, <RenderTarget options>)` and
  the 3D/array/cube variants return core `RenderTarget`s with a
  `WebGLRenderTargetExtension`; test with `has_extension_flag("isWebGLRenderTarget")`,
  `"isWebGLCubeRenderTarget"`, ... or `webgl_render_target_kind`. Cube methods take the
  `RenderTarget`: `WebGLCubeRenderTarget::clear(target, renderer)`.
- `WebGLRenderer` implements core's `CubeCameraRenderer`.
- WebXR is not ported: webxr_manager.mbt is a manager that never presents (`enabled` and
  `is_presenting` false). The real `WebXRManager` belongs in this package.

### State kept beside core objects (webgl_hooks.mbt)

Core types lack fields upstream sets ad hoc; these `WeakMap` side tables stand in:
`uniform_needs_update` / `set_uniform_needs_update` (`uniform.needsUpdate`; `None` is
`undefined`, i.e. upload), `uniform_type` (`uniform.type` in UBOs),
`geometry_max_instance_count` (`geometry._maxInstanceCount`), `camera_viewport`
(`camera.viewport` of `ArrayCamera` sub-cameras). Addon lights register themselves:
`register_light_probe_grid(object, &LightProbeGridSource)` with flag `isLightProbeGrid`,
`register_sun_light(object, &SunLightShadowSource)` with flag `isSunLight`.
`UniformsLib.LTC_FLOAT_1/2` and `LTC_HALF_1/2` are textures, not uniforms, so they are the
`uniforms_lib_ltc` slots here; the `RectAreaLightUniformsLib` addon assigns them and
`WebGLLights` reads them. Uniform `properties` stay in `@shaders.uniforms_lib_properties`.

### Groups

Stubs are `abort("dispatch arm: X::m (group N)")` with `_`-prefixed parameters (drop the
prefix when filling). List them with `grep -n 'dispatch arm' src/renderers/webgl/*.mbt`.
Each group owns its files, may add private fields and helpers there, and keeps every
public signature. Foundation files (gl_*, dom, js_collections, webgl_helpers, webgl_hooks,
webgl_properties and the fully ported modules) change only by agreement.

- Group 1: webgl_textures.mbt (`WebGLTextures`, 16 stubs).
- Group 2: webgl_state.mbt (`WebGLState`, `ColorBuffer`, `DepthBuffer`, `StencilBuffer`),
  webgl_program.mbt (`new`, `on_first_use`, `is_ready`, `destroy`; `get_uniforms` and
  `get_attributes` are done), webgl_programs.mbt, webgl_uniforms.mbt,
  webgl_uniforms_groups.mbt (76 stubs).
- Group 3: webgl_lights.mbt, webgl_materials.mbt, webgl_shadow_map.mbt,
  webgl_morphtargets.mbt, webgl_background.mbt, webgl_environments.mbt, webgl_output.mbt,
  pmrem_generator.mbt (29 stubs). `WebGLRenderStates.get` aborts until
  `WebGLLights::new` exists.
- Group 4: webgl_renderer.mbt (`WebGLRenderer`, 41 stubs), webgl_render_target.mbt (the
  constructors are done; `WebGLCubeRenderTarget::from_equirectangular_texture` and `clear`).

Done in the foundation: WebGLAnimation, WebGLAttributes, WebGLBufferRenderer,
WebGLIndexedBufferRenderer, WebGLCapabilities, WebGLExtensions, WebGLInfo,
WebGLProperties, WebGLUtils, WebGLShaderCache, WebGLShader (`webgl_shader`),
WebGLGeometries, WebGLObjects, WebGLBindingStates, WebGLRenderLists, WebGLRenderStates,
WebGLClipping, and the render target constructors.

### Differential tests against upstream

Node has no WebGL. The harness in `diff/core/webgl` (see `diff/README.md` for all the
harnesses and `node diff/run_all.mjs` to run them)
has a recording mock context (`harness/mock_gl_body.js`), the upstream side of each
scenario (`harness/scenarios/<name>.mjs`, driving the modules in `.repos/three.js/src`)
and a runner. The same mock source is embedded in webgl_mock_gl_test.mbt, so the MoonBit
side of each scenario is an ordinary test (webgl_differential_test.mbt) that also runs in
`moon test`.

- `node harness/run_diff.mjs [name ...]` runs every `*_test.mbt` here that calls
  `emit_log` with `WEBGL_DIFF=1`, runs the upstream scenarios and compares the logs entry
  by entry, printing the first mismatch.
- A scenario: `mock_gl(options=...)` (see the options comment in mock_gl_body.js), drive
  the modules, record non-GL results with `mock_note(gl, label, JsValue)` / `note_int`
  etc., end with `emit_log("<name>", gl)`. Write `scenarios/<name>.mjs` doing the same
  steps on upstream with `gl.__note( label, value )` and returning `gl.__log`. Put your
  group's MoonBit scenarios in your own `*_test.mbt`.
- Regenerate after editing `diff/core/webgl/tools/gl_spec.mjs` or the mock (tools in
  `diff/core/webgl/tools`): `node tools/gen_bindings.mjs <repo>/src/renderers/webgl`,
  `node tools/gen_mock.mjs [<repo>]` (`--check` in CI), then `moonfmt -w` the
  generated files. `node tools/check_coverage.mjs <three.js/src> <webgl dir>` checks that
  every `gl.*` method, constant and extension method upstream uses is bound;
  `node tools/check_constants.mjs <typescript>/lib/lib.dom.d.ts` checks the values.

## Packages above `core`

- Classes used mainly through their own methods (`Audio`, `AudioListener`) are
  `pub(all)` wrapper structs holding `object : @core.Object3D`, recovered from an object
  with `X::from_object`. Scene operations go through `.object`.
- Classes used mainly as scene objects (every helper) return `@core.Object3D` from
  `X::new`, keep their data in an `Object3DExtension` payload, and expose their methods as
  `X::method(object, ...)`, with `X::of(object)` returning the payload.
- Both override `Object3D` behaviour through `Object3DExtension` and call `super` through
  the `*_kind` methods in upstream's order.

## WebGPU and TSL conventions

The last stage: `nodes`, `materials/nodes`, `loaders/nodes`, `renderers/common`,
`renderers/webgpu`, `renderers/webgl-fallback` and the entry points (369 upstream files,
98k raw lines). `lights/webgpu` (`IESSpotLight`, `ProjectorLight`) is already in `src/core`.

### Packages

`node tools/webgpu_deps.mjs` measures the import graph (comments stripped, every
`import`/`export ... from`/`import()`), prints its SCCs, checks the layout below for
package cycles, MoonBit file-name clashes and exported-name clashes, and exits 1 on a
cycle. `--closure <prefixes>` prints what a set of files pulls in; `--files` lists every
file and its `.mbt` name. Measured on r187:

- No file-level cycle (upstream avoids them by patching `Node.prototype` from other
  files), but one directory-level SCC of 24 directories: all of `nodes/*`,
  `materials/nodes` and `renderers/common` (+`/nodes`, `/extras`). 15 import edges go
  nodes -> common, 31 common -> nodes, 5 nodes -> `NodeMaterial`.
- MoonBit only allows dot-call methods in the type's own package (checked: neither
  `pub extend` nor trait methods of another package work). The 145 chained TSL methods
  (`addMethodChaining` in 23 files) must therefore live with `Node`, and the closure of
  those files plus `NodeBuilder` is already 128 files / 33k lines (`--closure
  nodes/core/,nodes/tsl/,nodes/math/OperatorNode,nodes/math/MathNode`).
- Type-level dependencies that imports do not show: 42 node files use 50 members of
  `Renderer` (`builder.renderer.*`), and `NodeBuilder` holds `NodeMaterial`, `LightsNode`,
  `ClippingContext`. So the SCC is one package:

| package | upstream | files | raw lines | imports |
| --- | --- | --- | --- | --- |
| `src/nodes` | `nodes/**`, `materials/nodes/**`, `renderers/common/**` | 309 | 73,982 | core, math, renderers/webgl |
| `src/renderers/gpu` | none: WebGPU API bindings | | | core |
| `src/renderers/webgl_fallback` | `renderers/webgl-fallback/**` | 12 | 9,591 | nodes, renderers/webgl (gl bindings) |
| `src/renderers/webgpu` | `renderers/webgpu/**` | 40 | 14,006 | nodes, gpu, webgl_fallback |
| `src/loaders/nodes` | `loaders/nodes/**` | 3 | 476 | nodes, loaders |
| `src/webgpu` | `Three.WebGPU.js`, `Three.TSL.js`, `Three.WebGPU.Nodes.js` | 3 | 82 | all of the above |

`WebGPURenderer` imports `WebGLBackend`, never the reverse, so the two backends are
separate packages. `renderers/common/XRManager` imports `WebXRController`, which is why
`nodes` imports `renderers/webgl`; that package's `WeakMap`, `js_try`, `js_math_min`,
DOM bindings and `stable_sort_by` are reused rather than copied.

File names: a package is flat, so a file is named after its path below the package
root: `nodes/core/Node.js` -> `core_node.mbt`, `nodes/accessors/TextureNode.js` ->
`accessors_texture_node.mbt`, `materials/nodes/NodeMaterial.js` ->
`materials_node_material.mbt`, `renderers/common/nodes/NodeUniform.js` ->
`common_nodes_node_uniform.mbt`; the prefix is not repeated (`tsl/TSLCore.js` ->
`tsl_core.mbt`). The script prints the mapping (`mbtFileOf`). Exported names that clash
in `nodes` (18, all measured): `hash` (NodeUtils's is `hash`, TSL's `math/Hash` is
`hash_tsl`), `reference`/`referenceBuffer` of ReferenceBaseNode (`reference_base`,
`reference_base_buffer`), and the `mx_*` wrappers of MaterialXNodes over MaterialXNoise
(the MaterialXNoise ones take a `_impl` suffix). Private lets are file-prefixed as before.

### Node representation

About 230 classes extend each other up to 6 deep, and upstream reads subclass fields
through `isFooNode` checks. Core's "one struct + kind enum" would put every payload in one
enum written up front, so nodes use a class chain instead (core_node.mbt):

- `Node` is one struct with upstream's `Node` fields (`node_type`, `update_type`,
  `global`, `name`, `version`, ...) and `class_ : &NodeClass`, the payload of the most
  derived class. A payload struct embeds its superclass payload (`UniformNode { input :
  InputNode, ... }`) and returns it from `parent`.
- `NodeClass` has a method per overridable `Node` method (`setup`, `generate`,
  `generate_node_type`, `get_hash`, `is_cacheable`, `build`, `update`, `serialize`, ...),
  each taking the `Node`. Every default calls the same method on `parent()`, ending at
  `Node::m_base` (upstream's `Node.prototype.m`), so an unoverridden method falls through
  to the nearest superclass exactly as JS does. `super.m( ... )` is
  `self.<parent>.m(node, ...)`, or `node.m_base(...)` for direct subclasses of `Node`.
  Inside any method, `this.foo()` is `node.foo()`, which dispatches on the most derived
  class again.
- Construction mirrors JS: `Node::alloc(node_type?)` is `super()` and takes the next id
  before the subclass creates its child nodes (ids order the `getHash` defaults); each
  class has `X::construct(node, args...) -> X` (its constructor body; calls the parent's
  `construct` first and sets base fields such as `node.global = true`) and `X::new(args...)
  -> Node` = alloc, construct, `node.set_class(payload)`. `X::new` takes upstream's
  constructor arguments in order, optional ones labelled with upstream defaults.
- `X::of(node) -> X?` finds the class payload in the chain (`class_payload("X")`), for
  `node.isX` checks that then read fields. `node.has_flag("isTextureNode")` answers flags;
  each class's `has_flag` returns its own flags or asks `parent`. A payload that other
  files hold in typed fields carries `node : Node` (only `StackNode` so far).
- `children(self, node, out)` lists the node-valued properties in JS own-property order
  (parent's first, `_`-prefixed skipped), with upstream's property names: this is
  `_getChildren`, which orders `setup` (`node0`, `node1`, ...), analysis, cache keys
  (`hashString( property.slice( 0, -4 ) )`) and serialization. Use `push_child`,
  `push_children`, `push_child_object`.
- `generate_uses_output()` is `generate.length >= 2` and must match the arity of the
  class's `generate` (true by default, as `Node.generate( builder, output )`): it decides
  whether a snippet is cached and formatted by `Node.build`.
- Virtual methods introduced below `Node` (measured: about 25, e.g. TextureNode's
  `getDefaultUV`/`setupUV`/`generateUV`, AnalyticLightNode's `setupDirect`, ShadowNode's
  `setupShadowFilter`, InputNode's `getInputType`) belong to their family: the family
  root defines `pub(open) trait XClass` the same way, and its payload stores
  `mut class_ : &XClass` set to the most derived payload at the end of construction.
- Methods that upstream user code calls on node results (`texture( t ).sample( uv )`,
  `uniform( 1 ).onRenderUpdate( f )`, `.setGroup`, `.label`) are `Node` methods defined in
  the class's file that downcast with `X::of` and abort like upstream's `TypeError` for
  other nodes. A method name defined by two unrelated classes goes through `NodeClass`
  (`element`, `label`, `set_name`, `on_update`, `call` and `set_atomic`, of
  WorkgroupInfoNode and StorageBufferNode, are there; `Node::set_atomic`/`to_atomic`
  dispatch to it).
- `onUpdate( f )` / `onReference( f )` set `update_override` / `update_reference_override`
  on the node, as upstream binds them on the instance. A value-returning callback
  (`uniform( 0 ).onObjectUpdate( () => x )`) sets the value itself with
  `InputNode::set_value(n, ...)` and returns `None`. An instance's own `assign`
  (`depth.assign = ( value ) => depthBase( value )`) is `NodeClass::assign`, which
  `Node::assign`/`assign_node` try first; the class checks the instance.
- `getUpdateBeforeType( frame )` takes the frame (`NodeClass::get_update_before_type`
  gets `NodeFrame?`; NodeFrame passes itself, ComputeNode compares `frame.compute`).
- `NodeBuilder` follows the same scheme with `NodeBuilderClass` (core_node_builder.mbt):
  the 43 methods WGSL/GLSL builders override plus the 21 backend-only methods nodes call
  (`generateTextureLoad`, `getBitcastMethod`, `hasBuiltin`, ...). `NodeBuilder::m`
  dispatches, `NodeBuilder::m_base` is the base body. Backend builders live in the backend
  packages and hold their own fields in their payload, except the two that nodes write:
  `allow_early_returns` and `allow_global_variables` (WGSLNodeBuilder sets both to
  true; BarrierNode clears them, ComputeNode reads the first).
- Per-build data: `getDataFromNode` returns a typed `NodeData` (upstream's class plus the
  keys nodes add; add a key there, it is foundation code), `getNodeProperties` an
  insertion-ordered `NodeProperties` starting with `outputNode` (analyze iterates
  `Object.values`), `builder.context` an insertion-ordered `NodeContext` copied on change.
  Context callbacks (`getUV`, `getShadow`, ...) are `ContextValue::Other(JsValue::of(f))`
  read back with `cast`; the owner of a key adds a typed accessor next to its use.
- Other class hierarchies keep their own trait in the same style: `NodeMaterialClass`
  (setupLightingModel, setupVariants, ...), `BackendClass` (implemented by WebGPUBackend
  and WebGLBackend in their packages), `BindingClass`, `UniformClass`, `NodeLibrary`.
- NodeMaterials are core `Material`s, like the WebGL materials: `NodeMaterial::new()`
  returns `@core.Material` with `MaterialType::Material` and a `MaterialExtension` whose
  payload is the `NodeMaterial` struct (the node slots `color_node`, `position_node`, ...,
  and `class_ : &NodeMaterialClass`). `has_flag("isNodeMaterial")` makes core's
  `Material::is_node_material()` true. `copy_from`, `custom_program_cache_key` and
  `dispose` go through the extension; `NodeMaterial::of(material)` recovers the payload.
  `MeshStandardNodeMaterial::new()` etc. return `Material`, and `NodeMaterial.fromMaterial`
  maps core materials by `material_type`.

### TSL in MoonBit

TSL takes "a node or anything `nodeObject` converts". MoonBit coerces arguments to a
trait object implicitly, also inside array literals and labelled optional arguments
(checked), so TSL parameters are `&IntoTsl` and calls read like upstream:

| upstream | MoonBit |
| --- | --- |
| values passed to TSL | `&IntoTsl`, converted to `TslValue` (tsl_value.mbt): `Node`, `Double`, `Int`, `Bool`, `String`, vectors, `Color`, matrices, `Texture`, arrays, `ShaderFn`. `Int` becomes a JS number, as in JS: `int( 1 )` is how upstream gets an int constant, and so is `int(1)`. |
| `nodeObject( v )` | `node_object(v.to_tsl())` |
| `nodeProxy( OperatorNode, '+' )`, `nodeImmutable( ... )` | one explicit function per TSL name, next to its class: `pub fn add(a : &IntoTsl, b : &IntoTsl) -> Node`; immutables are `pub let position_local : Node`. `setParameterLength` limits become the signature. |
| `a.add( b ).mul( c )` (`addMethodChaining`) | `pub fn Node::add(self, b : &IntoTsl) -> Node`, defined in the file that defines `add`, including upstream's stack form (`this.isStackNode ? this.addToStack( ... )`). |
| `a.addAssign( b )` | `a.add_assign(b)` |
| `.xyz`, `.rgba`, `.stpq` getters | `n.xyz()` (generated by `tools/gen_swizzle.mjs` into tsl_swizzle.mbt, cached per node as upstream) |
| `n.x = v`, `n.setX( v )`, `n.flipX()` | `n.x().assign(v)`, `n.set_x(v)` (a `SetNode`), `n.flip_x()` |
| `n[ 2 ]`, `n[ 2 ] = v` | `n[2]`, `n[2] = v` (`#alias("_[_]")`): `ArrayElementNode` with a `uint` const, as the proxy; `n.element(2)` stays the float-index chained form |
| `vec3( x )`, `vec3( x, y, z )`, `vec3()` | `vec3(x)` for one argument, `vec3_of([x, y, z])` / `vec3_of([])` for any other count (MoonBit has no optional positional parameters), likewise `float`, `int`, `uint`, `bool`, `color`, `[iub]vec2..4`, `mat2..4`; `ConvertType`'s rules (all primitives -> one constant, else `JoinNode`/`ConvertNode`) run on the `TslValue`s |
| `Fn( ( [ a, b = uv() ] ) => ..., layout )` | `fn_(fn(inputs, builder) { let a = inputs.get(0).unwrap(); let b = inputs.get(1).or_else(fn() { uv() }); Some(...) }, layout?)` returning the `FnNode` as `Node`. `inputs.get(i)` / `inputs.named("a")` reproduce `getProxyParameters` (array or object destructuring); `None` is `undefined`, so JS default parameters keep their semantics, including `_resolveLayoutDefaults`, which calls the body twice. The body always gets the builder; upstream's `jsFunc.length` test only decides where JS puts it. |
| `f( a, b )`, `f( { a, b } )` | `f.call([a, b])`, `f.call_named({"a": a, "b": b})` |
| `.setLayout( { name, type, inputs } )`, `Fn( f, { a: 'float', return: 'vec3' } )`, `.once()` | `.set_layout(name=, type_=, inputs=[("a", "float")])`, `fn_(f, layout=FnLayout::short([("a", "float")], return_="vec3"))`, `.once()` |
| `If( c, () => { ... } ).ElseIf( c2, ... ).Else( ... )` | `if_(c, fn() { ... }).else_if(c2, fn() { ... }).else_(fn() { ... })`: bodies are `() -> Unit`; the 9 of 103 upstream bodies that `return` a value use `if_value`/`else_if_value`/`else_value` with `() -> Node` (a returned node becomes the branch output, which upstream code depends on). `if_`, `else_if` and `case_` return the `StackNode` for chaining, so a chain that does not end in `else_`/`default` ends with `\|> ignore` |
| `Stack( n )`, `struct( layout )`, `array( values )` / `array( type, count )` | `stack_(n)` (`stack` is StackNode's TSL name), `struct_(members, name?)` returning `StructFn` (`.call`, `.call_named`), `array(values)` / `array_of_type(type, count)` |
| `context( node, { a: x } )`, `overrideNode( n, cb )` | `context(node=n, value=node_context([("a", Node(x))]))`, `override_node(target, Some(OverrideCallback::{ f }))`; context callbacks have typed accessors (`NodeContext::get_shadow`, ...) |
| `Switch( x ).Case( 1, 2, f ).Default( f )`, `Loop( n, ( { i } ) => ... )` | `switch_(x).case_([1, 2], fn() { ... }).default(fn() { ... })`, `loop_([n], fn(inputs) { let i = inputs.named("i") ... })` |
| `Var( n, name )`, `Const( n )`, `n.toVar( name )`, `n.toConst()`, `uniform( v )`, `property( t, name )` | `var_(n, name?)`, `const_(n)`, `n.to_var(name?)`, `n.to_const()`, `uniform(v)`, `property(t, name?)` |
| `a.assign( b )` and other statements (`discard`, `Return`, `Break`, `Continue`, `x.increment()`) | return `Unit` (MoonBit rejects ignored values, and `|> ignore` on every statement is noise); `a.assign_node(b)` is the node-returning form for the few places upstream chains on it (`depth.assign( d ).toStack()`) |
| `currentStack`, `setCurrentStack`, `getCurrentStack` | the same, a package `Ref` (tsl_core.mbt) |

Names: camelCase -> snake_case; a TSL name that is a MoonBit keyword, reserved word or
prelude function gets `_` (`fn_`, `if_`, `else_`, `loop_`, `switch_`, `case_`, `var_`,
`const_`, `return_`, `break_`, `continue_`, `not_`, `type_`, `local_`, `atomic_`). Methods
keep the plain name where MoonBit allows it (`n.not()` is `n.not_()` since `not` is a
keyword-like prelude function; `n.mod(2)` is fine).

Example, upstream:

```js
const scale = uniform( 4 );
const checker = Fn( ( [ coord ] ) => {
	const cell = coord.mul( scale ).floor().toVar();
	const color = vec3( 0.1 ).toVar();
	If( cell.x.add( cell.y ).mod( 2 ).equal( 0 ), () => {
		color.assign( vec3( 1, 0.5, 0 ) );
	} );
	return color;
} ).setLayout( { name: 'checker', type: 'vec3', inputs: [ { name: 'coord', type: 'vec2' } ] } );
material.colorNode = checker( uv() );
```

MoonBit:

```moonbit
let scale = uniform(4)
let checker = fn_(fn(inputs, _) {
  let coord = inputs.get(0).unwrap()
  let cell = coord.mul(scale).floor().to_var()
  let color = vec3(0.1).to_var()
  if_(cell.x().add(cell.y()).mod(2).equal(0), fn() {
    color.assign(vec3_of([1, 0.5, 0]))
  })
  |> ignore
  Some(color)
}).set_layout(name="checker", type_="vec3", inputs=[("coord", "vec2")])
NodeMaterial::of(material).unwrap().color_node = Some(checker.call([uv()]))
```

### Byte-identical shaders

Generated WGSL/GLSL must equal upstream's byte for byte. What decides it:

- Numbers in shader text go through JS `String( n )` (bind it; MoonBit's `Double` printing
  differs for exponents and long fractions), and `_toFloat`'s `e` handling is kept.
- Every order that upstream gets from JS objects: `children` order, `NodeProperties`
  insertion order, `NodeContext` key order, `Map` iteration (MoonBit `Map` keeps insertion
  order, as JS `Map`; a JS object with integer-like keys orders them first: sort those).
- Counters: `nodeVar`/`nodeConst`/`nodeUniform`/`nodeVarying`/`nodeCode` indices come from
  the builder; the run-time node id counter and `fn<id>` layout names come from creation order
  (module-level node ids and library `fn<id>` names come from tables, below).
- `fn<id>` names of library functions. Upstream names a short layout (`Fn( f, { a:
  'float', return: 'vec3' } )`) `'fn' + fnId ++`, so the 130 library `Fn`s with short
  layouts are `fn0`..`fn129` in ES module evaluation order, and these names are in shader
  text. MoonBit initializes top-level lets in its own order, so the names are a table:
  `node tools/gen_fn_layout_names.mjs` loads upstream under Node with `FnNode.setLayout`
  patched, records each call site's `<path below src>:<const name>`, checks the order
  against an instrumented copy of `build/three.webgpu.js`, and writes
  `src/nodes/tsl_fn_layout_names.mbt` (`--check` reports a stale table). The order is the
  published bundles': `three.webgpu.js` imports `three.tsl.js`, so the `Three.TSL.js` graph
  takes `fn0`..`fn121` and the 8 files only `Three.WebGPU.js` reaches follow (loading
  `src/Three.WebGPU.js` alone interleaves them differently; the shader harness loads
  `Three.TSL.js` first, as the bundles do). Every library `Fn` with a short layout passes
  its key:

  ```moonbit
  pub let rrt_and_odt_fit : Node = fn_(
    fn(inputs, _) { ... },
    layout=FnLayout::short([("color", "vec3")], return_="vec3",
      upstream="nodes/display/ToneMappingFunctions.js:RRTAndODTFit"),
  )
  ```

  `FnNode::set_layout` takes the name from the table (aborting on an unknown key) without
  touching the counter, and the counter starts at `TSL_FN_FIRST_USER_ID` (130), so user
  `Fn`s get upstream's names too. Only user code and functions created at run time (not at
  module load) use `upstream`-less short layouts. The table's comments name the `.mbt` file
  of each key; `tsl_fn_library_status()` lists `(key, name, file, created)`, where
  `created` is 1 once the file is ported with `upstream=` (0: not ported or a missing key,
  2+: created twice).
- Ids of the nodes created at module load. Upstream's 856 module-level nodes take ids 0..855
  in the bundles' evaluation order (the first node user code creates is 856), and ids are
  observable: `Bindings` sorts shared uniform groups by id (UBO / uniform-struct member
  order), and `getCacheKey` / `getHash` defaults hash them. MoonBit evaluates top-level lets
  eagerly at load (each is a JS `const` in the output), but in a dependency-driven order that
  differs per linked program, and drops the lets a program never reads (measured: the nodes
  test binary creates 824 nodes at load, the webgl_fallback one 583, in different orders).
  So the ids are a table too: `node tools/gen_module_node_ids.mjs` loads upstream with
  `Node`'s constructor patched, maps each id to its top-level statement (`<path below
  src>:<declared name>`, or the map a loop fills: `nodes/tsl/TSLCore.js:floatsCacheMap`),
  checks the sequence against an instrumented copy of `build/three.webgpu.js`, checks that
  every `module_nodes( "<key>"` in src/ names a key once, and writes
  `src/nodes/core_module_node_ids.mbt` (428 statements; `--check` reports a stale table).
  The let mirroring a statement wraps its initializer:

  ```moonbit
  pub let camera_near : Node = module_nodes("nodes/accessors/Camera.js:cameraNear", fn() {
    uniform("float").set_name("cameraNear").set_group(render_group)...
  })
  ```

  `module_nodes` parks the counter at the statement's first id while the initializer runs (a
  statement's nodes are consecutive upstream, and the initializer must create the same nodes
  in the same order), then restores it; the run-time counter starts at
  `NODE_FIRST_RUNTIME_ID` (856). `module_node_ids_status()` lists `(key, base, count, file,
  calls, upstream classes, created classes)`; core_module_node_ids_test.mbt checks that every
  linked key ran once with upstream's class sequence and that only `PI2` (deprecated) is not
  ported. A module-level let that creates nodes without a key would take run-time ids.
- 32-bit integer math (`cyrb53`, `Math.imul`, `>>> 0`) uses the JS operators.
- Where upstream reads `fn.length` (`generate.length`, `jsFunc.length`), the arity is
  encoded explicitly (`generate_uses_output`; the Fn body always receives the builder).

### Groups

Stubs are `abort("dispatch arm: X::m (group)")` with `_`-prefixed parameters; list them
with `grep -rn 'dispatch arm' src/nodes src/renderers/gpu`. A group owns its files, may
add private items and fields there, keeps every public signature, and adds missing
`NodeData` keys or `NodeBuilderClass` methods only by agreement (foundation files).
Declared-but-empty types (`Renderer`, `Binding`, `BindGroup`, `ClippingContext`,
`Uniform`, `NodeMaterialObserver`, ...) are filled by their owning group; foundation code
only adds the fields it needs to them.

Foundation (this stage):

Status: F-core, F-A, F-B, F-C and F-D are done (no foundation stub left; `grep -rn
'dispatch arm' src/nodes` lists only the later groups' stubs, each tagged with its group).

- F-core: core_node.mbt (Node.js, done), core_constants, core_node_utils (hashes),
  tsl_value.mbt, the data classes (NodeVar, NodeVarying, NodeAttribute, NodeCode,
  NodeUniform, NodeFunction, NodeFunctionInput, NodeParser, StructType, NodeCache,
  StackTrace, NodeError) - done.
- F-A: core_node_builder.mbt (NodeBuilder.js), common_renderer.mbt's foundation fields.
- F-B: tsl_core.mbt, tsl_base.mbt, tsl_swizzle.mbt (generated), core_node_utils.mbt (rest),
  and the nodes TSLCore needs: utils_array_element_node, utils_convert_node,
  utils_join_node, utils_split_node, utils_set_node, utils_flip_node, utils_member_node.
- F-C: the other nodes/core files: StackNode, InputNode, ConstNode, UniformNode,
  UniformGroupNode, AttributeNode, PropertyNode, ParameterNode, VarNode, VaryingNode,
  ContextNode, OverrideContextNode, IsolateNode, BypassNode, AssignNode, ArrayNode,
  IndexNode, OutputStructNode, MRTNode, StructNode, StructTypeNode, SubBuildNode, TempNode,
  InspectorNode, LightingModel, NodeFrame.
- F-D: src/renderers/gpu (WebGPU bindings).

After the foundation, by file (upstream raw lines; MoonBit is 0.85-1.3x of that):

- G1 math and utils: nodes/math, nodes/utils (minus F-B's), nodes/code, nodes/geometry,
  nodes/procedural, nodes/shapes, nodes/fog (~8.5k).
- G2 accessors: nodes/accessors (9.5k; TextureNode family first, others depend on it).
- G3 lighting: nodes/lighting, nodes/functions/**, nodes/pmrem, nodes/materialx (8.5k).
- G4 display and compute: nodes/display, nodes/gpgpu, nodes/parsers, nodes/Nodes.js and
  nodes/TSL.js re-export lists (6.4k).
  Status: done (display_*, gpgpu_*, parsers_*, tsl.mbt, nodes.mbt; 109 `g4_` shader
  scenarios identical). `node tools/check_tsl_exports.mjs [--missing] [--strict dirs]`
  checks every export of nodes/TSL.js and nodes/Nodes.js against src/nodes (the flat
  package is the re-export list). Renderer members G6 had not declared are private
  `renderer_*` helpers aborting with `dispatch arm: ... (group G6)` in the display and
  gpgpu files (`compute`, `getViewport`, `getDrawingBufferSize`, `getCanvasTarget`,
  `copyFramebufferToTexture`, `render`, `renderObject`, `samples`,
  `getOutputBufferType`, `logarithmicDepthBuffer`, writable `lighting`, `xr`); swap each
  for the member once it exists. They run only when rendering (and `PassNode.setup`,
  `projectionDepth`), not in the shader scenarios.
- G5 materials: materials/nodes/** (5.7k), src/loaders/nodes (0.5k).
- G6 renderer: common_renderer.mbt, Backend, Background, Lighting, PostProcessing,
  RenderPipeline, DirectRenderPipeline, StandardDrawingPipeline, QuadMesh, CubeRenderTarget,
  CanvasTarget, XRManager, XRRenderTarget, InspectorBase, extras/PMREMGenerator (~10k).
- G7 renderer data: the other renderers/common files (Bindings, BindGroup, Binding,
  Buffer*, Uniform*, Sampler, SampledTexture, Storage*, Textures, Attributes, Geometries,
  Pipelines, ProgrammableStage, RenderObject(s), RenderList(s), RenderContext(s),
  RenderBundle(s), Info, ChainMap, DataMap, Color4, ...) and renderers/common/nodes (~12k).
- G8 WGSL: renderers/webgpu/nodes (WGSLNodeBuilder, WGSLNodeFunction, WGSLNodeParser,
  Basic/StandardNodeLibrary) (3.2k). Unblocks the shader harness on real materials.
- G9 WebGPU backend: the rest of renderers/webgpu (10.8k). The 23 `renderers/webgpu/descriptors`
  classes are already the generated descriptor structs of `@gpu` (`X::default()`, `reset`,
  `copy`); use them instead of porting those files again.
  Status: done (web_gpu_*, utils_web_gpu_*). `WebGPUBackend::new(parameters?)` returns the
  `@nodes.Backend` (`WebGPUBackend::of` recovers the payload); records are `backend.get( x )`
  JS objects with upstream's keys. `WebGPURenderer::new(canvas?, antialias?, ...)` /
  `from_parameters(JsValue)` return the `Renderer`. Upstream `await` is `wgpu_await` (resumes on
  a microtask like `await`); `.then` stays synchronous. Mock-GPU harness:
  `diff/core/g9` (`node harness/run.mjs`, 30 scenarios, all identical).
- G10 WebGL fallback: src/renderers/webgl_fallback (9.6k), GLSLNodeBuilder first.
  Status: done. `WebGLBackend::new(parameters? : JsValue) -> @nodes.Backend` (upstream's
  options object, copied by `Backend::new`); `WebGLBackend::of(backend)` recovers the payload,
  `GLSLNodeBuilder::new(object, renderer)`/`::of`. Per-object records are the common backend's
  plain JS objects with upstream's keys; `attribute.pbo`/`pboNode` are a side table
  (`glsl_attribute_pbo`). 247 `g10_` GLSL shader scenarios identical (run.mjs, or
  `node shader_diff/run_g10.mjs`); 28 mock-gl scenarios identical in
  `diff/core/g10` (`node harness/run.mjs`, README there). The gl spec gained the transform feedback
  calls, `clearBufferfv/fi`, `getSupportedExtensions` and 25 constants; the mock gained
  `getSupportedExtensions`, timer-query constants and opt-in query answers.
- G11 entry: src/webgpu facades (small, last).
  Status: done. `pub using @pkg { ... }` lists (MoonBit has no `export *`) generated by
  `node tools/check_webgpu_exports.mjs --write`, which also checks every export of the three
  entry files (run without `--write`: stale files or a missing export exit 1). Namespaces
  (`RendererUtils`, `NodeUtils`, `MathUtils`, `AnimationUtils`) are types with forwarding static
  methods; the TSL names are flat in the same package (TSL's `log` wins over utils.js's);
  `Three.WebGPU.Nodes.js`'s renderer is `WebGPURendererNodes`. examples/pixel_compare's
  WebGPU page uses it (`@three`), 20 scenes, identical call logs on the mock GPU and mock GL.

Order: G1-G4 and G7 can start at once; G5 needs G2/G3 types; G8 needs G1; G6 needs G7;
G9/G10 need G6-G8.

### Verification

The WebGPU harnesses live in `diff/core/webgpu` (shader text, mock GPU; README.md
there) and `diff/core/g6`, `g7`, `g9`, `g10` (renderer call logs); `diff/README.md` lists
every harness with its expected counts, and `node diff/run_all.mjs` runs them all (also in
CI). Paths below are relative to `diff/core/webgpu`.

1. Shaders. Upstream's node system runs in Node without a GPU:
   `new WebGPURenderer( { canvas: <stub> } )` with `renderer._bindings = undefined`, then
   `new WGSLNodeBuilder( mesh, renderer )` / `GLSLNodeBuilder` with `scene`, `camera`,
   `material`, `lightsNode = renderer.lighting.getNode( scene, camera )` set, and
   `builder.build()` gives `vertexShader`/`fragmentShader` (checked on a
   MeshBasicNodeMaterial). For node graphs below a material, `builder.flowStagesNode( node,
   type )` runs the three build stages on one node and returns `{ code, result, vars }`.
   The harness runs the same graph on both sides and compares the strings byte for byte:
   `node shader_diff/run.mjs [name ...]` runs `src/nodes/shader_diff_test.mbt` with
   `SHADER_DIFF=1` (each scenario prints `@@SHADER <name> <json>` with flow code, result,
   vars and uniforms) and the scenarios of the same names in `shader_diff/upstream.mjs`.
   Add a scenario to both files. Status: 27 foundation scenarios identical. The foundation scenarios use the base
   `NodeBuilder` (no backend), which `flowStagesNode` supports; after G8/G10, the same
   scenarios run through the WGSL/GLSL builders and whole materials.
2. Backend calls. A recording mock `GPUDevice`/`GPUAdapter`/`GPUCanvasContext` (all
   objects are plain JS objects that log `[method, args]`, with descriptors serialized
   deeply and handles numbered) is injected as `navigator.gpu`; upstream `WebGPURenderer`
   renders the same scenes as the MoonBit one and the logs are compared entry by entry,
   as the WebGL mock-gl logs were. The mock is generated from the same API list as the
   bindings (`src/renderers/gpu`), so a binding missing from the mock fails loudly:
   `node tools/gen_gpu_mock.mjs` (repo root) writes `mock_gpu_body.js` and the copy embedded in
   `src/renderers/gpu/gpu_mock_gpu_test.mbt`; `smoke_upstream.mjs` renders a box
   with upstream `WebGPURenderer` on it (94 calls). Log entries are `[target, method, args]`
   with objects numbered in creation order and descriptors snapshotted in key order; its
   Promises settle synchronously, so MoonBit callbacks have run when a binding returns.
3. Pixels. `examples/pixel_compare` gains WebGPU scenes: the same scene rendered by
   upstream `WebGPURenderer` and by the MoonBit one in a real browser with WebGPU, read
   back with `readRenderTargetPixelsAsync`, compared exactly; and the WebGL fallback
   (`forceWebGL: true`) against upstream's.

## Add-ons (`examples/jsm`)

Tier 1 is done: controls, GLTFLoader with DRACO/KTX2/meshopt, the HDR/EXR loaders,
the TSL post-processing nodes (`tsl/**`), and the key utils, objects and environments.
The same rules apply as for `src`: a faithful port with snake_case names, upstream's
structure and behaviour, verified against upstream. Not ported yet (tier 2): the other
loaders, exporters, `postprocessing/` + `shaders/` (the WebGL EffectComposer stack),
lines, CSM, lighting, webxr, geometries, curves, math beyond ColorSpaces/SimplexNoise,
modifiers, and the other utils/objects (GaussianSplat, ReflectorForSSRPass, ...).

Status at completion of tier 1 (all run together on the final tree; `moon test --target
js` 1826/1826):

| group | check | result |
| --- | --- | --- |
| controls (9) | replayed pointer/touch/wheel/key events, camera + internal state + events + listeners after each | 27/27 scenarios, 111,739 entries identical |
| GLTFLoader | 50 example models + 13 fixtures + plugin and no-decoder runs; scene graph, materials, attribute bytes, animations, associations, uuids | 67/67 |
| BufferGeometryUtils, SkeletonUtils | outputs on generated inputs | 1384/1384 |
| DRACOLoader | every Draco primitive of 15 GLBs, real wasm decoder | 4190 entries, 0 mismatches |
| KTX2Loader (+ ktx-parse, zstddec, WorkerPool, ColorSpaces) | 27 files x 4 worker configs, real Basis transcoder | 59/59 checks |
| HDR, RGBE, EXR, UltraHDR, HDRCubeTexture | every example .hdr/.exr plus 410 generated EXRs (all compressions, tiled, mip, multi-part, deep); data bytes | 2716/2716; corrupt inputs 2251/2251; fflate 2631/2631 |
| TSL post-processing (49 display files + lighting, shadows, math, utils) | WGSL/GLSL byte-diff; RenderPipeline call logs on the mock GPU incl. every WGSL module | 323 shader records identical; 52/52 mock-GPU scenarios |
| objects (13) + environments (3) + other utils | classic mock-GL logs, WGSL byte-diff, mock-GPU logs | 6 new mock-GL scenarios (52/52 total), 14 shader records, 4/4 + 3/3 mock GPU, 17/17 CPU |
| real browser (Apple GPU, desktop browser pane) | `webgpu.html` (44 scenes: 24 add-on), `?webgl=1`, classic `index.html` (21: 4 add-on), `gltf.html` (5 models) | all byte-identical / 0 bad pixels |

About 290 bugs were injected across the groups; the few that escaped were shown to have no
observable effect. Known gaps: `GLTFLoader` ignores `LoadingManager` URL handlers, and
there is no `loadAsync`/`parseAsync` on it (callbacks only); Draco/Basis default decoder
paths point at the r187 CDN; worker bodies stay JavaScript (see below); real XR, real
network credentials and multi-worker first-reply order are untested. `examples/showroom`
uses GLTFLoader, HDRLoader, OrbitControls and TSL bloom together.

### Packages

One package per upstream directory, under `src/addons`, imported as
`moonbit-community/three/addons/<dir>`. Files are named as in `src`
(`loaders/GLTFLoader.js` -> `gltf_loader.mbt`; `tsl/display/BloomNode.js` ->
`display_bloom_node.mbt` in `src/addons/tsl`, since a package is flat).

| package | upstream | imports (besides the port) |
| --- | --- | --- |
| `src/addons/controls` | `controls/*` | |
| `src/addons/utils` | `utils/*` (tier 1: BufferGeometryUtils, SkeletonUtils, SceneUtils, CameraUtils, GeometryUtils, SortUtils, ColorUtils, WorkerPool, WebGPUTextureUtils) | |
| `src/addons/math` | `math/*` (ColorSpaces, SimplexNoise) | |
| `src/addons/libs` | the pure-JS parts of `libs/*` that tier 1 uses (fflate's zlib inflate, ktx-parse) | |
| `src/addons/loaders` | `loaders/*` (tier 1: GLTF, DRACO, KTX2, HDR, RGBE, EXR, UltraHDR, HDRCubeTexture) | utils, libs, math |
| `src/addons/tsl` | `tsl/**` | utils, math |
| `src/addons/objects` | `objects/*` (both the WebGL `ShaderMaterial` variants and the WebGPU `*Mesh` variants) | |
| `src/addons/environments` | `environments/*` | |

The graph is acyclic (measured from the import statements). TSL add-ons are TSL
functions and node classes outside `src/nodes`. They cannot add dot methods to `Node`,
so chained forms that upstream adds with `addMethodChaining` become plain functions,
or `NodeClass` dispatch where that already exists.

### Third-party code and workers

- **Pure-JS libraries:** port only the part tier 1 calls, faithfully, into `src/addons/libs`
  (fflate's `unzlibSync`, used by EXR; ktx-parse's `read`), and test it differentially
  against the vendored module.
- **WebAssembly decoders** (Draco, Basis, zstd, meshopt) stay WebAssembly. Load them
  the way upstream does: `setDecoderPath` / `setTranscoderPath` and the vendored
  `examples/jsm/libs` files, through JS bindings.
- **Worker bodies:** the code that DRACOLoader and KTX2Loader send to a worker must be
  JavaScript, because a worker cannot run the MoonBit bundle. Embed upstream's worker
  function source verbatim as a string, the only place where add-on code stays JS, and
  port everything on the main thread.
- **Async APIs** take callbacks, as in `src`: `load(url, on_load, on_progress?, on_error?)`.
  Where upstream inherits `Loader.loadAsync`, the add-on defines a MoonBit `async fn
  load_async` through `@loaders.loader_promise`, as `src/loaders` does (HDR, HDRCubeTexture,
  UltraHDR).
- **Controls** bind DOM events through `src/renderers/webgl`'s DOM helpers. An event is a
  `JsValue` with typed accessors, added beside the use.

### Module-level nodes in add-ons

Upstream evaluates an add-on module's top-level statements when it is imported, after
the library and its own imports, so module-level `Fn`s with short layouts get `fn<id>`
names (and module-level nodes their ids) in the app's import order. MoonBit initializes
top-level lets in an order of its own (measured: neither source nor import order, even
within one file), and add-ons have no id table like the library's. So an add-on file whose
module-level nodes are observable (short-layout `Fn`s above all) keeps them in a lazily
built private record cached in a `Ref`:

- the builder first loads the add-on modules the file imports, in upstream's import
  order, then creates the nodes in upstream's statement order;
- exported `Fn`s become accessor functions (`pub fn d_gtr() -> Node`), and every public
  entry point of the file goes through the builder;
- `pub fn load_<file>()` (the `.mbt` name: `load_utils_specular_helpers()`,
  `load_display_recurrent_denoise_node()`) forces it. Apps and harnesses call these at
  start, in the order upstream's `import` statements would evaluate the modules.

Module-level nodes whose ids and names are not observable (layout-less `Fn`s, which are
inlined) may stay plain `let`s.

### Verification

The add-on harnesses live in `diff/addons` (controls, gltf, hdr, tsl/a4, tsl/a5, objects,
utils_env); the TSL add-ons' shader records are in the shared shader harness
(`diff/core/webgpu`) and their render pipelines in `diff/core/g9` (`run_a4.mjs`,
`run_a5.mjs`). `diff/README.md` lists every check, its expected count and the
bug-injection tools. Each group checks itself against upstream in its own way:
- **Loaders:** parse the files in `examples/models` and `examples/textures` on both
  sides and compare the result (scene graph, `toJSON`, attribute bytes and texture
  data). Image decoding goes through the same stub on both sides.
- **Controls:** drive the same synthetic pointer, wheel and key events into both sides
  and compare camera position, quaternion and target after every event.
- **TSL nodes and objects:** WGSL/GLSL byte-diff in the shared shader harness, mock-GPU
  call logs, and WebGPU scenes in `examples/pixel_compare`.
- **Utils:** compare outputs, e.g. `mergeGeometries` bytes or `SkeletonUtils.clone`
  structure.

## Tests

Port the matching `test/unit/src/<dir>/Foo.tests.js` to `foo_test.mbt`. Skip tests of
skipped members. Float comparison: use a small `approx` helper rather than exact
snapshots unless upstream asserts exact equality.

## Status

- `src/math`: done.
- `src/core`: done, including the math members above (`math_bridge.mbt`). All of
  upstream `core`, `textures`, `materials` (not `nodes`), `objects`, `cameras`, `lights`,
  `scenes`. Renderers must read `material.reflectivity()`, not the field.
- `src/renderers/webgl`: foundation done (bindings, all types, small modules); the four
  groups above fill the stubs.
- `src/renderers/webgl`: done (`WebGLRenderer`, all of `renderers/webgl`, the
  `WebGL*RenderTarget` classes, `PMREMGenerator`). 46 mock-gl scenarios (with WebXR) match upstream's
  call logs exactly. `examples/pixel_compare` renders 13 scenes bit-identical to upstream
  in a real browser (Apple M2 Ultra, ANGLE Metal); 17 with the helper scenes.
- `src/animation`, `src/audio`, `src/helpers`, `src/loaders`: done. WebXR is ported in
  `src/renderers/webgl` (mock XR only; no headset session tested).
- WebGPU and TSL: done. `src/nodes` (nodes, TSL, `materials/nodes`, `renderers/common`),
  `src/renderers/gpu` (generated WebGPU bindings), `src/renderers/webgpu` (WGSLNodeBuilder,
  WebGPUBackend, `WebGPURenderer`), `src/renderers/webgl_fallback` (GLSLNodeBuilder,
  WebGLBackend), `src/loaders/nodes`, and the `src/webgpu` facade (one import for
  `WebGPURenderer`, node materials and TSL). No `dispatch arm` stub is left.
- Port size: about 214k lines of MoonBit (`src/nodes` 96k) plus 57k lines of tests.

Scope: everything in upstream `src`. Upstream members not ported are deprecated ones
(`PI2`, `colorToDirection`, `directionToColor`, `directionToFaceDirection`, `Source`, ...)
and the TSL meta-programming helpers MoonBit replaces (`addMethodChaining`, `nodeProxy*`,
`nodeImmutable`); `node tools/check_webgpu_exports.mjs` lists every export of
`Three.TSL.js`, `Three.WebGPU.js` and `Three.WebGPU.Nodes.js` and reports 0 missing.

### Verification at completion

All of these were run together on the final tree (`moon check`: 0 errors; `moon test
--target js`: 1746/1746):

| check | result |
| --- | --- |
| shader text, every group, base/WGSL/GLSL builders (`diff/core/webgpu/shader_diff/run.mjs`) | 1509/1509 byte-identical |
| `Renderer` call logs, stub backend (G6) | 11/11 |
| renderer data classes, cache keys (G7) | 18/18 |
| `WebGPURenderer` on the recording mock GPU, including every WGSL module (G9) | 30/30 |
| WebGL fallback on mock WebGL 2 (G10) | 28/28 |
| the 20 WebGPU pixel scenes' call logs on mock GPU / mock WebGL 2 | 20/20, 20/20 |
| classic `WebGLRenderer` mock-gl call logs | 46/46 |
| materials / loaders differential checks | 8077 checks, 0 failures / 196/196 |
| `fn<id>` names and module-load node ids tables (`--check`) | up to date |
| WebGPU binding coverage (`tools/check_gpu_coverage.mjs`) | 0 missing |
| real browser, `examples/pixel_compare/webgpu.html` (WebGPU backend) | 20/20 scenes byte-identical |
| same page with `?webgl=1` (WebGL fallback) | 20/20 byte-identical |
| real browser, classic `index.html` | 17/17 (0 bad pixels) |

Every group injected plausible bugs into its own code and confirmed its harness caught
them (about 250 in all; the few misses had no observable effect). Pixel runs used one
machine (Apple M2 Ultra, Chromium in the Claude desktop app's browser pane).

### Known gaps

- Not exercised: a real XR session (WebGPU or WebGL), real Web Audio output, other GPUs
  and browsers, timestamp-query pool overflow, `HTMLTexture`, device loss on real
  hardware.
- Async APIs take callbacks instead of returning Promises (`init(on_done?)`,
  `read_render_target_pixels_async(..., f)`, `compile_async`, ...); the order of effects
  within a flow is upstream's, but a callback may run synchronously where upstream resumes
  on a microtask.
- Values a MoonBit type cannot hold: `null` vs `undefined` in a few `Option` fields (e.g.
  a material's `transparent` set to `null` on the override path is `false`; a loaded JSON
  `null` outside curves becomes NaN); upstream's NodeLoader bug (assigning the read-only
  `node.uuid`) is kept and aborts as upstream throws.
- `getMaterialCacheKey` uses upstream's recorded key order per node material class
  (MoonBit cannot enumerate fields); extra keys set on a material come in a fixed order,
  exact when only one is set.
- Release JS builds can fail at load with "Cannot access ... before initialization"
  (moon 0.1.20261102): a compiler-hoisted literal is emitted after a module-level node
  whose class refers back to it through a trait object (e.g. `depth` and its
  `NodeClass::assign`). Minimal repro and analysis: `repro/release_hoist_cycle`. Whether
  a given program hits it depends on what it links; debug builds are unaffected, so the
  examples load the debug build first.
- Earlier notes still apply: Raycaster's `false` stop is not supported, copying between
  unrelated classes aborts, and `PropertyBinding` does not bind integer enums or texture
  slots.
