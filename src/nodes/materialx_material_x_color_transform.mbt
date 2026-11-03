// nodes/materialx/MaterialXColorTransform.js

///|
/// `mx_srgb_texture_to_lin_rec709`.
pub let mx_srgb_texture_to_lin_rec709 : Node = module_nodes(
  "nodes/materialx/MaterialXColorTransform.js:mx_srgb_texture_to_lin_rec709",
  fn() {
    fn_(
      fn(inputs, _) {
        let color_immutable = inputs.get(0).unwrap()
        let color = vec3(color_immutable).to_var()
        let is_above = bvec3(greater_than(color, vec3(0.04045))).to_var()
        let lin_seg = vec3(color.div(12.92)).to_var()
        let pow_seg = vec3(
          pow(max(color.add(vec3(0.055)), vec3(0)).div(1.055), vec3(2.4)),
        ).to_var()
        Some(mix(lin_seg, pow_seg, is_above))
      },
      layout=FnLayout::short(
        [("color", "vec3")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXColorTransform.js:mx_srgb_texture_to_lin_rec709",
      ),
    )
  },
)
