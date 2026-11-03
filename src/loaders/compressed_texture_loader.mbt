// Upstream src/loaders/CompressedTextureLoader.js. Upstream subclasses override
// `parse`; here a format loader passes its parser to `CompressedTextureLoader::new`.

///|
/// What a compressed texture parser returns.
pub(all) struct CompressedTexData {
  mut width : Int32
  mut height : Int32
  mut format : Int32
  mut mipmaps : Array[@core.TextureImage]
  mut mipmap_count : Int32
  mut is_cubemap : Bool
}

///|
/// Abstract base for loaders of compressed formats that become a `CompressedTexture`.
pub struct CompressedTextureLoader {
  base : Loader
  /// Upstream's overridden `parse( buffer, loadMipmaps )`.
  parse : (JsValue, Bool) -> CompressedTexData
}

///|
pub fn CompressedTextureLoader::new(
  manager? : LoadingManager,
  parse? : (JsValue, Bool) -> CompressedTexData,
) -> CompressedTextureLoader {
  {
    base: Loader::new(manager?),
    parse: match parse {
      Some(parse) => parse
      None =>
        (_, _) => abort("CompressedTextureLoader: parse() is not implemented")
    },
  }
}

///|
pub impl LoaderLike for CompressedTextureLoader with fn loader(self) {
  self.base
}

///|
pub impl LoaderSettings for CompressedTextureLoader

///|
pub extend CompressedTextureLoader with LoaderLike::{loader}

///|
pub extend CompressedTextureLoader with LoaderSettings::{
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
/// One cube face, as upstream's `{ width, height, format, mipmaps }`. The port's
/// `DataImage` has no `format`; the texture's `format` is set as upstream does.
fn compressed_face(
  width : Int32,
  height : Int32,
  mipmaps : Array[@core.TextureImage],
) -> @core.TextureImage {
  let mipmaps = mipmaps.map(mipmap => {
    match mipmap {
      DataImage(image) => image
      _ => abort("CompressedTextureLoader: mipmaps must be data images")
    }
  })
  DataImage(@core.DataImage::new(width~, height~, mipmaps~))
}

///|
/// Loads the six files in `urls` as a cube map.
pub fn CompressedTextureLoader::load(
  self : CompressedTextureLoader,
  urls : Array[String],
  on_load? : (@core.Texture) -> Unit,
  on_progress? : (ProgressEvent) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> @core.Texture {
  let images : Array[@core.TextureImage] = []
  let texture = @core.CompressedTexture::new()
  let loader = self.file_loader()
  let mut loaded = 0
  fn load_texture(i : Int32) -> Unit {
    loader.load(
      urls[i],
      on_load=buffer => {
        let tex_datas = (self.parse)(buffer, true)
        while images.length() <= i {
          images.push(NoImage)
        }
        images[i] = compressed_face(
          tex_datas.width,
          tex_datas.height,
          tex_datas.mipmaps,
        )
        loaded += 1
        if loaded == 6 {
          if tex_datas.mipmap_count == 1 {
            texture.min_filter = @core.LinearFilter
          }
          texture.set_image(ImageArray(images))
          texture.format = tex_datas.format
          texture.set_needs_update(true)
          if on_load is Some(on_load) {
            on_load(texture)
          }
        }
      },
      on_progress?,
      on_error?,
    )
  }

  for i in 0..<urls.length() {
    load_texture(i)
  }
  texture
}

///|
/// Loads one file, a texture or a compressed cube map stored in a single DDS file.
pub fn CompressedTextureLoader::load_single(
  self : CompressedTextureLoader,
  url : String,
  on_load? : (@core.Texture) -> Unit,
  on_progress? : (ProgressEvent) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> @core.Texture {
  let images : Array[@core.TextureImage] = []
  let texture = @core.CompressedTexture::new()
  let loader = self.file_loader()
  loader.load(
    url,
    on_load=buffer => {
      let tex_datas = (self.parse)(buffer, true)
      if tex_datas.is_cubemap {
        let faces = tex_datas.mipmaps.length() / tex_datas.mipmap_count
        for f in 0..<faces {
          let mipmaps = []
          for i in 0..<tex_datas.mipmap_count {
            mipmaps.push(tex_datas.mipmaps[f * tex_datas.mipmap_count + i])
          }
          images.push(
            compressed_face(tex_datas.width, tex_datas.height, mipmaps),
          )
        }
        texture.set_image(ImageArray(images))
      } else {
        guard texture.image() is DataImage(image) else {
          abort("CompressedTextureLoader: texture image is not a data image")
        }
        image.width = tex_datas.width
        image.height = tex_datas.height
        texture.mipmaps = tex_datas.mipmaps
      }
      if tex_datas.mipmap_count == 1 {
        texture.min_filter = @core.LinearFilter
      }
      texture.format = tex_datas.format
      texture.set_needs_update(true)
      if on_load is Some(on_load) {
        on_load(texture)
      }
    },
    on_progress?,
    on_error?,
  )
  texture
}

///|
fn CompressedTextureLoader::file_loader(
  self : CompressedTextureLoader,
) -> FileLoader {
  FileLoader::new(manager=self.base.manager)
  .set_priority(self.base.priority)
  .set_cache(self.base.cache)
  .set_path(self.base.path)
  .set_response_type("arraybuffer")
  .set_request_header(self.base.request_header)
  .set_with_credentials(self.base.with_credentials)
}

///|
/// Upstream `loadAsync` with an array of URLs.
pub async fn CompressedTextureLoader::load_async(
  self : CompressedTextureLoader,
  urls : Array[String],
  on_progress? : (ProgressEvent) -> Unit,
) -> @core.Texture raise LoaderError {
  loader_promise((resolve, reject) => {
    self.load(urls, on_load=resolve, on_progress?, on_error=reject) |> ignore
  })
}
