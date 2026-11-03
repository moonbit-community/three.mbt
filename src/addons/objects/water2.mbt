// Upstream examples/jsm/objects/Water2.js (its class is also called `Water`; here
// `Water2`): flowing water for WebGLRenderer, built from a `Reflector` and a `Refractor`
// that render in its `onBeforeRender`, mixed by a flow-mapped Fresnel shader.

///|
/// The state upstream keeps in the constructor's closure.
pub(all) struct Water2 {
  flow_speed : Double
  cycle : Double
  half_cycle : Double
  texture_matrix : @math.Matrix4
  timer : @core.Timer
  reflector : @core.Object3D
  refractor : @core.Object3D
}

///|
pub impl @core.Object3DExtension for Water2 with fn type_name(_) {
  "Water"
}

///|
pub impl @core.Object3DExtension for Water2 with fn construct(_) {
  Water2::new()
}

///|
pub impl @core.Object3DExtension for Water2 with fn has_flag(_, flag) {
  flag == "isWater" || flag == "class:Water2"
}

///|
#deprecated
pub extend Water2 with @core.Object3DExtension::{
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
/// `Water.WaterShader` of Water2.js.
pub let water2_shader : ShaderDefinition = {
  name: Some("WaterShader"),
  uniforms: Map([
    ("color", { value: Null, }),
    ("reflectivity", { value: Number(0.0), }),
    ("tReflectionMap", { value: Null, }),
    ("tRefractionMap", { value: Null, }),
    ("tNormalMap0", { value: Null, }),
    ("tNormalMap1", { value: Null, }),
    ("textureMatrix", { value: Null, }),
    ("config", { value: Vector4(@math.Vector4::new(0.0, 0.0, 0.0, 1.0)), }),
  ]),
  vertex_shader: _water2_vertex_shader,
  fragment_shader: _water2_fragment_shader,
}

///|
/// `new Water( geometry, options )` of Water2.js. `color` is a hex (default `0xFFFFFF`);
/// without `normal_map0` / `normal_map1` the textures upstream names are loaded with a
/// `TextureLoader`.
pub fn Water2::new(
  geometry? : @core.BufferGeometry,
  color~ : Int32 = 0xFFFFFF,
  texture_width~ : Int32 = 512,
  texture_height~ : Int32 = 512,
  clip_bias~ : Double = 0.0,
  flow_direction? : @math.Vector2,
  flow_speed~ : Double = 0.03,
  reflectivity~ : Double = 0.02,
  scale~ : Double = 1.0,
  shader? : ShaderDefinition,
  flow_map? : @core.Texture,
  normal_map0? : @core.Texture,
  normal_map1? : @core.Texture,
) -> @core.Object3D {
  let object = @core.Mesh::new(geometry?)
  let geometry = match object.kind {
    Mesh(mesh) => mesh.geometry
    _ => abort("unreachable")
  }
  let color = @math.Color::from_hex(color)
  let flow_direction = match flow_direction {
    Some(v) => v
    None => @math.Vector2::new(1.0, 0.0)
  }
  let shader = match shader {
    Some(shader) => shader
    None => water2_shader
  }
  let texture_loader = @loaders.TextureLoader::new()
  let normal_map0 = match normal_map0 {
    Some(t) => t
    None => texture_loader.load("textures/water/Water_1_M_Normal.jpg")
  }
  let normal_map1 = match normal_map1 {
    Some(t) => t
    None => texture_loader.load("textures/water/Water_2_M_Normal.jpg")
  }
  let cycle = 0.15 // a cycle of a flow map phase
  let half_cycle = cycle * 0.5
  let texture_matrix = @math.Matrix4::new()
  let timer = @core.Timer::new()
  // internal components
  let reflector = Reflector::new(
    geometry~,
    texture_width~,
    texture_height~,
    clip_bias~,
  )
  let refractor = Refractor::new(
    geometry~,
    texture_width~,
    texture_height~,
    clip_bias~,
  )
  reflector.matrix_auto_update = false
  refractor.matrix_auto_update = false
  // material
  let material = @core.ShaderMaterial::new()
  material.name = match shader.name {
    Some(name) => name
    None => ""
  }
  material.uniforms = Some(
    @core.UniformsUtils::merge([@shaders.uniforms_lib["fog"], shader.uniforms]),
  )
  material.vertex_shader = Some(shader.vertex_shader)
  material.fragment_shader = Some(shader.fragment_shader)
  material.transparent = true
  material.fog = Some(true)
  match object.kind {
    Mesh(mesh) => mesh.material = Single(material)
    _ => ()
  }
  match flow_map {
    Some(flow_map) => {
      material.defines.unwrap()["USE_FLOWMAP"] = Json::string("")
      material.uniforms.unwrap()["tFlowMap"] = { value: Texture(flow_map), }
    }
    None =>
      material.uniforms.unwrap()["flowDirection"] = {
        value: Vector2(flow_direction),
      }
  }
  // maps
  normal_map0.wrap_t = @core.RepeatWrapping
  normal_map0.wrap_s = @core.RepeatWrapping
  normal_map1.wrap_t = @core.RepeatWrapping
  normal_map1.wrap_s = @core.RepeatWrapping
  objects_uniform(material, "tReflectionMap").value = Texture(
    Reflector::get_render_target(reflector).texture(),
  )
  objects_uniform(material, "tRefractionMap").value = Texture(
    Refractor::get_render_target(refractor).texture(),
  )
  objects_uniform(material, "tNormalMap0").value = Texture(normal_map0)
  objects_uniform(material, "tNormalMap1").value = Texture(normal_map1)
  // water
  objects_uniform(material, "color").value = Color(color)
  objects_uniform(material, "reflectivity").value = Number(reflectivity)
  objects_uniform(material, "textureMatrix").value = Matrix4(texture_matrix)
  // initial values
  let config = objects_uniform_vector4(objects_uniform(material, "config"))
  config.x = 0.0 // flowMapOffset0
  config.y = half_cycle // flowMapOffset1
  config.z = half_cycle // halfCycle
  config.w = scale // scale
  let water : Water2 = {
    flow_speed,
    cycle,
    half_cycle,
    texture_matrix,
    timer,
    reflector,
    refractor,
  }
  object.set_extension(water) |> ignore
  object.on_before_render = fn(renderer, scene, camera, _, _, _) {
    water.timer.update() |> ignore
    water.update_texture_matrix(object, camera)
    water.update_flow(object)
    object.visible = false
    water.reflector.matrix_world.copy(object.matrix_world) |> ignore
    water.refractor.matrix_world.copy(object.matrix_world) |> ignore
    (water.reflector.on_before_render)(
      renderer,
      scene,
      camera,
      geometry,
      material,
      None,
    )
    (water.refractor.on_before_render)(
      renderer,
      scene,
      camera,
      geometry,
      material,
      None,
    )
    object.visible = true
  }
  object
}

///|
/// The payload of a Water2.js `Water`, or `None` for other objects.
pub fn Water2::of(object : @core.Object3D) -> Water2? {
  objects_payload(object, "class:Water2")
}

///|
/// `updateTextureMatrix( camera )`.
fn Water2::update_texture_matrix(
  self : Water2,
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
/// `updateFlow()`: advances the two flow map offsets, half a cycle apart.
fn Water2::update_flow(self : Water2, scope : @core.Object3D) -> Unit {
  let delta = self.timer.get_delta()
  let config = objects_uniform_vector4(
    objects_uniform(Reflector::material_of(scope), "config"),
  )
  config.x += self.flow_speed * delta // flowMapOffset0
  config.y = config.x + self.half_cycle // flowMapOffset1
  // Important: The distance between offsets should be always the value of "halfCycle".
  // Moreover, both offsets should be in the range of [ 0, cycle ].
  // This approach ensures a smooth water flow and avoids "reset" effects.
  if config.x >= self.cycle {
    config.x = 0.0
    config.y = self.half_cycle
  } else if config.y >= self.cycle {
    config.y = config.y - self.cycle
  }
}

///|
let _water2_vertex_shader : String =
  #|
  #|
  #|		#include <common>
  #|		#include <fog_pars_vertex>
  #|		#include <logdepthbuf_pars_vertex>
  #|
  #|		uniform mat4 textureMatrix;
  #|
  #|		varying vec4 vCoord;
  #|		varying vec2 vUv;
  #|		varying vec3 vToEye;
  #|
  #|		void main() {
  #|
  #|			vUv = uv;
  #|			vCoord = textureMatrix * vec4( position, 1.0 );
  #|
  #|			vec4 worldPosition = modelMatrix * vec4( position, 1.0 );
  #|			vToEye = cameraPosition - worldPosition.xyz;
  #|
  #|			vec4 mvPosition =  viewMatrix * worldPosition; // used in fog_vertex
  #|			gl_Position = projectionMatrix * mvPosition;
  #|
  #|			#include <logdepthbuf_vertex>
  #|			#include <fog_vertex>
  #|
  #|		}

///|
let _water2_fragment_shader : String =
  #|
  #|
  #|		#include <common>
  #|		#include <fog_pars_fragment>
  #|		#include <logdepthbuf_pars_fragment>
  #|
  #|		uniform sampler2D tReflectionMap;
  #|		uniform sampler2D tRefractionMap;
  #|		uniform sampler2D tNormalMap0;
  #|		uniform sampler2D tNormalMap1;
  #|
  #|		#ifdef USE_FLOWMAP
  #|			uniform sampler2D tFlowMap;
  #|		#else
  #|			uniform vec2 flowDirection;
  #|		#endif
  #|
  #|		uniform vec3 color;
  #|		uniform float reflectivity;
  #|		uniform vec4 config;
  #|
  #|		varying vec4 vCoord;
  #|		varying vec2 vUv;
  #|		varying vec3 vToEye;
  #|
  #|		void main() {
  #|
  #|			#include <logdepthbuf_fragment>
  #|
  #|			float flowMapOffset0 = config.x;
  #|			float flowMapOffset1 = config.y;
  #|			float halfCycle = config.z;
  #|			float scale = config.w;
  #|
  #|			vec3 toEye = normalize( vToEye );
  #|
  #|			// determine flow direction
  #|			vec2 flow;
  #|			#ifdef USE_FLOWMAP
  #|				flow = texture2D( tFlowMap, vUv ).rg * 2.0 - 1.0;
  #|			#else
  #|				flow = flowDirection;
  #|			#endif
  #|			flow.x *= - 1.0;
  #|
  #|			// sample normal maps (distort uvs with flowdata)
  #|			vec4 normalColor0 = texture2D( tNormalMap0, ( vUv * scale ) + flow * flowMapOffset0 );
  #|			vec4 normalColor1 = texture2D( tNormalMap1, ( vUv * scale ) + flow * flowMapOffset1 );
  #|
  #|			// linear interpolate to get the final normal color
  #|			float flowLerp = abs( halfCycle - flowMapOffset0 ) / halfCycle;
  #|			vec4 normalColor = mix( normalColor0, normalColor1, flowLerp );
  #|
  #|			// calculate normal vector
  #|			vec3 normal = normalize( vec3( normalColor.r * 2.0 - 1.0, normalColor.b,  normalColor.g * 2.0 - 1.0 ) );
  #|
  #|			// calculate the fresnel term to blend reflection and refraction maps
  #|			float theta = max( dot( toEye, normal ), 0.0 );
  #|			float reflectance = reflectivity + ( 1.0 - reflectivity ) * pow( ( 1.0 - theta ), 5.0 );
  #|
  #|			// calculate final uv coords
  #|			vec3 coord = vCoord.xyz / vCoord.w;
  #|			vec2 uv = coord.xy + coord.z * normal.xz * 0.05;
  #|
  #|			vec4 reflectColor = texture2D( tReflectionMap, vec2( 1.0 - uv.x, uv.y ) );
  #|			vec4 refractColor = texture2D( tRefractionMap, uv );
  #|
  #|			// multiply water color with the mix of both textures
  #|			gl_FragColor = vec4( color, 1.0 ) * mix( refractColor, reflectColor, reflectance );
  #|
  #|			#include <tonemapping_fragment>
  #|			#include <colorspace_fragment>
  #|			#include <fog_fragment>
  #|
  #|		}
