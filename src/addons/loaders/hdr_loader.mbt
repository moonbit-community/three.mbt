// Upstream examples/jsm/loaders/HDRLoader.js. Upstream subclasses DataTextureLoader and
// overrides `parse`; here the loader holds a `DataTextureLoader` whose parse hook calls
// `HDRLoader::parse`, so `load` reads `type_` at parse time as upstream does.

///|
/// A loader for the RGBE HDR texture format.
pub(all) struct HDRLoader {
  mut base : @loaders.DataTextureLoader
  /// The texture type, `HalfFloatType` (default) or `FloatType`.
  mut type_ : Int32
}

///|
pub fn HDRLoader::new(manager? : @loaders.LoadingManager) -> HDRLoader {
  let loader : HDRLoader = {
    base: @loaders.DataTextureLoader::new(manager?),
    type_: @core.HalfFloatType,
  }
  loader.base = @loaders.DataTextureLoader::new(manager?, parse=buffer => {
    loader.parse(buffer)
  })
  loader
}

///|
pub impl @loaders.LoaderLike for HDRLoader with fn loader(self) {
  self.base.base
}

///|
pub impl @loaders.LoaderSettings for HDRLoader

///|
pub extend HDRLoader with @loaders.LoaderLike::{loader}

///|
pub extend HDRLoader with @loaders.LoaderSettings::{
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
/// Starts loading `url` and returns the texture; `on_load` also gets the parsed data,
/// whose `extra` holds upstream's `header`, `gamma` and `exposure`.
pub fn HDRLoader::load(
  self : HDRLoader,
  url : String,
  on_load? : (@core.Texture, @loaders.DataTexData) -> Unit,
  on_progress? : (@loaders.ProgressEvent) -> Unit,
  on_error? : (@core.JsValue) -> Unit,
) -> @core.Texture {
  self.base.load(url, on_load?, on_progress?, on_error?)
}

///|
/// Upstream `loadAsync`.
pub async fn HDRLoader::load_async(
  self : HDRLoader,
  url : String,
  on_progress? : (@loaders.ProgressEvent) -> Unit,
) -> @core.Texture raise @loaders.LoaderError {
  self.base.load_async(url, on_progress?)
}

///|
/// Sets the texture type.
pub fn HDRLoader::set_data_type(self : HDRLoader, value : Int32) -> HDRLoader {
  self.type_ = value
  self
}

///|
/// A JS `RegExp`.
#external
priv type HdrRegExp

///|
extern "js" fn HdrRegExp::new(source : String) -> HdrRegExp = "(s) => new RegExp(s)"

///|
/// `line.match( re )`: the match array or `null`.
extern "js" fn hdr_match(line : String, re : HdrRegExp) -> @core.JsValue = "(l, r) => l.match(r)"

///|
extern "js" fn hdr_match_group(m : @core.JsValue, i : Int32) -> String = "(m, i) => m[i]"

///|
extern "js" fn hdr_index_of_newline(s : String) -> Int32 = "(s) => s.indexOf(String.fromCharCode(10))"

///|
extern "js" fn hdr_slice(s : String, start : Int32, end : Int32) -> String = "(s, a, b) => s.slice(a, b)"

///|
extern "js" fn hdr_string_length(s : String) -> Int32 = "(s) => s.length"

///|
extern "js" fn hdr_char_at0(s : String) -> String = "(s) => s.charAt(0)"

///|
extern "js" fn hdr_parse_float(s : String) -> Double = "(s) => parseFloat(s)"

///|
extern "js" fn hdr_parse_int(s : String) -> Double = "(s) => parseInt(s, 10)"

///|
/// `String.fromCharCode.apply( null, new Uint16Array( buffer.subarray( p, p + n ) ) )`.
extern "js" fn hdr_chunk_string(
  buffer : @core.TypedArray,
  p : Int32,
  n : Int32,
) -> String = "(b, p, n) => String.fromCharCode.apply(null, new Uint16Array(b.subarray(p, p + n)))"

///|
extern "js" fn hdr_throw_error(message : String) -> Unit = "(m) => { throw new Error(m); }"

///|
extern "js" fn hdr_math_pow(x : Double, y : Double) -> Double = "Math.pow"

///|
extern "js" fn hdr_math_min(x : Double, y : Double) -> Double = "Math.min"

///|
extern "js" fn hdr_tex_extra(
  header : String,
  gamma : Double,
  exposure : Double,
) -> @core.JsValue = "(h, g, e) => ({ header: h, gamma: g, exposure: e })"

///|
// default error routine.  change this to change error handling
const HDR_RGBE_READ_ERROR = 1

///|
const HDR_RGBE_WRITE_ERROR = 2

///|
const HDR_RGBE_FORMAT_ERROR = 3

///|
const HDR_RGBE_MEMORY_ERROR = 4

///|
fn hdr_rgbe_error(rgbe_error_code : Int32, msg? : String) -> Unit {
  let msg = msg.unwrap_or("")
  match rgbe_error_code {
    HDR_RGBE_READ_ERROR =>
      hdr_throw_error("THREE.HDRLoader: Read Error: " + msg)
    HDR_RGBE_WRITE_ERROR =>
      hdr_throw_error("THREE.HDRLoader: Write Error: " + msg)
    HDR_RGBE_FORMAT_ERROR =>
      hdr_throw_error("THREE.HDRLoader: Bad File Format: " + msg)
    _ => hdr_throw_error("THREE.HDRLoader: Memory Error: " + msg)
  }
}

///|
// flags indicating which fields in an rgbe_header_info are valid
const HDR_RGBE_VALID_PROGRAMTYPE = 1

///|
const HDR_RGBE_VALID_FORMAT = 2

///|
const HDR_RGBE_VALID_DIMENSIONS = 4

///|
/// The byte array upstream reads with its ad hoc `pos` property.
priv struct HdrByteArray {
  bytes : @core.TypedArray
  mut pos : Int32
}

///|
/// Reads one line; `None` is upstream's `false`.
fn hdr_fgets(buffer : HdrByteArray) -> String? {
  let chunk_size = 128
  let line_limit = 1024
  let byte_length = buffer.bytes.byte_length()
  let mut p = buffer.pos
  let mut i = -1
  let mut len = 0
  let mut s = ""
  let mut chunk = hdr_chunk_string(buffer.bytes, p, chunk_size)
  while ({
          i = hdr_index_of_newline(chunk)
          0 > i
        }) &&
        len < line_limit &&
        p < byte_length {
    s += chunk
    len += hdr_string_length(chunk)
    p += chunk_size
    chunk = hdr_chunk_string(buffer.bytes, p, chunk_size)
  }
  if -1 < i {
    buffer.pos += len + i + 1
    return Some(s + hdr_slice(chunk, 0, i))
  }
  None
}

///|
/// RGBE format header struct.
priv struct HdrRgbeHeader {
  mut valid : Int32
  mut string : String
  mut comments : String
  mut programtype : String
  mut format : String
  mut gamma : Double
  mut exposure : Double
  mut width : Double
  mut height : Double
}

///|
// minimal header reading.  modify if you want to parse more information
fn hdr_rgbe_read_header(buffer : HdrByteArray) -> HdrRgbeHeader {
  // regexes to parse header info fields
  let magic_token_re = HdrRegExp::new("^#\\?(\\S+)")
  let gamma_re = HdrRegExp::new("^\\s*GAMMA\\s*=\\s*(\\d+(\\.\\d+)?)\\s*$")
  let exposure_re = HdrRegExp::new(
    "^\\s*EXPOSURE\\s*=\\s*(\\d+(\\.\\d+)?)\\s*$",
  )
  let format_re = HdrRegExp::new("^\\s*FORMAT=(\\S+)\\s*$")
  let dimensions_re = HdrRegExp::new(
    "^\\s*\\-Y\\s+(\\d+)\\s+\\+X\\s+(\\d+)\\s*$",
  )
  // RGBE format header struct
  let header = {
    valid: 0,
    string: "",
    comments: "",
    programtype: "RGBE",
    format: "",
    gamma: 1.0,
    exposure: 1.0,
    width: 0.0,
    height: 0.0,
  }
  let mut line = ""
  if buffer.pos >= buffer.bytes.byte_length() {
    hdr_rgbe_error(HDR_RGBE_READ_ERROR, msg="no header found")
  } else {
    match hdr_fgets(buffer) {
      Some(l) if l != "" => line = l
      _ => hdr_rgbe_error(HDR_RGBE_READ_ERROR, msg="no header found")
    }
  }
  // if you want to require the magic token then uncomment the next line
  let m = hdr_match(line, magic_token_re)
  if m.is_null() {
    hdr_rgbe_error(HDR_RGBE_FORMAT_ERROR, msg="bad initial token")
  }
  header.valid = header.valid | HDR_RGBE_VALID_PROGRAMTYPE
  header.programtype = hdr_match_group(m, 1)
  header.string += line + "\n"
  while true {
    let line = match hdr_fgets(buffer) {
      Some(line) => line
      None => break
    }
    header.string += line + "\n"
    if "#" == hdr_char_at0(line) {
      header.comments += line + "\n"
      continue // comment line
    }
    let m = hdr_match(line, gamma_re)
    if !m.is_null() {
      header.gamma = hdr_parse_float(hdr_match_group(m, 1))
    }
    let m = hdr_match(line, exposure_re)
    if !m.is_null() {
      header.exposure = hdr_parse_float(hdr_match_group(m, 1))
    }
    let m = hdr_match(line, format_re)
    if !m.is_null() {
      header.valid = header.valid | HDR_RGBE_VALID_FORMAT
      header.format = hdr_match_group(m, 1) //'32-bit_rle_rgbe';
    }
    let m = hdr_match(line, dimensions_re)
    if !m.is_null() {
      header.valid = header.valid | HDR_RGBE_VALID_DIMENSIONS
      header.height = hdr_parse_int(hdr_match_group(m, 1))
      header.width = hdr_parse_int(hdr_match_group(m, 2))
    }
    if (header.valid & HDR_RGBE_VALID_FORMAT) != 0 &&
      (header.valid & HDR_RGBE_VALID_DIMENSIONS) != 0 {
      break
    }
  }
  if (header.valid & HDR_RGBE_VALID_FORMAT) == 0 {
    hdr_rgbe_error(HDR_RGBE_FORMAT_ERROR, msg="missing format specifier")
  }
  if (header.valid & HDR_RGBE_VALID_DIMENSIONS) == 0 {
    hdr_rgbe_error(HDR_RGBE_FORMAT_ERROR, msg="missing image size specifier")
  }
  header
}

///|
fn hdr_rgbe_read_pixels_rle(
  buffer : @core.TypedArray,
  w : Double,
  h : Double,
) -> @core.TypedArray {
  let scanline_width = w
  if (
    // run length encoding is not allowed so read flat
      scanline_width < 8.0 ||
      scanline_width > (0x7fff : Int32).to_double()
    ) ||
    2 !=
    // this file is not run length encoded
    buffer.get_int(0) ||
    2 != buffer.get_int(1) ||
    (buffer.get_int(2) & 0x80) != 0 {
    // return the flat buffer
    return @core.TypedArray::uint8(buffer)
  }
  if scanline_width !=
    ((buffer.get_int(2) << 8) | buffer.get_int(3)).to_double() {
    hdr_rgbe_error(HDR_RGBE_FORMAT_ERROR, msg="wrong scanline width")
  }
  let scanline_width = scanline_width.to_int()
  let data_rgba = hdr_new_typed_array("Uint8Array", 4.0 * w * h)
  if data_rgba.length() == 0 {
    hdr_rgbe_error(HDR_RGBE_MEMORY_ERROR, msg="unable to allocate buffer space")
  }
  let mut offset = 0
  let mut pos = 0
  let ptr_end = 4 * scanline_width
  let rgbe_start = @core.TypedArray::uint8(4)
  let scanline_buffer = @core.TypedArray::uint8(ptr_end)
  let mut num_scanlines = h
  let byte_length = buffer.byte_length()
  // read in each successive scanline
  while num_scanlines > 0.0 && pos < byte_length {
    if pos + 4 > byte_length {
      hdr_rgbe_error(HDR_RGBE_READ_ERROR)
    }
    rgbe_start[0] = buffer[pos]
    pos += 1
    rgbe_start[1] = buffer[pos]
    pos += 1
    rgbe_start[2] = buffer[pos]
    pos += 1
    rgbe_start[3] = buffer[pos]
    pos += 1
    if 2 != rgbe_start.get_int(0) ||
      2 != rgbe_start.get_int(1) ||
      ((rgbe_start.get_int(2) << 8) | rgbe_start.get_int(3)) != scanline_width {
      hdr_rgbe_error(HDR_RGBE_FORMAT_ERROR, msg="bad rgbe scanline format")
    }
    // read each of the four channels for the scanline into the buffer
    // first red, then green, then blue, then exponent
    let mut ptr = 0
    while ptr < ptr_end && pos < byte_length {
      let mut count = buffer.get_int(pos)
      pos += 1
      let is_encoded_run = count > 128
      if is_encoded_run {
        count -= 128
      }
      if 0 == count || ptr + count > ptr_end {
        hdr_rgbe_error(HDR_RGBE_FORMAT_ERROR, msg="bad scanline data")
      }
      if is_encoded_run {
        // a (encoded) run of the same value
        let byte_value = buffer[pos]
        pos += 1
        for i in 0..<count {
          ignore(i)
          scanline_buffer[ptr] = byte_value
          ptr += 1
        }
        //ptr += count;
      } else {
        // a literal-run
        scanline_buffer.set_from(
          buffer.subarray(start=pos, end=pos + count),
          offset=ptr,
        )
        ptr += count
        pos += count
      }
    }

    // now convert data from buffer into rgba
    // first red, then green, then blue, then exponent (alpha)
    let l = scanline_width //scanline_buffer.byteLength;
    for i in 0..<l {
      let mut off = 0
      data_rgba[offset] = scanline_buffer[i + off]
      off += scanline_width //1;
      data_rgba[offset + 1] = scanline_buffer[i + off]
      off += scanline_width //1;
      data_rgba[offset + 2] = scanline_buffer[i + off]
      off += scanline_width //1;
      data_rgba[offset + 3] = scanline_buffer[i + off]
      offset += 4
    }
    num_scanlines -= 1.0
  }
  data_rgba
}

///|
fn hdr_rgbe_byte_to_rgb_float(
  source_array : @core.TypedArray,
  source_offset : Int32,
  dest_array : @core.TypedArray,
  dest_offset : Int32,
) -> Unit {
  let e = source_array[source_offset + 3]
  let scale = hdr_math_pow(2.0, e - 128.0) / 255.0
  dest_array[dest_offset + 0] = source_array[source_offset + 0] * scale
  dest_array[dest_offset + 1] = source_array[source_offset + 1] * scale
  dest_array[dest_offset + 2] = source_array[source_offset + 2] * scale
  dest_array[dest_offset + 3] = 1
}

///|
fn hdr_rgbe_byte_to_rgb_half(
  source_array : @core.TypedArray,
  source_offset : Int32,
  dest_array : @core.TypedArray,
  dest_offset : Int32,
) -> Unit {
  let e = source_array[source_offset + 3]
  let scale = hdr_math_pow(2.0, e - 128.0) / 255.0
  // clamping to 65504, the maximum representable value in float16
  dest_array[dest_offset + 0] = @core.to_half_float(
    hdr_math_min(source_array[source_offset + 0] * scale, 65504),
  )
  dest_array[dest_offset + 1] = @core.to_half_float(
    hdr_math_min(source_array[source_offset + 1] * scale, 65504),
  )
  dest_array[dest_offset + 2] = @core.to_half_float(
    hdr_math_min(source_array[source_offset + 2] * scale, 65504),
  )
  dest_array[dest_offset + 3] = @core.to_half_float(1)
}

///|
/// `new globalThis[ name ]( length )` with a length that may not be an integer.
extern "js" fn hdr_new_typed_array(
  name : String,
  length : Double,
) -> @core.TypedArray = "(t, n) => new globalThis[t](n)"

///|
extern "js" fn hdr_new_uint8(buffer : @core.JsValue) -> @core.TypedArray = "(b) => new Uint8Array(b)"

///|
/// Parses RGBE data (an `ArrayBuffer`). Throws upstream's errors.
pub fn HDRLoader::parse(
  self : HDRLoader,
  buffer : @core.JsValue,
) -> @loaders.DataTexData {
  // adapted from http://www.graphics.cornell.edu/~bjw/rgbe.html
  let byte_array = { bytes: hdr_new_uint8(buffer), pos: 0, }
  let rgbe_header_info = hdr_rgbe_read_header(byte_array)
  let w = rgbe_header_info.width
  let h = rgbe_header_info.height
  let image_rgba_data = hdr_rgbe_read_pixels_rle(
    byte_array.bytes.subarray(start=byte_array.pos),
    w,
    h,
  )
  let (data, type_) = match self.type_ {
    @core.FloatType => {
      let num_elements = image_rgba_data.length().to_double() / 4.0
      let float_array = hdr_new_typed_array("Float32Array", num_elements * 4.0)
      let mut j = 0
      while j.to_double() < num_elements {
        hdr_rgbe_byte_to_rgb_float(image_rgba_data, j * 4, float_array, j * 4)
        j += 1
      }
      (float_array, @core.FloatType)
    }
    @core.HalfFloatType => {
      let num_elements = image_rgba_data.length().to_double() / 4.0
      let half_array = hdr_new_typed_array("Uint16Array", num_elements * 4.0)
      let mut j = 0
      while j.to_double() < num_elements {
        hdr_rgbe_byte_to_rgb_half(image_rgba_data, j * 4, half_array, j * 4)
        j += 1
      }
      (half_array, @core.HalfFloatType)
    }
    _ => {
      hdr_throw_error(
        "THREE.HDRLoader: Unsupported type: " + self.type_.to_string(),
      )
      panic()
    }
  }
  let tex_data = @loaders.DataTexData::new()
  tex_data.width = Some(w.to_int())
  tex_data.height = Some(h.to_int())
  tex_data.data = Some(data)
  tex_data.extra = Some(
    hdr_tex_extra(
      rgbe_header_info.string,
      rgbe_header_info.gamma,
      rgbe_header_info.exposure,
    ),
  )
  tex_data.type_ = Some(type_)
  tex_data.color_space = Some(@core.LinearSRGBColorSpace)
  tex_data.min_filter = Some(@core.LinearFilter)
  tex_data.mag_filter = Some(@core.LinearFilter)
  tex_data.generate_mipmaps = Some(false)
  tex_data.flip_y = Some(true)
  tex_data
}
