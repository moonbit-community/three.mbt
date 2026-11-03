// Upstream src/loaders/ObjectLoader.js. Upstream briefly stores uuid strings in
// `light.target` and `skinnedMesh.skeleton` between `parseObject` and the binding
// passes; here those strings live in side tables of the parse, keyed by object id.

///|
/// Upstream's module-level `_customGeometries`, filled by `register_geometry`.
let object_loader_custom_geometries : Map[
  String,
  (Json, Map[String, @extras.Shape]) -> @core.BufferGeometry,
] = Map([])

///|
/// Loads scenes and objects in the JSON format of `Object3D::to_json`.
pub struct ObjectLoader {
  base : Loader
  /// A subclass's `parseMaterials` (NodeObjectLoader); `None` is this class's.
  mut parse_materials_override : ((Json?, Map[String, @core.Texture]) -> Map[
    String,
    @core.Material,
  ])?
}

///|
pub fn ObjectLoader::new(manager? : LoadingManager) -> ObjectLoader {
  { base: Loader::new(manager?), parse_materials_override: None, }
}

///|
/// Overrides `parseMaterials( json, textures )`, as a subclass does.
pub fn ObjectLoader::set_parse_materials_override(
  self : ObjectLoader,
  f : (Json?, Map[String, @core.Texture]) -> Map[String, @core.Material],
) -> Unit {
  self.parse_materials_override = Some(f)
}

///|
pub impl LoaderLike for ObjectLoader with fn loader(self) {
  self.base
}

///|
pub impl LoaderSettings for ObjectLoader

///|
pub extend ObjectLoader with LoaderLike::{loader}

///|
pub extend ObjectLoader with LoaderSettings::{
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
/// The uuids upstream keeps in `light.target` and `skinnedMesh.skeleton` while parsing.
priv struct ObjectLoaderPending {
  targets : Map[Int32, String]
  skeletons : Map[Int32, String]
}

///|
fn ObjectLoader::file_loader(self : ObjectLoader, url : String) -> FileLoader {
  let path = if self.base.path == "" {
    LoaderUtils::extract_url_base(url)
  } else {
    self.base.path
  }
  if self.base.resource_path == "" {
    self.base.resource_path = path
  }
  FileLoader::new(manager=self.base.manager)
  .set_priority(self.base.priority)
  .set_cache(self.base.cache)
  .set_path(self.base.path)
  .set_request_header(self.base.request_header)
  .set_with_credentials(self.base.with_credentials)
}

///|
/// `metadata === undefined || metadata.type === undefined || metadata.type.toLowerCase() === 'geometry'`.
fn object_loader_bad_metadata(json : Json) -> Bool {
  guard json is Object(json) && json.get("metadata") is Some(metadata) else {
    return true
  }
  guard metadata is Object(metadata) && metadata.get("type") is Some(type_) else {
    return true
  }
  guard type_ is String(type_) else {
    abort("ObjectLoader: metadata.type.toLowerCase is not a function")
  }
  type_.to_lower() == "geometry"
}

///|
/// Starts loading `url`; `on_load` receives the object once its images have loaded.
pub fn ObjectLoader::load(
  self : ObjectLoader,
  url : String,
  on_load? : (@core.Object3D) -> Unit,
  on_progress? : (ProgressEvent) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> Unit {
  let loader = self.file_loader(url)
  loader.load(
    url,
    on_load=text => {
      let json = match loaders_parse_json(text) {
        Ok(json) => json
        Err(e) => {
          if on_error is Some(on_error) {
            on_error(e)
          }
          js_console_error(
            "THREE.ObjectLoader: Can't parse " + url + ".",
            js_error_message(e),
          )
          return
        }
      }
      if object_loader_bad_metadata(json) {
        if on_error is Some(on_error) {
          on_error(js_new_error("THREE.ObjectLoader: Can't load " + url))
        }
        @core.error("ObjectLoader: Can't load " + url)
        return
      }
      self.parse(json, on_load?) |> ignore
    },
    on_progress?,
    on_error?,
  )
}

///|
/// Upstream's `async loadAsync`, which parses with `parse_async`.
pub async fn ObjectLoader::load_async(
  self : ObjectLoader,
  url : String,
  on_progress? : (ProgressEvent) -> Unit,
) -> @core.Object3D raise LoaderError {
  let loader = self.file_loader(url)
  let text = loader.load_async(url, on_progress?)
  let json = match loaders_parse_json(text) {
    Ok(json) => json
    Err(e) =>
      raise LoaderError(
        js_new_error(
          "THREE.ObjectLoader: Can't parse " +
          url +
          ". " +
          js_string(js_error_message(e)),
        ),
      )
  }
  if object_loader_bad_metadata(json) {
    raise LoaderError(js_new_error("THREE.ObjectLoader: Can't load " + url))
  }
  self.parse_async(json)
}

///|
/// Parses `json` into an object. `on_load` runs when the images have loaded, or
/// before returning when there are none to load.
pub fn ObjectLoader::parse(
  self : ObjectLoader,
  json : Json,
  on_load? : (@core.Object3D) -> Unit,
) -> @core.Object3D {
  let data = json_object(json, "ObjectLoader")
  let result : Ref[@core.Object3D?] = Ref(None)
  let animations = self.parse_animations(data.get("animations"))
  let shapes = self.parse_shapes(data.get("shapes"))
  let geometries = self.parse_geometries(data.get("geometries"), shapes)
  let images = self.parse_images(data.get("images"), () => {
    if on_load is Some(on_load) {
      on_load(result.val.unwrap())
    }
  })
  let textures = self.parse_textures(data.get("textures"), images)
  let materials = self.parse_materials(data.get("materials"), textures)
  let pending = { targets: Map([]), skeletons: Map([]), }
  let object = self.parse_object(
    json_field(data, "object"),
    geometries,
    materials,
    textures,
    animations,
    pending,
  )
  result.val = Some(object)
  let skeletons = self.parse_skeletons(data.get("skeletons"), object)
  self.bind_skeletons(object, skeletons, pending)
  self.bind_light_targets(object, pending)
  if on_load is Some(on_load) {
    let mut has_images = false
    for _, source in images {
      if source.data is DomImage(image) && js_is_html_image_element(image) {
        has_images = true
        break
      }
    }
    if has_images == false {
      on_load(object)
    }
  }
  object
}

///|
/// Upstream `parseAsync`: as `parse`, waiting for each image in turn.
pub async fn ObjectLoader::parse_async(
  self : ObjectLoader,
  json : Json,
) -> @core.Object3D raise LoaderError {
  let data = json_object(json, "ObjectLoader")
  let animations = self.parse_animations(data.get("animations"))
  let shapes = self.parse_shapes(data.get("shapes"))
  let geometries = self.parse_geometries(data.get("geometries"), shapes)
  let images = self.parse_images_async(data.get("images"))
  let textures = self.parse_textures(data.get("textures"), images)
  let materials = self.parse_materials(data.get("materials"), textures)
  let pending = { targets: Map([]), skeletons: Map([]), }
  let object = self.parse_object(
    json_field(data, "object"),
    geometries,
    materials,
    textures,
    animations,
    pending,
  )
  let skeletons = self.parse_skeletons(data.get("skeletons"), object)
  self.bind_skeletons(object, skeletons, pending)
  self.bind_light_targets(object, pending)
  object
}

///|
/// Upstream's static `ObjectLoader.registerGeometry`: `from_json` is the class's
/// static `fromJSON( data, shapes )`.
pub fn ObjectLoader::register_geometry(
  type_ : String,
  from_json : (Json, Map[String, @extras.Shape]) -> @core.BufferGeometry,
) -> Unit {
  object_loader_custom_geometries[type_] = from_json
}

// internals

///|
pub fn ObjectLoader::parse_shapes(
  self : ObjectLoader,
  json : Json?,
) -> Map[String, @extras.Shape] {
  ignore(self)
  let shapes = Map([])
  if json is Some(json) {
    for data in json_array(json, "shapes") {
      let shape = @extras.Shape::new().from_json(data)
      shapes[shape.uuid()] = shape
    }
  }
  shapes
}

///|
pub fn ObjectLoader::parse_skeletons(
  self : ObjectLoader,
  json : Json?,
  object : @core.Object3D,
) -> Map[String, @core.Skeleton] {
  ignore(self)
  let skeletons = Map([])
  let bones = Map([])

  // generate bone lookup table
  object.traverse(child => if child.is_bone() { bones[child.uuid] = child })

  // create skeletons
  if json is Some(json) {
    for data in json_array(json, "skeletons") {
      let skeleton = @core.Skeleton::new().from_json(data, bones)
      skeletons[skeleton.uuid] = skeleton
    }
  }
  skeletons
}

///|
/// `Geometries[ type ].fromJSON( data, shapes )` for the classes of src/geometries.
/// `EdgesGeometry` and `WireframeGeometry` have no `fromJSON`, so upstream throws.
fn object_loader_geometry_from_json(
  type_ : String,
  data : Json,
  shapes : Map[String, @extras.Shape],
) -> @core.BufferGeometry? {
  let geometry = match type_ {
    "BoxGeometry" => @geometries.BoxGeometry::from_json(data)
    "CapsuleGeometry" => @geometries.CapsuleGeometry::from_json(data)
    "CircleGeometry" => @geometries.CircleGeometry::from_json(data)
    "ConeGeometry" => @geometries.ConeGeometry::from_json(data)
    "CylinderGeometry" => @geometries.CylinderGeometry::from_json(data)
    "DodecahedronGeometry" => @geometries.DodecahedronGeometry::from_json(data)
    "ExtrudeGeometry" => @geometries.ExtrudeGeometry::from_json(data, shapes)
    "IcosahedronGeometry" => @geometries.IcosahedronGeometry::from_json(data)
    "LatheGeometry" => @geometries.LatheGeometry::from_json(data)
    "OctahedronGeometry" => @geometries.OctahedronGeometry::from_json(data)
    "PlaneGeometry" => @geometries.PlaneGeometry::from_json(data)
    "PolyhedronGeometry" => @geometries.PolyhedronGeometry::from_json(data)
    "RingGeometry" => @geometries.RingGeometry::from_json(data)
    "ShapeGeometry" => @geometries.ShapeGeometry::from_json(data, shapes)
    "SphereGeometry" => @geometries.SphereGeometry::from_json(data)
    "TetrahedronGeometry" => @geometries.TetrahedronGeometry::from_json(data)
    "TorusGeometry" => @geometries.TorusGeometry::from_json(data)
    "TorusKnotGeometry" => @geometries.TorusKnotGeometry::from_json(data)
    "TubeGeometry" => @geometries.TubeGeometry::from_json(data)
    "EdgesGeometry" | "WireframeGeometry" =>
      abort("ObjectLoader: Geometries[ data.type ].fromJSON is not a function")
    _ => return None
  }
  Some(geometry)
}

///|
pub fn ObjectLoader::parse_geometries(
  self : ObjectLoader,
  json : Json?,
  shapes : Map[String, @extras.Shape],
) -> Map[String, @core.BufferGeometry] {
  ignore(self)
  let geometries = Map([])
  if json is Some(json) {
    let buffer_geometry_loader = BufferGeometryLoader::new()
    for data_json in json_array(json, "geometries") {
      let data = json_object(data_json, "geometry")
      let type_ = json_opt_string(data, "type").unwrap_or("undefined")
      let geometry = match type_ {
        "BufferGeometry" | "InstancedBufferGeometry" =>
          buffer_geometry_loader.parse(data_json)
        _ =>
          match object_loader_geometry_from_json(type_, data_json, shapes) {
            Some(geometry) => geometry
            None =>
              match object_loader_custom_geometries.get(type_) {
                Some(from_json) => from_json(data_json, shapes)
                None => {
                  @core.warn(
                    "ObjectLoader: Unknown geometry type \"\{type_}\". Use .registerGeometry() before starting the deserialization process.",
                  )
                  // upstream then throws on `geometry.uuid = data.uuid`
                  abort("ObjectLoader: geometry is undefined")
                }
              }
          }
      }
      let uuid = json_string(json_field(data, "uuid"), "uuid")
      geometry.uuid = uuid
      if json_opt_string(data, "name") is Some(name) {
        geometry.name = name
      }
      if data.get("userData") is Some(user_data) {
        geometry.user_data = JsValue::from_json(user_data)
      }
      geometries[uuid] = geometry
    }
  }
  geometries
}

///|
pub fn ObjectLoader::parse_materials(
  self : ObjectLoader,
  json : Json?,
  textures : Map[String, @core.Texture],
) -> Map[String, @core.Material] {
  if self.parse_materials_override is Some(f) {
    return f(json, textures)
  }
  let cache : Map[String, @core.Material] = Map([]) // MultiMaterial
  let materials = Map([])
  if json is Some(json) {
    let loader = MaterialLoader::new()
    loader.set_textures(textures) |> ignore
    for data in json_array(json, "materials") {
      let uuid = json_string(
        json_field(json_object(data, "material"), "uuid"),
        "uuid",
      )
      if cache.get(uuid) is None {
        cache[uuid] = loader.parse(data)
      }
      materials[uuid] = cache[uuid]
    }
  }
  materials
}

///|
pub fn ObjectLoader::parse_animations(
  self : ObjectLoader,
  json : Json?,
) -> Map[String, &@core.SerializableResource] {
  ignore(self)
  let animations = Map([])
  if json is Some(json) {
    for data in json_array(json, "animations") {
      let clip = object_loader_parse_clip(data)
      animations[clip.uuid()] = clip
    }
  }
  animations
}

///|
/// What `deserializeImage` returns: an image element, `{ data, width, height }` or `null`.
priv enum ObjectLoaderImage {
  Element(JsValue)
  Data(@core.TypedArray, Int32, Int32)
  NullImage
}

///|
fn object_loader_data_image(image : Json) -> ObjectLoaderImage {
  let image = json_object(image, "image")
  if json_truthy(image.get("data")) {
    Data(
      json_typed_array(
        json_field(image, "type"),
        json_field(image, "data"),
        "image",
      ),
      json_number(json_field(image, "width"), "width").to_int(),
      json_number(json_field(image, "height"), "height").to_int(),
    )
  } else {
    NullImage
  }
}

///|
/// `scope.resourcePath + url` unless `url` is absolute.
fn ObjectLoader::image_path(self : ObjectLoader, url : String) -> String {
  if js_is_absolute_image_url(url) {
    url
  } else {
    self.base.resource_path + url
  }
}

///|
/// Builds the `TextureSource`s from the deserialized images, in upstream's order.
fn object_loader_image_sources(
  json : Json?,
  deserialize_image : (Json) -> ObjectLoaderImage,
) -> Map[String, @core.TextureSource] {
  let images = Map([])
  guard json is Some(json) else { return images }
  let json = json_array(json, "images")
  for image_json in json {
    let image = json_object(image_json, "image")
    let uuid = json_string(json_field(image, "uuid"), "uuid")
    match json_field(image, "url") {
      Array(urls) => {
        // load array of images e.g CubeTexture
        let image_array : Array[@core.TextureImage] = []
        for current_url in urls {
          match deserialize_image(current_url) {
            NullImage => ()
            Element(element) => image_array.push(DomImage(element))
            Data(data, width, height) =>
              // special case: handle array of data textures for cube textures
              image_array.push(
                TextureImage(@core.DataTexture::new(data~, width~, height~)),
              )
          }
        }
        images[uuid] = @core.TextureSource::new(data=ImageArray(image_array))
      }
      url => {
        // load single image
        let data : @core.TextureImage = match deserialize_image(url) {
          NullImage => NoImage
          Element(element) => DomImage(element)
          Data(data, width, height) =>
            DataImage(@core.DataImage::new(data~, width~, height~))
        }
        images[uuid] = @core.TextureSource::new(data~)
      }
    }
  }
  images
}

///|
pub fn ObjectLoader::parse_images(
  self : ObjectLoader,
  json : Json?,
  on_load : () -> Unit,
) -> Map[String, @core.TextureSource] {
  guard json is Some(Array(array)) && array.length() > 0 else {
    if json is Some(json) {
      ignore(json_array(json, "images"))
    }
    return Map([])
  }
  let manager = LoadingManager::new(on_load~)
  let loader = ImageLoader::new(manager~)
    .set_priority(self.base.priority)
    .set_cache(self.base.cache)
    .set_cross_origin(self.base.cross_origin)
  fn load_image(url : String) -> JsValue {
    let url = self.base.manager.resolve_url(url)
    self.base.manager.item_start(url)
    loader.load(url, on_load=_ => self.base.manager.item_end(url), on_error=_ => {
      self.base.manager.item_error(url)
      self.base.manager.item_end(url)
    })
  }

  object_loader_image_sources(json, image => {
    match image {
      String(url) => Element(load_image(self.image_path(url)))
      image => object_loader_data_image(image)
    }
  })
}

///|
pub async fn ObjectLoader::parse_images_async(
  self : ObjectLoader,
  json : Json?,
) -> Map[String, @core.TextureSource] raise LoaderError {
  guard json is Some(Array(array)) && array.length() > 0 else {
    if json is Some(json) {
      ignore(json_array(json, "images"))
    }
    return Map([])
  }
  let loader = ImageLoader::new(manager=self.base.manager)
    .set_priority(self.base.priority)
    .set_cache(self.base.cache)
    .set_cross_origin(self.base.cross_origin)

  async fn deserialize_image(
    image : Json,
  ) -> ObjectLoaderImage raise LoaderError {
    match image {
      String(url) => Element(loader.load_async(self.image_path(url)))
      image => object_loader_data_image(image)
    }
  }

  let images = Map([])
  for image_json in array {
    let image = json_object(image_json, "image")
    let uuid = json_string(json_field(image, "uuid"), "uuid")
    match json_field(image, "url") {
      Array(urls) => {
        // load array of images e.g CubeTexture
        let image_array : Array[@core.TextureImage] = []
        for current_url in urls {
          match deserialize_image(current_url) {
            NullImage => ()
            Element(element) => image_array.push(DomImage(element))
            Data(data, width, height) =>
              // special case: handle array of data textures for cube textures
              image_array.push(
                TextureImage(@core.DataTexture::new(data~, width~, height~)),
              )
          }
        }
        images[uuid] = @core.TextureSource::new(data=ImageArray(image_array))
      }
      url => {
        // load single image
        let data : @core.TextureImage = match deserialize_image(url) {
          NullImage => NoImage
          Element(element) => DomImage(element)
          Data(data, width, height) =>
            DataImage(@core.DataImage::new(data~, width~, height~))
        }
        images[uuid] = @core.TextureSource::new(data~)
      }
    }
  }
  images
}

///|
/// `parseConstant`: a number, or the name of a constant in `type_`.
fn object_loader_parse_constant(
  value : Json,
  type_ : Map[String, Int32],
) -> Int32? {
  match value {
    Number(value, ..) => Some(value.to_int())
    String(name) => {
      @core.warn(
        "ObjectLoader.parseTexture: Constant should be in numeric form. " + name,
      )
      type_.get(name)
    }
    _ => {
      @core.warn(
        "ObjectLoader.parseTexture: Constant should be in numeric form.",
      )
      None
    }
  }
}

///|
let object_loader_texture_mapping : Map[String, Int32] = {
  "UVMapping": @core.UVMapping,
  "CubeReflectionMapping": @core.CubeReflectionMapping,
  "CubeRefractionMapping": @core.CubeRefractionMapping,
  "EquirectangularReflectionMapping": @core.EquirectangularReflectionMapping,
  "EquirectangularRefractionMapping": @core.EquirectangularRefractionMapping,
}

///|
let object_loader_texture_wrapping : Map[String, Int32] = {
  "RepeatWrapping": @core.RepeatWrapping,
  "ClampToEdgeWrapping": @core.ClampToEdgeWrapping,
  "MirroredRepeatWrapping": @core.MirroredRepeatWrapping,
}

///|
let object_loader_texture_filter : Map[String, Int32] = {
  "NearestFilter": @core.NearestFilter,
  "NearestMipmapNearestFilter": @core.NearestMipmapNearestFilter,
  "NearestMipmapLinearFilter": @core.NearestMipmapLinearFilter,
  "LinearFilter": @core.LinearFilter,
  "LinearMipmapNearestFilter": @core.LinearMipmapNearestFilter,
  "LinearMipmapLinearFilter": @core.LinearMipmapLinearFilter,
}

///|
pub fn ObjectLoader::parse_textures(
  self : ObjectLoader,
  json : Json?,
  images : Map[String, @core.TextureSource],
) -> Map[String, @core.Texture] {
  ignore(self)
  let textures = Map([])
  guard json is Some(json) else { return textures }
  for data in json_array(json, "textures") {
    let data = json_object(data, "texture")
    let uuid = json_string(json_field(data, "uuid"), "uuid")
    let image_uuid = match data.get("image") {
      None => {
        @core.warn("ObjectLoader: No \"image\" specified for " + uuid)
        "undefined"
      }
      Some(image) => json_string(image, "image")
    }
    let source = match images.get(image_uuid) {
      Some(source) => source
      None => {
        @core.warn("ObjectLoader: Undefined image " + image_uuid)
        // upstream then throws on `source.data`
        abort("ObjectLoader: source is undefined")
      }
    }
    let texture = match source.data {
      ImageArray(images) => {
        let texture = @core.CubeTexture::new()
        if images.length() == 6 {
          texture.set_needs_update(true)
        }
        texture
      }
      image => {
        let texture = if image is DataImage({ data: Some(_), .. }) {
          @core.DataTexture::new()
        } else {
          @core.Texture::new()
        }
        if !(image is NoImage) {
          texture.set_needs_update(true) // textures can have undefined image data
        }
        texture
      }
    }
    texture.source = source
    texture.uuid = uuid
    if json_opt_string(data, "name") is Some(name) {
      texture.name = name
    }
    if data.get("mapping") is Some(mapping) {
      if object_loader_parse_constant(mapping, object_loader_texture_mapping)
        is Some(value) {
        texture.mapping = value
      }
    }
    if json_opt_int(data, "channel") is Some(channel) {
      texture.channel = channel
    }
    if data.get("offset") is Some(offset) {
      texture.offset.from_array(json_numbers(offset, "offset")) |> ignore
    }
    if data.get("repeat") is Some(repeat) {
      texture.repeat.from_array(json_numbers(repeat, "repeat")) |> ignore
    }
    if data.get("center") is Some(center) {
      texture.center.from_array(json_numbers(center, "center")) |> ignore
    }
    if json_opt_number(data, "rotation") is Some(rotation) {
      texture.rotation = rotation
    }
    if data.get("wrap") is Some(wrap) {
      let wrap = json_array(wrap, "wrap")
      if object_loader_parse_constant(wrap[0], object_loader_texture_wrapping)
        is Some(value) {
        texture.wrap_s = value
      }
      if object_loader_parse_constant(wrap[1], object_loader_texture_wrapping)
        is Some(value) {
        texture.wrap_t = value
      }
    }
    if json_opt_int(data, "format") is Some(format) {
      texture.format = format
    }
    if data.get("internalFormat") is Some(internal_format) {
      texture.internal_format = match internal_format {
        String(internal_format) => Some(internal_format)
        _ => None
      }
    }
    if json_opt_int(data, "type") is Some(type_) {
      texture.type_ = type_
    }
    if json_opt_string(data, "colorSpace") is Some(color_space) {
      texture.color_space = color_space
    }
    if data.get("minFilter") is Some(min_filter) {
      if object_loader_parse_constant(min_filter, object_loader_texture_filter)
        is Some(value) {
        texture.min_filter = value
      }
    }
    if data.get("magFilter") is Some(mag_filter) {
      if object_loader_parse_constant(mag_filter, object_loader_texture_filter)
        is Some(value) {
        texture.mag_filter = value
      }
    }
    if json_opt_int(data, "anisotropy") is Some(anisotropy) {
      texture.anisotropy = anisotropy
    }
    if json_opt_bool(data, "flipY") is Some(flip_y) {
      texture.flip_y = flip_y
    }
    if json_opt_bool(data, "generateMipmaps") is Some(generate_mipmaps) {
      texture.generate_mipmaps = generate_mipmaps
    }
    if json_opt_bool(data, "mipmapsAutoUpdate") is Some(mipmaps_auto_update) {
      texture.mipmaps_auto_update = mipmaps_auto_update
    }
    if json_opt_bool(data, "premultiplyAlpha") is Some(premultiply_alpha) {
      texture.premultiply_alpha = premultiply_alpha
    }
    if json_opt_int(data, "unpackAlignment") is Some(unpack_alignment) {
      texture.unpack_alignment = unpack_alignment
    }
    if data.get("compareFunction") is Some(compare_function) {
      texture.compare_function = match compare_function {
        Number(value, ..) => Some(value.to_int())
        _ => None
      }
    }
    if json_opt_bool(data, "normalized") is Some(normalized) {
      texture.normalized = normalized
    }
    if data.get("userData") is Some(user_data) {
      texture.user_data = JsValue::from_json(user_data)
    }
    textures[uuid] = texture
  }
  textures
}

///|
/// `new Color( value )` for the numeric colors of the format.
fn object_loader_color(value : Json?) -> @math.Color? {
  match value {
    None => None
    Some(Number(hex, ..)) =>
      Some(@math.Color::new(1.0, 1.0, 1.0).set_hex(hex.to_int()))
    Some(_) => Some(@math.Color::new(1.0, 1.0, 1.0))
  }
}

///|
/// `Object.assign( {}, data.view )` as a `CameraView`.
fn object_loader_camera_view(view : Json) -> @core.CameraView {
  let view = json_object(view, "view")
  {
    enabled: json_opt_bool(view, "enabled").unwrap_or(true),
    full_width: json_opt_number(view, "fullWidth").unwrap_or(1.0),
    full_height: json_opt_number(view, "fullHeight").unwrap_or(1.0),
    offset_x: json_opt_number(view, "offsetX").unwrap_or(0.0),
    offset_y: json_opt_number(view, "offsetY").unwrap_or(0.0),
    width: json_opt_number(view, "width").unwrap_or(1.0),
    height: json_opt_number(view, "height").unwrap_or(1.0),
  }
}

///|
/// The renderable objects keep their morph targets on their payloads.
fn object_loader_set_morph_targets(
  object : @core.Object3D,
  dictionary : Map[String, Int32]?,
  influences : Array[Double]?,
) -> Unit {
  match object.kind {
    Mesh(mesh) => {
      if dictionary is Some(_) {
        mesh.morph_target_dictionary = dictionary
      }
      if influences is Some(_) {
        mesh.morph_target_influences = influences
      }
    }
    Line(line) => {
      if dictionary is Some(_) {
        line.morph_target_dictionary = dictionary
      }
      if influences is Some(_) {
        line.morph_target_influences = influences
      }
    }
    Points(points) => {
      if dictionary is Some(_) {
        points.morph_target_dictionary = dictionary
      }
      if influences is Some(_) {
        points.morph_target_influences = influences
      }
    }
    // upstream adds expando properties that nothing reads or writes back
    _ => ()
  }
}

///|
fn object_loader_batched_mesh(
  object : @core.Object3D,
  data : Map[String, Json],
  geometry : @core.BufferGeometry?,
  get_texture : (String) -> @core.Texture?,
) -> Unit {
  guard object.kind is Mesh({ kind: BatchedMesh(batched), .. } as mesh) else {
    abort("ObjectLoader: not a BatchedMesh")
  }
  fn int(key : String) -> Int32 {
    json_number(json_field(data, key), key).to_int()
  }

  fn ints(key : String) -> Array[Int32] {
    json_numbers(json_field(data, key), key).map(value => value.to_int())
  }

  // `object.geometry = geometry`, which is `undefined` for an unknown uuid
  if geometry is Some(geometry) {
    mesh.geometry = geometry
  }
  batched.per_object_frustum_culled = json_bool(
    json_field(data, "perObjectFrustumCulled"),
    "perObjectFrustumCulled",
  )
  batched.sort_objects = json_bool(
    json_field(data, "sortObjects"),
    "sortObjects",
  )
  batched._geometry_info = json_array(
    json_field(data, "geometryInfo"),
    "geometryInfo",
  ).map(info => {
    let info = json_object(info, "geometryInfo")
    fn info_int(key : String) -> Int32 {
      json_number(json_field(info, key), key).to_int()
    }

    {
      vertex_start: info_int("vertexStart"),
      vertex_count: info_int("vertexCount"),
      reserved_vertex_count: info_int("reservedVertexCount"),
      index_start: info_int("indexStart"),
      index_count: info_int("indexCount"),
      reserved_index_count: info_int("reservedIndexCount"),
      start: info_int("start"),
      count: info_int("count"),
      bounding_box: info
      .get("boundingBox")
      .map(box => @math.Box3::new().from_json(box)),
      bounding_sphere: info
      .get("boundingSphere")
      .map(sphere => @math.Sphere::new().from_json(sphere)),
      active: json_bool(json_field(info, "active"), "active"),
    }
  })
  batched._instance_info = json_array(
    json_field(data, "instanceInfo"),
    "instanceInfo",
  ).map(info => {
    let info = json_object(info, "instanceInfo")
    {
      visible: json_bool(json_field(info, "visible"), "visible"),
      active: json_bool(json_field(info, "active"), "active"),
      geometry_index: json_number(
        json_field(info, "geometryIndex"),
        "geometryIndex",
      ).to_int(),
    }
  })
  batched._available_instance_ids = ints("availableInstanceIds")
  batched._available_geometry_ids = ints("availableGeometryIds")
  batched._next_index_start = int("nextIndexStart")
  batched._next_vertex_start = int("nextVertexStart")
  batched._geometry_count = int("geometryCount")
  batched._max_instance_count = int("maxInstanceCount")
  batched._max_vertex_count = int("maxVertexCount")
  batched._max_index_count = int("maxIndexCount")
  batched._geometry_initialized = json_bool(
    json_field(data, "geometryInitialized"),
    "geometryInitialized",
  )
  fn texture_uuid(key : String) -> String {
    json_string(
      json_field(json_object(json_field(data, key), key), "uuid"),
      "uuid",
    )
  }

  batched._matrices_texture = get_texture(texture_uuid("matricesTexture"))
  batched._indirect_texture = get_texture(texture_uuid("indirectTexture"))
  if data.get("colorsTexture") is Some(_) {
    batched._colors_texture = get_texture(texture_uuid("colorsTexture"))
  }
  if data.get("boundingSphere") is Some(sphere) {
    batched.bounding_sphere = Some(@math.Sphere::new().from_json(sphere))
  }
  if data.get("boundingBox") is Some(box) {
    batched.bounding_box = Some(@math.Box3::new().from_json(box))
  }
}

///|
/// Parses one object and its children. Shadow cameras are parsed with empty libraries,
/// as upstream calls `parseObject( data.shadow.camera )`.
fn ObjectLoader::parse_object(
  self : ObjectLoader,
  data_json : Json,
  geometries : Map[String, @core.BufferGeometry],
  materials : Map[String, @core.Material],
  textures : Map[String, @core.Texture],
  animations : Map[String, &@core.SerializableResource],
  pending : ObjectLoaderPending,
) -> @core.Object3D {
  let data = json_object(data_json, "object")
  fn get_geometry(name : Json?) -> @core.BufferGeometry? {
    let name = match name {
      Some(String(name)) => name
      _ => "undefined"
    }
    let geometry = geometries.get(name)
    if geometry is None {
      @core.warn("ObjectLoader: Undefined geometry " + name)
    }
    geometry
  }

  fn get_material(name : Json?) -> @core.MaterialSlot? {
    match name {
      None => None
      Some(Array(names)) => {
        let array = []
        for uuid in names {
          let uuid = json_string(uuid, "material")
          match materials.get(uuid) {
            Some(material) => array.push(material)
            // upstream pushes `undefined`, which the port's arrays cannot hold
            None => @core.warn("ObjectLoader: Undefined material " + uuid)
          }
        }
        Some(Multiple(array))
      }
      Some(name) => {
        let name = json_string(name, "material")
        match materials.get(name) {
          Some(material) => Some(Single(material))
          None => {
            @core.warn("ObjectLoader: Undefined material " + name)
            None
          }
        }
      }
    }
  }

  fn get_single_material(name : Json?) -> @core.Material? {
    match get_material(name) {
      None => None
      Some(Single(material)) => Some(material)
      Some(Multiple(_)) => abort("ObjectLoader: a Sprite takes one material")
    }
  }

  fn get_texture(uuid : String) -> @core.Texture? {
    let texture = textures.get(uuid)
    if texture is None {
      @core.warn("ObjectLoader: Undefined texture " + uuid)
    }
    texture
  }

  fn target_uuid(data : Map[String, Json]) -> String {
    // `data.target || ''`
    if json_truthy(data.get("target")) {
      json_string(data["target"], "target")
    } else {
      ""
    }
  }

  let type_ = json_opt_string(data, "type").unwrap_or("undefined")
  let object = match type_ {
    "Scene" => {
      let object = @core.Scene::new()
      let scene = object.as_scene()
      if data.get("background") is Some(background) {
        match background {
          Number(value, ..) if value == value.floor() && !value.is_inf() =>
            scene.background = object_loader_color(Some(background)).map(color => {
              @core.SceneBackground::Color(color)
            })
          background =>
            scene.background = get_texture(
              json_string(background, "background"),
            ).map(texture => @core.SceneBackground::Texture(texture))
        }
      }
      if data.get("environment") is Some(environment) {
        scene.environment = get_texture(json_string(environment, "environment"))
      }
      if data.get("fog") is Some(fog) {
        let fog = json_object(fog, "fog")
        match json_opt_string(fog, "type") {
          Some("Fog") =>
            scene.fog = Some(
              Fog(
                @core.Fog::new(
                  color?=object_loader_color(Some(json_field(fog, "color"))),
                  near?=json_opt_number(fog, "near"),
                  far?=json_opt_number(fog, "far"),
                ),
              ),
            )
          Some("FogExp2") =>
            scene.fog = Some(
              FogExp2(
                @core.FogExp2::new(
                  color?=object_loader_color(Some(json_field(fog, "color"))),
                  density?=json_opt_number(fog, "density"),
                ),
              ),
            )
          _ => ()
        }
        match (json_opt_string(fog, "name"), scene.fog) {
          (Some(""), _) => ()
          (Some(name), Some(Fog(fog))) => fog.name = name
          (Some(name), Some(FogExp2(fog))) => fog.name = name
          (None, _) => () // `object.fog.name = undefined`
          (Some(_), None) =>
            abort(
              "ObjectLoader: Cannot set properties of undefined (setting 'name')",
            )
        }
      }
      if json_opt_number(data, "backgroundBlurriness") is Some(value) {
        scene.background_blurriness = value
      }
      if json_opt_number(data, "backgroundIntensity") is Some(value) {
        scene.background_intensity = value
      }
      if data.get("backgroundRotation") is Some(rotation) {
        scene.background_rotation.from_array(
          json_array(rotation, "backgroundRotation"),
        )
        |> ignore
      }
      if json_opt_number(data, "environmentIntensity") is Some(value) {
        scene.environment_intensity = value
      }
      if data.get("environmentRotation") is Some(rotation) {
        scene.environment_rotation.from_array(
          json_array(rotation, "environmentRotation"),
        )
        |> ignore
      }
      object
    }
    "PerspectiveCamera" => {
      let object = @core.PerspectiveCamera::new(
        fov?=json_opt_number(data, "fov"),
        aspect?=json_opt_number(data, "aspect"),
        near?=json_opt_number(data, "near"),
        far?=json_opt_number(data, "far"),
      )
      let camera = object.as_perspective_camera()
      if json_opt_number(data, "focus") is Some(focus) {
        camera.focus = focus
      }
      if json_opt_number(data, "zoom") is Some(zoom) {
        camera.zoom = zoom
      }
      if json_opt_number(data, "filmGauge") is Some(film_gauge) {
        camera.film_gauge = film_gauge
      }
      if json_opt_number(data, "filmOffset") is Some(film_offset) {
        camera.film_offset = film_offset
      }
      if data.get("view") is Some(view) {
        camera.view = Some(object_loader_camera_view(view))
      }
      object
    }
    "OrthographicCamera" => {
      let object = @core.OrthographicCamera::new(
        left?=json_opt_number(data, "left"),
        right?=json_opt_number(data, "right"),
        top?=json_opt_number(data, "top"),
        bottom?=json_opt_number(data, "bottom"),
        near?=json_opt_number(data, "near"),
        far?=json_opt_number(data, "far"),
      )
      let camera = object.as_orthographic_camera()
      if json_opt_number(data, "zoom") is Some(zoom) {
        camera.zoom = zoom
      }
      if data.get("view") is Some(view) {
        camera.view = Some(object_loader_camera_view(view))
      }
      object
    }
    "AmbientLight" =>
      @core.AmbientLight::new(
        color?=object_loader_color(data.get("color")),
        intensity?=json_opt_number(data, "intensity"),
      )
    "DirectionalLight" => {
      let object = @core.DirectionalLight::new(
        color?=object_loader_color(data.get("color")),
        intensity?=json_opt_number(data, "intensity"),
      )
      pending.targets[object.id] = target_uuid(data)
      object
    }
    "PointLight" =>
      @core.PointLight::new(
        color?=object_loader_color(data.get("color")),
        intensity?=json_opt_number(data, "intensity"),
        distance?=json_opt_number(data, "distance"),
        decay?=json_opt_number(data, "decay"),
      )
    "RectAreaLight" =>
      @core.RectAreaLight::new(
        color?=object_loader_color(data.get("color")),
        intensity?=json_opt_number(data, "intensity"),
        width?=json_opt_number(data, "width"),
        height?=json_opt_number(data, "height"),
      )
    "SpotLight" => {
      let object = @core.SpotLight::new(
        color?=object_loader_color(data.get("color")),
        intensity?=json_opt_number(data, "intensity"),
        distance?=json_opt_number(data, "distance"),
        angle?=json_opt_number(data, "angle"),
        penumbra?=json_opt_number(data, "penumbra"),
        decay?=json_opt_number(data, "decay"),
      )
      pending.targets[object.id] = target_uuid(data)
      if data.get("map") is Some(map) {
        guard object.as_light().kind is SpotLight(spot) else {
          abort("ObjectLoader: not a SpotLight")
        }
        spot.map = get_texture(json_string(map, "map"))
      }
      object
    }
    "HemisphereLight" =>
      @core.HemisphereLight::new(
        sky_color?=object_loader_color(data.get("color")),
        ground_color?=object_loader_color(data.get("groundColor")),
        intensity?=json_opt_number(data, "intensity"),
      )
    "LightProbe" => {
      let sh = @math.SphericalHarmonics3::new().from_array(
        json_numbers(json_field(data, "sh"), "sh"),
      )
      @core.LightProbe::new(sh~, intensity?=json_opt_number(data, "intensity"))
    }
    "SkinnedMesh" => {
      let geometry = get_geometry(data.get("geometry"))
      let material = get_material(data.get("material"))
      let object = @core.SkinnedMesh::new(geometry?, material?)
      guard object.kind is Mesh({ kind: SkinnedMesh(skinned), .. }) else {
        abort("ObjectLoader: not a SkinnedMesh")
      }
      if json_opt_string(data, "bindMode") is Some(bind_mode) {
        skinned.bind_mode = bind_mode
      }
      if data.get("bindMatrix") is Some(bind_matrix) {
        skinned.bind_matrix.from_array(json_numbers(bind_matrix, "bindMatrix"))
        |> ignore
      }
      if json_opt_string(data, "skeleton") is Some(skeleton) {
        pending.skeletons[object.id] = skeleton
      }
      object
    }
    "Mesh" => {
      let geometry = get_geometry(data.get("geometry"))
      let material = get_material(data.get("material"))
      @core.Mesh::new(geometry?, material?)
    }
    "InstancedMesh" => {
      let geometry = get_geometry(data.get("geometry"))
      let material = get_material(data.get("material"))
      let count = json_number(json_field(data, "count"), "count").to_int()
      let instance_matrix = json_object(
        json_field(data, "instanceMatrix"),
        "instanceMatrix",
      )
      let instance_color = data.get("instanceColor")
      let object = @core.InstancedMesh::new(geometry?, material?, count)
      guard object.kind is Mesh({ kind: InstancedMesh(instanced), .. }) else {
        abort("ObjectLoader: not an InstancedMesh")
      }
      instanced.instance_matrix = @core.InstancedBufferAttribute::new(
        @core.TypedArray::float32(
          json_typed_numbers(
            json_field(instance_matrix, "array"),
            "instanceMatrix",
          ),
        ),
        16,
      )
      if instance_color is Some(instance_color) {
        let instance_color = json_object(instance_color, "instanceColor")
        instanced.instance_color = Some(
          @core.InstancedBufferAttribute::new(
            @core.TypedArray::float32(
              json_typed_numbers(
                json_field(instance_color, "array"),
                "instanceColor",
              ),
            ),
            json_number(json_field(instance_color, "itemSize"), "itemSize").to_int(),
          ),
        )
      }
      object
    }
    "BatchedMesh" => {
      let geometry = get_geometry(data.get("geometry"))
      let material = get_material(data.get("material"))
      let object = @core.BatchedMesh::new(
        json_number(json_field(data, "maxInstanceCount"), "maxInstanceCount").to_int(),
        json_number(json_field(data, "maxVertexCount"), "maxVertexCount").to_int(),
        max_index_count?=json_opt_int(data, "maxIndexCount"),
        material?,
      )
      object_loader_batched_mesh(object, data, geometry, get_texture)
      object
    }
    "LOD" => @core.LOD::new()
    "Line" =>
      @core.Line::new(
        geometry?=get_geometry(data.get("geometry")),
        material?=get_material(data.get("material")),
      )
    "LineLoop" =>
      @core.LineLoop::new(
        geometry?=get_geometry(data.get("geometry")),
        material?=get_material(data.get("material")),
      )
    "LineSegments" =>
      @core.LineSegments::new(
        geometry?=get_geometry(data.get("geometry")),
        material?=get_material(data.get("material")),
      )
    "PointCloud" | "Points" =>
      @core.Points::new(
        geometry?=get_geometry(data.get("geometry")),
        material?=get_material(data.get("material")),
      )
    "Sprite" => {
      let object = @core.Sprite::new(
        material?=get_single_material(data.get("material")),
      )
      if data.get("center") is Some(center) {
        guard object.kind is Sprite(sprite) else {
          abort("ObjectLoader: not a Sprite")
        }
        sprite.center.from_array(json_numbers(center, "center")) |> ignore
      }
      object
    }
    "Group" => @core.Group::new()
    "Bone" => @core.Bone::new()
    _ => @core.Object3D::new()
  }
  object.uuid = json_string(json_field(data, "uuid"), "uuid")
  if json_opt_string(data, "name") is Some(name) {
    object.name = name
  }
  if data.get("pivot") is Some(pivot) {
    object.pivot = Some(
      @math.Vector3::new(0.0, 0.0, 0.0).from_array(json_numbers(pivot, "pivot")),
    )
  }
  if data.get("matrix") is Some(matrix) {
    object.matrix.from_array(json_numbers(matrix, "matrix")) |> ignore
    if json_opt_bool(data, "matrixAutoUpdate") is Some(matrix_auto_update) {
      object.matrix_auto_update = matrix_auto_update
    }
    if object.matrix_auto_update {
      object.matrix.decompose(object.position, object.quaternion, object.scale)
      |> ignore
      if object.pivot is Some(pivot) {
        object.position.copy(pivot).apply_matrix4(object.matrix).sub(pivot)
        |> ignore
      }
    }
  } else {
    if data.get("position") is Some(position) {
      object.position.from_array(json_numbers(position, "position")) |> ignore
    }
    if data.get("rotation") is Some(rotation) {
      object.rotation.from_array(json_array(rotation, "rotation")) |> ignore
    }
    if data.get("quaternion") is Some(quaternion) {
      object.quaternion.from_array(json_numbers(quaternion, "quaternion"))
      |> ignore
    }
    if data.get("scale") is Some(scale) {
      object.scale.from_array(json_numbers(scale, "scale")) |> ignore
    }
  }
  if data.get("up") is Some(up) {
    object.up.from_array(json_numbers(up, "up")) |> ignore
  }
  let morph_target_dictionary = data
    .get("morphTargetDictionary")
    .map(dictionary => {
      let copy : Map[String, Int32] = Map([])
      for key, value in json_object(dictionary, "morphTargetDictionary") {
        copy[key] = json_number(value, "morphTargetDictionary").to_int()
      }
      copy
    })
  let morph_target_influences = data
    .get("morphTargetInfluences")
    .map(influences => json_numbers(influences, "morphTargetInfluences"))
  object_loader_set_morph_targets(
    object, morph_target_dictionary, morph_target_influences,
  )
  if json_opt_bool(data, "castShadow") is Some(cast_shadow) {
    object.cast_shadow = cast_shadow
  }
  if json_opt_bool(data, "receiveShadow") is Some(receive_shadow) {
    object.receive_shadow = receive_shadow
  }
  if json_truthy(data.get("shadow")) {
    let shadow_data = json_object(data["shadow"], "shadow")
    let shadow = match object.kind {
      Light({ shadow: Some(shadow), .. }) => shadow
      _ => abort("ObjectLoader: object.shadow is undefined")
    }
    if json_opt_number(shadow_data, "intensity") is Some(value) {
      shadow.intensity = value
    }
    if json_opt_number(shadow_data, "bias") is Some(value) {
      shadow.bias = value
    }
    if json_opt_number(shadow_data, "normalBias") is Some(value) {
      shadow.normal_bias = value
    }
    if json_opt_number(shadow_data, "radius") is Some(value) {
      shadow.radius = value
    }
    if json_opt_int(shadow_data, "blurSamples") is Some(value) {
      shadow.blur_samples = value
    }
    // `focus` and `aspect` exist on `SpotLightShadow` only; upstream adds them
    // as unused properties elsewhere
    if json_opt_number(shadow_data, "focus") is Some(value) &&
      shadow.kind is SpotLightShadow(spot) {
      spot.focus = value
    }
    if json_opt_number(shadow_data, "aspect") is Some(value) &&
      shadow.kind is SpotLightShadow(spot) {
      spot.aspect = value
    }
    if shadow_data.get("mapSize") is Some(map_size) {
      shadow.map_size.from_array(json_numbers(map_size, "mapSize")) |> ignore
    }
    if json_opt_int(shadow_data, "mapType") is Some(value) {
      shadow.map_type = value
    }
    if shadow_data.get("camera") is Some(camera) {
      shadow.camera = self.parse_object(
        camera,
        Map([]),
        Map([]),
        Map([]),
        Map([]),
        pending,
      )
    }
  }
  if json_opt_bool(data, "visible") is Some(visible) {
    object.visible = visible
  }
  if json_opt_bool(data, "frustumCulled") is Some(frustum_culled) {
    object.frustum_culled = frustum_culled
  }
  if json_opt_number(data, "renderOrder") is Some(render_order) {
    object.render_order = render_order
  }
  if json_opt_bool(data, "static") is Some(static_) {
    object.static_ = static_
  }
  if data.get("userData") is Some(user_data) {
    object.user_data = JsValue::from_json(user_data)
  }
  if json_opt_number(data, "layers") is Some(layers) {
    object.layers.mask = layers
  }
  if data.get("children") is Some(children) {
    for child in json_array(children, "children") {
      object.add(
        self.parse_object(
          child, geometries, materials, textures, animations, pending,
        ),
      )
      |> ignore
    }
  }
  if data.get("animations") is Some(object_animations) {
    for uuid in json_array(object_animations, "animations") {
      let uuid = json_string(uuid, "animation")
      match animations.get(uuid) {
        Some(animation) => object.animations.push(animation)
        // upstream pushes `undefined`
        None => ()
      }
    }
  }
  if type_ == "LOD" {
    guard object.kind is LOD(lod) else { abort("ObjectLoader: not a LOD") }
    if json_opt_bool(data, "autoUpdate") is Some(auto_update) {
      lod.auto_update = auto_update
    }
    for level in json_array(json_field(data, "levels"), "levels") {
      let level = json_object(level, "level")
      let child = object.get_object_by_property(
        "uuid",
        json_field(level, "object"),
      )
      if child is Some(child) {
        // `addLevel` takes `Math.abs( distance )`, which is 0 for `null`
        let distance = match level.get("distance") {
          Some(Null) => Some(0.0)
          _ => json_opt_number(level, "distance")
        }
        object.add_level(
          child,
          distance?,
          hysteresis?=json_opt_number(level, "hysteresis"),
        )
        |> ignore
      }
    }
  }
  object
}

///|
fn ObjectLoader::bind_skeletons(
  self : ObjectLoader,
  object : @core.Object3D,
  skeletons : Map[String, @core.Skeleton],
  pending : ObjectLoaderPending,
) -> Unit {
  ignore(self)
  if skeletons.length() == 0 {
    return
  }
  object.traverse(child => {
    if child.is_skinned_mesh() && pending.skeletons.get(child.id) is Some(uuid) {
      match skeletons.get(uuid) {
        None => @core.warn("ObjectLoader: No skeleton found with UUID: " + uuid)
        Some(skeleton) => {
          guard child.kind is Mesh({ kind: SkinnedMesh(skinned), .. }) else {
            return
          }
          child.bind(skeleton, bind_matrix=skinned.bind_matrix)
        }
      }
    }
  })
}

///|
fn ObjectLoader::bind_light_targets(
  self : ObjectLoader,
  object : @core.Object3D,
  pending : ObjectLoaderPending,
) -> Unit {
  ignore(self)
  object.traverse(child => {
    let light = match child.kind {
      Light(light) => light
      _ => return
    }
    let set_target = match light.kind {
      DirectionalLight(directional) => target => directional.target = target
      SpotLight(spot) => target => spot.target = target
      _ => return
    }
    let uuid = pending.targets.get(child.id).unwrap_or("")
    match object.get_object_by_property("uuid", Json::string(uuid)) {
      Some(target) => set_target(target)
      None => set_target(@core.Object3D::new())
    }
  })
}
