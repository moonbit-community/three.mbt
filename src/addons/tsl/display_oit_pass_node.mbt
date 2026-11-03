// examples/jsm/tsl/display/OITPassNode.js

///|
let _oit_pass_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _oit_pass_node_renderer_state : Ref[@nodes.RendererState?] = Ref(None)

///|
let _oit_pass_node_scene_state : Ref[@nodes.RendererState?] = Ref(None)

///|
/// Evaluates OITPassNode.js (no module-level nodes), as `import` does.
pub fn load_display_oit_pass_node() -> Unit {
  ()
}

///|
/// A render pass with Weighted Blended Order-Independent Transparency (McGuire and
/// Bavoil): OIT-qualified transparent objects accumulate into `_oit_render_target`.
pub(all) struct OITPassNode {
  pass : @nodes.PassNode
  /// The depth-based weight of a transparent fragment; `None` uses equation (9).
  mut weight_node : @nodes.Node?
  _oit_render_target : @core.RenderTarget
  mut _oit_mrt_node : @nodes.Node?
  /// The renderer of the current frame (`_renderer`), read by the render functions.
  _renderer : Ref[@nodes.Renderer?]
  _default_render_object_function : @nodes.RenderObjectFunction
  _oit_render_object_function : @nodes.RenderObjectFunction
}

///|
pub impl @nodes.NodeClass for OITPassNode with fn class_name(_) {
  "OITPassNode"
}

///|
pub impl @nodes.NodeClass for OITPassNode with fn parent(self) {
  Some(self.pass)
}

///|
pub impl @nodes.NodeClass for OITPassNode with fn has_flag(self, flag) {
  flag == "isOITPassNode" || self.pass.has_flag(flag)
}

///|
pub impl @nodes.NodeClass for OITPassNode with fn children(self, node, out) {
  self.pass.children(node, out)
  @nodes.push_child(out, "weightNode", self.weight_node)
}

///|
/// `_getMRTNode()`: the MRT configuration of the OIT pass (created once).
pub fn OITPassNode::_get_mrt_node(self : OITPassNode) -> @nodes.Node {
  match self._oit_mrt_node {
    Some(mrt) => mrt
    None => {
      let alpha = @nodes.output.a()
      let weight = match self.weight_node {
        Some(w) => w
        None => {
          // equation (9) from the paper, based on the linear eye-space depth
          let z = @nodes.position_view.z().negate()
          alpha.mul(
            @nodes.float(0.03)
            .div(z.div(200).pow(4).add(1.0e-5))
            .clamp(low=1.0e-2, high=3.0e3),
          )
        }
      }
      // since the revealage target is single-channel, the alpha must be blended
      // via its red channel
      let accum_blending = @nodes.BlendMode::new(blending=@core.CustomBlending)
      accum_blending.blend_src = @core.OneFactor
      accum_blending.blend_dst = @core.OneFactor
      let revealage_blending = @nodes.BlendMode::new(
        blending=@core.CustomBlending,
      )
      revealage_blending.blend_src = @core.ZeroFactor
      revealage_blending.blend_dst = @core.OneMinusSrcColorFactor
      let mrt = @nodes.mrt(
          Map::from_array([
            (
              "accum",
              @nodes.vec4_of([@nodes.output.rgb().mul(alpha), alpha]).mul(
                weight,
              ),
            ),
            ("revealage", alpha),
          ]),
        )
        .set_blend_mode("accum", accum_blending)
        .set_blend_mode("revealage", revealage_blending)
        .set_clear_color("accum", @math.Color::from_hex(0x000000), alpha=0.0)
        .set_clear_color(
          "revealage",
          @math.Color::from_hex(0xffffff),
          alpha=1.0,
        )
      self._oit_mrt_node = Some(mrt)
      mrt
    }
  }
}

///|
pub impl @nodes.PassNodeClass for OITPassNode with fn set_size(
  self,
  node,
  width,
  height,
) {
  @nodes.PassNode::set_size_base(node, width, height)
  self._oit_render_target.set_size(
    self.pass.render_target.width,
    self.pass.render_target.height,
  )
}

///|
pub impl @nodes.NodeClass for OITPassNode with fn setup(self, node, builder) {
  let beauty_node = self.pass.setup(node, builder).unwrap()
  // MSAA
  if builder.renderer.backend.has_flag("isWebGPUBackend") == true {
    // sample counts must match since the depth buffer is shared
    self._oit_render_target.samples = self.pass.render_target.samples
  } else {
    // The WebGL backend does not support depth texture sharing with MSAA unless
    // WEBGL_multisampled_render_to_texture is supported (which isn't available on most devices)
    self.pass.render_target.samples = 0
  }
  // TSL
  let accum_node = @nodes.texture(self._oit_render_target.textures[0])
  let revealage_node = @nodes.texture(self._oit_render_target.textures[1]).r()
  let accum_color = accum_node.rgb().div(accum_node.a().max(1.0e-5))
  Some(
    @nodes.vec4_of([
      @nodes.mix(accum_color, beauty_node.rgb(), revealage_node),
      beauty_node.a(),
    ]),
  )
}

///|
pub impl @nodes.NodeClass for OITPassNode with fn update_before(
  self,
  node,
  frame,
) {
  let renderer = frame.renderer.unwrap()
  let scene = self.pass.scene
  let camera = self.pass.camera
  self._renderer.val = Some(renderer)
  renderer.get_drawing_buffer_size(_oit_pass_node_size) |> ignore
  node.set_size(_oit_pass_node_size.x, _oit_pass_node_size.y)
  _oit_pass_node_renderer_state.val = Some(
    @nodes.save_renderer_state(
      renderer,
      state?=_oit_pass_node_renderer_state.val,
    ),
  )
  let current_mask = camera.layers.mask
  @nodes.InputNode::set_value(
    self.pass._camera_near,
    Number(@nodes.camera_near_of(camera)),
  )
  @nodes.InputNode::set_value(
    self.pass._camera_far,
    Number(@nodes.camera_far_of(camera)),
  )
  if self.pass._layers is Some(layers) {
    camera.layers.mask = layers.mask
  }
  renderer.auto_clear = self.pass.auto_clear
  renderer.auto_clear_color = self.pass.auto_clear_color
  renderer.auto_clear_depth = self.pass.auto_clear_depth
  renderer.auto_clear_stencil = self.pass.auto_clear_stencil
  // default pass: opaque objects and transparent objects that do not qualify for OIT
  renderer.set_mrt(self.pass._mrt) |> ignore
  renderer.set_render_target(Some(self.pass.render_target))
  renderer.set_render_object_function(
    Some(self._default_render_object_function),
  )
  renderer.render(scene, camera)
  // OIT pass: accumulate the weighted colors and the revealage of all OIT-qualified objects
  _oit_pass_node_scene_state.val = Some(
    @nodes.reset_scene_state(scene, state?=_oit_pass_node_scene_state.val),
  ) // the background must not affect the accumulation targets
  renderer.set_render_target(Some(self._oit_render_target))
  renderer.set_mrt(Some(self._get_mrt_node())) |> ignore
  renderer.set_render_object_function(Some(self._oit_render_object_function))
  renderer.auto_clear_depth = false // the depth buffer is shared with the default pass
  renderer.opaque_ = false
  renderer.transparent = true
  renderer.render(scene, camera)
  // restore
  @nodes.restore_scene_state(scene, _oit_pass_node_scene_state.val.unwrap())
  @nodes.restore_renderer_state(
    renderer,
    _oit_pass_node_renderer_state.val.unwrap(),
  )
  camera.layers.mask = current_mask
  self._renderer.val = None
  None
}

///|
pub impl @nodes.NodeClass for OITPassNode with fn dispose(self, node) {
  self.pass.dispose(node)
  self._oit_render_target.dispose()
}

///|
/// Whether `material` qualifies for OIT (`isOITCapable( material )`).
fn oit_pass_node_is_oit_capable(material : @core.Material) -> Bool {
  material.transparent == true &&
  material.blending == @core.NormalBlending &&
  (match material.transmission() {
    Some(t) => t > 0.0
    None => false
  }) ==
  false &&
  !(match @nodes.MeshPhysicalNodeMaterial::of(material) {
    Some(p) => p.transmission_node is Some(_)
    None => false
  }) &&
  !(match @nodes.NodeMaterial::of(material) {
    Some(n) => n.backdrop_node is Some(_)
    None => false
  })
}

///|
/// The constructor body (after `Node::alloc(node_type="vec4")`).
pub fn OITPassNode::construct(
  node : @nodes.Node,
  scene : @core.Object3D,
  camera : @core.Object3D,
  options : @nodes.PassNodeOptions,
) -> OITPassNode {
  let pass = @nodes.PassNode::construct(
    node,
    @nodes.PassNode::color(),
    scene,
    camera,
    options,
  )
  // the accumulation target shares the depth of the default pass so transparent
  // fragments are depth-tested against the opaque scene (without depth writes)
  let oit_render_target = @core.RenderTarget::new(width=1, height=1, count=2)
  oit_render_target.set_depth_texture(pass.render_target.depth_texture())
  let accum_texture = oit_render_target.textures[0] // RGBA16
  accum_texture.name = "accum"
  accum_texture.type_ = @core.HalfFloatType
  let revealage_texture = oit_render_target.textures[1] // R8
  revealage_texture.name = "revealage"
  revealage_texture.format = @core.RedFormat
  revealage_texture.type_ = @core.UnsignedByteType
  let renderer : Ref[@nodes.Renderer?] = Ref(None)
  // Renders opaque objects and transparent objects that do not qualify for OIT.
  let default_render_object_function = @nodes.RenderObjectFunction::{
    f: fn(
      object,
      scene,
      camera,
      geometry,
      material,
      group,
      lights_node,
      clipping_context,
      pass_id,
    ) {
      if oit_pass_node_is_oit_capable(material) == false {
        renderer.val
        .unwrap()
        .render_object(
          object, scene, camera, geometry, material, group, lights_node, clipping_context,
          pass_id,
        )
      }
    },
  }
  // Renders OIT-qualified objects into the accumulation targets.
  let oit_render_object_function = @nodes.RenderObjectFunction::{
    f: fn(
      object,
      scene,
      camera,
      geometry,
      material,
      group,
      lights_node,
      clipping_context,
      pass_id,
    ) {
      if oit_pass_node_is_oit_capable(material) == true {
        let current_depth_write = material.depth_write
        material.depth_write = false
        renderer.val
        .unwrap()
        .render_object(
          object, scene, camera, geometry, material, group, lights_node, clipping_context,
          pass_id,
        )
        material.depth_write = current_depth_write
      }
    },
  }
  let p = OITPassNode::{
    pass,
    weight_node: None,
    _oit_render_target: oit_render_target,
    _oit_mrt_node: None,
    _renderer: renderer,
    _default_render_object_function: default_render_object_function,
    _oit_render_object_function: oit_render_object_function,
  }
  p.pass.pass_class = p
  p
}

///|
/// `new OITPassNode( scene, camera, options )`.
pub fn OITPassNode::new(
  scene : @core.Object3D,
  camera : @core.Object3D,
  options~ : @nodes.PassNodeOptions = @nodes.PassNodeOptions::default(),
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  node.set_class(OITPassNode::construct(node, scene, camera, options))
}

///|
pub fn OITPassNode::of(node : @nodes.Node) -> OITPassNode? {
  addon_class_of(node, "OITPassNode")
}

///|
/// `oitPass( scene, camera, options )`: renders `scene` with Order-Independent
/// Transparency.
pub fn oit_pass(
  scene : @core.Object3D,
  camera : @core.Object3D,
  options~ : @nodes.PassNodeOptions = @nodes.PassNodeOptions::default(),
) -> @nodes.Node {
  OITPassNode::new(scene, camera, options~)
}
