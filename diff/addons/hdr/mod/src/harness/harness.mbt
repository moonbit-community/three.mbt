// MoonBit side of the a3_hdr differential harness; run.mjs calls these exports.

///|
pub fn unzlib(data : @core.TypedArray) -> @core.TypedArray {
  @libs.unzlib_sync(data)
}

///|
pub fn unzlib_opts(
  data : @core.TypedArray,
  out : @core.JsValue,
  dict : @core.JsValue,
) -> @core.TypedArray {
  let out : @core.TypedArray? = if out.is_undefined() { None } else { Some(out.cast()) }
  let dictionary : @core.TypedArray? = if dict.is_undefined() { None } else { Some(dict.cast()) }
  @libs.unzlib_sync(data, out?, dictionary?)
}

///|
extern "js" fn describe(
  texture : @core.JsValue,
  extra : @core.JsValue,
) -> @core.JsValue = "(t, e) => globalThis.__describe(t, e)"

///|
extern "js" fn describe_texture(t : @core.JsValue) -> @core.JsValue = "(t) => globalThis.__describeTexture(t)"

///|
extern "js" fn obj() -> @core.JsValue = "() => ({})"

///|
extern "js" fn set(o : @core.JsValue, k : String, v : @core.JsValue) -> Unit = "(o, k, v) => { o[k] = v; }"

///|
fn image_js(image : @core.TextureImage) -> @core.JsValue {
  match image {
    DataImage(img) => {
      let o = obj()
      set(o, "width", @core.JsValue::of(img.width))
      set(o, "height", @core.JsValue::of(img.height))
      set(o, "data", match img.data {
        Some(d) => @core.JsValue::of(d)
        None => @core.JsValue::undefined()
      })
      o
    }
    TextureImage(t) => texture_js(t)
    ImageArray(images) => {
      let a = images.map(image_js)
      @core.JsValue::of(FixedArray::from_array(a[:])) |> js_array_from
    }
    NoImage => @core.JsValue::undefined()
    DomImage(v) => v
  }
}

///|
extern "js" fn js_array_from(a : @core.JsValue) -> @core.JsValue = "(a) => Array.from(a)"

///|
fn texture_js(t : @core.Texture) -> @core.JsValue {
  let o = obj()
  set(o, "image", image_js(t.image()))
  set(o, "format", @core.JsValue::of(t.format))
  set(o, "type", @core.JsValue::of(t.type_))
  set(o, "colorSpace", @core.JsValue::of(t.color_space))
  set(o, "flipY", @core.JsValue::of(t.flip_y))
  set(o, "minFilter", @core.JsValue::of(t.min_filter))
  set(o, "magFilter", @core.JsValue::of(t.mag_filter))
  set(o, "wrapS", @core.JsValue::of(t.wrap_s))
  set(o, "wrapT", @core.JsValue::of(t.wrap_t))
  set(o, "mapping", @core.JsValue::of(t.mapping))
  set(o, "anisotropy", @core.JsValue::of(t.anisotropy))
  set(o, "generateMipmaps", @core.JsValue::of(t.generate_mipmaps))
  set(o, "mipmaps", @core.JsValue::of(t.mipmaps.length()))
  set(o, "version", @core.JsValue::of(t.version))
  o
}

///|
fn tex_data_js(d : @loaders.DataTexData) -> @core.JsValue {
  let o = match d.extra {
    Some(e) => e
    None => obj()
  }
  fn opt_int(k : String, v : Int?) {
    if v is Some(v) {
      set(o, k, @core.JsValue::of(v))
    }
  }

  opt_int("width", d.width)
  opt_int("height", d.height)
  opt_int("format", d.format)
  opt_int("type", d.type_)
  opt_int("minFilter", d.min_filter)
  opt_int("magFilter", d.mag_filter)
  if d.color_space is Some(c) {
    set(o, "colorSpace", @core.JsValue::of(c))
  }
  if d.flip_y is Some(f) {
    set(o, "flipY", @core.JsValue::of(f))
  }
  if d.generate_mipmaps is Some(f) {
    set(o, "generateMipmaps", @core.JsValue::of(f))
  }
  if d.data is Some(data) {
    set(o, "data", @core.JsValue::of(data))
  }
  o
}

///|
fn done_load(
  done : (@core.JsValue) -> Unit,
) -> (@core.Texture, @loaders.DataTexData) -> Unit {
  fn(t, d) { done(describe(texture_js(t), tex_data_js(d))) }
}

///|
extern "js" fn error_js(e : @core.JsValue) -> @core.JsValue = "(e) => ({ error: String(e && e.message), name: e && e.name })"

///|
pub fn hdr_load(url : String, type_ : Int, use_setter : Bool, done : (@core.JsValue) -> Unit) -> Unit {
  let loader = @aloaders.HDRLoader::new()
  if use_setter {
    loader.set_data_type(type_) |> ignore
  } else {
    loader.type_ = type_
  }
  loader.load(url, on_load=done_load(done), on_error=e => done(error_js(e))) |> ignore
}

///|
pub fn rgbe_load(url : String, type_ : Int, done : (@core.JsValue) -> Unit) -> Unit {
  let loader = @aloaders.RGBELoader::new()
  loader.set_data_type(type_) |> ignore
  loader.load(url, on_load=done_load(done), on_error=e => done(error_js(e))) |> ignore
}

///|
pub fn hdr_parse(buffer : @core.JsValue, type_ : Int) -> @core.JsValue {
  let loader = @aloaders.HDRLoader::new().set_data_type(type_)
  tex_data_js(loader.parse(buffer))
}

///|
pub fn exr_load(
  url : String,
  type_ : Int,
  format : Int,
  part : Int,
  done : (@core.JsValue) -> Unit,
) -> Unit {
  let loader = @aloaders.EXRLoader::new()
    .set_data_type(type_)
    .set_output_format(format)
    .set_part(part)
  loader.load(url, on_load=done_load(done), on_error=e => done(error_js(e))) |> ignore
}

///|
pub fn exr_parse(
  buffer : @core.JsValue,
  type_ : Int,
  format : Int,
  part : Int,
) -> @core.JsValue {
  let loader = @aloaders.EXRLoader::new()
  loader.type_ = type_
  loader.output_format = format
  loader.part = part
  tex_data_js(loader.parse(buffer))
}

///|
pub fn cube_load(
  path : String,
  urls : Array[String],
  type_ : Int,
  done : (@core.JsValue) -> Unit,
) -> Unit {
  let loader = @aloaders.HDRCubeTextureLoader::new().set_path(path)
  if type_ != 0 {
    loader.set_data_type(type_) |> ignore
  }
  let texture = loader.load(urls, on_load=t => done(describe_texture(texture_js(t))), on_error=e => done(error_js(e)))
  ignore(texture)
}

///|
pub fn ultra_load(url : String, type_ : Int, done : (@core.JsValue) -> Unit) -> Unit {
  let loader = @aloaders.UltraHDRLoader::new().set_data_type(type_)
  loader.load(url, on_load=done_load(done), on_error=e => done(error_js(e))) |> ignore
}

///|
extern "js" fn js_push(a : @core.JsValue, v : @core.JsValue) -> Int = "(a, v) => a.push(v)"

///|
extern "js" fn js_new_array() -> @core.JsValue = "() => []"

///|
extern "js" fn js_later(f : () -> Unit) -> Unit = "(f) => setTimeout(f, 50)"

///|
/// Like the upstream side: resolves with `{ loaded, errs }` on load, or `{ errs }` once
/// every corrupt face has reported its error.
pub fn cube_load_errors(
  path : String,
  urls : Array[String],
  done : (@core.JsValue) -> Unit,
) -> Unit {
  let errs = js_new_array()
  js_later_long(() => {
    let o = obj()
    set(o, "errs", errs)
    set(o, "timeout", @core.JsValue::of(true))
    done(o)
  })
  let bad = urls.filter(u => u == "bad.hdr").length()
  let loader = @aloaders.HDRCubeTextureLoader::new().set_path(path)
  loader.load(
    urls,
    on_load=t => {
      let o = obj()
      set(o, "loaded", describe_texture(texture_js(t)))
      set(o, "errs", errs)
      done(o)
    },
    on_error=e => {
      if js_push(errs, error_js(e)) == bad {
        js_later(() => {
          let o = obj()
          set(o, "errs", errs)
          done(o)
        })
      }
    },
  )
  |> ignore
}

///|
extern "js" fn js_later_long(f : () -> Unit) -> Unit = "(f) => setTimeout(f, 450)"
