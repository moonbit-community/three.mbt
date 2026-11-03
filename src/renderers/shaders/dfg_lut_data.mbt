// Upstream src/renderers/shaders/DFGLUTData.js. The table is in dfg_lut_table.mbt.

///|
let dfg_lut : Ref[@core.Texture?] = Ref(None)

///|
/// Upstream `getDFGLUT`: builds the texture once and returns the same one after that.
pub fn get_dfg_lut() -> @core.Texture {
  if dfg_lut.val is Some(lut) {
    return lut
  }
  let lut = @core.DataTexture::new(
    data=@core.TypedArray::uint16(dfg_lut_table),
    width=16,
    height=16,
    format=@core.RGFormat,
    type_=@core.HalfFloatType,
  )
  lut.name = "DFG_LUT"
  lut.min_filter = @core.LinearFilter
  lut.mag_filter = @core.LinearFilter
  lut.wrap_s = @core.ClampToEdgeWrapping
  lut.wrap_t = @core.ClampToEdgeWrapping
  lut.generate_mipmaps = false
  lut.set_needs_update(true)
  dfg_lut.val = Some(lut)
  lut
}
