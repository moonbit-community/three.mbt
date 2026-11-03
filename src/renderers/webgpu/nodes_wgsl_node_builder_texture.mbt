// WGSLNodeBuilder.js, the texture methods: sampling, loads, stores, gathers, the wrap
// functions and texture dimensions of the textures WGSL cannot sample with a sampler.

///|
/// `texture.is3DTexture || texture.isData3DTexture`.
fn _wgsl_is_3d(texture : @core.Texture) -> Bool {
  texture.has_extension_flag("is3DTexture") ||
  texture.texture_type is Data3DTexture
}

///|
/// `_generateTextureSample( texture, textureProperty, uvSnippet, depthSnippet,
/// offsetSnippet, shaderStage = this.shaderStage )`.
fn WGSLNodeBuilder::_generate_texture_sample(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  texture : @core.Texture,
  p : String,
  uv : String,
  depth : String?,
  offset : String?,
  shader_stage : String?,
) -> String {
  if _wgsl_stage(b, shader_stage) == "fragment" {
    if _wgsl_truthy(depth) {
      if _wgsl_truthy(offset) {
        return "textureSample( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{_wgsl_str(offset)} )"
      }
      "textureSample( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)} )"
    } else {
      if _wgsl_truthy(offset) {
        return "textureSample( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(offset)} )"
      }
      "textureSample( \{p}, \{p}_sampler, \{uv} )"
    }
  } else {
    self.generate_texture_sample_level(b, texture, p, uv, "0", depth, None)
  }
}

///|
/// `generateTextureSampleLevel( texture, textureProperty, uvSnippet, levelSnippet,
/// depthSnippet, offsetSnippet )`.
pub fn WGSLNodeBuilder::generate_texture_sample_level(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  texture : @core.Texture,
  p : String,
  uv : String,
  level : String,
  depth : String?,
  offset : String?,
) -> String {
  if !self.is_unfilterable(b, texture) {
    if _wgsl_truthy(depth) {
      if _wgsl_truthy(offset) {
        return "textureSampleLevel( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{level}, \{_wgsl_str(offset)} )"
      }
      "textureSampleLevel( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{level} )"
    } else {
      if _wgsl_truthy(offset) {
        return "textureSampleLevel( \{p}, \{p}_sampler, \{uv}, \{level}, \{_wgsl_str(offset)} )"
      }
      "textureSampleLevel( \{p}, \{p}_sampler, \{uv}, \{level} )"
    }
  } else if b.is_filtered_texture(texture) {
    self.generate_filtered_texture(b, texture, p, uv, offset, level, depth)
  } else {
    b.generate_texture_lod(texture, p, uv, depth, offset, level_snippet=level)
  }
}

///|
/// `generateWrapFunction( texture )`: the name of the (cached) WGSL function that wraps
/// coordinates as the texture's wrap modes do.
pub fn WGSLNodeBuilder::generate_wrap_function(
  _self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  texture : @core.Texture,
) -> String {
  let is_3d = _wgsl_is_3d(texture)
  let function_name = "tsl_coord_\{_wgsl_wrap_name(texture.wrap_s)}S_\{_wgsl_wrap_name(texture.wrap_t)}T_\{if is_3d { "3d" } else { "2d" }}"
  let node_code = match _wgsl_code_cache.get(function_name) {
    Some(n) => n
    None => {
      let includes = []
      // For 3D textures, use vec3f; for texture arrays, keep vec2f since array index
      // is separate
      let coord_type = if is_3d { "vec3f" } else { "vec2f" }
      let mut code = "fn \{function_name}( coord : \{coord_type} ) -> \{coord_type} {\n\n\treturn \{coord_type}(\n"
      let add_wrap_snippet = fn(wrap : Int32, axis : String) {
        if wrap == @core.RepeatWrapping {
          includes.push(_wgsl_polyfill.get("repeatWrapping_float").unwrap())
          code += "\t\ttsl_repeatWrapping_float( coord.\{axis} )"
        } else if wrap == @core.ClampToEdgeWrapping {
          includes.push(_wgsl_polyfill.get("clampWrapping_float").unwrap())
          code += "\t\ttsl_clampWrapping_float( coord.\{axis} )"
        } else if wrap == @core.MirroredRepeatWrapping {
          includes.push(_wgsl_polyfill.get("mirrorWrapping_float").unwrap())
          code += "\t\ttsl_mirrorWrapping_float( coord.\{axis} )"
        } else {
          code += "\t\tcoord.\{axis}"
          @core.warn(
            "WebGPURenderer: Unsupported texture wrap type \"\{wrap}\" for vertex shader.",
          )
        }
      }
      add_wrap_snippet(texture.wrap_s, "x")
      code += ",\n"
      add_wrap_snippet(texture.wrap_t, "y")
      if is_3d {
        code += ",\n"
        add_wrap_snippet(texture.wrap_r, "z")
      }
      code += "\n\t);\n\n}\n"
      let n = @nodes.CodeNode::new(code~, includes~)
      _wgsl_code_cache.set(function_name, n)
      n
    }
  }
  node_code.build(b) |> ignore
  function_name
}

///|
/// `getDataFromNode( texture, this.shaderStage, this.cache )` for the keys
/// `generateTextureDimension` adds: found through the parent caches, else created in
/// the current cache.
fn WGSLNodeBuilder::_texture_data(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  texture : @core.Texture,
) -> WGSLTextureData {
  let shader_stage = _wgsl_stage(b, None)
  let mut stages : Map[String, WGSLTextureData]? = None
  let mut cache : @nodes.NodeCache? = Some(b.cache)
  while cache is Some(c) && stages is None {
    match self.texture_data.get(c.id) {
      Some(by_texture) => stages = by_texture.get(texture.id)
      None => ()
    }
    cache = c.parent
  }
  let stages = match stages {
    Some(s) => s
    None => {
      let by_texture = match self.texture_data.get(b.cache.id) {
        Some(m) => m
        None => {
          let m = Map([])
          self.texture_data.set(b.cache.id, m)
          m
        }
      }
      let s = Map([])
      by_texture.set(texture.id, s)
      s
    }
  }
  match stages.get(shader_stage) {
    Some(d) => d
    None => {
      let d = {
        dimensions_snippet: None,
        array_layer_count: None,
        cube_face_count: None,
      }
      stages.set(shader_stage, d)
      d
    }
  }
}

///|
/// `generateTextureDimension( texture, textureProperty, levelSnippet )`: a var holding
/// `textureDimensions( ... )`, one per texture and level.
pub fn WGSLNodeBuilder::generate_texture_dimension(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  texture : @core.Texture,
  p : String,
  level : String,
) -> String {
  let texture_data = self._texture_data(b, texture)
  let dimensions = match texture_data.dimensions_snippet {
    Some(d) => d
    None => {
      let d = Map([])
      texture_data.dimensions_snippet = Some(d)
      d
    }
  }
  let texture_dimension_node = match dimensions.get(level) {
    Some(n) => n
    None => {
      let { primary_samples, .. } = wgsl_get_texture_sample_data(
        b.renderer,
        texture,
      )
      let is_multisampled = primary_samples > 1
      let dimension_type = if _wgsl_is_3d(texture) {
        "vec3<u32>"
      } else {
        // Regular 2D textures, depth textures, etc.
        "vec2<u32>"
      }
      // Build parameters string based on texture type and multisampling
      let params = if is_multisampled || @nodes.is_storage_texture(texture) {
        p
      } else {
        let level_part = if level != "" { ", u32( \{level} )" } else { "" }
        "\{p}\{level_part}"
      }
      let node = @nodes.VarNode::new(
        @nodes.ExpressionNode::new(
          snippet="textureDimensions( \{params} )",
          node_type=dimension_type,
        ),
      )
      dimensions.set(level, node)
      if texture.is_array_texture ||
        texture.texture_type is DataArrayTexture ||
        _wgsl_is_3d(texture) {
        texture_data.array_layer_count = Some(
          @nodes.VarNode::new(
            @nodes.ExpressionNode::new(
              snippet="textureNumLayers(\{p})",
              node_type="u32",
            ),
          ),
        )
      }
      // `texture.isTextureCube` is never set upstream, so `cubeFaceCount` stays unset.
      node
    }
  }
  texture_dimension_node.build(b)
}

///|
/// `generateTextureSize( texture, textureProperty, levelSnippet )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_texture_size(
  _,
  b,
  texture,
  p,
  level,
) {
  let { primary_samples, .. } = wgsl_get_texture_sample_data(
    b.renderer,
    texture,
  )
  let is_multisampled = primary_samples > 1
  let params = if is_multisampled || @nodes.is_storage_texture(texture) {
    p
  } else {
    "\{p}, \{level}"
  }
  "textureDimensions( \{params} )"
}

///|
/// `generateFilteredTexture( texture, textureProperty, uvSnippet, offsetSnippet,
/// levelSnippet = '0u', depthSnippet )`: biquadratic filtering by hand.
pub fn WGSLNodeBuilder::generate_filtered_texture(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  texture : @core.Texture,
  p : String,
  uv : String,
  offset : String?,
  level : String,
  depth : String?,
) -> String {
  let wrap_function = self.generate_wrap_function(b, texture)
  let texture_dimension = self.generate_texture_dimension(b, texture, p, level)
  let mut uv = uv
  if _wgsl_truthy(offset) {
    uv = "\{uv} + vec2<f32>(\{_wgsl_str(offset)}) / \{texture_dimension}"
  }
  if _wgsl_truthy(depth) {
    self._include(b, "biquadraticTextureArray") |> ignore
    return "tsl_biquadraticTexture_array( \{p}, \{wrap_function}( \{uv} ), \{texture_dimension}, u32( \{_wgsl_str(depth)} ), u32( \{level} ) )"
  }
  self._include(b, "biquadraticTexture") |> ignore
  "tsl_biquadraticTexture( \{p}, \{wrap_function}( \{uv} ), \{texture_dimension}, u32( \{level} ) )"
}

///|
/// `generateTextureLod( texture, textureProperty, uvSnippet, depthSnippet,
/// offsetSnippet, levelSnippet = '0u' )`: a texel load at wrapped, clamped coordinates.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_texture_lod(
  self,
  b,
  texture,
  p,
  uv,
  depth,
  offset,
  level,
) {
  let mut uv = uv
  // Cube textures cannot use textureLoad in WGSL, must use textureSampleLevel
  if texture.is_cube_texture() {
    if _wgsl_truthy(offset) {
      uv = "\{uv} + vec3<f32>(\{_wgsl_str(offset)})"
    }
    // Depth textures require integer level, regular textures use float
    let level_type = if texture.is_depth_texture() { "u32" } else { "f32" }
    return "textureSampleLevel( \{p}, \{p}_sampler, \{uv}, \{level_type}( \{level} ) )"
  }
  let wrap_function = self.generate_wrap_function(b, texture)
  let texture_dimension = self.generate_texture_dimension(b, texture, p, level)
  let vec_type = if _wgsl_is_3d(texture) { "vec3" } else { "vec2" }
  let texture_dimension_margin = if vec_type == "vec3" {
    "vec3<u32>( 1, 1, 1 )"
  } else {
    "vec2<u32>( 1, 1 )"
  }
  if _wgsl_truthy(offset) {
    uv = "\{uv} + \{vec_type}<f32>(\{_wgsl_str(offset)}) / \{vec_type}<f32>( \{texture_dimension} )"
  }
  let clamp_min = "\{vec_type}<f32>( 0 )"
  let clamp_max = "\{vec_type}<f32>( \{texture_dimension} - \{texture_dimension_margin} )"
  uv = "\{vec_type}<u32>( clamp( floor( \{wrap_function}( \{uv} ) * \{vec_type}<f32>( \{texture_dimension} ) ), \{clamp_min}, \{clamp_max} ) )"
  b.generate_texture_load(texture, p, uv, Some(level), depth, None)
}

///|
/// `generateStorageTextureLoad( texture, textureProperty, uvIndexSnippet, levelSnippet,
/// depthSnippet, offsetSnippet )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_storage_texture_load(
  _,
  _,
  _,
  p,
  uv_index,
  _,
  depth,
  offset,
) {
  let mut uv_index = uv_index
  if _wgsl_truthy(offset) {
    uv_index = "\{uv_index} + \{_wgsl_str(offset)}"
  }
  if _wgsl_truthy(depth) {
    "textureLoad( \{p}, \{uv_index}, \{_wgsl_str(depth)} )"
  } else {
    "textureLoad( \{p}, \{uv_index} )"
  }
}

///|
/// `generateTextureLoad( texture, textureProperty, uvIndexSnippet, levelSnippet,
/// depthSnippet, offsetSnippet )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_texture_load(
  _,
  b,
  texture,
  p,
  uv_index,
  level,
  depth,
  offset,
) {
  let level = match level {
    Some(l) => l
    None => "0u"
  }
  let mut uv_index = uv_index
  if _wgsl_truthy(offset) {
    uv_index = "\{uv_index} + \{_wgsl_str(offset)}"
  }
  if _wgsl_truthy(depth) {
    "textureLoad( \{p}, \{uv_index}, \{_wgsl_str(depth)}, u32( \{level} ) )"
  } else {
    let mut snippet = "textureLoad( \{p}, \{uv_index}, u32( \{level} ) )"
    if wgsl_backend_compatibility_mode(b.renderer) && texture.is_depth_texture() {
      snippet += ".x"
    }
    snippet
  }
}

///|
/// `generateTextureStore( texture, textureProperty, uvIndexSnippet, depthSnippet,
/// valueSnippet )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_texture_store(
  _,
  _,
  _,
  p,
  uv_index,
  depth,
  value,
) {
  if _wgsl_truthy(depth) {
    "textureStore( \{p}, \{uv_index}, \{_wgsl_str(depth)}, \{value} )"
  } else {
    "textureStore( \{p}, \{uv_index}, \{value} )"
  }
}

///|
/// `isSampleCompare( texture )`.
pub fn WGSLNodeBuilder::is_sample_compare(
  _self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  texture : @core.Texture,
) -> Bool {
  texture.is_depth_texture() &&
  texture.compare_function is Some(_) &&
  b.renderer.has_compatibility(@core.Compatibility_TEXTURE_COMPARE)
}

///|
/// `isUnfilterable( texture )`: textures WGSL cannot sample with a filtering sampler.
pub fn WGSLNodeBuilder::is_unfilterable(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  texture : @core.Texture,
) -> Bool {
  b.get_component_type_from_texture(texture) != "float" ||
  (!b.is_available("float32Filterable") && texture.type_ == @core.FloatType) ||
  (
    !self.is_sample_compare(b, texture) &&
    texture.min_filter == @core.NearestFilter &&
    texture.mag_filter == @core.NearestFilter
  ) ||
  wgsl_get_texture_sample_data(b.renderer, texture).primary_samples > 1 ||
  (
    texture.normalized &&
    (
      texture.type_ == @core.ShortType ||
      texture.type_ == @core.UnsignedShortType
    )
  )
}

///|
/// `generateTexture( texture, textureProperty, uvSnippet, depthSnippet, offsetSnippet,
/// shaderStage = this.shaderStage )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_texture(
  self,
  b,
  texture,
  p,
  uv,
  depth,
  offset,
  shader_stage,
) {
  if self.is_unfilterable(b, texture) {
    b.generate_texture_lod(texture, p, uv, depth, offset, level_snippet="0")
  } else {
    self._generate_texture_sample(
      b, texture, p, uv, depth, offset, shader_stage,
    )
  }
}

///|
/// `generateTextureGrad( texture, textureProperty, uvSnippet, gradSnippet,
/// depthSnippet, offsetSnippet, shaderStage = this.shaderStage )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_texture_grad(
  self,
  b,
  texture,
  p,
  uv,
  grad,
  depth,
  offset,
  shader_stage,
) {
  let stage = _wgsl_stage(b, shader_stage)
  if stage == "fragment" {
    // Unfilterable textures have no sampler binding. Use the same texel lookup as
    // regular sampling, preserving nearest filtering, wrapping and offsets.
    if self.is_unfilterable(b, texture) {
      return b.generate_texture(
        texture,
        p,
        uv,
        depth_snippet?=depth,
        offset_snippet?=offset,
        shader_stage=stage,
      )
    }
    let g0 = _wgsl_grad(grad, 0)
    let g1 = _wgsl_grad(grad, 1)
    if _wgsl_truthy(depth) {
      if _wgsl_truthy(offset) {
        return "textureSampleGrad( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{g0}, \{g1}, \{_wgsl_str(offset)} )"
      }
      "textureSampleGrad( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{g0}, \{g1} )"
    } else {
      if _wgsl_truthy(offset) {
        return "textureSampleGrad( \{p}, \{p}_sampler, \{uv}, \{g0}, \{g1}, \{_wgsl_str(offset)} )"
      }
      "textureSampleGrad( \{p}, \{p}_sampler, \{uv}, \{g0}, \{g1} )"
    }
  } else {
    @core.error(
      "WebGPURenderer: THREE.TextureNode.gradient() does not support \{stage} shader.",
    )
    "undefined"
  }
}

///|
/// `gradSnippet[ i ]`.
fn _wgsl_grad(grad : Array[String], i : Int32) -> String {
  if i < grad.length() {
    grad[i]
  } else {
    "undefined"
  }
}

///|
/// `generateTextureCompare( texture, textureProperty, uvSnippet, compareSnippet,
/// depthSnippet, offsetSnippet, shaderStage = this.shaderStage )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_texture_compare(
  _,
  b,
  texture,
  p,
  uv,
  compare,
  depth,
  offset,
  shader_stage,
) {
  let stage = _wgsl_stage(b, shader_stage)
  if stage == "fragment" {
    if texture.is_depth_texture() && texture.is_array_texture {
      if _wgsl_truthy(offset) {
        return "textureSampleCompare( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{compare}, \{_wgsl_str(offset)} )"
      }
      return "textureSampleCompare( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{compare} )"
    }
    if _wgsl_truthy(offset) {
      return "textureSampleCompare( \{p}, \{p}_sampler, \{uv}, \{compare}, \{_wgsl_str(offset)} )"
    }
    "textureSampleCompare( \{p}, \{p}_sampler, \{uv}, \{compare} )"
  } else {
    @core.error(
      "WebGPURenderer: THREE.DepthTexture.compareFunction() does not support \{stage} shader.",
    )
    "undefined"
  }
}

///|
/// `generateTextureGather( texture, textureProperty, uvSnippet, gatherSnippet,
/// depthSnippet, offsetSnippet )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_texture_gather(
  self,
  b,
  texture,
  p,
  uv,
  gather,
  depth,
  offset,
  _,
) {
  let { primary_samples, .. } = wgsl_get_texture_sample_data(
    b.renderer,
    texture,
  )
  if primary_samples > 1 {
    // textureGather() has no overload for multisampled textures (e.g. the depth of a
    // MSAA render target), so the four texels are fetched with textureLoad()
    let texture_dimension = self.generate_texture_dimension(b, texture, p, "0u")
    let mut coord_snippet = "vec2<i32>( floor( \{uv} * vec2<f32>( \{texture_dimension} ) - 0.5 ) )"
    if _wgsl_truthy(offset) {
      coord_snippet = "\{coord_snippet} + \{_wgsl_str(offset)}"
    }
    let coord = @nodes.VarNode::new(
      @nodes.ExpressionNode::new(snippet=coord_snippet, node_type="ivec2"),
    ).build(b)
    let coord_max = "vec2<i32>( \{texture_dimension} ) - 1"
    let load = fn(x : Int32, y : Int32) -> String {
      let snippet = b.generate_texture_load(
        texture,
        p,
        "clamp( \{coord} + vec2<i32>( \{x}, \{y} ), vec2<i32>( 0 ), \{coord_max} )",
        None,
        None,
        None,
      )
      if texture.is_depth_texture() {
        snippet
      } else {
        "\{snippet}[ \{_wgsl_str(gather)} ]"
      }
    }
    // same texel order as textureGather()
    let component_prefix = _wgsl_char_at0(
      b.get_component_type_from_texture(texture),
    )
    let l01 = load(0, 1)
    let l11 = load(1, 1)
    let l10 = load(1, 0)
    let l00 = load(0, 0)
    return "vec4<\{component_prefix}32>( \{l01}, \{l11}, \{l10}, \{l00} )"
  }
  let component_snippet = if texture.is_depth_texture() {
    ""
  } else {
    "\{_wgsl_str(gather)}, "
  }
  if _wgsl_truthy(depth) {
    if _wgsl_truthy(offset) {
      return "textureGather( \{component_snippet}\{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{_wgsl_str(offset)} )"
    }
    return "textureGather( \{component_snippet}\{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)} )"
  }
  if _wgsl_truthy(offset) {
    return "textureGather( \{component_snippet}\{p}, \{p}_sampler, \{uv}, \{_wgsl_str(offset)} )"
  }
  "textureGather( \{component_snippet}\{p}, \{p}_sampler, \{uv})"
}

///|
/// `string.charAt( 0 )`.
fn _wgsl_char_at0(s : String) -> String {
  if s.length() == 0 {
    ""
  } else {
    s.unsafe_substring(start=0, end=1)
  }
}

///|
/// `generateTextureGatherCompare( texture, textureProperty, uvSnippet, compareSnippet,
/// depthSnippet, offsetSnippet )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_texture_gather_compare(
  _,
  _,
  _,
  p,
  uv,
  compare,
  depth,
  offset,
  _,
) {
  if _wgsl_truthy(depth) {
    if _wgsl_truthy(offset) {
      return "textureGatherCompare( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{compare}, \{_wgsl_str(offset)} )"
    }
    return "textureGatherCompare( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{compare})"
  }
  if _wgsl_truthy(offset) {
    return "textureGatherCompare( \{p}, \{p}_sampler, \{uv}, \{compare}, \{_wgsl_str(offset)} )"
  }
  "textureGatherCompare( \{p}, \{p}_sampler, \{uv}, \{compare})"
}

///|
/// `generateTextureLevel( texture, textureProperty, uvSnippet, levelSnippet,
/// depthSnippet, offsetSnippet )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_texture_level(
  self,
  b,
  texture,
  p,
  uv,
  level,
  depth,
  offset,
) {
  if !self.is_unfilterable(b, texture) {
    if _wgsl_truthy(depth) {
      if _wgsl_truthy(offset) {
        return "textureSampleLevel( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{level}, \{_wgsl_str(offset)} )"
      }
      "textureSampleLevel( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{level} )"
    } else {
      if _wgsl_truthy(offset) {
        return "textureSampleLevel( \{p}, \{p}_sampler, \{uv}, \{level}, \{_wgsl_str(offset)} )"
      }
      "textureSampleLevel( \{p}, \{p}_sampler, \{uv}, \{level} )"
    }
  } else if b.is_filtered_texture(texture) {
    self.generate_filtered_texture(b, texture, p, uv, offset, level, depth)
  } else {
    b.generate_texture_lod(texture, p, uv, depth, offset, level_snippet=level)
  }
}

///|
/// `generateTextureBias( texture, textureProperty, uvSnippet, biasSnippet,
/// depthSnippet, offsetSnippet, shaderStage = this.shaderStage )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_texture_bias(
  _,
  b,
  _,
  p,
  uv,
  bias,
  depth,
  offset,
  shader_stage,
) {
  let stage = _wgsl_stage(b, shader_stage)
  if stage == "fragment" {
    if _wgsl_truthy(depth) {
      if _wgsl_truthy(offset) {
        return "textureSampleBias( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{bias}, \{_wgsl_str(offset)} )"
      }
      "textureSampleBias( \{p}, \{p}_sampler, \{uv}, \{_wgsl_str(depth)}, \{bias} )"
    } else {
      if _wgsl_truthy(offset) {
        return "textureSampleBias( \{p}, \{p}_sampler, \{uv}, \{bias}, \{_wgsl_str(offset)} )"
      }
      "textureSampleBias( \{p}, \{p}_sampler, \{uv}, \{bias} )"
    }
  } else {
    @core.error(
      "WebGPURenderer: THREE.TextureNode.biasNode does not support \{stage} shader.",
    )
    "undefined"
  }
}
