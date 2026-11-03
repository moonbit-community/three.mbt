// Upstream src/core/RenderTarget.js.

///|
pub fn RenderTarget::new(
  width~ : Int32 = 1,
  height~ : Int32 = 1,
  generate_mipmaps? : Bool,
  internal_format? : String,
  min_filter? : Int32,
  depth_buffer~ : Bool = true,
  stencil_buffer~ : Bool = false,
  resolve_color_buffer~ : Bool = true,
  resolve_depth_buffer~ : Bool = true,
  resolve_stencil_buffer~ : Bool = true,
  store_multisampled_color_buffer~ : Bool = true,
  store_multisampled_depth_buffer~ : Bool = true,
  store_multisampled_stencil_buffer~ : Bool = true,
  depth_texture? : Texture,
  samples~ : Int32 = 0,
  count~ : Int32 = 1,
  depth~ : Int32 = 1,
  multiview~ : Bool = false,
  use_array_depth_texture~ : Bool = false,
  mapping? : Int32,
  wrap_s? : Int32,
  wrap_t? : Int32,
  wrap_r? : Int32,
  mag_filter? : Int32,
  format? : Int32,
  type_? : Int32,
  anisotropy? : Int32,
  color_space? : String,
  flip_y? : Bool,
  mipmaps_auto_update? : Bool,
) -> RenderTarget {
  let w = width.to_double()
  let h = height.to_double()
  let target : RenderTarget = {
    dispatcher: EventDispatcher::new(),
    width,
    height,
    depth,
    scissor: @math.Vector4::new(0.0, 0.0, w, h),
    scissor_test: false,
    viewport: @math.Vector4::new(0.0, 0.0, w, h),
    textures: [],
    depth_buffer,
    stencil_buffer,
    resolve_color_buffer,
    resolve_depth_buffer,
    resolve_stencil_buffer,
    store_multisampled_color_buffer,
    store_multisampled_depth_buffer,
    store_multisampled_stencil_buffer,
    _depth_texture: None,
    samples,
    multiview,
    use_array_depth_texture,
    render_target_type: PlainRenderTarget,
    extension: None,
  }
  for _ in 0..<count {
    let texture = Texture::new(
      image=DataImage(DataImage::new(width~, height~, depth~)),
    )
    texture.is_render_target_texture = true
    texture.render_target = Some(target)
    target.textures.push(texture)
  }
  target._set_texture_options(
    mapping?,
    wrap_s?,
    wrap_t?,
    wrap_r?,
    mag_filter?,
    min_filter?,
    format?,
    type_?,
    anisotropy?,
    color_space?,
    flip_y?,
    generate_mipmaps?,
    mipmaps_auto_update?,
    internal_format?,
  )
  target.set_depth_texture(depth_texture)
  target
}

///|
/// Applies the texture options to all textures; constructors above core call this too.
pub fn RenderTarget::_set_texture_options(
  self : RenderTarget,
  mapping? : Int32,
  wrap_s? : Int32,
  wrap_t? : Int32,
  wrap_r? : Int32,
  mag_filter? : Int32,
  min_filter~ : Int32 = LinearFilter,
  format? : Int32,
  type_? : Int32,
  anisotropy? : Int32,
  color_space? : String,
  flip_y~ : Bool = false,
  generate_mipmaps~ : Bool = false,
  mipmaps_auto_update? : Bool,
  internal_format? : String,
) -> Unit {
  for texture in self.textures {
    texture.set_values(
      min_filter~,
      generate_mipmaps~,
      flip_y~,
      internal_format~,
      mapping?,
      wrap_s?,
      wrap_t?,
      wrap_r?,
      mag_filter?,
      format?,
      type_?,
      anisotropy?,
      color_space?,
      mipmaps_auto_update?,
    )
  }
}

///|
pub impl EventSource for RenderTarget with fn event_dispatcher(self) {
  self.dispatcher
}

///|
pub impl EventSource for RenderTarget with fn event_target(self) {
  RenderTarget(self)
}

///|
pub extend RenderTarget with EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
pub fn RenderTarget::texture(self : RenderTarget) -> Texture {
  self.textures[0]
}

///|
pub fn RenderTarget::set_texture(self : RenderTarget, value : Texture) -> Unit {
  if self.textures.is_empty() {
    self.textures.push(value)
  } else {
    self.textures[0] = value
  }
}

///|
pub fn RenderTarget::depth_texture(self : RenderTarget) -> Texture? {
  self._depth_texture
}

///|
pub fn RenderTarget::set_depth_texture(
  self : RenderTarget,
  current : Texture?,
) -> Unit {
  if self._depth_texture is Some(depth_texture) &&
    depth_texture.render_target is Some(target) &&
    physical_equal(target, self) {
    depth_texture.render_target = None
  }
  if current is Some(current) && current.render_target is None {
    current.render_target = Some(self)
  }
  self._depth_texture = current
}

///|
pub fn RenderTarget::set_size(
  self : RenderTarget,
  width : Int32,
  height : Int32,
  depth~ : Int32 = 1,
) -> Unit {
  if self.width != width || self.height != height || self.depth != depth {
    self.width = width
    self.height = height
    self.depth = depth
    for texture in self.textures {
      let image = texture.image()
      image.set_size(width, height, depth)
      if !(texture.texture_type is Data3DTexture) { // Fix for #31693
        texture.is_array_texture = image.depth() > 1.0
      }
    }
    self.dispose()
  }
  let w = width.to_double()
  let h = height.to_double()
  ignore(self.viewport.set(0.0, 0.0, w, h))
  ignore(self.scissor.set(0.0, 0.0, w, h))
}

///|
pub fn RenderTarget::clone(self : RenderTarget) -> RenderTarget {
  let target = match self.extension {
    Some(extension) => extension.construct()
    None =>
      match self.render_target_type {
        PlainRenderTarget => RenderTarget::new()
        RenderTarget3D => RenderTarget3D::new()
      }
  }
  target.copy(self)
}

///|
pub fn RenderTarget::copy(
  self : RenderTarget,
  source : RenderTarget,
) -> RenderTarget {
  self.width = source.width
  self.height = source.height
  self.depth = source.depth
  ignore(self.scissor.copy(source.scissor))
  self.scissor_test = source.scissor_test
  ignore(self.viewport.copy(source.viewport))
  self.textures.clear()
  for texture in source.textures {
    let clone = texture.clone()
    clone.is_render_target_texture = true
    clone.render_target = Some(self)
    // ensure image object is not shared, see #20328
    clone.source = TextureSource::new(data=texture.image().shallow_copy())
    self.textures.push(clone)
  }
  self.depth_buffer = source.depth_buffer
  self.stencil_buffer = source.stencil_buffer
  self.resolve_color_buffer = source.resolve_color_buffer
  self.resolve_depth_buffer = source.resolve_depth_buffer
  self.resolve_stencil_buffer = source.resolve_stencil_buffer
  self.store_multisampled_color_buffer = source.store_multisampled_color_buffer
  self.store_multisampled_depth_buffer = source.store_multisampled_depth_buffer
  self.store_multisampled_stencil_buffer = source.store_multisampled_stencil_buffer
  match source.depth_texture() {
    Some(source_depth_texture) =>
      if source_depth_texture.render_target is Some(target) &&
        physical_equal(target, source) {
        let depth_texture = source_depth_texture.clone()
        depth_texture.render_target = None
        self.set_depth_texture(Some(depth_texture))
      } else {
        self.set_depth_texture(Some(source_depth_texture))
      }
    None => self.set_depth_texture(None)
  }
  self.samples = source.samples
  self.multiview = source.multiview
  self.use_array_depth_texture = source.use_array_depth_texture
  if self.extension is Some(extension) {
    extension.copy_from(self, source)
  }
  self
}

///|
pub fn RenderTarget::dispose(self : RenderTarget) -> Unit {
  self.dispatch_event(Event::new("dispose"))
}
