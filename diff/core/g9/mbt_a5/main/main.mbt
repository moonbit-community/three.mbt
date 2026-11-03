// The MoonBit half of the A5 mock-GPU scenarios: harness/a5_scenarios.mjs step for step.
// `run_scenario( name, env, done )` loads the scenario's add-on modules (`load_*()`, as the
// upstream side imports them), aligns the id counters, runs the scenario and calls `done`.

///|
struct Env {
  name : String
  canvas : @core.JsValue
  raw : @core.JsValue
}

///|
fn align() -> Unit {
  fn advance(name : String, target : Int32, f : () -> Int32) -> Unit {
    let mut id = f()
    if id >= target {
      abort("counter \{name} already at \{id}")
    }
    while id < target - 1 {
      id = f()
    }
  }

  advance("node", 20000, fn() { @nodes.Node::alloc().id })
  advance("object3d", 1000, fn() { @core.Object3D::new().id })
  advance("material", 1000, fn() { @core.Material::new().id })
  advance("texture", 1000, fn() { @core.Texture::new().id })
  advance("attribute", 1000, fn() {
    @core.BufferAttribute::new(@core.TypedArray::float32(1), 1).id
  })
  advance("geometry", 1000, fn() { @core.BufferGeometry::new().id })
}

///|
priv struct Scenario {
  load : () -> Unit
  run : (Env, () -> Unit) -> Unit
}

///|
let scenarios : Map[String, Scenario] = Map([])

///|
fn scenario(
  name : String,
  load : () -> Unit,
  run : (Env, () -> Unit) -> Unit,
) -> Unit {
  scenarios[name] = { load, run }
}

///|
pub fn scenario_names() -> Array[String] {
  register()
  scenarios.keys().collect()
}

///|
pub fn run_scenario(
  name : String,
  env : @core.JsValue,
  done : () -> Unit,
) -> Unit {
  register()
  let env = { name, canvas: env.get("canvas"), raw: env }
  match scenarios.get(name) {
    Some(s) => {
      (s.load)()
      align()
      (s.run)(env, done)
    }
    None => abort("unknown scenario \{name}")
  }
}

///|
let registered : Ref[Bool] = Ref(false)

///|
fn register() -> Unit {
  if registered.val {
    return
  }
  registered.val = true
  register_display()
  register_temporal()
  register_lighting()
}

///|
fn main {

}

///|
fn renderer(env : Env) -> @nodes.Renderer {
  @webgpu.WebGPURenderer::new(canvas=env.canvas, antialias=false)
}

///|
fn camera() -> @core.Object3D {
  let camera = @core.PerspectiveCamera::new(
    fov=50.0,
    aspect=1.0,
    near=0.1,
    far=10.0,
  )
  camera.position.z = 3.0
  camera
}

///|
/// `litScene( ctx )`: a lit standard box and a plane.
fn lit_scene() -> @core.Object3D {
  let scene = @core.Scene::new()
  scene.add(
    @core.AmbientLight::new(color=@math.Color::from_hex(0x404040), intensity=1.0),
  )
  |> ignore
  let dl = @core.DirectionalLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=2.0,
  )
  dl.position.set(1.0, 2.0, 3.0) |> ignore
  scene.add(dl) |> ignore
  let box_material = @nodes.MeshStandardNodeMaterial::new()
  let box = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(),
    material=Single(box_material),
  )
  box_material.color.unwrap().set_hex(0x3366cc) |> ignore
  box.rotation.set(0.4, 0.6, 0.0) |> ignore
  scene.add(box) |> ignore
  let plane = @core.Mesh::new(
    geometry=@geometries.PlaneGeometry::new(width=4.0, height=4.0),
    material=Single(@nodes.MeshStandardNodeMaterial::new()),
  )
  plane.position.z = -1.0
  scene.add(plane) |> ignore
  scene
}

///|
/// `tick( r )`: one animation frame without requestAnimationFrame (the mock's never
/// fires), Animation's `update` minus the inspector, so FRAME-updated nodes run again.
fn tick(r : @nodes.Renderer) -> Unit {
  if r.info.auto_reset {
    r.info.reset()
  }
  let frame = r._nodes.unwrap().node_frame
  frame.update()
  r.info.frame = frame.frame_id
}

///|
/// Options of `pipeline`: an MRT for the scene pass, a step before frames after the first,
/// a step after the last frame, and one right after `init`.
priv struct PipelineOptions {
  mrt : (() -> @nodes.Node)?
  step : ((Int, @core.Object3D, @core.Object3D) -> Unit)?
  after : ((@nodes.RenderPipeline) -> Unit)?
  before : ((@nodes.Renderer) -> Unit)?
}

///|
let no_options : PipelineOptions = {
  mrt: None,
  step: None,
  after: None,
  before: None,
}

///|
/// `pipeline( ctx, frames, output, options )`: `frames` renders of a lit scene through a
/// RenderPipeline whose output is `output( scenePass, camera, scene, renderer )`.
fn pipeline(
  env : Env,
  done : () -> Unit,
  frames : Int,
  output : (@nodes.Node, @core.Object3D, @core.Object3D, @nodes.Renderer) -> @nodes.Node,
  options? : PipelineOptions = no_options,
) -> Unit {
  let r = renderer(env)
  r.init(on_done=fn(_) {
    if options.before is Some(f) {
      f(r)
    }
    let scene = lit_scene()
    let cam = camera()
    let pp = @nodes.RenderPipeline::new(r)
    let scene_pass = @nodes.pass(scene, cam)
    if options.mrt is Some(f) {
      scene_pass.set_mrt(Some(f())) |> ignore
    }
    pp.output_node = output(scene_pass, cam, scene, r)
    for i in 0..<frames {
      if i > 0 {
        tick(r)
      }
      if i > 0 && options.step is Some(f) {
        f(i, scene, cam)
      }
      pp.render()
    }
    if options.after is Some(f) {
      f(pp)
    }
    done()
  })
}

///|
fn child(scene : @core.Object3D, i : Int) -> @core.Object3D {
  scene.children[i]
}

///|
fn move_box(i : Int, scene : @core.Object3D, _ : @core.Object3D) -> Unit {
  let b = child(scene, 2)
  b.rotation.set_y(b.rotation.y + 0.1)
  b.position.x = 0.05 * i.to_double()
}

///|
fn velocity_mrt() -> @nodes.Node {
  @nodes.mrt(
    Map::from_array([("output", @nodes.output), ("velocity", @nodes.velocity)]),
  )
}

///|
fn normal_mrt() -> @nodes.Node {
  @nodes.mrt(
    Map::from_array([("output", @nodes.output), ("normal", @nodes.normal_view)]),
  )
}

///|
fn all_mrt() -> @nodes.Node {
  @nodes.mrt(
    Map::from_array([
      ("output", @nodes.output),
      ("normal", @nodes.normal_view),
      ("velocity", @nodes.velocity),
    ]),
  )
}

///|
fn no_modules() -> Unit {

}
