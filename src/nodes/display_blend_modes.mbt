// nodes/display/BlendModes.js

///|
/// `blendBurn( base, blend )`: color burn.
pub let blend_burn : Node = module_nodes(
  "nodes/display/BlendModes.js:blendBurn",
  fn() {
    fn_(
      fn(inputs, _) {
        let base = inputs.get(0).unwrap()
        let blend = inputs.get(1).unwrap()
        Some(min(1.0, base.one_minus().div(blend)).one_minus())
      },
      layout=FnLayout::short(
        [("base", "vec3"), ("blend", "vec3")],
        return_="vec3",
        upstream="nodes/display/BlendModes.js:blendBurn",
      ),
    )
  },
)

///|
/// `blendDodge( base, blend )`: color dodge.
pub let blend_dodge : Node = module_nodes(
  "nodes/display/BlendModes.js:blendDodge",
  fn() {
    fn_(
      fn(inputs, _) {
        let base = inputs.get(0).unwrap()
        let blend = inputs.get(1).unwrap()
        Some(min(base.div(blend.one_minus()), 1.0))
      },
      layout=FnLayout::short(
        [("base", "vec3"), ("blend", "vec3")],
        return_="vec3",
        upstream="nodes/display/BlendModes.js:blendDodge",
      ),
    )
  },
)

///|
/// `blendScreen( base, blend )`: screen.
pub let blend_screen : Node = module_nodes(
  "nodes/display/BlendModes.js:blendScreen",
  fn() {
    fn_(
      fn(inputs, _) {
        let base = inputs.get(0).unwrap()
        let blend = inputs.get(1).unwrap()
        Some(base.one_minus().mul(blend.one_minus()).one_minus())
      },
      layout=FnLayout::short(
        [("base", "vec3"), ("blend", "vec3")],
        return_="vec3",
        upstream="nodes/display/BlendModes.js:blendScreen",
      ),
    )
  },
)

///|
/// `blendOverlay( base, blend )`: overlay.
pub let blend_overlay : Node = module_nodes(
  "nodes/display/BlendModes.js:blendOverlay",
  fn() {
    fn_(
      fn(inputs, _) {
        let base = inputs.get(0).unwrap()
        let blend = inputs.get(1).unwrap()
        Some(
          mix(
            base.mul(2.0).mul(blend),
            base.one_minus().mul(2.0).mul(blend.one_minus()).one_minus(),
            step(0.5, base),
          ),
        )
      },
      layout=FnLayout::short(
        [("base", "vec3"), ("blend", "vec3")],
        return_="vec3",
        upstream="nodes/display/BlendModes.js:blendOverlay",
      ),
    )
  },
)

///|
/// `blendColor( base, blend )`: `blend` over `base` with alpha.
pub let blend_color : Node = module_nodes(
  "nodes/display/BlendModes.js:blendColor",
  fn() {
    fn_(
      fn(inputs, _) {
        let base = inputs.get(0).unwrap()
        let blend = inputs.get(1).unwrap()
        let out_alpha = blend.a().add(base.a().mul(blend.a().one_minus()))
        Some(
          vec4_of([
            blend
            .rgb()
            .mul(blend.a())
            .add(base.rgb().mul(base.a()).mul(blend.a().one_minus()))
            .div(out_alpha),
            out_alpha,
          ]),
        )
      },
      layout=FnLayout::short(
        [("base", "vec4"), ("blend", "vec4")],
        return_="vec4",
        upstream="nodes/display/BlendModes.js:blendColor",
      ),
    )
  },
)
