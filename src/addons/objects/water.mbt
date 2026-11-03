// Upstream examples/jsm/objects/Water.js: a reflecting ocean surface for WebGLRenderer.
// Its `onBeforeRender` renders a mirrored view into a render target; the `MirrorShader`
// distorts it with scrolling normal maps and adds sun light.

///|
/// The state upstream keeps in the constructor's closure.
pub(all) struct Water {
  clip_bias : Double
  eye : @math.Vector3
  mirror_plane : @math.Plane
  normal : @math.Vector3
  mirror_world_position : @math.Vector3
  camera_world_position : @math.Vector3
  rotation_matrix : @math.Matrix4
  look_at_position : @math.Vector3
  clip_plane : @math.Vector4
  view : @math.Vector3
  target : @math.Vector3
  q : @math.Vector4
  texture_matrix : @math.Matrix4
  mirror_camera : @core.Object3D
  render_target : @core.RenderTarget
}

///|
pub impl @core.Object3DExtension for Water with fn type_name(_) {
  "Mesh"
}

///|
pub impl @core.Object3DExtension for Water with fn construct(_) {
  Water::new()
}

///|
pub impl @core.Object3DExtension for Water with fn has_flag(_, flag) {
  flag == "isWater" || flag == "class:Water"
}

///|
#deprecated
pub extend Water with @core.Object3DExtension::{
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
/// `new Water( geometry, options )`. Colors are hex values; `water_normals` is the
/// normal map sampled for the waves (upstream's `null` by default).
pub fn Water::new(
  geometry? : @core.BufferGeometry,
  texture_width~ : Int32 = 512,
  texture_height~ : Int32 = 512,
  clip_bias~ : Double = 0.0,
  alpha~ : Double = 1.0,
  time~ : Double = 0.0,
  water_normals? : @core.Texture,
  sun_direction? : @math.Vector3,
  sun_color~ : Int32 = 0xffffff,
  water_color~ : Int32 = 0x7F7F7F,
  eye? : @math.Vector3,
  distortion_scale~ : Double = 20.0,
  side~ : Int32 = @core.FrontSide,
  fog~ : Bool = false,
) -> @core.Object3D {
  let object = @core.Mesh::new(geometry?)
  let sun_direction = match sun_direction {
    Some(v) => v
    None => @math.Vector3::new(0.70707, 0.70707, 0.0)
  }
  let sun_color = @math.Color::from_hex(sun_color)
  let water_color = @math.Color::from_hex(water_color)
  let eye = match eye {
    Some(v) => v
    None => @math.Vector3::new(0.0, 0.0, 0.0)
  }
  //
  let texture_matrix = @math.Matrix4::new()
  let mirror_camera = @core.PerspectiveCamera::new()
  let render_target = @webgl.WebGLRenderTarget::new(
    width=texture_width,
    height=texture_height,
    type_=@core.HalfFloatType,
  )
  let mirror_shader : ShaderDefinition = {
    name: Some("MirrorShader"),
    uniforms: @core.UniformsUtils::merge([
      @shaders.uniforms_lib["fog"],
      @shaders.uniforms_lib["lights"],
      Map([
        ("normalSampler", { value: Null, }),
        ("mirrorSampler", { value: Null, }),
        ("alpha", { value: Number(1.0), }),
        ("time", { value: Number(0.0), }),
        ("size", { value: Number(1.0), }),
        ("distortionScale", { value: Number(20.0), }),
        ("textureMatrix", { value: Matrix4(@math.Matrix4::new()), }),
        ("sunColor", { value: Color(@math.Color::from_hex(0x7F7F7F)), }),
        (
          "sunDirection",
          { value: Vector3(@math.Vector3::new(0.70707, 0.70707, 0.0)), },
        ),
        ("eye", { value: Vector3(@math.Vector3::new(0.0, 0.0, 0.0)), }),
        ("waterColor", { value: Color(@math.Color::from_hex(0x555555)), }),
      ]),
    ]),
    vertex_shader: _water_vertex_shader,
    fragment_shader: _water_fragment_shader,
  }
  let material = @core.ShaderMaterial::new()
  material.name = mirror_shader.name.unwrap()
  material.uniforms = Some(@core.UniformsUtils::clone(mirror_shader.uniforms))
  material.vertex_shader = Some(mirror_shader.vertex_shader)
  material.fragment_shader = Some(mirror_shader.fragment_shader)
  material.lights = Some(true)
  material.side = side
  material.fog = Some(fog)
  objects_uniform(material, "mirrorSampler").value = Texture(
    render_target.texture(),
  )
  objects_uniform(material, "textureMatrix").value = Matrix4(texture_matrix)
  objects_uniform(material, "alpha").value = Number(alpha)
  objects_uniform(material, "time").value = Number(time)
  objects_uniform(material, "normalSampler").value = match water_normals {
    Some(t) => Texture(t)
    None => Null
  }
  objects_uniform(material, "sunColor").value = Color(sun_color)
  objects_uniform(material, "waterColor").value = Color(water_color)
  objects_uniform(material, "sunDirection").value = Vector3(sun_direction)
  objects_uniform(material, "distortionScale").value = Number(distortion_scale)
  objects_uniform(material, "eye").value = Vector3(eye)
  match object.kind {
    Mesh(mesh) => mesh.material = Single(material)
    _ => ()
  }
  let water : Water = {
    clip_bias,
    eye,
    mirror_plane: @math.Plane::new(),
    normal: @math.Vector3::new(0.0, 0.0, 0.0),
    mirror_world_position: @math.Vector3::new(0.0, 0.0, 0.0),
    camera_world_position: @math.Vector3::new(0.0, 0.0, 0.0),
    rotation_matrix: @math.Matrix4::new(),
    look_at_position: @math.Vector3::new(0.0, 0.0, -1.0),
    clip_plane: @math.Vector4::new(0.0, 0.0, 0.0, 1.0),
    view: @math.Vector3::new(0.0, 0.0, 0.0),
    target: @math.Vector3::new(0.0, 0.0, 0.0),
    q: @math.Vector4::new(0.0, 0.0, 0.0, 1.0),
    texture_matrix,
    mirror_camera,
    render_target,
  }
  object.set_extension(water) |> ignore
  object.on_before_render = fn(renderer, scene, camera, _, _, _) {
    water.on_before_render(
      object,
      objects_webgl_renderer(renderer),
      scene,
      camera,
    )
  }
  object
}

///|
/// The payload of a `Water`, or `None` for other objects.
pub fn Water::of(object : @core.Object3D) -> Water? {
  objects_payload(object, "class:Water")
}

///|
/// `onBeforeRender( renderer, scene, camera )`.
fn Water::on_before_render(
  self : Water,
  scope : @core.Object3D,
  renderer : @webgl.WebGLRenderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  self.mirror_world_position.set_from_matrix_position(scope.matrix_world)
  |> ignore
  self.camera_world_position.set_from_matrix_position(camera.matrix_world)
  |> ignore
  self.rotation_matrix.extract_rotation(scope.matrix_world) |> ignore
  self.normal.set(0.0, 0.0, 1.0) |> ignore
  self.normal.apply_matrix4(self.rotation_matrix) |> ignore
  self.view.sub_vectors(self.mirror_world_position, self.camera_world_position)
  |> ignore
  // Avoid rendering when mirror is facing away
  if self.view.dot(self.normal) > 0.0 {
    return
  }
  self.view.reflect(self.normal).negate() |> ignore
  self.view.add(self.mirror_world_position) |> ignore
  self.rotation_matrix.extract_rotation(camera.matrix_world) |> ignore
  self.look_at_position.set(0.0, 0.0, -1.0) |> ignore
  self.look_at_position.apply_matrix4(self.rotation_matrix) |> ignore
  self.look_at_position.add(self.camera_world_position) |> ignore
  self.target.sub_vectors(self.mirror_world_position, self.look_at_position)
  |> ignore
  self.target.reflect(self.normal).negate() |> ignore
  self.target.add(self.mirror_world_position) |> ignore
  let mirror_camera = self.mirror_camera
  mirror_camera.position.copy(self.view) |> ignore
  mirror_camera.up.set(0.0, 1.0, 0.0) |> ignore
  mirror_camera.up.apply_matrix4(self.rotation_matrix) |> ignore
  mirror_camera.up.reflect(self.normal) |> ignore
  mirror_camera.look_at(self.target)
  objects_copy_camera_far(mirror_camera, camera) // Used in WebGLBackground
  mirror_camera.update_matrix_world()
  mirror_camera.projection_matrix().copy(camera.projection_matrix()) |> ignore
  // Update the texture matrix
  self.texture_matrix.set(
    0.5, 0.0, 0.0, 0.5, 0.0, 0.5, 0.0, 0.5, 0.0, 0.0, 0.5, 0.5, 0.0, 0.0, 0.0, 1.0,
  )
  |> ignore
  self.texture_matrix.multiply(mirror_camera.projection_matrix()) |> ignore
  self.texture_matrix.multiply(mirror_camera.matrix_world_inverse()) |> ignore
  // Now update projection matrix with new clip plane, implementing code from: http://www.terathon.com/code/oblique.html
  // Paper explaining this technique: http://www.terathon.com/lengyel/Lengyel-Oblique.pdf
  self.mirror_plane.set_from_normal_and_coplanar_point(
    self.normal,
    self.mirror_world_position,
  )
  |> ignore
  self.mirror_plane.apply_matrix4(mirror_camera.matrix_world_inverse())
  |> ignore
  self.clip_plane.set(
    self.mirror_plane.normal.x,
    self.mirror_plane.normal.y,
    self.mirror_plane.normal.z,
    self.mirror_plane.constant,
  )
  |> ignore
  let pe = mirror_camera.projection_matrix().elements
  self.q.x = (objects_math_sign(self.clip_plane.x) + pe[8]) / pe[0]
  self.q.y = (objects_math_sign(self.clip_plane.y) + pe[9]) / pe[5]
  self.q.z = -1.0
  self.q.w = (1.0 + pe[10]) / pe[14]
  // Calculate the scaled plane vector
  self.clip_plane.multiply_scalar(2.0 / self.clip_plane.dot(self.q)) |> ignore
  // Replacing the third row of the projection matrix
  pe[2] = self.clip_plane.x
  pe[6] = self.clip_plane.y
  pe[10] = self.clip_plane.z + 1.0 - self.clip_bias
  pe[14] = self.clip_plane.w
  self.eye.set_from_matrix_position(camera.matrix_world) |> ignore
  // Render
  let current_render_target = renderer.get_render_target()
  let current_xr_enabled = renderer.xr.enabled
  let current_shadow_auto_update = renderer.shadow_map.auto_update
  scope.visible = false
  renderer.xr.set_enabled(false) // Avoid camera modification and recursion
  renderer.shadow_map.auto_update = false // Avoid re-computing shadows
  renderer.set_render_target(Some(self.render_target))
  // make sure the depth buffer is writable so it can be properly cleared, see #18897
  renderer.state.buffers.depth.set_mask(true)
  if !renderer.auto_clear {
    renderer.clear()
  }
  renderer.render(scene, mirror_camera)
  scope.visible = true
  renderer.xr.set_enabled(current_xr_enabled)
  renderer.shadow_map.auto_update = current_shadow_auto_update
  renderer.set_render_target(current_render_target)
  // Restore viewport
  if @webgl.camera_viewport(camera) is Some(viewport) {
    renderer.state.viewport(viewport)
  }
}

///|
let _water_vertex_shader : String =
  #|
  #|				uniform mat4 textureMatrix;
  #|				uniform float time;
  #|
  #|				varying vec4 mirrorCoord;
  #|				varying vec4 worldPosition;
  #|
  #|				#include <common>
  #|				#include <fog_pars_vertex>
  #|				#include <shadowmap_pars_vertex>
  #|				#include <logdepthbuf_pars_vertex>
  #|
  #|				void main() {
  #|					mirrorCoord = modelMatrix * vec4( position, 1.0 );
  #|					worldPosition = mirrorCoord.xyzw;
  #|					mirrorCoord = textureMatrix * mirrorCoord;
  #|					vec4 mvPosition =  modelViewMatrix * vec4( position, 1.0 );
  #|					gl_Position = projectionMatrix * mvPosition;
  #|
  #|				#include <beginnormal_vertex>
  #|				#include <defaultnormal_vertex>
  #|				#include <logdepthbuf_vertex>
  #|				#include <fog_vertex>
  #|				#include <shadowmap_vertex>
  #|			}

///|
let _water_fragment_shader : String = (
    #|
    #|				uniform sampler2D mirrorSampler;
    #|				uniform float alpha;
    #|				uniform float time;
    #|				uniform float size;
    #|				uniform float distortionScale;
    #|				uniform sampler2D normalSampler;
    #|				uniform vec3 sunColor;
    #|				uniform vec3 sunDirection;
    #|				uniform vec3 eye;
    #|				uniform vec3 waterColor;
    #|
    #|				varying vec4 mirrorCoord;
    #|				varying vec4 worldPosition;
    #|
    #|				vec4 getNoise( vec2 uv ) {
    #|					vec2 uv0 = ( uv / 103.0 ) + vec2(time / 17.0, time / 29.0);
    #|					vec2 uv1 = uv / 107.0-vec2( time / -19.0, time / 31.0 );
    #|					vec2 uv2 = uv / vec2( 8907.0, 9803.0 ) + vec2( time / 101.0, time / 97.0 );
    #|					vec2 uv3 = uv / vec2( 1091.0, 1027.0 ) - vec2( time / 109.0, time / -113.0 );
    #|					vec4 noise = texture2D( normalSampler, uv0 ) +
    #|						texture2D( normalSampler, uv1 ) +
    #|						texture2D( normalSampler, uv2 ) +
    #|						texture2D( normalSampler, uv3 );
    #|					return noise * 0.5 - 1.0;
    #|				}
    #|
    #|				void sunLight( const vec3 surfaceNormal, const vec3 eyeDirection, float shiny, float spec, float diffuse, inout vec3 diffuseColor, inout vec3 specularColor ) {
    #|					vec3 reflection = normalize( reflect( -sunDirection, surfaceNormal ) );
    #|					float direction = max( 0.0, dot( eyeDirection, reflection ) );
    #|					specularColor += pow( direction, shiny ) * sunColor * spec;
    #|					diffuseColor += max( dot( sunDirection, surfaceNormal ), 0.0 ) * sunColor * diffuse;
    #|				}
    #|
    #|				#include <common>
    #|				#include <packing>
    #|				#include <bsdfs>
    #|				#include <fog_pars_fragment>
    #|				#include <logdepthbuf_pars_fragment>
    #|				#include <lights_pars_begin>
    #|				#include <shadowmap_pars_fragment>
    #|				#include <shadowmask_pars_fragment>
    #|
    #|				void main() {
    #|
    #|					#include <logdepthbuf_fragment>
    #|					vec4 noise = getNoise( worldPosition.xz * size );
    #|					vec3 surfaceNormal = normalize( noise.xzy * vec3( 1.5, 1.0, 1.5 ) );
    #|
    #|					vec3 diffuseLight = vec3(0.0);
    #|					vec3 specularLight = vec3(0.0);
    #|
    #|					vec3 worldToEye = eye-worldPosition.xyz;
    #|					vec3 eyeDirection = normalize( worldToEye );
    #|					sunLight( surfaceNormal, eyeDirection, 100.0, 2.0, 0.5, diffuseLight, specularLight );
    #|
    #|					float distance = length(worldToEye);
    #|
    #|					vec2 distortion = surfaceNormal.xz * ( 0.001 + 1.0 / distance ) * distortionScale;
    #|					vec3 reflectionSample = vec3( texture2D( mirrorSampler, mirrorCoord.xy / mirrorCoord.w + distortion ) );
    #|
    #|					float theta = max( dot( eyeDirection, surfaceNormal ), 0.0 );
    #|					float rf0 = 0.02;
    #|					float reflectance = rf0 + ( 1.0 - rf0 ) * pow( ( 1.0 - theta ), 5.0 );
    #|					vec3 scatter = max( 0.0, dot( surfaceNormal, eyeDirection ) ) * waterColor;
    #|					vec3 albedo = mix( ( sunColor * diffuseLight * 0.3 + scatter ) * getShadowMask(), reflectionSample + specularLight, reflectance );
    #|					vec3 outgoingLight = albedo;
    #|					gl_FragColor = vec4( outgoingLight, alpha );
    #|
    #|					#include <tonemapping_fragment>
    #|					#include <colorspace_fragment>
  ) +
  "\n" +
  "\t\t\t\t\t#include <fog_fragment>\t" +
  "\n" +
  (
    #|				}
  )
