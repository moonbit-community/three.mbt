// nodes/display/ColorAdjustment.js

///|
/// `workingLuminanceCoefficients`: the luminance coefficients of the working color
/// space, a variable computed once per shader.
pub let working_luminance_coefficients : Node = module_nodes(
  "nodes/display/ColorAdjustment.js:workingLuminanceCoefficients",
  fn() {
    fn_(fn(_, _) {
      Some(
        vec3(
          @math.color_management.get_luminance_coefficients(
            @math.Vector3::new(0.0, 0.0, 0.0),
          ),
        ),
      )
    })
    .once()
    .call([])
    .to_var(name="workingLuminanceCoefficients")
  },
)

///|
/// `grayscale( color, luminanceCoefficients = workingLuminanceCoefficients )`.
pub let grayscale : Node = module_nodes(
  "nodes/display/ColorAdjustment.js:grayscale",
  fn() {
    fn_(
      fn(inputs, _) {
        let color = inputs.get(0).unwrap()
        let luminance_coefficients = inputs
          .get(1)
          .unwrap_or_else(fn() { working_luminance_coefficients })
        Some(luminance(color.rgb(), luminance_coefficients~))
      },
      layout=FnLayout::short(
        [("color", "vec3"), ("luminanceCoefficients", "vec3")],
        return_="float",
        upstream="nodes/display/ColorAdjustment.js:grayscale",
      ),
    )
  },
)

///|
/// `saturation( color, adjustment = 1, luminanceCoefficients )`: 0 is grayscale, 1
/// the color, larger values saturate.
pub let saturation : Node = module_nodes(
  "nodes/display/ColorAdjustment.js:saturation",
  fn() {
    fn_(
      fn(inputs, _) {
        let color = inputs.get(0).unwrap()
        let adjustment = inputs.get(1).unwrap_or_else(fn() { float(1) })
        let luminance_coefficients = inputs
          .get(2)
          .unwrap_or_else(fn() { working_luminance_coefficients })
        Some(
          adjustment
          .mix(luminance(color.rgb(), luminance_coefficients~), color.rgb())
          .max(0.0),
        )
      },
      layout=FnLayout::short(
        [
          ("color", "vec3"),
          ("adjustment", "float"),
          ("luminanceCoefficients", "vec3"),
        ],
        return_="vec3",
        upstream="nodes/display/ColorAdjustment.js:saturation",
      ),
    )
  },
)

///|
/// `vibrance( color, adjustment = 0 )`: saturates the less saturated colors more.
pub let vibrance : Node = module_nodes(
  "nodes/display/ColorAdjustment.js:vibrance",
  fn() {
    fn_(
      fn(inputs, _) {
        let color = inputs.get(0).unwrap()
        let adjustment = inputs.get(1).unwrap_or_else(fn() { float(0) })
        let average = add_of([color.r(), color.g(), color.b()]).div(3.0)
        let mx = color.r().max(color.g().max(color.b()))
        let amt = mx.sub(average).mul(adjustment).mul(-3.0)
        Some(mix(color.rgb(), mx, amt).max(0.0))
      },
      layout=FnLayout::short(
        [("color", "vec3"), ("adjustment", "float")],
        return_="vec3",
        upstream="nodes/display/ColorAdjustment.js:vibrance",
      ),
    )
  },
)

///|
/// `hue( color, adjustment = 1 )`: rotates the hue by `adjustment` radians.
pub let hue : Node = module_nodes("nodes/display/ColorAdjustment.js:hue", fn() {
  fn_(
    fn(inputs, _) {
      let color = inputs.get(0).unwrap()
      let adjustment = inputs.get(1).unwrap_or_else(fn() { float(1) })
      let k = vec3_of([0.57735, 0.57735, 0.57735])
      let cos_angle = adjustment.cos()
      Some(
        vec3(
          color
          .rgb()
          .mul(cos_angle)
          .add(
            k
            .cross(color.rgb())
            .mul(adjustment.sin())
            .add(k.mul(dot(k, color.rgb()).mul(cos_angle.one_minus()))),
          ),
        ).max(0.0),
      )
    },
    layout=FnLayout::short(
      [("color", "vec3"), ("adjustment", "float")],
      return_="vec3",
      upstream="nodes/display/ColorAdjustment.js:hue",
    ),
  )
})

///|
/// `luminance( color, luminanceCoefficients )`: `dot( color, coefficients )`, by
/// default with the working color space's coefficients.
pub fn luminance(color : &IntoTsl, luminance_coefficients? : &IntoTsl) -> Node {
  let luminance_coefficients : &IntoTsl = match luminance_coefficients {
    Some(l) => l
    None =>
      vec3(
        @math.color_management.get_luminance_coefficients(
          @math.Vector3::new(0.0, 0.0, 0.0),
        ),
      )
  }
  dot(color, luminance_coefficients)
}

///|
/// `cdl( color, slope, offset, power, saturation, luminanceCoefficients )`: the ASC
/// Color Decision List transform.
pub let cdl : Node = module_nodes("nodes/display/ColorAdjustment.js:cdl", fn() {
  fn_(
    fn(inputs, _) {
      let color = inputs.get(0).unwrap()
      let slope = inputs.get(1).unwrap_or_else(fn() { vec3(1) })
      let offset = inputs.get(2).unwrap_or_else(fn() { vec3(0) })
      let power = inputs.get(3).unwrap_or_else(fn() { vec3(1) })
      let saturation = inputs.get(4).unwrap_or_else(fn() { float(1) })
      // ASC CDL v1.2 explicitly requires Rec. 709 luminance coefficients.
      let luminance_coefficients = inputs
        .get(5)
        .unwrap_or_else(fn() {
          vec3(
            @math.color_management.get_luminance_coefficients(
              @math.Vector3::new(0.0, 0.0, 0.0),
              color_space=@math.LinearSRGBColorSpace,
            ),
          )
        })
      // NOTE: The ASC CDL v1.2 defines a [0, 1] clamp on the slope+offset term, and another on the
      // saturation term. Per the ACEScc specification and Filament, limits may be omitted to support
      // if negative inputs to the power expression are avoided. We use `max( in, 0.0 )`
      // on final output, but the lower limit may not be required in all cases.
      let luma = color.rgb().dot(vec3(luminance_coefficients))
      let v = max(color.rgb().mul(slope).add(offset), 0.0)
      let pv = v.pow(power)
      if_(v.r().greater_than(0.0), fn() { v.r().assign(pv.r()) }) |> ignore
      if_(v.g().greater_than(0.0), fn() { v.g().assign(pv.g()) }) |> ignore
      if_(v.b().greater_than(0.0), fn() { v.b().assign(pv.b()) }) |> ignore
      v.assign(luma.add(v.sub(luma).mul(saturation)).max(0))
      Some(vec4_of([v.rgb(), color.a()]))
    },
    layout=FnLayout::short(
      [
        ("color", "vec4"),
        ("slope", "vec3"),
        ("offset", "vec3"),
        ("power", "vec3"),
        ("saturation", "float"),
        ("luminanceCoefficients", "vec3"),
      ],
      return_="vec4",
      upstream="nodes/display/ColorAdjustment.js:cdl",
    ),
  )
})

///|
/// `posterize( source, steps )`: quantizes `source` to `steps` levels.
pub let posterize : Node = module_nodes(
  "nodes/display/ColorAdjustment.js:posterize",
  fn() {
    fn_(fn(inputs, _) {
      let source = inputs.get(0).unwrap()
      let steps = inputs.get(1).unwrap()
      Some(source.mul(steps).floor().div(steps))
    })
  },
)
