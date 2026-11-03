// A GPU particle galaxy rendered with the MoonBit port of three.js's WebGPURenderer.
//
// 131,072 particles live in two storage buffers (position and velocity). A TSL compute
// shader seeds them as a three-armed spiral disk; another advances them every frame under
// three wandering attractors that pull and swirl them. The particles are drawn as
// additive sprites whose colour follows their speed. Nothing is simulated on the CPU.

///|
const COUNT : Int32 = 131072

///|
/// Particles never move faster than this (world units per second).
const MAX_SPEED : Double = 3.0

///|
/// The renderer, scene and camera once `start` has run.
struct App {
  renderer : @three.Renderer
  camera : @three.Object3D
}

///|
let app : Ref[App?] = { val: None, }

///|
/// Camera orbit: yaw and pitch in radians, distance from the centre.
let yaw : Ref[Double] = { val: 0.6, }

///|
let pitch : Ref[Double] = { val: 0.75, }

///|
let distance : Ref[Double] = { val: 7.0, }

///|
/// Seconds since the user last dragged; auto-rotation resumes after a pause.
let idle : Ref[Double] = { val: 10.0, }

///|
let repel : Ref[Bool] = { val: false, }

///|
/// Simulation uniforms, written from the CPU once per frame.
let time_u : @three.Node = @three.uniform(0.0)

///|
let delta_u : @three.Node = @three.uniform(0.0)

///|
/// Strength of the central mass; negative while repelling.
let central_u : @three.Node = @three.uniform(CENTRAL)

///|
/// 1 while the disk relaxes towards circular orbits, 0 while repelling.
let relax_u : @three.Node = @three.uniform(1.0)

///|
/// Strength of the three wandering attractors; negative while repelling.
let gravity_u : @three.Node = @three.uniform(PERTURB)

///|
const CENTRAL : Double = 1.2

///|
const PERTURB : Double = 0.12

///|
/// Where attractor `k` is at time `t`, on the CPU (for the glow sprites). They circle at
/// radius 2 a little slower than the stars there, which winds the disk into arms.
fn attractor_at(k : Int32, t : Double) -> (Double, Double, Double) {
  let phase = k.to_double() * 2.0944
  (
    @math.cos(t * 0.3 + phase) * 2.0,
    @math.sin(t * 0.7 + phase) * 0.12,
    @math.sin(t * 0.3 + phase) * 2.0,
  )
}

///|
/// The same path as `attractor_at`, as a TSL expression of the time uniform.
fn attractor_node(k : Int32) -> @three.Node {
  let phase = k.to_double() * 2.0944
  @three.vec3_of([
    time_u.mul(0.3).add(phase).cos().mul(2.0),
    time_u.mul(0.7).add(phase).sin().mul(0.12),
    time_u.mul(0.3).add(phase).sin().mul(2.0),
  ])
}

///|
/// A random float in [0, 1) per particle and per `salt`.
fn rand(salt : Int32) -> @three.Node {
  @three.hash_tsl.call([@three.instance_index.add(salt)])
}

///|
/// Seeds a three-armed spiral disk on circular orbits around the central mass.
fn seed_kernel(
  positions : @three.Node,
  velocities : @three.Node,
) -> @three.Node {
  @three.fn_(fn(_, _) {
    let i = @three.instance_index
    let radius = rand(0).pow(1.4).mul(3.6).add(0.3).to_var()
    let arm = rand(7919).mul(3).floor().mul(2.0944)
    let angle = arm
      .add(radius.mul(1.3))
      .add(rand(104729).sub(0.5).mul(0.8))
      .to_var()
    let height = rand(1299709)
      .sub(0.5)
      .mul(0.24)
      .mul(@three.float(1).sub(radius.div(4.5)))
    positions
    .element(i)
    .assign(
      @three.vec3_of([angle.cos().mul(radius), height, angle.sin().mul(radius)]),
    )
    let speed = @three.float(CENTRAL).div(radius).sqrt()
    velocities
    .element(i)
    .assign(
      @three.vec3_of([angle.sin().mul(-1).mul(speed), 0, angle.cos().mul(speed)]),
    )
    None
  })
  .call([])
  .compute(COUNT)
}

///|
/// One simulation step: gravity of the central mass and the three attractors, a pull
/// back to the disk plane, a speed limit and light damping, then integration.
fn step_kernel(
  positions : @three.Node,
  velocities : @three.Node,
) -> @three.Node {
  @three.fn_(fn(_, _) {
    let i = @three.instance_index
    let position = positions.element(i).to_var()
    let velocity = velocities.element(i).to_var()
    let to_centre = position.mul(-1).to_var()
    let centre_dist = to_centre.length().max(0.3).to_var()
    velocity.add_assign(
      to_centre
      .mul(central_u)
      .div(centre_dist.mul(centre_dist).mul(centre_dist))
      .mul(delta_u),
    )
    for k in 0..<3 {
      let to_attractor = attractor_node(k).sub(position).to_var()
      let dist = to_attractor.length().max(0.55).to_var()
      velocity.add_assign(
        to_attractor.mul(gravity_u).div(dist.mul(dist).mul(dist)).mul(delta_u),
      )
    }
    velocity.add_assign(
      @three.vec3_of([0, position.y().mul(-1.2), 0]).mul(delta_u),
    )
    // A soft leash beyond radius 4 brings stars thrown out by a repel back home.
    velocity.add_assign(
      position
      .mul(-0.9)
      .mul(@three.smoothstep(4.0, 8.0, position.length()))
      .mul(delta_u),
    )
    let speed = velocity.length().max(0.0001)
    velocity.mul_assign(@three.float(1).min(@three.float(MAX_SPEED).div(speed)))
    // Keep a rotating disk: damp radial motion and ease the tangential speed towards a
    // circular orbit. Off while repelling, so the explosion can play out.
    let planar = @three.vec3_of([position.x(), 0, position.z()]).to_var()
    let r = planar.length().max(0.3).to_var()
    let radial = planar.div(r).to_var()
    let tangent = @three.vec3_of([radial.z().mul(-1), 0, radial.x()]).to_var()
    velocity.sub_assign(
      radial.mul(velocity.dot(radial)).mul(relax_u).mul(delta_u.mul(0.6)),
    )
    let circular = @three.float(CENTRAL).div(r).sqrt()
    velocity.add_assign(
      tangent
      .mul(circular.sub(velocity.dot(tangent)))
      .mul(relax_u)
      .mul(delta_u.mul(0.25)),
    )
    position.add_assign(velocity.mul(delta_u))
    positions.element(i).assign(position)
    velocities.element(i).assign(velocity)
    None
  })
  .call([])
  .compute(COUNT)
}

///|
/// Additive sprites, coloured blue -> pink -> warm white with speed, soft-edged discs.
fn particle_material(
  positions : @three.Node,
  velocities : @three.Node,
) -> @three.Material {
  let material = @three.SpriteNodeMaterial::new()
  material.blending = @three.AdditiveBlending
  material.transparent = true
  material.depth_write = false
  let node_material = @three.NodeMaterial::of(material).unwrap()
  node_material.position_node = Some(positions.to_attribute())
  // Hue by distance from the centre (warm core, pink arms, blue rim); brightness by speed.
  let p = positions.to_attribute()
  let radius = @three.vec2_of([p.x(), p.z()]).length()
  let speed = velocities.to_attribute().length()
  let hue = @three.mix(
    @three.mix(
      @three.color(0xffc98a),
      @three.color(0xff3d8b),
      @three.smoothstep(0.2, 1.6, radius),
    ),
    @three.color(0x3a5bff),
    @three.smoothstep(1.6, 3.4, radius),
  )
  node_material.color_node = Some(
    hue.mul(@three.smoothstep(0.0, MAX_SPEED, speed).mul(1.1).add(0.45)),
  )
  let disc = @three.uv().sub(0.5).length()
  node_material.opacity_node = Some(
    @three.float(1).sub(@three.smoothstep(0.05, 0.5, disc)).mul(0.42),
  )
  @three.SpriteNodeMaterial::of(material).unwrap().scale_node = Some(
    @three.float(0.016),
  )
  material
}

///|
/// A large soft sprite marking an attractor.
fn glow_sprite(hex : Int32) -> @three.Object3D {
  let material = @three.SpriteNodeMaterial::new()
  material.blending = @three.AdditiveBlending
  material.transparent = true
  material.depth_write = false
  let node_material = @three.NodeMaterial::of(material).unwrap()
  node_material.color_node = Some(@three.color(hex))
  let disc = @three.uv().sub(0.5).length()
  node_material.opacity_node = Some(
    @three.float(1).sub(@three.smoothstep(0.0, 0.5, disc)).pow(3),
  )
  let sprite = @three.Sprite::new(material~)
  sprite.scale.set(0.9, 0.9, 0.9) |> ignore
  sprite
}

///|
fn place_camera(camera : @three.Object3D) -> Unit {
  let d = distance.val
  camera.position.set(
    d * @math.cos(pitch.val) * @math.sin(yaw.val),
    d * @math.sin(pitch.val),
    d * @math.cos(pitch.val) * @math.cos(yaw.val),
  )
  |> ignore
  camera.look_at_xyz(0.0, 0.0, 0.0)
}

///|
/// Creates the renderer on `canvas` (CSS size `width` x `height`), builds the scene,
/// seeds the particles and starts the animation loop. `on_ready` gets an error message, or
/// `None`, plus the backend name ("WebGPU" or "WebGL").
pub fn start(
  canvas : @three.JsValue,
  width : Double,
  height : Double,
  pixel_ratio : Double,
  on_ready : (String?, String) -> Unit,
) -> Unit {
  let renderer = @three.WebGPURenderer::new(canvas~, antialias=false)
  renderer.set_pixel_ratio(pixel_ratio)
  renderer.set_size(width, height, update_style=false)
  renderer.set_clear_color(@three.Color::from_hex(0x030208))
  let scene = @three.Scene::new()
  let camera = @three.PerspectiveCamera::new(
    fov=55.0,
    aspect=width / height,
    near=0.05,
    far=100.0,
  )
  place_camera(camera)
  let positions = @three.instanced_array(COUNT, type_="vec3")
  let velocities = @three.instanced_array(COUNT, type_="vec3")
  let seed = seed_kernel(positions, velocities)
  let step = step_kernel(positions, velocities)
  let particles = @three.InstancedMesh::new(
    geometry=@three.PlaneGeometry::new(),
    material=Single(particle_material(positions, velocities)),
    COUNT,
  )
  particles.frustum_culled = false
  scene.add(particles) |> ignore
  let glows = [
    glow_sprite(0x8fa8ff),
    glow_sprite(0xff8fc0),
    glow_sprite(0xffe2b0),
  ]
  for glow in glows {
    scene.add(glow) |> ignore
  }
  app.val = Some({ renderer, camera, })
  renderer.init(on_done=fn(error) {
    if error is Some(_) {
      on_ready(error, "")
      return
    }
    renderer.compute(seed)
    let mut last = -1.0
    renderer.set_animation_loop(
      Some(fn(now, _) {
        let seconds = now / 1000.0
        // Clamp the step so a hidden tab coming back does not fling every particle.
        let dt = if last < 0.0 {
          1.0 / 60.0
        } else {
          (seconds - last).min(1.0 / 30.0)
        }
        last = seconds
        @three.InputNode::set_value(time_u, Number(seconds))
        @three.InputNode::set_value(delta_u, Number(dt))
        @three.InputNode::set_value(
          relax_u,
          Number(if repel.val { 0.0 } else { 1.0 }),
        )
        @three.InputNode::set_value(
          central_u,
          Number(if repel.val { -2.0 } else { CENTRAL }),
        )
        @three.InputNode::set_value(
          gravity_u,
          Number(if repel.val { -0.6 } else { PERTURB }),
        )
        idle.val += dt
        if idle.val > 2.0 {
          yaw.val += dt * 0.06
        }
        place_camera(camera)
        for k, glow in glows {
          let (x, y, z) = attractor_at(k, seconds)
          glow.position.set(x, y, z) |> ignore
        }
        renderer.compute(step)
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
/// Follows a new CSS size of the canvas.
pub fn resize(width : Double, height : Double) -> Unit {
  guard app.val is Some({ renderer, camera, }) else { return }
  renderer.set_size(width, height, update_style=false)
  camera.as_perspective_camera().aspect = width / height
  camera.update_projection_matrix()
}

///|
/// Rotates the orbit by a pointer drag of `dx`, `dy` pixels.
pub fn orbit(dx : Double, dy : Double) -> Unit {
  yaw.val -= dx * 0.005
  pitch.val = (pitch.val + dy * 0.005).clamp(min=-1.4, max=1.4)
  idle.val = 0.0
}

///|
/// Zooms by a wheel delta.
pub fn zoom(delta : Double) -> Unit {
  distance.val = (distance.val * @math.exp(delta * 0.001)).clamp(
    min=2.0,
    max=20.0,
  )
}

///|
/// While `on` is true the attractors push particles away instead of pulling them in.
pub fn set_repel(on : Bool) -> Unit {
  repel.val = on
}

///|
pub fn particle_count() -> Int32 {
  COUNT
}

///|
fn main {

}
