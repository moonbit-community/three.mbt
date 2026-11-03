// nodes/accessors/SceneProperties.js

///|
let _scene_properties_m1 : @math.Matrix4 = @math.Matrix4::new()

///|
pub let background_blurriness : Node = module_nodes(
  "nodes/accessors/SceneProperties.js:backgroundBlurriness",
  fn() {
    uniform(0)
    .set_group(render_group)
    .on_render_update(fn(self_, frame) {
      InputNode::set_value(
        self_,
        Number(scene_data(frame.scene.unwrap()).background_blurriness),
      )
      None
    })
  },
)

///|
pub let background_intensity : Node = module_nodes(
  "nodes/accessors/SceneProperties.js:backgroundIntensity",
  fn() {
    uniform(1)
    .set_group(render_group)
    .on_render_update(fn(self_, frame) {
      InputNode::set_value(
        self_,
        Number(scene_data(frame.scene.unwrap()).background_intensity),
      )
      None
    })
  },
)

///|
pub let background_rotation : Node = module_nodes(
  "nodes/accessors/SceneProperties.js:backgroundRotation",
  fn() {
    uniform(@math.Matrix4::new())
    .set_group(render_group)
    .on_render_update(fn(self_, frame) {
      let scene = scene_data(frame.scene.unwrap())
      let background_is_texture = match scene.background {
        Some(Texture(t)) => t.mapping != @core.UVMapping
        _ => false
      }
      if background_is_texture ||
        material_properties_is_node(scene.background_node) {
        _scene_properties_m1
        .make_rotation_from_euler(scene.background_rotation)
        .transpose()
        |> ignore
      } else {
        _scene_properties_m1.identity() |> ignore
      }
      InputNode::set_value(self_, Matrix4(_scene_properties_m1))
      None
    })
  },
)
