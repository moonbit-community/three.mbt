// nodes/lighting/ShadowNode.js: shadow mapping for directional and spot lights. The
// methods specialized shadow nodes override (`setupShadowFilter`, `setupShadowCoord`,
// `getShadowFilterFn`, `setupRenderTarget`, `setupShadow`, `renderShadow`,
// `updateShadow`, `vsmPass`) dispatch through `ShadowNodeClass`.

///|
/// `VSMPassVertical( { samples, radius, size, shadowPass, depthLayer } )`.
let shadow_node_vsm_pass_vertical : Node = module_nodes(
  "nodes/lighting/ShadowNode.js:VSMPassVertical",
  fn() {
    fn_(fn(inputs, _) {
      let samples = inputs.named("samples").unwrap()
      let radius = inputs.named("radius").unwrap()
      let size = inputs.named("size").unwrap()
      let shadow_pass = inputs.named("shadowPass").unwrap()
      let depth_layer = inputs.named("depthLayer")
      let mean = float(0).to_var(name="meanVertical")
      let squared_mean = float(0).to_var(name="squareMeanVertical")
      let uv_stride = samples
        .less_than_equal(float(1))
        .select(float(0), else_node=float(2).div(samples.sub(1)))
      let uv_start = samples
        .less_than_equal(float(1))
        .select(float(0), else_node=float(-1))
      loop_(
        [loop_range(start=int(0), end=int(samples), type_="int", condition="<")],
        fn(inputs) {
          let i = inputs.named("i").unwrap()
          let uv_offset = uv_start.add(float(i).mul(uv_stride))
          let mut depth = shadow_pass.sample(
            add(screen_coordinate.xy(), vec2_of([0, uv_offset]).mul(radius)).div(
              size,
            ),
          )
          if shadow_node_is_array_texture(shadow_pass) {
            depth = depth.depth(physical_optional(depth_layer))
          }
          depth = depth.x()
          mean.add_assign(depth)
          squared_mean.add_assign(depth.mul(depth))
        },
      )
      mean.div_assign(samples)
      squared_mean.div_assign(samples)
      let std_dev = sqrt(squared_mean.sub(mean.mul(mean)).max(0))
      Some(vec2_of([mean, std_dev]))
    })
  },
)

///|
/// `VSMPassHorizontal( { samples, radius, size, shadowPass, depthLayer } )`.
let shadow_node_vsm_pass_horizontal : Node = module_nodes(
  "nodes/lighting/ShadowNode.js:VSMPassHorizontal",
  fn() {
    fn_(fn(inputs, _) {
      let samples = inputs.named("samples").unwrap()
      let radius = inputs.named("radius").unwrap()
      let size = inputs.named("size").unwrap()
      let shadow_pass = inputs.named("shadowPass").unwrap()
      let depth_layer = inputs.named("depthLayer")
      let mean = float(0).to_var(name="meanHorizontal")
      let squared_mean = float(0).to_var(name="squareMeanHorizontal")
      let uv_stride = samples
        .less_than_equal(float(1))
        .select(float(0), else_node=float(2).div(samples.sub(1)))
      let uv_start = samples
        .less_than_equal(float(1))
        .select(float(0), else_node=float(-1))
      loop_(
        [loop_range(start=int(0), end=int(samples), type_="int", condition="<")],
        fn(inputs) {
          let i = inputs.named("i").unwrap()
          let uv_offset = uv_start.add(float(i).mul(uv_stride))
          let mut distribution = shadow_pass.sample(
            add(screen_coordinate.xy(), vec2_of([uv_offset, 0]).mul(radius)).div(
              size,
            ),
          )
          if shadow_node_is_array_texture(shadow_pass) {
            distribution = distribution.depth(physical_optional(depth_layer))
          }
          mean.add_assign(distribution.x())
          squared_mean.add_assign(
            add(
              distribution.y().mul(distribution.y()),
              distribution.x().mul(distribution.x()),
            ),
          )
        },
      )
      mean.div_assign(samples)
      squared_mean.div_assign(samples)
      let std_dev = sqrt(squared_mean.sub(mean.mul(mean)).max(0))
      Some(vec2_of([mean, std_dev]))
    })
  },
)

///|
/// `shadowPass.value.isArrayTexture` of a texture node.
fn shadow_node_is_array_texture(texture_node : Node) -> Bool {
  match TextureNode::get_value_opt(texture_node) {
    Some(t) => t.is_array_texture
    None => false
  }
}

///|
/// `_shadowFilterLib[ type ]`: by shadow map type; PCFSoftShadowMap was removed.
fn shadow_node_filter_lib(type_ : Int32) -> Node? {
  match type_ {
    0 => Some(basic_shadow_filter)
    1 => Some(pcf_shadow_filter)
    3 => Some(vsm_shadow_filter)
    _ => None
  }
}

///|
/// `_rendererState`.
let shadow_node_renderer_state : Ref[RendererState?] = Ref(None)

///|
/// `_quadMesh`, created on first use (upstream creates it at module load).
let shadow_node_quad_mesh : Ref[QuadMesh?] = Ref(None)

///|
fn shadow_node_get_quad_mesh() -> QuadMesh {
  match shadow_node_quad_mesh.val {
    Some(q) => q
    None => {
      let q = QuadMesh::new()
      shadow_node_quad_mesh.val = Some(q)
      q
    }
  }
}

///|
/// The inputs of `setupShadowFilter( builder, { filterFn, shadowTexture, depthTexture,
/// shadowCoord, shadow, depthLayer } )`.
pub(all) struct ShadowFilterInputs {
  filter_fn : Node
  shadow_texture : @core.Texture?
  depth_texture : @core.Texture
  shadow_coord : Node
  shadow : @core.LightShadow
  depth_layer : Int32
}

///|
/// What `setupRenderTarget` returns: `{ shadowMap, depthTexture }`.
pub(all) struct ShadowRenderTarget {
  shadow_map : @core.RenderTarget
  depth_texture : @core.Texture
}

///|
/// The virtual methods of the `ShadowNode` family; defaults walk to the parent.
pub(open) trait ShadowNodeClass {
  fn shadow_parent(Self) -> &ShadowNodeClass? = _
  /// `setupShadowFilter( builder, inputs )`.
  fn setup_shadow_filter(Self, Node, NodeBuilder, ShadowFilterInputs) -> Node = _
  /// `setupShadowCoord( builder, shadowPosition )`.
  fn setup_shadow_coord(Self, Node, NodeBuilder, Node) -> Node = _
  /// `getShadowFilterFn( type )`.
  fn get_shadow_filter_fn(Self, Node, Int32) -> Node? = _
  /// `setupRenderTarget( shadow, builder )`.
  fn setup_render_target(Self, Node, @core.LightShadow, NodeBuilder) -> ShadowRenderTarget = _
  /// `setupShadow( builder )`.
  fn setup_shadow(Self, Node, NodeBuilder) -> Node = _
  /// `renderShadow( frame )`.
  fn render_shadow(Self, Node, NodeFrame) -> Unit = _
  /// `updateShadow( frame )`.
  fn update_shadow(Self, Node, NodeFrame) -> Unit = _
  /// `vsmPass( renderer )`.
  fn vsm_pass(Self, Node, Renderer) -> Unit = _
}

///|
impl ShadowNodeClass with fn shadow_parent(_) {
  None
}

///|
impl ShadowNodeClass with fn setup_shadow_filter(self, node, builder, inputs) {
  match self.shadow_parent() {
    Some(p) => p.setup_shadow_filter(node, builder, inputs)
    None => ShadowNode::setup_shadow_filter_base(node, builder, inputs)
  }
}

///|
impl ShadowNodeClass with fn setup_shadow_coord(self, node, builder, position) {
  match self.shadow_parent() {
    Some(p) => p.setup_shadow_coord(node, builder, position)
    None => ShadowNode::setup_shadow_coord_base(node, builder, position)
  }
}

///|
impl ShadowNodeClass with fn get_shadow_filter_fn(self, node, type_) {
  match self.shadow_parent() {
    Some(p) => p.get_shadow_filter_fn(node, type_)
    None => shadow_node_filter_lib(type_)
  }
}

///|
impl ShadowNodeClass with fn setup_render_target(self, node, shadow, builder) {
  match self.shadow_parent() {
    Some(p) => p.setup_render_target(node, shadow, builder)
    None => ShadowNode::setup_render_target_base(shadow, builder)
  }
}

///|
impl ShadowNodeClass with fn setup_shadow(self, node, builder) {
  match self.shadow_parent() {
    Some(p) => p.setup_shadow(node, builder)
    None => ShadowNode::setup_shadow_base(node, builder)
  }
}

///|
impl ShadowNodeClass with fn render_shadow(self, node, frame) {
  match self.shadow_parent() {
    Some(p) => p.render_shadow(node, frame)
    None => ShadowNode::render_shadow_base(node, frame)
  }
}

///|
impl ShadowNodeClass with fn update_shadow(self, node, frame) {
  match self.shadow_parent() {
    Some(p) => p.update_shadow(node, frame)
    None => ShadowNode::update_shadow_base(node, frame)
  }
}

///|
impl ShadowNodeClass with fn vsm_pass(self, node, renderer) {
  match self.shadow_parent() {
    Some(p) => p.vsm_pass(node, renderer)
    None => ShadowNode::vsm_pass_base(node, renderer)
  }
}

///|
priv struct ShadowNodeUnset {}

///|
impl ShadowNodeClass for ShadowNodeUnset

///|
/// `shadowMap._vsmShadowMapVertical` and `_vsmShadowMapHorizontal` of array shadow maps.
priv struct ShadowNodeVsmMaps {
  mut vertical : @core.RenderTarget?
  mut horizontal : @core.RenderTarget?
}

///|
let shadow_node_vsm_maps : @webgl.WeakMap[@core.RenderTarget, ShadowNodeVsmMaps] = @webgl.WeakMap::new()

///|
pub(all) struct ShadowNode {
  base : ShadowBaseNode
  mut shadow : @core.LightShadow
  mut shadow_map : @core.RenderTarget?
  mut vsm_shadow_map_vertical : @core.RenderTarget?
  mut vsm_shadow_map_horizontal : @core.RenderTarget?
  mut vsm_material_vertical : @core.Material?
  mut vsm_material_horizontal : @core.Material?
  mut _node : Node?
  mut _current_shadow_type : Int32?
  _camera_frame_id : @webgl.WeakMap[@core.Object3D, Int32]
  mut depth_layer : Int32
  /// The most derived payload of the family.
  mut class_ : &ShadowNodeClass
}

///|
pub impl ShadowNodeClass for ShadowNode

///|
pub impl NodeClass for ShadowNode with fn class_name(_) {
  "ShadowNode"
}

///|
pub impl NodeClass for ShadowNode with fn parent(self) {
  Some(self.base)
}

///|
pub impl NodeClass for ShadowNode with fn has_flag(self, flag) {
  flag == "isShadowNode" || NodeClass::has_flag(self.base, flag)
}

///|
pub impl NodeClass for ShadowNode with fn setup(self, node, builder) {
  if builder.renderer.shadow_map.enabled == false {
    return None
  }
  Some(
    fn_(fn(_, _) {
      let current_shadow_type = builder.renderer.shadow_map.type_
      if self._current_shadow_type != Some(current_shadow_type) {
        ShadowNode::reset(node)
        self._node = None
      }
      let mut output = self._node
      self.base.setup_shadow_position(builder)
      if output is None {
        let n = self.class_.setup_shadow(node, builder)
        self._node = Some(n)
        output = Some(n)
        self._current_shadow_type = Some(current_shadow_type)
      }
      let material = NodeMaterial::of(builder.material.unwrap())
      match material {
        Some({ received_shadow_node: Some(received), .. }) =>
          Some(received.call([output.unwrap()]))
        _ => output
      }
    }).call([]),
  )
}

///|
pub impl NodeClass for ShadowNode with fn dispose(self, node) {
  ShadowNode::reset(node)
  NodeClass::dispose(self.base, node)
}

///|
pub impl NodeClass for ShadowNode with fn update_before(self, node, frame) {
  let renderer = frame.renderer.unwrap()
  if renderer._precompilation_state is Some(_) {
    return None
  }
  let shadow = self.shadow
  let mut needs_update = shadow.needs_update || shadow.auto_update
  if needs_update {
    let camera = frame.camera.unwrap()
    if self._camera_frame_id.get(camera) == Some(frame.frame_id) {
      needs_update = false
    }
    self._camera_frame_id.set(camera, frame.frame_id)
  }
  if needs_update {
    self.class_.update_shadow(node, frame)
    shadow.needs_update = false
  }
  None
}

///|
/// The constructor body.
pub fn ShadowNode::construct(
  node : Node,
  light : @core.Object3D,
  shadow : @core.LightShadow?,
) -> ShadowNode {
  let base = ShadowBaseNode::construct(node, light)
  {
    base,
    shadow: match shadow {
      Some(s) => s
      None => light.as_light().shadow.unwrap()
    },
    shadow_map: None,
    vsm_shadow_map_vertical: None,
    vsm_shadow_map_horizontal: None,
    vsm_material_vertical: None,
    vsm_material_horizontal: None,
    _node: None,
    _current_shadow_type: None,
    _camera_frame_id: @webgl.WeakMap::new(),
    depth_layer: 0,
    class_: ShadowNodeUnset::{ },
  }
}

///|
/// `new ShadowNode( light, shadow = null )`.
pub fn ShadowNode::new(
  light : @core.Object3D,
  shadow? : @core.LightShadow,
) -> Node {
  let node = Node::alloc()
  let payload = ShadowNode::construct(node, light, shadow)
  payload.class_ = payload
  node.set_class(payload)
}

///|
pub fn ShadowNode::of(node : Node) -> ShadowNode? {
  match node.class_payload("ShadowNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn ShadowNode::payload_of(node : Node) -> ShadowNode {
  match ShadowNode::of(node) {
    Some(p) => p
    None => abort("TypeError: \{node.type_()} is not a ShadowNode")
  }
}

///|
/// The inputs object a shadow filter `Fn` is called with.
pub fn ShadowFilterInputs::to_tsl_object(self : ShadowFilterInputs) -> TslValue {
  Object({
    "depthTexture": Texture(self.depth_texture),
    "shadowCoord": Node(self.shadow_coord),
    "shadow": shadow_filter_shadow_value(self.shadow),
    "depthLayer": Number(self.depth_layer.to_double()),
  })
}

///|
/// `ShadowNode.prototype.setupShadowFilter`: the filtered shadow inside the shadow
/// camera frustum, 1 outside.
pub fn ShadowNode::setup_shadow_filter_base(
  _node : Node,
  _builder : NodeBuilder,
  inputs : ShadowFilterInputs,
) -> Node {
  let shadow_coord = inputs.shadow_coord
  let frustum_test = shadow_coord
    .x()
    .greater_than_equal(0)
    .and_(shadow_coord.x().less_than_equal(1))
    .and_(shadow_coord.y().greater_than_equal(0))
    .and_(shadow_coord.y().less_than_equal(1))
    .and_(shadow_coord.z().less_than_equal(1))
  let shadow_node = inputs.filter_fn.call([inputs.to_tsl_object()])
  frustum_test.select(shadow_node, else_node=float(1))
}

///|
/// `ShadowNode.prototype.setupShadowCoord`.
pub fn ShadowNode::setup_shadow_coord_base(
  node : Node,
  builder : NodeBuilder,
  shadow_position : Node,
) -> Node {
  let self = ShadowNode::payload_of(node)
  let shadow = self.shadow
  let renderer = builder.renderer
  let bias = match shadow.bias_node {
    Some(b) => (b.cast() : Node)
    None =>
      ReferenceNode::set_group(
        shadow_reference("bias", "float", shadow),
        render_group,
      )
  }
  let mut shadow_coord = shadow_position
  let coord_z = if shadow.camera.is_orthographic_camera() ||
    renderer.logarithmic_depth_buffer != true {
    shadow_coord = shadow_coord.xyz().div(shadow_coord.w())
    shadow_coord.z()
  } else {
    let w = shadow_coord.w()
    shadow_coord = shadow_coord.xy().div(w)
    let camera_near_local = ReferenceNode::set_group(
      reference("near", "float", object=Object3D(shadow.camera)),
      render_group,
    )
    let camera_far_local = ReferenceNode::set_group(
      reference("far", "float", object=Object3D(shadow.camera)),
      render_group,
    )
    view_z_to_logarithmic_depth(w.negate(), camera_near_local, camera_far_local)
  }
  vec3_of([
    shadow_coord.x(),
    shadow_coord.y().one_minus(),
    if renderer.reversed_depth_buffer {
      coord_z.sub(bias)
    } else {
      coord_z.add(bias)
    },
  ])
}

///|
/// `ShadowNode.prototype.setupRenderTarget`: a depth render target of the map size.
pub fn ShadowNode::setup_render_target_base(
  shadow : @core.LightShadow,
  builder : NodeBuilder,
) -> ShadowRenderTarget {
  let width = shadow.map_size.x.to_int()
  let height = shadow.map_size.y.to_int()
  let depth_texture = @core.DepthTexture::new(width~, height~)
  depth_texture.name = "ShadowDepthTexture"
  depth_texture.compare_function = Some(
    if builder.renderer.reversed_depth_buffer {
      @core.GreaterEqualCompare
    } else {
      @core.LessEqualCompare
    },
  )
  let shadow_map = builder.create_render_target(width, height)
  shadow_map.texture().name = "ShadowMap"
  shadow_map.texture().type_ = shadow.map_type
  shadow_map.set_depth_texture(Some(depth_texture))
  { shadow_map, depth_texture, }
}

///|
/// A VSM blur target.
fn shadow_node_vsm_target(
  builder : NodeBuilder,
  shadow : @core.LightShadow,
  depth? : Int32,
) -> @core.RenderTarget {
  builder.create_render_target(
    shadow.map_size.x.to_int(),
    shadow.map_size.y.to_int(),
    options=RenderTargetOptions::new(
      format=@core.RGFormat,
      type_=@core.HalfFloatType,
      depth?,
      depth_buffer=false,
    ),
  )
}

///|
/// `ShadowNode.prototype.setupShadow`: the shadow factor of this light.
pub fn ShadowNode::setup_shadow_base(
  node : Node,
  builder : NodeBuilder,
) -> Node {
  let self = ShadowNode::payload_of(node)
  let renderer = builder.renderer
  let camera = builder.camera.unwrap()
  let light = self.base.light
  let shadow = self.shadow
  let { depth_texture, shadow_map, } = self.class_.setup_render_target(
    node, shadow, builder,
  )
  let shadow_map_type = renderer.shadow_map.type_
  let has_texture_compare = renderer.has_compatibility(
    @core.Compatibility_TEXTURE_COMPARE,
  )
  if shadow_map_type == @core.PCFShadowMap && has_texture_compare {
    depth_texture.min_filter = @core.LinearFilter
    depth_texture.mag_filter = @core.LinearFilter
  } else {
    depth_texture.min_filter = @core.NearestFilter
    depth_texture.mag_filter = @core.NearestFilter
  }
  shadow.camera.as_camera().coordinate_system = camera.as_camera().coordinate_system
  shadow.camera.as_camera()._reversed_depth = renderer.reversed_depth_buffer
  shadow.camera.update_projection_matrix()
  let is_point_light_shadow = shadow.kind is PointLightShadow
  if shadow_map_type == @core.VSMShadowMap && !is_point_light_shadow {
    depth_texture.compare_function = None
    if shadow_map.depth > 1 {
      let maps = match shadow_node_vsm_maps.get(shadow_map) {
        Some(m) => m
        None => {
          let m = ShadowNodeVsmMaps::{ vertical: None, horizontal: None, }
          shadow_node_vsm_maps.set(shadow_map, m)
          m
        }
      }
      if maps.vertical is None {
        let target = shadow_node_vsm_target(
          builder,
          shadow,
          depth=shadow_map.depth,
        )
        target.texture().name = "VSMVertical"
        maps.vertical = Some(target)
      }
      self.vsm_shadow_map_vertical = maps.vertical
      if maps.horizontal is None {
        let target = shadow_node_vsm_target(
          builder,
          shadow,
          depth=shadow_map.depth,
        )
        target.texture().name = "VSMHorizontal"
        maps.horizontal = Some(target)
      }
      self.vsm_shadow_map_horizontal = maps.horizontal
    } else {
      self.vsm_shadow_map_vertical = Some(
        shadow_node_vsm_target(builder, shadow),
      )
      self.vsm_shadow_map_horizontal = Some(
        shadow_node_vsm_target(builder, shadow),
      )
    }
    let mut shadow_pass_vertical = texture(depth_texture)
    if depth_texture.is_array_texture {
      shadow_pass_vertical = shadow_pass_vertical.depth(self.depth_layer)
    }
    let mut shadow_pass_horizontal = texture(
      self.vsm_shadow_map_vertical.unwrap().texture(),
    )
    if depth_texture.is_array_texture {
      shadow_pass_horizontal = shadow_pass_horizontal.depth(self.depth_layer)
    }
    let samples = ReferenceNode::set_group(
      shadow_reference("blurSamples", "float", shadow),
      render_group,
    )
    let radius = ReferenceNode::set_group(
      shadow_reference("radius", "float", shadow),
      render_group,
    )
    let size = ReferenceNode::set_group(
      shadow_reference("mapSize", "vec2", shadow),
      render_group,
    )
    let shared_context = context(value=builder.get_shared_context())
    let material = match self.vsm_material_vertical {
      Some(m) => m
      None => {
        let m = NodeMaterial::new()
        self.vsm_material_vertical = Some(m)
        m
      }
    }
    let node_material = NodeMaterial::of(material).unwrap()
    node_material.context_node = Some(shared_context)
    node_material.fragment_node = Some(
      shadow_node_vsm_pass_vertical.call_named({
        "samples": samples,
        "radius": radius,
        "size": size,
        "shadowPass": shadow_pass_vertical,
        "depthLayer": self.depth_layer,
      }),
    )
    material.name = "VSMVertical"
    let material = match self.vsm_material_horizontal {
      Some(m) => m
      None => {
        let m = NodeMaterial::new()
        self.vsm_material_horizontal = Some(m)
        m
      }
    }
    let node_material = NodeMaterial::of(material).unwrap()
    node_material.context_node = Some(shared_context)
    node_material.fragment_node = Some(
      shadow_node_vsm_pass_horizontal.call_named({
        "samples": samples,
        "radius": radius,
        "size": size,
        "shadowPass": shadow_pass_horizontal,
        "depthLayer": self.depth_layer,
      }),
    )
    material.name = "VSMHorizontal"
  }
  let shadow_intensity = ReferenceNode::set_group(
    shadow_reference("intensity", "float", shadow),
    render_group,
  )
  let normal_bias = ReferenceNode::set_group(
    shadow_reference("normalBias", "float", shadow),
    render_group,
  )
  let shadow_matrix = light_shadow_matrix(light)
  let shadow_normal_bias = normal_world.mul(normal_bias)
  let received_shadow_position_node = match
    NodeMaterial::of(builder.material.unwrap()) {
    Some(m) => m.received_shadow_position_node
    None => None
  }
  let shadow_position = if !renderer.high_precision() ||
    received_shadow_position_node is Some(_) ||
    builder.context.get_node("shadowPositionWorld") is Some(_) {
    shadow_matrix.mul(shadow_position_world.add(shadow_normal_bias))
  } else {
    let highp_shadow_model_matrix = uniform("mat4").on_object_update(fn(
      n,
      frame,
    ) {
      match (InputNode::get_value(n), InputNode::get_value(shadow_matrix)) {
        (Matrix4(value), Matrix4(shadow_value)) =>
          value.multiply_matrices(
            shadow_value,
            frame.object.unwrap().matrix_world,
          )
          |> ignore
        _ => ()
      }
      None
    })
    highp_shadow_model_matrix
    .mul(position_local)
    .add(shadow_matrix.mul(vec4_of([shadow_normal_bias, 0])))
  }
  let shadow_coord = self.class_.setup_shadow_coord(
    node, builder, shadow_position,
  )
  let filter_fn = match shadow.filter_node {
    Some(f) => Some((f.cast() : Node))
    None => self.class_.get_shadow_filter_fn(node, renderer.shadow_map.type_)
  }
  guard filter_fn is Some(filter_fn) else {
    abort("THREE.WebGPURenderer: Shadow map type not supported yet.")
  }
  let shadow_depth_texture = if shadow_map_type == @core.VSMShadowMap &&
    !is_point_light_shadow {
    self.vsm_shadow_map_horizontal.unwrap().texture()
  } else {
    depth_texture
  }
  let shadow_node = self.class_.setup_shadow_filter(node, builder, {
    filter_fn,
    shadow_texture: Some(shadow_map.texture()),
    depth_texture: shadow_depth_texture,
    shadow_coord,
    shadow,
    depth_layer: self.depth_layer,
  })
  let shadow_color = if renderer.shadow_map.transmitted == true {
    if shadow_map.texture().is_cube_texture() {
      Some(cube_texture(shadow_map.texture(), uv_node=shadow_coord.xyz()))
    } else {
      let mut c = texture(shadow_map.texture(), uv_node=shadow_coord)
      if depth_texture.is_array_texture {
        c = c.depth(self.depth_layer)
      }
      Some(c)
    }
  } else {
    None
  }
  let shadow_output = match shadow_color {
    Some(shadow_color) =>
      mix(
        1,
        shadow_node.rgb().mix(shadow_color, 1),
        shadow_intensity.mul(shadow_color.a()),
      ).to_var()
    None => mix(1, shadow_node, shadow_intensity).to_var()
  }
  self.shadow_map = Some(shadow_map)
  self.shadow.map = Some(shadow_map)
  self.shadow.needs_update = true
  let light_label = if light.name != "" {
    light.name
  } else {
    "ID: " + light.id.to_string()
  }
  let inspect_name = "\{light.type_} Shadow [ \{light_label} ]"
  if shadow_color is Some(shadow_color) {
    shadow_color.to_inspector(name="\{inspect_name} / Color", callback=fn(_) {
      let map = self.shadow_map.unwrap()
      if map.texture().is_cube_texture() {
        return cube_texture(map.texture(), uv_node=equirect_direction.call([]))
      }
      texture(map.texture())
    })
    |> ignore
  }
  shadow_output.to_inspector(name="\{inspect_name} / Depth", callback=fn(_) {
    let shadow_camera_near = reference(
      "near",
      "float",
      object=Object3D(self.shadow.camera),
    )
    let shadow_camera_far = reference(
      "far",
      "float",
      object=Object3D(self.shadow.camera),
    )
    let map = self.shadow_map.unwrap()
    let depth_node = if map.texture().is_cube_texture() {
      cube_texture(
        map.depth_texture().unwrap(),
        uv_node=equirect_direction.call([]),
      ).r()
    } else {
      texture(map.depth_texture().unwrap()).r()
    }
    let mut linear_depth = if self.shadow.camera.is_perspective_camera() {
      perspective_depth_to_view_z.call([
        depth_node, shadow_camera_near, shadow_camera_far,
      ])
    } else {
      orthographic_depth_to_view_z.call([
        depth_node, shadow_camera_near, shadow_camera_far,
      ])
    }
    linear_depth = view_z_to_orthographic_depth(
      linear_depth, shadow_camera_near, shadow_camera_far,
    )
    linear_depth.one_minus()
  })
}

///|
/// `ShadowNode.prototype.renderShadow`: renders the scene from the shadow camera.
pub fn ShadowNode::render_shadow_base(node : Node, frame : NodeFrame) -> Unit {
  let self = ShadowNode::payload_of(node)
  let shadow = self.shadow
  let shadow_map = self.shadow_map.unwrap()
  let light = self.base.light
  let renderer = frame.renderer.unwrap()
  let scene = frame.scene.unwrap()
  shadow.update_matrices(light)
  shadow_map.set_size(
    shadow.map_size.x.to_int(),
    shadow.map_size.y.to_int(),
    depth=shadow_map.depth,
  )
  let current_scene_name = scene.name
  let light_label = if light.name != "" {
    light.name
  } else {
    "ID: " + light.id.to_string()
  }
  scene.name = "Shadow Map [ \{light_label} ]"
  renderer.render(scene, shadow.camera)
  scene.name = current_scene_name
}

///|
/// `ShadowNode.prototype.updateShadow`: renders the shadow map with the shadow
/// material and render function.
pub fn ShadowNode::update_shadow_base(node : Node, frame : NodeFrame) -> Unit {
  let self = ShadowNode::payload_of(node)
  let shadow_map = self.shadow_map.unwrap()
  let shadow = self.shadow
  let renderer = frame.renderer.unwrap()
  let scene = frame.scene.unwrap()
  let camera = frame.camera.unwrap()
  let shadow_type = renderer.shadow_map.type_
  let shadow_camera_layer = shadow.camera.layers.mask
  if shadow_node_js_and(shadow.camera.layers.mask, 0xFFFFFFFE) == 0.0 {
    shadow.camera.layers.mask = camera.layers.mask
  }
  let current_render_object_function = renderer.get_render_object_function()
  shadow_node_renderer_state.val = Some(
    reset_renderer_and_scene_state(
      renderer,
      scene,
      state?=shadow_node_renderer_state.val,
    ),
  )
  scene.as_scene().override_material = Some(self.base.get_shadow_material())
  renderer.set_render_object_function(
    Some(self.base.get_shadow_render_object_function(renderer, shadow~)),
  )
  renderer.set_clear_color_hex(0x000000, alpha=0.0)
  renderer.set_render_target(Some(shadow_map))
  let current_matrix_world_auto_update = scene.matrix_world_auto_update
  scene.matrix_world_auto_update = false
  self.class_.render_shadow(node, frame)
  scene.matrix_world_auto_update = current_matrix_world_auto_update
  renderer.set_render_object_function(current_render_object_function)
  if shadow_type == @core.VSMShadowMap && !(shadow.kind is PointLightShadow) {
    self.class_.vsm_pass(node, renderer)
  }
  shadow.camera.layers.mask = shadow_camera_layer
  restore_renderer_and_scene_state(
    renderer,
    scene,
    shadow_node_renderer_state.val.unwrap(),
  )
}

///|
extern "js" fn shadow_node_js_and(a : Double, b : Double) -> Double = "(a, b) => a & b"

///|
/// `ShadowNode.prototype.vsmPass`: the two VSM blur passes.
pub fn ShadowNode::vsm_pass_base(node : Node, renderer : Renderer) -> Unit {
  let self = ShadowNode::payload_of(node)
  let shadow = self.shadow
  let depth = self.shadow_map.unwrap().depth
  let width = shadow.map_size.x.to_int()
  let height = shadow.map_size.y.to_int()
  self.vsm_shadow_map_vertical.unwrap().set_size(width, height, depth~)
  self.vsm_shadow_map_horizontal.unwrap().set_size(width, height, depth~)
  renderer.set_render_target(self.vsm_shadow_map_vertical)
  let quad_mesh = shadow_node_get_quad_mesh()
  quad_mesh.set_material(self.vsm_material_vertical.unwrap())
  quad_mesh.render(renderer)
  renderer.set_render_target(self.vsm_shadow_map_horizontal)
  quad_mesh.set_material(self.vsm_material_horizontal.unwrap())
  quad_mesh.render(renderer)
}

///|
/// `_reset()`: frees the shadow map, the VSM targets and materials.
pub fn ShadowNode::reset(node : Node) -> Unit {
  let self = ShadowNode::payload_of(node)
  self._current_shadow_type = None
  self.base.dispose_shadow_material()
  if self.shadow_map is Some(map) {
    map.dispose()
    self.shadow_map = None
  }
  if self.vsm_shadow_map_vertical is Some(map) {
    map.dispose()
    self.vsm_shadow_map_vertical = None
    self.vsm_material_vertical.unwrap().dispose()
    self.vsm_material_vertical = None
  }
  if self.vsm_shadow_map_horizontal is Some(map) {
    map.dispose()
    self.vsm_shadow_map_horizontal = None
    self.vsm_material_horizontal.unwrap().dispose()
    self.vsm_material_horizontal = None
  }
}

///|
/// `shadow( light, shadow )`.
pub fn shadow(light : @core.Object3D, shadow? : @core.LightShadow) -> Node {
  ShadowNode::new(light, shadow?)
}
