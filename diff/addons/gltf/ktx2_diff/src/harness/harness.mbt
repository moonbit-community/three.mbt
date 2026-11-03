// MoonBit side of the KTX2 differential harness (run.mjs). Results are returned as JS
// objects in upstream's shapes (camelCase keys); run.mjs hashes typed arrays.

///|
using @core {type JsValue}

///|
extern "js" fn js_array(items : FixedArray[JsValue]) -> JsValue = "(a) => Array.from(a)"

///|
extern "js" fn js_array_items(a : JsValue) -> FixedArray[JsValue] = "(a) => Array.from(a)"

///|
fn arr(items : Array[JsValue]) -> JsValue {
  js_array(FixedArray::from_array(items[:]))
}

///|
fn int_arr(items : Array[Int]) -> JsValue {
  arr(items.map(x => JsValue::of(x)))
}

///|
fn opt_int(v : Int?) -> JsValue {
  match v {
    Some(x) => JsValue::of(x)
    None => JsValue::undefined()
  }
}

///|
fn obj(pairs : Array[(String, JsValue)]) -> JsValue {
  let o = JsValue::object()
  for p in pairs {
    o.set(p.0, p.1)
  }
  o
}

///|
fn describe_data_image(d : @core.DataImage) -> JsValue {
  obj([
    (
      "data",
      match d.data {
        Some(t) => JsValue::of(t)
        None => JsValue::undefined()
      },
    ),
    ("width", JsValue::of(d.width)),
    ("height", JsValue::of(d.height)),
    ("depth", opt_int(d.depth)),
    (
      "mipmaps",
      match d.mipmaps {
        Some(m) => arr(m.map(describe_data_image))
        None => JsValue::undefined()
      },
    ),
  ])
}

///|
fn describe_image(img : @core.TextureImage) -> JsValue {
  match img {
    NoImage => JsValue::null()
    DomImage(v) => v
    DataImage(d) => describe_data_image(d)
    TextureImage(_) => JsValue::of("<texture>")
    ImageArray(a) => arr(a.map(describe_image))
  }
}

///|
fn class_name(t : @core.Texture) -> String {
  match t.texture_type {
    CompressedTexture => "CompressedTexture"
    CompressedArrayTexture => "CompressedArrayTexture"
    CompressedCubeTexture => "CompressedCubeTexture"
    DataTexture => "DataTexture"
    Data3DTexture => "Data3DTexture"
    Texture => "Texture"
    _ => "other"
  }
}

///|
fn describe_texture(t : @core.Texture) -> JsValue {
  obj([
    ("cls", JsValue::of(class_name(t))),
    ("isCompressedTexture", JsValue::of(t.is_compressed_texture())),
    ("isCubeTexture", JsValue::of(t.is_cube_texture())),
    ("image", describe_image(t.image())),
    ("mipmaps", arr(t.mipmaps.map(describe_image))),
    ("format", JsValue::of(t.format)),
    ("type", JsValue::of(t.type_)),
    ("colorSpace", JsValue::of(t.color_space)),
    ("premultiplyAlpha", JsValue::of(t.premultiply_alpha)),
    ("generateMipmaps", JsValue::of(t.generate_mipmaps)),
    ("minFilter", JsValue::of(t.min_filter)),
    ("magFilter", JsValue::of(t.mag_filter)),
    ("wrapS", JsValue::of(t.wrap_s)),
    ("wrapT", JsValue::of(t.wrap_t)),
    (
      "wrapR",
      match t.texture_type {
        Data3DTexture | CompressedArrayTexture | DataArrayTexture =>
          JsValue::of(t.wrap_r)
        _ => JsValue::of("n/a")
      },
    ),
    ("mapping", JsValue::of(t.mapping)),
    ("flipY", JsValue::of(t.flip_y)),
    ("unpackAlignment", JsValue::of(t.unpack_alignment)),
    ("anisotropy", JsValue::of(t.anisotropy)),
    ("normalized", JsValue::of(t.normalized)),
    ("version", JsValue::of(t.version)),
    ("sourceVersion", JsValue::of(t.source.version)),
    ("userData", t.user_data),
    (
      "layerUpdates",
      match t.layer_updates {
        Some(l) => int_arr(l)
        None => JsValue::undefined()
      },
    ),
  ])
}

///|
fn config_of(config : JsValue) -> @addon_loaders.KTX2WorkerConfig? {
  if config.is_null() || config.is_undefined() {
    None
  } else {
    Some({
      astc_supported: config.get("astcSupported").cast(),
      astc_hdr_supported: config.get("astcHDRSupported").cast(),
      etc1_supported: config.get("etc1Supported").cast(),
      etc2_supported: config.get("etc2Supported").cast(),
      dxt_supported: config.get("dxtSupported").cast(),
      bptc_supported: config.get("bptcSupported").cast(),
      pvrtc_supported: config.get("pvrtcSupported").cast(),
    })
  }
}

///|
pub fn ktx2_new_loader(
  config : JsValue,
  transcoder_path : String,
) -> @addon_loaders.KTX2Loader {
  let loader = @addon_loaders.KTX2Loader::new()
  if transcoder_path != "" {
    ignore(loader.set_transcoder_path(transcoder_path))
  }
  loader.worker_config = config_of(config)
  loader
}

///|
pub fn ktx2_set_config(
  loader : @addon_loaders.KTX2Loader,
  config : JsValue,
) -> Unit {
  loader.worker_config = config_of(config)
}

///|
fn texture_callback(
  on_load : (JsValue, JsValue) -> Unit,
) -> (@core.Texture) -> Unit {
  fn(t) { on_load(describe_texture(t), JsValue::of(t)) }
}

///|
pub fn ktx2_load(
  loader : @addon_loaders.KTX2Loader,
  url : String,
  on_load : (JsValue, JsValue) -> Unit,
  on_error : (JsValue) -> Unit,
) -> Unit {
  loader.load(url, texture_callback(on_load), on_error~)
}

///|
pub fn ktx2_parse(
  loader : @addon_loaders.KTX2Loader,
  buffer : JsValue,
  on_load : (JsValue, JsValue) -> Unit,
  on_error : (JsValue) -> Unit,
) -> Unit {
  loader.parse(buffer, Some(texture_callback(on_load)), Some(on_error))
}

///|
pub fn ktx2_set_worker_limit(loader : @addon_loaders.KTX2Loader, n : Int) -> Bool {
  physical_equal(loader.set_worker_limit(n), loader)
}

///|
pub fn ktx2_init(loader : @addon_loaders.KTX2Loader) -> JsValue {
  loader.init().to_js()
}

///|
pub fn ktx2_dispose(loader : @addon_loaders.KTX2Loader) -> Unit {
  ignore(loader.dispose())
}

///|
pub fn ktx2_loader_state(loader : @addon_loaders.KTX2Loader) -> JsValue {
  obj([
    ("transcoderPath", JsValue::of(loader.transcoder_path)),
    ("workerSourceURL", JsValue::of(loader.worker_source_url != "")),
    ("transcoderPending", JsValue::of(loader.transcoder_pending is Some(_))),
    ("transcoderBinary", loader.transcoder_binary),
    (
      "workerConfig",
      match loader.worker_config {
        Some(c) => c.to_js()
        None => JsValue::null()
      },
    ),
    ("pool", worker_pool_state(loader.worker_pool)),
  ])
}

///|
pub fn ktx_read(bytes : @core.TypedArray) -> JsValue {
  let c = @libs.read(bytes)
  let key_value = JsValue::object()
  for k, v in c.key_value {
    key_value.set(k, match v {
      Bytes(b) => JsValue::of(b)
      Text(s) => JsValue::of(s)
    })
  }
  obj([
    ("vkFormat", JsValue::of(c.vk_format)),
    ("typeSize", JsValue::of(c.type_size)),
    ("pixelWidth", JsValue::of(c.pixel_width)),
    ("pixelHeight", JsValue::of(c.pixel_height)),
    ("pixelDepth", JsValue::of(c.pixel_depth)),
    ("layerCount", JsValue::of(c.layer_count)),
    ("faceCount", JsValue::of(c.face_count)),
    ("levelCount", JsValue::of(c.level_count)),
    ("supercompressionScheme", JsValue::of(c.supercompression_scheme)),
    (
      "levels",
      arr(
        c.levels.map(l => obj([
          ("levelData", JsValue::of(l.level_data)),
          ("uncompressedByteLength", JsValue::of(l.uncompressed_byte_length)),
        ])),
      ),
    ),
    (
      "dataFormatDescriptor",
      arr(
        c.data_format_descriptor.map(d => obj([
          ("vendorId", JsValue::of(d.vendor_id)),
          ("descriptorType", JsValue::of(d.descriptor_type)),
          ("versionNumber", JsValue::of(d.version_number)),
          ("colorModel", JsValue::of(d.color_model)),
          ("colorPrimaries", JsValue::of(d.color_primaries)),
          ("transferFunction", JsValue::of(d.transfer_function)),
          ("flags", JsValue::of(d.flags)),
          ("texelBlockDimension", int_arr(d.texel_block_dimension)),
          ("bytesPlane", int_arr(d.bytes_plane)),
          (
            "samples",
            arr(
              d.samples.map(s => obj([
                ("bitOffset", JsValue::of(s.bit_offset)),
                ("bitLength", JsValue::of(s.bit_length)),
                ("channelType", JsValue::of(s.channel_type)),
                ("samplePosition", int_arr(s.sample_position)),
                ("sampleLower", JsValue::of(s.sample_lower)),
                ("sampleUpper", JsValue::of(s.sample_upper)),
              ])),
            ),
          ),
        ])),
      ),
    ),
    ("keyValue", key_value),
    (
      "globalData",
      match c.global_data {
        None => JsValue::null()
        Some(g) =>
          obj([
            ("endpointCount", JsValue::of(g.endpoint_count)),
            ("selectorCount", JsValue::of(g.selector_count)),
            (
              "imageDescs",
              arr(
                g.image_descs.map(d => obj([
                  ("imageFlags", JsValue::of(d.image_flags)),
                  ("rgbSliceByteOffset", JsValue::of(d.rgb_slice_byte_offset)),
                  ("rgbSliceByteLength", JsValue::of(d.rgb_slice_byte_length)),
                  (
                    "alphaSliceByteOffset",
                    JsValue::of(d.alpha_slice_byte_offset),
                  ),
                  (
                    "alphaSliceByteLength",
                    JsValue::of(d.alpha_slice_byte_length),
                  ),
                ])),
              ),
            ),
            ("endpointsData", JsValue::of(g.endpoints_data)),
            ("selectorsData", JsValue::of(g.selectors_data)),
            ("tablesData", JsValue::of(g.tables_data)),
            ("extendedData", JsValue::of(g.extended_data)),
          ])
      },
    ),
  ])
}

///|
fn describe_space(s : @math.ColorSpaceDefinition) -> JsValue {
  obj([
    ("primaries", arr(s.primaries.map(x => JsValue::of(x)))),
    ("whitePoint", arr(s.white_point.map(x => JsValue::of(x)))),
    ("transfer", JsValue::of(s.transfer)),
    ("toXYZ", arr(s.to_xyz.elements.map(x => JsValue::of(x)))),
    ("fromXYZ", arr(s.from_xyz.elements.map(x => JsValue::of(x)))),
    (
      "luminanceCoefficients",
      arr(s.luminance_coefficients.map(x => JsValue::of(x))),
    ),
    (
      "workingColorSpaceConfig",
      match s.working_color_space_config {
        Some(c) =>
          obj([("unpackColorSpace", JsValue::of(c.unpack_color_space))])
        None => JsValue::undefined()
      },
    ),
    (
      "outputColorSpaceConfig",
      match s.output_color_space_config {
        Some(c) =>
          obj([
            ("drawingBufferColorSpace", JsValue::of(c.drawing_buffer_color_space)),
            (
              "toneMappingMode",
              match c.tone_mapping_mode {
                Some(m) => JsValue::of(m)
                None => JsValue::undefined()
              },
            ),
          ])
        None => JsValue::undefined()
      },
    ),
  ])
}

///|
pub fn color_spaces_dump() -> JsValue {
  let names = obj([
    ("DisplayP3ColorSpace", JsValue::of(@addon_math.DisplayP3ColorSpace)),
    (
      "LinearDisplayP3ColorSpace",
      JsValue::of(@addon_math.LinearDisplayP3ColorSpace),
    ),
    ("LinearRec2020ColorSpace", JsValue::of(@addon_math.LinearRec2020ColorSpace)),
    ("ExtendedSRGBColorSpace", JsValue::of(@addon_math.ExtendedSRGBColorSpace)),
  ])
  let impls = obj([
    (
      "DisplayP3ColorSpaceImpl",
      describe_space(@addon_math.display_p3_color_space_impl),
    ),
    (
      "LinearDisplayP3ColorSpaceImpl",
      describe_space(@addon_math.linear_display_p3_color_space_impl),
    ),
    (
      "LinearRec2020ColorSpaceImpl",
      describe_space(@addon_math.linear_rec2020_color_space_impl),
    ),
    (
      "ExtendedSRGBColorSpaceImpl",
      describe_space(@addon_math.extended_srgb_color_space_impl),
    ),
  ])
  // shared arrays, as upstream (ColorManagement.convert compares primaries by reference)
  let sharing = obj([
    (
      "p3PrimariesShared",
      JsValue::of(
        physical_equal(
          @addon_math.display_p3_color_space_impl.primaries,
          @addon_math.linear_display_p3_color_space_impl.primaries,
        ),
      ),
    ),
    (
      "p3MatrixShared",
      JsValue::of(
        physical_equal(
          @addon_math.display_p3_color_space_impl.to_xyz,
          @addon_math.linear_display_p3_color_space_impl.to_xyz,
        ),
      ),
    ),
    (
      "extendedSharesSRGB",
      JsValue::of(
        physical_equal(
          @addon_math.extended_srgb_color_space_impl.primaries,
          @math.color_management.spaces.get(@math.SRGBColorSpace).unwrap().primaries,
        ),
      ),
    ),
  ])
  @math.color_management.define(
    Map::from_array([
      (@addon_math.DisplayP3ColorSpace, @addon_math.display_p3_color_space_impl),
      (
        @addon_math.LinearDisplayP3ColorSpace,
        @addon_math.linear_display_p3_color_space_impl,
      ),
      (
        @addon_math.LinearRec2020ColorSpace,
        @addon_math.linear_rec2020_color_space_impl,
      ),
      (
        @addon_math.ExtendedSRGBColorSpace,
        @addon_math.extended_srgb_color_space_impl,
      ),
    ]),
  )
  let spaces = [
    @math.SRGBColorSpace,
    @math.LinearSRGBColorSpace,
    @addon_math.DisplayP3ColorSpace,
    @addon_math.LinearDisplayP3ColorSpace,
    @addon_math.LinearRec2020ColorSpace,
    @addon_math.ExtendedSRGBColorSpace,
  ]
  let inputs = [
    (0.3, 0.5, 0.7),
    (1.0, 0.5, 0.01),
    (0.0, 0.0, 0.0),
    (1.0, 1.0, 1.0),
    (-0.2, 1.3, 0.04),
  ]
  let conversions = []
  for src in spaces {
    for dst in spaces {
      for i in inputs {
        let c = @math.Color::new(i.0, i.1, i.2)
        ignore(@math.color_management.convert(c, src, dst))
        conversions.push(
          arr([
            JsValue::of(src),
            JsValue::of(dst),
            JsValue::of(c.r),
            JsValue::of(c.g),
            JsValue::of(c.b),
          ]),
        )
      }
    }
  }
  let misc = []
  for s in spaces {
    let c = @math.Color::new(0.0, 0.0, 0.0).set_rgb(1.0, 0.5, 0.01, color_space=s)
    let space = @math.color_management.spaces.get(s).unwrap()
    let has_output = space.output_color_space_config is Some(_)
    let has_working = space.working_color_space_config is Some(_)
    misc.push(
      arr([
        JsValue::of(s),
        JsValue::of(c.r),
        JsValue::of(c.g),
        JsValue::of(c.b),
        JsValue::of(c.get_style(color_space=s)),
        JsValue::of(@math.color_management.get_transfer(s)),
        JsValue::of(if has_output { @math.color_management.get_tone_mapping_mode(s) } else { "-" }),
        JsValue::of(if has_output { @math.color_management._get_drawing_buffer_color_space(s) } else { "-" }),
        JsValue::of(if has_working { @math.color_management._get_unpack_color_space(color_space=s) } else { "-" }),
      ]),
    )
  }
  obj([
    ("names", names),
    ("impls", impls),
    ("sharing", sharing),
    ("conversions", arr(conversions)),
    ("misc", arr(misc)),
  ])
}

///|
pub fn worker_pool_new(url : String, limit : Int) -> @utils.WorkerPool {
  let pool = @utils.WorkerPool::new()
  if limit > 0 {
    pool.set_worker_limit(limit)
  }
  pool.set_worker_creator(fn() { @utils.Worker::new(url) })
  pool
}

///|
pub fn worker_pool_set_limit(pool : @utils.WorkerPool, limit : Int) -> Unit {
  pool.set_worker_limit(limit)
}

///|
pub fn worker_pool_post(
  pool : @utils.WorkerPool,
  msg : JsValue,
  transfer : JsValue,
) -> JsValue {
  let transfer = Array::from_fixed_array(js_array_items(transfer))
  pool.post_message(msg, transfer).to_js()
}

///|
pub fn worker_pool_state(pool : @utils.WorkerPool) -> JsValue {
  obj([
    ("pool", JsValue::of(pool.pool)),
    ("workerStatus", JsValue::of(pool.worker_status)),
    ("queue", JsValue::of(pool.queue.length())),
    ("workers", JsValue::of(pool.workers.length())),
    (
      "workersDefined",
      JsValue::of(pool.workers.filter(w => w is Some(_)).length()),
    ),
    ("workersResolve", JsValue::of(pool.workers_resolve.length())),
  ])
}

///|
pub fn worker_pool_dispose(pool : @utils.WorkerPool) -> Unit {
  pool.dispose()
}

///|
pub fn ktx2_basis_worker_source() -> String {
  @addon_loaders.ktx2_loader_basis_worker
}

///|
extern "js" fn json_stringify(v : JsValue) -> String = "(v) => JSON.stringify(v)"

///|
pub fn ktx2_tables_json() -> JsValue {
  let tables = [
    @addon_loaders.ktx2_loader_basis_format,
    @addon_loaders.ktx2_loader_transcoder_format,
    @addon_loaders.ktx2_loader_engine_format,
    @addon_loaders.ktx2_loader_engine_type,
  ]
  arr(
    tables.map(t => {
      let o = JsValue::object()
      for k, v in t {
        o.set(k, JsValue::of(v))
      }
      JsValue::of(json_stringify(o))
    }),
  )
}

///|
pub fn ktx2_detect_support_webgl(gl : JsValue, canvas : JsValue) -> JsValue {
  let renderer = @webgl.WebGLRenderer::new(canvas=canvas.cast(), context=gl.cast())
  gl.get("__log").set("length", JsValue::of(0))
  let loader = @addon_loaders.KTX2Loader::new()
  let same = physical_equal(loader.detect_support(renderer), loader)
  obj([
    ("chained", JsValue::of(same)),
    ("config", loader.worker_config.unwrap().to_js()),
  ])
}
