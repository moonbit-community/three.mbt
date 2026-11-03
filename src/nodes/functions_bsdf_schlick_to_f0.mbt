// nodes/functions/BSDF/Schlick_to_F0.js

///|
/// `Schlick_to_F0( { f, f90, dotVH } )`.
pub let schlick_to_f0 : Node = module_nodes(
  "nodes/functions/BSDF/Schlick_to_F0.js:Schlick_to_F0",
  fn() {
    fn_(
      fn(inputs, _) {
        let f = inputs.named("f").unwrap()
        let f90 = inputs.named("f90").unwrap()
        let dot_vh = inputs.named("dotVH").unwrap()
        let x = dot_vh.one_minus().saturate()
        let x2 = x.mul(x)
        let x5 = x.mul_of([x2, x2]).clamp(low=0, high=0.9999)
        Some(f.sub(vec3(f90).mul(x5)).div(x5.one_minus()))
      },
      layout=FnLayout::short(
        [("f", "vec3"), ("f90", "float"), ("dotVH", "float")],
        return_="vec3",
        upstream="nodes/functions/BSDF/Schlick_to_F0.js:Schlick_to_F0",
      ),
    )
  },
)
