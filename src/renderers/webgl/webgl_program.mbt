// Upstream src/renderers/webgl/WebGLProgram.js. GROUP 2.
//
// Foundation: the struct, `get_uniforms` / `get_attributes` (the lazy-cache wrappers
// around `onFirstUse`). Group 2 fills `WebGLProgram::new`, `on_first_use`, `is_ready`,
// `destroy` and the module-level helpers (`resolveIncludes`, `unrollLoops`, prefixes, ...).
//
// The regular-expression passes (`resolveIncludes`, `unrollLoops`, `replaceLightNums`,
// `replaceClippingPlaneNums`) run upstream's own patterns through JS so the generated
// GLSL is byte-identical; chunk lookups call back into `@shaders.shader_chunk`.

///|
/// `{ type, location, locationSize }` from `fetchAttributeLocations`.
pub(all) struct ProgramAttribute {
  type_ : Int32
  location : Int32
  location_size : Int32
}

///|
/// `{ log, prefix }` of one shader in `program.diagnostics`.
pub(all) struct ShaderDiagnostics {
  log : String
  prefix : String
}

///|
/// `program.diagnostics`, set when `renderer.debug.checkShaderErrors` found logs.
pub(all) struct WebGLProgramDiagnostics {
  runnable : Bool
  program_log : String
  vertex_shader : ShaderDiagnostics
  fragment_shader : ShaderDiagnostics
}

///|
pub(all) struct WebGLProgram {
  /// `parameters.shaderType`.
  type_ : String
  /// `parameters.shaderName`.
  name : String
  id : Int32
  cache_key : String
  mut used_times : Int32
  /// `undefined` after `destroy()`.
  mut program : GLProgram?
  vertex_shader : GLShader
  fragment_shader : GLShader
  mut diagnostics : WebGLProgramDiagnostics?
  // closure state
  renderer : WebGLRenderer
  gl : WebGL2RenderingContext
  binding_states : WebGLBindingStates
  prefix_vertex : String
  prefix_fragment : String
  mut cached_uniforms : WebGLUniforms?
  mut cached_attributes : Map[String, ProgramAttribute]?
  mut program_ready : Bool
}

///|
/// The closure's `program` of each `WebGLProgram`, which `destroy()` does not clear (the
/// struct has no private field for it, so test stand-ins can still be built).
let webgl_program_gl_programs : WeakMap[WebGLProgram, GLProgram] = WeakMap::new()

///|
/// The closure's `program`.
fn WebGLProgram::gl_program(self : WebGLProgram) -> GLProgram {
  match webgl_program_gl_programs.get(self) {
    Some(program) => program
    None => self.program.unwrap()
  }
}

///|
/// From https://www.khronos.org/registry/webgl/extensions/KHR_parallel_shader_compile/
const WEBGL_PROGRAM_COMPLETION_STATUS_KHR : Int32 = 0x91B1

///|
let webgl_program_id_count : Ref[Int32] = { val: 0, }

///|
extern "js" fn webgl_program_handle_source(
  string : String,
  error_line : Int32,
) -> String =
  #|(string, errorLine) => {
  #|  const lines = string.split('\n');
  #|  const lines2 = [];
  #|  const from = Math.max(errorLine - 6, 0);
  #|  const to = Math.min(errorLine + 6, lines.length);
  #|  for (let i = from; i < to; i++) {
  #|    const line = i + 1;
  #|    lines2.push(`${line === errorLine ? '>' : ' '} ${line}: ${lines[i]}`);
  #|  }
  #|  return lines2.join('\n');
  #|}

///|
/// `/ERROR: 0:(\d+)/.exec( errors )`: the line number, or -1 without a match.
extern "js" fn webgl_program_error_line(errors : String) -> Int32 =
  #|(errors) => {
  #|  const m = /ERROR: 0:(\d+)/.exec(errors);
  #|  return m ? parseInt(m[1]) : -1;
  #|}

///|
extern "js" fn webgl_program_to_fixed4(x : Double) -> String = "(x) => x.toFixed(4)"

///|
extern "js" fn webgl_program_trim(s : String) -> String = "(s) => s.trim()"

///|
let webgl_program_m0 : @math.Matrix3 = @math.Matrix3::new()

///|
/// `getEncodingComponents( colorSpace )`.
fn webgl_program_get_encoding_components(
  color_space : String,
) -> (String, String) {
  let cm = @math.color_management
  ignore(cm._get_matrix(webgl_program_m0, cm.working_color_space, color_space))
  let encoding_matrix = "mat3( " +
    webgl_program_m0.elements.map(webgl_program_to_fixed4).join(",") +
    " )"
  match cm.get_transfer(color_space) {
    @math.LinearTransfer => (encoding_matrix, "LinearTransferOETF")
    @math.SRGBTransfer => (encoding_matrix, "sRGBTransferOETF")
    _ => {
      @core.warn("WebGLProgram: Unsupported color space:  " + color_space)
      (encoding_matrix, "LinearTransferOETF")
    }
  }
}

///|
/// `getShaderErrors( gl, shader, type )`.
fn webgl_program_get_shader_errors(
  gl : WebGL2RenderingContext,
  shader : GLShader,
  type_ : String,
) -> String {
  let status = gl.get_shader_parameter(shader, GL_COMPILE_STATUS)
  let shader_info_log = gl.get_shader_info_log(shader).unwrap_or("")
  let errors = webgl_program_trim(shader_info_log)
  if js_truthy(status) && errors == "" {
    return ""
  }
  let error_line = webgl_program_error_line(errors)
  if error_line >= 0 {
    // --enable-privileged-webgl-extension
    // log( '**' + type + '**', gl.getExtension( 'WEBGL_debug_shaders' ).getTranslatedShaderSource( shader ) );

    type_.to_upper() +
    "\n\n" +
    errors +
    "\n\n" +
    webgl_program_handle_source(
      gl.get_shader_source(shader).unwrap_or(""),
      error_line,
    )
  } else {
    errors
  }
}

///|
/// `getTexelEncodingFunction( functionName, colorSpace )`.
fn webgl_program_get_texel_encoding_function(
  function_name : String,
  color_space : String,
) -> String {
  let components = webgl_program_get_encoding_components(color_space)
  [
    "vec4 \{function_name}( vec4 value ) {",
    "\treturn \{components.1}( vec4( \{components.0} * value.rgb, value.a ) );",
    "}",
  ].join("\n")
}

///|
/// `toneMappingFunctions[ toneMapping ]`.
fn webgl_program_tone_mapping_name(tone_mapping : Int32) -> String? {
  match tone_mapping {
    @core.LinearToneMapping => Some("Linear")
    @core.ReinhardToneMapping => Some("Reinhard")
    @core.CineonToneMapping => Some("Cineon")
    @core.ACESFilmicToneMapping => Some("ACESFilmic")
    @core.AgXToneMapping => Some("AgX")
    @core.NeutralToneMapping => Some("Neutral")
    @core.CustomToneMapping => Some("Custom")
    _ => None
  }
}

///|
/// `getToneMappingFunction( functionName, toneMapping )`.
fn webgl_program_get_tone_mapping_function(
  function_name : String,
  tone_mapping : Int32,
) -> String {
  match webgl_program_tone_mapping_name(tone_mapping) {
    None => {
      @core.warn("WebGLProgram: Unsupported toneMapping: \{tone_mapping}")
      "vec3 " +
      function_name +
      "( vec3 color ) { return LinearToneMapping( color ); }"
    }
    Some(name) =>
      "vec3 " +
      function_name +
      "( vec3 color ) { return " +
      name +
      "ToneMapping( color ); }"
  }
}

///|
let webgl_program_v0 : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
/// `getLuminanceFunction()`.
fn webgl_program_get_luminance_function() -> String {
  ignore(@math.color_management.get_luminance_coefficients(webgl_program_v0))
  let r = webgl_program_to_fixed4(webgl_program_v0.x)
  let g = webgl_program_to_fixed4(webgl_program_v0.y)
  let b = webgl_program_to_fixed4(webgl_program_v0.z)
  [
    "float luminance( const in vec3 rgb ) {",
    "\tconst vec3 weights = vec3( \{r}, \{g}, \{b} );",
    "\treturn dot( weights, rgb );",
    "}",
  ].join("\n")
}

///|
/// `[ ... ].filter( filterEmptyLine ).join( '\n' )`.
fn webgl_program_join_lines(chunks : Array[String]) -> String {
  chunks.filter(fn(s) { s != "" }).join("\n")
}

///|
/// `generateVertexExtensions( parameters )`.
fn webgl_program_generate_vertex_extensions(
  parameters : WebGLProgramParameters,
) -> String {
  let chunks = [
    if parameters.extension_clip_cull_distance {
      "#extension GL_ANGLE_clip_cull_distance : require"
    } else {
      ""
    },
    if parameters.extension_multi_draw {
      "#extension GL_ANGLE_multi_draw : require"
    } else {
      ""
    },
  ]
  webgl_program_join_lines(chunks)
}

///|
extern "js" fn webgl_program_is_array_index(key : String) -> Bool =
  #|(k) => { const n = Number(k); return String(n >>> 0) === k && (n >>> 0) !== 4294967295; }

///|
/// The keys of a plain object in JS `for ... in` order: array-index keys ascending, then
/// the others in insertion order.
fn[V] webgl_program_js_key_order(map : Map[String, V]) -> Array[String] {
  let indices = []
  let others = []
  for key, _ in map {
    if webgl_program_is_array_index(key) {
      indices.push(key)
    } else {
      others.push(key)
    }
  }
  stable_sort_by(indices, fn(a, b) {
    js_to_double(@core.JsValue::of(a)) - js_to_double(@core.JsValue::of(b))
  })
  indices + others
}

///|
/// `String( value )` of a define value, as string concatenation prints it.
fn webgl_program_define_string(value : Json) -> String {
  match value {
    String(s) => s
    _ => js_to_string(@core.JsValue::from_json(value))
  }
}

///|
/// `generateDefines( defines )`.
fn webgl_program_generate_defines(defines : Map[String, Json]?) -> String {
  let chunks = []
  if defines is Some(defines) {
    for name in webgl_program_js_key_order(defines) {
      let value = defines[name]
      if value is False {
        continue
      }
      chunks.push("#define " + name + " " + webgl_program_define_string(value))
    }
  }
  chunks.join("\n")
}

///|
/// `fetchAttributeLocations( gl, program )`.
fn webgl_program_fetch_attribute_locations(
  gl : WebGL2RenderingContext,
  program : GLProgram,
) -> Map[String, ProgramAttribute] {
  let attributes = Map([])
  let n = js_number_to_int(
    gl.get_program_parameter(program, GL_ACTIVE_ATTRIBUTES),
  )
  for i in 0..<n {
    let info = gl.get_active_attrib(program, i)
    let name = info.name()
    let mut location_size = 1
    if info.type_() == GL_FLOAT_MAT2 {
      location_size = 2
    }
    if info.type_() == GL_FLOAT_MAT3 {
      location_size = 3
    }
    if info.type_() == GL_FLOAT_MAT4 {
      location_size = 4
    }

    // log( 'WebGLProgram: ACTIVE VERTEX ATTRIBUTE:', name, i );

    attributes[name] = {
      type_: info.type_(),
      location: gl.get_attrib_location(program, name),
      location_size,
    }
  }
  attributes
}

///|
extern "js" fn webgl_program_replace_light_nums_js(
  string : String,
  nums : FixedArray[Int32],
) -> String =
  #|(string, n) => string
  #|  .replace( /NUM_SUN_LIGHTS/g, n[0] )
  #|  .replace( /NUM_DIR_LIGHTS/g, n[1] )
  #|  .replace( /NUM_SPOT_LIGHTS/g, n[2] )
  #|  .replace( /NUM_SPOT_LIGHT_MAPS/g, n[3] )
  #|  .replace( /NUM_SPOT_LIGHT_COORDS/g, n[4] )
  #|  .replace( /NUM_RECT_AREA_LIGHTS/g, n[5] )
  #|  .replace( /NUM_POINT_LIGHTS/g, n[6] )
  #|  .replace( /NUM_HEMI_LIGHTS/g, n[7] )
  #|  .replace( /NUM_SUN_LIGHT_SHADOWS/g, n[8] )
  #|  .replace( /NUM_DIR_LIGHT_SHADOWS/g, n[9] )
  #|  .replace( /NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS/g, n[10] )
  #|  .replace( /NUM_SPOT_LIGHT_SHADOWS/g, n[11] )
  #|  .replace( /NUM_POINT_LIGHT_SHADOWS/g, n[12] )
  #|  .replace( /NUM_LIGHT_PROBE_GRIDS/g, n[13] )

///|
/// `replaceLightNums( string, parameters )`.
fn webgl_program_replace_light_nums(
  string : String,
  parameters : WebGLProgramParameters,
) -> String {
  let num_spot_light_coords = parameters.num_spot_light_shadows +
    parameters.num_spot_light_maps -
    parameters.num_spot_light_shadows_with_maps
  webgl_program_replace_light_nums_js(string, [
    parameters.num_sun_lights,
    parameters.num_dir_lights,
    parameters.num_spot_lights,
    parameters.num_spot_light_maps,
    num_spot_light_coords,
    parameters.num_rect_area_lights,
    parameters.num_point_lights,
    parameters.num_hemi_lights,
    parameters.num_sun_light_shadows,
    parameters.num_dir_light_shadows,
    parameters.num_spot_light_shadows_with_maps,
    parameters.num_spot_light_shadows,
    parameters.num_point_light_shadows,
    parameters.num_light_probe_grids,
  ])
}

///|
extern "js" fn webgl_program_replace_clipping_plane_nums_js(
  string : String,
  num_clipping_planes : Int32,
  union_clipping_planes : Int32,
) -> String =
  #|(string, a, b) => string
  #|  .replace( /NUM_CLIPPING_PLANES/g, a )
  #|  .replace( /UNION_CLIPPING_PLANES/g, b )

///|
/// `replaceClippingPlaneNums( string, parameters )`.
fn webgl_program_replace_clipping_plane_nums(
  string : String,
  parameters : WebGLProgramParameters,
) -> String {
  webgl_program_replace_clipping_plane_nums_js(
    string,
    parameters.num_clipping_planes,
    parameters.num_clipping_planes - parameters.num_clip_intersection,
  )
}

// Resolve Includes

///|
extern "js" fn webgl_program_resolve_includes_js(
  string : String,
  lookup : (String) -> String,
) -> String =
  #|(string, lookup) => {
  #|  const includePattern = /^[ \t]*#include +<([\w\d./]+)>/gm;
  #|  const resolveIncludes = (s) => s.replace(includePattern, (match, include) => resolveIncludes(lookup(include)));
  #|  return resolveIncludes(string);
  #|}

///|
/// `resolveIncludes( string )`: replaces `#include <chunk>` with `ShaderChunk[ chunk ]`,
/// recursively.
fn webgl_program_resolve_includes(string : String) -> String {
  webgl_program_resolve_includes_js(string, fn(name) {
    match @shaders.shader_chunk.get(name) {
      Some(chunk) => chunk
      None =>
        abort("THREE.WebGLProgram: Can not resolve #include <" + name + ">")
    }
  })
}

// Unroll Loops

///|
extern "js" fn webgl_program_unroll_loops(string : String) -> String =
  #|(string) => {
  #|  const unrollLoopPattern = /#pragma unroll_loop_start\s+for\s*\(\s*int\s+i\s*=\s*(\d+)\s*;\s*i\s*<\s*(\d+)\s*;\s*i\s*\+\+\s*\)\s*{([\s\S]+?)}\s+#pragma unroll_loop_end/g;
  #|  return string.replace(unrollLoopPattern, (match, start, end, snippet) => {
  #|    let string = '';
  #|    for (let i = parseInt(start); i < parseInt(end); i++) {
  #|      string += snippet
  #|        .replace(/\[\s*i\s*\]/g, '[ ' + i + ' ]')
  #|        .replace(/UNROLLED_LOOP_INDEX/g, i);
  #|    }
  #|    return string;
  #|  });
  #|}

///|
/// `generatePrecision( parameters )`.
fn webgl_program_generate_precision(
  parameters : WebGLProgramParameters,
) -> String {
  let p = parameters.precision
  let mut precisionstring = "precision \{p} float;\n\tprecision \{p} int;\n\tprecision \{p} sampler2D;\n\tprecision \{p} samplerCube;\n\tprecision \{p} sampler3D;\n\tprecision \{p} sampler2DArray;\n\tprecision \{p} sampler2DShadow;\n\tprecision \{p} samplerCubeShadow;\n\tprecision \{p} sampler2DArrayShadow;\n\tprecision \{p} isampler2D;\n\tprecision \{p} isampler3D;\n\tprecision \{p} isamplerCube;\n\tprecision \{p} isampler2DArray;\n\tprecision \{p} usampler2D;\n\tprecision \{p} usampler3D;\n\tprecision \{p} usamplerCube;\n\tprecision \{p} usampler2DArray;\n\t"
  if p == "highp" {
    precisionstring += "\n#define HIGH_PRECISION"
  } else if p == "mediump" {
    precisionstring += "\n#define MEDIUM_PRECISION"
  } else if p == "lowp" {
    precisionstring += "\n#define LOW_PRECISION"
  }
  precisionstring
}

///|
/// `generateShadowMapTypeDefine( parameters )`.
fn webgl_program_generate_shadow_map_type_define(
  parameters : WebGLProgramParameters,
) -> String {
  match parameters.shadow_map_type {
    @core.PCFShadowMap => "SHADOWMAP_TYPE_PCF"
    @core.VSMShadowMap => "SHADOWMAP_TYPE_VSM"
    _ => "SHADOWMAP_TYPE_BASIC"
  }
}

///|
/// `generateEnvMapModeDefine( parameters )`.
fn webgl_program_generate_env_map_mode_define(
  parameters : WebGLProgramParameters,
) -> String {
  if parameters.env_map == false {
    return "ENVMAP_MODE_REFLECTION"
  }
  match parameters.env_map_mode {
    Some(@core.CubeRefractionMapping) => "ENVMAP_MODE_REFRACTION"
    _ => "ENVMAP_MODE_REFLECTION"
  }
}

///|
/// `generateEnvMapBlendingDefine( parameters )`.
fn webgl_program_generate_env_map_blending_define(
  parameters : WebGLProgramParameters,
) -> String {
  if parameters.env_map == false {
    return "ENVMAP_BLENDING_NONE"
  }
  match parameters.combine {
    Some(@core.MultiplyOperation) => "ENVMAP_BLENDING_MULTIPLY"
    Some(@core.MixOperation) => "ENVMAP_BLENDING_MIX"
    Some(@core.AddOperation) => "ENVMAP_BLENDING_ADD"
    _ => "ENVMAP_BLENDING_NONE"
  }
}

///|
/// `cond ? text : ''`.
fn webgl_program_if(cond : Bool, text : String) -> String {
  if cond {
    text
  } else {
    ""
  }
}

///|
/// `parameters.xUv ? '#define X_UV ' + parameters.xUv : ''`.
fn webgl_program_uv_define(name : String, uv : String?) -> String {
  match uv {
    Some(uv) if uv != "" => "#define " + name + " " + uv
    _ => ""
  }
}

///|
/// `parameters.flatShading === false`.
fn webgl_program_flat_shading_is_false(
  parameters : WebGLProgramParameters,
) -> Bool {
  parameters.flat_shading == false &&
  !webgl_program_parameters_flat_shading_undefined(parameters)
}

///|
/// `new WebGLProgram( renderer, cacheKey, parameters, bindingStates )`: builds the GLSL,
/// compiles both shaders and links (`programIdCount` gives `id`).
pub fn WebGLProgram::new(
  renderer : WebGLRenderer,
  cache_key : String,
  parameters : WebGLProgramParameters,
  binding_states : WebGLBindingStates,
) -> WebGLProgram {
  // TODO Send this event to Three.js DevTools
  // log( 'WebGLProgram', cacheKey );

  let gl = renderer.get_context()
  let defines = parameters.defines
  let mut vertex_shader = parameters.shader.vertex_shader
  let mut fragment_shader = parameters.shader.fragment_shader
  let shader_map_type_define = webgl_program_generate_shadow_map_type_define(
    parameters,
  )
  let env_map_type_define = if parameters.env_map_pmrem {
    "ENVMAP_TYPE_PMREM"
  } else {
    "ENVMAP_TYPE_CUBE"
  }
  let env_map_mode_define = webgl_program_generate_env_map_mode_define(
    parameters,
  )
  let env_map_blending_define = webgl_program_generate_env_map_blending_define(
    parameters,
  )
  let custom_vertex_extensions = webgl_program_generate_vertex_extensions(
    parameters,
  )
  let custom_defines = webgl_program_generate_defines(defines)
  let program = gl.create_program()
  let mut prefix_vertex = ""
  let mut prefix_fragment = ""
  let mut version_string = match parameters.glsl_version {
    Some(v) if v != "" => "#version " + v + "\n"
    _ => ""
  }
  let shader_type = parameters.shader_type
  let shader_name = parameters.shader.name
  if parameters.is_raw_shader_material {
    prefix_vertex = webgl_program_join_lines([
      "#define SHADER_TYPE " + shader_type,
      "#define SHADER_NAME " + shader_name,
      custom_defines,
    ])
    if prefix_vertex.length() > 0 {
      prefix_vertex += "\n"
    }
    prefix_fragment = webgl_program_join_lines([
      "#define SHADER_TYPE " + shader_type,
      "#define SHADER_NAME " + shader_name,
      custom_defines,
    ])
    if prefix_fragment.length() > 0 {
      prefix_fragment += "\n"
    }
  } else {
    let p = parameters
    let flat_shading_false = webgl_program_flat_shading_is_false(p)
    prefix_vertex = webgl_program_join_lines([
      webgl_program_generate_precision(p),
      "#define SHADER_TYPE " + shader_type,
      "#define SHADER_NAME " + shader_name,
      custom_defines,
      webgl_program_if(
        p.extension_clip_cull_distance,
        "#define USE_CLIP_DISTANCE",
      ),
      webgl_program_if(p.batching, "#define USE_BATCHING"),
      webgl_program_if(p.batching_color, "#define USE_BATCHING_COLOR"),
      webgl_program_if(p.instancing, "#define USE_INSTANCING"),
      webgl_program_if(p.instancing_color, "#define USE_INSTANCING_COLOR"),
      webgl_program_if(p.instancing_morph, "#define USE_INSTANCING_MORPH"),
      webgl_program_if(p.use_fog && p.fog, "#define USE_FOG"),
      webgl_program_if(p.use_fog && p.fog_exp2, "#define FOG_EXP2"),
      webgl_program_if(p.map, "#define USE_MAP"),
      webgl_program_if(p.env_map, "#define USE_ENVMAP"),
      webgl_program_if(p.env_map, "#define " + env_map_mode_define),
      webgl_program_if(p.light_map, "#define USE_LIGHTMAP"),
      webgl_program_if(p.ao_map, "#define USE_AOMAP"),
      webgl_program_if(p.bump_map, "#define USE_BUMPMAP"),
      webgl_program_if(p.normal_map, "#define USE_NORMALMAP"),
      webgl_program_if(
        p.normal_map_object_space,
        "#define USE_NORMALMAP_OBJECTSPACE",
      ),
      webgl_program_if(
        p.normal_map_tangent_space,
        "#define USE_NORMALMAP_TANGENTSPACE",
      ),
      webgl_program_if(p.displacement_map, "#define USE_DISPLACEMENTMAP"),
      webgl_program_if(p.emissive_map, "#define USE_EMISSIVEMAP"),
      webgl_program_if(p.anisotropy, "#define USE_ANISOTROPY"),
      webgl_program_if(p.anisotropy_map, "#define USE_ANISOTROPYMAP"),
      webgl_program_if(p.clearcoat_map, "#define USE_CLEARCOATMAP"),
      webgl_program_if(
        p.clearcoat_roughness_map,
        "#define USE_CLEARCOAT_ROUGHNESSMAP",
      ),
      webgl_program_if(
        p.clearcoat_normal_map,
        "#define USE_CLEARCOAT_NORMALMAP",
      ),
      webgl_program_if(
        p.diffuse_roughness_map,
        "#define USE_DIFFUSE_ROUGHNESSMAP",
      ),
      webgl_program_if(p.iridescence_map, "#define USE_IRIDESCENCEMAP"),
      webgl_program_if(
        p.iridescence_thickness_map,
        "#define USE_IRIDESCENCE_THICKNESSMAP",
      ),
      webgl_program_if(p.specular_map, "#define USE_SPECULARMAP"),
      webgl_program_if(p.specular_color_map, "#define USE_SPECULAR_COLORMAP"),
      webgl_program_if(
        p.specular_intensity_map,
        "#define USE_SPECULAR_INTENSITYMAP",
      ),
      webgl_program_if(p.roughness_map, "#define USE_ROUGHNESSMAP"),
      webgl_program_if(p.metalness_map, "#define USE_METALNESSMAP"),
      webgl_program_if(p.alpha_map, "#define USE_ALPHAMAP"),
      webgl_program_if(p.alpha_hash, "#define USE_ALPHAHASH"),
      webgl_program_if(p.transmission, "#define USE_TRANSMISSION"),
      webgl_program_if(p.transmission_map, "#define USE_TRANSMISSIONMAP"),
      webgl_program_if(p.thickness_map, "#define USE_THICKNESSMAP"),
      webgl_program_if(p.sheen_color_map, "#define USE_SHEEN_COLORMAP"),
      webgl_program_if(p.sheen_roughness_map, "#define USE_SHEEN_ROUGHNESSMAP"),

      //

      webgl_program_uv_define("MAP_UV", p.map_uv),
      webgl_program_uv_define("ALPHAMAP_UV", p.alpha_map_uv),
      webgl_program_uv_define("LIGHTMAP_UV", p.light_map_uv),
      webgl_program_uv_define("AOMAP_UV", p.ao_map_uv),
      webgl_program_uv_define("EMISSIVEMAP_UV", p.emissive_map_uv),
      webgl_program_uv_define("BUMPMAP_UV", p.bump_map_uv),
      webgl_program_uv_define("NORMALMAP_UV", p.normal_map_uv),
      webgl_program_uv_define("DISPLACEMENTMAP_UV", p.displacement_map_uv),
      webgl_program_uv_define("METALNESSMAP_UV", p.metalness_map_uv),
      webgl_program_uv_define("ROUGHNESSMAP_UV", p.roughness_map_uv),
      webgl_program_uv_define("ANISOTROPYMAP_UV", p.anisotropy_map_uv),
      webgl_program_uv_define("CLEARCOATMAP_UV", p.clearcoat_map_uv),
      webgl_program_uv_define(
        "CLEARCOAT_NORMALMAP_UV",
        p.clearcoat_normal_map_uv,
      ),
      webgl_program_uv_define(
        "CLEARCOAT_ROUGHNESSMAP_UV",
        p.clearcoat_roughness_map_uv,
      ),
      webgl_program_uv_define(
        "DIFFUSE_ROUGHNESSMAP_UV",
        p.diffuse_roughness_map_uv,
      ),
      webgl_program_uv_define("IRIDESCENCEMAP_UV", p.iridescence_map_uv),
      webgl_program_uv_define(
        "IRIDESCENCE_THICKNESSMAP_UV",
        p.iridescence_thickness_map_uv,
      ),
      webgl_program_uv_define("SHEEN_COLORMAP_UV", p.sheen_color_map_uv),
      webgl_program_uv_define("SHEEN_ROUGHNESSMAP_UV", p.sheen_roughness_map_uv),
      webgl_program_uv_define("SPECULARMAP_UV", p.specular_map_uv),
      webgl_program_uv_define("SPECULAR_COLORMAP_UV", p.specular_color_map_uv),
      webgl_program_uv_define(
        "SPECULAR_INTENSITYMAP_UV",
        p.specular_intensity_map_uv,
      ),
      webgl_program_uv_define("TRANSMISSIONMAP_UV", p.transmission_map_uv),
      webgl_program_uv_define("THICKNESSMAP_UV", p.thickness_map_uv),

      //

      webgl_program_if(
        p.vertex_tangents && flat_shading_false,
        "#define USE_TANGENT",
      ),
      webgl_program_if(p.vertex_normals, "#define HAS_NORMAL"),
      webgl_program_if(p.vertex_colors, "#define USE_COLOR"),
      webgl_program_if(p.vertex_alphas, "#define USE_COLOR_ALPHA"),
      webgl_program_if(p.vertex_uv1s, "#define USE_UV1"),
      webgl_program_if(p.vertex_uv2s, "#define USE_UV2"),
      webgl_program_if(p.vertex_uv3s, "#define USE_UV3"),
      webgl_program_if(p.points_uvs, "#define USE_POINTS_UV"),
      webgl_program_if(p.flat_shading, "#define FLAT_SHADED"),
      webgl_program_if(p.skinning, "#define USE_SKINNING"),
      webgl_program_if(p.morph_targets, "#define USE_MORPHTARGETS"),
      webgl_program_if(
        p.morph_normals && flat_shading_false,
        "#define USE_MORPHNORMALS",
      ),
      webgl_program_if(p.morph_colors, "#define USE_MORPHCOLORS"),
      webgl_program_if(
        p.morph_targets_count > 0,
        "#define MORPHTARGETS_TEXTURE_STRIDE \{p.morph_texture_stride}",
      ),
      webgl_program_if(
        p.morph_targets_count > 0,
        "#define MORPHTARGETS_COUNT \{p.morph_targets_count}",
      ),
      webgl_program_if(p.double_sided, "#define DOUBLE_SIDED"),
      webgl_program_if(p.flip_sided, "#define FLIP_SIDED"),
      webgl_program_if(p.shadow_map_enabled, "#define USE_SHADOWMAP"),
      webgl_program_if(
        p.shadow_map_enabled,
        "#define " + shader_map_type_define,
      ),
      webgl_program_if(p.size_attenuation, "#define USE_SIZEATTENUATION"),
      webgl_program_if(p.num_light_probes > 0, "#define USE_LIGHT_PROBES"),
      webgl_program_if(
        p.logarithmic_depth_buffer,
        "#define USE_LOGARITHMIC_DEPTH_BUFFER",
      ),
      webgl_program_if(
        p.reversed_depth_buffer,
        "#define USE_REVERSED_DEPTH_BUFFER",
      ),
      "uniform mat4 modelMatrix;",
      "uniform mat4 modelViewMatrix;",
      "uniform mat4 projectionMatrix;",
      "uniform mat4 viewMatrix;",
      "uniform mat3 normalMatrix;",
      "uniform vec3 cameraPosition;",
      "uniform bool isOrthographic;",
      "#ifdef USE_INSTANCING",
      "\tattribute mat4 instanceMatrix;",
      "#endif",
      "#ifdef USE_INSTANCING_COLOR",
      "\tattribute vec3 instanceColor;",
      "#endif",
      "#ifdef USE_INSTANCING_MORPH",
      "\tuniform sampler2D morphTexture;",
      "#endif",
      "attribute vec3 position;",
      "attribute vec3 normal;",
      "attribute vec2 uv;",
      "#ifdef USE_UV1",
      "\tattribute vec2 uv1;",
      "#endif",
      "#ifdef USE_UV2",
      "\tattribute vec2 uv2;",
      "#endif",
      "#ifdef USE_UV3",
      "\tattribute vec2 uv3;",
      "#endif",
      "#ifdef USE_TANGENT",
      "\tattribute vec4 tangent;",
      "#endif",
      "#if defined( USE_COLOR_ALPHA )",
      "\tattribute vec4 color;",
      "#elif defined( USE_COLOR )",
      "\tattribute vec3 color;",
      "#endif",
      "#ifdef USE_SKINNING",
      "\tattribute vec4 skinIndex;",
      "\tattribute vec4 skinWeight;",
      "#endif",
      "\n",
    ])
    let tone_mapped = p.tone_mapping != @core.NoToneMapping
    prefix_fragment = webgl_program_join_lines([
      webgl_program_generate_precision(p),
      "#define SHADER_TYPE " + shader_type,
      "#define SHADER_NAME " + shader_name,
      custom_defines,
      webgl_program_if(p.use_fog && p.fog, "#define USE_FOG"),
      webgl_program_if(p.use_fog && p.fog_exp2, "#define FOG_EXP2"),
      webgl_program_if(p.alpha_to_coverage, "#define ALPHA_TO_COVERAGE"),
      webgl_program_if(p.map, "#define USE_MAP"),
      webgl_program_if(p.matcap, "#define USE_MATCAP"),
      webgl_program_if(p.env_map, "#define USE_ENVMAP"),
      webgl_program_if(p.env_map, "#define " + env_map_type_define),
      webgl_program_if(p.env_map, "#define " + env_map_mode_define),
      webgl_program_if(p.env_map, "#define " + env_map_blending_define),
      webgl_program_if(
        p.env_map_pmrem,
        "#define ENVMAP_MAX_LOD " +
        webgl_program_nullable_int(p.env_map_max_lod) +
        ".0",
      ),
      webgl_program_if(
        p.env_map_pmrem,
        "#define ENVMAP_SIZE " +
        webgl_program_nullable_int(p.env_map_size) +
        ".0",
      ),
      webgl_program_if(p.light_map, "#define USE_LIGHTMAP"),
      webgl_program_if(p.ao_map, "#define USE_AOMAP"),
      webgl_program_if(p.bump_map, "#define USE_BUMPMAP"),
      webgl_program_if(p.normal_map, "#define USE_NORMALMAP"),
      webgl_program_if(
        p.normal_map_object_space,
        "#define USE_NORMALMAP_OBJECTSPACE",
      ),
      webgl_program_if(
        p.normal_map_tangent_space,
        "#define USE_NORMALMAP_TANGENTSPACE",
      ),
      webgl_program_if(p.packed_normal_map, "#define USE_PACKED_NORMALMAP"),
      webgl_program_if(p.emissive_map, "#define USE_EMISSIVEMAP"),
      webgl_program_if(p.anisotropy, "#define USE_ANISOTROPY"),
      webgl_program_if(p.anisotropy_map, "#define USE_ANISOTROPYMAP"),
      webgl_program_if(p.clearcoat, "#define USE_CLEARCOAT"),
      webgl_program_if(p.clearcoat_map, "#define USE_CLEARCOATMAP"),
      webgl_program_if(
        p.clearcoat_roughness_map,
        "#define USE_CLEARCOAT_ROUGHNESSMAP",
      ),
      webgl_program_if(
        p.clearcoat_normal_map,
        "#define USE_CLEARCOAT_NORMALMAP",
      ),
      webgl_program_if(p.diffuse_roughness, "#define USE_DIFFUSE_ROUGHNESS"),
      webgl_program_if(
        p.diffuse_roughness_map,
        "#define USE_DIFFUSE_ROUGHNESSMAP",
      ),
      webgl_program_if(p.dispersion, "#define USE_DISPERSION"),
      webgl_program_if(p.retroreflection, "#define USE_RETROREFLECTION"),
      webgl_program_if(p.iridescence, "#define USE_IRIDESCENCE"),
      webgl_program_if(p.iridescence_map, "#define USE_IRIDESCENCEMAP"),
      webgl_program_if(
        p.iridescence_thickness_map,
        "#define USE_IRIDESCENCE_THICKNESSMAP",
      ),
      webgl_program_if(p.specular_map, "#define USE_SPECULARMAP"),
      webgl_program_if(p.specular_color_map, "#define USE_SPECULAR_COLORMAP"),
      webgl_program_if(
        p.specular_intensity_map,
        "#define USE_SPECULAR_INTENSITYMAP",
      ),
      webgl_program_if(p.roughness_map, "#define USE_ROUGHNESSMAP"),
      webgl_program_if(p.metalness_map, "#define USE_METALNESSMAP"),
      webgl_program_if(p.alpha_map, "#define USE_ALPHAMAP"),
      webgl_program_if(p.alpha_test, "#define USE_ALPHATEST"),
      webgl_program_if(p.alpha_hash, "#define USE_ALPHAHASH"),
      webgl_program_if(p.sheen, "#define USE_SHEEN"),
      webgl_program_if(p.sheen_color_map, "#define USE_SHEEN_COLORMAP"),
      webgl_program_if(p.sheen_roughness_map, "#define USE_SHEEN_ROUGHNESSMAP"),
      webgl_program_if(p.transmission, "#define USE_TRANSMISSION"),
      webgl_program_if(p.transmission_map, "#define USE_TRANSMISSIONMAP"),
      webgl_program_if(p.thickness_map, "#define USE_THICKNESSMAP"),
      webgl_program_if(
        p.vertex_tangents && flat_shading_false,
        "#define USE_TANGENT",
      ),
      webgl_program_if(
        p.vertex_colors || p.instancing_color,
        "#define USE_COLOR",
      ),
      webgl_program_if(
        p.vertex_alphas || p.batching_color,
        "#define USE_COLOR_ALPHA",
      ),
      webgl_program_if(p.vertex_uv1s, "#define USE_UV1"),
      webgl_program_if(p.vertex_uv2s, "#define USE_UV2"),
      webgl_program_if(p.vertex_uv3s, "#define USE_UV3"),
      webgl_program_if(p.points_uvs, "#define USE_POINTS_UV"),
      webgl_program_if(p.gradient_map, "#define USE_GRADIENTMAP"),
      webgl_program_if(p.flat_shading, "#define FLAT_SHADED"),
      webgl_program_if(p.double_sided, "#define DOUBLE_SIDED"),
      webgl_program_if(p.flip_sided, "#define FLIP_SIDED"),
      webgl_program_if(p.shadow_map_enabled, "#define USE_SHADOWMAP"),
      webgl_program_if(
        p.shadow_map_enabled,
        "#define " + shader_map_type_define,
      ),
      webgl_program_if(p.premultiplied_alpha, "#define PREMULTIPLIED_ALPHA"),
      webgl_program_if(p.num_light_probes > 0, "#define USE_LIGHT_PROBES"),
      webgl_program_if(p.decode_video_texture, "#define DECODE_VIDEO_TEXTURE"),
      webgl_program_if(
        p.decode_video_texture_emissive,
        "#define DECODE_VIDEO_TEXTURE_EMISSIVE",
      ),
      webgl_program_if(
        p.logarithmic_depth_buffer,
        "#define USE_LOGARITHMIC_DEPTH_BUFFER",
      ),
      webgl_program_if(
        p.reversed_depth_buffer,
        "#define USE_REVERSED_DEPTH_BUFFER",
      ),
      "uniform mat4 viewMatrix;",
      "uniform vec3 cameraPosition;",
      "uniform bool isOrthographic;",
      webgl_program_if(tone_mapped, "#define TONE_MAPPING"),
      // this code is required here because it is used by the toneMapping() function defined below
      if tone_mapped {
        @shaders.shader_chunk["tonemapping_pars_fragment"]
      } else {
        ""
      },
      if tone_mapped {
        webgl_program_get_tone_mapping_function("toneMapping", p.tone_mapping)
      } else {
        ""
      },
      webgl_program_if(p.dithering, "#define DITHERING"),
      webgl_program_if(p.opaque_, "#define OPAQUE"),
      // this code is required here because it is used by the various encoding/decoding function defined below
      @shaders.shader_chunk["colorspace_pars_fragment"],
      webgl_program_get_texel_encoding_function(
        "linearToOutputTexel",
        p.output_color_space,
      ),
      webgl_program_get_luminance_function(),
      webgl_program_if(
        p.use_depth_packing,
        "#define DEPTH_PACKING \{p.depth_packing}",
      ),
      "\n",
    ])
  }
  vertex_shader = webgl_program_resolve_includes(vertex_shader)
  vertex_shader = webgl_program_replace_light_nums(vertex_shader, parameters)
  vertex_shader = webgl_program_replace_clipping_plane_nums(
    vertex_shader, parameters,
  )
  fragment_shader = webgl_program_resolve_includes(fragment_shader)
  fragment_shader = webgl_program_replace_light_nums(
    fragment_shader, parameters,
  )
  fragment_shader = webgl_program_replace_clipping_plane_nums(
    fragment_shader, parameters,
  )
  vertex_shader = webgl_program_unroll_loops(vertex_shader)
  fragment_shader = webgl_program_unroll_loops(fragment_shader)
  if parameters.is_raw_shader_material != true {
    // GLSL 3.0 conversion for built-in materials and ShaderMaterial

    version_string = "#version 300 es\n"
    prefix_vertex = [
        custom_vertex_extensions, "#define attribute in", "#define varying out",
        "#define texture2D texture",
      ].join("\n") +
      "\n" +
      prefix_vertex
    let glsl3 = parameters.glsl_version == Some(@core.GLSL3)
    prefix_fragment = [
        "#define varying in",
        if glsl3 {
          ""
        } else {
          "layout(location = 0) out highp vec4 pc_fragColor;"
        },
        if glsl3 {
          ""
        } else {
          "#define gl_FragColor pc_fragColor"
        },
        "#define gl_FragDepthEXT gl_FragDepth",
        "#define texture2D texture",
        "#define textureCube texture",
        "#define texture2DProj textureProj",
        "#define texture2DLodEXT textureLod",
        "#define texture2DProjLodEXT textureProjLod",
        "#define textureCubeLodEXT textureLod",
        "#define texture2DGradEXT textureGrad",
        "#define texture2DProjGradEXT textureProjGrad",
        "#define textureCubeGradEXT textureGrad",
      ].join("\n") +
      "\n" +
      prefix_fragment
  }
  let vertex_glsl = version_string + prefix_vertex + vertex_shader
  let fragment_glsl = version_string + prefix_fragment + fragment_shader

  // log( '*VERTEX*', vertexGlsl );
  // log( '*FRAGMENT*', fragmentGlsl );

  let gl_vertex_shader = webgl_shader(gl, GL_VERTEX_SHADER, vertex_glsl)
  let gl_fragment_shader = webgl_shader(gl, GL_FRAGMENT_SHADER, fragment_glsl)
  gl.attach_shader(program, gl_vertex_shader)
  gl.attach_shader(program, gl_fragment_shader)

  // Force a particular attribute to index 0.

  match parameters.index0_attribute_name {
    Some(name) => gl.bind_attrib_location(program, 0, name)
    None =>
      if parameters.has_position_attribute {
        // below avoids the "Attribute 0 is disabled" performance penalty
        gl.bind_attrib_location(program, 0, "position")
      }
  }
  gl.link_program(program)

  // indicate when the program is ready to be used. if the KHR_parallel_shader_compile extension isn't supported,
  // flag the program as ready immediately. It may cause a stall when it's first used.

  let program_ready = parameters.renderer_extension_parallel_shader_compile ==
    false
  let id = webgl_program_id_count.val
  webgl_program_id_count.val += 1
  let self : WebGLProgram = {
    type_: parameters.shader_type,
    name: parameters.shader.name,
    id,
    cache_key,
    used_times: 1,
    program: Some(program),
    vertex_shader: gl_vertex_shader,
    fragment_shader: gl_fragment_shader,
    diagnostics: None,
    renderer,
    gl,
    binding_states,
    prefix_vertex,
    prefix_fragment,
    cached_uniforms: None,
    cached_attributes: None,
    program_ready,
  }
  webgl_program_gl_programs.set(self, program)
  self
}

///|
/// `'' + value` for an optional integer (`null` prints as `null`).
fn webgl_program_nullable_int(value : Int32?) -> String {
  match value {
    Some(v) => v.to_string()
    None => "null"
  }
}

///|
/// `onFirstUse( self )`: checks link errors, deletes the shaders and fills
/// `cached_uniforms` and `cached_attributes`.
pub fn WebGLProgram::on_first_use(self : WebGLProgram) -> Unit {
  let gl = self.gl
  let program = self.gl_program()
  let gl_vertex_shader = self.vertex_shader
  let gl_fragment_shader = self.fragment_shader

  // check for link errors
  if self.renderer.debug.check_shader_errors {
    let program_info_log = gl.get_program_info_log(program).unwrap_or("")
    let vertex_shader_info_log = gl
      .get_shader_info_log(gl_vertex_shader)
      .unwrap_or("")
    let fragment_shader_info_log = gl
      .get_shader_info_log(gl_fragment_shader)
      .unwrap_or("")
    let program_log = webgl_program_trim(program_info_log)
    let vertex_log = webgl_program_trim(vertex_shader_info_log)
    let fragment_log = webgl_program_trim(fragment_shader_info_log)
    let mut runnable = true
    let mut have_diagnostics = true
    if gl
      .get_program_parameter(program, GL_LINK_STATUS)
      .strict_equal(@core.JsValue::of(false)) {
      runnable = false
      match self.renderer.debug.on_shader_error {
        Some(on_shader_error) =>
          on_shader_error(gl, program, gl_vertex_shader, gl_fragment_shader)
        None => {
          // default error reporting

          let vertex_errors = webgl_program_get_shader_errors(
            gl, gl_vertex_shader, "vertex",
          )
          let fragment_errors = webgl_program_get_shader_errors(
            gl, gl_fragment_shader, "fragment",
          )
          let gl_error = gl.get_error()
          let validate_status = js_to_string(
            gl.get_program_parameter(program, GL_VALIDATE_STATUS),
          )
          @core.error(
            "WebGLProgram: Shader Error \{gl_error} - " +
            "VALIDATE_STATUS \{validate_status}\n\n" +
            "Material Name: \{self.name}\n" +
            "Material Type: \{self.type_}\n\n" +
            "Program Info Log: \{program_log}\n" +
            vertex_errors +
            "\n" +
            fragment_errors,
          )
        }
      }
    } else if program_log != "" {
      @core.warn("WebGLProgram: Program Info Log: " + program_log)
    } else if vertex_log == "" || fragment_log == "" {
      have_diagnostics = false
    }
    if have_diagnostics {
      self.diagnostics = Some({
        runnable,
        program_log,
        vertex_shader: { log: vertex_log, prefix: self.prefix_vertex, },
        fragment_shader: { log: fragment_log, prefix: self.prefix_fragment, },
      })
    }
  }

  // Clean up

  // Crashes in iOS9 and iOS10. #18402
  // gl.detachShader( program, glVertexShader );
  // gl.detachShader( program, glFragmentShader );

  gl.delete_shader(gl_vertex_shader)
  gl.delete_shader(gl_fragment_shader)
  self.cached_uniforms = Some(WebGLUniforms::new(gl, program))
  self.cached_attributes = Some(
    webgl_program_fetch_attribute_locations(gl, program),
  )
}

///|
/// `program.getUniforms()`.
pub fn WebGLProgram::get_uniforms(self : WebGLProgram) -> WebGLUniforms {
  if self.cached_uniforms is None {
    // Populates cachedUniforms and cachedAttributes
    self.on_first_use()
  }
  self.cached_uniforms.unwrap()
}

///|
/// `program.getAttributes()`: name -> attribute, in `getActiveAttrib` order.
pub fn WebGLProgram::get_attributes(
  self : WebGLProgram,
) -> Map[String, ProgramAttribute] {
  if self.cached_attributes is None {
    // Populates cachedAttributes and cachedUniforms
    self.on_first_use()
  }
  self.cached_attributes.unwrap()
}

///|
/// `program.isReady()`: polls `COMPLETION_STATUS_KHR` with `KHR_parallel_shader_compile`.
pub fn WebGLProgram::is_ready(self : WebGLProgram) -> Bool {
  if self.program_ready == false {
    self.program_ready = js_truthy(
      self.gl.get_program_parameter(
        self.gl_program(),
        WEBGL_PROGRAM_COMPLETION_STATUS_KHR,
      ),
    )
  }
  self.program_ready
}

///|
/// `program.destroy()`: releases binding states and deletes the GL program.
pub fn WebGLProgram::destroy(self : WebGLProgram) -> Unit {
  self.binding_states.release_states_of_program(self)
  self.gl.delete_program(self.gl_program())
  self.program = None
}
