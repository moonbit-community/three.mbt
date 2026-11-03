// The MoonBit half of the G9 differential harness: the scenarios of
// harness/scenarios.mjs, step for step, rendered with the port's WebGPURenderer on the
// mock GPU the driver installs. `run_scenario( name, env, done )` aligns the id counters,
// runs the scenario and calls `done` when its asynchronous steps have finished.

///|
fn j(v : &Show) -> Unit {
  ignore(v)
}

///|
/// The driver's environment: `{ canvas, note( label, value ), mock }`.
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
let scenarios : Map[String, (Env, () -> Unit) -> Unit] = Map([])

///|
fn scenario(name : String, f : (Env, () -> Unit) -> Unit) -> Unit {
  scenarios[name] = f
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
  align()
  let env = { name, canvas: env.get("canvas"), raw: env }
  match scenarios.get(name) {
    Some(f) => f(env, done)
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
  register_basics()
  register_materials()
  register_textures()
  register_render_setup()
  register_geometry()
  register_compute()
  register_copies()
  register_other()
  register_instancing_dispose()
  register_device_lost()
  register_no_adapter()
}

///|
fn main {

}
