// Upstream examples/jsm/loaders/UltraHDRLoader.js. The JPEG container scan, the MPF and
// ISO 21496-1 parsing and the gain map math are ported; DOM work (`DOMParser`,
// `createImageBitmap`, a 2D canvas, the `Promise` chain) goes through JS bindings, so a
// failure inside the promise chain is an unhandled rejection, as upstream.

///|
/// A loader for the Ultra HDR Image Format (JPEG with a gain map).
pub(all) struct UltraHDRLoader {
  base : @loaders.Loader
  /// The texture type, `HalfFloatType` (default) or `FloatType`.
  mut type_ : Int32
}

///|
pub fn UltraHDRLoader::new(
  manager? : @loaders.LoadingManager,
) -> UltraHDRLoader {
  { base: @loaders.Loader::new(manager?), type_: @core.HalfFloatType, }
}

///|
pub impl @loaders.LoaderLike for UltraHDRLoader with fn loader(self) {
  self.base
}

///|
pub impl @loaders.LoaderSettings for UltraHDRLoader

///|
pub extend UltraHDRLoader with @loaders.LoaderLike::{loader}

///|
pub extend UltraHDRLoader with @loaders.LoaderSettings::{
  set_cross_origin,
  set_with_credentials,
  set_path,
  set_resource_path,
  set_request_header,
  set_priority,
  set_cache,
  abort,
}

///|
/// Sets the texture type.
pub fn UltraHDRLoader::set_data_type(
  self : UltraHDRLoader,
  value : Int32,
) -> UltraHDRLoader {
  self.type_ = value
  self
}

// --- JS bindings ------------------------------------------------------------------

///|
#external
priv type UhdrDataView

///|
extern "js" fn UhdrDataView::new(
  buffer : @core.ArrayBuffer,
  offset : Int32,
  length : Int32,
) -> UhdrDataView = "(b, o, l) => new DataView(b, o, l)"

///|
extern "js" fn UhdrDataView::get_uint32(
  self : UhdrDataView,
  offset : Int32,
  little_endian : Bool,
) -> Double = "(v, o, l) => v.getUint32(o, l)"

///|
extern "js" fn UhdrDataView::get_int32(
  self : UhdrDataView,
  offset : Int32,
  little_endian : Bool,
) -> Double = "(v, o, l) => v.getInt32(o, l)"

///|
extern "js" fn UhdrDataView::get_uint8(
  self : UhdrDataView,
  offset : Int32,
) -> Int32 = "(v, o) => v.getUint8(o)"

///|
/// `dataView.getUint32( offset )`: big-endian, as upstream omits the flag.
extern "js" fn UhdrDataView::get_uint32_default(
  self : UhdrDataView,
  offset : Int32,
) -> Double = "(v, o) => v.getUint32(o)"

///|
extern "js" fn uhdr_text_decode(bytes : @core.TypedArray) -> String = "(b) => new TextDecoder().decode(b)"

///|
/// `new Uint8Array( buffer, offset, length )`.
extern "js" fn uhdr_uint8_view(
  buffer : @core.JsValue,
  offset : Double,
  length : Double,
) -> @core.TypedArray = "(b, o, l) => new Uint8Array(b, o, l)"

///|
extern "js" fn uhdr_new_uint8(buffer : @core.JsValue) -> @core.TypedArray = "(b) => new Uint8Array(b)"

///|
extern "js" fn uhdr_throw_error(message : @core.JsValue) -> Unit = "(m) => { throw new Error(m); }"

///|
extern "js" fn uhdr_console_error(error : @core.JsValue) -> Unit = "(e) => console.error(e)"

///|
extern "js" fn uhdr_math_pow(x : Double, y : Double) -> Double = "Math.pow"

///|
extern "js" fn uhdr_math_log2(x : Double) -> Double = "Math.log2"

///|
extern "js" fn uhdr_math_min(x : Double, y : Double) -> Double = "Math.min"

///|
extern "js" fn uhdr_math_max(x : Double, y : Double) -> Double = "Math.max"

///|
/// `value | 0`.
extern "js" fn uhdr_to_int32(value : Double) -> Int32 = "(v) => v | 0"

///|
/// `xmpXml.getElementsByTagName( tag )[ 0 ]` of `DOMParser.parseFromString`, `undefined`
/// when there is none.
extern "js" fn uhdr_parse_xml(text : String) -> @core.JsValue = "(t) => new DOMParser().parseFromString(t.substring(t.indexOf('<'), t.lastIndexOf('>') + 1), 'text/xml')"

///|
extern "js" fn uhdr_first_element(
  doc : @core.JsValue,
  tag : String,
) -> @core.JsValue = "(d, t) => { const [ e ] = d.getElementsByTagName(t); return e; }"

///|
extern "js" fn uhdr_get_attribute(
  node : @core.JsValue,
  name : String,
) -> @core.JsValue = "(n, k) => n.getAttribute(k)"

///|
/// `parseFloat( value || fallback )`.
extern "js" fn uhdr_parse_float_or(
  value : @core.JsValue,
  fallback : Double,
) -> Double = "(v, d) => parseFloat(v || d)"

///|
/// `parseFloat( value / ( 1 / 64 ) )`.
extern "js" fn uhdr_parse_float_offset(value : @core.JsValue) -> Double = "(v) => parseFloat(v / (1 / 64))"

///|
/// A JS truthiness test.
extern "js" fn uhdr_truthy(value : @core.JsValue) -> Bool = "(v) => !!v"

///|
extern "js" fn uhdr_is_string_true(value : @core.JsValue) -> Bool = "(v) => v === 'True'"

///|
/// `Promise.all( [ decodeImage( a ), decodeImage( b ) ] ).then( f ).catch( g )`, with
/// `decodeImage = ( data ) => createImageBitmap( new Blob( [ data ], { type: 'image/jpeg' } ) )`.
extern "js" fn uhdr_decode_images(
  a : @core.TypedArray,
  b : @core.TypedArray,
  on_images : (@core.JsValue, @core.JsValue) -> Unit,
  on_catch : (@core.JsValue) -> Unit,
) -> Unit =
  #|(a, b, f, g) => {
  #|  const decodeImage = ( data ) => createImageBitmap( new Blob( [ data ], { type: 'image/jpeg' } ) );
  #|  Promise.all( [ decodeImage( a ), decodeImage( b ) ] )
  #|    .then( ( [ sdrImage, gainmapImage ] ) => { f( sdrImage, gainmapImage ); } )
  #|    .catch( ( e ) => { g( e ); } );
  #|}

///|
extern "js" fn uhdr_number(o : @core.JsValue, key : String) -> Double = "(o, k) => o[k]"

///|
/// `document.createElement( 'canvas' )` and its 2D context with upstream's options.
extern "js" fn uhdr_create_canvas() -> @core.JsValue = "() => document.createElement('canvas')"

///|
extern "js" fn uhdr_get_context(canvas : @core.JsValue) -> @core.JsValue = "(c) => c.getContext('2d', { willReadFrequently: true, colorSpace: 'srgb' })"

///|
extern "js" fn uhdr_set_size(
  canvas : @core.JsValue,
  w : Double,
  h : Double,
) -> Unit = "(c, w, h) => { c.width = w; c.height = h; }"

///|
extern "js" fn uhdr_draw_image_scaled(
  ctx : @core.JsValue,
  image : @core.JsValue,
  sw : Double,
  sh : Double,
  dw : Double,
  dh : Double,
) -> Unit = "(ctx, i, sw, sh, dw, dh) => ctx.drawImage(i, 0, 0, sw, sh, 0, 0, dw, dh)"

///|
extern "js" fn uhdr_draw_image(
  ctx : @core.JsValue,
  image : @core.JsValue,
) -> Unit = "(ctx, i) => ctx.drawImage(i, 0, 0)"

///|
/// `ctx.getImageData( 0, 0, w, h, { colorSpace: 'srgb' } ).data`.
extern "js" fn uhdr_get_image_data(
  ctx : @core.JsValue,
  w : Double,
  h : Double,
) -> @core.TypedArray = "(ctx, w, h) => ctx.getImageData(0, 0, w, h, { colorSpace: 'srgb' }).data"

///|
/// Pre-calculated sRGB to linear lookup table for values 0-1023.
let uhdr_srgb_to_linear : @core.TypedArray = {
  let table = @core.TypedArray::float64(1024)
  for i in 0..<1024 {
    // (1/255) * 0.9478672986 = 0.003717127
    table[i] = uhdr_math_pow(i.to_double() * 0.003717127 + 0.0521327014, 2.4)
  }
  table
}

///|
/// Gain map metadata; `None` is upstream's `null`.
priv struct UhdrMetadata {
  mut version : @core.JsValue
  mut base_rendition_is_hdr : Bool?
  mut gain_map_min : Double
  mut gain_map_max : Double
  mut gamma : Double
  mut offset_sdr : Double
  mut offset_hdr : Double
  mut hdr_capacity_min : Double
  mut hdr_capacity_max : Double
}

///|
priv struct UhdrSection {
  section_type : Int32
  section : @core.TypedArray
  section_offset : Int32
}

///|
/// Parses Ultra HDR data (an `ArrayBuffer`); `on_load` gets `width`, `height`, `data`,
/// `format` and `type_` once the images are decoded.
pub fn UltraHDRLoader::parse(
  self : UltraHDRLoader,
  buffer : @core.JsValue,
  on_load : (@loaders.DataTexData) -> Unit,
) -> Unit {
  // `null` fields: arithmetic reads them as 0
  let metadata = {
    version: @core.JsValue::null(),
    base_rendition_is_hdr: None,
    gain_map_min: 0.0,
    gain_map_max: 0.0,
    gamma: 0.0,
    offset_sdr: 0.0,
    offset_hdr: 0.0,
    hdr_capacity_min: 0.0,
    hdr_capacity_max: 0.0,
  }
  let bytes = uhdr_new_uint8(buffer)
  let sections : Array[UhdrSection] = []
  // JPEG segment-aware scanner using length headers
  let mut offset = 0
  while offset < bytes.length() - 1 {
    // Find marker prefix
    if bytes.get_int(offset) != 0xff {
      offset += 1
      continue
    }
    let marker_type = bytes.get_int(offset + 1)
    // SOI (0xD8) - Start of Image, no length field
    if marker_type == 0xd8 {
      sections.push({
        section_type: marker_type,
        section: bytes.subarray(start=offset, end=offset + 2),
        section_offset: offset + 2,
      })
      offset += 2
      continue
    }
    // APP0-APP2 segments have length headers
    if marker_type == 0xe0 || marker_type == 0xe1 || marker_type == 0xe2 {
      // Length is stored as big-endian 16-bit value (includes length bytes, excludes marker)
      let segment_length = (bytes.get_int(offset + 2) << 8) |
        bytes.get_int(offset + 3)
      let segment_end = offset + 2 + segment_length
      sections.push({
        section_type: marker_type,
        section: bytes.subarray(start=offset, end=segment_end),
        section_offset: offset + 2,
      })
      offset = segment_end
      continue
    }
    // Skip other markers with length fields (0xC0-0xFE range, except RST and EOI)
    if marker_type >= 0xc0 &&
      marker_type <= 0xfe &&
      marker_type != 0xd9 &&
      (marker_type < 0xd0 || marker_type > 0xd7) {
      let segment_length = (bytes.get_int(offset + 2) << 8) |
        bytes.get_int(offset + 3)
      offset += 2 + segment_length
      continue
    }
    // EOI (0xD9) or RST markers (0xD0-0xD7) - no length field
    offset += 2
  }
  let mut primary_image : @core.TypedArray? = None
  let mut gainmap_image : @core.TypedArray? = None
  for i in 0..<sections.length() {
    let { section_type, section, section_offset, } = sections[i]
    if section_type == 0xe0 {
      // JPEG Header - no useful information
    } else if section_type == 0xe1 {
      // APP1: XMP Metadata
      self.parse_xmp_metadata(
        uhdr_text_decode(@core.TypedArray::uint8(section)),
        metadata,
      )
    } else if section_type == 0xe2 {
      // APP2: Data Sections - MPF / ICC Profile / ISO 21496-1 Metadata
      let section_data = UhdrDataView::new(
        section.buffer(),
        section.byte_offset() + 2,
        section.byte_length() - 2,
      )
      // Check for ISO 21496-1 namespace: "urn:iso:std:iso:ts:21496:-1\0"
      let iso_name_space = "urn:iso:std:iso:ts:21496:-1\u{0}"
      if section.byte_length() >= iso_name_space.length() + 2 {
        let mut is_iso = true
        for j in 0..<iso_name_space.length() {
          if section.get_int(2 + j) != iso_name_space.code_unit_at(j).to_int() {
            is_iso = false
            break
          }
        }
        if is_iso {
          // Parse ISO 21496-1 metadata
          let iso_data = section.subarray(start=2 + iso_name_space.length())
          self.parse_iso_metadata(iso_data, metadata)
          continue
        }
      }
      // Check for MPF
      let section_header = section_data.get_uint32(2, false)
      if section_header == 0x4d504600U.to_double() {
        // MPF Section

        // Section contains a list of static bytes and ends with offsets indicating location of SDR and gainmap images
        // First bytes after header indicate little / big endian ordering (0x49492A00 - LE / 0x4D4D002A - BE)
        let mpf_little_endian = section_data.get_uint32_default(6) ==
          0x49492a00U.to_double()
        let mpf_bytes_offset = 60
        // SDR size includes the metadata length, SDR offset is always 0
        let primary_image_size = section_data.get_uint32(
          mpf_bytes_offset, mpf_little_endian,
        )
        let primary_image_offset = section_data.get_uint32(
          mpf_bytes_offset + 4,
          mpf_little_endian,
        )
        // Gainmap size is an absolute value starting from its offset, gainmap offset needs 6 bytes padding to take into account 0x00 bytes at the end of XMP
        let gainmap_image_size = section_data.get_uint32(
          mpf_bytes_offset + 16,
          mpf_little_endian,
        )
        let gainmap_image_offset = section_data.get_uint32(
            mpf_bytes_offset + 20,
            mpf_little_endian,
          ) +
          section_offset.to_double() +
          6.0
        primary_image = Some(
          uhdr_uint8_view(buffer, primary_image_offset, primary_image_size),
        )
        gainmap_image = Some(
          uhdr_uint8_view(buffer, gainmap_image_offset, gainmap_image_size),
        )
      }
    }
  }
  // Minimal sufficient validation - https://developer.android.com/media/platform/hdr-image-format#signal_of_the_format
  // Version can come from either XMP or ISO metadata
  if !uhdr_truthy(metadata.version) {
    uhdr_throw_error(
      @core.JsValue::of("THREE.UltraHDRLoader: Not a valid UltraHDR image"),
    )
  }
  match (primary_image, gainmap_image) {
    (Some(primary_image), Some(gainmap_image)) =>
      self.apply_gainmap_to_sdr(
        metadata,
        primary_image,
        gainmap_image,
        (hdr_buffer, width, height) => {
          let tex_data = @loaders.DataTexData::new()
          tex_data.width = Some(width)
          tex_data.height = Some(height)
          tex_data.data = Some(hdr_buffer)
          tex_data.format = Some(@core.RGBAFormat)
          tex_data.type_ = Some(self.type_)
          on_load(tex_data)
        },
        error => uhdr_throw_error(error),
      )
    _ =>
      uhdr_throw_error(
        @core.JsValue::of(
          "THREE.UltraHDRLoader: Could not parse UltraHDR images",
        ),
      )
  }
}

///|
/// Parses ISO 21496-1 gainmap metadata from binary data.
fn UltraHDRLoader::parse_iso_metadata(
  self : UltraHDRLoader,
  data : @core.TypedArray,
  metadata : UhdrMetadata,
) -> Unit {
  ignore(self)
  let view = UhdrDataView::new(
    data.buffer(),
    data.byte_offset(),
    data.byte_length(),
  )
  // Skip minimum version (2 bytes) and writer version (2 bytes)
  let mut offset = 4
  // Read flags (1 byte)
  let flags = view.get_uint8(offset)
  offset += 1
  let backward_direction = (flags & 0x4) != 0
  let use_common_denominator = (flags & 0x8) != 0
  let mut gain_map_min = 0.0
  let mut gain_map_max = 0.0
  let mut gamma = 0.0
  let mut offset_sdr = 0.0
  let mut offset_hdr = 0.0
  let mut hdr_capacity_min = 0.0
  let mut hdr_capacity_max = 0.0
  if use_common_denominator {
    // Read common denominator (4 bytes, unsigned)
    let common_denominator = view.get_uint32(offset, false)
    offset += 4
    // Read baseHdrHeadroom (4 bytes, unsigned)
    let base_hdr_headroom_n = view.get_uint32(offset, false)
    offset += 4
    hdr_capacity_min = uhdr_math_log2(base_hdr_headroom_n / common_denominator)
    // Read alternateHdrHeadroom (4 bytes, unsigned)
    let alternate_hdr_headroom_n = view.get_uint32(offset, false)
    offset += 4
    hdr_capacity_max = uhdr_math_log2(
      alternate_hdr_headroom_n / common_denominator,
    )
    // Read first channel (or only channel) parameters
    let gain_map_min_n = view.get_int32(offset, false)
    offset += 4
    gain_map_min = gain_map_min_n / common_denominator
    let gain_map_max_n = view.get_int32(offset, false)
    offset += 4
    gain_map_max = gain_map_max_n / common_denominator
    let gamma_n = view.get_uint32(offset, false)
    offset += 4
    gamma = gamma_n / common_denominator
    let offset_sdr_n = view.get_int32(offset, false)
    offset += 4
    offset_sdr = offset_sdr_n / common_denominator * 255.0
    let offset_hdr_n = view.get_int32(offset, false)
    offset_hdr = offset_hdr_n / common_denominator * 255.0
  } else {
    // Read baseHdrHeadroom numerator and denominator
    let base_hdr_headroom_n = view.get_uint32(offset, false)
    offset += 4
    let base_hdr_headroom_d = view.get_uint32(offset, false)
    offset += 4
    hdr_capacity_min = uhdr_math_log2(base_hdr_headroom_n / base_hdr_headroom_d)
    // Read alternateHdrHeadroom numerator and denominator
    let alternate_hdr_headroom_n = view.get_uint32(offset, false)
    offset += 4
    let alternate_hdr_headroom_d = view.get_uint32(offset, false)
    offset += 4
    hdr_capacity_max = uhdr_math_log2(
      alternate_hdr_headroom_n / alternate_hdr_headroom_d,
    )
    // Read first channel parameters
    let gain_map_min_n = view.get_int32(offset, false)
    offset += 4
    let gain_map_min_d = view.get_uint32(offset, false)
    offset += 4
    gain_map_min = gain_map_min_n / gain_map_min_d
    let gain_map_max_n = view.get_int32(offset, false)
    offset += 4
    let gain_map_max_d = view.get_uint32(offset, false)
    offset += 4
    gain_map_max = gain_map_max_n / gain_map_max_d
    let gamma_n = view.get_uint32(offset, false)
    offset += 4
    let gamma_d = view.get_uint32(offset, false)
    offset += 4
    gamma = gamma_n / gamma_d
    let offset_sdr_n = view.get_int32(offset, false)
    offset += 4
    let offset_sdr_d = view.get_uint32(offset, false)
    offset += 4
    offset_sdr = offset_sdr_n / offset_sdr_d * 255.0
    let offset_hdr_n = view.get_int32(offset, false)
    offset += 4
    let offset_hdr_d = view.get_uint32(offset, false)
    offset_hdr = offset_hdr_n / offset_hdr_d * 255.0
  }
  // Convert log2 values to linear
  metadata.version = @core.JsValue::of("1.0") // ISO standard doesn't encode version string, use default
  metadata.base_rendition_is_hdr = Some(backward_direction)
  metadata.gain_map_min = gain_map_min
  metadata.gain_map_max = gain_map_max
  metadata.gamma = gamma
  metadata.offset_sdr = offset_sdr
  metadata.offset_hdr = offset_hdr
  metadata.hdr_capacity_min = hdr_capacity_min
  metadata.hdr_capacity_max = hdr_capacity_max
}

///|
/// Starts loading `url` and returns the texture, filled once the images are decoded.
pub fn UltraHDRLoader::load(
  self : UltraHDRLoader,
  url : String,
  on_load? : (@core.Texture, @loaders.DataTexData) -> Unit,
  on_progress? : (@loaders.ProgressEvent) -> Unit,
  on_error? : (@core.JsValue) -> Unit,
) -> @core.Texture {
  let texture = @core.DataTexture::new(
    data=if self.type_ == @core.HalfFloatType {
      @core.TypedArray::uint16(0)
    } else {
      @core.TypedArray::float32(0)
    },
    width=0,
    height=0,
    format=@core.RGBAFormat,
    type_=self.type_,
    mapping=@core.UVMapping,
    wrap_s=@core.ClampToEdgeWrapping,
    wrap_t=@core.ClampToEdgeWrapping,
    mag_filter=@core.LinearFilter,
    min_filter=@core.LinearMipMapLinearFilter,
    anisotropy=1,
    color_space=@core.LinearSRGBColorSpace,
  )
  texture.generate_mipmaps = true
  texture.flip_y = true
  let loader = @loaders.FileLoader::new(manager=self.base.manager)
  loader.set_priority(self.base.priority) |> ignore
  loader.set_cache(self.base.cache) |> ignore
  loader.set_response_type("arraybuffer") |> ignore
  loader.set_request_header(self.base.request_header) |> ignore
  loader.set_path(self.base.path) |> ignore
  loader.set_with_credentials(self.base.with_credentials) |> ignore
  loader.load(
    url,
    on_load=buffer => {
      let result = uhdr_try(() => {
        self.parse(buffer, tex_data => {
          texture.set_image(
            DataImage(
              @core.DataImage::new(
                data?=tex_data.data,
                width=tex_data.width.unwrap_or(0),
                height=tex_data.height.unwrap_or(0),
              ),
            ),
          )
          texture.set_needs_update(true)
          if on_load is Some(on_load) {
            on_load(texture, tex_data)
          }
        })
      })
      if !result.is_undefined() {
        if on_error is Some(on_error) {
          on_error(result)
        }
        uhdr_console_error(result)
      }
    },
    on_progress?,
    on_error?,
  )
  texture
}

///|
/// `try { f() } catch ( e ) { ... }`: the thrown value, or `undefined`.
extern "js" fn uhdr_try(f : () -> Unit) -> @core.JsValue = "(f) => { try { f(); return undefined; } catch (e) { return e === undefined ? null : e; } }"

///|
fn UltraHDRLoader::parse_xmp_metadata(
  self : UltraHDRLoader,
  xmp_data_string : String,
  metadata : UhdrMetadata,
) -> Unit {
  ignore(self)
  let xmp_xml = uhdr_parse_xml(xmp_data_string)
  // Determine if given XMP metadata is the primary GContainer descriptor or a gainmap descriptor
  let has_hdr_container_descriptor = uhdr_first_element(
    xmp_xml, "Container:Directory",
  )
  if uhdr_truthy(has_hdr_container_descriptor) {
    // There's not much useful information in the container descriptor besides memory-validation
  } else {
    // Gainmap descriptor - defaults from https://developer.android.com/media/platform/hdr-image-format#HDR_gain_map_metadata
    let gainmap_node = uhdr_first_element(xmp_xml, "rdf:Description")
    metadata.version = uhdr_get_attribute(gainmap_node, "hdrgm:Version")
    metadata.base_rendition_is_hdr = Some(
      uhdr_is_string_true(
        uhdr_get_attribute(gainmap_node, "hdrgm:BaseRenditionIsHDR"),
      ),
    )
    metadata.gain_map_min = uhdr_parse_float_or(
      uhdr_get_attribute(gainmap_node, "hdrgm:GainMapMin"),
      0.0,
    )
    metadata.gain_map_max = uhdr_parse_float_or(
      uhdr_get_attribute(gainmap_node, "hdrgm:GainMapMax"),
      1.0,
    )
    metadata.gamma = uhdr_parse_float_or(
      uhdr_get_attribute(gainmap_node, "hdrgm:Gamma"),
      1.0,
    )
    metadata.offset_sdr = uhdr_parse_float_offset(
      uhdr_get_attribute(gainmap_node, "hdrgm:OffsetSDR"),
    )
    metadata.offset_hdr = uhdr_parse_float_offset(
      uhdr_get_attribute(gainmap_node, "hdrgm:OffsetHDR"),
    )
    metadata.hdr_capacity_min = uhdr_parse_float_or(
      uhdr_get_attribute(gainmap_node, "hdrgm:HDRCapacityMin"),
      0.0,
    )
    metadata.hdr_capacity_max = uhdr_parse_float_or(
      uhdr_get_attribute(gainmap_node, "hdrgm:HDRCapacityMax"),
      1.0,
    )
  }
}

///|
fn uhdr_srgb_to_linear_value(value : Double) -> Double {
  // 0.04045 * 255 = 10.31475
  if value < 10.31475 {
    // (1/255) * 0.0773993808
    return value * 0.000303527
  }
  if value < 1024.0 {
    return uhdr_srgb_to_linear[uhdr_to_int32(value)]
  }
  // (1/255) * 0.9478672986 = 0.003717127
  uhdr_math_pow(value * 0.003717127 + 0.0521327014, 2.4)
}

///|
fn UltraHDRLoader::apply_gainmap_to_sdr(
  self : UltraHDRLoader,
  metadata : UhdrMetadata,
  sdr_buffer : @core.TypedArray,
  gainmap_buffer : @core.TypedArray,
  on_success : (@core.TypedArray, Int32, Int32) -> Unit,
  on_error : (@core.JsValue) -> Unit,
) -> Unit {
  uhdr_decode_images(
    sdr_buffer,
    gainmap_buffer,
    (sdr_image, gainmap_image) => {
      let sdr_width = uhdr_number(sdr_image, "width")
      let sdr_height = uhdr_number(sdr_image, "height")
      let sdr_image_aspect = sdr_width / sdr_height
      let gainmap_image_aspect = uhdr_number(gainmap_image, "width") /
        uhdr_number(gainmap_image, "height")
      if sdr_image_aspect != gainmap_image_aspect {
        on_error(
          @core.JsValue::of(
            "THREE.UltraHDRLoader Error: Aspect ratio mismatch between SDR and Gainmap images",
          ),
        )
        return
      }
      let canvas = uhdr_create_canvas()
      let ctx = uhdr_get_context(canvas)
      uhdr_set_size(canvas, sdr_width, sdr_height)
      // Use out-of-the-box interpolation of Canvas API to scale gainmap to fit the SDR resolution
      uhdr_draw_image_scaled(
        ctx,
        gainmap_image,
        uhdr_number(gainmap_image, "width"),
        uhdr_number(gainmap_image, "height"),
        sdr_width,
        sdr_height,
      )
      let gainmap_data = uhdr_get_image_data(ctx, sdr_width, sdr_height)
      uhdr_draw_image(ctx, sdr_image)
      let sdr_data = uhdr_get_image_data(ctx, sdr_width, sdr_height)

      // HDR Recovery formula - https://developer.android.com/media/platform/hdr-image-format#use_the_gain_map_to_create_adapted_HDR_rendition

      // 1.8 instead of 2 near-perfectly rectifies approximations introduced by precalculated SRGB_TO_LINEAR values
      let max_display_boost = uhdr_math_pow(
        1.8,
        metadata.hdr_capacity_max * 0.5,
      )
      let unclamped_weight_factor = (
          uhdr_math_log2(max_display_boost) - metadata.hdr_capacity_min
        ) /
        (metadata.hdr_capacity_max - metadata.hdr_capacity_min)
      let weight_factor = uhdr_math_min(
        uhdr_math_max(unclamped_weight_factor, 0.0),
        1.0,
      )
      let data_length = sdr_data.length()
      let gain_map_min = metadata.gain_map_min
      let gain_map_max = metadata.gain_map_max
      let offset_sdr = metadata.offset_sdr
      let offset_hdr = metadata.offset_hdr
      let inv_gamma = 1.0 / metadata.gamma
      let use_gamma_one = metadata.gamma == 1.0
      let is_half_float = self.type_ == @core.HalfFloatType
      let hdr_buffer = if is_half_float {
        let b = @core.TypedArray::uint16(data_length)
        b.fill(15360)
        b
      } else {
        let b = @core.TypedArray::float32(data_length)
        b.fill(1.0)
        b
      }
      let mut i = 0
      while i < data_length {
        for c in 0..<3 {
          let idx = i + c
          let sdr_value = sdr_data[idx]
          let gainmap_value = gainmap_data[idx] * 0.00392156862745098 // 1/255
          let log_recovery = if use_gamma_one {
            gainmap_value
          } else {
            uhdr_math_pow(gainmap_value, inv_gamma)
          }
          let log_boost = gain_map_min +
            (gain_map_max - gain_map_min) * log_recovery
          let hdr_value = (sdr_value + offset_sdr) *
            (if log_boost * weight_factor == 0.0 {
              1.0
            } else {
              uhdr_math_pow(2, log_boost * weight_factor)
            }) -
            offset_hdr
          let linear_hdr_value = uhdr_math_min(
            uhdr_math_max(uhdr_srgb_to_linear_value(hdr_value), 0),
            65504,
          )
          hdr_buffer[idx] = if is_half_float {
            @core.to_half_float(linear_hdr_value)
          } else {
            linear_hdr_value
          }
        }
        i += 4
      }
      on_success(
        hdr_buffer,
        uhdr_to_int32(sdr_width),
        uhdr_to_int32(sdr_height),
      )
    },
    e => on_error(e),
  )
}

///|
/// `loadAsync( url, onProgress )`, inherited from `Loader`: resolves with the texture.
pub async fn UltraHDRLoader::load_async(
  self : UltraHDRLoader,
  url : String,
  on_progress? : (@loaders.ProgressEvent) -> Unit,
) -> @core.Texture raise @loaders.LoaderError {
  @loaders.loader_promise((resolve, reject) => {
    self.load(
      url,
      on_load=(texture, _) => resolve(texture),
      on_progress?,
      on_error=reject,
    )
    |> ignore
  })
}
