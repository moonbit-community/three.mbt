// examples/jsm/tsl/display/AnaglyphPassNode.js

///|
let _anaglyph_pass_node_eye_l : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _anaglyph_pass_node_eye_r : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _anaglyph_pass_node_screen_bottom_left : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _anaglyph_pass_node_screen_bottom_right : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _anaglyph_pass_node_screen_top_left : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _anaglyph_pass_node_right : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _anaglyph_pass_node_up : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _anaglyph_pass_node_forward : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _anaglyph_pass_node_screen_center : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
/// Evaluates AnaglyphPassNode.js, as `import` does: its import of
/// StereoCompositePassNode.js (whose `_quadMesh` it creates); it has no module-level
/// nodes of its own.
pub fn load_display_anaglyph_pass_node() -> Unit {
  load_display_stereo_composite_pass_node()
}

///|
extern "js" fn anaglyph_pass_node_math_tan(x : Double) -> Double = "Math.tan"

///|
/// `AnaglyphAlgorithm`: how the two views are mixed.
#derive(Eq)
pub(all) enum AnaglyphAlgorithm {
  /// `'true'`
  True_
  /// `'grey'`
  Grey
  /// `'colour'`
  Colour
  /// `'halfColour'`
  HalfColour
  /// `'dubois'`
  Dubois
  /// `'optimised'`
  Optimised
  /// `'compromise'`
  Compromise
}

///|
/// `AnaglyphColorMode`: the colors of the glasses.
#derive(Eq)
pub(all) enum AnaglyphColorMode {
  /// `'redCyan'`
  RedCyan
  /// `'magentaCyan'`
  MagentaCyan
  /// `'magentaGreen'`
  MagentaGreen
}

///|
/// `LUMINANCE`.
let anaglyph_pass_node_lum : Array[Double] = [0.299, 0.587, 0.114]

///|
/// `createMatrixPair( leftSpec, rightSpec )`: each spec gives the input coefficients of
/// the output r, g and b (row-major, `[ 0, 0, 0 ]` when absent), returned column-major.
fn anaglyph_pass_node_matrix_pair(
  left : (Array[Double]?, Array[Double]?, Array[Double]?),
  right : (Array[Double]?, Array[Double]?, Array[Double]?),
) -> (Array[Double], Array[Double]) {
  fn spec_to_column_major(
    spec : (Array[Double]?, Array[Double]?, Array[Double]?),
  ) -> Array[Double] {
    let zero = [0.0, 0.0, 0.0]
    let r = spec.0.unwrap_or(zero)
    let g = spec.1.unwrap_or(zero)
    let b = spec.2.unwrap_or(zero)
    [r[0], g[0], b[0], r[1], g[1], b[1], r[2], g[2], b[2]]
  }

  (spec_to_column_major(left), spec_to_column_major(right))
}

///|
/// `ANAGLYPH_MATRICES[ algorithm ][ colorMode ]`.
fn anaglyph_pass_node_matrices(
  algorithm : AnaglyphAlgorithm,
  color_mode : AnaglyphColorMode,
) -> (Array[Double], Array[Double]) {
  let lum = anaglyph_pass_node_lum
  let pair = anaglyph_pass_node_matrix_pair
  match (algorithm, color_mode) {
    // True Anaglyph - Red channel from left, luminance to cyan channel for right
    (True_, RedCyan) =>
      pair((Some([1, 0, 0]), None, None), (None, Some(lum), Some(lum)))
    (True_, MagentaCyan) =>
      pair(
        (Some([1, 0, 0]), None, Some([0, 0, 0.5])),
        (None, Some(lum), Some([0, 0, 0.5])),
      )
    (True_, MagentaGreen) =>
      pair((Some([1, 0, 0]), None, Some(lum)), (None, Some(lum), None))
    // Grey Anaglyph - Luminance-based, no color, minimal ghosting
    (Grey, RedCyan) =>
      pair((Some(lum), None, None), (None, Some(lum), Some(lum)))
    (Grey, MagentaCyan) =>
      pair(
        (Some(lum), None, Some([0.15, 0.29, 0.06])),
        (None, Some(lum), Some([0.15, 0.29, 0.06])),
      )
    (Grey, MagentaGreen) =>
      pair((Some(lum), None, Some(lum)), (None, Some(lum), None))
    // Colour Anaglyph - Full color, high retinal rivalry
    (Colour, RedCyan) =>
      pair(
        (Some([1, 0, 0]), None, None),
        (None, Some([0, 1, 0]), Some([0, 0, 1])),
      )
    (Colour, MagentaCyan) =>
      pair(
        (Some([1, 0, 0]), None, Some([0, 0, 0.5])),
        (None, Some([0, 1, 0]), Some([0, 0, 0.5])),
      )
    (Colour, MagentaGreen) =>
      pair(
        (Some([1, 0, 0]), None, Some([0, 0, 1])),
        (None, Some([0, 1, 0]), None),
      )
    // Half-Colour Anaglyph - Luminance for left red, full color for right cyan
    (HalfColour, RedCyan) =>
      pair((Some(lum), None, None), (None, Some([0, 1, 0]), Some([0, 0, 1])))
    (HalfColour, MagentaCyan) =>
      pair(
        (Some(lum), None, Some([0.15, 0.29, 0.06])),
        (None, Some([0, 1, 0]), Some([0.15, 0.29, 0.06])),
      )
    (HalfColour, MagentaGreen) =>
      pair((Some(lum), None, Some(lum)), (None, Some([0, 1, 0]), None))
    // Dubois Anaglyph - Least-squares optimized for specific glasses
    (Dubois, RedCyan) =>
      pair(
        (
          Some([0.4561, 0.500484, 0.176381]),
          Some([-0.0400822, -0.0378246, -0.0157589]),
          Some([-0.0152161, -0.0205971, -0.00546856]),
        ),
        (
          Some([-0.0434706, -0.0879388, -0.00155529]),
          Some([0.378476, 0.73364, -0.0184503]),
          Some([-0.0721527, -0.112961, 1.2264]),
        ),
      )
    (Dubois, MagentaCyan) =>
      pair(
        (
          Some([0.4561, 0.500484, 0.176381]),
          Some([-0.0400822, -0.0378246, -0.0157589]),
          Some([0.088, 0.088, -0.003]),
        ),
        (
          Some([-0.0434706, -0.0879388, -0.00155529]),
          Some([0.378476, 0.73364, -0.0184503]),
          Some([0.088, 0.088, 0.613]),
        ),
      )
    (Dubois, MagentaGreen) =>
      pair(
        (
          Some([0.4561, 0.500484, 0.176381]),
          None,
          Some([-0.0434706, -0.0879388, -0.00155529]),
        ),
        (
          None,
          Some([0.378476 + 0.4561, 0.73364 + 0.500484, -0.0184503 + 0.176381]),
          None,
        ),
      )
    // Optimised Anaglyph - Improved color with reduced retinal rivalry
    (Optimised, RedCyan) =>
      pair(
        (Some([0, 0.7, 0.3]), None, None),
        (None, Some([0, 1, 0]), Some([0, 0, 1])),
      )
    (Optimised, MagentaCyan) =>
      pair(
        (Some([0, 0.7, 0.3]), None, Some([0, 0, 0.5])),
        (None, Some([0, 1, 0]), Some([0, 0, 0.5])),
      )
    (Optimised, MagentaGreen) =>
      pair(
        (Some([0, 0.7, 0.3]), None, Some([0, 0, 1])),
        (None, Some([0, 1, 0]), None),
      )
    // Compromise Anaglyph - Best balance of color and stereo effect
    (Compromise, RedCyan) =>
      pair(
        (Some([0.439, 0.447, 0.148]), None, None),
        (None, Some([0.095, 0.934, 0.005]), Some([0.018, 0.028, 1.057])),
      )
    (Compromise, MagentaCyan) =>
      pair(
        (Some([0.439, 0.447, 0.148]), None, Some([0.009, 0.014, 0.074])),
        (None, Some([0.095, 0.934, 0.005]), Some([0.009, 0.014, 0.528])),
      )
    (Compromise, MagentaGreen) =>
      pair(
        (Some([0.439, 0.447, 0.148]), None, Some([0.018, 0.028, 1.057])),
        (None, Some([0.095 + 0.439, 0.934 + 0.447, 0.005 + 0.148]), None),
      )
  }
}

///|
/// An anaglyph pass: the scene rendered for both eyes and composited with a color
/// matrix per eye.
pub(all) struct AnaglyphPassNode {
  stereo : StereoCompositePassNode
  /// The interpupillary distance (eye separation) in world units.
  mut eye_sep : Double
  /// The distance from the cameras to the screen plane.
  mut plane_distance : Double
  mut _algorithm : AnaglyphAlgorithm
  mut _color_mode : AnaglyphColorMode
  _color_matrix_left : @nodes.Node
  _color_matrix_right : @nodes.Node
}

///|
pub impl @nodes.NodeClass for AnaglyphPassNode with fn class_name(_) {
  "AnaglyphPassNode"
}

///|
pub impl @nodes.NodeClass for AnaglyphPassNode with fn parent(self) {
  Some(self.stereo)
}

///|
pub impl @nodes.NodeClass for AnaglyphPassNode with fn has_flag(self, flag) {
  flag == "isAnaglyphPassNode" || self.stereo.has_flag(flag)
}

///|
pub impl @nodes.PassNodeClass for AnaglyphPassNode with fn set_size(
  self,
  node,
  width,
  height,
) {
  @nodes.PassNodeClass::set_size(self.stereo, node, width, height)
}

///|
/// `get algorithm()`.
pub fn AnaglyphPassNode::algorithm(
  self : AnaglyphPassNode,
) -> AnaglyphAlgorithm {
  self._algorithm
}

///|
/// `set algorithm( value )`.
pub fn AnaglyphPassNode::set_algorithm(
  self : AnaglyphPassNode,
  value : AnaglyphAlgorithm,
) -> Unit {
  if self._algorithm != value {
    self._algorithm = value
    self.update_matrices()
  }
}

///|
/// `get colorMode()`.
pub fn AnaglyphPassNode::color_mode(
  self : AnaglyphPassNode,
) -> AnaglyphColorMode {
  self._color_mode
}

///|
/// `set colorMode( value )`.
pub fn AnaglyphPassNode::set_color_mode(
  self : AnaglyphPassNode,
  value : AnaglyphColorMode,
) -> Unit {
  if self._color_mode != value {
    self._color_mode = value
    self.update_matrices()
  }
}

///|
/// `_updateMatrices()`.
fn AnaglyphPassNode::update_matrices(self : AnaglyphPassNode) -> Unit {
  let (left, right) = anaglyph_pass_node_matrices(
    self._algorithm,
    self._color_mode,
  )
  match @nodes.InputNode::get_value(self._color_matrix_left) {
    Matrix3(m) => m.from_array(left) |> ignore
    _ => ()
  }
  match @nodes.InputNode::get_value(self._color_matrix_right) {
    Matrix3(m) => m.from_array(right) |> ignore
    _ => ()
  }
}

///|
pub impl StereoCompositePassNodeClass for AnaglyphPassNode with fn update_stereo_camera(
  self,
  _,
  coordinate_system,
) {
  let stereo = self.stereo.stereo
  let camera = self.stereo.pass.camera
  stereo.camera_l.as_camera().coordinate_system = coordinate_system
  stereo.camera_r.as_camera().coordinate_system = coordinate_system
  // Get the camera's local coordinate axes from its world matrix
  camera.matrix_world.extract_basis(
    _anaglyph_pass_node_right, _anaglyph_pass_node_up, _anaglyph_pass_node_forward,
  )
  |> ignore
  _anaglyph_pass_node_right.normalize() |> ignore
  _anaglyph_pass_node_up.normalize() |> ignore
  _anaglyph_pass_node_forward.normalize() |> ignore
  // Calculate eye positions
  let half_sep = self.eye_sep / 2.0
  _anaglyph_pass_node_eye_l
  .copy(camera.position)
  .add_scaled_vector(_anaglyph_pass_node_right, -half_sep)
  |> ignore
  _anaglyph_pass_node_eye_r
  .copy(camera.position)
  .add_scaled_vector(_anaglyph_pass_node_right, half_sep)
  |> ignore
  // Calculate screen center (at planeDistance in front of the camera center)
  _anaglyph_pass_node_screen_center
  .copy(camera.position)
  .add_scaled_vector(_anaglyph_pass_node_forward, -self.plane_distance)
  |> ignore
  // Calculate screen dimensions from camera FOV and aspect ratio
  let (fov, aspect, near, far) = match camera.as_camera().kind {
    PerspectiveCamera(p) => (p.fov, p.aspect, p.near, p.far)
    OrthographicCamera(o) => (0.0 / 0.0, 0.0 / 0.0, o.near, o.far)
    BaseCamera => (0.0 / 0.0, 0.0 / 0.0, 0.0 / 0.0, 0.0 / 0.0)
  }
  let deg2rad = ADDON_PI / 180.0
  let half_height = self.plane_distance *
    anaglyph_pass_node_math_tan(deg2rad * fov / 2.0)
  let half_width = half_height * aspect
  // Calculate screen corners
  _anaglyph_pass_node_screen_bottom_left
  .copy(_anaglyph_pass_node_screen_center)
  .add_scaled_vector(_anaglyph_pass_node_right, -half_width)
  .add_scaled_vector(_anaglyph_pass_node_up, -half_height)
  |> ignore
  _anaglyph_pass_node_screen_bottom_right
  .copy(_anaglyph_pass_node_screen_center)
  .add_scaled_vector(_anaglyph_pass_node_right, half_width)
  .add_scaled_vector(_anaglyph_pass_node_up, -half_height)
  |> ignore
  _anaglyph_pass_node_screen_top_left
  .copy(_anaglyph_pass_node_screen_center)
  .add_scaled_vector(_anaglyph_pass_node_right, -half_width)
  .add_scaled_vector(_anaglyph_pass_node_up, half_height)
  |> ignore
  // Set up the eye cameras
  for
    pair in [
      (stereo.camera_l, _anaglyph_pass_node_eye_l),
      (stereo.camera_r, _anaglyph_pass_node_eye_r),
    ] {
    let (eye_camera, eye) = pair
    eye_camera.position.copy(eye) |> ignore
    match eye_camera.as_camera().kind {
      PerspectiveCamera(p) => {
        p.near = near
        p.far = far
      }
      OrthographicCamera(o) => {
        o.near = near
        o.far = far
      }
      BaseCamera => ()
    }
    @utils.frame_corners(
      eye_camera,
      _anaglyph_pass_node_screen_bottom_left,
      _anaglyph_pass_node_screen_bottom_right,
      _anaglyph_pass_node_screen_top_left,
      estimate_view_frustum=true,
    )
    eye_camera.matrix_world.compose(
      eye_camera.position,
      eye_camera.quaternion,
      eye_camera.scale,
    )
    |> ignore
    eye_camera.as_camera().matrix_world_inverse
    .copy(eye_camera.matrix_world)
    .invert()
    |> ignore
  }
}

///|
pub impl @nodes.NodeClass for AnaglyphPassNode with fn setup(
  self,
  node,
  builder,
) {
  let uv_node = @nodes.uv()
  let anaglyph = @nodes.fn_(fn(_, _) {
    let color_l = self.stereo._map_left.sample(uv_node)
    let color_r = self.stereo._map_right.sample(uv_node)
    let color = @nodes.clamp(
      self._color_matrix_left
      .mul(color_l.rgb())
      .add(self._color_matrix_right.mul(color_r.rgb())),
    )
    Some(@nodes.vec4_of([color.rgb(), @nodes.max(color_l.a(), color_r.a())]))
  })
  let material = match self.stereo._material {
    Some(m) => m
    None => {
      let m = @nodes.NodeMaterial::new()
      self.stereo._material = Some(m)
      m
    }
  }
  let node_material = @nodes.NodeMaterial::of(material).unwrap()
  node_material.context_node = Some(
    @nodes.context(value=builder.get_shared_context()),
  )
  node_material.fragment_node = Some(anaglyph.call([]))
  material.name = "Anaglyph"
  material.set_needs_update(true)
  @nodes.NodeClass::setup(self.stereo, node, builder)
}

///|
/// `new AnaglyphPassNode( scene, camera )`.
pub fn AnaglyphPassNode::new(
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> @nodes.Node {
  load_display_anaglyph_pass_node()
  let node = @nodes.Node::alloc(node_type="vec4")
  let stereo = StereoCompositePassNode::construct(node, scene, camera)
  let color_matrix_left = @nodes.uniform(@math.Matrix3::new())
  let color_matrix_right = @nodes.uniform(@math.Matrix3::new())
  let p = AnaglyphPassNode::{
    stereo,
    eye_sep: 0.064,
    plane_distance: 0.5,
    _algorithm: Dubois,
    _color_mode: RedCyan,
    _color_matrix_left: color_matrix_left,
    _color_matrix_right: color_matrix_right,
  }
  // Initialize with default matrices
  p.update_matrices()
  stereo.stereo_class = p
  stereo.pass.pass_class = p
  node.set_class(p)
}

///|
pub fn AnaglyphPassNode::of(node : @nodes.Node) -> AnaglyphPassNode? {
  addon_class_of(node, "AnaglyphPassNode")
}

///|
/// `anaglyphPass( scene, camera )`.
pub fn anaglyph_pass(
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> @nodes.Node {
  AnaglyphPassNode::new(scene, camera)
}
