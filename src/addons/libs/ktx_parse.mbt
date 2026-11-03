// Upstream examples/jsm/libs/ktx-parse.module.js (ktx-parse, vendored minified): the
// part KTX2Loader uses, `read` (`Mi`), its reader class (`Ci`) and the constants
// KTX2Loader imports. Bytes are read through a JS `DataView`, as upstream. Header and
// DFD integers are `Int` (uint32 header values >= 2^31 would wrap); 64-bit values and
// `sampleLower`/`sampleUpper` are `Double`, as the JS numbers.

///|
pub const KHR_SUPERCOMPRESSION_NONE : Int32 = 0

///|
pub const KHR_SUPERCOMPRESSION_ZSTD : Int32 = 2

///|
pub const KHR_DF_FLAG_ALPHA_PREMULTIPLIED : Int32 = 1

///|
pub const KHR_DF_PRIMARIES_UNSPECIFIED : Int32 = 0

///|
pub const KHR_DF_PRIMARIES_BT709 : Int32 = 1

///|
pub const KHR_DF_PRIMARIES_DISPLAYP3 : Int32 = 10

///|
pub const KHR_DF_TRANSFER_SRGB : Int32 = 2

///|
pub const VK_FORMAT_UNDEFINED : Int32 = 0

///|
pub const VK_FORMAT_R8_UNORM : Int32 = 9

///|
pub const VK_FORMAT_R8_SRGB : Int32 = 15

///|
pub const VK_FORMAT_R8G8_UNORM : Int32 = 16

///|
pub const VK_FORMAT_R8G8_SRGB : Int32 = 22

///|
pub const VK_FORMAT_R8G8B8A8_UNORM : Int32 = 37

///|
pub const VK_FORMAT_R8G8B8A8_SRGB : Int32 = 43

///|
pub const VK_FORMAT_R16_SFLOAT : Int32 = 76

///|
pub const VK_FORMAT_R16G16_SFLOAT : Int32 = 83

///|
pub const VK_FORMAT_R16G16B16A16_UNORM : Int32 = 91

///|
pub const VK_FORMAT_R16G16B16A16_SFLOAT : Int32 = 97

///|
pub const VK_FORMAT_R32_SFLOAT : Int32 = 100

///|
pub const VK_FORMAT_R32G32_SFLOAT : Int32 = 103

///|
pub const VK_FORMAT_R32G32B32A32_SFLOAT : Int32 = 109

///|
pub const VK_FORMAT_B10G11R11_UFLOAT_PACK32 : Int32 = 122

///|
pub const VK_FORMAT_E5B9G9R9_UFLOAT_PACK32 : Int32 = 123

///|
pub const VK_FORMAT_BC1_RGB_UNORM_BLOCK : Int32 = 131

///|
pub const VK_FORMAT_BC1_RGB_SRGB_BLOCK : Int32 = 132

///|
pub const VK_FORMAT_BC1_RGBA_UNORM_BLOCK : Int32 = 133

///|
pub const VK_FORMAT_BC1_RGBA_SRGB_BLOCK : Int32 = 134

///|
pub const VK_FORMAT_BC3_UNORM_BLOCK : Int32 = 137

///|
pub const VK_FORMAT_BC3_SRGB_BLOCK : Int32 = 138

///|
pub const VK_FORMAT_BC4_UNORM_BLOCK : Int32 = 139

///|
pub const VK_FORMAT_BC4_SNORM_BLOCK : Int32 = 140

///|
pub const VK_FORMAT_BC5_UNORM_BLOCK : Int32 = 141

///|
pub const VK_FORMAT_BC5_SNORM_BLOCK : Int32 = 142

///|
pub const VK_FORMAT_BC7_UNORM_BLOCK : Int32 = 145

///|
pub const VK_FORMAT_BC7_SRGB_BLOCK : Int32 = 146

///|
pub const VK_FORMAT_ETC2_R8G8B8_SRGB_BLOCK : Int32 = 148

///|
pub const VK_FORMAT_ETC2_R8G8B8A8_SRGB_BLOCK : Int32 = 152

///|
pub const VK_FORMAT_EAC_R11_UNORM_BLOCK : Int32 = 153

///|
pub const VK_FORMAT_EAC_R11_SNORM_BLOCK : Int32 = 154

///|
pub const VK_FORMAT_EAC_R11G11_UNORM_BLOCK : Int32 = 155

///|
pub const VK_FORMAT_EAC_R11G11_SNORM_BLOCK : Int32 = 156

///|
pub const VK_FORMAT_ASTC_4x4_UNORM_BLOCK : Int32 = 157

///|
pub const VK_FORMAT_ASTC_4x4_SRGB_BLOCK : Int32 = 158

///|
pub const VK_FORMAT_ASTC_6x6_UNORM_BLOCK : Int32 = 165

///|
pub const VK_FORMAT_ASTC_6x6_SRGB_BLOCK : Int32 = 166

///|
pub const VK_FORMAT_PVRTC1_2BPP_UNORM_BLOCK_IMG : Int32 = 1000054000

///|
pub const VK_FORMAT_PVRTC1_4BPP_UNORM_BLOCK_IMG : Int32 = 1000054001

///|
pub const VK_FORMAT_PVRTC1_2BPP_SRGB_BLOCK_IMG : Int32 = 1000054004

///|
pub const VK_FORMAT_PVRTC1_4BPP_SRGB_BLOCK_IMG : Int32 = 1000054005

///|
pub const VK_FORMAT_ASTC_4x4_SFLOAT_BLOCK_EXT : Int32 = 1000066000

///|
pub const VK_FORMAT_ASTC_6x6_SFLOAT_BLOCK_EXT : Int32 = 1000066004

///|
/// One entry of `container.levels`.
pub(all) struct KTX2Level {
  mut level_data : @core.TypedArray
  mut uncompressed_byte_length : Double
}

///|
/// One entry of a basic DFD's `samples`.
pub(all) struct KTX2BasicFormatSample {
  mut bit_offset : Int32
  mut bit_length : Int32
  mut channel_type : Int32
  mut sample_position : Array[Int32]
  mut sample_lower : Double
  mut sample_upper : Double
}

///|
/// A basic data format descriptor block.
pub(all) struct KTX2DataFormatDescriptorBasicFormat {
  mut vendor_id : Int32
  mut descriptor_type : Int32
  mut version_number : Int32
  mut color_model : Int32
  mut color_primaries : Int32
  mut transfer_function : Int32
  mut flags : Int32
  mut texel_block_dimension : Array[Int32]
  mut bytes_plane : Array[Int32]
  mut samples : Array[KTX2BasicFormatSample]
}

///|
/// A key/value entry: bytes, or a string for keys matching `/^ktx/i`.
pub(all) enum KTX2KeyValue {
  Bytes(@core.TypedArray)
  Text(String)
}

///|
/// One entry of `globalData.imageDescs`.
pub(all) struct KTX2BasisLZImageDesc {
  mut image_flags : Int32
  mut rgb_slice_byte_offset : Int32
  mut rgb_slice_byte_length : Int32
  mut alpha_slice_byte_offset : Int32
  mut alpha_slice_byte_length : Int32
}

///|
/// `container.globalData` (BasisLZ supercompression global data).
pub(all) struct KTX2GlobalDataBasisLZ {
  mut endpoint_count : Int32
  mut selector_count : Int32
  mut image_descs : Array[KTX2BasisLZImageDesc]
  mut endpoints_data : @core.TypedArray
  mut selectors_data : @core.TypedArray
  mut tables_data : @core.TypedArray
  mut extended_data : @core.TypedArray
}

///|
/// The object `read` returns.
pub(all) struct KTX2Container {
  mut vk_format : Int32
  mut type_size : Int32
  mut pixel_width : Int32
  mut pixel_height : Int32
  mut pixel_depth : Int32
  mut layer_count : Int32
  mut face_count : Int32
  mut level_count : Int32
  mut supercompression_scheme : Int32
  mut levels : Array[KTX2Level]
  mut data_format_descriptor : Array[KTX2DataFormatDescriptorBasicFormat]
  mut key_value : Map[String, KTX2KeyValue]
  mut global_data : KTX2GlobalDataBasisLZ?
}

///|
#external
priv type KtxParseDataView

///|
extern "js" fn ktx_parse_data_view(
  t : @core.TypedArray,
  byte_offset : Double,
  byte_length : Double,
) -> KtxParseDataView =
  #|(t, e, n) => new DataView(t.buffer, t.byteOffset + e, n)

///|
extern "js" fn ktx_parse_get_uint8(dv : KtxParseDataView, o : Int32) -> Int32 =
  #|(dv, o) => dv.getUint8(o)

///|
extern "js" fn ktx_parse_get_uint16(
  dv : KtxParseDataView,
  o : Int32,
  le : Bool,
) -> Int32 =
  #|(dv, o, le) => dv.getUint16(o, le)

///|
extern "js" fn ktx_parse_get_uint32_number(
  dv : KtxParseDataView,
  o : Int32,
  le : Bool,
) -> Double =
  #|(dv, o, le) => dv.getUint32(o, le)

///|
extern "js" fn ktx_parse_get_int32(
  dv : KtxParseDataView,
  o : Int32,
  le : Bool,
) -> Int32 =
  #|(dv, o, le) => dv.getInt32(o, le)

///|
/// `new Uint8Array( dv.buffer, dv.byteOffset + offset, length )`.
extern "js" fn ktx_parse_view_bytes(
  dv : KtxParseDataView,
  offset : Int32,
  length : Int32,
) -> @core.TypedArray =
  #|(dv, o, n) => new Uint8Array(dv.buffer, dv.byteOffset + o, n)

///|
/// `new Uint8Array( t.buffer, t.byteOffset + offset, length )`.
extern "js" fn ktx_parse_sub_bytes(
  t : @core.TypedArray,
  offset : Double,
  length : Double,
) -> @core.TypedArray =
  #|(t, o, n) => new Uint8Array(t.buffer, t.byteOffset + o, n)

///|
extern "js" fn ktx_parse_double_to_int(x : Double) -> Int32 = "(x) => x | 0"

///|
/// `Si`: `new TextDecoder().decode( t )`.
extern "js" fn ktx_parse_si(t : @core.TypedArray) -> String =
  #|(t) => new TextDecoder().decode(t)

///|
extern "js" fn ktx_parse_is_ktx_key(key : String) -> Bool =
  #|(i) => !!i.match(/^ktx/i)

///|
extern "js" fn ktx_parse_strip_nul(t : String) -> String =
  #|(t) => t.substring(0, t.lastIndexOf("\0"))

///|
extern "js" fn ktx_parse_throw_error(message : String) -> Unit =
  #|(m) => { throw new Error(m); }

///|
/// `Ci`: a little-endian cursor over a `DataView`.
priv struct KtxParseBufferReader {
  data_view : KtxParseDataView
  little_endian : Bool
  mut offset : Int32
}

///|
fn KtxParseBufferReader::new(
  t : @core.TypedArray,
  e : Double,
  n : Double,
  i : Bool,
) -> KtxParseBufferReader {
  { data_view: ktx_parse_data_view(t, e, n), little_endian: i, offset: 0, }
}

///|
fn KtxParseBufferReader::next_uint8(self : KtxParseBufferReader) -> Int32 {
  let t = ktx_parse_get_uint8(self.data_view, self.offset)
  self.offset += 1
  t
}

///|
fn KtxParseBufferReader::next_uint16(self : KtxParseBufferReader) -> Int32 {
  let t = ktx_parse_get_uint16(self.data_view, self.offset, self.little_endian)
  self.offset += 2
  t
}

///|
fn KtxParseBufferReader::next_uint32_number(
  self : KtxParseBufferReader,
) -> Double {
  let t = ktx_parse_get_uint32_number(
    self.data_view,
    self.offset,
    self.little_endian,
  )
  self.offset += 4
  t
}

///|
fn KtxParseBufferReader::next_uint32(self : KtxParseBufferReader) -> Int32 {
  ktx_parse_double_to_int(self.next_uint32_number())
}

///|
fn KtxParseBufferReader::next_uint64(self : KtxParseBufferReader) -> Double {
  let t = ktx_parse_get_uint32_number(
      self.data_view,
      self.offset,
      self.little_endian,
    ) +
    4294967296.0 *
    ktx_parse_get_uint32_number(
      self.data_view,
      self.offset + 4,
      self.little_endian,
    )
  self.offset += 8
  t
}

///|
fn KtxParseBufferReader::next_int32(self : KtxParseBufferReader) -> Int32 {
  let t = ktx_parse_get_int32(self.data_view, self.offset, self.little_endian)
  self.offset += 4
  t
}

///|
fn KtxParseBufferReader::next_uint8_array(
  self : KtxParseBufferReader,
  t : Int32,
) -> @core.TypedArray {
  let e = ktx_parse_view_bytes(self.data_view, self.offset, t)
  self.offset += t
  e
}

///|
fn KtxParseBufferReader::skip(
  self : KtxParseBufferReader,
  t : Int32,
) -> KtxParseBufferReader {
  self.offset += t
  self
}

///|
fn KtxParseBufferReader::scan(
  self : KtxParseBufferReader,
  t : Int32,
  e~ : Int32 = 0,
) -> @core.TypedArray {
  let n = self.offset
  let mut i = 0
  while ktx_parse_get_uint8(self.data_view, self.offset) != e && i < t {
    i += 1
    self.offset += 1
  }
  if i < t {
    self.offset += 1
  }
  ktx_parse_view_bytes(self.data_view, n, i)
}

///|
/// `Oi`, the KTX 2.0 file identifier.
let ktx_parse_oi : Array[Int32] = [
  171, 75, 84, 88, 32, 50, 48, 187, 13, 10, 26, 10,
]

///|
/// Parses a KTX 2.0 file (upstream `read`).
pub fn read(t : @core.TypedArray) -> KTX2Container {
  let e = ktx_parse_sub_bytes(t, 0.0, ktx_parse_oi.length().to_double())
  for k in 0..<12 {
    if e.get_int(k) != ktx_parse_oi[k] {
      ktx_parse_throw_error("Missing KTX 2.0 identifier.")
      panic()
    }
  }
  let n : KTX2Container = {
    vk_format: 0,
    type_size: 1,
    pixel_width: 0,
    pixel_height: 0,
    pixel_depth: 0,
    layer_count: 0,
    face_count: 1,
    level_count: 0,
    supercompression_scheme: 0,
    levels: [],
    data_format_descriptor: [
      {
        vendor_id: 0,
        descriptor_type: 0,
        version_number: 2,
        color_model: 0,
        color_primaries: 1,
        transfer_function: 2,
        flags: 0,
        texel_block_dimension: [0, 0, 0, 0],
        bytes_plane: [0, 0, 0, 0, 0, 0, 0, 0],
        samples: [],
      },
    ],
    key_value: {},
    global_data: None,
  }
  let i = 17 * 4
  let s = KtxParseBufferReader::new(
    t,
    ktx_parse_oi.length().to_double(),
    i.to_double(),
    true,
  )
  n.vk_format = s.next_uint32()
  n.type_size = s.next_uint32()
  n.pixel_width = s.next_uint32()
  n.pixel_height = s.next_uint32()
  n.pixel_depth = s.next_uint32()
  n.layer_count = s.next_uint32()
  n.face_count = s.next_uint32()
  n.level_count = s.next_uint32()
  n.supercompression_scheme = s.next_uint32()
  let a = s.next_uint32_number()
  let r = s.next_uint32_number()
  let o = s.next_uint32_number()
  let l = s.next_uint32()
  let f = s.next_uint64()
  let c = s.next_uint64()
  let level_count = if n.level_count > 1 { n.level_count } else { 1 }
  let u = 3 * level_count * 8
  let h = KtxParseBufferReader::new(
    t,
    (ktx_parse_oi.length() + i).to_double(),
    u.to_double(),
    true,
  )
  for _e in 0..<level_count {
    let byte_offset = h.next_uint64()
    let byte_length = h.next_uint64()
    let level_data = ktx_parse_sub_bytes(t, byte_offset, byte_length)
    n.levels.push({ level_data, uncompressed_byte_length: h.next_uint64(), })
  }
  let p = KtxParseBufferReader::new(t, a, r, true)
  ignore(p.skip(4))
  let vendor_id = p.next_uint16()
  let descriptor_type = p.next_uint16()
  let version_number = p.next_uint16()
  let x = p.next_uint16()
  let color_model = p.next_uint8()
  let color_primaries = p.next_uint8()
  let transfer_function = p.next_uint8()
  let flags = p.next_uint8()
  let texel_block_dimension = [
    p.next_uint8(),
    p.next_uint8(),
    p.next_uint8(),
    p.next_uint8(),
  ]
  let bytes_plane = [
    p.next_uint8(),
    p.next_uint8(),
    p.next_uint8(),
    p.next_uint8(),
    p.next_uint8(),
    p.next_uint8(),
    p.next_uint8(),
    p.next_uint8(),
  ]
  let y : KTX2DataFormatDescriptorBasicFormat = {
    vendor_id,
    descriptor_type,
    version_number,
    color_model,
    color_primaries,
    transfer_function,
    flags,
    texel_block_dimension,
    bytes_plane,
    samples: [],
  }
  let b = (x.to_double() / 4.0 - 6.0) / 4.0
  let mut k = 0
  while k.to_double() < b {
    let bit_offset = p.next_uint16()
    let bit_length = p.next_uint8()
    let channel_type = p.next_uint8()
    let sample_position = [
      p.next_uint8(),
      p.next_uint8(),
      p.next_uint8(),
      p.next_uint8(),
    ]
    let e : KTX2BasicFormatSample = {
      bit_offset,
      bit_length,
      channel_type,
      sample_position,
      sample_lower: @double.neg_infinity,
      sample_upper: @double.infinity,
    }
    if (64 & e.channel_type) != 0 {
      e.sample_lower = p.next_int32().to_double()
      e.sample_upper = p.next_int32().to_double()
    } else {
      e.sample_lower = p.next_uint32_number()
      e.sample_upper = p.next_uint32_number()
    }
    // `y.samples[ t ] = e`
    y.samples.push(e)
    k += 1
  }
  n.data_format_descriptor.clear()
  n.data_format_descriptor.push(y)
  let m = KtxParseBufferReader::new(t, o, l.to_double(), true)
  while m.offset < l {
    let t = m.next_uint32()
    let e = m.scan(t)
    let i = ktx_parse_si(e)
    let value = m.next_uint8_array(t - e.byte_length() - 1)
    n.key_value[i] = Bytes(value)
    if ktx_parse_is_ktx_key(i) {
      let t = ktx_parse_si(value)
      n.key_value[i] = Text(ktx_parse_strip_nul(t))
    }
    ignore(m.skip(if t % 4 != 0 { 4 - t % 4 } else { 0 }))
  }
  if c <= 0.0 {
    return n
  }
  let d = KtxParseBufferReader::new(t, f, c, true)
  let endpoint_count = d.next_uint16()
  let selector_count = d.next_uint16()
  let v = d.next_uint32_number()
  let bb = d.next_uint32_number()
  let ll = d.next_uint32_number()
  let aa = d.next_uint32_number()
  let image_descs : Array[KTX2BasisLZImageDesc] = []
  for _t in 0..<level_count {
    let image_flags = d.next_uint32()
    let rgb_slice_byte_offset = d.next_uint32()
    let rgb_slice_byte_length = d.next_uint32()
    let alpha_slice_byte_offset = d.next_uint32()
    let alpha_slice_byte_length = d.next_uint32()
    image_descs.push({
      image_flags,
      rgb_slice_byte_offset,
      rgb_slice_byte_length,
      alpha_slice_byte_offset,
      alpha_slice_byte_length,
    })
  }
  let ii = f + d.offset.to_double()
  let vv = ii + v
  let cc = vv + bb
  let ff = cc + ll
  let endpoints_data = ktx_parse_sub_bytes(t, ii, v)
  let selectors_data = ktx_parse_sub_bytes(t, vv, bb)
  let tables_data = ktx_parse_sub_bytes(t, cc, ll)
  let extended_data = ktx_parse_sub_bytes(t, ff, aa)
  n.global_data = Some({
    endpoint_count,
    selector_count,
    image_descs,
    endpoints_data,
    selectors_data,
    tables_data,
    extended_data,
  })
  n
}
