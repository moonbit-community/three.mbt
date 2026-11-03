// Upstream examples/jsm/loaders/GLTFLoader.js: the loader, the plugin interface and
// the result. The parser is in gltf_parser.mbt, the built-in extensions in
// gltf_extensions.mbt. Upstream's promise chains are kept as `AddonPromise` chains
// (same `.then`s and `Promise.all`s), so dependencies resolve in upstream's order.

///|
/// A glTF material class: upstream's `getMaterialType` return value.
pub(all) enum GLTFMaterialType {
  MeshBasicMaterial
  MeshStandardMaterial
  MeshPhysicalMaterial
  /// A plugin's own class: its name and constructor.
  Other(String, () -> @core.Material)
}

///|
/// `new materialType()`.
pub fn GLTFMaterialType::create(self : GLTFMaterialType) -> @core.Material {
  match self {
    MeshBasicMaterial => @core.MeshBasicMaterial::new()
    MeshStandardMaterial => @core.MeshStandardMaterial::new()
    MeshPhysicalMaterial => @core.MeshPhysicalMaterial::new()
    Other(_, f) => f()
  }
}

///|
/// `materialType === other`.
pub fn GLTFMaterialType::same(
  self : GLTFMaterialType,
  other : GLTFMaterialType,
) -> Bool {
  match (self, other) {
    (MeshBasicMaterial, MeshBasicMaterial) => true
    (MeshStandardMaterial, MeshStandardMaterial) => true
    (MeshPhysicalMaterial, MeshPhysicalMaterial) => true
    (Other(_, f), Other(_, g)) => physical_equal(f, g)
    _ => false
  }
}

///|
/// The `materialParams` object passed to `new materialType( materialParams )`.
pub type GLTFMaterialParams = Map[String, @core.MaterialValue]

///|
/// A glTF plugin, as `GLTFLoader.register` callbacks return. Every hook is optional;
/// `None` is upstream's falsy result (a missing method or `null`).
pub(open) trait GLTFPlugin {
  /// The extension name; plugins are keyed by it.
  fn name(Self) -> String
  /// `_markDefs()`.
  fn mark_defs(Self) -> Unit = _
  /// `beforeRoot()`.
  fn before_root(Self) -> @utils.AddonPromise? = _
  /// `afterRoot( result )`.
  fn after_root(Self, GLTFResult) -> @utils.AddonPromise? = _
  /// `loadNode( index )`, resolving to an `Object3D`.
  fn load_node(Self, Int32) -> @utils.AddonPromise? = _
  /// `loadMesh( index )`, resolving to an `Object3D`.
  fn load_mesh(Self, Int32) -> @utils.AddonPromise? = _
  /// `loadBufferView( index )`, resolving to an `ArrayBuffer`.
  fn load_buffer_view(Self, Int32) -> @utils.AddonPromise? = _
  /// `loadMaterial( index )`, resolving to a `Material`.
  fn load_material(Self, Int32) -> @utils.AddonPromise? = _
  /// `loadTexture( index )`, resolving to a `Texture` or `null`.
  fn load_texture(Self, Int32) -> @utils.AddonPromise? = _
  /// `loadAnimation( index )`, resolving to an `AnimationClip`.
  fn load_animation(Self, Int32) -> @utils.AddonPromise? = _
  /// `getDependency( type, index )` for types the parser does not know.
  fn get_dependency(Self, String, Int32) -> @utils.AddonPromise? = _
  /// `getMaterialType( materialIndex )`.
  fn get_material_type(Self, Int32) -> GLTFMaterialType? = _
  /// `extendMaterialParams( materialIndex, materialParams )`.
  fn extend_material_params(Self, Int32, GLTFMaterialParams) -> @utils.AddonPromise? = _
  /// `createNodeMesh( nodeIndex )`, resolving to an `Object3D`.
  fn create_node_mesh(Self, Int32) -> @utils.AddonPromise? = _
  /// `createNodeAttachment( nodeIndex )`, resolving to an `Object3D`.
  fn create_node_attachment(Self, Int32) -> @utils.AddonPromise? = _
}

///|
impl GLTFPlugin with fn mark_defs(_) {

}

///|
impl GLTFPlugin with fn before_root(_) {
  None
}

///|
impl GLTFPlugin with fn after_root(_, _) {
  None
}

///|
impl GLTFPlugin with fn load_node(_, _) {
  None
}

///|
impl GLTFPlugin with fn load_mesh(_, _) {
  None
}

///|
impl GLTFPlugin with fn load_buffer_view(_, _) {
  None
}

///|
impl GLTFPlugin with fn load_material(_, _) {
  None
}

///|
impl GLTFPlugin with fn load_texture(_, _) {
  None
}

///|
impl GLTFPlugin with fn load_animation(_, _) {
  None
}

///|
impl GLTFPlugin with fn get_dependency(_, _, _) {
  None
}

///|
impl GLTFPlugin with fn get_material_type(_, _) {
  None
}

///|
impl GLTFPlugin with fn extend_material_params(_, _, _) {
  None
}

///|
impl GLTFPlugin with fn create_node_mesh(_, _) {
  None
}

///|
impl GLTFPlugin with fn create_node_attachment(_, _) {
  None
}

///|
/// What `GLTFLoader.load` passes to `onLoad`.
pub struct GLTFResult {
  /// `dependencies[ 0 ][ json.scene || 0 ]`; `None` when the asset has no scenes.
  scene : @core.Object3D?
  scenes : Array[@core.Object3D]
  animations : Array[@animation.AnimationClip]
  /// `None` where upstream's `loadCamera` returned `undefined`.
  cameras : Array[@core.Object3D?]
  asset : @core.JsValue
  parser : GLTFParser
  user_data : @core.JsValue
}

///|
/// Loads glTF 2.0 assets (`.gltf` and `.glb`).
pub struct GLTFLoader {
  base : @loaders.Loader
  mut draco_loader : DRACOLoader?
  mut ktx2_loader : KTX2Loader?
  mut meshopt_decoder : @core.JsValue?
  plugin_callbacks : Array[(GLTFParser) -> &GLTFPlugin]
}

///|
pub impl @loaders.LoaderLike for GLTFLoader with fn loader(self) {
  self.base
}

///|
pub impl @loaders.LoaderSettings for GLTFLoader

///|
pub extend GLTFLoader with @loaders.LoaderSettings::{
  set_cross_origin,
  set_with_credentials,
  set_path,
  set_resource_path,
  set_request_header,
  set_priority,
  set_cache,
}

///|
pub extend GLTFLoader with @loaders.LoaderLike::{loader}

///|
pub fn GLTFLoader::new(manager? : @loaders.LoadingManager) -> GLTFLoader {
  let loader = {
    base: @loaders.Loader::new(manager?),
    draco_loader: None,
    ktx2_loader: None,
    meshopt_decoder: None,
    plugin_callbacks: [],
  }
  let callbacks : Array[(GLTFParser) -> &GLTFPlugin] = [
    parser => GLTFMaterialsClearcoatExtension::new(parser),
    parser => GLTFMaterialsDiffuseRoughnessExtension::new(parser),
    parser => GLTFMaterialsDispersionExtension::new(parser),
    parser => GLTFTextureBasisUExtension::new(parser),
    parser => GLTFTextureWebPExtension::new(parser),
    parser => GLTFTextureAVIFExtension::new(parser),
    parser => GLTFMaterialsSheenExtension::new(parser),
    parser => GLTFMaterialsTransmissionExtension::new(parser),
    parser => GLTFMaterialsVolumeExtension::new(parser),
    parser => GLTFMaterialsIorExtension::new(parser),
    parser => GLTFMaterialsEmissiveStrengthExtension::new(parser),
    parser => GLTFMaterialsSpecularExtension::new(parser),
    parser => GLTFMaterialsIridescenceExtension::new(parser),
    parser => GLTFMaterialsAnisotropyExtension::new(parser),
    parser => GLTFMaterialsBumpExtension::new(parser),
    parser => GLTFLightsExtension::new(parser),
    parser => GLTFMeshoptCompression::new(parser, gltf_EXT_MESHOPT_COMPRESSION),
    parser => GLTFMeshoptCompression::new(parser, gltf_KHR_MESHOPT_COMPRESSION),
    parser => GLTFMeshGpuInstancing::new(parser),
  ]
  for callback in callbacks {
    loader.register(callback) |> ignore
  }
  loader
}

///|
/// Loads `url` and passes the parsed asset to `on_load`.
pub fn GLTFLoader::load(
  self : GLTFLoader,
  url : String,
  on_load : (GLTFResult) -> Unit,
  on_progress? : (@loaders.ProgressEvent) -> Unit,
  on_error? : (@core.JsValue) -> Unit,
) -> Unit {
  let base = self.base
  let resource_path = if base.resource_path != "" {
    base.resource_path
  } else if base.path != "" {
    // If a base path is set, resources will be relative paths from that plus the relative path of the gltf file
    let relative_url = @loaders.LoaderUtils::extract_url_base(url)
    @loaders.LoaderUtils::resolve_url(relative_url, base.path)
  } else {
    @loaders.LoaderUtils::extract_url_base(url)
  }

  // Tells the LoadingManager to track an extra item, which resolves after
  // the model is fully loaded.
  base.manager.item_start(url)
  let on_error_ = fn(e : @core.JsValue) {
    match on_error {
      Some(f) => f(e)
      None => gltf_console_error(e)
    }
    base.manager.item_error(url)
    base.manager.item_end(url)
  }
  let loader = @loaders.FileLoader::new(manager=base.manager)
  loader.set_priority(base.priority) |> ignore
  loader.set_cache(base.cache) |> ignore
  loader.set_path(base.path) |> ignore
  loader.set_response_type("arraybuffer") |> ignore
  loader.set_request_header(base.request_header) |> ignore
  loader.set_with_credentials(base.with_credentials) |> ignore
  loader.load(
    url,
    on_load=fn(data) {
      let error = @utils.addon_try(fn() {
        self.parse(
          data,
          resource_path,
          fn(gltf) {
            on_load(gltf)
            base.manager.item_end(url)
          },
          on_error=on_error_,
        )
      })
      if error is Some(e) {
        on_error_(e)
      }
    },
    on_progress?,
    on_error=on_error_,
  )
}

///|
/// Sets the Draco loader used for `KHR_draco_mesh_compression`.
pub fn GLTFLoader::set_draco_loader(
  self : GLTFLoader,
  draco_loader : DRACOLoader,
) -> GLTFLoader {
  self.draco_loader = Some(draco_loader)
  self
}

///|
/// Sets the KTX2 loader used for `KHR_texture_basisu`.
pub fn GLTFLoader::set_ktx2_loader(
  self : GLTFLoader,
  ktx2_loader : KTX2Loader,
) -> GLTFLoader {
  self.ktx2_loader = Some(ktx2_loader)
  self
}

///|
/// Sets the meshopt decoder (upstream's `MeshoptDecoder` object, a JS value).
pub fn GLTFLoader::set_meshopt_decoder(
  self : GLTFLoader,
  meshopt_decoder : @core.JsValue,
) -> GLTFLoader {
  self.meshopt_decoder = Some(meshopt_decoder)
  self
}

///|
/// Registers a plugin callback (once; compared by identity).
pub fn GLTFLoader::register(
  self : GLTFLoader,
  callback : (GLTFParser) -> &GLTFPlugin,
) -> GLTFLoader {
  if self.plugin_callbacks.search_by(f => physical_equal(f, callback)) is None {
    self.plugin_callbacks.push(callback)
  }
  self
}

///|
/// Unregisters a plugin callback.
pub fn GLTFLoader::unregister(
  self : GLTFLoader,
  callback : (GLTFParser) -> &GLTFPlugin,
) -> GLTFLoader {
  if self.plugin_callbacks.search_by(f => physical_equal(f, callback))
    is Some(i) {
    self.plugin_callbacks.remove(i) |> ignore
  }
  self
}

///|
/// Parses glTF `data`: a JSON string, an `ArrayBuffer` (`.glb` or JSON text), or a
/// parsed JSON object.
pub fn GLTFLoader::parse(
  self : GLTFLoader,
  data : @core.JsValue,
  path : String,
  on_load : (GLTFResult) -> Unit,
  on_error? : (@core.JsValue) -> Unit,
) -> Unit {
  let extensions : Map[String, GLTFExtension] = {}
  let plugins : Map[String, &GLTFPlugin] = {}
  let json = if gltf_is_string(data) {
    gltf_json_parse(data)
  } else if gltf_is_array_buffer(data) {
    let magic = gltf_decode_text(data, 0, 4)
    if magic == gltf_BINARY_EXTENSION_HEADER_MAGIC {
      let mut binary = None
      let error = @utils.addon_try(fn() {
        binary = Some(GLTFBinaryExtension::new(data))
      })
      match (error, binary) {
        (None, Some(binary)) => {
          extensions[gltf_KHR_BINARY_GLTF] = Binary(binary)
          gltf_json_parse(@core.JsValue::of(binary.content.unwrap()))
        }
        (Some(error), _) => {
          if on_error is Some(f) {
            f(error)
          }
          return
        }
        _ => return
      }
    } else {
      gltf_json_parse(gltf_js_string(gltf_decode_all(data)))
    }
  } else {
    data
  }
  if gltf_unsupported_asset(json) {
    if on_error is Some(f) {
      f(
        @utils.addon_new_error(
          "THREE.GLTFLoader: Unsupported asset. glTF versions >=2.0 are supported.",
        ),
      )
    }
    return
  }
  let base = self.base
  let parser = GLTFParser::new(json, {
    path: if path != "" {
      path
    } else {
      base.resource_path
    },
    cross_origin: base.cross_origin,
    priority: base.priority,
    cache: base.cache,
    with_credentials: base.with_credentials,
    request_header: base.request_header,
    manager: base.manager,
    ktx2_loader: self.ktx2_loader,
    meshopt_decoder: self.meshopt_decoder,
  })
  parser.file_loader.set_request_header(base.request_header) |> ignore
  for callback in self.plugin_callbacks {
    let plugin = callback(parser)
    if plugin.name() == "" {
      gltf_console_error(
        gltf_js_string("THREE.GLTFLoader: Invalid plugin found: missing name"),
      )
    }
    plugins[plugin.name()] = plugin

    // Workaround to avoid determining as unknown extension
    // in addUnknownExtensionsToUserData().
    extensions[plugin.name()] = Plugin
  }
  let extensions_used = json.get("extensionsUsed")
  if gltf_truthy(extensions_used) {
    for i in 0..<gltf_length(extensions_used) {
      let extension_name : String = gltf_at(extensions_used, i).cast()
      let extensions_required = gltf_or(
        json.get("extensionsRequired"),
        @core.JsValue::of(([] : Array[String])),
      )
      match extension_name {
        "KHR_materials_unlit" =>
          extensions[extension_name] = MaterialsUnlit(
            GLTFMaterialsUnlitExtension::new(),
          )
        "KHR_draco_mesh_compression" =>
          extensions[extension_name] = DracoMeshCompression(
            GLTFDracoMeshCompressionExtension::new(json, self.draco_loader),
          )
        "KHR_texture_transform" =>
          extensions[extension_name] = TextureTransform(
            GLTFTextureTransformExtension::new(),
          )
        "KHR_mesh_quantization" =>
          extensions[extension_name] = MeshQuantization(
            GLTFMeshQuantizationExtension::new(),
          )
        _ =>
          if gltf_index_of(extensions_required, extension_name) >= 0 &&
            plugins.get(extension_name) is None {
            gltf_console_warn(
              "THREE.GLTFLoader: Unknown extension \"" + extension_name + "\".",
            )
          }
      }
    }
  }
  parser.set_extensions(extensions)
  parser.set_plugins(plugins)
  parser.parse(on_load, on_error?)
}

///|
/// `array.indexOf( value )`.
extern "js" fn gltf_index_of(array : @core.JsValue, value : String) -> Int32 = "(a, v) => a.indexOf(v)"

// --- registry -------------------------------------------------------------------

///|
/// Upstream's `GLTFRegistry`: the parser's object cache (promises, derived materials,
/// interleaved buffers), as JS values.
pub struct GLTFRegistry {
  mut objects : Map[String, @core.JsValue]
  /// `cache[ 'DefaultMaterial' ]`, a plain property that `removeAll` keeps.
  mut default_material : @core.Material?
}

///|
fn GLTFRegistry::new() -> GLTFRegistry {
  { objects: {}, default_material: None, }
}

///|
/// `get( key )`; `undefined` when absent.
pub fn GLTFRegistry::get(self : GLTFRegistry, key : String) -> @core.JsValue {
  match self.objects.get(key) {
    Some(v) => v
    None => @core.JsValue::undefined()
  }
}

///|
pub fn GLTFRegistry::add(
  self : GLTFRegistry,
  key : String,
  object : @core.JsValue,
) -> Unit {
  self.objects[key] = object
}

///|
pub fn GLTFRegistry::remove(self : GLTFRegistry, key : String) -> Unit {
  self.objects.remove(key)
}

///|
pub fn GLTFRegistry::remove_all(self : GLTFRegistry) -> Unit {
  self.objects = {}
}

// --- associations ---------------------------------------------------------------

///|
/// The glTF definitions a three.js object came from (upstream's association values).
pub(all) struct GLTFReference {
  mut materials : Int32?
  mut textures : Int32?
  mut meshes : Int32?
  mut nodes : Int32?
  mut primitives : Int32?
}

///|
pub fn GLTFReference::new(
  materials? : Int32,
  textures? : Int32,
  meshes? : Int32,
  nodes? : Int32,
  primitives? : Int32,
) -> GLTFReference {
  { materials, textures, meshes, nodes, primitives, }
}

///|
/// `{ ...mapping }`.
pub fn GLTFReference::copy(self : GLTFReference) -> GLTFReference {
  { ..self, }
}

///|
/// A key of `parser.associations`.
pub(all) enum GLTFAssociationKey {
  Object3D(@core.Object3D)
  Material(@core.Material)
  Texture(@core.Texture)
}

///|
fn GLTFAssociationKey::to_js(self : GLTFAssociationKey) -> @core.JsValue {
  match self {
    Object3D(o) => @core.JsValue::of(o)
    Material(m) => @core.JsValue::of(m)
    Texture(t) => @core.JsValue::of(t)
  }
}

///|
priv struct GltfAssociationEntry {
  key : GLTFAssociationKey
  value : GLTFReference?
}

///|
/// `parser.associations`: a `Map` from three.js objects to `GLTFReference`s, keyed by
/// identity and kept in insertion order.
pub struct GLTFAssociations {
  priv map : GltfJsMap
}

///|
pub fn GLTFAssociations::new() -> GLTFAssociations {
  { map: GltfJsMap::new(), }
}

///|
/// `associations.get( key )`; `None` for a missing key or an `undefined` value.
pub fn GLTFAssociations::get(
  self : GLTFAssociations,
  key : GLTFAssociationKey,
) -> GLTFReference? {
  let entry = self.map.get(key.to_js())
  if entry.is_undefined() {
    None
  } else {
    let entry : GltfAssociationEntry = entry.cast()
    entry.value
  }
}

///|
pub fn GLTFAssociations::has(
  self : GLTFAssociations,
  key : GLTFAssociationKey,
) -> Bool {
  self.map.has(key.to_js())
}

///|
/// `associations.set( key, value )`; `None` stores `undefined`.
pub fn GLTFAssociations::set(
  self : GLTFAssociations,
  key : GLTFAssociationKey,
  value : GLTFReference?,
) -> Unit {
  self.map.set(
    key.to_js(),
    @core.JsValue::of(GltfAssociationEntry::{ key, value, }),
  )
}

///|
pub fn GLTFAssociations::size(self : GLTFAssociations) -> Int32 {
  self.map.size()
}

///|
/// The entries in insertion order.
pub fn GLTFAssociations::entries(
  self : GLTFAssociations,
) -> Array[(GLTFAssociationKey, GLTFReference?)] {
  self.map
  .values()
  .map(v => {
    let entry : GltfAssociationEntry = v.cast()
    (entry.key, entry.value)
  })
}

///|
pub fn GLTFAssociations::get_object(
  self : GLTFAssociations,
  object : @core.Object3D,
) -> GLTFReference? {
  self.get(Object3D(object))
}

///|
pub fn GLTFAssociations::get_material(
  self : GLTFAssociations,
  material : @core.Material,
) -> GLTFReference? {
  self.get(Material(material))
}

///|
pub fn GLTFAssociations::get_texture(
  self : GLTFAssociations,
  texture : @core.Texture,
) -> GLTFReference? {
  self.get(Texture(texture))
}
