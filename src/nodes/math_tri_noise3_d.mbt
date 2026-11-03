// nodes/math/TriNoise3D.js: a 3D noise from triangle waves
// (https://github.com/cabbibo/glsl-tri-noise-3d).

///|
let _tri_noise_tri : Node = module_nodes("nodes/math/TriNoise3D.js:tri", fn() {
  fn_(
    fn(inputs, _) {
      let x = operator_node_input(inputs, 0)
      Some(x.fract().sub(0.5).abs())
    },
    layout=FnLayout::short(
      [("x", "float")],
      return_="float",
      upstream="nodes/math/TriNoise3D.js:tri",
    ),
  )
})

///|
fn tri_noise_tri(x : Node) -> Node {
  _tri_noise_tri.call([x])
}

///|
let _tri_noise_tri3 : Node = module_nodes("nodes/math/TriNoise3D.js:tri3", fn() {
  fn_(
    fn(inputs, _) {
      let p = operator_node_input(inputs, 0)
      Some(
        vec3_of([
          tri_noise_tri(p.z().add(tri_noise_tri(p.y().mul(1.0)))),
          tri_noise_tri(p.z().add(tri_noise_tri(p.x().mul(1.0)))),
          tri_noise_tri(p.y().add(tri_noise_tri(p.x().mul(1.0)))),
        ]),
      )
    },
    layout=FnLayout::short(
      [("p", "vec3")],
      return_="vec3",
      upstream="nodes/math/TriNoise3D.js:tri3",
    ),
  )
})

///|
/// `triNoise3D( position, speed, time )`: a 3D noise of `position` animated by `time`.
pub let tri_noise3d : Node = module_nodes(
  "nodes/math/TriNoise3D.js:triNoise3D",
  fn() {
    fn_(
      fn(inputs, _) {
        let position = operator_node_input(inputs, 0)
        let speed = operator_node_input(inputs, 1)
        let time = operator_node_input(inputs, 2)
        let p = vec3(position).to_var()
        let z = float(1.4).to_var()
        let rz = float(0.0).to_var()
        let bp = vec3(p).to_var()
        loop_(
          [
            loop_range(
              start=float(0.0),
              end=float(3.0),
              type_="float",
              condition="<=",
            ),
          ],
          fn(_) {
            let dg = vec3(_tri_noise_tri3.call([bp.mul(2.0)])).to_var()
            p.add_assign(dg.add(time.mul(float(0.1).mul(speed))))
            bp.mul_assign(1.8)
            z.mul_assign(1.5)
            p.mul_assign(1.2)
            let t = float(
              tri_noise_tri(
                p.z().add(tri_noise_tri(p.x().add(tri_noise_tri(p.y())))),
              ),
            ).to_var()
            rz.add_assign(t.div(z))
            bp.add_assign(0.14)
          },
        )
        Some(rz)
      },
      layout=FnLayout::short(
        [("position", "vec3"), ("speed", "float"), ("time", "float")],
        return_="float",
        upstream="nodes/math/TriNoise3D.js:triNoise3D",
      ),
    )
  },
)
