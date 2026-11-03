// nodes/accessors/Skinning.js: skinned positions, normals and tangents from the bone
// matrices (a uniform buffer, or the bone texture beyond the uniform buffer limit).

///|
/// `_skeletonsUpdated`: skeleton -> the frame it was last updated in.
let _skinning_skeletons_updated : @webgl.WeakMap[@core.Skeleton, Int32] = @webgl.WeakMap::new()

///|
/// The bone matrices source of `getSkinnedPosition`: `element( i )` of a buffer node,
/// or of the bone texture (`getBoneTextureMatrices`).
priv enum SkinningBoneMatrices {
  BufferMatrices(Node)
  TextureMatrices(Node)
}

///|
/// `boneMatrices.element( i )`.
fn SkinningBoneMatrices::element(self : SkinningBoneMatrices, i : Node) -> Node {
  match self {
    BufferMatrices(n) => n.element(i)
    TextureMatrices(bone_texture) => {
      let size = int(texture_size(bone_texture).x()).to_const()
      let j = int(i).mul(4).to_const()
      let y = j.div(size).to_const()
      let x = j.sub(y.mul(size)).to_const()
      mat4_of([
        bone_texture.load(ivec2_of([x, y])),
        bone_texture.load(ivec2_of([x.add(1), y])),
        bone_texture.load(ivec2_of([x.add(2), y])),
        bone_texture.load(ivec2_of([x.add(3), y])),
      ])
    }
  }
}

///|
/// The skeleton of a skinned mesh.
fn skinning_skeleton(object : @core.Object3D) -> @core.Skeleton {
  match object.kind {
    Mesh({ kind: SkinnedMesh({ skeleton: Some(s), .. }), .. }) => s
    _ => abort("TypeError: Cannot read properties of undefined (skeleton)")
  }
}

///|
/// The skinned mesh payload.
fn skinning_skinned_mesh(object : @core.Object3D) -> @core.SkinnedMesh {
  match object.kind {
    Mesh({ kind: SkinnedMesh(s), .. }) => s
    _ => abort("TypeError: \{object.type_} is not a SkinnedMesh")
  }
}

///|
/// `getBoneMatricesNode( builder, skeleton )`.
fn skinning_get_bone_matrices_node(
  builder : NodeBuilder,
  skeleton : @core.Skeleton,
) -> SkinningBoneMatrices {
  let uniform_buffer_size = skeleton.bones.length() * 16 * 4
  if uniform_buffer_size <= builder.get_uniform_buffer_limit() {
    BufferMatrices(
      reference_buffer("skeleton.boneMatrices", "mat4", skeleton.bones.length()),
    )
  } else {
    if skeleton.bone_texture is None {
      skeleton.compute_bone_texture() |> ignore
    }
    let bone_texture = texture(skeleton.bone_texture.unwrap())
    on_object_update(fn(frame) {
      let skeleton = skinning_skeleton(frame.object.unwrap())
      if skeleton.bone_texture is None {
        skeleton.compute_bone_texture() |> ignore
      }
      TextureNode::set_value(bone_texture, skeleton.bone_texture)
    })
    |> ignore
    TextureMatrices(bone_texture)
  }
}

///|
/// `getSkinnedPosition( boneMatrices, position, bindMatrix, bindMatrixInverse,
/// skinIndex, skinWeight )`.
fn skinning_get_skinned_position(
  bone_matrices : SkinningBoneMatrices,
  position : Node,
  bind_matrix : Node,
  bind_matrix_inverse : Node,
  skin_index : Node,
  skin_weight : Node,
) -> Node {
  let bone_mat_x = bone_matrices.element(skin_index.x())
  let bone_mat_y = bone_matrices.element(skin_index.y())
  let bone_mat_z = bone_matrices.element(skin_index.z())
  let bone_mat_w = bone_matrices.element(skin_index.w())
  let skin_vertex = bind_matrix.mul(position)
  let skinned = add_of([
    bone_mat_x.mul(skin_weight.x()).mul(skin_vertex),
    bone_mat_y.mul(skin_weight.y()).mul(skin_vertex),
    bone_mat_z.mul(skin_weight.z()).mul(skin_vertex),
    bone_mat_w.mul(skin_weight.w()).mul(skin_vertex),
  ])
  bind_matrix_inverse.mul(skinned).xyz()
}

///|
/// `getSkinnedNormalAndTangent( ... )`: `{ skinNormal, skinTangent }`.
fn skinning_get_skinned_normal_and_tangent(
  bone_matrices : SkinningBoneMatrices,
  normal : Node,
  tangent : Node,
  bind_matrix : Node,
  bind_matrix_inverse : Node,
  skin_index : Node,
  skin_weight : Node,
) -> (Node, Node) {
  let bone_mat_x = bone_matrices.element(skin_index.x())
  let bone_mat_y = bone_matrices.element(skin_index.y())
  let bone_mat_z = bone_matrices.element(skin_index.z())
  let bone_mat_w = bone_matrices.element(skin_index.w())
  let mut skin_matrix = add_of([
    skin_weight.x().mul(bone_mat_x),
    skin_weight.y().mul(bone_mat_y),
    skin_weight.z().mul(bone_mat_z),
    skin_weight.w().mul(bone_mat_w),
  ])
  skin_matrix = bind_matrix_inverse.mul(skin_matrix).mul(bind_matrix)
  let skin_matrix3 = mat3(skin_matrix)
  let skin_normal = skin_matrix3.mul(normal)
  let skin_tangent = skin_matrix3.mul(tangent)
  (skin_normal, skin_tangent)
}

///|
/// `setupPreviousBoneData( skeleton )`.
fn skinning_setup_previous_bone_data(skeleton : @core.Skeleton) -> Unit {
  if skeleton.previous_bone_matrices is None {
    skeleton.update()
    skeleton.previous_bone_matrices = Some(
      @core.TypedArray::float32(skeleton.bone_matrices.unwrap()),
    )
  }
  if skeleton.previous_bone_texture is None && skeleton.bone_texture is Some(t) {
    let (width, height) = match t.image() {
      DataImage(d) => (d.width, d.height)
      _ => (1, 1)
    }
    let previous_bone_texture = @core.DataTexture::new(
      data=skeleton.previous_bone_matrices.unwrap(),
      width~,
      height~,
      format=@core.RGBAFormat,
      type_=@core.FloatType,
    )
    previous_bone_texture.set_needs_update(true)
    skeleton.previous_bone_texture = Some(previous_bone_texture)
  }
}

///|
/// `getPreviousBoneMatricesNode( builder, skeleton )`.
fn skinning_get_previous_bone_matrices_node(
  builder : NodeBuilder,
  skeleton : @core.Skeleton,
) -> SkinningBoneMatrices {
  skinning_setup_previous_bone_data(skeleton)
  let uniform_buffer_size = skeleton.bones.length() * 16 * 4
  if uniform_buffer_size <= builder.get_uniform_buffer_limit() {
    BufferMatrices(
      reference_buffer(
        "skeleton.previousBoneMatrices",
        "mat4",
        skeleton.bones.length(),
      ),
    )
  } else {
    let previous_bone_texture = texture(skeleton.previous_bone_texture.unwrap())
    on_object_update(fn(frame) {
      TextureNode::set_value(
        previous_bone_texture,
        skinning_skeleton(frame.object.unwrap()).previous_bone_texture,
      )
    })
    |> ignore
    TextureMatrices(previous_bone_texture)
  }
}

///|
/// The per-frame skeleton update of `skinning` and `computeSkinning`.
fn skinning_update_skeleton(
  skeleton : @core.Skeleton,
  frame_id : Int32,
) -> Unit {
  if _skinning_skeletons_updated.get(skeleton) != Some(frame_id) {
    _skinning_skeletons_updated.set(skeleton, frame_id)
    match skeleton.previous_bone_matrices {
      Some(previous) => {
        previous.set_from(skeleton.bone_matrices.unwrap())
        match skeleton.previous_bone_texture {
          Some(t) => t.set_needs_update(true)
          None => ()
        }
      }
      None => ()
    }
    skeleton.update()
  }
}

///|
/// `skinning( skinnedMesh )`: `skinning.call( [ mesh ] )`.
pub let skinning : Node = module_nodes("nodes/accessors/Skinning.js:skinning", fn() {
  fn_(
    fn(inputs, builder) {
      let skinned_mesh : @core.Object3D = match inputs.value(0) {
        Js(v) => v.cast()
        _ => abort("skinning: expects a SkinnedMesh")
      }
      let skin_index_node = attribute("skinIndex", node_type="uvec4")
      let skin_weight_node = attribute("skinWeight", node_type="vec4")
      let bind_matrix_node = reference("bindMatrix", "mat4")
      let bind_matrix_inverse_node = reference("bindMatrixInverse", "mat4")
      let bone_matrices_node = skinning_get_bone_matrices_node(
        builder,
        skinning_skeleton(skinned_mesh),
      )
      let needs_previous_data = builder.needs_previous_data()
      on_object_update(fn(frame) {
        let skeleton = skinning_skeleton(frame.object.unwrap())
        if needs_previous_data {
          skinning_setup_previous_bone_data(skeleton)
        }
        skinning_update_skeleton(skeleton, frame.frame_id)
      })
      |> ignore
      if needs_previous_data {
        let previous_bone_matrices_node = skinning_get_previous_bone_matrices_node(
          builder,
          skinning_skeleton(skinned_mesh),
        )
        let previous_skinned_position = skinning_get_skinned_position(
          previous_bone_matrices_node, position_previous, bind_matrix_node, bind_matrix_inverse_node,
          skin_index_node, skin_weight_node,
        )
        position_previous.assign(previous_skinned_position)
      }
      let skin_position = skinning_get_skinned_position(
        bone_matrices_node, position_local, bind_matrix_node, bind_matrix_inverse_node,
        skin_index_node, skin_weight_node,
      )
      position_local.assign(skin_position)
      if builder.has_geometry_attribute("normal") {
        let (skin_normal, skin_tangent) = skinning_get_skinned_normal_and_tangent(
          bone_matrices_node, normal_local, tangent_local, bind_matrix_node, bind_matrix_inverse_node,
          skin_index_node, skin_weight_node,
        )
        normal_local.assign(skin_normal)
        if builder.has_geometry_attribute("tangent") {
          tangent_local.assign(skin_tangent)
        }
      }
      None
    },
    layout=ReturnType("void"),
  )
})

///|
/// `computeSkinning( skinnedMesh, toPosition = null )`.
pub let compute_skinning : Node = module_nodes(
  "nodes/accessors/Skinning.js:computeSkinning",
  fn() {
    fn_(fn(inputs, builder) {
      let skinned_mesh : @core.Object3D = match inputs.value(0) {
        Js(v) => v.cast()
        _ => abort("computeSkinning: expects a SkinnedMesh")
      }
      let to_position = inputs.get(1)
      let geometry = skinned_mesh.get_geometry().unwrap()
      let position_array = geometry.get_attribute("position").unwrap().array()
      let skin_index_array = geometry
        .get_attribute("skinIndex")
        .unwrap()
        .array()
      let skin_weight_array = geometry
        .get_attribute("skinWeight")
        .unwrap()
        .array()
      let position_node = storage(
          @core.InstancedBufferAttribute::new(position_array, 3),
          type_="vec3",
        )
        .set_pbo(true)
        .to_read_only()
        .element(instance_index)
        .to_var()
      let skin_index_node = storage(
          @core.InstancedBufferAttribute::new(
            @core.TypedArray::uint32(skin_index_array),
            4,
          ),
          type_="uvec4",
        )
        .set_pbo(true)
        .to_read_only()
        .element(instance_index)
        .to_var()
      let skin_weight_node = storage(
          @core.InstancedBufferAttribute::new(skin_weight_array, 4),
          type_="vec4",
        )
        .set_pbo(true)
        .to_read_only()
        .element(instance_index)
        .to_var()
      let mesh = skinning_skinned_mesh(skinned_mesh)
      let bind_matrix_node = uniform(mesh.bind_matrix, type_="mat4")
      let bind_matrix_inverse_node = uniform(
        mesh.bind_matrix_inverse,
        type_="mat4",
      )
      let skeleton = skinning_skeleton(skinned_mesh)
      let bone_matrices_node = BufferMatrices(
        buffer(skeleton.bone_matrices.unwrap(), "mat4", skeleton.bones.length()),
      )
      on_object_update(fn(frame) {
        skinning_update_skeleton(skeleton, frame.frame_id)
      })
      |> ignore
      if builder.needs_previous_data() {
        skinning_setup_previous_bone_data(skeleton)
        let previous_bone_matrices_node = BufferMatrices(
          buffer(
            skeleton.previous_bone_matrices.unwrap(),
            "mat4",
            skeleton.bones.length(),
          ),
        )
        let previous_skinned_position = skinning_get_skinned_position(
          previous_bone_matrices_node, position_previous, bind_matrix_node, bind_matrix_inverse_node,
          skin_index_node, skin_weight_node,
        )
        position_previous.assign(previous_skinned_position)
      }
      let skin_position = skinning_get_skinned_position(
        bone_matrices_node, position_node, bind_matrix_node, bind_matrix_inverse_node,
        skin_index_node, skin_weight_node,
      )
      match to_position {
        Some(p) => p.assign(skin_position)
        None => ()
      }
      if builder.has_geometry_attribute("normal") {
        let (skin_normal, skin_tangent) = skinning_get_skinned_normal_and_tangent(
          bone_matrices_node, normal_local, tangent_local, bind_matrix_node, bind_matrix_inverse_node,
          skin_index_node, skin_weight_node,
        )
        normal_local.assign(skin_normal)
        if builder.has_geometry_attribute("tangent") {
          tangent_local.assign(skin_tangent)
        }
      }
      Some(skin_position)
    })
  },
)
