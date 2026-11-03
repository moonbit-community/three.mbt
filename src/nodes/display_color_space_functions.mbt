// nodes/display/ColorSpaceFunctions.js

///|
/// `sRGBTransferEOTF( color )`: sRGB to linear (the sRGB electro-optical transfer).
pub let s_rgb_transfer_eotf : Node = module_nodes(
  "nodes/display/ColorSpaceFunctions.js:sRGBTransferEOTF",
  fn() {
    fn_(
      fn(inputs, _) {
        let color = inputs.get(0).unwrap()
        let a = color.mul(0.9478672986).add(0.0521327014).pow(2.4)
        let b = color.mul(0.0773993808)
        let factor = color.less_than_equal(0.04045)
        let rgb_result = mix(a, b, factor)
        Some(rgb_result)
      },
      layout=FnLayout::short(
        [("color", "vec3")],
        return_="vec3",
        upstream="nodes/display/ColorSpaceFunctions.js:sRGBTransferEOTF",
      ),
    )
  },
)

///|
/// `sRGBTransferOETF( color )`: linear to sRGB (the sRGB opto-electronic transfer).
pub let s_rgb_transfer_oetf : Node = module_nodes(
  "nodes/display/ColorSpaceFunctions.js:sRGBTransferOETF",
  fn() {
    fn_(
      fn(inputs, _) {
        let color = inputs.get(0).unwrap()
        let a = color.pow(0.41666).mul(1.055).sub(0.055)
        let b = color.mul(12.92)
        let factor = color.less_than_equal(0.0031308)
        let rgb_result = mix(a, b, factor)
        Some(rgb_result)
      },
      layout=FnLayout::short(
        [("color", "vec3")],
        return_="vec3",
        upstream="nodes/display/ColorSpaceFunctions.js:sRGBTransferOETF",
      ),
    )
  },
)
