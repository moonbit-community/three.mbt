// examples/jsm/tsl/display/SSAAPassNode.js

///|
let _ssaa_pass_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _ssaa_pass_node_clear_color : @math.Color = @math.Color::new(1.0, 1.0, 1.0)

///|
/// Supersample anti-aliasing: renders the scene several times with jittered
/// (sub-pixel) camera offsets and accumulates the results.
pub(all) struct SSAAPassNode {
  pass : @nodes.PassNode
  /// The sample level, 0..5 (1, 2, 4, 8, 16 or 32 samples).
  mut sample_level : Int32
  /// Whether rounding errors are cancelled out by varying the sample weights.
  mut unbiased : Bool
  sample_weight : @nodes.Node
  mut _sample_render_target : @core.RenderTarget?
  _quad_mesh : @nodes.QuadMesh
}

///|
pub impl @nodes.NodeClass for SSAAPassNode with fn class_name(_) {
  "SSAAPassNode"
}

///|
pub impl @nodes.NodeClass for SSAAPassNode with fn parent(self) {
  Some(self.pass)
}

///|
pub impl @nodes.NodeClass for SSAAPassNode with fn has_flag(self, flag) {
  flag == "isSSAAPassNode" || self.pass.has_flag(flag)
}

///|
pub impl @nodes.NodeClass for SSAAPassNode with fn children(self, node, out) {
  self.pass.children(node, out)
  @nodes.push_child(out, "sampleWeight", Some(self.sample_weight))
}

///|
pub impl @nodes.PassNodeClass for SSAAPassNode with fn set_size(
  _,
  node,
  width,
  height,
) {
  @nodes.PassNode::set_size_base(node, width, height)
}

///|
/// `camera.setViewOffset`: only perspective and orthographic cameras have it.
fn ssaa_pass_node_camera_view(
  camera : @core.Object3D,
) -> (Bool, @core.CameraView?) {
  match camera.as_camera().kind {
    PerspectiveCamera(p) => (true, p.view)
    OrthographicCamera(o) => (true, o.view)
    BaseCamera => (false, None)
  }
}

///|
pub impl @nodes.NodeClass for SSAAPassNode with fn update_before(
  self,
  node,
  frame,
) {
  let renderer = frame.renderer.unwrap()
  let scene = self.pass.scene
  let camera = self.pass.camera
  //
  let size = renderer.get_drawing_buffer_size(_ssaa_pass_node_size)
  node.set_size(size.x, size.y)
  let render_target = self.pass.render_target
  let sample_render_target = self._sample_render_target.unwrap()
  sample_render_target.set_size(render_target.width, render_target.height)
  //
  @nodes.InputNode::set_value(
    self.pass._camera_near,
    Number(@nodes.camera_near_of(camera)),
  )
  @nodes.InputNode::set_value(
    self.pass._camera_far,
    Number(@nodes.camera_far_of(camera)),
  )
  let current_render_target = renderer.get_render_target()
  let current_mrt = renderer.get_mrt()
  let current_auto_clear = renderer.auto_clear
  let current_clear_color = renderer.get_clear_color(
    _ssaa_pass_node_clear_color,
  )
  let current_clear_alpha = renderer.get_clear_alpha()
  renderer.set_mrt(node.get_mrt()) |> ignore
  renderer.auto_clear = false
  let level = if self.sample_level < 5 { self.sample_level } else { 5 }
  let jitter_offsets = ssaa_pass_node_jitter_vectors[if level > 0 {
      level
    } else {
      0
    }]
  let base_sample_weight = 1.0 / jitter_offsets.length().to_double()
  let rounding_range = 1.0 / 32.0
  let mut full_width = render_target.width.to_double()
  let mut full_height = render_target.height.to_double()
  let mut offset_x = 0.0
  let mut offset_y = 0.0
  let mut width = render_target.width.to_double()
  let mut height = render_target.height.to_double()
  let (has_view_offset, view) = ssaa_pass_node_camera_view(camera)
  // `Object.assign( {}, camera.view )`
  let original_view_offset = view.map(fn(v) { v.clone() })
  let original_enabled = match original_view_offset {
    Some(v) => v.enabled
    None => false
  }
  if original_enabled {
    let v = original_view_offset.unwrap()
    full_width = v.full_width
    full_height = v.full_height
    offset_x = v.offset_x
    offset_y = v.offset_y
    width = v.width
    height = v.height
  }
  // render the scene multiple times, each slightly jitter offset from the last and accumulate the results.
  for i, jitter_offset in jitter_offsets {
    if has_view_offset {
      camera.set_view_offset(
        full_width,
        full_height,
        offset_x + jitter_offset.0.to_double() * 0.0625,
        offset_y + jitter_offset.1.to_double() * 0.0625, // 0.0625 = 1 / 16
        width,
        height,
      )
    }
    let mut sample_weight = base_sample_weight
    if self.unbiased {
      // the theory is that equal weights for each sample lead to an accumulation of rounding errors.
      // The following equation varies the sampleWeight per sample so that it is uniformly distributed
      // across a range of values whose rounding errors cancel each other out.
      let uniform_centered_distribution = -0.5 +
        (i.to_double() + 0.5) / jitter_offsets.length().to_double()
      sample_weight = sample_weight +
        rounding_range * uniform_centered_distribution
    }
    @nodes.InputNode::set_value(self.sample_weight, Number(sample_weight))
    renderer.set_render_target(Some(sample_render_target))
    renderer.clear()
    renderer.render(scene, camera)
    // accumulation
    renderer.set_render_target(Some(render_target))
    if i == 0 {
      renderer.set_clear_color_hex(0x000000, alpha=0.0)
      renderer.clear()
      renderer.set_clear_color(current_clear_color, alpha=current_clear_alpha)
    }
    self._quad_mesh.render(renderer)
  }
  renderer.copy_texture_to_texture(
    sample_render_target.depth_texture().unwrap(),
    render_target.depth_texture().unwrap(),
  )
  // restore
  if has_view_offset && original_enabled {
    let v = original_view_offset.unwrap()
    camera.set_view_offset(
      v.full_width,
      v.full_height,
      v.offset_x,
      v.offset_y,
      v.width,
      v.height,
    )
  } else if has_view_offset {
    camera.clear_view_offset()
  }
  renderer.set_render_target(current_render_target)
  renderer.set_mrt(current_mrt) |> ignore
  renderer.auto_clear = current_auto_clear
  None
}

///|
pub impl @nodes.NodeClass for SSAAPassNode with fn setup(self, node, builder) {
  if self._sample_render_target is None {
    self._sample_render_target = Some(self.pass.render_target.clone())
  }
  let sample_render_target = self._sample_render_target.unwrap()
  let pass_mrt = node.get_mrt()
  let sample_texture = match pass_mrt {
    Some(pass_mrt) => {
      let outputs : Map[String, @nodes.Node] = Map([])
      for name, _ in @nodes.MRTNode::of(pass_mrt).unwrap().output_nodes {
        let index = @nodes.get_texture_index(
          sample_render_target.textures,
          name,
        )
        if index >= 0 {
          outputs.set(
            name,
            @nodes.texture(sample_render_target.textures[index]).mul(
              self.sample_weight,
            ),
          )
        }
      }
      @nodes.mrt(outputs)
    }
    None =>
      @nodes.texture(sample_render_target.texture()).mul(self.sample_weight)
  }
  let material = @nodes.NodeMaterial::new()
  self._quad_mesh.set_material(material)
  @nodes.NodeMaterial::of(material).unwrap().fragment_node = Some(
    @nodes.unpremultiply_alpha.call([sample_texture]),
  )
  material.transparent = true
  material.depth_test = false
  material.depth_write = false
  material.premultiplied_alpha = true
  material.blending = @core.AdditiveBlending
  material.name = "SSAA"
  self.pass.setup_base(node, builder)
}

///|
pub impl @nodes.NodeClass for SSAAPassNode with fn dispose(self, node) {
  self.pass.dispose(node)
  if self._sample_render_target is Some(target) {
    target.dispose()
  }
}

///|
/// `new SSAAPassNode( scene, camera )`.
pub fn SSAAPassNode::new(
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  let pass = @nodes.PassNode::construct(
    node,
    @nodes.PassNode::color(),
    scene,
    camera,
    { ..@nodes.PassNodeOptions::default(), samples: Some(0), },
  )
  let sample_weight = @nodes.uniform(1)
  let p = SSAAPassNode::{
    pass,
    sample_level: 4,
    unbiased: true,
    sample_weight,
    _sample_render_target: None,
    _quad_mesh: @nodes.QuadMesh::new(),
  }
  pass.pass_class = p
  node.set_class(p)
}

///|
pub fn SSAAPassNode::of(node : @nodes.Node) -> SSAAPassNode? {
  addon_class_of(node, "SSAAPassNode")
}

///|
/// These jitter vectors are specified in integers because it is easier: a [-8,8)
/// integer grid, mapped onto [-0.5,0.5) by the 1/16 scale.
let ssaa_pass_node_jitter_vectors : Array[Array[(Int32, Int32)]] = [
  [(0, 0)],
  [(4, 4), (-4, -4)],
  [(-2, -6), (6, -2), (-6, 2), (2, 6)],
  [(1, -3), (-1, 3), (5, 1), (-3, -5), (-5, 5), (-7, -1), (3, 7), (7, -7)],
  [
    (1, 1),
    (-1, -3),
    (-3, 2),
    (4, -1),
    (-5, -2),
    (2, 5),
    (5, 3),
    (3, -5),
    (-2, 6),
    (0, -7),
    (-4, -6),
    (-6, 4),
    (-8, 0),
    (7, -4),
    (6, 7),
    (-7, -8),
  ],
  [
    (-4, -7),
    (-7, -5),
    (-3, -5),
    (-5, -4),
    (-1, -4),
    (-2, -2),
    (-6, -1),
    (-4, 0),
    (-7, 1),
    (-1, 2),
    (-6, 3),
    (-3, 3),
    (-7, 6),
    (-3, 6),
    (-5, 7),
    (-1, 7),
    (5, -7),
    (1, -6),
    (6, -5),
    (4, -4),
    (2, -3),
    (7, -2),
    (1, -1),
    (4, -1),
    (2, 1),
    (6, 2),
    (0, 4),
    (4, 4),
    (2, 5),
    (7, 5),
    (5, 6),
    (3, 7),
  ],
]

///|
/// `ssaaPass( scene, camera )`.
pub fn ssaa_pass(
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> @nodes.Node {
  SSAAPassNode::new(scene, camera)
}
