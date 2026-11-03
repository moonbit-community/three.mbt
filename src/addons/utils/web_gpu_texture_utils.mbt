// Upstream examples/jsm/utils/WebGPUTextureUtils.js. The module-level `_quadMesh` is
// created by `load_web_gpu_texture_utils()` (or the first `decompress`), so its ids
// follow the ES import order the app mirrors. `decompress` takes callbacks for its
// promise.

///|
/// Upstream's `let _renderer;`: `undefined` until the first `decompress` that creates
/// its own renderer, then `null` once that renderer is disposed.
priv enum WebGPUTextureUtilsRenderer {
  Undefined
  Null
  Renderer(@nodes.Renderer)
}

///|
let _web_gpu_texture_utils_renderer : Ref[WebGPUTextureUtilsRenderer] = Ref(
  Undefined,
)

///|
let _web_gpu_texture_utils_quad_mesh : Ref[@nodes.QuadMesh?] = Ref(None)

///|
/// Evaluates the module: creates `_quadMesh`. Idempotent.
pub fn load_web_gpu_texture_utils() -> Unit {
  if _web_gpu_texture_utils_quad_mesh.val is None {
    _web_gpu_texture_utils_quad_mesh.val = Some(@nodes.QuadMesh::new())
  }
}

///|
extern "js" fn web_gpu_texture_utils_create_canvas() -> @core.JsValue = "() => document.createElement('canvas')"

///|
extern "js" fn web_gpu_texture_utils_get_context_2d(
  canvas : @core.JsValue,
) -> @core.JsValue = "(c) => c.getContext('2d')"

///|
extern "js" fn web_gpu_texture_utils_set_size(
  canvas : @core.JsValue,
  width : Double,
  height : Double,
) -> Unit = "(c, w, h) => { c.width = w; c.height = h; }"

///|
extern "js" fn web_gpu_texture_utils_draw_image(
  context : @core.JsValue,
  image : @core.JsValue,
  width : Double,
  height : Double,
) -> Unit = "(c, i, w, h) => c.drawImage(i, 0, 0, w, h)"

///|
extern "js" fn web_gpu_texture_utils_get_number(
  object : @core.JsValue,
  key : String,
) -> Double = "(o, k) => o[k]"

///|
/// `texture.image[ key ]` (`width`, `height`) as a JS number.
fn web_gpu_texture_utils_image_size(
  image : @core.TextureImage,
  key : String,
) -> Double {
  match image {
    DomImage(v) => web_gpu_texture_utils_get_number(v, key)
    DataImage(d) =>
      (if key == "width" { d.width } else { d.height }).to_double()
    // an array (cube faces) has no `width`: `undefined`, so `Math.min` gives NaN
    TextureImage(_) | ImageArray(_) => 0.0 / 0.0
    NoImage =>
      abort("TypeError: Cannot read properties of null (reading '\{key}')")
  }
}

///|
/// Runs `f` `ticks` microtasks later, where upstream's `await` chains resume.
extern "js" fn web_gpu_texture_utils_after_ticks(
  ticks : Int32,
  f : () -> Unit,
) -> Unit = "(n, f) => { const step = (k) => { if (k === 0) f(); else queueMicrotask(() => step(k - 1)); }; step(n); }"

///|
extern "js" fn web_gpu_texture_utils_math_min(a : Double, b : Double) -> Double = "Math.min"

///|
/// `decompress( blitTexture, maxTextureSize, renderer )`: renders `blit_texture` (e.g. a
/// compressed texture) into a canvas and calls `on_done` with a `CanvasTexture` of it.
/// Without `renderer` a `WebGPURenderer` is created, initialized and disposed. As
/// upstream, a call with a `renderer` before any call without one fails (upstream's
/// `_renderer` is still `undefined`); `on_error` gets that error, or it aborts.
pub fn decompress(
  blit_texture : @core.Texture,
  max_texture_size~ : Double = _web_gpu_texture_utils_infinity,
  renderer? : @nodes.Renderer,
  on_done : (@core.Texture) -> Unit,
  on_error? : (String) -> Unit,
) -> Unit {
  load_web_gpu_texture_utils()
  fn rest(renderer : @nodes.Renderer) -> Unit {
    let material = @nodes.NodeMaterial::new()
    @nodes.NodeMaterial::of(material).unwrap().fragment_node = Some(
      @nodes.texture(blit_texture, uv_node=@nodes.uv().flip_y()),
    )
    let image = blit_texture.image()
    let width = web_gpu_texture_utils_math_min(
      web_gpu_texture_utils_image_size(image, "width"),
      max_texture_size,
    )
    let height = web_gpu_texture_utils_math_min(
      web_gpu_texture_utils_image_size(image, "height"),
      max_texture_size,
    )
    let current_output_color_space = renderer.output_color_space
    renderer.set_size(width, height)
    renderer.output_color_space = blit_texture.color_space
    let quad_mesh = _web_gpu_texture_utils_quad_mesh.val.unwrap()
    quad_mesh.set_material(material)
    quad_mesh.render(renderer)
    renderer.output_color_space = current_output_color_space
    let canvas = web_gpu_texture_utils_create_canvas()
    let context = web_gpu_texture_utils_get_context_2d(canvas)
    web_gpu_texture_utils_set_size(canvas, width, height)
    web_gpu_texture_utils_draw_image(
      context,
      renderer.dom_element(),
      width,
      height,
    )
    let readable_texture = @core.CanvasTexture::new(canvas~)
    readable_texture.min_filter = blit_texture.min_filter
    readable_texture.mag_filter = blit_texture.mag_filter
    readable_texture.wrap_s = blit_texture.wrap_s
    readable_texture.wrap_t = blit_texture.wrap_t
    readable_texture.color_space = blit_texture.color_space
    readable_texture.name = blit_texture.name
    match _web_gpu_texture_utils_renderer.val {
      Renderer(r) => {
        // `async dispose()` first awaits `init()` (an async function returning the
        // init promise): its body runs three microtasks later
        web_gpu_texture_utils_after_ticks(3, fn() { r.dispose() })
        _web_gpu_texture_utils_renderer.val = Null
      }
      Null => ()
      Undefined => {
        // `_renderer.dispose()` on `undefined`: the async function rejects
        let message = "Cannot read properties of undefined (reading 'dispose')"
        // the returned promise rejects; its handlers run a microtask later
        web_gpu_texture_utils_after_ticks(1, fn() {
          match on_error {
            Some(f) => f(message)
            None => abort("TypeError: " + message)
          }
        })
        return
      }
    }
    // the returned promise resolves; `await decompress( ... )` resumes a microtask later
    web_gpu_texture_utils_after_ticks(1, fn() { on_done(readable_texture) })
  }

  match renderer {
    Some(renderer) => rest(renderer)
    None => {
      let renderer = @webgpu.WebGPURenderer::new()
      _web_gpu_texture_utils_renderer.val = Renderer(renderer)
      renderer.init(on_done=fn(error) {
        match error {
          None => rest(renderer)
          Some(e) =>
            match on_error {
              Some(f) => f(e)
              None => abort(e)
            }
        }
      })
    }
  }
}

///|
let _web_gpu_texture_utils_infinity : Double = 1.0 / 0.0
