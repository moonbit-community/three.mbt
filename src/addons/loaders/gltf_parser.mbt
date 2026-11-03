// Upstream GLTFParser (examples/jsm/loaders/GLTFLoader.js) and the module functions
// it uses (createDefaultMaterial, addUnknownExtensionsToUserData, addMorphTargets,
// updateMorphTargets, createPrimitiveKey, computeBounds, addPrimitiveAttributes).
// Dependencies are JS promises cached by key exactly as upstream caches them.

///|
/// The parser's `options`.
pub(all) struct GLTFParserOptions {
  path : String
  cross_origin : String
  priority : String
  cache : String
  with_credentials : Bool
  request_header : Map[String, String]
  manager : @loaders.LoadingManager
  ktx2_loader : KTX2Loader?
  meshopt_decoder : JsValue?
}

///|
/// A loader `loadImageSource` can use: `parser.textureLoader` or the KTX2 loader.
pub enum GLTFImageLoader {
  TextureLoader(@loaders.TextureLoader)
  ImageBitmapLoader(@loaders.ImageBitmapLoader)
  KTX2Loader(KTX2Loader)
}

///|
/// Parses a glTF JSON object (and its binary chunk) into three.js objects.
pub struct GLTFParser {
  json : JsValue
  mut extensions : Map[String, GLTFExtension]
  mut plugins : Map[String, &GLTFPlugin]
  options : GLTFParserOptions
  /// The loader object cache.
  cache : GLTFRegistry
  /// Associations between three.js objects and glTF elements.
  mut associations : GLTFAssociations
  /// BufferGeometry caching, by primitive key.
  primitive_cache : Map[String, AddonPromise]
  mut node_cache : Map[Int32, AddonPromise]
  mesh_cache : GLTFNodeRefCache
  camera_cache : GLTFNodeRefCache
  light_cache : GLTFNodeRefCache
  source_cache : Map[Int32, AddonPromise]
  texture_cache : Map[String, AddonPromise]
  /// Track node names, to ensure no duplicates (a plain JS object, as upstream).
  node_names_used : JsValue
  texture_loader : GLTFImageLoader
  file_loader : @loaders.FileLoader
}

///|
/// `_identityMatrix`.
let gltf_identity_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
pub fn GLTFParser::new(
  json : JsValue,
  options : GLTFParserOptions,
) -> GLTFParser {
  // Use an ImageBitmapLoader if imageBitmaps are supported. Moves much of the
  // expensive work of uploading a texture to the GPU off the main thread.
  let texture_loader = if gltf_use_texture_loader() {
    let loader = @loaders.TextureLoader::new(manager=options.manager)
    loader.set_priority(options.priority) |> ignore
    loader.set_cache(options.cache) |> ignore
    loader.set_cross_origin(options.cross_origin) |> ignore
    loader.set_with_credentials(options.with_credentials) |> ignore
    loader.set_request_header(options.request_header) |> ignore
    GLTFImageLoader::TextureLoader(loader)
  } else {
    let loader = @loaders.ImageBitmapLoader::new(manager=options.manager)
    loader.set_priority(options.priority) |> ignore
    loader.set_cache(options.cache) |> ignore
    loader.set_cross_origin(options.cross_origin) |> ignore
    loader.set_with_credentials(options.with_credentials) |> ignore
    loader.set_request_header(options.request_header) |> ignore
    GLTFImageLoader::ImageBitmapLoader(loader)
  }
  let file_loader = @loaders.FileLoader::new(manager=options.manager)
  file_loader.set_priority(options.priority) |> ignore
  file_loader.set_cache(options.cache) |> ignore
  file_loader.set_response_type("arraybuffer") |> ignore
  if options.with_credentials || options.cross_origin == "use-credentials" {
    file_loader.set_with_credentials(true) |> ignore
  }
  {
    json,
    extensions: {},
    plugins: {},
    options,
    cache: GLTFRegistry::new(),
    associations: GLTFAssociations::new(),
    primitive_cache: {},
    node_cache: {},
    mesh_cache: GLTFNodeRefCache::new(),
    camera_cache: GLTFNodeRefCache::new(),
    light_cache: GLTFNodeRefCache::new(),
    source_cache: {},
    texture_cache: {},
    node_names_used: JsValue::object(),
    texture_loader,
    file_loader,
  }
}

///|
pub fn GLTFParser::set_extensions(
  self : GLTFParser,
  extensions : Map[String, GLTFExtension],
) -> Unit {
  self.extensions = extensions
}

///|
pub fn GLTFParser::set_plugins(
  self : GLTFParser,
  plugins : Map[String, &GLTFPlugin],
) -> Unit {
  self.plugins = plugins
}

///|
/// The parser in the plugin lists of `_invokeOne` / `_invokeAll`.
priv struct GltfParserPlugin {
  parser : GLTFParser
}

///|
impl GLTFPlugin for GltfParserPlugin with fn name(_) {
  ""
}

///|
impl GLTFPlugin for GltfParserPlugin with fn mark_defs(self) {
  self.parser.mark_defs()
}

///|
impl GLTFPlugin for GltfParserPlugin with fn load_node(self, index) {
  Some(self.parser.load_node(index))
}

///|
impl GLTFPlugin for GltfParserPlugin with fn load_mesh(self, index) {
  Some(self.parser.load_mesh(index))
}

///|
impl GLTFPlugin for GltfParserPlugin with fn load_buffer_view(self, index) {
  Some(self.parser.load_buffer_view(index))
}

///|
impl GLTFPlugin for GltfParserPlugin with fn load_material(self, index) {
  Some(self.parser.load_material(index))
}

///|
impl GLTFPlugin for GltfParserPlugin with fn load_texture(self, index) {
  Some(self.parser.load_texture(index))
}

///|
impl GLTFPlugin for GltfParserPlugin with fn load_animation(self, index) {
  Some(self.parser.load_animation(index))
}

///|
impl GLTFPlugin for GltfParserPlugin with fn get_material_type(self, index) {
  Some(self.parser.get_material_type(index))
}

///|
impl GLTFPlugin for GltfParserPlugin with fn create_node_mesh(self, index) {
  self.parser.create_node_mesh(index)
}

///|
/// Parses the asset; `on_load` receives the result.
pub fn GLTFParser::parse(
  self : GLTFParser,
  on_load : (GLTFResult) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> Unit {
  let parser = self
  let json = self.json
  let extensions = self.extensions

  // Clear the loader cache
  self.cache.remove_all()
  self.node_cache = {}

  // Mark the special nodes/meshes in json for efficient parse
  self.invoke_all(fn(ext) {
    ext.mark_defs()
    None
  })
  |> ignore
  let chain = AddonPromise::all(self.invoke_all(ext => ext.before_root()))
    .then_(fn(_ : JsValue) {
      AddonPromise::all([
        parser.get_dependencies("scene"),
        parser.get_dependencies("animation"),
        parser.get_dependencies("camera"),
      ])
    })
    .then_(fn(dependencies : Array[JsValue]) {
      let scenes : Array[@core.Object3D] = dependencies[0].cast()
      let scene_index = gltf_or(json.get("scene"), gltf_js_number(0))
      let scene : @core.Object3D? = gltf_at(dependencies[0], scene_index.cast()).cast()
      let result = {
        scene,
        scenes,
        animations: dependencies[1].cast(),
        cameras: dependencies[2].cast(),
        asset: json.get("asset"),
        parser,
        user_data: JsValue::object(),
      }
      gltf_add_unknown_extensions_to_user_data(
        extensions,
        result.user_data,
        json,
      )
      gltf_assign_extras(result.user_data, json)
      AddonPromise::all(parser.invoke_all(ext => ext.after_root(result))).then_(fn(
          _ : JsValue,
        ) {
          for scene in result.scenes {
            scene.update_matrix_world()
          }
          on_load(result)
        },
      )
    })
  match on_error {
    Some(f) => chain.catch_(f) |> ignore
    None => ()
  }
}

///|
/// Marks the special nodes/meshes in json for efficient parse.
fn GLTFParser::mark_defs(self : GLTFParser) -> Unit {
  let empty = JsValue::of(([] : Array[Int32]))
  let node_defs = gltf_or(self.json.get("nodes"), empty)
  let skin_defs = gltf_or(self.json.get("skins"), empty)
  let mesh_defs = gltf_or(self.json.get("meshes"), empty)

  // Nothing in the node definition indicates whether it is a Bone or an
  // Object3D. Use the skins' joint references to mark bones.
  for skin_index in 0..<gltf_length(skin_defs) {
    let joints = gltf_at(skin_defs, skin_index).get("joints")
    for i in 0..<gltf_length(joints) {
      gltf_at(node_defs, gltf_at(joints, i).cast()).set(
        "isBone",
        JsValue::of(true),
      )
    }
  }

  // Iterate over all nodes, marking references to shared resources,
  // as well as skeleton joints.
  for node_index in 0..<gltf_length(node_defs) {
    let node_def = gltf_at(node_defs, node_index)
    if gltf_defined(node_def.get("mesh")) {
      self.add_node_ref(self.mesh_cache, node_def.get("mesh"))

      // Nothing in the mesh definition indicates whether it is
      // a SkinnedMesh or Mesh. Use the node's mesh reference
      // to mark SkinnedMesh if node has skin.
      if gltf_defined(node_def.get("skin")) {
        gltf_at(mesh_defs, node_def.get("mesh").cast()).set(
          "isSkinnedMesh",
          JsValue::of(true),
        )
      }
    }
    if gltf_defined(node_def.get("camera")) {
      self.add_node_ref(self.camera_cache, node_def.get("camera"))
    }
  }
}

///|
/// Counts references to shared node / Object3D resources (`_addNodeRef`).
pub fn GLTFParser::add_node_ref(
  _self : GLTFParser,
  cache : GLTFNodeRefCache,
  index : JsValue,
) -> Unit {
  if index.is_undefined() {
    return
  }
  let index : Int32 = index.cast()
  if cache.refs.get(index) is None {
    cache.refs[index] = 0
    cache.uses[index] = 0
  }
  cache.refs[index] = cache.refs[index] + 1
}

///|
/// Returns a reference to a shared resource, cloning it if necessary (`_getNodeRef`).
pub fn GLTFParser::get_node_ref(
  self : GLTFParser,
  cache : GLTFNodeRefCache,
  index : Int32,
  object : @core.Object3D,
) -> @core.Object3D {
  if cache.refs.get(index) is Some(refs) && refs <= 1 {
    return object
  }
  let ref_ = object.clone()

  // Propagates mappings to the cloned object, prevents mappings on the
  // original object from being lost.
  fn update_mappings(
    original : @core.Object3D,
    clone : @core.Object3D,
  ) -> Unit {
    let mappings = self.associations.get_object(original)
    if mappings is Some(_) {
      self.associations.set(Object3D(clone), mappings)
    }
    for i, child in original.children {
      update_mappings(child, clone.children[i])
    }
  }

  update_mappings(object, ref_)
  let uses = match cache.uses.get(index) {
    Some(u) => {
      cache.uses[index] = u + 1
      u.to_string()
    }
    None => "NaN"
  }
  ref_.name = ref_.name + "_instance_" + uses
  ref_
}

///|
/// `_invokeOne( func )`: the plugins, then the parser; the first truthy result.
fn[X] GLTFParser::invoke_one(
  self : GLTFParser,
  func : (&GLTFPlugin) -> X?,
) -> X? {
  let extensions : Array[&GLTFPlugin] = self.plugins.values().collect()
  extensions.push(GltfParserPlugin::{ parser: self, })
  for extension in extensions {
    let result = func(extension)
    if result is Some(_) {
      return result
    }
  }
  None
}

///|
/// `_invokeAll( func )`: the parser, then the plugins; every truthy result.
fn[X] GLTFParser::invoke_all(
  self : GLTFParser,
  func : (&GLTFPlugin) -> X?,
) -> Array[X] {
  let extensions : Array[&GLTFPlugin] = [GltfParserPlugin::{ parser: self, }]
  for p in self.plugins.values() {
    extensions.push(p)
  }
  let pending = []
  for extension in extensions {
    if func(extension) is Some(result) {
      pending.push(result)
    }
  }
  pending
}

///|
/// `null`, as a value where upstream passes or returns `null` for a promise.
fn gltf_null_promise() -> AddonPromise {
  JsValue::null().cast()
}

///|
/// Requests the specified dependency asynchronously, with caching.
pub fn GLTFParser::get_dependency(
  self : GLTFParser,
  type_ : String,
  index : Int32,
) -> AddonPromise {
  let cache_key = type_ + ":" + index.to_string()
  let mut dependency = self.cache.get(cache_key)
  if !gltf_truthy(dependency) {
    let result : AddonPromise? = match type_ {
      "scene" => Some(self.load_scene(index))
      "node" => self.invoke_one(ext => ext.load_node(index))
      "mesh" => self.invoke_one(ext => ext.load_mesh(index))
      "accessor" => Some(self.load_accessor(index))
      "bufferView" => self.invoke_one(ext => ext.load_buffer_view(index))
      "buffer" => Some(self.load_buffer(index))
      "material" => self.invoke_one(ext => ext.load_material(index))
      "texture" => self.invoke_one(ext => ext.load_texture(index))
      "skin" => Some(self.load_skin(index))
      "animation" => self.invoke_one(ext => ext.load_animation(index))
      "camera" => self.load_camera(index)
      _ => {
        let dependency = self.invoke_one(ext => ext.get_dependency(type_, index))
        if dependency is None {
          @utils.addon_throw_error("Unknown type: " + type_)
        }
        dependency
      }
    }
    dependency = match result {
      Some(p) => p.to_js()
      None =>
        if type_ == "camera" {
          JsValue::undefined()
        } else {
          JsValue::null()
        }
    }
    self.cache.add(cache_key, dependency)
  }
  dependency.cast()
}

///|
/// Requests all dependencies of the specified type asynchronously, with caching.
pub fn GLTFParser::get_dependencies(
  self : GLTFParser,
  type_ : String,
) -> AddonPromise {
  let mut dependencies = self.cache.get(type_)
  if !gltf_truthy(dependencies) {
    let parser = self
    let defs = gltf_or(
      self.json.get(type_ + (if type_ == "mesh" { "es" } else { "s" })),
      JsValue::of(([] : Array[Int32])),
    )
    let pending = []
    for index in 0..<gltf_length(defs) {
      pending.push(parser.get_dependency(type_, index).to_js())
    }
    dependencies = AddonPromise::all_values(pending).to_js()
    self.cache.add(type_, dependencies)
  }
  dependencies.cast()
}

///|
fn GLTFParser::load_buffer(
  self : GLTFParser,
  buffer_index : Int32,
) -> AddonPromise {
  let buffer_def = gltf_at(self.json.get("buffers"), buffer_index)
  let loader = self.file_loader
  if gltf_truthy(buffer_def.get("type")) &&
    !gltf_equals_string(buffer_def.get("type"), "arraybuffer") {
    @utils.addon_throw_error(
      "THREE.GLTFLoader: " +
      gltf_string(buffer_def.get("type")) +
      " buffer type is not supported.",
    )
  }

  // If present, GLB container is required to be the first buffer.
  if buffer_def.get("uri").is_undefined() && buffer_index == 0 {
    let body = match self.extensions.get(gltf_KHR_BINARY_GLTF) {
      Some(Binary(binary)) =>
        match binary.body {
          Some(body) => body
          None => JsValue::null()
        }
      _ =>
        @utils.addon_throw_error(
          "TypeError: Cannot read properties of undefined (reading 'body')",
        )
    }
    return AddonPromise::resolve(body)
  }
  let options = self.options
  AddonPromise::new(fn(resolve, reject) {
    loader.load(
      @loaders.LoaderUtils::resolve_url(
        gltf_string(buffer_def.get("uri")),
        options.path,
      ),
      on_load=resolve,
      on_error=fn(_) {
        reject(
          @utils.addon_new_error(
            "THREE.GLTFLoader: Failed to load buffer \"" +
            gltf_string(buffer_def.get("uri")) +
            "\".",
          ),
        )
      },
    )
  })
}

///|
fn GLTFParser::load_buffer_view(
  self : GLTFParser,
  buffer_view_index : Int32,
) -> AddonPromise {
  let buffer_view_def = gltf_at(self.json.get("bufferViews"), buffer_view_index)
  self
  .get_dependency("buffer", buffer_view_def.get("buffer").cast())
  .then_(fn(buffer : JsValue) {
    let byte_length : Int32 = gltf_or(
      buffer_view_def.get("byteLength"),
      gltf_js_number(0),
    ).cast()
    let byte_offset : Int32 = gltf_or(
      buffer_view_def.get("byteOffset"),
      gltf_js_number(0),
    ).cast()
    gltf_slice(buffer, byte_offset, byte_offset + byte_length)
  })
}

///|
/// `new TypedArray( buffer, byteOffset, length )`.
fn gltf_typed_view(
  name : String,
  buffer : JsValue,
  byte_offset : Int32,
  length : Int32,
) -> @core.TypedArray {
  @core.TypedArray::view_by_name(name, buffer.cast(), byte_offset~, length~)
}

///|
fn GLTFParser::load_accessor(
  self : GLTFParser,
  accessor_index : Int32,
) -> AddonPromise {
  let parser = self
  let json = self.json
  let accessor_def = gltf_at(self.json.get("accessors"), accessor_index)
  if accessor_def.get("bufferView").is_undefined() &&
    accessor_def.get("sparse").is_undefined() {
    let item_size = gltf_type_size(accessor_def.get("type"))
    let typed_array = gltf_component_type(accessor_def.get("componentType"))
    let normalized = gltf_is_true(accessor_def.get("normalized"))
    let count : Int32 = accessor_def.get("count").cast()
    let array = @core.TypedArray::new_by_name(typed_array, count * item_size)
    return AddonPromise::resolve(
      @core.GeometryAttribute::Buffer(
        @core.BufferAttribute::new(array, item_size, normalized~),
      ),
    )
  }
  let pending_buffer_views = []
  if gltf_defined(accessor_def.get("bufferView")) {
    pending_buffer_views.push(
      self.get_dependency("bufferView", accessor_def.get("bufferView").cast()),
    )
  } else {
    pending_buffer_views.push(gltf_null_promise())
  }
  if gltf_defined(accessor_def.get("sparse")) {
    let sparse = accessor_def.get("sparse")
    pending_buffer_views.push(
      self.get_dependency(
        "bufferView",
        sparse.get("indices").get("bufferView").cast(),
      ),
    )
    pending_buffer_views.push(
      self.get_dependency(
        "bufferView",
        sparse.get("values").get("bufferView").cast(),
      ),
    )
  }
  AddonPromise::all(pending_buffer_views).then_(fn(
    buffer_views : Array[JsValue],
  ) {
    let buffer_view = buffer_views[0]
    let item_size = gltf_type_size(accessor_def.get("type"))
    let typed_array = gltf_component_type(accessor_def.get("componentType"))

    // For VEC3: itemSize is 3, elementBytes is 4, itemBytes is 12.
    let element_bytes = gltf_bytes_per_element(typed_array)
    let item_bytes = element_bytes * item_size
    let byte_offset : Int32 = gltf_or(
      accessor_def.get("byteOffset"),
      gltf_js_number(0),
    ).cast()
    let byte_stride = if gltf_defined(accessor_def.get("bufferView")) {
      gltf_at(json.get("bufferViews"), accessor_def.get("bufferView").cast()).get(
        "byteStride",
      )
    } else {
      JsValue::undefined()
    }
    let normalized = gltf_is_true(accessor_def.get("normalized"))
    let count : Int32 = accessor_def.get("count").cast()
    let mut buffer_attribute : @core.GeometryAttribute = if gltf_truthy(
        byte_stride,
      ) &&
      !gltf_equals_number(byte_stride, item_bytes.to_double()) {
      // The buffer is not interleaved if the stride is the item size in bytes.
      // Each "slice" of the buffer, as defined by 'count' elements of 'byteStride' bytes, gets its own InterleavedBuffer
      // This makes sure that IBA.count reflects accessor.count properly
      let byte_stride : Int32 = byte_stride.cast()
      let ib_slice = gltf_floor(
        byte_offset.to_double() / byte_stride.to_double(),
      ).to_int()
      let ib_cache_key = "InterleavedBuffer:" +
        gltf_string(accessor_def.get("bufferView")) +
        ":" +
        gltf_string(accessor_def.get("componentType")) +
        ":" +
        ib_slice.to_string() +
        ":" +
        count.to_string()
      let cached = parser.cache.get(ib_cache_key)
      let ib : @core.InterleavedBuffer = if gltf_truthy(cached) {
        cached.cast()
      } else {
        let array = gltf_typed_view(
          typed_array,
          buffer_view,
          ib_slice * byte_stride,
          count * byte_stride / element_bytes,
        )

        // Integer parameters to IB/IBA are in array elements, not bytes.
        let ib = @core.InterleavedBuffer::new(
          array,
          byte_stride / element_bytes,
        )
        parser.cache.add(ib_cache_key, JsValue::of(ib))
        ib
      }
      Interleaved(
        @core.InterleavedBufferAttribute::new(
          ib,
          item_size,
          byte_offset % byte_stride / element_bytes,
          normalized~,
        ),
      )
    } else {
      let array = if buffer_view.is_null() {
        @core.TypedArray::new_by_name(typed_array, count * item_size)
      } else {
        gltf_typed_view(
          typed_array,
          buffer_view,
          byte_offset,
          count * item_size,
        )
      }
      Buffer(@core.BufferAttribute::new(array, item_size, normalized~))
    }

    // https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#sparse-accessors
    if gltf_defined(accessor_def.get("sparse")) {
      let sparse = accessor_def.get("sparse")
      let item_size_indices = 1
      let typed_array_indices = gltf_component_type(
        sparse.get("indices").get("componentType"),
      )
      let byte_offset_indices : Int32 = gltf_or(
        sparse.get("indices").get("byteOffset"),
        gltf_js_number(0),
      ).cast()
      let byte_offset_values : Int32 = gltf_or(
        sparse.get("values").get("byteOffset"),
        gltf_js_number(0),
      ).cast()
      let sparse_count : Int32 = sparse.get("count").cast()
      let sparse_indices = gltf_typed_view(
        typed_array_indices,
        buffer_views[1],
        byte_offset_indices,
        sparse_count * item_size_indices,
      )
      let sparse_values = gltf_typed_view(
        typed_array,
        buffer_views[2],
        byte_offset_values,
        sparse_count * item_size,
      )
      if !buffer_view.is_null() {
        // Avoid modifying the original ArrayBuffer, if the bufferView wasn't initialized with zeroes.
        buffer_attribute = Buffer(
          @core.BufferAttribute::new(
            buffer_attribute.array().slice(),
            buffer_attribute.item_size(),
            normalized=buffer_attribute.normalized(),
          ),
        )
      }

      // Ignore normalized since we copy from sparse
      gltf_set_normalized(buffer_attribute, false)
      for i in 0..<sparse_indices.length() {
        let index = sparse_indices.get_int(i)
        buffer_attribute.set_x(index, sparse_values[i * item_size])
        if item_size >= 2 {
          buffer_attribute.set_y(index, sparse_values[i * item_size + 1])
        }
        if item_size >= 3 {
          buffer_attribute.set_z(index, sparse_values[i * item_size + 2])
        }
        if item_size >= 4 {
          buffer_attribute.set_w(index, sparse_values[i * item_size + 3])
        }
        if item_size >= 5 {
          @utils.addon_throw_error(
            "THREE.GLTFLoader: Unsupported itemSize in sparse BufferAttribute.",
          )
        }
      }
      gltf_set_normalized(buffer_attribute, normalized)
    }
    buffer_attribute
  })
}

///|
fn GLTFParser::load_texture(
  self : GLTFParser,
  texture_index : Int32,
) -> AddonPromise {
  let json = self.json
  let texture_def = gltf_at(json.get("textures"), texture_index)
  let source_index : Int32 = texture_def.get("source").cast()
  let source_def = gltf_at(json.get("images"), source_index)
  let loader = gltf_source_loader(self, source_def)
  self.load_texture_image(texture_index, source_index, loader)
}

///|
/// Loads a texture's image with `loader`, resolving to the texture or `null`.
pub fn GLTFParser::load_texture_image(
  self : GLTFParser,
  texture_index : Int32,
  source_index : Int32,
  loader : GLTFImageLoader,
) -> AddonPromise {
  let parser = self
  let json = self.json
  let texture_def = gltf_at(json.get("textures"), texture_index)
  let source_def = gltf_at(json.get("images"), source_index)
  let cache_key = gltf_concat_key(
    gltf_or(source_def.get("uri"), source_def.get("bufferView")),
    texture_def.get("sampler"),
  )
  if self.texture_cache.get(cache_key) is Some(promise) {
    // See https://github.com/mrdoob/three.js/issues/21559.
    return promise
  }
  let promise = self
    .load_image_source(source_index, loader)
    .then_(fn(texture : @core.Texture) {
      texture.flip_y = false
      texture.name = gltf_string(
        gltf_or(
          gltf_or(texture_def.get("name"), source_def.get("name")),
          gltf_js_string(""),
        ),
      )
      if texture.name == "" &&
        gltf_is_string(source_def.get("uri")) &&
        !gltf_string(source_def.get("uri")).has_prefix("data:image/") {
        texture.name = gltf_string(source_def.get("uri"))
      }
      let samplers = gltf_or(json.get("samplers"), JsValue::object())
      let sampler = gltf_or(
        gltf_index_any(samplers, texture_def.get("sampler")),
        JsValue::object(),
      )
      texture.mag_filter = gltf_webgl_filter(sampler.get("magFilter")).unwrap_or(
        @core.LinearFilter,
      )
      texture.min_filter = gltf_webgl_filter(sampler.get("minFilter")).unwrap_or(
        @core.LinearMipmapLinearFilter,
      )
      texture.wrap_s = gltf_webgl_wrapping(sampler.get("wrapS")).unwrap_or(
        @core.RepeatWrapping,
      )
      texture.wrap_t = gltf_webgl_wrapping(sampler.get("wrapT")).unwrap_or(
        @core.RepeatWrapping,
      )
      texture.generate_mipmaps = !texture.is_compressed_texture() &&
        texture.min_filter != @core.NearestFilter &&
        texture.min_filter != @core.LinearFilter
      parser.associations.set(
        Texture(texture),
        Some(GLTFReference::new(textures=texture_index)),
      )
      texture
    })
    .catch_(fn(_) { JsValue::null() })
  self.texture_cache[cache_key] = promise
  promise
}

///|
/// `o[ k ]` with any key value.
extern "js" fn gltf_index_any(object : JsValue, key : JsValue) -> JsValue = "(o, k) => o[k]"

///|
fn GLTFParser::load_image_source(
  self : GLTFParser,
  source_index : Int32,
  loader : GLTFImageLoader,
) -> AddonPromise {
  let parser = self
  let json = self.json
  let options = self.options
  if self.source_cache.get(source_index) is Some(cached) {
    return cached.then_(fn(texture : @core.Texture) { texture.clone() })
  }
  let source_def = gltf_at(json.get("images"), source_index)
  let source_uri = Ref::new(gltf_or(source_def.get("uri"), gltf_js_string("")))
  let is_object_url = Ref::new(false)
  let pending = match loader {
    KTX2Loader(loader) if gltf_defined(source_def.get("bufferView")) =>
      // KTX2Loader parses the binary image data from bufferView directly (see #35193).
      parser
      .get_dependency("bufferView", source_def.get("bufferView").cast())
      .then_(fn(buffer_view : JsValue) {
        AddonPromise::new(fn(resolve, reject) {
          loader.parse(
            buffer_view,
            Some(fn(texture) { resolve(JsValue::of(texture)) }),
            Some(reject),
          )
        })
      })
    _ => {
      if gltf_defined(source_def.get("bufferView")) {
        // Load binary image data from bufferView, if provided.
        source_uri.val = parser
          .get_dependency("bufferView", source_def.get("bufferView").cast())
          .then_(fn(buffer_view : JsValue) {
            is_object_url.val = true
            let url = gltf_create_object_url(
              buffer_view,
              source_def.get("mimeType"),
            )
            source_uri.val = gltf_js_string(url)
            url
          })
          .to_js()
      } else if source_def.get("uri").is_undefined() {
        @utils.addon_throw_error(
          "THREE.GLTFLoader: Image " +
          source_index.to_string() +
          " is missing URI and bufferView",
        )
      }
      AddonPromise::resolve(source_uri.val).then_(fn(source_uri : String) {
        AddonPromise::new(fn(resolve, reject) {
          let url = @loaders.LoaderUtils::resolve_url(source_uri, options.path)
          match loader {
            ImageBitmapLoader(loader) =>
              loader.load(
                url,
                on_load=fn(image_bitmap) {
                  let texture = @core.Texture::new(
                    image=@core.TextureImage::from_js(image_bitmap),
                  )
                  texture.set_needs_update(true)
                  resolve(JsValue::of(texture))
                },
                on_error=reject,
              )
            TextureLoader(loader) =>
              loader.load(
                url,
                on_load=fn(texture) { resolve(JsValue::of(texture)) },
                on_error=reject,
              )
              |> ignore
            KTX2Loader(loader) =>
              loader.load(
                url,
                fn(texture) { resolve(JsValue::of(texture)) },
                on_error=reject,
              )
          }
        })
      })
    }
  }
  let promise = pending
    .then_(fn(texture : @core.Texture) {
      // Clean up resources and configure Texture.
      if is_object_url.val {
        gltf_revoke_object_url(source_uri.val)
      }
      gltf_assign_extras(texture.user_data, source_def)
      texture.user_data.set(
        "mimeType",
        if gltf_truthy(source_def.get("mimeType")) {
          source_def.get("mimeType")
        } else {
          gltf_js_string(gltf_image_uri_mime_type(source_def.get("uri")))
        },
      )
      texture
    })
    .catch_(fn(error) -> JsValue {
      gltf_console_error2(
        "THREE.GLTFLoader: Couldn't load texture",
        source_uri.val,
      )
      @utils.addon_throw(error)
    })
  self.source_cache[source_index] = promise
  promise
}

///|
/// Asynchronously assigns a texture to the given material parameters.
pub fn GLTFParser::assign_texture(
  self : GLTFParser,
  material_params : GLTFMaterialParams,
  map_name : String,
  map_def : JsValue,
  color_space? : String,
) -> AddonPromise {
  let parser = self
  self
  .get_dependency("texture", map_def.get("index").cast())
  .then_(fn(texture : JsValue) -> JsValue {
    if !gltf_truthy(texture) {
      return JsValue::null()
    }
    let mut texture : @core.Texture = texture.cast()
    let tex_coord = map_def.get("texCoord")
    if gltf_defined(tex_coord) && gltf_greater_than_zero(tex_coord) {
      texture = texture.clone()
      texture.channel = tex_coord.cast()
    }
    if parser.extensions.get(gltf_KHR_TEXTURE_TRANSFORM) is Some(extension) {
      let transform = if gltf_defined(map_def.get("extensions")) {
        map_def.get("extensions").get(gltf_KHR_TEXTURE_TRANSFORM)
      } else {
        JsValue::undefined()
      }
      if gltf_truthy(transform) {
        let gltf_reference = parser.associations.get_texture(texture)
        texture = match extension {
          TextureTransform(ext) => ext.extend_texture(texture, transform)
          _ =>
            @utils.addon_throw_error(
              "TypeError: parser.extensions[ EXTENSIONS.KHR_TEXTURE_TRANSFORM ].extendTexture is not a function",
            )
        }
        parser.associations.set(Texture(texture), gltf_reference)
      }
    }
    if color_space is Some(color_space) {
      texture.color_space = color_space
    }
    material_params[map_name] = Texture(texture)
    JsValue::of(texture)
  })
}

///|
/// `v > 0`.
extern "js" fn gltf_greater_than_zero(v : JsValue) -> Bool = "(v) => v > 0"

///|
/// The geometry of a Mesh, Line or Points.
fn gltf_mesh_geometry(object : @core.Object3D) -> @core.BufferGeometry {
  match object.get_geometry() {
    Some(g) => g
    None =>
      @utils.addon_throw_error(
        "TypeError: Cannot read properties of undefined (reading 'geometry')",
      )
  }
}

///|
/// `object.geometry = geometry`.
fn gltf_set_mesh_geometry(
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
) -> Unit {
  match object.kind {
    Mesh(m) => m.geometry = geometry
    Line(m) => m.geometry = geometry
    Points(m) => m.geometry = geometry
    Sprite(m) => m.geometry = geometry
    _ => ()
  }
}

///|
/// The material slot of a Mesh, Line or Points.
fn gltf_mesh_material(object : @core.Object3D) -> @core.MaterialSlot {
  match object.get_material() {
    Some(m) => m
    None =>
      @utils.addon_throw_error(
        "TypeError: Cannot read properties of undefined (reading 'material')",
      )
  }
}

///|
/// `object.material = material`.
fn gltf_set_mesh_material(
  object : @core.Object3D,
  material : @core.Material,
) -> Unit {
  match object.kind {
    Mesh(m) => m.material = Single(material)
    Line(m) => m.material = Single(material)
    Points(m) => m.material = Single(material)
    Sprite(m) => m.material = material
    _ => ()
  }
}

///|
/// Assigns the final material to a Mesh, Line, or Points instance, deriving and
/// caching variants for points, lines, vertex colors, flat shading and derivative
/// tangents.
pub fn GLTFParser::assign_final_material(
  self : GLTFParser,
  mesh : @core.Object3D,
) -> Unit {
  let geometry = gltf_mesh_geometry(mesh)
  let mut material = match gltf_mesh_material(mesh) {
    Single(m) => m
    Multiple(ms) => ms[0]
  }
  let use_derivative_tangents = geometry.attributes.get("tangent") is None
  let use_vertex_colors = geometry.attributes.get("color") is Some(_)
  let use_flat_shading = geometry.attributes.get("normal") is None
  if mesh.is_points() {
    let cache_key = "PointsMaterial:" + material.uuid
    let cached = self.cache.get(cache_key)
    let points_material : @core.Material = if gltf_truthy(cached) {
      cached.cast()
    } else {
      let points_material = @core.PointsMaterial::new()
      points_material.copy_base(material)
      if points_material.color is Some(c) && material.color is Some(m) {
        c.copy(m) |> ignore
      }
      points_material.map = material.map
      points_material.size_attenuation = Some(false) // glTF spec says points should be 1px
      self.cache.add(cache_key, JsValue::of(points_material))
      points_material
    }
    material = points_material
  } else if mesh.is_line() {
    let cache_key = "LineBasicMaterial:" + material.uuid
    let cached = self.cache.get(cache_key)
    let line_material : @core.Material = if gltf_truthy(cached) {
      cached.cast()
    } else {
      let line_material = @core.LineBasicMaterial::new()
      line_material.copy_base(material)
      if line_material.color is Some(c) && material.color is Some(m) {
        c.copy(m) |> ignore
      }
      line_material.map = material.map
      self.cache.add(cache_key, JsValue::of(line_material))
      line_material
    }
    material = line_material
  }

  // Clone the material if it will be modified
  if use_derivative_tangents || use_vertex_colors || use_flat_shading {
    let mut cache_key = "ClonedMaterial:" + material.uuid + ":"
    if use_derivative_tangents {
      cache_key += "derivative-tangents:"
    }
    if use_vertex_colors {
      cache_key += "vertex-colors:"
    }
    if use_flat_shading {
      cache_key += "flat-shading:"
    }
    let cached = self.cache.get(cache_key)
    let cached_material : @core.Material = if gltf_truthy(cached) {
      cached.cast()
    } else {
      let cached_material = material.clone()
      if use_vertex_colors {
        cached_material.vertex_colors = true
      }
      if use_flat_shading {
        cached_material.flat_shading = Some(true)
      }
      if use_derivative_tangents {
        // https://github.com/mrdoob/three.js/issues/11438#issuecomment-507003995
        if cached_material.normal_scale is Some(s) {
          s.y = s.y * -1.0
        }
        if cached_material.clearcoat_normal_scale is Some(s) {
          s.y = s.y * -1.0
        }
      }
      self.cache.add(cache_key, JsValue::of(cached_material))
      self.associations.set(
        Material(cached_material),
        self.associations.get_material(material),
      )
      cached_material
    }
    material = cached_material
  }
  gltf_set_mesh_material(mesh, material)
}

///|
fn GLTFParser::get_material_type(
  _self : GLTFParser,
  _material_index : Int32,
) -> GLTFMaterialType {
  MeshStandardMaterial
}

///|
fn GLTFParser::load_material(
  self : GLTFParser,
  material_index : Int32,
) -> AddonPromise {
  let parser = self
  let json = self.json
  let extensions = self.extensions
  let material_def = gltf_at(json.get("materials"), material_index)
  let material_params : GLTFMaterialParams = {}
  let material_extensions = gltf_or(
    material_def.get("extensions"),
    JsValue::object(),
  )
  let pending = []
  let material_type = if gltf_truthy(
      material_extensions.get(gltf_KHR_MATERIALS_UNLIT),
    ) {
    let kmu_extension = match extensions.get(gltf_KHR_MATERIALS_UNLIT) {
      Some(MaterialsUnlit(ext)) => ext
      _ =>
        @utils.addon_throw_error(
          "TypeError: Cannot read properties of undefined (reading 'getMaterialType')",
        )
    }
    let material_type = kmu_extension.get_material_type()
    pending.push(
      kmu_extension.extend_params(material_params, material_def, parser),
    )
    material_type
  } else {
    // Specification:
    // https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#metallic-roughness-material
    let metallic_roughness = gltf_or(
      material_def.get("pbrMetallicRoughness"),
      JsValue::object(),
    )
    let color = @math.Color::new(1.0, 1.0, 1.0)
    material_params["color"] = Color(color)
    material_params["opacity"] = Number(1.0)
    if gltf_is_array(metallic_roughness.get("baseColorFactor")) {
      let array = metallic_roughness.get("baseColorFactor")
      color.set_rgb(
        gltf_at(array, 0).cast(),
        gltf_at(array, 1).cast(),
        gltf_at(array, 2).cast(),
        color_space=@core.LinearSRGBColorSpace,
      )
      |> ignore
      material_params["opacity"] = gltf_param_number(gltf_at(array, 3))
    }
    if gltf_defined(metallic_roughness.get("baseColorTexture")) {
      pending.push(
        parser.assign_texture(
          material_params,
          "map",
          metallic_roughness.get("baseColorTexture"),
          color_space=@core.SRGBColorSpace,
        ),
      )
    }
    material_params["metalness"] = if gltf_defined(
        metallic_roughness.get("metallicFactor"),
      ) {
      gltf_param_number(metallic_roughness.get("metallicFactor"))
    } else {
      Number(1.0)
    }
    material_params["roughness"] = if gltf_defined(
        metallic_roughness.get("roughnessFactor"),
      ) {
      gltf_param_number(metallic_roughness.get("roughnessFactor"))
    } else {
      Number(1.0)
    }
    if gltf_defined(metallic_roughness.get("metallicRoughnessTexture")) {
      pending.push(
        parser.assign_texture(
          material_params,
          "metalnessMap",
          metallic_roughness.get("metallicRoughnessTexture"),
        ),
      )
      pending.push(
        parser.assign_texture(
          material_params,
          "roughnessMap",
          metallic_roughness.get("metallicRoughnessTexture"),
        ),
      )
    }
    let material_type = self
      .invoke_one(ext => ext.get_material_type(material_index))
      .unwrap()
    pending.push(
      AddonPromise::all(
        self.invoke_all(ext => {
          ext.extend_material_params(material_index, material_params)
        }),
      ),
    )
    material_type
  }
  if gltf_is_true(material_def.get("doubleSided")) {
    material_params["side"] = Number(@core.DoubleSide.to_double())
  }
  let alpha_mode = gltf_or(
    material_def.get("alphaMode"),
    gltf_js_string("OPAQUE"),
  )
  if gltf_equals_string(alpha_mode, "BLEND") {
    material_params["transparent"] = Bool(true)

    // See: https://github.com/mrdoob/three.js/issues/17706
    material_params["depthWrite"] = Bool(false)
  } else {
    material_params["transparent"] = Bool(false)
    if gltf_equals_string(alpha_mode, "MASK") {
      material_params["alphaTest"] = if gltf_defined(
          material_def.get("alphaCutoff"),
        ) {
        gltf_param_number(material_def.get("alphaCutoff"))
      } else {
        Number(0.5)
      }
    }
  }
  let is_basic = material_type.same(MeshBasicMaterial)
  if gltf_defined(material_def.get("normalTexture")) && !is_basic {
    pending.push(
      parser.assign_texture(
        material_params,
        "normalMap",
        material_def.get("normalTexture"),
      ),
    )
    let normal_scale = @math.Vector2::new(1, 1)
    material_params["normalScale"] = Vector2(normal_scale)
    if gltf_defined(material_def.get("normalTexture").get("scale")) {
      let scale : Double = material_def.get("normalTexture").get("scale").cast()
      normal_scale.set(scale, scale) |> ignore
    }
  }
  if gltf_defined(material_def.get("occlusionTexture")) && !is_basic {
    pending.push(
      parser.assign_texture(
        material_params,
        "aoMap",
        material_def.get("occlusionTexture"),
      ),
    )
    if gltf_defined(material_def.get("occlusionTexture").get("strength")) {
      material_params["aoMapIntensity"] = gltf_param_number(
        material_def.get("occlusionTexture").get("strength"),
      )
    }
  }
  if gltf_defined(material_def.get("emissiveFactor")) && !is_basic {
    let emissive_factor = material_def.get("emissiveFactor")
    material_params["emissive"] = Color(gltf_color_from_array(emissive_factor))
  }
  if gltf_defined(material_def.get("emissiveTexture")) && !is_basic {
    pending.push(
      parser.assign_texture(
        material_params,
        "emissiveMap",
        material_def.get("emissiveTexture"),
        color_space=@core.SRGBColorSpace,
      ),
    )
  }
  AddonPromise::all(pending).then_(fn(_ : JsValue) {
    let material = material_type.create()
    material.set_values(values=material_params)
    if gltf_truthy(material_def.get("name")) {
      material.name = gltf_string(material_def.get("name"))
    }
    gltf_assign_extras(material.user_data, material_def)
    parser.associations.set(
      Material(material),
      Some(GLTFReference::new(materials=material_index)),
    )
    if gltf_truthy(material_def.get("extensions")) {
      gltf_add_unknown_extensions_to_user_data(
        extensions,
        material.user_data,
        material_def,
      )
    }
    material
  })
}

///|
/// When Object3D instances are targeted by animation, they need unique names.
pub fn GLTFParser::create_unique_name(
  self : GLTFParser,
  original_name : JsValue,
) -> String {
  let sanitized_name = @animation.PropertyBinding::sanitize_node_name(
    gltf_string(gltf_or(original_name, gltf_js_string(""))),
  )
  if gltf_in(self.node_names_used, sanitized_name) {
    sanitized_name +
    "_" +
    gltf_string(gltf_pre_increment(self.node_names_used, sanitized_name))
  } else {
    self.node_names_used.set(sanitized_name, gltf_js_number(0))
    sanitized_name
  }
}

///|
/// Creates BufferGeometries from primitives.
fn GLTFParser::load_geometries(
  self : GLTFParser,
  primitives : JsValue,
) -> AddonPromise {
  let parser = self
  let extensions = self.extensions
  let cache = self.primitive_cache
  fn create_draco_primitive(primitive : JsValue) -> AddonPromise {
    let ext = match extensions.get(gltf_KHR_DRACO_MESH_COMPRESSION) {
      Some(DracoMeshCompression(ext)) => ext
      _ =>
        @utils.addon_throw_error(
          "TypeError: Cannot read properties of undefined (reading 'decodePrimitive')",
        )
    }
    ext
    .decode_primitive(primitive, parser)
    .then_(fn(geometry : @core.BufferGeometry) {
      gltf_add_primitive_attributes(geometry, primitive, parser)
    })
  }

  let pending = []
  for i in 0..<gltf_length(primitives) {
    let primitive = gltf_at(primitives, i)
    let cache_key = gltf_create_primitive_key(primitive)

    // See if we've already created this geometry
    match cache.get(cache_key) {
      Some(cached) =>
        // Use the cached geometry if it exists
        pending.push(cached)
      None => {
        let extensions = primitive.get("extensions")
        let mut geometry_promise = if gltf_truthy(extensions) &&
          gltf_truthy(extensions.get(gltf_KHR_DRACO_MESH_COMPRESSION)) {
          // Use DRACO geometry if available
          create_draco_primitive(primitive)
        } else {
          // Otherwise create a new geometry
          gltf_add_primitive_attributes(
            @core.BufferGeometry::new(),
            primitive,
            parser,
          )
        }

        // Convert strip/fan primitives to triangles
        let mode = primitive.get("mode")
        if gltf_equals_number(mode, gltf_TRIANGLE_STRIP) {
          geometry_promise = geometry_promise.then_(fn(
            geometry : @core.BufferGeometry,
          ) {
            @utils.BufferGeometryUtils::to_triangles_draw_mode(
              geometry,
              @core.TriangleStripDrawMode,
            )
          })
        } else if gltf_equals_number(mode, gltf_TRIANGLE_FAN) {
          geometry_promise = geometry_promise.then_(fn(
            geometry : @core.BufferGeometry,
          ) {
            @utils.BufferGeometryUtils::to_triangles_draw_mode(
              geometry,
              @core.TriangleFanDrawMode,
            )
          })
        }

        // Cache this geometry
        cache[cache_key] = geometry_promise
        pending.push(geometry_promise)
      }
    }
  }
  AddonPromise::all(pending)
}

///|
fn GLTFParser::load_mesh(self : GLTFParser, mesh_index : Int32) -> AddonPromise {
  let parser = self
  let json = self.json
  let extensions = self.extensions
  let mesh_def = gltf_at(json.get("meshes"), mesh_index)
  let primitives = mesh_def.get("primitives")
  let pending = []
  for i in 0..<gltf_length(primitives) {
    let material = if gltf_at(primitives, i).get("material").is_undefined() {
      JsValue::of(gltf_create_default_material(self.cache))
    } else {
      self
      .get_dependency("material", gltf_at(primitives, i).get("material").cast())
      .to_js()
    }
    pending.push(material)
  }
  pending.push(parser.load_geometries(primitives).to_js())
  AddonPromise::all_values(pending).then_(fn(results : Array[JsValue]) {
    let materials = results[0:results.length() - 1]
    let geometries : Array[@core.BufferGeometry] = results[results.length() - 1].cast()
    let meshes = []
    for i in 0..<geometries.length() {
      let geometry = geometries[i]
      let primitive = gltf_at(primitives, i)

      // 1. create Mesh
      let material : @core.Material = materials[i].cast()
      let mode = primitive.get("mode")
      let mesh = if gltf_equals_number(mode, gltf_TRIANGLES) ||
        gltf_equals_number(mode, gltf_TRIANGLE_STRIP) ||
        gltf_equals_number(mode, gltf_TRIANGLE_FAN) ||
        mode.is_undefined() {
        let needs_skinning = gltf_is_true(mesh_def.get("isSkinnedMesh"))
        let has_skinning_attributes = geometry.has_attribute("skinIndex") &&
          geometry.has_attribute("skinWeight")
        if needs_skinning && !has_skinning_attributes {
          gltf_console_warn(
            "THREE.GLTFLoader: Missing skinIndex or skinWeight attributes. Skinning disabled.",
          )
        }

        // .isSkinnedMesh isn't in glTF spec. See ._markDefs()
        let mesh = if needs_skinning && has_skinning_attributes {
          @core.SkinnedMesh::new(geometry~, material=Single(material))
        } else {
          @core.Mesh::new(geometry~, material=Single(material))
        }
        if mesh.is_skinned_mesh() {
          // normalize skin weights to fix malformed assets (see #15319)
          mesh.normalize_skin_weights()
        }
        mesh
      } else if gltf_equals_number(mode, gltf_LINES) {
        @core.LineSegments::new(geometry~, material=Single(material))
      } else if gltf_equals_number(mode, gltf_LINE_STRIP) {
        @core.Line::new(geometry~, material=Single(material))
      } else if gltf_equals_number(mode, gltf_LINE_LOOP) {
        @core.LineLoop::new(geometry~, material=Single(material))
      } else if gltf_equals_number(mode, gltf_POINTS) {
        @core.Points::new(geometry~, material=Single(material))
      } else {
        @utils.addon_throw_error(
          "THREE.GLTFLoader: Primitive mode unsupported: " + gltf_string(mode),
        )
      }
      if gltf_mesh_geometry(mesh).morph_attributes.length() > 0 {
        gltf_update_morph_targets(mesh, mesh_def)
      }
      mesh.name = parser.create_unique_name(
        gltf_or(
          mesh_def.get("name"),
          gltf_js_string("mesh_" + mesh_index.to_string()),
        ),
      )
      gltf_assign_extras(mesh.user_data, mesh_def)
      if gltf_truthy(primitive.get("extensions")) {
        gltf_add_unknown_extensions_to_user_data(
          extensions,
          mesh.user_data,
          primitive,
        )
      }
      parser.assign_final_material(mesh)
      meshes.push(mesh)
    }
    for i in 0..<meshes.length() {
      parser.associations.set(
        Object3D(meshes[i]),
        Some(GLTFReference::new(meshes=mesh_index, primitives=i)),
      )
    }
    if meshes.length() == 1 {
      if gltf_truthy(mesh_def.get("extensions")) {
        gltf_add_unknown_extensions_to_user_data(
          extensions,
          meshes[0].user_data,
          mesh_def,
        )
      }
      // upstream's `async` callback: the result is a promise the chain adopts
      return AddonPromise::resolve(meshes[0])
    }
    let group = @core.Group::new()
    if gltf_truthy(mesh_def.get("extensions")) {
      gltf_add_unknown_extensions_to_user_data(
        extensions,
        group.user_data,
        mesh_def,
      )
    }
    parser.associations.set(
      Object3D(group),
      Some(GLTFReference::new(meshes=mesh_index)),
    )
    for i in 0..<meshes.length() {
      group.add(meshes[i]) |> ignore
    }
    AddonPromise::resolve(group)
  })
}

///|
fn GLTFParser::load_camera(
  self : GLTFParser,
  camera_index : Int32,
) -> AddonPromise? {
  let camera_def = gltf_at(self.json.get("cameras"), camera_index)
  let params = gltf_index_any(camera_def, camera_def.get("type"))
  if !gltf_truthy(params) {
    gltf_console_warn("THREE.GLTFLoader: Missing camera parameters.")
    return None
  }
  let camera = if gltf_equals_string(camera_def.get("type"), "perspective") {
    @core.PerspectiveCamera::new(
      fov=@math.rad_to_deg(params.get("yfov").cast()),
      aspect=gltf_or(params.get("aspectRatio"), gltf_js_number(1)).cast(),
      near=gltf_or(params.get("znear"), gltf_js_number(1)).cast(),
      far=gltf_or(params.get("zfar"), gltf_js_number(2.0e6)).cast(),
    )
  } else if gltf_equals_string(camera_def.get("type"), "orthographic") {
    let xmag : Double = params.get("xmag").cast()
    let ymag : Double = params.get("ymag").cast()
    let znear : Double? = if params.get("znear").is_undefined() {
      None
    } else {
      Some(params.get("znear").cast())
    }
    let zfar : Double? = if params.get("zfar").is_undefined() {
      None
    } else {
      Some(params.get("zfar").cast())
    }
    @core.OrthographicCamera::new(
      left=-xmag,
      right=xmag,
      top=ymag,
      bottom=-ymag,
      near?=znear,
      far?=zfar,
    )
  } else {
    @utils.addon_throw_error(
      "TypeError: Cannot set properties of undefined (setting 'name')",
    )
  }
  if gltf_truthy(camera_def.get("name")) {
    camera.name = self.create_unique_name(camera_def.get("name"))
  }
  gltf_assign_extras(camera.user_data, camera_def)
  Some(AddonPromise::resolve(camera))
}

///|
fn GLTFParser::load_skin(self : GLTFParser, skin_index : Int32) -> AddonPromise {
  let skin_def = gltf_at(self.json.get("skins"), skin_index)
  let joints = skin_def.get("joints")
  let pending = []
  for i in 0..<gltf_length(joints) {
    pending.push(self.load_node_shallow(gltf_at(joints, i).cast()))
  }
  if gltf_defined(skin_def.get("inverseBindMatrices")) {
    pending.push(
      self.get_dependency(
        "accessor",
        skin_def.get("inverseBindMatrices").cast(),
      ),
    )
  } else {
    pending.push(gltf_null_promise())
  }
  AddonPromise::all(pending).then_(fn(results : Array[JsValue]) {
    let inverse_bind_matrices = results.pop().unwrap()
    let joint_nodes = results
    let matrices = if inverse_bind_matrices.is_null() {
      None
    } else {
      let accessor : @core.GeometryAttribute = inverse_bind_matrices.cast()
      Some(accessor.array().to_array())
    }

    // Note that bones (joint nodes) may or may not be in the
    // scene graph at this time.
    let bones = []
    let bone_inverses = []
    for i in 0..<joint_nodes.length() {
      let joint_node = joint_nodes[i]
      if gltf_truthy(joint_node) {
        bones.push((joint_node.cast() : @core.Object3D))
        let mat = @math.Matrix4::new()
        if matrices is Some(array) {
          mat.from_array(array, offset=i * 16) |> ignore
        }
        bone_inverses.push(mat)
      } else {
        gltf_console_warn2(
          "THREE.GLTFLoader: Joint \"%s\" could not be found.",
          gltf_at(joints, i),
        )
      }
    }
    @core.Skeleton::new(bones~, bone_inverses~)
  })
}

///|
fn GLTFParser::load_animation(
  self : GLTFParser,
  animation_index : Int32,
) -> AddonPromise {
  let json = self.json
  let parser = self
  let animation_def = gltf_at(json.get("animations"), animation_index)
  let animation_name = if gltf_truthy(animation_def.get("name")) {
    gltf_string(animation_def.get("name"))
  } else {
    "animation_" + animation_index.to_string()
  }
  let pending_nodes = []
  let pending_input_accessors = []
  let pending_output_accessors = []
  let pending_samplers = []
  let pending_targets = []
  let channels = animation_def.get("channels")
  for i in 0..<gltf_length(channels) {
    let channel = gltf_at(channels, i)
    let sampler = gltf_index_any(
      animation_def.get("samplers"),
      channel.get("sampler"),
    )
    let target = channel.get("target")
    let name = target.get("node")
    let parameters = animation_def.get("parameters")
    let input = if gltf_defined(parameters) {
      gltf_index_any(parameters, sampler.get("input"))
    } else {
      sampler.get("input")
    }
    let output = if gltf_defined(parameters) {
      gltf_index_any(parameters, sampler.get("output"))
    } else {
      sampler.get("output")
    }
    if target.get("node").is_undefined() {
      continue
    }
    pending_nodes.push(self.get_dependency("node", name.cast()).to_js())
    pending_input_accessors.push(
      self.get_dependency("accessor", input.cast()).to_js(),
    )
    pending_output_accessors.push(
      self.get_dependency("accessor", output.cast()).to_js(),
    )
    pending_samplers.push(sampler)
    pending_targets.push(target)
  }
  AddonPromise::all([
    AddonPromise::all_values(pending_nodes),
    AddonPromise::all_values(pending_input_accessors),
    AddonPromise::all_values(pending_output_accessors),
    AddonPromise::all_values(pending_samplers),
    AddonPromise::all_values(pending_targets),
  ]).then_(fn(dependencies : Array[Array[JsValue]]) {
    let nodes = dependencies[0]
    let input_accessors = dependencies[1]
    let output_accessors = dependencies[2]
    let samplers = dependencies[3]
    let targets = dependencies[4]
    let tracks = []
    for i in 0..<nodes.length() {
      let node = nodes[i]
      let input_accessor : @core.GeometryAttribute = input_accessors[i].cast()
      let output_accessor : @core.GeometryAttribute = output_accessors[i].cast()
      let sampler = samplers[i]
      let target = targets[i]
      if node.is_undefined() {
        continue
      }
      let node : @core.Object3D = node.cast()
      node.update_matrix()
      let created_tracks = parser.create_animation_tracks(
        node, input_accessor, output_accessor, sampler, target,
      )
      for track in created_tracks {
        tracks.push(track)
      }
    }
    let animation = @animation.AnimationClip::new(name=animation_name, tracks~)
    gltf_assign_extras(animation.user_data, animation_def)
    animation
  })
}

///|
/// Creates the node's mesh (shared meshes are cloned per node), or `None`.
pub fn GLTFParser::create_node_mesh(
  self : GLTFParser,
  node_index : Int32,
) -> AddonPromise? {
  let json = self.json
  let parser = self
  let node_def = gltf_at(json.get("nodes"), node_index)
  if node_def.get("mesh").is_undefined() {
    return None
  }
  let mesh_index : Int32 = node_def.get("mesh").cast()
  Some(
    parser
    .get_dependency("mesh", mesh_index)
    .then_(fn(mesh : @core.Object3D) {
      let node = parser.get_node_ref(parser.mesh_cache, mesh_index, mesh)

      // if weights are provided on the node, override weights on the mesh.
      let weights = node_def.get("weights")
      if gltf_defined(weights) {
        node.traverse(fn(o) {
          if !o.is_mesh() {
            return
          }
          let influences = match o.morph_targets() {
            (_, Some(influences)) => influences
            _ =>
              @utils.addon_throw_error(
                "TypeError: Cannot set properties of undefined",
              )
          }
          for i in 0..<gltf_length(weights) {
            gltf_set_influence(influences, i, gltf_at(weights, i).cast())
          }
        })
      }
      node
    }),
  )
}

///|
/// `influences[ i ] = value`, growing the array as a JS assignment does.
fn gltf_set_influence(
  influences : Array[Double],
  i : Int32,
  value : Double,
) -> Unit {
  while influences.length() <= i {
    influences.push(0)
  }
  influences[i] = value
}

///|
fn GLTFParser::load_node(self : GLTFParser, node_index : Int32) -> AddonPromise {
  let json = self.json
  let parser = self
  let node_def = gltf_at(json.get("nodes"), node_index)
  let node_pending = parser.load_node_shallow(node_index)
  let child_pending = []
  let children_def = gltf_or(
    node_def.get("children"),
    JsValue::of(([] : Array[Int32])),
  )
  for i in 0..<gltf_length(children_def) {
    child_pending.push(
      parser.get_dependency("node", gltf_at(children_def, i).cast()),
    )
  }
  let skeleton_pending = if node_def.get("skin").is_undefined() {
    AddonPromise::resolve(JsValue::null())
  } else {
    parser.get_dependency("skin", node_def.get("skin").cast())
  }
  AddonPromise::all([
    node_pending,
    AddonPromise::all(child_pending),
    skeleton_pending,
  ]).then_(fn(results : Array[JsValue]) {
    let node : @core.Object3D = results[0].cast()
    let children : Array[@core.Object3D] = results[1].cast()
    let skeleton = results[2]
    if !skeleton.is_null() {
      let skeleton : @core.Skeleton = skeleton.cast()
      // This full traverse should be fine because
      // child glTF nodes have not been added to this node yet.
      node.traverse(fn(mesh) {
        if !mesh.is_skinned_mesh() {
          return
        }
        mesh.bind(skeleton, bind_matrix=gltf_identity_matrix)
      })
    }
    for i in 0..<children.length() {
      node.add(children[i]) |> ignore
    }

    // Reconstruct pivot from container pattern created by GLTFExporter
    // The container has position+pivot, rotation, scale; child has -pivot offset and mesh
    let pivot = node.user_data.get("pivot")
    if gltf_defined(pivot) && children.length() > 0 {
      let pivot_child = children[0]

      // Set pivot on container and adjust transforms
      node.pivot = Some(@math.Vector3::new(0, 0, 0).from_array(pivot.cast()))

      // Adjust container position: stored as position + pivot, so subtract pivot
      node.position.x -= gltf_at(pivot, 0).cast()
      node.position.y -= gltf_at(pivot, 1).cast()
      node.position.z -= gltf_at(pivot, 2).cast()

      // Remove the child's -pivot offset since pivot now handles it
      pivot_child.position.set(0, 0, 0) |> ignore
      gltf_delete(node.user_data, "pivot")
    }
    node
  })
}

///|
/// `_loadNodeShallow`: a single node without its skin and children.
fn GLTFParser::load_node_shallow(
  self : GLTFParser,
  node_index : Int32,
) -> AddonPromise {
  let json = self.json
  let extensions = self.extensions
  let parser = self

  // This method is called from .loadNode() and .loadSkin().
  // Cache a node to avoid duplication.
  if self.node_cache.get(node_index) is Some(cached) {
    return cached
  }
  let node_def = gltf_at(json.get("nodes"), node_index)

  // reserve node's name before its dependencies, so the root has the intended name.
  let node_name = if gltf_truthy(node_def.get("name")) {
    parser.create_unique_name(node_def.get("name"))
  } else {
    ""
  }
  let pending = []
  let mesh_promise = parser.invoke_one(ext => ext.create_node_mesh(node_index))
  if mesh_promise is Some(p) {
    pending.push(p)
  }
  if gltf_defined(node_def.get("camera")) {
    let camera_index : Int32 = node_def.get("camera").cast()
    pending.push(
      parser
      .get_dependency("camera", camera_index)
      .then_(fn(camera : @core.Object3D) {
        parser.get_node_ref(parser.camera_cache, camera_index, camera)
      }),
    )
  }
  for
    promise in parser.invoke_all(ext => ext.create_node_attachment(node_index)) {
    pending.push(promise)
  }
  let promise = AddonPromise::all(pending).then_(fn(
    objects : Array[@core.Object3D],
  ) {
    // .isBone isn't in glTF spec. See ._markDefs
    let node = if gltf_is_true(node_def.get("isBone")) {
      @core.Bone::new()
    } else if objects.length() > 1 {
      @core.Group::new()
    } else if objects.length() == 1 {
      objects[0]
    } else {
      @core.Object3D::new()
    }
    if objects.length() == 0 || !physical_equal(node, objects[0]) {
      for i in 0..<objects.length() {
        node.add(objects[i]) |> ignore
      }
    }
    if gltf_truthy(node_def.get("name")) {
      node.user_data.set("name", node_def.get("name"))
      node.name = node_name
    }
    gltf_assign_extras(node.user_data, node_def)
    if gltf_truthy(node_def.get("extensions")) {
      gltf_add_unknown_extensions_to_user_data(
        extensions,
        node.user_data,
        node_def,
      )
    }
    if gltf_defined(node_def.get("matrix")) {
      let matrix = @math.Matrix4::new()
      matrix.from_array(node_def.get("matrix").cast()) |> ignore
      node.apply_matrix4(matrix)
    } else {
      if gltf_defined(node_def.get("translation")) {
        node.position.from_array(node_def.get("translation").cast()) |> ignore
      }
      if gltf_defined(node_def.get("rotation")) {
        node.quaternion.from_array(node_def.get("rotation").cast()) |> ignore
      }
      if gltf_defined(node_def.get("scale")) {
        node.scale.from_array(node_def.get("scale").cast()) |> ignore
      }
    }
    if !parser.associations.has(Object3D(node)) {
      parser.associations.set(Object3D(node), Some(GLTFReference::new()))
    } else if gltf_defined(node_def.get("mesh")) &&
      parser.mesh_cache.refs.get(node_def.get("mesh").cast()).unwrap_or(0) > 1 {
      let mapping = parser.associations.get_object(node)
      parser.associations.set(Object3D(node), mapping.map(m => m.copy()))
    }
    match parser.associations.get_object(node) {
      Some(mapping) => mapping.nodes = Some(node_index)
      None =>
        @utils.addon_throw_error(
          "TypeError: Cannot set properties of undefined (setting 'nodes')",
        )
    }
    node
  })
  self.node_cache[node_index] = promise
  promise
}

///|
fn GLTFParser::load_scene(
  self : GLTFParser,
  scene_index : Int32,
) -> AddonPromise {
  let extensions = self.extensions
  let scene_def = gltf_at(self.json.get("scenes"), scene_index)
  let parser = self

  // Loader returns Group, not Scene.
  // See: https://github.com/mrdoob/three.js/issues/18342#issuecomment-578981172
  let scene = @core.Group::new()
  if gltf_truthy(scene_def.get("name")) {
    scene.name = parser.create_unique_name(scene_def.get("name"))
  }
  gltf_assign_extras(scene.user_data, scene_def)
  if gltf_truthy(scene_def.get("extensions")) {
    gltf_add_unknown_extensions_to_user_data(
      extensions,
      scene.user_data,
      scene_def,
    )
  }
  let node_ids = gltf_or(
    scene_def.get("nodes"),
    JsValue::of(([] : Array[Int32])),
  )
  let pending = []
  for i in 0..<gltf_length(node_ids) {
    pending.push(parser.get_dependency("node", gltf_at(node_ids, i).cast()))
  }
  AddonPromise::all(pending).then_(fn(nodes : Array[@core.Object3D]) {
    for node in nodes {
      // If the node already has a parent, it means it's being reused across multiple scenes.
      // Clone it to avoid the second scene's add() removing it from the first scene.
      // See: https://github.com/mrdoob/three.js/issues/27993
      if node.parent is Some(_) {
        scene.add(@utils.SkeletonUtils::clone(node)) |> ignore
      } else {
        scene.add(node) |> ignore
      }
    }

    // Removes dangling associations, associations that reference a node that
    // didn't make it into the scene.
    fn reduce_associations(node : @core.Object3D) -> GLTFAssociations {
      let reduced_associations = GLTFAssociations::new()
      for entry in parser.associations.entries() {
        match entry {
          (Material(_) as key, value) | (Texture(_) as key, value) =>
            reduced_associations.set(key, value)
          _ => ()
        }
      }
      node.traverse(fn(node) {
        let mappings = parser.associations.get_object(node)
        if mappings is Some(_) {
          reduced_associations.set(Object3D(node), mappings)
        }
      })
      reduced_associations
    }

    parser.associations = reduce_associations(scene)
    scene
  })
}

///|
fn GLTFParser::create_animation_tracks(
  self : GLTFParser,
  node : @core.Object3D,
  input_accessor : @core.GeometryAttribute,
  output_accessor : @core.GeometryAttribute,
  sampler : JsValue,
  target : JsValue,
) -> Array[@animation.KeyframeTrack] {
  let tracks = []
  let target_name = if node.name != "" { node.name } else { node.uuid }
  let target_names = []
  fn collect_morph_targets(object : @core.Object3D) -> Unit {
    if object.morph_targets().1 is Some(_) {
      target_names.push(
        if object.name != "" {
          object.name
        } else {
          object.uuid
        },
      )
    }
  }

  let path = gltf_path_property(target.get("path"))
  if path == Some("morphTargetInfluences") {
    collect_morph_targets(node)

    // for multi-primitive meshes, the node is a Group containing the sub-meshes
    if node.is_group() {
      node.children.each(collect_morph_targets)
    }
  } else {
    target_names.push(target_name)
  }
  let interpolation = if gltf_defined(sampler.get("interpolation")) {
    gltf_interpolation(sampler.get("interpolation"))
  } else {
    Some(@core.InterpolateLinear)
  }
  let output_array = self.get_array_from_accessor(output_accessor)
  for j in 0..<target_names.length() {
    let name = target_names[j] +
      "." +
      (match path {
        Some(p) => p
        None => "undefined"
      })
    let times = input_accessor.array()
    let track = match path {
      Some("morphTargetInfluences") =>
        @animation.NumberKeyframeTrack::new(
          name,
          times,
          output_array,
          interpolation?,
        )
      Some("quaternion") =>
        @animation.QuaternionKeyframeTrack::new(
          name,
          times,
          output_array,
          interpolation?,
        )
      Some("position") | Some("scale") =>
        @animation.VectorKeyframeTrack::new(
          name,
          times,
          output_array,
          interpolation?,
        )
      _ =>
        if output_accessor.item_size() == 1 {
          @animation.NumberKeyframeTrack::new(
            name,
            times,
            output_array,
            interpolation?,
          )
        } else {
          @animation.VectorKeyframeTrack::new(
            name,
            times,
            output_array,
            interpolation?,
          )
        }
    }

    // Override interpolation with custom factory method.
    if gltf_equals_string(sampler.get("interpolation"), "CUBICSPLINE") {
      self.create_cubic_spline_track_interpolant(track)
    }
    tracks.push(track)
  }
  tracks
}

///|
fn GLTFParser::get_array_from_accessor(
  _self : GLTFParser,
  accessor : @core.GeometryAttribute,
) -> @core.TypedArray {
  let output_array = accessor.array()
  if accessor.normalized() {
    let scale = gltf_normalized_component_scale(output_array.type_name())
    let scaled = @core.TypedArray::float32(output_array.length())
    for j in 0..<output_array.length() {
      scaled[j] = output_array[j] * scale
    }
    return scaled
  }
  output_array
}

///|
fn GLTFParser::create_cubic_spline_track_interpolant(
  _self : GLTFParser,
  track : @animation.KeyframeTrack,
) -> Unit {
  // Mark as CUBICSPLINE. `track.getInterpolation()` doesn't support custom interpolants.
  track.create_interpolant_factory = Some(
    @animation.InterpolantFactory::new(
      gltf_interpolant_factory_method_gltf_cubic_spline,
      is_interpolant_factory_method_gltf_cubic_spline=true,
    ),
  )
}

// --- module functions ------------------------------------------------------------

///|
/// Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#default-material
fn gltf_create_default_material(cache : GLTFRegistry) -> @core.Material {
  match cache.default_material {
    Some(m) => m
    None => {
      let material = @core.MeshStandardMaterial::new()
      material.set_values(values={
        "color": Number(0xFFFFFF),
        "emissive": Number(0x000000),
        "metalness": Number(1),
        "roughness": Number(1),
        "transparent": Bool(false),
        "depthTest": Bool(true),
        "side": Number(@core.FrontSide.to_double()),
      })
      cache.default_material = Some(material)
      material
    }
  }
}

///|
/// Add unknown glTF extensions to an object's userData.
fn gltf_add_unknown_extensions_to_user_data(
  known_extensions : Map[String, GLTFExtension],
  user_data : JsValue,
  object_def : JsValue,
) -> Unit {
  let extensions = object_def.get("extensions")
  for name in gltf_keys(extensions) {
    if known_extensions.get(name) is None {
      gltf_add_user_extension(user_data, name, extensions.get(name))
    }
  }
}

///|
/// Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#morph-targets
fn gltf_add_morph_targets(
  geometry : @core.BufferGeometry,
  targets : JsValue,
  parser : GLTFParser,
) -> AddonPromise {
  let mut has_morph_position = false
  let mut has_morph_normal = false
  let mut has_morph_color = false
  for i in 0..<gltf_length(targets) {
    let target = gltf_at(targets, i)
    if gltf_defined(target.get("POSITION")) {
      has_morph_position = true
    }
    if gltf_defined(target.get("NORMAL")) {
      has_morph_normal = true
    }
    if gltf_defined(target.get("COLOR_0")) {
      has_morph_color = true
    }
    if has_morph_position && has_morph_normal && has_morph_color {
      break
    }
  }
  if !has_morph_position && !has_morph_normal && !has_morph_color {
    return AddonPromise::resolve(geometry)
  }
  let pending_position_accessors = []
  let pending_normal_accessors = []
  let pending_color_accessors = []
  fn existing(name : String) -> JsValue {
    match geometry.attributes.get(name) {
      Some(a) => JsValue::of(a)
      None => JsValue::undefined()
    }
  }

  for i in 0..<gltf_length(targets) {
    let target = gltf_at(targets, i)
    if has_morph_position {
      let pending_accessor = if gltf_defined(target.get("POSITION")) {
        parser.get_dependency("accessor", target.get("POSITION").cast()).to_js()
      } else {
        existing("position")
      }
      pending_position_accessors.push(pending_accessor)
    }
    if has_morph_normal {
      let pending_accessor = if gltf_defined(target.get("NORMAL")) {
        parser.get_dependency("accessor", target.get("NORMAL").cast()).to_js()
      } else {
        existing("normal")
      }
      pending_normal_accessors.push(pending_accessor)
    }
    if has_morph_color {
      let pending_accessor = if gltf_defined(target.get("COLOR_0")) {
        parser.get_dependency("accessor", target.get("COLOR_0").cast()).to_js()
      } else {
        existing("color")
      }
      pending_color_accessors.push(pending_accessor)
    }
  }
  AddonPromise::all([
    AddonPromise::all_values(pending_position_accessors),
    AddonPromise::all_values(pending_normal_accessors),
    AddonPromise::all_values(pending_color_accessors),
  ]).then_(fn(accessors : Array[Array[@core.GeometryAttribute]]) {
    let morph_positions = accessors[0]
    let morph_normals = accessors[1]
    let morph_colors = accessors[2]
    if has_morph_position {
      geometry.morph_attributes["position"] = morph_positions
    }
    if has_morph_normal {
      geometry.morph_attributes["normal"] = morph_normals
    }
    if has_morph_color {
      geometry.morph_attributes["color"] = morph_colors
    }
    geometry.morph_targets_relative = true
    geometry
  })
}

///|
/// `updateMorphTargets( mesh, meshDef )`.
fn gltf_update_morph_targets(mesh : @core.Object3D, mesh_def : JsValue) -> Unit {
  mesh.update_morph_targets()
  let influences = match mesh.morph_targets() {
    (_, Some(influences)) => influences
    _ => []
  }
  let weights = mesh_def.get("weights")
  if gltf_defined(weights) {
    for i in 0..<gltf_length(weights) {
      gltf_set_influence(influences, i, gltf_at(weights, i).cast())
    }
  }

  // .extras has user-defined data, so check that .extras.targetNames is an array.
  let extras = mesh_def.get("extras")
  if gltf_truthy(extras) && gltf_is_array(extras.get("targetNames")) {
    let target_names = extras.get("targetNames")
    if influences.length() == gltf_length(target_names) {
      let dictionary : Map[String, Int32] = Map([])
      for i in 0..<gltf_length(target_names) {
        dictionary[gltf_string(gltf_at(target_names, i))] = i
      }
      gltf_set_morph_target_dictionary(mesh, dictionary)
    } else {
      gltf_console_warn(
        "THREE.GLTFLoader: Invalid extras.targetNames length. Ignoring names.",
      )
    }
  }
}

///|
/// `mesh.morphTargetDictionary = dictionary`.
fn gltf_set_morph_target_dictionary(
  object : @core.Object3D,
  dictionary : Map[String, Int32],
) -> Unit {
  match object.kind {
    Mesh(m) => m.morph_target_dictionary = Some(dictionary)
    Line(m) => m.morph_target_dictionary = Some(dictionary)
    Points(m) => m.morph_target_dictionary = Some(dictionary)
    _ => ()
  }
}

///|
/// `createPrimitiveKey( primitiveDef )`.
fn gltf_create_primitive_key(primitive_def : JsValue) -> String {
  let extensions = primitive_def.get("extensions")
  let draco_extension = if gltf_truthy(extensions) {
    extensions.get(gltf_KHR_DRACO_MESH_COMPRESSION)
  } else {
    extensions
  }
  let mut geometry_key = if gltf_truthy(draco_extension) {
    "draco:" +
    gltf_string(draco_extension.get("bufferView")) +
    ":" +
    gltf_string(draco_extension.get("indices")) +
    ":" +
    gltf_create_attributes_key(draco_extension.get("attributes"))
  } else {
    gltf_string(primitive_def.get("indices")) +
    ":" +
    gltf_create_attributes_key(primitive_def.get("attributes")) +
    ":" +
    gltf_string(primitive_def.get("mode"))
  }
  let targets = primitive_def.get("targets")
  if gltf_defined(targets) {
    for i in 0..<gltf_length(targets) {
      geometry_key += ":" + gltf_create_attributes_key(gltf_at(targets, i))
    }
  }
  geometry_key
}

///|
/// `createAttributesKey( attributes )`.
fn gltf_create_attributes_key(attributes : JsValue) -> String {
  let mut attributes_key = ""
  let keys = gltf_sorted_keys(attributes)
  for key in keys {
    attributes_key += key + ":" + gltf_string(attributes.get(key)) + ";"
  }
  attributes_key
}

///|
/// `computeBounds( geometry, primitiveDef, parser )`.
fn gltf_compute_bounds(
  geometry : @core.BufferGeometry,
  primitive_def : JsValue,
  parser : GLTFParser,
) -> Unit {
  let attributes = primitive_def.get("attributes")
  let box_ = @math.Box3::new()
  if gltf_defined(attributes.get("POSITION")) {
    let accessor = gltf_at(
      parser.json.get("accessors"),
      attributes.get("POSITION").cast(),
    )
    let min = accessor.get("min")
    let max = accessor.get("max")

    // glTF requires 'min' and 'max', but VRM (which extends glTF) currently ignores that requirement.
    if gltf_defined(min) && gltf_defined(max) {
      box_.set(
        @math.Vector3::new(
          gltf_at(min, 0).cast(),
          gltf_at(min, 1).cast(),
          gltf_at(min, 2).cast(),
        ),
        @math.Vector3::new(
          gltf_at(max, 0).cast(),
          gltf_at(max, 1).cast(),
          gltf_at(max, 2).cast(),
        ),
      )
      |> ignore
      if gltf_truthy(accessor.get("normalized")) {
        let box_scale = gltf_normalized_component_scale(
          gltf_component_type(accessor.get("componentType")),
        )
        box_.min.multiply_scalar(box_scale) |> ignore
        box_.max.multiply_scalar(box_scale) |> ignore
      }
    } else {
      gltf_console_warn(
        "THREE.GLTFLoader: Missing min/max properties for accessor POSITION.",
      )
      return
    }
  } else {
    return
  }
  let targets = primitive_def.get("targets")
  if gltf_defined(targets) {
    let max_displacement = @math.Vector3::new(0, 0, 0)
    let vector = @math.Vector3::new(0, 0, 0)
    for i in 0..<gltf_length(targets) {
      let target = gltf_at(targets, i)
      if gltf_defined(target.get("POSITION")) {
        let accessor = gltf_at(
          parser.json.get("accessors"),
          target.get("POSITION").cast(),
        )
        let min = accessor.get("min")
        let max = accessor.get("max")

        // glTF requires 'min' and 'max', but VRM (which extends glTF) currently ignores that requirement.
        if gltf_defined(min) && gltf_defined(max) {
          // we need to get max of absolute components because target weight is [-1,1]
          vector.set_x(
            gltf_max(
              gltf_abs(gltf_at(min, 0).cast()),
              gltf_abs(gltf_at(max, 0).cast()),
            ),
          )
          |> ignore
          vector.set_y(
            gltf_max(
              gltf_abs(gltf_at(min, 1).cast()),
              gltf_abs(gltf_at(max, 1).cast()),
            ),
          )
          |> ignore
          vector.set_z(
            gltf_max(
              gltf_abs(gltf_at(min, 2).cast()),
              gltf_abs(gltf_at(max, 2).cast()),
            ),
          )
          |> ignore
          if gltf_truthy(accessor.get("normalized")) {
            let box_scale = gltf_normalized_component_scale(
              gltf_component_type(accessor.get("componentType")),
            )
            vector.multiply_scalar(box_scale) |> ignore
          }

          // Note: this assumes that the sum of all weights is at most 1. This isn't quite correct - it's more conservative
          // to assume that each target can have a max weight of 1. However, for some use cases - notably, when morph targets
          // are used to implement key-frame animations and as such only two are active at a time - this results in very large
          // boxes. So for now we make a box that's sometimes a touch too small but is hopefully mostly of reasonable size.
          max_displacement.max(vector) |> ignore
        } else {
          gltf_console_warn(
            "THREE.GLTFLoader: Missing min/max properties for accessor POSITION.",
          )
        }
      }
    }

    // As per comment above this box isn't conservative, but has a reasonable size for a very large number of morph targets.
    box_.expand_by_vector(max_displacement) |> ignore
  }
  geometry.bounding_box = Some(box_)
  let sphere = @math.Sphere::new()
  box_.get_center(sphere.center) |> ignore
  sphere.radius = box_.min.distance_to(box_.max) / 2.0
  geometry.bounding_sphere = Some(sphere)
}

///|
/// `addPrimitiveAttributes( geometry, primitiveDef, parser )`.
fn gltf_add_primitive_attributes(
  geometry : @core.BufferGeometry,
  primitive_def : JsValue,
  parser : GLTFParser,
) -> AddonPromise {
  let attributes = primitive_def.get("attributes")
  let pending = []
  fn assign_attribute_accessor(
    accessor_index : Int32,
    attribute_name : String,
  ) -> AddonPromise {
    parser
    .get_dependency("accessor", accessor_index)
    .then_(fn(accessor : @core.GeometryAttribute) {
      geometry.set_attribute(attribute_name, accessor) |> ignore
    })
  }

  for gltf_attribute_name in gltf_keys(attributes) {
    let three_attribute_name = gltf_three_attribute_name(gltf_attribute_name)

    // Skip attributes already provided by e.g. Draco extension.
    if geometry.attributes.get(three_attribute_name) is Some(_) {
      continue
    }
    pending.push(
      assign_attribute_accessor(
        attributes.get(gltf_attribute_name).cast(),
        three_attribute_name,
      ),
    )
  }
  if gltf_defined(primitive_def.get("indices")) && geometry.index is None {
    let accessor = parser
      .get_dependency("accessor", primitive_def.get("indices").cast())
      .then_(fn(accessor : @core.GeometryAttribute) {
        geometry.set_index(Some(accessor)) |> ignore
      })
    pending.push(accessor)
  }
  if @math.color_management.working_color_space != @core.LinearSRGBColorSpace &&
    gltf_in(attributes, "COLOR_0") {
    gltf_console_warn(
      "THREE.GLTFLoader: Converting vertex colors from \"srgb-linear\" to \"" +
      @math.color_management.working_color_space +
      "\" not supported.",
    )
  }
  gltf_assign_extras(geometry.user_data, primitive_def)
  gltf_compute_bounds(geometry, primitive_def, parser)
  AddonPromise::all(pending).then_(fn(_ : JsValue) {
    if gltf_defined(primitive_def.get("targets")) {
      gltf_add_morph_targets(geometry, primitive_def.get("targets"), parser).to_js()
    } else {
      JsValue::of(geometry)
    }
  })
}
