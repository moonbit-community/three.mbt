// Upstream src/loaders/MaterialLoader.js. Parsing is core's `Material::from_json`,
// as upstream's `material.fromJSON( json, textures )`.

///|
/// Upstream's module-level `_customMaterials`, filled by `register_material`.
let material_loader_custom_materials : Map[String, () -> @core.Material] = Map([])

///|
/// Loads materials in the JSON format of `Material::to_json`. Node materials are not
/// supported.
pub struct MaterialLoader {
  base : Loader
  /// The textures the material refers to, by uuid.
  mut textures : Map[String, @core.Texture]
}

///|
pub fn MaterialLoader::new(manager? : LoadingManager) -> MaterialLoader {
  { base: Loader::new(manager?), textures: Map([]), }
}

///|
pub impl LoaderLike for MaterialLoader with fn loader(self) {
  self.base
}

///|
pub impl LoaderSettings for MaterialLoader

///|
pub extend MaterialLoader with LoaderLike::{loader}

///|
pub extend MaterialLoader with LoaderSettings::{
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
/// Starts loading `url`; `on_load` receives the material.
pub fn MaterialLoader::load(
  self : MaterialLoader,
  url : String,
  on_load : (@core.Material) -> Unit,
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
pub async fn MaterialLoader::load_async(
  self : MaterialLoader,
  url : String,
  on_progress? : (ProgressEvent) -> Unit,
) -> @core.Material raise LoaderError {
  loader_promise((resolve, reject) => {
    self.load(url, resolve, on_progress?, on_error=reject)
  })
}

///|
/// Parses `json` into a material of the class its `type` names.
pub fn MaterialLoader::parse(
  self : MaterialLoader,
  json : Json,
) -> @core.Material {
  let type_ = match json {
    Object(object) =>
      match object.get("type") {
        Some(String(type_)) => type_
        _ => "undefined"
      }
    _ => "undefined"
  }
  let material = self.create_material_from_type(type_)
  material.from_json(json, textures=self.textures)
}

///|
/// Sets the textures, by uuid, that the parsed materials refer to.
pub fn MaterialLoader::set_textures(
  self : MaterialLoader,
  value : Map[String, @core.Texture],
) -> MaterialLoader {
  self.textures = value
  self
}

///|
pub fn MaterialLoader::create_material_from_type(
  self : MaterialLoader,
  type_ : String,
) -> @core.Material {
  ignore(self)
  MaterialLoader::create_material_from_type_static(type_)
}

///|
/// Upstream's static `MaterialLoader.createMaterialFromType`. Registered types come
/// first, as upstream spreads `_customMaterials` over the built-in classes.
pub fn MaterialLoader::create_material_from_type_static(
  type_ : String,
) -> @core.Material {
  if material_loader_custom_materials.get(type_) is Some(construct) {
    return construct()
  }
  match type_ {
    "ShadowMaterial" => @core.ShadowMaterial::new()
    "SpriteMaterial" => @core.SpriteMaterial::new()
    "RawShaderMaterial" => @core.RawShaderMaterial::new()
    "ShaderMaterial" => @core.ShaderMaterial::new()
    "PointsMaterial" => @core.PointsMaterial::new()
    "MeshPhysicalMaterial" => @core.MeshPhysicalMaterial::new()
    "MeshStandardMaterial" => @core.MeshStandardMaterial::new()
    "MeshPhongMaterial" => @core.MeshPhongMaterial::new()
    "MeshToonMaterial" => @core.MeshToonMaterial::new()
    "MeshNormalMaterial" => @core.MeshNormalMaterial::new()
    "MeshLambertMaterial" => @core.MeshLambertMaterial::new()
    "MeshDepthMaterial" => @core.MeshDepthMaterial::new()
    "MeshDistanceMaterial" => @core.MeshDistanceMaterial::new()
    "MeshBasicMaterial" => @core.MeshBasicMaterial::new()
    "MeshMatcapMaterial" => @core.MeshMatcapMaterial::new()
    "LineDashedMaterial" => @core.LineDashedMaterial::new()
    "LineBasicMaterial" => @core.LineBasicMaterial::new()
    "Material" => @core.Material::new()
    _ => {
      @core.warn_once(
        "MaterialLoader: Unknown material type \"\{type_}\". Use .registerMaterial() before starting the deserialization process.",
      )
      @core.Material::new()
    }
  }
}

///|
/// Upstream's static `MaterialLoader.registerMaterial`: `construct` is `new materialClass()`.
pub fn MaterialLoader::register_material(
  type_ : String,
  construct : () -> @core.Material,
) -> Unit {
  material_loader_custom_materials[type_] = construct
}
