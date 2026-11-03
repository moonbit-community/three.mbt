// Upstream src/extras/PMREMGenerator.js. GROUP 3. It lives here, not in `extras`, because
// it renders with `WebGLRenderer`.

///|
pub struct PMREMGenerator {
  _renderer : WebGLRenderer
  mut _cube_size : Int32
  mut _source_target : @core.RenderTarget?
  _cube_camera : @core.Object3D
  _box_mesh : @core.Object3D
  mut _cubemap_material : @core.Material?
  mut _equirect_material : @core.Material?
  mut _blur_material : @core.Material?
  mut _ggx_material : @core.Material?
  mut _integration_material : @core.Material?
}

///|
/// Smaller inputs are upsampled so that every PMREM has enough mip levels.
const PMREM_GENERATOR_MIN_SIZE : Int32 = 256

///|
/// Log2 of the face size of the roughest mip level. Smaller faces can't
/// represent the diffuse irradiance that is stored in this level.
const PMREM_GENERATOR_LOD_MIN : Int32 = 3

///|
/// GGX VNDF samples for the sharp mip levels.
const PMREM_GENERATOR_GGX_SAMPLES : Double = 256

///|
/// Integrate a small source mip for the rough levels to avoid sampling noise.
const PMREM_GENERATOR_INTEGRATION_SIZE : Int32 = 16

///|
const PMREM_GENERATOR_INTEGRATION_LEVELS : Int32 = 3

///|
let _pmrem_generator_origin : @math.Vector3 = @math.Vector3::new(0, 0, 0)

///|
let _pmrem_generator_clear_color : @math.Color = @math.Color::new(0, 0, 0)

///|
/// `Math.SQRT2`.
extern "js" fn pmrem_generator_sqrt2() -> Double = "() => Math.SQRT2"

///|
/// `Math.PI`.
extern "js" fn pmrem_generator_pi() -> Double = "() => Math.PI"

///|
/// `new PMREMGenerator( renderer )`.
pub fn PMREMGenerator::new(renderer : WebGLRenderer) -> PMREMGenerator {
  {
    _renderer: renderer,
    _cube_size: 0,
    _source_target: None,
    _cube_camera: @core.CubeCamera::new(near=1, far=10),
    // upstream passes `null` as the material; an empty slot keeps the material ids
    // untouched until `_renderCube` assigns one
    _box_mesh: @core.Mesh::new(
      geometry=@geometries.BoxGeometry::new(width=5, height=5, depth=5),
      material=Multiple([]),
    ),
    _cubemap_material: None,
    _equirect_material: None,
    _blur_material: None,
    _ggx_material: None,
    _integration_material: None,
  }
}

///|
/// `PMREMGenerator.lodToRoughness( lod, maxLod )`: the roughness a mip level of a PMREM
/// has been prefiltered for.
pub fn PMREMGenerator::lod_to_roughness(
  lod : Double,
  max_lod : Double,
) -> Double {
  if max_lod > 0.0 {
    1.0 - (1.0 - lod / max_lod).sqrt()
  } else {
    0.0
  }
}

///|
/// `pmremGenerator.fromScene( scene, sigma, near, far, { size, position } )`.
pub fn PMREMGenerator::from_scene(
  self : PMREMGenerator,
  scene : @core.Object3D,
  sigma~ : Double = 0,
  near~ : Double = 0.1,
  far~ : Double = 100,
  size~ : Int32 = 256,
  position? : @math.Vector3,
) -> @core.RenderTarget {
  let position = match position {
    Some(position) => position
    None => _pmrem_generator_origin
  }
  let renderer = self._renderer
  self._set_size(size.to_double())
  let pmrem_target = self._allocate_target()
  let source_target = self._get_source_target(depth_buffer=true)
  if sigma > 0.0 {
    source_target.texture().mipmaps_auto_update = false
  }

  // Clear every captured face, independent of the application's clear settings.
  let auto_clear = renderer.auto_clear
  let auto_clear_color = renderer.auto_clear_color
  let auto_clear_depth = renderer.auto_clear_depth
  let auto_clear_stencil = renderer.auto_clear_stencil
  let scene_data = match scene.kind {
    Scene(scene_data) => Some(scene_data)
    _ => None
  }
  let background = match scene_data {
    Some(scene_data) => scene_data.background
    None => None
  }
  renderer.auto_clear = true
  renderer.auto_clear_color = true
  renderer.auto_clear_depth = true
  renderer.auto_clear_stencil = true
  if scene_data is Some(scene_data) && background is None {
    scene_data.background = Some(
      Color(renderer.get_clear_color(_pmrem_generator_clear_color)),
    )
  }
  let cube_camera = @core.CubeCamera::new(
    near~,
    far~,
    render_target=source_target,
  )
  ignore(cube_camera.position.copy(position))
  cube_camera.update_cube_camera(renderer, scene)
  renderer.auto_clear = auto_clear
  renderer.auto_clear_color = auto_clear_color
  renderer.auto_clear_depth = auto_clear_depth
  renderer.auto_clear_stencil = auto_clear_stencil
  if scene_data is Some(scene_data) {
    scene_data.background = background
  }
  if sigma > 0.0 {
    source_target.texture().mipmaps_auto_update = true
    self._blur(pmrem_target, sigma)
  }
  self._apply_pmrem(pmrem_target)
  pmrem_target
}

///|
/// `pmremGenerator.fromEquirectangular( equirectangular, renderTarget )`.
pub fn PMREMGenerator::from_equirectangular(
  self : PMREMGenerator,
  equirectangular : @core.Texture,
  render_target? : @core.RenderTarget,
) -> @core.RenderTarget {
  self._from_texture(equirectangular, render_target)
}

///|
/// `pmremGenerator.fromCubemap( cubemap, renderTarget )`.
pub fn PMREMGenerator::from_cubemap(
  self : PMREMGenerator,
  cubemap : @core.Texture,
  render_target? : @core.RenderTarget,
) -> @core.RenderTarget {
  self._from_texture(cubemap, render_target)
}

///|
/// `pmremGenerator.compileCubemapShader()`.
pub fn PMREMGenerator::compile_cubemap_shader(self : PMREMGenerator) -> Unit {
  if self._cubemap_material is None {
    let material = pmrem_generator_get_cubemap_material()
    self._cubemap_material = Some(material)
    self._compile_material(material)
  }
}

///|
/// `pmremGenerator.compileEquirectangularShader()`.
pub fn PMREMGenerator::compile_equirectangular_shader(
  self : PMREMGenerator,
) -> Unit {
  if self._equirect_material is None {
    let material = pmrem_generator_get_equirect_material()
    self._equirect_material = Some(material)
    self._compile_material(material)
  }
}

///|
/// `pmremGenerator.dispose()`. The PMREMs it returned belong to the caller.
pub fn PMREMGenerator::dispose(self : PMREMGenerator) -> Unit {
  if self._source_target is Some(target) {
    target.dispose()
  }
  if self._cubemap_material is Some(material) {
    material.dispose()
  }
  if self._equirect_material is Some(material) {
    material.dispose()
  }
  if self._blur_material is Some(material) {
    material.dispose()
  }
  if self._ggx_material is Some(material) {
    material.dispose()
  }
  if self._integration_material is Some(material) {
    material.dispose()
  }
  match self._box_mesh.get_geometry() {
    Some(geometry) => geometry.dispose()
    None => ()
  }
}

///|
/// `_setSize( cubeSize )`.
fn PMREMGenerator::_set_size(self : PMREMGenerator, cube_size : Double) -> Unit {
  self._cube_size = js_math_max(
    PMREM_GENERATOR_MIN_SIZE.to_double(),
    @math.floor_power_of_two(cube_size),
  ).to_int()
}

///|
/// `( image.width || image.image.width )` of the first face of a cube texture.
fn pmrem_generator_face_width(image : @core.TextureImage) -> Double {
  match image {
    DomImage(image) => pmrem_generator_dom_face_width(image)
    DataImage(image) => image.width.to_double()
    TextureImage(texture) =>
      match texture.image() {
        DataImage(image) => image.width.to_double()
        DomImage(image) => image.get("width").cast()
        _ => abort("PMREMGenerator: cube face without a width")
      }
    NoImage | ImageArray(_) =>
      abort("PMREMGenerator: cube face without a width")
  }
}

///|
extern "js" fn pmrem_generator_dom_face_width(image : @core.JsValue) -> Double = "(i) => i.width || i.image.width"

///|
/// `image.width` of an equirectangular texture.
fn pmrem_generator_image_width(image : @core.TextureImage) -> Double {
  match image {
    DomImage(image) => image.get("width").cast()
    DataImage(image) => image.width.to_double()
    _ => abort("PMREMGenerator: texture without a width")
  }
}

///|
/// `_fromTexture( texture, renderTarget )`.
fn PMREMGenerator::_from_texture(
  self : PMREMGenerator,
  texture : @core.Texture,
  render_target : @core.RenderTarget?,
) -> @core.RenderTarget {
  if texture.mapping == @core.CubeReflectionMapping ||
    texture.mapping == @core.CubeRefractionMapping {
    let size = match texture.image() {
      ImageArray(images) =>
        if images.length() == 0 {
          PMREM_GENERATOR_MIN_SIZE.to_double()
        } else {
          pmrem_generator_face_width(images[0])
        }
      _ => abort("PMREMGenerator: cube texture without images")
    }
    self._set_size(size)
  } else { // Equirectangular
    self._set_size(pmrem_generator_image_width(texture.image()) / 4.0)
  }
  let pmrem_target = match render_target {
    Some(target) => target
    None => self._allocate_target()
  }
  self._texture_to_cubemap(texture)
  self._apply_pmrem(pmrem_target)
  pmrem_target
}

///|
/// `_allocateTarget()`.
fn PMREMGenerator::_allocate_target(
  self : PMREMGenerator,
) -> @core.RenderTarget {
  let size = self._cube_size
  let pmrem_target = pmrem_generator_create_render_target(size, false, false)

  // Allocate only the prefiltered mip levels without automatic mipmap generation.
  let max_lod = @cmath.log2(size.to_double()) -
    PMREM_GENERATOR_LOD_MIN.to_double()
  let texture = pmrem_target.texture()
  let mut lod = 0
  while lod.to_double() <= max_lod {
    texture.mipmaps.push(
      DataImage(@core.DataImage::new(width=size >> lod, height=size >> lod)),
    )
    lod += 1
  }
  texture.name = "PMREM"
  texture.is_pmrem_texture = true
  pmrem_target
}

///|
/// `_getSourceTarget( depthBuffer )`.
fn PMREMGenerator::_get_source_target(
  self : PMREMGenerator,
  depth_buffer~ : Bool = false,
) -> @core.RenderTarget {
  let size = self._cube_size
  let source_target = self._source_target
  match source_target {
    Some(target) if target.width == size &&
      !(depth_buffer && target.depth_buffer == false) => target
    _ => {
      if source_target is Some(target) {
        target.dispose()
      }
      let target = pmrem_generator_create_render_target(
        size, true, depth_buffer,
      )
      self._source_target = Some(target)
      target
    }
  }
}

///|
/// `boxMesh.material = material`.
fn PMREMGenerator::_set_box_material(
  self : PMREMGenerator,
  material : @core.Material,
) -> Unit {
  match self._box_mesh.kind {
    Mesh(mesh) => mesh.material = Single(material)
    _ => abort("PMREMGenerator: box mesh is not a mesh")
  }
}

///|
/// `_compileMaterial( material )`.
fn PMREMGenerator::_compile_material(
  self : PMREMGenerator,
  material : @core.Material,
) -> Unit {
  self._set_box_material(material)
  ignore(self._renderer.compile(self._box_mesh, self._cube_camera.children[0]))
}

///|
/// `_renderCube( target, lod, material )`: renders the box mesh with `material` into all
/// six faces of `target` at mip level `lod`.
fn PMREMGenerator::_render_cube(
  self : PMREMGenerator,
  target : @core.RenderTarget,
  lod : Int32,
  material : @core.Material,
) -> Unit {
  let box_mesh = self._box_mesh
  let cube_camera = self._cube_camera
  self._set_box_material(material)
  let cube = cube_camera.as_cube_camera()
  cube.render_target = Some(target)
  cube.active_mipmap_level = lod

  // WebGLRenderer uses the target viewport without scaling it to the active mip.
  let size = target.width >> lod
  ignore(target.viewport.set(0, 0, size.to_double(), size.to_double()))
  cube_camera.update_cube_camera(self._renderer, box_mesh)
  ignore(
    target.viewport.set(
      0,
      0,
      target.width.to_double(),
      target.height.to_double(),
    ),
  )
}

///|
/// `material.uniforms[ name ].value = value`.
fn pmrem_generator_set_uniform(
  material : @core.Material,
  name : String,
  value : @core.UniformValue,
) -> Unit {
  guard material.uniforms is Some(uniforms) &&
    uniforms.get(name) is Some(uniform) else {
    abort("PMREMGenerator: missing uniform " + name)
  }
  uniform.value = value
}

///|
/// `_textureToCubemap( texture )`.
fn PMREMGenerator::_texture_to_cubemap(
  self : PMREMGenerator,
  texture : @core.Texture,
) -> Unit {
  let material = if texture.mapping == @core.CubeReflectionMapping ||
    texture.mapping == @core.CubeRefractionMapping {
    let material = match self._cubemap_material {
      Some(material) => material
      None => {
        let material = pmrem_generator_get_cubemap_material()
        self._cubemap_material = Some(material)
        material
      }
    }
    pmrem_generator_set_uniform(
      material,
      "flipEnvMap",
      Number(if texture.is_render_target_texture == false { -1 } else { 1 }),
    )
    material
  } else {
    match self._equirect_material {
      Some(material) => material
      None => {
        let material = pmrem_generator_get_equirect_material()
        self._equirect_material = Some(material)
        material
      }
    }
  }
  pmrem_generator_set_uniform(material, "envMap", Texture(texture))
  self._render_cube(self._get_source_target(), 0, material)
}

///|
/// `_applyPMREM( pmremTarget )`: prefilters the source cubemap into the mip levels of
/// the PMREM.
fn PMREMGenerator::_apply_pmrem(
  self : PMREMGenerator,
  pmrem_target : @core.RenderTarget,
) -> Unit {
  if self._ggx_material is None {
    self._ggx_material = Some(pmrem_generator_get_ggx_material())
    self._integration_material = Some(
      pmrem_generator_get_integration_material(),
    )
  }
  let ggx_material = self._ggx_material.unwrap()
  let integration_material = self._integration_material.unwrap()
  let size = self._cube_size.to_double()
  let max_lod = pmrem_target.texture().mipmaps.length() - 1
  let source_texture = self._source_target.unwrap().texture()
  pmrem_generator_set_uniform(ggx_material, "envMap", Texture(source_texture))
  pmrem_generator_set_uniform(
    integration_material,
    "envMap",
    Texture(source_texture),
  )
  pmrem_generator_set_uniform(
    integration_material,
    "sourceLod",
    Number(@cmath.log2(size / PMREM_GENERATOR_INTEGRATION_SIZE.to_double())),
  )
  for lod in 0..<=max_lod {
    let roughness = PMREMGenerator::lod_to_roughness(
      lod.to_double(),
      max_lod.to_double(),
    )
    if lod > max_lod - PMREM_GENERATOR_INTEGRATION_LEVELS {
      pmrem_generator_set_uniform(
        integration_material,
        "roughness",
        Number(roughness),
      )
      self._render_cube(pmrem_target, lod, integration_material)
    } else {
      // For V = N, pdf( L ) = D( H ) / 4. Match the source texel solid angle to
      // 1 / ( GGX_SAMPLES * pdf ), with a half-mip bias to reduce sampling noise.
      // The shader supplies log2 of the GGX denominator.
      let lod_bias = if roughness > 0.0 {
        @cmath.log2(size) +
        0.5 *
        @cmath.log2(
          6.0 / (PMREM_GENERATOR_GGX_SAMPLES * @cmath.pow(roughness, 4.0)),
        ) +
        0.5
      } else {
        0.0
      }
      pmrem_generator_set_uniform(ggx_material, "roughness", Number(roughness))
      pmrem_generator_set_uniform(ggx_material, "lodBias", Number(lod_bias))
      self._render_cube(pmrem_target, lod, ggx_material)
    }
  }
}

///|
/// `_blur( pmremTarget, sigma )`: the initial `fromScene()` blur, in two passes.
fn PMREMGenerator::_blur(
  self : PMREMGenerator,
  pmrem_target : @core.RenderTarget,
  sigma : Double,
) -> Unit {
  let material = match self._blur_material {
    Some(material) => material
    None => {
      let material = pmrem_generator_get_blur_material()
      self._blur_material = Some(material)
      material
    }
  }
  let source_target = self._source_target.unwrap()

  // Split the blur variance between two passes. Clamp sigma to the sphere's
  // maximum angular distance.
  pmrem_generator_set_uniform(
    material,
    "sigma",
    Number(js_math_min(sigma, pmrem_generator_pi()) / pmrem_generator_sqrt2()),
  )
  pmrem_generator_set_uniform(
    material,
    "envMap",
    Texture(source_target.texture()),
  )
  self._render_cube(pmrem_target, 0, material)
  pmrem_generator_set_uniform(
    material,
    "envMap",
    Texture(pmrem_target.texture()),
  )
  self._render_cube(source_target, 0, material)
}

///|
/// `_createRenderTarget( size, generateMipmaps, depthBuffer )`.
fn pmrem_generator_create_render_target(
  size : Int32,
  generate_mipmaps : Bool,
  depth_buffer : Bool,
) -> @core.RenderTarget {
  WebGLCubeRenderTarget::new(
    size~,
    min_filter=@core.LinearMipmapLinearFilter,
    generate_mipmaps~,
    type_=@core.HalfFloatType,
    color_space=@core.LinearSRGBColorSpace,
    depth_buffer~,
  )
}

///|
/// `_getMaterial( name, uniforms, fragmentShader )`.
fn pmrem_generator_get_material(
  name : String,
  uniforms : Map[String, @core.Uniform],
  fragment_shader : String,
) -> @core.Material {
  let material = @core.ShaderMaterial::new()
  material.name = name
  material.uniforms = Some(uniforms)
  material.vertex_shader = @shaders.shader_chunk.get("cube_vert")
  material.fragment_shader = Some(fragment_shader)
  material.side = @core.BackSide
  material.blending = @core.NoBlending
  material.depth_test = false
  material.depth_write = false
  material
}

///|
fn pmrem_generator_get_ggx_material() -> @core.Material {
  pmrem_generator_get_material(
    "PMREMGGXConvolution",
    Map([
      ("envMap", { value: Null, }),
      ("roughness", { value: Number(0), }),
      ("lodBias", { value: Number(0), }),
    ]),
    pmrem_generator_ggx_fragment,
  )
}

///|
fn pmrem_generator_get_integration_material() -> @core.Material {
  pmrem_generator_get_material(
    "PMREMGGXIntegration",
    Map([
      ("envMap", { value: Null, }),
      ("roughness", { value: Number(0), }),
      ("sourceLod", { value: Number(0), }),
      // a uniform so the loops aren't unrolled
      (
        "sourceSize",
        { value: Number(PMREM_GENERATOR_INTEGRATION_SIZE.to_double()), },
      ),
    ]),
    pmrem_generator_integration_fragment,
  )
}

///|
fn pmrem_generator_get_blur_material() -> @core.Material {
  pmrem_generator_get_material(
    "PMREMSphericalGaussianBlur",
    Map([("envMap", { value: Null, }), ("sigma", { value: Number(0), })]),
    pmrem_generator_blur_fragment,
  )
}

///|
fn pmrem_generator_get_equirect_material() -> @core.Material {
  pmrem_generator_get_material(
    "PMREMEquirectangularToCubemap",
    Map([("envMap", { value: Null, })]),
    pmrem_generator_equirect_fragment,
  )
}

///|
fn pmrem_generator_get_cubemap_material() -> @core.Material {
  pmrem_generator_get_material(
    "PMREMCubemapToCubemap",
    Map([("envMap", { value: Null, }), ("flipEnvMap", { value: Number(-1), })]),
    pmrem_generator_cubemap_fragment,
  )
}

///|
let pmrem_generator_ggx_fragment : String = (
    #|
    #|
    #|		#define GGX_SAMPLES 256u
    #|
    #|		varying vec3 vWorldDirection;
    #|
    #|		uniform samplerCube envMap;
    #|		uniform float roughness;
    #|		uniform float lodBias;
    #|
    #|		#include <common>
    #|
    #|		// Van der Corput radical inverse
    #|		float radicalInverse_VdC( uint bits ) {
    #|
    #|			bits = ( bits << 16u ) | ( bits >> 16u );
    #|			bits = ( ( bits & 0x55555555u ) << 1u ) | ( ( bits & 0xAAAAAAAAu ) >> 1u );
    #|			bits = ( ( bits & 0x33333333u ) << 2u ) | ( ( bits & 0xCCCCCCCCu ) >> 2u );
    #|			bits = ( ( bits & 0x0F0F0F0Fu ) << 4u ) | ( ( bits & 0xF0F0F0F0u ) >> 4u );
    #|			bits = ( ( bits & 0x00FF00FFu ) << 8u ) | ( ( bits & 0xFF00FF00u ) >> 8u );
    #|			return float( bits ) * 2.3283064365386963e-10; // / 0x100000000
    #|
    #|		}
    #|
    #|		// Hammersley sequence
    #|		vec2 hammersley( uint i, uint N ) {
    #|
    #|			return vec2( float( i ) / float( N ), radicalInverse_VdC( i ) );
    #|
    #|		}
    #|
    #|		void main() {
    #|
    #|			vec3 N = normalize( vWorldDirection );
    #|
    #|			// For very low roughness, just sample the environment directly
    #|			if ( roughness < 0.001 ) {
    #|
    #|				gl_FragColor = vec4( textureLod( envMap, N, 0.0 ).rgb, 1.0 );
    #|				return;
    #|
    #|			}
    #|
    #|			float alpha = roughness * roughness;
    #|			float alpha2 = alpha * alpha;
    #|
    #|			// Tangent space basis for VNDF sampling
    #|			vec3 up = abs( N.z ) < 0.999 ? vec3( 0.0, 0.0, 1.0 ) : vec3( 1.0, 0.0, 0.0 );
    #|			vec3 tangent = normalize( cross( up, N ) );
    #|			vec3 bitangent = cross( N, tangent );
    #|
    #|			vec3 prefilteredColor = vec3( 0.0 );
    #|			float totalWeight = 0.0;
    #|
    #|			for ( uint i = 0u; i < GGX_SAMPLES; i ++ ) {
    #|
    #|				vec2 Xi = hammersley( i, GGX_SAMPLES );
    #|
    #|				// With V = N, sample the reflected direction directly.
    #|				float invQ = 1.0 / ( 1.0 - Xi.x + alpha2 * Xi.x );
    #|				float NdotL = ( 1.0 - Xi.x - alpha2 * Xi.x ) * invQ;
    #|
    #|				if ( NdotL > 0.0 ) {
    #|
    #|					float phi = 2.0 * PI * Xi.y;
    #|					float sinTheta = 2.0 * alpha * sqrt( Xi.x * ( 1.0 - Xi.x ) ) * invQ;
    #|					vec3 L = N * NdotL + ( tangent * cos( phi ) + bitangent * sin( phi ) ) * sinTheta;
    #|
    #|					// Match the source mip to the sample's solid angle. The terms
    #|					// independent of the sample are precomputed in lodBias.
    #|					float d = alpha2 * invQ;
    #|					float lod = max( log2( d ) + lodBias, 0.0 );
    #|
    #|					// Weight by NdotL for the split-sum approximation
    #|					prefilteredColor += textureLod( envMap, L, lod ).rgb * NdotL;
    #|					totalWeight += NdotL;
    #|
    #|				}
    #|
    #|			}
    #|
    #|			gl_FragColor = vec4( prefilteredColor / totalWeight, 1.0 );
    #|
    #|		}
    #|
  ) +
  // upstream's template literal ends with the indentation before its backtick
  "\t"

///|
let pmrem_generator_integration_fragment : String = (
    #|
    #|
    #|		varying vec3 vWorldDirection;
    #|
    #|		uniform samplerCube envMap;
    #|		uniform float roughness;
    #|		uniform float sourceLod;
    #|		uniform int sourceSize;
    #|
    #|		void main() {
    #|
    #|			vec3 N = normalize( vWorldDirection );
    #|
    #|			float alpha = roughness * roughness;
    #|			float alpha2 = alpha * alpha;
    #|
    #|			float texelSize = 2.0 / float( sourceSize );
    #|
    #|			vec3 prefilteredColor = vec3( 0.0 );
    #|			float totalWeight = 0.0;
    #|
    #|			// Pair opposite texels: only the one in N's hemisphere contributes.
    #|			for ( int face = 0; face < 3; face ++ ) {
    #|
    #|				for ( int y = 0; y < sourceSize; y ++ ) {
    #|
    #|					for ( int x = 0; x < sourceSize; x ++ ) {
    #|
    #|						vec2 uv = ( vec2( x, y ) + 0.5 ) * texelSize - 1.0;
    #|						vec3 texelDirection = face == 0 ? vec3( 1.0, uv ) : ( face == 1 ? vec3( uv.x, 1.0, uv.y ) : vec3( uv, 1.0 ) );
    #|
    #|						float invDistance = inversesqrt( 1.0 + dot( uv, uv ) );
    #|						float NdotL = dot( N, texelDirection );
    #|						texelDirection *= NdotL < 0.0 ? - 1.0 : 1.0;
    #|						NdotL = abs( NdotL ) * invDistance;
    #|
    #|						// With V = N, NdotH squared is ( 1 + NdotL ) / 2. Common factors
    #|						// in the GGX distribution and texel solid angle cancel when normalized.
    #|						float d = 1.0 + alpha2 + ( alpha2 - 1.0 ) * NdotL;
    #|						float weight = NdotL * invDistance * invDistance * invDistance / ( d * d );
    #|
    #|						prefilteredColor += textureLod( envMap, texelDirection, sourceLod ).rgb * weight;
    #|						totalWeight += weight;
    #|
    #|					}
    #|
    #|				}
    #|
    #|			}
    #|
    #|			gl_FragColor = vec4( prefilteredColor / totalWeight, 1.0 );
    #|
    #|		}
    #|
  ) +
  // upstream's template literal ends with the indentation before its backtick
  "\t"

///|
let pmrem_generator_blur_fragment : String = (
    #|
    #|
    #|		#define SAMPLES 20
    #|		#define GOLDEN_ANGLE 2.39996322973
    #|
    #|		varying vec3 vWorldDirection;
    #|
    #|		uniform samplerCube envMap;
    #|		uniform float sigma;
    #|
    #|		#include <common>
    #|
    #|		void main() {
    #|
    #|			vec3 outputDirection = normalize( vWorldDirection );
    #|
    #|			vec3 up = abs( outputDirection.z ) < 0.999 ? vec3( 0.0, 0.0, 1.0 ) : vec3( 1.0, 0.0, 0.0 );
    #|			vec3 tangent = normalize( cross( up, outputDirection ) );
    #|			vec3 bitangent = cross( outputDirection, tangent );
    #|
    #|			// Truncate the kernel at three standard deviations or at the antipode.
    #|			float thetaMax = min( 3.0 * sigma, PI );
    #|			float truncation = 1.0 - exp( - 0.5 * thetaMax * thetaMax / ( sigma * sigma ) );
    #|
    #|			vec3 accumColor = vec3( 0.0 );
    #|			float accumWeight = 0.0;
    #|
    #|			for ( int i = 0; i < SAMPLES; i ++ ) {
    #|
    #|				// Stratified inverse-CDF sampling of the Gaussian, placed on a golden-angle spiral.
    #|				float stratum = ( float( i ) + 0.5 ) / float( SAMPLES );
    #|				float theta = sigma * sqrt( - 2.0 * log( 1.0 - stratum * truncation ) );
    #|				float phi = float( i ) * GOLDEN_ANGLE;
    #|
    #|				vec3 offset = cos( phi ) * tangent + sin( phi ) * bitangent;
    #|				vec3 sampleDirection = cos( theta ) * outputDirection + sin( theta ) * offset;
    #|
    #|				// Correct the planar sample density to solid angle.
    #|				float weight = sin( theta ) / theta;
    #|
    #|				accumColor += weight * textureLod( envMap, sampleDirection, 0.0 ).rgb;
    #|				accumWeight += weight;
    #|
    #|			}
    #|
    #|			gl_FragColor = vec4( accumColor / accumWeight, 1.0 );
    #|
    #|		}
    #|
  ) +
  // upstream's template literal ends with the indentation before its backtick
  "\t"

///|
let pmrem_generator_equirect_fragment : String = (
    #|
    #|
    #|		varying vec3 vWorldDirection;
    #|
    #|		uniform sampler2D envMap;
    #|
    #|		#include <common>
    #|
    #|		void main() {
    #|
    #|			// Average four subpixel samples to preserve small, bright features.
    #|			vec3 direction = normalize( vWorldDirection );
    #|			vec3 dx = dFdx( direction ) * 0.25;
    #|			vec3 dy = dFdy( direction ) * 0.25;
    #|
    #|			vec3 color = textureLod( envMap, equirectUv( normalize( direction - dx - dy ) ), 0.0 ).rgb;
    #|			color += textureLod( envMap, equirectUv( normalize( direction + dx - dy ) ), 0.0 ).rgb;
    #|			color += textureLod( envMap, equirectUv( normalize( direction - dx + dy ) ), 0.0 ).rgb;
    #|			color += textureLod( envMap, equirectUv( normalize( direction + dx + dy ) ), 0.0 ).rgb;
    #|			gl_FragColor = vec4( color * 0.25, 1.0 );
    #|
    #|		}
    #|
  ) +
  // upstream's template literal ends with the indentation before its backtick
  "\t"

///|
let pmrem_generator_cubemap_fragment : String = (
    #|
    #|
    #|		varying vec3 vWorldDirection;
    #|
    #|		uniform samplerCube envMap;
    #|		uniform float flipEnvMap;
    #|
    #|		void main() {
    #|
    #|			gl_FragColor = vec4( textureCube( envMap, vec3( flipEnvMap * vWorldDirection.x, vWorldDirection.yz ) ).rgb, 1.0 );
    #|
    #|		}
    #|
  ) +
  // upstream's template literal ends with the indentation before its backtick
  "\t"
