// State upstream attaches to objects owned by `core`, `shaders` or addons, kept here
// because those types have no field for it. Each is a `WeakMap` keyed by the object, so
// the semantics (per object, collected with it) match upstream's ad-hoc properties.

///|
let webgl_uniform_needs_update : WeakMap[@core.Uniform, Bool] = WeakMap::new()

///|
/// `uniform.needsUpdate`; `None` is `undefined`, which `WebGLUniforms.upload` treats as
/// "always upload".
pub fn uniform_needs_update(uniform : @core.Uniform) -> Bool? {
  webgl_uniform_needs_update.get(uniform)
}

///|
/// `uniform.needsUpdate = value`.
pub fn set_uniform_needs_update(uniform : @core.Uniform, value : Bool) -> Unit {
  webgl_uniform_needs_update.set(uniform, value)
}

///|
let webgl_uniform_type : WeakMap[@core.Uniform, String] = WeakMap::new()

///|
/// `uniform.type` of a uniform in a `UniformsGroup` (`'int'`, `'uint'`; `None` is float).
pub fn uniform_type(uniform : @core.Uniform) -> String? {
  webgl_uniform_type.get(uniform)
}

///|
/// `uniform.type = value`.
pub fn set_uniform_type(uniform : @core.Uniform, value : String) -> Unit {
  webgl_uniform_type.set(uniform, value)
}

///|
let webgl_geometry_max_instance_count : WeakMap[@core.BufferGeometry, Int32] = WeakMap::new()

///|
/// `geometry._maxInstanceCount`, set by `WebGLBindingStates` for instanced attributes.
pub fn geometry_max_instance_count(geometry : @core.BufferGeometry) -> Int32? {
  webgl_geometry_max_instance_count.get(geometry)
}

///|
/// `geometry._maxInstanceCount = value`.
pub fn set_geometry_max_instance_count(
  geometry : @core.BufferGeometry,
  value : Int32,
) -> Unit {
  webgl_geometry_max_instance_count.set(geometry, value)
}

///|
/// `delete geometry._maxInstanceCount`.
pub fn delete_geometry_max_instance_count(
  geometry : @core.BufferGeometry,
) -> Unit {
  webgl_geometry_max_instance_count.delete(geometry)
}

///|
let webgl_camera_viewport : WeakMap[@core.Object3D, @math.Vector4] = WeakMap::new()

///|
/// `camera.viewport`, set on the sub-cameras of an `ArrayCamera` (and by WebXR).
pub fn camera_viewport(camera : @core.Object3D) -> @math.Vector4? {
  webgl_camera_viewport.get(camera)
}

///|
/// `camera.viewport = value`; `None` is `camera.viewport = undefined`.
pub fn set_camera_viewport(
  camera : @core.Object3D,
  value : @math.Vector4?,
) -> Unit {
  match value {
    Some(viewport) => webgl_camera_viewport.set(camera, viewport)
    None => webgl_camera_viewport.delete(camera)
  }
}

///|
/// What the renderer reads from an addon `LightProbeGrid` (`isLightProbeGrid`).
pub(open) trait LightProbeGridSource {
  /// `grid.texture`; `None` skips the grid.
  fn texture(Self) -> @core.Texture?
  /// `grid.boundingBox`.
  fn bounding_box(Self) -> @math.Box3
  /// `grid.resolution`.
  fn resolution(Self) -> @math.Vector3
  /// `grid.priority`.
  fn priority(Self) -> Double
}

///|
let webgl_light_probe_grids : WeakMap[@core.Object3D, &LightProbeGridSource] = WeakMap::new()

///|
/// Registers an addon `LightProbeGrid` light so the renderer can read it. The addon
/// calls this when it constructs the object; it must also answer
/// `has_flag("isLightProbeGrid")` in its `Object3DExtension`.
pub fn register_light_probe_grid(
  object : @core.Object3D,
  source : &LightProbeGridSource,
) -> Unit {
  webgl_light_probe_grids.set(object, source)
}

///|
/// The registered `LightProbeGrid` data of `object`.
pub fn light_probe_grid_of(object : @core.Object3D) -> &LightProbeGridSource? {
  webgl_light_probe_grids.get(object)
}

///|
/// `light.isLightProbeGrid`.
pub fn is_light_probe_grid(object : @core.Object3D) -> Bool {
  object.has_extension_flag("isLightProbeGrid")
}

///|
/// What `WebGLLights` and `WebGLShadowMap` read from an addon `SunLight` (`isSunLight`)
/// beyond the core `Light` fields: its cascaded shadow. `shadow` is the light's core
/// `LightShadow`; the defaults are `LightShadow`'s own methods, which a `SunLightShadow`
/// overrides.
pub(open) trait SunLightShadowSource {
  /// `shadow.getMatrix( cascade )`.
  fn get_matrix(Self, Int32) -> @math.Matrix4
  /// `shadow._cascadeData[ cascade ]`, uploaded as the `sunShadowCascade` uniform.
  fn cascade_data(Self, Int32) -> @core.UniformValue
  /// `shadow.getCamera( cascade )`.
  fn get_camera(Self, @core.LightShadow, Int32) -> @core.Object3D = _
  /// `shadow.getFrustum( cascade )`.
  fn get_frustum(Self, @core.LightShadow, Int32) -> @math.Frustum = _
  /// `shadow.getViewport( cascade )`.
  fn get_viewport(Self, @core.LightShadow, Int32) -> @math.Vector4 = _
  /// `shadow.updateMatrices( light, viewCamera )`.
  fn update_matrices(Self, @core.LightShadow, @core.Object3D, @core.Object3D) -> Unit = _
}

///|
impl SunLightShadowSource with fn get_camera(_, shadow, _) {
  shadow.get_camera()
}

///|
impl SunLightShadowSource with fn get_frustum(_, shadow, _) {
  shadow.get_frustum()
}

///|
impl SunLightShadowSource with fn get_viewport(_, shadow, cascade) {
  shadow.get_viewport(cascade)
}

///|
impl SunLightShadowSource with fn update_matrices(_, shadow, light, _) {
  shadow.update_matrices(light)
}

///|
let webgl_sun_light_shadows : WeakMap[@core.Object3D, &SunLightShadowSource] = WeakMap::new()

///|
/// Registers an addon `SunLight`. The addon calls this at construction and answers
/// `has_flag("isSunLight")`; its `type_` is `"SunLight"`.
pub fn register_sun_light(
  object : @core.Object3D,
  shadow : &SunLightShadowSource,
) -> Unit {
  webgl_sun_light_shadows.set(object, shadow)
}

///|
/// The registered `SunLight` shadow of `object`.
pub fn sun_light_shadow_of(object : @core.Object3D) -> &SunLightShadowSource? {
  webgl_sun_light_shadows.get(object)
}

///|
/// `light.isSunLight`.
pub fn is_sun_light(object : @core.Object3D) -> Bool {
  object.has_extension_flag("isSunLight")
}

///|
/// `UniformsLib.LTC_FLOAT_1` / `LTC_FLOAT_2` / `LTC_HALF_1` / `LTC_HALF_2`: the
/// rect-area-light lookup textures. The `RectAreaLightUniformsLib` addon assigns them;
/// `WebGLLights` reads them. They are textures, not uniforms, so they live here instead
/// of in `@shaders.uniforms_lib`.
pub(all) struct UniformsLibLTC {
  mut ltc_float_1 : @core.Texture?
  mut ltc_float_2 : @core.Texture?
  mut ltc_half_1 : @core.Texture?
  mut ltc_half_2 : @core.Texture?
}

///|
/// The process-wide `UniformsLib.LTC_*` slots.
pub let uniforms_lib_ltc : UniformsLibLTC = {
  ltc_float_1: None,
  ltc_float_2: None,
  ltc_half_1: None,
  ltc_half_2: None,
}

///|
let webgl_interleaved_buffer_sources : WeakMap[
  @core.InterleavedBuffer,
  @core.BufferAttribute,
] = WeakMap::new()

///|
/// The buffer attribute an interleaved buffer stands for: upstream's interleaved
/// attributes can view a buffer attribute (`new InterleavedBufferAttribute( attribute,
/// itemSize, offset )`, the columns of instance matrices), and the GL buffer is then the
/// attribute's. Registered by the nodes package for its stand-in interleaved buffers.
pub fn interleaved_buffer_source(
  buffer : @core.InterleavedBuffer,
) -> @core.BufferAttribute? {
  webgl_interleaved_buffer_sources.get(buffer)
}

///|
/// Registers `buffer` as standing for `attribute` (see `interleaved_buffer_source`).
pub fn set_interleaved_buffer_source(
  buffer : @core.InterleavedBuffer,
  attribute : @core.BufferAttribute,
) -> Unit {
  webgl_interleaved_buffer_sources.set(buffer, attribute)
}
