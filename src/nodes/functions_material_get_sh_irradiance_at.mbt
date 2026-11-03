// nodes/functions/material/getShIrradianceAt.js

///|
/// `getShIrradianceAt( normal, shCoefficients )`: irradiance from spherical harmonics
/// (the normal has unit length).
pub let get_sh_irradiance_at : Node = module_nodes(
  "nodes/functions/material/getShIrradianceAt.js:getShIrradianceAt",
  fn() {
    fn_(fn(inputs, _) {
      let normal = inputs.get(0).unwrap()
      let sh_coefficients = inputs.get(1).unwrap()
      let x = normal.x()
      let y = normal.y()
      let z = normal.z()
      let mut result = sh_coefficients.element(0).mul(0.886227)
      result = result.add(sh_coefficients.element(1).mul(2.0 * 0.511664).mul(y))
      result = result.add(sh_coefficients.element(2).mul(2.0 * 0.511664).mul(z))
      result = result.add(sh_coefficients.element(3).mul(2.0 * 0.511664).mul(x))
      result = result.add(
        sh_coefficients.element(4).mul(2.0 * 0.429043).mul(x).mul(y),
      )
      result = result.add(
        sh_coefficients.element(5).mul(2.0 * 0.429043).mul(y).mul(z),
      )
      result = result.add(
        sh_coefficients.element(6).mul(z.mul(z).mul(0.743125).sub(0.247708)),
      )
      result = result.add(
        sh_coefficients.element(7).mul(2.0 * 0.429043).mul(x).mul(z),
      )
      result = result.add(
        sh_coefficients.element(8).mul(0.429043).mul(mul(x, x).sub(mul(y, y))),
      )
      Some(result)
    })
  },
)
