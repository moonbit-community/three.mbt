// Upstream src/renderers/webgl/WebGLPrograms.js. GROUP 2.

///|
/// The `parameters` object `WebGLPrograms.getParameters` builds, `WebGLProgram` compiles
/// from and `material.onBeforeCompile` receives.
///
/// `shaderName`, `uniforms`, `vertexShader` and `fragmentShader` live in `shader`, the
/// core `ShaderObject` handed to `on_before_compile`, so edits made there are what
/// `acquireProgram` compiles. Before calling `on_before_compile`, set
/// `shader.parameters = JsValue::of(parameters)` so the callback can reach the rest.
///
/// Upstream fields that are `false` or a value (`mapUv: HAS_MAP && 'uv'`,
/// `envMapMode: HAS_ENVMAP && mapping`) are `T?` here; `None` is `false`, and the program
/// cache key must print it as `false` as `Array.join` does. Fields that may be
/// `undefined` (`shaderID`, `customVertexShaderID`, `combine`) are `T?` too and print as
/// the empty string.
pub(all) struct WebGLProgramParameters {
  shader_id : String?
  shader_type : String
  shader : @core.ShaderObject
  defines : Map[String, Json]?
  custom_vertex_shader_id : Int32?
  custom_fragment_shader_id : Int32?
  // `mut`: the WebGLNodesHandler add-on rewrites them in `build`
  mut is_raw_shader_material : Bool
  mut glsl_version : String?
  precision : String
  batching : Bool
  batching_color : Bool
  instancing : Bool
  instancing_color : Bool
  instancing_morph : Bool
  output_color_space : String
  alpha_to_coverage : Bool
  map : Bool
  matcap : Bool
  env_map : Bool
  /// `HAS_ENVMAP && envMap.mapping`
  env_map_mode : Int32?
  env_map_pmrem : Bool
  /// `null` without PMREM
  env_map_max_lod : Int32?
  /// `null` without PMREM
  env_map_size : Int32?
  ao_map : Bool
  light_map : Bool
  bump_map : Bool
  normal_map : Bool
  displacement_map : Bool
  emissive_map : Bool
  normal_map_object_space : Bool
  normal_map_tangent_space : Bool
  packed_normal_map : Bool
  metalness_map : Bool
  roughness_map : Bool
  anisotropy : Bool
  anisotropy_map : Bool
  clearcoat : Bool
  clearcoat_map : Bool
  clearcoat_normal_map : Bool
  clearcoat_roughness_map : Bool
  diffuse_roughness : Bool
  diffuse_roughness_map : Bool
  dispersion : Bool
  retroreflection : Bool
  iridescence : Bool
  iridescence_map : Bool
  iridescence_thickness_map : Bool
  sheen : Bool
  sheen_color_map : Bool
  sheen_roughness_map : Bool
  specular_map : Bool
  specular_color_map : Bool
  specular_intensity_map : Bool
  transmission : Bool
  transmission_map : Bool
  thickness_map : Bool
  gradient_map : Bool
  /// upstream `opaque` (a reserved word here)
  opaque_ : Bool
  alpha_map : Bool
  alpha_test : Bool
  alpha_hash : Bool
  /// `material.combine`, `undefined` on materials without it
  combine : Int32?
  // `HAS_X && getChannel( material.x.channel )`: `None` is `false`.
  map_uv : String?
  ao_map_uv : String?
  light_map_uv : String?
  bump_map_uv : String?
  normal_map_uv : String?
  displacement_map_uv : String?
  emissive_map_uv : String?
  metalness_map_uv : String?
  roughness_map_uv : String?
  anisotropy_map_uv : String?
  clearcoat_map_uv : String?
  clearcoat_normal_map_uv : String?
  clearcoat_roughness_map_uv : String?
  diffuse_roughness_map_uv : String?
  iridescence_map_uv : String?
  iridescence_thickness_map_uv : String?
  sheen_color_map_uv : String?
  sheen_roughness_map_uv : String?
  specular_map_uv : String?
  specular_color_map_uv : String?
  specular_intensity_map_uv : String?
  transmission_map_uv : String?
  thickness_map_uv : String?
  alpha_map_uv : String?
  vertex_tangents : Bool
  vertex_normals : Bool
  vertex_colors : Bool
  vertex_alphas : Bool
  points_uvs : Bool
  fog : Bool
  use_fog : Bool
  fog_exp2 : Bool
  flat_shading : Bool
  size_attenuation : Bool
  logarithmic_depth_buffer : Bool
  reversed_depth_buffer : Bool
  skinning : Bool
  has_position_attribute : Bool
  morph_targets : Bool
  morph_normals : Bool
  morph_colors : Bool
  morph_targets_count : Int32
  morph_texture_stride : Int32
  num_sun_lights : Int32
  num_dir_lights : Int32
  num_point_lights : Int32
  num_spot_lights : Int32
  num_spot_light_maps : Int32
  num_rect_area_lights : Int32
  num_hemi_lights : Int32
  num_sun_light_shadows : Int32
  num_dir_light_shadows : Int32
  num_point_light_shadows : Int32
  num_spot_light_shadows : Int32
  num_spot_light_shadows_with_maps : Int32
  num_light_probes : Int32
  num_light_probe_grids : Int32
  num_clipping_planes : Int32
  num_clip_intersection : Int32
  dithering : Bool
  shadow_map_enabled : Bool
  shadow_map_type : Int32
  tone_mapping : Int32
  decode_video_texture : Bool
  decode_video_texture_emissive : Bool
  premultiplied_alpha : Bool
  double_sided : Bool
  flip_sided : Bool
  use_depth_packing : Bool
  depth_packing : Int32
  index0_attribute_name : String?
  extension_clip_cull_distance : Bool
  extension_multi_draw : Bool
  renderer_extension_parallel_shader_compile : Bool
  custom_program_cache_key : String
  mut vertex_uv1s : Bool
  mut vertex_uv2s : Bool
  mut vertex_uv3s : Bool
}

///|
/// Parameters whose `fogExp2` is `undefined` (not `false`): a linear `Fog` makes
/// `!! fog && fog.isFogExp2` undefined, which the cache key prints as the empty string.
let webgl_programs_fog_exp2_undefined : WeakMap[WebGLProgramParameters, Bool] = WeakMap::new()

///|
/// Parameters whose `flatShading` is `undefined` (not `false`): its `||` chain ends on a
/// missing `isMesh*Material` flag, so `flatShading === false` fails.
let webgl_programs_flat_shading_undefined : WeakMap[
  WebGLProgramParameters,
  Bool,
] = WeakMap::new()

///|
/// Whether `fogExp2` is upstream's `undefined` (see the field).
fn webgl_program_parameters_fog_exp2_undefined(
  parameters : WebGLProgramParameters,
) -> Bool {
  webgl_programs_fog_exp2_undefined.get(parameters) == Some(true)
}

///|
/// Whether `flatShading` is upstream's `undefined` (see the field).
fn webgl_program_parameters_flat_shading_undefined(
  parameters : WebGLProgramParameters,
) -> Bool {
  webgl_programs_flat_shading_undefined.get(parameters) == Some(true)
}

///|
/// `isPackedRGFormat( format )`.
fn webgl_programs_is_packed_rg_format(format : Int32) -> Bool {
  format == @core.RGFormat ||
  format == @core.RG11_EAC_Format ||
  format == @core.RED_GREEN_RGTC2_Format
}

///|
pub struct WebGLPrograms {
  renderer : WebGLRenderer
  environments : WebGLEnvironments
  extensions : WebGLExtensions
  capabilities : WebGLCapabilities
  binding_states : WebGLBindingStates
  clipping : WebGLClipping
  _program_layers : @core.Layers
  _custom_shaders : WebGLShaderCache
  /// the `Set` of texture channels `getChannel` saw
  _active_channels : Map[Int32, Bool]
  /// unordered; `releaseProgram` swaps the last one in
  programs : Array[WebGLProgram]
  programs_map : Map[String, WebGLProgram]
  logarithmic_depth_buffer : Bool
  /// `material.type` -> `ShaderLib` key
  shader_ids : Map[String, String]
}

///|
/// `new WebGLPrograms( renderer, environments, extensions, capabilities, bindingStates,
/// clipping )`.
pub fn WebGLPrograms::new(
  renderer : WebGLRenderer,
  environments : WebGLEnvironments,
  extensions : WebGLExtensions,
  capabilities : WebGLCapabilities,
  binding_states : WebGLBindingStates,
  clipping : WebGLClipping,
) -> WebGLPrograms {
  {
    renderer,
    environments,
    extensions,
    capabilities,
    binding_states,
    clipping,
    _program_layers: @core.Layers::new(),
    _custom_shaders: WebGLShaderCache::new(),
    _active_channels: Map([]),
    programs: [],
    programs_map: Map([]),
    logarithmic_depth_buffer: capabilities.logarithmic_depth_buffer,
    shader_ids: Map([
      ("MeshDepthMaterial", "depth"),
      ("MeshDistanceMaterial", "distance"),
      ("MeshNormalMaterial", "normal"),
      ("MeshBasicMaterial", "basic"),
      ("MeshLambertMaterial", "lambert"),
      ("MeshPhongMaterial", "phong"),
      ("MeshToonMaterial", "toon"),
      ("MeshStandardMaterial", "physical"),
      ("MeshPhysicalMaterial", "physical"),
      ("MeshMatcapMaterial", "matcap"),
      ("LineBasicMaterial", "basic"),
      ("LineDashedMaterial", "dashed"),
      ("PointsMaterial", "points"),
      ("ShadowMaterial", "shadow"),
      ("SpriteMaterial", "sprite"),
    ]),
  }
}

///|
/// `getChannel( value )`.
fn WebGLPrograms::get_channel(self : WebGLPrograms, value : Int32) -> String {
  self._active_channels[value] = true
  if value == 0 {
    return "uv"
  }
  "uv\{value}"
}

///|
/// `HAS_X && getChannel( material.x.channel )`: `None` is `false`.
fn WebGLPrograms::map_uv(
  self : WebGLPrograms,
  has_map : Bool,
  map : @core.Texture?,
) -> String? {
  if has_map {
    Some(self.get_channel(map.unwrap().channel))
  } else {
    None
  }
}

///|
/// `texture.width` of a mipmap entry (`{ width, height }` or an image).
fn webgl_programs_image_width(image : @core.TextureImage) -> Int32 {
  match image {
    DataImage(d) => d.width
    DomImage(js) => js_number_to_int(js.get("width"))
    TextureImage(t) => t.width().to_int()
    _ => abort("WebGLPrograms: mipmap without a width")
  }
}

///|
/// `x > 0` for an optional number (`undefined > 0` is false).
fn webgl_programs_positive(value : Double?) -> Bool {
  match value {
    Some(v) => v > 0.0
    None => false
  }
}

///|
/// `programCache.getParameters( material, lights, shadows, scene, object, lightProbeGrids )`.
/// `scene` is a `Scene` (the renderer substitutes its empty scene); `shadows` are the
/// shadow-casting lights; `light_probe_grids` the `LightProbeGrid` objects.
pub fn WebGLPrograms::get_parameters(
  self : WebGLPrograms,
  material : @core.Material,
  lights : WebGLLightsState,
  shadows : Array[@core.Object3D],
  scene : @core.Object3D,
  object : @core.Object3D,
  light_probe_grids : Array[@core.Object3D],
) -> WebGLProgramParameters {
  let renderer = self.renderer
  let capabilities = self.capabilities
  let extensions = self.extensions
  let scene_data = match scene.kind {
    Scene(s) => Some(s)
    _ => None
  }
  let fog = match scene_data {
    Some(s) => s.fog
    None => None
  }
  let geometry = object.get_geometry().unwrap()
  let is_standard = material.is_mesh_standard_material()
  let is_lambert = material.is_mesh_lambert_material()
  let is_phong = material.is_mesh_phong_material()
  let environment = if is_standard || is_lambert || is_phong {
    match scene_data {
      Some(s) => s.environment
      None => None
    }
  } else {
    None
  }
  let use_pmrem = is_standard ||
    (is_lambert && material.env_map is None) ||
    (is_phong && material.env_map is None)
  let env_map = self.environments.get(
    match material.env_map {
      Some(t) => Some(t)
      None => environment
    },
    use_pmrem~,
  )
  let shader_id = self.shader_ids.get(material.type_)

  // heuristics to create shader parameters according to lights in the scene
  // (not to blow over maxLights budget)

  let mut precision = capabilities.precision
  if material.precision is Some(material_precision) {
    precision = capabilities.get_max_precision(material_precision)
    if precision != material_precision {
      @core.warn(
        "WebGLProgram.getParameters: " +
        material_precision +
        " not supported, using " +
        precision +
        " instead.",
      )
    }
  }

  //

  let morph_attributes = geometry.morph_attributes
  let morph_attribute = match morph_attributes.get("position") {
    Some(a) => Some(a)
    None =>
      match morph_attributes.get("normal") {
        Some(a) => Some(a)
        None => morph_attributes.get("color")
      }
  }
  let morph_targets_count = match morph_attribute {
    Some(a) => a.length()
    None => 0
  }
  let mut morph_texture_stride = 0
  if morph_attributes.contains("position") {
    morph_texture_stride = 1
  }
  if morph_attributes.contains("normal") {
    morph_texture_stride = 2
  }
  if morph_attributes.contains("color") {
    morph_texture_stride = 3
  }

  //

  let mut vertex_shader = ""
  let mut fragment_shader = ""
  let mut custom_vertex_shader_id = None
  let mut custom_fragment_shader_id = None
  match shader_id {
    Some(id) => {
      let shader = @shaders.shader_lib[id]
      vertex_shader = shader.vertex_shader
      fragment_shader = shader.fragment_shader
    }
    None => {
      vertex_shader = material.vertex_shader.unwrap_or("")
      fragment_shader = material.fragment_shader.unwrap_or("")
      let vertex_shader_stage = self._custom_shaders.get_vertex_shader_stage(
        material,
      )
      let fragment_shader_stage = self._custom_shaders.get_fragment_shader_stage(
        material,
      )
      ignore(
        self._custom_shaders.update(
          material, vertex_shader_stage, fragment_shader_stage,
        ),
      )
      custom_vertex_shader_id = Some(vertex_shader_stage.id)
      custom_fragment_shader_id = Some(fragment_shader_stage.id)
    }
  }
  let current_render_target = renderer.get_render_target()
  let reversed_depth_buffer = renderer.state.buffers.depth.get_reversed()
  let is_instancedmesh = object.is_instanced_mesh()
  let is_batchedmesh = object.is_batched_mesh()
  let has_map = material.map is Some(_)
  let has_matcap = material.matcap is Some(_)
  let has_envmap = env_map is Some(_)
  let has_pmrem = match env_map {
    Some(t) => t.is_pmrem_texture
    None => false
  }
  let has_aomap = material.ao_map is Some(_)
  let has_lightmap = material.light_map is Some(_)
  let has_bumpmap = material.bump_map is Some(_) &&
    material.wireframe == Some(false)
  let has_normalmap = material.normal_map is Some(_)
  let has_displacementmap = material.displacement_map is Some(_)
  let has_emissivemap = material.emissive_map is Some(_)
  let has_metalnessmap = material.metalness_map is Some(_)
  let has_roughnessmap = material.roughness_map is Some(_)
  let has_anisotropy = webgl_programs_positive(material.anisotropy())
  let has_clearcoat = webgl_programs_positive(material.clearcoat())
  let has_diffuse_roughness = webgl_programs_positive(
    material.diffuse_roughness(),
  )
  let has_dispersion = webgl_programs_positive(material.dispersion())
  let has_retroreflection = webgl_programs_positive(
    material.retroreflectivity(),
  )
  let has_iridescence = webgl_programs_positive(material.iridescence())
  let has_sheen = webgl_programs_positive(material.sheen())
  let has_transmission = webgl_programs_positive(material.transmission())
  let has_anisotropymap = has_anisotropy && material.anisotropy_map is Some(_)
  let has_clearcoatmap = has_clearcoat && material.clearcoat_map is Some(_)
  let has_clearcoat_normalmap = has_clearcoat &&
    material.clearcoat_normal_map is Some(_)
  let has_clearcoat_roughnessmap = has_clearcoat &&
    material.clearcoat_roughness_map is Some(_)
  let has_diffuse_roughnessmap = has_diffuse_roughness &&
    material.diffuse_roughness_map is Some(_)
  let has_iridescencemap = has_iridescence &&
    material.iridescence_map is Some(_)
  let has_iridescence_thicknessmap = has_iridescence &&
    material.iridescence_thickness_map is Some(_)
  let has_sheen_colormap = has_sheen && material.sheen_color_map is Some(_)
  let has_sheen_roughnessmap = has_sheen &&
    material.sheen_roughness_map is Some(_)
  let has_specularmap = material.specular_map is Some(_)
  let has_specular_colormap = material.specular_color_map is Some(_)
  let has_specular_intensitymap = material.specular_intensity_map is Some(_)
  let has_transmissionmap = has_transmission &&
    material.transmission_map is Some(_)
  let has_thicknessmap = has_transmission && material.thickness_map is Some(_)
  let has_gradientmap = material.gradient_map is Some(_)
  let has_alphamap = material.alpha_map is Some(_)
  let has_alphatest = material.alpha_test() > 0.0
  let has_alphahash = material.alpha_hash
  let has_extensions = material.extensions is Some(_)
  let mut tone_mapping = @core.NoToneMapping
  if material.tone_mapped {
    match current_render_target {
      None => tone_mapping = renderer.tone_mapping
      Some(rt) =>
        if rt.has_extension_flag("isXRRenderTarget") {
          tone_mapping = renderer.tone_mapping
        }
    }
  }
  let env_map_mipmaps : Array[@core.TextureImage]? = if has_pmrem {
    let env_map = env_map.unwrap()
    if env_map.texture_type is CompressedCubeTexture {
      match env_map.image() {
        ImageArray(images) =>
          match images[0] {
            DataImage({ mipmaps: Some(mipmaps), .. }) =>
              Some(mipmaps.map(fn(m) { @core.TextureImage::DataImage(m) }))
            TextureImage(t) => Some(t.mipmaps)
            _ => abort("WebGLPrograms: compressed cube face without mipmaps")
          }
        _ => abort("WebGLPrograms: compressed cube texture without faces")
      }
    } else {
      Some(env_map.mipmaps)
    }
  } else {
    None
  }
  let output_color_space = match current_render_target {
    None => renderer.output_color_space()
    Some(rt) =>
      if rt.has_extension_flag("isXRRenderTarget") {
        rt.texture().color_space
      } else {
        @math.color_management.working_color_space
      }
  }
  let attributes = geometry.attributes
  let normal_map_type = material.normal_map_type
  let fog_is_exp2 = fog is Some(FogExp2(_))
  let wireframe_false = material.wireframe == Some(false)
  // `isMeshLambertMaterial || isMeshPhongMaterial || isMeshStandardMaterial ||
  // isMeshPhysicalMaterial` is `undefined` (not `false`) when none is set
  let lit_flat = !attributes.contains("normal") &&
    has_normalmap == false &&
    (
      is_lambert ||
      is_phong ||
      is_standard ||
      material.is_mesh_physical_material()
    )
  let lit_flat_undefined = !attributes.contains("normal") &&
    has_normalmap == false &&
    !(is_lambert ||
    is_phong ||
    is_standard ||
    material.is_mesh_physical_material())
  let flat_shading = wireframe_false &&
    (material.flat_shading == Some(true) || lit_flat)
  let flat_shading_undefined = wireframe_false &&
    material.flat_shading != Some(true) &&
    lit_flat_undefined
  let (batching_color, instancing_color, instancing_morph) = match object.kind {
    Mesh({ kind: BatchedMesh(b), .. }) =>
      (b._colors_texture is Some(_), false, false)
    Mesh({ kind: InstancedMesh(i), .. }) =>
      (false, i.instance_color is Some(_), i.morph_texture is Some(_))
    _ => (false, false, false)
  }
  let map_uv = self.map_uv(has_map, material.map)
  let ao_map_uv = self.map_uv(has_aomap, material.ao_map)
  let light_map_uv = self.map_uv(has_lightmap, material.light_map)
  let bump_map_uv = self.map_uv(has_bumpmap, material.bump_map)
  let normal_map_uv = self.map_uv(has_normalmap, material.normal_map)
  let displacement_map_uv = self.map_uv(
    has_displacementmap,
    material.displacement_map,
  )
  let emissive_map_uv = self.map_uv(has_emissivemap, material.emissive_map)
  let metalness_map_uv = self.map_uv(has_metalnessmap, material.metalness_map)
  let roughness_map_uv = self.map_uv(has_roughnessmap, material.roughness_map)
  let anisotropy_map_uv = self.map_uv(
    has_anisotropymap,
    material.anisotropy_map,
  )
  let clearcoat_map_uv = self.map_uv(has_clearcoatmap, material.clearcoat_map)
  let clearcoat_normal_map_uv = self.map_uv(
    has_clearcoat_normalmap,
    material.clearcoat_normal_map,
  )
  let clearcoat_roughness_map_uv = self.map_uv(
    has_clearcoat_roughnessmap,
    material.clearcoat_roughness_map,
  )
  let diffuse_roughness_map_uv = self.map_uv(
    has_diffuse_roughnessmap,
    material.diffuse_roughness_map,
  )
  let iridescence_map_uv = self.map_uv(
    has_iridescencemap,
    material.iridescence_map,
  )
  let iridescence_thickness_map_uv = self.map_uv(
    has_iridescence_thicknessmap,
    material.iridescence_thickness_map,
  )
  let sheen_color_map_uv = self.map_uv(
    has_sheen_colormap,
    material.sheen_color_map,
  )
  let sheen_roughness_map_uv = self.map_uv(
    has_sheen_roughnessmap,
    material.sheen_roughness_map,
  )
  let specular_map_uv = self.map_uv(has_specularmap, material.specular_map)
  let specular_color_map_uv = self.map_uv(
    has_specular_colormap,
    material.specular_color_map,
  )
  let specular_intensity_map_uv = self.map_uv(
    has_specular_intensitymap,
    material.specular_intensity_map,
  )
  let transmission_map_uv = self.map_uv(
    has_transmissionmap,
    material.transmission_map,
  )
  let thickness_map_uv = self.map_uv(has_thicknessmap, material.thickness_map)
  let alpha_map_uv = self.map_uv(has_alphamap, material.alpha_map)
  let shader_extensions = material.extensions
  let extension_clip_cull_distance = has_extensions &&
    shader_extensions.unwrap().clip_cull_distance == true &&
    extensions.has("WEBGL_clip_cull_distance")
  let extension_multi_draw = (
      (has_extensions && shader_extensions.unwrap().multi_draw == true) ||
      is_batchedmesh
    ) &&
    extensions.has("WEBGL_multi_draw")
  let renderer_extension_parallel_shader_compile = extensions.has(
    "KHR_parallel_shader_compile",
  )
  let shader : @core.ShaderObject = {
    name: material.name,
    uniforms: Map([]),
    vertex_shader,
    fragment_shader,
    parameters: @core.JsValue::undefined(),
  }
  let parameters : WebGLProgramParameters = {
    shader_id,
    shader_type: material.type_,
    shader,
    defines: material.defines,
    custom_vertex_shader_id,
    custom_fragment_shader_id,
    is_raw_shader_material: material.is_raw_shader_material(),
    glsl_version: material.glsl_version,
    precision,
    batching: is_batchedmesh,
    batching_color,
    instancing: is_instancedmesh,
    instancing_color,
    instancing_morph,
    output_color_space,
    alpha_to_coverage: material.alpha_to_coverage,
    map: has_map,
    matcap: has_matcap,
    env_map: has_envmap,
    env_map_mode: match env_map {
      Some(t) => Some(t.mapping)
      None => None
    },
    env_map_pmrem: has_pmrem,
    env_map_max_lod: match env_map_mipmaps {
      Some(m) => Some(m.length() - 1)
      None => None
    },
    env_map_size: match env_map_mipmaps {
      Some(m) => Some(webgl_programs_image_width(m[0]))
      None => None
    },
    ao_map: has_aomap,
    light_map: has_lightmap,
    bump_map: has_bumpmap,
    normal_map: has_normalmap,
    displacement_map: has_displacementmap,
    emissive_map: has_emissivemap,
    normal_map_object_space: has_normalmap &&
    normal_map_type == Some(@core.ObjectSpaceNormalMap),
    normal_map_tangent_space: has_normalmap &&
    normal_map_type == Some(@core.TangentSpaceNormalMap),
    packed_normal_map: has_normalmap &&
    normal_map_type == Some(@core.TangentSpaceNormalMap) &&
    webgl_programs_is_packed_rg_format(material.normal_map.unwrap().format),
    metalness_map: has_metalnessmap,
    roughness_map: has_roughnessmap,
    anisotropy: has_anisotropy,
    anisotropy_map: has_anisotropymap,
    clearcoat: has_clearcoat,
    clearcoat_map: has_clearcoatmap,
    clearcoat_normal_map: has_clearcoat_normalmap,
    clearcoat_roughness_map: has_clearcoat_roughnessmap,
    diffuse_roughness: has_diffuse_roughness,
    diffuse_roughness_map: has_diffuse_roughnessmap,
    dispersion: has_dispersion,
    retroreflection: has_retroreflection,
    iridescence: has_iridescence,
    iridescence_map: has_iridescencemap,
    iridescence_thickness_map: has_iridescence_thicknessmap,
    sheen: has_sheen,
    sheen_color_map: has_sheen_colormap,
    sheen_roughness_map: has_sheen_roughnessmap,
    specular_map: has_specularmap,
    specular_color_map: has_specular_colormap,
    specular_intensity_map: has_specular_intensitymap,
    transmission: has_transmission,
    transmission_map: has_transmissionmap,
    thickness_map: has_thicknessmap,
    gradient_map: has_gradientmap,
    opaque_: material.transparent == false &&
    material.blending == @core.NormalBlending &&
    material.alpha_to_coverage == false,
    alpha_map: has_alphamap,
    alpha_test: has_alphatest,
    alpha_hash: has_alphahash,
    combine: material.combine,

    //

    map_uv,
    ao_map_uv,
    light_map_uv,
    bump_map_uv,
    normal_map_uv,
    displacement_map_uv,
    emissive_map_uv,
    metalness_map_uv,
    roughness_map_uv,
    anisotropy_map_uv,
    clearcoat_map_uv,
    clearcoat_normal_map_uv,
    clearcoat_roughness_map_uv,
    diffuse_roughness_map_uv,
    iridescence_map_uv,
    iridescence_thickness_map_uv,
    sheen_color_map_uv,
    sheen_roughness_map_uv,
    specular_map_uv,
    specular_color_map_uv,
    specular_intensity_map_uv,
    transmission_map_uv,
    thickness_map_uv,
    alpha_map_uv,

    //

    vertex_tangents: attributes.contains("tangent") &&
    (has_normalmap || has_anisotropy),
    vertex_normals: attributes.contains("normal"),
    vertex_colors: material.vertex_colors,
    vertex_alphas: material.vertex_colors == true &&
    (match attributes.get("color") {
      Some(color) => color.item_size() == 4
      None => false
    }),
    points_uvs: object.is_points() &&
    attributes.contains("uv") &&
    (has_map || has_alphamap),
    fog: fog is Some(_),
    use_fog: material.fog == Some(true),
    fog_exp2: fog_is_exp2,
    flat_shading,
    size_attenuation: material.size_attenuation == Some(true),
    logarithmic_depth_buffer: self.logarithmic_depth_buffer,
    reversed_depth_buffer,
    skinning: object.is_skinned_mesh(),
    has_position_attribute: attributes.contains("position"),
    morph_targets: morph_attributes.contains("position"),
    morph_normals: morph_attributes.contains("normal"),
    morph_colors: morph_attributes.contains("color"),
    morph_targets_count,
    morph_texture_stride,
    num_sun_lights: lights.sun.length(),
    num_dir_lights: lights.directional.length(),
    num_point_lights: lights.point.length(),
    num_spot_lights: lights.spot.length(),
    num_spot_light_maps: lights.spot_light_map.length(),
    num_rect_area_lights: lights.rect_area.length(),
    num_hemi_lights: lights.hemi.length(),
    num_sun_light_shadows: lights.sun_shadow_map.length(),
    num_dir_light_shadows: lights.directional_shadow_map.length(),
    num_point_light_shadows: lights.point_shadow_map.length(),
    num_spot_light_shadows: lights.spot_shadow_map.length(),
    num_spot_light_shadows_with_maps: lights.num_spot_light_shadows_with_maps,
    num_light_probes: lights.num_light_probes,
    num_light_probe_grids: light_probe_grids
    .filter(fn(grid) {
      match light_probe_grid_of(grid) {
        Some(source) => source.texture() is Some(_)
        // an unregistered object reads `grid.texture` as `undefined`, which is not `null`
        None => true
      }
    })
    .length(),
    num_clipping_planes: self.clipping.num_planes,
    num_clip_intersection: self.clipping.num_intersection,
    dithering: material.dithering,
    shadow_map_enabled: renderer.shadow_map.enabled && shadows.length() > 0,
    shadow_map_type: renderer.shadow_map.type_,
    tone_mapping,
    decode_video_texture: has_map &&
    material.map.unwrap().is_video_texture() &&
    @math.color_management.get_transfer(material.map.unwrap().color_space) ==
    @math.SRGBTransfer,
    decode_video_texture_emissive: has_emissivemap &&
    material.emissive_map.unwrap().is_video_texture() &&
    @math.color_management.get_transfer(
      material.emissive_map.unwrap().color_space,
    ) ==
    @math.SRGBTransfer,
    premultiplied_alpha: material.premultiplied_alpha,
    double_sided: material.side == @core.DoubleSide,
    flip_sided: material.side == @core.BackSide,
    use_depth_packing: match material.depth_packing {
      Some(d) => d >= 0
      None => false
    },
    depth_packing: material.depth_packing.unwrap_or(0),
    index0_attribute_name: material.index0_attribute_name,
    extension_clip_cull_distance,
    extension_multi_draw,
    renderer_extension_parallel_shader_compile,
    custom_program_cache_key: material.custom_program_cache_key(),
    vertex_uv1s: false,
    vertex_uv2s: false,
    vertex_uv3s: false,
  }
  if fog is Some(Fog(_)) {
    webgl_programs_fog_exp2_undefined.set(parameters, true)
  }
  if flat_shading_undefined {
    webgl_programs_flat_shading_undefined.set(parameters, true)
  }

  // the usage of getChannel() determines the active texture channels for this shader

  parameters.vertex_uv1s = self._active_channels.contains(1)
  parameters.vertex_uv2s = self._active_channels.contains(2)
  parameters.vertex_uv3s = self._active_channels.contains(3)
  self._active_channels.clear()
  shader.parameters = @core.JsValue::of(parameters)
  parameters
}

///|
/// `String( value )` as `Array.prototype.join` prints it (`null` / `undefined` are empty).
fn webgl_programs_join_string(value : @core.JsValue) -> String {
  if value.is_null() || value.is_undefined() {
    ""
  } else {
    js_to_string(value)
  }
}

///|
/// A `T | false` field: `None` prints as `false`.
fn webgl_programs_or_false(value : String?) -> String {
  match value {
    Some(v) => v
    None => "false"
  }
}

///|
/// An optional number field: `None` (`null` / `undefined`) prints as the empty string.
fn webgl_programs_or_empty(value : Int32?) -> String {
  match value {
    Some(v) => v.to_string()
    None => ""
  }
}

///|
/// `programCache.getProgramCacheKey( parameters )`.
pub fn WebGLPrograms::get_program_cache_key(
  self : WebGLPrograms,
  parameters : WebGLProgramParameters,
) -> String {
  let array : Array[String] = []
  match parameters.shader_id {
    Some(id) if id != "" => array.push(id)
    _ => {
      array.push(webgl_programs_or_empty(parameters.custom_vertex_shader_id))
      array.push(webgl_programs_or_empty(parameters.custom_fragment_shader_id))
    }
  }
  if parameters.defines is Some(defines) {
    for name in webgl_program_js_key_order(defines) {
      array.push(name)
      array.push(
        webgl_programs_join_string(@core.JsValue::from_json(defines[name])),
      )
    }
  }
  if parameters.is_raw_shader_material == false {
    self.get_program_cache_key_parameters(array, parameters)
    self.get_program_cache_key_booleans(array, parameters)
    array.push(self.renderer.output_color_space())
  }
  array.push(parameters.custom_program_cache_key)
  array.join(",")
}

///|
/// `getProgramCacheKeyParameters( array, parameters )`.
fn WebGLPrograms::get_program_cache_key_parameters(
  _self : WebGLPrograms,
  array : Array[String],
  parameters : WebGLProgramParameters,
) -> Unit {
  let p = parameters
  array.push(p.precision)
  array.push(p.output_color_space)
  array.push(
    match p.env_map_mode {
      Some(m) => m.to_string()
      None => "false"
    },
  )
  array.push(p.env_map_pmrem.to_string())
  array.push(webgl_programs_or_empty(p.env_map_max_lod))
  array.push(webgl_programs_or_empty(p.env_map_size))
  array.push(webgl_programs_or_false(p.map_uv))
  array.push(webgl_programs_or_false(p.alpha_map_uv))
  array.push(webgl_programs_or_false(p.light_map_uv))
  array.push(webgl_programs_or_false(p.ao_map_uv))
  array.push(webgl_programs_or_false(p.bump_map_uv))
  array.push(webgl_programs_or_false(p.normal_map_uv))
  array.push(webgl_programs_or_false(p.displacement_map_uv))
  array.push(webgl_programs_or_false(p.emissive_map_uv))
  array.push(webgl_programs_or_false(p.metalness_map_uv))
  array.push(webgl_programs_or_false(p.roughness_map_uv))
  array.push(webgl_programs_or_false(p.anisotropy_map_uv))
  array.push(webgl_programs_or_false(p.clearcoat_map_uv))
  array.push(webgl_programs_or_false(p.clearcoat_normal_map_uv))
  array.push(webgl_programs_or_false(p.clearcoat_roughness_map_uv))
  array.push(webgl_programs_or_false(p.diffuse_roughness_map_uv))
  array.push(webgl_programs_or_false(p.iridescence_map_uv))
  array.push(webgl_programs_or_false(p.iridescence_thickness_map_uv))
  array.push(webgl_programs_or_false(p.sheen_color_map_uv))
  array.push(webgl_programs_or_false(p.sheen_roughness_map_uv))
  array.push(webgl_programs_or_false(p.specular_map_uv))
  array.push(webgl_programs_or_false(p.specular_color_map_uv))
  array.push(webgl_programs_or_false(p.specular_intensity_map_uv))
  array.push(webgl_programs_or_false(p.transmission_map_uv))
  array.push(webgl_programs_or_false(p.thickness_map_uv))
  array.push(webgl_programs_or_empty(p.combine))
  array.push(
    if webgl_program_parameters_fog_exp2_undefined(p) {
      ""
    } else {
      p.fog_exp2.to_string()
    },
  )
  array.push(p.size_attenuation.to_string())
  array.push(p.morph_targets_count.to_string())
  array.push(p.num_sun_lights.to_string())
  array.push(p.num_dir_lights.to_string())
  array.push(p.num_point_lights.to_string())
  array.push(p.num_spot_lights.to_string())
  array.push(p.num_spot_light_maps.to_string())
  array.push(p.num_hemi_lights.to_string())
  array.push(p.num_rect_area_lights.to_string())
  array.push(p.num_sun_light_shadows.to_string())
  array.push(p.num_dir_light_shadows.to_string())
  array.push(p.num_point_light_shadows.to_string())
  array.push(p.num_spot_light_shadows.to_string())
  array.push(p.num_spot_light_shadows_with_maps.to_string())
  array.push(p.num_light_probes.to_string())
  array.push(p.num_light_probe_grids.to_string())
  array.push(p.shadow_map_type.to_string())
  array.push(p.tone_mapping.to_string())
  array.push(p.num_clipping_planes.to_string())
  array.push(p.num_clip_intersection.to_string())
  array.push(p.depth_packing.to_string())
}

///|
/// `getProgramCacheKeyBooleans( array, parameters )`.
fn WebGLPrograms::get_program_cache_key_booleans(
  self : WebGLPrograms,
  array : Array[String],
  parameters : WebGLProgramParameters,
) -> Unit {
  let p = parameters
  let layers = self._program_layers
  let enable_if = fn(cond : Bool, channel : Int32) {
    if cond {
      layers.enable(channel)
    }
  }
  layers.disable_all()
  enable_if(p.instancing, 0)
  enable_if(p.instancing_color, 1)
  enable_if(p.instancing_morph, 2)
  enable_if(p.matcap, 3)
  enable_if(p.env_map, 4)
  enable_if(p.normal_map_object_space, 5)
  enable_if(p.normal_map_tangent_space, 6)
  enable_if(p.clearcoat, 7)
  enable_if(p.iridescence, 8)
  enable_if(p.alpha_test, 9)
  enable_if(p.vertex_colors, 10)
  enable_if(p.vertex_alphas, 11)
  enable_if(p.vertex_uv1s, 12)
  enable_if(p.vertex_uv2s, 13)
  enable_if(p.vertex_uv3s, 14)
  enable_if(p.vertex_tangents, 15)
  enable_if(p.anisotropy, 16)
  enable_if(p.alpha_hash, 17)
  enable_if(p.batching, 18)
  enable_if(p.dispersion, 19)
  enable_if(p.retroreflection, 24)
  enable_if(p.diffuse_roughness, 25)
  enable_if(p.batching_color, 20)
  enable_if(p.gradient_map, 21)
  enable_if(p.packed_normal_map, 22)
  enable_if(p.vertex_normals, 23)
  array.push(js_to_string(@core.JsValue::of(layers.mask)))
  layers.disable_all()
  enable_if(p.fog, 0)
  enable_if(p.use_fog, 1)
  enable_if(p.flat_shading, 2)
  enable_if(p.logarithmic_depth_buffer, 3)
  enable_if(p.reversed_depth_buffer, 4)
  enable_if(p.skinning, 5)
  enable_if(p.morph_targets, 6)
  enable_if(p.morph_normals, 7)
  enable_if(p.morph_colors, 8)
  enable_if(p.premultiplied_alpha, 9)
  enable_if(p.shadow_map_enabled, 10)
  enable_if(p.double_sided, 11)
  enable_if(p.flip_sided, 12)
  enable_if(p.use_depth_packing, 13)
  enable_if(p.dithering, 14)
  enable_if(p.transmission, 15)
  enable_if(p.sheen, 16)
  enable_if(p.opaque_, 17)
  enable_if(p.points_uvs, 18)
  enable_if(p.decode_video_texture, 19)
  enable_if(p.decode_video_texture_emissive, 20)
  enable_if(p.alpha_to_coverage, 21)
  enable_if(p.num_light_probe_grids > 0, 22)
  enable_if(p.has_position_attribute, 23)
  array.push(js_to_string(@core.JsValue::of(layers.mask)))
}

///|
/// `programCache.getUniforms( material )`: a clone of the `ShaderLib` uniforms, or the
/// material's own for shader materials.
pub fn WebGLPrograms::get_uniforms(
  self : WebGLPrograms,
  material : @core.Material,
) -> Map[String, @core.Uniform] {
  match self.shader_ids.get(material.type_) {
    Some(shader_id) => {
      let shader = @shaders.shader_lib[shader_id]
      @core.UniformsUtils::clone(shader.uniforms)
    }
    None => material.uniforms.unwrap_or(Map([]))
  }
}

///|
/// `programCache.acquireProgram( parameters, cacheKey )`.
pub fn WebGLPrograms::acquire_program(
  self : WebGLPrograms,
  parameters : WebGLProgramParameters,
  cache_key : String,
) -> WebGLProgram {
  match self.programs_map.get(cache_key) {
    Some(program) => {
      program.used_times += 1
      program
    }
    None => {
      let program = WebGLProgram::new(
        self.renderer,
        cache_key,
        parameters,
        self.binding_states,
      )
      self.programs.push(program)
      self.programs_map[cache_key] = program
      program
    }
  }
}

///|
/// `programCache.releaseProgram( program )`.
pub fn WebGLPrograms::release_program(
  self : WebGLPrograms,
  program : WebGLProgram,
) -> Unit {
  program.used_times -= 1
  if program.used_times == 0 {
    // Remove from unordered set
    let programs = self.programs
    let mut i = -1
    for j, p in programs {
      if physical_equal(p, program) {
        i = j
        break
      }
    }
    // `programs[ -1 ] = ...` is a no-op property write upstream
    if i >= 0 {
      programs[i] = programs[programs.length() - 1]
    }
    ignore(programs.pop())

    // Remove from map
    self.programs_map.remove(program.cache_key)

    // Free WebGL resources
    program.destroy()
  }
}

///|
/// `programCache.releaseShaderCache( material )`.
pub fn WebGLPrograms::release_shader_cache(
  self : WebGLPrograms,
  material : @core.Material,
) -> Unit {
  ignore(self._custom_shaders.remove(material))
}

///|
/// `programCache.dispose()`.
pub fn WebGLPrograms::dispose(self : WebGLPrograms) -> Unit {
  self._custom_shaders.dispose()
}
