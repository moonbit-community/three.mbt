// Upstream src/renderers/webgl/WebGLBackground.js. GROUP 3.
//
// Upstream adds `envMap` / `map` getters to the background materials that read the
// `envMap` / `t2D` uniforms. Here the material fields are assigned together with the
// uniforms, which keeps them equal.

///|
pub struct WebGLBackground {
  renderer : WebGLRenderer
  environments : WebGLEnvironments
  state : WebGLState
  objects : WebGLObjects
  alpha : Bool
  premultiplied_alpha : Bool
  clear_color : @math.Color
  mut clear_alpha : Double
  mut plane_mesh : @core.Object3D?
  mut box_mesh : @core.Object3D?
  /// compared by identity of the color or texture inside
  mut current_background : @core.SceneBackground?
  mut current_background_version : Int32
  mut current_tonemapping : Int32?
}

///|
/// `new WebGLBackground( renderer, environments, state, objects, alpha,
/// premultipliedAlpha )`.
pub fn WebGLBackground::new(
  renderer : WebGLRenderer,
  environments : WebGLEnvironments,
  state : WebGLState,
  objects : WebGLObjects,
  alpha : Bool,
  premultiplied_alpha : Bool,
) -> WebGLBackground {
  {
    renderer,
    environments,
    state,
    objects,
    alpha,
    premultiplied_alpha,
    clear_color: @math.Color::new(0, 0, 0),
    clear_alpha: if alpha {
      0
    } else {
      1
    },
    plane_mesh: None,
    box_mesh: None,
    current_background: None,
    current_background_version: 0,
    current_tonemapping: None,
  }
}

///|
/// `background.getClearColor()`.
pub fn WebGLBackground::get_clear_color(self : WebGLBackground) -> @math.Color {
  self.clear_color
}

///|
let _webgl_background_rgb : @math.Color = @math.Color::new(0, 0, 0)

///|
let _webgl_background_m1 : @math.Matrix4 = @math.Matrix4::new()

///|
let _webgl_background_m : @math.Matrix3 = @math.Matrix3::new().set(
  -1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0,
)

///|
/// `renderer.xr.getEnvironmentBlendMode()`: the session's blend mode, `undefined`
/// without a session.
fn webgl_background_environment_blend_mode(xr : WebXRManager) -> String? {
  xr.get_environment_blend_mode()
}

///|
/// The single material of a background mesh.
fn webgl_background_mesh_material(mesh : @core.Object3D) -> @core.Material {
  guard mesh.get_material() is Some(Single(material)) else {
    abort("WebGLBackground: mesh without material")
  }
  material
}

///|
/// The geometry of a background mesh.
fn webgl_background_mesh_geometry(
  mesh : @core.Object3D,
) -> @core.BufferGeometry {
  guard mesh.get_geometry() is Some(geometry) else {
    abort("WebGLBackground: mesh without geometry")
  }
  geometry
}

///|
/// `material.uniforms[ name ]`.
fn webgl_background_uniform(
  material : @core.Material,
  name : String,
) -> @core.Uniform {
  guard material.uniforms is Some(uniforms) &&
    uniforms.get(name) is Some(uniform) else {
    abort("WebGLBackground: missing uniform " + name)
  }
  uniform
}

///|
/// `uniforms[ name ].value` as a `Matrix3`.
fn webgl_background_matrix3(
  material : @core.Material,
  name : String,
) -> @math.Matrix3 {
  guard webgl_background_uniform(material, name).value is Matrix3(m) else {
    abort("WebGLBackground: uniform " + name + " is not a Matrix3")
  }
  m
}

///|
/// A background `ShaderMaterial`.
fn webgl_background_material(
  name : String,
  shader : String,
  side : Int32,
) -> @core.Material {
  guard @shaders.shader_lib.get(shader) is Some(entry) else {
    abort("WebGLBackground: no ShaderLib." + shader)
  }
  let material = @core.ShaderMaterial::new()
  material.name = name
  material.uniforms = Some(@core.clone_uniforms(entry.uniforms))
  material.vertex_shader = Some(entry.vertex_shader)
  material.fragment_shader = Some(entry.fragment_shader)
  material.side = side
  material.depth_test = false
  material.depth_write = false
  material.fog = Some(false)
  material.allow_override = false
  material
}

///|
/// `getBackground( scene )`.
fn WebGLBackground::get_background(
  self : WebGLBackground,
  scene : @core.Object3D,
) -> @core.SceneBackground? {
  guard scene.kind is Scene(scene_data) else { return None }
  match scene_data.background {
    Some(Texture(texture)) => {
      let use_pmrem = scene_data.background_blurriness > 0.0 // use PMREM if the user wants to blur the background
      match self.environments.get(Some(texture), use_pmrem~) {
        Some(texture) => Some(Texture(texture))
        None => None
      }
    }
    background => background
  }
}

///|
/// `setClear( color, alpha )`.
fn WebGLBackground::set_clear(
  self : WebGLBackground,
  color : @math.Color,
  alpha : Double,
) -> Unit {
  let color_space = @core.get_unlit_uniform_color_space(
    self.renderer.get_render_target(),
    self.renderer.output_color_space(),
  )
  ignore(color.get_rgb(_webgl_background_rgb, color_space~))
  self.state.buffers.color.set_clear(
    _webgl_background_rgb.r,
    _webgl_background_rgb.g,
    _webgl_background_rgb.b,
    alpha,
    premultiplied_alpha=self.premultiplied_alpha,
  )
}

///|
/// `background.setClearColor( color, alpha )`.
pub fn WebGLBackground::set_clear_color(
  self : WebGLBackground,
  color : @math.Color,
  alpha~ : Double = 1,
) -> Unit {
  ignore(self.clear_color.copy(color))
  self.clear_alpha = alpha
  self.set_clear(self.clear_color, self.clear_alpha)
}

///|
/// `background.setClearColor( hex, alpha )`.
pub fn WebGLBackground::set_clear_color_hex(
  self : WebGLBackground,
  hex : Int32,
  alpha~ : Double = 1,
) -> Unit {
  ignore(self.clear_color.set_hex(hex))
  self.clear_alpha = alpha
  self.set_clear(self.clear_color, self.clear_alpha)
}

///|
/// `background.getClearAlpha()`.
pub fn WebGLBackground::get_clear_alpha(self : WebGLBackground) -> Double {
  self.clear_alpha
}

///|
/// `background.setClearAlpha( alpha )`.
pub fn WebGLBackground::set_clear_alpha(
  self : WebGLBackground,
  alpha : Double,
) -> Unit {
  self.clear_alpha = alpha
  self.set_clear(self.clear_color, self.clear_alpha)
}

///|
/// `background.render( scene )`.
pub fn WebGLBackground::render(
  self : WebGLBackground,
  scene : @core.Object3D,
) -> Unit {
  let mut force_clear = false
  let background = self.get_background(scene)
  match background {
    None => self.set_clear(self.clear_color, self.clear_alpha)
    Some(Color(color)) => {
      self.set_clear(color, 1)
      force_clear = true
    }
    Some(Texture(_)) => ()
  }
  let environment_blend_mode = webgl_background_environment_blend_mode(
    self.renderer.xr,
  )
  if environment_blend_mode == Some("additive") {
    self.state.buffers.color.set_clear(
      0,
      0,
      0,
      1,
      premultiplied_alpha=self.premultiplied_alpha,
    )
  } else if environment_blend_mode == Some("alpha-blend") {
    self.state.buffers.color.set_clear(
      0,
      0,
      0,
      0,
      premultiplied_alpha=self.premultiplied_alpha,
    )
  }
  let renderer = self.renderer
  if renderer.auto_clear || force_clear {
    // buffers might not be writable which is required to ensure a correct clear
    self.state.buffers.depth.set_test(true)
    self.state.buffers.depth.set_mask(true)
    self.state.buffers.color.set_mask(true)
    renderer.clear(
      color=renderer.auto_clear_color,
      depth=renderer.auto_clear_depth,
      stencil=renderer.auto_clear_stencil,
    )
  }
}

///|
/// Whether the cached background differs from `background`, recording it if so.
fn WebGLBackground::background_changed(
  self : WebGLBackground,
  background : @core.Texture,
) -> Bool {
  let same = match self.current_background {
    Some(Texture(current)) => physical_equal(current, background)
    _ => false
  }
  if !same ||
    self.current_background_version != background.version ||
    self.current_tonemapping != Some(self.renderer.tone_mapping) {
    self.current_background = Some(Texture(background))
    self.current_background_version = background.version
    self.current_tonemapping = Some(self.renderer.tone_mapping)
    true
  } else {
    false
  }
}

///|
/// `background.addToRenderList( renderList, scene )`.
pub fn WebGLBackground::add_to_render_list(
  self : WebGLBackground,
  render_list : WebGLRenderList,
  scene : @core.Object3D,
) -> Unit {
  let background = self.get_background(scene)
  guard background is Some(Texture(background)) else { return }
  let scene_data = scene.as_scene()
  if background.is_cube_texture() {
    let box_mesh = match self.box_mesh {
      Some(box_mesh) => box_mesh
      None => {
        let box_mesh = @core.Mesh::new(
          geometry=@geometries.BoxGeometry::new(width=1, height=1, depth=1),
          material=Single(
            webgl_background_material(
              "BackgroundCubeMaterial",
              "backgroundCube",
              @core.BackSide,
            ),
          ),
        )
        let geometry = webgl_background_mesh_geometry(box_mesh)
        ignore(geometry.delete_attribute("normal"))
        ignore(geometry.delete_attribute("uv"))
        box_mesh.on_before_render = fn(_, _, camera, _, _, _) {
          ignore(box_mesh.matrix_world.copy_position(camera.matrix_world))
        }
        ignore(self.objects.update(box_mesh))
        self.box_mesh = Some(box_mesh)
        box_mesh
      }
    }
    let material = webgl_background_mesh_material(box_mesh)
    webgl_background_uniform(material, "envMap").value = Texture(background)
    material.env_map = Some(background)
    webgl_background_uniform(material, "backgroundBlurriness").value = Number(
      scene_data.background_blurriness,
    )
    webgl_background_uniform(material, "backgroundIntensity").value = Number(
      scene_data.background_intensity,
    )

    // note: since the matrix is orthonormal, we can use the more-efficient transpose() in lieu of invert()
    let rotation = webgl_background_matrix3(material, "backgroundRotation")
    ignore(
      rotation
      .set_from_matrix4(
        _webgl_background_m1.make_rotation_from_euler(
          scene_data.background_rotation,
        ),
      )
      .transpose(),
    )
    if background.is_render_target_texture == false {
      ignore(rotation.premultiply(_webgl_background_m))
    }
    material.tone_mapped = @math.color_management.get_transfer(
        background.color_space,
      ) !=
      @core.SRGBTransfer
    if self.background_changed(background) {
      material.set_needs_update(true)
    }
    box_mesh.layers.enable_all()

    // push to the pre-sorted opaque render list
    render_list.unshift(
      box_mesh,
      webgl_background_mesh_geometry(box_mesh),
      material,
      0,
      0,
      None,
    )
  } else {
    let plane_mesh = match self.plane_mesh {
      Some(plane_mesh) => plane_mesh
      None => {
        let plane_mesh = @core.Mesh::new(
          geometry=@geometries.PlaneGeometry::new(width=2, height=2),
          material=Single(
            webgl_background_material(
              "BackgroundMaterial",
              "background",
              @core.FrontSide,
            ),
          ),
        )
        ignore(
          webgl_background_mesh_geometry(plane_mesh).delete_attribute("normal"),
        )
        ignore(self.objects.update(plane_mesh))
        self.plane_mesh = Some(plane_mesh)
        plane_mesh
      }
    }
    let material = webgl_background_mesh_material(plane_mesh)
    webgl_background_uniform(material, "t2D").value = Texture(background)
    material.map = Some(background)
    webgl_background_uniform(material, "backgroundIntensity").value = Number(
      scene_data.background_intensity,
    )
    material.tone_mapped = @math.color_management.get_transfer(
        background.color_space,
      ) !=
      @core.SRGBTransfer
    if background.matrix_auto_update {
      background.update_matrix()
    }
    ignore(
      webgl_background_matrix3(material, "uvTransform").copy(background.matrix),
    )
    if self.background_changed(background) {
      material.set_needs_update(true)
    }
    plane_mesh.layers.enable_all()

    // push to the pre-sorted opaque render list
    render_list.unshift(
      plane_mesh,
      webgl_background_mesh_geometry(plane_mesh),
      material,
      0,
      0,
      None,
    )
  }
}

///|
/// `background.dispose()`.
pub fn WebGLBackground::dispose(self : WebGLBackground) -> Unit {
  if self.box_mesh is Some(box_mesh) {
    webgl_background_mesh_geometry(box_mesh).dispose()
    webgl_background_mesh_material(box_mesh).dispose()
    self.box_mesh = None
  }
  if self.plane_mesh is Some(plane_mesh) {
    webgl_background_mesh_geometry(plane_mesh).dispose()
    webgl_background_mesh_material(plane_mesh).dispose()
    self.plane_mesh = None
  }
}
