// The members of src/math that need core types, as free functions named after the math
// class and member, with their upstream scratch objects. Also the typed-array forms of
// `toArray` and `fromArray`, which math only has for `Array[Double]`.

///|
extern "js" fn objects_math_min(a : Double, b : Double) -> Double = "Math.min"

///|
extern "js" fn objects_nan() -> Double = "() => NaN"

///|
fn objects_max_int(a : Int32, b : Int32) -> Int32 {
  if a > b {
    a
  } else {
    b
  }
}

///|
extern "js" fn objects_array_sort(array : JsValue, compare : JsValue) -> Unit = "(a, f) => { a.sort(f); }"

///|
/// `array.sort( compare )`. Core's sorts are unstable or differ on NaN comparisons.
fn[T] objects_stable_sort(array : Array[T], compare : (T, T) -> Double) -> Unit {
  objects_array_sort(JsValue::of(array), JsValue::of(compare))
}

///|
extern "js" fn typed_array_write_elements16(
  array : TypedArray,
  elements : JsValue,
  offset : Int32,
) -> Unit =
  #|(a, e, o) => {
  #|  a[o] = e[0]; a[o + 1] = e[1]; a[o + 2] = e[2]; a[o + 3] = e[3];
  #|  a[o + 4] = e[4]; a[o + 5] = e[5]; a[o + 6] = e[6]; a[o + 7] = e[7];
  #|  a[o + 8] = e[8]; a[o + 9] = e[9]; a[o + 10] = e[10]; a[o + 11] = e[11];
  #|  a[o + 12] = e[12]; a[o + 13] = e[13]; a[o + 14] = e[14]; a[o + 15] = e[15];
  #|}

///|
extern "js" fn typed_array_read_elements16(
  array : TypedArray,
  elements : JsValue,
  offset : Int32,
) -> Unit =
  #|(a, e, o) => {
  #|  e[0] = a[o]; e[1] = a[o + 1]; e[2] = a[o + 2]; e[3] = a[o + 3];
  #|  e[4] = a[o + 4]; e[5] = a[o + 5]; e[6] = a[o + 6]; e[7] = a[o + 7];
  #|  e[8] = a[o + 8]; e[9] = a[o + 9]; e[10] = a[o + 10]; e[11] = a[o + 11];
  #|  e[12] = a[o + 12]; e[13] = a[o + 13]; e[14] = a[o + 14]; e[15] = a[o + 15];
  #|}

///|
/// `matrix.toArray( array, offset )` for a typed array. Allocates nothing.
fn typed_array_write_matrix4(
  array : TypedArray,
  matrix : @math.Matrix4,
  offset : Int32,
) -> Unit {
  typed_array_write_elements16(array, JsValue::of(matrix.elements), offset)
}

///|
/// `matrix.fromArray( array, offset )` for a typed array. Allocates nothing.
fn typed_array_read_matrix4(
  array : TypedArray,
  matrix : @math.Matrix4,
  offset : Int32,
) -> @math.Matrix4 {
  typed_array_read_elements16(array, JsValue::of(matrix.elements), offset)
  matrix
}

///|
/// `color.toArray( array, offset )` for a typed array.
fn typed_array_write_color(
  array : TypedArray,
  color : @math.Color,
  offset : Int32,
) -> Unit {
  array[offset] = color.r
  array[offset + 1] = color.g
  array[offset + 2] = color.b
}

///|
/// `color.fromArray( array, offset )` for a typed array.
fn typed_array_read_color(
  array : TypedArray,
  color : @math.Color,
  offset : Int32,
) -> @math.Color {
  color.r = array[offset]
  color.g = array[offset + 1]
  color.b = array[offset + 2]
  color
}

///|
let _math_bridge_box3_vector : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _math_bridge_box3_box : @math.Box3 = @math.Box3::new()

///|
/// Upstream `Box3.setFromObject`.
pub fn box3_set_from_object(
  box_ : @math.Box3,
  object : Object3D,
  precise~ : Bool = false,
) -> @math.Box3 {
  ignore(box_.make_empty())
  box3_expand_by_object(box_, object, precise~)
}

///|
/// Upstream `Box3.expandByObject`.
pub fn box3_expand_by_object(
  box_ : @math.Box3,
  object : Object3D,
  precise~ : Bool = false,
) -> @math.Box3 {
  // Computes the world-axis-aligned bounding box of an object (including its children),
  // accounting for both the object's, and children's, world transforms
  object.update_world_matrix(false, false)
  if object.get_geometry() is Some(geometry) {
    let position_attribute = geometry.get_attribute("position")
    // precise AABB computation based on vertex data requires at least a position attribute.
    // instancing and batching aren't supported so far and use the normal (conservative) code path.
    if precise &&
      position_attribute is Some(position_attribute) &&
      !object.is_instanced_mesh() &&
      !object.is_batched_mesh() {
      for i in 0..<position_attribute.count() {
        if object.is_mesh() {
          ignore(object.get_vertex_position(i, _math_bridge_box3_vector))
        } else {
          ignore(
            _math_bridge_box3_vector.from_buffer_attribute(
              position_attribute, i,
            ),
          )
        }
        ignore(_math_bridge_box3_vector.apply_matrix4(object.matrix_world))
        ignore(box_.expand_by_point(_math_bridge_box3_vector))
      }
    } else {
      if object.has_object_bounds() {
        // object-level bounding box
        if object.get_bounding_box() is None {
          object.compute_bounding_box()
        }
        guard object.get_bounding_box() is Some(bounding_box) else {
          abort("Box3.expandByObject: object has no bounding box")
        }
        ignore(_math_bridge_box3_box.copy(bounding_box))
      } else {
        // geometry-level bounding box
        if geometry.bounding_box is None {
          geometry.compute_bounding_box()
        }
        guard geometry.bounding_box is Some(bounding_box) else {
          abort("Box3.expandByObject: geometry has no bounding box")
        }
        ignore(_math_bridge_box3_box.copy(bounding_box))
      }
      ignore(_math_bridge_box3_box.apply_matrix4(object.matrix_world))
      ignore(box_.union(_math_bridge_box3_box))
    }
  }
  for child in object.children {
    ignore(box3_expand_by_object(box_, child, precise~))
  }
  box_
}

///|
let _math_bridge_triangle_v40 : @math.Vector4 = @math.Vector4::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
let _math_bridge_triangle_v41 : @math.Vector4 = @math.Vector4::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
let _math_bridge_triangle_v42 : @math.Vector4 = @math.Vector4::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
/// What `triangle_get_interpolated_attribute` writes into: `Vector2`, `Vector3`, `Vector4`.
pub(open) trait InterpolatedAttributeTarget {
  fn set_scalar(Self, Double) -> Self
  /// `addScaledVector` with the `Vector4` upstream passes for all three target types.
  fn add_scaled_vector4(Self, @math.Vector4, Double) -> Self
}

///|
pub impl InterpolatedAttributeTarget for @math.Vector2 with fn set_scalar(
  self,
  scalar,
) {
  self.x = scalar
  self.y = scalar
  self
}

///|
pub impl InterpolatedAttributeTarget for @math.Vector2 with fn add_scaled_vector4(
  self,
  v,
  s,
) {
  self.x = self.x + v.x * s
  self.y = self.y + v.y * s
  self
}

///|
pub impl InterpolatedAttributeTarget for @math.Vector3 with fn set_scalar(
  self,
  scalar,
) {
  self.x = scalar
  self.y = scalar
  self.z = scalar
  self
}

///|
pub impl InterpolatedAttributeTarget for @math.Vector3 with fn add_scaled_vector4(
  self,
  v,
  s,
) {
  self.x = self.x + v.x * s
  self.y = self.y + v.y * s
  self.z = self.z + v.z * s
  self
}

///|
pub impl InterpolatedAttributeTarget for @math.Vector4 with fn set_scalar(
  self,
  scalar,
) {
  self.x = scalar
  self.y = scalar
  self.z = scalar
  self.w = scalar
  self
}

///|
pub impl InterpolatedAttributeTarget for @math.Vector4 with fn add_scaled_vector4(
  self,
  v,
  s,
) {
  self.x = self.x + v.x * s
  self.y = self.y + v.y * s
  self.z = self.z + v.z * s
  self.w = self.w + v.w * s
  self
}

///|
/// Upstream `Triangle.getInterpolatedAttribute`.
pub fn[T : InterpolatedAttributeTarget] triangle_get_interpolated_attribute(
  attr : GeometryAttribute,
  i1 : Int32,
  i2 : Int32,
  i3 : Int32,
  barycoord : @math.Vector3,
  target : T,
) -> T {
  ignore(_math_bridge_triangle_v40.set_scalar(0.0))
  ignore(_math_bridge_triangle_v41.set_scalar(0.0))
  ignore(_math_bridge_triangle_v42.set_scalar(0.0))
  ignore(_math_bridge_triangle_v40.from_buffer_attribute(attr, i1))
  ignore(_math_bridge_triangle_v41.from_buffer_attribute(attr, i2))
  ignore(_math_bridge_triangle_v42.from_buffer_attribute(attr, i3))
  ignore(target.set_scalar(0.0))
  ignore(target.add_scaled_vector4(_math_bridge_triangle_v40, barycoord.x))
  ignore(target.add_scaled_vector4(_math_bridge_triangle_v41, barycoord.y))
  ignore(target.add_scaled_vector4(_math_bridge_triangle_v42, barycoord.z))
  target
}

///|
/// Upstream `Triangle.setFromAttributeAndIndices`.
pub fn triangle_set_from_attribute_and_indices(
  triangle : @math.Triangle,
  attribute : GeometryAttribute,
  i0 : Int32,
  i1 : Int32,
  i2 : Int32,
) -> @math.Triangle {
  ignore(triangle.a.from_buffer_attribute(attribute, i0))
  ignore(triangle.b.from_buffer_attribute(attribute, i1))
  ignore(triangle.c.from_buffer_attribute(attribute, i2))
  triangle
}

///|
let _math_bridge_frustum_sphere : @math.Sphere = @math.Sphere::new()

///|
let _math_bridge_frustum_default_sprite_center : @math.Vector2 = @math.Vector2::new(
  0.5, 0.5,
)

///|
/// Upstream `Frustum.intersectsObject`.
pub fn frustum_intersects_object(
  frustum : @math.Frustum,
  object : Object3D,
) -> Bool {
  if object.has_object_bounds() {
    if object.get_bounding_sphere() is None {
      object.compute_bounding_sphere()
    }
    guard object.get_bounding_sphere() is Some(bounding_sphere) else {
      abort("Frustum.intersectsObject: object has no bounding sphere")
    }
    ignore(
      _math_bridge_frustum_sphere
      .copy(bounding_sphere)
      .apply_matrix4(object.matrix_world),
    )
  } else {
    guard object.get_geometry() is Some(geometry) else {
      abort("Frustum.intersectsObject: object has no geometry")
    }
    if geometry.bounding_sphere is None {
      geometry.compute_bounding_sphere()
    }
    guard geometry.bounding_sphere is Some(bounding_sphere) else {
      abort("Frustum.intersectsObject: geometry has no bounding sphere")
    }
    ignore(
      _math_bridge_frustum_sphere
      .copy(bounding_sphere)
      .apply_matrix4(object.matrix_world),
    )
  }
  frustum.intersects_sphere(_math_bridge_frustum_sphere)
}

///|
/// Upstream `Frustum.intersectsSprite`.
pub fn frustum_intersects_sprite(
  frustum : @math.Frustum,
  sprite : Object3D,
) -> Bool {
  ignore(_math_bridge_frustum_sphere.center.set(0.0, 0.0, 0.0))
  let offset = _math_bridge_frustum_default_sprite_center.distance_to(
    sprite.sprite_data().center,
  )
  _math_bridge_frustum_sphere.radius = 0.7071067811865476 + offset
  ignore(_math_bridge_frustum_sphere.apply_matrix4(sprite.matrix_world))
  frustum.intersects_sphere(_math_bridge_frustum_sphere)
}

///|
let _math_bridge_frustum_array_proj_screen_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
/// Upstream `FrustumArray.setFromArrayCamera`.
pub fn frustum_array_set_from_array_camera(
  frustum_array : @math.FrustumArray,
  camera_array : Object3D,
) -> @math.FrustumArray {
  guard camera_array.kind
    is Camera(
      { kind: PerspectiveCamera({ array_camera: Some(array_camera), .. }), .. }
    ) else {
    abort("FrustumArray.setFromArrayCamera: not an ArrayCamera")
  }
  let cameras = array_camera.cameras
  let frustums = frustum_array.frustums
  for i, camera in cameras {
    ignore(
      _math_bridge_frustum_array_proj_screen_matrix.multiply_matrices(
        camera.projection_matrix(),
        camera.matrix_world_inverse(),
      ),
    )
    if i >= frustums.length() {
      frustums.push(@math.Frustum::new())
    }
    let data = camera.camera_data()
    ignore(
      frustums[i].set_from_projection_matrix(
        _math_bridge_frustum_array_proj_screen_matrix,
        coordinate_system=data.coordinate_system,
        reversed_depth=data._reversed_depth,
      ),
    )
  }
  frustum_array.count = cameras.length()
  frustum_array
}

///|
/// Upstream `FrustumArray.intersectsObject`.
pub fn frustum_array_intersects_object(
  frustum_array : @math.FrustumArray,
  object : Object3D,
) -> Bool {
  let frustums = frustum_array.frustums
  for i in 0..<frustum_array.count {
    if frustum_intersects_object(frustums[i], object) {
      return true
    }
  }
  false
}

///|
/// Upstream `FrustumArray.intersectsSprite`.
pub fn frustum_array_intersects_sprite(
  frustum_array : @math.FrustumArray,
  sprite : Object3D,
) -> Bool {
  let frustums = frustum_array.frustums
  for i in 0..<frustum_array.count {
    if frustum_intersects_sprite(frustums[i], sprite) {
      return true
    }
  }
  false
}
