// examples/jsm/tsl/display/DepthOfFieldNode.js

///|
extern "js" fn depth_of_field_node_math_round(x : Double) -> Double = "Math.round"

///|
extern "js" fn depth_of_field_node_math_sqrt(x : Double) -> Double = "Math.sqrt"

///|
extern "js" fn depth_of_field_node_math_cos(x : Double) -> Double = "Math.cos"

///|
extern "js" fn depth_of_field_node_math_sin(x : Double) -> Double = "Math.sin"

///|
/// The module's top-level state: `_quadMesh` and `_rendererState`.
priv struct DepthOfFieldNodeModule {
  quad_mesh : @nodes.QuadMesh
  mut renderer_state : @nodes.RendererState?
}

///|
let depth_of_field_node_module : AddonModule[DepthOfFieldNodeModule] = AddonModule::new(fn() {
    // import { gaussianBlur } from './GaussianBlurNode.js'
    load_display_gaussian_blur_node()
    { quad_mesh: @nodes.QuadMesh::new(), renderer_state: None, }
  },
)

///|
/// Evaluates DepthOfFieldNode.js's top-level statements (`import`), after its import of
/// GaussianBlurNode.js.
pub fn load_display_depth_of_field_node() -> Unit {
  depth_of_field_node_module.get() |> ignore
}

///|
/// Post processing node for depth of field: a circle of confusion pass, bokeh blurs of
/// the near and far fields at half resolution and a composite.
pub(all) struct DepthOfFieldNode {
  mut texture_node : @nodes.Node
  mut view_z_node : @nodes.Node
  mut focus_distance_node : @nodes.Node
  mut focal_length_node : @nodes.Node
  mut bokeh_scale_node : @nodes.Node
  _inv_size : @nodes.Node
  _coc_rt : @core.RenderTarget
  _coc_blurred_rt : @core.RenderTarget
  _blur64_rt : @core.RenderTarget
  _blur16_near_rt : @core.RenderTarget
  _blur16_far_rt : @core.RenderTarget
  _composite_rt : @core.RenderTarget
  _coc_material : @core.Material
  _coc_blurred_material : @core.Material
  _blur64_material : @core.Material
  _blur16_material : @core.Material
  _composite_material : @core.Material
  _texture_node : @nodes.Node
  _coc_texture_node : @nodes.Node
  _coc_blur_node : @nodes.Node
  _blur64_texture_node : @nodes.Node
  _blur16_near_texture_node : @nodes.Node
  _blur16_far_texture_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for DepthOfFieldNode with fn class_name(_) {
  "DepthOfFieldNode"
}

///|
pub impl @nodes.NodeClass for DepthOfFieldNode with fn children(self, _, out) {
  @nodes.push_child(out, "textureNode", Some(self.texture_node))
  @nodes.push_child(out, "viewZNode", Some(self.view_z_node))
  @nodes.push_child(out, "focusDistanceNode", Some(self.focus_distance_node))
  @nodes.push_child(out, "focalLengthNode", Some(self.focal_length_node))
  @nodes.push_child(out, "bokehScaleNode", Some(self.bokeh_scale_node))
}

///|
/// `setSize( width, height )`: the full resolution targets and the half resolution blur
/// targets.
pub fn DepthOfFieldNode::set_size(
  self : DepthOfFieldNode,
  width : Double,
  height : Double,
) -> Unit {
  a4_uniform_vector2(self._inv_size).set(1.0 / width, 1.0 / height) |> ignore
  self._coc_rt.set_size(width.to_int(), height.to_int())
  self._composite_rt.set_size(width.to_int(), height.to_int())
  // blur runs in half resolution
  let half_res_x = depth_of_field_node_math_round(width / 2.0).to_int()
  let half_res_y = depth_of_field_node_math_round(height / 2.0).to_int()
  self._coc_blurred_rt.set_size(half_res_x, half_res_y)
  self._blur64_rt.set_size(half_res_x, half_res_y)
  self._blur16_near_rt.set_size(half_res_x, half_res_y)
  self._blur16_far_rt.set_size(half_res_x, half_res_y)
}

///|
/// `getTextureNode()`: the composite result.
pub fn DepthOfFieldNode::get_texture_node(
  self : DepthOfFieldNode,
) -> @nodes.Node {
  self._texture_node
}

///|
pub impl @nodes.NodeClass for DepthOfFieldNode with fn update_before(
  self,
  _,
  frame,
) {
  let renderer = frame.renderer.unwrap()
  let m = depth_of_field_node_module.get()
  // resize
  let map = @nodes.TextureNode::get_value(self.texture_node)
  self.set_size(map.image().width(), map.image().height())
  // save state
  m.renderer_state = Some(
    @nodes.reset_renderer_state(renderer, state?=m.renderer_state),
  )
  renderer.set_clear_color_hex(0x000000, alpha=0.0)
  let quad_mesh = m.quad_mesh
  // coc
  quad_mesh.set_material(self._coc_material)
  renderer.set_render_target(Some(self._coc_rt))
  quad_mesh.object.name = "DoF [ CoC ]"
  quad_mesh.render(renderer)
  // blur near field to avoid visible aliased edges when the near field
  // is blended with the background
  @nodes.TextureNode::set_value(
    self._coc_texture_node,
    Some(self._coc_rt.textures[0]),
  )
  quad_mesh.set_material(self._coc_blurred_material)
  renderer.set_render_target(Some(self._coc_blurred_rt))
  quad_mesh.object.name = "DoF [ CoC Blur ]"
  quad_mesh.render(renderer)
  // blur64 near
  @nodes.TextureNode::set_value(
    self._coc_texture_node,
    Some(self._coc_blurred_rt.texture()),
  )
  quad_mesh.set_material(self._blur64_material)
  renderer.set_render_target(Some(self._blur64_rt))
  quad_mesh.object.name = "DoF [ Blur64 Near ]"
  quad_mesh.render(renderer)
  // blur16 near
  quad_mesh.set_material(self._blur16_material)
  renderer.set_render_target(Some(self._blur16_near_rt))
  quad_mesh.object.name = "DoF [ Blur16 Near ]"
  quad_mesh.render(renderer)
  // blur64 far
  @nodes.TextureNode::set_value(
    self._coc_texture_node,
    Some(self._coc_rt.textures[1]),
  )
  quad_mesh.set_material(self._blur64_material)
  renderer.set_render_target(Some(self._blur64_rt))
  quad_mesh.object.name = "DoF [ Blur64 Far ]"
  quad_mesh.render(renderer)
  // blur16 far
  quad_mesh.set_material(self._blur16_material)
  renderer.set_render_target(Some(self._blur16_far_rt))
  quad_mesh.object.name = "DoF [ Blur16 Far ]"
  quad_mesh.render(renderer)
  // composite
  quad_mesh.set_material(self._composite_material)
  renderer.set_render_target(Some(self._composite_rt))
  quad_mesh.object.name = "DoF [ Composite ]"
  quad_mesh.render(renderer)
  // restore
  @nodes.restore_renderer_state(renderer, m.renderer_state.unwrap())
  None
}

///|
pub impl @nodes.NodeClass for DepthOfFieldNode with fn setup(self, _, builder) {
  let shared_context = @nodes.context(value=builder.get_shared_context())
  let (points16, points64) = DepthOfFieldNode::generate_kernels()
  // CoC, near and far fields
  let near_field = @nodes.property("float")
  let far_field = @nodes.property("float")
  let output_node = @nodes.output_struct([near_field, far_field])
  let coc = @nodes.fn_(fn(_, _) {
    let signed_dist = self.view_z_node.negate().sub(self.focus_distance_node)
    let coc = @nodes.smoothstep(0, self.focal_length_node, signed_dist.abs())
    near_field.assign(@nodes.step(signed_dist, 0).mul(coc))
    far_field.assign(@nodes.step(0, signed_dist).mul(coc))
    Some(@nodes.float(0))
  })
  let coc_material = @nodes.NodeMaterial::of(self._coc_material).unwrap()
  coc_material.context_node = Some(shared_context)
  coc_material.color_node = Some(coc.call([]))
  coc_material.output_node = Some(output_node)
  self._coc_material.set_needs_update(true)
  // blurred CoC for near field
  @nodes.NodeMaterial::of(self._coc_blurred_material).unwrap().color_node = Some(
    self._coc_blur_node,
  )
  self._coc_blurred_material.set_needs_update(true)
  // bokeh 64 blur pass
  let bokeh64 = @nodes.uniform_array(
    @nodes.TslValue::Array(points64.map(fn(p) { Vector2(p) })),
  )
  let blur64 = @nodes.fn_(fn(_, _) {
    let acc = @nodes.vec3_of([])
    let uv_node = @nodes.uv()
    let coc = self._coc_texture_node.sample(uv_node).r()
    let sample_step = self._inv_size.mul(self.bokeh_scale_node).mul(coc)
    @nodes.loop_([64], fn(inputs) {
      let i = inputs.named("i").unwrap()
      let s_uv = uv_node.add(sample_step.mul(bokeh64.element(i)))
      let tap = self.texture_node.sample(s_uv)
      acc.add_assign(tap.rgb())
    })
    acc.div_assign(64)
    Some(@nodes.vec4_of([acc, coc]))
  })
  let blur64_material = @nodes.NodeMaterial::of(self._blur64_material).unwrap()
  blur64_material.context_node = Some(shared_context)
  blur64_material.fragment_node = Some(blur64.call([]))
  self._blur64_material.set_needs_update(true)
  // bokeh 16 blur pass
  let bokeh16 = @nodes.uniform_array(
    @nodes.TslValue::Array(points16.map(fn(p) { Vector2(p) })),
  )
  let blur16 = @nodes.fn_(fn(_, _) {
    let uv_node = @nodes.uv()
    let col = self._blur64_texture_node.sample(uv_node).to_var()
    let max_val = col.rgb()
    let coc = col.a()
    let sample_step = self._inv_size.mul(self.bokeh_scale_node).mul(coc)
    @nodes.loop_([16], fn(inputs) {
      let i = inputs.named("i").unwrap()
      let s_uv = uv_node.add(sample_step.mul(bokeh16.element(i)))
      let tap = self._blur64_texture_node.sample(s_uv)
      max_val.assign(@nodes.max(tap.rgb(), max_val))
    })
    Some(@nodes.vec4_of([max_val, coc]))
  })
  let blur16_material = @nodes.NodeMaterial::of(self._blur16_material).unwrap()
  blur16_material.context_node = Some(shared_context)
  blur16_material.fragment_node = Some(blur16.call([]))
  self._blur16_material.set_needs_update(true)
  // composite
  let composite = @nodes.fn_(fn(_, _) {
    let uv_node = @nodes.uv()
    let near = self._blur16_near_texture_node.sample(uv_node)
    let far = self._blur16_far_texture_node.sample(uv_node)
    let beauty = self.texture_node.sample(uv_node)
    // TODO: applying the bokeh scale to the near field CoC value introduces blending
    // issues around edges of blurred foreground objects when their are rendered above
    // the background. for now, don't apply the bokeh scale to the blend factors. that
    // will cause less blur for objects which are partly out-of-focus (CoC between 0 and 1).
    let blend_near = @nodes.min(near.a(), 0.5).mul(2)
    let blend_far = @nodes.min(far.a(), 0.5).mul(2)
    let result = @nodes.vec4_of([0, 0, 0, 1]).to_var()
    result.rgb().assign(@nodes.mix(beauty.rgb(), far.rgb(), blend_far))
    result.rgb().assign(@nodes.mix(result.rgb(), near.rgb(), blend_near))
    Some(result)
  })
  let composite_material = @nodes.NodeMaterial::of(self._composite_material).unwrap()
  composite_material.context_node = Some(shared_context)
  composite_material.fragment_node = Some(composite.call([]))
  self._composite_material.set_needs_update(true)
  Some(self._texture_node)
}

///|
/// `_generateKernels()`: Vogel disc sample points, 16 and 64 of them.
fn DepthOfFieldNode::generate_kernels() -> (
  Array[@math.Vector2],
  Array[@math.Vector2],
) {
  // Vogel's method, see https://www.shadertoy.com/view/4fBXRG
  // this approach allows to generate uniformly distributed sample
  // points in a disc-shaped pattern. Blurring with these samples
  // produces a typical optical lens blur
  let golden_angle = 2.39996323
  let samples = 80
  let points64 = []
  let points16 = []
  for i in 0..<samples {
    let theta = i.to_double() * golden_angle
    let r = depth_of_field_node_math_sqrt(i.to_double()) /
      depth_of_field_node_math_sqrt(samples.to_double())
    let p = @math.Vector2::new(
      r * depth_of_field_node_math_cos(theta),
      r * depth_of_field_node_math_sin(theta),
    )
    if i % 5 == 0 {
      points16.push(p)
    } else {
      points64.push(p)
    }
  }
  (points16, points64)
}

///|
pub impl @nodes.NodeClass for DepthOfFieldNode with fn dispose(self, node) {
  node.dispose_base()
  self._coc_rt.dispose()
  self._coc_blurred_rt.dispose()
  self._blur64_rt.dispose()
  self._blur16_near_rt.dispose()
  self._blur16_far_rt.dispose()
  self._composite_rt.dispose()
  self._coc_material.dispose()
  self._coc_blurred_material.dispose()
  self._blur64_material.dispose()
  self._blur16_material.dispose()
  self._composite_material.dispose()
  self._coc_blur_node.dispose()
}

///|
/// `new DepthOfFieldNode( textureNode, viewZNode, focusDistanceNode, focalLengthNode,
/// bokehScaleNode )`.
pub fn DepthOfFieldNode::new(
  texture_node : @nodes.Node,
  view_z_node : @nodes.Node,
  focus_distance_node : @nodes.Node,
  focal_length_node : @nodes.Node,
  bokeh_scale_node : @nodes.Node,
) -> @nodes.Node {
  depth_of_field_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="vec4")
  let _inv_size = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let _coc_rt = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
    format=@core.RedFormat,
    count=2,
  )
  _coc_rt.textures[0].name = "DepthOfField.NearField"
  _coc_rt.textures[1].name = "DepthOfField.FarField"
  let _coc_blurred_rt = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
    format=@core.RedFormat,
  )
  _coc_blurred_rt.texture().name = "DepthOfField.NearFieldBlurred"
  let _blur64_rt = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  _blur64_rt.texture().name = "DepthOfField.Blur64"
  let _blur16_near_rt = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  _blur16_near_rt.texture().name = "DepthOfField.Blur16Near"
  let _blur16_far_rt = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  _blur16_far_rt.texture().name = "DepthOfField.Blur16Far"
  let _composite_rt = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  _composite_rt.texture().name = "DepthOfField.Composite"
  let _coc_material = @nodes.NodeMaterial::new()
  let _coc_blurred_material = @nodes.NodeMaterial::new()
  let _blur64_material = @nodes.NodeMaterial::new()
  let _blur16_material = @nodes.NodeMaterial::new()
  let _composite_material = @nodes.NodeMaterial::new()
  let _texture_node = @nodes.texture(_composite_rt.texture())
  let _coc_texture_node = @nodes.texture(_coc_rt.texture())
  let _coc_blur_node = gaussian_blur(
    _coc_texture_node,
    direction_node=1,
    sigma=2,
  )
  let _blur64_texture_node = @nodes.texture(_blur64_rt.texture())
  let _blur16_near_texture_node = @nodes.texture(_blur16_near_rt.texture())
  let _blur16_far_texture_node = @nodes.texture(_blur16_far_rt.texture())
  node.update_before_type = @nodes.NodeUpdateType::frame()
  node.set_class(DepthOfFieldNode::{
    texture_node,
    view_z_node,
    focus_distance_node,
    focal_length_node,
    bokeh_scale_node,
    _inv_size,
    _coc_rt,
    _coc_blurred_rt,
    _blur64_rt,
    _blur16_near_rt,
    _blur16_far_rt,
    _composite_rt,
    _coc_material,
    _coc_blurred_material,
    _blur64_material,
    _blur16_material,
    _composite_material,
    _texture_node,
    _coc_texture_node,
    _coc_blur_node,
    _blur64_texture_node,
    _blur16_near_texture_node,
    _blur16_far_texture_node,
  })
}

///|
pub fn DepthOfFieldNode::of(node : @nodes.Node) -> DepthOfFieldNode? {
  addon_class_of(node, "DepthOfFieldNode")
}

///|
/// `dof( node, viewZNode, focusDistance = 1, focalLength = 1, bokehScale = 1 )`.
pub fn dof(
  node : @nodes.Node,
  view_z_node : &@nodes.IntoTsl,
  focus_distance? : &@nodes.IntoTsl,
  focal_length? : &@nodes.IntoTsl,
  bokeh_scale? : &@nodes.IntoTsl,
) -> @nodes.Node {
  let texture_node = @nodes.convert_to_texture(node)
  let view_z_node = @nodes.node_object(view_z_node.to_tsl())
  let focus_distance = a4_node_object_or(focus_distance, Number(1.0))
  let focal_length = a4_node_object_or(focal_length, Number(1.0))
  let bokeh_scale = a4_node_object_or(bokeh_scale, Number(1.0))
  DepthOfFieldNode::new(
    texture_node, view_z_node, focus_distance, focal_length, bokeh_scale,
  )
}
