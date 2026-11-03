// Upstream src/materials/Material.js. `Material::new` sets the base properties, each
// subclass constructor sets its own, and the rest stay `None`, upstream's `undefined`.

///|
let _material_id : Ref[Int32] = Ref(0)

///|
extern "js" fn material_infinity() -> Double = "() => Infinity"

///|
extern "js" fn material_function_to_string(f : JsValue) -> String = "(f) => f.toString()"

///|
/// A value passed to `Material::set_values`. `Number` also holds hex colors and constants.
pub(all) enum MaterialValue {
  Undefined
  Null
  Bool(Bool)
  Number(Double)
  String(String)
  Color(@math.Color)
  Vector2(@math.Vector2)
  Euler(@math.Euler)
  Texture(Texture)
  Planes(Array[@math.Plane])
  Uniforms(Map[String, Uniform])
  UniformsGroups(Array[UniformsGroup])
  Defines(Map[String, Json])
  Extensions(ShaderExtensions)
  AttributeValues(Map[String, Array[Double]])
  /// `userData`.
  Object(JsValue)
  OnBeforeRender(
    (JsValue, Object3D, Object3D, BufferGeometry, Object3D, GeometryGroup?) -> Unit
  )
  OnBeforeCompile((ShaderObject, JsValue) -> Unit)
  CustomProgramCacheKey(() -> String)
}

///|
pub fn Material::new() -> Material {
  let id = _material_id.val
  _material_id.val += 1
  {
    id,
    dispatcher: EventDispatcher::new(),
    uuid: @math.generate_uuid(),
    name: "",
    type_: "Material",
    material_type: Material,
    extension: None,
    blending: NormalBlending,
    side: FrontSide,
    vertex_colors: false,
    opacity: 1.0,
    transparent: false,
    alpha_hash: false,
    blend_src: SrcAlphaFactor,
    blend_dst: OneMinusSrcAlphaFactor,
    blend_equation: AddEquation,
    blend_src_alpha: None,
    blend_dst_alpha: None,
    blend_equation_alpha: None,
    blend_color: @math.Color::new(0.0, 0.0, 0.0),
    blend_alpha: 0.0,
    depth_func: LessEqualDepth,
    depth_test: true,
    depth_write: true,
    stencil_write_mask: 0xff,
    stencil_func: AlwaysStencilFunc,
    stencil_ref: 0,
    stencil_func_mask: 0xff,
    stencil_fail: KeepStencilOp,
    stencil_z_fail: KeepStencilOp,
    stencil_z_pass: KeepStencilOp,
    stencil_write: false,
    clipping_planes: None,
    clip_intersection: false,
    clip_shadows: false,
    shadow_side: None,
    color_write: true,
    precision: None,
    polygon_offset: false,
    polygon_offset_factor: 0.0,
    polygon_offset_units: 0.0,
    dithering: false,
    alpha_to_coverage: false,
    premultiplied_alpha: false,
    force_single_pass: false,
    allow_override: true,
    visible: true,
    tone_mapped: true,
    user_data: JsValue::object(),
    version: 0,
    _alpha_test: 0.0,
    on_before_render: (_, _, _, _, _, _) => (),
    on_before_compile: None,
    custom_program_cache_key: None,
    defines: None,
    color: None,
    map: None,
    linewidth: None,
    linecap: None,
    linejoin: None,
    fog: None,
    scale: None,
    dash_size: None,
    gap_size: None,
    light_map: None,
    light_map_intensity: None,
    ao_map: None,
    ao_map_intensity: None,
    specular_map: None,
    alpha_map: None,
    env_map: None,
    env_map_rotation: None,
    env_map_intensity: None,
    combine: None,
    reflectivity: None,
    refraction_ratio: None,
    wireframe: None,
    wireframe_linewidth: None,
    wireframe_linecap: None,
    wireframe_linejoin: None,
    depth_packing: None,
    displacement_map: None,
    displacement_scale: None,
    displacement_bias: None,
    emissive: None,
    emissive_intensity: None,
    emissive_map: None,
    bump_map: None,
    bump_scale: None,
    normal_map: None,
    normal_map_type: None,
    normal_scale: None,
    flat_shading: None,
    matcap: None,
    gradient_map: None,
    specular: None,
    shininess: None,
    roughness: None,
    metalness: None,
    roughness_map: None,
    metalness_map: None,
    size: None,
    size_attenuation: None,
    rotation: None,
    uniforms: None,
    uniforms_groups: None,
    vertex_shader: None,
    fragment_shader: None,
    lights: None,
    clipping: None,
    extensions: None,
    default_attribute_values: None,
    index0_attribute_name: None,
    uniforms_need_update: None,
    glsl_version: None,
    anisotropy_rotation: None,
    anisotropy_map: None,
    clearcoat_map: None,
    clearcoat_roughness: None,
    clearcoat_roughness_map: None,
    clearcoat_normal_scale: None,
    clearcoat_normal_map: None,
    diffuse_roughness_map: None,
    ior: None,
    iridescence_map: None,
    iridescence_ior: None,
    iridescence_thickness_minimum: None,
    iridescence_thickness_maximum: None,
    iridescence_thickness_map: None,
    sheen_color: None,
    sheen_color_map: None,
    sheen_roughness: None,
    sheen_roughness_map: None,
    transmission_map: None,
    thickness: None,
    thickness_map: None,
    attenuation_distance: None,
    attenuation_color: None,
    specular_intensity: None,
    specular_intensity_map: None,
    specular_color: None,
    specular_color_map: None,
    _anisotropy: None,
    _clearcoat: None,
    _diffuse_roughness: None,
    _dispersion: None,
    _iridescence: None,
    _retroreflectivity: None,
    _sheen: None,
    _transmission: None,
  }
}

///|
pub impl EventSource for Material with fn event_dispatcher(self) {
  self.dispatcher
}

///|
pub impl EventSource for Material with fn event_target(self) {
  Material(self)
}

///|
pub extend Material with EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
/// Upstream's `alphaTest` getter.
pub fn Material::alpha_test(self : Material) -> Double {
  self._alpha_test
}

///|
/// Upstream's `alphaTest` setter: crossing zero changes the shader, so bumps `version`.
pub fn Material::set_alpha_test(self : Material, value : Double) -> Unit {
  if (self._alpha_test > 0.0) != (value > 0.0) {
    self.version += 1
  }
  self._alpha_test = value
}

///|
/// Upstream's `needsUpdate` setter.
pub fn Material::set_needs_update(self : Material, value : Bool) -> Unit {
  if value {
    self.version += 1
  }
}

///|
/// Upstream's `customProgramCacheKey()`. The field of the same name is the instance
/// override, which wins over a subclass method as a JS own property does.
pub fn Material::custom_program_cache_key(self : Material) -> String {
  if self.custom_program_cache_key is Some(key) {
    return key()
  }
  if self.extension is Some(extension) &&
    extension.custom_program_cache_key(self) is Some(key) {
    return key
  }
  match self.on_before_compile {
    Some(callback) => material_function_to_string(JsValue::of(callback))
    None => "onBeforeCompile( /* shaderobject, renderer */ ) {}"
  }
}

///|
/// Per class, the properties upstream sets to `null`, which `None` cannot tell from unset.
fn material_null_properties(material_type : MaterialType) -> Array[String] {
  match material_type {
    Material | ShadowMaterial => []
    LineBasicMaterial | LineDashedMaterial => ["map"]
    MeshBasicMaterial =>
      ["map", "lightMap", "aoMap", "specularMap", "alphaMap", "envMap"]
    MeshDepthMaterial | MeshDistanceMaterial =>
      ["map", "alphaMap", "displacementMap"]
    MeshLambertMaterial | MeshPhongMaterial =>
      [
        "map", "lightMap", "aoMap", "emissiveMap", "bumpMap", "normalMap", "displacementMap",
        "specularMap", "alphaMap", "envMap",
      ]
    MeshMatcapMaterial =>
      ["matcap", "map", "bumpMap", "normalMap", "displacementMap", "alphaMap"]
    MeshNormalMaterial => ["bumpMap", "normalMap", "displacementMap"]
    MeshStandardMaterial =>
      [
        "map", "lightMap", "aoMap", "emissiveMap", "bumpMap", "normalMap", "displacementMap",
        "roughnessMap", "metalnessMap", "alphaMap", "envMap",
      ]
    MeshPhysicalMaterial =>
      [
        "map", "lightMap", "aoMap", "emissiveMap", "bumpMap", "normalMap", "displacementMap",
        "roughnessMap", "metalnessMap", "alphaMap", "envMap", "anisotropyMap", "clearcoatMap",
        "clearcoatRoughnessMap", "clearcoatNormalMap", "diffuseRoughnessMap", "iridescenceMap",
        "iridescenceThicknessMap", "sheenColorMap", "sheenRoughnessMap", "transmissionMap",
        "thicknessMap", "specularIntensityMap", "specularColorMap",
      ]
    MeshToonMaterial =>
      [
        "map", "gradientMap", "lightMap", "aoMap", "emissiveMap", "bumpMap", "normalMap",
        "displacementMap", "alphaMap",
      ]
    PointsMaterial | SpriteMaterial => ["map", "alphaMap"]
    RawShaderMaterial | ShaderMaterial => ["glslVersion"]
  }
}

///|
/// Whether `this[ key ] !== undefined`.
fn Material::has_value(self : Material, key : String) -> Bool {
  let defined = match key {
    "id"
    | "type"
    | "alphaTest"
    | "blendColor"
    | "clippingPlanes"
    | "userData"
    | "onBeforeRender"
    | "onBeforeCompile"
    | "customProgramCacheKey"
    | "uuid"
    | "name"
    | "blending"
    | "side"
    | "vertexColors"
    | "opacity"
    | "transparent"
    | "alphaHash"
    | "blendSrc"
    | "blendDst"
    | "blendEquation"
    | "blendSrcAlpha"
    | "blendDstAlpha"
    | "blendEquationAlpha"
    | "blendAlpha"
    | "depthFunc"
    | "depthTest"
    | "depthWrite"
    | "stencilWriteMask"
    | "stencilFunc"
    | "stencilRef"
    | "stencilFuncMask"
    | "stencilFail"
    | "stencilZFail"
    | "stencilZPass"
    | "stencilWrite"
    | "clipIntersection"
    | "clipShadows"
    | "shadowSide"
    | "colorWrite"
    | "precision"
    | "polygonOffset"
    | "polygonOffsetFactor"
    | "polygonOffsetUnits"
    | "dithering"
    | "alphaToCoverage"
    | "premultipliedAlpha"
    | "forceSinglePass"
    | "allowOverride"
    | "visible"
    | "toneMapped"
    | "version" => true
    "reflectivity" => self.reflectivity() is Some(_)
    "defines" => self.defines is Some(_)
    "color" => self.color is Some(_)
    "map" => self.map is Some(_)
    "linewidth" => self.linewidth is Some(_)
    "linecap" => self.linecap is Some(_)
    "linejoin" => self.linejoin is Some(_)
    "fog" => self.fog is Some(_)
    "scale" => self.scale is Some(_)
    "dashSize" => self.dash_size is Some(_)
    "gapSize" => self.gap_size is Some(_)
    "lightMap" => self.light_map is Some(_)
    "lightMapIntensity" => self.light_map_intensity is Some(_)
    "aoMap" => self.ao_map is Some(_)
    "aoMapIntensity" => self.ao_map_intensity is Some(_)
    "specularMap" => self.specular_map is Some(_)
    "alphaMap" => self.alpha_map is Some(_)
    "envMap" => self.env_map is Some(_)
    "envMapRotation" => self.env_map_rotation is Some(_)
    "envMapIntensity" => self.env_map_intensity is Some(_)
    "combine" => self.combine is Some(_)
    "refractionRatio" => self.refraction_ratio is Some(_)
    "wireframe" => self.wireframe is Some(_)
    "wireframeLinewidth" => self.wireframe_linewidth is Some(_)
    "wireframeLinecap" => self.wireframe_linecap is Some(_)
    "wireframeLinejoin" => self.wireframe_linejoin is Some(_)
    "depthPacking" => self.depth_packing is Some(_)
    "displacementMap" => self.displacement_map is Some(_)
    "displacementScale" => self.displacement_scale is Some(_)
    "displacementBias" => self.displacement_bias is Some(_)
    "emissive" => self.emissive is Some(_)
    "emissiveIntensity" => self.emissive_intensity is Some(_)
    "emissiveMap" => self.emissive_map is Some(_)
    "bumpMap" => self.bump_map is Some(_)
    "bumpScale" => self.bump_scale is Some(_)
    "normalMap" => self.normal_map is Some(_)
    "normalMapType" => self.normal_map_type is Some(_)
    "normalScale" => self.normal_scale is Some(_)
    "flatShading" => self.flat_shading is Some(_)
    "matcap" => self.matcap is Some(_)
    "gradientMap" => self.gradient_map is Some(_)
    "specular" => self.specular is Some(_)
    "shininess" => self.shininess is Some(_)
    "roughness" => self.roughness is Some(_)
    "metalness" => self.metalness is Some(_)
    "roughnessMap" => self.roughness_map is Some(_)
    "metalnessMap" => self.metalness_map is Some(_)
    "size" => self.size is Some(_)
    "sizeAttenuation" => self.size_attenuation is Some(_)
    "rotation" => self.rotation is Some(_)
    "uniforms" => self.uniforms is Some(_)
    "uniformsGroups" => self.uniforms_groups is Some(_)
    "vertexShader" => self.vertex_shader is Some(_)
    "fragmentShader" => self.fragment_shader is Some(_)
    "lights" => self.lights is Some(_)
    "clipping" => self.clipping is Some(_)
    "extensions" => self.extensions is Some(_)
    "defaultAttributeValues" => self.default_attribute_values is Some(_)
    "index0AttributeName" => self.index0_attribute_name is Some(_)
    "uniformsNeedUpdate" => self.uniforms_need_update is Some(_)
    "glslVersion" => self.glsl_version is Some(_)
    "anisotropyRotation" => self.anisotropy_rotation is Some(_)
    "anisotropyMap" => self.anisotropy_map is Some(_)
    "clearcoatMap" => self.clearcoat_map is Some(_)
    "clearcoatRoughness" => self.clearcoat_roughness is Some(_)
    "clearcoatRoughnessMap" => self.clearcoat_roughness_map is Some(_)
    "clearcoatNormalScale" => self.clearcoat_normal_scale is Some(_)
    "clearcoatNormalMap" => self.clearcoat_normal_map is Some(_)
    "diffuseRoughnessMap" => self.diffuse_roughness_map is Some(_)
    "ior" => self.ior is Some(_)
    "iridescenceMap" => self.iridescence_map is Some(_)
    "iridescenceIOR" => self.iridescence_ior is Some(_)
    "iridescenceThicknessMinimum" =>
      self.iridescence_thickness_minimum is Some(_)
    "iridescenceThicknessMaximum" =>
      self.iridescence_thickness_maximum is Some(_)
    "iridescenceThicknessMap" => self.iridescence_thickness_map is Some(_)
    "sheenColor" => self.sheen_color is Some(_)
    "sheenColorMap" => self.sheen_color_map is Some(_)
    "sheenRoughness" => self.sheen_roughness is Some(_)
    "sheenRoughnessMap" => self.sheen_roughness_map is Some(_)
    "transmissionMap" => self.transmission_map is Some(_)
    "thickness" => self.thickness is Some(_)
    "thicknessMap" => self.thickness_map is Some(_)
    "attenuationDistance" => self.attenuation_distance is Some(_)
    "attenuationColor" => self.attenuation_color is Some(_)
    "specularIntensity" => self.specular_intensity is Some(_)
    "specularIntensityMap" => self.specular_intensity_map is Some(_)
    "specularColor" => self.specular_color is Some(_)
    "specularColorMap" => self.specular_color_map is Some(_)
    "anisotropy" => self._anisotropy is Some(_)
    "clearcoat" => self._clearcoat is Some(_)
    "diffuseRoughness" => self._diffuse_roughness is Some(_)
    "dispersion" => self._dispersion is Some(_)
    "iridescence" => self._iridescence is Some(_)
    "retroreflectivity" => self._retroreflectivity is Some(_)
    "sheen" => self._sheen is Some(_)
    "transmission" => self._transmission is Some(_)
    _ => false
  }
  defined || material_null_properties(self.material_type).contains(key)
}

///|
/// The property `key` if it holds a color. `None` also covers an unset color property.
fn Material::color_value(self : Material, key : String) -> @math.Color? {
  match key {
    "blendColor" => Some(self.blend_color)
    "color" => self.color
    "emissive" => self.emissive
    "specular" => self.specular
    "sheenColor" => self.sheen_color
    "attenuationColor" => self.attenuation_color
    "specularColor" => self.specular_color
    _ => None
  }
}

///|
/// `this[ key ] = value`. Returns false if the typed field cannot hold `value`.
fn Material::assign_value(
  self : Material,
  key : String,
  value : MaterialValue,
) -> Bool {
  match (key, value) {
    ("id", _) => abort("Material: 'id' is read-only.")
    ("type", String(v)) => self.type_ = v
    ("alphaTest", Number(v)) => self.set_alpha_test(v)
    ("reflectivity", Number(v)) => self.set_reflectivity(v)
    ("clippingPlanes", Planes(v)) => self.clipping_planes = Some(v)
    ("clippingPlanes", Null) => self.clipping_planes = None
    ("userData", Object(v)) => self.user_data = v
    ("onBeforeRender", OnBeforeRender(v)) => self.on_before_render = v
    ("onBeforeCompile", OnBeforeCompile(v)) => self.on_before_compile = Some(v)
    ("customProgramCacheKey", CustomProgramCacheKey(v)) =>
      self.custom_program_cache_key = Some(v)
    ("uuid", String(v)) => self.uuid = v
    ("name", String(v)) => self.name = v
    ("blending", Number(v)) => self.blending = v.to_int()
    ("side", Number(v)) => self.side = v.to_int()
    ("vertexColors", Bool(v)) => self.vertex_colors = v
    ("opacity", Number(v)) => self.opacity = v
    ("transparent", Bool(v)) => self.transparent = v
    ("alphaHash", Bool(v)) => self.alpha_hash = v
    ("blendSrc", Number(v)) => self.blend_src = v.to_int()
    ("blendDst", Number(v)) => self.blend_dst = v.to_int()
    ("blendEquation", Number(v)) => self.blend_equation = v.to_int()
    ("blendSrcAlpha", Number(v)) => self.blend_src_alpha = Some(v.to_int())
    ("blendSrcAlpha", Null) => self.blend_src_alpha = None
    ("blendDstAlpha", Number(v)) => self.blend_dst_alpha = Some(v.to_int())
    ("blendDstAlpha", Null) => self.blend_dst_alpha = None
    ("blendEquationAlpha", Number(v)) =>
      self.blend_equation_alpha = Some(v.to_int())
    ("blendEquationAlpha", Null) => self.blend_equation_alpha = None
    ("blendAlpha", Number(v)) => self.blend_alpha = v
    ("depthFunc", Number(v)) => self.depth_func = v.to_int()
    ("depthTest", Bool(v)) => self.depth_test = v
    ("depthWrite", Bool(v)) => self.depth_write = v
    ("stencilWriteMask", Number(v)) => self.stencil_write_mask = v.to_int()
    ("stencilFunc", Number(v)) => self.stencil_func = v.to_int()
    ("stencilRef", Number(v)) => self.stencil_ref = v.to_int()
    ("stencilFuncMask", Number(v)) => self.stencil_func_mask = v.to_int()
    ("stencilFail", Number(v)) => self.stencil_fail = v.to_int()
    ("stencilZFail", Number(v)) => self.stencil_z_fail = v.to_int()
    ("stencilZPass", Number(v)) => self.stencil_z_pass = v.to_int()
    ("stencilWrite", Bool(v)) => self.stencil_write = v
    ("clipIntersection", Bool(v)) => self.clip_intersection = v
    ("clipShadows", Bool(v)) => self.clip_shadows = v
    ("shadowSide", Number(v)) => self.shadow_side = Some(v.to_int())
    ("shadowSide", Null) => self.shadow_side = None
    ("colorWrite", Bool(v)) => self.color_write = v
    ("precision", String(v)) => self.precision = Some(v)
    ("precision", Null) => self.precision = None
    ("polygonOffset", Bool(v)) => self.polygon_offset = v
    ("polygonOffsetFactor", Number(v)) => self.polygon_offset_factor = v
    ("polygonOffsetUnits", Number(v)) => self.polygon_offset_units = v
    ("dithering", Bool(v)) => self.dithering = v
    ("alphaToCoverage", Bool(v)) => self.alpha_to_coverage = v
    ("premultipliedAlpha", Bool(v)) => self.premultiplied_alpha = v
    ("forceSinglePass", Bool(v)) => self.force_single_pass = v
    ("allowOverride", Bool(v)) => self.allow_override = v
    ("visible", Bool(v)) => self.visible = v
    ("toneMapped", Bool(v)) => self.tone_mapped = v
    ("version", Number(v)) => self.version = v.to_int()
    ("defines", Defines(v)) => self.defines = Some(v)
    ("map", Texture(v)) => self.map = Some(v)
    ("map", Null) => self.map = None
    ("linewidth", Number(v)) => self.linewidth = Some(v)
    ("linecap", String(v)) => self.linecap = Some(v)
    ("linejoin", String(v)) => self.linejoin = Some(v)
    ("fog", Bool(v)) => self.fog = Some(v)
    ("scale", Number(v)) => self.scale = Some(v)
    ("dashSize", Number(v)) => self.dash_size = Some(v)
    ("gapSize", Number(v)) => self.gap_size = Some(v)
    ("lightMap", Texture(v)) => self.light_map = Some(v)
    ("lightMap", Null) => self.light_map = None
    ("lightMapIntensity", Number(v)) => self.light_map_intensity = Some(v)
    ("aoMap", Texture(v)) => self.ao_map = Some(v)
    ("aoMap", Null) => self.ao_map = None
    ("aoMapIntensity", Number(v)) => self.ao_map_intensity = Some(v)
    ("specularMap", Texture(v)) => self.specular_map = Some(v)
    ("specularMap", Null) => self.specular_map = None
    ("alphaMap", Texture(v)) => self.alpha_map = Some(v)
    ("alphaMap", Null) => self.alpha_map = None
    ("envMap", Texture(v)) => self.env_map = Some(v)
    ("envMap", Null) => self.env_map = None
    ("envMapRotation", Null) => self.env_map_rotation = None
    ("envMapIntensity", Number(v)) => self.env_map_intensity = Some(v)
    ("combine", Number(v)) => self.combine = Some(v.to_int())
    ("refractionRatio", Number(v)) => self.refraction_ratio = Some(v)
    ("wireframe", Bool(v)) => self.wireframe = Some(v)
    ("wireframeLinewidth", Number(v)) => self.wireframe_linewidth = Some(v)
    ("wireframeLinecap", String(v)) => self.wireframe_linecap = Some(v)
    ("wireframeLinejoin", String(v)) => self.wireframe_linejoin = Some(v)
    ("depthPacking", Number(v)) => self.depth_packing = Some(v.to_int())
    ("displacementMap", Texture(v)) => self.displacement_map = Some(v)
    ("displacementMap", Null) => self.displacement_map = None
    ("displacementScale", Number(v)) => self.displacement_scale = Some(v)
    ("displacementBias", Number(v)) => self.displacement_bias = Some(v)
    ("emissiveIntensity", Number(v)) => self.emissive_intensity = Some(v)
    ("emissiveMap", Texture(v)) => self.emissive_map = Some(v)
    ("emissiveMap", Null) => self.emissive_map = None
    ("bumpMap", Texture(v)) => self.bump_map = Some(v)
    ("bumpMap", Null) => self.bump_map = None
    ("bumpScale", Number(v)) => self.bump_scale = Some(v)
    ("normalMap", Texture(v)) => self.normal_map = Some(v)
    ("normalMap", Null) => self.normal_map = None
    ("normalMapType", Number(v)) => self.normal_map_type = Some(v.to_int())
    ("normalScale", Null) => self.normal_scale = None
    ("flatShading", Bool(v)) => self.flat_shading = Some(v)
    ("matcap", Texture(v)) => self.matcap = Some(v)
    ("matcap", Null) => self.matcap = None
    ("gradientMap", Texture(v)) => self.gradient_map = Some(v)
    ("gradientMap", Null) => self.gradient_map = None
    ("shininess", Number(v)) => self.shininess = Some(v)
    ("roughness", Number(v)) => self.roughness = Some(v)
    ("metalness", Number(v)) => self.metalness = Some(v)
    ("roughnessMap", Texture(v)) => self.roughness_map = Some(v)
    ("roughnessMap", Null) => self.roughness_map = None
    ("metalnessMap", Texture(v)) => self.metalness_map = Some(v)
    ("metalnessMap", Null) => self.metalness_map = None
    ("size", Number(v)) => self.size = Some(v)
    ("sizeAttenuation", Bool(v)) => self.size_attenuation = Some(v)
    ("rotation", Number(v)) => self.rotation = Some(v)
    ("uniforms", Uniforms(v)) => self.uniforms = Some(v)
    ("uniformsGroups", UniformsGroups(v)) => self.uniforms_groups = Some(v)
    ("vertexShader", String(v)) => self.vertex_shader = Some(v)
    ("fragmentShader", String(v)) => self.fragment_shader = Some(v)
    ("lights", Bool(v)) => self.lights = Some(v)
    ("clipping", Bool(v)) => self.clipping = Some(v)
    ("extensions", Extensions(v)) => self.extensions = Some(v)
    ("defaultAttributeValues", AttributeValues(v)) =>
      self.default_attribute_values = Some(v)
    ("index0AttributeName", String(v)) => self.index0_attribute_name = Some(v)
    ("uniformsNeedUpdate", Bool(v)) => self.uniforms_need_update = Some(v)
    ("glslVersion", String(v)) => self.glsl_version = Some(v)
    ("glslVersion", Null) => self.glsl_version = None
    ("anisotropyRotation", Number(v)) => self.anisotropy_rotation = Some(v)
    ("anisotropyMap", Texture(v)) => self.anisotropy_map = Some(v)
    ("anisotropyMap", Null) => self.anisotropy_map = None
    ("clearcoatMap", Texture(v)) => self.clearcoat_map = Some(v)
    ("clearcoatMap", Null) => self.clearcoat_map = None
    ("clearcoatRoughness", Number(v)) => self.clearcoat_roughness = Some(v)
    ("clearcoatRoughnessMap", Texture(v)) =>
      self.clearcoat_roughness_map = Some(v)
    ("clearcoatRoughnessMap", Null) => self.clearcoat_roughness_map = None
    ("clearcoatNormalScale", Null) => self.clearcoat_normal_scale = None
    ("clearcoatNormalMap", Texture(v)) => self.clearcoat_normal_map = Some(v)
    ("clearcoatNormalMap", Null) => self.clearcoat_normal_map = None
    ("diffuseRoughnessMap", Texture(v)) => self.diffuse_roughness_map = Some(v)
    ("diffuseRoughnessMap", Null) => self.diffuse_roughness_map = None
    ("ior", Number(v)) => self.ior = Some(v)
    ("iridescenceMap", Texture(v)) => self.iridescence_map = Some(v)
    ("iridescenceMap", Null) => self.iridescence_map = None
    ("iridescenceIOR", Number(v)) => self.iridescence_ior = Some(v)
    ("iridescenceThicknessMinimum", Number(v)) =>
      self.iridescence_thickness_minimum = Some(v)
    ("iridescenceThicknessMaximum", Number(v)) =>
      self.iridescence_thickness_maximum = Some(v)
    ("iridescenceThicknessMap", Texture(v)) =>
      self.iridescence_thickness_map = Some(v)
    ("iridescenceThicknessMap", Null) => self.iridescence_thickness_map = None
    ("sheenColorMap", Texture(v)) => self.sheen_color_map = Some(v)
    ("sheenColorMap", Null) => self.sheen_color_map = None
    ("sheenRoughness", Number(v)) => self.sheen_roughness = Some(v)
    ("sheenRoughnessMap", Texture(v)) => self.sheen_roughness_map = Some(v)
    ("sheenRoughnessMap", Null) => self.sheen_roughness_map = None
    ("transmissionMap", Texture(v)) => self.transmission_map = Some(v)
    ("transmissionMap", Null) => self.transmission_map = None
    ("thickness", Number(v)) => self.thickness = Some(v)
    ("thicknessMap", Texture(v)) => self.thickness_map = Some(v)
    ("thicknessMap", Null) => self.thickness_map = None
    ("attenuationDistance", Number(v)) => self.attenuation_distance = Some(v)
    ("specularIntensity", Number(v)) => self.specular_intensity = Some(v)
    ("specularIntensityMap", Texture(v)) =>
      self.specular_intensity_map = Some(v)
    ("specularIntensityMap", Null) => self.specular_intensity_map = None
    ("specularColorMap", Texture(v)) => self.specular_color_map = Some(v)
    ("specularColorMap", Null) => self.specular_color_map = None
    ("anisotropy", Number(v)) => self.set_anisotropy(v)
    ("clearcoat", Number(v)) => self.set_clearcoat(v)
    ("diffuseRoughness", Number(v)) => self.set_diffuse_roughness(v)
    ("dispersion", Number(v)) => self.set_dispersion(v)
    ("iridescence", Number(v)) => self.set_iridescence(v)
    ("retroreflectivity", Number(v)) => self.set_retroreflectivity(v)
    ("sheen", Number(v)) => self.set_sheen(v)
    ("transmission", Number(v)) => self.set_transmission(v)
    _ => return false
  }
  true
}

///|
/// `Color.set( value )` with one argument, which ignores anything else.
fn material_set_color(color : @math.Color, value : MaterialValue) -> Unit {
  match value {
    Color(v) => ignore(color.copy(v))
    Number(v) => ignore(color.set_hex(v.to_int()))
    String(v) => ignore(color.set_style(v))
    _ => ()
  }
}

///|
/// Upstream `setValues`. Keys are upstream's property names, such as `"vertexColors"`.
pub fn Material::set_values(
  self : Material,
  values? : Map[String, MaterialValue],
) -> Unit {
  guard values is Some(values) else { return }
  for key, new_value in values {
    if new_value is Undefined {
      warn("Material: parameter '\{key}' has value of undefined.")
      continue
    }
    if !self.has_value(key) {
      warn("Material: '\{key}' is not a property of THREE.\{self.type_}.")
      continue
    }
    match (self.color_value(key), key, new_value) {
      (Some(color), _, _) => material_set_color(color, new_value)
      (_, "normalScale", Vector2(v)) if self.normal_scale is Some(current) =>
        ignore(current.copy(v))
      (_, "clearcoatNormalScale", Vector2(v)) if self.clearcoat_normal_scale
        is Some(current) => ignore(current.copy(v))
      (_, "envMapRotation", Euler(v)) if self.env_map_rotation is Some(current) =>
        ignore(current.copy(v))
      _ =>
        if !self.assign_value(key, new_value) {
          warn("Material: '\{key}' cannot hold the given value.")
        }
    }
  }
}

///|
/// As `JSON.stringify` writes it: `Json::stringify` would print the invalid `Infinity`.
fn material_json_number(value : Double) -> Json {
  @math.json_number(value)
}

///|
fn material_json_numbers(values : Array[Double]) -> Json {
  Json::array(values.map(material_json_number))
}

///|
fn material_json_nullable(value : Int32?) -> Json {
  match value {
    Some(value) => json_int(value)
    None => Json::null()
  }
}

///|
fn material_put_number(
  data : Map[String, Json],
  key : String,
  value : Double?,
) -> Unit {
  if value is Some(value) {
    data[key] = material_json_number(value)
  }
}

///|
fn material_put_int(
  data : Map[String, Json],
  key : String,
  value : Int32?,
) -> Unit {
  if value is Some(value) {
    data[key] = json_int(value)
  }
}

///|
fn material_put_bool(
  data : Map[String, Json],
  key : String,
  value : Bool?,
) -> Unit {
  if value is Some(value) {
    data[key] = Json::boolean(value)
  }
}

///|
fn material_put_string(
  data : Map[String, Json],
  key : String,
  value : String?,
) -> Unit {
  if value is Some(value) {
    data[key] = Json::string(value)
  }
}

///|
fn material_put_color(
  data : Map[String, Json],
  key : String,
  value : @math.Color?,
) -> Unit {
  if value is Some(value) {
    data[key] = json_int(value.get_hex())
  }
}

///|
/// `value.toJSON( meta ).uuid`.
fn material_texture_uuid(texture : Texture, meta : ToJsonMeta?) -> Json {
  guard texture.to_json(meta?) is { "uuid": uuid, .. } else {
    abort("Material: Texture::to_json has no uuid")
  }
  uuid
}

///|
fn material_put_texture(
  data : Map[String, Json],
  key : String,
  value : Texture?,
  meta : ToJsonMeta,
) -> Unit {
  if value is Some(value) {
    data[key] = material_texture_uuid(value, Some(meta))
  }
}

///|
pub fn Material::to_json(self : Material, meta? : ToJsonMeta) -> Json {
  let is_root_object = meta is None
  let root_meta = match meta {
    Some(meta) => meta
    None => ToJsonMeta::new()
  }
  let data : Map[String, Json] = Map([])
  data["metadata"] = Json::object(
    Map([
      ("version", Json::number(4.7)),
      ("type", Json::string("Material")),
      ("generator", Json::string("Material.toJSON")),
    ]),
  )

  // standard Material serialization
  data["uuid"] = Json::string(self.uuid)
  data["type"] = Json::string(self.type_)
  data["blending"] = json_int(self.blending)
  data["side"] = json_int(self.side)
  data["shadowSide"] = material_json_nullable(self.shadow_side)
  data["vertexColors"] = Json::boolean(self.vertex_colors)
  data["opacity"] = material_json_number(self.opacity)
  data["transparent"] = Json::boolean(self.transparent)
  data["blendSrc"] = json_int(self.blend_src)
  data["blendDst"] = json_int(self.blend_dst)
  data["blendEquation"] = json_int(self.blend_equation)
  data["blendSrcAlpha"] = material_json_nullable(self.blend_src_alpha)
  data["blendDstAlpha"] = material_json_nullable(self.blend_dst_alpha)
  data["blendEquationAlpha"] = material_json_nullable(self.blend_equation_alpha)
  data["blendColor"] = json_int(self.blend_color.get_hex())
  data["blendAlpha"] = material_json_number(self.blend_alpha)
  data["depthFunc"] = json_int(self.depth_func)
  data["depthTest"] = Json::boolean(self.depth_test)
  data["depthWrite"] = Json::boolean(self.depth_write)
  data["colorWrite"] = Json::boolean(self.color_write)
  data["clipIntersection"] = Json::boolean(self.clip_intersection)
  data["clipShadows"] = Json::boolean(self.clip_shadows)
  data["stencilWriteMask"] = json_int(self.stencil_write_mask)
  data["stencilFunc"] = json_int(self.stencil_func)
  data["stencilRef"] = json_int(self.stencil_ref)
  data["stencilFuncMask"] = json_int(self.stencil_func_mask)
  data["stencilFail"] = json_int(self.stencil_fail)
  data["stencilZFail"] = json_int(self.stencil_z_fail)
  data["stencilZPass"] = json_int(self.stencil_z_pass)
  data["stencilWrite"] = Json::boolean(self.stencil_write)
  data["polygonOffset"] = Json::boolean(self.polygon_offset)
  data["polygonOffsetFactor"] = material_json_number(self.polygon_offset_factor)
  data["polygonOffsetUnits"] = material_json_number(self.polygon_offset_units)
  data["dithering"] = Json::boolean(self.dithering)
  data["alphaTest"] = material_json_number(self.alpha_test())
  data["alphaHash"] = Json::boolean(self.alpha_hash)
  data["alphaToCoverage"] = Json::boolean(self.alpha_to_coverage)
  data["premultipliedAlpha"] = Json::boolean(self.premultiplied_alpha)
  data["forceSinglePass"] = Json::boolean(self.force_single_pass)
  data["allowOverride"] = Json::boolean(self.allow_override)
  data["visible"] = Json::boolean(self.visible)
  data["toneMapped"] = Json::boolean(self.tone_mapped)
  data["name"] = Json::string(self.name)
  material_put_color(data, "color", self.color)
  material_put_number(data, "roughness", self.roughness)
  material_put_number(data, "metalness", self.metalness)
  material_put_number(data, "sheen", self.sheen())
  material_put_color(data, "sheenColor", self.sheen_color)
  material_put_number(data, "sheenRoughness", self.sheen_roughness)
  material_put_color(data, "emissive", self.emissive)
  material_put_number(data, "emissiveIntensity", self.emissive_intensity)
  material_put_color(data, "specular", self.specular)
  material_put_number(data, "specularIntensity", self.specular_intensity)
  material_put_color(data, "specularColor", self.specular_color)
  material_put_number(data, "shininess", self.shininess)
  material_put_number(data, "clearcoat", self.clearcoat())
  material_put_number(data, "clearcoatRoughness", self.clearcoat_roughness)
  material_put_number(data, "diffuseRoughness", self.diffuse_roughness())
  material_put_texture(
    data,
    "diffuseRoughnessMap",
    self.diffuse_roughness_map,
    root_meta,
  )
  material_put_texture(data, "clearcoatMap", self.clearcoat_map, root_meta)
  material_put_texture(
    data,
    "clearcoatRoughnessMap",
    self.clearcoat_roughness_map,
    root_meta,
  )
  if self.clearcoat_normal_map is Some(_) {
    material_put_texture(
      data,
      "clearcoatNormalMap",
      self.clearcoat_normal_map,
      root_meta,
    )
    data["clearcoatNormalScale"] = material_json_numbers(
      self.clearcoat_normal_scale.unwrap().to_array(),
    )
  }
  material_put_texture(data, "sheenColorMap", self.sheen_color_map, root_meta)
  material_put_texture(
    data,
    "sheenRoughnessMap",
    self.sheen_roughness_map,
    root_meta,
  )
  material_put_number(data, "dispersion", self.dispersion())
  material_put_number(data, "retroreflectivity", self.retroreflectivity())
  material_put_number(data, "iridescence", self.iridescence())
  material_put_number(data, "iridescenceIOR", self.iridescence_ior)
  material_put_number(
    data,
    "iridescenceThicknessMinimum",
    self.iridescence_thickness_minimum,
  )
  material_put_number(
    data,
    "iridescenceThicknessMaximum",
    self.iridescence_thickness_maximum,
  )
  material_put_texture(data, "iridescenceMap", self.iridescence_map, root_meta)
  material_put_texture(
    data,
    "iridescenceThicknessMap",
    self.iridescence_thickness_map,
    root_meta,
  )
  material_put_number(data, "anisotropy", self.anisotropy())
  material_put_number(data, "anisotropyRotation", self.anisotropy_rotation)
  material_put_texture(data, "anisotropyMap", self.anisotropy_map, root_meta)
  material_put_texture(data, "map", self.map, root_meta)
  material_put_texture(data, "matcap", self.matcap, root_meta)
  material_put_texture(data, "alphaMap", self.alpha_map, root_meta)
  if self.light_map is Some(_) {
    material_put_texture(data, "lightMap", self.light_map, root_meta)
    material_put_number(data, "lightMapIntensity", self.light_map_intensity)
  }
  if self.ao_map is Some(_) {
    material_put_texture(data, "aoMap", self.ao_map, root_meta)
    material_put_number(data, "aoMapIntensity", self.ao_map_intensity)
  }
  if self.bump_map is Some(_) {
    material_put_texture(data, "bumpMap", self.bump_map, root_meta)
    material_put_number(data, "bumpScale", self.bump_scale)
  }
  if self.normal_map is Some(_) {
    material_put_texture(data, "normalMap", self.normal_map, root_meta)
    material_put_int(data, "normalMapType", self.normal_map_type)
    data["normalScale"] = material_json_numbers(
      self.normal_scale.unwrap().to_array(),
    )
  }
  if self.displacement_map is Some(_) {
    material_put_texture(
      data,
      "displacementMap",
      self.displacement_map,
      root_meta,
    )
    material_put_number(data, "displacementScale", self.displacement_scale)
    material_put_number(data, "displacementBias", self.displacement_bias)
  }
  material_put_texture(data, "roughnessMap", self.roughness_map, root_meta)
  material_put_texture(data, "metalnessMap", self.metalness_map, root_meta)
  material_put_texture(data, "emissiveMap", self.emissive_map, root_meta)
  material_put_texture(data, "specularMap", self.specular_map, root_meta)
  material_put_texture(
    data,
    "specularIntensityMap",
    self.specular_intensity_map,
    root_meta,
  )
  material_put_texture(
    data,
    "specularColorMap",
    self.specular_color_map,
    root_meta,
  )
  if self.env_map is Some(_) {
    material_put_texture(data, "envMap", self.env_map, root_meta)
    material_put_int(data, "combine", self.combine)
  }
  if self.env_map_rotation is Some(rotation) {
    data["envMapRotation"] = Json::array(rotation.to_array())
  }
  material_put_number(data, "envMapIntensity", self.env_map_intensity)
  material_put_number(data, "reflectivity", self.reflectivity())
  material_put_number(data, "refractionRatio", self.refraction_ratio)
  material_put_texture(data, "gradientMap", self.gradient_map, root_meta)
  material_put_number(data, "transmission", self.transmission())
  material_put_texture(
    data,
    "transmissionMap",
    self.transmission_map,
    root_meta,
  )
  material_put_number(data, "thickness", self.thickness)
  material_put_texture(data, "thicknessMap", self.thickness_map, root_meta)
  material_put_number(data, "attenuationDistance", self.attenuation_distance)
  material_put_color(data, "attenuationColor", self.attenuation_color)
  material_put_number(data, "size", self.size)
  material_put_bool(data, "sizeAttenuation", self.size_attenuation)
  if self.clipping_planes is Some(planes) && planes.length() > 0 {
    data["clippingPlanes"] = Json::array(planes.map(plane => plane.to_json()))
  }

  // rotation (SpriteMaterial)
  material_put_number(data, "rotation", self.rotation)

  // depthPacking (MeshDepthMaterial)
  material_put_int(data, "depthPacking", self.depth_packing)
  material_put_number(data, "linewidth", self.linewidth)
  material_put_string(data, "linecap", self.linecap)
  material_put_string(data, "linejoin", self.linejoin)
  material_put_number(data, "dashSize", self.dash_size)
  material_put_number(data, "gapSize", self.gap_size)
  material_put_number(data, "scale", self.scale)
  material_put_bool(data, "wireframe", self.wireframe)
  material_put_number(data, "wireframeLinewidth", self.wireframe_linewidth)
  material_put_string(data, "wireframeLinecap", self.wireframe_linecap)
  material_put_string(data, "wireframeLinejoin", self.wireframe_linejoin)
  material_put_bool(data, "flatShading", self.flat_shading)
  material_put_bool(data, "fog", self.fog)
  if self.user_data.key_count() > 0 {
    data["userData"] = self.user_data.to_json()
  }
  if is_root_object {
    let textures = to_json_extract_from_cache(root_meta.textures)
    let images = to_json_extract_from_cache(root_meta.images)
    if textures.length() > 0 {
      data["textures"] = Json::array(textures)
    }
    if images.length() > 0 {
      data["images"] = Json::array(images)
    }
  }

  // subclass additions: upstream makes these after `super.toJSON( meta )`, with the
  // caller's `meta`, not the root's
  if self.is_shader_material() {
    self.to_json_shader(meta, data)
  }
  if self.extension is Some(extension) {
    extension.to_json(self, meta, data)
  }
  Json::object(data)
}

///|
fn material_read_double(
  json : Map[String, Json],
  key : String,
  current : Double,
) -> Double {
  match json.get(key) {
    Some(Number(value, ..)) => value
    // upstream assigns the `null` that `JSON.stringify` wrote for a non-finite number
    Some(Null as value) => @math.json_to_number(value).unwrap()
    _ => current
  }
}

///|
fn material_read_int(
  json : Map[String, Json],
  key : String,
  current : Int32,
) -> Int32 {
  match json.get(key) {
    Some(Number(value, ..)) => value.to_int()
    _ => current
  }
}

///|
fn material_read_bool(
  json : Map[String, Json],
  key : String,
  current : Bool,
) -> Bool {
  match json.get(key) {
    Some(True) => true
    Some(False) => false
    _ => current
  }
}

///|
fn material_read_string(
  json : Map[String, Json],
  key : String,
  current : String,
) -> String {
  match json.get(key) {
    Some(String(value)) => value
    _ => current
  }
}

///|
/// A present key overwrites `current`: `null` (what `JSON.stringify` writes for a
/// non-finite number) as NaN, so that it is written back as `null`; other non-numbers
/// with `None`.
fn material_read_opt_double(
  json : Map[String, Json],
  key : String,
  current : Double?,
) -> Double? {
  match json.get(key) {
    None => current
    Some(value) => @math.json_to_number(value)
  }
}

///|
fn material_read_opt_int(
  json : Map[String, Json],
  key : String,
  current : Int32?,
) -> Int32? {
  match json.get(key) {
    None => current
    Some(Number(value, ..)) => Some(value.to_int())
    Some(_) => None
  }
}

///|
fn material_read_opt_bool(
  json : Map[String, Json],
  key : String,
  current : Bool?,
) -> Bool? {
  match json.get(key) {
    None => current
    Some(True) => Some(true)
    Some(False) => Some(false)
    Some(_) => None
  }
}

///|
fn material_read_opt_string(
  json : Map[String, Json],
  key : String,
  current : String?,
) -> String? {
  match json.get(key) {
    None => current
    Some(String(value)) => Some(value)
    Some(_) => None
  }
}

///|
/// `textures[ json.key ] || null`; `textures` being absent throws upstream.
fn material_read_texture(
  json : Map[String, Json],
  key : String,
  textures : Map[String, Texture]?,
  current : Texture?,
) -> Texture? {
  guard json.get(key) is Some(value) else { return current }
  guard textures is Some(textures) else {
    abort("Material::from_json: no textures for '\{key}'")
  }
  guard value is String(uuid) else { return None }
  textures.get(uuid)
}

///|
fn material_read_numbers(json : Json) -> Array[Double] {
  guard json is Array(values) else { abort("Material: expected an array") }
  values.map(value => {
    guard @math.json_to_number(value) is Some(number) else {
      abort("Material: expected an array of numbers")
    }
    number
  })
}

///|
fn material_read_color(
  json : Map[String, Json],
  key : String,
  color : @math.Color?,
) -> Unit {
  if json.get(key) is Some(Number(hex, ..)) && color is Some(color) {
    ignore(color.set_hex(hex.to_int()))
  }
}

///|
fn material_read_setter(
  json : Map[String, Json],
  key : String,
  setter : (Double) -> Unit,
) -> Unit {
  if json.get(key) is Some(value) && @math.json_to_number(value) is Some(value) {
    setter(value)
  }
}

///|
/// Upstream `fromJSON`. `textures` is keyed by uuid.
pub fn Material::from_json(
  self : Material,
  json : Json,
  textures? : Map[String, Texture],
) -> Material {
  guard json is Object(json) else {
    abort("Material::from_json: not an object")
  }
  self.uuid = material_read_string(json, "uuid", self.uuid)
  self.name = material_read_string(json, "name", self.name)
  material_read_color(json, "color", self.color)
  self.roughness = material_read_opt_double(json, "roughness", self.roughness)
  self.metalness = material_read_opt_double(json, "metalness", self.metalness)
  material_read_setter(json, "sheen", v => self.set_sheen(v))
  if json.get("sheenColor") is Some(Number(hex, ..)) {
    self.sheen_color = Some(
      @math.Color::new(1.0, 1.0, 1.0).set_hex(hex.to_int()),
    )
  }
  self.sheen_roughness = material_read_opt_double(
    json,
    "sheenRoughness",
    self.sheen_roughness,
  )
  material_read_color(json, "emissive", self.emissive)
  material_read_color(json, "specular", self.specular)
  self.specular_intensity = material_read_opt_double(
    json,
    "specularIntensity",
    self.specular_intensity,
  )
  material_read_color(json, "specularColor", self.specular_color)
  self.shininess = material_read_opt_double(json, "shininess", self.shininess)
  material_read_setter(json, "clearcoat", v => self.set_clearcoat(v))
  self.clearcoat_roughness = material_read_opt_double(
    json,
    "clearcoatRoughness",
    self.clearcoat_roughness,
  )
  material_read_setter(json, "diffuseRoughness", v => {
    self.set_diffuse_roughness(v)
  })
  material_read_setter(json, "dispersion", v => self.set_dispersion(v))
  material_read_setter(json, "retroreflectivity", v => {
    self.set_retroreflectivity(v)
  })
  material_read_setter(json, "iridescence", v => self.set_iridescence(v))
  self.iridescence_ior = material_read_opt_double(
    json,
    "iridescenceIOR",
    self.iridescence_ior,
  )
  self.iridescence_thickness_minimum = material_read_opt_double(
    json,
    "iridescenceThicknessMinimum",
    self.iridescence_thickness_minimum,
  )
  self.iridescence_thickness_maximum = material_read_opt_double(
    json,
    "iridescenceThicknessMaximum",
    self.iridescence_thickness_maximum,
  )
  // files written before r187
  if json.get("iridescenceThicknessRange") is Some(Array(range)) {
    guard range is [Number(minimum, ..), Number(maximum, ..), ..] else {
      abort("Material::from_json: bad iridescenceThicknessRange")
    }
    self.iridescence_thickness_minimum = Some(minimum)
    self.iridescence_thickness_maximum = Some(maximum)
  }
  material_read_setter(json, "transmission", v => self.set_transmission(v))
  self.thickness = material_read_opt_double(json, "thickness", self.thickness)
  self.attenuation_distance = material_read_opt_double(
    json,
    "attenuationDistance",
    self.attenuation_distance,
  )
  material_read_color(json, "attenuationColor", self.attenuation_color)
  material_read_setter(json, "anisotropy", v => self.set_anisotropy(v))
  self.anisotropy_rotation = material_read_opt_double(
    json,
    "anisotropyRotation",
    self.anisotropy_rotation,
  )
  self.fog = material_read_opt_bool(json, "fog", self.fog)
  self.flat_shading = material_read_opt_bool(
    json,
    "flatShading",
    self.flat_shading,
  )
  self.blending = material_read_int(json, "blending", self.blending)
  self.combine = material_read_opt_int(json, "combine", self.combine)
  self.side = material_read_int(json, "side", self.side)
  self.shadow_side = material_read_opt_int(json, "shadowSide", self.shadow_side)
  self.opacity = material_read_double(json, "opacity", self.opacity)
  self.transparent = material_read_bool(json, "transparent", self.transparent)
  material_read_setter(json, "alphaTest", v => self.set_alpha_test(v))
  self.alpha_hash = material_read_bool(json, "alphaHash", self.alpha_hash)
  self.depth_func = material_read_int(json, "depthFunc", self.depth_func)
  self.depth_test = material_read_bool(json, "depthTest", self.depth_test)
  self.depth_write = material_read_bool(json, "depthWrite", self.depth_write)
  self.color_write = material_read_bool(json, "colorWrite", self.color_write)
  if json.get("clippingPlanes") is Some(Array(planes)) {
    self.clipping_planes = Some(
      planes.map(plane => @math.Plane::new().from_json(plane)),
    )
  }
  self.clip_intersection = material_read_bool(
    json,
    "clipIntersection",
    self.clip_intersection,
  )
  self.clip_shadows = material_read_bool(json, "clipShadows", self.clip_shadows)
  self.depth_packing = material_read_opt_int(
    json,
    "depthPacking",
    self.depth_packing,
  )
  self.blend_src = material_read_int(json, "blendSrc", self.blend_src)
  self.blend_dst = material_read_int(json, "blendDst", self.blend_dst)
  self.blend_equation = material_read_int(
    json,
    "blendEquation",
    self.blend_equation,
  )
  self.blend_src_alpha = material_read_opt_int(
    json,
    "blendSrcAlpha",
    self.blend_src_alpha,
  )
  self.blend_dst_alpha = material_read_opt_int(
    json,
    "blendDstAlpha",
    self.blend_dst_alpha,
  )
  self.blend_equation_alpha = material_read_opt_int(
    json,
    "blendEquationAlpha",
    self.blend_equation_alpha,
  )
  material_read_color(json, "blendColor", Some(self.blend_color))
  self.blend_alpha = material_read_double(json, "blendAlpha", self.blend_alpha)
  self.stencil_write_mask = material_read_int(
    json,
    "stencilWriteMask",
    self.stencil_write_mask,
  )
  self.stencil_func = material_read_int(json, "stencilFunc", self.stencil_func)
  self.stencil_ref = material_read_int(json, "stencilRef", self.stencil_ref)
  self.stencil_func_mask = material_read_int(
    json,
    "stencilFuncMask",
    self.stencil_func_mask,
  )
  self.stencil_fail = material_read_int(json, "stencilFail", self.stencil_fail)
  self.stencil_z_fail = material_read_int(
    json,
    "stencilZFail",
    self.stencil_z_fail,
  )
  self.stencil_z_pass = material_read_int(
    json,
    "stencilZPass",
    self.stencil_z_pass,
  )
  self.stencil_write = material_read_bool(
    json,
    "stencilWrite",
    self.stencil_write,
  )
  self.wireframe = material_read_opt_bool(json, "wireframe", self.wireframe)
  self.wireframe_linewidth = material_read_opt_double(
    json,
    "wireframeLinewidth",
    self.wireframe_linewidth,
  )
  self.wireframe_linecap = material_read_opt_string(
    json,
    "wireframeLinecap",
    self.wireframe_linecap,
  )
  self.wireframe_linejoin = material_read_opt_string(
    json,
    "wireframeLinejoin",
    self.wireframe_linejoin,
  )
  self.rotation = material_read_opt_double(json, "rotation", self.rotation)
  self.linewidth = material_read_opt_double(json, "linewidth", self.linewidth)
  self.linecap = material_read_opt_string(json, "linecap", self.linecap)
  self.linejoin = material_read_opt_string(json, "linejoin", self.linejoin)
  self.dash_size = material_read_opt_double(json, "dashSize", self.dash_size)
  self.gap_size = material_read_opt_double(json, "gapSize", self.gap_size)
  self.scale = material_read_opt_double(json, "scale", self.scale)
  self.polygon_offset = material_read_bool(
    json,
    "polygonOffset",
    self.polygon_offset,
  )
  self.polygon_offset_factor = material_read_double(
    json,
    "polygonOffsetFactor",
    self.polygon_offset_factor,
  )
  self.polygon_offset_units = material_read_double(
    json,
    "polygonOffsetUnits",
    self.polygon_offset_units,
  )
  self.dithering = material_read_bool(json, "dithering", self.dithering)
  self.alpha_to_coverage = material_read_bool(
    json,
    "alphaToCoverage",
    self.alpha_to_coverage,
  )
  self.premultiplied_alpha = material_read_bool(
    json,
    "premultipliedAlpha",
    self.premultiplied_alpha,
  )
  self.force_single_pass = material_read_bool(
    json,
    "forceSinglePass",
    self.force_single_pass,
  )
  self.allow_override = material_read_bool(
    json,
    "allowOverride",
    self.allow_override,
  )
  self.visible = material_read_bool(json, "visible", self.visible)
  self.tone_mapped = material_read_bool(json, "toneMapped", self.tone_mapped)
  if json.get("userData") is Some(user_data) {
    self.user_data = JsValue::from_json(user_data)
  }
  match json.get("vertexColors") {
    Some(Number(value, ..)) => self.vertex_colors = value > 0.0
    Some(True) => self.vertex_colors = true
    Some(False) => self.vertex_colors = false
    _ => ()
  }

  // for PointsMaterial
  self.size = material_read_opt_double(json, "size", self.size)
  self.size_attenuation = material_read_opt_bool(
    json,
    "sizeAttenuation",
    self.size_attenuation,
  )

  // maps
  self.map = material_read_texture(json, "map", textures, self.map)
  self.matcap = material_read_texture(json, "matcap", textures, self.matcap)
  self.alpha_map = material_read_texture(
    json,
    "alphaMap",
    textures,
    self.alpha_map,
  )
  self.bump_map = material_read_texture(
    json,
    "bumpMap",
    textures,
    self.bump_map,
  )
  self.bump_scale = material_read_opt_double(json, "bumpScale", self.bump_scale)
  self.normal_map = material_read_texture(
    json,
    "normalMap",
    textures,
    self.normal_map,
  )
  self.normal_map_type = material_read_opt_int(
    json,
    "normalMapType",
    self.normal_map_type,
  )
  match json.get("normalScale") {
    None => ()
    // Blender exporter used to export a scalar. See #7459
    Some(Number(scale, ..)) =>
      self.normal_scale = Some(@math.Vector2::new(scale, scale))
    Some(scale) =>
      self.normal_scale = Some(
        @math.Vector2::new(0.0, 0.0).from_array(material_read_numbers(scale)),
      )
  }
  self.displacement_map = material_read_texture(
    json,
    "displacementMap",
    textures,
    self.displacement_map,
  )
  self.displacement_scale = material_read_opt_double(
    json,
    "displacementScale",
    self.displacement_scale,
  )
  self.displacement_bias = material_read_opt_double(
    json,
    "displacementBias",
    self.displacement_bias,
  )
  self.roughness_map = material_read_texture(
    json,
    "roughnessMap",
    textures,
    self.roughness_map,
  )
  self.metalness_map = material_read_texture(
    json,
    "metalnessMap",
    textures,
    self.metalness_map,
  )
  self.emissive_map = material_read_texture(
    json,
    "emissiveMap",
    textures,
    self.emissive_map,
  )
  self.emissive_intensity = material_read_opt_double(
    json,
    "emissiveIntensity",
    self.emissive_intensity,
  )
  self.specular_map = material_read_texture(
    json,
    "specularMap",
    textures,
    self.specular_map,
  )
  self.specular_intensity_map = material_read_texture(
    json,
    "specularIntensityMap",
    textures,
    self.specular_intensity_map,
  )
  self.specular_color_map = material_read_texture(
    json,
    "specularColorMap",
    textures,
    self.specular_color_map,
  )
  self.env_map = material_read_texture(json, "envMap", textures, self.env_map)
  if json.get("envMapRotation") is Some(Array(rotation)) {
    ignore(self.env_map_rotation.unwrap().from_array(rotation))
  }
  self.env_map_intensity = material_read_opt_double(
    json,
    "envMapIntensity",
    self.env_map_intensity,
  )
  material_read_setter(json, "reflectivity", v => self.set_reflectivity(v))
  self.refraction_ratio = material_read_opt_double(
    json,
    "refractionRatio",
    self.refraction_ratio,
  )
  self.light_map = material_read_texture(
    json,
    "lightMap",
    textures,
    self.light_map,
  )
  self.light_map_intensity = material_read_opt_double(
    json,
    "lightMapIntensity",
    self.light_map_intensity,
  )
  self.ao_map = material_read_texture(json, "aoMap", textures, self.ao_map)
  self.ao_map_intensity = material_read_opt_double(
    json,
    "aoMapIntensity",
    self.ao_map_intensity,
  )
  self.gradient_map = material_read_texture(
    json,
    "gradientMap",
    textures,
    self.gradient_map,
  )
  self.clearcoat_map = material_read_texture(
    json,
    "clearcoatMap",
    textures,
    self.clearcoat_map,
  )
  self.clearcoat_roughness_map = material_read_texture(
    json,
    "clearcoatRoughnessMap",
    textures,
    self.clearcoat_roughness_map,
  )
  self.clearcoat_normal_map = material_read_texture(
    json,
    "clearcoatNormalMap",
    textures,
    self.clearcoat_normal_map,
  )
  if json.get("clearcoatNormalScale") is Some(scale) {
    self.clearcoat_normal_scale = Some(
      @math.Vector2::new(0.0, 0.0).from_array(material_read_numbers(scale)),
    )
  }
  self.diffuse_roughness_map = material_read_texture(
    json,
    "diffuseRoughnessMap",
    textures,
    self.diffuse_roughness_map,
  )
  self.iridescence_map = material_read_texture(
    json,
    "iridescenceMap",
    textures,
    self.iridescence_map,
  )
  self.iridescence_thickness_map = material_read_texture(
    json,
    "iridescenceThicknessMap",
    textures,
    self.iridescence_thickness_map,
  )
  self.transmission_map = material_read_texture(
    json,
    "transmissionMap",
    textures,
    self.transmission_map,
  )
  self.thickness_map = material_read_texture(
    json,
    "thicknessMap",
    textures,
    self.thickness_map,
  )
  self.anisotropy_map = material_read_texture(
    json,
    "anisotropyMap",
    textures,
    self.anisotropy_map,
  )
  self.sheen_color_map = material_read_texture(
    json,
    "sheenColorMap",
    textures,
    self.sheen_color_map,
  )
  self.sheen_roughness_map = material_read_texture(
    json,
    "sheenRoughnessMap",
    textures,
    self.sheen_roughness_map,
  )
  if self.is_shader_material() {
    self.from_json_shader(json, textures)
  }
  self
}

///|
/// `new this.constructor()`.
fn Material::new_like(self : Material) -> Material {
  if self.extension is Some(extension) {
    return extension.construct()
  }
  match self.material_type {
    Material => Material::new()
    LineBasicMaterial => LineBasicMaterial::new()
    LineDashedMaterial => LineDashedMaterial::new()
    MeshBasicMaterial => MeshBasicMaterial::new()
    MeshDepthMaterial => MeshDepthMaterial::new()
    MeshDistanceMaterial => MeshDistanceMaterial::new()
    MeshLambertMaterial => MeshLambertMaterial::new()
    MeshMatcapMaterial => MeshMatcapMaterial::new()
    MeshNormalMaterial => MeshNormalMaterial::new()
    MeshPhongMaterial => MeshPhongMaterial::new()
    MeshPhysicalMaterial => MeshPhysicalMaterial::new()
    MeshStandardMaterial => MeshStandardMaterial::new()
    MeshToonMaterial => MeshToonMaterial::new()
    PointsMaterial => PointsMaterial::new()
    RawShaderMaterial => RawShaderMaterial::new()
    ShaderMaterial => ShaderMaterial::new()
    ShadowMaterial => ShadowMaterial::new()
    SpriteMaterial => SpriteMaterial::new()
  }
}

///|
pub fn Material::clone(self : Material) -> Material {
  self.new_like().copy(self)
}

///|
/// Upstream's `Material.prototype.copy`, which subclasses reach through `super.copy`.
pub fn Material::copy_base(self : Material, source : Material) -> Unit {
  self.name = source.name
  self.blending = source.blending
  self.side = source.side
  self.vertex_colors = source.vertex_colors
  self.opacity = source.opacity
  self.transparent = source.transparent
  self.blend_src = source.blend_src
  self.blend_dst = source.blend_dst
  self.blend_equation = source.blend_equation
  self.blend_src_alpha = source.blend_src_alpha
  self.blend_dst_alpha = source.blend_dst_alpha
  self.blend_equation_alpha = source.blend_equation_alpha
  ignore(self.blend_color.copy(source.blend_color))
  self.blend_alpha = source.blend_alpha
  self.depth_func = source.depth_func
  self.depth_test = source.depth_test
  self.depth_write = source.depth_write
  self.stencil_write_mask = source.stencil_write_mask
  self.stencil_func = source.stencil_func
  self.stencil_ref = source.stencil_ref
  self.stencil_func_mask = source.stencil_func_mask
  self.stencil_fail = source.stencil_fail
  self.stencil_z_fail = source.stencil_z_fail
  self.stencil_z_pass = source.stencil_z_pass
  self.stencil_write = source.stencil_write
  self.clipping_planes = match source.clipping_planes {
    Some(planes) => Some(planes.map(plane => plane.clone()))
    None => None
  }
  self.clip_intersection = source.clip_intersection
  self.clip_shadows = source.clip_shadows
  self.shadow_side = source.shadow_side
  self.color_write = source.color_write
  self.precision = source.precision
  self.polygon_offset = source.polygon_offset
  self.polygon_offset_factor = source.polygon_offset_factor
  self.polygon_offset_units = source.polygon_offset_units
  self.dithering = source.dithering
  self.set_alpha_test(source.alpha_test())
  self.alpha_hash = source.alpha_hash
  self.alpha_to_coverage = source.alpha_to_coverage
  self.premultiplied_alpha = source.premultiplied_alpha
  self.force_single_pass = source.force_single_pass
  self.allow_override = source.allow_override
  self.visible = source.visible
  self.tone_mapped = source.tone_mapped
  self.user_data = source.user_data.json_clone()
}

///|
/// Copies as the class of `self` does; aborts where `this.color.copy( undefined )` throws.
pub fn Material::copy(self : Material, source : Material) -> Material {
  match self.material_type {
    Material => self.copy_base(source)
    LineBasicMaterial => self.copy_line_basic(source)
    LineDashedMaterial => self.copy_line_dashed(source)
    MeshBasicMaterial => self.copy_mesh_basic(source)
    MeshDepthMaterial => self.copy_mesh_depth(source)
    MeshDistanceMaterial => self.copy_mesh_distance(source)
    MeshLambertMaterial => self.copy_mesh_lambert(source)
    MeshMatcapMaterial => self.copy_mesh_matcap(source)
    MeshNormalMaterial => self.copy_mesh_normal(source)
    MeshPhongMaterial => self.copy_mesh_phong(source)
    MeshPhysicalMaterial => self.copy_mesh_physical(source)
    MeshStandardMaterial => self.copy_mesh_standard(source)
    MeshToonMaterial => self.copy_mesh_toon(source)
    PointsMaterial => self.copy_points(source)
    RawShaderMaterial | ShaderMaterial => self.copy_shader(source)
    ShadowMaterial => self.copy_shadow(source)
    SpriteMaterial => self.copy_sprite(source)
  }
  if self.extension is Some(extension) {
    extension.copy_from(self, source)
  }
  self
}

///|
pub fn Material::dispose(self : Material) -> Unit {
  if self.extension is Some(extension) {
    extension.dispose(self)
  }
  self.dispatch_event(Event::new("dispose"))
}
