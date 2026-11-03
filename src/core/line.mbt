// Upstream src/objects/Line.js. `LineLoop` and `LineSegments` are `LineKind`s, with their
// constructors in their own files.

///|
let _line_v_start : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _line_v_end : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _line_inverse_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _line_ray : @math.Ray = @math.Ray::new()

///|
let _line_sphere : @math.Sphere = @math.Sphere::new()

///|
let _line_intersect_point_on_ray : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _line_intersect_point_on_segment : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
/// Builds a `Line`-kind object; `LineLoop` and `LineSegments` pass `kind` and `type_`.
fn line_make(
  geometry : BufferGeometry?,
  material : MaterialSlot?,
  kind : LineKind,
  type_ : String,
) -> Object3D {
  let line : Line = {
    geometry: match geometry {
      Some(geometry) => geometry
      None => BufferGeometry::new()
    },
    material: match material {
      Some(material) => material
      None => Single(LineBasicMaterial::new())
    },
    morph_target_dictionary: None,
    morph_target_influences: None,
    kind,
  }
  let object = Object3D::new(kind=Line(line), type_~)
  object.update_morph_targets()
  object
}

///|
pub fn Line::new(
  geometry? : BufferGeometry,
  material? : MaterialSlot,
) -> Object3D {
  line_make(geometry, material, PlainLine, "Line")
}

///|
fn Object3D::line_data(self : Object3D) -> Line {
  guard self.kind is Line(line) else { abort("Object3D: not a Line") }
  line
}

///|
/// Computes the `lineDistance` attribute. The geometry must not be indexed.
pub fn Object3D::compute_line_distances(self : Object3D) -> Object3D {
  let line = self.line_data()
  match line.kind {
    LineSegments => line_segments_compute_line_distances(line)
    PlainLine | LineLoop => {
      let geometry = line.geometry
      // we assume non-indexed geometry
      if geometry.index is None {
        guard geometry.attributes.get("position") is Some(position_attribute) else {
          abort("Line.computeLineDistances: geometry has no position attribute")
        }
        let line_distances : Array[Double] = [0.0]
        for i in 1..<position_attribute.count() {
          ignore(_line_v_start.from_buffer_attribute(position_attribute, i - 1))
          ignore(_line_v_end.from_buffer_attribute(position_attribute, i))
          line_distances.push(
            line_distances[i - 1] + _line_v_start.distance_to(_line_v_end),
          )
        }
        ignore(
          geometry.set_attribute(
            "lineDistance",
            Float32BufferAttribute::new(line_distances, 1),
          ),
        )
      } else {
        warn(
          "Line.computeLineDistances(): Computation only possible with non-indexed BufferGeometry.",
        )
      }
    }
  }
  self
}

///|
/// Upstream `raycast`.
fn hook_line_raycast(
  object : Object3D,
  raycaster : Raycaster,
  intersects : Array[Intersection],
) -> Unit {
  let line = object.line_data()
  let geometry = line.geometry
  let matrix_world = object.matrix_world
  let threshold = raycaster.params.line.threshold
  let draw_range = geometry.draw_range
  // Checking boundingSphere distance to ray
  if geometry.bounding_sphere is None {
    geometry.compute_bounding_sphere()
  }
  guard geometry.bounding_sphere is Some(bounding_sphere) else {
    abort("Line.raycast: geometry has no bounding sphere")
  }
  ignore(_line_sphere.copy(bounding_sphere))
  ignore(_line_sphere.apply_matrix4(matrix_world))
  _line_sphere.radius = _line_sphere.radius + threshold
  if !raycaster.ray.intersects_sphere(_line_sphere) {
    return
  }
  ignore(_line_inverse_matrix.copy(matrix_world).invert())
  ignore(_line_ray.copy(raycaster.ray).apply_matrix4(_line_inverse_matrix))
  let local_threshold = threshold /
    ((object.scale.x + object.scale.y + object.scale.z) / 3.0)
  let local_threshold_sq = local_threshold * local_threshold
  let step = if line.kind is LineSegments { 2 } else { 1 }
  let draw_end = draw_range.start.to_double() + draw_range.count
  let start = objects_max_int(0, draw_range.start)
  let position_attribute = geometry.attributes.get("position")
  match geometry.index {
    Some(index) => {
      let end = objects_math_min(index.count().to_double(), draw_end)
      for i = start; i.to_double() < end - 1.0; i = i + step {
        let a = index.get_x(i).to_int()
        let b = index.get_x(i + 1).to_int()
        if line_check_intersection(
            object, position_attribute, raycaster, local_threshold_sq, a, b, i,
          )
          is Some(intersect) {
          intersects.push(intersect)
        }
      }
      if line.kind is LineLoop {
        let last = (end - 1.0).to_int()
        let a = line_index_or_outside(index, last)
        let b = line_index_or_outside(index, start)
        if line_check_intersection(
            object, position_attribute, raycaster, local_threshold_sq, a, b, last,
          )
          is Some(intersect) {
          intersects.push(intersect)
        }
      }
    }
    None => {
      guard position_attribute is Some(position) else {
        abort("Line.raycast: geometry has no position attribute")
      }
      let end = objects_math_min(position.count().to_double(), draw_end)
      for i = start; i.to_double() < end - 1.0; i = i + step {
        if line_check_intersection(
            object,
            position_attribute,
            raycaster,
            local_threshold_sq,
            i,
            i + 1,
            i,
          )
          is Some(intersect) {
          intersects.push(intersect)
        }
      }
      if line.kind is LineLoop {
        let last = (end - 1.0).to_int()
        if line_check_intersection(
            object, position_attribute, raycaster, local_threshold_sq, last, start,
            last,
          )
          is Some(intersect) {
          intersects.push(intersect)
        }
      }
    }
  }
}

///|
/// `index.getX( i )` for the closing segment of a `LineLoop`, where an empty draw range
/// reads past the index: upstream's `undefined` then gives NaN positions, as -1 does.
fn line_index_or_outside(index : GeometryAttribute, i : Int32) -> Int32 {
  if i >= 0 && i < index.count() {
    index.get_x(i).to_int()
  } else {
    -1
  }
}

///|
fn line_check_intersection(
  object : Object3D,
  position_attribute : GeometryAttribute?,
  raycaster : Raycaster,
  threshold_sq : Double,
  a : Int32,
  b : Int32,
  i : Int32,
) -> Intersection? {
  guard position_attribute is Some(position_attribute) else {
    abort("Line.raycast: geometry has no position attribute")
  }
  ignore(_line_v_start.from_buffer_attribute(position_attribute, a))
  ignore(_line_v_end.from_buffer_attribute(position_attribute, b))
  let dist_sq = _line_ray.distance_sq_to_segment(
    _line_v_start,
    _line_v_end,
    optional_point_on_ray=_line_intersect_point_on_ray,
    optional_point_on_segment=_line_intersect_point_on_segment,
  )
  if dist_sq > threshold_sq {
    return None
  }
  // Move back to world space for distance calculation
  ignore(_line_intersect_point_on_ray.apply_matrix4(object.matrix_world))
  let distance = raycaster.ray.origin.distance_to(_line_intersect_point_on_ray)
  if distance < raycaster.near || distance > raycaster.far {
    return None
  }
  let intersection = Intersection::make(
    distance,
    _line_intersect_point_on_segment.clone().apply_matrix4(object.matrix_world),
    object,
  )
  intersection.index = Some(i)
  Some(intersection)
}

///|
/// Upstream `intersectsFrustum`.
fn hook_line_intersects_frustum(
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
fn hook_line_new_like(object : Object3D) -> Object3D {
  match object.line_data().kind {
    PlainLine => Line::new()
    LineLoop => LineLoop::new()
    LineSegments => LineSegments::new()
  }
}

///|
/// Calls `object.copy_base( source, recursive )` first, as `super.copy`.
fn hook_line_copy(
  object : Object3D,
  source : Object3D,
  recursive : Bool,
) -> Unit {
  object.copy_base(source, recursive)
  let target = object.line_data()
  let (dictionary, influences) = morph_targets_copy(source)
  target.morph_target_influences = influences
  target.morph_target_dictionary = dictionary
  guard source.get_material() is Some(material) else {
    abort("Line.copy: source has no material")
  }
  guard source.get_geometry() is Some(geometry) else {
    abort("Line.copy: source has no geometry")
  }
  target.material = material_slot_copy(material)
  target.geometry = geometry
}
