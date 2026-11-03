// nodes/utils/ReflectorNode.js: planar reflections (`reflector()`). The texture node
// samples the reflection that its `ReflectorBaseNode` renders from a mirrored camera.

///|
let _reflector_plane : @math.Plane = @math.Plane::new()

///|
let _reflector_normal : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _reflector_world_position : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _reflector_camera_world_position : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _reflector_rotation_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _reflector_look_at_position : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, -1.0,
)

///|
let _reflector_clip_plane : @math.Vector4 = @math.Vector4::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
let _reflector_view : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _reflector_target : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _reflector_q : @math.Vector4 = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)

///|
let _reflector_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _reflector_default_rt : @core.RenderTarget = {
  let rt = @core.RenderTarget::new()
  rt
}

///|
let _reflector_default_uv : Node = module_nodes(
  "nodes/utils/ReflectorNode.js:_defaultUV",
  fn() { screen_uv.flip_x() },
)

///|
let _reflector_default_rt_depth : Unit = _reflector_default_rt.set_depth_texture(
  Some(@core.DepthTexture::new(width=1, height=1)),
)

///|
let _reflector_in_reflector : Ref[Bool] = Ref(false)

///|
extern "js" fn reflector_math_sign(x : Double) -> Double = "Math.sign"

///|
extern "js" fn reflector_math_round(x : Double) -> Double = "Math.round"

///|
/// The texture node of a reflection.
pub(all) struct ReflectorNode {
  texture : TextureNode
  mut _reflector_base_node : Node
  mut _depth_node : Node?
}

///|
pub impl NodeClass for ReflectorNode with fn class_name(_) {
  "ReflectorNode"
}

///|
pub impl NodeClass for ReflectorNode with fn parent(self) {
  Some(self.texture)
}

///|
pub impl NodeClass for ReflectorNode with fn has_flag(self, flag) {
  self.texture.has_flag(flag)
}

///|
pub impl NodeClass for ReflectorNode with fn setup(self, node, builder) {
  // ignore if used in post-processing
  let is_quad_mesh = match builder.object {
    Object3D(o) => o.has_extension_flag("isQuadMesh")
    _ => false
  }
  if !is_quad_mesh {
    self._reflector_base_node.build(builder) |> ignore
  }
  NodeClass::setup(self.texture, node, builder)
}

///|
pub impl NodeClass for ReflectorNode with fn dispose(self, node) {
  NodeClass::dispose(self.texture, node)
  self._reflector_base_node.dispose()
}

///|
pub impl InputNodeClass for ReflectorNode with fn input_parent(self) {
  Some(self.texture)
}

///|
pub impl TextureNodeClass for ReflectorNode with fn texture_parent(self) {
  Some(self.texture)
}

///|
pub impl TextureNodeClass for ReflectorNode with fn clone(self, _) {
  // upstream passes `this.reflectorNode`, which is undefined: a reflector with the
  // default parameters, whose base node is replaced below
  let new_node = ReflectorNode::new()
  let t = self.texture
  let n = TextureNode::of(new_node).unwrap()
  n.uv_node = t.uv_node
  n.level_node = t.level_node
  n.bias_node = t.bias_node
  n.sampler = t.sampler
  n.depth_node = t.depth_node
  n.compare_node = t.compare_node
  n.grad_node = t.grad_node
  n.gather_node = t.gather_node
  n.offset_node = t.offset_node
  ReflectorNode::of(new_node).unwrap()._reflector_base_node = self._reflector_base_node
  new_node
}

///|
/// `new ReflectorNode( parameters = {} )`.
pub fn ReflectorNode::new(
  target? : @core.Object3D,
  resolution_scale~ : Double = 1.0,
  generate_mipmaps~ : Bool = false,
  bounces~ : Bool = true,
  depth~ : Bool = false,
  samples~ : Int32 = 0,
  default_texture? : @core.Texture,
  reflector? : Node,
) -> Node {
  ignore(_reflector_default_rt_depth)
  let this = Node::alloc()
  let texture = TextureNode::construct(
    this,
    Some(default_texture.unwrap_or(_reflector_default_rt.texture())),
    Some(_reflector_default_uv),
    None,
    None,
  )
  let payload = { texture, _reflector_base_node: this, _depth_node: None, }
  texture.install(this, payload, payload, payload) |> ignore
  payload._reflector_base_node = match reflector {
    Some(r) => r
    None =>
      ReflectorBaseNode::new(
        this,
        target?,
        resolution_scale~,
        generate_mipmaps~,
        bounces~,
        depth~,
        samples~,
      )
  }
  this.set_update_matrix(false) |> ignore
  this
}

///|
pub fn ReflectorNode::of(node : Node) -> ReflectorNode? {
  match node.class_payload("ReflectorNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `get reflector()`: the `ReflectorBaseNode`.
pub fn ReflectorNode::reflector(node : Node) -> Node {
  ReflectorNode::of(node).unwrap()._reflector_base_node
}

///|
/// `get target()`: the object whose plane reflects.
pub fn ReflectorNode::target(node : Node) -> @core.Object3D {
  ReflectorBaseNode::of(ReflectorNode::reflector(node)).unwrap().target
}

///|
/// `getDepthNode()`: the reflection's depth (reflectors created with `depth`).
pub fn ReflectorNode::get_depth_node(node : Node) -> Node {
  let self = ReflectorNode::of(node).unwrap()
  match self._depth_node {
    Some(n) => n
    None => {
      let base = ReflectorBaseNode::of(self._reflector_base_node).unwrap()
      if base.depth != true {
        abort(
          "THREE.ReflectorNode: Depth node can only be requested when the reflector is created with { depth: true }. ",
        )
      }
      let n = ReflectorNode::new(
        default_texture=_reflector_default_rt.depth_texture().unwrap(),
        reflector=self._reflector_base_node,
      )
      self._depth_node = Some(n)
      n
    }
  }
}

///|
/// Renders the reflection of a `ReflectorNode`.
pub(all) struct ReflectorBaseNode {
  mut texture_node : Node
  mut target : @core.Object3D
  mut resolution_scale : Double
  mut generate_mipmaps : Bool
  mut bounces : Bool
  mut depth : Bool
  mut samples : Int32
  virtual_cameras : @webgl.WeakMap[@core.Object3D, @core.Object3D]
  /// `renderTargets`, keyed by virtual camera in insertion order.
  render_targets : Array[(@core.Object3D, @core.RenderTarget)]
  mut force_update : Bool
  mut has_output : Bool
}

///|
pub impl NodeClass for ReflectorBaseNode with fn class_name(_) {
  "ReflectorBaseNode"
}

///|
pub impl NodeClass for ReflectorBaseNode with fn children(self, _, out) {
  push_child(out, "textureNode", Some(self.texture_node))
}

///|
pub impl NodeClass for ReflectorBaseNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for ReflectorBaseNode with fn setup(self, node, builder) {
  self._update_resolution(_reflector_default_rt, builder.renderer)
  node.setup_base(builder)
}

///|
pub impl NodeClass for ReflectorBaseNode with fn dispose(self, node) {
  node.dispose_base()
  for entry in self.render_targets {
    entry.1.dispose()
  }
}

///|
pub impl NodeClass for ReflectorBaseNode with fn update_reference(
  self,
  _,
  state,
) {
  let camera = match state {
    Frame(frame) => frame.camera
    Builder(builder) => builder.camera
  }
  @core.JsValue::of(self.get_virtual_camera(camera.unwrap()))
}

///|
pub impl NodeClass for ReflectorBaseNode with fn update_before(self, _, frame) {
  self.update_before_base(frame)
}

///|
/// `new ReflectorBaseNode( textureNode, parameters = {} )`.
pub fn ReflectorBaseNode::new(
  texture_node : Node,
  target? : @core.Object3D,
  resolution_scale~ : Double = 1.0,
  generate_mipmaps~ : Bool = false,
  bounces~ : Bool = true,
  depth~ : Bool = false,
  samples~ : Int32 = 0,
) -> Node {
  let node = Node::alloc()
  let target = match target {
    Some(t) => t
    None => @core.Object3D::new()
  }
  let payload = {
    texture_node,
    target,
    resolution_scale,
    generate_mipmaps,
    bounces,
    depth,
    samples,
    virtual_cameras: @webgl.WeakMap::new(),
    render_targets: [],
    force_update: false,
    has_output: false,
  }
  node.update_before_type = if bounces {
    NodeUpdateType::render()
  } else {
    NodeUpdateType::frame()
  }
  node.set_class(payload)
}

///|
pub fn ReflectorBaseNode::of(node : Node) -> ReflectorBaseNode? {
  match node.class_payload("ReflectorBaseNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn ReflectorBaseNode::_update_resolution(
  self : ReflectorBaseNode,
  render_target : @core.RenderTarget,
  renderer : Renderer,
) -> Unit {
  let resolution = self.resolution_scale
  renderer.get_drawing_buffer_size(_reflector_size) |> ignore
  render_target.set_size(
    reflector_math_round(_reflector_size.x * resolution).to_int(),
    reflector_math_round(_reflector_size.y * resolution).to_int(),
  )
}

///|
/// `getVirtualCamera( camera )`: the mirrored copy of a camera.
pub fn ReflectorBaseNode::get_virtual_camera(
  self : ReflectorBaseNode,
  camera : @core.Object3D,
) -> @core.Object3D {
  match self.virtual_cameras.get(camera) {
    Some(c) => c
    None => {
      let virtual_camera = camera.clone()
      self.virtual_cameras.set(camera, virtual_camera)
      virtual_camera
    }
  }
}

///|
/// `getRenderTarget( camera )`.
pub fn ReflectorBaseNode::get_render_target(
  self : ReflectorBaseNode,
  camera : @core.Object3D,
) -> @core.RenderTarget {
  for entry in self.render_targets {
    if physical_equal(entry.0, camera) {
      return entry.1
    }
  }
  let render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    type_=@core.HalfFloatType,
    samples=self.samples,
  )
  if self.generate_mipmaps == true {
    render_target.texture().min_filter = @core.LinearMipmapLinearFilter
    render_target.texture().generate_mipmaps = true
  }
  if self.depth == true {
    render_target.set_depth_texture(Some(@core.DepthTexture::new()))
  }
  self.render_targets.push((camera, render_target))
  render_target
}

///|
fn _reflector_camera_near_far(camera : @core.Object3D) -> (Double, Double) {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => (c.near, c.far)
    OrthographicCamera(c) => (c.near, c.far)
    BaseCamera => abort("ReflectorNode: the camera has no near/far")
  }
}

///|
fn _reflector_set_near_far(
  camera : @core.Object3D,
  near : Double,
  far : Double,
) -> Unit {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => {
      c.near = near
      c.far = far
    }
    OrthographicCamera(c) => {
      c.near = near
      c.far = far
    }
    BaseCamera => ()
  }
}

///|
/// ReflectorBaseNode's `updateBefore( frame )`: renders the scene from the mirrored
/// camera into the reflection's render target.
pub fn ReflectorBaseNode::update_before_base(
  self : ReflectorBaseNode,
  frame : NodeFrame,
) -> Bool? {
  if self.bounces == false && _reflector_in_reflector.val {
    return Some(false)
  }
  _reflector_in_reflector.val = true
  let scene = frame.scene.unwrap()
  let camera = frame.camera.unwrap()
  let renderer = frame.renderer.unwrap()
  let material = frame.material.unwrap()
  let target = self.target
  let virtual_camera = self.get_virtual_camera(camera)
  let render_target = self.get_render_target(virtual_camera)
  renderer.get_drawing_buffer_size(_reflector_size) |> ignore
  self._update_resolution(render_target, renderer)
  //
  _reflector_world_position.set_from_matrix_position(target.matrix_world)
  |> ignore
  _reflector_camera_world_position.set_from_matrix_position(camera.matrix_world)
  |> ignore
  _reflector_rotation_matrix.extract_rotation(target.matrix_world) |> ignore
  _reflector_normal.set(0.0, 0.0, 1.0) |> ignore
  _reflector_normal.apply_matrix4(_reflector_rotation_matrix) |> ignore
  _reflector_view.sub_vectors(
    _reflector_world_position, _reflector_camera_world_position,
  )
  |> ignore
  // Avoid rendering when reflector is facing away unless forcing an update
  let is_facing_away = _reflector_view.dot(_reflector_normal) > 0.0
  let mut needs_clear = false
  if is_facing_away == true && self.force_update == false {
    if self.has_output == false {
      _reflector_in_reflector.val = false
      return None
    }
    needs_clear = true
  }
  _reflector_view.reflect(_reflector_normal).negate() |> ignore
  _reflector_view.add(_reflector_world_position) |> ignore
  _reflector_rotation_matrix.extract_rotation(camera.matrix_world) |> ignore
  _reflector_look_at_position.set(0.0, 0.0, -1.0) |> ignore
  _reflector_look_at_position.apply_matrix4(_reflector_rotation_matrix)
  |> ignore
  _reflector_look_at_position.add(_reflector_camera_world_position) |> ignore
  _reflector_target.sub_vectors(
    _reflector_world_position, _reflector_look_at_position,
  )
  |> ignore
  _reflector_target.reflect(_reflector_normal).negate() |> ignore
  _reflector_target.add(_reflector_world_position) |> ignore
  //
  virtual_camera.as_camera().coordinate_system = camera.as_camera().coordinate_system
  virtual_camera.position.copy(_reflector_view) |> ignore
  virtual_camera.up.set(0.0, 1.0, 0.0) |> ignore
  virtual_camera.up.apply_matrix4(_reflector_rotation_matrix) |> ignore
  virtual_camera.up.reflect(_reflector_normal) |> ignore
  virtual_camera.look_at(_reflector_target)
  let (near, far) = _reflector_camera_near_far(camera)
  _reflector_set_near_far(virtual_camera, near, far)
  virtual_camera.update_matrix_world()
  let projection_matrix = virtual_camera.as_camera().projection_matrix
  projection_matrix.copy(camera.projection_matrix()) |> ignore
  // The reflection is mirrored horizontally, so the view offset must be mirrored as well.
  let e = projection_matrix.elements
  e[8] = e[8] * -1.0
  e[12] = e[12] * -1.0
  // Now update projection matrix with new clip plane, implementing code from: http://www.terathon.com/code/oblique.html
  _reflector_plane.set_from_normal_and_coplanar_point(
    _reflector_normal, _reflector_world_position,
  )
  |> ignore
  _reflector_plane.apply_matrix4(virtual_camera.matrix_world_inverse())
  |> ignore
  let clip_plane = _reflector_clip_plane
  clip_plane.set(
    _reflector_plane.normal.x,
    _reflector_plane.normal.y,
    _reflector_plane.normal.z,
    _reflector_plane.constant,
  )
  |> ignore
  _reflector_q.x = (reflector_math_sign(clip_plane.x) + e[8]) / e[0]
  _reflector_q.y = (reflector_math_sign(clip_plane.y) + e[9]) / e[5]
  _reflector_q.z = -1.0
  _reflector_q.w = (1.0 + e[10]) / e[14]
  // Calculate the scaled plane vector
  clip_plane.multiply_scalar(1.0 / clip_plane.dot(_reflector_q)) |> ignore
  let clip_bias = 0.0
  // Replacing the third row of the projection matrix
  e[2] = clip_plane.x
  e[6] = clip_plane.y
  e[10] = if renderer.coordinate_system() == @core.WebGPUCoordinateSystem {
    clip_plane.z - clip_bias
  } else {
    clip_plane.z + 1.0 - clip_bias
  }
  e[14] = clip_plane.w
  //
  TextureNode::set_value(self.texture_node, Some(render_target.texture()))
  if self.depth == true {
    TextureNode::set_value(
      ReflectorNode::get_depth_node(self.texture_node),
      render_target.depth_texture(),
    )
  }
  material.visible = false
  let current_render_target = renderer.get_render_target()
  let current_mrt = renderer.get_mrt()
  let current_auto_clear = renderer.auto_clear
  renderer.set_mrt(None) |> ignore
  renderer.set_render_target(Some(render_target))
  renderer.auto_clear = true
  let previous_name = scene.name
  // TODO: Add bounce index
  scene.name = (if scene.name == "" { "Scene" } else { scene.name }) +
    " [ Reflector ]"
  if needs_clear {
    renderer.clear()
    self.has_output = false
  } else {
    renderer.render(scene, virtual_camera)
    self.has_output = true
  }
  scene.name = previous_name
  renderer.set_mrt(current_mrt) |> ignore
  renderer.set_render_target(current_render_target)
  renderer.auto_clear = current_auto_clear
  material.visible = true
  _reflector_in_reflector.val = false
  self.force_update = false
  None
}

///|
/// `reflector( parameters )`.
pub fn reflector(
  target? : @core.Object3D,
  resolution_scale~ : Double = 1.0,
  generate_mipmaps~ : Bool = false,
  bounces~ : Bool = true,
  depth~ : Bool = false,
  samples~ : Int32 = 0,
) -> Node {
  ReflectorNode::new(
    target?,
    resolution_scale~,
    generate_mipmaps~,
    bounces~,
    depth~,
    samples~,
  )
}
