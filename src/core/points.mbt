// Upstream src/objects/Points.js.

///|
let _points_inverse_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _points_ray : @math.Ray = @math.Ray::new()

///|
let _points_sphere : @math.Sphere = @math.Sphere::new()

///|
let _points_position : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
pub fn Points::new(
  geometry? : BufferGeometry,
  material? : MaterialSlot,
) -> Object3D {
  let points : Points = {
    geometry: match geometry {
      Some(geometry) => geometry
      None => BufferGeometry::new()
    },
    material: match material {
      Some(material) => material
      None => Single(PointsMaterial::new())
    },
    morph_target_dictionary: None,
    morph_target_influences: None,
  }
  let object = Object3D::new(kind=Points(points), type_="Points")
  object.update_morph_targets()
  object
}

///|
fn Object3D::points_data(self : Object3D) -> Points {
  guard self.kind is Points(points) else { abort("Object3D: not Points") }
  points
}

///|
/// Upstream `raycast`.
fn hook_points_raycast(
  object : Object3D,
  raycaster : Raycaster,
  intersects : Array[Intersection],
) -> Unit {
  let geometry = object.points_data().geometry
  let matrix_world = object.matrix_world
  let threshold = raycaster.params.points.threshold
  let draw_range = geometry.draw_range
  // Checking boundingSphere distance to ray
  if geometry.bounding_sphere is None {
    geometry.compute_bounding_sphere()
  }
  guard geometry.bounding_sphere is Some(bounding_sphere) else {
    abort("Points.raycast: geometry has no bounding sphere")
  }
  ignore(_points_sphere.copy(bounding_sphere))
  ignore(_points_sphere.apply_matrix4(matrix_world))
  _points_sphere.radius = _points_sphere.radius + threshold
  if !raycaster.ray.intersects_sphere(_points_sphere) {
    return
  }
  ignore(_points_inverse_matrix.copy(matrix_world).invert())
  ignore(_points_ray.copy(raycaster.ray).apply_matrix4(_points_inverse_matrix))
  let local_threshold = threshold /
    ((object.scale.x + object.scale.y + object.scale.z) / 3.0)
  let local_threshold_sq = local_threshold * local_threshold
  let draw_end = draw_range.start.to_double() + draw_range.count
  let start = objects_max_int(0, draw_range.start)
  match geometry.index {
    Some(index) => {
      guard geometry.attributes.get("position") is Some(position_attribute) else {
        abort("Points.raycast: geometry has no position attribute")
      }
      let end = objects_math_min(index.count().to_double(), draw_end)
      for i = start; i.to_double() < end; i = i + 1 {
        let a = index.get_x(i).to_int()
        ignore(_points_position.from_buffer_attribute(position_attribute, a))
        points_test_point(
          _points_position, a, local_threshold_sq, matrix_world, raycaster, intersects,
          object,
        )
      }
    }
    None => {
      guard geometry.attributes.get("position") is Some(position_attribute) else {
        abort("Points.raycast: geometry has no position attribute")
      }
      let end = objects_math_min(
        position_attribute.count().to_double(),
        draw_end,
      )
      for i = start; i.to_double() < end; i = i + 1 {
        ignore(_points_position.from_buffer_attribute(position_attribute, i))
        points_test_point(
          _points_position, i, local_threshold_sq, matrix_world, raycaster, intersects,
          object,
        )
      }
    }
  }
}

///|
fn points_test_point(
  point : @math.Vector3,
  index : Int32,
  local_threshold_sq : Double,
  matrix_world : @math.Matrix4,
  raycaster : Raycaster,
  intersects : Array[Intersection],
  object : Object3D,
) -> Unit {
  let ray_point_distance_sq = _points_ray.distance_sq_to_point(point)
  if ray_point_distance_sq < local_threshold_sq {
    let intersect_point = @math.Vector3::new(0.0, 0.0, 0.0)
    ignore(_points_ray.closest_point_to_point(point, intersect_point))
    ignore(intersect_point.apply_matrix4(matrix_world))
    let distance = raycaster.ray.origin.distance_to(intersect_point)
    if distance < raycaster.near || distance > raycaster.far {
      return
    }
    let intersection = Intersection::make(distance, intersect_point, object)
    intersection.distance_to_ray = Some(ray_point_distance_sq.sqrt())
    intersection.index = Some(index)
    intersects.push(intersection)
  }
}

///|
/// Upstream `intersectsFrustum`.
fn hook_points_intersects_frustum(
  object : Object3D,
  frustum : FrustumRef,
) -> Bool {
  match frustum {
    Single(frustum) => frustum_intersects_object(frustum, object)
    Array(frustum) => frustum_array_intersects_object(frustum, object)
  }
}

///|
/// `new this.constructor()`.
fn hook_points_new_like(_object : Object3D) -> Object3D {
  Points::new()
}

///|
/// Calls `object.copy_base( source, recursive )` first, as `super.copy`.
fn hook_points_copy(
  object : Object3D,
  source : Object3D,
  recursive : Bool,
) -> Unit {
  object.copy_base(source, recursive)
  let target = object.points_data()
  let (dictionary, influences) = morph_targets_copy(source)
  target.morph_target_influences = influences
  target.morph_target_dictionary = dictionary
  guard source.get_material() is Some(material) else {
    abort("Points.copy: source has no material")
  }
  guard source.get_geometry() is Some(geometry) else {
    abort("Points.copy: source has no geometry")
  }
  target.material = material_slot_copy(material)
  target.geometry = geometry
}
