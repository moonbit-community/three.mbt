// examples/jsm/tsl/display/PixelationPassNode.js

///|
/// A pixelation pass: renders the scene at a reduced resolution (with nearest
/// filtering) and draws depth and normal based edges.
pub(all) struct PixelationPassNode {
  pass : @nodes.PassNode
  mut pixel_size : Double
  mut normal_edge_strength : @nodes.Node
  mut depth_edge_strength : @nodes.Node
}

///|
pub impl @nodes.NodeClass for PixelationPassNode with fn class_name(_) {
  "PixelationPassNode"
}

///|
pub impl @nodes.NodeClass for PixelationPassNode with fn parent(self) {
  Some(self.pass)
}

///|
pub impl @nodes.NodeClass for PixelationPassNode with fn has_flag(self, flag) {
  flag == "isPixelationPassNode" || self.pass.has_flag(flag)
}

///|
pub impl @nodes.NodeClass for PixelationPassNode with fn children(
  self,
  node,
  out,
) {
  self.pass.children(node, out)
  @nodes.push_child(out, "normalEdgeStrength", Some(self.normal_edge_strength))
  @nodes.push_child(out, "depthEdgeStrength", Some(self.depth_edge_strength))
}

///|
pub impl @nodes.PassNodeClass for PixelationPassNode with fn set_size(
  self,
  node,
  width,
  height,
) {
  let adjusted_width = (width / self.pixel_size).floor()
  let adjusted_height = (height / self.pixel_size).floor()
  @nodes.PassNode::set_size_base(node, adjusted_width, adjusted_height)
}

///|
pub impl @nodes.NodeClass for PixelationPassNode with fn setup(self, node, _) {
  let texture_node = node.get_texture_node(name="output")
  let depth_node = node.get_texture_node(name="depth")
  let normal_node = node.get_texture_node(name="normal")
  let uv_node_texture = match a4_texture_uv_node(texture_node) {
    Some(n) => n
    None => @nodes.uv()
  }
  let uv_node_depth = match a4_texture_uv_node(depth_node) {
    Some(n) => n
    None => @nodes.uv()
  }
  let uv_node_normal = match a4_texture_uv_node(normal_node) {
    Some(n) => n
    None => @nodes.uv()
  }
  let sample_texture = fn() { texture_node.sample(uv_node_texture) }
  let sample_depth = fn(uv : @nodes.Node) { depth_node.sample(uv).r() }
  let sample_normal = fn(uv : @nodes.Node) {
    normal_node.sample(uv).rgb().normalize()
  }
  let depth_edge_indicator = fn(
    depth : @nodes.Node,
    depth_e : @nodes.Node,
    depth_w : @nodes.Node,
    depth_n : @nodes.Node,
    depth_s : @nodes.Node,
  ) {
    let diff = @nodes.property("float", name="diff")
    diff.add_assign(@nodes.clamp(depth_e.sub(depth)))
    diff.add_assign(@nodes.clamp(depth_w.sub(depth)))
    diff.add_assign(@nodes.clamp(depth_n.sub(depth)))
    diff.add_assign(@nodes.clamp(depth_s.sub(depth)))
    @nodes.floor(@nodes.smoothstep(0.01, 0.02, diff).mul(2)).div(2)
  }
  let neighbor_normal_edge_indicator = fn(
    x : Double,
    y : Double,
    neighbor_depth : @nodes.Node,
    depth : @nodes.Node,
    normal : @nodes.Node,
    inv_size : @nodes.Node,
  ) {
    let depth_diff = neighbor_depth.sub(depth).to_const()
    let neighbor_normal = sample_normal(
      uv_node_normal.add(@nodes.vec2_of([x, y]).mul(inv_size)),
    ).to_const()
    // Edge pixels should yield to faces who's normals are closer to the bias normal.
    let normal_edge_bias = @nodes.vec3_of([1, 1, 1]) // This should probably be a parameter.
    let normal_diff = @nodes.dot(normal.sub(neighbor_normal), normal_edge_bias).to_const()
    let normal_indicator = @nodes.clamp(
      @nodes.smoothstep(-0.01, 0.01, normal_diff),
      low=0.0,
      high=1.0,
    ).to_const()
    // Only the shallower pixel should detect the normal edge.
    let depth_indicator = @nodes.clamp(
      @nodes.sign(depth_diff.mul(0.25).add(0.0025)),
      low=0.0,
      high=1.0,
    ).to_const()
    @nodes.float(1.0)
    .sub(@nodes.dot(normal, neighbor_normal))
    .mul(depth_indicator)
    .mul(normal_indicator)
  }
  let normal_edge_indicator = fn(
    depth : @nodes.Node,
    normal : @nodes.Node,
    depth_e : @nodes.Node,
    depth_w : @nodes.Node,
    depth_n : @nodes.Node,
    depth_s : @nodes.Node,
    inv_size : @nodes.Node,
  ) {
    let indicator = @nodes.property("float", name="indicator")
    indicator.add_assign(
      neighbor_normal_edge_indicator(0, -1, depth_s, depth, normal, inv_size),
    )
    indicator.add_assign(
      neighbor_normal_edge_indicator(0, 1, depth_n, depth, normal, inv_size),
    )
    indicator.add_assign(
      neighbor_normal_edge_indicator(-1, 0, depth_w, depth, normal, inv_size),
    )
    indicator.add_assign(
      neighbor_normal_edge_indicator(1, 0, depth_e, depth, normal, inv_size),
    )
    @nodes.step(0.1, indicator)
  }
  let pixelation = @nodes.fn_(fn(_, _) {
    let texel = sample_texture()
    let depth = @nodes.property("float", name="depth")
    let normal = @nodes.property("vec3", name="normal")
    let depth_e = @nodes.float_of([]).to_var()
    let depth_w = @nodes.float_of([]).to_var()
    let depth_n = @nodes.float_of([]).to_var()
    let depth_s = @nodes.float_of([]).to_var()
    let inv_size = @nodes.vec2(1)
      .div(@nodes.texture_size(texture_node))
      .to_const()
    @nodes.if_(
      self.depth_edge_strength
      .greater_than(0.0)
      .or(self.normal_edge_strength.greater_than(0.0)),
      fn() {
        depth.assign(sample_depth(uv_node_depth))
        normal.assign(sample_normal(uv_node_normal))
        depth_e.assign(
          sample_depth(uv_node_depth.add(@nodes.vec2_of([1, 0]).mul(inv_size))),
        )
        depth_w.assign(
          sample_depth(uv_node_depth.add(@nodes.vec2_of([-1, 0]).mul(inv_size))),
        )
        depth_n.assign(
          sample_depth(uv_node_depth.add(@nodes.vec2_of([0, 1]).mul(inv_size))),
        )
        depth_s.assign(
          sample_depth(uv_node_depth.add(@nodes.vec2_of([0, -1]).mul(inv_size))),
        )
      },
    )
    |> ignore
    let dei = @nodes.property("float", name="dei")
    @nodes.if_(self.depth_edge_strength.greater_than(0.0), fn() {
      dei.assign(
        depth_edge_indicator(depth, depth_e, depth_w, depth_n, depth_s),
      )
    })
    |> ignore
    let nei = @nodes.property("float", name="nei")
    @nodes.if_(
      self.normal_edge_strength
      .greater_than(0.0)
      .and_(normal.length().greater_than(0)),
      fn() {
        nei.assign(
          normal_edge_indicator(
            depth, normal, depth_e, depth_w, depth_n, depth_s, inv_size,
          ),
        )
      },
    )
    |> ignore
    let strength = dei
      .greater_than(0)
      .select(
        @nodes.float(1.0).sub(dei.mul(self.depth_edge_strength)),
        else_node=nei.mul(self.normal_edge_strength).add(1),
      )
    Some(@nodes.vec4_of([texel.mul(strength).rgb(), texel.a()]))
  })
  let output_node = pixelation.call([])
  Some(output_node)
}

///|
/// `new PixelationPassNode( scene, camera, pixelSize = 6, normalEdgeStrength = 0.3,
/// depthEdgeStrength = 0.4 )`.
pub fn PixelationPassNode::new(
  scene : @core.Object3D,
  camera : @core.Object3D,
  pixel_size~ : Double = 6.0,
  normal_edge_strength? : &@nodes.IntoTsl,
  depth_edge_strength? : &@nodes.IntoTsl,
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  let pass = @nodes.PassNode::construct(
    node,
    @nodes.PassNode::color(),
    scene,
    camera,
    {
      ..@nodes.PassNodeOptions::default(),
      min_filter: Some(@core.NearestFilter),
      mag_filter: Some(@core.NearestFilter),
    },
  )
  let normal_edge_strength = a4_node_object_or(
    normal_edge_strength,
    Number(0.3),
  )
  let depth_edge_strength = a4_node_object_or(depth_edge_strength, Number(0.4))
  let p = PixelationPassNode::{
    pass,
    pixel_size,
    normal_edge_strength,
    depth_edge_strength,
  }
  pass._mrt = Some(
    @nodes.mrt(
      Map::from_array([
        ("output", @nodes.output),
        ("normal", @nodes.normal_view),
      ]),
    ),
  )
  pass.pass_class = p
  node.set_class(p)
}

///|
pub fn PixelationPassNode::of(node : @nodes.Node) -> PixelationPassNode? {
  addon_class_of(node, "PixelationPassNode")
}

///|
/// `pixelationPass( scene, camera, pixelSize, normalEdgeStrength, depthEdgeStrength )`.
pub fn pixelation_pass(
  scene : @core.Object3D,
  camera : @core.Object3D,
  pixel_size~ : Double = 6.0,
  normal_edge_strength? : &@nodes.IntoTsl,
  depth_edge_strength? : &@nodes.IntoTsl,
) -> @nodes.Node {
  PixelationPassNode::new(
    scene,
    camera,
    pixel_size~,
    normal_edge_strength?,
    depth_edge_strength?,
  )
}
