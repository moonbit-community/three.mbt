// examples/jsm/tsl/display/AfterImageNode.js

///|
priv struct AfterImageNodeModule {
  _quad_mesh : @nodes.QuadMesh
}

///|
let _after_image_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let display_after_image_node_module : AddonModule[AfterImageNodeModule] = AddonModule::new(fn() {
    { _quad_mesh: @nodes.QuadMesh::new(), }
  },
)

///|
let _after_image_node_renderer_state : Ref[@nodes.RendererState?] = Ref(None)

///|
/// Evaluates AfterImageNode.js (its `_quadMesh`), as `import` does.
pub fn load_display_after_image_node() -> Unit {
  display_after_image_node_module.get() |> ignore
}

///|
/// Post processing node for creating an after image effect.
pub(all) struct AfterImageNode {
  /// The texture node that represents the input of the effect.
  mut texture_node : @nodes.Node
  /// How quickly the after-image fades (a node).
  mut damp : @nodes.Node
  mut _comp_rt : @core.RenderTarget
  mut _old_rt : @core.RenderTarget
  _texture_node : @nodes.Node
  _texture_node_old : @nodes.Node
  mut _material_composed : @core.Material?
}

///|
pub impl @nodes.NodeClass for AfterImageNode with fn class_name(_) {
  "AfterImageNode"
}

///|
pub impl @nodes.NodeClass for AfterImageNode with fn children(self, _, out) {
  @nodes.push_child(out, "textureNode", Some(self.texture_node))
  @nodes.push_child(out, "damp", Some(self.damp))
}

///|
pub impl @nodes.NodeClass for AfterImageNode with fn set_size(
  self,
  _,
  width,
  height,
) {
  self.set_size(width, height)
  true
}

///|
pub impl @nodes.NodeClass for AfterImageNode with fn update_before(
  self,
  _,
  frame,
) {
  let renderer = frame.renderer.unwrap()
  let quad_mesh = display_after_image_node_module.get()._quad_mesh
  _after_image_node_renderer_state.val = Some(
    @nodes.reset_renderer_state(
      renderer,
      state?=_after_image_node_renderer_state.val,
    ),
  )
  //
  let texture_node = self.texture_node
  let map = @nodes.TextureNode::get_value(texture_node)
  let texture_type = map.type_
  self._comp_rt.texture().type_ = texture_type
  self._old_rt.texture().type_ = texture_type
  renderer.get_drawing_buffer_size(_after_image_node_size) |> ignore
  self.set_size(_after_image_node_size.x, _after_image_node_size.y)
  // make sure texture nodes point to correct render targets
  @nodes.TextureNode::set_value(
    self._texture_node,
    Some(self._comp_rt.texture()),
  )
  @nodes.TextureNode::set_value(
    self._texture_node_old,
    Some(self._old_rt.texture()),
  )
  // composite
  quad_mesh.set_material(self._material_composed.unwrap())
  quad_mesh.object.name = "AfterImage"
  renderer.set_render_target(Some(self._comp_rt))
  quad_mesh.render(renderer)
  // swap
  let temp = self._old_rt
  self._old_rt = self._comp_rt
  self._comp_rt = temp
  //
  @nodes.restore_renderer_state(
    renderer,
    _after_image_node_renderer_state.val.unwrap(),
  )
  None
}

///|
/// `textureNode.sample()`: a copy of the texture node whose `uvNode` is `undefined` (the
/// texture's default uv).
fn after_image_node_sample_default(texture_node : @nodes.Node) -> @nodes.Node {
  let copy = @nodes.TextureNode::clone(texture_node)
  let t = @nodes.TextureNode::of(copy).unwrap()
  t.uv_node = None
  t.reference_node = Some(@nodes.TextureNode::get_base(texture_node))
  copy
}

///|
pub impl @nodes.NodeClass for AfterImageNode with fn setup(self, node, builder) {
  let texture_node = self.texture_node
  let texture_node_old = self._texture_node_old
  //
  @nodes.TextureNode::of(texture_node_old).unwrap().uv_node = Some(
    match addon_texture_uv_node(texture_node) {
      Some(u) => u
      None => @nodes.uv()
    },
  )
  let after_img = @nodes.fn_(fn(_, _) {
    let texel_old = after_image_node_sample_default(texture_node_old).to_var()
    let texel_new = after_image_node_sample_default(texture_node).to_var()
    let threshold = @nodes.float(0.1).to_const()
    // m acts as a mask. It's 1 if the previous pixel was "bright enough" (above the threshold) and 0 if it wasn't.
    let m = @nodes.max(@nodes.sign(texel_old.sub(threshold)), 0.0)
    // This is where the after-image fades:
    //
    // - If m is 0, texelOld is multiplied by 0, effectively clearing the after-image for that pixel.
    // - If m is 1, texelOld is multiplied by "damp". Since "damp" is between 0 and 1, this reduces the color value of
    // texelOld, making it darker and causing it to fade.
    texel_old.mul_assign(self.damp.mul(m))
    Some(@nodes.max(texel_new, texel_old))
  })
  //
  let material_composed = match self._material_composed {
    Some(m) => m
    None => {
      let m = @nodes.NodeMaterial::new()
      self._material_composed = Some(m)
      m
    }
  }
  material_composed.name = "AfterImage"
  @nodes.NodeMaterial::of(material_composed).unwrap().fragment_node = Some(
    after_img.call([]),
  )
  //
  let properties = builder.get_node_properties(node)
  properties.set_node("textureNode", texture_node)
  //
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for AfterImageNode with fn dispose(self, node) {
  node.dispose_base()
  self._comp_rt.dispose()
  self._old_rt.dispose()
  if self._material_composed is Some(m) {
    m.dispose()
  }
}

///|
/// `getTextureNode()`: the result of the effect.
pub fn AfterImageNode::get_texture_node(self : AfterImageNode) -> @nodes.Node {
  self._texture_node
}

///|
/// `setSize( width, height )`: the size of both internal render targets.
pub fn AfterImageNode::set_size(
  self : AfterImageNode,
  width : Double,
  height : Double,
) -> Unit {
  self._comp_rt.set_size(width.to_int(), height.to_int())
  self._old_rt.set_size(width.to_int(), height.to_int())
}

///|
/// `new AfterImageNode( textureNode, damp = float( 0.96 ) )`.
pub fn AfterImageNode::new(
  texture_node : @nodes.Node,
  damp? : @nodes.Node,
) -> @nodes.Node {
  display_after_image_node_module.get() |> ignore
  // the default parameter is evaluated before `super()`
  let damp = match damp {
    Some(d) => d
    None => @nodes.float(0.96)
  }
  let node = @nodes.Node::alloc(node_type="vec4")
  let comp_rt = @core.RenderTarget::new(width=1, height=1, depth_buffer=false)
  comp_rt.texture().name = "AfterImageNode.comp"
  let old_rt = @core.RenderTarget::new(width=1, height=1, depth_buffer=false)
  old_rt.texture().name = "AfterImageNode.old"
  let texture_node_ = @nodes.pass_texture(node, comp_rt.texture())
  let texture_node_old = @nodes.texture(old_rt.texture())
  node.update_before_type = @nodes.NodeUpdateType::frame()
  node.set_class(AfterImageNode::{
    texture_node,
    damp,
    _comp_rt: comp_rt,
    _old_rt: old_rt,
    _texture_node: texture_node_,
    _texture_node_old: texture_node_old,
    _material_composed: None,
  })
}

///|
pub fn AfterImageNode::of(node : @nodes.Node) -> AfterImageNode? {
  addon_class_of(node, "AfterImageNode")
}

///|
/// `afterImage( node, damp )`.
pub fn after_image(node : @nodes.Node, damp? : &@nodes.IntoTsl) -> @nodes.Node {
  let texture_node = @nodes.convert_to_texture(node)
  let damp = match damp {
    Some(d) =>
      match d.to_tsl() {
        Undefined => None
        v => Some(@nodes.node_object(v))
      }
    None => None
  }
  AfterImageNode::new(texture_node, damp?)
}
