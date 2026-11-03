// examples/jsm/tsl/math/curlNoise.js

///|
priv struct CurlNoiseModule {
  permute : @nodes.Node
  snoise : @nodes.Node
  snoise_vec3 : @nodes.Node
  curl_noise : @nodes.Node
}

///|
let math_curl_noise_module : AddonModule[CurlNoiseModule] = AddonModule::new(fn() {
  let permute = @nodes.fn_(
    fn(inputs, _) {
      let x = addon_arg(inputs, 0)
      Some(@nodes.mod(x.mul(x).mul(34.0).add(x), 289.0))
    },
    layout=addon_short_layout([("x", "vec4")], "vec4"),
  )
  let snoise = @nodes.fn_(
    fn(inputs, _) {
      let v = addon_arg(inputs, 0)
      let c = @nodes.div(1.0, @nodes.vec2_of([6, 3]))
      let d = @nodes.vec4_of([0, 0.5, 1, 2])
      let i = @nodes.floor(v.add(@nodes.dot(v, c.yyy())))
      let x0 = v.sub(i).add(@nodes.dot(i, c.xxx()))
      let g = @nodes.step(x0.yzx(), x0.xyz())
      let l = @nodes.sub(1.0, g)
      let i1 = @nodes.min(g.xyz(), l.zxy())
      let i2 = @nodes.max(g.xyz(), l.zxy())
      let x1 = x0.sub(i1).add(c.x())
      let x2 = x0.sub(i2).add(c.y())
      let x3 = x0.sub(d.yyy())
      i.assign(@nodes.mod(i, 289.0))
      let p = permute.call([
        permute
        .call([
          permute
          .call([i.z().add(@nodes.vec4_of([0.0, i1.z(), i2.z(), 1.0]))])
          .add(i.y())
          .add(@nodes.vec4_of([0.0, i1.y(), i2.y(), 1.0])),
        ])
        .add(i.x())
        .add(@nodes.vec4_of([0.0, i1.x(), i2.x(), 1.0])),
      ])
      let ns = @nodes.mul(0.142857142857, d.wyz()).sub(d.xzx())
      let j = p.sub(@nodes.mul(49.0, @nodes.floor(p.mul(ns.z()).mul(ns.z()))))
      let x_ = @nodes.floor(j.mul(ns.z()))
      let x = x_.mul(ns.x()).add(ns.yyyy())
      let y = @nodes.floor(j.sub(@nodes.mul(7.0, x_)))
        .mul(ns.x())
        .add(ns.yyyy())
      let h = @nodes.sub(1.0, @nodes.abs(x)).sub(@nodes.abs(y))
      let b0 = @nodes.vec4_of([x.xy(), y.xy()])
      let b1 = @nodes.vec4_of([x.zw(), y.zw()])
      let sh = @nodes.step(h, @nodes.vec4(0)).negate()
      let a0 = b0
        .xzyw()
        .add(@nodes.floor(b0).mul(2.0).add(1.0).xzyw().mul(sh.xxyy()))
      let a1 = b1
        .xzyw()
        .add(@nodes.floor(b1).mul(2.0).add(1.0).xzyw().mul(sh.zzww()))
      let p0 = @nodes.vec3_of([a0.xy(), h.x()])
      let p1 = @nodes.vec3_of([a0.zw(), h.y()])
      let p2 = @nodes.vec3_of([a1.xy(), h.z()])
      let p3 = @nodes.vec3_of([a1.zw(), h.w()])
      let norm = @nodes.inverse_sqrt(
        @nodes.vec4_of([
          @nodes.dot(p0, p0),
          @nodes.dot(p1, p1),
          @nodes.dot(p2, p2),
          @nodes.dot(p3, p3),
        ]),
      )
      p0.mul_assign(norm.x())
      p1.mul_assign(norm.y())
      p2.mul_assign(norm.z())
      p3.mul_assign(norm.w())
      let m = @nodes.max(
        @nodes.sub(
          0.6,
          @nodes.vec4_of([
            @nodes.dot(x0, x0),
            @nodes.dot(x1, x1),
            @nodes.dot(x2, x2),
            @nodes.dot(x3, x3),
          ]),
        ),
        0.0,
      )
      Some(
        @nodes.add(
          0.5,
          @nodes.mul(
            12.0,
            @nodes.dot(
              m.mul(m).mul(m),
              @nodes.vec4_of([
                @nodes.dot(p0, x0),
                @nodes.dot(p1, x1),
                @nodes.dot(p2, x2),
                @nodes.dot(p3, x3),
              ]),
            ),
          ),
        ),
      )
    },
    layout=addon_short_layout([("v", "vec3")], "float"),
  )
  let snoise_vec3 = @nodes.fn_(
    fn(inputs, _) {
      let x = addon_arg(inputs, 0)
      Some(
        @nodes.vec3_of([
          snoise.call([@nodes.vec3(x).mul(2.0).sub(1.0)]),
          snoise
          .call([
            @nodes.vec3_of([x.y().sub(19.1), x.z().add(33.4), x.x().add(47.2)]),
          ])
          .mul(2.0)
          .sub(1.0),
          snoise.call([
            @nodes.vec3_of([x.z().add(74.2), x.x().sub(124.5), x.y().add(99.4)])
            .mul(2.0)
            .sub(1.0),
          ]),
        ]),
      )
    },
    layout=addon_short_layout([("x", "vec3")], "vec3"),
  )
  let curl_noise = @nodes.fn_(
    fn(inputs, _) {
      let p = addon_arg(inputs, 0)
      let e = @nodes.float(0.1)
      let dx = @nodes.vec3_of([e, 0.0, 0.0])
      let dy = @nodes.vec3_of([0.0, e, 0.0])
      let dz = @nodes.vec3_of([0.0, 0.0, e])
      let p_x0 = snoise_vec3.call([p.sub(dx)])
      let p_x1 = snoise_vec3.call([p.add(dx)])
      let p_y0 = snoise_vec3.call([p.sub(dy)])
      let p_y1 = snoise_vec3.call([p.add(dy)])
      let p_z0 = snoise_vec3.call([p.sub(dz)])
      let p_z1 = snoise_vec3.call([p.add(dz)])
      let x = p_y1.z().sub(p_y0.z()).sub(p_z1.y()).add(p_z0.y())
      let y = p_z1.x().sub(p_z0.x()).sub(p_x1.z()).add(p_x0.z())
      let z = p_x1.y().sub(p_x0.y()).sub(p_y1.x()).add(p_y0.x())
      let divisor = @nodes.div(1.0, @nodes.mul(2.0, e))
      Some(@nodes.vec3_of([x, y, z]).mul(divisor))
    },
    layout=addon_short_layout([("p", "vec3")], "vec3"),
  )
  { permute, snoise, snoise_vec3, curl_noise, }
})

///|
/// Evaluates curlNoise.js, as `import` does.
pub fn load_math_curl_noise() -> Unit {
  math_curl_noise_module.get() |> ignore
}

///|
/// `permute( x )` (vec4).
pub fn permute() -> @nodes.Node {
  math_curl_noise_module.get().permute
}

///|
/// `snoise( v )`: 3D simplex noise in [0, 1].
pub fn snoise() -> @nodes.Node {
  math_curl_noise_module.get().snoise
}

///|
/// `snoiseVec3( x )`: three decorrelated simplex noises.
pub fn snoise_vec3() -> @nodes.Node {
  math_curl_noise_module.get().snoise_vec3
}

///|
/// `curlNoise( p )`: the curl of `snoiseVec3`.
pub fn curl_noise() -> @nodes.Node {
  math_curl_noise_module.get().curl_noise
}
