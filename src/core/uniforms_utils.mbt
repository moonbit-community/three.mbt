// Upstream src/renderers/shaders/UniformsUtils.js.

///|
extern "js" fn uniforms_slice_array(value : JsValue) -> JsValue =
  #|(v) => Array.isArray( v ) ? v.slice() : v

///|
/// `isThreeObject`. `Plane` is deliberately absent, as upstream.
fn uniforms_is_three_object(value : UniformValue) -> Bool {
  value
  is (Color(_)
  | Matrix3(_)
  | Matrix4(_)
  | Vector2(_)
  | Vector3(_)
  | Vector4(_)
  | Texture(_)
  | Quaternion(_))
}

///|
fn uniforms_clone_value(property : UniformValue) -> UniformValue {
  match property {
    Texture({ is_render_target_texture: true, .. }) => {
      warn(
        "UniformsUtils: Textures of render targets cannot be cloned via cloneUniforms() or mergeUniforms().",
      )
      Null
    }
    Numbers(array) => Numbers(array.copy())
    Array(array) =>
      if array.get(0) is Some(first) && uniforms_is_three_object(first) {
        Array(array.map(item => item.clone()))
      } else {
        Array(array.copy())
      }
    Other(value) => Other(uniforms_slice_array(value))
    _ =>
      if uniforms_is_three_object(property) {
        property.clone()
      } else {
        property
      }
  }
}

///|
/// Upstream `cloneUniforms`.
pub fn clone_uniforms(src : Map[String, Uniform]) -> Map[String, Uniform] {
  let dst = Map([])
  for u, uniform in src {
    dst[u] = Uniform::new(uniforms_clone_value(uniform.value))
  }
  dst
}

///|
/// Upstream `mergeUniforms`.
pub fn merge_uniforms(
  uniforms : Array[Map[String, Uniform]],
) -> Map[String, Uniform] {
  let merged = Map([])
  for uniform in uniforms {
    let tmp = clone_uniforms(uniform)
    for p, value in tmp {
      merged[p] = value
    }
  }
  merged
}

///|
/// Upstream `cloneUniformsGroups`.
pub fn clone_uniforms_groups(
  src : Array[UniformsGroup],
) -> Array[UniformsGroup] {
  src.map(group => group.clone())
}

///|
/// Upstream `getUnlitUniformColorSpace`, given what it reads from the renderer.
pub fn get_unlit_uniform_color_space(
  current_render_target : RenderTarget?,
  output_color_space : String,
) -> String {
  guard current_render_target is Some(current_render_target) else {
    // https://github.com/mrdoob/three.js/pull/23937#issuecomment-1111067398
    return output_color_space
  }
  // https://github.com/mrdoob/three.js/issues/27868
  if current_render_target.has_extension_flag("isXRRenderTarget") {
    return current_render_target.textures[0].color_space
  }
  @math.color_management.working_color_space
}

///|
/// Upstream's legacy `UniformsUtils` object.
#external
pub type UniformsUtils

///|
pub fn UniformsUtils::clone(src : Map[String, Uniform]) -> Map[String, Uniform] {
  clone_uniforms(src)
}

///|
pub fn UniformsUtils::merge(
  uniforms : Array[Map[String, Uniform]],
) -> Map[String, Uniform] {
  merge_uniforms(uniforms)
}
