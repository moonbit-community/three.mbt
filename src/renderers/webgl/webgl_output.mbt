// Upstream src/renderers/webgl/WebGLOutput.js. GROUP 3.

///|
/// A post-processing pass given to `renderer.setEffects`. Upstream duck-types `Pass`
/// objects (examples/jsm/postprocessing); the defaults are what an absent property means.
pub(open) trait WebGLOutputEffect {
  /// `effect.render( renderer, writeBuffer, readBuffer, deltaTime )`.
  fn render(
    Self,
    WebGLRenderer,
    @core.RenderTarget?,
    @core.RenderTarget,
    Double?,
  ) -> Unit
  /// `effect.enabled`
  fn enabled(Self) -> Bool = _
  /// `effect.needsSwap`
  fn needs_swap(Self) -> Bool = _
  /// `effect.isRenderPass`
  fn is_render_pass(Self) -> Bool = _
  /// `effect.isOutputPass`
  fn is_output_pass(Self) -> Bool = _
  /// `effect.needsDepthTexture`
  fn needs_depth_texture(Self) -> Bool = _
  /// `effect.setSize( width, height )`
  fn set_size(Self, Int32, Int32) -> Unit = _
  /// `effect.setDepthTexture( depthTexture )`
  fn set_depth_texture(Self, @core.Texture) -> Unit = _
}

///|
impl WebGLOutputEffect with fn enabled(_) {
  true
}

///|
impl WebGLOutputEffect with fn needs_swap(_) {
  true
}

///|
impl WebGLOutputEffect with fn is_render_pass(_) {
  false
}

///|
impl WebGLOutputEffect with fn is_output_pass(_) {
  false
}

///|
impl WebGLOutputEffect with fn needs_depth_texture(_) {
  false
}

///|
impl WebGLOutputEffect with fn set_size(_, _, _) {

}

///|
impl WebGLOutputEffect with fn set_depth_texture(_, _) {

}

///|
pub struct WebGLOutput {
  type_ : Int32
  antialias : Bool
  depth : Bool
  stencil : Bool
  target_scene : @core.RenderTarget
  mut target_a : @core.RenderTarget?
  mut target_b : @core.RenderTarget?
  mut depth_texture : @core.Texture?
  geometry : @core.BufferGeometry
  material : @core.Material
  mesh : @core.Object3D
  camera : @core.Object3D
  mut _output_color_space : String?
  mut _output_tone_mapping : Int32?
  mut _is_compositing : Bool
  mut _saved_tone_mapping : Int32
  mut _saved_render_target : @core.RenderTarget?
  mut _effects : Array[&WebGLOutputEffect]
  mut _has_render_pass : Bool
}

///|
/// `toneMappingMap[ toneMapping ]`.
fn webgl_output_tone_mapping_define(tone_mapping : Int32) -> String? {
  match tone_mapping {
    @core.LinearToneMapping => Some("LINEAR_TONE_MAPPING")
    @core.ReinhardToneMapping => Some("REINHARD_TONE_MAPPING")
    @core.CineonToneMapping => Some("CINEON_TONE_MAPPING")
    @core.ACESFilmicToneMapping => Some("ACES_FILMIC_TONE_MAPPING")
    @core.AgXToneMapping => Some("AGX_TONE_MAPPING")
    @core.NeutralToneMapping => Some("NEUTRAL_TONE_MAPPING")
    @core.CustomToneMapping => Some("CUSTOM_TONE_MAPPING")
    _ => None
  }
}

///|
/// `new WebGLOutput( type, width, height, antialias, depth, stencil )`.
pub fn WebGLOutput::new(
  type_ : Int32,
  width : Int32,
  height : Int32,
  antialias : Bool,
  depth : Bool,
  stencil : Bool,
) -> WebGLOutput {
  // render target for the scene pass (potentially multisampled)
  let target_scene = WebGLRenderTarget::new(
    width~,
    height~,
    type_~,
    depth_buffer=depth,
    stencil_buffer=stencil,
    samples=if antialias { 4 } else { 0 },
    store_multisampled_depth_buffer=false,
    store_multisampled_stencil_buffer=false,
    resolve_depth_buffer=false,
    resolve_stencil_buffer=false,
  )

  // create fullscreen triangle geometry
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.BufferAttribute::new(
        @core.TypedArray::float32([-1.0, 3, 0, -1, -1, 0, 3, -1, 0]),
        3,
      ),
    ),
  )
  ignore(
    geometry.set_attribute(
      "uv",
      @core.BufferAttribute::new(
        @core.TypedArray::float32([0.0, 2, 0, 0, 2, 0]),
        2,
      ),
    ),
  )

  // create output material with tone mapping support
  let material = @core.RawShaderMaterial::new()
  material.uniforms = Some(Map([("tDiffuse", { value: Null, })]))
  material.vertex_shader = Some(webgl_output_vertex_shader)
  material.fragment_shader = Some(webgl_output_fragment_shader)
  material.depth_test = false
  material.depth_write = false
  let mesh = @core.Mesh::new(geometry~, material=Single(material))
  let camera = @core.OrthographicCamera::new(
    left=-1,
    right=1,
    top=1,
    bottom=-1,
    near=0,
    far=1,
  )
  {
    type_,
    antialias,
    depth,
    stencil,
    target_scene,
    target_a: None,
    target_b: None,
    depth_texture: None,
    geometry,
    material,
    mesh,
    camera,
    _output_color_space: None,
    _output_tone_mapping: None,
    _is_compositing: false,
    _saved_tone_mapping: @core.NoToneMapping,
    _saved_render_target: None,
    _effects: [],
    _has_render_pass: false,
  }
}

///|
/// `output.setSize( width, height )`.
pub fn WebGLOutput::set_size(
  self : WebGLOutput,
  width : Int32,
  height : Int32,
) -> Unit {
  self.target_scene.set_size(width, height)
  if self.target_a is Some(target_a) {
    target_a.set_size(width, height)
  }
  if self.target_b is Some(target_b) {
    target_b.set_size(width, height)
  }
  for effect in self._effects {
    effect.set_size(width, height)
  }
}

///|
/// `output.setEffects( effects )`.
pub fn WebGLOutput::set_effects(
  self : WebGLOutput,
  effects : Array[&WebGLOutputEffect],
) -> Unit {
  self._effects = effects
  self._has_render_pass = effects.length() > 0 && effects[0].is_render_pass()
  let target_scene = self.target_scene
  let width = target_scene.width
  let height = target_scene.height
  if effects.length() > 0 && self.target_a is None {
    self.target_a = Some(
      WebGLRenderTarget::new(
        width~,
        height~,
        type_=@core.HalfFloatType,
        depth_buffer=false,
        stencil_buffer=false,
      ),
    )
    self.target_b = Some(
      WebGLRenderTarget::new(
        width~,
        height~,
        type_=@core.HalfFloatType,
        depth_buffer=false,
        stencil_buffer=false,
      ),
    )
  }

  // only store and resolve the scene depth if an effect reads it
  let needs_depth_texture = self.depth &&
    effects.iter().any(fn(effect) { effect.needs_depth_texture() })
  if needs_depth_texture != (target_scene.depth_texture() is Some(_)) {
    if needs_depth_texture && self.depth_texture is None {
      let depth_texture = @core.DepthTexture::new(width~, height~)
      if self.stencil {
        depth_texture.format = @core.DepthStencilFormat
        depth_texture.type_ = @core.UnsignedInt248Type
      }
      self.depth_texture = Some(depth_texture)
    }

    // release GPU resources so the scene target is rebuilt with the new depth setup
    target_scene.dispose()
    target_scene.set_depth_texture(
      if needs_depth_texture {
        self.depth_texture
      } else {
        None
      },
    )
    target_scene.resolve_depth_buffer = needs_depth_texture
    target_scene.store_multisampled_depth_buffer = needs_depth_texture
  }
  for effect in effects {
    effect.set_size(width, height)
    if needs_depth_texture && effect.needs_depth_texture() {
      effect.set_depth_texture(self.depth_texture.unwrap())
    }
  }
}

///|
/// `output.begin( renderer, renderTarget )`; true if the scene renders into the output
/// target.
pub fn WebGLOutput::begin(
  self : WebGLOutput,
  renderer : WebGLRenderer,
  render_target : @core.RenderTarget?,
) -> Bool {
  // Don't begin during compositing phase (post-processing effects call render())
  if self._is_compositing {
    return false
  }
  if renderer.tone_mapping == @core.NoToneMapping && self._effects.length() == 0 {
    return false
  }
  self._saved_render_target = render_target

  // resize internal buffers to match render target (e.g. XR resolution)
  if render_target is Some(render_target) {
    let width = render_target.width
    let height = render_target.height
    if self.target_scene.width != width || self.target_scene.height != height {
      self.set_size(width, height)
    }
  }

  // if the first effect is a RenderPass, it renders the scene itself (see end())
  if self._has_render_pass == false {
    renderer.set_render_target(Some(self.target_scene))
  }

  // disable tone mapping during render - it will be applied in end()
  self._saved_tone_mapping = renderer.tone_mapping
  renderer.tone_mapping = @core.NoToneMapping
  true
}

///|
/// `output.hasRenderPass()`.
pub fn WebGLOutput::has_render_pass(self : WebGLOutput) -> Bool {
  self._has_render_pass
}

///|
/// `output.end( renderer, deltaTime )`.
pub fn WebGLOutput::end(
  self : WebGLOutput,
  renderer : WebGLRenderer,
  delta_time? : Double,
) -> Unit {
  // restore tone mapping
  renderer.tone_mapping = self._saved_tone_mapping
  self._is_compositing = true

  // run post-processing effects - the scene lives in the multisampled targetScene,
  // effects ping-pong between the single-sampled targetA and targetB
  let mut read_buffer = self.target_scene
  let mut write_buffer = self.target_a
  for effect in self._effects {
    if effect.enabled() == false {
      continue
    }
    effect.render(renderer, write_buffer, read_buffer, delta_time)
    if effect.needs_swap() != false {
      // keep targetScene out of the rotation so only the scene pass is multisampled
      guard write_buffer is Some(written) else {
        abort("WebGLOutput: effects without ping-pong targets")
      }
      read_buffer = written
      write_buffer = match self.target_a {
        Some(target_a) if physical_equal(written, target_a) => self.target_b
        _ => self.target_a
      }
    }
  }

  // update output material defines if settings changed
  let material = self.material
  if self._output_color_space != Some(renderer.output_color_space()) ||
    self._output_tone_mapping != Some(renderer.tone_mapping) {
    self._output_color_space = Some(renderer.output_color_space())
    self._output_tone_mapping = Some(renderer.tone_mapping)
    let defines : Map[String, Json] = Map([])
    material.defines = Some(defines)
    if @math.color_management.get_transfer(renderer.output_color_space()) ==
      @core.SRGBTransfer {
      defines.set("SRGB_TRANSFER", Json::string(""))
    }
    if webgl_output_tone_mapping_define(renderer.tone_mapping)
      is Some(tone_mapping) {
      defines.set(tone_mapping, Json::string(""))
    }
    material.set_needs_update(true)
  }

  // final output to canvas (or XR render target)
  material.uniforms.unwrap().get("tDiffuse").unwrap().value = Texture(
    read_buffer.texture(),
  )
  renderer.set_render_target(self._saved_render_target)
  renderer.render(self.mesh, self.camera)
  self._saved_render_target = None
  self._is_compositing = false
}

///|
/// `output.isCompositing()`.
pub fn WebGLOutput::is_compositing(self : WebGLOutput) -> Bool {
  self._is_compositing
}

///|
/// `output.dispose()`.
pub fn WebGLOutput::dispose(self : WebGLOutput) -> Unit {
  self.target_scene.dispose()
  if self.target_a is Some(target_a) {
    target_a.dispose()
  }
  if self.target_b is Some(target_b) {
    target_b.dispose()
  }
  self.geometry.dispose()
  self.material.dispose()
}

///|
let webgl_output_vertex_shader : String =
  #|
  #|			precision highp float;
  #|
  #|			uniform mat4 modelViewMatrix;
  #|			uniform mat4 projectionMatrix;
  #|
  #|			attribute vec3 position;
  #|			attribute vec2 uv;
  #|
  #|			varying vec2 vUv;
  #|
  #|			void main() {
  #|				vUv = uv;
  #|				gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
  #|			}

///|
let webgl_output_fragment_shader : String =
  #|
  #|			precision highp float;
  #|
  #|			uniform sampler2D tDiffuse;
  #|
  #|			varying vec2 vUv;
  #|
  #|			#include <tonemapping_pars_fragment>
  #|			#include <colorspace_pars_fragment>
  #|
  #|			void main() {
  #|				gl_FragColor = texture2D( tDiffuse, vUv );
  #|
  #|				#ifdef LINEAR_TONE_MAPPING
  #|					gl_FragColor.rgb = LinearToneMapping( gl_FragColor.rgb );
  #|				#elif defined( REINHARD_TONE_MAPPING )
  #|					gl_FragColor.rgb = ReinhardToneMapping( gl_FragColor.rgb );
  #|				#elif defined( CINEON_TONE_MAPPING )
  #|					gl_FragColor.rgb = CineonToneMapping( gl_FragColor.rgb );
  #|				#elif defined( ACES_FILMIC_TONE_MAPPING )
  #|					gl_FragColor.rgb = ACESFilmicToneMapping( gl_FragColor.rgb );
  #|				#elif defined( AGX_TONE_MAPPING )
  #|					gl_FragColor.rgb = AgXToneMapping( gl_FragColor.rgb );
  #|				#elif defined( NEUTRAL_TONE_MAPPING )
  #|					gl_FragColor.rgb = NeutralToneMapping( gl_FragColor.rgb );
  #|				#elif defined( CUSTOM_TONE_MAPPING )
  #|					gl_FragColor.rgb = CustomToneMapping( gl_FragColor.rgb );
  #|				#endif
  #|
  #|				#ifdef SRGB_TRANSFER
  #|					gl_FragColor = sRGBTransferOETF( gl_FragColor );
  #|				#endif
  #|			}
