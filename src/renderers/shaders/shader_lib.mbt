// Upstream src/renderers/shaders/ShaderLib.js.

///|
/// One `ShaderLib` entry.
pub(all) struct ShaderLibEntry {
  mut uniforms : Map[String, @core.Uniform]
  mut vertex_shader : String
  mut fragment_shader : String
}

///|
let shader_lib_standard : ShaderLibEntry = {
  uniforms: @core.merge_uniforms([
    uniforms_lib_common,
    uniforms_lib_envmap,
    uniforms_lib_aomap,
    uniforms_lib_lightmap,
    uniforms_lib_emissivemap,
    uniforms_lib_bumpmap,
    uniforms_lib_normalmap,
    uniforms_lib_displacementmap,
    uniforms_lib_roughnessmap,
    uniforms_lib_metalnessmap,
    uniforms_lib_fog,
    uniforms_lib_lights,
    Map([
      ("emissive", uniform_color(0x000000)),
      ("roughness", uniform_number(1.0)),
      ("metalness", uniform_number(0.0)),
      ("envMapIntensity", uniform_number(1.0)),
    ]),
  ]),
  vertex_shader: chunk_meshphysical_vert,
  fragment_shader: chunk_meshphysical_frag,
}

///|
let shader_lib_physical : ShaderLibEntry = {
  uniforms: @core.merge_uniforms([
    shader_lib_standard.uniforms,
    Map([
      ("clearcoat", uniform_number(0.0)),
      ("clearcoatMap", uniform_null()),
      ("clearcoatMapTransform", uniform_matrix3()),
      ("clearcoatNormalMap", uniform_null()),
      ("clearcoatNormalMapTransform", uniform_matrix3()),
      ("clearcoatNormalScale", uniform_vector2(1.0, 1.0)),
      ("clearcoatRoughness", uniform_number(0.0)),
      ("clearcoatRoughnessMap", uniform_null()),
      ("clearcoatRoughnessMapTransform", uniform_matrix3()),
      ("diffuseRoughness", uniform_number(0.0)),
      ("diffuseRoughnessMap", uniform_null()),
      ("diffuseRoughnessMapTransform", uniform_matrix3()),
      ("dispersion", uniform_number(0.0)),
      ("retroreflectivity", uniform_number(0.0)),
      ("iridescence", uniform_number(0.0)),
      ("iridescenceMap", uniform_null()),
      ("iridescenceMapTransform", uniform_matrix3()),
      ("iridescenceIOR", uniform_number(1.3)),
      ("iridescenceThicknessMinimum", uniform_number(100.0)),
      ("iridescenceThicknessMaximum", uniform_number(400.0)),
      ("iridescenceThicknessMap", uniform_null()),
      ("iridescenceThicknessMapTransform", uniform_matrix3()),
      ("sheen", uniform_number(0.0)),
      ("sheenColor", uniform_color(0x000000)),
      ("sheenColorMap", uniform_null()),
      ("sheenColorMapTransform", uniform_matrix3()),
      ("sheenRoughness", uniform_number(1.0)),
      ("sheenRoughnessMap", uniform_null()),
      ("sheenRoughnessMapTransform", uniform_matrix3()),
      ("transmission", uniform_number(0.0)),
      ("transmissionMap", uniform_null()),
      ("transmissionMapTransform", uniform_matrix3()),
      ("transmissionSamplerSize", uniform_vector2(0.0, 0.0)),
      ("transmissionSamplerMap", uniform_null()),
      ("thickness", uniform_number(0.0)),
      ("thicknessMap", uniform_null()),
      ("thicknessMapTransform", uniform_matrix3()),
      ("attenuationDistance", uniform_number(0.0)),
      ("attenuationColor", uniform_color(0x000000)),
      (
        "specularColor",
        @core.Uniform::new(Color(@math.Color::new(1.0, 1.0, 1.0))),
      ),
      ("specularColorMap", uniform_null()),
      ("specularColorMapTransform", uniform_matrix3()),
      ("specularIntensity", uniform_number(1.0)),
      ("specularIntensityMap", uniform_null()),
      ("specularIntensityMapTransform", uniform_matrix3()),
      ("anisotropyVector", uniform_vector2(0.0, 0.0)),
      ("anisotropyMap", uniform_null()),
      ("anisotropyMapTransform", uniform_matrix3()),
    ]),
  ]),
  vertex_shader: chunk_meshphysical_vert,
  fragment_shader: chunk_meshphysical_frag,
}

///|
/// Upstream `ShaderLib`, in upstream key order: `physical` comes last.
pub let shader_lib : Map[String, ShaderLibEntry] = Map([
  (
    "basic",
    {
      uniforms: @core.merge_uniforms([
        uniforms_lib_common, uniforms_lib_specularmap, uniforms_lib_envmap, uniforms_lib_aomap,
        uniforms_lib_lightmap, uniforms_lib_fog,
      ]),
      vertex_shader: chunk_meshbasic_vert,
      fragment_shader: chunk_meshbasic_frag,
    },
  ),
  (
    "lambert",
    {
      uniforms: @core.merge_uniforms([
        uniforms_lib_common,
        uniforms_lib_specularmap,
        uniforms_lib_envmap,
        uniforms_lib_aomap,
        uniforms_lib_lightmap,
        uniforms_lib_emissivemap,
        uniforms_lib_bumpmap,
        uniforms_lib_normalmap,
        uniforms_lib_displacementmap,
        uniforms_lib_fog,
        uniforms_lib_lights,
        Map([
          ("emissive", uniform_color(0x000000)),
          ("envMapIntensity", uniform_number(1.0)),
        ]),
      ]),
      vertex_shader: chunk_meshlambert_vert,
      fragment_shader: chunk_meshlambert_frag,
    },
  ),
  (
    "phong",
    {
      uniforms: @core.merge_uniforms([
        uniforms_lib_common,
        uniforms_lib_specularmap,
        uniforms_lib_envmap,
        uniforms_lib_aomap,
        uniforms_lib_lightmap,
        uniforms_lib_emissivemap,
        uniforms_lib_bumpmap,
        uniforms_lib_normalmap,
        uniforms_lib_displacementmap,
        uniforms_lib_fog,
        uniforms_lib_lights,
        Map([
          ("emissive", uniform_color(0x000000)),
          ("specular", uniform_color(0x111111)),
          ("shininess", uniform_number(30.0)),
          ("envMapIntensity", uniform_number(1.0)),
        ]),
      ]),
      vertex_shader: chunk_meshphong_vert,
      fragment_shader: chunk_meshphong_frag,
    },
  ),
  ("standard", shader_lib_standard),
  (
    "toon",
    {
      uniforms: @core.merge_uniforms([
        uniforms_lib_common,
        uniforms_lib_aomap,
        uniforms_lib_lightmap,
        uniforms_lib_emissivemap,
        uniforms_lib_bumpmap,
        uniforms_lib_normalmap,
        uniforms_lib_displacementmap,
        uniforms_lib_gradientmap,
        uniforms_lib_fog,
        uniforms_lib_lights,
        Map([("emissive", uniform_color(0x000000))]),
      ]),
      vertex_shader: chunk_meshtoon_vert,
      fragment_shader: chunk_meshtoon_frag,
    },
  ),
  (
    "matcap",
    {
      uniforms: @core.merge_uniforms([
        uniforms_lib_common,
        uniforms_lib_bumpmap,
        uniforms_lib_normalmap,
        uniforms_lib_displacementmap,
        uniforms_lib_fog,
        Map([("matcap", uniform_null())]),
      ]),
      vertex_shader: chunk_meshmatcap_vert,
      fragment_shader: chunk_meshmatcap_frag,
    },
  ),
  (
    "points",
    {
      uniforms: @core.merge_uniforms([uniforms_lib_points, uniforms_lib_fog]),
      vertex_shader: chunk_points_vert,
      fragment_shader: chunk_points_frag,
    },
  ),
  (
    "dashed",
    {
      uniforms: @core.merge_uniforms([
        uniforms_lib_common,
        uniforms_lib_fog,
        Map([
          ("scale", uniform_number(1.0)),
          ("dashSize", uniform_number(1.0)),
          ("totalSize", uniform_number(2.0)),
        ]),
      ]),
      vertex_shader: chunk_linedashed_vert,
      fragment_shader: chunk_linedashed_frag,
    },
  ),
  (
    "depth",
    {
      uniforms: @core.merge_uniforms([
        uniforms_lib_common, uniforms_lib_displacementmap,
      ]),
      vertex_shader: chunk_depth_vert,
      fragment_shader: chunk_depth_frag,
    },
  ),
  (
    "normal",
    {
      uniforms: @core.merge_uniforms([
        uniforms_lib_common,
        uniforms_lib_bumpmap,
        uniforms_lib_normalmap,
        uniforms_lib_displacementmap,
        Map([("opacity", uniform_number(1.0))]),
      ]),
      vertex_shader: chunk_meshnormal_vert,
      fragment_shader: chunk_meshnormal_frag,
    },
  ),
  (
    "sprite",
    {
      uniforms: @core.merge_uniforms([uniforms_lib_sprite, uniforms_lib_fog]),
      vertex_shader: chunk_sprite_vert,
      fragment_shader: chunk_sprite_frag,
    },
  ),
  (
    "background",
    {
      uniforms: Map([
        ("uvTransform", uniform_matrix3()),
        ("t2D", uniform_null()),
        ("backgroundIntensity", uniform_number(1.0)),
      ]),
      vertex_shader: chunk_background_vert,
      fragment_shader: chunk_background_frag,
    },
  ),
  (
    "backgroundCube",
    {
      uniforms: Map([
        ("envMap", uniform_null()),
        ("backgroundBlurriness", uniform_number(0.0)),
        ("backgroundIntensity", uniform_number(1.0)),
        ("backgroundRotation", uniform_matrix3()),
      ]),
      vertex_shader: chunk_background_cube_vert,
      fragment_shader: chunk_background_cube_frag,
    },
  ),
  (
    "cube",
    {
      uniforms: Map([
        ("tCube", uniform_null()),
        ("tFlip", uniform_number(-1.0)),
        ("opacity", uniform_number(1.0)),
      ]),
      vertex_shader: chunk_cube_vert,
      fragment_shader: chunk_cube_frag,
    },
  ),
  (
    "equirect",
    {
      uniforms: Map([("tEquirect", uniform_null())]),
      vertex_shader: chunk_equirect_vert,
      fragment_shader: chunk_equirect_frag,
    },
  ),
  (
    "distance",
    {
      uniforms: @core.merge_uniforms([
        uniforms_lib_common,
        uniforms_lib_displacementmap,
        Map([
          (
            "referencePosition",
            @core.Uniform::new(Vector3(@math.Vector3::new(0.0, 0.0, 0.0))),
          ),
          ("nearDistance", uniform_number(1.0)),
          ("farDistance", uniform_number(1000.0)),
        ]),
      ]),
      vertex_shader: chunk_distance_vert,
      fragment_shader: chunk_distance_frag,
    },
  ),
  (
    "shadow",
    {
      uniforms: @core.merge_uniforms([
        uniforms_lib_lights,
        uniforms_lib_fog,
        Map([
          ("color", uniform_color(0x00000)),
          ("opacity", uniform_number(1.0)),
        ]),
      ]),
      vertex_shader: chunk_shadow_vert,
      fragment_shader: chunk_shadow_frag,
    },
  ),
  ("physical", shader_lib_physical),
])
