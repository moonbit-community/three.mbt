// nodes/accessors/MaterialProperties.js

///|
let _material_properties_m1 : @math.Matrix4 = @math.Matrix4::new()

///|
/// `state.material` of a build or a frame, as an update reference.
fn material_properties_reference(state : NodeUpdateState) -> @core.JsValue {
  let material = match state {
    Builder(b) => b.material
    Frame(f) => f.material
  }
  match material {
    Some(m) => @core.JsValue::of(m)
    None => @core.JsValue::undefined()
  }
}

///|
/// The scene payload of an `Object3D`.
pub fn scene_data(scene : @core.Object3D) -> @core.Scene {
  match scene.kind {
    Scene(s) => s
    _ => abort("TypeError: \{scene.type_} is not a scene")
  }
}

///|
/// `node && node.isNode` for a scene's dynamic node property.
fn material_properties_is_node(value : @core.JsValue?) -> Bool {
  match value {
    Some(v) => !v.is_undefined() && !v.is_null()
    None => false
  }
}

///|
/// `materialRefractionRatio`.
pub let material_refraction_ratio : Node = module_nodes(
  "nodes/accessors/MaterialProperties.js:materialRefractionRatio",
  fn() {
    uniform(0)
    .on_reference(fn(_, state) { material_properties_reference(state) })
    .on_object_update(fn(self_, frame) {
      match frame.material.unwrap().refraction_ratio {
        Some(r) => InputNode::set_value(self_, Number(r))
        None => ()
      }
      None
    })
  },
)

///|
/// `materialEnvIntensity`.
pub let material_env_intensity : Node = module_nodes(
  "nodes/accessors/MaterialProperties.js:materialEnvIntensity",
  fn() {
    uniform(1)
    .on_reference(fn(_, state) { material_properties_reference(state) })
    .on_object_update(fn(self_, frame) {
      let material = frame.material.unwrap()
      let value = if material.env_map is Some(_) {
        material.env_map_intensity
      } else {
        Some(scene_data(frame.scene.unwrap()).environment_intensity)
      }
      match value {
        Some(v) => InputNode::set_value(self_, Number(v))
        None => ()
      }
      None
    })
  },
)

///|
/// `materialEnvRotation`.
pub let material_env_rotation : Node = module_nodes(
  "nodes/accessors/MaterialProperties.js:materialEnvRotation",
  fn() {
    uniform(@math.Matrix4::new())
    .on_reference(fn(_, state) { material_properties_reference(state) })
    .on_object_update(fn(self_, frame) {
      let material = frame.material.unwrap()
      let scene = scene_data(frame.scene.unwrap())
      let has_scene_environment = scene.environment is Some(_) ||
        material_properties_is_node(scene.environment_node)
      let rotation = if has_scene_environment && material.env_map is None {
        Some(scene.environment_rotation)
      } else {
        material.env_map_rotation
      }
      match rotation {
        Some(r) =>
          _material_properties_m1.make_rotation_from_euler(r).transpose()
          |> ignore
        None => _material_properties_m1.identity() |> ignore
      }
      InputNode::set_value(self_, Matrix4(_material_properties_m1))
      None
    })
  },
)
