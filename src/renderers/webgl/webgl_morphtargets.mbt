// Upstream src/renderers/webgl/WebGLMorphtargets.js. GROUP 3.

///|
/// `morphTextures.get( geometry )`.
pub(all) struct MorphTextureEntry {
  count : Int32
  texture : @core.Texture
  size : @math.Vector2
}

///|
pub struct WebGLMorphtargets {
  gl : WebGL2RenderingContext
  capabilities : WebGLCapabilities
  textures : WebGLTextures
  morph_textures : WeakMap[@core.BufferGeometry, MorphTextureEntry]
  morph : @math.Vector4
}

///|
/// `new WebGLMorphtargets( gl, capabilities, textures )`.
pub fn WebGLMorphtargets::new(
  gl : WebGL2RenderingContext,
  capabilities : WebGLCapabilities,
  textures : WebGLTextures,
) -> WebGLMorphtargets {
  {
    gl,
    capabilities,
    textures,
    morph_textures: WeakMap::new(),
    morph: @math.Vector4::new(0, 0, 0, 0),
  }
}

///|
/// `morphtargets.update( object, geometry, program )`.
pub fn WebGLMorphtargets::update(
  self : WebGLMorphtargets,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  program : WebGLProgram,
) -> Unit {
  let gl = self.gl
  let morph = self.morph
  let morph_textures = self.morph_textures
  let (_, object_influences) = object.morph_targets()

  // the following encodes morph targets into an array of data textures. Each layer represents a single morph target.
  let morph_attributes = geometry.morph_attributes
  let morph_attribute = match morph_attributes.get("position") {
    Some(attribute) => Some(attribute)
    None =>
      match morph_attributes.get("normal") {
        Some(attribute) => Some(attribute)
        None => morph_attributes.get("color")
      }
  }
  let morph_targets_count = match morph_attribute {
    Some(attribute) => attribute.length()
    None => 0
  }
  let entry = match morph_textures.get(geometry) {
    Some(entry) if entry.count == morph_targets_count => entry
    previous => {
      if previous is Some(previous) {
        previous.texture.dispose()
      }
      let has_morph_position = morph_attributes.get("position") is Some(_)
      let has_morph_normals = morph_attributes.get("normal") is Some(_)
      let has_morph_colors = morph_attributes.get("color") is Some(_)
      let morph_targets = morph_attributes.get("position").unwrap_or([])
      let morph_normals = morph_attributes.get("normal").unwrap_or([])
      let morph_colors = morph_attributes.get("color").unwrap_or([])
      let mut vertex_data_count = 0
      if has_morph_position {
        vertex_data_count = 1
      }
      if has_morph_normals {
        vertex_data_count = 2
      }
      if has_morph_colors {
        vertex_data_count = 3
      }
      let position_count = match geometry.attributes.get("position") {
        Some(position) => position.count()
        None => abort("WebGLMorphtargets: geometry without position")
      }
      let mut width = position_count * vertex_data_count
      let mut height = 1
      let max_texture_size = self.capabilities.max_texture_size
      if width > max_texture_size {
        height = (width.to_double() / max_texture_size.to_double())
          .ceil()
          .to_int()
        width = max_texture_size
      }
      let buffer = @core.TypedArray::float32(
        width * height * 4 * morph_targets_count,
      )
      let texture = @core.DataArrayTexture::new(
        data=buffer,
        width~,
        height~,
        depth=morph_targets_count,
      )
      texture.type_ = @core.FloatType
      texture.set_needs_update(true)

      // fill buffer
      let vertex_data_stride = vertex_data_count * 4
      for i in 0..<morph_targets_count {
        let morph_target = morph_targets[i]
        let offset = width * height * 4 * i
        for j in 0..<morph_target.count() {
          let stride = j * vertex_data_stride
          if has_morph_position {
            ignore(morph.from_buffer_attribute(morph_target, j))
            buffer.set(offset + stride + 0, morph.x)
            buffer.set(offset + stride + 1, morph.y)
            buffer.set(offset + stride + 2, morph.z)
            buffer.set(offset + stride + 3, 0)
          }
          if has_morph_normals {
            let morph_normal = morph_normals[i]
            ignore(morph.from_buffer_attribute(morph_normal, j))
            buffer.set(offset + stride + 4, morph.x)
            buffer.set(offset + stride + 5, morph.y)
            buffer.set(offset + stride + 6, morph.z)
            buffer.set(offset + stride + 7, 0)
          }
          if has_morph_colors {
            let morph_color = morph_colors[i]
            ignore(morph.from_buffer_attribute(morph_color, j))
            buffer.set(offset + stride + 8, morph.x)
            buffer.set(offset + stride + 9, morph.y)
            buffer.set(offset + stride + 10, morph.z)
            buffer.set(
              offset + stride + 11,
              if morph_color.item_size() == 4 {
                morph.w
              } else {
                1
              },
            )
          }
        }
      }
      let entry : MorphTextureEntry = {
        count: morph_targets_count,
        texture,
        size: @math.Vector2::new(width.to_double(), height.to_double()),
      }
      morph_textures.set(geometry, entry)
      let dispose_texture : Ref[(@core.Event) -> Unit] = { val: fn(_) {  }, }
      dispose_texture.val = fn(_) {
        texture.dispose()
        morph_textures.delete(geometry)
        geometry.remove_event_listener("dispose", dispose_texture.val)
      }
      geometry.add_event_listener("dispose", dispose_texture.val)
      entry
    }
  }

  //
  let uniforms = program.get_uniforms()
  match object.kind {
    Mesh(
      { kind: InstancedMesh({ morph_texture: Some(morph_texture), .. }), .. }
    ) =>
      uniforms.set_value(
        gl,
        "morphTexture",
        Texture(morph_texture),
        textures=self.textures,
      )
    _ => {
      let influences = object_influences.unwrap()
      let mut morph_influences_sum = 0.0
      for i in 0..<influences.length() {
        morph_influences_sum += influences[i]
      }
      let morph_base_influence = if geometry.morph_targets_relative {
        1.0
      } else {
        1.0 - morph_influences_sum
      }
      uniforms.set_value(
        gl,
        "morphTargetBaseInfluence",
        Number(morph_base_influence),
      )
      uniforms.set_value(gl, "morphTargetInfluences", Numbers(influences))
    }
  }
  uniforms.set_value(
    gl,
    "morphTargetsTexture",
    Texture(entry.texture),
    textures=self.textures,
  )
  uniforms.set_value(gl, "morphTargetsTextureSize", Vector2(entry.size))
}
