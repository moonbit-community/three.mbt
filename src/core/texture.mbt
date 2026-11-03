// Upstream src/textures/Texture.js. Overrides of the subclasses in src/textures are
// arms of the `texture_type` matches in `clone`, `copy`, `to_json` and `dispose`.

///|
let _texture_id : Ref[Int32] = Ref(0)

///|
let _texture_temp_vec3 : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
/// `Texture.DEFAULT_IMAGE`.
pub let texture_default_image : Ref[TextureImage] = Ref(NoImage)

///|
/// `Texture.DEFAULT_MAPPING`.
pub let texture_default_mapping : Ref[Int32] = Ref(UVMapping)

///|
/// `Texture.DEFAULT_ANISOTROPY`.
pub let texture_default_anisotropy : Ref[Int32] = Ref(1)

///|
extern "js" fn texture_math_floor(a : Double) -> Double = "Math.floor"

///|
extern "js" fn texture_math_ceil(a : Double) -> Double = "Math.ceil"

///|
extern "js" fn texture_math_abs(a : Double) -> Double = "Math.abs"

///|
pub fn Texture::new(
  image~ : TextureImage = texture_default_image.val,
  mapping~ : Int32 = texture_default_mapping.val,
  wrap_s~ : Int32 = ClampToEdgeWrapping,
  wrap_t~ : Int32 = ClampToEdgeWrapping,
  mag_filter~ : Int32 = LinearFilter,
  min_filter~ : Int32 = LinearMipmapLinearFilter,
  format~ : Int32 = RGBAFormat,
  type_~ : Int32 = UnsignedByteType,
  anisotropy~ : Int32 = texture_default_anisotropy.val,
  color_space~ : String = NoColorSpace,
) -> Texture {
  let id = _texture_id.val
  _texture_id.val = id + 1
  {
    id,
    dispatcher: EventDispatcher::new(),
    uuid: @math.generate_uuid(),
    name: "",
    source: TextureSource::new(data=image),
    mipmaps: [],
    mapping,
    channel: 0,
    wrap_s,
    wrap_t,
    mag_filter,
    min_filter,
    anisotropy,
    format,
    internal_format: None,
    type_,
    offset: @math.Vector2::new(0.0, 0.0),
    repeat: @math.Vector2::new(1.0, 1.0),
    center: @math.Vector2::new(0.0, 0.0),
    rotation: 0.0,
    matrix_auto_update: true,
    matrix: @math.Matrix3::new(),
    generate_mipmaps: true,
    mipmaps_auto_update: true,
    premultiply_alpha: false,
    flip_y: true,
    unpack_alignment: 4, // valid values: 1, 2, 4, 8 (see http://www.khronos.org/opengles/sdk/docs/man/xhtml/glPixelStorei.xml)
    color_space,
    user_data: JsValue::object(),
    update_ranges: [],
    version: 0,
    on_update: None,
    render_target: None,
    is_render_target_texture: false,
    is_array_texture: !(image is NoImage) && image.depth() > 1.0,
    pmrem_version: 0,
    is_pmrem_texture: false,
    normalized: false,
    compare_function: None,
    wrap_r: ClampToEdgeWrapping,
    layer_updates: None,
    source_texture: None,
    external_source: None,
    _request_video_frame_callback_id: 0,
    texture_type: Texture,
    extension: None,
  }
}

///|
pub impl EventSource for Texture with fn event_dispatcher(self) {
  self.dispatcher
}

///|
pub impl EventSource for Texture with fn event_target(self) {
  Texture(self)
}

///|
pub extend Texture with EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
/// `Double` because DOM images can report any number.
pub fn Texture::width(self : Texture) -> Double {
  self.source.get_size(_texture_temp_vec3).x
}

///|
pub fn Texture::height(self : Texture) -> Double {
  self.source.get_size(_texture_temp_vec3).y
}

///|
pub fn Texture::depth(self : Texture) -> Double {
  self.source.get_size(_texture_temp_vec3).z
}

///|
pub fn Texture::image(self : Texture) -> TextureImage {
  self.source.data
}

///|
pub fn Texture::set_image(self : Texture, value : TextureImage) -> Unit {
  self.source.data = value
}

///|
pub fn Texture::update_matrix(self : Texture) -> Unit {
  ignore(
    self.matrix.set_uv_transform(
      self.offset.x,
      self.offset.y,
      self.repeat.x,
      self.repeat.y,
      self.rotation,
      self.center.x,
      self.center.y,
    ),
  )
}

///|
pub fn Texture::add_update_range(
  self : Texture,
  start : Int32,
  count : Int32,
) -> Unit {
  self.update_ranges.push({ start, count, })
}

///|
pub fn Texture::clear_update_ranges(self : Texture) -> Unit {
  self.update_ranges.clear()
}

///|
/// `new this.constructor().copy( this )`; `VideoTexture` passes its image along.
pub fn Texture::clone(self : Texture) -> Texture {
  let texture = match self.extension {
    Some(extension) => extension.construct()
    None =>
      match self.texture_type {
        Texture => Texture::new()
        CanvasTexture => CanvasTexture::new()
        CompressedArrayTexture => CompressedArrayTexture::new()
        // Upstream's constructor reads `images[ 0 ]` of undefined and throws.
        CompressedCubeTexture =>
          abort("CompressedCubeTexture::clone: constructor requires images")
        CompressedTexture => CompressedTexture::new()
        CubeDepthTexture => CubeDepthTexture::new()
        CubeTexture => CubeTexture::new()
        Data3DTexture => Data3DTexture::new()
        DataArrayTexture => DataArrayTexture::new()
        DataTexture => DataTexture::new()
        DepthTexture => DepthTexture::new()
        ExternalTexture => ExternalTexture::new()
        FramebufferTexture => FramebufferTexture::new()
        HTMLTexture => HTMLTexture::new()
        VideoFrameTexture => VideoFrameTexture::new()
        VideoTexture => video_texture_construct(self.image())
      }
  }
  texture.copy(self)
}

///|
pub fn Texture::copy(self : Texture, source : Texture) -> Texture {
  self.name = source.name
  self.source = source.source
  self.mipmaps = source.mipmaps.copy()
  self.mapping = source.mapping
  self.channel = source.channel
  self.wrap_s = source.wrap_s
  self.wrap_t = source.wrap_t
  self.mag_filter = source.mag_filter
  self.min_filter = source.min_filter
  self.anisotropy = source.anisotropy
  self.format = source.format
  self.internal_format = source.internal_format
  self.type_ = source.type_
  self.normalized = source.normalized
  ignore(self.offset.copy(source.offset))
  ignore(self.repeat.copy(source.repeat))
  ignore(self.center.copy(source.center))
  self.rotation = source.rotation
  self.matrix_auto_update = source.matrix_auto_update
  ignore(self.matrix.copy(source.matrix))
  self.generate_mipmaps = source.generate_mipmaps
  self.mipmaps_auto_update = source.mipmaps_auto_update
  self.premultiply_alpha = source.premultiply_alpha
  self.flip_y = source.flip_y
  self.unpack_alignment = source.unpack_alignment
  self.color_space = source.color_space
  self.render_target = source.render_target
  self.is_render_target_texture = source.is_render_target_texture
  self.is_pmrem_texture = source.is_pmrem_texture
  self.is_array_texture = source.is_array_texture
  self.user_data = source.user_data.json_clone()
  self.set_needs_update(true)
  match self.texture_type {
    CompressedArrayTexture | Data3DTexture | DataArrayTexture =>
      self.wrap_r = source.wrap_r
    CubeDepthTexture | DepthTexture => {
      // see #30540
      self.source = TextureSource::new(data=source.image().shallow_copy())
      self.compare_function = source.compare_function
    }
    ExternalTexture => {
      self.source_texture = source.source_texture
      self.external_source = source.external_source
    }
    FramebufferTexture =>
      self.source = TextureSource::new(data=source.image().shallow_copy())
    _ => ()
  }
  if self.extension is Some(extension) {
    extension.copy_from(self, source)
  }
  self
}

///|
/// Upstream's `setValues( values )`, with one labelled argument per key. Keys the class
/// has no property for warn and are skipped, as upstream; other unknown keys do not
/// compile. `Vector2` and `Matrix3` values are copied into the current object.
pub fn Texture::set_values(
  self : Texture,
  uuid? : String,
  name? : String,
  source? : TextureSource,
  image? : TextureImage,
  mipmaps? : Array[TextureImage],
  mapping? : Int32,
  channel? : Int32,
  wrap_s? : Int32,
  wrap_t? : Int32,
  wrap_r? : Int32,
  mag_filter? : Int32,
  min_filter? : Int32,
  anisotropy? : Int32,
  format? : Int32,
  internal_format? : String?,
  type_? : Int32,
  offset? : @math.Vector2,
  repeat? : @math.Vector2,
  center? : @math.Vector2,
  rotation? : Double,
  matrix_auto_update? : Bool,
  matrix? : @math.Matrix3,
  generate_mipmaps? : Bool,
  mipmaps_auto_update? : Bool,
  premultiply_alpha? : Bool,
  flip_y? : Bool,
  unpack_alignment? : Int32,
  color_space? : String,
  user_data? : JsValue,
  update_ranges? : Array[UpdateRange],
  version? : Int32,
  on_update? : ((Texture) -> Unit)?,
  render_target? : RenderTarget?,
  is_render_target_texture? : Bool,
  is_array_texture? : Bool,
  pmrem_version? : Int32,
  is_pmrem_texture? : Bool,
  normalized? : Bool,
  compare_function? : Int32?,
  layer_updates? : Array[Int32]?,
  source_texture? : Texture?,
) -> Unit {
  if uuid is Some(value) {
    self.uuid = value
  }
  if name is Some(value) {
    self.name = value
  }
  if source is Some(value) {
    self.source = value
  }
  if image is Some(value) {
    self.set_image(value)
  }
  if mipmaps is Some(value) {
    self.mipmaps = value
  }
  if mapping is Some(value) {
    self.mapping = value
  }
  if channel is Some(value) {
    self.channel = value
  }
  if wrap_s is Some(value) {
    self.wrap_s = value
  }
  if wrap_t is Some(value) {
    self.wrap_t = value
  }
  if wrap_r is Some(value) {
    if self.texture_type
      is (CompressedArrayTexture | Data3DTexture | DataArrayTexture) {
      self.wrap_r = value
    } else {
      warn("Texture.setValues(): property 'wrapR' does not exist.")
    }
  }
  if mag_filter is Some(value) {
    self.mag_filter = value
  }
  if min_filter is Some(value) {
    self.min_filter = value
  }
  if anisotropy is Some(value) {
    self.anisotropy = value
  }
  if format is Some(value) {
    self.format = value
  }
  if internal_format is Some(value) {
    self.internal_format = value
  }
  if type_ is Some(value) {
    self.type_ = value
  }
  if offset is Some(value) {
    ignore(self.offset.copy(value))
  }
  if repeat is Some(value) {
    ignore(self.repeat.copy(value))
  }
  if center is Some(value) {
    ignore(self.center.copy(value))
  }
  if rotation is Some(value) {
    self.rotation = value
  }
  if matrix_auto_update is Some(value) {
    self.matrix_auto_update = value
  }
  if matrix is Some(value) {
    ignore(self.matrix.copy(value))
  }
  if generate_mipmaps is Some(value) {
    self.generate_mipmaps = value
  }
  if mipmaps_auto_update is Some(value) {
    self.mipmaps_auto_update = value
  }
  if premultiply_alpha is Some(value) {
    self.premultiply_alpha = value
  }
  if flip_y is Some(value) {
    self.flip_y = value
  }
  if unpack_alignment is Some(value) {
    self.unpack_alignment = value
  }
  if color_space is Some(value) {
    self.color_space = value
  }
  if user_data is Some(value) {
    self.user_data = value
  }
  if update_ranges is Some(value) {
    self.update_ranges = value
  }
  if version is Some(value) {
    self.version = value
  }
  if on_update is Some(value) {
    self.on_update = value
  }
  if render_target is Some(value) {
    self.render_target = value
  }
  if is_render_target_texture is Some(value) {
    self.is_render_target_texture = value
  }
  if is_array_texture is Some(value) {
    self.is_array_texture = value
  }
  if pmrem_version is Some(value) {
    self.pmrem_version = value
  }
  if is_pmrem_texture is Some(value) {
    self.is_pmrem_texture = value
  }
  if normalized is Some(value) {
    self.normalized = value
  }
  if compare_function is Some(value) {
    if self.texture_type is (CubeDepthTexture | DepthTexture) {
      self.compare_function = value
    } else {
      warn("Texture.setValues(): property 'compareFunction' does not exist.")
    }
  }
  if layer_updates is Some(value) {
    if self.layer_updates is Some(_) {
      self.layer_updates = value
    } else {
      warn("Texture.setValues(): property 'layerUpdates' does not exist.")
    }
  }
  if source_texture is Some(value) {
    if self.texture_type is ExternalTexture {
      self.source_texture = value
    } else {
      warn("Texture.setValues(): property 'sourceTexture' does not exist.")
    }
  }
}

///|
fn Texture::to_json_base(self : Texture, meta : ToJsonMeta?) -> Json {
  if meta is Some(meta) && meta.textures.get(self.uuid) is Some(texture) {
    return texture
  }
  ignore(self.source.to_json(meta?))
  let output : Map[String, Json] = {
    "metadata": Json::object({
      "version": Json::number(4.7),
      "type": Json::string("Texture"),
      "generator": Json::string("Texture.toJSON"),
    }),
    "uuid": Json::string(self.uuid),
    "name": Json::string(self.name),
    "image": Json::string(self.source.uuid),
    "mapping": json_int(self.mapping),
    "channel": json_int(self.channel),
    "repeat": json_numbers([self.repeat.x, self.repeat.y]),
    "offset": json_numbers([self.offset.x, self.offset.y]),
    "center": json_numbers([self.center.x, self.center.y]),
    "rotation": @math.json_number(self.rotation),
    "wrap": Json::array([json_int(self.wrap_s), json_int(self.wrap_t)]),
    "format": json_int(self.format),
    "internalFormat": match self.internal_format {
      Some(value) => Json::string(value)
      None => Json::null()
    },
    "type": json_int(self.type_),
    "normalized": Json::boolean(self.normalized),
    "colorSpace": Json::string(self.color_space),
    "minFilter": json_int(self.min_filter),
    "magFilter": json_int(self.mag_filter),
    "anisotropy": json_int(self.anisotropy),
    "flipY": Json::boolean(self.flip_y),
    "generateMipmaps": Json::boolean(self.generate_mipmaps),
    "mipmapsAutoUpdate": Json::boolean(self.mipmaps_auto_update),
    "premultiplyAlpha": Json::boolean(self.premultiply_alpha),
    "unpackAlignment": json_int(self.unpack_alignment),
  }
  if self.user_data.key_count() > 0 {
    output["userData"] = self.user_data.to_json()
  }
  let json = Json::object(output)
  if meta is Some(meta) {
    meta.textures[self.uuid] = json
  }
  json
}

///|
pub fn Texture::to_json(self : Texture, meta? : ToJsonMeta) -> Json {
  let json = self.to_json_base(meta)
  // Upstream's overrides write to the object `meta` holds, cached or not.
  guard json is Object(data) else { return json }
  if self.texture_type is (CubeDepthTexture | DepthTexture) {
    data["compareFunction"] = match self.compare_function {
      Some(value) => json_int(value)
      None => Json::null()
    }
  }
  if self.extension is Some(extension) {
    extension.to_json(self, meta, data)
  }
  json
}

///|
pub fn Texture::dispose(self : Texture) -> Unit {
  match self.texture_type {
    HTMLTexture => html_texture_dispose(self)
    VideoFrameTexture | VideoTexture => video_texture_dispose(self)
    _ => ()
  }
  self.dispatch_event(Event::new("dispose"))
}

///|
fn texture_wrap_coordinate(value : Double, wrap : Int32) -> Double {
  match wrap {
    RepeatWrapping => value - texture_math_floor(value)
    ClampToEdgeWrapping => if value < 0.0 { 0.0 } else { 1.0 }
    MirroredRepeatWrapping =>
      if texture_math_abs(texture_math_floor(value) % 2.0) == 1.0 {
        texture_math_ceil(value) - value
      } else {
        value - texture_math_floor(value)
      }
    _ => value
  }
}

///|
pub fn Texture::transform_uv(
  self : Texture,
  uv : @math.Vector2,
) -> @math.Vector2 {
  if self.mapping != UVMapping {
    return uv
  }
  ignore(uv.apply_matrix3(self.matrix))
  if uv.x < 0.0 || uv.x > 1.0 {
    uv.x = texture_wrap_coordinate(uv.x, self.wrap_s)
  }
  if uv.y < 0.0 || uv.y > 1.0 {
    uv.y = texture_wrap_coordinate(uv.y, self.wrap_t)
  }
  if self.flip_y {
    uv.y = 1.0 - uv.y
  }
  uv
}

///|
/// Setter of upstream `needsUpdate`.
pub fn Texture::set_needs_update(self : Texture, value : Bool) -> Unit {
  if value {
    self.version += 1
    self.source.set_needs_update(true)
  }
}

///|
/// Setter of upstream `needsPMREMUpdate`.
pub fn Texture::set_needs_pmrem_update(self : Texture, value : Bool) -> Unit {
  if value {
    self.pmrem_version += 1
  }
}

///|
/// `texture.isCompressedTexture`, which subclasses inherit.
pub fn Texture::is_compressed_texture(self : Texture) -> Bool {
  self.texture_type
  is (CompressedArrayTexture | CompressedCubeTexture | CompressedTexture)
}

///|
/// `texture.isCubeTexture`, which `CompressedCubeTexture` and `CubeDepthTexture` also set.
pub fn Texture::is_cube_texture(self : Texture) -> Bool {
  self.texture_type is (CompressedCubeTexture | CubeDepthTexture | CubeTexture)
}

///|
/// `texture.isDepthTexture`, which `CubeDepthTexture` inherits.
pub fn Texture::is_depth_texture(self : Texture) -> Bool {
  self.texture_type is (CubeDepthTexture | DepthTexture)
}

///|
/// `texture.isVideoTexture`, which `VideoFrameTexture` inherits.
pub fn Texture::is_video_texture(self : Texture) -> Bool {
  self.texture_type is (VideoFrameTexture | VideoTexture)
}
