// Upstream src/renderers/webgl/WebGLMaterials.js. GROUP 3.
// Read `material.reflectivity()`, not the field (see PORTING.md, `src/core`).

///|
pub struct WebGLMaterials {
  renderer : WebGLRenderer
  properties : WebGLProperties
}

///|
/// `new WebGLMaterials( renderer, properties )`.
pub fn WebGLMaterials::new(
  renderer : WebGLRenderer,
  properties : WebGLProperties,
) -> WebGLMaterials {
  { renderer, properties, }
}

///|
let _webgl_materials_m1 : @math.Matrix4 = @math.Matrix4::new()

///|
let _webgl_materials_m : @math.Matrix3 = @math.Matrix3::new().set(
  -1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0,
)

///|
/// `uniforms[ name ]`; upstream throws on a missing uniform.
fn webgl_materials_uniform(
  uniforms : Map[String, @core.Uniform],
  name : String,
) -> @core.Uniform {
  guard uniforms.get(name) is Some(uniform) else {
    abort("WebGLMaterials: missing uniform " + name)
  }
  uniform
}

///|
/// `uniforms[ name ].value = value`.
fn webgl_materials_set(
  uniforms : Map[String, @core.Uniform],
  name : String,
  value : @core.UniformValue,
) -> Unit {
  webgl_materials_uniform(uniforms, name).value = value
}

///|
/// `uniforms[ name ].value = number`; `None` is `undefined`.
fn webgl_materials_set_number(
  uniforms : Map[String, @core.Uniform],
  name : String,
  value : Double?,
) -> Unit {
  webgl_materials_set(
    uniforms,
    name,
    match value {
      Some(value) => Number(value)
      None => Other(@core.JsValue::undefined())
    },
  )
}

///|
fn webgl_materials_color(
  uniforms : Map[String, @core.Uniform],
  name : String,
) -> @math.Color {
  guard webgl_materials_uniform(uniforms, name).value is Color(color) else {
    abort("WebGLMaterials: uniform " + name + " is not a Color")
  }
  color
}

///|
fn webgl_materials_vector2(
  uniforms : Map[String, @core.Uniform],
  name : String,
) -> @math.Vector2 {
  guard webgl_materials_uniform(uniforms, name).value is Vector2(v) else {
    abort("WebGLMaterials: uniform " + name + " is not a Vector2")
  }
  v
}

///|
fn webgl_materials_vector3(
  uniforms : Map[String, @core.Uniform],
  name : String,
) -> @math.Vector3 {
  guard webgl_materials_uniform(uniforms, name).value is Vector3(v) else {
    abort("WebGLMaterials: uniform " + name + " is not a Vector3")
  }
  v
}

///|
fn webgl_materials_matrix3(
  uniforms : Map[String, @core.Uniform],
  name : String,
) -> @math.Matrix3 {
  guard webgl_materials_uniform(uniforms, name).value is Matrix3(m) else {
    abort("WebGLMaterials: uniform " + name + " is not a Matrix3")
  }
  m
}

///|
/// `refreshTransformUniform( map, uniform )`.
fn webgl_materials_refresh_transform_uniform(
  map : @core.Texture,
  uniforms : Map[String, @core.Uniform],
  name : String,
) -> Unit {
  if map.matrix_auto_update {
    map.update_matrix()
  }
  ignore(webgl_materials_matrix3(uniforms, name).copy(map.matrix))
}

///|
/// `uniforms[ name ].value = texture` and its transform, for a set texture.
fn webgl_materials_refresh_map(
  uniforms : Map[String, @core.Uniform],
  map : @core.Texture?,
  name : String,
  transform : String,
) -> Unit {
  if map is Some(map) {
    webgl_materials_set(uniforms, name, Texture(map))
    webgl_materials_refresh_transform_uniform(map, uniforms, transform)
  }
}

///|
/// `materials.refreshFogUniforms( uniforms, fog )`.
pub fn WebGLMaterials::refresh_fog_uniforms(
  self : WebGLMaterials,
  uniforms : Map[String, @core.Uniform],
  fog : @core.SceneFog,
) -> Unit {
  let color_space = @core.get_unlit_uniform_color_space(
    self.renderer.get_render_target(),
    self.renderer.output_color_space(),
  )
  match fog {
    Fog(fog) => {
      ignore(
        fog.color.get_rgb(
          webgl_materials_color(uniforms, "fogColor"),
          color_space~,
        ),
      )
      webgl_materials_set(uniforms, "fogNear", Number(fog.near))
      webgl_materials_set(uniforms, "fogFar", Number(fog.far))
    }
    FogExp2(fog) => {
      ignore(
        fog.color.get_rgb(
          webgl_materials_color(uniforms, "fogColor"),
          color_space~,
        ),
      )
      webgl_materials_set(uniforms, "fogDensity", Number(fog.density))
    }
  }
}

///|
/// `materials.refreshMaterialUniforms( uniforms, material, pixelRatio, height,
/// transmissionRenderTarget )`.
pub fn WebGLMaterials::refresh_material_uniforms(
  self : WebGLMaterials,
  uniforms : Map[String, @core.Uniform],
  material : @core.Material,
  pixel_ratio : Double,
  height : Double,
  transmission_render_target : @core.RenderTarget?,
) -> Unit {
  if material.is_node_material() {
    material.uniforms_need_update = Some(false)
    return
  }
  match material.material_type {
    MeshBasicMaterial => self.refresh_uniforms_common(uniforms, material)
    MeshLambertMaterial => {
      self.refresh_uniforms_common(uniforms, material)
      if material.env_map is Some(_) {
        webgl_materials_set_number(
          uniforms,
          "envMapIntensity",
          material.env_map_intensity,
        )
      }
    }
    MeshToonMaterial => {
      self.refresh_uniforms_common(uniforms, material)
      webgl_materials_refresh_uniforms_toon(uniforms, material)
    }
    MeshPhongMaterial => {
      self.refresh_uniforms_common(uniforms, material)
      webgl_materials_refresh_uniforms_phong(uniforms, material)
      if material.env_map is Some(_) {
        webgl_materials_set_number(
          uniforms,
          "envMapIntensity",
          material.env_map_intensity,
        )
      }
    }
    MeshStandardMaterial | MeshPhysicalMaterial => {
      self.refresh_uniforms_common(uniforms, material)
      webgl_materials_refresh_uniforms_standard(uniforms, material)
      if material.is_mesh_physical_material() {
        webgl_materials_refresh_uniforms_physical(
          uniforms, material, transmission_render_target,
        )
      }
    }
    MeshMatcapMaterial => {
      self.refresh_uniforms_common(uniforms, material)
      webgl_materials_refresh_uniforms_matcap(uniforms, material)
    }
    MeshDepthMaterial => self.refresh_uniforms_common(uniforms, material)
    MeshDistanceMaterial => {
      self.refresh_uniforms_common(uniforms, material)
      self.refresh_uniforms_distance(uniforms, material)
    }
    MeshNormalMaterial => self.refresh_uniforms_common(uniforms, material)
    LineBasicMaterial | LineDashedMaterial => {
      webgl_materials_refresh_uniforms_line(uniforms, material)
      if material.is_line_dashed_material() {
        webgl_materials_refresh_uniforms_dash(uniforms, material)
      }
    }
    PointsMaterial =>
      webgl_materials_refresh_uniforms_points(
        uniforms, material, pixel_ratio, height,
      )
    SpriteMaterial =>
      webgl_materials_refresh_uniforms_sprites(uniforms, material)
    ShadowMaterial => {
      ignore(
        webgl_materials_color(uniforms, "color").copy(material.color.unwrap()),
      )
      webgl_materials_set(uniforms, "opacity", Number(material.opacity))
    }
    ShaderMaterial | RawShaderMaterial =>
      material.uniforms_need_update = Some(false) // #15581
    Material => ()
  }
}

///|
/// `refreshUniformsCommon( uniforms, material )`.
fn WebGLMaterials::refresh_uniforms_common(
  self : WebGLMaterials,
  uniforms : Map[String, @core.Uniform],
  material : @core.Material,
) -> Unit {
  webgl_materials_set(uniforms, "opacity", Number(material.opacity))
  if material.color is Some(color) {
    ignore(webgl_materials_color(uniforms, "diffuse").copy(color))
  }
  if material.emissive is Some(emissive) {
    ignore(
      webgl_materials_color(uniforms, "emissive")
      .copy(emissive)
      .multiply_scalar(material.emissive_intensity.unwrap()),
    )
  }
  webgl_materials_refresh_map(uniforms, material.map, "map", "mapTransform")
  webgl_materials_refresh_map(
    uniforms,
    material.alpha_map,
    "alphaMap",
    "alphaMapTransform",
  )
  if material.bump_map is Some(bump_map) {
    webgl_materials_set(uniforms, "bumpMap", Texture(bump_map))
    webgl_materials_refresh_transform_uniform(
      bump_map, uniforms, "bumpMapTransform",
    )
    let bump_scale = material.bump_scale.unwrap()
    webgl_materials_set(uniforms, "bumpScale", Number(bump_scale))
    if material.side == @core.BackSide {
      webgl_materials_set(uniforms, "bumpScale", Number(bump_scale * -1.0))
    }
  }
  if material.normal_map is Some(normal_map) {
    webgl_materials_set(uniforms, "normalMap", Texture(normal_map))
    webgl_materials_refresh_transform_uniform(
      normal_map, uniforms, "normalMapTransform",
    )
    let normal_scale = webgl_materials_vector2(uniforms, "normalScale")
    ignore(normal_scale.copy(material.normal_scale.unwrap()))
    if material.side == @core.BackSide {
      ignore(normal_scale.negate())
    }
  }
  if material.displacement_map is Some(displacement_map) {
    webgl_materials_set(uniforms, "displacementMap", Texture(displacement_map))
    webgl_materials_refresh_transform_uniform(
      displacement_map, uniforms, "displacementMapTransform",
    )
    webgl_materials_set_number(
      uniforms,
      "displacementScale",
      material.displacement_scale,
    )
    webgl_materials_set_number(
      uniforms,
      "displacementBias",
      material.displacement_bias,
    )
  }
  webgl_materials_refresh_map(
    uniforms,
    material.emissive_map,
    "emissiveMap",
    "emissiveMapTransform",
  )
  webgl_materials_refresh_map(
    uniforms,
    material.specular_map,
    "specularMap",
    "specularMapTransform",
  )
  if material.alpha_test() > 0.0 {
    webgl_materials_set(uniforms, "alphaTest", Number(material.alpha_test()))
  }
  let material_properties = self.properties.get_material(material)
  let env_map = material_properties.env_map
  let env_map_rotation = material_properties.env_map_rotation
  if env_map is Some(env_map) {
    webgl_materials_set(uniforms, "envMap", Texture(env_map))

    // note: since the matrix is orthonormal, we can use the more-efficient transpose() in lieu of invert()
    let rotation = webgl_materials_matrix3(uniforms, "envMapRotation")
    ignore(
      rotation
      .set_from_matrix4(
        _webgl_materials_m1.make_rotation_from_euler(env_map_rotation.unwrap()),
      )
      .transpose(),
    )
    if env_map.is_cube_texture() && env_map.is_render_target_texture == false {
      ignore(rotation.premultiply(_webgl_materials_m))
    }
    webgl_materials_set_number(
      uniforms,
      "reflectivity",
      material.reflectivity(),
    )
    webgl_materials_set_number(uniforms, "ior", material.ior)
    webgl_materials_set_number(
      uniforms,
      "refractionRatio",
      material.refraction_ratio,
    )
  }
  if material.light_map is Some(light_map) {
    webgl_materials_set(uniforms, "lightMap", Texture(light_map))
    webgl_materials_set_number(
      uniforms,
      "lightMapIntensity",
      material.light_map_intensity,
    )
    webgl_materials_refresh_transform_uniform(
      light_map, uniforms, "lightMapTransform",
    )
  }
  if material.ao_map is Some(ao_map) {
    webgl_materials_set(uniforms, "aoMap", Texture(ao_map))
    webgl_materials_set_number(
      uniforms,
      "aoMapIntensity",
      material.ao_map_intensity,
    )
    webgl_materials_refresh_transform_uniform(
      ao_map, uniforms, "aoMapTransform",
    )
  }
}

///|
/// `refreshUniformsLine( uniforms, material )`.
fn webgl_materials_refresh_uniforms_line(
  uniforms : Map[String, @core.Uniform],
  material : @core.Material,
) -> Unit {
  ignore(
    webgl_materials_color(uniforms, "diffuse").copy(material.color.unwrap()),
  )
  webgl_materials_set(uniforms, "opacity", Number(material.opacity))
  webgl_materials_refresh_map(uniforms, material.map, "map", "mapTransform")
}

///|
/// `refreshUniformsDash( uniforms, material )`.
fn webgl_materials_refresh_uniforms_dash(
  uniforms : Map[String, @core.Uniform],
  material : @core.Material,
) -> Unit {
  let dash_size = material.dash_size.unwrap()
  webgl_materials_set(uniforms, "dashSize", Number(dash_size))
  webgl_materials_set(
    uniforms,
    "totalSize",
    Number(dash_size + material.gap_size.unwrap()),
  )
  webgl_materials_set_number(uniforms, "scale", material.scale)
}

///|
/// `refreshUniformsPoints( uniforms, material, pixelRatio, height )`.
fn webgl_materials_refresh_uniforms_points(
  uniforms : Map[String, @core.Uniform],
  material : @core.Material,
  pixel_ratio : Double,
  height : Double,
) -> Unit {
  ignore(
    webgl_materials_color(uniforms, "diffuse").copy(material.color.unwrap()),
  )
  webgl_materials_set(uniforms, "opacity", Number(material.opacity))
  webgl_materials_set(
    uniforms,
    "size",
    Number(material.size.unwrap() * pixel_ratio),
  )
  webgl_materials_set(uniforms, "scale", Number(height * 0.5))
  webgl_materials_refresh_map(uniforms, material.map, "map", "uvTransform")
  webgl_materials_refresh_map(
    uniforms,
    material.alpha_map,
    "alphaMap",
    "alphaMapTransform",
  )
  if material.alpha_test() > 0.0 {
    webgl_materials_set(uniforms, "alphaTest", Number(material.alpha_test()))
  }
}

///|
/// `refreshUniformsSprites( uniforms, material )`.
fn webgl_materials_refresh_uniforms_sprites(
  uniforms : Map[String, @core.Uniform],
  material : @core.Material,
) -> Unit {
  ignore(
    webgl_materials_color(uniforms, "diffuse").copy(material.color.unwrap()),
  )
  webgl_materials_set(uniforms, "opacity", Number(material.opacity))
  webgl_materials_set_number(uniforms, "rotation", material.rotation)
  webgl_materials_refresh_map(uniforms, material.map, "map", "mapTransform")
  webgl_materials_refresh_map(
    uniforms,
    material.alpha_map,
    "alphaMap",
    "alphaMapTransform",
  )
  if material.alpha_test() > 0.0 {
    webgl_materials_set(uniforms, "alphaTest", Number(material.alpha_test()))
  }
}

///|
/// `refreshUniformsPhong( uniforms, material )`.
fn webgl_materials_refresh_uniforms_phong(
  uniforms : Map[String, @core.Uniform],
  material : @core.Material,
) -> Unit {
  ignore(
    webgl_materials_color(uniforms, "specular").copy(material.specular.unwrap()),
  )
  // to prevent pow( 0.0, 0.0 )
  webgl_materials_set(
    uniforms,
    "shininess",
    Number(js_math_max(material.shininess.unwrap(), 1.0e-4)),
  )
}

///|
/// `refreshUniformsToon( uniforms, material )`.
fn webgl_materials_refresh_uniforms_toon(
  uniforms : Map[String, @core.Uniform],
  material : @core.Material,
) -> Unit {
  if material.gradient_map is Some(gradient_map) {
    webgl_materials_set(uniforms, "gradientMap", Texture(gradient_map))
  }
}

///|
/// `refreshUniformsStandard( uniforms, material )`.
fn webgl_materials_refresh_uniforms_standard(
  uniforms : Map[String, @core.Uniform],
  material : @core.Material,
) -> Unit {
  webgl_materials_set_number(uniforms, "metalness", material.metalness)
  webgl_materials_refresh_map(
    uniforms,
    material.metalness_map,
    "metalnessMap",
    "metalnessMapTransform",
  )
  webgl_materials_set_number(uniforms, "roughness", material.roughness)
  webgl_materials_refresh_map(
    uniforms,
    material.roughness_map,
    "roughnessMap",
    "roughnessMapTransform",
  )
  if material.env_map is Some(_) {
    //uniforms.envMap.value = material.envMap; // part of uniforms common
    webgl_materials_set_number(
      uniforms,
      "envMapIntensity",
      material.env_map_intensity,
    )
  }
}

///|
/// `value > 0` for an optional number (`undefined > 0` is false).
fn webgl_materials_positive(value : Double?) -> Bool {
  match value {
    Some(value) => value > 0.0
    None => false
  }
}

///|
/// `refreshUniformsPhysical( uniforms, material, transmissionRenderTarget )`.
fn webgl_materials_refresh_uniforms_physical(
  uniforms : Map[String, @core.Uniform],
  material : @core.Material,
  transmission_render_target : @core.RenderTarget?,
) -> Unit {
  webgl_materials_set_number(uniforms, "ior", material.ior) // also part of uniforms common
  if webgl_materials_positive(material.diffuse_roughness()) {
    webgl_materials_set_number(
      uniforms,
      "diffuseRoughness",
      material.diffuse_roughness(),
    )
    webgl_materials_refresh_map(
      uniforms,
      material.diffuse_roughness_map,
      "diffuseRoughnessMap",
      "diffuseRoughnessMapTransform",
    )
  }
  if webgl_materials_positive(material.sheen()) {
    ignore(
      webgl_materials_color(uniforms, "sheenColor")
      .copy(material.sheen_color.unwrap())
      .multiply_scalar(material.sheen().unwrap()),
    )
    webgl_materials_set_number(
      uniforms,
      "sheenRoughness",
      material.sheen_roughness,
    )
    webgl_materials_refresh_map(
      uniforms,
      material.sheen_color_map,
      "sheenColorMap",
      "sheenColorMapTransform",
    )
    webgl_materials_refresh_map(
      uniforms,
      material.sheen_roughness_map,
      "sheenRoughnessMap",
      "sheenRoughnessMapTransform",
    )
  }
  if webgl_materials_positive(material.clearcoat()) {
    webgl_materials_set_number(uniforms, "clearcoat", material.clearcoat())
    webgl_materials_set_number(
      uniforms,
      "clearcoatRoughness",
      material.clearcoat_roughness,
    )
    webgl_materials_refresh_map(
      uniforms,
      material.clearcoat_map,
      "clearcoatMap",
      "clearcoatMapTransform",
    )
    webgl_materials_refresh_map(
      uniforms,
      material.clearcoat_roughness_map,
      "clearcoatRoughnessMap",
      "clearcoatRoughnessMapTransform",
    )
    if material.clearcoat_normal_map is Some(clearcoat_normal_map) {
      webgl_materials_set(
        uniforms,
        "clearcoatNormalMap",
        Texture(clearcoat_normal_map),
      )
      webgl_materials_refresh_transform_uniform(
        clearcoat_normal_map, uniforms, "clearcoatNormalMapTransform",
      )
      let scale = webgl_materials_vector2(uniforms, "clearcoatNormalScale")
      ignore(scale.copy(material.clearcoat_normal_scale.unwrap()))
      if material.side == @core.BackSide {
        ignore(scale.negate())
      }
    }
  }
  if webgl_materials_positive(material.dispersion()) {
    webgl_materials_set_number(uniforms, "dispersion", material.dispersion())
  }
  if webgl_materials_positive(material.retroreflectivity()) {
    webgl_materials_set_number(
      uniforms,
      "retroreflectivity",
      material.retroreflectivity(),
    )
  }
  if webgl_materials_positive(material.iridescence()) {
    webgl_materials_set_number(uniforms, "iridescence", material.iridescence())
    webgl_materials_set_number(
      uniforms,
      "iridescenceIOR",
      material.iridescence_ior,
    )
    webgl_materials_set_number(
      uniforms,
      "iridescenceThicknessMinimum",
      material.iridescence_thickness_minimum,
    )
    webgl_materials_set_number(
      uniforms,
      "iridescenceThicknessMaximum",
      material.iridescence_thickness_maximum,
    )
    webgl_materials_refresh_map(
      uniforms,
      material.iridescence_map,
      "iridescenceMap",
      "iridescenceMapTransform",
    )
    webgl_materials_refresh_map(
      uniforms,
      material.iridescence_thickness_map,
      "iridescenceThicknessMap",
      "iridescenceThicknessMapTransform",
    )
  }
  if webgl_materials_positive(material.transmission()) {
    webgl_materials_set_number(
      uniforms,
      "transmission",
      material.transmission(),
    )
    guard transmission_render_target is Some(target) else {
      abort("WebGLMaterials: transmission without a transmission render target")
    }
    webgl_materials_set(
      uniforms,
      "transmissionSamplerMap",
      Texture(target.texture()),
    )
    ignore(
      webgl_materials_vector2(uniforms, "transmissionSamplerSize").set(
        target.width.to_double(),
        target.height.to_double(),
      ),
    )
    webgl_materials_refresh_map(
      uniforms,
      material.transmission_map,
      "transmissionMap",
      "transmissionMapTransform",
    )
    webgl_materials_set_number(uniforms, "thickness", material.thickness)
    webgl_materials_refresh_map(
      uniforms,
      material.thickness_map,
      "thicknessMap",
      "thicknessMapTransform",
    )
    webgl_materials_set_number(
      uniforms,
      "attenuationDistance",
      material.attenuation_distance,
    )
    ignore(
      webgl_materials_color(uniforms, "attenuationColor").copy(
        material.attenuation_color.unwrap(),
      ),
    )
  }
  if webgl_materials_positive(material.anisotropy()) {
    let anisotropy = material.anisotropy().unwrap()
    let rotation = material.anisotropy_rotation.unwrap()
    ignore(
      webgl_materials_vector2(uniforms, "anisotropyVector").set(
        anisotropy * @cmath.cos(rotation),
        anisotropy * @cmath.sin(rotation),
      ),
    )
    webgl_materials_refresh_map(
      uniforms,
      material.anisotropy_map,
      "anisotropyMap",
      "anisotropyMapTransform",
    )
  }
  webgl_materials_set_number(
    uniforms,
    "specularIntensity",
    material.specular_intensity,
  )
  ignore(
    webgl_materials_color(uniforms, "specularColor").copy(
      material.specular_color.unwrap(),
    ),
  )
  webgl_materials_refresh_map(
    uniforms,
    material.specular_color_map,
    "specularColorMap",
    "specularColorMapTransform",
  )
  webgl_materials_refresh_map(
    uniforms,
    material.specular_intensity_map,
    "specularIntensityMap",
    "specularIntensityMapTransform",
  )
}

///|
/// `refreshUniformsMatcap( uniforms, material )`.
fn webgl_materials_refresh_uniforms_matcap(
  uniforms : Map[String, @core.Uniform],
  material : @core.Material,
) -> Unit {
  if material.matcap is Some(matcap) {
    webgl_materials_set(uniforms, "matcap", Texture(matcap))
  }
}

///|
/// `refreshUniformsDistance( uniforms, material )`.
fn WebGLMaterials::refresh_uniforms_distance(
  self : WebGLMaterials,
  uniforms : Map[String, @core.Uniform],
  material : @core.Material,
) -> Unit {
  guard self.properties.get_material(material).light is Some(light) else {
    abort("WebGLMaterials: MeshDistanceMaterial without a light")
  }
  ignore(
    webgl_materials_vector3(uniforms, "referencePosition").set_from_matrix_position(
      light.matrix_world,
    ),
  )
  guard light.as_light().shadow is Some(shadow) else {
    abort("WebGLMaterials: light without shadow")
  }
  webgl_materials_set(
    uniforms,
    "nearDistance",
    Number(webgl_shadow_map_camera_near(shadow.camera)),
  )
  webgl_materials_set(
    uniforms,
    "farDistance",
    Number(webgl_shadow_map_camera_far(shadow.camera)),
  )
}
