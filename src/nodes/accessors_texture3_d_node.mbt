// nodes/accessors/Texture3DNode.js

///|
/// `normal( { texture, uv } )`: the gradient normal of a 3D texture.
let _texture3d_node_normal : Node = module_nodes(
  "nodes/accessors/Texture3DNode.js:normal",
  fn() {
    fn_(fn(inputs, _) {
      let texture = inputs.named("texture").unwrap()
      let uv = inputs.named("uv").unwrap()
      let epsilon = 0.0001
      let ret = vec3_of([]).to_var()
      if_(uv.x().less_than(epsilon), fn() { ret.assign(vec3_of([1, 0, 0])) })
      .else_if(uv.y().less_than(epsilon), fn() {
        ret.assign(vec3_of([0, 1, 0]))
      })
      .else_if(uv.z().less_than(epsilon), fn() {
        ret.assign(vec3_of([0, 0, 1]))
      })
      .else_if(uv.x().greater_than(1.0 - epsilon), fn() {
        ret.assign(vec3_of([-1, 0, 0]))
      })
      .else_if(uv.y().greater_than(1.0 - epsilon), fn() {
        ret.assign(vec3_of([0, -1, 0]))
      })
      .else_if(uv.z().greater_than(1.0 - epsilon), fn() {
        ret.assign(vec3_of([0, 0, -1]))
      })
      .else_(fn() {
        let step = 0.01
        let x = texture
          .sample(uv.add(vec3_of([-step, 0.0, 0.0])))
          .r()
          .sub(texture.sample(uv.add(vec3_of([step, 0.0, 0.0]))).r())
        let y = texture
          .sample(uv.add(vec3_of([0.0, -step, 0.0])))
          .r()
          .sub(texture.sample(uv.add(vec3_of([0.0, step, 0.0]))).r())
        let z = texture
          .sample(uv.add(vec3_of([0.0, 0.0, -step])))
          .r()
          .sub(texture.sample(uv.add(vec3_of([0.0, 0.0, step]))).r())
        ret.assign(vec3_of([x, y, z]))
      })
      Some(ret.normalize())
    })
  },
)

///|
pub(all) struct Texture3DNode {
  texture : TextureNode
}

///|
pub impl NodeClass for Texture3DNode with fn class_name(_) {
  "Texture3DNode"
}

///|
pub impl NodeClass for Texture3DNode with fn parent(self) {
  Some(self.texture)
}

///|
pub impl NodeClass for Texture3DNode with fn has_flag(self, flag) {
  flag == "isTexture3DNode" || self.texture.has_flag(flag)
}

///|
pub impl InputNodeClass for Texture3DNode with fn input_parent(self) {
  Some(self.texture)
}

///|
pub impl InputNodeClass for Texture3DNode with fn get_input_type(_, _, _) {
  Some("texture3D")
}

///|
pub impl TextureNodeClass for Texture3DNode with fn texture_parent(self) {
  Some(self.texture)
}

///|
pub impl TextureNodeClass for Texture3DNode with fn get_default_uv(_, _) {
  vec3_of([0.5, 0.5, 0.5])
}

///|
/// Ignores `.updateMatrix`.
pub impl TextureNodeClass for Texture3DNode with fn set_update_matrix(_, _, _) {

}

///|
pub impl TextureNodeClass for Texture3DNode with fn generate_uv(
  self,
  _,
  builder,
  uv_node,
) {
  uv_node.build(
    builder,
    output=if self.texture.sampler { "vec3" } else { "ivec3" },
  )
}

///|
pub impl TextureNodeClass for Texture3DNode with fn generate_offset(
  _,
  _,
  builder,
  offset_node,
) {
  offset_node.build(builder, output="ivec3")
}

///|
pub impl TextureNodeClass for Texture3DNode with fn construct_like(
  _,
  value,
  uv_node,
  level_node,
  _,
) {
  // `new this.constructor( value, uvNode, levelNode, biasNode )`: the constructor
  // takes no bias.
  Texture3DNode::new(value, uv_node?, level_node?)
}

///|
/// The constructor body.
pub fn Texture3DNode::construct(
  node : Node,
  value : @core.Texture?,
  uv_node : Node?,
  level_node : Node?,
) -> Texture3DNode {
  let texture = TextureNode::construct(node, value, uv_node, level_node, None)
  // `setUpdateMatrix` is a no-op here, so `updateMatrix` keeps its `false`.
  texture.update_matrix = false
  { texture, }
}

///|
/// `new Texture3DNode( value, uvNode = null, levelNode = null )`.
pub fn Texture3DNode::new(
  value : @core.Texture?,
  uv_node? : Node,
  level_node? : Node,
) -> Node {
  let node = Node::alloc()
  let t = Texture3DNode::construct(node, value, uv_node, level_node)
  t.texture.install(node, t, t, t)
}

///|
pub fn Texture3DNode::of(node : Node) -> Texture3DNode? {
  match node.class_payload("Texture3DNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `normal( uvNode )`: the gradient normal at `uvNode`.
pub fn Node::normal(self : Node, uv_node : &IntoTsl) -> Node {
  match Texture3DNode::of(self) {
    Some(_) => ()
    None => abort("TypeError: \{self.type_()}.normal is not a function")
  }
  _texture3d_node_normal.call_named({ "texture": self, "uv": uv_node })
}

///|
/// `texture3D( value, uvNode, levelNode )`.
pub fn texture3d(
  value : &IntoTsl,
  uv_node? : &IntoTsl,
  level_node? : &IntoTsl,
) -> Node {
  Texture3DNode::new(
    texture_node_texture_arg(value.to_tsl()),
    uv_node?=texture_node_node_arg(texture_node_opt_arg(uv_node)),
    level_node?=texture_node_node_arg(texture_node_opt_arg(level_node)),
  )
}

///|
/// `texture3DLoad( ...params )`.
pub fn texture3d_load(
  value : &IntoTsl,
  uv_node? : &IntoTsl,
  level_node? : &IntoTsl,
) -> Node {
  texture3d(value, uv_node?, level_node?).set_sampler(false)
}

///|
/// `texture3DLevel( value, uvNode, levelNode )`.
pub fn texture3d_level(
  value : &IntoTsl,
  uv_node : &IntoTsl,
  level_node : &IntoTsl,
) -> Node {
  texture3d(value, uv_node~).level(level_node)
}
