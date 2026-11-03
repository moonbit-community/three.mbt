// A tank of liquid simulated with MLS-MPM on the GPU, ported from upstream's
// `webgpu_compute_particles_fluid` example to MoonBit against the port's WebGPURenderer.
// Five TSL compute kernels run every frame: clear the grid, scatter particle momentum
// and stress to it with fixed-point atomics (two passes), update the grid, and gather the
// grid velocities back to the particles. On top of upstream's example: the tank tilts back
// and forth (gravity rotates with it), fast-moving water turns to foam white, and the
// mouse pushes the liquid in the tank's own frame.

///|
/// Base URL of the shared assets (models, textures, decoders); the page sets it from
/// examples/assets.js before `start`.
let assets_base : Ref[String] = { val: "../../.repos/three.js/examples/" }

///|
pub fn set_assets(base : String) -> Unit {
  assets_base.val = base
}

///|
const MAX_PARTICLES : Int32 = 8192 * 8

///|
const GRID : Int32 = 64

///|
const WORKGROUP : Int32 = 64

///|
const FIXED_POINT : Double = 1.0e7

///|
struct App {
  renderer : @nodes.Renderer
  camera : @core.Object3D
}

///|
let app : Ref[App?] = { val: None, }

///|
/// Tilt amplitude in radians (0 keeps the tank level) and the latest pointer in NDC.
let tilt_amplitude : Ref[Double] = { val: 0.32, }

///|
let pointer_ndc : Ref[(Double, Double)?] = { val: None, }

///|
let grid_size_u : @nodes.Node = @nodes.uniform(
  @math.Vector3::new(GRID.to_double(), GRID.to_double(), GRID.to_double()),
)

///|
let stiffness_u : @nodes.Node = @nodes.uniform(50.0)

///|
let rest_density_u : @nodes.Node = @nodes.uniform(1.5)

///|
let viscosity_u : @nodes.Node = @nodes.uniform(0.1)

///|
let dt_u : @nodes.Node = @nodes.uniform(1.0 / 60.0)

///|
let gravity_u : @nodes.Node = @nodes.uniform(
  @math.Vector3::new(0.0, -(9.81 * 9.81), 0.0),
)

///|
let mouse_ray_origin_u : @nodes.Node = @nodes.uniform(
  @math.Vector3::new(0.0, 0.0, 0.0),
)

///|
let mouse_ray_direction_u : @nodes.Node = @nodes.uniform(
  @math.Vector3::new(0.0, 0.0, 0.0),
)

///|
let mouse_force_u : @nodes.Node = @nodes.uniform(
  @math.Vector3::new(0.0, 0.0, 0.0),
)

///|
/// WebGPU only has integer atomics, so grid sums use fixed point.
fn encode_fixed_point(f : @nodes.Node) -> @nodes.Node {
  @nodes.int(f.mul(FIXED_POINT))
}

///|
fn decode_fixed_point(i : @nodes.Node) -> @nodes.Node {
  @nodes.float(i).div(FIXED_POINT)
}

///|
/// `for gx, gy, gz in 0..<3`: the 27 grid cells around a particle.
fn loop3(body : (@nodes.Node, @nodes.Node, @nodes.Node) -> Unit) -> Unit {
  let range = fn(name) {
    @nodes.loop_range(start=0, end=3, type_="int", name~, condition="<")
  }
  @nodes.loop_([range("gx")], fn(gx) {
    @nodes.loop_([range("gy")], fn(gy) {
      @nodes.loop_([range("gz")], fn(gz) {
        body(
          gx.named("gx").unwrap(),
          gy.named("gy").unwrap(),
          gz.named("gz").unwrap(),
        )
      })
    })
  })
}

///|
/// Quadratic B-spline weights of a particle at `grid_position` and its base cell.
fn kernel_weights(grid_position : @nodes.Node) -> (@nodes.Node, @nodes.Node) {
  let cell_index = @nodes.ivec3(grid_position).sub(1).to_const(name="cellIndex")
  let cell_diff = grid_position.fract().sub(0.5).to_const(name="cellDiff")
  let half = @nodes.float(0.5)
  let w0 = half.mul(half.sub(cell_diff)).mul(half.sub(cell_diff))
  let w1 = @nodes.float(0.75).sub(cell_diff.mul(cell_diff))
  let w2 = half.mul(half.add(cell_diff)).mul(half.add(cell_diff))
  (cell_index, @nodes.array([w0, w1, w2]).to_const(name="weights"))
}

///|
fn cell_weight(
  weights : @nodes.Node,
  gx : @nodes.Node,
  gy : @nodes.Node,
  gz : @nodes.Node,
) -> @nodes.Node {
  weights
  .element(gx)
  .x()
  .mul(weights.element(gy).y())
  .mul(weights.element(gz).z())
}

///|
fn cell_pointer(cell_x : @nodes.Node) -> @nodes.Node {
  cell_x
  .x()
  .mul(@nodes.int(GRID * GRID))
  .add(cell_x.y().mul(@nodes.int(GRID)))
  .add(cell_x.z())
  .to_const()
}

///|
/// Pushes a position back inside a rounded box centred in the unit cube.
fn clamp_to_rounded_box(
  pos : @nodes.Node,
  box : @nodes.Node,
  radius : @nodes.Node,
) -> @nodes.Node {
  let result = pos.sub(0.5).to_var()
  let pp = @nodes.step(box, result.abs()).mul(
    result.add(box.negate().mul(result.sign())),
  )
  let pp_len = pp.length().to_var()
  let dist = pp_len.sub(radius)
  @nodes.if_(dist.greater_than(0.0), fn() {
    result.sub_assign(pp.normalize().mul(dist).mul(1.3))
  })
  |> ignore
  result.add_assign(0.5)
  result
}

///|
/// The particle and grid buffers plus the seeding and the five simulation kernels.
struct Simulation {
  particles : @nodes.Node
  seed : @nodes.Node
  kernels : Array[@nodes.Node]
}

///|
fn simulation() -> Simulation {
  let particle_struct = @nodes.struct_([
    @nodes.StructMember::new("position", "vec3"),
    @nodes.StructMember::new("velocity", "vec3"),
    @nodes.StructMember::new("C", "mat3"),
  ])
  let particles = @nodes.instanced_array(
    MAX_PARTICLES,
    type_=particle_struct.node,
  )
  let cell_count = GRID * GRID * GRID
  let cell_struct = @nodes.struct_([
    @nodes.StructMember::new("x", "int", atomic_=true),
    @nodes.StructMember::new("y", "int", atomic_=true),
    @nodes.StructMember::new("z", "int", atomic_=true),
    @nodes.StructMember::new("mass", "int", atomic_=true),
  ])
  let cells = @nodes.instanced_array(cell_count, type_=cell_struct.node)
  let cells_float = @nodes.instanced_array(cell_count, type_="vec4")
  let particle = fn() { particles.element(@nodes.instance_index) }

  // Upstream seeds with Math.random on the CPU; here a kernel hashes the index into the
  // same [0.1, 0.9]^3 cube.
  let seed = @nodes.fn_(fn(_, _) {
      let rand = fn(salt : Int32) {
        @nodes.hash_tsl
        .call([@nodes.instance_index.add(salt)])
        .mul(0.8)
        .add(0.1)
      }
      particle()
      .get("position")
      .assign(@nodes.vec3_of([rand(0), rand(7919), rand(104729)]))
      None
    })
    .call([])
    .compute(MAX_PARTICLES, workgroup_size=[WORKGROUP, 1, 1])

  // 1. clear the grid
  let clear_grid = @nodes.fn_(fn(_, _) {
      let cell = cells.element(@nodes.instance_index)
      for field in ["x", "y", "z", "mass"] {
        @nodes.atomic_store(cell.get(field), 0) |> ignore
      }
      None
    })
    .call([])
    .compute(cell_count)
    .set_name("clearGridKernel")

  // 2. particle to grid: mass and momentum (APIC: velocity plus the affine term C)
  let p2g1 = @nodes.fn_(fn(_, _) {
      let position = particle()
        .get("position")
        .to_const(name="particlePosition")
      let velocity = particle()
        .get("velocity")
        .to_const(name="particleVelocity")
      let c = particle().get("C").to_const(name="C")
      let grid_position = position.mul(grid_size_u).to_var()
      let (cell_index, weights) = kernel_weights(grid_position)
      loop3(fn(gx, gy, gz) {
        let weight = cell_weight(weights, gx, gy, gz)
        let cell_x = cell_index.add(@nodes.ivec3_of([gx, gy, gz])).to_const()
        let cell_dist = @nodes.vec3(cell_x)
          .add(0.5)
          .sub(grid_position)
          .to_const(name="cellDist")
        let q = c.mul(cell_dist)
        let mass_contrib = weight
        let vel_contrib = mass_contrib
          .mul(velocity.add(q))
          .to_const(name="velContrib")
        let cell = cells.element(cell_pointer(cell_x))
        @nodes.atomic_add(cell.get("x"), encode_fixed_point(vel_contrib.x()))
        |> ignore
        @nodes.atomic_add(cell.get("y"), encode_fixed_point(vel_contrib.y()))
        |> ignore
        @nodes.atomic_add(cell.get("z"), encode_fixed_point(vel_contrib.z()))
        |> ignore
        @nodes.atomic_add(cell.get("mass"), encode_fixed_point(mass_contrib))
        |> ignore
      })
      None
    })
    .call([])
    .compute(MAX_PARTICLES, workgroup_size=[WORKGROUP, 1, 1])
    .set_name("p2g1Kernel")

  // 3. particle to grid: pressure and viscous stress from the local density
  let p2g2 = @nodes.fn_(fn(_, _) {
      let position = particle()
        .get("position")
        .to_const(name="particlePosition")
      let grid_position = position.mul(grid_size_u).to_var()
      let (cell_index, weights) = kernel_weights(grid_position)
      let density = @nodes.float(0).to_var(name="density")
      loop3(fn(gx, gy, gz) {
        let weight = cell_weight(weights, gx, gy, gz)
        let cell_x = cell_index.add(@nodes.ivec3_of([gx, gy, gz])).to_const()
        let cell = cells.element(cell_pointer(cell_x))
        let mass = decode_fixed_point(@nodes.atomic_load(cell.get("mass")))
        density.add_assign(mass.mul(weight))
      })
      let volume = @nodes.float(1).div(density)
      let pressure = @nodes.max(
        0.0,
        @nodes.pow(density.div(rest_density_u), 5.0).sub(1).mul(stiffness_u),
      ).to_const(name="pressure")
      let stress = @nodes.mat3_of([
        pressure.negate(),
        0,
        0,
        0,
        pressure.negate(),
        0,
        0,
        0,
        pressure.negate(),
      ]).to_var(name="stress")
      let dudv = particle().get("C").to_const(name="C")
      let strain = dudv.add(dudv.transpose())
      stress.add_assign(strain.mul(viscosity_u))
      let eq16_term0 = volume.mul(-4).mul(stress).mul(dt_u)
      loop3(fn(gx, gy, gz) {
        let weight = cell_weight(weights, gx, gy, gz)
        let cell_x = cell_index.add(@nodes.ivec3_of([gx, gy, gz])).to_const()
        let cell_dist = @nodes.vec3(cell_x)
          .add(0.5)
          .sub(grid_position)
          .to_const(name="cellDist")
        let momentum = eq16_term0
          .mul(weight)
          .mul(cell_dist)
          .to_const(name="momentum")
        let cell = cells.element(cell_pointer(cell_x))
        @nodes.atomic_add(cell.get("x"), encode_fixed_point(momentum.x()))
        |> ignore
        @nodes.atomic_add(cell.get("y"), encode_fixed_point(momentum.y()))
        |> ignore
        @nodes.atomic_add(cell.get("z"), encode_fixed_point(momentum.z()))
        |> ignore
      })
      None
    })
    .call([])
    .compute(MAX_PARTICLES, workgroup_size=[WORKGROUP, 1, 1])
    .set_name("p2g2Kernel")

  // 4. grid update: momentum to velocity, zero velocity at the walls
  let update_grid = @nodes.fn_(fn(_, _) {
      let cell = cells.element(@nodes.instance_index)
      let mass = decode_fixed_point(@nodes.atomic_load(cell.get("mass"))).to_const()
      @nodes.if_(mass.less_than_equal(0), fn() { @nodes.return_() }) |> ignore
      let vx = decode_fixed_point(@nodes.atomic_load(cell.get("x")))
        .div(mass)
        .to_var()
      let vy = decode_fixed_point(@nodes.atomic_load(cell.get("y")))
        .div(mass)
        .to_var()
      let vz = decode_fixed_point(@nodes.atomic_load(cell.get("z")))
        .div(mass)
        .to_var()
      let index = @nodes.int(@nodes.instance_index)
      let x = index.div(@nodes.int(GRID * GRID))
      let y = index.div(@nodes.int(GRID)).mod(@nodes.int(GRID))
      let z = index.mod(@nodes.int(GRID))
      let at_wall = fn(c : @nodes.Node) {
        c
        .less_than(@nodes.int(1))
        .or(c.greater_than(@nodes.int(GRID).sub(@nodes.int(2))))
      }
      @nodes.if_(at_wall(x), fn() { vx.assign(0) }) |> ignore
      @nodes.if_(at_wall(y), fn() { vy.assign(0) }) |> ignore
      @nodes.if_(at_wall(z), fn() { vz.assign(0) }) |> ignore
      cells_float
      .element(@nodes.instance_index)
      .assign(@nodes.vec4_of([vx, vy, vz, mass]))
      None
    })
    .call([])
    .compute(cell_count)
    .set_name("updateGridKernel")

  // 5. grid to particle: gather velocity and C, gravity, mouse, walls, advect
  let grid_vec = @math.Vector3::new(
    GRID.to_double(),
    GRID.to_double(),
    GRID.to_double(),
  )
  let g2p = @nodes.fn_(fn(_, _) {
      let position = particle().get("position").to_var(name="particlePosition")
      let grid_position = position.mul(grid_size_u).to_var()
      let velocity = @nodes.vec3(0).to_var()
      let (cell_index, weights) = kernel_weights(grid_position)
      let b = @nodes.mat3(0).to_var(name="B")
      loop3(fn(gx, gy, gz) {
        let weight = cell_weight(weights, gx, gy, gz)
        let cell_x = cell_index.add(@nodes.ivec3_of([gx, gy, gz])).to_const()
        let cell_dist = @nodes.vec3(cell_x)
          .add(0.5)
          .sub(grid_position)
          .to_const(name="cellDist")
        let weighted_velocity = cells_float
          .element(cell_pointer(cell_x))
          .xyz()
          .mul(weight)
          .to_const(name="weightedVelocity")
        b.add_assign(
          @nodes.mat3_of([
            weighted_velocity.mul(cell_dist.x()),
            weighted_velocity.mul(cell_dist.y()),
            weighted_velocity.mul(cell_dist.z()),
          ]),
        )
        velocity.add_assign(weighted_velocity)
      })
      particle().get("C").assign(b.mul(4))
      velocity.add_assign(gravity_u.mul(dt_u))
      velocity.div_assign(grid_size_u)
      // mouse: push particles near the pointer ray along the pointer's motion
      let dist = @nodes.cross(
        mouse_ray_direction_u,
        position.sub(mouse_ray_origin_u),
      ).length()
      let force = dist.mul(3.0).one_minus().max(0.0).pow(2)
      velocity.add_assign(mouse_force_u.mul(force))
      position.add_assign(velocity.mul(dt_u))
      position.assign(
        @nodes.clamp(
          position,
          low=@nodes.vec3(1).div(grid_size_u),
          high=@nodes.vec3(grid_vec).sub(1).div(grid_size_u),
        ),
      )
      // keep the particles inside a rounded box
      let inner_box = grid_size_u.mul(0.5).sub(9.0).div(grid_size_u).to_var()
      let inner_radius = @nodes.float(6.0).div(grid_size_u.x())
      let pos_next = position
        .add(velocity.mul(dt_u).mul(2.0))
        .to_const(name="posNext")
      let pos_next_clamped = clamp_to_rounded_box(
        pos_next, inner_box, inner_radius,
      )
      velocity.add_assign(pos_next_clamped.sub(pos_next))
      velocity.mul_assign(grid_size_u)
      particle().get("position").assign(position)
      particle().get("velocity").assign(velocity)
      None
    })
    .call([])
    .compute(MAX_PARTICLES, workgroup_size=[WORKGROUP, 1, 1])
    .set_name("g2pKernel")
  { particles, seed, kernels: [clear_grid, p2g1, p2g2, update_grid, g2p], }
}

///|
extern "js" fn required_limits() -> @core.JsValue =
  #|() => ({ maxStorageBuffersInVertexStage: 1 })

///|
pub fn start(
  canvas : @core.JsValue,
  width : Double,
  height : Double,
  pixel_ratio : Double,
  on_ready : (String?, String) -> Unit,
) -> Unit {
  let renderer = @webgpu.WebGPURenderer::new(
    canvas~,
    antialias=true,
    required_limits=required_limits(),
  )
  renderer.set_pixel_ratio(pixel_ratio)
  renderer.set_size(width, height, update_style=false)
  renderer.tone_mapping = @core.ACESFilmicToneMapping
  renderer.tone_mapping_exposure = 1.35
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(
    fov=40.0,
    aspect=width / height,
    near=0.01,
    far=10.0,
  )
  camera.position.set(-1.3, 1.3, -1.3) |> ignore
  app.val = Some({ renderer, camera, })
  let controls = @controls.OrbitControls::new(camera, dom_element=canvas)
  controls.min_distance = 1.0
  controls.max_distance = 3.0
  controls.max_polar_angle = @cmath.PI * 0.35
  controls.target.set(0.0, 0.3, 0.0) |> ignore
  controls.enable_damping = true

  // Sky and reflections: an UltraHDR equirect, blurred behind the tank.
  @addon_loaders.UltraHDRLoader::new().load(
    assets_base.val + "textures/equirectangular/royal_esplanade_2k.hdr.jpg",
    on_load=fn(texture, _) {
      texture.mapping = @core.EquirectangularReflectionMapping
      let s = scene.as_scene()
      s.background = Some(Texture(texture))
      s.background_blurriness = 0.5
      s.environment = Some(texture)
    },
  )
  |> ignore
  let sim = simulation()

  // The particles: one small icosahedron drawn MAX_PARTICLES times, offset per instance.
  let geometry = @utils.BufferGeometryUtils::merge_vertices(
    @geometries.IcosahedronGeometry::new(radius=0.008, detail=1.0).delete_attribute(
      "uv",
    ),
  )
  let material = @nodes.MeshStandardNodeMaterial::new()
  let node_material = @nodes.NodeMaterial::of(material).unwrap()
  let particle = sim.particles.element(@nodes.instance_index)
  node_material.position_node = Some(
    @nodes.attribute("position").add(particle.get("position")),
  )
  // Deep blue water, whitening to foam where it moves fast.
  let speed = particle.get("velocity").length()
  node_material.color_node = Some(
    @nodes.mix(
      @nodes.color(0x0066ff),
      @nodes.color(0xe8f6ff),
      @nodes.smoothstep(40.0, 95.0, speed),
    ),
  )
  material.roughness = Some(0.25)
  let mesh = @core.Mesh::new(geometry~, material=Single(material))
  if mesh.kind is Mesh(m) {
    m.count = MAX_PARTICLES
  }
  mesh.frustum_culled = false
  // The tank pivots about its centre: the mesh sits in [0, 1]^3 of simulation space.
  let tank = @core.Group::new()
  tank.position.set(0.0, 0.5, 0.0) |> ignore
  mesh.position.set(-0.5, -0.5, -0.5) |> ignore
  tank.add(mesh) |> ignore
  scene.add(tank) |> ignore

  // Mouse: the pointer ray in simulation space, and its motion on the tank floor.
  let raycaster = @core.Raycaster::new()
  let inverse = @math.Matrix4::new()
  let floor = @math.Plane::new(
    normal=@math.Vector3::new(0.0, 1.0, 0.0),
    constant=0.0,
  )
  let mouse = @math.Vector3::new(0.0, 0.0, 0.0)
  let prev_mouse = @math.Vector3::new(0.0, 0.0, 0.0)
  let force = @math.Vector3::new(0.0, 0.0, 0.0)
  let gravity = @math.Vector3::new(0.0, 0.0, 0.0)
  renderer.init(on_done=fn(error) {
    if error is Some(_) {
      on_ready(error, "")
      return
    }
    renderer.compute(sim.seed)
    let mut last = -1.0
    renderer.set_animation_loop(
      Some(fn(now, _) {
        let t = now / 1000.0
        let dt = if last < 0.0 { 1.0 / 60.0 } else { t - last }
        last = t
        @nodes.InputNode::set_value(
          dt_u,
          Number(dt.clamp(min=0.00001, max=1.0 / 60.0)),
        )
        // Tilt the tank; in its frame gravity turns the other way.
        let angle = tilt_amplitude.val * @cmath.sin(t * 1.1)
        tank.rotation.set(0.0, 0.0, angle) |> ignore
        let g = 9.81 * 9.81
        gravity.set(-g * @cmath.sin(angle), -g * @cmath.cos(angle), 0.0)
        |> ignore
        @nodes.InputNode::set_value(gravity_u, Vector3(gravity.clone()))
        tank.update_matrix_world()
        inverse.copy(mesh.matrix_world).invert() |> ignore
        if pointer_ndc.val is Some((x, y)) {
          raycaster.set_from_camera(@math.Vector2::new(x, y), camera)
          let ray = raycaster.ray.apply_matrix4(inverse)
          @nodes.InputNode::set_value(
            mouse_ray_origin_u,
            Vector3(ray.origin.clone()),
          )
          @nodes.InputNode::set_value(
            mouse_ray_direction_u,
            Vector3(ray.direction.clone()),
          )
          ray.intersect_plane(floor, mouse) |> ignore
        }
        force.copy(mouse).sub(prev_mouse).multiply_scalar(2.0) |> ignore
        let len = force.length()
        if len > 0.3 {
          force.multiply_scalar(0.3 / len) |> ignore
        }
        prev_mouse.copy(mouse) |> ignore
        @nodes.InputNode::set_value(mouse_force_u, Vector3(force.clone()))
        renderer.compute_list(sim.kernels)
        controls.update() |> ignore
        renderer.render(scene, camera)
      }),
    )
    let backend = if renderer.backend.has_flag("isWebGPUBackend") {
      "WebGPU"
    } else {
      "WebGL 2 (fallback)"
    }
    on_ready(None, backend)
  })
}

///|
pub fn resize(width : Double, height : Double) -> Unit {
  guard app.val is Some({ renderer, camera, }) else { return }
  renderer.set_size(width, height, update_style=false)
  camera.as_perspective_camera().aspect = width / height
  camera.update_projection_matrix()
}

///|
/// The pointer in normalized device coordinates (-1..1, y up).
pub fn pointer(x : Double, y : Double) -> Unit {
  pointer_ndc.val = Some((x, y))
}

///|
/// Tilt amplitude in degrees; 0 holds the tank level.
pub fn set_tilt(degrees : Double) -> Unit {
  tilt_amplitude.val = degrees * @cmath.PI / 180.0
}

///|
pub fn set_viscosity(value : Double) -> Unit {
  @nodes.InputNode::set_value(viscosity_u, Number(value))
}

///|
pub fn particle_count() -> Int32 {
  MAX_PARTICLES
}

///|
fn main {

}
