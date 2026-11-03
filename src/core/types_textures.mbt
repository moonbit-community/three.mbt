// Types for upstream src/textures. `Texture` is one flat struct, like `Material`.

///|
/// The class of a `Texture`, for `isDataTexture`-style checks. `Texture` also covers
/// subclasses above core, which add an `extension`.
pub(all) enum TextureType {
  Texture
  CanvasTexture
  CompressedArrayTexture
  CompressedCubeTexture
  CompressedTexture
  CubeDepthTexture
  CubeTexture
  Data3DTexture
  DataArrayTexture
  DataTexture
  DepthTexture
  ExternalTexture
  FramebufferTexture
  HTMLTexture
  VideoFrameTexture
  VideoTexture
}

///|
/// The `{ data, width, height, depth }` images of data, render target and compressed
/// textures. `mipmaps` is set on the per-face images of compressed cube textures.
pub(all) struct DataImage {
  mut data : TypedArray?
  mut width : Int32
  mut height : Int32
  mut depth : Int32?
  mut mipmaps : Array[DataImage]?
}

///|
/// What `source.data` and `texture.image` can hold.
pub(all) enum TextureImage {
  /// `null`.
  NoImage
  /// `HTMLImageElement`, `HTMLCanvasElement`, `ImageBitmap`, video and other DOM values.
  DomImage(JsValue)
  DataImage(DataImage)
  /// The `DataTexture` entries of a cube texture's image array.
  TextureImage(Texture)
  /// Cube textures: one entry per face.
  ImageArray(Array[TextureImage])
}

///|
pub(all) struct TextureSource {
  id : Int32
  mut uuid : String
  mut data : TextureImage
  mut data_ready : Bool
  mut version : Int32
}

///|
/// Upstream `Texture` and all of src/textures; see `texture_type`.
pub(all) struct Texture {
  id : Int32
  dispatcher : EventDispatcher
  mut uuid : String
  mut name : String
  mut source : TextureSource
  mut mipmaps : Array[TextureImage]
  mut mapping : Int32
  mut channel : Int32
  mut wrap_s : Int32
  mut wrap_t : Int32
  mut mag_filter : Int32
  mut min_filter : Int32
  mut anisotropy : Int32
  mut format : Int32
  /// A GL internal format name such as `"RGBA8"`.
  mut internal_format : String?
  mut type_ : Int32
  mut offset : @math.Vector2
  mut repeat : @math.Vector2
  mut center : @math.Vector2
  mut rotation : Double
  mut matrix_auto_update : Bool
  mut matrix : @math.Matrix3
  mut generate_mipmaps : Bool
  mut mipmaps_auto_update : Bool
  mut premultiply_alpha : Bool
  mut flip_y : Bool
  mut unpack_alignment : Int32
  mut color_space : String
  mut user_data : JsValue
  mut update_ranges : Array[UpdateRange]
  mut version : Int32
  mut on_update : ((Texture) -> Unit)?
  mut render_target : RenderTarget?
  mut is_render_target_texture : Bool
  mut is_array_texture : Bool
  mut pmrem_version : Int32
  mut is_pmrem_texture : Bool
  mut normalized : Bool
  // DepthTexture
  mut compare_function : Int32?
  // Data3DTexture, DataArrayTexture, CompressedArrayTexture
  mut wrap_r : Int32
  mut layer_updates : Array[Int32]?
  // ExternalTexture: a `Texture`, or a GPU handle in `external_source`.
  mut source_texture : Texture?
  mut external_source : JsValue?
  // VideoTexture
  mut _request_video_frame_callback_id : Int32
  mut texture_type : TextureType
  mut extension : &TextureExtension?
}
