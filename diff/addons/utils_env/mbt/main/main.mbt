// The MoonBit half of the a6 mock-GPU scenarios (../gpu/scenarios.mjs), step for step.

///|
extern "js" fn env_note(
  env : @core.JsValue,
  label : String,
  value : @core.JsValue,
) -> Unit = "(e, l, v) => e.note( l, v )"

///|
fn[T] js(v : T) -> @core.JsValue {
  @core.JsValue::of(v)
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
extern "js" fn js_get(v : @core.JsValue, key : String) -> @core.JsValue = "(v, k) => v[k]"

///|
fn image_of(t : @core.Texture) -> @core.JsValue {
  match t.image() {
    DomImage(v) => v
    _ => abort("not a DOM image")
  }
}

///|
fn describe_texture(t : @core.Texture) -> Array[@core.JsValue] {
  [
    js(t.texture_type is CanvasTexture),
    js(t.min_filter.to_double()),
    js(t.mag_filter.to_double()),
    js(t.wrap_s.to_double()),
    js(t.wrap_t.to_double()),
    js(t.color_space),
    js(t.name),
    js_get(image_of(t), "__id"),
    js_get(image_of(t), "width"),
    js_get(image_of(t), "height"),
  ]
}

///|
pub fn run_scenario(
  name : String,
  env : @core.JsValue,
  done : () -> Unit,
) -> Unit {
  // the add-on modules, in the app's import order, before the counters are aligned
  @utils.load_web_gpu_texture_utils()
  align()
  let canvas = env.get("canvas")
  let note = fn(label : String, value : @core.JsValue) {
    env_note(env, label, value)
  }
  match name {
    "pmrem_room" => {
      let r = @webgpu.WebGPURenderer::new(canvas~)
      r.init(on_done=fn(_) {
        let pmrem = @nodes.PMREMGenerator::new(r)
        let room = @environments.RoomEnvironment::new()
        let target = pmrem.from_scene(room, sigma=0.04, near=0.1, far=100.0, size=32)
        note("target", js([
          js(target.width.to_double()),
          js(target.height.to_double()),
          js(target.texture().mapping.to_double()),
          js(target.texture().type_.to_double()),
        ]))
        let scene = @core.Scene::new()
        scene.as_scene().environment = Some(target.texture())
        let m = @nodes.MeshStandardNodeMaterial::new()
        m.roughness = Some(0.3)
        m.metalness = Some(1.0)
        scene.add(
          @core.Mesh::new(
            geometry=@geometries.SphereGeometry::new(
              radius=0.5,
              width_segments=8.0,
              height_segments=6.0,
            ),
            material=Single(m),
          ),
        )
        |> ignore
        let cam = @core.PerspectiveCamera::new(fov=50.0, aspect=1.0, near=0.1, far=10.0)
        cam.position.set(0.0, 0.0, 3.0) |> ignore
        r.render(scene, cam)
        room.dispose()
        pmrem.dispose()
        done()
      })
    }
    "pmrem_color_debug" => {
      let r = @webgpu.WebGPURenderer::new(canvas~)
      r.init(on_done=fn(_) {
        let pmrem = @nodes.PMREMGenerator::new(r)
        let t1 = pmrem.from_scene(
          @environments.ColorEnvironment::new(color=0x8040c0),
          sigma=0.0,
          near=0.1,
          far=100.0,
          size=16,
        )
        let t2 = pmrem.from_scene(
          @environments.DebugEnvironment::new(),
          sigma=0.02,
          near=0.1,
          far=100.0,
          size=16,
        )
        note("targets", js([t1.width.to_double(), t2.width.to_double()]))
        done()
      })
    }
    "decompress" => {
      let data = @core.TypedArray::uint8(4 * 2 * 4)
      for i in 0..<data.length() {
        data[i] = (i * 7 % 256).to_double()
      }
      let tex = @core.DataTexture::new(data~, width=4, height=2)
      tex.color_space = @core.SRGBColorSpace
      tex.name = "blit"
      tex.min_filter = @core.NearestFilter
      tex.wrap_s = @core.RepeatWrapping
      tex.set_needs_update(true)
      let r = @webgpu.WebGPURenderer::new(canvas~)
      r.init(on_done=fn(_) {
        let next = fn() {
          @utils.decompress(tex, fn(t) {
            note("b", js(describe_texture(t)))
            @utils.decompress(tex, max_texture_size=2.0, renderer=r, fn(t2) {
              let d = describe_texture(t2)
              d.push(js(r.output_color_space))
              note("c", js(d))
              done()
            })
          })
        }
        @utils.decompress(
          tex,
          renderer=r,
          fn(_) {
            note("a", js("resolved"))
            next()
          },
          on_error=fn(e) {
            note("a", js(e))
            next()
          },
        )
      })
    }
    _ => abort("unknown scenario \{name}")
  }
}

///|
fn main {

}
