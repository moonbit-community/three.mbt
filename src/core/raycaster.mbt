// Upstream src/core/Raycaster.js.

///|
let _raycaster_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
/// `direction` must be normalized.
pub fn Raycaster::new(
  origin? : @math.Vector3,
  direction? : @math.Vector3,
  near~ : Double = 0.0,
  far? : Double,
) -> Raycaster {
  {
    ray: @math.Ray::new(origin?, direction?),
    near,
    far: far.unwrap_or(buffer_geometry_infinity()),
    camera: None,
    layers: Layers::new(),
    params: {
      mesh: JsValue::object(),
      line: { threshold: 1.0, },
      lod: JsValue::object(),
      points: { threshold: 1.0, },
      sprite: JsValue::object(),
    },
  }
}

///|
/// `direction` is assumed to be normalized, for accurate distance calculations.
pub fn Raycaster::set(
  self : Raycaster,
  origin : @math.Vector3,
  direction : @math.Vector3,
) -> Unit {
  ignore(self.ray.set(origin, direction))
}

///|
/// Sets the ray from normalized device coordinates and a camera.
pub fn Raycaster::set_from_camera(
  self : Raycaster,
  coords : @math.Vector2,
  camera : Object3D,
) -> Unit {
  if camera.is_perspective_camera() {
    ignore(self.ray.origin.set_from_matrix_position(camera.matrix_world))
    ignore(
      self.ray.direction
      .set(coords.x, coords.y, 0.5)
      .unproject(camera)
      .sub(self.ray.origin)
      .normalize(),
    )
    self.camera = Some(camera)
  } else if camera.is_orthographic_camera() {
    // set origin in plane of camera
    ignore(
      self.ray.origin
      .set(coords.x, coords.y, camera.projection_matrix().elements[14])
      .unproject(camera),
    )
    ignore(
      self.ray.direction
      .set(0.0, 0.0, -1.0)
      .transform_direction(camera.matrix_world),
    )
    self.camera = Some(camera)
  } else {
    error("Raycaster: Unsupported camera type: " + camera.type_)
  }
}

///|
pub fn Raycaster::set_from_xr_controller(
  self : Raycaster,
  controller : Object3D,
) -> Raycaster {
  ignore(_raycaster_matrix.identity().extract_rotation(controller.matrix_world))
  ignore(self.ray.origin.set_from_matrix_position(controller.matrix_world))
  ignore(
    self.ray.direction.set(0.0, 0.0, -1.0).apply_matrix4(_raycaster_matrix),
  )
  self
}

///|
pub fn Raycaster::intersect_object(
  self : Raycaster,
  object : Object3D,
  recursive~ : Bool = true,
  intersects~ : Array[Intersection] = [],
) -> Array[Intersection] {
  raycaster_intersect(object, self, intersects, recursive)
  objects_stable_sort(intersects, raycaster_asc_sort)
  intersects
}

///|
pub fn Raycaster::intersect_objects(
  self : Raycaster,
  objects : Array[Object3D],
  recursive~ : Bool = true,
  intersects~ : Array[Intersection] = [],
) -> Array[Intersection] {
  for object in objects {
    raycaster_intersect(object, self, intersects, recursive)
  }
  objects_stable_sort(intersects, raycaster_asc_sort)
  intersects
}

///|
fn raycaster_asc_sort(a : Intersection, b : Intersection) -> Double {
  a.distance - b.distance
}

///|
fn raycaster_intersect(
  object : Object3D,
  raycaster : Raycaster,
  intersects : Array[Intersection],
  recursive : Bool,
) -> Unit {
  if object.layers.test_(raycaster.layers) {
    object.raycast(raycaster, intersects)
  }
  if recursive {
    for child in object.children {
      raycaster_intersect(child, raycaster, intersects, true)
    }
  }
}

///|
/// An intersection with the fields every class sets; the rest are filled in afterwards.
fn Intersection::make(
  distance : Double,
  point : @math.Vector3,
  object : Object3D,
) -> Intersection {
  {
    distance,
    distance_to_ray: None,
    point,
    index: None,
    face: None,
    face_index: None,
    barycoord: None,
    uv: None,
    uv1: None,
    normal: None,
    instance_id: None,
    batch_id: None,
    object,
  }
}
