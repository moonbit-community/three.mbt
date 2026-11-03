// Upstream src/lights/LightShadow.js. Subclass behaviour dispatches on `kind`; the
// subclass parts are in directional_light_shadow.mbt, point_light_shadow.mbt and
// spot_light_shadow.mbt.

///|
let _light_shadow_proj_screen_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _light_shadow_light_position_world : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _light_shadow_look_target : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
fn LightShadow::with_kind(
  camera : Object3D,
  kind : LightShadowKind,
) -> LightShadow {
  {
    camera,
    intensity: 1.0,
    bias: 0.0,
    bias_node: None,
    shadow_node: None,
    filter_node: None,
    normal_bias: 0.0,
    radius: 1.0,
    blur_samples: 8,
    map_size: @math.Vector2::new(512.0, 512.0),
    map_type: UnsignedByteType,
    map: None,
    map_pass: None,
    matrix: @math.Matrix4::new(),
    auto_update: true,
    needs_update: false,
    _frustum: @math.Frustum::new(),
    _frame_extents: @math.Vector2::new(1.0, 1.0),
    _viewport_count: 1,
    _viewports: [@math.Vector4::new(0.0, 0.0, 1.0, 1.0)],
    kind,
  }
}

///|
/// `new LightShadow( camera )`.
pub fn LightShadow::new(camera : Object3D) -> LightShadow {
  LightShadow::with_kind(camera, BaseLightShadow)
}

///|
pub fn LightShadow::get_viewport_count(self : LightShadow) -> Int32 {
  self._viewport_count
}

///|
pub fn LightShadow::get_camera(self : LightShadow) -> Object3D {
  self.camera
}

///|
pub fn LightShadow::get_frustum(self : LightShadow) -> @math.Frustum {
  self._frustum
}

///|
/// `light` is a `DirectionalLight` or `SpotLight`, as upstream reads `light.target`.
pub fn LightShadow::update_matrices(
  self : LightShadow,
  light : Object3D,
) -> Unit {
  match self.kind {
    SpotLightShadow(spot) => spot.update_camera(self, light)
    BaseLightShadow | DirectionalLightShadow | PointLightShadow => ()
  }
  let shadow_camera = self.camera
  ignore(
    _light_shadow_light_position_world.set_from_matrix_position(
      light.matrix_world,
    ),
  )
  ignore(shadow_camera.position.copy(_light_shadow_light_position_world))
  ignore(
    _light_shadow_look_target.set_from_matrix_position(
      light.light_target().matrix_world,
    ),
  )
  shadow_camera.look_at(_light_shadow_look_target)
  shadow_camera.update_matrix_world()
  self._update_matrix(shadow_camera, self.matrix, self._frustum)
}

///|
/// Upstream `_updateMatrix`.
pub fn LightShadow::_update_matrix(
  self : LightShadow,
  shadow_camera : Object3D,
  shadow_matrix : @math.Matrix4,
  frustum : @math.Frustum,
  viewport? : @math.Vector4,
) -> Unit {
  let camera = shadow_camera.camera_data()
  ignore(
    _light_shadow_proj_screen_matrix.multiply_matrices(
      camera.projection_matrix,
      camera.matrix_world_inverse,
    ),
  )
  ignore(
    frustum.set_from_projection_matrix(
      _light_shadow_proj_screen_matrix,
      coordinate_system=camera.coordinate_system,
      reversed_depth=camera._reversed_depth,
    ),
  )
  let frame_extents = self._frame_extents
  let (scale_x, scale_y, offset_x, offset_y) = match viewport {
    Some(viewport) =>
      (
        viewport.z / frame_extents.x,
        viewport.w / frame_extents.y,
        viewport.x / frame_extents.x,
        viewport.y / frame_extents.y,
      )
    None => (1.0, 1.0, 0.0, 0.0)
  }
  if camera.coordinate_system == WebGPUCoordinateSystem ||
    camera._reversed_depth {
    ignore(
      shadow_matrix.set(
        0.5 * scale_x,
        0.0,
        0.0,
        0.5 * scale_x + offset_x,
        0.0,
        0.5 * scale_y,
        0.0,
        0.5 * scale_y + offset_y,
        0.0,
        0.0,
        1.0,
        0.0, // Identity Z (preserving the correct [0, 1] range from the projection matrix)
        0.0,
        0.0,
        0.0,
        1.0,
      ),
    )
  } else {
    ignore(
      shadow_matrix.set(
        0.5 * scale_x,
        0.0,
        0.0,
        0.5 * scale_x + offset_x,
        0.0,
        0.5 * scale_y,
        0.0,
        0.5 * scale_y + offset_y,
        0.0,
        0.0,
        0.5,
        0.5,
        0.0,
        0.0,
        0.0,
        1.0,
      ),
    )
  }
  ignore(shadow_matrix.multiply(_light_shadow_proj_screen_matrix))
}

///|
pub fn LightShadow::get_viewport(
  self : LightShadow,
  viewport_index : Int32,
) -> @math.Vector4 {
  self._viewports[viewport_index]
}

///|
pub fn LightShadow::get_frame_extents(self : LightShadow) -> @math.Vector2 {
  self._frame_extents
}

///|
pub fn LightShadow::dispose(self : LightShadow) -> Unit {
  if self.map is Some(map) {
    map.dispose()
  }
  if self.map_pass is Some(map_pass) {
    map_pass.dispose()
  }
}

///|
pub fn LightShadow::copy(
  self : LightShadow,
  source : LightShadow,
) -> LightShadow {
  self.camera = source.camera.clone()
  self.intensity = source.intensity
  self.bias = source.bias
  self.radius = source.radius
  self.auto_update = source.auto_update
  self.needs_update = source.needs_update
  self.normal_bias = source.normal_bias
  self.blur_samples = source.blur_samples
  ignore(self.map_size.copy(source.map_size))
  self.map_type = source.map_type
  self.bias_node = source.bias_node
  match (self.kind, source.kind) {
    (SpotLightShadow(spot), SpotLightShadow(source_spot)) => {
      spot.focus = source_spot.focus
      spot.aspect = source_spot.aspect
    }
    (SpotLightShadow(_), _) =>
      abort("SpotLightShadow.copy: source is not a SpotLightShadow")
    _ => ()
  }
  self
}

///|
pub fn LightShadow::clone(self : LightShadow) -> LightShadow {
  // `new this.constructor()`; `copy` replaces the camera of the base class.
  let shadow = match self.kind {
    BaseLightShadow => LightShadow::new(self.camera)
    DirectionalLightShadow => DirectionalLightShadow::new()
    PointLightShadow => PointLightShadow::new()
    SpotLightShadow(_) => SpotLightShadow::new()
  }
  shadow.copy(self)
}

///|
pub fn LightShadow::to_json(self : LightShadow) -> Json {
  let object : Map[String, Json] = Map([])
  object["intensity"] = @math.json_number(self.intensity)
  object["bias"] = @math.json_number(self.bias)
  object["normalBias"] = @math.json_number(self.normal_bias)
  object["radius"] = @math.json_number(self.radius)
  object["blurSamples"] = json_int(self.blur_samples)
  object["mapSize"] = json_numbers(self.map_size.to_array())
  object["mapType"] = json_int(self.map_type)
  // `this.camera.toJSON( false ).object`
  guard self.camera.to_json(meta=ToJsonMeta::new()) is Object(output) &&
    output.get("object") is Some(Object(camera)) else {
    abort("LightShadow.toJSON: camera has no object")
  }
  camera.remove("matrix")
  object["camera"] = Json::object(camera)
  if self.kind is SpotLightShadow(spot) {
    object["focus"] = @math.json_number(spot.focus)
    object["aspect"] = @math.json_number(spot.aspect)
  }
  Json::object(object)
}
