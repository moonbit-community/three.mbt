// Upstream examples/jsm/objects/LensflareMesh.js: the lens flare of Lensflare.js for
// WebGPURenderer, with node materials drawn through `renderer.renderObject`. Its
// `LensflareElement` is the one in lensflare.mbt. Properties upstream assigns on its
// materials and element meshes (`material2.scale`, `mesh2.color`, ...) are registered with
// `@nodes.reference_set_instance_property`, where its reference nodes read them.

///|
/// `LensflareMesh.Geometry`, created on first use (upstream: when the module loads).
let _lensflare_mesh_geometry : Ref[@core.BufferGeometry?] = Ref(None)

///|
/// Creates the module-level `LensflareMesh.Geometry`, as importing LensflareMesh.js does.
pub fn load_lensflare_mesh() -> Unit {
  LensflareMesh::geometry() |> ignore
}

///|
/// `LensflareMesh.Geometry`: a quad with interleaved positions and uvs.
pub fn LensflareMesh::geometry() -> @core.BufferGeometry {
  match _lensflare_mesh_geometry.val {
    Some(geometry) => geometry
    None => {
      let geometry = lensflare_quad_geometry()
      _lensflare_mesh_geometry.val = Some(geometry)
      geometry
    }
  }
}

///|
/// `sharedValues`: the plain object the shared `reference` nodes read.
priv struct LensflareMeshSharedValues {
  scale : @math.Vector2
  position_screen : @math.Vector3
}

///|
impl @nodes.ReferenceSource for LensflareMeshSharedValues with fn identity(self) {
  @core.JsValue::of(self)
}

///|
impl @nodes.ReferenceSource for LensflareMeshSharedValues with fn get_property(
  self,
  key,
) {
  match key {
    "scale" => Vector2(self.scale)
    "positionScreen" => Vector3(self.position_screen)
    _ => Undefined
  }
}

///|
/// The state upstream keeps in the constructor's closure.
pub(all) struct LensflareMesh {
  position_view : @math.Vector3
  temp_map : @core.Texture
  occlusion_map : @core.Texture
  mut current_type : Int32
  shared_scale : @math.Vector2
  position_screen : @math.Vector3
  material1a : @core.Material
  material1b : @core.Material
  mesh1 : @core.Object3D
  elements : Array[LensflareElement]
  element_meshes : Array[@core.Object3D]
  material2 : @core.Material
  material2_screen_position : @math.Vector3
  material2_scale : @math.Vector2
  screen_position_pixels : @math.Vector4
  valid_area : @math.Box2
  viewport : @math.Vector4
  lights_node : @nodes.Node
}

///|
pub impl @core.Object3DExtension for LensflareMesh with fn type_name(_) {
  "LensflareMesh"
}

///|
pub impl @core.Object3DExtension for LensflareMesh with fn construct(_) {
  LensflareMesh::new()
}

///|
pub impl @core.Object3DExtension for LensflareMesh with fn has_flag(_, flag) {
  flag == "isLensflareMesh" || flag == "class:LensflareMesh"
}

///|
/// Upstream's instance `dispose`.
pub impl @core.Object3DExtension for LensflareMesh with fn dispose(self, _) {
  self.material1a.dispose()
  self.material1b.dispose()
  self.material2.dispose()
  self.temp_map.dispose()
  self.occlusion_map.dispose()
  for element in self.elements {
    element.texture.dispose()
  }
}

///|
#deprecated
pub extend LensflareMesh with @core.Object3DExtension::{
  type_name,
  construct,
  payload,
  has_flag,
  raycast,
  copy_from,
  to_json,
  update_matrix_world,
  update_world_matrix,
  intersects_frustum,
  get_world_direction,
  dispose,
}

///|
/// The payload of a `LensflareMesh`, or `None` for other objects.
pub fn LensflareMesh::of(object : @core.Object3D) -> LensflareMesh? {
  objects_payload(object, "class:LensflareMesh")
}

///|
/// `addElement( element )`.
pub fn LensflareMesh::add_element(
  object : @core.Object3D,
  element : LensflareElement,
) -> Unit {
  let lensflare : LensflareMesh = objects_require(object, "class:LensflareMesh")
  lensflare.elements.push(element)
}

///|
/// `new LensflareMesh()`: add it to a light and fill it with `add_element`.
pub fn LensflareMesh::new() -> @core.Object3D {
  let geometry = LensflareMesh::geometry()
  let base_material = @nodes.MeshBasicNodeMaterial::new()
  base_material.opacity = 0.0
  base_material.transparent = true
  let object = @core.Mesh::new(geometry~, material=Single(base_material))
  object.frustum_culled = false
  object.render_order = 1.0 / 0.0
  //
  let position_view = @math.Vector3::new(0.0, 0.0, 0.0)
  // textures
  let temp_map = @core.FramebufferTexture::new(width=16, height=16)
  let occlusion_map = @core.FramebufferTexture::new(width=16, height=16)
  // values for shared material uniforms
  let shared_values : LensflareMeshSharedValues = {
    scale: @math.Vector2::new(0.0, 0.0),
    position_screen: @math.Vector3::new(0.0, 0.0, 0.0),
  }
  // materials
  let scale = @nodes.reference("scale", "vec2", object=Custom(shared_values))
  let screen_position = @nodes.reference(
    "positionScreen",
    "vec3",
    object=Custom(shared_values),
  )
  let vertex_node = @nodes.vec4_of([
    @nodes.position_geometry.xy().mul(scale).add(screen_position.xy()),
    screen_position.z(),
    1.0,
  ])
  let material1a = @nodes.NodeMaterial::new()
  material1a.depth_test = true
  material1a.depth_write = false
  material1a.transparent = false
  material1a.fog = Some(false)
  // `material1a.type = 'Lensflare-1a'`: NodeMaterial's `type` setter ignores it
  let nm1a = @nodes.NodeMaterial::of(material1a).unwrap()
  nm1a.vertex_node = Some(vertex_node)
  nm1a.color_node = Some(@nodes.vec4_of([1.0, 0.0, 1.0, 1.0]))
  let material1b = @nodes.NodeMaterial::new()
  material1b.depth_test = false
  material1b.depth_write = false
  material1b.transparent = false
  material1b.fog = Some(false)
  // `material1b.type = 'Lensflare-1b'`: NodeMaterial's `type` setter ignores it
  let nm1b = @nodes.NodeMaterial::of(material1b).unwrap()
  nm1b.vertex_node = Some(vertex_node)
  nm1b.color_node = Some(
    @nodes.texture(temp_map, uv_node=@nodes.vec2(@nodes.uv().flip_y())),
  )
  // the following object is used for occlusionMap generation
  let mesh1 = @core.Mesh::new(geometry~, material=Single(material1a))
  //
  let material2 = @nodes.NodeMaterial::new()
  material2.transparent = true
  material2.blending = @core.AdditiveBlending
  material2.depth_write = false
  material2.depth_test = false
  material2.fog = Some(false)
  // `material2.type = 'Lensflare-2'`: NodeMaterial's `type` setter ignores it
  let material2_screen_position = @math.Vector3::new(0.0, 0.0, 0.0)
  let material2_scale = @math.Vector2::new(0.0, 0.0)
  let material2_identity = @core.JsValue::of(material2)
  @nodes.reference_set_instance_property(material2_identity, "screenPosition", fn() {
    Vector3(material2_screen_position)
  })
  @nodes.reference_set_instance_property(material2_identity, "scale", fn() {
    Vector2(material2_scale)
  })
  @nodes.reference_set_instance_property(material2_identity, "occlusionMap", fn() {
    Texture(occlusion_map)
  })
  let nm2 = @nodes.NodeMaterial::of(material2).unwrap()
  nm2.vertex_node = Some(
    @nodes.fn_(fn(_, _) {
      let scale = @nodes.material_reference("scale", "vec2")
      let screen_position = @nodes.material_reference("screenPosition", "vec3")
      // `material.occlusionMap` of the builder's material, material2
      let occlusion_map = occlusion_map
      let pos = @nodes.position_geometry.xy().to_var()
      let visibility = @nodes.texture_load(
        occlusion_map,
        uv_node=@nodes.ivec2_of([2, 2]),
      ).to_var()
      visibility.add_assign(
        @nodes.texture_load(occlusion_map, uv_node=@nodes.ivec2_of([8, 2])),
      )
      visibility.add_assign(
        @nodes.texture_load(occlusion_map, uv_node=@nodes.ivec2_of([14, 2])),
      )
      visibility.add_assign(
        @nodes.texture_load(occlusion_map, uv_node=@nodes.ivec2_of([14, 8])),
      )
      visibility.add_assign(
        @nodes.texture_load(occlusion_map, uv_node=@nodes.ivec2_of([14, 14])),
      )
      visibility.add_assign(
        @nodes.texture_load(occlusion_map, uv_node=@nodes.ivec2_of([8, 14])),
      )
      visibility.add_assign(
        @nodes.texture_load(occlusion_map, uv_node=@nodes.ivec2_of([2, 14])),
      )
      visibility.add_assign(
        @nodes.texture_load(occlusion_map, uv_node=@nodes.ivec2_of([2, 8])),
      )
      visibility.add_assign(
        @nodes.texture_load(occlusion_map, uv_node=@nodes.ivec2_of([8, 8])),
      )
      let v_visibility = @nodes.varying_property("float", name="vVisibility")
      v_visibility.assign(visibility.r().div(9.0))
      v_visibility.mul_assign(visibility.g().div(9.0).one_minus())
      v_visibility.mul_assign(visibility.b().div(9.0))
      Some(
        @nodes.vec4_of([
          pos.mul(scale).add(screen_position.xy()).xy(),
          screen_position.z(),
          1.0,
        ]),
      )
    }).call([]),
  )
  nm2.color_node = Some(
    @nodes.fn_(fn(_, _) {
      let color = @nodes.reference("color", "color")
      let map = @nodes.reference("map", "texture")
      let v_visibility = @nodes.varying_property("float", name="vVisibility")
      let output = map.to_var()
      output.a().mul_assign(v_visibility)
      output.rgb().mul_assign(color)
      Some(output)
    }).call([]),
  )
  let lensflare : LensflareMesh = {
    position_view,
    temp_map,
    occlusion_map,
    current_type: @core.UnsignedByteType,
    shared_scale: shared_values.scale,
    position_screen: shared_values.position_screen,
    material1a,
    material1b,
    mesh1,
    elements: [],
    element_meshes: [],
    material2,
    material2_screen_position,
    material2_scale,
    screen_position_pixels: @math.Vector4::new(0.0, 0.0, 16.0, 16.0),
    valid_area: @math.Box2::new(),
    viewport: @math.Vector4::new(0.0, 0.0, 0.0, 1.0),
    // dummy node for renderer.renderObject()
    lights_node: @nodes.Node::new(),
  }
  object.set_extension(lensflare) |> ignore
  object.on_before_render = fn(renderer, scene, camera, _, _, _) {
    lensflare.on_before_render(object, renderer.cast(), scene, camera)
  }
  object
}

///|
/// `onBeforeRender( renderer, scene, camera )`.
fn LensflareMesh::on_before_render(
  self : LensflareMesh,
  this : @core.Object3D,
  renderer : @nodes.Renderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  let viewport = self.viewport
  renderer.get_viewport(viewport) |> ignore
  viewport.multiply_scalar(renderer.get_pixel_ratio()).floor() |> ignore
  let type_ = match renderer.get_render_target() {
    Some(render_target) => render_target.texture().type_
    None => @core.UnsignedByteType
  }
  if self.current_type != type_ {
    self.temp_map.dispose()
    self.occlusion_map.dispose()
    self.occlusion_map.type_ = type_
    self.temp_map.type_ = type_
    self.current_type = type_
  }
  let inv_aspect = viewport.w / viewport.z
  let half_viewport_width = viewport.z / 2.0
  let half_viewport_height = viewport.w / 2.0
  let size = 16.0 / viewport.w
  self.shared_scale.set(size * inv_aspect, size) |> ignore
  self.valid_area.min.set(viewport.x, viewport.y) |> ignore
  self.valid_area.max.set(
    viewport.x + (viewport.z - 16.0),
    viewport.y + (viewport.w - 16.0),
  )
  |> ignore
  // calculate position in screen space
  self.position_view.set_from_matrix_position(this.matrix_world) |> ignore
  self.position_view.apply_matrix4(camera.matrix_world_inverse()) |> ignore
  if self.position_view.z > 0.0 {
    return // lensflare is behind the camera
  }
  let position_screen = self.position_screen
  position_screen
  .copy(self.position_view)
  .apply_matrix4(camera.projection_matrix())
  |> ignore
  // horizontal and vertical coordinate of the lower left corner of the pixels to copy
  let pixels = self.screen_position_pixels
  pixels.x = viewport.x +
    position_screen.x * half_viewport_width +
    half_viewport_width -
    8.0
  pixels.y = viewport.y -
    position_screen.y * half_viewport_height +
    half_viewport_height -
    8.0
  // screen cull
  if self.valid_area.contains_point(@math.Vector2::new(pixels.x, pixels.y)) {
    let geometry = LensflareMesh::geometry()
    // save current RGB to temp texture
    renderer.copy_framebuffer_to_texture(self.temp_map, rectangle=pixels)
    // render pink quad
    renderer.render_object(
      self.mesh1,
      scene,
      camera,
      geometry,
      self.material1a,
      None,
      self.lights_node,
      None,
      None,
    )
    // copy result to occlusionMap
    renderer.copy_framebuffer_to_texture(self.occlusion_map, rectangle=pixels)
    // restore graphics
    renderer.render_object(
      self.mesh1,
      scene,
      camera,
      geometry,
      self.material1b,
      None,
      self.lights_node,
      None,
      None,
    )
    // render elements
    let vec_x = -position_screen.x * 2.0
    let vec_y = -position_screen.y * 2.0
    for i, element in self.elements {
      let mesh2 = match self.element_meshes.get(i) {
        Some(mesh2) => mesh2
        None => {
          let mesh2 = @core.Mesh::new(
            geometry~,
            material=Single(self.material2),
          )
          self.element_meshes.push(mesh2)
          let color = element.color.convert_srgb_to_linear()
          let map = element.texture
          let identity = @core.JsValue::of(mesh2)
          @nodes.reference_set_instance_property(identity, "color", fn() {
            Color(color)
          })
          @nodes.reference_set_instance_property(identity, "map", fn() {
            Texture(map)
          })
          mesh2
        }
      }
      self.material2_screen_position.x = position_screen.x +
        vec_x * element.distance
      self.material2_screen_position.y = position_screen.y -
        vec_y * element.distance
      self.material2_screen_position.z = position_screen.z
      let size = element.size / viewport.w
      self.material2_scale.set(size * inv_aspect, size) |> ignore
      renderer.render_object(
        mesh2,
        scene,
        camera,
        geometry,
        self.material2,
        None,
        self.lights_node,
        None,
        None,
      )
    }
  }
}
