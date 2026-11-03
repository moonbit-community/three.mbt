///|
let _camera_helper_vector : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _camera_helper_camera : @core.Object3D = @core.Camera::new()

///|
/// Shows a camera's frustum, line of sight and up vector. A `LineSegments` whose
/// `matrix` is the camera's `matrix_world`.
pub(all) struct CameraHelper {
  mut camera : @core.Object3D
  /// Point name to the vertex indices it moves.
  mut point_map : Map[String, Array[Int32]]
}

///|
pub impl @core.Object3DExtension for CameraHelper with fn type_name(_) {
  "CameraHelper"
}

///|
/// Upstream's `new CameraHelper()` throws on the missing camera.
pub impl @core.Object3DExtension for CameraHelper with fn construct(_) {
  abort("CameraHelper: new CameraHelper() needs a camera")
}

///|
pub impl @core.Object3DExtension for CameraHelper with fn dispose(_, object) {
  object.dispose_kind()
  geometry_of(object).dispose()
  material_of(object).dispose()
}

///|
#deprecated
pub extend CameraHelper with @core.Object3DExtension::{
  type_name,
  construct,
  payload,
  has_flag,
  raycast,
  copy_from,
  to_json,
  update_matrix_world,
  update_world_matrix,
  intersects_frustum,
  get_world_direction,
  dispose,
}

///|
/// `new CameraHelper( camera )`.
pub fn CameraHelper::new(camera : @core.Object3D) -> @core.Object3D {
  let geometry = @core.BufferGeometry::new()
  let material = @core.LineBasicMaterial::new()
  ignore(color_of(material).set_hex(0xffffff))
  material.vertex_colors = true
  material.tone_mapped = false
  let vertices : Array[Double] = []
  let colors : Array[Double] = []
  let point_map : Map[String, Array[Int32]] = Map([])
  fn add_point(id : String) {
    vertices.push(0.0)
    vertices.push(0.0)
    vertices.push(0.0)
    colors.push(0.0)
    colors.push(0.0)
    colors.push(0.0)
    match point_map.get(id) {
      Some(points) => points.push(vertices.length() / 3 - 1)
      None => point_map[id] = [vertices.length() / 3 - 1]
    }
  }

  fn add_line(a : String, b : String) {
    add_point(a)
    add_point(b)
  }

  // near
  add_line("n1", "n2")
  add_line("n2", "n4")
  add_line("n4", "n3")
  add_line("n3", "n1")
  // far
  add_line("f1", "f2")
  add_line("f2", "f4")
  add_line("f4", "f3")
  add_line("f3", "f1")
  // sides
  add_line("n1", "f1")
  add_line("n2", "f2")
  add_line("n3", "f3")
  add_line("n4", "f4")
  // cone
  add_line("p", "n1")
  add_line("p", "n2")
  add_line("p", "n3")
  add_line("p", "n4")
  // up
  add_line("u1", "u2")
  add_line("u2", "u3")
  add_line("u3", "u1")
  // target
  add_line("c", "t")
  add_line("p", "c")
  // cross
  add_line("cn1", "cn2")
  add_line("cn3", "cn4")
  add_line("cf1", "cf2")
  add_line("cf3", "cf4")
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(vertices, 3),
    ),
  )
  ignore(
    geometry.set_attribute(
      "color",
      @core.Float32BufferAttribute::new(colors, 3),
    ),
  )
  let helper : CameraHelper = { camera, point_map, }
  let object = @core.LineSegments::new(geometry~, material=Single(material)).set_extension(
    helper,
  )
  if camera.is_perspective_camera() || camera.is_orthographic_camera() {
    camera.update_projection_matrix()
  }
  object.matrix = camera.matrix_world
  object.matrix_auto_update = false
  CameraHelper::update(object)
  let color_frustum = @math.Color::from_hex(0xffaa00)
  let color_cone = @math.Color::from_hex(0xff0000)
  let color_up = @math.Color::from_hex(0x00aaff)
  let color_target = @math.Color::from_hex(0xffffff)
  let color_cross = @math.Color::from_hex(0x333333)
  ignore(
    CameraHelper::set_colors(
      object, color_frustum, color_cone, color_up, color_target, color_cross,
    ),
  )
  object
}

///|
/// The `CameraHelper` payload of `object`, if it is one.
pub fn CameraHelper::of(object : @core.Object3D) -> CameraHelper? {
  helper_payload(object, "CameraHelper")
}

///|
/// `helper.setColors( frustum, cone, up, target, cross )`.
pub fn CameraHelper::set_colors(
  helper : @core.Object3D,
  frustum : @math.Color,
  cone : @math.Color,
  up : @math.Color,
  target : @math.Color,
  cross : @math.Color,
) -> @core.Object3D {
  let geometry = geometry_of(helper)
  guard geometry.get_attribute("color") is Some(color_attribute) else {
    abort("CameraHelper.setColors: no color attribute")
  }
  fn set(index : Int32, color : @math.Color) {
    color_attribute.set_xyz(index, color.r, color.g, color.b)
  }

  // near: n1, n2 / n2, n4 / n4, n3 / n3, n1; far: f1, f2 / f2, f4 / f4, f3 / f3, f1;
  // sides: n1, f1 / n2, f2 / n3, f3 / n4, f4
  for i in 0..<24 {
    set(i, frustum)
  }
  // cone: p, n1 / p, n2 / p, n3 / p, n4
  for i in 24..<32 {
    set(i, cone)
  }
  // up: u1, u2 / u2, u3 / u3, u1
  for i in 32..<38 {
    set(i, up)
  }
  // target: c, t
  set(38, target)
  set(39, target)
  // cross: p, c / cn1, cn2 / cn3, cn4 / cf1, cf2 / cf3, cf4
  for i in 40..<50 {
    set(i, cross)
  }
  color_attribute.set_needs_update(true)
  helper
}

///|
/// `helper.update()`: moves the vertices to the camera's current frustum.
pub fn CameraHelper::update(helper : @core.Object3D) -> Unit {
  let payload : CameraHelper = require_payload(helper, "CameraHelper")
  let geometry = geometry_of(helper)
  let point_map = payload.point_map
  let camera = payload.camera
  let w = 1.0
  let h = 1.0
  // we need just camera projection matrix inverse
  // world matrix must be identity
  ignore(
    _camera_helper_camera
    .projection_matrix_inverse()
    .copy(camera.projection_matrix_inverse()),
  )
  // Adjust z values based on coordinate system
  let (near_z, far_z) = if camera.reversed_depth() {
    (1.0, 0.0)
  } else {
    let coordinate_system = match camera.kind {
      Camera(data) => data.coordinate_system
      _ => abort("CameraHelper.update(): not a camera")
    }
    if coordinate_system == @core.WebGLCoordinateSystem {
      (-1.0, 1.0)
    } else if coordinate_system == @core.WebGPUCoordinateSystem {
      (0.0, 1.0)
    } else {
      abort(
        "THREE.CameraHelper.update(): Invalid coordinate system: \{coordinate_system}",
      )
    }
  }
  fn set_point(point : String, x : Double, y : Double, z : Double) {
    ignore(_camera_helper_vector.set(x, y, z).unproject(_camera_helper_camera))
    if point_map.get(point) is Some(points) {
      guard geometry.get_attribute("position") is Some(position) else {
        abort("CameraHelper.update: no position attribute")
      }
      for index in points {
        position.set_xyz(
          index,
          _camera_helper_vector.x,
          _camera_helper_vector.y,
          _camera_helper_vector.z,
        )
      }
    }
  }

  // center / target
  set_point("c", 0.0, 0.0, near_z)
  set_point("t", 0.0, 0.0, far_z)
  // near
  set_point("n1", -w, -h, near_z)
  set_point("n2", w, -h, near_z)
  set_point("n3", -w, h, near_z)
  set_point("n4", w, h, near_z)
  // far
  set_point("f1", -w, -h, far_z)
  set_point("f2", w, -h, far_z)
  set_point("f3", -w, h, far_z)
  set_point("f4", w, h, far_z)
  // up
  set_point("u1", w * 0.7, h * 1.1, near_z)
  set_point("u2", -w * 0.7, h * 1.1, near_z)
  set_point("u3", 0.0, h * 2.0, near_z)
  // cross
  set_point("cf1", -w, 0.0, far_z)
  set_point("cf2", w, 0.0, far_z)
  set_point("cf3", 0.0, -h, far_z)
  set_point("cf4", 0.0, h, far_z)
  set_point("cn1", -w, 0.0, near_z)
  set_point("cn2", w, 0.0, near_z)
  set_point("cn3", 0.0, -h, near_z)
  set_point("cn4", 0.0, h, near_z)
  guard geometry.get_attribute("position") is Some(position) else {
    abort("CameraHelper.update: no position attribute")
  }
  position.set_needs_update(true)
}
