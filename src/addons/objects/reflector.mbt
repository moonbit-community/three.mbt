// Upstream examples/jsm/objects/Reflector.js: a flat mirror for WebGLRenderer. Its
// `onBeforeRender` renders the scene from a mirrored camera into a render target that
// the `ReflectorShader` material projects onto the surface.

///|
/// The state upstream keeps in the constructor's closure and on the instance.
pub(all) struct Reflector {
  /// Renders the reflection even when the reflector faces away.
  mut force_update : Bool
  _reflection_cameras : @webgl.WeakMap[@core.Object3D, @core.Object3D]
  render_target : @core.RenderTarget
  clip_bias : Double
  reflector_plane : @math.Plane
  normal : @math.Vector3
  reflector_world_position : @math.Vector3
  camera_world_position : @math.Vector3
  rotation_matrix : @math.Matrix4
  look_at_position : @math.Vector3
  clip_plane : @math.Vector4
  view : @math.Vector3
  target : @math.Vector3
  q : @math.Vector4
  texture_matrix : @math.Matrix4
}

///|
pub impl @core.Object3DExtension for Reflector with fn type_name(_) {
  "Reflector"
}

///|
pub impl @core.Object3DExtension for Reflector with fn construct(_) {
  Reflector::new()
}

///|
pub impl @core.Object3DExtension for Reflector with fn has_flag(_, flag) {
  flag == "isReflector" || flag == "class:Reflector"
}

///|
/// Upstream's instance `dispose`.
pub impl @core.Object3DExtension for Reflector with fn dispose(self, object) {
  self.render_target.dispose()
  Reflector::material_of(object).dispose()
}

///|
fn Reflector::material_of(object : @core.Object3D) -> @core.Material {
  match object.kind {
    Mesh({ material: Single(m), .. }) => m
    Mesh({ material: Multiple(m), .. }) => m[0]
    _ => abort("TypeError: not a mesh")
  }
}

///|
#deprecated
pub extend Reflector with @core.Object3DExtension::{
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
/// `Reflector.ReflectorShader`.
pub let reflector_shader : ShaderDefinition = {
  name: Some("ReflectorShader"),
  uniforms: Map([
    ("color", { value: Null, }),
    ("tDiffuse", { value: Null, }),
    ("textureMatrix", { value: Null, }),
  ]),
  vertex_shader: _reflector_vertex_shader,
  fragment_shader: _reflector_fragment_shader,
}

///|
/// `new Reflector( geometry, options )`. `color` is a hex (default `0x7F7F7F`); a
/// `texture_width`, `texture_height` or `clip_bias` of 0 takes the default, as upstream's
/// `||` does.
pub fn Reflector::new(
  geometry? : @core.BufferGeometry,
  color? : Int32,
  texture_width~ : Int32 = 0,
  texture_height~ : Int32 = 0,
  clip_bias~ : Double = 0.0,
  shader? : ShaderDefinition,
  multisample~ : Int32 = 4,
) -> @core.Object3D {
  let object = @core.Mesh::new(geometry?)
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
    None => reflector_shader
  }
  let texture_matrix = @math.Matrix4::new()
  let render_target = @webgl.WebGLRenderTarget::new(
    width=texture_width,
    height=texture_height,
    samples=multisample,
    type_=@core.HalfFloatType,
  )
  let material = @core.ShaderMaterial::new()
  material.name = match shader.name {
    Some(name) => name
    None => "unspecified"
  }
  material.uniforms = Some(@core.UniformsUtils::clone(shader.uniforms))
  material.fragment_shader = Some(shader.fragment_shader)
  material.vertex_shader = Some(shader.vertex_shader)
  objects_uniform(material, "tDiffuse").value = Texture(render_target.texture())
  objects_uniform(material, "color").value = Color(color)
  objects_uniform(material, "textureMatrix").value = Matrix4(texture_matrix)
  match object.kind {
    Mesh(mesh) => mesh.material = Single(material)
    _ => ()
  }
  let reflector : Reflector = {
    force_update: false,
    _reflection_cameras: @webgl.WeakMap::new(),
    render_target,
    clip_bias,
    reflector_plane: @math.Plane::new(),
    normal: @math.Vector3::new(0.0, 0.0, 0.0),
    reflector_world_position: @math.Vector3::new(0.0, 0.0, 0.0),
    camera_world_position: @math.Vector3::new(0.0, 0.0, 0.0),
    rotation_matrix: @math.Matrix4::new(),
    look_at_position: @math.Vector3::new(0.0, 0.0, -1.0),
    clip_plane: @math.Vector4::new(0.0, 0.0, 0.0, 1.0),
    view: @math.Vector3::new(0.0, 0.0, 0.0),
    target: @math.Vector3::new(0.0, 0.0, 0.0),
    q: @math.Vector4::new(0.0, 0.0, 0.0, 1.0),
    texture_matrix,
  }
  object.set_extension(reflector) |> ignore
  object.on_before_render = fn(renderer, scene, camera, _, _, _) {
    reflector.on_before_render(
      object,
      objects_webgl_renderer(renderer),
      scene,
      camera,
    )
  }
  object
}

///|
/// The payload of a `Reflector`, or `None` for other objects.
pub fn Reflector::of(object : @core.Object3D) -> Reflector? {
  objects_payload(object, "class:Reflector")
}

///|
/// `reflector.forceUpdate`.
pub fn Reflector::set_force_update(
  object : @core.Object3D,
  value : Bool,
) -> Unit {
  let reflector : Reflector = objects_require(object, "class:Reflector")
  reflector.force_update = value
}

///|
/// `getRenderTarget()`: the internal render target.
pub fn Reflector::get_render_target(
  object : @core.Object3D,
) -> @core.RenderTarget {
  let reflector : Reflector = objects_require(object, "class:Reflector")
  reflector.render_target
}

///|
/// `getReflectionCamera( camera )`: the mirrored camera kept for `camera`.
pub fn Reflector::get_reflection_camera(
  object : @core.Object3D,
  camera : @core.Object3D,
) -> @core.Object3D {
  let reflector : Reflector = objects_require(object, "class:Reflector")
  reflector.reflection_camera(camera)
}

///|
fn Reflector::reflection_camera(
  self : Reflector,
  camera : @core.Object3D,
) -> @core.Object3D {
  match self._reflection_cameras.get(camera) {
    Some(reflection_camera) => reflection_camera
    None => {
      let reflection_camera = camera.clone()
      self._reflection_cameras.set(camera, reflection_camera)
      reflection_camera
    }
  }
}

///|
/// `onBeforeRender( renderer, scene, camera )`, with `this` the reflector.
fn Reflector::on_before_render(
  self : Reflector,
  scope : @core.Object3D,
  renderer : @webgl.WebGLRenderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  let reflection_camera = self.reflection_camera(camera)
  self.reflector_world_position.set_from_matrix_position(scope.matrix_world)
  |> ignore
  self.camera_world_position.set_from_matrix_position(camera.matrix_world)
  |> ignore
  self.rotation_matrix.extract_rotation(scope.matrix_world) |> ignore
  self.normal.set(0.0, 0.0, 1.0) |> ignore
  self.normal.apply_matrix4(self.rotation_matrix) |> ignore
  self.view.sub_vectors(
    self.reflector_world_position,
    self.camera_world_position,
  )
  |> ignore
  // Avoid rendering when reflector is facing away unless forcing an update
  let is_facing_away = self.view.dot(self.normal) > 0.0
  if is_facing_away && !self.force_update {
    return
  }
  self.view.reflect(self.normal).negate() |> ignore
  self.view.add(self.reflector_world_position) |> ignore
  self.rotation_matrix.extract_rotation(camera.matrix_world) |> ignore
  self.look_at_position.set(0.0, 0.0, -1.0) |> ignore
  self.look_at_position.apply_matrix4(self.rotation_matrix) |> ignore
  self.look_at_position.add(self.camera_world_position) |> ignore
  self.target.sub_vectors(self.reflector_world_position, self.look_at_position)
  |> ignore
  self.target.reflect(self.normal).negate() |> ignore
  self.target.add(self.reflector_world_position) |> ignore
  reflection_camera.position.copy(self.view) |> ignore
  reflection_camera.up.set(0.0, 1.0, 0.0) |> ignore
  reflection_camera.up.apply_matrix4(self.rotation_matrix) |> ignore
  reflection_camera.up.reflect(self.normal) |> ignore
  reflection_camera.look_at(self.target)
  objects_copy_camera_far(reflection_camera, camera) // Used in WebGLBackground
  reflection_camera.update_matrix_world()
  reflection_camera.projection_matrix().copy(camera.projection_matrix())
  |> ignore
  // The reflection is mirrored horizontally, so the view offset must be mirrored as well.
  let e = reflection_camera.projection_matrix().elements
  e[8] *= -1.0
  e[12] *= -1.0
  // Update the texture matrix
  self.texture_matrix.set(
    0.5, 0.0, 0.0, 0.5, 0.0, 0.5, 0.0, 0.5, 0.0, 0.0, 0.5, 0.5, 0.0, 0.0, 0.0, 1.0,
  )
  |> ignore
  self.texture_matrix.multiply(reflection_camera.projection_matrix()) |> ignore
  self.texture_matrix.multiply(reflection_camera.matrix_world_inverse())
  |> ignore
  self.texture_matrix.multiply(scope.matrix_world) |> ignore
  // Now update projection matrix with new clip plane, implementing code from: http://www.terathon.com/code/oblique.html
  // Paper explaining this technique: http://www.terathon.com/lengyel/Lengyel-Oblique.pdf
  self.reflector_plane.set_from_normal_and_coplanar_point(
    self.normal,
    self.reflector_world_position,
  )
  |> ignore
  self.reflector_plane.apply_matrix4(reflection_camera.matrix_world_inverse())
  |> ignore
  self.clip_plane.set(
    self.reflector_plane.normal.x,
    self.reflector_plane.normal.y,
    self.reflector_plane.normal.z,
    self.reflector_plane.constant,
  )
  |> ignore
  let projection_matrix = reflection_camera.projection_matrix()
  let pe = projection_matrix.elements
  if reflection_camera.is_orthographic_camera() {
    self.q.x = (objects_math_sign(self.clip_plane.x) + pe[8]) / pe[0]
    self.q.y = (objects_math_sign(self.clip_plane.y) + pe[9]) / pe[5]
    // actual view-space z at the far plane, no normalization needed
    self.q.z = match objects_camera_far(camera) {
      Some(far) => -far
      None => 0.0 / 0.0
    }
    self.q.w = 1.0 // w_clip = 1 in orthographic (no perspective division)
  } else {
    self.q.x = (objects_math_sign(self.clip_plane.x) + pe[8]) / pe[0]
    self.q.y = (objects_math_sign(self.clip_plane.y) + pe[9]) / pe[5]
    self.q.z = -1.0
    self.q.w = (1.0 + pe[10]) / pe[14]
  }
  // Calculate the scaled plane vector
  self.clip_plane.multiply_scalar(2.0 / self.clip_plane.dot(self.q)) |> ignore
  // Replacing the third row of the projection matrix
  pe[2] = self.clip_plane.x
  pe[6] = self.clip_plane.y
  if reflection_camera.is_orthographic_camera() {
    // For orthographic cameras, w_clip = 1 always (no perspective division),
    // so the -1 near-plane offset must go into the constant term (elements[14])
    // rather than the z coefficient (elements[10]).
    pe[10] = self.clip_plane.z - self.clip_bias
    pe[14] = self.clip_plane.w - 1.0
  } else {
    pe[10] = self.clip_plane.z + 1.0 - self.clip_bias
    pe[14] = self.clip_plane.w
  }
  // Render
  scope.visible = false
  let current_render_target = renderer.get_render_target()
  let current_xr_enabled = renderer.xr.enabled
  let current_shadow_auto_update = renderer.shadow_map.auto_update
  renderer.xr.set_enabled(false) // Avoid camera modification
  renderer.shadow_map.auto_update = false // Avoid re-computing shadows
  renderer.set_render_target(Some(self.render_target))
  // make sure the depth buffer is writable so it can be properly cleared, see #18897
  renderer.state.buffers.depth.set_mask(true)
  if !renderer.auto_clear {
    renderer.clear()
  }
  renderer.render(scene, reflection_camera)
  renderer.xr.set_enabled(current_xr_enabled)
  renderer.shadow_map.auto_update = current_shadow_auto_update
  renderer.set_render_target(current_render_target)
  // Restore viewport
  if @webgl.camera_viewport(camera) is Some(viewport) {
    renderer.state.viewport(viewport)
  }
  scope.visible = true
  self.force_update = false
}

///|
let _reflector_vertex_shader : String =
  #|
  #|		uniform mat4 textureMatrix;
  #|		varying vec4 vUv;
  #|
  #|		#include <common>
  #|		#include <logdepthbuf_pars_vertex>
  #|
  #|		void main() {
  #|
  #|			vUv = textureMatrix * vec4( position, 1.0 );
  #|
  #|			gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
  #|
  #|			#include <logdepthbuf_vertex>
  #|
  #|		}

///|
let _reflector_fragment_shader : String =
  #|
  #|		uniform vec3 color;
  #|		uniform sampler2D tDiffuse;
  #|		varying vec4 vUv;
  #|
  #|		#include <logdepthbuf_pars_fragment>
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
  #|			#include <logdepthbuf_fragment>
  #|
  #|			vec4 base = texture2DProj( tDiffuse, vUv );
  #|			gl_FragColor = vec4( blendOverlay( base.rgb, color ), 1.0 );
  #|
  #|			#include <tonemapping_fragment>
  #|			#include <colorspace_fragment>
  #|
  #|		}
