// Upstream src/objects/Sprite.js.

///|
/// The quad every `Sprite` shares, created by the first one.
let _sprite_geometry : Ref[BufferGeometry?] = Ref(None)

///|
let _sprite_intersect_point : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _sprite_world_scale : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _sprite_mv_position : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _sprite_aligned_position : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _sprite_rotated_position : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _sprite_view_world_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _sprite_v_a : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _sprite_v_b : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _sprite_v_c : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _sprite_uv_a : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _sprite_uv_b : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _sprite_uv_c : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
extern "js" fn sprite_cos(x : Double) -> Double = "Math.cos"

///|
extern "js" fn sprite_sin(x : Double) -> Double = "Math.sin"

///|
fn sprite_shared_geometry() -> BufferGeometry {
  match _sprite_geometry.val {
    Some(geometry) => geometry
    None => {
      let geometry = BufferGeometry::new()
      let float32_array = TypedArray::float32([
        -0.5, -0.5, 0.0, 0.0, 0.0, 0.5, -0.5, 0.0, 1.0, 0.0, 0.5, 0.5, 0.0, 1.0,
        1.0, -0.5, 0.5, 0.0, 0.0, 1.0,
      ])
      let interleaved_buffer = InterleavedBuffer::new(float32_array, 5)
      ignore(geometry.set_index([0, 1, 2, 0, 2, 3]))
      ignore(
        geometry.set_attribute(
          "position",
          InterleavedBufferAttribute::new(interleaved_buffer, 3, 0),
        ),
      )
      ignore(
        geometry.set_attribute(
          "uv",
          InterleavedBufferAttribute::new(interleaved_buffer, 2, 3),
        ),
      )
      _sprite_geometry.val = Some(geometry)
      geometry
    }
  }
}

///|
pub fn Sprite::new(material? : Material) -> Object3D {
  // As upstream: the default material (a default argument), then the sprite, then
  // the shared geometry on first use.
  let material = match material {
    Some(material) => material
    None => SpriteMaterial::new()
  }
  let object = Object3D::new(type_="Sprite")
  let sprite : Sprite = {
    geometry: sprite_shared_geometry(),
    material,
    center: @math.Vector2::new(0.5, 0.5),
    count: 1,
  }
  object.kind = Sprite(sprite)
  object
}

///|
fn Object3D::sprite_data(self : Object3D) -> Sprite {
  guard self.kind is Sprite(sprite) else { abort("Object3D: not a Sprite") }
  sprite
}

///|
/// Upstream `raycast`.
fn hook_sprite_raycast(
  object : Object3D,
  raycaster : Raycaster,
  intersects : Array[Intersection],
) -> Unit {
  let sprite = object.sprite_data()
  guard raycaster.camera is Some(camera) else {
    let message = "Sprite: \"Raycaster.camera\" needs to be set in order to raycast against sprites."
    error(message)
    abort(message)
  }
  ignore(_sprite_world_scale.set_from_matrix_scale(object.matrix_world))
  ignore(_sprite_view_world_matrix.copy(camera.matrix_world))
  ignore(
    object.model_view_matrix.multiply_matrices(
      camera.matrix_world_inverse(),
      object.matrix_world,
    ),
  )
  ignore(_sprite_mv_position.set_from_matrix_position(object.model_view_matrix))
  if camera.is_perspective_camera() &&
    sprite.material.size_attenuation is Some(false) {
    ignore(_sprite_world_scale.multiply_scalar(-_sprite_mv_position.z))
  }
  // a material without `rotation` reads `undefined`, which is not 0 and makes these NaN
  let rotation = sprite.material.rotation.unwrap_or(objects_nan())
  let rotated = rotation != 0.0
  let cos = if rotated { sprite_cos(rotation) } else { 0.0 }
  let sin = if rotated { sprite_sin(rotation) } else { 0.0 }
  let center = sprite.center
  sprite_transform_vertex(
    _sprite_v_a.set(-0.5, -0.5, 0.0),
    _sprite_mv_position,
    center,
    _sprite_world_scale,
    rotated,
    sin,
    cos,
  )
  sprite_transform_vertex(
    _sprite_v_b.set(0.5, -0.5, 0.0),
    _sprite_mv_position,
    center,
    _sprite_world_scale,
    rotated,
    sin,
    cos,
  )
  sprite_transform_vertex(
    _sprite_v_c.set(0.5, 0.5, 0.0),
    _sprite_mv_position,
    center,
    _sprite_world_scale,
    rotated,
    sin,
    cos,
  )
  ignore(_sprite_uv_a.set(0.0, 0.0))
  ignore(_sprite_uv_b.set(1.0, 0.0))
  ignore(_sprite_uv_c.set(1.0, 1.0))
  // check first triangle
  let mut intersect = raycaster.ray.intersect_triangle(
    _sprite_v_a, _sprite_v_b, _sprite_v_c, false, _sprite_intersect_point,
  )
  if intersect is None {
    // check second triangle
    sprite_transform_vertex(
      _sprite_v_b.set(-0.5, 0.5, 0.0),
      _sprite_mv_position,
      center,
      _sprite_world_scale,
      rotated,
      sin,
      cos,
    )
    ignore(_sprite_uv_b.set(0.0, 1.0))
    intersect = raycaster.ray.intersect_triangle(
      _sprite_v_a, _sprite_v_c, _sprite_v_b, false, _sprite_intersect_point,
    )
    if intersect is None {
      return
    }
  }
  let distance = raycaster.ray.origin.distance_to(_sprite_intersect_point)
  if distance < raycaster.near || distance > raycaster.far {
    return
  }
  let intersection = Intersection::make(
    distance,
    _sprite_intersect_point.clone(),
    object,
  )
  intersection.uv = @math.Triangle::get_interpolation_static(
    _sprite_intersect_point,
    _sprite_v_a,
    _sprite_v_b,
    _sprite_v_c,
    _sprite_uv_a,
    _sprite_uv_b,
    _sprite_uv_c,
    @math.Vector2::new(0.0, 0.0),
  )
  intersects.push(intersection)
}

///|
fn sprite_transform_vertex(
  vertex_position : @math.Vector3,
  mv_position : @math.Vector3,
  center : @math.Vector2,
  scale : @math.Vector3,
  rotated : Bool,
  sin : Double,
  cos : Double,
) -> Unit {
  // compute position in camera space
  _sprite_aligned_position.x = (vertex_position.x - center.x + 0.5) * scale.x
  _sprite_aligned_position.y = (vertex_position.y - center.y + 0.5) * scale.y
  // to check if rotation is not zero
  if rotated {
    _sprite_rotated_position.x = cos * _sprite_aligned_position.x -
      sin * _sprite_aligned_position.y
    _sprite_rotated_position.y = sin * _sprite_aligned_position.x +
      cos * _sprite_aligned_position.y
  } else {
    ignore(_sprite_rotated_position.copy(_sprite_aligned_position))
  }
  ignore(vertex_position.copy(mv_position))
  vertex_position.x = vertex_position.x + _sprite_rotated_position.x
  vertex_position.y = vertex_position.y + _sprite_rotated_position.y
  // transform to world space
  ignore(vertex_position.apply_matrix4(_sprite_view_world_matrix))
}

///|
/// Upstream `intersectsFrustum`.
fn hook_sprite_intersects_frustum(
  object : Object3D,
  frustum : FrustumRef,
) -> Bool {
  match frustum {
    Single(frustum) => frustum_intersects_sprite(frustum, object)
    Array(frustum) => frustum_array_intersects_sprite(frustum, object)
  }
}

///|
/// `new this.constructor()`.
fn hook_sprite_new_like(_object : Object3D) -> Object3D {
  Sprite::new()
}

///|
/// Calls `object.copy_base( source, recursive )` first, as `super.copy`.
fn hook_sprite_copy(
  object : Object3D,
  source : Object3D,
  recursive : Bool,
) -> Unit {
  object.copy_base(source, recursive)
  let target = object.sprite_data()
  let source_sprite = source.sprite_data()
  ignore(target.center.copy(source_sprite.center))
  target.material = source_sprite.material
}

///|
/// Adds the class's fields to `data`, which is upstream's `data.object`.
fn hook_sprite_to_json(
  object : Object3D,
  _meta : ToJsonMeta,
  data : Map[String, Json],
) -> Unit {
  data["center"] = json_numbers(object.sprite_data().center.to_array())
}
