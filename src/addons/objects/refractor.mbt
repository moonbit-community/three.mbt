// Upstream examples/jsm/objects/Refractor.js: a refracting surface for WebGLRenderer.
// Its `onBeforeRender` renders the scene behind the surface through an oblique-frustum
// virtual camera into a render target.

///|
/// The state upstream keeps in the constructor's closures and on the instance.
pub(all) struct Refractor {
  /// `refractor.camera`: the virtual camera.
  camera : @core.Object3D
  render_target : @core.RenderTarget
  clip_bias : Double
  refractor_plane : @math.Plane
  texture_matrix : @math.Matrix4
  // visible()
  visible_refractor_world_position : @math.Vector3
  visible_camera_world_position : @math.Vector3
  visible_rotation_matrix : @math.Matrix4
  visible_view : @math.Vector3
  visible_normal : @math.Vector3
  // updateRefractorPlane()
  plane_normal : @math.Vector3
  plane_position : @math.Vector3
  plane_quaternion : @math.Quaternion
  plane_scale : @math.Vector3
  // updateVirtualCamera()
  clip_plane : @math.Plane
  clip_vector : @math.Vector4
  q : @math.Vector4
}

///|
pub impl @core.Object3DExtension for Refractor with fn type_name(_) {
  "Refractor"
}

///|
pub impl @core.Object3DExtension for Refractor with fn construct(_) {
  Refractor::new()
}

///|
pub impl @core.Object3DExtension for Refractor with fn has_flag(_, flag) {
  flag == "isRefractor" || flag == "class:Refractor"
}

///|
/// Upstream's instance `dispose`.
pub impl @core.Object3DExtension for Refractor with fn dispose(self, object) {
  self.render_target.dispose()
  Reflector::material_of(object).dispose()
}

///|
#deprecated
pub extend Refractor with @core.Object3DExtension::{
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
/// `Refractor.RefractorShader`.
pub let refractor_shader : ShaderDefinition = {
  name: Some("RefractorShader"),
  uniforms: Map([
    ("color", { value: Null, }),
    ("tDiffuse", { value: Null, }),
    ("textureMatrix", { value: Null, }),
  ]),
  vertex_shader: _refractor_vertex_shader,
  fragment_shader: _refractor_fragment_shader,
}

///|
/// `new Refractor( geometry, options )`. `color` is a hex (default `0x7F7F7F`); a
/// `texture_width`, `texture_height` or `clip_bias` of 0 takes the default, as upstream's
/// `||` does.
pub fn Refractor::new(
  geometry? : @core.BufferGeometry,
  color? : Int32,
  texture_width~ : Int32 = 0,
  texture_height~ : Int32 = 0,
  clip_bias~ : Double = 0.0,
  shader? : ShaderDefinition,
  multisample~ : Int32 = 4,
) -> @core.Object3D {
  let object = @core.Mesh::new(geometry?)
  let virtual_camera = @core.PerspectiveCamera::new()
  let color = match color {
    Some(hex) => @math.Color::from_hex(hex)
    None => @math.Color::from_hex(0x7F7F7F)
  }
  let texture_width = if texture_width == 0 { 512 } else { texture_width }
  let texture_height = if texture_height == 0 { 512 } else { texture_height }
  let clip_bias = if clip_bias == 0.0 || clip_bias.is_nan() {
    0.0
  } else {
    clip_bias
  }
  let shader = match shader {
    Some(shader) => shader
    None => refractor_shader
  }
  //
  virtual_camera.matrix_auto_update = false
  virtual_camera.user_data.set("refractor", @core.JsValue::of(true))
  //
  let refractor_plane = @math.Plane::new()
  let texture_matrix = @math.Matrix4::new()
  // render target
  let render_target = @webgl.WebGLRenderTarget::new(
    width=texture_width,
    height=texture_height,
    samples=multisample,
    type_=@core.HalfFloatType,
  )
  // material
  let material = @core.ShaderMaterial::new()
  material.name = match shader.name {
    Some(name) => name
    None => "unspecified"
  }
  material.uniforms = Some(@core.UniformsUtils::clone(shader.uniforms))
  material.vertex_shader = Some(shader.vertex_shader)
  material.fragment_shader = Some(shader.fragment_shader)
  material.transparent = true // ensures, refractors are drawn from farthest to closest
  match object.kind {
    Mesh(mesh) => mesh.material = Single(material)
    _ => ()
  }
  objects_uniform(material, "color").value = Color(color)
  objects_uniform(material, "tDiffuse").value = Texture(render_target.texture())
  objects_uniform(material, "textureMatrix").value = Matrix4(texture_matrix)
  let refractor : Refractor = {
    camera: virtual_camera,
    render_target,
    clip_bias,
    refractor_plane,
    texture_matrix,
    visible_refractor_world_position: @math.Vector3::new(0.0, 0.0, 0.0),
    visible_camera_world_position: @math.Vector3::new(0.0, 0.0, 0.0),
    visible_rotation_matrix: @math.Matrix4::new(),
    visible_view: @math.Vector3::new(0.0, 0.0, 0.0),
    visible_normal: @math.Vector3::new(0.0, 0.0, 0.0),
    plane_normal: @math.Vector3::new(0.0, 0.0, 0.0),
    plane_position: @math.Vector3::new(0.0, 0.0, 0.0),
    plane_quaternion: @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
    plane_scale: @math.Vector3::new(0.0, 0.0, 0.0),
    clip_plane: @math.Plane::new(),
    clip_vector: @math.Vector4::new(0.0, 0.0, 0.0, 1.0),
    q: @math.Vector4::new(0.0, 0.0, 0.0, 1.0),
  }
  object.set_extension(refractor) |> ignore
  object.on_before_render = fn(renderer, scene, camera, _, _, _) {
    // ensure refractors are rendered only once per frame
    if camera.user_data.get("refractor").strict_equal(@core.JsValue::of(true)) {
      return
    }
    // avoid rendering when the refractor is viewed from behind
    if !refractor.visible(object, camera) {
      return
    }
    // update
    refractor.update_refractor_plane(object)
    refractor.update_texture_matrix(object, camera)
    refractor.update_virtual_camera(camera)
    refractor.render(object, objects_webgl_renderer(renderer), scene, camera)
  }
  object
}

///|
/// The payload of a `Refractor`, or `None` for other objects.
pub fn Refractor::of(object : @core.Object3D) -> Refractor? {
  objects_payload(object, "class:Refractor")
}

///|
/// `getRenderTarget()`: the internal render target.
pub fn Refractor::get_render_target(
  object : @core.Object3D,
) -> @core.RenderTarget {
  let refractor : Refractor = objects_require(object, "class:Refractor")
  refractor.render_target
}

///|
/// `refractor.camera`: the virtual camera.
pub fn Refractor::get_camera(object : @core.Object3D) -> @core.Object3D {
  let refractor : Refractor = objects_require(object, "class:Refractor")
  refractor.camera
}

///|
/// `visible( camera )`: whether the camera sees the front of the refractor.
fn Refractor::visible(
  self : Refractor,
  scope : @core.Object3D,
  camera : @core.Object3D,
) -> Bool {
  self.visible_refractor_world_position.set_from_matrix_position(
    scope.matrix_world,
  )
  |> ignore
  self.visible_camera_world_position.set_from_matrix_position(
    camera.matrix_world,
  )
  |> ignore
  self.visible_view.sub_vectors(
    self.visible_refractor_world_position,
    self.visible_camera_world_position,
  )
  |> ignore
  self.visible_rotation_matrix.extract_rotation(scope.matrix_world) |> ignore
  self.visible_normal.set(0.0, 0.0, 1.0) |> ignore
  self.visible_normal.apply_matrix4(self.visible_rotation_matrix) |> ignore
  self.visible_view.dot(self.visible_normal) < 0.0
}

///|
/// `updateRefractorPlane()`.
fn Refractor::update_refractor_plane(
  self : Refractor,
  scope : @core.Object3D,
) -> Unit {
  scope.matrix_world.decompose(
    self.plane_position,
    self.plane_quaternion,
    self.plane_scale,
  )
  |> ignore
  self.plane_normal
  .set(0.0, 0.0, 1.0)
  .apply_quaternion(self.plane_quaternion)
  .normalize()
  |> ignore
  // flip the normal because we want to cull everything above the plane
  self.plane_normal.negate() |> ignore
  self.refractor_plane.set_from_normal_and_coplanar_point(
    self.plane_normal,
    self.plane_position,
  )
  |> ignore
}

///|
/// `updateVirtualCamera( camera )`.
fn Refractor::update_virtual_camera(
  self : Refractor,
  camera : @core.Object3D,
) -> Unit {
  let virtual_camera = self.camera
  virtual_camera.matrix_world.copy(camera.matrix_world) |> ignore
  virtual_camera
  .matrix_world_inverse()
  .copy(virtual_camera.matrix_world)
  .invert()
  |> ignore
  virtual_camera.projection_matrix().copy(camera.projection_matrix()) |> ignore
  objects_copy_camera_far(virtual_camera, camera) // used in WebGLBackground
  // The following code creates an oblique view frustum for clipping.
  // see: Lengyel, Eric. “Oblique View Frustum Depth Projection and Clipping”.
  // Journal of Game Development, Vol. 1, No. 2 (2005), Charles River Media, pp. 5–16
  self.clip_plane.copy(self.refractor_plane) |> ignore
  self.clip_plane.apply_matrix4(virtual_camera.matrix_world_inverse()) |> ignore
  self.clip_vector.set(
    self.clip_plane.normal.x,
    self.clip_plane.normal.y,
    self.clip_plane.normal.z,
    self.clip_plane.constant,
  )
  |> ignore
  // calculate the clip-space corner point opposite the clipping plane and
  // transform it into camera space by multiplying it by the inverse of the projection matrix
  let pe = virtual_camera.projection_matrix().elements
  self.q.x = (objects_math_sign(self.clip_vector.x) + pe[8]) / pe[0]
  self.q.y = (objects_math_sign(self.clip_vector.y) + pe[9]) / pe[5]
  self.q.z = -1.0
  self.q.w = (1.0 + pe[10]) / pe[14]
  // calculate the scaled plane vector
  self.clip_vector.multiply_scalar(2.0 / self.clip_vector.dot(self.q)) |> ignore
  // replacing the third row of the projection matrix
  pe[2] = self.clip_vector.x
  pe[6] = self.clip_vector.y
  pe[10] = self.clip_vector.z + 1.0 - self.clip_bias
  pe[14] = self.clip_vector.w
}

///|
/// `updateTextureMatrix( camera )`: range mapping to [ 0, 1 ] times the camera's
/// projection and view and the refractor's model matrix ("Object Linear Texgen").
fn Refractor::update_texture_matrix(
  self : Refractor,
  scope : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  self.texture_matrix.set(
    0.5, 0.0, 0.0, 0.5, 0.0, 0.5, 0.0, 0.5, 0.0, 0.0, 0.5, 0.5, 0.0, 0.0, 0.0, 1.0,
  )
  |> ignore
  self.texture_matrix.multiply(camera.projection_matrix()) |> ignore
  self.texture_matrix.multiply(camera.matrix_world_inverse()) |> ignore
  self.texture_matrix.multiply(scope.matrix_world) |> ignore
}

///|
/// `render( renderer, scene, camera )`.
fn Refractor::render(
  self : Refractor,
  scope : @core.Object3D,
  renderer : @webgl.WebGLRenderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  scope.visible = false
  let current_render_target = renderer.get_render_target()
  let current_xr_enabled = renderer.xr.enabled
  let current_shadow_auto_update = renderer.shadow_map.auto_update
  renderer.xr.set_enabled(false) // avoid camera modification
  renderer.shadow_map.auto_update = false // avoid re-computing shadows
  renderer.set_render_target(Some(self.render_target))
  if !renderer.auto_clear {
    renderer.clear()
  }
  renderer.render(scene, self.camera)
  renderer.xr.set_enabled(current_xr_enabled)
  renderer.shadow_map.auto_update = current_shadow_auto_update
  renderer.set_render_target(current_render_target)
  // restore viewport
  if @webgl.camera_viewport(camera) is Some(viewport) {
    renderer.state.viewport(viewport)
  }
  scope.visible = true
}

///|
let _refractor_vertex_shader : String =
  #|
  #|
  #|		uniform mat4 textureMatrix;
  #|
  #|		varying vec4 vUv;
  #|
  #|		void main() {
  #|
  #|			vUv = textureMatrix * vec4( position, 1.0 );
  #|			gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
  #|
  #|		}

///|
let _refractor_fragment_shader : String =
  #|
  #|
  #|		uniform vec3 color;
  #|		uniform sampler2D tDiffuse;
  #|
  #|		varying vec4 vUv;
  #|
  #|		float blendOverlay( float base, float blend ) {
  #|
  #|			return( base < 0.5 ? ( 2.0 * base * blend ) : ( 1.0 - 2.0 * ( 1.0 - base ) * ( 1.0 - blend ) ) );
  #|
  #|		}
  #|
  #|		vec3 blendOverlay( vec3 base, vec3 blend ) {
  #|
  #|			return vec3( blendOverlay( base.r, blend.r ), blendOverlay( base.g, blend.g ), blendOverlay( base.b, blend.b ) );
  #|
  #|		}
  #|
  #|		void main() {
  #|
  #|			vec4 base = texture2DProj( tDiffuse, vUv );
  #|			gl_FragColor = vec4( blendOverlay( base.rgb, color ), 1.0 );
  #|
  #|			#include <tonemapping_fragment>
  #|			#include <colorspace_fragment>
  #|
  #|		}
