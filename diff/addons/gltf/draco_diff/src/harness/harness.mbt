///|
using @core {type JsValue}

///|
pub fn new_loader() -> @aloaders.DRACOLoader {
  @aloaders.DRACOLoader::new()
}

///|
pub fn set_decoder_path(l : @aloaders.DRACOLoader, path : String) -> Unit {
  l.set_decoder_path(path) |> ignore
}

///|
pub fn set_decoder_path_gltf(
  l : @aloaders.DRACOLoader,
  js : String,
  wasm : String,
) -> Unit {
  l.set_decoder_path_config(js, wasm) |> ignore
}

///|
pub fn gltf_config() -> JsValue {
  let o = JsValue::object()
  o.set("js", JsValue::of(@aloaders.draco_gltf_config.js))
  o.set("wasm", JsValue::of(@aloaders.draco_gltf_config.wasm))
  o
}

///|
pub fn set_decoder_config(l : @aloaders.DRACOLoader, config : JsValue) -> Unit {
  l.set_decoder_config(config) |> ignore
}

///|
pub fn set_worker_limit(l : @aloaders.DRACOLoader, n : Int) -> Unit {
  l.set_worker_limit(n) |> ignore
}

///|
pub fn preload(l : @aloaders.DRACOLoader) -> Unit {
  l.preload() |> ignore
}

///|
pub fn load(
  l : @aloaders.DRACOLoader,
  url : String,
  on_load : (@core.BufferGeometry) -> Unit,
  on_error : (JsValue) -> Unit,
) -> Unit {
  l.load(url, on_load, on_error~)
}

///|
pub fn parse(
  l : @aloaders.DRACOLoader,
  buffer : JsValue,
  on_load : (@core.BufferGeometry) -> Unit,
  on_error : (JsValue) -> Unit,
) -> Unit {
  l.parse(buffer, on_load, on_error~)
}

///|
/// `ids` / `types`: JS arrays of [name, value] pairs, or null for the defaults.
pub fn decode(
  l : @aloaders.DRACOLoader,
  buffer : JsValue,
  callback : (@core.BufferGeometry) -> Unit,
  ids : JsValue,
  types : JsValue,
  color_space : JsValue,
  on_error : (JsValue) -> Unit,
) -> @utils.AddonPromise {
  let attribute_ids = if ids.is_null() {
    None
  } else {
    let m : Map[String, Int] = {}
    let pairs : Array[Array[JsValue]] = ids.cast()
    for p in pairs {
      m[p[0].cast()] = p[1].cast()
    }
    Some(m)
  }
  let attribute_types = if types.is_null() {
    None
  } else {
    let m : Map[String, String] = {}
    let pairs : Array[Array[JsValue]] = types.cast()
    for p in pairs {
      m[p[0].cast()] = p[1].cast()
    }
    Some(m)
  }
  if color_space.is_undefined() {
    l.decode_draco_file(buffer, callback, attribute_ids?, attribute_types?, on_error~)
  } else {
    l.decode_draco_file(
      buffer,
      callback,
      attribute_ids?,
      attribute_types?,
      vertex_color_space=color_space.cast(),
      on_error~,
    )
  }
}

///|
pub fn dispose(l : @aloaders.DRACOLoader) -> Unit {
  l.dispose() |> ignore
}

///|
pub fn debug(l : @aloaders.DRACOLoader) -> Unit {
  l.debug()
}

///|
/// The geometry as plain data: attributes in order, index.
pub fn summary(g : @core.BufferGeometry) -> JsValue {
  let attrs : Array[JsValue] = []
  for name, a in g.attributes {
    let o = JsValue::object()
    o.set("name", JsValue::of(name))
    match a {
      Buffer(b) => {
        o.set("interleaved", JsValue::of(false))
        o.set("array", JsValue::of(b.array))
        o.set("itemSize", JsValue::of(b.item_size))
        o.set("count", JsValue::of(b.count))
        o.set("normalized", JsValue::of(b.normalized))
        o.set("attrName", JsValue::of(b.name))
      }
      Interleaved(b) => {
        o.set("interleaved", JsValue::of(true))
        o.set("array", JsValue::of(b.data.array))
        o.set("stride", JsValue::of(b.data.stride))
        o.set("offset", JsValue::of(b.offset))
        o.set("itemSize", JsValue::of(b.item_size))
        o.set("count", JsValue::of(b.count()))
        o.set("normalized", JsValue::of(b.normalized))
        o.set("attrName", JsValue::of(b.name))
      }
      GL(_) => o.set("gl", JsValue::of(true))
    }
    attrs.push(o)
  }
  let r = JsValue::object()
  r.set("attributes", JsValue::of(attrs))
  match g.index {
    Some(Buffer(b)) => {
      let o = JsValue::object()
      o.set("array", JsValue::of(b.array))
      o.set("itemSize", JsValue::of(b.item_size))
      o.set("count", JsValue::of(b.count))
      o.set("normalized", JsValue::of(b.normalized))
      r.set("index", o)
    }
    Some(_) => r.set("index", JsValue::of("non-buffer"))
    None => r.set("index", JsValue::null())
  }
  r.set("type", JsValue::of(g.type_))
  r.set("groups", JsValue::of(g.groups.length()))
  r
}
