// examples/jsm/tsl/display/SSAONode.js

///|
extern "js" fn ssao_node_math_round(x : Double) -> Double = "Math.round"

///|
/// The module's top-level `_quadMesh`.
priv struct SSAONodeModule {
  _quad_mesh : @nodes.QuadMesh
}

///|
let _ssao_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _ssao_node_renderer_state : Ref[@nodes.RendererState?] = Ref(None)

///|
let display_ssao_node_module : AddonModule[SSAONodeModule] = AddonModule::new(fn() {
  load_display_depth_aware_blur()
  { _quad_mesh: @nodes.QuadMesh::new(), }
})

///|
/// Evaluates SSAONode.js (after its import depthAwareBlur.js), as `import` does.
pub fn load_display_ssao_node() -> Unit {
  display_ssao_node_module.get() |> ignore
}

///|
/// Post processing node for screen space ambient occlusion (a Vogel disk of samples,
/// then a separable depth-aware blur).
pub(all) struct SSAONode {
  mut depth_node : @nodes.Node
  mut normal_node : @nodes.Node
  mut resolution_scale : Double
  mut radius : @nodes.Node
  mut intensity : @nodes.Node
  mut bias : @nodes.Node
  mut samples : @nodes.Node
  mut blur_enabled : Bool
  mut blur_sharpness : @nodes.Node
  resolution : @math.Vector2
  _ao_render_target : @core.RenderTarget
  _blur_render_target : @core.RenderTarget
  _camera_projection_matrix : @nodes.Node
  _camera_projection_matrix_inverse : @nodes.Node
  _camera_near : @nodes.Node
  _camera_far : @nodes.Node
  _camera : @core.Object3D
  _blur_input : @nodes.Node
  _blur_direction : @nodes.Node
  _ao_material : @core.Material
  _blur_material : @core.Material
  _texture_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for SSAONode with fn class_name(_) {
  "SSAONode"
}

///|
pub impl @nodes.NodeClass for SSAONode with fn children(self, _, out) {
  @nodes.push_child(out, "depthNode", Some(self.depth_node))
  @nodes.push_child(out, "normalNode", Some(self.normal_node))
  @nodes.push_child(out, "radius", Some(self.radius))
  @nodes.push_child(out, "intensity", Some(self.intensity))
  @nodes.push_child(out, "bias", Some(self.bias))
  @nodes.push_child(out, "samples", Some(self.samples))
  @nodes.push_child(out, "blurSharpness", Some(self.blur_sharpness))
}

///|
pub impl @nodes.NodeClass for SSAONode with fn set_size(self, _, width, height) {
  self.set_size(width, height)
  true
}

///|
pub impl @nodes.NodeClass for SSAONode with fn update_before(self, _, frame) {
  let renderer = frame.renderer.unwrap()
  let quad_mesh = display_ssao_node_module.get()._quad_mesh
  _ssao_node_renderer_state.val = Some(
    @nodes.reset_renderer_state(renderer, state?=_ssao_node_renderer_state.val),
  )
  let size = renderer.get_drawing_buffer_size(_ssao_node_size)
  self.set_size(size.x, size.y)
  renderer.set_clear_color_hex(0xffffff, alpha=1.0)
  // ambient occlusion
  quad_mesh.set_material(self._ao_material)
  quad_mesh.object.name = "SSAO.AO"
  renderer.set_render_target(Some(self._ao_render_target))
  quad_mesh.render(renderer)
  // separable, depth-aware blur: horizontal ( AO -> blur ) then vertical ( blur -> AO )
  if self.blur_enabled == true {
    quad_mesh.set_material(self._blur_material)
    quad_mesh.object.name = "SSAO.Blur"
    @nodes.TextureNode::set_value(
      self._blur_input,
      Some(self._ao_render_target.texture()),
    )
    ssao_node_uniform_vector2(self._blur_direction).set(
      1.0 / self.resolution.x,
      0.0,
    )
    |> ignore
    renderer.set_render_target(Some(self._blur_render_target))
    quad_mesh.render(renderer)
    @nodes.TextureNode::set_value(
      self._blur_input,
      Some(self._blur_render_target.texture()),
    )
    ssao_node_uniform_vector2(self._blur_direction).set(
      0.0,
      1.0 / self.resolution.y,
    )
    |> ignore
    renderer.set_render_target(Some(self._ao_render_target))
    quad_mesh.render(renderer)
  }
  @nodes.restore_renderer_state(
    renderer,
    _ssao_node_renderer_state.val.unwrap(),
  )
  None
}

///|
pub impl @nodes.NodeClass for SSAONode with fn setup(self, _, builder) {
  let uv_node = @nodes.uv()
  let sample_depth = fn(uv : @nodes.Node) {
    @nodes.projection_depth.call([
      self.depth_node.sample(uv).r(),
      self._camera_near,
      self._camera_far,
    ])
  }
  // ambient occlusion
  let ao = @nodes.fn_(fn(_, _) {
    let depth = sample_depth(uv_node).to_var()
    @nodes.is_background_depth.call([depth]).discard()
    let view_position = @nodes.get_view_position
      .call([uv_node, depth, self._camera_projection_matrix_inverse])
      .to_var()
    let view_normal = self.normal_node
      .sample(uv_node)
      .rgb()
      .normalize()
      .to_var()
    // a low-discrepancy Vogel disk rotated per-pixel decorrelates the samples spatially,
    // so a small blur is enough to hide the sampling pattern
    let phi = @nodes.interleaved_gradient_noise
      .call([@nodes.screen_coordinate])
      .mul(@nodes.two_pi)
      .to_var()
    let samples = self.samples
    // the fragment's clip position is loop-invariant; projection is linear, so each
    // sample only has to project its (view-plane) offset and add it
    let clip_position = self._camera_projection_matrix
      .mul(@nodes.vec4_of([view_position, 1.0]))
      .to_var()
    let occlusion = @nodes.float(0).to_var()
    @nodes.loop_(
      [
        @nodes.loop_range(
          start=@nodes.int(0),
          end=samples,
          type_="int",
          condition="<",
        ),
      ],
      fn(inputs) {
        let i = inputs.named("i").unwrap()
        // disk offset in the view-aligned plane at the fragment's depth, then reprojected
        let offset = @nodes.vogel_disk_sample
          .call([i, samples, phi])
          .mul(self.radius)
        let clip_offset = self._camera_projection_matrix.mul(
          @nodes.vec4_of([offset, 0.0, 0.0]),
        )
        let sample_uv = @nodes.get_screen_position_from_clip.call([
          clip_position.add(clip_offset),
        ])
        let sample_view_position = @nodes.get_view_position.call([
          sample_uv,
          sample_depth(sample_uv),
          self._camera_projection_matrix_inverse,
        ])
        // normalized obscurance: only occluders above the tangent plane count, faded by distance
        let v = sample_view_position.sub(view_position).to_var()
        let dist = @nodes.length(v).to_var()
        let cos_angle = @nodes.dot(v, view_normal).div(
          @nodes.max(dist, @nodes.float(0.0001)),
        )
        let falloff = self.radius.div(self.radius.add(dist))
        occlusion.add_assign(
          @nodes.max(cos_angle.sub(self.bias), 0.0).mul(falloff),
        )
      },
    )
    Some(
      @nodes.clamp(
        occlusion.div(samples).mul(self.intensity).one_minus(),
        low=0.0,
        high=1.0,
      ),
    )
  })
  let shared_context = @nodes.context(value=builder.get_shared_context())
  // compute ambient occlusion
  let ao_material = @nodes.NodeMaterial::of(self._ao_material).unwrap()
  ao_material.context_node = Some(shared_context)
  ao_material.fragment_node = Some(ao.call([]))
  self._ao_material.set_needs_update(true)
  // separable, depth-aware blur ( run horizontally then vertically via `_blurDirection` )
  let blur_material = @nodes.NodeMaterial::of(self._blur_material).unwrap()
  blur_material.context_node = Some(shared_context)
  blur_material.fragment_node = Some(
    depth_aware_blur().call([
      self._blur_input,
      self.depth_node,
      self._blur_direction,
      self._camera,
      self.blur_sharpness,
      self.radius,
    ]),
  )
  self._blur_material.set_needs_update(true)
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for SSAONode with fn dispose(self, node) {
  node.dispose_base()
  self._ao_render_target.dispose()
  self._blur_render_target.dispose()
  self._ao_material.dispose()
  self._blur_material.dispose()
}

///|
/// `getTextureNode()`: the ambient occlusion result.
pub fn SSAONode::get_texture_node(self : SSAONode) -> @nodes.Node {
  self._texture_node
}

///|
/// `setSize( width, height )`: the render targets' size, scaled by `resolutionScale`.
pub fn SSAONode::set_size(
  self : SSAONode,
  width : Double,
  height : Double,
) -> Unit {
  let width = @webgl.js_math_max(
    1,
    ssao_node_math_round(self.resolution_scale * width),
  )
  let height = @webgl.js_math_max(
    1,
    ssao_node_math_round(self.resolution_scale * height),
  )
  self.resolution.set(width, height) |> ignore
  self._ao_render_target.set_size(width.to_int(), height.to_int())
  self._blur_render_target.set_size(width.to_int(), height.to_int())
}

///|
fn ssao_node_uniform_vector2(node : @nodes.Node) -> @math.Vector2 {
  match @nodes.InputNode::get_value(node) {
    Vector2(v) => v
    _ => abort("uniform value is not a Vector2")
  }
}

///|
/// `new SSAONode( depthNode, normalNode, camera )`.
pub fn SSAONode::new(
  depth_node : @nodes.Node,
  normal_node : @nodes.Node,
  camera : @core.Object3D,
) -> @nodes.Node {
  display_ssao_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="float")
  node.update_before_type = @nodes.NodeUpdateType::frame()
  let radius = @nodes.uniform(0.5)
  let intensity = @nodes.uniform(1)
  let bias = @nodes.uniform(0.025)
  let samples = @nodes.uniform(16)
  let blur_sharpness = @nodes.uniform(2)
  let ao_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    format=@core.RedFormat,
  )
  ao_render_target.texture().name = "SSAONode.AO"
  let blur_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    format=@core.RedFormat,
  )
  blur_render_target.texture().name = "SSAONode.Blur"
  let camera_projection_matrix = @nodes.uniform(
    camera.as_camera().projection_matrix,
  )
  let camera_projection_matrix_inverse = @nodes.uniform(
    camera.as_camera().projection_matrix_inverse,
  )
  let camera_near = @nodes.reference("near", "float", object=Object3D(camera))
  let camera_far = @nodes.reference("far", "float", object=Object3D(camera))
  let blur_input = @nodes.texture(ao_render_target.texture())
  let blur_direction = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let ao_material = @nodes.NodeMaterial::new()
  ao_material.name = "SSAO.AO"
  let blur_material = @nodes.NodeMaterial::new()
  blur_material.name = "SSAO.Blur"
  let texture_node = @nodes.pass_texture(node, ao_render_target.texture())
  node.set_class(SSAONode::{
    depth_node,
    normal_node,
    resolution_scale: 0.5,
    radius,
    intensity,
    bias,
    samples,
    blur_enabled: true,
    blur_sharpness,
    resolution: @math.Vector2::new(0.0, 0.0),
    _ao_render_target: ao_render_target,
    _blur_render_target: blur_render_target,
    _camera_projection_matrix: camera_projection_matrix,
    _camera_projection_matrix_inverse: camera_projection_matrix_inverse,
    _camera_near: camera_near,
    _camera_far: camera_far,
    _camera: camera,
    _blur_input: blur_input,
    _blur_direction: blur_direction,
    _ao_material: ao_material,
    _blur_material: blur_material,
    _texture_node: texture_node,
  })
}

///|
pub fn SSAONode::of(node : @nodes.Node) -> SSAONode? {
  addon_class_of(node, "SSAONode")
}

///|
/// `ssao( depthNode, normalNode, camera )`.
pub fn ssao(
  depth_node : &@nodes.IntoTsl,
  normal_node : &@nodes.IntoTsl,
  camera : @core.Object3D,
) -> @nodes.Node {
  display_ssao_node_module.get() |> ignore
  SSAONode::new(
    addon_node_object(depth_node),
    addon_node_object(normal_node),
    camera,
  )
}
