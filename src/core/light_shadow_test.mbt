///|
fn light_shadow_test_camera(size : Double, near : Double) -> @core.Object3D {
  @core.OrthographicCamera::new(
    left=-size,
    right=size,
    top=size,
    bottom=-size,
    near~,
    far=near * 1000.0,
  )
}

///|
test "LightShadow Instancing" {
  let object = @core.LightShadow::new(light_shadow_test_camera(5.0, 0.5))
  assert_eq(object.intensity, 1.0)
  assert_eq(object.bias, 0.0)
  assert_eq(object.normal_bias, 0.0)
  assert_eq(object.radius, 1.0)
  assert_eq(object.blur_samples, 8)
  assert_eq(object.map_size.x, 512.0)
  assert_eq(object.map_type, @core.UnsignedByteType)
  assert_true(object.map is None)
  assert_true(object.map_pass is None)
  assert_true(object.auto_update)
  assert_false(object.needs_update)
}

///|
test "LightShadow dispose" {
  @core.LightShadow::new(@core.Camera::new()).dispose()
}

///|
test "LightShadow dispose disposes both maps" {
  let shadow = @core.LightShadow::new(@core.Camera::new())
  let log = []
  let map = @core.RenderTarget::new()
  map.add_event_listener("dispose", _ => log.push("map"))
  let map_pass = @core.RenderTarget::new()
  map_pass.add_event_listener("dispose", _ => log.push("map_pass"))
  shadow.map = Some(map)
  shadow.map_pass = Some(map_pass)
  shadow.dispose()
  assert_eq(log, ["map", "map_pass"])
}

///|
test "LightShadow clone/copy" {
  let a = @core.LightShadow::new(light_shadow_test_camera(5.0, 0.5))
  let b = @core.LightShadow::new(light_shadow_test_camera(3.0, 0.3))
  assert_false(
    light_test_strip_ids(a.to_json()) == light_test_strip_ids(b.to_json()),
  )
  let c = a.clone()
  assert_eq(
    light_test_strip_ids(a.to_json()),
    light_test_strip_ids(c.to_json()),
  )
  assert_false(physical_equal(a.camera, c.camera))
  ignore(c.map_size.set(256, 256))
  assert_false(
    light_test_strip_ids(a.to_json()) == light_test_strip_ids(c.to_json()),
  )
  ignore(b.copy(a))
  assert_eq(
    light_test_strip_ids(a.to_json()),
    light_test_strip_ids(b.to_json()),
  )
  ignore(b.map_size.set(512, 512))
  ignore(a.map_size.set(1, 1))
  assert_false(
    light_test_strip_ids(a.to_json()) == light_test_strip_ids(b.to_json()),
  )
}

///|
test "LightShadow accessors" {
  let camera = @core.PerspectiveCamera::new()
  let shadow = @core.LightShadow::new(camera)
  assert_true(physical_equal(shadow.get_camera(), camera))
  assert_eq(shadow.get_viewport_count(), 1)
  assert_true(shadow.get_viewport(0).equals(@math.Vector4::new(0, 0, 1, 1)))
  assert_true(shadow.get_frame_extents().equals(@math.Vector2::new(1, 1)))
  assert_true(physical_equal(shadow.get_frustum(), shadow._frustum))
}

///|
test "LightShadow updateMatrices" {
  let light = @core.DirectionalLight::new()
  ignore(light.position.set(0, 10, 0))
  light.update_matrix_world()
  light.light_target().update_matrix_world()
  guard light.as_light().shadow is Some(shadow) else { fail("no shadow") }
  shadow.update_matrices(light)
  assert_true(shadow.camera.position.equals(vec3(0, 10, 0)))
  // the frustum holds the light target, ten units along the shadow camera
  assert_true(shadow.get_frustum().contains_point(vec3(0, 0, 0)))
  assert_false(shadow.get_frustum().contains_point(vec3(100, 0, 0)))
  // the bias matrix sends the target to the middle of the shadow map
  let point = vec3(0, 0, 0).apply_matrix4(shadow.matrix)
  assert_true(approx(point.x, 0.5) && approx(point.y, 0.5))
}

///|
test "LightShadow copy takes the settings outside toJSON" {
  let a = @core.LightShadow::new(@core.PerspectiveCamera::new())
  a.auto_update = false
  a.needs_update = true
  a.map_type = @core.FloatType
  a.bias_node = Some(@core.JsValue::of(1))
  a.shadow_node = Some(@core.JsValue::of(2))
  a.map = Some(@core.RenderTarget::new())
  let b = a.clone()
  assert_false(b.auto_update)
  assert_true(b.needs_update)
  assert_eq(b.map_type, @core.FloatType)
  assert_true(b.bias_node is Some(_))
  // upstream's `copy` leaves these alone
  assert_true(b.shadow_node is None)
  assert_true(b.map is None)
}

///|
test "LightShadow _updateMatrix uses the viewport" {
  let camera = @core.OrthographicCamera::new()
  camera.update_matrix_world()
  let shadow = @core.LightShadow::new(camera)
  ignore(shadow._frame_extents.set(4, 2))
  let matrix = @math.Matrix4::new()
  let frustum = @math.Frustum::new()
  shadow._update_matrix(
    camera,
    matrix,
    frustum,
    viewport=@math.Vector4::new(1, 1, 1, 1),
  )
  let point = vec3(0, 0, -1).apply_matrix4(matrix)
  assert_true(approx(point.x, 0.25 * 0.5 + 0.25))
  assert_true(approx(point.y, 0.5 * 0.5 + 0.5))
}

///|
test "LightShadow matrix keeps Z with WebGPU coordinates" {
  let camera = @core.OrthographicCamera::new(near=1.0, far=3.0)
  camera.as_camera().coordinate_system = @core.WebGPUCoordinateSystem
  camera.update_projection_matrix()
  camera.update_matrix_world()
  let shadow = @core.LightShadow::new(camera)
  let matrix = @math.Matrix4::new()
  shadow._update_matrix(camera, matrix, @math.Frustum::new())
  let point = vec3(0, 0, -3).apply_matrix4(matrix)
  assert_true(approx(point.z, 1.0))
}
