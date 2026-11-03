// GLSLNodeBuilder.js: texture sampling, loads, gathers and comparisons.

///|
/// `generateTextureLoad( texture, textureProperty, uvIndexSnippet, levelSnippet,
/// depthSnippet, offsetSnippet )` with a nullable texture (the PBO path passes `null`).
fn _glsl_generate_texture_load(
  texture : @core.Texture?,
  texture_property : String,
  uv_index_snippet : String,
  level_snippet : String?,
  depth_snippet : String?,
  offset_snippet : String?,
) -> String {
  let level_snippet = match level_snippet {
    Some(l) => l
    None => "0"
  }
  let mut snippet = if _glsl_truthy(depth_snippet) {
    let depth_snippet = _glsl_str(depth_snippet)
    if _glsl_truthy(offset_snippet) {
      "texelFetchOffset( \{texture_property}, ivec3( \{uv_index_snippet}, \{depth_snippet} ), int( \{level_snippet} ), \{_glsl_str(offset_snippet)} )"
    } else {
      "texelFetch( \{texture_property}, ivec3( \{uv_index_snippet}, \{depth_snippet} ), int( \{level_snippet} ) )"
    }
  } else if _glsl_truthy(offset_snippet) {
    "texelFetchOffset( \{texture_property}, \{uv_index_snippet}, int( \{level_snippet} ), \{_glsl_str(offset_snippet)} )"
  } else {
    "texelFetch( \{texture_property}, \{uv_index_snippet}, int( \{level_snippet} ) )"
  }
  if texture is Some(t) && t.is_depth_texture() {
    snippet += ".x"
  }
  snippet
}

///|
/// `generateTextureLoad( texture, textureProperty, uvIndexSnippet, levelSnippet,
/// depthSnippet, offsetSnippet )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn generate_texture_load(
  _,
  _,
  texture,
  texture_property,
  uv_index_snippet,
  level_snippet,
  depth_snippet,
  offset_snippet,
) {
  _glsl_generate_texture_load(
    Some(texture),
    texture_property,
    uv_index_snippet,
    level_snippet,
    depth_snippet,
    offset_snippet,
  )
}

///|
/// `if ( depthSnippet ) uvSnippet = `vec3( ${ uvSnippet }, ${ depthSnippet } )``.
fn _glsl_uv_with_depth(uv_snippet : String, depth_snippet : String?) -> String {
  if _glsl_truthy(depth_snippet) {
    "vec3( \{uv_snippet}, \{_glsl_str(depth_snippet)} )"
  } else {
    uv_snippet
  }
}

///|
/// `generateTexture( texture, textureProperty, uvSnippet, depthSnippet, offsetSnippet )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn generate_texture(
  _,
  _,
  texture,
  texture_property,
  uv_snippet,
  depth_snippet,
  offset_snippet,
  _,
) {
  let uv_snippet = _glsl_uv_with_depth(uv_snippet, depth_snippet)
  if texture.is_depth_texture() {
    if _glsl_truthy(offset_snippet) {
      return "textureOffset( \{texture_property}, \{uv_snippet}, \{_glsl_str(offset_snippet)} ).x"
    }
    return "texture( \{texture_property}, \{uv_snippet} ).x"
  }
  if _glsl_truthy(offset_snippet) {
    return "textureOffset( \{texture_property}, \{uv_snippet}, \{_glsl_str(offset_snippet)} )"
  }
  "texture( \{texture_property}, \{uv_snippet} )"
}

///|
/// `generateTextureSize( texture, textureProperty, levelSnippet )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn generate_texture_size(
  _,
  _,
  _,
  texture_property,
  level_snippet,
) {
  "textureSize( \{texture_property}, \{level_snippet} )"
}

///|
/// `generateTextureLevel( texture, textureProperty, uvSnippet, levelSnippet,
/// depthSnippet, offsetSnippet )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn generate_texture_level(
  _,
  _,
  texture,
  texture_property,
  uv_snippet,
  level_snippet,
  depth_snippet,
  offset_snippet,
) {
  let uv_snippet = _glsl_uv_with_depth(uv_snippet, depth_snippet)
  if texture.is_depth_texture() {
    if _glsl_truthy(offset_snippet) {
      return "textureLodOffset( \{texture_property}, \{uv_snippet}, \{level_snippet}, \{_glsl_str(offset_snippet)} ).x"
    }
    return "textureLod( \{texture_property}, \{uv_snippet}, \{level_snippet} ).x"
  }
  if _glsl_truthy(offset_snippet) {
    return "textureLodOffset( \{texture_property}, \{uv_snippet}, \{level_snippet}, \{_glsl_str(offset_snippet)} )"
  }
  "textureLod( \{texture_property}, \{uv_snippet}, \{level_snippet} )"
}

///|
/// `generateTextureLod( texture, textureProperty, uvSnippet, depthSnippet,
/// offsetSnippet, levelSnippet )`: not defined by GLSLNodeBuilder, so the base
/// NodeBuilder's (WGSL-only) method applies.
///
/// `generateTextureBias( texture, textureProperty, uvSnippet, biasSnippet,
/// depthSnippet, offsetSnippet )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn generate_texture_bias(
  _,
  _,
  _,
  texture_property,
  uv_snippet,
  bias_snippet,
  depth_snippet,
  offset_snippet,
  _,
) {
  let uv_snippet = _glsl_uv_with_depth(uv_snippet, depth_snippet)
  if _glsl_truthy(offset_snippet) {
    return "textureOffset( \{texture_property}, \{uv_snippet}, \{_glsl_str(offset_snippet)}, \{bias_snippet} )"
  }
  "texture( \{texture_property}, \{uv_snippet}, \{bias_snippet} )"
}

///|
/// `gradSnippet[ i ]` as a template literal prints it.
fn _glsl_grad(grad_snippet : Array[String], i : Int32) -> String {
  if i < grad_snippet.length() {
    grad_snippet[i]
  } else {
    "undefined"
  }
}

///|
/// `generateTextureGrad( texture, textureProperty, uvSnippet, gradSnippet,
/// depthSnippet, offsetSnippet )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn generate_texture_grad(
  _,
  _,
  _,
  texture_property,
  uv_snippet,
  grad_snippet,
  depth_snippet,
  offset_snippet,
  _,
) {
  let uv_snippet = _glsl_uv_with_depth(uv_snippet, depth_snippet)
  let dx = _glsl_grad(grad_snippet, 0)
  let dy = _glsl_grad(grad_snippet, 1)
  if _glsl_truthy(offset_snippet) {
    return "textureGradOffset( \{texture_property}, \{uv_snippet}, \{dx}, \{dy}, \{_glsl_str(offset_snippet)} )"
  }
  "textureGrad( \{texture_property}, \{uv_snippet}, \{dx}, \{dy} )"
}

///|
/// `generateTextureCompare( texture, textureProperty, uvSnippet, compareSnippet,
/// depthSnippet, offsetSnippet, shaderStage = this.shaderStage )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn generate_texture_compare(
  _,
  b,
  texture,
  texture_property,
  uv_snippet,
  compare_snippet,
  depth_snippet,
  offset_snippet,
  shader_stage,
) {
  let shader_stage = _glsl_stage(b, shader_stage)
  if shader_stage == "fragment" {
    // Cube shadow maps use vec4(direction, compareValue)
    if texture.is_cube_texture() {
      return "texture( \{texture_property}, vec4( \{uv_snippet}, \{compare_snippet} ) )"
    }
    if _glsl_truthy(depth_snippet) {
      let depth_snippet = _glsl_str(depth_snippet)
      if _glsl_truthy(offset_snippet) {
        return "textureOffset( \{texture_property}, vec4( \{uv_snippet}, \{depth_snippet}, \{compare_snippet} ), \{_glsl_str(offset_snippet)} )"
      }
      return "texture( \{texture_property}, vec4( \{uv_snippet}, \{depth_snippet}, \{compare_snippet} ) )"
    }
    if _glsl_truthy(offset_snippet) {
      return "textureOffset( \{texture_property}, vec3( \{uv_snippet}, \{compare_snippet} ), \{_glsl_str(offset_snippet)} )"
    }
    "texture( \{texture_property}, vec3( \{uv_snippet}, \{compare_snippet} ) )"
  } else {
    @core.error(
      "WebGPURenderer: THREE.DepthTexture.compareFunction() does not support \{shader_stage} shader.",
    )
    "undefined"
  }
}

///|
/// `generateTextureGather( texture, textureProperty, uvSnippet, gatherSnippet,
/// depthSnippet, offsetSnippet, flipYSnippet )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn generate_texture_gather(
  self,
  b,
  texture,
  texture_property,
  uv_snippet,
  gather_snippet,
  depth_snippet,
  offset_snippet,
  flip_y_snippet,
) {
  let gather_snippet = if texture.is_depth_texture() {
    "0"
  } else {
    _glsl_str(gather_snippet)
  }
  let offset_snippet = match offset_snippet {
    Some(o) => o
    None => "ivec2( 0 )"
  }
  let flip_y_snippet = match flip_y_snippet {
    Some(f) => f
    None => "false"
  }
  if _glsl_truthy(depth_snippet) {
    self._include(b, "textureGatherArray") |> ignore
    return "tsl_textureGather_array( \{gather_snippet}, \{texture_property}, vec3( \{uv_snippet}, \{_glsl_str(depth_snippet)} ), \{offset_snippet}, \{flip_y_snippet} )"
  }
  self._include(b, "textureGather") |> ignore
  "tsl_textureGather( \{gather_snippet}, \{texture_property}, \{uv_snippet}, \{offset_snippet}, \{flip_y_snippet} )"
}

///|
/// `generateTextureGatherCompare( texture, textureProperty, uvSnippet, compareSnippet,
/// depthSnippet, offsetSnippet, flipYSnippet )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn generate_texture_gather_compare(
  self,
  b,
  _,
  texture_property,
  uv_snippet,
  compare_snippet,
  depth_snippet,
  offset_snippet,
  flip_y_snippet,
) {
  let offset_snippet = match offset_snippet {
    Some(o) => o
    None => "ivec2( 0 )"
  }
  let flip_y_snippet = match flip_y_snippet {
    Some(f) => f
    None => "false"
  }
  if _glsl_truthy(depth_snippet) {
    self._include(b, "textureGatherCompareArray") |> ignore
    return "tsl_textureGatherCompare_array( \{texture_property}, vec3( \{uv_snippet}, \{_glsl_str(depth_snippet)} ), \{offset_snippet}, \{compare_snippet}, \{flip_y_snippet} )"
  }
  self._include(b, "textureGatherCompare") |> ignore
  "tsl_textureGatherCompare( \{texture_property}, \{uv_snippet}, \{offset_snippet}, \{compare_snippet}, \{flip_y_snippet} )"
}
