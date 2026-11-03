// Upstream src/renderers/webgl/WebGLEnvironments.js. GROUP 3.

///|
pub struct WebGLEnvironments {
  renderer : WebGLRenderer
  /// texture -> `WebGLCubeRenderTarget`
  mut cube_maps : WeakMap[@core.Texture, @core.RenderTarget]
  /// texture -> PMREM render target
  mut pmrem_maps : WeakMap[@core.Texture, @core.RenderTarget]
  mut pmrem_generator : PMREMGenerator?
  /// `onCubemapDispose`, kept so it can be removed
  mut on_cubemap_dispose : (@core.Event) -> Unit
  /// `onPMREMDispose`, kept so it can be removed
  mut on_pmrem_dispose : (@core.Event) -> Unit
}

///|
/// `image && image.height > 0` for a DOM image.
extern "js" fn webgl_environments_dom_has_height(image : @core.JsValue) -> Bool = "(i) => !!(i && i.height > 0)"

///|
/// `image[ i ] !== undefined` for a DOM value.
extern "js" fn webgl_environments_dom_has_index(
  image : @core.JsValue,
  i : Int32,
) -> Bool = "(v, i) => v[i] !== undefined"

///|
/// `image && image.height > 0`.
fn webgl_environments_has_height(image : @core.TextureImage) -> Bool {
  match image {
    NoImage => false
    DomImage(image) => webgl_environments_dom_has_height(image)
    DataImage(image) => image.height > 0
    // a texture or an array has no `height`
    TextureImage(_) | ImageArray(_) => false
  }
}

///|
/// `isCubeTextureComplete( image )`.
fn webgl_environments_is_cube_texture_complete(
  image : @core.TextureImage,
) -> Bool {
  let length = 6
  let mut count = 0
  for i in 0..<length {
    let defined = match image {
      ImageArray(images) => i < images.length()
      DomImage(image) => webgl_environments_dom_has_index(image, i)
      NoImage | DataImage(_) | TextureImage(_) => false
    }
    if defined {
      count += 1
    }
  }
  count == length
}

///|
/// `image && isCubeTextureComplete( image )`.
fn webgl_environments_has_complete_cube(image : @core.TextureImage) -> Bool {
  match image {
    NoImage => false
    image => webgl_environments_is_cube_texture_complete(image)
  }
}

///|
/// `mapTextureMapping( texture, mapping )`.
fn webgl_environments_map_texture_mapping(
  texture : @core.Texture,
  mapping : Int32,
) -> @core.Texture {
  if mapping == @core.EquirectangularReflectionMapping {
    texture.mapping = @core.CubeReflectionMapping
  } else if mapping == @core.EquirectangularRefractionMapping {
    texture.mapping = @core.CubeRefractionMapping
  }
  texture
}

///|
/// `new WebGLEnvironments( renderer )`.
pub fn WebGLEnvironments::new(renderer : WebGLRenderer) -> WebGLEnvironments {
  let environments : WebGLEnvironments = {
    renderer,
    cube_maps: WeakMap::new(),
    pmrem_maps: WeakMap::new(),
    pmrem_generator: None,
    on_cubemap_dispose: fn(_) {  },
    on_pmrem_dispose: fn(_) {  },
  }
  environments.on_cubemap_dispose = fn(event) {
    guard event.target is Some(Texture(texture)) else { return }
    texture.remove_event_listener("dispose", environments.on_cubemap_dispose)
    if environments.cube_maps.get(texture) is Some(cubemap) {
      environments.cube_maps.delete(texture)
      cubemap.dispose()
    }
  }
  environments.on_pmrem_dispose = fn(event) {
    guard event.target is Some(Texture(texture)) else { return }
    texture.remove_event_listener("dispose", environments.on_pmrem_dispose)
    if environments.pmrem_maps.get(texture) is Some(pmrem) {
      environments.pmrem_maps.delete(texture)
      pmrem.dispose()
    }
  }
  environments
}

///|
/// `environments.get( texture, usePMREM )`: the cube or PMREM texture to sample, or the
/// texture itself; `None` for no texture.
pub fn WebGLEnvironments::get(
  self : WebGLEnvironments,
  texture : @core.Texture?,
  use_pmrem~ : Bool = false,
) -> @core.Texture? {
  guard texture is Some(texture) else { return None }
  if use_pmrem {
    return self.get_pmrem(texture)
  }
  self.get_cube(texture)
}

///|
/// `getCube( texture )`.
fn WebGLEnvironments::get_cube(
  self : WebGLEnvironments,
  texture : @core.Texture,
) -> @core.Texture? {
  let mapping = texture.mapping
  if mapping == @core.EquirectangularReflectionMapping ||
    mapping == @core.EquirectangularRefractionMapping {
    match self.cube_maps.get(texture) {
      Some(render_target) => {
        let cubemap = render_target.texture()
        return Some(
          webgl_environments_map_texture_mapping(cubemap, texture.mapping),
        )
      }
      None => {
        let image = texture.image()
        if webgl_environments_has_height(image) {
          let height = match image {
            DataImage(image) => image.height
            DomImage(image) => image.get("height").cast()
            _ => 0
          }
          let render_target = WebGLCubeRenderTarget::new(size=height)
          ignore(
            WebGLCubeRenderTarget::from_equirectangular_texture(
              render_target,
              self.renderer,
              texture,
            ),
          )
          self.cube_maps.set(texture, render_target)
          texture.add_event_listener("dispose", self.on_cubemap_dispose)
          return Some(
            webgl_environments_map_texture_mapping(
              render_target.texture(),
              texture.mapping,
            ),
          )
        } else {
          // image not yet ready. try the conversion next frame
          return None
        }
      }
    }
  }
  Some(texture)
}

///|
fn WebGLEnvironments::pmrem_generator(
  self : WebGLEnvironments,
) -> PMREMGenerator {
  match self.pmrem_generator {
    Some(generator) => generator
    None => {
      let generator = PMREMGenerator::new(self.renderer)
      self.pmrem_generator = Some(generator)
      generator
    }
  }
}

///|
/// `getPMREM( texture )`.
fn WebGLEnvironments::get_pmrem(
  self : WebGLEnvironments,
  texture : @core.Texture,
) -> @core.Texture? {
  if texture.is_pmrem_texture != true {
    let mapping = texture.mapping
    let is_equirect_map = mapping == @core.EquirectangularReflectionMapping ||
      mapping == @core.EquirectangularRefractionMapping
    let is_cube_map = mapping == @core.CubeReflectionMapping ||
      mapping == @core.CubeRefractionMapping

    // equirect/cube map to PMREM conversion
    if is_equirect_map || is_cube_map {
      let render_target = self.pmrem_maps.get(texture)
      let current_pmrem_version = match render_target {
        Some(render_target) => render_target.texture().pmrem_version
        None => 0
      }
      if texture.is_render_target_texture &&
        texture.pmrem_version != current_pmrem_version {
        let generator = self.pmrem_generator()
        let render_target = if is_equirect_map {
          generator.from_equirectangular(texture, render_target?)
        } else {
          generator.from_cubemap(texture, render_target?)
        }
        render_target.texture().pmrem_version = texture.pmrem_version
        self.pmrem_maps.set(texture, render_target)
        return Some(render_target.texture())
      } else {
        match render_target {
          Some(render_target) => return Some(render_target.texture())
          None => {
            let image = texture.image()
            if (is_equirect_map && webgl_environments_has_height(image)) ||
              (is_cube_map && webgl_environments_has_complete_cube(image)) {
              let generator = self.pmrem_generator()
              let render_target = if is_equirect_map {
                generator.from_equirectangular(texture)
              } else {
                generator.from_cubemap(texture)
              }
              render_target.texture().pmrem_version = texture.pmrem_version
              self.pmrem_maps.set(texture, render_target)
              texture.add_event_listener("dispose", self.on_pmrem_dispose)
              return Some(render_target.texture())
            } else {
              // image not yet ready. try the conversion next frame
              return None
            }
          }
        }
      }
    }
  }
  Some(texture)
}

///|
/// `environments.dispose()`.
pub fn WebGLEnvironments::dispose(self : WebGLEnvironments) -> Unit {
  self.cube_maps = WeakMap::new()
  self.pmrem_maps = WeakMap::new()
  if self.pmrem_generator is Some(generator) {
    generator.dispose()
    self.pmrem_generator = None
  }
}
