// Upstream src/renderers/webgl/WebGLShadowMap.js. GROUP 3.

///|
pub(all) struct WebGLShadowMap {
  renderer : WebGLRenderer
  objects : WebGLObjects
  capabilities : WebGLCapabilities
  mut _frustum : @math.Frustum
  _shadow_map_size : @math.Vector2
  _viewport_size : @math.Vector2
  _viewport : @math.Vector4
  _depth_material : @core.Material
  _distance_material : @core.Material
  /// `_materialCache`: key -> source material uuid -> shadow material
  _material_cache : Map[String, Map[String, @core.Material]]
  _max_texture_size : Int32
  /// `shadowSide[ side ]`
  shadow_side : Map[Int32, Int32]
  shadow_material_vertical : @core.Material
  shadow_material_horizontal : @core.Material
  full_screen_tri : @core.BufferGeometry
  full_screen_mesh : @core.Object3D
  mut enabled : Bool
  mut auto_update : Bool
  mut needs_update : Bool
  /// `shadowMap.type`
  mut type_ : Int32
  mut _previous_type : Int32
  /// `onMaterialDispose`, kept so it can be removed
  mut on_material_dispose : (@core.Event) -> Unit
}

///|
let _webgl_shadow_map_cube_directions : Array[@math.Vector3] = [
  @math.Vector3::new(1, 0, 0),
  @math.Vector3::new(-1, 0, 0),
  @math.Vector3::new(0, 1, 0),
  @math.Vector3::new(0, -1, 0),
  @math.Vector3::new(0, 0, 1),
  @math.Vector3::new(0, 0, -1),
]

///|
let _webgl_shadow_map_cube_ups : Array[@math.Vector3] = [
  @math.Vector3::new(0, -1, 0),
  @math.Vector3::new(0, -1, 0),
  @math.Vector3::new(0, 0, 1),
  @math.Vector3::new(0, 0, -1),
  @math.Vector3::new(0, -1, 0),
  @math.Vector3::new(0, -1, 0),
]

///|
let _webgl_shadow_map_proj_screen_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _webgl_shadow_map_light_position_world : @math.Vector3 = @math.Vector3::new(
  0, 0, 0,
)

///|
let _webgl_shadow_map_look_target : @math.Vector3 = @math.Vector3::new(0, 0, 0)

///|
/// `camera.near` of a perspective or orthographic camera.
fn webgl_shadow_map_camera_near(camera : @core.Object3D) -> Double {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => c.near
    OrthographicCamera(c) => c.near
    BaseCamera => abort("WebGLShadowMap: camera without near")
  }
}

///|
/// `camera.far` of a perspective or orthographic camera.
fn webgl_shadow_map_camera_far(camera : @core.Object3D) -> Double {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => c.far
    OrthographicCamera(c) => c.far
    BaseCamera => abort("WebGLShadowMap: camera without far")
  }
}

///|
/// `camera.far = far`.
fn webgl_shadow_map_set_camera_far(
  camera : @core.Object3D,
  far : Double,
) -> Unit {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => c.far = far
    OrthographicCamera(c) => c.far = far
    BaseCamera => abort("WebGLShadowMap: camera without far")
  }
}

///|
/// `( layers.mask & 0xFFFFFFFE ) !== 0`.
extern "js" fn webgl_shadow_map_has_non_default_layers(mask : Double) -> Bool = "(m) => (m & 0xFFFFFFFE) !== 0"

///|
/// `light.isPointLight`.
fn webgl_shadow_map_is_point_light(light : @core.Object3D) -> Bool {
  light.kind is Light({ kind: PointLight(_), .. })
}

///|
/// `new WebGLShadowMap( renderer, objects, capabilities )`.
pub fn WebGLShadowMap::new(
  renderer : WebGLRenderer,
  objects : WebGLObjects,
  capabilities : WebGLCapabilities,
) -> WebGLShadowMap {
  let shadow_material_vertical = @core.ShaderMaterial::new()
  shadow_material_vertical.defines = Some(
    Map([("VSM_SAMPLES", Json::number(8))]),
  )
  shadow_material_vertical.uniforms = Some(
    Map([
      ("shadow_pass", { value: Null, }),
      ("resolution", { value: Vector2(@math.Vector2::new(0, 0)), }),
      ("radius", { value: Number(4.0), }),
    ]),
  )
  shadow_material_vertical.vertex_shader = Some(@shaders.vsm_vertex)
  shadow_material_vertical.fragment_shader = Some(@shaders.vsm_fragment)
  let shadow_material_horizontal = shadow_material_vertical.clone()
  shadow_material_horizontal.defines
  .unwrap()
  .set("HORIZONTAL_PASS", Json::number(1))
  let full_screen_tri = @core.BufferGeometry::new()
  ignore(
    full_screen_tri.set_attribute(
      "position",
      @core.BufferAttribute::new(
        @core.TypedArray::float32([-1.0, -1, 0.5, 3, -1, 0.5, -1, 3, 0.5]),
        3,
      ),
    ),
  )
  let full_screen_mesh = @core.Mesh::new(
    geometry=full_screen_tri,
    material=Single(shadow_material_vertical),
  )
  let shadow_map : WebGLShadowMap = {
    renderer,
    objects,
    capabilities,
    _frustum: @math.Frustum::new(),
    _shadow_map_size: @math.Vector2::new(0, 0),
    _viewport_size: @math.Vector2::new(0, 0),
    _viewport: @math.Vector4::new(0, 0, 0, 0),
    _depth_material: @core.MeshDepthMaterial::new(),
    _distance_material: @core.MeshDistanceMaterial::new(),
    _material_cache: Map([]),
    _max_texture_size: capabilities.max_texture_size,
    shadow_side: Map([
      (@core.FrontSide, @core.BackSide),
      (@core.BackSide, @core.FrontSide),
      (@core.DoubleSide, @core.DoubleSide),
    ]),
    shadow_material_vertical,
    shadow_material_horizontal,
    full_screen_tri,
    full_screen_mesh,
    enabled: false,
    auto_update: true,
    needs_update: false,
    type_: @core.PCFShadowMap,
    _previous_type: @core.PCFShadowMap,
    on_material_dispose: fn(_) {  },
  }
  shadow_map.on_material_dispose = fn(event) {
    shadow_map.on_material_dispose_event(event)
  }
  shadow_map
}

///|
/// `onMaterialDispose( event )`.
fn WebGLShadowMap::on_material_dispose_event(
  self : WebGLShadowMap,
  event : @core.Event,
) -> Unit {
  guard event.target is Some(Material(material)) else { return }
  material.remove_event_listener("dispose", self.on_material_dispose)

  // make sure to remove the unique distance/depth materials used for shadow map rendering
  for _, cache in self._material_cache {
    let uuid = material.uuid
    if cache.get(uuid) is Some(shadow_material) {
      shadow_material.dispose()
      cache.remove(uuid)
    }
  }
}

///|
/// `shadowMap.render( lights, scene, camera )`; `lights` are the shadow-casting lights.
pub fn WebGLShadowMap::render(
  self : WebGLShadowMap,
  lights : Array[@core.Object3D],
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  if self.enabled == false {
    return
  }
  if self.auto_update == false && self.needs_update == false {
    return
  }
  if lights.length() == 0 {
    return
  }
  if self.type_ == @core.PCFSoftShadowMap {
    @core.warn(
      "WebGLShadowMap: PCFSoftShadowMap has been removed. Using PCFShadowMap instead.",
    )
    self.type_ = @core.PCFShadowMap
  }
  let renderer = self.renderer
  let current_render_target = renderer.get_render_target()
  let active_cube_face = renderer.get_active_cube_face()
  let active_mipmap_level = renderer.get_active_mipmap_level()
  let state = renderer.state

  // Set GL state for depth map.
  state.set_blending(@core.NoBlending)
  if state.buffers.depth.get_reversed() {
    state.buffers.color.set_clear(0, 0, 0, 0)
  } else {
    state.buffers.color.set_clear(1, 1, 1, 1)
  }
  state.buffers.depth.set_test(true)
  state.set_scissor_test(false)

  // check for shadow map type changes
  let type_changed = self._previous_type != self.type_

  // When shadow map type changes, materials need recompilation because sampler types change
  // (sampler2DShadow for PCF vs sampler2D for Basic)
  if type_changed {
    scene.traverse(fn(object) {
      match object.get_material() {
        Some(Multiple(materials)) =>
          materials.each(fn(mat) { mat.set_needs_update(true) })
        Some(Single(material)) => material.set_needs_update(true)
        None => ()
      }
    })
  }

  // render depth map
  let shadow_map_size = self._shadow_map_size
  let viewport_size = self._viewport_size
  let max_texture_size = self._max_texture_size.to_double()
  for light in lights {
    let shadow = match light.kind {
      Light({ shadow: Some(shadow), .. }) => shadow
      _ => {
        @core.warn("WebGLShadowMap: " + light.type_ + " has no shadow.")
        continue
      }
    }
    if shadow.auto_update == false && shadow.needs_update == false {
      continue
    }
    ignore(shadow_map_size.copy(shadow.map_size))
    let shadow_frame_extents = shadow.get_frame_extents()
    ignore(shadow_map_size.multiply(shadow_frame_extents))
    ignore(viewport_size.copy(shadow.map_size))
    if shadow_map_size.x > max_texture_size ||
      shadow_map_size.y > max_texture_size {
      if shadow_map_size.x > max_texture_size {
        viewport_size.x = (max_texture_size / shadow_frame_extents.x).floor()
        shadow_map_size.x = viewport_size.x * shadow_frame_extents.x
        shadow.map_size.x = viewport_size.x
      }
      if shadow_map_size.y > max_texture_size {
        viewport_size.y = (max_texture_size / shadow_frame_extents.y).floor()
        shadow_map_size.y = viewport_size.y * shadow_frame_extents.y
        shadow.map_size.y = viewport_size.y
      }
    }
    let reversed_depth_buffer = renderer.state.buffers.depth.get_reversed()
    shadow.camera.as_camera()._reversed_depth = reversed_depth_buffer
    let is_point_light = webgl_shadow_map_is_point_light(light)
    if shadow.map is None || type_changed {
      if shadow.map is Some(map) {
        if map.depth_texture() is Some(depth_texture) {
          depth_texture.dispose()
          map.set_depth_texture(None)
        }
        map.dispose()
      }
      let width = shadow_map_size.x.to_int()
      let height = shadow_map_size.y.to_int()
      if self.type_ == @core.VSMShadowMap {
        if is_point_light {
          @core.warn(
            "WebGLShadowMap: VSM shadow maps are not supported for PointLights. Use PCF or BasicShadowMap instead.",
          )
          continue
        }
        let map = WebGLRenderTarget::new(
          width~,
          height~,
          format=@core.RGFormat,
          type_=@core.HalfFloatType,
          min_filter=@core.LinearFilter,
          mag_filter=@core.LinearFilter,
          generate_mipmaps=false,
        )
        shadow.map = Some(map)
        map.texture().name = light.name + ".shadowMap"

        // Native depth texture for VSM - depth is captured here, then blurred into the color texture
        let depth_texture = @core.DepthTexture::new(
          width~,
          height~,
          type_=@core.FloatType,
        )
        map.set_depth_texture(Some(depth_texture))
        depth_texture.name = light.name + ".shadowMapDepth"
        depth_texture.format = @core.DepthFormat
        depth_texture.compare_function = None // For regular sampling (not shadow comparison)
        depth_texture.min_filter = @core.NearestFilter
        depth_texture.mag_filter = @core.NearestFilter
      } else {
        let (map, depth_texture) = if is_point_light {
          let map = WebGLCubeRenderTarget::new(size=width)
          let depth_texture = @core.CubeDepthTexture::new(
            size=width,
            type_=@core.UnsignedIntType,
          )
          (map, depth_texture)
        } else {
          let map = WebGLRenderTarget::new(width~, height~)
          let depth_texture = @core.DepthTexture::new(
            width~,
            height~,
            type_=@core.UnsignedIntType,
          )
          (map, depth_texture)
        }
        shadow.map = Some(map)
        map.set_depth_texture(Some(depth_texture))
        depth_texture.name = light.name + ".shadowMap"
        depth_texture.format = @core.DepthFormat
        if self.type_ == @core.PCFShadowMap {
          depth_texture.compare_function = Some(
            if reversed_depth_buffer {
              @core.GreaterEqualCompare
            } else {
              @core.LessEqualCompare
            },
          )
          depth_texture.min_filter = @core.LinearFilter
          depth_texture.mag_filter = @core.LinearFilter
        } else {
          depth_texture.compare_function = None
          depth_texture.min_filter = @core.NearestFilter
          depth_texture.mag_filter = @core.NearestFilter
        }
      }
      shadow.camera.update_projection_matrix()
    }
    let map = shadow.map.unwrap()
    let is_cube = map.has_extension_flag("isWebGLCubeRenderTarget")
    if is_cube == false &&
      (
        map.width.to_double() != shadow_map_size.x ||
        map.height.to_double() != shadow_map_size.y
      ) {
      map.set_size(shadow_map_size.x.to_int(), shadow_map_size.y.to_int())
    }

    // For cube render targets (PointLights), render all 6 faces. Sun lights
    // render one atlas viewport per cascade.
    let face_count = if is_cube { 6 } else { shadow.get_viewport_count() }
    // a registered addon `SunLight` overrides the per-cascade `LightShadow` methods
    let sun_shadow = if is_sun_light(light) {
      sun_light_shadow_of(light)
    } else {
      None
    }
    if is_point_light == false {
      match sun_shadow {
        Some(sun_shadow) => sun_shadow.update_matrices(shadow, light, camera)
        None => shadow.update_matrices(light)
      }
    }
    let layers = if webgl_shadow_map_has_non_default_layers(
        shadow.camera.layers.mask,
      ) {
      shadow.camera.layers
    } else {
      camera.layers
    }
    for face in 0..<face_count {
      let shadow_camera = match sun_shadow {
        Some(sun_shadow) => sun_shadow.get_camera(shadow, face)
        None => shadow.get_camera()
      }
      if is_point_light {
        let point_camera = shadow.camera
        let shadow_matrix = shadow.matrix
        let distance = match light.kind {
          Light({ kind: PointLight(point), .. }) => point.distance
          _ => 0.0
        }
        let far = if distance != 0.0 && !distance.is_nan() {
          distance
        } else {
          webgl_shadow_map_camera_far(point_camera)
        }
        if far != webgl_shadow_map_camera_far(point_camera) {
          webgl_shadow_map_set_camera_far(point_camera, far)
          point_camera.update_projection_matrix()
        }
        ignore(
          _webgl_shadow_map_light_position_world.set_from_matrix_position(
            light.matrix_world,
          ),
        )
        ignore(
          point_camera.position.copy(_webgl_shadow_map_light_position_world),
        )
        ignore(_webgl_shadow_map_look_target.copy(point_camera.position))
        ignore(
          _webgl_shadow_map_look_target.add(
            _webgl_shadow_map_cube_directions[face],
          ),
        )
        ignore(point_camera.up.copy(_webgl_shadow_map_cube_ups[face]))
        point_camera.look_at(_webgl_shadow_map_look_target)
        point_camera.update_matrix_world()
        ignore(
          shadow_matrix.make_translation(
            -_webgl_shadow_map_light_position_world.x,
            -_webgl_shadow_map_light_position_world.y,
            -_webgl_shadow_map_light_position_world.z,
          ),
        )
        let camera_data = point_camera.as_camera()
        ignore(
          _webgl_shadow_map_proj_screen_matrix.multiply_matrices(
            camera_data.projection_matrix,
            camera_data.matrix_world_inverse,
          ),
        )
        ignore(
          shadow._frustum.set_from_projection_matrix(
            _webgl_shadow_map_proj_screen_matrix,
            coordinate_system=camera_data.coordinate_system,
            reversed_depth=point_camera.reversed_depth(),
          ),
        )
      }

      // For cube render targets, render to each face separately
      if is_cube {
        renderer.set_render_target(Some(map), active_cube_face=face)
        renderer.clear()
      } else {
        // For 2D render targets, use viewports
        if face == 0 {
          renderer.set_render_target(Some(map))
          renderer.clear()
        }
        let viewport = match sun_shadow {
          Some(sun_shadow) => sun_shadow.get_viewport(shadow, face)
          None => shadow.get_viewport(face)
        }
        ignore(
          self._viewport.set(
            viewport_size.x * viewport.x,
            viewport_size.y * viewport.y,
            viewport_size.x * viewport.z,
            viewport_size.y * viewport.w,
          ),
        )
        state.viewport(self._viewport)
      }
      self._frustum = match sun_shadow {
        Some(sun_shadow) => sun_shadow.get_frustum(shadow, face)
        None => shadow.get_frustum()
      }
      self.render_object(
        scene,
        camera,
        shadow_camera,
        light,
        layers,
        self.type_,
      )
    }

    // do blur pass for VSM
    if !(shadow.kind is PointLightShadow) && self.type_ == @core.VSMShadowMap {
      self.vsm_pass(shadow, camera)
    }
    shadow.needs_update = false
  }
  self._previous_type = self.type_
  self.needs_update = false
  renderer.set_render_target(
    current_render_target,
    active_cube_face~,
    active_mipmap_level~,
  )
}

///|
/// `VSMPass( shadow, camera )`.
fn WebGLShadowMap::vsm_pass(
  self : WebGLShadowMap,
  shadow : @core.LightShadow,
  camera : @core.Object3D,
) -> Unit {
  let renderer = self.renderer
  let geometry = self.objects.update(self.full_screen_mesh)
  let vertical = self.shadow_material_vertical
  let horizontal = self.shadow_material_horizontal
  let blur_samples = Json::number(shadow.blur_samples.to_double())
  if vertical.defines.unwrap().get("VSM_SAMPLES") != Some(blur_samples) {
    vertical.defines.unwrap().set("VSM_SAMPLES", blur_samples)
    horizontal.defines.unwrap().set("VSM_SAMPLES", blur_samples)
    vertical.set_needs_update(true)
    horizontal.set_needs_update(true)
  }
  let map = shadow.map.unwrap()
  let map_pass = match shadow.map_pass {
    None => {
      let map_pass = WebGLRenderTarget::new(
        width=self._shadow_map_size.x.to_int(),
        height=self._shadow_map_size.y.to_int(),
        format=@core.RGFormat,
        type_=@core.HalfFloatType,
      )
      shadow.map_pass = Some(map_pass)
      map_pass
    }
    Some(map_pass) => {
      if map_pass.width != map.width || map_pass.height != map.height {
        map_pass.set_size(map.width, map.height)
      }
      map_pass
    }
  }

  // vertical pass - read from native depth texture
  let vertical_uniforms = vertical.uniforms.unwrap()
  vertical_uniforms.get("shadow_pass").unwrap().value = match
    map.depth_texture() {
    Some(texture) => Texture(texture)
    None => Null
  }
  guard vertical_uniforms.get("resolution").unwrap().value
    is Vector2(resolution) else {
    abort("WebGLShadowMap: resolution")
  }
  ignore(resolution.set(map.width.to_double(), map.height.to_double()))
  vertical_uniforms.get("radius").unwrap().value = Number(shadow.radius)
  renderer.set_render_target(Some(map_pass))
  renderer.clear()
  renderer.render_buffer_direct(
    camera,
    None,
    geometry,
    vertical,
    self.full_screen_mesh,
    None,
  )

  // horizontal pass
  let horizontal_uniforms = horizontal.uniforms.unwrap()
  horizontal_uniforms.get("shadow_pass").unwrap().value = Texture(
    map_pass.texture(),
  )
  guard horizontal_uniforms.get("resolution").unwrap().value
    is Vector2(resolution) else {
    abort("WebGLShadowMap: resolution")
  }
  ignore(resolution.set(map.width.to_double(), map.height.to_double()))
  horizontal_uniforms.get("radius").unwrap().value = Number(shadow.radius)
  renderer.set_render_target(Some(map))
  renderer.clear()
  renderer.render_buffer_direct(
    camera,
    None,
    geometry,
    horizontal,
    self.full_screen_mesh,
    None,
  )
}

///|
/// `getDepthMaterial( object, material, light, type )`.
fn WebGLShadowMap::get_depth_material(
  self : WebGLShadowMap,
  object : @core.Object3D,
  material : @core.Material,
  light : @core.Object3D,
  type_ : Int32,
) -> @core.Material {
  let is_point_light = webgl_shadow_map_is_point_light(light)
  let custom_material = if is_point_light {
    object.custom_distance_material
  } else {
    object.custom_depth_material
  }
  let result = match custom_material {
    Some(custom_material) => custom_material
    None => {
      let result = if is_point_light {
        self._distance_material
      } else {
        self._depth_material
      }
      let alpha_test = material.alpha_test()
      if (
          self.renderer.local_clipping_enabled &&
          material.clip_shadows &&
          material.clipping_planes is Some(planes) &&
          planes.length() != 0
        ) ||
        (
          material.displacement_map is Some(_) &&
          material.displacement_scale != Some(0.0)
        ) ||
        (material.alpha_map is Some(_) && alpha_test > 0.0) ||
        (material.map is Some(_) && alpha_test > 0.0) ||
        material.alpha_to_coverage {
        // in this case we need a unique material instance reflecting the
        // appropriate state
        let key_a = result.uuid
        let key_b = material.uuid
        let materials_for_variant = match self._material_cache.get(key_a) {
          Some(materials) => materials
          None => {
            let materials = Map([])
            self._material_cache.set(key_a, materials)
            materials
          }
        }
        match materials_for_variant.get(key_b) {
          Some(cached_material) => cached_material
          None => {
            let cached_material = result.clone()
            materials_for_variant.set(key_b, cached_material)
            material.add_event_listener("dispose", self.on_material_dispose)
            cached_material
          }
        }
      } else {
        result
      }
    }
  }
  result.visible = material.visible
  result.wireframe = material.wireframe
  if type_ == @core.VSMShadowMap {
    result.side = match material.shadow_side {
      Some(side) => side
      None => material.side
    }
  } else {
    result.side = match material.shadow_side {
      Some(side) => side
      None => self.shadow_side.get(material.side).unwrap()
    }
  }
  result.alpha_map = material.alpha_map
  // approximate alphaToCoverage by using a fixed alphaTest value
  result.set_alpha_test(
    if material.alpha_to_coverage {
      0.5
    } else {
      material.alpha_test()
    },
  )
  result.map = material.map
  result.clip_shadows = material.clip_shadows
  result.clipping_planes = material.clipping_planes
  result.clip_intersection = material.clip_intersection
  result.displacement_map = material.displacement_map
  result.displacement_scale = material.displacement_scale
  result.displacement_bias = material.displacement_bias
  result.wireframe_linewidth = material.wireframe_linewidth
  result.linewidth = material.linewidth
  if is_point_light && result.is_mesh_distance_material() {
    let material_properties = self.renderer.properties.get_material(result)
    material_properties.light = Some(light)
  }
  result
}

///|
/// `renderObject( object, camera, shadowCamera, light, layers, type )`.
fn WebGLShadowMap::render_object(
  self : WebGLShadowMap,
  object : @core.Object3D,
  camera : @core.Object3D,
  shadow_camera : @core.Object3D,
  light : @core.Object3D,
  layers : @core.Layers,
  type_ : Int32,
) -> Unit {
  if object.visible == false {
    return
  }
  let visible = object.layers.test_(layers)
  if visible && (object.is_mesh() || object.is_line() || object.is_points()) {
    if (
        object.cast_shadow ||
        (object.receive_shadow && type_ == @core.VSMShadowMap)
      ) &&
      (
        !object.frustum_culled ||
        object.intersects_frustum(Single(self._frustum))
      ) {
      ignore(
        object.model_view_matrix.multiply_matrices(
          shadow_camera.matrix_world_inverse(),
          object.matrix_world,
        ),
      )
      let geometry = self.objects.update(object)
      let renderer_value = @core.JsValue::of(self.renderer)
      match object.get_material() {
        Some(Multiple(materials)) => {
          let groups = geometry.groups
          for k in 0..<groups.length() {
            let group = groups[k]
            let material_index = group.material_index
            if material_index >= 0 &&
              material_index < materials.length() &&
              materials[material_index].visible {
              let group_material = materials[material_index]
              let depth_material = self.get_depth_material(
                object, group_material, light, type_,
              )
              (object.on_before_shadow)(
                renderer_value,
                object,
                camera,
                shadow_camera,
                geometry,
                depth_material,
                Some(group),
              )
              self.renderer.render_buffer_direct(
                shadow_camera,
                None,
                geometry,
                depth_material,
                object,
                Some(group),
              )
              (object.on_after_shadow)(
                renderer_value,
                object,
                camera,
                shadow_camera,
                geometry,
                depth_material,
                Some(group),
              )
            }
          }
        }
        Some(Single(material)) =>
          if material.visible {
            let depth_material = self.get_depth_material(
              object, material, light, type_,
            )
            (object.on_before_shadow)(
              renderer_value,
              object,
              camera,
              shadow_camera,
              geometry,
              depth_material,
              None,
            )
            self.renderer.render_buffer_direct(
              shadow_camera,
              None,
              geometry,
              depth_material,
              object,
              None,
            )
            (object.on_after_shadow)(
              renderer_value,
              object,
              camera,
              shadow_camera,
              geometry,
              depth_material,
              None,
            )
          }
        None => ()
      }
    }
  }
  let children = object.children
  for i in 0..<children.length() {
    self.render_object(children[i], camera, shadow_camera, light, layers, type_)
  }
}
