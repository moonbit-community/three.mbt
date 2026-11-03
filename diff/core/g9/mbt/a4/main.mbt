// The MoonBit half of the A4 mock-GPU scenarios: harness/a4_scenarios.mjs step for step.
// `run_scenario( name, env, done )` loads the scenario's add-on modules (`load_*()`, as the
// upstream side imports them), aligns the id counters, runs the scenario and calls `done`.

///|
struct Env {
  name : String
  canvas : @core.JsValue
  raw : @core.JsValue
}

///|
extern "js" fn env_note(env : @core.JsValue, label : String, value : @core.JsValue) -> Unit = "(e, l, v) => e.note( l, v )"

///|
fn Env::note(self : Env, label : String, value : @core.JsValue) -> Unit {
  env_note(self.raw, label, value)
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
/// `scenario( name, modules, run )`: `load` calls the modules' `load_*()` in order.
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
  register_basic()
  register_basic_more()
  register_blur()
  register_ao()
  register_ssr()
  register_pass()
}

///|
fn main {

}

///|
fn no_modules() -> Unit {

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
