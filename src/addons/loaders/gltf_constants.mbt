// GLTFLoader's module-level tables: EXTENSIONS, WEBGL_CONSTANTS, WEBGL_COMPONENT_TYPES,
// WEBGL_FILTERS, WEBGL_WRAPPINGS, WEBGL_TYPE_SIZES, ATTRIBUTES, PATH_PROPERTIES,
// INTERPOLATION, ALPHA_MODES and the binary header constants.

///|
let gltf_KHR_BINARY_GLTF : String = "KHR_binary_glTF"

///|
let gltf_KHR_DRACO_MESH_COMPRESSION : String = "KHR_draco_mesh_compression"

///|
let gltf_KHR_LIGHTS_PUNCTUAL : String = "KHR_lights_punctual"

///|
let gltf_KHR_MATERIALS_CLEARCOAT : String = "KHR_materials_clearcoat"

///|
let gltf_KHR_MATERIALS_DIFFUSE_ROUGHNESS : String = "KHR_materials_diffuse_roughness"

///|
let gltf_KHR_MATERIALS_DISPERSION : String = "KHR_materials_dispersion"

///|
let gltf_KHR_MATERIALS_IOR : String = "KHR_materials_ior"

///|
let gltf_KHR_MATERIALS_SHEEN : String = "KHR_materials_sheen"

///|
let gltf_KHR_MATERIALS_SPECULAR : String = "KHR_materials_specular"

///|
let gltf_KHR_MATERIALS_TRANSMISSION : String = "KHR_materials_transmission"

///|
let gltf_KHR_MATERIALS_IRIDESCENCE : String = "KHR_materials_iridescence"

///|
let gltf_KHR_MATERIALS_ANISOTROPY : String = "KHR_materials_anisotropy"

///|
let gltf_KHR_MATERIALS_UNLIT : String = "KHR_materials_unlit"

///|
let gltf_KHR_MATERIALS_VOLUME : String = "KHR_materials_volume"

///|
let gltf_KHR_TEXTURE_BASISU : String = "KHR_texture_basisu"

///|
let gltf_KHR_TEXTURE_TRANSFORM : String = "KHR_texture_transform"

///|
let gltf_KHR_MATERIALS_EMISSIVE_STRENGTH : String = "KHR_materials_emissive_strength"

///|
let gltf_KHR_MESH_QUANTIZATION : String = "KHR_mesh_quantization"

///|
let gltf_EXT_MATERIALS_BUMP : String = "EXT_materials_bump"

///|
let gltf_EXT_TEXTURE_WEBP : String = "EXT_texture_webp"

///|
let gltf_EXT_TEXTURE_AVIF : String = "EXT_texture_avif"

///|
let gltf_EXT_MESHOPT_COMPRESSION : String = "EXT_meshopt_compression"

///|
let gltf_KHR_MESHOPT_COMPRESSION : String = "KHR_meshopt_compression"

///|
let gltf_EXT_MESH_GPU_INSTANCING : String = "EXT_mesh_gpu_instancing"

///|
let gltf_BINARY_EXTENSION_HEADER_MAGIC : String = "glTF"

///|
let gltf_BINARY_EXTENSION_HEADER_LENGTH : Int32 = 12

///|
let gltf_BINARY_EXTENSION_CHUNK_TYPE_JSON : Double = 0x4E4F534A

///|
let gltf_BINARY_EXTENSION_CHUNK_TYPE_BIN : Double = 0x004E4942

// WEBGL_CONSTANTS

///|
let gltf_POINTS : Double = 0

///|
let gltf_LINES : Double = 1

///|
let gltf_LINE_LOOP : Double = 2

///|
let gltf_LINE_STRIP : Double = 3

///|
let gltf_TRIANGLES : Double = 4

///|
let gltf_TRIANGLE_STRIP : Double = 5

///|
let gltf_TRIANGLE_FAN : Double = 6

///|
/// `WEBGL_COMPONENT_TYPES`: the typed array constructor name of a component type.
fn gltf_component_type(component_type : @core.JsValue) -> String {
  if gltf_equals_number(component_type, 5120) {
    "Int8Array"
  } else if gltf_equals_number(component_type, 5121) {
    "Uint8Array"
  } else if gltf_equals_number(component_type, 5122) {
    "Int16Array"
  } else if gltf_equals_number(component_type, 5123) {
    "Uint16Array"
  } else if gltf_equals_number(component_type, 5125) {
    "Uint32Array"
  } else if gltf_equals_number(component_type, 5126) {
    "Float32Array"
  } else {
    @utils.addon_throw_error(
      "TypeError: WEBGL_COMPONENT_TYPES[ " +
      gltf_string(component_type) +
      " ] is undefined",
    )
  }
}

///|
/// `TypedArray.BYTES_PER_ELEMENT`.
fn gltf_bytes_per_element(name : String) -> Int32 {
  match name {
    "Int8Array" | "Uint8Array" => 1
    "Int16Array" | "Uint16Array" => 2
    _ => 4
  }
}

///|
/// `WEBGL_FILTERS[ v ]`.
fn gltf_webgl_filter(value : @core.JsValue) -> Int32? {
  if gltf_equals_number(value, 9728) {
    Some(@core.NearestFilter)
  } else if gltf_equals_number(value, 9729) {
    Some(@core.LinearFilter)
  } else if gltf_equals_number(value, 9984) {
    Some(@core.NearestMipmapNearestFilter)
  } else if gltf_equals_number(value, 9985) {
    Some(@core.LinearMipmapNearestFilter)
  } else if gltf_equals_number(value, 9986) {
    Some(@core.NearestMipmapLinearFilter)
  } else if gltf_equals_number(value, 9987) {
    Some(@core.LinearMipmapLinearFilter)
  } else {
    None
  }
}

///|
/// `WEBGL_WRAPPINGS[ v ]`.
fn gltf_webgl_wrapping(value : @core.JsValue) -> Int32? {
  if gltf_equals_number(value, 33071) {
    Some(@core.ClampToEdgeWrapping)
  } else if gltf_equals_number(value, 33648) {
    Some(@core.MirroredRepeatWrapping)
  } else if gltf_equals_number(value, 10497) {
    Some(@core.RepeatWrapping)
  } else {
    None
  }
}

///|
/// `WEBGL_TYPE_SIZES[ type ]`.
fn gltf_type_size(type_ : @core.JsValue) -> Int32 {
  match gltf_string(type_) {
    "SCALAR" => 1
    "VEC2" => 2
    "VEC3" => 3
    "VEC4" => 4
    "MAT2" => 4
    "MAT3" => 9
    "MAT4" => 16
    other =>
      @utils.addon_throw_error(
        "THREE.GLTFLoader: unknown accessor type " + other,
      )
  }
}

///|
/// `ATTRIBUTES[ name ] || name.toLowerCase()`.
fn gltf_three_attribute_name(name : String) -> String {
  match name {
    "POSITION" => "position"
    "NORMAL" => "normal"
    "TANGENT" => "tangent"
    "TEXCOORD_0" => "uv"
    "TEXCOORD_1" => "uv1"
    "TEXCOORD_2" => "uv2"
    "TEXCOORD_3" => "uv3"
    "COLOR_0" => "color"
    "WEIGHTS_0" => "skinWeight"
    "JOINTS_0" => "skinIndex"
    _ => gltf_to_lower_case(name)
  }
}

///|
extern "js" fn gltf_to_lower_case(s : String) -> String = "(s) => s.toLowerCase()"

///|
/// `PATH_PROPERTIES[ path ]`; `None` is `undefined`.
fn gltf_path_property(path : @core.JsValue) -> String? {
  if !gltf_is_string(path) {
    return None
  }
  match gltf_string(path) {
    "scale" => Some("scale")
    "translation" => Some("position")
    "rotation" => Some("quaternion")
    "weights" => Some("morphTargetInfluences")
    _ => None
  }
}

///|
/// `INTERPOLATION[ name ]`; CUBICSPLINE and unknown names are `undefined`.
fn gltf_interpolation(name : @core.JsValue) -> Int32? {
  if gltf_equals_string(name, "LINEAR") {
    Some(@core.InterpolateLinear)
  } else if gltf_equals_string(name, "STEP") {
    Some(@core.InterpolateDiscrete)
  } else {
    None
  }
}

///|
/// `getNormalizedComponentScale( constructor )`.
fn gltf_normalized_component_scale(name : String) -> Double {
  match name {
    "Int8Array" => 1.0 / 127.0
    "Uint8Array" => 1.0 / 255.0
    "Int16Array" => 1.0 / 32767.0
    "Uint16Array" => 1.0 / 65535.0
    _ =>
      @utils.addon_throw_error(
        "THREE.GLTFLoader: Unsupported normalized accessor component type.",
      )
  }
}
