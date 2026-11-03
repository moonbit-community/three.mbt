// The MoonBit side of the mock scenarios; each mirrors scenarios_upstream.mjs.

///|
fn text_header() -> Map[String, String] {
  { "X-Test": "yes", "Accept": "text/plain" }
}

///|
extern "js" fn js_bool(value : Bool) -> JsValue = "(b) => b"

///|
extern "js" fn js_same(a : JsValue, b : JsValue) -> Bool = "(a, b) => a === b"

///|
extern "js" fn js_get_string(value : JsValue, key : String) -> String = "(v, k) => String(v[k])"

///|
extern "js" fn js_byte_length(value : JsValue) -> Int = "(v) => v.byteLength"

///|
extern "js" fn js_error_name(value : JsValue) -> JsValue = "(e) => e.name"

///|
extern "js" fn js_new_uint8(buffer : JsValue) -> @core.TypedArray = "(b) => new Uint8Array(b)"

///|
extern "js" fn js_throw_error(message : String) -> Unit = "(m) => { throw new Error(m); }"

///|
extern "js" fn js_then_note_result(
  promise : @js_async.Promise[JsValue],
  ok : String,
  err : String,
) -> Unit =
  #|(p, ok, err) => { p.then(r => r.ok ? globalThis.__note(ok, r.value) : globalThis.__note(err, r.value), e => globalThis.__note(err + ' (moonbit)', String(e))); }

///|
extern "js" fn js_result(ok : Bool, value : JsValue) -> JsValue = "(ok, value) => ({ ok, value })"

///|
/// Notes the value of `f` under `ok`, or the `LoaderError` value under `err`.
fn js_then_note(f : async () -> JsValue raise @loaders.LoaderError, ok : String, err : String) -> Unit {
  js_then_note_result(
    @js_async.Promise::from_async(async fn() -> JsValue {
      js_result(true, f()) catch {
        @loaders.LoaderError(e) => js_result(false, e)
      }
    }),
    ok,
    err,
  )
}

///|
fn image_src(texture : @core.Texture) -> String {
  match texture.image() {
    DomImage(image) => js_get_string(image, "src")
    _ => "no image"
  }
}

///|
fn image_value(texture : @core.Texture) -> JsValue {
  texture.image().to_js()
}

///|
fn scenario_file_basic() -> Unit {
  let manager = manager_with_log("m")
  let loader = @loaders.FileLoader::new(manager~)
  loader
  .set_path("base/")
  .set_request_header(text_header())
  .set_with_credentials(true)
  .set_priority("high")
  .set_cache("no-store")
  |> ignore
  loader.load(
    "a.txt",
    on_load=d => note("a.onLoad", d),
    on_progress=e => note("a.onProgress", e.to_js()),
    on_error=e => note("a.onError", e),
  )
  loader.load(
    "a.txt",
    on_load=d => note("a2.onLoad", d),
    on_progress=e => note("a2.onProgress", e.to_js()),
    on_error=e => note("a2.onError", e),
  )
  loader.load("b.txt", on_load=d => note("b.onLoad", d))
  note_s("sync end", "")
}

///|
fn scenario_file_response_types() -> Unit {
  let m = manager_with_log("m")
  @loaders.FileLoader::new(manager=m)
  .set_response_type("arraybuffer")
  .load("r/ab.bin", on_load=d => note("ab", d))
  @loaders.FileLoader::new(manager=m)
  .set_response_type("json")
  .load("r/data.json", on_load=d => note("json", d))
  @loaders.FileLoader::new(manager=m)
  .set_response_type("blob")
  .load("r/blob.bin", on_load=d => note("blob", d))
  @loaders.FileLoader::new(manager=m)
  .set_response_type("document")
  .set_mime_type("text/xml")
  .load("r/doc.xml", on_load=d => note("doc", d))
  @loaders.FileLoader::new(manager=m)
  .set_mime_type("text/plain; charset=\"ISO-8859-1\"")
  .load("r/latin.txt", on_load=d => note("latin", d))
  @loaders.FileLoader::new(manager=m)
  .set_mime_type("text/plain")
  .load("r/plain.txt", on_load=d => note("plain", d))
}

///|
fn scenario_file_errors() -> Unit {
  let m = manager_with_log("m")
  let l = @loaders.FileLoader::new(manager=m)
  l.load(
    "e/404.txt",
    on_load=d => note("404.onLoad", d),
    on_error=e => note("404.onError", e),
  )
  l.load(
    "e/net.txt",
    on_load=d => note("net.onLoad", d),
    on_error=e => note("net.onError", e),
  )
  l.load(
    "e/zero.txt",
    on_load=d => note("zero.onLoad", d),
    on_progress=e => note("zero.onProgress", e.to_js()),
  )
  l.load(
    "e/nolen.txt",
    on_load=d => note("nolen.onLoad", d),
    on_progress=e => note("nolen.onProgress", e.to_js()),
  )
  l.load(
    "e/nobody.txt",
    on_load=d => note("nobody.onLoad", d),
    on_progress=e => note("nobody.onProgress", e.to_js()),
  )
  l.load("e/missing.txt")
}

///|
fn scenario_file_cache_and_abort() -> Unit {
  @loaders.Cache::set_enabled(true)
  let m = manager_with_log("m")
  let l = @loaders.FileLoader::new(manager=m)
  l.load("c/x.txt", on_load=d => {
    note("x1", d)
    note("cached?", @loaders.Cache::get("file:c/x.txt").unwrap_or(JsValue::undefined()))
    l.load("c/x.txt", on_load=d2 => {
      note("x2", d2)
      @loaders.Cache::set_enabled(false)
      @loaders.Cache::clear()
    })
    note_s("after second load", "")
  })
}

///|
fn scenario_file_abort() -> Unit {
  let m = manager_with_log("m")
  let slow = @loaders.FileLoader::new(manager=m)
  slow.load(
    "c/slow.txt",
    on_load=d => note("slow.onLoad", d),
    on_error=e => note("slow.onError", e),
  )
  slow.abort() |> ignore
  slow.load(
    "c/after.txt",
    on_load=d => note("after.onLoad", d),
    on_error=e => note("after.onError", e),
  )
  let via_manager = @loaders.FileLoader::new(manager=m)
  via_manager.load(
    "c/slow2.txt",
    on_load=d => note("slow2.onLoad", d),
    on_error=e => note("slow2.onError", e),
  )
  m.abort() |> ignore
  note_s("aborted", "")
  @loaders.FileLoader::new(manager=m).load(
    "c/after.txt",
    on_load=d => note("after2.onLoad", d),
    on_error=e => note("after2.onError", e),
  )
}

///|
fn scenario_file_load_async() -> Unit {
  let l = @loaders.FileLoader::new(manager=manager_with_log("m"))
  js_then_note(
    (async fn() -> JsValue raise @loaders.LoaderError {
      l.load_async("p/ok.txt", on_progress=e => note("ok.progress", e.to_js()))
    }),
    "ok.resolved",
    "ok.rejected",
  )
  js_then_note(
    async fn() -> JsValue raise @loaders.LoaderError { l.load_async("p/bad.txt") },
    "bad.resolved",
    "bad.rejected",
  )
}


///|
fn scenario_image_loader() -> Unit {
  @loaders.Cache::set_enabled(true)
  let m = manager_with_log("m")
  let l = @loaders.ImageLoader::new(manager=m)
    .set_path("img/")
    .set_cross_origin("use-credentials")
    .set_priority("low")
  let a = l.load(
    "a.png",
    on_load=i => note("a.onLoad", i),
    on_error=e => note("a.onError", e),
  )
  note("returned", a)
  let s1 = l.load("slow.png", on_load=i => {
    note("slow1.onLoad", i)
    l.load("slow.png", on_load=i2 => {
      note("slow3.onLoad", i2)
      @loaders.Cache::set_enabled(false)
      @loaders.Cache::clear()
    })
    |> ignore
  })
  let s2 = l.load("slow.png", on_load=i => note("slow2.onLoad", i))
  note("same element", js_bool(js_same(s1, s2)))
  l.load(
    "missing.png",
    on_load=i => note("missing.onLoad", i),
    on_error=e => note("missing.onError", e),
  )
  |> ignore
  @loaders.ImageLoader::new(manager=m).load(
    "data:image/png;base64,AA",
    on_load=i => note("data.onLoad", i),
  )
  |> ignore
}

///|
fn scenario_texture_loader() -> Unit {
  let m = manager_with_log("m")
  let l = @loaders.TextureLoader::new(manager=m).set_path("t/")
  let tex : Ref[@core.Texture?] = Ref(None)
  tex.val = Some(
    l.load("a.png", on_load=t => {
      note("onLoad same", js_bool(physical_equal(t, tex.val.unwrap())))
      note("image", image_value(t))
      note("version", JsValue::of(t.version.to_double()))
      note_s(
        "size",
        "\{t.image().width().to_int()}x\{t.image().height().to_int()}",
      )
    }),
  )
  note("initial image", image_value(tex.val.unwrap()))
  note("initial version", JsValue::of(tex.val.unwrap().version.to_double()))
  l.load(
    "missing.png",
    on_load=t => note("missing.onLoad", image_value(t)),
    on_error=e => note("missing.onError", e),
  )
  |> ignore
  js_then_note(
    (async fn() -> JsValue raise @loaders.LoaderError {
      image_value(l.load_async("a.png"))
    }),
    "async image",
    "async image error",
  )
}

///|
fn scenario_cube_texture_loader() -> Unit {
  let m = manager_with_log("m")
  let l = @loaders.CubeTextureLoader::new(manager=m).set_path("cube/")
  let tex : Ref[@core.Texture?] = Ref(None)
  tex.val = Some(
    l.load(
      ["px.png", "nx.png", "py.png", "ny.png", "pz.png", "nz.png"],
      on_load=t => {
        note("onLoad", js_bool(physical_equal(t, tex.val.unwrap())))
        guard t.images() is ImageArray(images) else { abort("no images") }
        note_s(
          "images",
          images
          .map(i => {
            guard i is DomImage(i) else { abort("not an image") }
            js_get_string(i, "src")
          })
          .join(","),
        )
        note("version", JsValue::of(t.version.to_double()))
        note_s("colorSpace", t.color_space)
      },
    ),
  )
  guard tex.val.unwrap().images() is ImageArray(images) else { abort("no images") }
  note("initial images", JsValue::of(images.length().to_double()))
  @loaders.CubeTextureLoader::new(manager=m)
  .set_path("cube/")
  .load(
    ["px.png", "missing.png"],
    on_load=t => note("never", image_value(t)),
    on_error=e => note("cube.onError", e),
  )
  |> ignore
}

///|
fn scenario_image_bitmap_loader() -> Unit {
  @loaders.Cache::set_enabled(true)
  let m = manager_with_log("m")
  let l = @loaders.ImageBitmapLoader::new(manager=m)
  l
  .set_options({
    "imageOrientation": Json::string("flipY"),
    "premultiplyAlpha": Json::string("premultiply"),
  })
  .set_cross_origin("use-credentials")
  .set_request_header({ "R": "1" })
  |> ignore
  l.load(
    "bm/a.png",
    on_load=b => {
      note("a.onLoad", b)
      l.load("bm/a.png", on_load=b2 => {
        note("a3.onLoad", b2)
        @loaders.Cache::set_enabled(false)
        @loaders.Cache::clear()
      })
    },
    on_error=e => note("a.onError", e),
  )
  l.load("bm/a.png", on_load=b => note("a2.onLoad", b))
  l.load(
    "bm/empty.png",
    on_load=b => note("empty.onLoad", b),
    on_error=e => note("empty.onError", e),
  )
  l.load(
    "bm/empty.png",
    on_load=b => note("empty2.onLoad", b),
    on_error=e => note("empty2.onError", e),
  )
}

///|
fn scenario_json_loaders() -> Unit {
  let m = manager_with_log("m")
  @loaders.BufferGeometryLoader::new(manager=m).load("j/geo.json", g => {
    guard g.get_attribute("position") is Some(position) else { abort("no position") }
    note_s(
      "geo",
      position.array().to_array().map(v => v.to_int().to_string()).join(","),
    )
  })
  @loaders.BufferGeometryLoader::new(manager=m).load(
    "j/bad.json",
    _ => note_s("never", ""),
    on_error=e => note("bad.onError", js_error_name(e)),
  )
  @loaders.MaterialLoader::new(manager=m).load("j/mat.json", mat => {
    note_s(
      "mat",
      "\{mat.type_} \{mat.uuid} \{mat.color.unwrap().get_hex()} \{mat.shininess.unwrap().to_int()}",
    )
  })
  @loaders.ObjectLoader::new(manager=m).load(
    "j/scene.json",
    on_load=o => {
      guard o.get_material() is Some(Single(material)) else { abort("no material") }
      note_s(
        "scene.onLoad",
        "\{o.type_} \{o.uuid} \{image_src(material.map.unwrap())}",
      )
      note_s("cube images", "")
    },
    on_error=e => note("scene.onError", e),
  )
  @loaders.ObjectLoader::new(manager=m).load(
    "j/bad.json",
    on_load=_ => note_s("never", ""),
    on_error=e => note("badscene.onError", js_error_name(e)),
  )
  @loaders.ObjectLoader::new(manager=m).load(
    "j/geometry.json",
    on_load=_ => note_s("never", ""),
    on_error=e => note("geometry.onError", e),
  )
  let loader = @loaders.ObjectLoader::new(manager=m)
  js_then_note(
    (async fn() -> JsValue raise @loaders.LoaderError {
      let o = loader.load_async("j/scene.json")
      guard o.get_material() is Some(Single(material)) else { abort("no material") }
      JsValue::of("\{o.uuid} \{image_src(material.map.unwrap())}")
    }),
    "async scene",
    "async scene error",
  )
}

///|
fn scenario_data_texture_loader() -> Unit {
  let m = manager_with_log("m")
  let l = @loaders.DataTextureLoader::new(manager=m, parse=buffer => {
    if js_byte_length(buffer) == 3 {
      js_throw_error("parse failed")
    }
    let data = @loaders.DataTexData::new()
    data.width = Some(1)
    data.height = Some(1)
    data.data = Some(js_new_uint8(buffer))
    data.flip_y = Some(true)
    data.format = Some(@core.RedFormat)
    data.min_filter = Some(@core.NearestFilter)
    data.mipmap_count = Some(1)
    data.generate_mipmaps = Some(false)
    data
  })
  let tex : Ref[@core.Texture?] = Ref(None)
  tex.val = Some(
    l.load("d/a.bin", on_load=(t, td) => {
      guard t.image() is DataImage(image) else { abort("no data image") }
      let values = image.data.unwrap().to_array().map(v => v.to_int().to_string()).join(",")
      note_s(
        "onLoad",
        "\{physical_equal(t, tex.val.unwrap())} \{image.width}x\{image.height} \{values} \{t.min_filter} \{t.mag_filter} \{t.wrap_s} \{t.flip_y} \{t.format} \{t.version} \{t.generate_mipmaps} \{td.width.unwrap()}",
      )
    }),
  )
  l.load(
    "d/b.bin",
    on_load=(_, _) => note_s("never", ""),
    on_error=e => note("b.onError", e),
  )
  |> ignore
}

///|
fn scenario_audio_loader() -> Unit {
  let m = manager_with_log("m")
  let l = @loaders.AudioLoader::new(manager=m)
  l.load(
    "au/a.mp3",
    on_load=b => note("a.onLoad", b.to_js()),
    on_error=e => note("a.onError", e),
  )
  l.load(
    "au/empty.mp3",
    on_load=b => note("empty.onLoad", b.to_js()),
    on_error=e => note("empty.onError", e),
  )
}

///|
fn scenario_loading_manager() -> Unit {
  let m = manager_with_log("m")
  m.set_url_modifier(Some(url => "mod/" + url)) |> ignore
  note_s("resolve", m.resolve_url("caf\u{65}\u{301}.txt"))
  @loaders.FileLoader::new(manager=m).load("x.txt", on_load=d => note("x", d))
  let loader = @loaders.Loader::new()
  m.add_handler(@loaders.RegExp::new("\\.jpg$", flags="i"), loader) |> ignore
  m.add_handler(@loaders.RegExp::new("\\.png$", flags="gi"), @loaders.Loader::new())
  |> ignore
  fn is_loader(handler : &@loaders.LoaderLike?) -> Bool {
    handler is Some(handler) && physical_equal(handler.loader(), loader)
  }

  note("jpg", js_bool(is_loader(m.get_handler("foo.jpg"))))
  note("png", js_bool(m.get_handler("foo.png") is Some(_)))
  note("png again", js_bool(m.get_handler("foo.png") is Some(_)))
  note(
    "none",
    if m.get_handler("foo.gif") is Some(_) {
      JsValue::of("found")
    } else {
      JsValue::null()
    },
  )
  m.remove_handler(@loaders.RegExp::new("\\.jpg$", flags="i")) |> ignore
  note("still", js_bool(is_loader(m.get_handler("foo.jpg"))))
  note_s(
    "extract",
    @loaders.LoaderUtils::extract_url_base("/a/b/c.glb") +
    " " +
    @loaders.LoaderUtils::extract_url_base("c.glb"),
  )
  note_s(
    "resolveURL",
    [
      @loaders.LoaderUtils::resolve_url("/x.png", "https://h.com/a/b/"),
      @loaders.LoaderUtils::resolve_url("x.png", "a/"),
      @loaders.LoaderUtils::resolve_url("data:a,b", "a/"),
      @loaders.LoaderUtils::resolve_url("blob:x", "a/"),
      @loaders.LoaderUtils::resolve_url("//h/x", "a/"),
      @loaders.LoaderUtils::resolve_url("", "a/"),
    ].join(" "),
  )
}

///|
fn scenarios(name : String) -> Unit {
  match name {
    "file_basic" => scenario_file_basic()
    "file_response_types" => scenario_file_response_types()
    "file_errors" => scenario_file_errors()
    "file_cache_and_abort" => scenario_file_cache_and_abort()
    "file_abort" => scenario_file_abort()
    "file_load_async" => scenario_file_load_async()
    "image_loader" => scenario_image_loader()
    "texture_loader" => scenario_texture_loader()
    "cube_texture_loader" => scenario_cube_texture_loader()
    "image_bitmap_loader" => scenario_image_bitmap_loader()
    "json_loaders" => scenario_json_loaders()
    "data_texture_loader" => scenario_data_texture_loader()
    "audio_loader" => scenario_audio_loader()
    "loading_manager" => scenario_loading_manager()
    _ => abort("unknown scenario " + name)
  }
}
