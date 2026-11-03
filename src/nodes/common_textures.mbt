// renderers/common/Textures.js

///|
extern "js" fn textures_js_get(
  object : @core.JsValue,
  key : String,
) -> @core.JsValue = "(o, k) => o[k]"

///|
extern "js" fn textures_js_or_one(
  object : @core.JsValue,
  key : String,
) -> Int32 = "(o, k) => o[k] || 1"

///|
extern "js" fn textures_is_video_element(image : @core.JsValue) -> Bool = "(i) => (typeof HTMLVideoElement !== 'undefined') && (i instanceof HTMLVideoElement)"

///|
extern "js" fn textures_is_video_frame(image : @core.JsValue) -> Bool = "(i) => (typeof VideoFrame !== 'undefined') && (i instanceof VideoFrame)"

///|
extern "js" fn textures_has_key(object : @core.JsValue, key : String) -> Bool = "(o, k) => k in o"

///|
extern "js" fn textures_canvas_prepare(
  canvas : @core.JsValue,
  image : @core.JsValue,
) -> Unit =
  #|(canvas, image) => {
  #|  if ( ! canvas.hasAttribute( 'layoutsubtree' ) ) canvas.setAttribute( 'layoutsubtree', 'true' );
  #|  if ( image.parentNode !== canvas ) canvas.appendChild( image );
  #|}

///|
extern "js" fn textures_canvas_on_paint(
  canvas : @core.JsValue,
  f : (@core.JsValue) -> Unit,
) -> Unit = "(canvas, f) => { canvas.onpaint = ( event ) => f( event && event.changedElements ); }"

///|
extern "js" fn textures_includes(
  array : @core.JsValue,
  value : @core.JsValue,
) -> Bool = "(a, v) => a.includes(v)"

///|
extern "js" fn textures_js_truthy(value : @core.JsValue) -> Bool = "(v) => !!v"

///|
extern "js" fn textures_math_log2(x : Double) -> Double = "Math.log2"

///|
/// `{ width, height, depth }` of `getSize`.
pub(all) struct TextureSize {
  mut width : Int32
  mut height : Int32
  mut depth : Int32
}

///|
let _textures_size : TextureSize = { width: 0, height: 0, depth: 0, }

///|
/// The `options` of `backend.createTexture` / `updateTexture`.
pub(all) struct TextureOptions {
  /// `undefined` unless the texture belongs to a render target.
  mut sample_count : Int32?
  mut width : Int32
  mut height : Int32
  mut depth : Int32
  mut needs_mipmaps : Bool
  mut levels : Int32
  /// `options.image`; `None` is unset.
  mut image : @core.TextureImage?
  /// `options.images` of cube textures; `None` is unset.
  mut images : Array[@core.TextureImage]?
  /// `options.renderTarget` of `copyFramebufferToTexture` (added by G6).
  mut render_target : @core.RenderTarget?
}

///|
/// `{}` or `{ sampleCount }`.
pub fn TextureOptions::new(sample_count? : Int32) -> TextureOptions {
  {
    sample_count,
    width: 0,
    height: 0,
    depth: 0,
    needs_mipmaps: false,
    levels: 0,
    image: None,
    images: None,
    render_target: None,
  }
}

///|
/// The record of a texture in `Textures`.
pub(all) struct TextureData {
  mut initialized : Bool?
  mut version : Int32?
  mut generation : Int32?
  mut is_default_texture : Bool?
  mut bind_groups : RefSet[BindGroup]?
  mut on_dispose : ((@core.Event) -> Unit)?
  mut ref_ : @webgl.WeakRef[@core.Texture]?
}

///|
/// The record of a render target in `Textures`.
pub(all) struct RenderTargetData {
  mut initialized : Bool?
  /// `depthTextureMips[ activeMipmapLevel ]`.
  mut depth_texture_mips : Map[Int32, @core.Texture]?
  mut width : Int32?
  mut height : Int32?
  mut textures : Array[@core.Texture]?
  /// `null` when the target has no depth texture.
  mut depth_texture : @core.Texture?
  mut depth : Bool?
  mut stencil : Bool?
  mut render_target : @core.RenderTarget?
  mut sample_count : Int32?
  mut on_dispose : ((@core.Event) -> Unit)?
  mut ref_ : @webgl.WeakRef[@core.RenderTarget]?
  /// `depthInitialized`, set by the renderer (added by G6).
  mut depth_initialized : Bool?
}

///|
/// A tracked texture or render target.
priv enum TexturesTracked {
  TrackedTexture(@webgl.WeakRef[@core.Texture])
  TrackedRenderTarget(@webgl.WeakRef[@core.RenderTarget])
}

///|
/// Creates, updates and destroys the GPU textures of textures and render targets.
pub struct Textures {
  renderer : Renderer
  backend : Backend
  info : Info
  priv textures_data : DataMap[@core.Texture, TextureData]
  priv render_targets_data : DataMap[@core.RenderTarget, RenderTargetData]
  priv _html_textures : RefSet[@core.Texture]
  priv _tracked : RefSet[TexturesTracked]
  priv _tracked_keys : @webgl.WeakMap[@core.JsValue, TexturesTracked]
  priv _registry : @webgl.FinalizationRegistry[@core.JsValue]
}

///|
/// `new Textures( renderer, backend, info )`.
pub fn Textures::new(
  renderer : Renderer,
  backend : Backend,
  info : Info,
) -> Textures {
  let tracked : RefSet[TexturesTracked] = RefSet::new()
  let tracked_keys : @webgl.WeakMap[@core.JsValue, TexturesTracked] = @webgl.WeakMap::new()
  {
    renderer,
    backend,
    info,
    textures_data: DataMap::new(fn() {
      {
        initialized: None,
        version: None,
        generation: None,
        is_default_texture: None,
        bind_groups: None,
        on_dispose: None,
        ref_: None,
      }
    }),
    render_targets_data: DataMap::new(fn() {
      {
        initialized: None,
        depth_texture_mips: None,
        width: None,
        height: None,
        textures: None,
        depth_texture: None,
        depth: None,
        stencil: None,
        render_target: None,
        sample_count: None,
        on_dispose: None,
        ref_: None,
        depth_initialized: None,
      }
    }),
    _html_textures: RefSet::new(),
    _tracked: tracked,
    _tracked_keys: tracked_keys,
    _registry: @webgl.FinalizationRegistry::new(fn(ref_) {
      match tracked_keys.get(ref_) {
        Some(t) => tracked.delete(t)
        None => ()
      }
    }),
  }
}

///|
/// `get( texture )`: the texture's record.
pub fn Textures::get(self : Textures, texture : @core.Texture) -> TextureData {
  self.textures_data.get(texture)
}

///|
/// `has( texture )`.
pub fn Textures::has(self : Textures, texture : @core.Texture) -> Bool {
  self.textures_data.has(texture)
}

///|
/// `delete( texture )`.
pub fn Textures::delete(
  self : Textures,
  texture : @core.Texture,
) -> TextureData? {
  self.textures_data.delete(texture)
}

///|
/// `get( renderTarget )`: the render target's record.
pub fn Textures::get_render_target(
  self : Textures,
  render_target : @core.RenderTarget,
) -> RenderTargetData {
  self.render_targets_data.get(render_target)
}

///|
/// `has( renderTarget )`.
pub fn Textures::has_render_target(
  self : Textures,
  render_target : @core.RenderTarget,
) -> Bool {
  self.render_targets_data.has(render_target)
}

///|
/// `delete( renderTarget )`.
pub fn Textures::delete_render_target(
  self : Textures,
  render_target : @core.RenderTarget,
) -> RenderTargetData? {
  self.render_targets_data.delete(render_target)
}

///|
fn Textures::_track_texture(
  self : Textures,
  texture : @core.Texture,
) -> @webgl.WeakRef[@core.Texture] {
  let r = @webgl.WeakRef::new(texture)
  let t = TrackedTexture(r)
  self._tracked_keys.set(@core.JsValue::of(r), t)
  self._tracked.add(t)
  self._registry.register(texture, @core.JsValue::of(r), r)
  r
}

///|
fn Textures::_untrack(self : Textures, ref_ : @core.JsValue) -> Unit {
  match self._tracked_keys.get(ref_) {
    Some(t) => self._tracked.delete(t)
    None => ()
  }
  self._registry.unregister(ref_)
}

///|
/// `dispose()`: destroys every tracked texture and render target.
pub fn Textures::dispose(self : Textures) -> Unit {
  self._tracked.each(fn(t) {
    match t {
      TrackedRenderTarget(r) =>
        match r.deref() {
          Some(render_target) =>
            if self.has_render_target(render_target) {
              self._destroy_render_target(render_target)
            }
          None => ()
        }
      TrackedTexture(r) =>
        match r.deref() {
          Some(texture) =>
            if self.has(texture) {
              self._destroy_texture(texture)
            }
          None => ()
        }
    }
  })
  self._tracked.clear()
  self._html_textures.clear()
  self.textures_data.dispose()
  self.render_targets_data.dispose()
}

///|
/// `updateRenderTarget( renderTarget, activeMipmapLevel = 0 )`: sizes the depth
/// texture and updates the target's textures.
pub fn Textures::update_render_target(
  self : Textures,
  render_target : @core.RenderTarget,
  active_mipmap_level~ : Int32 = 0,
) -> Unit {
  let render_target_data = self.get_render_target(render_target)
  let sample_count = if render_target.samples == 0 {
    1
  } else {
    render_target.samples
  }
  let depth_texture_mips = match render_target_data.depth_texture_mips {
    Some(m) => m
    None => {
      let m = Map([])
      render_target_data.depth_texture_mips = Some(m)
      m
    }
  }
  let textures = render_target.textures
  let size = if textures.length() > 0 {
    self.get_size(textures[0])
  } else {
    match render_target.depth_texture() {
      Some(t) => self.get_size(t)
      None =>
        abort("TypeError: Cannot read properties of null (reading 'images')")
    }
  }
  let size_width = size.width
  let size_height = size.height
  let size_depth = size.depth
  let mip_width = size_width >> active_mipmap_level
  let mip_height = size_height >> active_mipmap_level
  let mut depth_texture = match render_target.depth_texture() {
    Some(t) => Some(t)
    None => depth_texture_mips.get(active_mipmap_level)
  }
  let use_depth_texture = render_target.depth_buffer ||
    render_target.stencil_buffer
  let mut texture_needs_update = false
  let has_array_depth_texture = match depth_texture {
    Some(t) => _textures_image_depth(t.image()) > 1
    None => false
  }
  let use_array_depth = size_depth > 1 &&
    (
      render_target.use_array_depth_texture ||
      render_target.multiview ||
      has_array_depth_texture
    )
  if depth_texture is None && use_depth_texture {
    let t = @core.DepthTexture::new()
    t.format = if render_target.stencil_buffer {
      @core.DepthStencilFormat
    } else {
      @core.DepthFormat
    }
    t.type_ = if self.renderer.reversed_depth_buffer {
      @core.FloatType
    } else if render_target.stencil_buffer {
      @core.UnsignedInt248Type
    } else {
      @core.UnsignedIntType
    }
    t.image().set_size(mip_width, mip_height, size_depth)
    t.render_target = Some(render_target)
    depth_texture_mips.set(active_mipmap_level, t)
    depth_texture = Some(t)
  }
  match depth_texture {
    Some(t) => t.is_array_texture = use_array_depth
    None => ()
  }
  if render_target_data.width != Some(size_width) ||
    Some(size_height) != render_target_data.height {
    texture_needs_update = true
  }
  match depth_texture {
    Some(t) if _textures_owned_by(t, render_target) => {
      let image = t.image()
      if texture_needs_update ||
        _textures_image_width(image) != mip_width ||
        _textures_image_height(image) != mip_height {
        image.set_size(
          mip_width,
          mip_height,
          if use_array_depth {
            size_depth
          } else {
            1
          },
        )
        t.set_needs_update(true)
      }
    }
    _ => ()
  }
  render_target_data.width = Some(size_width)
  render_target_data.height = Some(size_height)
  render_target_data.textures = Some(textures)
  render_target_data.depth_texture = depth_texture
  render_target_data.depth = Some(render_target.depth_buffer)
  render_target_data.stencil = Some(render_target.stencil_buffer)
  render_target_data.render_target = Some(render_target)
  if render_target_data.sample_count != Some(sample_count) {
    texture_needs_update = true
    match depth_texture {
      Some(t) if _textures_owned_by(t, render_target) =>
        t.set_needs_update(true)
      _ => ()
    }
    render_target_data.sample_count = Some(sample_count)
  }
  if render_target_data.initialized != Some(true) {
    render_target_data.initialized = Some(true)
    self.info.memory.render_targets += 1
    let on_dispose = fn(_e : @core.Event) {
      self._destroy_render_target(render_target)
    }
    render_target_data.on_dispose = Some(on_dispose)
    render_target.add_event_listener("dispose", on_dispose)
    let r = @webgl.WeakRef::new(render_target)
    render_target_data.ref_ = Some(r)
    let t = TrackedRenderTarget(r)
    self._tracked_keys.set(@core.JsValue::of(r), t)
    self._tracked.add(t)
    self._registry.register(render_target, @core.JsValue::of(r), r)
  }
  let options = TextureOptions::new(sample_count~)
  if !render_target.has_extension_flag("isXRRenderTarget") {
    for texture in textures {
      if texture_needs_update {
        texture.set_needs_update(true)
      }
      self.update_texture(texture, options~) |> ignore
    }
    match depth_texture {
      Some(t) => self.update_texture(t, options~) |> ignore
      None => ()
    }
  }
}

///|
/// `depthTexture.renderTarget === renderTarget`.
fn _textures_owned_by(
  texture : @core.Texture,
  render_target : @core.RenderTarget,
) -> Bool {
  match texture.render_target {
    Some(rt) => physical_equal(rt, render_target)
    None => false
  }
}

///|
fn _textures_image_width(image : @core.TextureImage) -> Int32 {
  image.width().to_int()
}

///|
fn _textures_image_height(image : @core.TextureImage) -> Int32 {
  image.height().to_int()
}

///|
/// `image.depth`, or 0 when the image has none.
fn _textures_image_depth(image : @core.TextureImage) -> Int32 {
  match image {
    NoImage => 0
    _ => image.depth().to_int()
  }
}

///|
/// The mipmaps `getMipmaps` returns, for their count.
fn _textures_mipmaps_length(texture : @core.Texture) -> Int32 {
  if texture.texture_type is CompressedCubeTexture {
    match texture.image() {
      ImageArray(images) if images.length() > 0 =>
        match images[0] {
          TextureImage(t) => t.mipmaps.length()
          DataImage({ mipmaps: Some(m), .. }) => m.length()
          DomImage(v) =>
            match textures_js_get(v, "mipmaps") {
              m if m.is_undefined() || m.is_null() =>
                abort(
                  "TypeError: Cannot read properties of undefined (reading 'length')",
                )
              m => textures_js_get(m, "length").cast()
            }
          _ =>
            abort(
              "TypeError: Cannot read properties of undefined (reading 'length')",
            )
        }
      _ =>
        abort(
          "TypeError: Cannot read properties of undefined (reading 'mipmaps')",
        )
    }
  } else {
    texture.mipmaps.length()
  }
}

///|
/// `texture.images` (cube textures); `None` when the texture has no such getter.
fn _textures_images(texture : @core.Texture) -> @core.TextureImage? {
  match texture.texture_type {
    CubeTexture | CubeDepthTexture => Some(texture.image())
    _ => None
  }
}

///|
/// Whether a JS value would be truthy as `texture.images`.
fn _textures_image_truthy(image : @core.TextureImage) -> Bool {
  match image {
    NoImage => false
    DomImage(v) => textures_js_truthy(v)
    _ => true
  }
}

///|
/// `x[ 0 ]` of an image value.
fn _textures_first(image : @core.TextureImage) -> @core.TextureImage {
  match image {
    ImageArray(images) => if images.length() > 0 { images[0] } else { NoImage }
    DomImage(v) => @core.TextureImage::from_js(textures_js_get(v, "0"))
    _ => NoImage
  }
}

///|
/// `updateTexture( texture, options = {} )`: creates or updates the GPU texture; the
/// texture's generation (`None` is `undefined`).
pub fn Textures::update_texture(
  self : Textures,
  texture : @core.Texture,
  options? : TextureOptions,
) -> Int32? {
  let options = match options {
    Some(o) => o
    None => TextureOptions::new()
  }
  let texture_data = self.get(texture)
  if texture_data.initialized == Some(true) &&
    texture_data.version == Some(texture.version) {
    return texture_data.generation
  }
  let render_target = if texture.is_render_target_texture ||
    texture.is_depth_texture() {
    texture.render_target
  } else {
    None
  }
  match render_target {
    Some(rt) if self.get_render_target(rt).initialized != Some(true) => {
      self.update_render_target(rt)
      return texture_data.generation
    }
    _ => ()
  }
  let is_render_target = texture.is_render_target_texture ||
    texture.is_depth_texture() ||
    texture.texture_type is FramebufferTexture
  let backend = self.backend
  if is_render_target && texture_data.initialized == Some(true) {
    backend.destroy_texture(texture)
  }
  if texture.texture_type is FramebufferTexture {
    match self.renderer.get_render_target() {
      Some(render_target) => texture.type_ = render_target.texture().type_
      None => texture.type_ = @core.UnsignedByteType
    }
  }
  if texture.texture_type is HTMLTexture &&
    _textures_image_truthy(texture.image()) {
    let canvas = self.renderer.dom_element()
    if textures_has_key(canvas, "requestPaint") {
      textures_canvas_prepare(canvas, texture.image().to_js())
      if self._html_textures.size() == 0 {
        let html_textures = self._html_textures
        textures_canvas_on_paint(canvas, fn(changed) {
          html_textures.each(fn(t) {
            if !textures_js_truthy(changed) ||
              textures_includes(changed, t.image().to_js()) {
              t.set_needs_update(true)
            }
          })
        })
      }
      self._html_textures.add(texture)
    }
  }
  let size = self.get_size(texture)
  let width = size.width
  let height = size.height
  let depth = size.depth
  options.width = width
  options.height = height
  options.depth = depth
  options.needs_mipmaps = self.needs_mipmaps(texture)
  options.levels = if options.needs_mipmaps {
    self.get_mip_levels(texture, width, height)
  } else {
    1
  }
  if texture.is_cube_texture() &&
    texture.mipmaps.length() > 0 &&
    !is_render_target {
    options.levels += 1
  }
  if is_render_target ||
    is_storage_texture(texture) ||
    texture.texture_type is ExternalTexture {
    backend.create_texture(texture, options)
    texture_data.generation = Some(texture.version)
  } else if texture.version > 0 {
    let image = texture.image()
    let incomplete = match image {
      NoImage =>
        abort("TypeError: Cannot read properties of null (reading 'complete')")
      DomImage(v) => {
        let complete = textures_js_get(v, "complete")
        complete.strict_equal(@core.JsValue::of(false))
      }
      _ => false
    }
    if incomplete {
      @core.warn("Renderer: Texture marked for update but image is incomplete.")
    } else {
      match _textures_images(texture) {
        Some(images) if _textures_image_truthy(images) =>
          match images {
            ImageArray(list) => options.images = Some(list.copy())
            _ => abort("TypeError: texture.images is not iterable")
          }
        _ => options.image = Some(image)
      }
      if texture_data.is_default_texture is (None | Some(true)) {
        backend.create_texture(texture, options)
        texture_data.is_default_texture = Some(false)
        texture_data.generation = Some(texture.version)
      }
      if texture.source.data_ready {
        backend.update_texture(texture, options)
        texture.clear_update_ranges()
      }
      if options.needs_mipmaps &&
        _textures_mipmaps_length(texture) == 0 &&
        texture.mipmaps_auto_update {
        backend.generate_mipmaps(texture)
      }
      match texture.on_update {
        Some(f) => f(texture)
        None => ()
      }
    }
  } else {
    backend.create_default_texture(texture)
    texture_data.is_default_texture = Some(true)
    texture_data.generation = Some(texture.version)
  }
  if texture_data.initialized != Some(true) {
    texture_data.initialized = Some(true)
    texture_data.generation = Some(texture.version)
    texture_data.bind_groups = Some(RefSet::new())
    self.info.create_texture(texture)
    if texture.is_video_texture() &&
      @math.color_management.enabled &&
      @math.color_management.get_transfer(texture.color_space) !=
      @math.SRGBTransfer {
      @core.warn(
        "WebGPURenderer: Video textures must use a color space with a sRGB transfer function, e.g. SRGBColorSpace.",
      )
    }
    if !texture.is_render_target_texture {
      let on_dispose = fn(_e : @core.Event) { self._destroy_texture(texture) }
      texture_data.on_dispose = Some(on_dispose)
      texture.add_event_listener("dispose", on_dispose)
    }
    texture_data.ref_ = Some(self._track_texture(texture))
  }
  texture_data.version = Some(texture.version)
  texture_data.generation
}

///|
/// `updateSampler( sampler )`: the backend's sampler key.
pub fn Textures::update_sampler(self : Textures, sampler : Binding) -> String {
  self.backend.update_sampler(sampler)
}

///|
/// `getSize( texture, target = _size )`: the size of the texture's image (the shared
/// target is returned, as upstream).
pub fn Textures::get_size(
  self : Textures,
  texture : @core.Texture,
  target? : TextureSize,
) -> TextureSize {
  ignore(self)
  let target = match target {
    Some(t) => t
    None => _textures_size
  }
  let mut image = match _textures_images(texture) {
    Some(images) if _textures_image_truthy(images) => _textures_first(images)
    _ => texture.image()
  }
  if texture.texture_type is CompressedCubeTexture {
    image = _textures_first(image)
  }
  match image {
    TextureImage(t) => image = t.image()
    DomImage(v) => {
      let inner = textures_js_get(v, "image")
      if !inner.is_undefined() {
        image = @core.TextureImage::from_js(inner)
      }
    }
    _ => ()
  }
  if _textures_image_truthy(image) {
    match image {
      DomImage(v) if texture.texture_type is HTMLTexture => {
        target.width = textures_js_or_one(v, "offsetWidth")
        target.height = textures_js_or_one(v, "offsetHeight")
        target.depth = 1
      }
      DomImage(v) if textures_is_video_element(v) => {
        target.width = textures_js_or_one(v, "videoWidth")
        target.height = textures_js_or_one(v, "videoHeight")
        target.depth = 1
      }
      DomImage(v) if textures_is_video_frame(v) => {
        target.width = textures_js_or_one(v, "displayWidth")
        target.height = textures_js_or_one(v, "displayHeight")
        target.depth = 1
      }
      DomImage(v) => {
        target.width = textures_js_or_one(v, "width")
        target.height = textures_js_or_one(v, "height")
        target.depth = if texture.is_cube_texture() {
          6
        } else {
          textures_js_or_one(v, "depth")
        }
      }
      _ => {
        target.width = _textures_or_one(image.width())
        target.height = _textures_or_one(image.height())
        target.depth = if texture.is_cube_texture() {
          6
        } else {
          _textures_or_one(image.depth())
        }
      }
    }
  } else {
    target.width = 1
    target.height = 1
    target.depth = 1
  }
  target
}

///|
/// `x || 1`.
fn _textures_or_one(x : Double) -> Int32 {
  if x == 0.0 || x.is_nan() {
    1
  } else {
    x.to_int()
  }
}

///|
/// `getMipLevels( texture, width, height )`.
pub fn Textures::get_mip_levels(
  self : Textures,
  texture : @core.Texture,
  width : Int32,
  height : Int32,
) -> Int32 {
  ignore(self)
  let mipmaps_length = _textures_mipmaps_length(texture)
  if mipmaps_length > 0 {
    mipmaps_length
  } else if texture.is_compressed_texture() {
    1
  } else {
    let max = if width > height { width } else { height }
    textures_math_log2(max.to_double()).floor().to_int() + 1
  }
}

///|
/// `needsMipmaps( texture )`.
pub fn Textures::needs_mipmaps(
  self : Textures,
  texture : @core.Texture,
) -> Bool {
  ignore(self)
  texture.generate_mipmaps || _textures_mipmaps_length(texture) > 0
}

///|
/// `_destroyRenderTarget( renderTarget )`.
pub fn Textures::_destroy_render_target(
  self : Textures,
  render_target : @core.RenderTarget,
) -> Unit {
  if self.has_render_target(render_target) {
    let render_target_data = self.get_render_target(render_target)
    let textures = render_target_data.textures
    let depth_texture = render_target_data.depth_texture
    match render_target_data.on_dispose {
      Some(f) => render_target.remove_event_listener("dispose", f)
      None => ()
    }
    match render_target_data.ref_ {
      Some(r) => self._untrack(@core.JsValue::of(r))
      None => self._untrack(@core.JsValue::undefined())
    }
    match textures {
      Some(textures) =>
        for texture in textures {
          self._destroy_texture(texture)
        }
      None =>
        abort(
          "TypeError: Cannot read properties of undefined (reading 'length')",
        )
    }
    match depth_texture {
      Some(t) if _textures_owned_by(t, render_target) =>
        self._destroy_texture(t)
      _ => ()
    }
    self.delete_render_target(render_target) |> ignore
    self.backend.delete(@core.JsValue::of(render_target))
    self.info.memory.render_targets -= 1
  }
}

///|
/// `_destroyTexture( texture )`.
pub fn Textures::_destroy_texture(
  self : Textures,
  texture : @core.Texture,
) -> Unit {
  if self.has(texture) {
    let texture_data = self.get(texture)
    match texture_data.on_dispose {
      Some(f) => texture.remove_event_listener("dispose", f)
      None => ()
    }
    match texture_data.ref_ {
      Some(r) => self._untrack(@core.JsValue::of(r))
      None => self._untrack(@core.JsValue::undefined())
    }
    let is_default_texture = texture_data.is_default_texture
    self.backend.destroy_texture(texture, is_default_texture?)
    match texture_data.bind_groups {
      Some(bind_groups) =>
        bind_groups.each(fn(bind_group) {
          let bindings_data = self.backend.get(@core.JsValue::of(bind_group))
          bindings_data.set("groups", @core.JsValue::undefined())
          bindings_data.set("versions", @core.JsValue::undefined())
          for binding in bind_group.bindings {
            if binding.has_flag("isSampler") &&
              _sampler_same_texture(binding.texture(), Some(texture)) {
              if !binding.has_flag("isSampledTexture") {
                self.backend.destroy_sampler(binding)
              }
              binding.reset()
              binding.release()
            }
          }
        })
      None => ()
    }
    self._html_textures.delete(texture)
    self.delete(texture) |> ignore
    self.info.destroy_texture(texture)
  }
}
