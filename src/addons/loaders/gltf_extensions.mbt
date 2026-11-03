// GLTFLoader's built-in extensions (upstream's EXTENSIONS classes): punctual lights,
// unlit and the KHR_materials_* plugins, the texture source plugins (basisu, webp,
// avif), meshopt buffer views, GPU instancing, the binary container, Draco, texture
// transforms and mesh quantization.

///|
/// The entries of `parser.extensions` (upstream's `extensions[ name ]` values).
pub enum GLTFExtension {
  /// `true`: a plugin's name, marked so it is not an unknown extension.
  Plugin
  Binary(GLTFBinaryExtension)
  MaterialsUnlit(GLTFMaterialsUnlitExtension)
  DracoMeshCompression(GLTFDracoMeshCompressionExtension)
  TextureTransform(GLTFTextureTransformExtension)
  MeshQuantization(GLTFMeshQuantizationExtension)
}

///|
/// `getMaterialExtension( parser, materialIndex, extensionName )`; `None` is `null`.
fn gltf_get_material_extension(
  parser : GLTFParser,
  material_index : Int32,
  extension_name : String,
) -> JsValue? {
  let material_def = gltf_at(parser.json.get("materials"), material_index)
  let extensions = material_def.get("extensions")
  if gltf_truthy(extensions) && gltf_truthy(extensions.get(extension_name)) {
    return Some(extensions.get(extension_name))
  }
  None
}

///|
/// A JSON number as a material parameter (`undefined` stays `undefined`).
fn gltf_param_number(value : JsValue) -> @core.MaterialValue {
  if value.is_undefined() {
    Undefined
  } else {
    Number(value.cast())
  }
}

///|
/// `new Color().setRGB( a[ 0 ], a[ 1 ], a[ 2 ], LinearSRGBColorSpace )`.
fn gltf_color_from_array(array : JsValue) -> @math.Color {
  @math.Color::new(0, 0, 0).set_rgb(
    gltf_at(array, 0).cast(),
    gltf_at(array, 1).cast(),
    gltf_at(array, 2).cast(),
    color_space=@core.LinearSRGBColorSpace,
  )
}

// --- KHR_lights_punctual ---------------------------------------------------------

///|
/// Instance counts of shared nodes (upstream's `{ refs: {}, uses: {} }`).
pub struct GLTFNodeRefCache {
  refs : Map[Int32, Int32]
  uses : Map[Int32, Int32]
}

///|
pub fn GLTFNodeRefCache::new() -> GLTFNodeRefCache {
  { refs: {}, uses: {}, }
}

///|
/// Punctual lights extension.
pub struct GLTFLightsExtension {
  parser : GLTFParser
  name : String
  cache : GLTFNodeRefCache
}

///|
pub fn GLTFLightsExtension::new(parser : GLTFParser) -> &GLTFPlugin {
  GLTFLightsExtension::{
    parser,
    name: gltf_KHR_LIGHTS_PUNCTUAL,
    cache: GLTFNodeRefCache::new(),
  }
}

///|
impl GLTFPlugin for GLTFLightsExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFLightsExtension with fn mark_defs(self) {
  let parser = self.parser
  let node_defs = gltf_or(
    self.parser.json.get("nodes"),
    JsValue::of(([] : Array[Int32])),
  )
  for node_index in 0..<gltf_length(node_defs) {
    let node_def = gltf_at(node_defs, node_index)
    let extensions = node_def.get("extensions")
    if gltf_truthy(extensions) &&
      gltf_truthy(extensions.get(self.name)) &&
      gltf_defined(extensions.get(self.name).get("light")) {
      parser.add_node_ref(self.cache, extensions.get(self.name).get("light"))
    }
  }
}

///|
fn GLTFLightsExtension::load_light(
  self : GLTFLightsExtension,
  light_index : Int32,
) -> AddonPromise {
  let parser = self.parser
  let cache_key = "light:" + light_index.to_string()
  let dependency = parser.cache.get(cache_key)
  if gltf_truthy(dependency) {
    return dependency.cast()
  }
  let json = parser.json
  let extensions = gltf_or(
    if gltf_truthy(json.get("extensions")) {
      json.get("extensions").get(self.name)
    } else {
      json.get("extensions")
    },
    JsValue::object(),
  )
  let light_defs = gltf_or(
    extensions.get("lights"),
    JsValue::of(([] : Array[Int32])),
  )
  let light_def = gltf_at(light_defs, light_index)
  let color = @math.Color::new(1, 1, 1)
  if gltf_defined(light_def.get("color")) {
    let c = light_def.get("color")
    color.set_rgb(
      gltf_at(c, 0).cast(),
      gltf_at(c, 1).cast(),
      gltf_at(c, 2).cast(),
      color_space=@core.LinearSRGBColorSpace,
    )
    |> ignore
  }
  let range : Double = if gltf_defined(light_def.get("range")) {
    light_def.get("range").cast()
  } else {
    0
  }
  let type_ = light_def.get("type")
  let light_node = if gltf_equals_string(type_, "directional") {
    let light_node = @core.DirectionalLight::new(color~)
    light_node.light_target().position.set(0, 0, -1) |> ignore
    light_node.add(light_node.light_target()) |> ignore
    light_node
  } else if gltf_equals_string(type_, "point") {
    let light_node = @core.PointLight::new(color~)
    match light_node.as_light().kind {
      PointLight(p) => p.distance = range
      _ => ()
    }
    light_node
  } else if gltf_equals_string(type_, "spot") {
    let light_node = @core.SpotLight::new(color~)
    let spot = light_node.as_spot_light()
    spot.distance = range
    // Handle spotlight properties.
    gltf_spot_defaults(light_def)
    let inner : Double = light_def.get("spot").get("innerConeAngle").cast()
    let outer : Double = light_def.get("spot").get("outerConeAngle").cast()
    spot.angle = outer
    spot.penumbra = 1.0 - inner / outer
    light_node.light_target().position.set(0, 0, -1) |> ignore
    light_node.add(light_node.light_target()) |> ignore
    light_node
  } else {
    @utils.addon_throw_error(
      "THREE.GLTFLoader: Unexpected light type: " + gltf_string(type_),
    )
  }

  // Some lights (e.g. spot) default to a position other than the origin. Reset the position
  // here, because node-level parsing will only override position if explicitly specified.
  light_node.position.set(0, 0, 0) |> ignore
  gltf_assign_extras(light_node.user_data, light_def)
  if gltf_defined(light_def.get("intensity")) {
    light_node.as_light().intensity = light_def.get("intensity").cast()
  }
  light_node.name = parser.create_unique_name(
    gltf_or(
      light_def.get("name"),
      gltf_js_string("light_" + light_index.to_string()),
    ),
  )
  let dependency = AddonPromise::resolve(light_node)
  parser.cache.add(cache_key, dependency.to_js())
  dependency
}

///|
/// `lightDef.spot = lightDef.spot || {}` and the cone angle defaults.
extern "js" fn gltf_spot_defaults(light_def : JsValue) -> Unit =
  #|(lightDef) => {
  #|  lightDef.spot = lightDef.spot || {};
  #|  lightDef.spot.innerConeAngle = lightDef.spot.innerConeAngle !== undefined ? lightDef.spot.innerConeAngle : 0;
  #|  lightDef.spot.outerConeAngle = lightDef.spot.outerConeAngle !== undefined ? lightDef.spot.outerConeAngle : Math.PI / 4.0;
  #|}

///|
impl GLTFPlugin for GLTFLightsExtension with fn get_dependency(
  self,
  type_,
  index,
) {
  if type_ != "light" {
    return None
  }
  Some(self.load_light(index))
}

///|
impl GLTFPlugin for GLTFLightsExtension with fn create_node_attachment(
  self,
  node_index,
) {
  let parser = self.parser
  let json = parser.json
  let node_def = gltf_at(json.get("nodes"), node_index)
  let light_def = gltf_or(
    if gltf_truthy(node_def.get("extensions")) {
      node_def.get("extensions").get(self.name)
    } else {
      node_def.get("extensions")
    },
    JsValue::object(),
  )
  let light_index = light_def.get("light")
  if light_index.is_undefined() {
    return None
  }
  let light_index : Int32 = light_index.cast()
  Some(
    self
    .load_light(light_index)
    .then_(fn(light : @core.Object3D) {
      parser.get_node_ref(self.cache, light_index, light)
    }),
  )
}

// --- KHR_materials_unlit ---------------------------------------------------------

///|
/// Unlit materials extension.
pub struct GLTFMaterialsUnlitExtension {
  name : String
}

///|
pub fn GLTFMaterialsUnlitExtension::new() -> GLTFMaterialsUnlitExtension {
  { name: gltf_KHR_MATERIALS_UNLIT, }
}

///|
pub fn GLTFMaterialsUnlitExtension::get_material_type(
  _self : GLTFMaterialsUnlitExtension,
) -> GLTFMaterialType {
  MeshBasicMaterial
}

///|
pub fn GLTFMaterialsUnlitExtension::extend_params(
  _self : GLTFMaterialsUnlitExtension,
  material_params : GLTFMaterialParams,
  material_def : JsValue,
  parser : GLTFParser,
) -> AddonPromise {
  let pending = []
  let color = @math.Color::new(1.0, 1.0, 1.0)
  material_params["color"] = Color(color)
  material_params["opacity"] = Number(1.0)
  let metallic_roughness = material_def.get("pbrMetallicRoughness")
  if gltf_truthy(metallic_roughness) {
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
  }
  AddonPromise::all(pending)
}

// --- material plugins ------------------------------------------------------------

///|
/// Emissive strength extension.
pub struct GLTFMaterialsEmissiveStrengthExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFMaterialsEmissiveStrengthExtension::new(
  parser : GLTFParser,
) -> &GLTFPlugin {
  GLTFMaterialsEmissiveStrengthExtension::{
    parser,
    name: gltf_KHR_MATERIALS_EMISSIVE_STRENGTH,
  }
}

///|
impl GLTFPlugin for GLTFMaterialsEmissiveStrengthExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMaterialsEmissiveStrengthExtension with fn extend_material_params(
  self,
  material_index,
  material_params,
) {
  guard gltf_get_material_extension(self.parser, material_index, self.name)
    is Some(extension) else {
    return Some(AddonPromise::resolve_undefined())
  }
  if gltf_defined(extension.get("emissiveStrength")) {
    material_params["emissiveIntensity"] = gltf_param_number(
      extension.get("emissiveStrength"),
    )
  }
  Some(AddonPromise::resolve_undefined())
}

///|
/// Clearcoat extension.
pub struct GLTFMaterialsClearcoatExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFMaterialsClearcoatExtension::new(parser : GLTFParser) -> &GLTFPlugin {
  GLTFMaterialsClearcoatExtension::{
    parser,
    name: gltf_KHR_MATERIALS_CLEARCOAT,
  }
}

///|
impl GLTFPlugin for GLTFMaterialsClearcoatExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMaterialsClearcoatExtension with fn get_material_type(
  self,
  material_index,
) {
  gltf_get_material_extension(self.parser, material_index, self.name).map(_ => {
    GLTFMaterialType::MeshPhysicalMaterial
  })
}

///|
impl GLTFPlugin for GLTFMaterialsClearcoatExtension with fn extend_material_params(
  self,
  material_index,
  material_params,
) {
  guard gltf_get_material_extension(self.parser, material_index, self.name)
    is Some(extension) else {
    return Some(AddonPromise::resolve_undefined())
  }
  let pending = []
  if gltf_defined(extension.get("clearcoatFactor")) {
    material_params["clearcoat"] = gltf_param_number(
      extension.get("clearcoatFactor"),
    )
  }
  if gltf_defined(extension.get("clearcoatTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "clearcoatMap",
        extension.get("clearcoatTexture"),
      ),
    )
  }
  if gltf_defined(extension.get("clearcoatRoughnessFactor")) {
    material_params["clearcoatRoughness"] = gltf_param_number(
      extension.get("clearcoatRoughnessFactor"),
    )
  }
  if gltf_defined(extension.get("clearcoatRoughnessTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "clearcoatRoughnessMap",
        extension.get("clearcoatRoughnessTexture"),
      ),
    )
  }
  if gltf_defined(extension.get("clearcoatNormalTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "clearcoatNormalMap",
        extension.get("clearcoatNormalTexture"),
      ),
    )
    if gltf_defined(extension.get("clearcoatNormalTexture").get("scale")) {
      let scale : Double = extension
        .get("clearcoatNormalTexture")
        .get("scale")
        .cast()
      material_params["clearcoatNormalScale"] = Vector2(
        @math.Vector2::new(scale, scale),
      )
    }
  }
  Some(AddonPromise::all(pending))
}

///|
/// Diffuse roughness extension.
pub struct GLTFMaterialsDiffuseRoughnessExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFMaterialsDiffuseRoughnessExtension::new(
  parser : GLTFParser,
) -> &GLTFPlugin {
  GLTFMaterialsDiffuseRoughnessExtension::{
    parser,
    name: gltf_KHR_MATERIALS_DIFFUSE_ROUGHNESS,
  }
}

///|
impl GLTFPlugin for GLTFMaterialsDiffuseRoughnessExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMaterialsDiffuseRoughnessExtension with fn get_material_type(
  self,
  material_index,
) {
  gltf_get_material_extension(self.parser, material_index, self.name).map(_ => {
    GLTFMaterialType::MeshPhysicalMaterial
  })
}

///|
impl GLTFPlugin for GLTFMaterialsDiffuseRoughnessExtension with fn extend_material_params(
  self,
  material_index,
  material_params,
) {
  guard gltf_get_material_extension(self.parser, material_index, self.name)
    is Some(extension) else {
    return Some(AddonPromise::resolve_undefined())
  }
  let pending = []
  material_params["diffuseRoughness"] = if gltf_defined(
      extension.get("diffuseRoughnessFactor"),
    ) {
    gltf_param_number(extension.get("diffuseRoughnessFactor"))
  } else {
    Number(0)
  }
  if gltf_defined(extension.get("diffuseRoughnessTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "diffuseRoughnessMap",
        extension.get("diffuseRoughnessTexture"),
      ),
    )
  }
  Some(AddonPromise::all(pending))
}

///|
/// Dispersion extension.
pub struct GLTFMaterialsDispersionExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFMaterialsDispersionExtension::new(
  parser : GLTFParser,
) -> &GLTFPlugin {
  GLTFMaterialsDispersionExtension::{
    parser,
    name: gltf_KHR_MATERIALS_DISPERSION,
  }
}

///|
impl GLTFPlugin for GLTFMaterialsDispersionExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMaterialsDispersionExtension with fn get_material_type(
  self,
  material_index,
) {
  gltf_get_material_extension(self.parser, material_index, self.name).map(_ => {
    GLTFMaterialType::MeshPhysicalMaterial
  })
}

///|
impl GLTFPlugin for GLTFMaterialsDispersionExtension with fn extend_material_params(
  self,
  material_index,
  material_params,
) {
  guard gltf_get_material_extension(self.parser, material_index, self.name)
    is Some(extension) else {
    return Some(AddonPromise::resolve_undefined())
  }
  material_params["dispersion"] = if gltf_defined(extension.get("dispersion")) {
    gltf_param_number(extension.get("dispersion"))
  } else {
    Number(0)
  }
  Some(AddonPromise::resolve_undefined())
}

///|
/// Iridescence extension.
pub struct GLTFMaterialsIridescenceExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFMaterialsIridescenceExtension::new(
  parser : GLTFParser,
) -> &GLTFPlugin {
  GLTFMaterialsIridescenceExtension::{
    parser,
    name: gltf_KHR_MATERIALS_IRIDESCENCE,
  }
}

///|
impl GLTFPlugin for GLTFMaterialsIridescenceExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMaterialsIridescenceExtension with fn get_material_type(
  self,
  material_index,
) {
  gltf_get_material_extension(self.parser, material_index, self.name).map(_ => {
    GLTFMaterialType::MeshPhysicalMaterial
  })
}

///|
impl GLTFPlugin for GLTFMaterialsIridescenceExtension with fn extend_material_params(
  self,
  material_index,
  material_params,
) {
  guard gltf_get_material_extension(self.parser, material_index, self.name)
    is Some(extension) else {
    return Some(AddonPromise::resolve_undefined())
  }
  let pending = []
  if gltf_defined(extension.get("iridescenceFactor")) {
    material_params["iridescence"] = gltf_param_number(
      extension.get("iridescenceFactor"),
    )
  }
  if gltf_defined(extension.get("iridescenceTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "iridescenceMap",
        extension.get("iridescenceTexture"),
      ),
    )
  }
  if gltf_defined(extension.get("iridescenceIor")) {
    material_params["iridescenceIOR"] = gltf_param_number(
      extension.get("iridescenceIor"),
    )
  }
  if gltf_defined(extension.get("iridescenceThicknessMinimum")) {
    material_params["iridescenceThicknessMinimum"] = gltf_param_number(
      extension.get("iridescenceThicknessMinimum"),
    )
  }
  if gltf_defined(extension.get("iridescenceThicknessMaximum")) {
    material_params["iridescenceThicknessMaximum"] = gltf_param_number(
      extension.get("iridescenceThicknessMaximum"),
    )
  }
  if gltf_defined(extension.get("iridescenceThicknessTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "iridescenceThicknessMap",
        extension.get("iridescenceThicknessTexture"),
      ),
    )
  }
  Some(AddonPromise::all(pending))
}

///|
/// Sheen extension.
pub struct GLTFMaterialsSheenExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFMaterialsSheenExtension::new(parser : GLTFParser) -> &GLTFPlugin {
  GLTFMaterialsSheenExtension::{ parser, name: gltf_KHR_MATERIALS_SHEEN, }
}

///|
impl GLTFPlugin for GLTFMaterialsSheenExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMaterialsSheenExtension with fn get_material_type(
  self,
  material_index,
) {
  gltf_get_material_extension(self.parser, material_index, self.name).map(_ => {
    GLTFMaterialType::MeshPhysicalMaterial
  })
}

///|
impl GLTFPlugin for GLTFMaterialsSheenExtension with fn extend_material_params(
  self,
  material_index,
  material_params,
) {
  guard gltf_get_material_extension(self.parser, material_index, self.name)
    is Some(extension) else {
    return Some(AddonPromise::resolve_undefined())
  }
  let pending = []
  let sheen_color = @math.Color::new(0, 0, 0)
  material_params["sheenColor"] = Color(sheen_color)
  material_params["sheenRoughness"] = Number(0)
  material_params["sheen"] = Number(1)
  if gltf_defined(extension.get("sheenColorFactor")) {
    let color_factor = extension.get("sheenColorFactor")
    sheen_color.set_rgb(
      gltf_at(color_factor, 0).cast(),
      gltf_at(color_factor, 1).cast(),
      gltf_at(color_factor, 2).cast(),
      color_space=@core.LinearSRGBColorSpace,
    )
    |> ignore
  }
  if gltf_defined(extension.get("sheenRoughnessFactor")) {
    material_params["sheenRoughness"] = gltf_param_number(
      extension.get("sheenRoughnessFactor"),
    )
  }
  if gltf_defined(extension.get("sheenColorTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "sheenColorMap",
        extension.get("sheenColorTexture"),
        color_space=@core.SRGBColorSpace,
      ),
    )
  }
  if gltf_defined(extension.get("sheenRoughnessTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "sheenRoughnessMap",
        extension.get("sheenRoughnessTexture"),
      ),
    )
  }
  Some(AddonPromise::all(pending))
}

///|
/// Transmission extension.
pub struct GLTFMaterialsTransmissionExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFMaterialsTransmissionExtension::new(
  parser : GLTFParser,
) -> &GLTFPlugin {
  GLTFMaterialsTransmissionExtension::{
    parser,
    name: gltf_KHR_MATERIALS_TRANSMISSION,
  }
}

///|
impl GLTFPlugin for GLTFMaterialsTransmissionExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMaterialsTransmissionExtension with fn get_material_type(
  self,
  material_index,
) {
  gltf_get_material_extension(self.parser, material_index, self.name).map(_ => {
    GLTFMaterialType::MeshPhysicalMaterial
  })
}

///|
impl GLTFPlugin for GLTFMaterialsTransmissionExtension with fn extend_material_params(
  self,
  material_index,
  material_params,
) {
  guard gltf_get_material_extension(self.parser, material_index, self.name)
    is Some(extension) else {
    return Some(AddonPromise::resolve_undefined())
  }
  let pending = []
  if gltf_defined(extension.get("transmissionFactor")) {
    material_params["transmission"] = gltf_param_number(
      extension.get("transmissionFactor"),
    )
  }
  if gltf_defined(extension.get("transmissionTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "transmissionMap",
        extension.get("transmissionTexture"),
      ),
    )
  }
  Some(AddonPromise::all(pending))
}

///|
/// Volume extension.
pub struct GLTFMaterialsVolumeExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFMaterialsVolumeExtension::new(parser : GLTFParser) -> &GLTFPlugin {
  GLTFMaterialsVolumeExtension::{ parser, name: gltf_KHR_MATERIALS_VOLUME, }
}

///|
impl GLTFPlugin for GLTFMaterialsVolumeExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMaterialsVolumeExtension with fn get_material_type(
  self,
  material_index,
) {
  gltf_get_material_extension(self.parser, material_index, self.name).map(_ => {
    GLTFMaterialType::MeshPhysicalMaterial
  })
}

///|
impl GLTFPlugin for GLTFMaterialsVolumeExtension with fn extend_material_params(
  self,
  material_index,
  material_params,
) {
  guard gltf_get_material_extension(self.parser, material_index, self.name)
    is Some(extension) else {
    return Some(AddonPromise::resolve_undefined())
  }
  let pending = []
  material_params["thickness"] = if gltf_defined(
      extension.get("thicknessFactor"),
    ) {
    gltf_param_number(extension.get("thicknessFactor"))
  } else {
    Number(0)
  }
  if gltf_defined(extension.get("thicknessTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "thicknessMap",
        extension.get("thicknessTexture"),
      ),
    )
  }
  material_params["attenuationDistance"] = gltf_param_number(
    gltf_or(extension.get("attenuationDistance"), gltf_js_number(1.0 / 0.0)),
  )
  let color_array = gltf_or(
    extension.get("attenuationColor"),
    JsValue::of([1.0, 1.0, 1.0]),
  )
  material_params["attenuationColor"] = Color(
    gltf_color_from_array(color_array),
  )
  Some(AddonPromise::all(pending))
}

///|
/// Index of refraction extension.
pub struct GLTFMaterialsIorExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFMaterialsIorExtension::new(parser : GLTFParser) -> &GLTFPlugin {
  GLTFMaterialsIorExtension::{ parser, name: gltf_KHR_MATERIALS_IOR, }
}

///|
impl GLTFPlugin for GLTFMaterialsIorExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMaterialsIorExtension with fn get_material_type(
  self,
  material_index,
) {
  gltf_get_material_extension(self.parser, material_index, self.name).map(_ => {
    GLTFMaterialType::MeshPhysicalMaterial
  })
}

///|
impl GLTFPlugin for GLTFMaterialsIorExtension with fn extend_material_params(
  self,
  material_index,
  material_params,
) {
  guard gltf_get_material_extension(self.parser, material_index, self.name)
    is Some(extension) else {
    return Some(AddonPromise::resolve_undefined())
  }
  let ior = if gltf_defined(extension.get("ior")) {
    gltf_param_number(extension.get("ior"))
  } else {
    Number(1.5)
  }
  material_params["ior"] = ior
  if ior is Number(0) {
    material_params["ior"] = Number(1000) // see #26167
  }
  Some(AddonPromise::resolve_undefined())
}

///|
/// Specular extension.
pub struct GLTFMaterialsSpecularExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFMaterialsSpecularExtension::new(parser : GLTFParser) -> &GLTFPlugin {
  GLTFMaterialsSpecularExtension::{ parser, name: gltf_KHR_MATERIALS_SPECULAR, }
}

///|
impl GLTFPlugin for GLTFMaterialsSpecularExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMaterialsSpecularExtension with fn get_material_type(
  self,
  material_index,
) {
  gltf_get_material_extension(self.parser, material_index, self.name).map(_ => {
    GLTFMaterialType::MeshPhysicalMaterial
  })
}

///|
impl GLTFPlugin for GLTFMaterialsSpecularExtension with fn extend_material_params(
  self,
  material_index,
  material_params,
) {
  guard gltf_get_material_extension(self.parser, material_index, self.name)
    is Some(extension) else {
    return Some(AddonPromise::resolve_undefined())
  }
  let pending = []
  material_params["specularIntensity"] = if gltf_defined(
      extension.get("specularFactor"),
    ) {
    gltf_param_number(extension.get("specularFactor"))
  } else {
    Number(1.0)
  }
  if gltf_defined(extension.get("specularTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "specularIntensityMap",
        extension.get("specularTexture"),
      ),
    )
  }
  let color_array = gltf_or(
    extension.get("specularColorFactor"),
    JsValue::of([1.0, 1.0, 1.0]),
  )
  material_params["specularColor"] = Color(gltf_color_from_array(color_array))
  if gltf_defined(extension.get("specularColorTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "specularColorMap",
        extension.get("specularColorTexture"),
        color_space=@core.SRGBColorSpace,
      ),
    )
  }
  Some(AddonPromise::all(pending))
}

///|
/// Bump extension.
pub struct GLTFMaterialsBumpExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFMaterialsBumpExtension::new(parser : GLTFParser) -> &GLTFPlugin {
  GLTFMaterialsBumpExtension::{ parser, name: gltf_EXT_MATERIALS_BUMP, }
}

///|
impl GLTFPlugin for GLTFMaterialsBumpExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMaterialsBumpExtension with fn get_material_type(
  self,
  material_index,
) {
  gltf_get_material_extension(self.parser, material_index, self.name).map(_ => {
    GLTFMaterialType::MeshPhysicalMaterial
  })
}

///|
impl GLTFPlugin for GLTFMaterialsBumpExtension with fn extend_material_params(
  self,
  material_index,
  material_params,
) {
  guard gltf_get_material_extension(self.parser, material_index, self.name)
    is Some(extension) else {
    return Some(AddonPromise::resolve_undefined())
  }
  let pending = []
  material_params["bumpScale"] = if gltf_defined(extension.get("bumpFactor")) {
    gltf_param_number(extension.get("bumpFactor"))
  } else {
    Number(1.0)
  }
  if gltf_defined(extension.get("bumpTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "bumpMap",
        extension.get("bumpTexture"),
      ),
    )
  }
  Some(AddonPromise::all(pending))
}

///|
/// Anisotropy extension.
pub struct GLTFMaterialsAnisotropyExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFMaterialsAnisotropyExtension::new(
  parser : GLTFParser,
) -> &GLTFPlugin {
  GLTFMaterialsAnisotropyExtension::{
    parser,
    name: gltf_KHR_MATERIALS_ANISOTROPY,
  }
}

///|
impl GLTFPlugin for GLTFMaterialsAnisotropyExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMaterialsAnisotropyExtension with fn get_material_type(
  self,
  material_index,
) {
  gltf_get_material_extension(self.parser, material_index, self.name).map(_ => {
    GLTFMaterialType::MeshPhysicalMaterial
  })
}

///|
impl GLTFPlugin for GLTFMaterialsAnisotropyExtension with fn extend_material_params(
  self,
  material_index,
  material_params,
) {
  guard gltf_get_material_extension(self.parser, material_index, self.name)
    is Some(extension) else {
    return Some(AddonPromise::resolve_undefined())
  }
  let pending = []
  if gltf_defined(extension.get("anisotropyStrength")) {
    material_params["anisotropy"] = gltf_param_number(
      extension.get("anisotropyStrength"),
    )
  }
  if gltf_defined(extension.get("anisotropyRotation")) {
    material_params["anisotropyRotation"] = gltf_param_number(
      extension.get("anisotropyRotation"),
    )
  }
  if gltf_defined(extension.get("anisotropyTexture")) {
    pending.push(
      self.parser.assign_texture(
        material_params,
        "anisotropyMap",
        extension.get("anisotropyTexture"),
      ),
    )
  }
  Some(AddonPromise::all(pending))
}

// --- texture source plugins --------------------------------------------------------

///|
/// BasisU (KTX2) texture extension.
pub struct GLTFTextureBasisUExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFTextureBasisUExtension::new(parser : GLTFParser) -> &GLTFPlugin {
  GLTFTextureBasisUExtension::{ parser, name: gltf_KHR_TEXTURE_BASISU, }
}

///|
impl GLTFPlugin for GLTFTextureBasisUExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFTextureBasisUExtension with fn load_texture(
  self,
  texture_index,
) {
  let parser = self.parser
  let json = parser.json
  let texture_def = gltf_at(json.get("textures"), texture_index)
  let extensions = texture_def.get("extensions")
  if !gltf_truthy(extensions) || !gltf_truthy(extensions.get(self.name)) {
    return None
  }
  let extension = extensions.get(self.name)
  guard parser.options.ktx2_loader is Some(loader) else {
    if gltf_truthy(json.get("extensionsRequired")) &&
      gltf_index_of(json.get("extensionsRequired"), self.name) >= 0 {
      @utils.addon_throw_error(
        "THREE.GLTFLoader: setKTX2Loader must be called before loading KTX2 textures",
      )
    } else {
      // Assumes that the extension is optional and that a fallback texture is present
      return None
    }
  }
  Some(
    parser.load_texture_image(
      texture_index,
      extension.get("source").cast(),
      KTX2Loader(loader),
    ),
  )
}

///|
/// The loader for an image source: `parser.textureLoader`, or a manager handler.
fn gltf_source_loader(parser : GLTFParser, source : JsValue) -> GLTFImageLoader {
  let loader = parser.texture_loader
  if gltf_truthy(source.get("uri")) {
    // Upstream asks `manager.getHandler( uri )`; a handler is a `LoaderLike`, which
    // the port cannot call, so handlers are not used here.
    ignore(parser.options.manager.get_handler(gltf_string(source.get("uri"))))
  }
  loader
}

///|
/// WebP texture extension.
pub struct GLTFTextureWebPExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFTextureWebPExtension::new(parser : GLTFParser) -> &GLTFPlugin {
  GLTFTextureWebPExtension::{ parser, name: gltf_EXT_TEXTURE_WEBP, }
}

///|
impl GLTFPlugin for GLTFTextureWebPExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFTextureWebPExtension with fn load_texture(
  self,
  texture_index,
) {
  let name = self.name
  let parser = self.parser
  let json = parser.json
  let texture_def = gltf_at(json.get("textures"), texture_index)
  let extensions = texture_def.get("extensions")
  if !gltf_truthy(extensions) || !gltf_truthy(extensions.get(name)) {
    return None
  }
  let extension = extensions.get(name)
  let source = gltf_at(json.get("images"), extension.get("source").cast())
  let loader = gltf_source_loader(parser, source)
  Some(
    parser.load_texture_image(
      texture_index,
      extension.get("source").cast(),
      loader,
    ),
  )
}

///|
/// AVIF texture extension.
pub struct GLTFTextureAVIFExtension {
  parser : GLTFParser
  name : String
}

///|
pub fn GLTFTextureAVIFExtension::new(parser : GLTFParser) -> &GLTFPlugin {
  GLTFTextureAVIFExtension::{ parser, name: gltf_EXT_TEXTURE_AVIF, }
}

///|
impl GLTFPlugin for GLTFTextureAVIFExtension with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFTextureAVIFExtension with fn load_texture(
  self,
  texture_index,
) {
  let name = self.name
  let parser = self.parser
  let json = parser.json
  let texture_def = gltf_at(json.get("textures"), texture_index)
  let extensions = texture_def.get("extensions")
  if !gltf_truthy(extensions) || !gltf_truthy(extensions.get(name)) {
    return None
  }
  let extension = extensions.get(name)
  let source = gltf_at(json.get("images"), extension.get("source").cast())
  let loader = gltf_source_loader(parser, source)
  Some(
    parser.load_texture_image(
      texture_index,
      extension.get("source").cast(),
      loader,
    ),
  )
}

// --- meshopt -------------------------------------------------------------------------

///|
/// meshopt buffer view compression (EXT_ and KHR_meshopt_compression).
pub struct GLTFMeshoptCompression {
  name : String
  parser : GLTFParser
}

///|
pub fn GLTFMeshoptCompression::new(
  parser : GLTFParser,
  name : String,
) -> &GLTFPlugin {
  GLTFMeshoptCompression::{ name, parser, }
}

///|
impl GLTFPlugin for GLTFMeshoptCompression with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMeshoptCompression with fn load_buffer_view(self, index) {
  let json = self.parser.json
  let buffer_view = gltf_at(json.get("bufferViews"), index)
  let extensions = buffer_view.get("extensions")
  if gltf_truthy(extensions) && gltf_truthy(extensions.get(self.name)) {
    let extension_def = extensions.get(self.name)
    let buffer = self.parser.get_dependency(
      "buffer",
      extension_def.get("buffer").cast(),
    )
    let decoder = match self.parser.options.meshopt_decoder {
      Some(d) => d
      None => JsValue::null()
    }
    if gltf_meshopt_unsupported(decoder) {
      if gltf_truthy(json.get("extensionsRequired")) &&
        gltf_index_of(json.get("extensionsRequired"), self.name) >= 0 {
        @utils.addon_throw_error(
          "THREE.GLTFLoader: setMeshoptDecoder must be called before loading compressed files",
        )
      } else {
        // Assumes that the extension is optional and that fallback buffer data is present
        return None
      }
    }
    Some(
      buffer.then_(fn(res : JsValue) {
        let byte_offset : Int32 = gltf_or(
          extension_def.get("byteOffset"),
          gltf_js_number(0),
        ).cast()
        let byte_length : Int32 = gltf_or(
          extension_def.get("byteLength"),
          gltf_js_number(0),
        ).cast()
        let count = extension_def.get("count")
        let stride = extension_def.get("byteStride")
        let source = gltf_uint8_view(res, byte_offset, byte_length)
        if gltf_meshopt_has_async(decoder) {
          gltf_meshopt_decode_async(
            decoder,
            count,
            stride,
            source,
            extension_def.get("mode"),
            extension_def.get("filter"),
          ).then_(fn(res : JsValue) { gltf_buffer_of(res) })
        } else {
          // Support for MeshoptDecoder 0.18 or earlier, without decodeGltfBufferAsync
          gltf_meshopt_ready(decoder).then_(fn(_ : JsValue) {
            gltf_meshopt_decode_sync(
              decoder,
              count,
              stride,
              source,
              extension_def.get("mode"),
              extension_def.get("filter"),
            )
          })
        }
      }),
    )
  } else {
    None
  }
}

// --- EXT_mesh_gpu_instancing -----------------------------------------------------------

///|
/// GPU instancing extension.
pub struct GLTFMeshGpuInstancing {
  name : String
  parser : GLTFParser
}

///|
pub fn GLTFMeshGpuInstancing::new(parser : GLTFParser) -> &GLTFPlugin {
  GLTFMeshGpuInstancing::{ name: gltf_EXT_MESH_GPU_INSTANCING, parser, }
}

///|
impl GLTFPlugin for GLTFMeshGpuInstancing with fn name(self) {
  self.name
}

///|
impl GLTFPlugin for GLTFMeshGpuInstancing with fn create_node_mesh(
  self,
  node_index,
) {
  let json = self.parser.json
  let node_def = gltf_at(json.get("nodes"), node_index)
  let extensions = node_def.get("extensions")
  if !gltf_truthy(extensions) ||
    !gltf_truthy(extensions.get(self.name)) ||
    node_def.get("mesh").is_undefined() {
    return None
  }
  let mesh_def = gltf_at(json.get("meshes"), node_def.get("mesh").cast())

  // No Points or Lines + Instancing support yet
  let primitives = mesh_def.get("primitives")
  for i in 0..<gltf_length(primitives) {
    let mode = gltf_at(primitives, i).get("mode")
    if !gltf_equals_number(mode, gltf_TRIANGLES) &&
      !gltf_equals_number(mode, gltf_TRIANGLE_STRIP) &&
      !gltf_equals_number(mode, gltf_TRIANGLE_FAN) &&
      !mode.is_undefined() {
      return None
    }
  }
  let extension_def = extensions.get(self.name)
  let attributes_def = extension_def.get("attributes")

  // @TODO: Can we support InstancedMesh + SkinnedMesh?
  let pending = []
  let attributes : Map[String, @core.GeometryAttribute] = Map([])
  let keys = gltf_keys(attributes_def)
  for key in keys {
    pending.push(
      self.parser
      .get_dependency("accessor", attributes_def.get(key).cast())
      .then_(fn(accessor : @core.GeometryAttribute) {
        attributes[key] = accessor
        accessor
      }),
    )
  }
  if pending.length() < 1 {
    return None
  }
  pending.push(self.parser.create_node_mesh(node_index).unwrap())
  Some(
    AddonPromise::all(pending).then_(fn(results : Array[JsValue]) {
      let node_object : @core.Object3D = results.pop().unwrap().cast()
      let meshes = if node_object.is_group() {
        node_object.children
      } else {
        [node_object]
      }
      let first : @core.GeometryAttribute = results[0].cast()
      let count = first.count() // All attribute counts should be same
      let instanced_meshes = []
      for mesh in meshes {
        // Temporal variables
        let m = @math.Matrix4::new()
        let p = @math.Vector3::new(0, 0, 0)
        let q = @math.Quaternion::new(0, 0, 0, 1)
        let s = @math.Vector3::new(1, 1, 1)
        let instanced_mesh = @core.InstancedMesh::new(
          geometry=gltf_mesh_geometry(mesh),
          material=gltf_mesh_material(mesh),
          count,
        )
        for i in 0..<count {
          if attributes.get("TRANSLATION") is Some(a) {
            p.from_buffer_attribute(a, i) |> ignore
          }
          if attributes.get("ROTATION") is Some(a) {
            q.from_buffer_attribute(a, i) |> ignore
          }
          if attributes.get("SCALE") is Some(a) {
            s.from_buffer_attribute(a, i) |> ignore
          }
          instanced_mesh.set_matrix_at(i, m.compose(p, q, s)) |> ignore
        }

        // Add instance attributes to the geometry, excluding TRS.
        let mut instance_geometry : @core.BufferGeometry? = None
        for attribute_name in gltf_js_key_order(attributes.keys().collect()) {
          let attr = attributes[attribute_name]
          if attribute_name == "_COLOR_0" {
            match instanced_mesh.kind {
              Mesh({ kind: InstancedMesh(im), .. }) =>
                im.instance_color = Some(
                  @core.InstancedBufferAttribute::new(
                    attr.array(),
                    attr.item_size(),
                    normalized=attr.normalized(),
                  ),
                )
              _ => ()
            }
          } else if attribute_name != "TRANSLATION" &&
            attribute_name != "ROTATION" &&
            attribute_name != "SCALE" {
            if instance_geometry is None {
              // do a shallow clone of the goemetry so per-instance data are not shared
              let source = gltf_mesh_geometry(instanced_mesh)
              let geometry = @core.BufferGeometry::new()
              geometry.name = source.name
              for name in gltf_js_key_order(source.attributes.keys().collect()) {
                geometry.set_attribute(name, source.attributes[name]) |> ignore
              }
              for
                name in gltf_js_key_order(
                  source.morph_attributes.keys().collect(),
                ) {
                geometry.morph_attributes[name] = source.morph_attributes[name]
              }
              if source.index is Some(index) {
                geometry.set_index(index) |> ignore
              }
              geometry.morph_targets_relative = source.morph_targets_relative
              for group in source.groups {
                geometry.add_group(
                  group.start,
                  group.count,
                  material_index=group.material_index,
                )
              }
              if source.bounding_box is Some(b) {
                geometry.bounding_box = Some(b.clone())
              }
              if source.bounding_sphere is Some(b) {
                geometry.bounding_sphere = Some(b.clone())
              }
              geometry.draw_range.start = source.draw_range.start
              geometry.draw_range.count = source.draw_range.count
              geometry.user_data = gltf_object_assign_copy(source.user_data)
              gltf_set_mesh_geometry(instanced_mesh, geometry)
              instance_geometry = Some(geometry)
            }
            instance_geometry
            .unwrap()
            .set_attribute(
              attribute_name,
              @core.InstancedBufferAttribute::new(
                attr.array(),
                attr.item_size(),
                normalized=attr.normalized(),
              ),
            )
            |> ignore
          }
        }

        // Just in case
        instanced_mesh.copy_base(mesh, true)
        self.parser.assign_final_material(instanced_mesh)
        instanced_meshes.push(instanced_mesh)
      }
      if node_object.is_group() {
        node_object.clear() |> ignore
        node_object.add_all(instanced_meshes) |> ignore
        return node_object
      }
      instanced_meshes[0]
    }),
  )
}

///|
/// `Object.assign( {}, o )`.
extern "js" fn gltf_object_assign_copy(o : JsValue) -> JsValue = "(o) => Object.assign({}, o)"

///|
/// The order `for ( const k in object )` visits these keys: integer-like keys first,
/// ascending, then the others in insertion order.
extern "js" fn gltf_js_key_order(keys : Array[String]) -> Array[String] =
  #|(keys) => { const o = {}; for (const k of keys) o[k] = true; return Object.keys(o); }

// --- KHR_binary_glTF -----------------------------------------------------------------

///|
/// The `.glb` header.
pub(all) struct GLTFBinaryHeader {
  magic : String
  version : Double
  length : Double
}

///|
/// The binary glTF container: the JSON chunk text and the BIN chunk.
pub struct GLTFBinaryExtension {
  name : String
  content : String?
  /// The BIN chunk, an `ArrayBuffer`; `None` is `null`.
  body : JsValue?
  header : GLTFBinaryHeader
}

///|
/// Parses a `.glb` container; throws upstream's errors.
pub fn GLTFBinaryExtension::new(data : JsValue) -> GLTFBinaryExtension {
  let header = {
    magic: gltf_decode_magic(data),
    version: gltf_get_uint32(data, 0, 4),
    length: gltf_get_uint32(data, 0, 8),
  }
  if header.magic != gltf_BINARY_EXTENSION_HEADER_MAGIC {
    @utils.addon_throw_error(
      "THREE.GLTFLoader: Unsupported glTF-Binary header.",
    )
  } else if header.version < 2.0 {
    @utils.addon_throw_error("THREE.GLTFLoader: Legacy binary file detected.")
  }
  let mut content = None
  let mut body = None
  let chunk_contents_length = header.length -
    gltf_BINARY_EXTENSION_HEADER_LENGTH.to_double()
  let mut chunk_index = 0
  while chunk_index.to_double() < chunk_contents_length {
    let chunk_length = gltf_get_uint32(
      data, gltf_BINARY_EXTENSION_HEADER_LENGTH, chunk_index,
    )
    chunk_index += 4
    let chunk_type = gltf_get_uint32(
      data, gltf_BINARY_EXTENSION_HEADER_LENGTH, chunk_index,
    )
    chunk_index += 4
    if chunk_type == gltf_BINARY_EXTENSION_CHUNK_TYPE_JSON {
      content = Some(
        gltf_decode_text(
          data,
          gltf_BINARY_EXTENSION_HEADER_LENGTH + chunk_index,
          chunk_length.to_int(),
        ),
      )
    } else if chunk_type == gltf_BINARY_EXTENSION_CHUNK_TYPE_BIN {
      let byte_offset = gltf_BINARY_EXTENSION_HEADER_LENGTH + chunk_index
      body = Some(
        gltf_slice(data, byte_offset, byte_offset + chunk_length.to_int()),
      )
    }

    // Clients must ignore chunks with unknown types.
    chunk_index += chunk_length.to_int()
  }
  if content is None {
    @utils.addon_throw_error("THREE.GLTFLoader: JSON content not found.")
  }
  { name: gltf_KHR_BINARY_GLTF, content, body, header, }
}

// --- KHR_draco_mesh_compression -----------------------------------------------------

///|
/// Draco mesh compression extension.
pub struct GLTFDracoMeshCompressionExtension {
  name : String
  json : JsValue
  draco_loader : DRACOLoader
}

///|
/// Throws upstream's error without a Draco loader.
pub fn GLTFDracoMeshCompressionExtension::new(
  json : JsValue,
  draco_loader : DRACOLoader?,
) -> GLTFDracoMeshCompressionExtension {
  guard draco_loader is Some(draco_loader) else {
    @utils.addon_throw_error(
      "THREE.GLTFLoader: No DRACOLoader instance provided.",
    )
  }
  let extension = { name: gltf_KHR_DRACO_MESH_COMPRESSION, json, draco_loader, }
  extension.draco_loader.preload() |> ignore
  extension
}

///|
/// Decodes a Draco primitive, resolving to its `BufferGeometry`.
pub fn GLTFDracoMeshCompressionExtension::decode_primitive(
  self : GLTFDracoMeshCompressionExtension,
  primitive : JsValue,
  parser : GLTFParser,
) -> AddonPromise {
  let json = self.json
  let draco_loader = self.draco_loader
  let extension = primitive.get("extensions").get(self.name)
  let buffer_view_index : Int32 = extension.get("bufferView").cast()
  let gltf_attribute_map = extension.get("attributes")
  let three_attribute_map : Map[String, Int32] = Map([])
  let attribute_normalized_map : Map[String, Bool] = Map([])
  let attribute_type_map : Map[String, String] = Map([])
  for attribute_name in gltf_keys(gltf_attribute_map) {
    let three_attribute_name = gltf_three_attribute_name(attribute_name)
    three_attribute_map[three_attribute_name] = gltf_attribute_map
      .get(attribute_name)
      .cast()
  }
  let attributes = primitive.get("attributes")
  for attribute_name in gltf_keys(attributes) {
    let three_attribute_name = gltf_three_attribute_name(attribute_name)
    if gltf_defined(gltf_attribute_map.get(attribute_name)) {
      let accessor_def = gltf_at(
        json.get("accessors"),
        attributes.get(attribute_name).cast(),
      )
      let component_type = gltf_component_type(
        accessor_def.get("componentType"),
      )
      attribute_type_map[three_attribute_name] = component_type
      attribute_normalized_map[three_attribute_name] = gltf_is_true(
        accessor_def.get("normalized"),
      )
    }
  }
  parser
  .get_dependency("bufferView", buffer_view_index)
  .then_(fn(buffer_view : JsValue) {
    AddonPromise::new(fn(resolve, reject) {
      draco_loader.decode_draco_file(
        buffer_view,
        fn(geometry) {
          for
            attribute_name in gltf_js_key_order(
              geometry.attributes.keys().collect(),
            ) {
            let attribute = geometry.attributes[attribute_name]
            if attribute_normalized_map.get(attribute_name) is Some(normalized) {
              gltf_set_normalized(attribute, normalized)
            }
          }
          resolve(JsValue::of(geometry))
        },
        attribute_ids=three_attribute_map,
        attribute_types=attribute_type_map,
        vertex_color_space=@core.LinearSRGBColorSpace,
        on_error=reject,
      )
      |> ignore
    })
  })
}

///|
/// `attribute.normalized = value`.
fn gltf_set_normalized(
  attribute : @core.GeometryAttribute,
  value : Bool,
) -> Unit {
  match attribute {
    Buffer(a) => a.normalized = value
    Interleaved(a) => a.normalized = value
    GL(a) => a.normalized = value
  }
}

// --- KHR_texture_transform ---------------------------------------------------------

///|
/// Texture transform extension.
pub struct GLTFTextureTransformExtension {
  name : String
}

///|
pub fn GLTFTextureTransformExtension::new() -> GLTFTextureTransformExtension {
  { name: gltf_KHR_TEXTURE_TRANSFORM, }
}

///|
/// Applies a `KHR_texture_transform` definition, cloning the texture when it changes.
pub fn GLTFTextureTransformExtension::extend_texture(
  _self : GLTFTextureTransformExtension,
  texture : @core.Texture,
  transform : JsValue,
) -> @core.Texture {
  let tex_coord = transform.get("texCoord")
  if (
      tex_coord.is_undefined() ||
      gltf_equals_number(tex_coord, texture.channel.to_double())
    ) &&
    transform.get("offset").is_undefined() &&
    transform.get("rotation").is_undefined() &&
    transform.get("scale").is_undefined() {
    // See https://github.com/mrdoob/three.js/issues/21819.
    return texture
  }
  let texture = texture.clone()
  if gltf_defined(tex_coord) {
    texture.channel = tex_coord.cast()
  }
  if gltf_defined(transform.get("offset")) {
    texture.offset.from_array(transform.get("offset").cast()) |> ignore
  }
  if gltf_defined(transform.get("rotation")) {
    texture.rotation = transform.get("rotation").cast()
  }
  if gltf_defined(transform.get("scale")) {
    texture.repeat.from_array(transform.get("scale").cast()) |> ignore
  }
  if gltf_defined(transform.get("rotation")) {
    // glTF's KHR_texture_transform order differs from three.js:
    // glTF defines the UV transform as T * R * S
    // three.js defines the UV transform as T * S * R
    //
    // To fix this, we need to override the matrix with the value computed per glTF spec
    // We still set the other fields so that you can inspect/export the resulting object.
    let c = gltf_cos(texture.rotation)
    let s = gltf_sin(texture.rotation)
    texture.matrix.set(
      texture.repeat.x * c,
      texture.repeat.y * s,
      texture.offset.x,
      -texture.repeat.x * s,
      texture.repeat.y * c,
      texture.offset.y,
      0,
      0,
      1,
    )
    |> ignore
    texture.matrix_auto_update = false
  }
  texture.set_needs_update(true)
  texture
}

// --- KHR_mesh_quantization ---------------------------------------------------------

///|
/// Mesh quantization extension (nothing to do at load time).
pub struct GLTFMeshQuantizationExtension {
  name : String
}

///|
pub fn GLTFMeshQuantizationExtension::new() -> GLTFMeshQuantizationExtension {
  { name: gltf_KHR_MESH_QUANTIZATION, }
}
