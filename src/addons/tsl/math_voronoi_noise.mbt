// examples/jsm/tsl/math/voronoiNoise.js

///|
priv struct VoronoiNoiseModule {
  hash2d : @nodes.Node
  voronoi2d : @nodes.Node
  hash3d : @nodes.Node
  voronoi3d : @nodes.Node
}

///|
fn voronoi_noise_cell_loop(name : String, body : (@nodes.Node) -> Unit) -> Unit {
  @nodes.loop_(
    [
      @nodes.loop_range(
        start=@nodes.int(-1),
        end=@nodes.int(1),
        name~,
        condition="<=",
      ),
    ],
    fn(inputs) { body(inputs.named(name).unwrap()) },
  )
}

///|
let math_voronoi_noise_module : AddonModule[VoronoiNoiseModule] = AddonModule::new(fn() {
    let hash2d = @nodes.fn_(
      fn(inputs, _) {
        let p = addon_arg(inputs, 0)
        Some(
          @nodes.fract(
            @nodes.sin(
              @nodes.vec2_of([
                @nodes.dot(p, @nodes.vec2_of([127.1, 311.7])),
                @nodes.dot(p, @nodes.vec2_of([269.5, 183.3])),
              ]),
            ).mul(18.5453),
          ),
        )
      },
      layout=addon_short_layout([("p", "vec2")], "vec2"),
    )
    let voronoi2d = @nodes.fn_(
      fn(inputs, _) {
        let p = addon_arg(inputs, 0)
        let time = addon_arg(inputs, 1)
        let n = p.floor().to_const()
        let f = p.fract().to_const()
        let min_dist = @nodes.float(8).to_var()
        voronoi_noise_cell_loop("x", fn(x) {
          voronoi_noise_cell_loop("y", fn(y) {
            let g = @nodes.vec2_of([@nodes.float(x), @nodes.float(y)]).to_const()
            let o = hash2d.call([n.add(g)]).to_const()
            let r = g
              .sub(f)
              .add(@nodes.sin(time.add(o.mul(@nodes.two_pi))).mul(0.5).add(0.5))
            min_dist.assign(@nodes.min(min_dist, @nodes.dot(r, r)))
          })
        })
        Some(min_dist)
      },
      layout=addon_short_layout([("p", "vec2"), ("time", "float")], "float"),
    )
    let hash3d = @nodes.fn_(
      fn(inputs, _) {
        let p = addon_arg(inputs, 0)
        Some(
          @nodes.fract(
            @nodes.sin(
              @nodes.vec3_of([
                @nodes.dot(p, @nodes.vec3_of([127.1, 311.7, 74.7])),
                @nodes.dot(p, @nodes.vec3_of([269.5, 183.3, 246.1])),
                @nodes.dot(p, @nodes.vec3_of([113.5, 271.9, 124.6])),
              ]),
            ).mul(18.5453),
          ),
        )
      },
      layout=addon_short_layout([("p", "vec3")], "vec3"),
    )
    let voronoi3d = @nodes.fn_(
      fn(inputs, _) {
        let p = addon_arg(inputs, 0)
        let time = addon_arg(inputs, 1)
        let n = p.floor().to_const()
        let f = p.fract().to_const()
        let min_dist = @nodes.float(8).to_var()
        voronoi_noise_cell_loop("x", fn(x) {
          voronoi_noise_cell_loop("y", fn(y) {
            voronoi_noise_cell_loop("z", fn(z) {
              let g = @nodes.vec3_of([
                @nodes.float(x),
                @nodes.float(y),
                @nodes.float(z),
              ]).to_const()
              let o = hash3d.call([n.add(g)]).to_const()
              let r = g
                .sub(f)
                .add(
                  @nodes.sin(time.add(o.mul(@nodes.two_pi))).mul(0.5).add(0.5),
                )
              min_dist.assign(@nodes.min(min_dist, @nodes.dot(r, r)))
            })
          })
        })
        Some(min_dist)
      },
      layout=addon_short_layout([("p", "vec3"), ("time", "float")], "float"),
    )
    { hash2d, voronoi2d, hash3d, voronoi3d, }
  },
)

///|
/// Evaluates voronoiNoise.js, as `import` does.
pub fn load_math_voronoi_noise() -> Unit {
  math_voronoi_noise_module.get() |> ignore
}

///|
/// `hash2d( p )`.
pub fn hash2d() -> @nodes.Node {
  math_voronoi_noise_module.get().hash2d
}

///|
/// `voronoi2d( p, time )`: distance to the nearest animated Voronoi cell center.
pub fn voronoi2d() -> @nodes.Node {
  math_voronoi_noise_module.get().voronoi2d
}

///|
/// `hash3d( p )`.
pub fn hash3d() -> @nodes.Node {
  math_voronoi_noise_module.get().hash3d
}

///|
/// `voronoi3d( p, time )`.
pub fn voronoi3d() -> @nodes.Node {
  math_voronoi_noise_module.get().voronoi3d
}
