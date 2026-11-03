// nodes/accessors/ClippingNode.js: clipping planes (discarding, alpha to coverage, or
// hardware clip distances).

///|
pub(all) struct ClippingNode {
  mut scope : String
  mut hardware_clipping : Bool
  /// `this.position`, set by `setup`.
  mut position : Node?
}

///|
/// `ClippingNode.ALPHA_TO_COVERAGE`.
pub fn ClippingNode::alpha_to_coverage() -> String {
  "alphaToCoverage"
}

///|
/// `ClippingNode.DEFAULT`.
pub fn ClippingNode::default_() -> String {
  "default"
}

///|
/// `ClippingNode.HARDWARE`.
pub fn ClippingNode::hardware() -> String {
  "hardware"
}

///|
pub impl NodeClass for ClippingNode with fn class_name(_) {
  "ClippingNode"
}

///|
pub impl NodeClass for ClippingNode with fn children(self, _, out) {
  push_child(out, "position", self.position)
}

///|
pub impl NodeClass for ClippingNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for ClippingNode with fn setup(self, node, builder) {
  node.setup_base(builder) |> ignore
  let clipping_context = builder.clipping_context.unwrap()
  let intersection_planes = clipping_context.intersection_planes
  let union_planes = clipping_context.union_planes
  self.hardware_clipping = builder.hardware_clipping
  self.position = Some(
    if builder.camera.unwrap().is_array_camera() {
      camera_world_matrix.mul(vec4_of([position_view, 1])).xyz()
    } else {
      position_view
    },
  )
  if self.scope == ClippingNode::alpha_to_coverage() {
    Some(self.setup_alpha_to_coverage(intersection_planes, union_planes))
  } else if self.scope == ClippingNode::hardware() {
    Some(self.setup_hardware_clipping(union_planes, builder))
  } else {
    Some(self.setup_default(intersection_planes, union_planes))
  }
}

///|
/// `setupAlphaToCoverage( intersectionPlanes, unionPlanes )`.
pub fn ClippingNode::setup_alpha_to_coverage(
  self : ClippingNode,
  intersection_planes : Array[@math.Vector4],
  union_planes : Array[@math.Vector4],
) -> Node {
  fn_(fn(_, _) {
    let position = self.position.unwrap()
    let distance_to_plane = float_of([]).to_var(name="distanceToPlane")
    let distance_gradient = float_of([]).to_var(name="distanceToGradient")
    let clip_opacity = float(1).to_var(name="clipOpacity")
    let num_union_planes = union_planes.length()
    if !self.hardware_clipping && num_union_planes > 0 {
      let clipping_planes = uniform_array(union_planes).set_group(render_group)
      loop_([num_union_planes], fn(inputs) {
        let i = inputs.named("i").unwrap()
        let plane = clipping_planes.element(i)
        distance_to_plane.assign(
          position.dot(plane.xyz()).negate().add(plane.w()),
        )
        distance_gradient.assign(distance_to_plane.fwidth().div(2.0))
        clip_opacity.mul_assign(
          smoothstep(
            distance_gradient.negate(),
            distance_gradient,
            distance_to_plane,
          ),
        )
      })
    }
    let num_intersection_planes = intersection_planes.length()
    if num_intersection_planes > 0 {
      let clipping_planes = uniform_array(intersection_planes).set_group(
        render_group,
      )
      let intersection_clip_opacity = float(1).to_var(
        name="intersectionClipOpacity",
      )
      loop_([num_intersection_planes], fn(inputs) {
        let i = inputs.named("i").unwrap()
        let plane = clipping_planes.element(i)
        distance_to_plane.assign(
          position.dot(plane.xyz()).negate().add(plane.w()),
        )
        distance_gradient.assign(distance_to_plane.fwidth().div(2.0))
        intersection_clip_opacity.mul_assign(
          smoothstep(
            distance_gradient.negate(),
            distance_gradient,
            distance_to_plane,
          ).one_minus(),
        )
      })
      clip_opacity.mul_assign(intersection_clip_opacity.one_minus())
    }
    diffuse_color.a().mul_assign(clip_opacity)
    diffuse_color.a().equal(0.0).discard()
    None
  }).call([])
}

///|
/// `setupDefault( intersectionPlanes, unionPlanes )`.
pub fn ClippingNode::setup_default(
  self : ClippingNode,
  intersection_planes : Array[@math.Vector4],
  union_planes : Array[@math.Vector4],
) -> Node {
  fn_(fn(_, _) {
    let position = self.position.unwrap()
    let num_union_planes = union_planes.length()
    if !self.hardware_clipping && num_union_planes > 0 {
      let clipping_planes = uniform_array(union_planes).set_group(render_group)
      loop_([num_union_planes], fn(inputs) {
        let i = inputs.named("i").unwrap()
        let plane = clipping_planes.element(i)
        position.dot(plane.xyz()).greater_than(plane.w()).discard()
      })
    }
    let num_intersection_planes = intersection_planes.length()
    if num_intersection_planes > 0 {
      let clipping_planes = uniform_array(intersection_planes).set_group(
        render_group,
      )
      let clipped = bool(true).to_var(name="clipped")
      loop_([num_intersection_planes], fn(inputs) {
        let i = inputs.named("i").unwrap()
        let plane = clipping_planes.element(i)
        clipped.assign(
          position.dot(plane.xyz()).greater_than(plane.w()).and_(clipped),
        )
      })
      clipped.discard()
    }
    None
  }).call([])
}

///|
/// `setupHardwareClipping( unionPlanes, builder )`.
pub fn ClippingNode::setup_hardware_clipping(
  self : ClippingNode,
  union_planes : Array[@math.Vector4],
  builder : NodeBuilder,
) -> Node {
  let num_union_planes = union_planes.length()
  builder.enable_hardware_clipping(num_union_planes)
  fn_(fn(_, _) {
    let position = self.position.unwrap()
    let clipping_planes = uniform_array(union_planes).set_group(render_group)
    let hw_clip_distances = builtin(builder.get_clip_distance())
    loop_([num_union_planes], fn(inputs) {
      let i = inputs.named("i").unwrap()
      let plane = clipping_planes.element(i)
      let distance = position.dot(plane.xyz()).sub(plane.w()).negate()
      hw_clip_distances.element(i).assign(distance)
    })
    None
  }).call([])
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn ClippingNode::construct(_node : Node, scope : String) -> ClippingNode {
  { scope, hardware_clipping: false, position: None, }
}

///|
/// `new ClippingNode( scope = ClippingNode.DEFAULT )`.
pub fn ClippingNode::new(scope? : String) -> Node {
  let node = Node::alloc()
  node.set_class(
    ClippingNode::construct(node, scope.unwrap_or(ClippingNode::default_())),
  )
}

///|
pub fn ClippingNode::of(node : Node) -> ClippingNode? {
  match node.class_payload("ClippingNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `clipping()`.
pub fn clipping() -> Node {
  ClippingNode::new()
}

///|
/// `clippingAlpha()`.
pub fn clipping_alpha() -> Node {
  ClippingNode::new(scope=ClippingNode::alpha_to_coverage())
}

///|
/// `hardwareClipping()`.
pub fn hardware_clipping() -> Node {
  ClippingNode::new(scope=ClippingNode::hardware())
}
