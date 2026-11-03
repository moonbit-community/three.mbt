// Upstream src/loaders/BufferGeometryLoader.js.

///|
/// Loads geometries in the JSON format of `BufferGeometry::to_json`.
pub struct BufferGeometryLoader {
  base : Loader
}

///|
pub fn BufferGeometryLoader::new(
  manager? : LoadingManager,
) -> BufferGeometryLoader {
  { base: Loader::new(manager?), }
}

///|
pub impl LoaderLike for BufferGeometryLoader with fn loader(self) {
  self.base
}

///|
pub impl LoaderSettings for BufferGeometryLoader

///|
pub extend BufferGeometryLoader with LoaderLike::{loader}

///|
pub extend BufferGeometryLoader with LoaderSettings::{
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
/// Loads `url` through `FileLoader`, parses it as JSON and then with `parse`.
/// `on_load` and `on_error` follow upstream's shared `load` of the JSON loaders.
fn json_loader_load(
  base : Loader,
  url : String,
  parse : (Json) -> Unit,
  on_progress : ((ProgressEvent) -> Unit)?,
  on_error : ((JsValue) -> Unit)?,
) -> Unit {
  let loader = FileLoader::new(manager=base.manager)
    .set_priority(base.priority)
    .set_cache(base.cache)
    .set_path(base.path)
    .set_request_header(base.request_header)
    .set_with_credentials(base.with_credentials)
  loader.load(
    url,
    on_load=text => {
      let result = js_try(() => {
        match loaders_parse_json(text) {
          Ok(json) => parse(json)
          Err(e) => ignore(js_throw(e))
        }
      })
      if !result.ok() {
        if on_error is Some(on_error) {
          on_error(result.error())
        } else {
          loaders_error_value(result.error())
        }
        base.manager.item_error(url)
      }
    },
    on_progress?,
    on_error?,
  )
}

///|
/// Starts loading `url`; `on_load` receives the geometry.
pub fn BufferGeometryLoader::load(
  self : BufferGeometryLoader,
  url : String,
  on_load : (@core.BufferGeometry) -> Unit,
  on_progress? : (ProgressEvent) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> Unit {
  json_loader_load(
    self.base,
    url,
    json => on_load(self.parse(json)),
    on_progress,
    on_error,
  )
}

///|
/// Upstream `loadAsync`.
pub async fn BufferGeometryLoader::load_async(
  self : BufferGeometryLoader,
  url : String,
  on_progress? : (ProgressEvent) -> Unit,
) -> @core.BufferGeometry raise LoaderError {
  loader_promise((resolve, reject) => {
    self.load(url, resolve, on_progress?, on_error=reject)
  })
}

///|
/// Builds one attribute; `instanced` selects `InstancedBufferAttribute` as upstream
/// does for the top-level attributes.
fn buffer_geometry_loader_attribute(
  attribute : Map[String, Json],
  get_interleaved_buffer : (String) -> @core.InterleavedBuffer,
  instanced : Bool,
) -> @core.GeometryAttribute {
  let item_size = json_number(json_field(attribute, "itemSize"), "itemSize").to_int()
  let normalized = json_opt_bool(attribute, "normalized").unwrap_or(false)
  if json_truthy(attribute.get("isInterleavedBufferAttribute")) {
    let interleaved_buffer = get_interleaved_buffer(
      json_string(json_field(attribute, "data"), "data"),
    )
    let buffer_attribute = @core.InterleavedBufferAttribute::new(
      interleaved_buffer,
      item_size,
      json_opt_number(attribute, "offset").unwrap_or(0.0).to_int(),
      normalized~,
    )
    if json_opt_string(attribute, "name") is Some(name) {
      buffer_attribute.name = name
    }
    if attribute.get("usage") is Some(_) {
      // `InterleavedBufferAttribute` has no `setUsage`
      abort("BufferGeometryLoader: bufferAttribute.setUsage is not a function")
    }
    if attribute.get("gpuType") is Some(_) {
      abort("BufferGeometryLoader: InterleavedBufferAttribute has no gpuType")
    }
    return Interleaved(buffer_attribute)
  }
  let typed_array = json_typed_array(
    json_field(attribute, "type"),
    json_field(attribute, "array"),
    "attribute",
  )
  let buffer_attribute = if instanced &&
    json_truthy(attribute.get("isInstancedBufferAttribute")) {
    @core.InstancedBufferAttribute::new(typed_array, item_size, normalized~)
  } else {
    @core.BufferAttribute::new(typed_array, item_size, normalized~)
  }
  if json_opt_string(attribute, "name") is Some(name) {
    buffer_attribute.name = name
  }
  if json_opt_int(attribute, "usage") is Some(usage) {
    buffer_attribute.set_usage(usage) |> ignore
  }
  if json_opt_int(attribute, "gpuType") is Some(gpu_type) {
    buffer_attribute.gpu_type = gpu_type
  }
  Buffer(buffer_attribute)
}

///|
/// Parses `json` into a `BufferGeometry` (or `InstancedBufferGeometry`).
pub fn BufferGeometryLoader::parse(
  self : BufferGeometryLoader,
  json : Json,
) -> @core.BufferGeometry {
  ignore(self)
  let json = json_object(json, "BufferGeometryLoader")
  let interleaved_buffer_map : Map[String, @core.InterleavedBuffer] = Map([])
  let array_buffer_map : Map[String, @core.ArrayBuffer] = Map([])
  let data = json_object(json_field(json, "data"), "data")
  fn get_array_buffer(uuid : String) -> @core.ArrayBuffer {
    if array_buffer_map.get(uuid) is Some(buffer) {
      return buffer
    }
    let array_buffers = json_object(
      json_field(data, "arrayBuffers"),
      "arrayBuffers",
    )
    let array_buffer = json_numbers(
      json_field(array_buffers, uuid),
      "arrayBuffer",
    )
    let ab = @core.TypedArray::uint32(array_buffer).buffer()
    array_buffer_map[uuid] = ab
    ab
  }

  fn get_interleaved_buffer(uuid : String) -> @core.InterleavedBuffer {
    if interleaved_buffer_map.get(uuid) is Some(buffer) {
      return buffer
    }
    let interleaved_buffers = json_object(
      json_field(data, "interleavedBuffers"),
      "interleavedBuffers",
    )
    let interleaved_buffer = json_object(
      json_field(interleaved_buffers, uuid),
      "interleavedBuffer",
    )
    let buffer = get_array_buffer(
      json_string(json_field(interleaved_buffer, "buffer"), "buffer"),
    )
    let array = @core.TypedArray::view_by_name(
      json_string(json_field(interleaved_buffer, "type"), "type"),
      buffer,
    )
    let ib = @core.InterleavedBuffer::new(
      array,
      json_number(json_field(interleaved_buffer, "stride"), "stride").to_int(),
    )
    ib.uuid = json_string(json_field(interleaved_buffer, "uuid"), "uuid")
    if json_opt_int(interleaved_buffer, "usage") is Some(usage) {
      ib.set_usage(usage) |> ignore
    }
    interleaved_buffer_map[uuid] = ib
    ib
  }

  let geometry = if json_truthy(json.get("isInstancedBufferGeometry")) {
    @core.InstancedBufferGeometry::new()
  } else {
    @core.BufferGeometry::new()
  }
  if data.get("index") is Some(index) {
    let index = json_object(index, "index")
    let typed_array = json_typed_array(
      json_field(index, "type"),
      json_field(index, "array"),
      "index",
    )
    geometry.set_index(@core.BufferAttribute::new(typed_array, 1)) |> ignore
  }
  let attributes = json_object(json_field(data, "attributes"), "attributes")
  for key, attribute in attributes {
    let buffer_attribute = buffer_geometry_loader_attribute(
      json_object(attribute, "attribute"),
      get_interleaved_buffer,
      true,
    )
    geometry.set_attribute(key, buffer_attribute) |> ignore
  }
  let morph_attributes = data.get("morphAttributes")
  if json_truthy(morph_attributes) {
    for
      key, attribute_array in json_object(
        morph_attributes.unwrap(),
        "morphAttributes",
      ) {
      let array = []
      for attribute in json_array(attribute_array, "morphAttributes") {
        array.push(
          buffer_geometry_loader_attribute(
            json_object(attribute, "attribute"),
            get_interleaved_buffer,
            false,
          ),
        )
      }
      geometry.morph_attributes[key] = array
    }
  }
  if json_truthy(data.get("morphTargetsRelative")) {
    geometry.morph_targets_relative = true
  }
  let groups = if json_truthy(data.get("groups")) {
    data.get("groups")
  } else if json_truthy(data.get("drawcalls")) {
    data.get("drawcalls")
  } else {
    data.get("offsets")
  }
  if groups is Some(groups) {
    for group in json_array(groups, "groups") {
      let group = json_object(group, "group")
      geometry.add_group(
        json_number(json_field(group, "start"), "start").to_int(),
        json_number(json_field(group, "count"), "count"),
        material_index?=json_opt_int(group, "materialIndex"),
      )
    }
  }
  if data.get("boundingSphere") is Some(bounding_sphere) {
    geometry.bounding_sphere = Some(
      @math.Sphere::new().from_json(bounding_sphere),
    )
  }
  if json_truthy(json.get("name")) {
    geometry.name = json_string(json.get("name").unwrap(), "name")
  }
  if json_truthy(json.get("userData")) {
    geometry.user_data = JsValue::from_json(json.get("userData").unwrap())
  }
  geometry
}
