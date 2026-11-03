// nodes/accessors/Batch.js: `BatchedMesh` transforms, colors and indirect ids read from
// its data textures.

///|
/// `getBatchingColor( colorsTexture, id )`.
let _batch_get_batching_color : Node = module_nodes(
  "nodes/accessors/Batch.js:getBatchingColor",
  fn() {
    fn_(fn(inputs, _) {
      let colors_texture = inputs.value(0)
      let id = inputs.get(1).unwrap()
      let size = int(
        texture_size(texture_load(colors_texture), level_node=0).x(),
      ).to_const()
      let j = int(id)
      let x = j.mod(size).to_const()
      let y = j.div(size).to_const()
      Some(texture_load(colors_texture, uv_node=ivec2_of([x, y])))
    })
  },
)

///|
/// `getIndirectIndex( indirectTexture, id )`.
let _batch_get_indirect_index : Node = module_nodes(
  "nodes/accessors/Batch.js:getIndirectIndex",
  fn() {
    fn_(fn(inputs, _) {
      let indirect_texture = inputs.value(0)
      let id = inputs.get(1).unwrap()
      let size = int(
        texture_size(texture_load(indirect_texture), level_node=0).x(),
      ).to_const()
      let x = int(id).mod(size).to_const()
      let y = int(id).div(size).to_const()
      Some(texture_load(indirect_texture, uv_node=ivec2_of([x, y])).x())
    })
  },
)

///|
/// `createBatchingMatrixNode( matricesTexture, id )`.
fn batch_create_batching_matrix_node(
  matrices_texture : @core.Texture,
  id : Node,
) -> Node {
  let size = int(texture_size(texture_load(matrices_texture), level_node=0).x()).to_const()
  let j = float(id).mul(4).to_int().to_const()
  let x = j.mod(size).to_const()
  let y = j.div(size).to_const()
  mat4_of([
    texture_load(matrices_texture, uv_node=ivec2_of([x, y])),
    texture_load(matrices_texture, uv_node=ivec2_of([x.add(1), y])),
    texture_load(matrices_texture, uv_node=ivec2_of([x.add(2), y])),
    texture_load(matrices_texture, uv_node=ivec2_of([x.add(3), y])),
  ])
}

///|
/// The `BatchedMesh` payload.
fn batch_mesh(object : @core.Object3D) -> @core.BatchedMesh {
  match object.kind {
    Mesh({ kind: BatchedMesh(b), .. }) => b
    _ => abort("TypeError: \{object.type_} is not a BatchedMesh")
  }
}

///|
/// `getPreviousMatricesTexture( batchMesh )`.
fn batch_get_previous_matrices_texture(
  object : @core.Object3D,
) -> @core.Texture {
  let b = batch_mesh(object)
  match b._previous_matrices_texture {
    Some(t) => t
    None => {
      let matrices_texture = b._matrices_texture.unwrap()
      let image = match matrices_texture.image() {
        DataImage(d) => d
        _ => abort("BatchedMesh: matrices texture has no data image")
      }
      let previous_matrices_texture = @core.DataTexture::new(
        data=image.data.unwrap().slice(),
        width=image.width,
        height=image.height,
        format=matrices_texture.format,
        type_=matrices_texture.type_,
      )
      previous_matrices_texture.version = matrices_texture.version
      b._previous_matrices_texture = Some(previous_matrices_texture)
      previous_matrices_texture
    }
  }
}

///|
pub let batch_color : Node = module_nodes(
  "nodes/accessors/Batch.js:batchColor",
  fn() { varying_property("vec4", name="vBatchColor") },
)

///|
pub let batch_indirect_index : Node = module_nodes(
  "nodes/accessors/Batch.js:batchIndirectIndex",
  fn() { varying_property("uint", name="vBatchIndirectId") },
)

///|
/// `batch( batchMesh )`: `batch.call( [ mesh ] )`.
pub let batch : Node = module_nodes("nodes/accessors/Batch.js:batch", fn() {
  fn_(
    fn(inputs, builder) {
      let batch_object : @core.Object3D = match inputs.value(0) {
        Js(v) => v.cast()
        _ => abort("batch: expects a BatchedMesh")
      }
      let b = batch_mesh(batch_object)
      let batching_id_node = if builder.get_draw_index() is None {
        instance_index
      } else {
        draw_index
      }
      let indirect_id = _batch_get_indirect_index.call([
        TslValue::Texture(b._indirect_texture.unwrap()),
        int(batching_id_node),
      ])
      batch_indirect_index.assign(indirect_id)
      let batching_matrix = batch_create_batching_matrix_node(
        b._matrices_texture.unwrap(),
        indirect_id,
      )
      match b._colors_texture {
        Some(colors_texture) => {
          let color = _batch_get_batching_color.call([
            TslValue::Texture(colors_texture),
            indirect_id,
          ])
          batch_color.assign(color)
        }
        None => ()
      }
      let bm = mat3(batching_matrix)
      position_local.assign(batching_matrix.mul(position_local))
      if builder.needs_previous_data() {
        on_after_object_update(fn(frame) {
          let object = frame.object.unwrap()
          let previous_matrices_texture = batch_get_previous_matrices_texture(
            object,
          )
          let matrices_texture = batch_mesh(object)._matrices_texture.unwrap()
          if previous_matrices_texture.version != matrices_texture.version {
            match
              (previous_matrices_texture.image(), matrices_texture.image()) {
              (DataImage(p), DataImage(m)) =>
                p.data.unwrap().set_from(m.data.unwrap())
              _ => ()
            }
            previous_matrices_texture.version = matrices_texture.version
          }
        })
        |> ignore
        let previous_batching_matrix_node = batch_create_batching_matrix_node(
          batch_get_previous_matrices_texture(batch_object),
          indirect_id,
        )
        position_previous.assign(
          previous_batching_matrix_node.mul(position_previous).xyz(),
        )
      }
      let transformed_normal = normal_local.div(
        vec3_of([bm[0].dot(bm[0]), bm[1].dot(bm[1]), bm[2].dot(bm[2])]),
      )
      let batching_normal = bm.mul(transformed_normal).xyz()
      normal_local.assign(batching_normal)
      if builder.has_geometry_attribute("tangent") {
        tangent_local.mul_assign(bm)
      }
      let draw_format = if builder.renderer.backend.has_flag("isWebGPUBackend") {
        "merged"
      } else {
        "multiDraw"
      }
      on_object_update(fn(frame) {
        let object = frame.object.unwrap()
        object._update_draw_parameters(
          frame.camera.unwrap(),
          object.get_geometry().unwrap(),
          frame.material.unwrap(),
          draw_format~,
        )
      })
      |> ignore
      None
    },
    layout=ReturnType("void"),
  )
})
