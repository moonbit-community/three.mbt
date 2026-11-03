// nodes/accessors/Lights.js: per-light uniforms, created once per light.

///|
/// The uniforms of one light (`getLightData( light )`).
priv struct LightsData {
  mut shadow_matrix : Node?
  mut position : Node?
  mut target_position : Node?
  mut view_position : Node?
  mut view_position_uniform : Node?
}

///|
/// `uniformsLib`.
let _lights_uniforms_lib : @webgl.WeakMap[@core.Object3D, LightsData] = @webgl.WeakMap::new()

///|
/// `getLightData( light )`.
fn lights_get_light_data(light : @core.Object3D) -> LightsData {
  match _lights_uniforms_lib.get(light) {
    Some(d) => d
    None => {
      let d = LightsData::{
        shadow_matrix: None,
        position: None,
        target_position: None,
        view_position: None,
        view_position_uniform: None,
      }
      _lights_uniforms_lib.set(light, d)
      d
    }
  }
}

///|
/// The light payload of an `Object3D`.
fn lights_light(light : @core.Object3D) -> @core.Light {
  match light.kind {
    Light(l) => l
    _ => abort("TypeError: \{light.type_} is not a light")
  }
}

///|
/// `lightShadowMatrix( light )`.
pub fn light_shadow_matrix(light : @core.Object3D) -> Node {
  let data = lights_get_light_data(light)
  match data.shadow_matrix {
    Some(n) => n
    None => {
      let n = uniform("mat4")
        .set_group(render_group)
        .on_render_update(fn(self_, frame) {
          let shadow = lights_light(light).shadow.unwrap()
          if !light.cast_shadow || !frame.renderer.unwrap().shadow_map.enabled {
            let camera = frame.camera.unwrap()
            let shadow_camera = camera_data(shadow.camera)
            let coordinate_system = camera_data(camera).coordinate_system
            if shadow_camera.coordinate_system != coordinate_system {
              shadow_camera.coordinate_system = coordinate_system
              shadow.camera.update_projection_matrix()
            }
            shadow.update_matrices(light)
          }
          InputNode::set_value(self_, Matrix4(shadow.matrix))
          None
        })
      data.shadow_matrix = Some(n)
      n
    }
  }
}

///|
/// `lightProjectionUV( light, position = positionWorld )`.
pub fn light_projection_uv(light : @core.Object3D, position? : Node) -> Node {
  let position = position.unwrap_or(position_world)
  let spot_light_coord = light_shadow_matrix(light).mul(position)
  let projection_uv = spot_light_coord.xyz().div(spot_light_coord.w())
  projection_uv
}

///|
/// `lightPosition( light )`.
pub fn light_position(light : @core.Object3D) -> Node {
  let data = lights_get_light_data(light)
  match data.position {
    Some(n) => n
    None => {
      let n = uniform(@math.Vector3::new(0.0, 0.0, 0.0))
        .set_group(render_group)
        .on_render_update(fn(self_, _) {
          match InputNode::get_value(self_) {
            Vector3(v) =>
              v.set_from_matrix_position(light.matrix_world) |> ignore
            _ => ()
          }
          None
        })
      data.position = Some(n)
      n
    }
  }
}

///|
/// `light.target` of directional and spot lights.
fn lights_target(light : @core.Object3D) -> @core.Object3D {
  match lights_light(light).kind {
    DirectionalLight(d) => d.target
    SpotLight(s) => s.target
    _ => abort("TypeError: Cannot read properties of undefined (target)")
  }
}

///|
/// `lightTargetPosition( light )`.
pub fn light_target_position(light : @core.Object3D) -> Node {
  let data = lights_get_light_data(light)
  match data.target_position {
    Some(n) => n
    None => {
      let n = uniform(@math.Vector3::new(0.0, 0.0, 0.0))
        .set_group(render_group)
        .on_render_update(fn(self_, _) {
          match InputNode::get_value(self_) {
            Vector3(v) =>
              v.set_from_matrix_position(lights_target(light).matrix_world)
              |> ignore
            _ => ()
          }
          None
        })
      data.target_position = Some(n)
      n
    }
  }
}

///|
/// `lightViewPosition( light )`.
pub fn light_view_position(light : @core.Object3D) -> Node {
  let data = lights_get_light_data(light)
  match data.view_position {
    Some(n) => n
    None => {
      let n = fn_(fn(_, builder) {
          let camera = builder.camera.unwrap()
          if camera.is_array_camera() && camera_sub_cameras(camera).length() > 0 {
            return Some(
              camera_view_matrix.mul(vec4_of([light_position(light), 1])).xyz(),
            )
          }
          match data.view_position_uniform {
            Some(u) => Some(u)
            None => {
              let u = uniform(@math.Vector3::new(0.0, 0.0, 0.0))
                .set_group(render_group)
                .on_render_update(fn(self_, frame) {
                  let v = match InputNode::get_value(self_) {
                    Vector3(v) => v
                    _ => {
                      let v = @math.Vector3::new(0.0, 0.0, 0.0)
                      InputNode::set_value(self_, Vector3(v))
                      v
                    }
                  }
                  v.set_from_matrix_position(light.matrix_world) |> ignore
                  v.apply_matrix4(
                    camera_data(frame.camera.unwrap()).matrix_world_inverse,
                  )
                  |> ignore
                  None
                })
              data.view_position_uniform = Some(u)
              Some(u)
            }
          }
        })
        .once()
        .call([])
      data.view_position = Some(n)
      n
    }
  }
}

///|
/// `lightTargetDirection( light )`.
pub fn light_target_direction(light : @core.Object3D) -> Node {
  camera_view_matrix.transform_direction(
    light_position(light).sub(light_target_position(light)),
  )
}
