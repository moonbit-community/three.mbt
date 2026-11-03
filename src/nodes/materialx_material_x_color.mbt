// nodes/materialx/MaterialXColor.js

///|
/// `mx_hsvtorgb`.
pub let mx_hsvtorgb : Node = module_nodes(
  "nodes/materialx/MaterialXColor.js:mx_hsvtorgb",
  fn() {
    fn_(
      fn(inputs, _) {
        let hsv = inputs.get(0).unwrap()
        let s = hsv.y()
        let v = hsv.z()
        let result = vec3_of([]).to_var()
        if_(s.less_than(0.0001), fn() { result.assign(vec3_of([v, v, v])) }).else_(fn() {
            let mut h = hsv.x()
            h = h.sub(floor(h)).mul(6).to_var()
            let hi = int(trunc(h))
            let f = h.sub(float(hi))
            let p = v.mul(s.one_minus())
            let q = v.mul(s.mul(f).one_minus())
            let t = v.mul(s.mul(f.one_minus()).one_minus())
            if_(hi.equal(int(0)), fn() { result.assign(vec3_of([v, t, p])) })
            .else_if(hi.equal(int(1)), fn() {
              result.assign(vec3_of([q, v, p]))
            })
            .else_if(hi.equal(int(2)), fn() {
              result.assign(vec3_of([p, v, t]))
            })
            .else_if(hi.equal(int(3)), fn() {
              result.assign(vec3_of([p, q, v]))
            })
            .else_if(hi.equal(int(4)), fn() {
              result.assign(vec3_of([t, p, v]))
            })
            .else_(fn() { result.assign(vec3_of([v, p, q])) })
          },
        )
        Some(result)
      },
      layout=FnLayout::short(
        [("hsv", "vec3")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXColor.js:mx_hsvtorgb",
      ),
    )
  },
)

///|
/// `mx_rgbtohsv`.
pub let mx_rgbtohsv : Node = module_nodes(
  "nodes/materialx/MaterialXColor.js:mx_rgbtohsv",
  fn() {
    fn_(
      fn(inputs, _) {
        let c_immutable = inputs.get(0).unwrap()
        let c = vec3(c_immutable).to_var()
        let r = float(c.x()).to_var()
        let g = float(c.y()).to_var()
        let b = float(c.z()).to_var()
        let mincomp = float(min(r, min(g, b))).to_var()
        let maxcomp = float(max(r, max(g, b))).to_var()
        let delta = float(maxcomp.sub(mincomp)).to_var()
        let h = float_of([]).to_var()
        let s = float_of([]).to_var()
        let v = float_of([]).to_var()
        v.assign(maxcomp)
        if_(maxcomp.greater_than(0), fn() { s.assign(delta.div(maxcomp)) }).else_(fn() {
            s.assign(0)
          },
        )
        if_(s.less_than_equal(0), fn() { h.assign(0) }).else_(fn() {
          if_(r.greater_than_equal(maxcomp), fn() {
            h.assign(g.sub(b).div(delta))
          })
          .else_if(g.greater_than_equal(maxcomp), fn() {
            h.assign(add(2, b.sub(r).div(delta)))
          })
          .else_(fn() { h.assign(add(4, r.sub(g).div(delta))) })
          h.mul_assign(0.16666666666666666)
          if_(h.less_than(0), fn() { h.add_assign(1) }) |> ignore
        })
        Some(vec3_of([h, s, v]))
      },
      layout=FnLayout::short(
        [("c", "vec3")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXColor.js:mx_rgbtohsv",
      ),
    )
  },
)
