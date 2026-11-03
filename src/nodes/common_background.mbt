// renderers/common/Background.js: the clear values of a render, and the sky sphere
// of node backgrounds.

///|
let _background_clear_color : Color4 = Color4::new()

///|
/// The record of a scene in `Background`.
pub(all) struct BackgroundSceneData {
  mut background_mesh : @core.Object3D?
  /// The `ContextNode` the sphere's material outputs.
  mut background_mesh_node : Node?
  mut background_cache_key : Double?
}

///|
/// Clears with the background color or draws the background sphere.
pub struct Background {
  renderer : Renderer
  nodes : NodeManager
  priv data : DataMap[@core.Object3D, BackgroundSceneData]
}

///|
/// `new Background( renderer, nodes )`.
pub fn Background::new(renderer : Renderer, nodes : NodeManager) -> Background {
  {
    renderer,
    nodes,
    data: DataMap::new(fn() {
      {
        background_mesh: None,
        background_mesh_node: None,
        background_cache_key: None,
      }
    }),
  }
}

///|
/// `get( scene )`.
pub fn Background::get(
  self : Background,
  scene : @core.Object3D,
) -> BackgroundSceneData {
  self.data.get(scene)
}

///|
/// `update( scene, renderList, renderContext )`: sets the render context's clear
/// values and adds the background mesh of a node background to the render list.
pub fn Background::update(
  self : Background,
  scene : @core.Object3D,
  render_list : RenderList,
  render_context : RenderContext,
) -> Unit {
  let renderer = self.renderer
  let scene_background = match scene.kind {
    Scene(s) => s.background
    _ => None
  }
  let mut force_clear = false
  match self.nodes.get_background_node(scene) {
    Some(background_node) => {
      let scene_data = self.get(scene)
      _background_clear_color.copy(renderer._clear_color) |> ignore
      let background_mesh = match scene_data.background_mesh {
        Some(m) => m
        None => {
          let background_mesh_node = vec4(background_node)
            .mul(background_intensity)
            .context(
              value=node_context([
                // @TODO: Add Texture2D support using node context
                (
                  "getUV",
                  Other(
                    @core.JsValue::of(ContextGetUV::{
                      f: fn(_, _) {
                        background_rotation.mul(normal_world_geometry)
                      },
                    }),
                  ),
                ),
                (
                  "getTextureLevel",
                  Other(
                    @core.JsValue::of(ContextGetTextureLevel::{
                      f: fn(_) { background_blurriness },
                    }),
                  ),
                ),
              ]),
            )
          // when using orthographic cameras, we must scale the skybox sphere
          // up to exceed the dimensions of the camera's viewing box.
          let is_ortho = camera_projection_matrix
            .element(3)
            .element(3)
            .equal(1.0)
          // calculate the orthographic scale
          let ortho_scale = div(
            1.0,
            camera_projection_matrix.element(1).element(1),
          ).mul(3.0)
          // compute vertex position
          let modified_position = is_ortho.select(
            position_local.mul(ortho_scale),
            else_node=position_local,
          )
          // by using a w component of 0, the skybox will not translate when the camera moves through the scene
          let view_position = model_view_matrix.mul(
            vec4_of([modified_position, 0.0]),
          )
          // we force w=1.0 here to prevent the w_clip=0 divide-by-zero error for ortho cameras.
          let mut view_proj = camera_projection_matrix.mul(
            vec4_of([view_position.xyz(), 1.0]),
          )
          // force background to far plane so it does not occlude objects
          view_proj = view_proj.set_z(view_proj.w())
          let node_material = NodeMaterial::new()
          node_material.name = "Background.material"
          node_material.side = @core.BackSide
          node_material.depth_test = false
          node_material.depth_write = false
          node_material.allow_override = false
          node_material.fog = Some(false)
          node_material.lights = Some(false)
          let payload = NodeMaterial::of(node_material).unwrap()
          payload.vertex_node = Some(view_proj)
          payload.color_node = Some(background_mesh_node)
          scene_data.background_mesh_node = Some(background_mesh_node)
          let mesh = @core.Mesh::new(
            geometry=@geometries.SphereGeometry::new(
              radius=1.0,
              width_segments=32.0,
              height_segments=32.0,
            ),
            material=Single(node_material),
          )
          scene_data.background_mesh = Some(mesh)
          mesh.frustum_culled = false
          mesh.name = "Background.mesh"
          let on_background_dispose : Ref[(@core.Event) -> Unit] = Ref(fn(_) {

          })
          on_background_dispose.val = fn(_) {
            background_node.remove_event_listener(
              "dispose",
              on_background_dispose.val,
            )
            node_material.dispose()
            mesh.get_geometry().unwrap().dispose()
          }
          background_node.add_event_listener(
            "dispose",
            on_background_dispose.val,
          )
          mesh
        }
      }
      let background_cache_key = background_node.get_cache_key()
      if scene_data.background_cache_key != Some(background_cache_key) {
        let mesh_node = scene_data.background_mesh_node.unwrap()
        ContextNode::of(mesh_node).unwrap().node = Some(
          vec4(background_node).mul(background_intensity),
        )
        mesh_node.set_needs_update(true)
        match background_mesh.get_material() {
          Some(Single(m)) => m.set_needs_update(true)
          _ => ()
        }
        scene_data.background_cache_key = Some(background_cache_key)
      }
      let material = match background_mesh.get_material() {
        Some(Single(m)) => m
        _ => abort("Background: the mesh has no material")
      }
      render_list.unshift(
        background_mesh,
        background_mesh.get_geometry().unwrap(),
        material,
        0,
        0.0,
        None,
        None,
      )
    }
    None =>
      match scene_background {
        None => {
          // no background settings, use clear color configuration from the renderer
          renderer._clear_color.color.get_rgb(_background_clear_color.color)
          |> ignore
          _background_clear_color.a = renderer._clear_color.a
        }
        Some(Color(background)) => {
          // background is an opaque color
          background.get_rgb(_background_clear_color.color) |> ignore
          _background_clear_color.a = 1.0
          force_clear = true
        }
        Some(Texture(_)) =>
          @core.error("Renderer: Unsupported background configuration.")
      }
  }
  //
  let environment_blend_mode = renderer.xr.get_environment_blend_mode()
  if environment_blend_mode == Some("additive") {
    _background_clear_color.set(0.0, 0.0, 0.0, a=1.0) |> ignore
  } else if environment_blend_mode == Some("alpha-blend") {
    _background_clear_color.set(0.0, 0.0, 0.0, a=0.0) |> ignore
  }
  //
  if renderer.auto_clear == true || force_clear == true {
    let clear_color_value = render_context.clear_color_value
    clear_color_value.r = _background_clear_color.color.r
    clear_color_value.g = _background_clear_color.color.g
    clear_color_value.b = _background_clear_color.color.b
    clear_color_value.a = _background_clear_color.a
    // premultiply alpha
    if renderer.backend.has_flag("isWebGLBackend") || renderer.alpha == true {
      clear_color_value.r *= clear_color_value.a
      clear_color_value.g *= clear_color_value.a
      clear_color_value.b *= clear_color_value.a
    }
    // upstream also writes `depthClearValue` and `stencilClearValue`, which no
    // backend reads (they read `clearDepthValue` / `clearStencilValue`)
    render_context.clear_color = renderer.auto_clear_color == true
    render_context.clear_depth = renderer.auto_clear_depth == true
    render_context.clear_stencil = renderer.auto_clear_stencil == true
  } else {
    render_context.clear_color = false
    render_context.clear_depth = false
    render_context.clear_stencil = false
  }
}
