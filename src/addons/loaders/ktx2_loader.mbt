// Upstream examples/jsm/loaders/KTX2Loader.js. Everything on the main thread is ported;
// `KTX2Loader.BasisWorker` runs in a Web Worker, so its source stays JavaScript and is
// embedded verbatim (`ktx2_loader_basis_worker`, written by the ktx2_diff
// tools/gen_ktx2_loader.py script from upstream's file). Promise chains and `async`
// functions go through `@utils.AddonPromise` with upstream's microtask steps.

///|
/// Base URL of the Basis transcoder; upstream resolves `../libs/basis/` against its module.
pub const KTX2_LIBS_URL : String = "https://cdn.jsdelivr.net/npm/three@0.187.0/examples/jsm/libs/basis/"

///|
let ktx2_wasm_bin_url : String = KTX2_LIBS_URL + "basis_transcoder.wasm"

///|
let ktx2_wasm_js_url : String = KTX2_LIBS_URL + "basis_transcoder.js"

///|
#external
priv type Ktx2WeakMap

///|
extern "js" fn ktx2_weak_map_new() -> Ktx2WeakMap = "() => new WeakMap()"

///|
extern "js" fn ktx2_weak_map_has(
  map : Ktx2WeakMap,
  key : @core.JsValue,
) -> Bool = "(m, k) => m.has(k)"

///|
extern "js" fn ktx2_weak_map_get(
  map : Ktx2WeakMap,
  key : @core.JsValue,
) -> @core.JsValue = "(m, k) => m.get(k)"

///|
extern "js" fn ktx2_weak_map_set(
  map : Ktx2WeakMap,
  key : @core.JsValue,
  value : @core.JsValue,
) -> Unit = "(m, k, v) => { m.set(k, v); }"

///|
/// Upstream `{ promise }`, a `_taskCache` entry.
priv struct Ktx2Task {
  promise : @utils.AddonPromise
}

///|
/// Upstream `_taskCache`, keyed by the `ArrayBuffer`.
let ktx2_task_cache : Ktx2WeakMap = ktx2_weak_map_new()

///|
/// Upstream `_activeLoaders`.
let ktx2_active_loaders : Ref[Int32] = Ref(0)

///|
/// Upstream `_zstd`.
let ktx2_zstd : Ref[@utils.AddonPromise?] = Ref(None)

///|
extern "js" fn ktx2_console_warn(message : String) -> Unit = "(m) => console.warn(m)"

///|
extern "js" fn ktx2_has_msc_transcoder() -> Bool = "() => typeof MSC_TRANSCODER !== 'undefined'"

///|
/// `typeof navigator !== 'undefined' && ...`: a desktop Linux browser.
extern "js" fn ktx2_navigator_is_linux_desktop() -> Bool =
  #|() => typeof navigator !== 'undefined' &&
  #|  typeof navigator.platform !== 'undefined' && typeof navigator.userAgent !== 'undefined' &&
  #|  navigator.platform.indexOf( 'Linux' ) >= 0 && navigator.userAgent.indexOf( 'Android' ) < 0

///|
extern "js" fn ktx2_astc_has_hdr_profile(
  extension : @webgl.GLExtension,
) -> Bool =
  #|(e) => e.getSupportedProfiles().includes( 'hdr' )

///|
extern "js" fn ktx2_create_object_url(body : String) -> String = "(b) => URL.createObjectURL( new Blob( [ b ] ) )"

///|
extern "js" fn ktx2_revoke_object_url(url : String) -> Unit = "(u) => URL.revokeObjectURL( u )"

///|
extern "js" fn ktx2_array_buffer_slice0(
  buffer : @core.JsValue,
) -> @core.JsValue = "(b) => b.slice( 0 )"

///|
extern "js" fn ktx2_new_uint8_array(buffer : @core.JsValue) -> @core.TypedArray = "(b) => new Uint8Array( b )"

///|
/// `fn.substring( fn.indexOf( '{' ) + 1, fn.lastIndexOf( '}' ) )`.
extern "js" fn ktx2_function_body(source : String) -> String =
  #|(fn) => fn.substring( fn.indexOf( '{' ) + 1, fn.lastIndexOf( '}' ) )

///|
/// `new <name>( levelData.buffer, levelData.byteOffset, levelData.byteLength / <name>.BYTES_PER_ELEMENT )`.
extern "js" fn ktx2_level_view(
  name : String,
  level_data : @core.TypedArray,
) -> @core.TypedArray =
  #|(name, d) => { const C = globalThis[ name ]; return new C( d.buffer, d.byteOffset, d.byteLength / C.BYTES_PER_ELEMENT ); }

///|
extern "js" fn ktx2_subarray(
  data : @core.TypedArray,
  start : Double,
  end : Double,
) -> @core.TypedArray = "(d, s, e) => d.subarray( s, e )"

///|
/// `promise.then( f )` with `f` possibly `undefined`.
extern "js" fn ktx2_promise_then(
  promise : @utils.AddonPromise,
  f : @core.JsValue,
) -> @utils.AddonPromise = "(p, f) => p.then( f )"

///|
/// `promise.catch( f )` with `f` possibly `undefined`.
extern "js" fn ktx2_promise_catch(
  promise : @utils.AddonPromise,
  f : @core.JsValue,
) -> @utils.AddonPromise = "(p, f) => p.catch( f )"

///|
/// `_createTextureFrom`'s destructuring, which throws a `TypeError` without `data`.
extern "js" fn ktx2_destructure_transcode_result(
  transcode_result : @core.JsValue,
) -> @core.JsValue =
  #|(transcodeResult) => {
  #|  const { type: messageType, error, data: { faces, width, height, format, type, dfdFlags } } = transcodeResult;
  #|  return { messageType, error, faces, width, height, format, type, dfdFlags };
  #|}

///|
extern "js" fn ktx2_js_length(array : @core.JsValue) -> Int32 = "(a) => a.length"

///|
extern "js" fn ktx2_js_at(array : @core.JsValue, i : Int32) -> @core.JsValue = "(a, i) => a[ i ]"

///|
extern "js" fn ktx2_js_int(value : @core.JsValue) -> Int32 = "(v) => v"

///|
/// The output formats the device supports, which the worker transcodes to.
pub(all) struct KTX2WorkerConfig {
  mut astc_supported : Bool
  mut astc_hdr_supported : Bool
  mut etc1_supported : Bool
  mut etc2_supported : Bool
  mut dxt_supported : Bool
  mut bptc_supported : Bool
  mut pvrtc_supported : Bool
}

///|
/// The config as upstream's object (`{ astcSupported, ... }`), as posted to workers.
pub fn KTX2WorkerConfig::to_js(self : KTX2WorkerConfig) -> @core.JsValue {
  let o = @core.JsValue::object()
  o.set("astcSupported", @core.JsValue::of(self.astc_supported))
  o.set("astcHDRSupported", @core.JsValue::of(self.astc_hdr_supported))
  o.set("etc1Supported", @core.JsValue::of(self.etc1_supported))
  o.set("etc2Supported", @core.JsValue::of(self.etc2_supported))
  o.set("dxtSupported", @core.JsValue::of(self.dxt_supported))
  o.set("bptcSupported", @core.JsValue::of(self.bptc_supported))
  o.set("pvrtcSupported", @core.JsValue::of(self.pvrtc_supported))
  o
}

///|
/// A loader for KTX 2.0 GPU texture containers (Basis Universal and raw formats).
pub(all) struct KTX2Loader {
  base : @loaders.Loader
  mut transcoder_path : String
  mut transcoder_binary : @core.JsValue
  mut transcoder_pending : @utils.AddonPromise?
  worker_pool : @utils.WorkerPool
  mut worker_source_url : String
  mut worker_config : KTX2WorkerConfig?
}

///|
pub fn KTX2Loader::new(manager? : @loaders.LoadingManager) -> KTX2Loader {
  let loader = {
    base: @loaders.Loader::new(manager?),
    transcoder_path: "",
    transcoder_binary: @core.JsValue::null(),
    transcoder_pending: None,
    worker_pool: @utils.WorkerPool::new(),
    worker_source_url: "",
    worker_config: None,
  }
  if ktx2_has_msc_transcoder() {
    ktx2_console_warn(
      "THREE.KTX2Loader: Please update to latest \"basis_transcoder\"." +
      " \"msc_basis_transcoder\" is no longer supported in three.js r125+.",
    )
  }
  loader
}

///|
pub impl @loaders.LoaderLike for KTX2Loader with fn loader(self) {
  self.base
}

///|
pub impl @loaders.LoaderSettings for KTX2Loader

///|
pub extend KTX2Loader with @loaders.LoaderLike::{loader}

///|
pub extend KTX2Loader with @loaders.LoaderSettings::{
  set_cross_origin,
  set_with_credentials,
  set_path,
  set_resource_path,
  set_request_header,
  set_priority,
  set_cache,
  abort,
}

///|
/// Sets the directory of `basis_transcoder.js` and `basis_transcoder.wasm`.
pub fn KTX2Loader::set_transcoder_path(
  self : KTX2Loader,
  path : String,
) -> KTX2Loader {
  self.transcoder_path = path
  self
}

///|
/// Sets the maximum number of Web Workers.
pub fn KTX2Loader::set_worker_limit(
  self : KTX2Loader,
  worker_limit : Int32,
) -> KTX2Loader {
  self.worker_pool.set_worker_limit(worker_limit)
  self
}

///|
/// Detects the compressed formats a `WebGLRenderer` supports (upstream's WebGL branch).
pub fn KTX2Loader::detect_support(
  self : KTX2Loader,
  renderer : @webgl.WebGLRenderer,
) -> KTX2Loader {
  let extensions = renderer.extensions
  let astc_supported = extensions.has("WEBGL_compressed_texture_astc")
  let astc_hdr_supported = extensions.has("WEBGL_compressed_texture_astc") &&
    ktx2_astc_has_hdr_profile(
      extensions.get("WEBGL_compressed_texture_astc").unwrap(),
    )
  let etc1_supported = extensions.has("WEBGL_compressed_texture_etc1")
  let etc2_supported = extensions.has("WEBGL_compressed_texture_etc")
  let dxt_supported = extensions.has("WEBGL_compressed_texture_s3tc")
  let bptc_supported = extensions.has("EXT_texture_compression_bptc")
  let pvrtc_supported = extensions.has("WEBGL_compressed_texture_pvrtc") ||
    extensions.has("WEBKIT_WEBGL_compressed_texture_pvrtc")
  let config = {
    astc_supported,
    astc_hdr_supported,
    etc1_supported,
    etc2_supported,
    dxt_supported,
    bptc_supported,
    pvrtc_supported,
  }
  self.worker_config = Some(config)
  if ktx2_navigator_is_linux_desktop() &&
    config.astc_supported &&
    config.etc2_supported &&
    config.bptc_supported &&
    config.dxt_supported {

    // On Linux, Mesa drivers for AMD and Intel GPUs expose ETC1,ETC2 and ASTC even though the hardware doesn't support these.
    // Using these extensions will result in expensive software decompression on the main thread inside the driver, causing performance issues.
    // In general, browsers should not expose extensions for emulated formats, but Chrome and Firefox currently do so on Linux.
    // Since a granular filter is a little too fragile and we can transcode into other GPU formats, disable formats that are likely to be emulated.
    config.astc_supported = false
    config.etc1_supported = false
    config.etc2_supported = false
  }
  self
}

///|
/// Detects the compressed formats a `WebGPURenderer` supports (upstream's WebGPU branch).
pub fn KTX2Loader::detect_support_webgpu(
  self : KTX2Loader,
  renderer : @nodes.Renderer,
) -> KTX2Loader {
  let astc_supported = renderer.has_feature("texture-compression-astc")
  let etc1_supported = renderer.has_feature("texture-compression-etc1")
  let etc2_supported = renderer.has_feature("texture-compression-etc2")
  let dxt_supported = renderer.has_feature("texture-compression-s3tc")
  let bptc_supported = renderer.has_feature("texture-compression-bc")
  let pvrtc_supported = renderer.has_feature("texture-compression-pvrtc")
  self.worker_config = Some({
    astc_supported,
    astc_hdr_supported: false, // https://github.com/gpuweb/gpuweb/issues/3856
    etc1_supported,
    etc2_supported,
    dxt_supported,
    bptc_supported,
    pvrtc_supported,
  })
  self
}

///|
/// Upstream `loader.loadAsync( url )` of `Loader`.
fn ktx2_load_async(
  loader : @loaders.FileLoader,
  url : String,
) -> @utils.AddonPromise {
  @utils.AddonPromise::new((resolve, reject) => {
    loader.load(url, on_load=resolve, on_error=reject)
  })
}

///|
/// `JSON.stringify` of a table of integers.
fn ktx2_json_stringify(table : Map[String, Int32]) -> String {
  let entries = []
  for key, value in table {
    entries.push("\"" + key + "\":" + value.to_string())
  }
  "{" + entries.join(",") + "}"
}

///|
/// Loads the transcoder and sets up the worker pool; resolves when done.
pub fn KTX2Loader::init(self : KTX2Loader) -> @utils.AddonPromise {
  if self.transcoder_pending is None {
    let base = self.base
    let js_loader = @loaders.FileLoader::new(manager=base.manager)
    ignore(js_loader.set_priority(base.priority))
    ignore(js_loader.set_cache(base.cache))
    ignore(js_loader.set_with_credentials(base.with_credentials))
    let binary_loader = @loaders.FileLoader::new(manager=base.manager)
    ignore(binary_loader.set_priority(base.priority))
    ignore(binary_loader.set_cache(base.cache))
    ignore(binary_loader.set_with_credentials(base.with_credentials))
    ignore(binary_loader.set_response_type("arraybuffer"))
    let (js_content, binary_content) = if self.transcoder_path == "" {
      let js_content = ktx2_load_async(js_loader, ktx2_wasm_js_url)
      let binary_content = ktx2_load_async(binary_loader, ktx2_wasm_bin_url)
      (js_content, binary_content)
    } else {
      // Load transcoder wrapper.
      ignore(js_loader.set_path(self.transcoder_path))
      let js_content = ktx2_load_async(js_loader, "basis_transcoder.js")

      // Load transcoder WASM binary.
      ignore(binary_loader.set_path(self.transcoder_path))
      let binary_content = ktx2_load_async(
        binary_loader, "basis_transcoder.wasm",
      )
      (js_content, binary_content)
    }
    self.transcoder_pending = Some(
      @utils.AddonPromise::all([js_content, binary_content]).then_(fn(
        contents : Array[@core.JsValue],
      ) {
        let js_content : String = contents[0].cast()
        let binary_content = contents[1]
        let fn_ = ktx2_loader_basis_worker
        let body = [
          "/* constants */",
          "let _EngineFormat = " +
          ktx2_json_stringify(ktx2_loader_engine_format),
          "let _EngineType = " + ktx2_json_stringify(ktx2_loader_engine_type),
          "let _TranscoderFormat = " +
          ktx2_json_stringify(ktx2_loader_transcoder_format),
          "let _BasisFormat = " + ktx2_json_stringify(ktx2_loader_basis_format),
          "/* basis_transcoder.js */",
          js_content,
          "/* worker */",
          ktx2_function_body(fn_),
        ].join("\n")
        self.worker_source_url = ktx2_create_object_url(body)
        self.transcoder_binary = binary_content
        self.worker_pool.set_worker_creator(fn() {
          let worker = @utils.Worker::new(self.worker_source_url)
          let transcoder_binary = ktx2_array_buffer_slice0(
            self.transcoder_binary,
          )
          let msg = @core.JsValue::object()
          msg.set("type", @core.JsValue::of("init"))
          msg.set(
            "config",
            match self.worker_config {
              Some(config) => config.to_js()
              None => @core.JsValue::null()
            },
          )
          msg.set("transcoderBinary", transcoder_binary)
          worker.post_message(msg, [transcoder_binary])
          worker
        })
        @core.JsValue::undefined()
      }),
    )
    if ktx2_active_loaders.val > 0 {

      // Each instance loads a transcoder and allocates workers, increasing network and memory cost.
      ktx2_console_warn(
        "THREE.KTX2Loader: Multiple active KTX2 loaders may cause performance issues." +
        " Use a single KTX2Loader instance, or call .dispose() on old instances.",
      )
    }
    ktx2_active_loaders.val += 1
  }
  self.transcoder_pending.unwrap()
}

///|
/// Loads `url` and passes the texture to `on_load`.
pub fn KTX2Loader::load(
  self : KTX2Loader,
  url : String,
  on_load : (@core.Texture) -> Unit,
  on_progress? : (@loaders.ProgressEvent) -> Unit,
  on_error? : (@core.JsValue) -> Unit,
) -> Unit {
  if self.worker_config is None {
    @utils.addon_throw_error(
      "THREE.KTX2Loader: Missing initialization with `.detectSupport( renderer )`.",
    )
  }
  let base = self.base
  let loader = @loaders.FileLoader::new(manager=base.manager)
  ignore(loader.set_priority(base.priority))
  ignore(loader.set_cache(base.cache))
  ignore(loader.set_path(base.path))
  ignore(loader.set_cross_origin(base.cross_origin))
  ignore(loader.set_with_credentials(base.with_credentials))
  ignore(loader.set_request_header(base.request_header))
  ignore(loader.set_response_type("arraybuffer"))
  loader.load(
    url,
    on_load=buffer => self.parse(buffer, Some(on_load), on_error),
    on_progress?,
    on_error?,
  )
}

///|
/// Parses KTX2 data (an `ArrayBuffer`, transferred to a worker for Basis files).
pub fn KTX2Loader::parse(
  self : KTX2Loader,
  buffer : @core.JsValue,
  on_load : ((@core.Texture) -> Unit)?,
  on_error : ((@core.JsValue) -> Unit)?,
) -> Unit {
  if self.worker_config is None {
    @utils.addon_throw_error(
      "THREE.KTX2Loader: Missing initialization with `.detectSupport( renderer )`.",
    )
  }
  let on_error_js = match on_error {
    Some(f) => @core.JsValue::of(f)
    None => @core.JsValue::undefined()
  }

  // Check for an existing task using this buffer. A transferred buffer cannot be transferred
  // again from this thread.
  if ktx2_weak_map_has(ktx2_task_cache, buffer) {
    let cached_task : Ktx2Task = ktx2_weak_map_get(ktx2_task_cache, buffer).cast()
    let on_load_js = match on_load {
      Some(f) =>
        @core.JsValue::of(fn(texture : @core.JsValue) -> Unit {
          f(texture.cast())
        })
      None => @core.JsValue::undefined()
    }
    ignore(
      ktx2_promise_catch(
        ktx2_promise_then(cached_task.promise, on_load_js),
        on_error_js,
      ),
    )
    return
  }
  ignore(
    ktx2_promise_catch(
      self
      .create_texture(buffer)
      .then_(fn(texture : @core.JsValue) {
        match on_load {
          Some(f) => {
            f(texture.cast())
            @core.JsValue::undefined()
          }
          None => @core.JsValue::null()
        }
      }),
      on_error_js,
    ),
  )
}

///|
/// The JS mipmap objects `{ data, width, height }` of a worker reply.
fn ktx2_worker_mipmaps(mipmaps : @core.JsValue) -> Array[@core.DataImage] {
  let out = []
  for i in 0..<ktx2_js_length(mipmaps) {
    let mipmap = ktx2_js_at(mipmaps, i)
    out.push(
      @core.DataImage::new(
        data=mipmap.get("data").cast(),
        width=ktx2_js_int(mipmap.get("width")),
        height=ktx2_js_int(mipmap.get("height")),
      ),
    )
  }
  out
}

///|
fn KTX2Loader::create_texture_from(
  _self : KTX2Loader,
  transcode_result : @core.JsValue,
  container : @libs.KTX2Container,
) -> @core.JsValue {
  let result = ktx2_destructure_transcode_result(transcode_result)
  if result.get("messageType").strict_equal(@core.JsValue::of("error")) {
    return @utils.AddonPromise::reject(result.get("error")).to_js()
  }
  let faces = result.get("faces")
  let width = ktx2_js_int(result.get("width"))
  let height = ktx2_js_int(result.get("height"))
  let format = ktx2_js_int(result.get("format"))
  let type_ = ktx2_js_int(result.get("type"))
  let dfd_flags = ktx2_js_int(result.get("dfdFlags"))
  let texture = if container.face_count == 6 {
    let images = []
    for i in 0..<ktx2_js_length(faces) {
      let face = ktx2_js_at(faces, i)
      images.push(
        @core.TextureImage::DataImage(
          @core.DataImage::new(
            width=ktx2_js_int(face.get("width")),
            height=ktx2_js_int(face.get("height")),
            mipmaps=ktx2_worker_mipmaps(face.get("mipmaps")),
          ),
        ),
      )
    }
    @core.CompressedCubeTexture::new(images, format~, type_~)
  } else {
    let mipmaps = ktx2_worker_mipmaps(ktx2_js_at(faces, 0).get("mipmaps")).map(m => {
      @core.TextureImage::DataImage(m)
    })
    if container.layer_count > 1 {
      @core.CompressedArrayTexture::new(
        mipmaps~,
        width~,
        height~,
        depth=container.layer_count,
        format~,
        type_~,
      )
    } else {
      @core.CompressedTexture::new(mipmaps~, width~, height~, format~, type_~)
    }
  }
  texture.min_filter = if ktx2_js_length(ktx2_js_at(faces, 0).get("mipmaps")) ==
    1 {
    @core.LinearFilter
  } else {
    @core.LinearMipmapLinearFilter
  }
  texture.mag_filter = @core.LinearFilter
  texture.generate_mipmaps = false
  texture.set_needs_update(true)
  texture.color_space = ktx2_parse_color_space(container)
  texture.premultiply_alpha = (
      dfd_flags & @libs.KHR_DF_FLAG_ALPHA_PREMULTIPLIED
    ) !=
    0
  @core.JsValue::of(texture)
}

///|
/// Upstream `async _createTexture( buffer, config = {} )`.
fn KTX2Loader::create_texture(
  self : KTX2Loader,
  buffer : @core.JsValue,
  config~ : @core.JsValue = @core.JsValue::object(),
) -> @utils.AddonPromise {
  @utils.AddonPromise::new((resolve, _) => {
    let container = @libs.read(ktx2_new_uint8_array(buffer))

    // Basis UASTC HDR is a subset of ASTC, which can be transcoded efficiently
    // to BC6H. To detect whether a KTX2 file uses Basis UASTC HDR, or default
    // ASTC, inspect the DFD color model.
    //
    // Source: https://github.com/BinomialLLC/basis_universal/issues/381
    let is_basis_hdr = container.vk_format ==
      @libs.VK_FORMAT_ASTC_4x4_SFLOAT_BLOCK_EXT &&
      container.data_format_descriptor[0].color_model == 0xA7

    // If the device supports ASTC, Basis UASTC HDR requires no transcoder.
    let needs_transcoder = container.vk_format == @libs.VK_FORMAT_UNDEFINED ||
      (is_basis_hdr && !self.worker_config.unwrap().astc_hdr_supported)
    if !needs_transcoder {
      resolve(ktx2_create_raw_texture(container).to_js())
      return
    }

    //
    let task_config = config
    let texture_pending = self
      .init()
      .then_(fn(_ : @core.JsValue) {
        let msg = @core.JsValue::object()
        msg.set("type", @core.JsValue::of("transcode"))
        msg.set("buffer", buffer)
        msg.set("taskConfig", task_config)
        self.worker_pool.post_message(msg, [buffer])
      })
      .then_(fn(e : @core.JsValue) {
        self.create_texture_from(e.get("data"), container)
      })

    // Cache the task result.
    ktx2_weak_map_set(
      ktx2_task_cache,
      buffer,
      @core.JsValue::of(Ktx2Task::{ promise: texture_pending, }),
    )
    resolve(texture_pending.to_js())
  })
}

///|
/// Frees the workers and the worker source URL.
pub fn KTX2Loader::dispose(self : KTX2Loader) -> KTX2Loader {
  self.worker_pool.dispose()
  if self.worker_source_url != "" {
    ktx2_revoke_object_url(self.worker_source_url)
  }
  ktx2_active_loaders.val -= 1
  self
}

// CONSTANTS

///|
/// Upstream `KTX2Loader.BasisFormat`.
pub let ktx2_loader_basis_format : Map[String, Int32] = {
  "ETC1S": 0,
  "UASTC": 1,
  "UASTC_HDR": 2,
}

///|
/// Upstream `KTX2Loader.TranscoderFormat`.
// Source: https://github.com/BinomialLLC/basis_universal/blob/master/webgl/texture_test/index.html
pub let ktx2_loader_transcoder_format : Map[String, Int32] = {
  "ETC1": 0,
  "ETC2": 1,
  "BC1": 2,
  "BC3": 3,
  "BC4": 4,
  "BC5": 5,
  "BC7_M6_OPAQUE_ONLY": 6,
  "BC7_M5": 7,
  "PVRTC1_4_RGB": 8,
  "PVRTC1_4_RGBA": 9,
  "ASTC_4x4": 10,
  "ATC_RGB": 11,
  "ATC_RGBA_INTERPOLATED_ALPHA": 12,
  "RGBA32": 13,
  "RGB565": 14,
  "BGR565": 15,
  "RGBA4444": 16,
  "BC6H": 22,
  "RGB_HALF": 24,
  "RGBA_HALF": 25,
}

///|
/// Upstream `KTX2Loader.EngineFormat`.
pub let ktx2_loader_engine_format : Map[String, Int32] = {
  "RGBAFormat": @core.RGBAFormat,
  "RGBA_ASTC_4x4_Format": @core.RGBA_ASTC_4x4_Format,
  "RGB_BPTC_UNSIGNED_Format": @core.RGB_BPTC_UNSIGNED_Format,
  "RGBA_BPTC_Format": @core.RGBA_BPTC_Format,
  "RGBA_ETC2_EAC_Format": @core.RGBA_ETC2_EAC_Format,
  "RGBA_PVRTC_4BPPV1_Format": @core.RGBA_PVRTC_4BPPV1_Format,
  "RGBA_S3TC_DXT5_Format": @core.RGBA_S3TC_DXT5_Format,
  "RGB_ETC1_Format": @core.RGB_ETC1_Format,
  "RGB_ETC2_Format": @core.RGB_ETC2_Format,
  "RGB_PVRTC_4BPPV1_Format": @core.RGB_PVRTC_4BPPV1_Format,
  "RGBA_S3TC_DXT1_Format": @core.RGBA_S3TC_DXT1_Format,
}

///|
/// Upstream `KTX2Loader.EngineType`.
pub let ktx2_loader_engine_type : Map[String, Int32] = {
  "UnsignedByteType": @core.UnsignedByteType,
  "HalfFloatType": @core.HalfFloatType,
  "FloatType": @core.FloatType,
}

// WEB WORKER

///|
/// Upstream `KTX2Loader.BasisWorker`, as `Function.prototype.toString` gives it.
pub let ktx2_loader_basis_worker : String =
  #|function () {
  #|
  #|	let config;
  #|	let transcoderPending;
  #|	let BasisModule;
  #|
  #|	const EngineFormat = _EngineFormat; // eslint-disable-line no-undef
  #|	const EngineType = _EngineType; // eslint-disable-line no-undef
  #|	const TranscoderFormat = _TranscoderFormat; // eslint-disable-line no-undef
  #|	const BasisFormat = _BasisFormat; // eslint-disable-line no-undef
  #|
  #|	self.addEventListener( 'message', function ( e ) {
  #|
  #|		const message = e.data;
  #|
  #|		switch ( message.type ) {
  #|
  #|			case 'init':
  #|				config = message.config;
  #|				init( message.transcoderBinary );
  #|				break;
  #|
  #|			case 'transcode':
  #|				transcoderPending.then( () => {
  #|
  #|					try {
  #|
  #|						const { faces, buffers, width, height, hasAlpha, format, type, dfdFlags } = transcode( message.buffer );
  #|
  #|						self.postMessage( { type: 'transcode', id: message.id, data: { faces, width, height, hasAlpha, format, type, dfdFlags } }, buffers );
  #|
  #|					} catch ( error ) {
  #|
  #|						console.error( error );
  #|
  #|						self.postMessage( { type: 'error', id: message.id, error: error.message } );
  #|
  #|					}
  #|
  #|				} );
  #|				break;
  #|
  #|		}
  #|
  #|	} );
  #|
  #|	function init( wasmBinary ) {
  #|
  #|		transcoderPending = new Promise( ( resolve ) => {
  #|
  #|			BasisModule = { wasmBinary, onRuntimeInitialized: resolve };
  #|			BASIS( BasisModule ); // eslint-disable-line no-undef
  #|
  #|		} ).then( () => {
  #|
  #|			BasisModule.initializeBasis();
  #|
  #|			if ( BasisModule.KTX2File === undefined ) {
  #|
  #|				console.warn( 'THREE.KTX2Loader: Please update Basis Universal transcoder.' );
  #|
  #|			}
  #|
  #|		} );
  #|
  #|	}
  #|
  #|	function transcode( buffer ) {
  #|
  #|		const ktx2File = new BasisModule.KTX2File( new Uint8Array( buffer ) );
  #|
  #|		function cleanup() {
  #|
  #|			ktx2File.close();
  #|			ktx2File.delete();
  #|
  #|		}
  #|
  #|		if ( ! ktx2File.isValid() ) {
  #|
  #|			cleanup();
  #|			throw new Error( 'THREE.KTX2Loader:	Invalid or unsupported .ktx2 file' );
  #|
  #|		}
  #|
  #|		let basisFormat;
  #|
  #|		if ( ktx2File.isUASTC() ) {
  #|
  #|			basisFormat = BasisFormat.UASTC;
  #|
  #|		} else if ( ktx2File.isETC1S() ) {
  #|
  #|			basisFormat = BasisFormat.ETC1S;
  #|
  #|		} else if ( ktx2File.isHDR() ) {
  #|
  #|			basisFormat = BasisFormat.UASTC_HDR;
  #|
  #|		} else {
  #|
  #|			throw new Error( 'THREE.KTX2Loader: Unknown Basis encoding' );
  #|
  #|		}
  #|
  #|		const width = ktx2File.getWidth();
  #|		const height = ktx2File.getHeight();
  #|		const layerCount = ktx2File.getLayers() || 1;
  #|		const levelCount = ktx2File.getLevels();
  #|		const faceCount = ktx2File.getFaces();
  #|		const hasAlpha = ktx2File.getHasAlpha();
  #|		const dfdFlags = ktx2File.getDFDFlags();
  #|
  #|		const { transcoderFormat, engineFormat, engineType } = getTranscoderFormat( basisFormat, width, height, hasAlpha );
  #|
  #|		if ( ! width || ! height || ! levelCount ) {
  #|
  #|			cleanup();
  #|			throw new Error( 'THREE.KTX2Loader:	Invalid texture' );
  #|
  #|		}
  #|
  #|		if ( ! ktx2File.startTranscoding() ) {
  #|
  #|			cleanup();
  #|			throw new Error( 'THREE.KTX2Loader: .startTranscoding failed' );
  #|
  #|		}
  #|
  #|		const faces = [];
  #|		const buffers = [];
  #|
  #|		for ( let face = 0; face < faceCount; face ++ ) {
  #|
  #|			const mipmaps = [];
  #|
  #|			for ( let mip = 0; mip < levelCount; mip ++ ) {
  #|
  #|				const layerMips = [];
  #|
  #|				let mipWidth, mipHeight;
  #|
  #|				for ( let layer = 0; layer < layerCount; layer ++ ) {
  #|
  #|					const levelInfo = ktx2File.getImageLevelInfo( mip, layer, face );
  #|
  #|					if ( face === 0 && mip === 0 && layer === 0 && ( levelInfo.origWidth % 4 !== 0 || levelInfo.origHeight % 4 !== 0 ) ) {
  #|
  #|						console.warn( 'THREE.KTX2Loader: ETC1S and UASTC textures should use multiple-of-four dimensions.' );
  #|
  #|					}
  #|
  #|					if ( levelCount > 1 ) {
  #|
  #|						mipWidth = levelInfo.origWidth;
  #|						mipHeight = levelInfo.origHeight;
  #|
  #|					} else {
  #|
  #|						// Handles non-multiple-of-four dimensions in textures without mipmaps. Textures with
  #|						// mipmaps must use multiple-of-four dimensions, for some texture formats and APIs.
  #|						// See mrdoob/three.js#25908.
  #|						mipWidth = levelInfo.width;
  #|						mipHeight = levelInfo.height;
  #|
  #|					}
  #|
  #|					let dst = new Uint8Array( ktx2File.getImageTranscodedSizeInBytes( mip, layer, 0, transcoderFormat ) );
  #|					const status = ktx2File.transcodeImage( dst, mip, layer, face, transcoderFormat, 0, - 1, - 1 );
  #|
  #|					if ( engineType === EngineType.HalfFloatType ) {
  #|
  #|						dst = new Uint16Array( dst.buffer, dst.byteOffset, dst.byteLength / Uint16Array.BYTES_PER_ELEMENT );
  #|
  #|					}
  #|
  #|					if ( ! status ) {
  #|
  #|						cleanup();
  #|						throw new Error( 'THREE.KTX2Loader: .transcodeImage failed.' );
  #|
  #|					}
  #|
  #|					layerMips.push( dst );
  #|
  #|				}
  #|
  #|				const mipData = concat( layerMips );
  #|
  #|				mipmaps.push( { data: mipData, width: mipWidth, height: mipHeight } );
  #|				buffers.push( mipData.buffer );
  #|
  #|			}
  #|
  #|			faces.push( { mipmaps, width, height, format: engineFormat, type: engineType } );
  #|
  #|		}
  #|
  #|		cleanup();
  #|
  #|		return { faces, buffers, width, height, hasAlpha, dfdFlags, format: engineFormat, type: engineType };
  #|
  #|	}
  #|
  #|	//
  #|
  #|	// Optimal choice of a transcoder target format depends on the Basis format (ETC1S, UASTC, or
  #|	// UASTC HDR), device capabilities, and texture dimensions. The list below ranks the formats
  #|	// separately for each format. Currently, priority is assigned based on:
  #|	//
  #|	//   high quality > low quality > uncompressed
  #|	//
  #|	// Prioritization may be revisited, or exposed for configuration, in the future.
  #|	//
  #|	// Reference: https://github.com/KhronosGroup/3D-Formats-Guidelines/blob/main/KTXDeveloperGuide.md
  #|	const FORMAT_OPTIONS = [
  #|		{
  #|			if: 'astcSupported',
  #|			basisFormat: [ BasisFormat.UASTC ],
  #|			transcoderFormat: [ TranscoderFormat.ASTC_4x4, TranscoderFormat.ASTC_4x4 ],
  #|			engineFormat: [ EngineFormat.RGBA_ASTC_4x4_Format, EngineFormat.RGBA_ASTC_4x4_Format ],
  #|			engineType: [ EngineType.UnsignedByteType ],
  #|			priorityETC1S: Infinity,
  #|			priorityUASTC: 1,
  #|			needsPowerOfTwo: false,
  #|		},
  #|		{
  #|			if: 'bptcSupported',
  #|			basisFormat: [ BasisFormat.ETC1S, BasisFormat.UASTC ],
  #|			transcoderFormat: [ TranscoderFormat.BC7_M5, TranscoderFormat.BC7_M5 ],
  #|			engineFormat: [ EngineFormat.RGBA_BPTC_Format, EngineFormat.RGBA_BPTC_Format ],
  #|			engineType: [ EngineType.UnsignedByteType ],
  #|			priorityETC1S: 3,
  #|			priorityUASTC: 2,
  #|			needsPowerOfTwo: false,
  #|		},
  #|		{
  #|			if: 'dxtSupported',
  #|			basisFormat: [ BasisFormat.ETC1S, BasisFormat.UASTC ],
  #|			transcoderFormat: [ TranscoderFormat.BC1, TranscoderFormat.BC3 ],
  #|			engineFormat: [ EngineFormat.RGBA_S3TC_DXT1_Format, EngineFormat.RGBA_S3TC_DXT5_Format ],
  #|			engineType: [ EngineType.UnsignedByteType ],
  #|			priorityETC1S: 4,
  #|			priorityUASTC: 5,
  #|			needsPowerOfTwo: false,
  #|		},
  #|		{
  #|			if: 'etc2Supported',
  #|			basisFormat: [ BasisFormat.ETC1S, BasisFormat.UASTC ],
  #|			transcoderFormat: [ TranscoderFormat.ETC1, TranscoderFormat.ETC2 ],
  #|			engineFormat: [ EngineFormat.RGB_ETC2_Format, EngineFormat.RGBA_ETC2_EAC_Format ],
  #|			engineType: [ EngineType.UnsignedByteType ],
  #|			priorityETC1S: 1,
  #|			priorityUASTC: 3,
  #|			needsPowerOfTwo: false,
  #|		},
  #|		{
  #|			if: 'etc1Supported',
  #|			basisFormat: [ BasisFormat.ETC1S, BasisFormat.UASTC ],
  #|			transcoderFormat: [ TranscoderFormat.ETC1 ],
  #|			engineFormat: [ EngineFormat.RGB_ETC1_Format ],
  #|			engineType: [ EngineType.UnsignedByteType ],
  #|			priorityETC1S: 2,
  #|			priorityUASTC: 4,
  #|			needsPowerOfTwo: false,
  #|		},
  #|		{
  #|			if: 'pvrtcSupported',
  #|			basisFormat: [ BasisFormat.ETC1S, BasisFormat.UASTC ],
  #|			transcoderFormat: [ TranscoderFormat.PVRTC1_4_RGB, TranscoderFormat.PVRTC1_4_RGBA ],
  #|			engineFormat: [ EngineFormat.RGB_PVRTC_4BPPV1_Format, EngineFormat.RGBA_PVRTC_4BPPV1_Format ],
  #|			engineType: [ EngineType.UnsignedByteType ],
  #|			priorityETC1S: 5,
  #|			priorityUASTC: 6,
  #|			needsPowerOfTwo: true,
  #|		},
  #|		{
  #|			if: 'bptcSupported',
  #|			basisFormat: [ BasisFormat.UASTC_HDR ],
  #|			transcoderFormat: [ TranscoderFormat.BC6H ],
  #|			engineFormat: [ EngineFormat.RGB_BPTC_UNSIGNED_Format ],
  #|			engineType: [ EngineType.HalfFloatType ],
  #|			priorityHDR: 1,
  #|			needsPowerOfTwo: false,
  #|		},
  #|
  #|		// Uncompressed fallbacks.
  #|
  #|		{
  #|			basisFormat: [ BasisFormat.ETC1S, BasisFormat.UASTC ],
  #|			transcoderFormat: [ TranscoderFormat.RGBA32, TranscoderFormat.RGBA32 ],
  #|			engineFormat: [ EngineFormat.RGBAFormat, EngineFormat.RGBAFormat ],
  #|			engineType: [ EngineType.UnsignedByteType, EngineType.UnsignedByteType ],
  #|			priorityETC1S: 100,
  #|			priorityUASTC: 100,
  #|			needsPowerOfTwo: false,
  #|		},
  #|		{
  #|			basisFormat: [ BasisFormat.UASTC_HDR ],
  #|			transcoderFormat: [ TranscoderFormat.RGBA_HALF ],
  #|			engineFormat: [ EngineFormat.RGBAFormat ],
  #|			engineType: [ EngineType.HalfFloatType ],
  #|			priorityHDR: 100,
  #|			needsPowerOfTwo: false,
  #|		}
  #|	];
  #|
  #|	const OPTIONS = {
  #|		[ BasisFormat.ETC1S ]: FORMAT_OPTIONS
  #|			.filter( ( opt ) => opt.basisFormat.includes( BasisFormat.ETC1S ) )
  #|			.sort( ( a, b ) => a.priorityETC1S - b.priorityETC1S ),
  #|
  #|		[ BasisFormat.UASTC ]: FORMAT_OPTIONS
  #|			.filter( ( opt ) => opt.basisFormat.includes( BasisFormat.UASTC ) )
  #|			.sort( ( a, b ) => a.priorityUASTC - b.priorityUASTC ),
  #|
  #|		[ BasisFormat.UASTC_HDR ]: FORMAT_OPTIONS
  #|			.filter( ( opt ) => opt.basisFormat.includes( BasisFormat.UASTC_HDR ) )
  #|			.sort( ( a, b ) => a.priorityHDR - b.priorityHDR ),
  #|	};
  #|
  #|	function getTranscoderFormat( basisFormat, width, height, hasAlpha ) {
  #|
  #|		const options = OPTIONS[ basisFormat ];
  #|
  #|		for ( let i = 0; i < options.length; i ++ ) {
  #|
  #|			const opt = options[ i ];
  #|
  #|			if ( opt.if && ! config[ opt.if ] ) continue;
  #|			if ( ! opt.basisFormat.includes( basisFormat ) ) continue;
  #|			if ( hasAlpha && opt.transcoderFormat.length < 2 ) continue;
  #|			if ( opt.needsPowerOfTwo && ! ( isPowerOfTwo( width ) && isPowerOfTwo( height ) ) ) continue;
  #|
  #|			const transcoderFormat = opt.transcoderFormat[ hasAlpha ? 1 : 0 ];
  #|			const engineFormat = opt.engineFormat[ hasAlpha ? 1 : 0 ];
  #|			const engineType = opt.engineType[ 0 ];
  #|
  #|			return { transcoderFormat, engineFormat, engineType };
  #|
  #|		}
  #|
  #|		throw new Error( 'THREE.KTX2Loader: Failed to identify transcoding target.' );
  #|
  #|	}
  #|
  #|	function isPowerOfTwo( value ) {
  #|
  #|		if ( value <= 2 ) return true;
  #|
  #|		return ( value & ( value - 1 ) ) === 0 && value !== 0;
  #|
  #|	}
  #|
  #|	/**
  #|	 * Concatenates N byte arrays.
  #|	 *
  #|	 * @param {Uint8Array[]} arrays
  #|	 * @return {Uint8Array}
  #|	 */
  #|	function concat( arrays ) {
  #|
  #|		if ( arrays.length === 1 ) return arrays[ 0 ];
  #|
  #|		let totalByteLength = 0;
  #|
  #|		for ( let i = 0; i < arrays.length; i ++ ) {
  #|
  #|			const array = arrays[ i ];
  #|			totalByteLength += array.byteLength;
  #|
  #|		}
  #|
  #|		const result = new Uint8Array( totalByteLength );
  #|
  #|		let byteOffset = 0;
  #|
  #|		for ( let i = 0; i < arrays.length; i ++ ) {
  #|
  #|			const array = arrays[ i ];
  #|			result.set( array, byteOffset );
  #|
  #|			byteOffset += array.byteLength;
  #|
  #|		}
  #|
  #|		return result;
  #|
  #|	}
  #|
  #|}

// Parsing for non-Basis textures. These textures may have supercompression
// like Zstd, but they do not require transcoding.

///|
let ktx2_uncompressed_formats : Set[Int32] = Set::from_array([
  @core.RGBAFormat,
  @core.RGBFormat,
  @core.RGFormat,
  @core.RedFormat,
])

///|
let ktx2_normalized_vk_formats : Set[Int32] = Set::from_array([
  @libs.VK_FORMAT_R16G16B16A16_UNORM,
])

///|
/// Upstream `FORMAT_MAP`.
let ktx2_format_map : Map[Int32, Int32] = Map::from_array([
  (@libs.VK_FORMAT_R32G32B32A32_SFLOAT, @core.RGBAFormat),
  (@libs.VK_FORMAT_R32G32_SFLOAT, @core.RGFormat),
  (@libs.VK_FORMAT_R32_SFLOAT, @core.RedFormat),
  (@libs.VK_FORMAT_R16G16B16A16_SFLOAT, @core.RGBAFormat),
  (@libs.VK_FORMAT_R16G16_SFLOAT, @core.RGFormat),
  (@libs.VK_FORMAT_R16_SFLOAT, @core.RedFormat),
  (@libs.VK_FORMAT_R16G16B16A16_UNORM, @core.RGBAFormat),
  (@libs.VK_FORMAT_R8G8B8A8_SRGB, @core.RGBAFormat),
  (@libs.VK_FORMAT_R8G8B8A8_UNORM, @core.RGBAFormat),
  (@libs.VK_FORMAT_R8G8_SRGB, @core.RGFormat),
  (@libs.VK_FORMAT_R8G8_UNORM, @core.RGFormat),
  (@libs.VK_FORMAT_R8_SRGB, @core.RedFormat),
  (@libs.VK_FORMAT_R8_UNORM, @core.RedFormat),
  (@libs.VK_FORMAT_E5B9G9R9_UFLOAT_PACK32, @core.RGBFormat),
  (@libs.VK_FORMAT_B10G11R11_UFLOAT_PACK32, @core.RGBFormat),
  (@libs.VK_FORMAT_ETC2_R8G8B8A8_SRGB_BLOCK, @core.RGBA_ETC2_EAC_Format),
  (@libs.VK_FORMAT_ETC2_R8G8B8_SRGB_BLOCK, @core.RGB_ETC2_Format),
  (@libs.VK_FORMAT_EAC_R11_UNORM_BLOCK, @core.R11_EAC_Format),
  (@libs.VK_FORMAT_EAC_R11_SNORM_BLOCK, @core.SIGNED_R11_EAC_Format),
  (@libs.VK_FORMAT_EAC_R11G11_UNORM_BLOCK, @core.RG11_EAC_Format),
  (@libs.VK_FORMAT_EAC_R11G11_SNORM_BLOCK, @core.SIGNED_RG11_EAC_Format),
  (@libs.VK_FORMAT_ASTC_4x4_SFLOAT_BLOCK_EXT, @core.RGBA_ASTC_4x4_Format),
  (@libs.VK_FORMAT_ASTC_4x4_SRGB_BLOCK, @core.RGBA_ASTC_4x4_Format),
  (@libs.VK_FORMAT_ASTC_4x4_UNORM_BLOCK, @core.RGBA_ASTC_4x4_Format),
  (@libs.VK_FORMAT_ASTC_6x6_SFLOAT_BLOCK_EXT, @core.RGBA_ASTC_6x6_Format),
  (@libs.VK_FORMAT_ASTC_6x6_SRGB_BLOCK, @core.RGBA_ASTC_6x6_Format),
  (@libs.VK_FORMAT_ASTC_6x6_UNORM_BLOCK, @core.RGBA_ASTC_6x6_Format),
  (@libs.VK_FORMAT_BC1_RGBA_SRGB_BLOCK, @core.RGBA_S3TC_DXT1_Format),
  (@libs.VK_FORMAT_BC1_RGBA_UNORM_BLOCK, @core.RGBA_S3TC_DXT1_Format),
  (@libs.VK_FORMAT_BC1_RGB_SRGB_BLOCK, @core.RGB_S3TC_DXT1_Format),
  (@libs.VK_FORMAT_BC1_RGB_UNORM_BLOCK, @core.RGB_S3TC_DXT1_Format),
  (@libs.VK_FORMAT_BC3_SRGB_BLOCK, @core.RGBA_S3TC_DXT5_Format),
  (@libs.VK_FORMAT_BC3_UNORM_BLOCK, @core.RGBA_S3TC_DXT5_Format),
  (@libs.VK_FORMAT_BC4_SNORM_BLOCK, @core.SIGNED_RED_RGTC1_Format),
  (@libs.VK_FORMAT_BC4_UNORM_BLOCK, @core.RED_RGTC1_Format),
  (@libs.VK_FORMAT_BC5_SNORM_BLOCK, @core.SIGNED_RED_GREEN_RGTC2_Format),
  (@libs.VK_FORMAT_BC5_UNORM_BLOCK, @core.RED_GREEN_RGTC2_Format),
  (@libs.VK_FORMAT_BC7_SRGB_BLOCK, @core.RGBA_BPTC_Format),
  (@libs.VK_FORMAT_BC7_UNORM_BLOCK, @core.RGBA_BPTC_Format),
  (@libs.VK_FORMAT_PVRTC1_4BPP_SRGB_BLOCK_IMG, @core.RGBA_PVRTC_4BPPV1_Format),
  (@libs.VK_FORMAT_PVRTC1_4BPP_UNORM_BLOCK_IMG, @core.RGBA_PVRTC_4BPPV1_Format),
  (@libs.VK_FORMAT_PVRTC1_2BPP_SRGB_BLOCK_IMG, @core.RGBA_PVRTC_2BPPV1_Format),
  (@libs.VK_FORMAT_PVRTC1_2BPP_UNORM_BLOCK_IMG, @core.RGBA_PVRTC_2BPPV1_Format),
])

///|
/// Upstream `TYPE_MAP`.
let ktx2_type_map : Map[Int32, Int32] = Map::from_array([
  (@libs.VK_FORMAT_R32G32B32A32_SFLOAT, @core.FloatType),
  (@libs.VK_FORMAT_R32G32_SFLOAT, @core.FloatType),
  (@libs.VK_FORMAT_R32_SFLOAT, @core.FloatType),
  (@libs.VK_FORMAT_R16G16B16A16_SFLOAT, @core.HalfFloatType),
  (@libs.VK_FORMAT_R16G16_SFLOAT, @core.HalfFloatType),
  (@libs.VK_FORMAT_R16_SFLOAT, @core.HalfFloatType),
  (@libs.VK_FORMAT_R16G16B16A16_UNORM, @core.UnsignedShortType),
  (@libs.VK_FORMAT_R8G8B8A8_SRGB, @core.UnsignedByteType),
  (@libs.VK_FORMAT_R8G8B8A8_UNORM, @core.UnsignedByteType),
  (@libs.VK_FORMAT_R8G8_SRGB, @core.UnsignedByteType),
  (@libs.VK_FORMAT_R8G8_UNORM, @core.UnsignedByteType),
  (@libs.VK_FORMAT_R8_SRGB, @core.UnsignedByteType),
  (@libs.VK_FORMAT_R8_UNORM, @core.UnsignedByteType),
  (@libs.VK_FORMAT_E5B9G9R9_UFLOAT_PACK32, @core.UnsignedInt5999Type),
  (@libs.VK_FORMAT_B10G11R11_UFLOAT_PACK32, @core.UnsignedInt101111Type),
  (@libs.VK_FORMAT_ETC2_R8G8B8A8_SRGB_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_ETC2_R8G8B8_SRGB_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_EAC_R11_UNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_EAC_R11_SNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_EAC_R11G11_UNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_EAC_R11G11_SNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_ASTC_4x4_SFLOAT_BLOCK_EXT, @core.HalfFloatType),
  (@libs.VK_FORMAT_ASTC_4x4_SRGB_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_ASTC_4x4_UNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_ASTC_6x6_SFLOAT_BLOCK_EXT, @core.HalfFloatType),
  (@libs.VK_FORMAT_ASTC_6x6_SRGB_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_ASTC_6x6_UNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_BC1_RGBA_SRGB_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_BC1_RGBA_UNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_BC1_RGB_SRGB_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_BC1_RGB_UNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_BC3_SRGB_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_BC3_UNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_BC4_SNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_BC4_UNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_BC5_SNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_BC5_UNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_BC7_SRGB_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_BC7_UNORM_BLOCK, @core.UnsignedByteType),
  (@libs.VK_FORMAT_PVRTC1_4BPP_SRGB_BLOCK_IMG, @core.UnsignedByteType),
  (@libs.VK_FORMAT_PVRTC1_4BPP_UNORM_BLOCK_IMG, @core.UnsignedByteType),
  (@libs.VK_FORMAT_PVRTC1_2BPP_SRGB_BLOCK_IMG, @core.UnsignedByteType),
  (@libs.VK_FORMAT_PVRTC1_2BPP_UNORM_BLOCK_IMG, @core.UnsignedByteType),
])

///|
/// Upstream `async function createRawTexture( container )`.
fn ktx2_create_raw_texture(
  container : @libs.KTX2Container,
) -> @utils.AddonPromise {
  @utils.AddonPromise::new((resolve, reject) => {
    let vk_format = container.vk_format
    if ktx2_format_map.get(vk_format) is None {
      @utils.addon_throw_error(
        "THREE.KTX2Loader: Unsupported vkFormat: " + vk_format.to_string(),
      )
    }

    // TODO: Merge the TYPE_MAP warning into the thrown error above, after r190.
    if ktx2_type_map.get(vk_format) is None {
      ktx2_console_warn(
        "THREE.KTX2Loader: Missing \".type\" for vkFormat: " +
        vk_format.to_string(),
      )
    }

    //
    if container.supercompression_scheme == @libs.KHR_SUPERCOMPRESSION_ZSTD {
      if ktx2_zstd.val is None {
        ktx2_zstd.val = Some(
          @utils.AddonPromise::new((resolve, _) => {
            let zstd = @libs.ZSTDDecoder::new()
            ignore(
              @utils.AddonPromise::from_js(zstd.init()).then_(fn(
                _ : @core.JsValue,
              ) {
                resolve(@core.JsValue::of(zstd))
              }),
            )
          }),
        )
      }
      // `zstd = await _zstd`, then the rest of the function body.
      ignore(
        ktx2_zstd.val
        .unwrap()
        .then_(fn(zstd : @core.JsValue) {
          match
            @utils.addon_try(fn() {
              resolve(
                @core.JsValue::of(
                  ktx2_create_raw_texture_from_levels(
                    container,
                    Some(zstd.cast()),
                  ),
                ),
              )
            }) {
            Some(error) => reject(error)
            None => ()
          }
        }),
      )
    } else {
      resolve(
        @core.JsValue::of(ktx2_create_raw_texture_from_levels(container, None)),
      )
    }
  })
}

///|
/// `Math.max( 1, x )`.
fn ktx2_max1(x : Int32) -> Int32 {
  if x > 1 {
    x
  } else {
    1
  }
}

///|
/// The part of `createRawTexture` after `await _zstd`.
fn ktx2_create_raw_texture_from_levels(
  container : @libs.KTX2Container,
  zstd : @libs.ZSTDDecoder?,
) -> @core.Texture {
  let vk_format = container.vk_format
  let type_ = ktx2_type_map.get(vk_format)

  //
  let mipmaps : Array[@core.DataImage] = []
  for level_index in 0..<container.levels.length() {
    let level_width = ktx2_max1(container.pixel_width >> level_index)
    let level_height = ktx2_max1(container.pixel_height >> level_index)
    let level_depth = if container.pixel_depth != 0 {
      ktx2_max1(container.pixel_depth >> level_index)
    } else {
      0
    }
    let level = container.levels[level_index]
    let level_data = if container.supercompression_scheme ==
      @libs.KHR_SUPERCOMPRESSION_NONE {
      level.level_data
    } else if container.supercompression_scheme ==
      @libs.KHR_SUPERCOMPRESSION_ZSTD {
      zstd
      .unwrap()
      .decode(
        level.level_data,
        uncompressed_size=level.uncompressed_byte_length,
      )
    } else {
      @utils.addon_throw_error(
        "THREE.KTX2Loader: Unsupported supercompressionScheme.",
      )
    }
    let data = if type_ == Some(@core.FloatType) {
      ktx2_level_view("Float32Array", level_data)
    } else if type_ == Some(@core.HalfFloatType) ||
      type_ == Some(@core.UnsignedShortType) {
      ktx2_level_view("Uint16Array", level_data)
    } else if type_ == Some(@core.UnsignedInt5999Type) ||
      type_ == Some(@core.UnsignedInt101111Type) {
      ktx2_level_view("Uint32Array", level_data)
    } else {
      level_data
    }
    mipmaps.push(
      @core.DataImage::new(
        data~,
        width=level_width,
        height=level_height,
        depth=level_depth,
      ),
    )
  }

  // levelCount = 0 implies runtime-generated mipmaps.
  let use_mipmaps = container.level_count == 0 || mipmaps.length() > 1
  let format = ktx2_format_map.get(vk_format).unwrap()
  let texture = if ktx2_uncompressed_formats.contains(format) {
    let texture = if container.pixel_depth == 0 {
      @core.DataTexture::new(
        data=mipmaps[0].data.unwrap(),
        width=container.pixel_width,
        height=container.pixel_height,
      )
    } else {
      @core.Data3DTexture::new(
        data=mipmaps[0].data.unwrap(),
        width=container.pixel_width,
        height=container.pixel_height,
        depth=container.pixel_depth,
      )
    }
    texture.mipmaps = mipmaps.map(m => @core.TextureImage::DataImage(m))
    texture.min_filter = if use_mipmaps {
      @core.NearestMipmapNearestFilter
    } else {
      @core.NearestFilter
    }
    texture.mag_filter = @core.NearestFilter
    texture.generate_mipmaps = container.level_count == 0
    texture.normalized = ktx2_normalized_vk_formats.contains(vk_format)
    texture
  } else {
    if container.pixel_depth > 0 {
      @utils.addon_throw_error("THREE.KTX2Loader: Unsupported pixelDepth.")
    }
    let texture = if container.face_count == 6 {
      let faces = []
      for face in 0..<6 {
        let face_mipmaps = []
        for mipmap in mipmaps {
          let data = mipmap.data.unwrap()
          let face_length = data.length().to_double() / 6.0
          face_mipmaps.push(
            @core.DataImage::new(
              data=ktx2_subarray(
                data,
                face.to_double() * face_length,
                (face + 1).to_double() * face_length,
              ),
              width=mipmap.width,
              height=mipmap.height,
            ),
          )
        }
        faces.push(
          @core.TextureImage::DataImage(
            @core.DataImage::new(
              mipmaps=face_mipmaps,
              width=container.pixel_width,
              height=container.pixel_height,
            ),
          ),
        )
      }
      @core.CompressedCubeTexture::new(faces)
    } else {
      @core.CompressedTexture::new(
        mipmaps=mipmaps.map(m => @core.TextureImage::DataImage(m)),
        width=container.pixel_width,
        height=container.pixel_height,
      )
    }
    texture.min_filter = if use_mipmaps {
      @core.LinearMipmapLinearFilter
    } else {
      @core.LinearFilter
    }
    texture.mag_filter = @core.LinearFilter
    texture
  }
  // `TYPE_MAP[ vkFormat ]`; the type stays as it is when the map has no entry.
  if type_ is Some(type_) {
    texture.type_ = type_
  }
  texture.format = format
  texture.color_space = ktx2_parse_color_space(container)
  texture.set_needs_update(true)

  //
  texture
}

///|
/// Upstream `parseColorSpace`.
fn ktx2_parse_color_space(container : @libs.KTX2Container) -> String {
  let dfd = container.data_format_descriptor[0]
  if dfd.color_primaries == @libs.KHR_DF_PRIMARIES_BT709 {
    if dfd.transfer_function == @libs.KHR_DF_TRANSFER_SRGB {
      @core.SRGBColorSpace
    } else {
      @core.LinearSRGBColorSpace
    }
  } else if dfd.color_primaries == @libs.KHR_DF_PRIMARIES_DISPLAYP3 {
    if dfd.transfer_function == @libs.KHR_DF_TRANSFER_SRGB {
      @addon_math.DisplayP3ColorSpace
    } else {
      @addon_math.LinearDisplayP3ColorSpace
    }
  } else if dfd.color_primaries == @libs.KHR_DF_PRIMARIES_UNSPECIFIED {
    @core.NoColorSpace
  } else {
    ktx2_console_warn(
      "THREE.KTX2Loader: Unsupported color primaries, \"\{dfd.color_primaries}\"",
    )
    @core.NoColorSpace
  }
}
