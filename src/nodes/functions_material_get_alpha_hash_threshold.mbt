// nodes/functions/material/getAlphaHashThreshold.js

///|
let get_alpha_hash_threshold_scale : Double = 0.05

///|
/// `hash2D( value )`.
let get_alpha_hash_threshold_hash2d : Node = module_nodes(
  "nodes/functions/material/getAlphaHashThreshold.js:hash2D",
  fn() {
    fn_(
      fn(inputs, _) {
        let value = inputs.get(0).unwrap()
        Some(
          fract(
            mul(1.0e4, sin(mul(17.0, value.x()).add(mul(0.1, value.y())))).mul(
              add(0.1, abs(sin(mul(13.0, value.y()).add(value.x())))),
            ),
          ),
        )
      },
      layout=FnLayout::short(
        [("value", "vec2")],
        return_="float",
        upstream="nodes/functions/material/getAlphaHashThreshold.js:hash2D",
      ),
    )
  },
)

///|
/// `hash3D( value )`.
let get_alpha_hash_threshold_hash3d : Node = module_nodes(
  "nodes/functions/material/getAlphaHashThreshold.js:hash3D",
  fn() {
    fn_(
      fn(inputs, _) {
        let value = inputs.get(0).unwrap()
        Some(
          get_alpha_hash_threshold_hash2d.call([
            vec2_of([
              get_alpha_hash_threshold_hash2d.call([value.xy()]),
              value.z(),
            ]),
          ]),
        )
      },
      layout=FnLayout::short(
        [("value", "vec3")],
        return_="float",
        upstream="nodes/functions/material/getAlphaHashThreshold.js:hash3D",
      ),
    )
  },
)

///|
/// `getAlphaHashThreshold( position )`: the alpha hashing threshold (Wyman and
/// McGuire, "Hashed Alpha Testing").
pub let get_alpha_hash_threshold : Node = module_nodes(
  "nodes/functions/material/getAlphaHashThreshold.js:getAlphaHashThreshold",
  fn() {
    fn_(
      fn(inputs, _) {
        let position = inputs.get(0).unwrap()
        let max_deriv = max(
          length(d_fdx(position.xyz())),
          length(d_fdy(position.xyz())),
        )
        let pix_scale = float(1)
          .div(float(get_alpha_hash_threshold_scale).mul(max_deriv))
          .to_var(name="pixScale")
        let pix_scales = vec2_of([
          exp2(floor(log2(pix_scale))),
          exp2(ceil(log2(pix_scale))),
        ])
        let alpha = vec2_of([
          get_alpha_hash_threshold_hash3d.call([
            floor(pix_scales.x().mul(position.xyz())),
          ]),
          get_alpha_hash_threshold_hash3d.call([
            floor(pix_scales.y().mul(position.xyz())),
          ]),
        ])
        let lerp_factor = fract(log2(pix_scale))
        let x = add(
          mul(lerp_factor.one_minus(), alpha.x()),
          mul(lerp_factor, alpha.y()),
        )
        let a = min(lerp_factor, lerp_factor.one_minus())
        let cases = vec3_of([
          x.mul(x).div(mul(2.0, a).mul(sub(1.0, a))),
          x.sub(mul(0.5, a)).div(sub(1.0, a)),
          sub(
            1.0,
            sub(1.0, x).mul(sub(1.0, x)).div(mul(2.0, a).mul(sub(1.0, a))),
          ),
        ])
        let threshold = x
          .less_than(a.one_minus())
          .select(
            x.less_than(a).select(cases.x(), else_node=cases.y()),
            else_node=cases.z(),
          )
        Some(clamp(threshold, low=1.0e-6, high=1.0))
      },
      layout=FnLayout::short(
        [("position", "vec3")],
        return_="float",
        upstream="nodes/functions/material/getAlphaHashThreshold.js:getAlphaHashThreshold",
      ),
    )
  },
)
