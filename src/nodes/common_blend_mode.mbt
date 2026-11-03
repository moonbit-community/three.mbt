// renderers/common/BlendMode.js

///|
/// The blending state of a render target attachment (MRT outputs).
pub(all) struct BlendMode {
  mut blending : Int32
  mut blend_src : Int32
  mut blend_dst : Int32
  mut blend_equation : Int32
  mut blend_src_alpha : Int32?
  mut blend_dst_alpha : Int32?
  mut blend_equation_alpha : Int32?
  mut premultiply_alpha : Bool
}

///|
/// `new BlendMode( blending = NormalBlending )`.
pub fn BlendMode::new(blending~ : Int32 = @core.NormalBlending) -> BlendMode {
  {
    blending,
    blend_src: @core.SrcAlphaFactor,
    blend_dst: @core.OneMinusSrcAlphaFactor,
    blend_equation: @core.AddEquation,
    blend_src_alpha: None,
    blend_dst_alpha: None,
    blend_equation_alpha: None,
    premultiply_alpha: false,
  }
}

///|
pub fn BlendMode::copy(self : BlendMode, source : BlendMode) -> BlendMode {
  self.blending = source.blending
  self.blend_src = source.blend_src
  self.blend_dst = source.blend_dst
  self.blend_equation = source.blend_equation
  self.blend_src_alpha = source.blend_src_alpha
  self.blend_dst_alpha = source.blend_dst_alpha
  self.blend_equation_alpha = source.blend_equation_alpha
  self.premultiply_alpha = source.premultiply_alpha
  self
}

///|
pub fn BlendMode::clone(self : BlendMode) -> BlendMode {
  BlendMode::new().copy(self)
}
