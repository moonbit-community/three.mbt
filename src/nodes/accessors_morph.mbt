// nodes/accessors/Morph.js: morph targets packed into a data array texture, blended by
// `morphTargetInfluences` (or the instanced `morphTexture`).

///|
/// `{ count, texture, stride, size }` of a geometry's morph texture.
priv struct MorphEntry {
  count : Int32
  texture : @core.Texture
  stride : Int32
  size : @math.Vector2
}

///|
let _morph_textures : @webgl.WeakMap[@core.BufferGeometry, MorphEntry] = @webgl.WeakMap::new()

///|
let _morph_vec4 : @math.Vector4 = @math.Vector4::new(0.0, 0.0, 0.0, 0.0)

///|
/// `{ influences, count }` of a mesh.
priv struct MorphInfluencesData {
  influences : Node?
  count : Int32
}

///|
let _morph_influences_data : @webgl.WeakMap[@core.Object3D, MorphInfluencesData] = @webgl.WeakMap::new()

///|
/// `getMorph( { bufferMap, influence, stride, width, depth, offset } )`.
let _morph_get_morph : Node = module_nodes(
  "nodes/accessors/Morph.js:getMorph",
  fn() {
    fn_(fn(inputs, _) {
      // `bufferMap` is a texture, which `nodeObject` leaves as it is.
      let buffer_map = match inputs.params {
        [Object(o), ..] => o.get("bufferMap").unwrap_or(Undefined)
        _ => Undefined
      }
      let influence = inputs.named("influence").unwrap()
      let stride = inputs.named("stride").unwrap()
      let width = inputs.named("width").unwrap()
      let depth = inputs.named("depth").unwrap()
      let offset = inputs.named("offset").unwrap()
      let texel_index = int(vertex_index).mul(stride).add(offset)
      let y = texel_index.div(width)
      let x = texel_index.sub(y.mul(width))
      let buffer_attrib = texture_load(buffer_map, uv_node=ivec2_of([x, y])).depth(
        depth,
      )
      Some(buffer_attrib.mul(influence))
    })
  },
)

///|
/// The mesh payload of an `Object3D`.
fn morph_mesh(object : @core.Object3D) -> @core.Mesh {
  match object.kind {
    Mesh(m) => m
    _ => abort("TypeError: \{object.type_} is not a mesh")
  }
}

///|
let _morph_base : Node = module_nodes("nodes/accessors/Morph.js:morphBase", fn() {
  uniform(1).on_object_update(fn(self_, frame) {
    let object = frame.object.unwrap()
    let value = if object.get_geometry().unwrap().morph_targets_relative {
      1.0
    } else {
      let mut sum = 0.0
      for x in morph_mesh(object).morph_target_influences.unwrap() {
        sum = sum + x
      }
      1.0 - sum
    }
    InputNode::set_value(self_, Number(value))
    None
  })
})

///|
let _morph_color_sum : Node = module_nodes(
  "nodes/accessors/Morph.js:morphColorSum",
  fn() { property("vec4", name="morphColorSum") },
)

///|
/// `geometry.morphAttributes.color[ 0 ].itemSize === 4`.
fn morph_color_has_alpha(geometry : @core.BufferGeometry) -> Bool {
  match geometry.morph_attributes.get("color") {
    Some(colors) => colors[0].item_size() == 4
    None =>
      abort("TypeError: Cannot read properties of undefined (reading '0')")
  }
}

///|
/// `morphColor( color )`.
pub let morph_color : Node = module_nodes(
  "nodes/accessors/Morph.js:morphColor",
  fn() {
    fn_(fn(inputs, builder) {
      let color = inputs.get(0).unwrap()
      if morph_color_has_alpha(builder.geometry.unwrap()) {
        return Some(varying(color.mul(_morph_base).add(_morph_color_sum)))
      }
      Some(
        varying(
          vec4_of([
            color.rgb().mul(_morph_base).add(_morph_color_sum.rgb()),
            color.a(),
          ]),
        ),
      )
    })
  },
)

///|
/// `getEntry( geometry )`.
fn morph_get_entry(geometry : @core.BufferGeometry) -> MorphEntry {
  let morph_position = geometry.morph_attributes.get("position")
  let morph_normal = geometry.morph_attributes.get("normal")
  let morph_color = geometry.morph_attributes.get("color")
  let has_morph_position = morph_position is Some(_)
  let has_morph_normals = morph_normal is Some(_)
  let has_morph_colors = morph_color is Some(_)
  let morph_attribute = morph_first([morph_position, morph_normal, morph_color])
  let morph_targets_count = match morph_attribute {
    Some(a) => a.length()
    None => 0
  }
  match _morph_textures.get(geometry) {
    Some(entry) if entry.count == morph_targets_count => entry
    entry => {
      match entry {
        Some(e) => e.texture.dispose()
        None => ()
      }
      let morph_targets = morph_position.unwrap_or([])
      let morph_normals = morph_normal.unwrap_or([])
      let morph_colors = morph_color.unwrap_or([])
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
      let mut width = geometry.get_attribute("position").unwrap().count() *
        vertex_data_count
      let mut height = 1
      // @TODO: Use 'capabilities.maxTextureSize'
      let max_texture_size = 4096
      if width > max_texture_size {
        height = (width.to_double() / max_texture_size.to_double())
          .ceil()
          .to_int()
        width = max_texture_size
      }
      let buffer = @core.TypedArray::float32(
        width * height * 4 * morph_targets_count,
      )
      let buffer_texture = @core.DataArrayTexture::new(
        data=buffer,
        width~,
        height~,
        depth=morph_targets_count,
      )
      buffer_texture.type_ = @core.FloatType
      buffer_texture.set_needs_update(true)
      let vertex_data_stride = vertex_data_count * 4
      for i in 0..<morph_targets_count {
        let morph_target = morph_targets[i]
        let offset = width * height * 4 * i
        for j in 0..<morph_target.count() {
          let stride = j * vertex_data_stride
          if has_morph_position {
            morph_vec4_from_attribute(morph_target, j)
            buffer[offset + stride + 0] = _morph_vec4.x
            buffer[offset + stride + 1] = _morph_vec4.y
            buffer[offset + stride + 2] = _morph_vec4.z
            buffer[offset + stride + 3] = 0.0
          }
          if has_morph_normals {
            morph_vec4_from_attribute(morph_normals[i], j)
            buffer[offset + stride + 4] = _morph_vec4.x
            buffer[offset + stride + 5] = _morph_vec4.y
            buffer[offset + stride + 6] = _morph_vec4.z
            buffer[offset + stride + 7] = 0.0
          }
          if has_morph_colors {
            let morph_color = morph_colors[i]
            morph_vec4_from_attribute(morph_color, j)
            buffer[offset + stride + 8] = _morph_vec4.x
            buffer[offset + stride + 9] = _morph_vec4.y
            buffer[offset + stride + 10] = _morph_vec4.z
            buffer[offset + stride + 11] = if morph_color.item_size() == 4 {
              _morph_vec4.w
            } else {
              1.0
            }
          }
        }
      }
      let entry = MorphEntry::{
        count: morph_targets_count,
        texture: buffer_texture,
        stride: vertex_data_count,
        size: @math.Vector2::new(width.to_double(), height.to_double()),
      }
      _morph_textures.set(geometry, entry)
      let dispose_texture : Ref[(@core.Event) -> Unit] = Ref(fn(_) {  })
      dispose_texture.val = fn(_) {
        buffer_texture.dispose()
        _morph_textures.delete(geometry)
        geometry.remove_event_listener("dispose", dispose_texture.val)
      }
      geometry.add_event_listener("dispose", dispose_texture.val)
      entry
    }
  }
}

///|
/// `a || b || c` of morph attribute lists.
fn morph_first(
  values : Array[Array[@core.GeometryAttribute]?],
) -> Array[@core.GeometryAttribute]? {
  for v in values {
    if v is Some(_) {
      return v
    }
  }
  None
}

///|
/// `_morphVec4.fromBufferAttribute( attribute, index )`.
fn morph_vec4_from_attribute(
  attribute : @core.GeometryAttribute,
  index : Int32,
) -> Unit {
  _morph_vec4.x = attribute.get_x(index)
  _morph_vec4.y = attribute.get_y(index)
  _morph_vec4.z = attribute.get_z(index)
  _morph_vec4.w = attribute.get_w(index)
}

///|
/// `morphReference( mesh )`: `morph_reference.call( [ mesh ] )`.
pub let morph_reference : Node = module_nodes(
  "nodes/accessors/Morph.js:morphReference",
  fn() {
    fn_(
      fn(inputs, builder) {
        let object : @core.Object3D = match inputs.value(0) {
          Js(v) => v.cast()
          _ => abort("morphReference: expects a mesh")
        }
        let mesh = morph_mesh(object)
        let geometry = mesh.geometry
        let morph_position = geometry.morph_attributes.get("position")
        let morph_normal = geometry.morph_attributes.get("normal")
        let morph_color_attribute = geometry.morph_attributes.get("color")
        let has_morph_position = morph_position is Some(_)
        let has_morph_normals = geometry.has_attribute("normal") &&
          morph_normal is Some(_)
        let has_morph_colors = builder.material.unwrap().vertex_colors &&
          morph_color_attribute is Some(_)
        let has_color_alpha = has_morph_colors &&
          morph_color_attribute.unwrap()[0].item_size() == 4
        let morph_attribute = morph_first([
          morph_position, morph_normal, morph_color_attribute,
        ])
        let morph_targets_count = match morph_attribute {
          Some(a) => a.length()
          None => 0
        }
        if morph_targets_count == 0 {
          return None
        }
        let morph_texture = match object.kind {
          Mesh({ kind: InstancedMesh(m), .. }) => m.morph_texture
          _ => None
        }
        if morph_texture is Some(_) {
          builder.object_specific = true
        }
        let morph_influence_data = match _morph_influences_data.get(object) {
          Some(d) if d.count == morph_targets_count => d
          _ => {
            let d = MorphInfluencesData::{
              influences: mesh.morph_target_influences.map(fn(a) {
                uniform_array(a, element_type="float")
              }),
              count: morph_targets_count,
            }
            _morph_influences_data.set(object, d)
            d
          }
        }
        let influences = morph_influence_data.influences
        let entry = morph_get_entry(geometry)
        let buffer_map = entry.texture
        let stride = entry.stride
        let size = entry.size
        if has_morph_position {
          position_local.mul_assign(_morph_base)
        }
        if has_morph_normals {
          normal_local.mul_assign(_morph_base)
        }
        if has_morph_colors {
          _morph_color_sum.assign(0)
        }
        let width = int(size.x)
        loop_([morph_targets_count], fn(loop_inputs) {
          let i = loop_inputs.named("i").unwrap()
          let influence = float(0).to_var()
          if mesh.count > 1 && morph_texture is Some(morph_texture) {
            influence.assign(
              texture_load(
                morph_texture,
                uv_node=ivec2_of([int(i).add(1), int(instance_index)]),
              ).r(),
            )
          } else {
            influence.assign(influences.unwrap().element(i).to_var())
          }
          if_(influence.not_equal(0), fn() {
            let morph_args = fn(offset : Int32) -> Map[String, &IntoTsl] {
              {
                "bufferMap": TslValue::Texture(buffer_map),
                "influence": influence,
                "stride": stride,
                "width": width,
                "depth": i,
                "offset": int(offset),
              }
            }
            if has_morph_position {
              position_local.add_assign(
                _morph_get_morph.call_named(morph_args(0)).xyz(),
              )
            }
            if has_morph_normals {
              normal_local.add_assign(
                _morph_get_morph.call_named(morph_args(1)).xyz(),
              )
            }
            if has_morph_colors {
              let morph = _morph_get_morph.call_named(morph_args(2))
              if has_color_alpha {
                _morph_color_sum.add_assign(morph)
              } else {
                _morph_color_sum.rgb().add_assign(morph.rgb())
              }
            }
          })
          |> ignore
        })
        on_object_update(fn(frame) {
          match morph_influence_data.influences {
            Some(influences) => {
              UniformArrayNode::of(influences).unwrap().array = morph_mesh(
                  frame.object.unwrap(),
                ).morph_target_influences
                .unwrap()
                .map(fn(x) { Number(x) })
              influences.update(frame) |> ignore
            }
            None => ()
          }
        })
        |> ignore
        None
      },
      layout=ReturnType("void"),
    )
  },
)
