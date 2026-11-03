// examples/jsm/tsl/WebGLNodesHandler.js: builds node materials with the GLSL node builder
// for the classic WebGLRenderer (`renderer.set_nodes_handler( WebGLNodesHandler::new() )`).
//
// Design. Upstream's `RendererProxy` is a JS `Proxy` that answers its own members
// (`_renderer`, `contextNode`, `inspector`, `library`, `lighting`, `backend`,
// `hasInitialized`, `getMRT`, `getCanvasTarget`, `hasCompatibility`, `getCacheKey`) and
// forwards every other read and write to the WebGLRenderer. The builder needs a real
// `@nodes.Renderer`, so the proxy is one over a WebGL fallback backend whose `gl` is the
// renderer's context and whose `extensions` forward to the renderer's (upstream's backend
// object is `{ isWebGPUBackend: false, extensions, gl, capabilities }`). Its own members
// are those of `Renderer::new` (a `context()` node, an `InspectorBase`, a `Lighting`) plus a
// `BasicNodeLibrary`; `hasInitialized()` is `_initialized = true`, `getMRT()` the unset
// MRT, and TEXTURE_COMPARE is the WebGL backend's only compatibility. The WebGLRenderer
// members the nodes read through the proxy (tone mapping, exposure, output color space,
// shadow map, render target, size and pixel ratio, auto clear) are copied from the
// WebGLRenderer before every build and node update (`webgl_nodes_handler_sync`); the
// members it does not have upstream read as `undefined` there (`isRenderer`,
// `reversedDepthBuffer`, `logarithmicDepthBuffer`, `currentSamples`, `highPrecision`),
// here `false` / 0.
// `proxy._renderer` is `webgl_nodes_handler_webgl_renderer( proxy )`.
//
// Upstream hands WebGLRenderer the uniform nodes themselves as `{ value }` uniforms
// (`parameters.uniforms[ name ] = uniform.node`, `group.uniforms = nodeUniforms`), read at
// upload time. Here each is a `@core.Uniform` registered with its node
// (`webgl_nodes_handler_uniform_nodes`) and refreshed from the node after every node
// update and before every draw of the material (`webgl_nodes_handler_sync_uniforms`).
//
// `WebGLNodeBuilder` is a builder class wrapping the GLSL builder's payload, forwarding
// every `NodeBuilderClass` method to it and overriding `add_node`. Its per-instance
// overrides of a shadow node (`setupRenderTarget`, `updateBefore`) are a `ShadowNodeClass`
// over the node's class: `updateBefore` only ever reaches the renderer through
// `updateShadow`, which is the no-op here. Ad-hoc material fields (`_latestBuilder`,
// `prevObjectHash`) live in weak maps of the handler.

///|
/// `getObjectHash( object )`: the object parameters that change the shader.
fn webgl_nodes_handler_object_hash(object : @core.Object3D) -> String {
  "" + object.receive_shadow.to_string()
}

///|
/// `generateUniformsList( program, uniforms )` (WebGLUniforms.seqWithValue).
fn webgl_nodes_handler_uniforms_list(
  program : @webgl.WebGLProgram,
  uniforms : Map[String, @core.Uniform],
) -> Array[@webgl.WebGLUniformSetter] {
  let prog_uniforms = program.get_uniforms()
  let uniforms_list = []
  for i in 0..<prog_uniforms.seq.length() {
    let u = prog_uniforms.seq[i]
    if uniforms.contains(u.id().key()) {
      uniforms_list.push(u)
    }
  }
  uniforms_list
}

///|
extern "js" fn webgl_nodes_handler_js_string(x : Double) -> String = "(x) => String( x )"

///|
extern "js" fn webgl_nodes_handler_queue_microtask(f : () -> Unit) -> Unit = "(f) => queueMicrotask( f )"

///|
extern "js" fn webgl_nodes_handler_is_typed_array(x : @core.JsValue) -> Bool = "(x) => ArrayBuffer.isView( x )"

///|
extern "js" fn webgl_nodes_handler_stub_canvas() -> @core.JsValue = "() => ( { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } } )"

// ---------------------------------------------------------------------------
// Uniforms backed by nodes

///|
/// The node each `{ value }` uniform handed to WebGLRenderer reads its value from.
let webgl_nodes_handler_uniform_nodes : @webgl.WeakMap[
  @core.Uniform,
  @nodes.Node,
] = @webgl.WeakMap::new()

///|
fn webgl_nodes_handler_tsl_value(value : @nodes.TslValue) -> @core.UniformValue {
  match value {
    Undefined | Null => Null
    Number(n) => Number(n)
    Bool(b) => Bool(b)
    Vector2(v) => Vector2(v)
    Vector3(v) => Vector3(v)
    Vector4(v) => Vector4(v)
    Color(c) => Color(c)
    Matrix3(m) => Matrix3(m)
    Matrix4(m) => Matrix4(m)
    Texture(t) => Texture(t)
    Array(a) => Array(a.map(webgl_nodes_handler_tsl_value))
    Js(v) =>
      if webgl_nodes_handler_is_typed_array(v) {
        TypedArray(v.cast())
      } else {
        Other(v)
      }
    Matrix2(m) => Other(@core.JsValue::of(m))
    v => Other(@core.JsValue::of(v))
  }
}

///|
/// `node.value` of a uniform node, as a WebGL uniform value.
fn webgl_nodes_handler_node_value(node : @nodes.Node) -> @core.UniformValue {
  if node.is_instance_of("TextureNode") {
    match @nodes.TextureNode::get_value_opt(node) {
      Some(t) => Texture(t)
      None => Null
    }
  } else {
    webgl_nodes_handler_tsl_value(@nodes.InputNode::get_value(node))
  }
}

///|
/// A `{ value }` uniform reading `node.value`.
fn webgl_nodes_handler_node_uniform(node : @nodes.Node) -> @core.Uniform {
  let uniform = @core.Uniform::new(webgl_nodes_handler_node_value(node))
  webgl_nodes_handler_uniform_nodes.set(uniform, node)
  uniform
}

///|
fn webgl_nodes_handler_sync_uniform(uniform : @core.Uniform) -> Unit {
  if webgl_nodes_handler_uniform_nodes.get(uniform) is Some(node) {
    uniform.value = webgl_nodes_handler_node_value(node)
  }
}

///|
/// Refreshes the node-backed uniforms and uniform groups from their nodes.
fn webgl_nodes_handler_sync_uniforms(
  uniforms : Map[String, @core.Uniform]?,
  uniforms_groups : Array[@core.UniformsGroup]?,
) -> Unit {
  if uniforms is Some(uniforms) {
    for _, uniform in uniforms {
      webgl_nodes_handler_sync_uniform(uniform)
    }
  }
  if uniforms_groups is Some(groups) {
    for group in groups {
      for entry in group.uniforms {
        match entry {
          Single(u) => webgl_nodes_handler_sync_uniform(u)
          Multiple(us) => us.each(webgl_nodes_handler_sync_uniform)
        }
      }
    }
  }
}

///|
/// `uniform.nodeUniform` of a uniform of a `NodeUniformsGroup`.
fn webgl_nodes_handler_group_node_uniform(
  uniform : @nodes.Uniform,
) -> @nodes.NodeUniform {
  if @nodes.NumberNodeUniform::of(uniform) is Some(u) {
    u.node_uniform
  } else if @nodes.Vector2NodeUniform::of(uniform) is Some(u) {
    u.node_uniform
  } else if @nodes.Vector3NodeUniform::of(uniform) is Some(u) {
    u.node_uniform
  } else if @nodes.Vector4NodeUniform::of(uniform) is Some(u) {
    u.node_uniform
  } else if @nodes.ColorNodeUniform::of(uniform) is Some(u) {
    u.node_uniform
  } else if @nodes.Matrix2NodeUniform::of(uniform) is Some(u) {
    u.node_uniform
  } else if @nodes.Matrix3NodeUniform::of(uniform) is Some(u) {
    u.node_uniform
  } else if @nodes.Matrix4NodeUniform::of(uniform) is Some(u) {
    u.node_uniform
  } else {
    abort("WebGLNodesHandler: \{uniform.name} is not a node uniform")
  }
}

// ---------------------------------------------------------------------------
// RendererProxy

///|
/// `rendererProxy._renderer`.
let webgl_nodes_handler_proxies : @webgl.WeakMap[
  @nodes.Renderer,
  @webgl.WebGLRenderer,
] = @webgl.WeakMap::new()

///|
fn webgl_nodes_handler_webgl_renderer(
  renderer : @nodes.Renderer,
) -> @webgl.WebGLRenderer {
  match webgl_nodes_handler_proxies.get(renderer) {
    Some(r) => r
    None => abort("WebGLNodesHandler: not a renderer proxy")
  }
}

///|
/// `new RendererProxy( renderer )`.
fn webgl_nodes_handler_renderer_proxy(
  renderer : @webgl.WebGLRenderer,
) -> @nodes.Renderer {
  let parameters = @core.JsValue::object()
  parameters.set("canvas", webgl_nodes_handler_stub_canvas())
  parameters.set("forceWebGL", @core.JsValue::of(true))
  let backend = @webgl_fallback.WebGLBackend::new(parameters~)
  let payload = @webgl_fallback.WebGLBackend::of(backend).unwrap()
  let gl = renderer.get_context()
  payload.gl = Some(gl)
  payload.extensions = Some({
    backend: payload,
    gl,
    available_extensions: [],
    extensions: Map([]),
    _renderer_extensions: Some(renderer.extensions),
  })
  payload.capabilities = Some(@webgl_fallback.WebGLCapabilities::new(payload))
  let proxy = @nodes.Renderer::new(backend)
  proxy.library = @webgpu.BasicNodeLibrary::new()
  proxy._initialized = true
  // `isRenderer` is the WebGLRenderer's: undefined
  proxy.is_renderer = false
  backend.renderer = Some(proxy)
  webgl_nodes_handler_proxies.set(proxy, renderer)
  webgl_nodes_handler_sync(proxy)
  proxy
}

///|
/// The proxy's view of the WebGLRenderer members the nodes read.
fn webgl_nodes_handler_sync(proxy : @nodes.Renderer) -> Unit {
  let renderer = webgl_nodes_handler_webgl_renderer(proxy)
  proxy.tone_mapping = renderer.tone_mapping
  proxy.tone_mapping_exposure = renderer.tone_mapping_exposure
  proxy.output_color_space = renderer.output_color_space()
  proxy.shadow_map.enabled = renderer.shadow_map.enabled
  proxy.shadow_map.type_ = renderer.shadow_map.type_
  proxy._render_target = renderer.get_render_target()
  proxy._active_cube_face = renderer.get_active_cube_face()
  proxy._active_mipmap_level = renderer.get_active_mipmap_level()
  proxy.auto_clear = renderer.auto_clear
  proxy.auto_clear_color = renderer.auto_clear_color
  proxy.auto_clear_depth = renderer.auto_clear_depth
  proxy.auto_clear_stencil = renderer.auto_clear_stencil
  proxy.sort_objects = renderer.sort_objects
  let canvas_target = proxy._canvas_target
  canvas_target._pixel_ratio = renderer._pixel_ratio
  canvas_target._width = renderer._width
  canvas_target._height = renderer._height
}

///|
/// `rendererProxy.getCacheKey()`.
fn webgl_nodes_handler_renderer_cache_key(proxy : @nodes.Renderer) -> String {
  let renderer = webgl_nodes_handler_webgl_renderer(proxy)
  renderer.tone_mapping.to_string() + renderer.output_color_space()
}

// ---------------------------------------------------------------------------
// WebGLNodeBuilder

///|
/// `class WebGLNodeBuilder extends GLSLNodeBuilder`: adapts nodes to use WebGLRenderer
/// resources.
priv struct WebGLNodesHandlerNodeBuilder {
  glsl : @webgl_fallback.GLSLNodeBuilder
}

///|
/// `new WebGLNodeBuilder( object, renderer )`.
fn WebGLNodesHandlerNodeBuilder::new(
  object : @core.Object3D,
  renderer : @nodes.Renderer,
) -> @nodes.NodeBuilder {
  let builder = @webgl_fallback.GLSLNodeBuilder::new(Object3D(object), renderer)
  let glsl = @webgl_fallback.GLSLNodeBuilder::of(builder).unwrap()
  builder.class_ = WebGLNodesHandlerNodeBuilder::{ glsl, }
  builder
}

///|
/// The shadow nodes `addNode` already redirected.
let webgl_nodes_handler_shadow_nodes : @webgl.WeakMap[@nodes.Node, Bool] = @webgl.WeakMap::new()

///|
/// A shadow node's `setupRenderTarget` and `updateBefore` instance overrides.
priv struct WebGLNodesHandlerShadowClass {
  parent : &@nodes.ShadowNodeClass
}

///|
impl @nodes.ShadowNodeClass for WebGLNodesHandlerShadowClass with fn shadow_parent(
  self,
) {
  Some(self.parent)
}

///|
impl @nodes.ShadowNodeClass for WebGLNodesHandlerShadowClass with fn setup_render_target(
  _,
  _,
  shadow,
  _,
) {
  let shadow_map = shadow.map.unwrap()
  { shadow_map, depth_texture: shadow_map.depth_texture().unwrap(), }
}

///|
impl @nodes.ShadowNodeClass for WebGLNodesHandlerShadowClass with fn update_shadow(
  _,
  _,
  _,
) {
  // no need to rerender shadows since WebGLRenderer is handling it
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn class_name(
  _,
) {
  "WebGLNodeBuilder"
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn payload(
  self,
) {
  @core.JsValue::of(self)
}

///|
/// `addNode( node )`.
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn add_node(
  _,
  b,
  node,
) {
  if node.has_flag("isShadowNode") {
    if !webgl_nodes_handler_shadow_nodes.has(node) {
      webgl_nodes_handler_shadow_nodes.set(node, true)
      let shadow = @nodes.ShadowNode::of(node).unwrap()
      shadow.class_ = WebGLNodesHandlerShadowClass::{ parent: shadow.class_, }
    }
  } else if @nodes.PMREMNode::of(node) is Some(pmrem) &&
    pmrem._generator is None &&
    pmrem._webgl_generator is None {
    pmrem._webgl_generator = Some(
      @webgl.PMREMGenerator::new(webgl_nodes_handler_webgl_renderer(b.renderer)),
    )
  }
  b.add_node_base(node)
}

// The GLSLNodeBuilder methods, inherited.

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn has_flag(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::has_flag(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn _get_bind_group(
  self,
  a1,
  a2,
  a3,
) {
  @nodes.NodeBuilderClass::_get_bind_group(self.glsl, a1, a2, a3)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn build_code(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::build_code(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn prebuild(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::prebuild(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn build_function_code(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::build_function_code(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn enable_dual_source_blending(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::enable_dual_source_blending(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn enable_shader_f16(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::enable_shader_f16(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn enable_sub_groups(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::enable_sub_groups(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_array_declaration(
  self,
  a1,
  a2,
  a3,
) {
  @nodes.NodeBuilderClass::generate_array_declaration(self.glsl, a1, a2, a3)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_const_statement(
  self,
  a1,
  a2,
  a3,
  a4,
) {
  @nodes.NodeBuilderClass::generate_const_statement(self.glsl, a1, a2, a3, a4)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_let_statement(
  self,
  a1,
  a2,
  a3,
  a4,
) {
  @nodes.NodeBuilderClass::generate_let_statement(self.glsl, a1, a2, a3, a4)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_var_statement(
  self,
  a1,
  a2,
  a3,
  a4,
) {
  @nodes.NodeBuilderClass::generate_var_statement(self.glsl, a1, a2, a3, a4)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_texture(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
  a6,
  a7,
) {
  @nodes.NodeBuilderClass::generate_texture(
    self.glsl,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
  )
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_texture_lod(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
  a6,
  a7,
) {
  @nodes.NodeBuilderClass::generate_texture_lod(
    self.glsl,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
  )
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_texture_size(
  self,
  a1,
  a2,
  a3,
  a4,
) {
  @nodes.NodeBuilderClass::generate_texture_size(self.glsl, a1, a2, a3, a4)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_attributes(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::get_attributes(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_declaration_name(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::get_declaration_name(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_draw_index(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::get_draw_index(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_frag_coord(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::get_frag_coord(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_front_facing(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::get_front_facing(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_function_operator(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::get_function_operator(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_instance_index(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::get_instance_index(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_invocation_subgroup_index(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::get_invocation_subgroup_index(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_method(
  self,
  a1,
  a2,
  a3,
) {
  @nodes.NodeBuilderClass::get_method(self.glsl, a1, a2, a3)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_output_struct_name(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::get_output_struct_name(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_property_name(
  self,
  a1,
  a2,
  a3,
) {
  @nodes.NodeBuilderClass::get_property_name(self.glsl, a1, a2, a3)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_subgroup_index(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::get_subgroup_index(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_subgroup_size(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::get_subgroup_size(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_ternary(
  self,
  a1,
  a2,
  a3,
  a4,
) {
  @nodes.NodeBuilderClass::get_ternary(self.glsl, a1, a2, a3, a4)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_type(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::get_type(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_type_from_attribute(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::get_type_from_attribute(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_uniform_from_node(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
) {
  @nodes.NodeBuilderClass::get_uniform_from_node(self.glsl, a1, a2, a3, a4, a5)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_uniforms(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::get_uniforms(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_var(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
) {
  @nodes.NodeBuilderClass::get_var(self.glsl, a1, a2, a3, a4, a5)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_vars(
  self,
  a1,
  a2,
  a3,
) {
  @nodes.NodeBuilderClass::get_vars(self.glsl, a1, a2, a3)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_varyings(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::get_varyings(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_vector_select(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
) {
  @nodes.NodeBuilderClass::get_vector_select(self.glsl, a1, a2, a3, a4, a5)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_vertex_index(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::get_vertex_index(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn is_available(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::is_available(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn is_flip_y(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::is_flip_y(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn is_reserved_keyword(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::is_reserved_keyword(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn needs_to_working_color_space(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::needs_to_working_color_space(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn enable_hardware_clipping(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::enable_hardware_clipping(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_pbo(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::generate_pbo(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn setup_pbo(
  self,
  a1,
  a2,
) {
  @nodes.NodeBuilderClass::setup_pbo(self.glsl, a1, a2)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_texture_load(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
  a6,
  a7,
) {
  @nodes.NodeBuilderClass::generate_texture_load(
    self.glsl,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
  )
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_storage_texture_load(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
  a6,
  a7,
) {
  @nodes.NodeBuilderClass::generate_storage_texture_load(
    self.glsl,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
  )
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_texture_level(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
  a6,
  a7,
) {
  @nodes.NodeBuilderClass::generate_texture_level(
    self.glsl,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
  )
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_texture_bias(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
  a6,
  a7,
  a8,
) {
  @nodes.NodeBuilderClass::generate_texture_bias(
    self.glsl,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
  )
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_texture_grad(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
  a6,
  a7,
  a8,
) {
  @nodes.NodeBuilderClass::generate_texture_grad(
    self.glsl,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
  )
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_texture_compare(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
  a6,
  a7,
  a8,
) {
  @nodes.NodeBuilderClass::generate_texture_compare(
    self.glsl,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
  )
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_texture_gather(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
  a6,
  a7,
  a8,
) {
  @nodes.NodeBuilderClass::generate_texture_gather(
    self.glsl,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
  )
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_texture_gather_compare(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
  a6,
  a7,
  a8,
) {
  @nodes.NodeBuilderClass::generate_texture_gather_compare(
    self.glsl,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
  )
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn generate_texture_store(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
  a6,
) {
  @nodes.NodeBuilderClass::generate_texture_store(
    self.glsl,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
  )
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_bitcast_method(
  self,
  a1,
  a2,
  a3,
) {
  @nodes.NodeBuilderClass::get_bitcast_method(self.glsl, a1, a2, a3)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_float_packing_method(
  self,
  a1,
  a2,
  a3,
) {
  @nodes.NodeBuilderClass::get_float_packing_method(self.glsl, a1, a2, a3)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_float_unpacking_method(
  self,
  a1,
  a2,
  a3,
) {
  @nodes.NodeBuilderClass::get_float_unpacking_method(self.glsl, a1, a2, a3)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_clip_distance(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::get_clip_distance(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_frag_depth(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::get_frag_depth(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_invocation_local_index(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::get_invocation_local_index(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn get_scoped_array(
  self,
  a1,
  a2,
  a3,
  a4,
  a5,
  a6,
) {
  @nodes.NodeBuilderClass::get_scoped_array(self.glsl, a1, a2, a3, a4, a5, a6)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn has_builtin(
  self,
  a1,
  a2,
  a3,
) {
  @nodes.NodeBuilderClass::has_builtin(self.glsl, a1, a2, a3)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn register_transform(
  self,
  a1,
  a2,
  a3,
) {
  @nodes.NodeBuilderClass::register_transform(self.glsl, a1, a2, a3)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn enable_multiview(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::enable_multiview(self.glsl, a1)
}

///|
impl @nodes.NodeBuilderClass for WebGLNodesHandlerNodeBuilder with fn transforms(
  self,
  a1,
) {
  @nodes.NodeBuilderClass::transforms(self.glsl, a1)
}

// ---------------------------------------------------------------------------
// SceneContext

///|
/// `class SceneContext`: reusable nodes of a scene.
priv struct WebGLNodesHandlerSceneContext {
  // TODO: can / should we update the fog and environment node every frame for recompile?
  // (upstream also keeps the unused `renderer`)
  scene : @core.Object3D
  lights_node : @nodes.Node
  mut fog_node : @nodes.Node?
  mut environment_node : @nodes.Node?
  mut prev_fog : @core.SceneFog?
  mut prev_environment : @core.Texture?
}

///|
/// `new SceneContext( renderer, scene )`.
fn WebGLNodesHandlerSceneContext::new(
  renderer : @nodes.Renderer,
  scene : @core.Object3D,
) -> WebGLNodesHandlerSceneContext {
  {
    scene,
    lights_node: renderer.lighting.get_node(scene),
    fog_node: None,
    environment_node: None,
    prev_fog: None,
    prev_environment: None,
  }
}

///|
fn WebGLNodesHandlerSceneContext::get_cache_key(
  self : WebGLNodesHandlerSceneContext,
) -> Double {
  let lights_hash = self.lights_node.get_cache_key()
  let env_hash = match self.environment_node {
    Some(n) => n.get_cache_key()
    None => 0.0
  }
  let fog_hash = match self.fog_node {
    Some(n) => n.get_cache_key()
    None => 0.0
  }
  @nodes.hash_array([lights_hash, env_hash, fog_hash])
}

///|
fn webgl_nodes_handler_same_fog(
  a : @core.SceneFog?,
  b : @core.SceneFog?,
) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(Fog(x)), Some(Fog(y))) => physical_equal(x, y)
    (Some(FogExp2(x)), Some(FogExp2(y))) => physical_equal(x, y)
    _ => false
  }
}

///|
fn webgl_nodes_handler_same_texture(
  a : @core.Texture?,
  b : @core.Texture?,
) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(x), Some(y)) => physical_equal(x, y)
    _ => false
  }
}

///|
/// `scene.fog`; `None` also for objects other than scenes (`undefined` upstream, which
/// yields no fog node either).
fn WebGLNodesHandlerSceneContext::scene_fog(
  self : WebGLNodesHandlerSceneContext,
) -> @core.SceneFog? {
  if self.scene.is_scene() {
    self.scene.as_scene().fog
  } else {
    None
  }
}

///|
/// `scene.environment` (`None` for objects other than scenes).
fn WebGLNodesHandlerSceneContext::scene_environment(
  self : WebGLNodesHandlerSceneContext,
) -> @core.Texture? {
  if self.scene.is_scene() {
    self.scene.as_scene().environment
  } else {
    None
  }
}

///|
fn WebGLNodesHandlerSceneContext::update(
  self : WebGLNodesHandlerSceneContext,
) -> Unit {
  // update fog
  let fog = self.scene_fog()
  if !webgl_nodes_handler_same_fog(self.prev_fog, fog) {
    self.fog_node = self.get_fog_node()
    self.prev_fog = fog
  }
  // update environment
  let environment = self.scene_environment()
  if !webgl_nodes_handler_same_texture(self.prev_environment, environment) {
    self.environment_node = self.get_environment_node()
    self.prev_environment = environment
  }
}

///|
fn WebGLNodesHandlerSceneContext::get_fog_node(
  self : WebGLNodesHandlerSceneContext,
) -> @nodes.Node? {
  match self.scene_fog() {
    Some(FogExp2(_) as f) => {
      let color = @nodes.reference("color", "color", object=Fog(f))
      let density = @nodes.reference("density", "float", object=Fog(f))
      Some(@nodes.fog.call([color, @nodes.density_fog_factor.call([density])]))
    }
    Some(Fog(_) as f) => {
      let color = @nodes.reference("color", "color", object=Fog(f))
      let near = @nodes.reference("near", "float", object=Fog(f))
      let far = @nodes.reference("far", "float", object=Fog(f))
      Some(@nodes.fog.call([color, @nodes.range_fog_factor.call([near, far])]))
    }
    None => None
  }
}

///|
fn WebGLNodesHandlerSceneContext::get_environment_node(
  self : WebGLNodesHandlerSceneContext,
) -> @nodes.Node? {
  match self.scene_environment() {
    Some(environment) if environment.is_cube_texture() =>
      Some(@nodes.cube_texture(@nodes.TslValue::Texture(environment)))
    Some(environment) =>
      Some(@nodes.texture(@nodes.TslValue::Texture(environment)))
    None => None
  }
}

// ---------------------------------------------------------------------------
// WebGLNodesHandler

///|
/// One `programCache` entry: what `onUpdateProgram` caches per program.
priv struct WebGLNodesHandlerProgramEntry {
  uniforms_groups : Array[@core.UniformsGroup]
  uniforms : Map[String, @core.Uniform]?
  uniforms_list : Array[@webgl.WebGLUniformSetter]
  update_nodes : Array[@nodes.Node]
}

///|
/// One `renderStack` frame.
priv struct WebGLNodesHandlerFrame {
  scene_context : WebGLNodesHandlerSceneContext
  camera : @core.Object3D
}

///|
/// Compatibility loader and builder for TSL node materials in WebGLRenderer.
pub(all) struct WebGLNodesHandler {
  /// The renderer proxy (`None` until `set_renderer`).
  mut renderer : @nodes.Renderer?
  node_frame : @nodes.NodeFrame
  priv scene_contexts : @webgl.WeakMap[
    @core.Object3D,
    WebGLNodesHandlerSceneContext,
  ]
  /// `programCache`: material -> program -> entry, in insertion order.
  priv program_cache : @webgl.WeakMap[
    @core.Material,
    Array[(@webgl.WebGLProgram, WebGLNodesHandlerProgramEntry)],
  ]
  priv render_stack : Array[WebGLNodesHandlerFrame]
  /// `material._latestBuilder`.
  priv latest_builders : @webgl.WeakMap[@core.Material, @nodes.NodeBuilder]
  /// `material.prevObjectHash`.
  priv prev_object_hashes : @webgl.WeakMap[@core.Material, String]
  mut on_dispose_material_callback : (@core.Event) -> Unit
  mut get_output_callback : (@nodes.Node, @nodes.NodeBuilder) -> @nodes.Node
}

///|
/// `new WebGLNodesHandler()`.
pub fn WebGLNodesHandler::new() -> WebGLNodesHandler {
  let self : WebGLNodesHandler = {
    renderer: None,
    node_frame: @nodes.NodeFrame::new(),
    scene_contexts: @webgl.WeakMap::new(),
    program_cache: @webgl.WeakMap::new(),
    render_stack: [],
    latest_builders: @webgl.WeakMap::new(),
    prev_object_hashes: @webgl.WeakMap::new(),
    on_dispose_material_callback: _ => (),
    get_output_callback: (output_node, _) => output_node,
  }
  let on_dispose_material_callback : Ref[(@core.Event) -> Unit] = Ref(_ => ())
  on_dispose_material_callback.val = event => {
    guard event.target is Some(Material(material)) else { return }
    // dispose of all the uniform groups
    let program_cache = self.program_cache
    if program_cache.get(material) is Some(programs) {
      for entry in programs {
        entry.1.uniforms_groups.each(u => u.dispose())
      }
      self.program_cache.delete(material)
    }
    material.remove_event_listener("dispose", on_dispose_material_callback.val)
  }
  self.on_dispose_material_callback = on_dispose_material_callback.val
  self.get_output_callback = (output_node, _) => {
    // apply tone mapping and color spaces to the output
    let renderer = webgl_nodes_handler_webgl_renderer(self.renderer.unwrap())
    let output_color_space = renderer.output_color_space()
    let tone_mapping = renderer.tone_mapping
    let output_node = output_node.tone_mapping(tone_mapping)
    @nodes.working_to_color_space(output_node, output_color_space)
  }
  self
}

///|
/// `onBeforeRenderCallback`, the `onBeforeRender` of every node material.
fn WebGLNodesHandler::on_before_render_callback(
  self : WebGLNodesHandler,
  material : @core.Material,
  object : @core.Object3D,
) -> Unit {
  let renderer = webgl_nodes_handler_webgl_renderer(self.renderer.unwrap())
  // update node frame references for update nodes
  let node_frame = self.node_frame
  node_frame.material = Some(material)
  node_frame.object = Some(object)
  // increment "frame" here to force uniform buffers to update for the material, which otherwise only get
  // updated once per frame.
  renderer.info.render.frame += 1
  // update the uniform groups and nodes for the program if they're available before rendering
  if renderer.properties.has(material) {
    let material_properties = renderer.properties.get_material(material)
    let current_program = material_properties.current_program
    let programs = self.program_cache.get(material)
    if programs is Some(programs) &&
      current_program is Some(current_program) &&
      programs.iter().find_first(e => physical_equal(e.0, current_program))
      is Some((_, { update_nodes, .. })) {
      // update the nodes for the current object
      self.update_nodes(update_nodes)
    }
    webgl_nodes_handler_sync_uniforms(
      material_properties.uniforms,
      material.uniforms_groups,
    )
  }
  let object_hash = webgl_nodes_handler_object_hash(object)
  if self.prev_object_hashes.get(material) != Some(object_hash) {
    self.prev_object_hashes.set(material, object_hash)
    material.set_needs_update(true)
  }
}

///|
/// `customProgramCacheKeyCallback`, the `customProgramCacheKey` of every node material.
fn WebGLNodesHandler::custom_program_cache_key_callback(
  self : WebGLNodesHandler,
  material : @core.Material,
) -> String {
  let render_stack = self.render_stack
  let renderer = self.renderer.unwrap()
  let node_frame = self.node_frame
  let scene_hash = render_stack[render_stack.length() - 1].scene_context.get_cache_key()
  // this.constructor.prototype.customProgramCacheKey.call( this )
  let own = material.custom_program_cache_key
  material.custom_program_cache_key = None
  let material_hash = material.custom_program_cache_key()
  material.custom_program_cache_key = own
  let renderer_hash = webgl_nodes_handler_renderer_cache_key(renderer)
  material_hash +
  webgl_nodes_handler_js_string(scene_hash) +
  renderer_hash +
  webgl_nodes_handler_object_hash(node_frame.object.unwrap())
}

///|
/// `setRenderer( renderer )`.
pub fn WebGLNodesHandler::set_renderer(
  self : WebGLNodesHandler,
  renderer : @webgl.WebGLRenderer,
) -> Unit {
  let renderer_proxy = webgl_nodes_handler_renderer_proxy(renderer)
  self.node_frame.renderer = Some(renderer_proxy)
  self.renderer = Some(renderer_proxy)
}

///|
/// `onUpdateProgram( material, program, materialProperties )`.
pub fn WebGLNodesHandler::on_update_program(
  self : WebGLNodesHandler,
  material : @core.Material,
  program : @webgl.WebGLProgram,
  material_properties : @webgl.MaterialProperties,
) -> Unit {
  let program_cache = self.program_cache
  if !program_cache.has(material) {
    program_cache.set(material, [])
  }
  let programs = program_cache.get(material).unwrap()
  if !programs.iter().any(e => physical_equal(e.0, program)) {
    let builder = self.latest_builders.get(material).unwrap()
    let uniforms = material_properties.uniforms
    programs.push(
      (
        program,
        {
          uniforms_groups: self.collect_uniforms_groups(builder),
          uniforms,
          uniforms_list: webgl_nodes_handler_uniforms_list(
            program,
            uniforms.unwrap(),
          ),
          update_nodes: builder.update_nodes,
        },
      ),
    )
  }
  let { uniforms_groups, uniforms, uniforms_list, update_nodes, } = programs
    .iter()
    .find_first(e => physical_equal(e.0, program))
    .unwrap().1
  material.uniforms_groups = Some(uniforms_groups)
  material_properties.uniforms = uniforms
  material_properties.uniforms_list = Some(uniforms_list)
  self.update_nodes(update_nodes)
  webgl_nodes_handler_sync_uniforms(uniforms, Some(uniforms_groups))
}

///|
/// `renderStart( scene, camera, targetScene = scene )`.
pub fn WebGLNodesHandler::render_start(
  self : WebGLNodesHandler,
  scene : @core.Object3D,
  camera : @core.Object3D,
  target_scene? : @core.Object3D,
) -> Unit {
  let target_scene = match target_scene {
    Some(t) => t
    None => scene
  }
  let node_frame = self.node_frame
  let render_stack = self.render_stack
  let renderer = self.renderer.unwrap()
  let scene_contexts = self.scene_contexts
  webgl_nodes_handler_sync(renderer)
  node_frame.update()
  node_frame.camera = Some(camera)
  node_frame.scene = Some(target_scene)
  node_frame.frame_id += 1
  let scene_context = match scene_contexts.get(target_scene) {
    Some(c) => c
    None => {
      let c = WebGLNodesHandlerSceneContext::new(renderer, target_scene)
      scene_contexts.set(target_scene, c)
      c
    }
  }
  renderer.lighting.begin_render(target_scene)
  scene_context.update()
  render_stack.push({ scene_context, camera, })
}

///|
/// `updateLights( lights )`.
pub fn WebGLNodesHandler::update_lights(
  self : WebGLNodesHandler,
  lights : Array[@core.Object3D],
) -> Unit {
  let frame = self.render_stack[self.render_stack.length() - 1]
  @nodes.LightsNode::set_lights(frame.scene_context.lights_node, lights)
  |> ignore
}

///|
/// `renderEnd()`.
pub fn WebGLNodesHandler::render_end(self : WebGLNodesHandler) -> Unit {
  let node_frame = self.node_frame
  let renderer = self.renderer.unwrap()
  let render_stack = self.render_stack
  let { scene_context, .. } = render_stack.pop().unwrap()
  renderer.lighting.finish_render(scene_context.scene)
  if render_stack.last() is Some({ camera, scene_context, }) {
    node_frame.camera = Some(camera)
    node_frame.scene = Some(scene_context.scene)
  }
}

///|
/// `setObject( object, material )`.
pub fn WebGLNodesHandler::set_object(
  self : WebGLNodesHandler,
  object : @core.Object3D,
  material : @core.Material,
) -> Unit {
  self.node_frame.object = Some(object)
  material.custom_program_cache_key = Some(() => {
    self.custom_program_cache_key_callback(material)
  })
  material.on_before_render = (_, _, _, _, object, _) => {
    self.on_before_render_callback(material, object)
  }
}

///|
/// `build( material, object, parameters )`.
pub fn WebGLNodesHandler::build(
  self : WebGLNodesHandler,
  material : @core.Material,
  object : @core.Object3D,
  parameters : @webgl.WebGLProgramParameters,
) -> Unit {
  let node_frame = self.node_frame
  let renderer = self.renderer.unwrap()
  let get_output_callback = self.get_output_callback
  let on_dispose_material_callback = self.on_dispose_material_callback
  let render_stack = self.render_stack
  let { camera, scene_context, } = render_stack[render_stack.length() - 1]
  let { fog_node, environment_node, lights_node, scene, .. } = scene_context
  webgl_nodes_handler_sync(renderer)
  // prepare the frame
  node_frame.material = Some(material)
  node_frame.object = Some(object)
  // create & run the builder
  let builder = WebGLNodesHandlerNodeBuilder::new(object, renderer)
  builder.scene = Some(scene)
  builder.camera = Some(camera)
  builder.material = Some(material)
  builder.fog_node = fog_node
  builder.environment_node = environment_node
  builder.lights_node = Some(lights_node)
  builder.context.set(
    "getOutput",
    Other(
      @core.JsValue::of(@nodes.ContextGetOutput::{ f: get_output_callback, }),
    ),
  )
  builder.build() |> ignore
  // update the shader parameters and geometry for program creation and rendering
  self.update_shader_parameters(builder, parameters)
  self.update_geometry_attributes(builder, object.get_geometry().unwrap())
  // reset node frame settings to account for any intermediate renders
  node_frame.material = Some(material)
  node_frame.object = Some(object)
  // set up callbacks for uniforms and node updates
  self.latest_builders.set(material, builder)
  material.add_event_listener("dispose", on_dispose_material_callback)
  self.update_nodes(builder.update_nodes)
  webgl_nodes_handler_sync_uniforms(Some(parameters.shader.uniforms), None)
}

///|
/// `updateGeometryAttributes( builder, geometry )`.
pub fn WebGLNodesHandler::update_geometry_attributes(
  _self : WebGLNodesHandler,
  builder : @nodes.NodeBuilder,
  geometry : @core.BufferGeometry,
) -> Unit {
  // TODO: this may cause issues if the material / geometry is used in multiple places

  // add instancing attributes
  builder.buffer_attributes.each(v => {
    let node = @nodes.BufferAttributeNode::of(v.node.unwrap()).unwrap()
    geometry.set_attribute(v.name, node.attribute.unwrap()) |> ignore
  })
  // force WebGLAttributes & WebGLBindingStates to refresh
  // could be fixed by running "build" sooner? Or calling "WebGLAttributes" separately for those
  // associated with a material?
  webgl_nodes_handler_queue_microtask(() => geometry.dispose())
}

///|
/// `string.replace( /#version 300 es/, '' )`.
fn webgl_nodes_handler_strip_version(code : String) -> String {
  code.replace(old="#version 300 es", new="")
}

///|
/// `updateShaderParameters( builder, parameters )`.
pub fn WebGLNodesHandler::update_shader_parameters(
  _self : WebGLNodesHandler,
  builder : @nodes.NodeBuilder,
  parameters : @webgl.WebGLProgramParameters,
) -> Unit {
  // set up shaders
  parameters.is_raw_shader_material = true
  parameters.glsl_version = Some(@core.GLSL3)
  parameters.shader.vertex_shader = webgl_nodes_handler_strip_version(
    builder.vertex_shader.unwrap(),
  )
  parameters.shader.fragment_shader = webgl_nodes_handler_strip_version(
    builder.fragment_shader.unwrap(),
  )
  // add uniforms accessed by WebGLRenderer
  let uniforms : Map[String, @core.Uniform] = Map([
    ("fogColor", @core.Uniform::new(Color(@math.Color::new(1.0, 1.0, 1.0)))),
    ("fogNear", @core.Uniform::new(Number(0.0))),
    ("fogFar", @core.Uniform::new(Number(0.0))),
    ("fogDensity", @core.Uniform::new(Number(0.0))),
    ("envMapIntensity", @core.Uniform::new(Number(0.0))),
  ])
  for name, uniform in @core.clone_uniforms(@shaders.uniforms_lib["lights"]) {
    uniforms[name] = uniform
  }
  parameters.shader.uniforms = uniforms
  // init uniforms
  let builder_uniforms = [
    ..builder.uniforms.vertex,
    ..builder.uniforms.fragment,
  ]
  for uniform in builder_uniforms {
    parameters.shader.uniforms[uniform.name] = webgl_nodes_handler_node_uniform(
      uniform.node,
    )
  }
}

///|
/// `collectUniformsGroups( builder )`.
pub fn WebGLNodesHandler::collect_uniforms_groups(
  _self : WebGLNodesHandler,
  builder : @nodes.NodeBuilder,
) -> Array[@core.UniformsGroup] {
  let glsl = match builder.class_.payload().cast() {
    ({ glsl, } : WebGLNodesHandlerNodeBuilder) => glsl
  }
  // create UniformsGroups for regular grouped uniforms
  let uniforms_groups = []
  for key, binding in glsl.uniform_groups {
    let uniforms = @nodes.UniformsGroup::of(binding).unwrap().uniforms
    let group = @core.UniformsGroup::new()
    group.name = key
    group.uniforms = uniforms.map(node => {
      let node_uniform = webgl_nodes_handler_group_node_uniform(node)
      let uniform = webgl_nodes_handler_node_uniform(node_uniform.node)
      // `uniform.type`, which WebGLUniformsGroups reads
      @webgl.set_uniform_type(uniform, node_uniform.type_)
      @core.UniformsGroupEntry::Single(uniform)
    })
    uniforms_groups.push(group)
  }
  // init uniforms
  for shader_stage in ["vertex", "fragment"] {
    for uniform in builder.uniforms.stage(shader_stage) {
      if uniform.type_ == "buffer" {
        // buffer uniforms are all nested in groups
        let group = @core.UniformsGroup::new()
        group.name = glsl.get_uniform_buffer_name(
          builder, uniform, shader_stage,
        )
        let u = webgl_nodes_handler_node_uniform(uniform.node)
        @webgl.set_uniform_type(u, uniform.type_)
        group.uniforms = [Single(u)]
        uniforms_groups.push(group)
      }
    }
  }
  uniforms_groups
}

///|
/// `updateNodes( updateNodes )`.
pub fn WebGLNodesHandler::update_nodes(
  self : WebGLNodesHandler,
  update_nodes : Array[@nodes.Node],
) -> Unit {
  // update nodes for render
  let node_frame = self.node_frame
  webgl_nodes_handler_sync(self.renderer.unwrap())
  node_frame.render_id += 1
  for node in update_nodes {
    node_frame.update_node(node)
  }
}

///|
pub impl @webgl.WebGLNodesHandler for WebGLNodesHandler with fn set_renderer(
  self,
  renderer,
) {
  WebGLNodesHandler::set_renderer(self, renderer)
}

///|
pub impl @webgl.WebGLNodesHandler for WebGLNodesHandler with fn set_object(
  self,
  object,
  material,
) {
  WebGLNodesHandler::set_object(self, object, material)
}

///|
pub impl @webgl.WebGLNodesHandler for WebGLNodesHandler with fn render_start(
  self,
  scene,
  camera,
  target_scene,
) {
  WebGLNodesHandler::render_start(self, scene, camera, target_scene?)
}

///|
pub impl @webgl.WebGLNodesHandler for WebGLNodesHandler with fn render_end(self) {
  WebGLNodesHandler::render_end(self)
}

///|
pub impl @webgl.WebGLNodesHandler for WebGLNodesHandler with fn update_lights(
  self,
  lights,
) {
  WebGLNodesHandler::update_lights(self, lights)
}

///|
pub impl @webgl.WebGLNodesHandler for WebGLNodesHandler with fn build(
  self,
  material,
  object,
  parameters,
) {
  WebGLNodesHandler::build(self, material, object, parameters)
}

///|
pub impl @webgl.WebGLNodesHandler for WebGLNodesHandler with fn on_update_program(
  self,
  material,
  program,
  material_properties,
) {
  WebGLNodesHandler::on_update_program(
    self, material, program, material_properties,
  )
}
