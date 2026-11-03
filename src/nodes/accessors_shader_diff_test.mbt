// MoonBit side of the G2 (nodes/accessors) shader scenarios. The upstream side is
// diff/core/webgpu/shader_diff/upstream_g2.mjs; `node shader_diff/run.mjs
// g2_...` compares them byte for byte.
//
// Both sides build with `G2Builder`: a NodeBuilder class whose texture methods print
// their arguments (`null` as `-`) and which can report `isFlipY()`, on a mesh whose
// geometry has every attribute the scenarios read, with a perspective camera. Records
// add the varyings and attributes the build declared.

///|
extern "js" fn g2_shader_diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.SHADER_DIFF === '1'"

///|
extern "js" fn g2_shader_json(
  code : String,
  result : String,
  vars : String,
  uniforms : Array[String],
  varyings : Array[String],
  attributes : Array[String],
  values : Array[String],
) -> String = "(code, result, vars, uniforms, varyings, attributes, values) => JSON.stringify({ code, result, vars, uniforms, varyings, attributes, values })"

///|
/// JS `String( n )`.
extern "js" fn g2_number(n : Double) -> String = "(n) => String(n)"

///|
/// `Array.from( typedArray )` printed as upstream_g2.mjs prints it.
extern "js" fn g2_js_value(v : @core.JsValue) -> String = "(v) => ArrayBuffer.isView(v) ? '[' + Array.from(v).map(String).join(',') + ']' : (v !== null && typeof v === 'object' && 'count' in v && 'item_size' in v) ? 'attribute:' + v.count : 'object'"

///|
fn g2_numbers(a : Array[Double]) -> String {
  "[" + a.map(g2_number).join(",") + "]"
}

///|
/// `valueString( v )` of upstream_g2.mjs.
fn g2_value_string(v : @nodes.TslValue) -> String {
  match v {
    Undefined => "undefined"
    Null => "null"
    Number(x) => g2_number(x)
    Bool(b) => b.to_string()
    Texture(t) => "texture:" + t.name
    Color(c) => g2_numbers([c.r, c.g, c.b])
    Matrix2(m) => g2_numbers(m.elements)
    Matrix3(m) => g2_numbers(m.elements)
    Matrix4(m) => g2_numbers(m.elements)
    Vector2(p) => g2_numbers([p.x, p.y])
    Vector3(p) => g2_numbers([p.x, p.y, p.z])
    Vector4(p) => g2_numbers([p.x, p.y, p.z, p.w])
    Js(j) => g2_js_value(j)
    _ => "object"
  }
}

///|
fn g2_fmt(s : String?) -> String {
  match s {
    Some(s) => s
    None => "-"
  }
}

///|
struct G2Builder {
  flip_y : Bool
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn class_name(_) {
  "G2Builder"
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn is_flip_y(self, _) {
  self.flip_y
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn generate_texture(
  _,
  _,
  _,
  p,
  uv,
  depth,
  offset,
  _,
) {
  "tex(\{p}, \{uv}, \{g2_fmt(depth)}, \{g2_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn generate_texture_level(
  _,
  _,
  _,
  p,
  uv,
  level,
  depth,
  offset,
) {
  "texLevel(\{p}, \{uv}, \{level}, \{g2_fmt(depth)}, \{g2_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn generate_texture_bias(
  _,
  _,
  _,
  p,
  uv,
  bias,
  depth,
  offset,
  _,
) {
  "texBias(\{p}, \{uv}, \{bias}, \{g2_fmt(depth)}, \{g2_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn generate_texture_grad(
  _,
  _,
  _,
  p,
  uv,
  grad,
  depth,
  offset,
  _,
) {
  let g = "[" + grad.join(",") + "]"
  "texGrad(\{p}, \{uv}, \{g}, \{g2_fmt(depth)}, \{g2_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn generate_texture_compare(
  _,
  _,
  _,
  p,
  uv,
  compare,
  depth,
  offset,
  _,
) {
  "texCompare(\{p}, \{uv}, \{compare}, \{g2_fmt(depth)}, \{g2_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn generate_texture_gather(
  _,
  _,
  _,
  p,
  uv,
  gather,
  depth,
  offset,
  flip_y,
) {
  "texGather(\{p}, \{uv}, \{g2_fmt(gather)}, \{g2_fmt(depth)}, \{g2_fmt(offset)}, \{g2_fmt(flip_y)})"
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn generate_texture_gather_compare(
  _,
  _,
  _,
  p,
  uv,
  compare,
  depth,
  offset,
  flip_y,
) {
  "texGatherCompare(\{p}, \{uv}, \{compare}, \{g2_fmt(depth)}, \{g2_fmt(offset)}, \{g2_fmt(flip_y)})"
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn generate_texture_load(
  _,
  _,
  _,
  p,
  uv,
  level,
  depth,
  offset,
) {
  "texLoad(\{p}, \{uv}, \{g2_fmt(level)}, \{g2_fmt(depth)}, \{g2_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn generate_storage_texture_load(
  _,
  _,
  _,
  p,
  uv,
  level,
  depth,
  offset,
) {
  "storageLoad(\{p}, \{uv}, \{g2_fmt(level)}, \{g2_fmt(depth)}, \{g2_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn generate_texture_store(
  _,
  _,
  _,
  p,
  uv,
  depth,
  value,
) {
  "store(\{p}, \{uv}, \{g2_fmt(depth)}, \{value})"
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn generate_texture_size(
  _,
  _,
  _,
  p,
  level,
) {
  "size(\{p}, \{level})"
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn get_clip_distance(_, _) {
  "clipDistances"
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn enable_hardware_clipping(
  _,
  _,
  _,
) {

}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn get_draw_index(_, _) {
  None
}

///|
impl @nodes.NodeBuilderClass for G2Builder with fn is_available(_, _, name) {
  name == "storageBuffer"
}

///|
/// The backend of the G2 renderer: the WebGPU stub, with a uniform buffer limit.
struct G2Backend {
  limit : Int32
}

///|
impl @nodes.BackendClass for G2Backend with fn class_name(_) {
  "WebGPUBackend"
}

///|
impl @nodes.BackendClass for G2Backend with fn has_flag(_, flag) {
  flag == "isWebGPUBackend"
}

///|
impl @nodes.BackendClass for G2Backend with fn coordinate_system(_, _) {
  @core.WebGPUCoordinateSystem
}

///|
impl @nodes.BackendClass for G2Backend with fn get_uniform_buffer_limit(self, _) {
  self.limit
}

///|
fn g2_attribute(n : Int32, item_size : Int32) -> @core.GeometryAttribute {
  Buffer(
    @core.BufferAttribute::new(
      @core.TypedArray::float32(n * item_size),
      item_size,
    ),
  )
}

///|
/// The scenario geometry: 24 vertices with position, normal, uv, uv1, tangent, color.
let g2_geometry : @core.BufferGeometry = {
  let g = @core.BufferGeometry::new()
  g.set_attribute("position", g2_attribute(24, 3)) |> ignore
  g.set_attribute("normal", g2_attribute(24, 3)) |> ignore
  g.set_attribute("uv", g2_attribute(24, 2)) |> ignore
  g.set_attribute("uv1", g2_attribute(24, 2)) |> ignore
  g.set_attribute("tangent", g2_attribute(24, 4)) |> ignore
  g.set_attribute("color", g2_attribute(24, 4)) |> ignore
  g
}

///|
/// `record` of upstream_g2.mjs.
fn g2_record(
  b : @nodes.NodeBuilder,
  flow : @nodes.FlowData,
  values~ : Array[String] = [],
) -> String {
  let uniforms = []
  for stage in ["vertex", "fragment", "compute"] {
    for u in b.uniforms.stage(stage) {
      uniforms.push("\{stage}:\{u.name}:\{u.type_}")
    }
  }
  let varyings = b.varyings.map(fn(v) { "\{v.name}:\{v.type_}" })
  let attributes = b.attributes.map(fn(a) { "\{a.name}:\{a.type_}" })
  for a in b.buffer_attributes {
    attributes.push("buffer:\{a.name}:\{a.type_}")
  }
  g2_shader_json(
    flow.code,
    flow.result_snippet(),
    flow.vars.unwrap_or(""),
    uniforms,
    varyings,
    attributes,
    values,
  )
}

///|
/// One scenario: its node, the shader stage and whether `isFlipY()` holds.
struct G2Scenario {
  name : String
  make : () -> @nodes.Node
  stage : String
  flip_y : Bool
  /// Puts the node material callbacks in the context (`materialContext`).
  ctx : Bool
  material : (@core.Material) -> Unit
  object : (@core.Object3D) -> @core.Object3D
  /// Builds the node from the builder's object (`make( object )`).
  make_with : ((@core.Object3D) -> @nodes.Node)?
  /// `getUniformBufferLimit()`.
  limit : Int32
  /// Sets `builder.clippingContext`.
  clipping : Bool
  /// `builder.camera` (a perspective camera by default).
  camera : (() -> @core.Object3D)?
  /// A MeshPhysicalMaterial instead of a MeshBasicMaterial.
  physical : Bool
  /// `renderer._mrt` with velocity, so `needsPreviousData()` holds.
  velocity : Bool
  /// Records the uniform values after one update.
  update : Bool
}

///|
fn g2(name : String, make : () -> @nodes.Node) -> G2Scenario {
  {
    name,
    make,
    stage: "fragment",
    flip_y: false,
    ctx: false,
    material: fn(_) {  },
    object: fn(o) { o },
    make_with: None,
    limit: 65536,
    clipping: false,
    camera: None,
    physical: false,
    velocity: false,
    update: true,
  }
}

///|
fn g2_vertex(name : String, make : () -> @nodes.Node) -> G2Scenario {
  { ..g2(name, make), stage: "vertex", }
}

///|
fn g2_ctx(name : String, make : () -> @nodes.Node) -> G2Scenario {
  { ..g2(name, make), ctx: true, }
}

///|
fn g2_setup(f : () -> @nodes.Node) -> @core.JsValue {
  @core.JsValue::of(@nodes.ContextSetup::{ f, })
}

///|
/// `materialContext( builder )` of upstream_g2.mjs.
fn g2_material_context(b : @nodes.NodeBuilder) -> Unit {
  b.context.set(
    "setupPositionView",
    Other(
      g2_setup(fn() {
        @nodes.model_view_matrix.mul(@nodes.position_local).xyz()
      }),
    ),
  )
  b.context.set(
    "setupModelViewProjection",
    Other(
      g2_setup(fn() {
        @nodes.camera_projection_matrix.mul(@nodes.position_view)
      }),
    ),
  )
  b.context.set(
    "setupNormal",
    Other(
      g2_setup(fn() {
        @nodes.sub_build(@nodes.normal_view_geometry, "NORMAL", type_="vec3")
      }),
    ),
  )
  b.context.set(
    "setupClearcoatNormal",
    Other(
      g2_setup(fn() {
        @nodes.sub_build(@nodes.normal_view_geometry, "NORMAL", type_="vec3")
      }),
    ),
  )
  b.context.set("clipSpace", Node(@nodes.vec4_of([1, 2, 3, 1])))
}

///|
fn g2_tex() -> @core.Texture {
  let t = @core.Texture::new()
  t.name = "tex"
  t.offset.set(0.25, 0.5) |> ignore
  t
}

///|
let g2_scene : @core.Object3D = @core.Scene::new()

///|
fn g2_texture_scenarios() -> Array[G2Scenario] {
  [
    g2("g2_texture_sample", fn() { @nodes.texture(g2_tex()) }),
    g2("g2_texture_uv", fn() {
      @nodes.texture(g2_tex(), uv_node=@nodes.uv(index=1))
    }),
    g2("g2_texture_uv_vec", fn() {
      @nodes.texture(g2_tex(), uv_node=@nodes.vec2_of([0.25, 0.75]))
    }),
    g2("g2_texture_level", fn() {
      @nodes.texture(g2_tex(), uv_node=@nodes.vec2(0.5)).level(2)
    }),
    g2("g2_texture_level_fn", fn() {
      @nodes.texture_level(g2_tex(), @nodes.vec2(0.5), @nodes.float(3).to_var())
    }),
    g2("g2_texture_bias", fn() {
      @nodes.texture(g2_tex(), uv_node=@nodes.vec2(0.5)).bias(0.5)
    }),
    g2("g2_texture_grad", fn() {
      @nodes.texture(g2_tex(), uv_node=@nodes.vec2(0.5)).grad(
        @nodes.vec2(0.1),
        @nodes.vec2(0.2),
      )
    }),
    g2("g2_texture_offset", fn() {
      @nodes.texture(g2_tex(), uv_node=@nodes.vec2(0.5)).offset(
        @nodes.ivec2_of([1, 2]),
      )
    }),
    g2("g2_texture_depth", fn() {
      @nodes.texture(g2_tex(), uv_node=@nodes.vec2(0.5)).depth(3)
    }),
    g2("g2_texture_gather", fn() {
      @nodes.texture(g2_tex(), uv_node=@nodes.vec2(0.5)).gather()
    }),
    g2("g2_texture_gather_channel", fn() {
      @nodes.texture(g2_tex(), uv_node=@nodes.vec2(0.5)).gather(gather_node=2)
    }),
    g2("g2_texture_load", fn() {
      @nodes.texture_load(g2_tex(), uv_node=@nodes.ivec2_of([1, 2]))
    }),
    g2("g2_texture_load_level", fn() {
      @nodes.texture_load(
        g2_tex(),
        uv_node=@nodes.ivec2_of([1, 2]),
        level_node=1,
      )
    }),
    g2("g2_texture_chain_load", fn() {
      @nodes.texture(g2_tex()).load(@nodes.ivec2_of([3, 4]))
    }),
    g2("g2_texture_size", fn() { @nodes.texture_size(@nodes.texture(g2_tex())) }),
    g2("g2_texture_size_level", fn() {
      @nodes.texture(g2_tex()).size(level_node=2)
    }),
    g2("g2_texture_shared", fn() {
      let t = @nodes.texture(g2_tex())
      @nodes.vec2_of([
        t.sample(@nodes.vec2(0.1)).x(),
        t.sample(@nodes.vec2(0.2)).y(),
      ])
    }),
    g2("g2_texture_matrix", fn() {
      let t = g2_tex()
      t.matrix_auto_update = false
      @nodes.texture(t).rgb()
    }),
    g2("g2_texture_uniform", fn() {
      let t = g2_tex()
      @nodes.vec2_of([
        @nodes.uniform_texture(value=t).r(),
        @nodes.uniform_texture(value=t).g(),
      ])
    }),
    g2("g2_texture_mergeable", fn() {
      let t = g2_tex()
      @nodes.vec2_of([@nodes.texture(t).r(), @nodes.texture(t).g()])
    }),
    g2("g2_texture_of_node", fn() {
      @nodes.texture(@nodes.texture(g2_tex()), uv_node=@nodes.vec2(0.3))
    }),
    g2("g2_texture_array", fn() {
      @nodes.texture(@core.DataArrayTexture::new(), uv_node=@nodes.vec2(0.5))
    }),
    g2("g2_texture_depth_texture", fn() {
      @nodes.texture(
        @core.DepthTexture::new(width=4, height=4),
        uv_node=@nodes.vec2(0.5),
      )
    }),
    g2("g2_texture_int", fn() {
      let t = g2_tex()
      t.type_ = @core.IntType
      @nodes.texture(t, uv_node=@nodes.vec2(0.5))
    }),
    g2("g2_texture_uint_red", fn() {
      let t = g2_tex()
      t.type_ = @core.UnsignedIntType
      t.format = @core.RedIntegerFormat
      @nodes.texture(t, uv_node=@nodes.vec2(0.5))
    }),
    {
      ..g2("g2_texture_flip_y", fn() {
        @nodes.texture(g2_tex(), uv_node=@nodes.vec2(0.5))
      }),
      flip_y: true,
    },
    {
      ..g2("g2_texture_flip_y_load", fn() {
        @nodes.texture_load(g2_tex(), uv_node=@nodes.ivec2_of([1, 2]))
      }),
      flip_y: true,
    },
    g2("g2_texture_property", fn() {
      @nodes.texture(g2_tex()).convert("property")
    }),
    g2("g2_texture_sampler", fn() { @nodes.sampler(g2_tex()) }),
    g2("g2_texture_cube", fn() {
      @nodes.cube_texture(
        @core.CubeTexture::new(),
        uv_node=@nodes.vec3_of([0, 1, 0]),
      )
    }),
    g2("g2_texture_cube_level", fn() {
      @nodes.cube_texture(
        @core.CubeTexture::new(),
        uv_node=@nodes.vec3_of([0, 1, 0]),
        level_node=2,
      )
    }),
    g2("g2_texture_3d", fn() {
      @nodes.texture3d(
        @core.Data3DTexture::new(),
        uv_node=@nodes.vec3_of([0.1, 0.2, 0.3]),
      )
    }),
    g2("g2_texture_3d_default", fn() {
      @nodes.texture3d(@core.Data3DTexture::new())
    }),
    g2("g2_texture_3d_load", fn() {
      @nodes.texture3d_load(
        @core.Data3DTexture::new(),
        uv_node=@nodes.ivec3_of([1, 2, 3]),
      )
    }),
    g2("g2_texture_3d_offset", fn() {
      @nodes.texture3d(@core.Data3DTexture::new(), uv_node=@nodes.vec3(0.5)).offset(
        @nodes.ivec3_of([1, 0, 1]),
      )
    }),
    g2("g2_storage_texture_load", fn() {
      @nodes.storage_texture(
        @nodes.StorageTexture::new(width=4, height=4),
        uv_node=@nodes.uvec2_of([1, 2]),
      )
    }),
    g2("g2_storage_texture_store", fn() {
      @nodes.texture_store(
        @nodes.StorageTexture::new(width=4, height=4),
        @nodes.uvec2_of([1, 2]),
        @nodes.vec4_of([1, 0, 0, 1]),
      )
    }),
  ]
}

///|
fn g2_accessor_scenarios() -> Array[G2Scenario] {
  [
    // Builtins and plain attributes.
    g2("g2_builtin", fn() { @nodes.builtin("gl_FragCoord") }),
    g2("g2_point_uv", fn() { @nodes.point_uv }),
    g2("g2_uv0", fn() { @nodes.uv() }),
    g2("g2_vertex_color", fn() { @nodes.vertex_color() }),
    g2("g2_vertex_color_missing", fn() { @nodes.vertex_color(index=2) }),
    g2("g2_position_geometry", fn() { @nodes.position_geometry }),
    g2("g2_position_local", fn() { @nodes.position_local }),
    g2_vertex("g2_position_local_vertex", fn() { @nodes.position_local }),
    g2("g2_normal_geometry", fn() { @nodes.normal_geometry }),
    g2("g2_tangent_geometry", fn() { @nodes.tangent_geometry }),
    // Camera.
    g2("g2_camera_near_far", fn() {
      @nodes.vec2_of([@nodes.camera_near, @nodes.camera_far])
    }),
    g2("g2_camera_position", fn() { @nodes.camera_position }),
    g2("g2_camera_matrices", fn() {
      @nodes.camera_projection_matrix
      .mul(@nodes.camera_view_matrix)
      .mul(@nodes.camera_world_matrix)
      .mul(@nodes.camera_projection_matrix_inverse)
    }),
    g2("g2_camera_normal_matrix", fn() { @nodes.camera_normal_matrix }),
    g2("g2_camera_index", fn() { @nodes.camera_index }),
    // ScreenNode's update reads the renderer's drawing buffer size (G6).
    g2("g2_camera_viewport", fn() { @nodes.camera_viewport }),
    // Model and object.
    g2("g2_model_world_matrix", fn() { @nodes.model_world_matrix }),
    g2("g2_model_vectors", fn() {
      @nodes.model_position
      .add(@nodes.model_scale)
      .add(@nodes.model_direction)
      .add(@nodes.model_view_position)
      .mul(@nodes.model_radius)
    }),
    g2("g2_model_normal_matrix", fn() { @nodes.model_normal_matrix }),
    g2("g2_model_world_matrix_inverse", fn() {
      @nodes.model_world_matrix_inverse
    }),
    g2("g2_model_view_matrix", fn() { @nodes.model_view_matrix }),
    g2_vertex("g2_model_view_matrix_vertex", fn() { @nodes.model_view_matrix }),
    g2("g2_highp_model_view_matrix", fn() {
      @nodes.highp_model_view_matrix.mul(@nodes.highp_model_normal_view_matrix)
    }),
    g2("g2_mediump_model_view_matrix", fn() { @nodes.mediump_model_view_matrix }),
    g2("g2_object_nodes", fn() {
      let o = @core.Object3D::new()
      @nodes.object_position(o)
      .add(@nodes.object_scale(o))
      .add(@nodes.object_direction(o))
      .add(@nodes.object_view_position(o))
      .mul(@nodes.object_radius(o))
    }),
    g2("g2_object_world_matrix", fn() {
      @nodes.object_world_matrix(@core.Object3D::new())
    }),
    // Position, normal, tangent, bitangent.
    g2("g2_position_world", fn() { @nodes.position_world }),
    g2_vertex("g2_position_world_vertex", fn() { @nodes.position_world }),
    g2("g2_position_world_direction", fn() { @nodes.position_world_direction }),
    g2_ctx("g2_position_view", fn() { @nodes.position_view }),
    {
      ..g2_ctx("g2_position_view_vertex", fn() { @nodes.position_view }),
      stage: "vertex",
    },
    g2_ctx("g2_position_view_direction", fn() { @nodes.position_view_direction }),
    {
      ..g2_ctx("g2_model_view_projection", fn() { @nodes.model_view_projection }),
      stage: "vertex",
    },
    g2_ctx("g2_clip_space", fn() { @nodes.clip_space }),
    {
      ..g2_ctx("g2_clip_space_vertex", fn() { @nodes.clip_space }),
      stage: "vertex",
    },
    g2("g2_normal_local", fn() { @nodes.normal_local }),
    g2_ctx("g2_normal_flat", fn() { @nodes.normal_flat }),
    g2("g2_normal_view_geometry", fn() { @nodes.normal_view_geometry }),
    g2("g2_normal_world_geometry", fn() { @nodes.normal_world_geometry }),
    g2_ctx("g2_normal_view", fn() { @nodes.normal_view }),
    g2_ctx("g2_normal_world", fn() { @nodes.normal_world }),
    g2_ctx("g2_clearcoat_normal_view", fn() { @nodes.clearcoat_normal_view }),
    g2("g2_transform_normal", fn() {
      @nodes.transform_normal.call([@nodes.normal_local])
    }),
    g2("g2_transform_normal_chain", fn() {
      @nodes.normal_local.transform_normal(
        matrix=@nodes.model_world_matrix_inverse,
      )
    }),
    g2("g2_transform_normal_to_view", fn() {
      @nodes.transform_normal_to_view.call([@nodes.normal_local])
    }),
    g2("g2_tangent_local", fn() { @nodes.tangent_local }),
    g2_ctx("g2_tangent_view", fn() { @nodes.tangent_view }),
    g2_ctx("g2_tangent_world", fn() { @nodes.tangent_world }),
    g2("g2_bitangent_geometry", fn() { @nodes.bitangent_geometry }),
    g2("g2_bitangent_local", fn() { @nodes.bitangent_local }),
    g2_ctx("g2_bitangent_view", fn() { @nodes.bitangent_view }),
    g2_ctx("g2_bitangent_world", fn() { @nodes.bitangent_world }),
    g2_ctx("g2_tbn_view_matrix", fn() { @nodes.tbn_view_matrix }),
    g2_ctx("g2_parallax_uv", fn() { @nodes.parallax_uv(@nodes.uv(), 0.1) }),
    g2_ctx("g2_bent_normal_view", fn() { @nodes.bent_normal_view }),
    g2_ctx("g2_reflect_vector", fn() { @nodes.reflect_vector }),
    g2_ctx("g2_refract_vector", fn() { @nodes.refract_vector }),
    g2_ctx("g2_texture_cube_default", fn() {
      @nodes.cube_texture(@core.CubeTexture::new())
    }),
    // Material, scene and light uniforms.
    g2("g2_material_properties", fn() {
      @nodes.vec3_of([
        @nodes.material_refraction_ratio, @nodes.material_env_intensity, 0,
      ]).add(@nodes.material_env_rotation[0].xyz())
    }),
    g2("g2_scene_properties", fn() {
      @nodes.vec2_of([@nodes.background_blurriness, @nodes.background_intensity]).add(
        @nodes.background_rotation[1].xy(),
      )
    }),
    g2("g2_material_color", fn() { @nodes.material_color }),
    {
      ..g2("g2_material_color_map", fn() { @nodes.material_color }),
      material: fn(m) { m.map = Some(g2_tex()) },
    },
    g2("g2_material_opacity", fn() { @nodes.material_opacity }),
    {
      ..g2("g2_material_alpha_map", fn() { @nodes.material_opacity }),
      material: fn(m) { m.alpha_map = Some(g2_tex()) },
    },
    g2("g2_material_specular_strength", fn() {
      @nodes.material_specular_strength
    }),
    g2("g2_material_reflectivity", fn() { @nodes.material_reflectivity }),
    {
      ..g2("g2_material_ao", fn() { @nodes.material_ao }),
      material: fn(m) { m.ao_map = Some(g2_tex()) },
    },
    {
      ..g2("g2_material_light_map", fn() { @nodes.material_light_map }),
      material: fn(m) { m.light_map = Some(g2_tex()) },
    },
    g2("g2_material_line_dash_offset", fn() { @nodes.material_line_dash_offset }),
    g2("g2_material_rotation", fn() { @nodes.material_rotation }),
    g2("g2_material_reference", fn() {
      @nodes.material_reference("opacity", "float")
    }),
    g2("g2_material_reference_color", fn() {
      @nodes.material_reference("color", "color")
    }),
    g2("g2_reference_object", fn() {
      @nodes.reference(
        "position",
        "vec3",
        object=Object3D(@core.Object3D::new()),
      )
    }),
    g2("g2_reference_material", fn() {
      let m = @core.MeshBasicMaterial::new()
      @nodes.reference("opacity", "float", object=Material(m))
    }),
    {
      ..g2("g2_user_data", fn() { @nodes.user_data("speed", "float") }),
      object: fn(mesh) {
        g2_set_user_data(mesh.user_data, "speed", 2.0)
        mesh
      },
    },
    g2("g2_light_position", fn() {
      let light = @core.PointLight::new()
      @nodes.light_position(light).add(@nodes.light_view_position(light))
    }),
    g2("g2_light_target", fn() {
      let light = @core.DirectionalLight::new()
      @nodes.light_target_direction(light).add(
        @nodes.light_target_position(light),
      )
    }),
    g2("g2_light_projection_uv", fn() {
      @nodes.light_projection_uv(@core.SpotLight::new())
    }),
    // Buffers and arrays.
    g2("g2_uniform_array_float", fn() {
      @nodes.uniform_array([1, 2, 3]).element(@nodes.int(1))
    }),
    g2("g2_uniform_array_vec3", fn() {
      @nodes.uniform_array([
        @math.Vector3::new(0.0, 0.0, 0.0),
        @math.Vector3::new(1.0, 2.0, 3.0),
      ]).element(@nodes.instance_index)
    }),
    g2("g2_uniform_array_color", fn() {
      @nodes.uniform_array([@math.Color::new(1.0, 0.0, 0.0)]).element(0)
    }),
    g2("g2_uniform_array_mat3", fn() {
      @nodes.uniform_array([@math.Matrix3::new()], element_type="mat3").element(
        0,
      )
    }),
    g2("g2_uniform_array_int", fn() {
      @nodes.uniform_array([1, 2], element_type="int").element(1)
    }),
    g2("g2_buffer_mat4", fn() {
      @nodes.buffer(@core.TypedArray::float32(32), "mat4", 2).element(
        @nodes.instance_index,
      )
    }),
    g2("g2_buffer_attribute", fn() {
      @nodes.buffer_attribute(@core.TypedArray::float32(72), type_="vec3")
    }),
    g2_vertex("g2_buffer_attribute_vertex", fn() {
      @nodes.buffer_attribute(@core.TypedArray::float32(72), type_="vec3")
    }),
    g2_vertex("g2_instanced_buffer_attribute", fn() {
      @nodes.instanced_buffer_attribute(
        @core.InstancedBufferAttribute::new(@core.TypedArray::float32(12), 4),
      )
    }),
    g2_vertex("g2_buffer_attribute_mat4", fn() {
      @nodes.instanced_dynamic_buffer_attribute(
        @core.InstancedBufferAttribute::new(@core.TypedArray::float32(48), 16),
      )
    }),
    g2("g2_reference_buffer", fn() {
      @nodes.reference_buffer(
        "morphTargetInfluences",
        "float",
        2,
        object=Object3D(@core.Mesh::new()),
      ).element(1)
    }),
    g2_vertex("g2_velocity", fn() { @nodes.velocity }),
    g2("g2_texture_bicubic", fn() {
      @nodes.texture_bicubic.call([
        @nodes.texture(g2_tex(), uv_node=@nodes.vec2(0.5)),
        0.5,
      ])
    }),
  ]
}

///|
extern "js" fn g2_set_user_data(
  user_data : @core.JsValue,
  key : String,
  value : Double,
) -> Unit = "(u, k, v) => { u[k] = v; }"

///|
fn g2_scenarios() -> Array[G2Scenario] {
  [
    ..g2_texture_scenarios(),
    ..g2_accessor_scenarios(),
    ..g2_object_scenarios(),
    ..g2_more_scenarios(),
    ..g2_storage_scenarios(),
    ..g2_map_scenarios(),
    ..g2_variant_scenarios(),
  ]
}

///|
fn g2_skinned_mesh() -> @core.Object3D {
  let g = @core.BufferGeometry::new()
  g.set_attribute("position", g2_attribute(24, 3)) |> ignore
  g.set_attribute("normal", g2_attribute(24, 3)) |> ignore
  g.set_attribute("tangent", g2_attribute(24, 4)) |> ignore
  g.set_attribute("skinWeight", g2_attribute(24, 4)) |> ignore
  g.set_attribute(
    "skinIndex",
    @core.BufferAttribute::new(@core.TypedArray::uint16(24 * 4), 4),
  )
  |> ignore
  let bones = [@core.Bone::new(), @core.Bone::new()]
  bones[0].add(bones[1]) |> ignore
  let mesh = @core.SkinnedMesh::new(
    geometry=g,
    material=Single(@core.MeshBasicMaterial::new()),
  )
  mesh.add(bones[0]) |> ignore
  mesh.bind(@core.Skeleton::new(bones~))
  mesh
}

///|
fn g2_morph_mesh() -> @core.Object3D {
  let g = @core.BufferGeometry::new()
  g.set_attribute("position", g2_attribute(24, 3)) |> ignore
  g.set_attribute("normal", g2_attribute(24, 3)) |> ignore
  g.morph_attributes.set("position", [g2_attribute(24, 3), g2_attribute(24, 3)])
  g.morph_attributes.set("normal", [g2_attribute(24, 3), g2_attribute(24, 3)])
  @core.Mesh::new(geometry=g, material=Single(@core.MeshBasicMaterial::new()))
}

///|
fn g2_instanced_mesh(colors : Bool) -> @core.Object3D {
  let mesh = @core.InstancedMesh::new(
    geometry=g2_geometry,
    material=Single(@core.MeshBasicMaterial::new()),
    3,
  )
  if colors {
    mesh.set_color_at(0, @math.Color::new(1.0, 0.0, 0.0)) |> ignore
  }
  mesh
}

///|
fn g2_batched_mesh() -> @core.Object3D {
  let mesh = @core.BatchedMesh::new(
    2,
    48,
    max_index_count=72,
    material=Single(@core.MeshBasicMaterial::new()),
  )
  let id = mesh.add_instance(mesh.add_geometry(g2_geometry))
  mesh.set_color_at(id, @math.Color::new(1.0, 0.0, 0.0)) |> ignore
  mesh
}

///|
fn g2_clipping_context() -> @nodes.ClippingContext {
  let c = @nodes.ClippingContext::new()
  c.union_planes = [
    @math.Vector4::new(0.0, 1.0, 0.0, 0.0),
    @math.Vector4::new(1.0, 0.0, 0.0, 2.0),
  ]
  c.intersection_planes = [@math.Vector4::new(0.0, 0.0, 1.0, 1.0)]
  c
}

///|
/// A scenario built from its object, inside a `Fn` as a material setup calls it.
fn g2_with(
  name : String,
  object : () -> @core.Object3D,
  body : (@core.Object3D) -> @nodes.Node,
) -> G2Scenario {
  {
    ..g2(name, fn() { abort("g2_with") }),
    stage: "vertex",
    object: fn(_) { object() },
    make_with: Some(fn(o) { @nodes.fn_(fn(_, _) { Some(body(o)) }).call([]) }),
  }
}

///|
fn g2_object_scenarios() -> Array[G2Scenario] {
  [
    g2_with("g2_skinning", g2_skinned_mesh, fn(o) {
      @nodes.skinning.call([o]) |> ignore
      @nodes.position_local
    }),
    g2_with("g2_skinning_normal", g2_skinned_mesh, fn(o) {
      @nodes.skinning.call([o]) |> ignore
      @nodes.normal_local.add(@nodes.tangent_local)
    }),
    {
      ..g2_with("g2_skinning_texture", g2_skinned_mesh, fn(o) {
        @nodes.skinning.call([o]) |> ignore
        @nodes.position_local
      }),
      limit: 1024,
    },
    g2_with("g2_morph", g2_morph_mesh, fn(o) {
      @nodes.morph_reference.call([o]) |> ignore
      @nodes.position_local.add(@nodes.normal_local)
    }),
    g2_with("g2_instanced_mesh", fn() { g2_instanced_mesh(false) }, fn(o) {
      @nodes.instanced_mesh.call([o]) |> ignore
      @nodes.position_local.add(@nodes.normal_local)
    }),
    g2_with("g2_instanced_mesh_color", fn() { g2_instanced_mesh(true) }, fn(o) {
      @nodes.instanced_mesh.call([o]) |> ignore
      @nodes.vec3(@nodes.instance_color)
    }),
    g2_with("g2_instance", fn() { g2_instanced_mesh(true) }, fn(o) {
      let (matrix, color) = match o.kind {
        Mesh({ kind: InstancedMesh(m), .. }) =>
          (m.instance_matrix, m.instance_color)
        _ => abort("g2_instance")
      }
      @nodes.instance.call([matrix, color]) |> ignore
      @nodes.position_local.add(@nodes.instance_color)
    }),
    {
      ..g2_with("g2_instance_large", fn() { g2_instanced_mesh(false) }, fn(o) {
        let matrix = match o.kind {
          Mesh({ kind: InstancedMesh(m), .. }) => m.instance_matrix
          _ => abort("g2_instance_large")
        }
        @nodes.instance.call([matrix]) |> ignore
        @nodes.position_local
      }),
      limit: 64,
    },
    {
      ..g2_vertex("g2_reference_attribute", fn() {
        @nodes.reference_attribute("instanceColor", type_="vec3")
      }),
      object: fn(_) { g2_instanced_mesh(true) },
    },
    g2_with("g2_batch", g2_batched_mesh, fn(o) {
      @nodes.batch.call([o]) |> ignore
      @nodes.position_local
      .add(@nodes.normal_local)
      .add(@nodes.batch_color.xyz())
    }),
    // Clipping.
    {
      ..g2_ctx("g2_clipping", fn() {
        @nodes.fn_(fn(_, _) {
          @nodes.clipping().to_stack() |> ignore
          Some(@nodes.diffuse_color)
        }).call([])
      }),
      clipping: true,
    },
    {
      ..g2_ctx("g2_clipping_alpha", fn() {
        @nodes.fn_(fn(_, _) {
          @nodes.clipping_alpha().to_stack() |> ignore
          Some(@nodes.diffuse_color)
        }).call([])
      }),
      clipping: true,
    },
    {
      ..g2_ctx("g2_clipping_hardware", fn() {
        @nodes.fn_(fn(_, _) {
          @nodes.hardware_clipping().to_stack() |> ignore
          Some(@nodes.position_local)
        }).call([])
      }),
      clipping: true,
      stage: "vertex",
    },
    // Storage buffers (direct use), lights, more textures.
    g2("g2_attribute_array", fn() { @nodes.attribute_array(4, type_="vec3") }),
    g2("g2_instanced_array", fn() {
      @nodes.instanced_array(4, type_="vec4").to_read_only()
    }),
    g2("g2_storage_buffer", fn() {
      @nodes.storage(
        @nodes.StorageBufferAttribute::new(4, 4),
        type_="vec4",
        count=4,
      )
    }),
    g2("g2_light_shadow_matrix", fn() {
      @nodes.light_shadow_matrix(@core.SpotLight::new())
    }),
    g2_ctx("g2_uniform_cube_texture", fn() { @nodes.uniform_cube_texture() }),
    g2("g2_texture_cube_of_node", fn() {
      @nodes.cube_texture(
        @nodes.cube_texture(
          @core.CubeTexture::new(),
          uv_node=@nodes.vec3_of([1, 0, 0]),
        ),
        uv_node=@nodes.vec3_of([0, 0, 1]),
      )
    }),
    g2("g2_texture_3d_normal", fn() {
      @nodes.texture3d(@core.Data3DTexture::new()).normal(@nodes.vec3(0.5))
    }),
    g2("g2_storage_texture_3d", fn() {
      @nodes.storage_texture3d(
        @nodes.Storage3DTexture::new(width=2, height=2, depth=2),
        uv_node=@nodes.uvec3_of([1, 1, 1]),
      )
    }),
    g2("g2_texture_blur", fn() {
      @nodes.texture(g2_tex(), uv_node=@nodes.vec2(0.5)).blur(0.5)
    }),
    g2("g2_sampler_comparison", fn() { @nodes.sampler_comparison(g2_tex()) }),
    g2("g2_vertex_color1", fn() { @nodes.vertex_color(index=1) }),
    g2_vertex("g2_position_previous", fn() { @nodes.position_previous }),
  ]
}

///|
test "g2 shader scenarios run (compared with upstream by run.mjs)" {
  let renderer = @nodes.Renderer::foundation_stub()
  for scenario in g2_scenarios() {
    let material = if scenario.physical {
      @core.MeshPhysicalMaterial::new()
    } else {
      @core.MeshBasicMaterial::new()
    }
    (scenario.material)(material)
    let mesh = (scenario.object)(
      @core.Mesh::new(geometry=g2_geometry, material=Single(material)),
    )
    mesh.position.set(1.0, 2.0, 3.0) |> ignore
    mesh.scale.set(2.0, 2.0, 2.0) |> ignore
    mesh.update_matrix_world(force=true)
    renderer.backend.class_ = G2Backend::{ limit: scenario.limit, }
    let b = @nodes.NodeBuilder::new(Object3D(mesh), renderer, None, class_=G2Builder::{
      flip_y: scenario.flip_y,
    })
    b.camera = Some(
      match scenario.camera {
        Some(c) => c()
        None => @core.PerspectiveCamera::new()
      },
    )
    b.camera.unwrap().position.set(0.0, 1.0, 5.0) |> ignore
    b.camera.unwrap().update_matrix_world(force=true)
    renderer._mrt = if scenario.velocity { Some(g2_velocity_mrt) } else { None }
    if scenario.ctx {
      g2_material_context(b)
    }
    if scenario.clipping {
      b.clipping_context = Some(g2_clipping_context())
    }
    b.set_shader_stage(Some(scenario.stage))
    let node = match scenario.make_with {
      Some(f) => f(mesh)
      None => (scenario.make)()
    }
    let flow = b.flow_stages_node(node)
    // The uniform values after one update of the build's update nodes.
    if !scenario.update {
      let record = g2_record(b, flow, values=["skipped"])
      if g2_shader_diff_enabled() {
        println("@@SHADER \{scenario.name} \{record}")
      }
      continue
    }
    b.build_update_nodes()
    let frame = @nodes.NodeFrame::new()
    frame.frame_id = 1
    frame.render_id = 1
    frame.renderer = Some(renderer)
    frame.camera = b.camera
    frame.object = Some(mesh)
    frame.material = Some(material)
    frame.scene = Some(g2_scene)
    for node in b.update_nodes {
      frame.update_node(node)
    }
    let values = []
    for stage in ["vertex", "fragment", "compute"] {
      for u in b.uniforms.stage(stage) {
        values.push("\{u.name}=\{g2_value_string(u.value())}")
      }
    }
    let record = g2_record(b, flow, values~)
    if g2_shader_diff_enabled() {
      println("@@SHADER \{scenario.name} \{record}")
    }
  }
}

///|
fn g2_array_camera(multi_view : Bool) -> @core.Object3D {
  let cameras = [@core.PerspectiveCamera::new(), @core.PerspectiveCamera::new()]
  @webgl.set_camera_viewport(
    cameras[0],
    Some(@math.Vector4::new(0.0, 0.0, 1.0, 1.0)),
  )
  @webgl.set_camera_viewport(
    cameras[1],
    Some(@math.Vector4::new(1.0, 0.0, 1.0, 1.0)),
  )
  let camera = @core.ArrayCamera::new(array=cameras)
  match camera.kind {
    Camera({ kind: PerspectiveCamera({ array_camera: Some(a), .. }), .. }) =>
      a.is_multi_view_camera = multi_view
    _ => ()
  }
  camera
}

///|
let g2_velocity_mrt : @nodes.Node = @nodes.mrt({
  "output": @nodes.output,
  "velocity": @nodes.velocity,
})

///|
fn g2_physical(name : String, make : () -> @nodes.Node) -> G2Scenario {
  { ..g2(name, make), physical: true, }
}

///|
fn g2_more_scenarios() -> Array[G2Scenario] {
  [
    // Array, multiview and orthographic cameras.
    {
      ..g2("g2_array_camera", fn() {
        @nodes.camera_projection_matrix
        .mul(@nodes.camera_view_matrix)
        .mul(@nodes.camera_world_matrix)
        .mul(@nodes.camera_projection_matrix_inverse)
        .mul(@nodes.camera_normal_matrix[0].xyzz())
      }),
      camera: Some(fn() { g2_array_camera(false) }),
    },
    {
      ..g2("g2_array_camera_position", fn() {
        @nodes.camera_position.add(@nodes.camera_viewport.xyz())
      }),
      camera: Some(fn() { g2_array_camera(false) }),
    },
    {
      ..g2("g2_array_camera_highp", fn() {
        @nodes.highp_model_view_matrix.mul(
          @nodes.highp_model_normal_view_matrix[0].xyzz(),
        )
      }),
      camera: Some(fn() { g2_array_camera(false) }),
    },
    {
      ..g2("g2_multiview_camera", fn() {
        @nodes.camera_view_matrix.mul(@nodes.highp_model_view_matrix)
      }),
      camera: Some(fn() { g2_array_camera(true) }),
    },
    {
      ..g2("g2_array_camera_light", fn() {
        @nodes.light_view_position(@core.PointLight::new())
      }),
      camera: Some(fn() { g2_array_camera(false) }),
    },
    {
      ..g2_ctx("g2_ortho_view_direction", fn() {
        @nodes.position_view_direction
      }),
      camera: Some(fn() { @core.OrthographicCamera::new() }),
    },
    // More material properties (a physical material).
    g2_physical("g2_material_physical", fn() {
      @nodes.vec4_of([
        @nodes.material_roughness, @nodes.material_metalness, @nodes.material_clearcoat,
        @nodes.material_clearcoat_roughness,
      ]).add(
        @nodes.vec4_of([
          @nodes.material_sheen_roughness, @nodes.material_iridescence_thickness,
          @nodes.material_transmission, @nodes.material_thickness,
        ]),
      )
    }),
    g2_physical("g2_material_physical_colors", fn() {
      @nodes.material_emissive
      .add(@nodes.material_sheen)
      .add(@nodes.material_specular_color)
      .add(@nodes.material_attenuation_color)
    }),
    g2_physical("g2_material_physical_floats", fn() {
      @nodes.vec4_of([
        @nodes.material_specular_intensity, @nodes.material_ior, @nodes.material_attenuation_distance,
        @nodes.material_dispersion,
      ]).add(
        @nodes.vec4_of([
          @nodes.material_iridescence,
          @nodes.material_iridescence_ior,
          @nodes.material_anisotropy.x(),
          @nodes.material_diffuse_roughness,
        ]),
      )
    }),
    {
      ..g2_physical("g2_material_physical_maps", fn() {
        @nodes.vec4_of([
          @nodes.material_roughness, @nodes.material_metalness, @nodes.material_clearcoat,
          @nodes.material_clearcoat_roughness,
        ])
        .add(
          @nodes.vec4_of([
            @nodes.material_sheen_roughness, @nodes.material_iridescence_thickness,
            @nodes.material_transmission, @nodes.material_thickness,
          ]),
        )
        .add(
          @nodes.vec4_of([
            @nodes.material_emissive, @nodes.material_specular_intensity,
          ]),
        )
        .add(
          @nodes.vec4_of([
            @nodes.material_sheen.add(@nodes.material_specular_color),
            1,
          ]),
        )
        .add(@nodes.vec4_of([@nodes.material_anisotropy, 0, 0]))
      }),
      material: fn(m) {
        m.roughness_map = Some(g2_tex())
        m.metalness_map = Some(g2_tex())
        m.emissive_map = Some(g2_tex())
        m.clearcoat_map = Some(g2_tex())
        m.sheen_roughness_map = Some(g2_tex())
        m.anisotropy_map = Some(g2_tex())
        m.iridescence_thickness_map = Some(g2_tex())
        m.transmission_map = Some(g2_tex())
        m.thickness_map = Some(g2_tex())
        m.specular_intensity_map = Some(g2_tex())
        m.specular_color_map = Some(g2_tex())
        m.sheen_color_map = Some(g2_tex())
        m.clearcoat_roughness_map = Some(g2_tex())
      },
    },
    g2("g2_material_shininess", fn() {
      @nodes.vec2_of([@nodes.material_shininess, @nodes.material_point_size])
      .add(
        @nodes.vec2_of([@nodes.material_line_width, @nodes.material_line_scale]),
      )
      .add(
        @nodes.vec2_of([
          @nodes.material_line_dash_size, @nodes.material_line_gap_size,
        ]),
      )
      .add(@nodes.material_alpha_test)
    }),
    g2("g2_material_specular", fn() { @nodes.material_specular }),
    // References.
    g2("g2_renderer_reference", fn() {
      @nodes.renderer_reference("toneMappingExposure", "float")
    }),
    g2("g2_reference_shadow", fn() {
      let light = @core.SpotLight::new()
      let shadow = match light.kind {
        Light({ shadow: Some(s), .. }) => s
        _ => abort("g2_reference_shadow")
      }
      @nodes.vec4_of([
        @nodes.reference("bias", "float", object=Shadow(shadow)),
        @nodes.reference("mapSize", "vec2", object=Shadow(shadow)),
        @nodes.reference("near", "float", object=Object3D(shadow.camera)),
      ])
    }),
    g2("g2_reference_fog", fn() {
      @nodes.reference(
        "color",
        "color",
        object=Fog(
          Fog(
            @core.Fog::new(
              color=@math.Color::from_hex(0xff0000),
              near=1.0,
              far=2.0,
            ),
          ),
        ),
      ).add(
        @nodes.reference(
          "density",
          "float",
          object=Fog(
            FogExp2(@core.FogExp2::new(color=@math.Color::from_hex(0x00ff00))),
          ),
        ),
      )
    }),
    g2("g2_reference_element", fn() {
      @nodes.reference(
        "morphTargetInfluences",
        "float",
        object=Object3D(@core.Mesh::new()),
      ).element(0)
    }),
    g2("g2_reference_name", fn() {
      @nodes.material_reference("opacity", "float").set_name("myOpacity")
    }),
    g2("g2_reference_texture", fn() {
      let m = @core.MeshBasicMaterial::new()
      m.map = Some(g2_tex())
      @nodes.material_reference("map", "texture", material=m)
    }),
    // More textures.
    g2("g2_texture_channel", fn() {
      let t = g2_tex()
      t.channel = 1
      @nodes.texture(t)
    }),
    g2_ctx("g2_texture_refraction", fn() {
      @nodes.cube_texture(
        @core.CubeTexture::new(mapping=@core.CubeRefractionMapping),
      )
    }),
    g2("g2_texture_array_load", fn() {
      @nodes.texture_load(
        @core.DataArrayTexture::new(),
        uv_node=@nodes.ivec2_of([1, 1]),
      ).depth(2)
    }),
    g2("g2_texture_3d_level", fn() {
      @nodes.texture3d_level(@core.Data3DTexture::new(), @nodes.vec3(0.5), 1)
    }),
    g2("g2_storage_texture_rw", fn() {
      @nodes.storage_texture(
        @nodes.StorageTexture::new(width=4, height=4),
        uv_node=@nodes.uvec2_of([1, 2]),
      ).to_read_write()
    }),
    g2("g2_storage_texture_store_node", fn() {
      @nodes.texture_store(
        @nodes.storage_texture(@nodes.StorageTexture::new(width=4, height=4)),
        @nodes.uvec2_of([3, 4]),
        @nodes.vec4_of([0, 1, 0, 1]),
      )
    }),
    g2("g2_storage_texture_store_3d", fn() {
      @nodes.texture_store(
        @nodes.storage_texture3d(
          @nodes.Storage3DTexture::new(width=2, height=2, depth=2),
        ),
        @nodes.uvec3_of([1, 1, 1]),
        @nodes.vec4_of([0, 0, 1, 1]),
      )
    }),
    // Previous-frame data (an MRT with velocity).
    {
      ..g2_with("g2_skinning_previous", g2_skinned_mesh, fn(o) {
        @nodes.skinning.call([o]) |> ignore
        @nodes.position_local.add(@nodes.position_previous)
      }),
      velocity: true,
    },
    {
      ..g2_with("g2_instance_previous", fn() { g2_instanced_mesh(false) }, fn(
        o,
      ) {
        @nodes.instanced_mesh.call([o]) |> ignore
        @nodes.position_local.add(@nodes.position_previous)
      }),
      velocity: true,
    },
    {
      ..g2_with("g2_batch_previous", g2_batched_mesh, fn(o) {
        @nodes.batch.call([o]) |> ignore
        @nodes.position_local.add(@nodes.position_previous)
      }),
      velocity: true,
    },
  ]
}

///|
fn g2_storage_instanced_mesh() -> @core.Object3D {
  let mesh = g2_instanced_mesh(false)
  match mesh.kind {
    Mesh({ kind: InstancedMesh(m), .. }) =>
      m.instance_matrix = @nodes.StorageInstancedBufferAttribute::from_array(
        @core.TypedArray::float32(48),
        16,
      )
    _ => ()
  }
  mesh
}

///|
fn g2_storage_scenarios() -> Array[G2Scenario] {
  [
    // Storage buffer elements.
    g2("g2_storage_element", fn() {
      @nodes.storage(
        @nodes.StorageBufferAttribute::new(4, 4),
        type_="vec4",
        count=4,
      ).element(@nodes.instance_index)
    }),
    g2("g2_storage_element_read_only", fn() {
      @nodes.attribute_array(4, type_="vec3")
      .to_read_only()
      .element(@nodes.int(2))
    }),
    g2("g2_storage_element_atomic", fn() {
      @nodes.instanced_array(4, type_="uint").to_atomic().element(1)
    }),
    {
      ..g2_vertex("g2_reference_attribute_storage", fn() {
        @nodes.reference_attribute("instanceMatrix", type_="mat4")
      }),
      object: fn(_) { g2_storage_instanced_mesh() },
    },
    {
      ..g2("g2_compute_skinning", fn() { abort("g2_compute_skinning") }),
      stage: "compute",
      object: fn(_) { g2_skinned_mesh() },
      make_with: Some(fn(o) { @nodes.compute_skinning.call([o]) }),
    },
    g2_with("g2_instance_storage", g2_storage_instanced_mesh, fn(o) {
      let matrix = match o.kind {
        Mesh({ kind: InstancedMesh(m), .. }) => m.instance_matrix
        _ => abort("g2_instance_storage")
      }
      @nodes.instance.call([matrix]) |> ignore
      @nodes.position_local
    }),
  ]
}

///|
fn g2_map_scenarios() -> Array[G2Scenario] {
  [
    // Normal and bump maps.
    g2_ctx("g2_material_normal", fn() { @nodes.material_normal }),
    {
      ..g2_ctx("g2_material_normal_map", fn() { @nodes.material_normal }),
      material: fn(m) { m.normal_map = Some(g2_tex()) },
    },
    {
      ..g2_ctx("g2_material_normal_map_rg", fn() { @nodes.material_normal }),
      physical: true,
      material: fn(m) {
        let t = g2_tex()
        t.format = @core.RGFormat
        m.normal_map = Some(t)
        m.normal_map_type = Some(@core.ObjectSpaceNormalMap)
      },
    },
    {
      ..g2_ctx("g2_material_bump_map", fn() { @nodes.material_normal }),
      material: fn(m) { m.bump_map = Some(g2_tex()) },
    },
    {
      ..g2_ctx("g2_material_clearcoat_normal", fn() {
        @nodes.material_clearcoat_normal
      }),
      physical: true,
      material: fn(m) { m.clearcoat_normal_map = Some(g2_tex()) },
    },
  ]
}

///|
fn g2_geometry_of(attributes : Array[(String, Int32)]) -> @core.BufferGeometry {
  let g = @core.BufferGeometry::new()
  for a in attributes {
    g.set_attribute(a.0, g2_attribute(24, a.1)) |> ignore
  }
  g
}

///|
fn g2_set_geometry(mesh : @core.Object3D, g : @core.BufferGeometry) -> Unit {
  match mesh.kind {
    Mesh(m) => m.geometry = g
    _ => ()
  }
}

///|
fn g2_variant_scenarios() -> Array[G2Scenario] {
  [
    // Geometry and material variants: flat shading, no tangent, no normal, morph colors.
    {
      ..g2_ctx("g2_flat_shading", fn() {
        @nodes.normal_view.add(@nodes.tangent_view)
      }),
      material: fn(m) { m.flat_shading = Some(true) },
    },
    {
      ..g2_ctx("g2_no_tangent", fn() {
        @nodes.tangent_view.add(@nodes.bitangent_view)
      }),
      object: fn(mesh) {
        g2_set_geometry(
          mesh,
          g2_geometry_of([("position", 3), ("normal", 3), ("uv", 2)]),
        )
        mesh
      },
    },
    {
      ..g2_ctx("g2_no_normal", fn() {
        @nodes.normal_local.add(@nodes.normal_view)
      }),
      object: fn(mesh) {
        g2_set_geometry(mesh, g2_geometry_of([("position", 3)]))
        mesh
      },
    },
    {
      ..g2_with("g2_morph_color", fn() { abort("object") }, fn(o) {
        @nodes.morph_reference.call([o]) |> ignore
        @nodes.morph_color.call([@nodes.vertex_color()])
      }),
      material: fn(m) { m.vertex_colors = true },
      object: fn(mesh) {
        let g = g2_geometry_of([("position", 3), ("color", 3)])
        g.morph_attributes.set("position", [g2_attribute(24, 3)])
        g.morph_attributes.set("color", [g2_attribute(24, 3)])
        g2_set_geometry(mesh, g)
        mesh.update_morph_targets()
        mesh
      },
    },
    g2("g2_reference_base", fn() {
      let m = @core.MeshBasicMaterial::new()
      @nodes.reference("opacity", "float", object=Material(m))
      .add(0)
      .add(@nodes.renderer_reference("toneMappingExposure", "float"))
    }),
    g2("g2_reference_base_node", fn() {
      @nodes.reference_base(
        "opacity",
        "float",
        object=Material(@core.MeshBasicMaterial::new()),
      )
    }),
    {
      ..g2_ctx("g2_material_reference_cube", fn() {
        @nodes.material_reference("envMap", "cubeTexture")
      }),
      material: fn(m) { m.env_map = Some(@core.CubeTexture::new()) },
    },
    g2_vertex("g2_dynamic_buffer_attribute", fn() {
      @nodes.dynamic_buffer_attribute(
        @core.TypedArray::float32(96),
        type_="vec4",
      )
    }),
    g2_vertex("g2_to_attribute", fn() {
      @nodes.attribute_array(24, type_="vec3").to_attribute()
    }),
  ]
}

// ---- the TextureNode compare paths with `renderer.hasCompatibility( TEXTURE_COMPARE )`
// on and off (added by G6 once `Renderer::has_compatibility` existed)

///|
struct G2CompatBackend {
  compat : Bool
}

///|
impl @nodes.BackendClass for G2CompatBackend with fn class_name(_) {
  "WebGPUBackend"
}

///|
impl @nodes.BackendClass for G2CompatBackend with fn has_flag(_, flag) {
  flag == "isWebGPUBackend"
}

///|
impl @nodes.BackendClass for G2CompatBackend with fn coordinate_system(_, _) {
  @core.WebGPUCoordinateSystem
}

///|
impl @nodes.BackendClass for G2CompatBackend with fn get_uniform_buffer_limit(
  _,
  _,
) {
  65536
}

///|
impl @nodes.BackendClass for G2CompatBackend with fn has_compatibility(
  self,
  _,
  _,
) {
  self.compat
}

///|
fn g2c_depth(f : Int32?) -> @core.Texture {
  let t = @core.DepthTexture::new(width=4, height=4)
  if f is Some(_) {
    t.compare_function = f
  }
  t
}

///|
test "g2 compare scenarios run (compared with upstream by run.mjs)" {
  let renderer = @nodes.Renderer::foundation_stub()
  let scenarios : Array[(String, Bool, () -> @nodes.Node)] = [
    (
      "g2c_compare_native",
      true,
      fn() {
        @nodes.texture(g2c_depth(None), uv_node=@nodes.vec2(0.5)).compare(0.25)
      },
    ),
    (
      "g2c_compare_step_null",
      false,
      fn() {
        @nodes.texture(g2c_depth(None), uv_node=@nodes.vec2(0.5)).compare(0.25)
      },
    ),
    (
      "g2c_compare_step_less",
      false,
      fn() {
        @nodes.texture(
          g2c_depth(Some(@core.LessCompare)),
          uv_node=@nodes.vec2(0.5),
        ).compare(0.25)
      },
    ),
    (
      "g2c_compare_step_greater",
      false,
      fn() {
        @nodes.texture(
          g2c_depth(Some(@core.GreaterEqualCompare)),
          uv_node=@nodes.vec2(0.5),
        ).compare(0.25)
      },
    ),
    (
      "g2c_compare_unsupported",
      false,
      fn() {
        @nodes.texture(
          g2c_depth(Some(@core.NeverCompare)),
          uv_node=@nodes.vec2(0.5),
        ).compare(0.25)
      },
    ),
    (
      "g2c_compare_gather",
      true,
      fn() {
        @nodes.texture(g2c_depth(None), uv_node=@nodes.vec2(0.5))
        .gather()
        .compare(0.25)
      },
    ),
    (
      "g2c_compare_level",
      true,
      fn() {
        @nodes.texture(g2c_depth(None), uv_node=@nodes.vec2(0.5))
        .compare(0.25)
        .level(0)
      },
    ),
  ]
  // `hasCompatibility()` needs an initialized renderer
  renderer._initialized = true
  for s in scenarios {
    let (name, compat, make) = s
    renderer.backend.class_ = G2CompatBackend::{ compat, }
    let mesh = @core.Mesh::new(
      geometry=g2_geometry,
      material=Single(@core.MeshBasicMaterial::new()),
    )
    let b = @nodes.NodeBuilder::new(Object3D(mesh), renderer, None, class_=G2Builder::{
      flip_y: false,
    })
    b.camera = Some(@core.PerspectiveCamera::new())
    renderer._mrt = None
    b.set_shader_stage(Some("fragment"))
    let flow = b.flow_stages_node(make())
    if g2_shader_diff_enabled() {
      println("@@SHADER \{name} \{g2_record(b, flow, values=["skipped"])}")
    }
  }
}
