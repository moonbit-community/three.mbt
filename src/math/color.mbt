///|
let _color_keywords : Map[String, Int32] = {
  "aliceblue": 0xF0F8FF,
  "antiquewhite": 0xFAEBD7,
  "aqua": 0x00FFFF,
  "aquamarine": 0x7FFFD4,
  "azure": 0xF0FFFF,
  "beige": 0xF5F5DC,
  "bisque": 0xFFE4C4,
  "black": 0x000000,
  "blanchedalmond": 0xFFEBCD,
  "blue": 0x0000FF,
  "blueviolet": 0x8A2BE2,
  "brown": 0xA52A2A,
  "burlywood": 0xDEB887,
  "cadetblue": 0x5F9EA0,
  "chartreuse": 0x7FFF00,
  "chocolate": 0xD2691E,
  "coral": 0xFF7F50,
  "cornflowerblue": 0x6495ED,
  "cornsilk": 0xFFF8DC,
  "crimson": 0xDC143C,
  "cyan": 0x00FFFF,
  "darkblue": 0x00008B,
  "darkcyan": 0x008B8B,
  "darkgoldenrod": 0xB8860B,
  "darkgray": 0xA9A9A9,
  "darkgreen": 0x006400,
  "darkgrey": 0xA9A9A9,
  "darkkhaki": 0xBDB76B,
  "darkmagenta": 0x8B008B,
  "darkolivegreen": 0x556B2F,
  "darkorange": 0xFF8C00,
  "darkorchid": 0x9932CC,
  "darkred": 0x8B0000,
  "darksalmon": 0xE9967A,
  "darkseagreen": 0x8FBC8F,
  "darkslateblue": 0x483D8B,
  "darkslategray": 0x2F4F4F,
  "darkslategrey": 0x2F4F4F,
  "darkturquoise": 0x00CED1,
  "darkviolet": 0x9400D3,
  "deeppink": 0xFF1493,
  "deepskyblue": 0x00BFFF,
  "dimgray": 0x696969,
  "dimgrey": 0x696969,
  "dodgerblue": 0x1E90FF,
  "firebrick": 0xB22222,
  "floralwhite": 0xFFFAF0,
  "forestgreen": 0x228B22,
  "fuchsia": 0xFF00FF,
  "gainsboro": 0xDCDCDC,
  "ghostwhite": 0xF8F8FF,
  "gold": 0xFFD700,
  "goldenrod": 0xDAA520,
  "gray": 0x808080,
  "green": 0x008000,
  "greenyellow": 0xADFF2F,
  "grey": 0x808080,
  "honeydew": 0xF0FFF0,
  "hotpink": 0xFF69B4,
  "indianred": 0xCD5C5C,
  "indigo": 0x4B0082,
  "ivory": 0xFFFFF0,
  "khaki": 0xF0E68C,
  "lavender": 0xE6E6FA,
  "lavenderblush": 0xFFF0F5,
  "lawngreen": 0x7CFC00,
  "lemonchiffon": 0xFFFACD,
  "lightblue": 0xADD8E6,
  "lightcoral": 0xF08080,
  "lightcyan": 0xE0FFFF,
  "lightgoldenrodyellow": 0xFAFAD2,
  "lightgray": 0xD3D3D3,
  "lightgreen": 0x90EE90,
  "lightgrey": 0xD3D3D3,
  "lightpink": 0xFFB6C1,
  "lightsalmon": 0xFFA07A,
  "lightseagreen": 0x20B2AA,
  "lightskyblue": 0x87CEFA,
  "lightslategray": 0x778899,
  "lightslategrey": 0x778899,
  "lightsteelblue": 0xB0C4DE,
  "lightyellow": 0xFFFFE0,
  "lime": 0x00FF00,
  "limegreen": 0x32CD32,
  "linen": 0xFAF0E6,
  "magenta": 0xFF00FF,
  "maroon": 0x800000,
  "mediumaquamarine": 0x66CDAA,
  "mediumblue": 0x0000CD,
  "mediumorchid": 0xBA55D3,
  "mediumpurple": 0x9370DB,
  "mediumseagreen": 0x3CB371,
  "mediumslateblue": 0x7B68EE,
  "mediumspringgreen": 0x00FA9A,
  "mediumturquoise": 0x48D1CC,
  "mediumvioletred": 0xC71585,
  "midnightblue": 0x191970,
  "mintcream": 0xF5FFFA,
  "mistyrose": 0xFFE4E1,
  "moccasin": 0xFFE4B5,
  "navajowhite": 0xFFDEAD,
  "navy": 0x000080,
  "oldlace": 0xFDF5E6,
  "olive": 0x808000,
  "olivedrab": 0x6B8E23,
  "orange": 0xFFA500,
  "orangered": 0xFF4500,
  "orchid": 0xDA70D6,
  "palegoldenrod": 0xEEE8AA,
  "palegreen": 0x98FB98,
  "paleturquoise": 0xAFEEEE,
  "palevioletred": 0xDB7093,
  "papayawhip": 0xFFEFD5,
  "peachpuff": 0xFFDAB9,
  "peru": 0xCD853F,
  "pink": 0xFFC0CB,
  "plum": 0xDDA0DD,
  "powderblue": 0xB0E0E6,
  "purple": 0x800080,
  "rebeccapurple": 0x663399,
  "red": 0xFF0000,
  "rosybrown": 0xBC8F8F,
  "royalblue": 0x4169E1,
  "saddlebrown": 0x8B4513,
  "salmon": 0xFA8072,
  "sandybrown": 0xF4A460,
  "seagreen": 0x2E8B57,
  "seashell": 0xFFF5EE,
  "sienna": 0xA0522D,
  "silver": 0xC0C0C0,
  "skyblue": 0x87CEEB,
  "slateblue": 0x6A5ACD,
  "slategray": 0x708090,
  "slategrey": 0x708090,
  "snow": 0xFFFAFA,
  "springgreen": 0x00FF7F,
  "steelblue": 0x4682B4,
  "tan": 0xD2B48C,
  "teal": 0x008080,
  "thistle": 0xD8BFD8,
  "tomato": 0xFF6347,
  "turquoise": 0x40E0D0,
  "violet": 0xEE82EE,
  "wheat": 0xF5DEB3,
  "white": 0xFFFFFF,
  "whitesmoke": 0xF5F5F5,
  "yellow": 0xFFFF00,
  "yellowgreen": 0x9ACD32,
}

///|
/// `Color.NAMES`: the X11 color names.
pub let color_names : Map[String, Int32] = _color_keywords

///|
/// The `{ h, s, l }` target of `Color::get_hsl`.
pub(all) struct Hsl {
  mut h : Double
  mut s : Double
  mut l : Double
}

///|
pub fn Hsl::new(h : Double, s : Double, l : Double) -> Hsl {
  { h, s, l, }
}

///|
let _hsl_a : Hsl = Hsl::new(0.0, 0.0, 0.0)

///|
let _hsl_b : Hsl = Hsl::new(0.0, 0.0, 0.0)

///|
let _color : Color = Color::new(1.0, 1.0, 1.0)

///|
fn hue2rgb(p : Double, q : Double, t : Double) -> Double {
  let mut t = t
  if t < 0.0 {
    t += 1.0
  }
  if t > 1.0 {
    t -= 1.0
  }
  if t < 1.0 / 6.0 {
    return p + (q - p) * 6.0 * t
  }
  if t < 1.0 / 2.0 {
    return q
  }
  if t < 2.0 / 3.0 {
    return p + (q - p) * 6.0 * (2.0 / 3.0 - t)
  }
  p
}

// `Math.max`/`Math.min` semantics (NaN, signed zero) differ from `@cmp`.

///|
fn js_max(a : Double, b : Double) -> Double = "Math" "max"

///|
fn js_min(a : Double, b : Double) -> Double = "Math" "min"

///|
fn js_max3(a : Double, b : Double, c : Double) -> Double = "Math" "max"

///|
fn js_min3(a : Double, b : Double, c : Double) -> Double = "Math" "min"

///|
extern "js" fn js_parse_int(string : String, radix : Int32) -> Double =
  #|(string, radix) => parseInt(string, radix)

///|
extern "js" fn js_parse_float(string : String) -> Double =
  #|(string) => parseFloat(string)

///|
extern "js" fn js_parse_hex_digit(hex : String, index : Int32) -> Double =
  #|(hex, index) => parseInt(hex.charAt(index), 16)

///|
extern "js" fn js_number_to_string(x : Double) -> String =
  #|(x) => String(x)

///|
extern "js" fn js_to_fixed3(x : Double) -> String =
  #|(x) => x.toFixed(3)

///|
extern "js" fn js_to_lower_case(string : String) -> String =
  #|(string) => string.toLowerCase()

///|
extern "js" fn js_hex_string(hex : Int32) -> String =
  #|(hex) => ('000000' + hex.toString(16)).slice(-6)

///|
#external
priv type ColorRegExp

///|
extern "js" fn ColorRegExp::new(source : String) -> ColorRegExp =
  #|(source) => new RegExp(source)

///|
/// All groups of a match with unmatched ones as `""`, or `[]` on no match.
extern "js" fn ColorRegExp::exec(
  self : ColorRegExp,
  string : String,
) -> FixedArray[String] =
  #|(regexp, string) => {
  #|  const m = regexp.exec(string);
  #|  return m === null ? [] : Array.from(m, (group) => group === undefined ? "" : group);
  #|}

///|
let _style_function_regexp : ColorRegExp = ColorRegExp::new(
  (
    #|^(\w+)\(([^\)]*)\)
  ),
)

///|
let _style_rgb_regexp : ColorRegExp = ColorRegExp::new(
  (
    #|^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d+(?:\.\d+)?|\.\d+)\s*)?$
  ),
)

///|
let _style_rgb_percent_regexp : ColorRegExp = ColorRegExp::new(
  (
    #|^\s*(\d+(?:\.\d+)?|\.\d+)\%\s*,\s*(\d+(?:\.\d+)?|\.\d+)\%\s*,\s*(\d+(?:\.\d+)?|\.\d+)\%\s*(?:,\s*(\d+(?:\.\d+)?|\.\d+)\s*)?$
  ),
)

///|
let _style_hsl_regexp : ColorRegExp = ColorRegExp::new(
  (
    #|^\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+))\s*,\s*(\d+(?:\.\d+)?|\.\d+)\%\s*,\s*(\d+(?:\.\d+)?|\.\d+)\%\s*(?:,\s*(\d+(?:\.\d+)?|\.\d+)\s*)?$
  ),
)

///|
let _style_hex_regexp : ColorRegExp = ColorRegExp::new(
  (
    #|^\#([A-Fa-f\d]+)$
  ),
)

///|
/// A color in RGB, stored in the working color space.
pub(all) struct Color {
  mut r : Double
  mut g : Double
  mut b : Double
}

///|
pub fn Color::new(r : Double, g : Double, b : Double) -> Color {
  { r, g, b, }
}

///|
/// Upstream `new Color( 0xff0000 )`.
pub fn Color::from_hex(hex : Int32) -> Color {
  Color::new(1.0, 1.0, 1.0).set_hex(hex)
}

///|
/// Upstream `new Color( 'red' )`.
pub fn Color::from_style(style : String) -> Color {
  Color::new(1.0, 1.0, 1.0).set_style(style)
}

///|
pub fn Color::set(self : Color, r : Double, g : Double, b : Double) -> Color {
  self.set_rgb(r, g, b)
}

///|
pub fn Color::set_scalar(self : Color, scalar : Double) -> Color {
  self.r = scalar
  self.g = scalar
  self.b = scalar
  self
}

///|
pub fn Color::set_hex(
  self : Color,
  hex : Int32,
  color_space~ : String = SRGBColorSpace,
) -> Color {
  self.r = ((hex >> 16) & 255).to_double() / 255.0
  self.g = ((hex >> 8) & 255).to_double() / 255.0
  self.b = (hex & 255).to_double() / 255.0
  ignore(color_management.color_space_to_working(self, color_space))
  self
}

///|
pub fn Color::set_rgb(
  self : Color,
  r : Double,
  g : Double,
  b : Double,
  color_space~ : String = color_management.working_color_space,
) -> Color {
  self.r = r
  self.g = g
  self.b = b
  ignore(color_management.color_space_to_working(self, color_space))
  self
}

///|
pub fn Color::set_hsl(
  self : Color,
  h : Double,
  s : Double,
  l : Double,
  color_space~ : String = color_management.working_color_space,
) -> Color {
  // h,s,l ranges are in 0.0 - 1.0
  let h = euclidean_modulo(h, 1.0)
  let s = clamp(s, 0.0, 1.0)
  let l = clamp(l, 0.0, 1.0)
  if s == 0.0 {
    self.r = l
    self.g = l
    self.b = l
  } else {
    let p = if l <= 0.5 { l * (1.0 + s) } else { l + s - l * s }
    let q = 2.0 * l - p
    self.r = hue2rgb(q, p, h + 1.0 / 3.0)
    self.g = hue2rgb(q, p, h)
    self.b = hue2rgb(q, p, h - 1.0 / 3.0)
  }
  ignore(color_management.color_space_to_working(self, color_space))
  self
}

///|
pub fn Color::set_style(
  self : Color,
  style : String,
  color_space~ : String = SRGBColorSpace,
) -> Color {
  fn handle_alpha(string : String) -> Unit {
    // an unmatched group is "", upstream's undefined
    if string == "" {
      return
    }
    if js_parse_float(string) < 1.0 {
      println("THREE.Color: Alpha component of " + style + " will be ignored.")
    }
  }

  let m = _style_function_regexp.exec(style)
  if m.length() > 0 {
    // rgb / hsl
    let name = m[1]
    let components = m[2]
    match name {
      "rgb" | "rgba" => {
        let color = _style_rgb_regexp.exec(components)
        if color.length() > 0 {
          // rgb(255,0,0) rgba(255,0,0,0.5)
          handle_alpha(color[4])
          return self.set_rgb(
            js_min(255.0, js_parse_int(color[1], 10)) / 255.0,
            js_min(255.0, js_parse_int(color[2], 10)) / 255.0,
            js_min(255.0, js_parse_int(color[3], 10)) / 255.0,
            color_space~,
          )
        }
        let color = _style_rgb_percent_regexp.exec(components)
        if color.length() > 0 {
          // rgb(100%,0%,0%) rgba(100%,0%,0%,0.5) rgb(50.5%,0%,0%)
          handle_alpha(color[4])
          return self.set_rgb(
            js_min(100.0, js_parse_float(color[1])) / 100.0,
            js_min(100.0, js_parse_float(color[2])) / 100.0,
            js_min(100.0, js_parse_float(color[3])) / 100.0,
            color_space~,
          )
        }
      }
      "hsl" | "hsla" => {
        let color = _style_hsl_regexp.exec(components)
        if color.length() > 0 {
          // hsl(120,50%,50%) hsla(120,50%,50%,0.5) hsl(-120,50%,50%)
          handle_alpha(color[4])
          return self.set_hsl(
            js_parse_float(color[1]) / 360.0,
            js_parse_float(color[2]) / 100.0,
            js_parse_float(color[3]) / 100.0,
            color_space~,
          )
        }
      }
      _ => println("THREE.Color: Unknown color model " + style)
    }
  } else {
    let m = _style_hex_regexp.exec(style)
    if m.length() > 0 {
      // hex color
      let hex = m[1]
      let size = hex.length()
      if size == 3 {
        // #ff0
        return self.set_rgb(
          js_parse_hex_digit(hex, 0) / 15.0,
          js_parse_hex_digit(hex, 1) / 15.0,
          js_parse_hex_digit(hex, 2) / 15.0,
          color_space~,
        )
      } else if size == 6 {
        // #ff0000
        return self.set_hex(js_parse_int(hex, 16).to_int(), color_space~)
      } else {
        println("THREE.Color: Invalid hex color " + style)
      }
    } else if style.length() > 0 {
      return self.set_color_name(style, color_space~)
    }
  }
  self
}

///|
pub fn Color::set_color_name(
  self : Color,
  style : String,
  color_space~ : String = SRGBColorSpace,
) -> Color {
  // color keywords
  match _color_keywords.get(js_to_lower_case(style)) {
    // red
    Some(hex) => ignore(self.set_hex(hex, color_space~))
    // unknown color
    None => println("THREE.Color: Unknown color " + style)
  }
  self
}

///|
pub fn Color::clone(self : Color) -> Color {
  Color::new(self.r, self.g, self.b)
}

///|
pub fn Color::copy(self : Color, color : Color) -> Color {
  self.r = color.r
  self.g = color.g
  self.b = color.b
  self
}

///|
pub fn Color::copy_srgb_to_linear(self : Color, color : Color) -> Color {
  self.r = srgb_to_linear(color.r)
  self.g = srgb_to_linear(color.g)
  self.b = srgb_to_linear(color.b)
  self
}

///|
pub fn Color::copy_linear_to_srgb(self : Color, color : Color) -> Color {
  self.r = linear_to_srgb(color.r)
  self.g = linear_to_srgb(color.g)
  self.b = linear_to_srgb(color.b)
  self
}

///|
pub fn Color::convert_srgb_to_linear(self : Color) -> Color {
  self.copy_srgb_to_linear(self)
}

///|
pub fn Color::convert_linear_to_srgb(self : Color) -> Color {
  self.copy_linear_to_srgb(self)
}

///|
pub fn Color::get_hex(
  self : Color,
  color_space~ : String = SRGBColorSpace,
) -> Int32 {
  ignore(
    color_management.working_to_color_space(_color.copy(self), color_space),
  )
  (clamp(_color.r * 255.0, 0.0, 255.0).round() * 65536.0 +
  clamp(_color.g * 255.0, 0.0, 255.0).round() * 256.0 +
  clamp(_color.b * 255.0, 0.0, 255.0).round()).to_int()
}

///|
pub fn Color::get_hex_string(
  self : Color,
  color_space~ : String = SRGBColorSpace,
) -> String {
  js_hex_string(self.get_hex(color_space~))
}

///|
pub fn Color::get_hsl(
  self : Color,
  target : Hsl,
  color_space~ : String = color_management.working_color_space,
) -> Hsl {
  // h,s,l ranges are in 0.0 - 1.0
  ignore(
    color_management.working_to_color_space(_color.copy(self), color_space),
  )
  let r = _color.r
  let g = _color.g
  let b = _color.b
  let max = js_max3(r, g, b)
  let min = js_min3(r, g, b)
  let mut hue = 0.0
  let mut saturation = 0.0
  let lightness = (min + max) / 2.0
  if min != max {
    let delta = max - min
    saturation = if lightness <= 0.5 {
      delta / (max + min)
    } else {
      delta / (2.0 - max - min)
    }
    hue = if max == r {
      (g - b) / delta + (if g < b { 6.0 } else { 0.0 })
    } else if max == g {
      (b - r) / delta + 2.0
    } else if max == b {
      (r - g) / delta + 4.0
    } else {
      // NaN channels: no switch case matches, leaving upstream's hue undefined
      0.0 / 0.0
    }
    hue /= 6.0
  }
  target.h = hue
  target.s = saturation
  target.l = lightness
  target
}

///|
pub fn Color::get_rgb(
  self : Color,
  target : Color,
  color_space~ : String = color_management.working_color_space,
) -> Color {
  ignore(
    color_management.working_to_color_space(_color.copy(self), color_space),
  )
  target.r = _color.r
  target.g = _color.g
  target.b = _color.b
  target
}

///|
pub fn Color::get_style(
  self : Color,
  color_space~ : String = SRGBColorSpace,
) -> String {
  ignore(
    color_management.working_to_color_space(_color.copy(self), color_space),
  )
  let r = _color.r
  let g = _color.g
  let b = _color.b
  if color_space != SRGBColorSpace {
    // Requires CSS Color Module Level 4 (https://www.w3.org/TR/css-color-4/).
    return "color(\{color_space} \{js_to_fixed3(r)} \{js_to_fixed3(g)} \{js_to_fixed3(b)})"
  }
  let red = js_number_to_string((r * 255.0).round())
  let green = js_number_to_string((g * 255.0).round())
  let blue = js_number_to_string((b * 255.0).round())
  "rgb(\{red},\{green},\{blue})"
}

///|
pub fn Color::offset_hsl(
  self : Color,
  h : Double,
  s : Double,
  l : Double,
) -> Color {
  ignore(self.get_hsl(_hsl_a))
  self.set_hsl(_hsl_a.h + h, _hsl_a.s + s, _hsl_a.l + l)
}

///|
pub fn Color::add(self : Color, color : Color) -> Color {
  self.r += color.r
  self.g += color.g
  self.b += color.b
  self
}

///|
pub fn Color::add_colors(self : Color, color1 : Color, color2 : Color) -> Color {
  self.r = color1.r + color2.r
  self.g = color1.g + color2.g
  self.b = color1.b + color2.b
  self
}

///|
pub fn Color::add_scalar(self : Color, s : Double) -> Color {
  self.r += s
  self.g += s
  self.b += s
  self
}

///|
pub fn Color::sub(self : Color, color : Color) -> Color {
  self.r = js_max(0.0, self.r - color.r)
  self.g = js_max(0.0, self.g - color.g)
  self.b = js_max(0.0, self.b - color.b)
  self
}

///|
pub fn Color::multiply(self : Color, color : Color) -> Color {
  self.r *= color.r
  self.g *= color.g
  self.b *= color.b
  self
}

///|
pub fn Color::multiply_scalar(self : Color, s : Double) -> Color {
  self.r *= s
  self.g *= s
  self.b *= s
  self
}

///|
pub fn Color::lerp(self : Color, color : Color, alpha : Double) -> Color {
  self.r += (color.r - self.r) * alpha
  self.g += (color.g - self.g) * alpha
  self.b += (color.b - self.b) * alpha
  self
}

///|
pub fn Color::lerp_colors(
  self : Color,
  color1 : Color,
  color2 : Color,
  alpha : Double,
) -> Color {
  self.r = color1.r + (color2.r - color1.r) * alpha
  self.g = color1.g + (color2.g - color1.g) * alpha
  self.b = color1.b + (color2.b - color1.b) * alpha
  self
}

///|
pub fn Color::lerp_hsl(self : Color, color : Color, alpha : Double) -> Color {
  ignore(self.get_hsl(_hsl_a))
  ignore(color.get_hsl(_hsl_b))
  let h = lerp(_hsl_a.h, _hsl_b.h, alpha)
  let s = lerp(_hsl_a.s, _hsl_b.s, alpha)
  let l = lerp(_hsl_a.l, _hsl_b.l, alpha)
  self.set_hsl(h, s, l)
}

///|
pub fn Color::set_from_vector3(self : Color, v : Vector3) -> Color {
  self.r = v.x
  self.g = v.y
  self.b = v.z
  self
}

///|
pub fn Color::apply_matrix3(self : Color, m : Matrix3) -> Color {
  let r = self.r
  let g = self.g
  let b = self.b
  let e = m.elements
  self.r = e[0] * r + e[3] * g + e[6] * b
  self.g = e[1] * r + e[4] * g + e[7] * b
  self.b = e[2] * r + e[5] * g + e[8] * b
  self
}

///|
pub fn Color::equals(self : Color, c : Color) -> Bool {
  c.r == self.r && c.g == self.g && c.b == self.b
}

///|
pub fn Color::from_array(
  self : Color,
  array : Array[Double],
  offset~ : Int32 = 0,
) -> Color {
  self.r = array[offset]
  self.g = array[offset + 1]
  self.b = array[offset + 2]
  self
}

///|
pub fn Color::to_array(
  self : Color,
  array~ : Array[Double] = [],
  offset~ : Int32 = 0,
) -> Array[Double] {
  // the target grows as a plain upstream array would
  while array.length() < offset + 3 {
    array.push(0.0)
  }
  array[offset] = self.r
  array[offset + 1] = self.g
  array[offset + 2] = self.b
  array
}

///|
pub fn[A : BufferAttributeLike] Color::from_buffer_attribute(
  self : Color,
  attribute : A,
  index : Int32,
) -> Color {
  self.r = attribute.get_x(index)
  self.g = attribute.get_y(index)
  self.b = attribute.get_z(index)
  self
}

///|
pub fn Color::to_json(self : Color) -> Int32 {
  self.get_hex()
}
