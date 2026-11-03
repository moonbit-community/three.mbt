// renderers/common/extras/PMREMGenerator.js: prefiltered, mipmapped radiance
// environment maps (PMREMs) from scenes, cube maps and equirectangular textures,
// rendered into the mips of a cube render target with node materials.

///|
/// Smaller inputs are upsampled so that every PMREM has enough mip levels.
let _pmrem_min_size : Int32 = 256

///|
/// Log2 of the face size of the roughest mip level.
let _pmrem_lod_min : Int32 = 3

///|
/// Spiral samples per pass of the initial fromScene() blur.
let _pmrem_blur_samples : Int32 = 20

///|
/// GGX VNDF samples for the sharp mip levels.
let _pmrem_ggx_samples : Int32 = 256

///|
/// Integrate a small source mip for the rough levels to avoid sampling noise.
let _pmrem_integration_size : Int32 = 16

///|
let _pmrem_integration_levels : Int32 = 3

///|
let _pmrem_origin : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _pmrem_clear_color : @math.Color = @math.Color::new(1.0, 1.0, 1.0)

///|
extern "js" fn pmrem_math_log2(x : Double) -> Double = "Math.log2"

///|
extern "js" fn pmrem_math_pow(x : Double, y : Double) -> Double = "Math.pow"

///|
extern "js" fn pmrem_math_min(x : Double, y : Double) -> Double = "Math.min"

///|
extern "js" fn pmrem_math_max(x : Double, y : Double) -> Double = "Math.max"

///|
extern "js" fn pmrem_math_sqrt(x : Double) -> Double = "Math.sqrt"

///|
/// The uniforms dictionary of a PMREM material (`_uniformsMap.get( material )`).
pub(all) struct PMREMUniforms {
  env_map : Node
  sigma : Node?
  roughness : Node?
  lod_bias : Node?
  source_lod : Node?
  source_size : Node?
}

///|
/// Maps materials to their uniforms dictionary.
let _pmrem_uniforms_map : @webgl.WeakMap[@core.JsValue, PMREMUniforms] = @webgl.WeakMap::new()

///|
fn _pmrem_uniforms(material : @core.Material) -> PMREMUniforms {
  _pmrem_uniforms_map.get(@core.JsValue::of(material)).unwrap()
}

///|
/// Generates prefiltered, mipmapped radiance environment maps (PMREMs).
pub(all) struct PMREMGenerator {
  _renderer : Renderer
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
/// `new PMREMGenerator( renderer )`.
pub fn PMREMGenerator::new(renderer : Renderer) -> PMREMGenerator {
  {
    _renderer: renderer,
    _cube_size: 0,
    _source_target: None,
    _cube_camera: @core.CubeCamera::new(near=1.0, far=10.0),
    // upstream passes a `null` material; an empty material array allocates none
    _box_mesh: @core.Mesh::new(
      geometry=@geometries.BoxGeometry::new(width=5.0, height=5.0, depth=5.0),
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
/// `fromScene( scene, sigma = 0, near = 0.1, far = 100, options = {} )`: renders the
/// scene into a cube map, optionally blurred, and prefilters it.
pub fn PMREMGenerator::from_scene(
  self : PMREMGenerator,
  scene : @core.Object3D,
  sigma~ : Double = 0.0,
  near~ : Double = 0.1,
  far~ : Double = 100.0,
  size~ : Int32 = 256,
  position~ : @math.Vector3 = _pmrem_origin,
  render_target? : @core.RenderTarget,
) -> @core.RenderTarget {
  let renderer = self._renderer
  self._set_size(size.to_double())
  if renderer.has_initialized() == false {
    abort(
      "THREE.PMREMGenerator: .fromScene() called before the backend is initialized. Use \"await renderer.init();\" before using this method.",
    )
  }
  let pmrem_target = match render_target {
    Some(t) => t
    None => self._allocate_target()
  }
  let source_target = self._get_source_target(depth_buffer=true)
  if sigma > 0.0 {
    source_target.texture().mipmaps_auto_update = false
  }
  // Clear every captured face, independent of the application's clear settings.
  let auto_clear = renderer.auto_clear
  let auto_clear_color = renderer.auto_clear_color
  let auto_clear_depth = renderer.auto_clear_depth
  let auto_clear_stencil = renderer.auto_clear_stencil
  let scene_data = scene.as_scene()
  let background = scene_data.background
  renderer.auto_clear = true
  renderer.auto_clear_color = true
  renderer.auto_clear_depth = true
  renderer.auto_clear_stencil = true
  if background is None {
    scene_data.background = Some(
      Color(renderer.get_clear_color(_pmrem_clear_color)),
    )
  }
  let cube_camera = @core.CubeCamera::new(
    near~,
    far~,
    render_target=source_target,
  )
  cube_camera.position.copy(position) |> ignore
  cube_camera.update_cube_camera(renderer, scene)
  renderer.auto_clear = auto_clear
  renderer.auto_clear_color = auto_clear_color
  renderer.auto_clear_depth = auto_clear_depth
  renderer.auto_clear_stencil = auto_clear_stencil
  scene_data.background = background
  if sigma > 0.0 {
    source_target.texture().mipmaps_auto_update = true
    self._blur(pmrem_target, sigma)
  }
  self._apply_pmrem(pmrem_target)
  pmrem_target
}

///|
/// `async fromSceneAsync( ... )` (deprecated).
pub fn PMREMGenerator::from_scene_async(
  self : PMREMGenerator,
  scene : @core.Object3D,
  sigma~ : Double = 0.0,
  near~ : Double = 0.1,
  far~ : Double = 100.0,
  size~ : Int32 = 256,
  position~ : @math.Vector3 = _pmrem_origin,
  render_target? : @core.RenderTarget,
  on_done : (@core.RenderTarget) -> Unit,
) -> Unit {
  @core.warn_once(
    "PMREMGenerator: \".fromSceneAsync()\" is deprecated. Use \"await renderer.init()\" instead.",
  )
  self._renderer.init(on_done=fn(error) {
    match error {
      None =>
        on_done(
          self.from_scene(
            scene,
            sigma~,
            near~,
            far~,
            size~,
            position~,
            render_target?,
          ),
        )
      Some(e) => abort(e)
    }
  })
}

///|
/// `fromEquirectangular( equirectangular, renderTarget = null )`.
pub fn PMREMGenerator::from_equirectangular(
  self : PMREMGenerator,
  equirectangular : @core.Texture,
  render_target? : @core.RenderTarget,
) -> @core.RenderTarget {
  if self._renderer.has_initialized() == false {
    abort(
      "THREE.PMREMGenerator: .fromEquirectangular() called before the backend is initialized. Use \"await renderer.init();\" before using this method.",
    )
  }
  self._from_texture(equirectangular, render_target)
}

///|
/// `async fromEquirectangularAsync( equirectangular, renderTarget = null )` (deprecated).
pub fn PMREMGenerator::from_equirectangular_async(
  self : PMREMGenerator,
  equirectangular : @core.Texture,
  render_target? : @core.RenderTarget,
  on_done : (@core.RenderTarget) -> Unit,
) -> Unit {
  @core.warn_once(
    "PMREMGenerator: \".fromEquirectangularAsync()\" is deprecated. Use \"await renderer.init()\" instead.",
  )
  self._renderer.init(on_done=fn(error) {
    match error {
      None => on_done(self._from_texture(equirectangular, render_target))
      Some(e) => abort(e)
    }
  })
}

///|
/// `fromCubemap( cubemap, renderTarget = null )`.
pub fn PMREMGenerator::from_cubemap(
  self : PMREMGenerator,
  cubemap : @core.Texture,
  render_target? : @core.RenderTarget,
) -> @core.RenderTarget {
  if self._renderer.has_initialized() == false {
    abort(
      "THREE.PMREMGenerator: .fromCubemap() called before the backend is initialized. Use \"await renderer.init();\" before using this method.",
    )
  }
  self._from_texture(cubemap, render_target)
}

///|
/// `async fromCubemapAsync( cubemap, renderTarget = null )` (deprecated).
pub fn PMREMGenerator::from_cubemap_async(
  self : PMREMGenerator,
  cubemap : @core.Texture,
  render_target? : @core.RenderTarget,
  on_done : (@core.RenderTarget) -> Unit,
) -> Unit {
  @core.warn_once(
    "PMREMGenerator: \".fromCubemapAsync()\" is deprecated. Use \"await renderer.init()\" instead.",
  )
  self._renderer.init(on_done=fn(error) {
    match error {
      None => on_done(self._from_texture(cubemap, render_target))
      Some(e) => abort(e)
    }
  })
}

///|
/// `async compileCubemapShader()`.
pub fn PMREMGenerator::compile_cubemap_shader(
  self : PMREMGenerator,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  if self._cubemap_material is None {
    let material = _pmrem_get_cubemap_material()
    self._cubemap_material = Some(material)
    self._compile_material(material, on_done)
  } else {
    on_done()
  }
}

///|
/// `async compileEquirectangularShader()`.
pub fn PMREMGenerator::compile_equirectangular_shader(
  self : PMREMGenerator,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  if self._equirect_material is None {
    let material = _pmrem_get_equirect_material()
    self._equirect_material = Some(material)
    self._compile_material(material, on_done)
  } else {
    on_done()
  }
}

///|
/// `dispose()`.
pub fn PMREMGenerator::dispose(self : PMREMGenerator) -> Unit {
  match self._source_target {
    Some(t) => t.dispose()
    None => ()
  }
  for
    material in [
      self._cubemap_material,
      self._equirect_material,
      self._blur_material,
      self._ggx_material,
      self._integration_material,
    ] {
    match material {
      Some(m) => m.dispose()
      None => ()
    }
  }
  self._box_mesh.get_geometry().unwrap().dispose()
}

///|
/// `PMREMGenerator.lodToRoughness( lod, maxLod )`.
pub fn PMREMGenerator::lod_to_roughness(
  lod : Double,
  max_lod : Double,
) -> Double {
  if max_lod > 0.0 {
    1.0 - pmrem_math_sqrt(1.0 - lod / max_lod)
  } else {
    0.0
  }
}

///|
fn PMREMGenerator::_set_size(self : PMREMGenerator, cube_size : Double) -> Unit {
  self._cube_size = pmrem_math_max(
    _pmrem_min_size.to_double(),
    @math.floor_power_of_two(cube_size),
  ).to_int()
}

///|
/// The width of a cube map's first face (`image[ 0 ].width || image[ 0 ].image.width`).
fn _pmrem_cube_face_width(texture : @core.Texture) -> Double {
  match texture.image() {
    ImageArray(images) =>
      if images.length() == 0 {
        _pmrem_min_size.to_double()
      } else {
        let width = images[0].width()
        if width != 0.0 && !width.is_nan() {
          width
        } else {
          match images[0] {
            TextureImage(t) => t.image().width()
            _ => width
          }
        }
      }
    _ => _pmrem_min_size.to_double()
  }
}

///|
fn PMREMGenerator::_from_texture(
  self : PMREMGenerator,
  texture : @core.Texture,
  render_target : @core.RenderTarget?,
) -> @core.RenderTarget {
  if texture.mapping == @core.CubeReflectionMapping ||
    texture.mapping == @core.CubeRefractionMapping {
    self._set_size(_pmrem_cube_face_width(texture))
  } else { // Equirectangular
    self._set_size(texture.image().width() / 4.0)
  }
  let pmrem_target = match render_target {
    Some(t) => t
    None => self._allocate_target()
  }
  self._texture_to_cubemap(texture)
  self._apply_pmrem(pmrem_target)
  pmrem_target
}

///|
fn PMREMGenerator::_allocate_target(
  self : PMREMGenerator,
) -> @core.RenderTarget {
  let size = self._cube_size
  let pmrem_target = _pmrem_create_render_target(size, false, false)
  // Allocate only the prefiltered mip levels without automatic mipmap generation.
  let max_lod = pmrem_math_log2(size.to_double()) - _pmrem_lod_min.to_double()
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
fn PMREMGenerator::_get_source_target(
  self : PMREMGenerator,
  depth_buffer~ : Bool = false,
) -> @core.RenderTarget {
  let size = self._cube_size
  let needs_new = match self._source_target {
    None => true
    Some(t) => t.width != size || (depth_buffer && t.depth_buffer == false)
  }
  if needs_new {
    match self._source_target {
      Some(t) => t.dispose()
      None => ()
    }
    self._source_target = Some(
      _pmrem_create_render_target(size, true, depth_buffer),
    )
  }
  self._source_target.unwrap()
}

///|
fn PMREMGenerator::_compile_material(
  self : PMREMGenerator,
  material : @core.Material,
  on_done : () -> Unit,
) -> Unit {
  _pmrem_set_box_material(self._box_mesh, material)
  self._renderer.compile(
    self._box_mesh,
    self._cube_camera.children[0],
    on_done~,
  )
}

///|
fn _pmrem_set_box_material(
  box_mesh : @core.Object3D,
  material : @core.Material,
) -> Unit {
  match box_mesh.kind {
    Mesh(m) => m.material = Single(material)
    _ => ()
  }
}

///|
fn PMREMGenerator::_render_cube(
  self : PMREMGenerator,
  target : @core.RenderTarget,
  lod : Int32,
  material : @core.Material,
) -> Unit {
  let box_mesh = self._box_mesh
  let cube_camera = self._cube_camera
  _pmrem_set_box_material(box_mesh, material)
  match cube_camera.kind {
    CubeCamera(c) => {
      c.render_target = Some(target)
      c.active_mipmap_level = lod
    }
    _ => ()
  }
  cube_camera.update_cube_camera(self._renderer, box_mesh)
}

///|
fn PMREMGenerator::_texture_to_cubemap(
  self : PMREMGenerator,
  texture : @core.Texture,
) -> Unit {
  let material = if texture.mapping == @core.CubeReflectionMapping ||
    texture.mapping == @core.CubeRefractionMapping {
    match self._cubemap_material {
      Some(m) => m
      None => {
        let m = _pmrem_get_cubemap_material()
        self._cubemap_material = Some(m)
        m
      }
    }
  } else {
    match self._equirect_material {
      Some(m) => m
      None => {
        let m = _pmrem_get_equirect_material()
        self._equirect_material = Some(m)
        m
      }
    }
  }
  TextureNode::set_value(_pmrem_uniforms(material).env_map, Some(texture))
  self._render_cube(self._get_source_target(), 0, material)
}

///|
fn PMREMGenerator::_apply_pmrem(
  self : PMREMGenerator,
  pmrem_target : @core.RenderTarget,
) -> Unit {
  if self._ggx_material is None {
    self._ggx_material = Some(_pmrem_get_ggx_material())
    self._integration_material = Some(_pmrem_get_integration_material())
  }
  let ggx_material = self._ggx_material.unwrap()
  let integration_material = self._integration_material.unwrap()
  let size = self._cube_size.to_double()
  let max_lod = pmrem_target.texture().mipmaps.length() - 1
  let source_texture = self._source_target.unwrap().texture()
  let ggx_uniforms = _pmrem_uniforms(ggx_material)
  TextureNode::set_value(ggx_uniforms.env_map, Some(source_texture))
  let integration_uniforms = _pmrem_uniforms(integration_material)
  TextureNode::set_value(integration_uniforms.env_map, Some(source_texture))
  InputNode::set_value(
    integration_uniforms.source_lod.unwrap(),
    Number(pmrem_math_log2(size / _pmrem_integration_size.to_double())),
  )
  for lod in 0..<=max_lod {
    let roughness = PMREMGenerator::lod_to_roughness(
      lod.to_double(),
      max_lod.to_double(),
    )
    if lod > max_lod - _pmrem_integration_levels {
      InputNode::set_value(
        integration_uniforms.roughness.unwrap(),
        Number(roughness),
      )
      self._render_cube(pmrem_target, lod, integration_material)
    } else {
      // For V = N, pdf( L ) = D( H ) / 4. Match the source texel solid angle to
      // 1 / ( GGX_SAMPLES * pdf ), with a half-mip bias to reduce sampling noise.
      // The shader supplies log2 of the GGX denominator.
      let lod_bias = if roughness > 0.0 {
        pmrem_math_log2(size) +
        0.5 *
        pmrem_math_log2(
          6.0 /
          (_pmrem_ggx_samples.to_double() * pmrem_math_pow(roughness, 4.0)),
        ) +
        0.5
      } else {
        0.0
      }
      InputNode::set_value(ggx_uniforms.roughness.unwrap(), Number(roughness))
      InputNode::set_value(ggx_uniforms.lod_bias.unwrap(), Number(lod_bias))
      self._render_cube(pmrem_target, lod, ggx_material)
    }
  }
}

///|
fn PMREMGenerator::_blur(
  self : PMREMGenerator,
  pmrem_target : @core.RenderTarget,
  sigma : Double,
) -> Unit {
  let material = match self._blur_material {
    Some(m) => m
    None => {
      let m = _pmrem_get_blur_material()
      self._blur_material = Some(m)
      m
    }
  }
  let uniforms = _pmrem_uniforms(material)
  let source_target = self._source_target.unwrap()
  // Split the blur variance between two passes. Clamp sigma to the sphere's
  // maximum angular distance.
  InputNode::set_value(
    uniforms.sigma.unwrap(),
    Number(pmrem_math_min(sigma, 3.141592653589793) / 1.4142135623730951),
  )
  TextureNode::set_value(uniforms.env_map, Some(source_target.texture()))
  self._render_cube(pmrem_target, 0, material)
  TextureNode::set_value(uniforms.env_map, Some(pmrem_target.texture()))
  self._render_cube(source_target, 0, material)
}

///|
fn _pmrem_create_render_target(
  size : Int32,
  generate_mipmaps : Bool,
  depth_buffer : Bool,
) -> @core.RenderTarget {
  CubeRenderTarget::new(
    size~,
    options=RenderTargetOptions::new(
      min_filter=@core.LinearMipmapLinearFilter,
      generate_mipmaps~,
      type_=@core.HalfFloatType,
      color_space=@core.LinearSRGBColorSpace,
      depth_buffer~,
    ),
  )
}

///|
fn _pmrem_get_material(
  type_ : String,
  uniforms : PMREMUniforms,
  fragment_node : Node,
) -> @core.Material {
  let material = NodeMaterial::new()
  material.name = "PMREM_\{type_}"
  NodeMaterial::of(material).unwrap().fragment_node = Some(fragment_node)
  material.side = @core.BackSide
  material.blending = @core.NoBlending
  material.depth_test = false
  material.depth_write = false
  _pmrem_uniforms_map.set(@core.JsValue::of(material), uniforms)
  material
}

///|
fn _pmrem_get_blur_material() -> @core.Material {
  let env_map = cube_texture_empty()
  let sigma = uniform(0)
  let uniforms = {
    env_map,
    sigma: Some(sigma),
    roughness: None,
    lod_bias: None,
    source_lod: None,
    source_size: None,
  }
  _pmrem_get_material(
    "blur",
    uniforms,
    spherical_gaussian_blur.call_named({
      "envMap": env_map,
      "sigma": sigma,
      "direction": position_world_direction,
      "SAMPLES": int(_pmrem_blur_samples),
    }),
  )
}

///|
fn _pmrem_get_ggx_material() -> @core.Material {
  let env_map = cube_texture_empty()
  let roughness = uniform(0)
  let lod_bias = uniform(0)
  let uniforms = {
    env_map,
    sigma: None,
    roughness: Some(roughness),
    lod_bias: Some(lod_bias),
    source_lod: None,
    source_size: None,
  }
  _pmrem_get_material(
    "ggx",
    uniforms,
    ggx_convolution.call_named({
      "envMap": env_map,
      "roughness": roughness,
      "lodBias": lod_bias,
      "direction": position_world_direction,
      "GGX_SAMPLES": uint(_pmrem_ggx_samples),
    }),
  )
}

///|
fn _pmrem_get_integration_material() -> @core.Material {
  let env_map = cube_texture_empty()
  let roughness = uniform(0)
  let source_lod = uniform(0)
  let source_size = uniform(_pmrem_integration_size, type_="int") // a uniform so the loops aren't unrolled
  let uniforms = {
    env_map,
    sigma: None,
    roughness: Some(roughness),
    lod_bias: None,
    source_lod: Some(source_lod),
    source_size: Some(source_size),
  }
  _pmrem_get_material(
    "integration",
    uniforms,
    ggx_integration.call_named({
      "envMap": env_map,
      "roughness": roughness,
      "sourceLod": source_lod,
      "sourceSize": source_size,
      "direction": position_world_direction,
    }),
  )
}

///|
fn _pmrem_get_cubemap_material() -> @core.Material {
  let env_map = cube_texture_empty()
  let uniforms = {
    env_map,
    sigma: None,
    roughness: None,
    lod_bias: None,
    source_lod: None,
    source_size: None,
  }
  _pmrem_get_material(
    "cubemap",
    uniforms,
    env_map.sample(position_world_direction),
  )
}

///|
fn _pmrem_get_equirect_material() -> @core.Material {
  let env_map = texture_empty()
  let uniforms = {
    env_map,
    sigma: None,
    roughness: None,
    lod_bias: None,
    source_lod: None,
    source_size: None,
  }
  let fragment_node = fn_(fn(_, _) {
    // Average four subpixel samples to preserve small, bright features.
    let direction = position_world_direction
    let dx = direction.d_fdx().mul(0.25).to_const()
    let dy = direction.d_fdy().mul(0.25).to_const()
    let color = env_map
      .sample(equirect_uv.call([direction.sub(dx).sub(dy).normalize()]))
      .level(0)
      .rgb()
      .add(
        env_map
        .sample(equirect_uv.call([direction.add(dx).sub(dy).normalize()]))
        .level(0)
        .rgb(),
      )
      .add(
        env_map
        .sample(equirect_uv.call([direction.sub(dx).add(dy).normalize()]))
        .level(0)
        .rgb(),
      )
      .add(
        env_map
        .sample(equirect_uv.call([direction.add(dx).add(dy).normalize()]))
        .level(0)
        .rgb(),
      )
    Some(vec4_of([color.mul(0.25), 1.0]))
  }).call([])
  _pmrem_get_material("equirect", uniforms, fragment_node)
}
