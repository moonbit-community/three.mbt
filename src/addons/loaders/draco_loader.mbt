// Upstream examples/jsm/loaders/DRACOLoader.js. Everything on the main thread is ported;
// the worker body (`DRACOWorker`) runs in a Web Worker, so it stays JavaScript and is
// embedded verbatim below (`draco_worker_body`). Promise chains go through
// `@utils.AddonPromise` with upstream's `.then` steps.

///|
using @core {type JsValue}

///|
/// Base URL of the decoder files; upstream resolves `../libs/draco/` against its module.
pub const DRACO_LIBS_URL : String = "https://cdn.jsdelivr.net/npm/three@0.187.0/examples/jsm/libs/draco/"

///|
/// Explicit decoder URLs, upstream's `{ js, wasm }` object.
pub(all) struct DRACOPathConfig {
  js : String
  wasm : String
}

///|
/// Upstream `DRACO_GLTF_CONFIG`, the decoder built for glTF.
pub let draco_gltf_config : DRACOPathConfig = {
  js: DRACO_LIBS_URL + "gltf/draco_wasm_wrapper.js",
  wasm: DRACO_LIBS_URL + "gltf/draco_decoder.wasm",
}

///|
/// Upstream `decoderPaths`; `dep_js` is `None` for upstream's `null`.
pub(all) struct DRACODecoderPaths {
  mut js : String
  mut wasm : String
  mut dep_js : String?
}

///|
#external
priv type DracoJsWorker

///|
extern "js" fn draco_new_worker(url : String) -> DracoJsWorker = "(u) => new Worker(u)"

///|
extern "js" fn draco_worker_post_init(
  worker : DracoJsWorker,
  decoder_config : JsValue,
) -> Unit =
  #|(w, c) => { w.postMessage({ type: 'init', decoderConfig: c }); }

///|
extern "js" fn draco_worker_post_decode(
  worker : DracoJsWorker,
  id : Int32,
  task_config : JsValue,
  buffer : JsValue,
) -> Unit =
  #|(w, id, taskConfig, buffer) => { w.postMessage({ type: 'decode', id: id, taskConfig, buffer }, [buffer]); }

///|
extern "js" fn draco_worker_set_onmessage(
  worker : DracoJsWorker,
  f : (JsValue) -> Unit,
) -> Unit =
  #|(w, f) => { w.onmessage = function (e) { f(e.data); }; }

///|
extern "js" fn draco_worker_terminate(worker : DracoJsWorker) -> Unit = "(w) => w.terminate()"

///|
/// `resolve` / `reject` of one task, upstream's `worker._callbacks[ taskID ]`.
priv struct DracoTaskCallbacks {
  resolve : (JsValue) -> Unit
  reject : (JsValue) -> Unit
}

///|
/// A pool worker with upstream's `_callbacks`, `_taskCosts` and `_taskLoad`.
priv struct DracoWorker {
  worker : DracoJsWorker
  callbacks : Map[Int32, DracoTaskCallbacks]
  task_costs : Map[Int32, Int32]
  mut task_load : Int32
}

///|
/// Upstream's `_taskCache` entries.
priv struct DracoCachedTask {
  key : String
  promise : @utils.AddonPromise
}

///|
/// Upstream's module-level `_taskCache`, keyed by the `ArrayBuffer`.
let draco_task_cache : @webgl.WeakMap[JsValue, DracoCachedTask] = @webgl.WeakMap::new()

///|
extern "js" fn draco_json_stringify(value : JsValue) -> String = "(v) => JSON.stringify(v)"

///|
extern "js" fn draco_byte_length(buffer : JsValue) -> Int32 = "(b) => b.byteLength"

///|
extern "js" fn draco_use_js(decoder_config : JsValue) -> Bool =
  #|(c) => typeof WebAssembly !== 'object' || c.type === 'js'

///|
extern "js" fn draco_create_object_url(body : String) -> String =
  #|(body) => URL.createObjectURL(new Blob([body]))

///|
extern "js" fn draco_revoke_object_url(url : String) -> Unit = "(u) => URL.revokeObjectURL(u)"

///|
extern "js" fn draco_is_float32_array(array : JsValue) -> Bool = "(a) => a instanceof Float32Array"

///|
extern "js" fn draco_truthy(value : JsValue) -> Bool = "(v) => !!v"

///|
extern "js" fn draco_console_warn(message : String) -> Unit = "(m) => console.warn(m)"

///|
extern "js" fn draco_console_error(message : String) -> Unit = "(m) => console.error(m)"

///|
extern "js" fn draco_console_log(message : String, value : JsValue) -> Unit = "(m, v) => console.log(m, v)"

///|
extern "js" fn draco_type_error(message : String) -> JsValue = "(m) => new TypeError(m)"

///|
/// `workerPool.sort( f )`: JS's sort, as upstream's comparator never returns 0.
extern "js" fn draco_sort_raw(
  array : JsValue,
  f : (JsValue, JsValue) -> Double,
) -> Unit = "(a, f) => { a.sort(f); }"

///|
fn draco_sort_workers(
  pool : Array[DracoWorker],
  f : (DracoWorker, DracoWorker) -> Double,
) -> Unit {
  draco_sort_raw(JsValue::of(pool), (a, b) => f(a.cast(), b.cast()))
}

///|
/// `{ attributeIDs, attributeTypes, useUniqueIDs, vertexColorSpace }`.
extern "js" fn draco_task_config(
  attribute_ids : JsValue,
  attribute_types : JsValue,
  use_unique_ids : Bool,
  vertex_color_space : String,
) -> JsValue =
  #|(attributeIDs, attributeTypes, useUniqueIDs, vertexColorSpace) => ({ attributeIDs, attributeTypes, useUniqueIDs, vertexColorSpace: vertexColorSpace })

///|
/// A JS object with the map's keys in insertion order.
fn[V] draco_object(map : Map[String, V]) -> JsValue {
  let object = JsValue::object()
  for key, value in map {
    object.set(key, JsValue::of(value))
  }
  object
}

///|
/// A loader for the Draco format.
pub struct DRACOLoader {
  base : @loaders.Loader
  decoder_paths : DRACODecoderPaths
  /// Upstream `decoderConfig`, the plain object sent to the workers.
  mut decoder_config : JsValue
  mut decoder_pending : @utils.AddonPromise?
  mut worker_limit : Int32
  priv worker_pool : Array[DracoWorker]
  mut worker_next_task_id : Int32
  mut worker_source_url : String
  default_attribute_ids : Map[String, String]
  default_attribute_types : Map[String, String]
}

///|
pub fn DRACOLoader::new(manager? : @loaders.LoadingManager) -> DRACOLoader {
  {
    base: @loaders.Loader::new(manager?),
    decoder_paths: {
      js: DRACO_LIBS_URL + "draco_wasm_wrapper.js",
      wasm: DRACO_LIBS_URL + "draco_decoder.wasm",
      dep_js: Some(DRACO_LIBS_URL + "draco_decoder.js"),
    },
    decoder_config: JsValue::object(),
    decoder_pending: None,
    worker_limit: 4,
    worker_pool: [],
    worker_next_task_id: 1,
    worker_source_url: "",
    default_attribute_ids: {
      "position": "POSITION",
      "normal": "NORMAL",
      "color": "COLOR",
      "uv": "TEX_COORD",
    },
    default_attribute_types: {
      "position": "Float32Array",
      "normal": "Float32Array",
      "color": "Float32Array",
      "uv": "Float32Array",
    },
  }
}

///|
pub impl @loaders.LoaderLike for DRACOLoader with fn loader(self) {
  self.base
}

///|
pub impl @loaders.LoaderSettings for DRACOLoader

///|
pub extend DRACOLoader with @loaders.LoaderLike::{loader}

///|
pub extend DRACOLoader with @loaders.LoaderSettings::{
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
/// Sets the directory of the decoder files.
pub fn DRACOLoader::set_decoder_path(
  self : DRACOLoader,
  path : String,
) -> DRACOLoader {
  let decoder_paths = self.decoder_paths
  decoder_paths.js = @loaders.LoaderUtils::resolve_url(
    "draco_wasm_wrapper.js", path,
  )
  decoder_paths.wasm = @loaders.LoaderUtils::resolve_url(
    "draco_decoder.wasm", path,
  )
  decoder_paths.dep_js = Some(
    @loaders.LoaderUtils::resolve_url("draco_decoder.js", path),
  )
  self
}

///|
/// Upstream `setDecoderPath( { js, wasm } )`: explicit URLs of the decoder files.
pub fn DRACOLoader::set_decoder_path_config(
  self : DRACOLoader,
  js : String,
  wasm : String,
) -> DRACOLoader {
  let decoder_paths = self.decoder_paths
  decoder_paths.js = js
  decoder_paths.wasm = wasm
  decoder_paths.dep_js = None
  self
}

///|
/// Deprecated upstream; `config` is the decoder config object (`{ type: 'js' }`).
pub fn DRACOLoader::set_decoder_config(
  self : DRACOLoader,
  config : JsValue,
) -> DRACOLoader {
  draco_console_warn(
    "THREE.DRACOLoader: setDecoderConfig to has been deprecated and will be removed in r194.",
  )
  self.decoder_config = config
  self
}

///|
pub fn DRACOLoader::set_worker_limit(
  self : DRACOLoader,
  worker_limit : Int32,
) -> DRACOLoader {
  self.worker_limit = worker_limit
  self
}

///|
/// Loads a `.drc` file; vertex colors are taken as sRGB.
pub fn DRACOLoader::load(
  self : DRACOLoader,
  url : String,
  on_load : (@core.BufferGeometry) -> Unit,
  on_progress? : (@loaders.ProgressEvent) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> Unit {
  let base = self.base
  let loader = @loaders.FileLoader::new(manager=base.manager)
  loader.set_priority(base.priority) |> ignore
  loader.set_cache(base.cache) |> ignore
  loader.set_path(base.path) |> ignore
  loader.set_response_type("arraybuffer") |> ignore
  loader.set_request_header(base.request_header) |> ignore
  loader.set_with_credentials(base.with_credentials) |> ignore
  loader.load(
    url,
    on_load=buffer => self.parse(buffer, on_load, on_error?),
    on_progress?,
    on_error?,
  )
}

///|
/// Parses Draco data from an `ArrayBuffer`.
pub fn DRACOLoader::parse(
  self : DRACOLoader,
  buffer : JsValue,
  on_load : (@core.BufferGeometry) -> Unit,
  on_error~ : (JsValue) -> Unit = _ => (),
) -> Unit {
  self
  .decode_draco_file(
    buffer,
    on_load,
    vertex_color_space=@core.SRGBColorSpace,
    on_error~,
  )
  .catch_(on_error)
  |> ignore
}

///|
/// Decodes `buffer`; `attribute_ids` maps attribute names to Draco unique IDs (glTF).
pub fn DRACOLoader::decode_draco_file(
  self : DRACOLoader,
  buffer : JsValue,
  callback : (@core.BufferGeometry) -> Unit,
  attribute_ids? : Map[String, Int32],
  attribute_types? : Map[String, String],
  vertex_color_space~ : String = @core.LinearSRGBColorSpace,
  on_error~ : (JsValue) -> Unit = _ => (),
) -> @utils.AddonPromise {
  let task_config = draco_task_config(
    match attribute_ids {
      Some(ids) => draco_object(ids)
      None => draco_object(self.default_attribute_ids)
    },
    match attribute_types {
      Some(types) => draco_object(types)
      None => draco_object(self.default_attribute_types)
    },
    attribute_ids is Some(_),
    vertex_color_space,
  )
  self.decode_geometry(buffer, task_config).then_(callback).catch_(on_error)
}

///|
fn DRACOLoader::decode_geometry(
  self : DRACOLoader,
  buffer : JsValue,
  task_config : JsValue,
) -> @utils.AddonPromise {
  let task_key = draco_json_stringify(task_config)

  // Check for an existing task using this buffer. A transferred buffer cannot be transferred
  // again from this thread.
  if draco_task_cache.get(buffer) is Some(cached_task) {
    if cached_task.key == task_key {
      return cached_task.promise
    } else if draco_byte_length(buffer) == 0 {
      // Technically, it would be possible to wait for the previous task to complete,
      // transfer the buffer back, and decode again with the second configuration. That
      // is complex, and I don't know of any reason to decode a Draco buffer twice in
      // different ways, so this is left unimplemented.
      @utils.addon_throw_error(
        "THREE.DRACOLoader: Unable to re-decode a buffer with different " +
        "settings. Buffer has already been transferred.",
      )
    }
  }

  //
  let mut worker : DracoWorker? = None
  let task_id = self.worker_next_task_id
  self.worker_next_task_id += 1
  let task_cost = draco_byte_length(buffer)

  // Obtain a worker and assign a task, and construct a geometry instance
  // when the task completes.
  let geometry_pending = self
    .get_worker(task_id, task_cost)
    .then_((w : DracoWorker) => {
      worker = Some(w)
      @utils.AddonPromise::new((resolve, reject) => {
        w.callbacks[task_id] = { resolve, reject, }
        draco_worker_post_decode(w.worker, task_id, task_config, buffer)
      })
    })
    .then_((message : JsValue) => self.create_geometry(message.get("geometry")))

  // Remove task from the task list.
  // Note: replaced '.finally()' with '.catch().then()' block - iOS 11 support (#19416)
  geometry_pending
  .catch_(_ => true)
  .then_((_ : JsValue) => {
    if worker is Some(w) && task_id != 0 {
      self.release_task(w, task_id)
    }
  })
  |> ignore

  // Cache the task result.
  draco_task_cache.set(buffer, { key: task_key, promise: geometry_pending, })
  geometry_pending
}

///|
fn DRACOLoader::create_geometry(
  self : DRACOLoader,
  geometry_data : JsValue,
) -> @core.BufferGeometry {
  let geometry = @core.BufferGeometry::new()
  let index = geometry_data.get("index")
  if draco_truthy(index) {
    geometry.set_index(@core.BufferAttribute::new(index.get("array").cast(), 1))
    |> ignore
  }
  let attributes : Array[JsValue] = geometry_data.get("attributes").cast()
  for i in 0..<attributes.length() {
    let data = attributes[i]
    let name : String = data.get("name").cast()
    let array = data.get("array")
    let item_size : Int32 = data.get("itemSize").cast()
    let stride : Int32 = data.get("stride").cast()
    let vertex_color_space = data.get("vertexColorSpace")
    let attribute = if item_size == stride {
      @core.GeometryAttribute::Buffer(
        @core.BufferAttribute::new(array.cast(), item_size),
      )
    } else {
      let buffer = @core.InterleavedBuffer::new(array.cast(), stride)
      @core.GeometryAttribute::Interleaved(
        @core.InterleavedBufferAttribute::new(buffer, item_size, 0),
      )
    }
    if name == "color" {
      self.assign_vertex_color_space(attribute, vertex_color_space)
      let normalized = draco_is_float32_array(array) == false
      match attribute {
        Buffer(a) => a.normalized = normalized
        Interleaved(a) => a.normalized = normalized
        GL(a) => a.normalized = normalized
      }
    }
    geometry.set_attribute(name, attribute) |> ignore
  }
  geometry
}

///|
fn DRACOLoader::assign_vertex_color_space(
  _self : DRACOLoader,
  attribute : @core.GeometryAttribute,
  input_color_space : JsValue,
) -> Unit {
  // While .drc files do not specify colorspace, the only 'official' tooling
  // is PLY and OBJ converters, which use sRGB. We'll assume sRGB when a .drc
  // file is passed into .load() or .parse(). GLTFLoader uses internal APIs
  // to decode geometry, and vertex colors are already Linear-sRGB in there.
  if !input_color_space.strict_equal(JsValue::of(@core.SRGBColorSpace)) {
    return
  }
  let color = @math.Color::new(1.0, 1.0, 1.0)
  for i in 0..<attribute.count() {
    color.from_buffer_attribute(attribute, i) |> ignore
    @math.color_management.color_space_to_working(color, @core.SRGBColorSpace)
    |> ignore
    attribute.set_xyz(i, color.r, color.g, color.b)
  }
}

///|
fn DRACOLoader::load_library(
  self : DRACOLoader,
  url : String,
  response_type : String,
) -> @utils.AddonPromise {
  let base = self.base
  let loader = @loaders.FileLoader::new(manager=base.manager)
  loader.set_priority(base.priority) |> ignore
  loader.set_cache(base.cache) |> ignore
  loader.set_response_type(response_type) |> ignore
  loader.set_with_credentials(base.with_credentials) |> ignore
  @utils.AddonPromise::new((resolve, reject) => {
    loader.load(url, on_load=resolve, on_error=reject)
  })
}

///|
/// Loads the decoder ahead of the first decode.
pub fn DRACOLoader::preload(self : DRACOLoader) -> DRACOLoader {
  self.init_decoder() |> ignore
  self
}

///|
fn DRACOLoader::init_decoder(self : DRACOLoader) -> @utils.AddonPromise {
  if self.decoder_pending is Some(pending) {
    return pending
  }
  let use_js = draco_use_js(self.decoder_config)
  let libraries_pending : Array[@utils.AddonPromise] = []
  let decoder_paths = self.decoder_paths
  if use_js {
    guard decoder_paths.dep_js is Some(dep_js) else {
      @utils.addon_throw_error(
        "THREE.DRACOLoader: WebAssembly is required when using a custom decoder paths.",
      )
    }
    libraries_pending.push(self.load_library(dep_js, "text"))
  } else {
    libraries_pending.push(self.load_library(decoder_paths.js, "text"))
    libraries_pending.push(self.load_library(decoder_paths.wasm, "arraybuffer"))
  }
  let pending = @utils.AddonPromise::all(libraries_pending).then_((
    libraries : Array[JsValue],
  ) => {
    let js_content : String = libraries[0].cast()
    if !use_js {
      self.decoder_config.set("wasmBinary", libraries[1])
    }
    let body = [
      "/* draco decoder */", js_content, "", "/* worker */", draco_worker_body,
    ].join("\n")
    self.worker_source_url = draco_create_object_url(body)
    JsValue::undefined()
  })
  self.decoder_pending = Some(pending)
  pending
}

///|
fn DRACOLoader::get_worker(
  self : DRACOLoader,
  task_id : Int32,
  task_cost : Int32,
) -> @utils.AddonPromise {
  self
  .init_decoder()
  .then_((_ : JsValue) => {
    if self.worker_pool.length() < self.worker_limit {
      let worker : DracoWorker = {
        worker: draco_new_worker(self.worker_source_url),
        callbacks: {},
        task_costs: {},
        task_load: 0,
      }
      draco_worker_post_init(worker.worker, self.decoder_config)
      draco_worker_set_onmessage(worker.worker, message => {
        let type_ : String = message.get("type").cast()
        match type_ {
          "decode" => (draco_callbacks(worker, message).resolve)(message)
          "error" => (draco_callbacks(worker, message).reject)(message)
          _ =>
            draco_console_error(
              "THREE.DRACOLoader: Unexpected message, \"" + type_ + "\"",
            )
        }
      })
      self.worker_pool.push(worker)
    } else {
      draco_sort_workers(self.worker_pool, (a, b) => {
        if a.task_load > b.task_load {
          -1.0
        } else {
          1.0
        }
      })
    }
    guard self.worker_pool.last() is Some(worker) else {
      @utils.addon_throw(
        draco_type_error(
          "Cannot read properties of undefined (reading '_taskCosts')",
        ),
      )
    }
    worker.task_costs[task_id] = task_cost
    worker.task_load += task_cost
    worker
  })
}

///|
/// `worker._callbacks[ message.id ]`.
fn draco_callbacks(
  worker : DracoWorker,
  message : JsValue,
) -> DracoTaskCallbacks {
  let id : Int32 = message.get("id").cast()
  match worker.callbacks.get(id) {
    Some(callbacks) => callbacks
    None =>
      @utils.addon_throw(
        draco_type_error(
          "Cannot read properties of undefined (reading '" +
          (if message.get("type").cast() == "decode" {
            "resolve"
          } else {
            "reject"
          }) +
          "')",
        ),
      )
  }
}

///|
fn DRACOLoader::release_task(
  _self : DRACOLoader,
  worker : DracoWorker,
  task_id : Int32,
) -> Unit {
  worker.task_load -= worker.task_costs.get(task_id).unwrap_or(0)
  worker.callbacks.remove(task_id)
  worker.task_costs.remove(task_id)
}

///|
/// Logs each worker's task load.
pub fn DRACOLoader::debug(self : DRACOLoader) -> Unit {
  draco_console_log(
    "Task load: ",
    JsValue::of(self.worker_pool.map(worker => worker.task_load)),
  )
}

///|
/// Terminates the workers and revokes the worker source URL.
pub fn DRACOLoader::dispose(self : DRACOLoader) -> DRACOLoader {
  for i in 0..<self.worker_pool.length() {
    draco_worker_terminate(self.worker_pool[i].worker)
  }
  self.worker_pool.clear()
  if self.worker_source_url != "" {
    draco_revoke_object_url(self.worker_source_url)
  }
  self
}

///|
/// Upstream `DRACOWorker`'s body, sent to the workers verbatim.
let draco_worker_body : String =
  #|
  #|
  #|	let decoderConfig;
  #|	let decoderPending;
  #|
  #|	onmessage = function ( e ) {
  #|
  #|		const message = e.data;
  #|
  #|		switch ( message.type ) {
  #|
  #|			case 'init':
  #|				decoderConfig = message.decoderConfig;
  #|				decoderPending = new Promise( function ( resolve/*, reject*/ ) {
  #|
  #|					decoderConfig.onModuleLoaded = function ( draco ) {
  #|
  #|						// Module is Promise-like. Wrap before resolving to avoid loop.
  #|						resolve( { draco: draco } );
  #|
  #|					};
  #|
  #|					DracoDecoderModule( decoderConfig ); // eslint-disable-line no-undef
  #|
  #|				} );
  #|				break;
  #|
  #|			case 'decode':
  #|				const buffer = message.buffer;
  #|				const taskConfig = message.taskConfig;
  #|				decoderPending.then( ( module ) => {
  #|
  #|					const draco = module.draco;
  #|					const decoder = new draco.Decoder();
  #|
  #|					try {
  #|
  #|						const geometry = decodeGeometry( draco, decoder, new Int8Array( buffer ), taskConfig );
  #|
  #|						const buffers = geometry.attributes.map( ( attr ) => attr.array.buffer );
  #|
  #|						if ( geometry.index ) buffers.push( geometry.index.array.buffer );
  #|
  #|						self.postMessage( { type: 'decode', id: message.id, geometry }, buffers );
  #|
  #|					} catch ( error ) {
  #|
  #|						console.error( error );
  #|
  #|						self.postMessage( { type: 'error', id: message.id, error: error.message } );
  #|
  #|					} finally {
  #|
  #|						draco.destroy( decoder );
  #|
  #|					}
  #|
  #|				} );
  #|				break;
  #|
  #|		}
  #|
  #|	};
  #|
  #|	function decodeGeometry( draco, decoder, array, taskConfig ) {
  #|
  #|		const attributeIDs = taskConfig.attributeIDs;
  #|		const attributeTypes = taskConfig.attributeTypes;
  #|
  #|		let dracoGeometry;
  #|		let decodingStatus;
  #|
  #|		const geometryType = decoder.GetEncodedGeometryType( array );
  #|
  #|		if ( geometryType === draco.TRIANGULAR_MESH ) {
  #|
  #|			dracoGeometry = new draco.Mesh();
  #|			decodingStatus = decoder.DecodeArrayToMesh( array, array.byteLength, dracoGeometry );
  #|
  #|		} else if ( geometryType === draco.POINT_CLOUD ) {
  #|
  #|			dracoGeometry = new draco.PointCloud();
  #|			decodingStatus = decoder.DecodeArrayToPointCloud( array, array.byteLength, dracoGeometry );
  #|
  #|		} else {
  #|
  #|			throw new Error( 'THREE.DRACOLoader: Unexpected geometry type.' );
  #|
  #|		}
  #|
  #|		if ( ! decodingStatus.ok() || dracoGeometry.ptr === 0 ) {
  #|
  #|			throw new Error( 'THREE.DRACOLoader: Decoding failed: ' + decodingStatus.error_msg() );
  #|
  #|		}
  #|
  #|		const geometry = { index: null, attributes: [] };
  #|
  #|		// Gather all vertex attributes.
  #|		for ( const attributeName in attributeIDs ) {
  #|
  #|			const attributeType = self[ attributeTypes[ attributeName ] ];
  #|
  #|			let attribute;
  #|			let attributeID;
  #|
  #|			// A Draco file may be created with default vertex attributes, whose attribute IDs
  #|			// are mapped 1:1 from their semantic name (POSITION, NORMAL, ...). Alternatively,
  #|			// a Draco file may contain a custom set of attributes, identified by known unique
  #|			// IDs. glTF files always do the latter, and `.drc` files typically do the former.
  #|			if ( taskConfig.useUniqueIDs ) {
  #|
  #|				attributeID = attributeIDs[ attributeName ];
  #|				attribute = decoder.GetAttributeByUniqueId( dracoGeometry, attributeID );
  #|
  #|			} else {
  #|
  #|				attributeID = decoder.GetAttributeId( dracoGeometry, draco[ attributeIDs[ attributeName ] ] );
  #|
  #|				if ( attributeID === - 1 ) continue;
  #|
  #|				attribute = decoder.GetAttribute( dracoGeometry, attributeID );
  #|
  #|			}
  #|
  #|			const attributeResult = decodeAttribute( draco, decoder, dracoGeometry, attributeName, attributeType, attribute );
  #|
  #|			if ( attributeName === 'color' ) {
  #|
  #|				attributeResult.vertexColorSpace = taskConfig.vertexColorSpace;
  #|
  #|			}
  #|
  #|			geometry.attributes.push( attributeResult );
  #|
  #|		}
  #|
  #|		// Add index.
  #|		if ( geometryType === draco.TRIANGULAR_MESH ) {
  #|
  #|			geometry.index = decodeIndex( draco, decoder, dracoGeometry );
  #|
  #|		}
  #|
  #|		draco.destroy( dracoGeometry );
  #|
  #|		return geometry;
  #|
  #|	}
  #|
  #|	function decodeIndex( draco, decoder, dracoGeometry ) {
  #|
  #|		const numFaces = dracoGeometry.num_faces();
  #|		const numIndices = numFaces * 3;
  #|		const byteLength = numIndices * 4;
  #|
  #|		const ptr = draco._malloc( byteLength );
  #|		decoder.GetTrianglesUInt32Array( dracoGeometry, byteLength, ptr );
  #|		const index = new Uint32Array( draco.HEAPF32.buffer, ptr, numIndices ).slice();
  #|		draco._free( ptr );
  #|
  #|		return { array: index, itemSize: 1 };
  #|
  #|	}
  #|
  #|	function decodeAttribute( draco, decoder, dracoGeometry, attributeName, TypedArray, attribute ) {
  #|
  #|		const count = dracoGeometry.num_points();
  #|		const itemSize = attribute.num_components();
  #|		const dracoDataType = getDracoDataType( draco, TypedArray );
  #|
  #|		// Reference: https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#data-alignment
  #|		const srcByteStride = itemSize * TypedArray.BYTES_PER_ELEMENT;
  #|		const dstByteStride = Math.ceil( srcByteStride / 4 ) * 4;
  #|
  #|		const dstStride = dstByteStride / TypedArray.BYTES_PER_ELEMENT;
  #|
  #|		const srcByteLength = count * srcByteStride;
  #|		const dstByteLength = count * dstByteStride;
  #|
  #|		const ptr = draco._malloc( srcByteLength );
  #|		decoder.GetAttributeDataArrayForAllPoints( dracoGeometry, attribute, dracoDataType, srcByteLength, ptr );
  #|
  #|		const srcArray = new TypedArray( draco.HEAPF32.buffer, ptr, srcByteLength / TypedArray.BYTES_PER_ELEMENT );
  #|		let dstArray;
  #|
  #|		if ( srcByteStride === dstByteStride ) {
  #|
  #|			// THREE.BufferAttribute
  #|
  #|			dstArray = srcArray.slice();
  #|
  #|		} else {
  #|
  #|			// THREE.InterleavedBufferAttribute
  #|
  #|			dstArray = new TypedArray( dstByteLength / TypedArray.BYTES_PER_ELEMENT );
  #|
  #|			let dstOffset = 0;
  #|
  #|			for ( let i = 0; i < count; i ++ ) {
  #|
  #|				for ( let j = 0; j < itemSize; j ++ ) {
  #|
  #|					dstArray[ dstOffset + j ] = srcArray[ i * itemSize + j ];
  #|
  #|				}
  #|
  #|				dstOffset += dstStride;
  #|
  #|			}
  #|
  #|		}
  #|
  #|		draco._free( ptr );
  #|
  #|		return {
  #|			name: attributeName,
  #|			count: count,
  #|			itemSize: itemSize,
  #|			array: dstArray,
  #|			stride: dstStride
  #|		};
  #|
  #|	}
  #|
  #|	function getDracoDataType( draco, TypedArray ) {
  #|
  #|		switch ( TypedArray ) {
  #|
  #|			case Float32Array: return draco.DT_FLOAT32;
  #|			case Int8Array: return draco.DT_INT8;
  #|			case Int16Array: return draco.DT_INT16;
  #|			case Int32Array: return draco.DT_INT32;
  #|			case Uint8Array: return draco.DT_UINT8;
  #|			case Uint16Array: return draco.DT_UINT16;
  #|			case Uint32Array: return draco.DT_UINT32;
  #|
  #|		}
  #|
  #|	}
  #|
  #|
