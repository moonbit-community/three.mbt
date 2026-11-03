// nodes/functions/BSDF/LTC.js: rect area lights with linearly transformed cosines
// (Heitz, Dupuy, Hill and Neubelt).

///|
/// `LTC_Uv( { N, V, roughness } )`.
pub let ltc_uv : Node = module_nodes("nodes/functions/BSDF/LTC.js:LTC_Uv", fn() {
  fn_(
    fn(inputs, _) {
      let n = inputs.named("N").unwrap()
      let v = inputs.named("V").unwrap()
      let roughness = inputs.named("roughness").unwrap()
      let lut_size = 64.0
      let lut_scale = (lut_size - 1.0) / lut_size
      let lut_bias = 0.5 / lut_size
      let dot_nv = n.dot(v).saturate()
      let uv = vec2_of([roughness, dot_nv.one_minus().sqrt()])
      uv.assign(uv.mul(lut_scale).add(lut_bias))
      Some(uv)
    },
    layout=FnLayout::short(
      [("N", "vec3"), ("V", "vec3"), ("roughness", "float")],
      return_="vec2",
      upstream="nodes/functions/BSDF/LTC.js:LTC_Uv",
    ),
  )
})

///|
/// `LTC_ClippedSphereFormFactor( { f } )`.
let ltc_clipped_sphere_form_factor : Node = module_nodes(
  "nodes/functions/BSDF/LTC.js:LTC_ClippedSphereFormFactor",
  fn() {
    fn_(
      fn(inputs, _) {
        let f = inputs.named("f").unwrap()
        let l = f.length()
        Some(max(l.mul(l).add(f.z()).div(l.add(1.0)), 0))
      },
      layout=FnLayout::short(
        [("f", "vec3")],
        return_="float",
        upstream="nodes/functions/BSDF/LTC.js:LTC_ClippedSphereFormFactor",
      ),
    )
  },
)

///|
/// `LTC_EdgeVectorFormFactor( { v1, v2 } )`.
let ltc_edge_vector_form_factor : Node = module_nodes(
  "nodes/functions/BSDF/LTC.js:LTC_EdgeVectorFormFactor",
  fn() {
    fn_(
      fn(inputs, _) {
        let v1 = inputs.named("v1").unwrap()
        let v2 = inputs.named("v2").unwrap()
        let x = v1.dot(v2)
        let y = x.abs().to_var()
        let a = y.mul(0.0145206).add(0.4965155).mul(y).add(0.8543985).to_var()
        let b = y.add(4.1616724).mul(y).add(3.4175940).to_var()
        let v = a.div(b)
        let theta_sintheta = x
          .greater_than(0.0)
          .select(
            v,
            else_node=max(x.mul(x).one_minus(), 1.0e-7)
              .inverse_sqrt()
              .mul(0.5)
              .sub(v),
          )
        Some(v1.cross(v2).mul(theta_sintheta))
      },
      layout=FnLayout::short(
        [("v1", "vec3"), ("v2", "vec3")],
        return_="vec3",
        upstream="nodes/functions/BSDF/LTC.js:LTC_EdgeVectorFormFactor",
      ),
    )
  },
)

///|
/// The four edge form factors of a projected rect.
fn ltc_vector_form_factor(
  coords0 : Node,
  coords1 : Node,
  coords2 : Node,
  coords3 : Node,
) -> Node {
  let vector_form_factor = vec3(0).to_var()
  vector_form_factor.add_assign(
    ltc_edge_vector_form_factor.call_named({ "v1": coords0, "v2": coords1 }),
  )
  vector_form_factor.add_assign(
    ltc_edge_vector_form_factor.call_named({ "v1": coords1, "v2": coords2 }),
  )
  vector_form_factor.add_assign(
    ltc_edge_vector_form_factor.call_named({ "v1": coords2, "v2": coords3 }),
  )
  vector_form_factor.add_assign(
    ltc_edge_vector_form_factor.call_named({ "v1": coords3, "v2": coords0 }),
  )
  vector_form_factor
}

///|
/// `LTC_Evaluate( { N, V, P, mInv, p0, p1, p2, p3 } )`.
pub let ltc_evaluate : Node = module_nodes(
  "nodes/functions/BSDF/LTC.js:LTC_Evaluate",
  fn() {
    fn_(
      fn(inputs, _) {
        let n = inputs.named("N").unwrap()
        let v = inputs.named("V").unwrap()
        let p = inputs.named("P").unwrap()
        let m_inv = inputs.named("mInv").unwrap()
        let p0 = inputs.named("p0").unwrap()
        let p1 = inputs.named("p1").unwrap()
        let p2 = inputs.named("p2").unwrap()
        let p3 = inputs.named("p3").unwrap()
        let v1 = p1.sub(p0).to_var()
        let v2 = p3.sub(p0).to_var()
        let light_normal = v1.cross(v2)
        let result = vec3_of([]).to_var()
        if_(light_normal.dot(p.sub(p0)).greater_than_equal(0.0), fn() {
          let t1 = v.sub(n.mul(v.dot(n))).normalize()
          let t2 = n.cross(t1).negate()
          let mat = m_inv.mul(mat3_of([t1, t2, n]).transpose()).to_var()
          let coords0 = mat.mul(p0.sub(p)).normalize().to_var()
          let coords1 = mat.mul(p1.sub(p)).normalize().to_var()
          let coords2 = mat.mul(p2.sub(p)).normalize().to_var()
          let coords3 = mat.mul(p3.sub(p)).normalize().to_var()
          let vector_form_factor = ltc_vector_form_factor(
            coords0, coords1, coords2, coords3,
          )
          result.assign(
            vec3(
              ltc_clipped_sphere_form_factor.call_named({
                "f": vector_form_factor,
              }),
            ),
          )
        })
        |> ignore
        Some(result)
      },
      layout=FnLayout::short(
        [
          ("N", "vec3"),
          ("V", "vec3"),
          ("P", "vec3"),
          ("mInv", "mat3"),
          ("p0", "vec3"),
          ("p1", "vec3"),
          ("p2", "vec3"),
          ("p3", "vec3"),
        ],
        return_="vec3",
        upstream="nodes/functions/BSDF/LTC.js:LTC_Evaluate",
      ),
    )
  },
)

///|
/// `LTC_Evaluate_Volume( { P, p0, p1, p2, p3 } )`.
pub let ltc_evaluate_volume : Node = module_nodes(
  "nodes/functions/BSDF/LTC.js:LTC_Evaluate_Volume",
  fn() {
    fn_(
      fn(inputs, _) {
        let p = inputs.named("P").unwrap()
        let p0 = inputs.named("p0").unwrap()
        let p1 = inputs.named("p1").unwrap()
        let p2 = inputs.named("p2").unwrap()
        let p3 = inputs.named("p3").unwrap()
        let v1 = p1.sub(p0).to_var()
        let v2 = p3.sub(p0).to_var()
        let light_normal = v1.cross(v2)
        let result = vec3_of([]).to_var()
        if_(light_normal.dot(p.sub(p0)).greater_than_equal(0.0), fn() {
          let coords0 = p0.sub(p).normalize().to_var()
          let coords1 = p1.sub(p).normalize().to_var()
          let coords2 = p2.sub(p).normalize().to_var()
          let coords3 = p3.sub(p).normalize().to_var()
          let vector_form_factor = ltc_vector_form_factor(
            coords0, coords1, coords2, coords3,
          )
          result.assign(
            vec3(
              ltc_clipped_sphere_form_factor.call_named({
                "f": vector_form_factor.abs(),
              }),
            ),
          )
        })
        |> ignore
        Some(result)
      },
      layout=FnLayout::short(
        [
          ("P", "vec3"),
          ("p0", "vec3"),
          ("p1", "vec3"),
          ("p2", "vec3"),
          ("p3", "vec3"),
        ],
        return_="vec3",
        upstream="nodes/functions/BSDF/LTC.js:LTC_Evaluate_Volume",
      ),
    )
  },
)
