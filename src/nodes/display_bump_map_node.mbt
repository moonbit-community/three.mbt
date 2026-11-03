// nodes/display/BumpMapNode.js
// Bump Mapping Unparametrized Surfaces on the GPU by Morten S. Mikkelsen
// https://mmikk.github.io/papers3d/mm_sfgrad_bump.pdf

///|
let _bump_map_node_dhdxy_fwd : Node = module_nodes(
  "nodes/display/BumpMapNode.js:dHdxy_fwd",
  fn() {
    fn_(fn(inputs, _) {
      let texture_node = inputs.named("textureNode").unwrap()
      let bump_scale = inputs.named("bumpScale").unwrap()
      // It's used to preserve the same TextureNode instance
      let sample_texture = fn(callback : (Node) -> Node) {
        let get_uv = ContextGetUV::{
          f: fn(tex_node, _) {
            callback(
              match TextureNode::of(tex_node) {
                Some(t) =>
                  match t.uv_node {
                    Some(u) => u
                    None => uv()
                  }
                None => uv()
              },
            )
          },
        }
        texture_node
        .isolate()
        .context(
          value=node_context([
            ("getUV", Other(@core.JsValue::of(get_uv))),
            ("forceUVContext", Bool(true)),
          ]),
        )
      }
      let hll = float(sample_texture(fn(uv_node) { uv_node }))
      Some(
        vec2_of([
          float(sample_texture(fn(uv_node) { uv_node.add(uv_node.d_fdx()) })).sub(
            hll,
          ),
          float(sample_texture(fn(uv_node) { uv_node.add(uv_node.d_fdy()) })).sub(
            hll,
          ),
        ]).mul(bump_scale),
      )
    })
  },
)

///|
// Evaluate the derivative of the height w.r.t. screen-space using forward differencing (listing 2)
let _bump_map_node_perturb_normal_arb : Node = module_nodes(
  "nodes/display/BumpMapNode.js:perturbNormalArb",
  fn() {
    fn_(fn(inputs, _) {
      let surf_pos = inputs.named("surf_pos").unwrap()
      let surf_norm = inputs.named("surf_norm").unwrap()
      let dhdxy = inputs.named("dHdxy").unwrap()
      // normalize is done to ensure that the bump map looks the same regardless of the texture's scale
      let v_sigma_x = surf_pos.d_fdx().normalize()
      let v_sigma_y = surf_pos.d_fdy().normalize()
      let v_n = surf_norm // normalized
      let r1 = v_sigma_y.cross(v_n)
      let r2 = v_n.cross(v_sigma_x)
      let f_det = v_sigma_x.dot(r1).mul(face_direction)
      let v_grad = f_det.sign().mul(dhdxy.x().mul(r1).add(dhdxy.y().mul(r2)))
      Some(f_det.abs().mul(surf_norm).sub(v_grad).normalize())
    })
  },
)

///|
/// Perturbs a normal by the derivatives of a height map.
pub(all) struct BumpMapNode {
  mut texture_node : Node
  /// `None` is `null` (a scale of 1).
  mut scale_node : Node?
  mut normal_node : Node
}

///|
pub impl NodeClass for BumpMapNode with fn class_name(_) {
  "BumpMapNode"
}

///|
pub impl NodeClass for BumpMapNode with fn children(self, _, out) {
  push_child(out, "textureNode", Some(self.texture_node))
  push_child(out, "scaleNode", self.scale_node)
  push_child(out, "normalNode", Some(self.normal_node))
}

///|
pub impl NodeClass for BumpMapNode with fn setup(self, _, builder) {
  // Screen-space derivatives are unreliable on thin lines, so the bump
  // effect is disabled for wireframe rendering.
  match builder.material {
    Some(m) if m.wireframe == Some(true) => return Some(self.normal_node)
    Some(_) => ()
    None =>
      abort("TypeError: Cannot read properties of null (reading 'wireframe')")
  }
  let bump_scale : &IntoTsl = match self.scale_node {
    Some(s) => s as &IntoTsl
    None => 1 as &IntoTsl
  }
  let dhdxy = _bump_map_node_dhdxy_fwd.call_named({
    "textureNode": self.texture_node,
    "bumpScale": bump_scale,
  })
  Some(
    _bump_map_node_perturb_normal_arb.call_named({
      "surf_pos": position_view,
      "surf_norm": self.normal_node,
      "dHdxy": dhdxy,
    }),
  )
}

///|
pub fn BumpMapNode::construct(
  _node : Node,
  texture_node : Node,
  scale_node : Node?,
  normal_node : Node,
) -> BumpMapNode {
  { texture_node, scale_node, normal_node, }
}

///|
/// `new BumpMapNode( textureNode, scaleNode = null, normalNode = normalView )`.
pub fn BumpMapNode::new(
  texture_node : Node,
  scale_node? : Node,
  normal_node? : Node,
) -> Node {
  let node = Node::alloc(node_type="vec3")
  node.set_class(
    BumpMapNode::construct(
      node,
      texture_node,
      scale_node,
      normal_node.unwrap_or(normal_view),
    ),
  )
}

///|
pub fn BumpMapNode::of(node : Node) -> BumpMapNode? {
  match node.class_payload("BumpMapNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `bumpMap( textureNode, scaleNode, normalNode )`.
pub fn bump_map(
  texture_node : &IntoTsl,
  scale_node? : &IntoTsl,
  normal_node? : &IntoTsl,
) -> Node {
  BumpMapNode::new(
    node_object(texture_node.to_tsl()),
    scale_node?=scale_node.map(fn(s) { node_object(s.to_tsl()) }),
    normal_node?=normal_node.map(fn(n) { node_object(n.to_tsl()) }),
  )
}
