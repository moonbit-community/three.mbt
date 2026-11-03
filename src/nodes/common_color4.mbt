// renderers/common/Color4.js. Upstream extends `Color`; the RGB part is a `Color`
// here, so `color4.color` is what upstream passes where a `Color` is expected.

///|
/// A color with alpha.
pub(all) struct Color4 {
  color : @math.Color
  mut a : Double
}

///|
/// `new Color4( r, g, b, a = 1 )`; without arguments the color is white.
pub fn Color4::new(
  r~ : Double = 1.0,
  g~ : Double = 1.0,
  b~ : Double = 1.0,
  a~ : Double = 1.0,
) -> Color4 {
  { color: @math.Color::new(r, g, b), a, }
}

///|
/// `set( r, g, b, a = 1 )` with components.
pub fn Color4::set(
  self : Color4,
  r : Double,
  g : Double,
  b : Double,
  a~ : Double = 1.0,
) -> Color4 {
  self.a = a
  self.color.set(r, g, b) |> ignore
  self
}

///|
/// `set( color, undefined, undefined, a = 1 )` with a `Color`.
pub fn Color4::set_color(
  self : Color4,
  color : @math.Color,
  a~ : Double = 1.0,
) -> Color4 {
  self.a = a
  self.color.copy(color) |> ignore
  self
}

///|
/// `set( hex, undefined, undefined, a = 1 )` with a hex number.
pub fn Color4::set_hex(self : Color4, hex : Int32, a~ : Double = 1.0) -> Color4 {
  self.a = a
  self.color.set_hex(hex) |> ignore
  self
}

///|
/// `copy( color )` from a `Color4` (alpha included).
pub fn Color4::copy(self : Color4, color : Color4) -> Color4 {
  self.a = color.a
  self.color.copy(color.color) |> ignore
  self
}

///|
/// `copy( color )` from a `Color`, which has no alpha.
pub fn Color4::copy_color(self : Color4, color : @math.Color) -> Color4 {
  self.color.copy(color) |> ignore
  self
}

///|
pub fn Color4::clone(self : Color4) -> Color4 {
  Color4::new(r=self.color.r, g=self.color.g, b=self.color.b, a=self.a)
}
