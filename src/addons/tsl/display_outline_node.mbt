// examples/jsm/tsl/display/OutlineNode.js

///|
extern "js" fn outline_node_math_round(x : Double) -> Double = "Math.round"

///|
/// The module's top-level `_quadMesh`.
priv struct OutlineNodeModule {
  _quad_mesh : @nodes.QuadMesh
}

///|
let _outline_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _outline_node_blur_direction_x : @math.Vector2 = @math.Vector2::new(
  1.0, 0.0,
)

///|
let _outline_node_blur_direction_y : @math.Vector2 = @math.Vector2::new(
  0.0, 1.0,
)

///|
let _outline_node_renderer_state : Ref[@nodes.RendererState?] = Ref(None)

///|
let display_outline_node_module : AddonModule[OutlineNodeModule] = AddonModule::new(fn() {
    { _quad_mesh: @nodes.QuadMesh::new(), }
  },
)

///|
/// Evaluates OutlineNode.js (its `_quadMesh`), as `import` does.
pub fn load_display_outline_node() -> Unit {
  display_outline_node_module.get() |> ignore
}

///|
/// Post processing node for rendering outlines around selected objects (`r`: visible
/// edges, `g`: hidden edges).
pub(all) struct OutlineNode {
  mut scene : @core.Object3D
  mut camera : @core.Object3D
  mut selected_objects : Array[@core.Object3D]
  mut edge_thickness_node : @nodes.Node
  mut edge_glow_node : @nodes.Node
  mut down_sample_ratio : Double
  // render targets
  _render_target_depth_buffer : @core.RenderTarget
  _render_target_mask_buffer : @core.RenderTarget
  _render_target_mask_down_sample_buffer : @core.RenderTarget
  _render_target_edge_buffer1 : @core.RenderTarget
  _render_target_edge_buffer2 : @core.RenderTarget
  _render_target_blur_buffer1 : @core.RenderTarget
  _render_target_blur_buffer2 : @core.RenderTarget
  _render_target_composite : @core.RenderTarget
  // uniforms
  _camera_near : @nodes.Node
  _camera_far : @nodes.Node
  _blur_direction : @nodes.Node
  _depth_texture_uniform : @nodes.Node
  _mask_texture_uniform : @nodes.Node
  _mask_textures_down_sample_uniform : @nodes.Node
  _edge1_texture_uniform : @nodes.Node
  _edge2_texture_uniform : @nodes.Node
  _blur_color_texture_uniform : @nodes.Node
  // constants
  _visible_edge_color : @nodes.Node
  _hidden_edge_color : @nodes.Node
  // materials
  _depth_material : @core.Material
  _depth_sprite_material : @core.Material
  _prepare_mask_material : @core.Material
  _prepare_mask_sprite_material : @core.Material
  _material_copy : @core.Material
  _edge_detection_material : @core.Material
  _separable_blur_material : @core.Material
  _separable_blur_material2 : @core.Material
  _composite_material : @core.Material
  /// original material id -> (original material, pass material)
  _depth_material_cache : Map[Int32, (@core.Material, @core.Material)]
  _prepare_mask_material_cache : Map[Int32, (@core.Material, @core.Material)]
  _on_material_dispose : (@core.Event) -> Unit
  /// object id -> object (a `Set` of objects upstream)
  _selection_cache : Map[Int32, @core.Object3D]
  mut _last_selection_count : Int32
  _texture_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for OutlineNode with fn class_name(_) {
  "OutlineNode"
}

///|
pub impl @nodes.NodeClass for OutlineNode with fn children(self, _, out) {
  @nodes.push_child(out, "edgeThicknessNode", Some(self.edge_thickness_node))
  @nodes.push_child(out, "edgeGlowNode", Some(self.edge_glow_node))
}

///|
pub impl @nodes.NodeClass for OutlineNode with fn set_size(
  self,
  _,
  width,
  height,
) {
  self.set_size(width, height)
  true
}

///|
pub impl @nodes.NodeClass for OutlineNode with fn update_before(self, _, frame) {
  let renderer = frame.renderer.unwrap()
  let camera = self.camera
  let scene = self.scene
  let quad_mesh = display_outline_node_module.get()._quad_mesh
  self.update_selection_cache()
  // If no objects are selected, all subsequent passes can be skipped since
  // the outline would be empty anyway. The composite render target is cleared
  // once when transitioning to an empty selection so a previously rendered
  // outline does not linger on screen.
  if self._selection_cache.length() == 0 {
    if self._last_selection_count > 0 {
      _outline_node_renderer_state.val = Some(
        @nodes.reset_renderer_state(
          renderer,
          state?=_outline_node_renderer_state.val,
        ),
      )
      renderer.set_render_target(Some(self._render_target_composite))
      renderer.set_clear_color_hex(0x000000, alpha=0.0)
      renderer.clear()
      @nodes.restore_renderer_state(
        renderer,
        _outline_node_renderer_state.val.unwrap(),
      )
      self._last_selection_count = 0
    }
    return None
  }
  self._last_selection_count = self._selection_cache.length()
  _outline_node_renderer_state.val = Some(
    @nodes.reset_renderer_and_scene_state(
      renderer,
      scene,
      state?=_outline_node_renderer_state.val,
    ),
  )
  //
  let size = renderer.get_drawing_buffer_size(_outline_node_size)
  self.set_size(size.x, size.y)
  //
  renderer.set_clear_color_hex(0xffffff, alpha=1.0)
  let current_scene_name = scene.name
  // 1. Draw non-selected objects in the depth buffer
  renderer.set_render_target(Some(self._render_target_depth_buffer))
  renderer.set_render_object_function(
    Some({
      f: fn(
        object,
        scene,
        camera,
        geometry,
        material,
        group,
        lights_node,
        clipping_context,
        _,
      ) {
        if !self._selection_cache.contains(object.id) {
          let base_material = if object.is_sprite() {
            self._depth_sprite_material
          } else {
            self._depth_material
          }
          let override_material = self.get_pass_material(
            self._depth_material_cache,
            base_material,
            material,
          )
          renderer.render_object(
            object,
            scene,
            camera,
            geometry,
            override_material,
            group,
            lights_node,
            clipping_context,
            None,
          )
        }
      },
    }),
  )
  scene.name = "Outline [ Non-Selected Objects Pass ]"
  renderer.render(scene, camera)
  // 2. Draw only the selected objects by comparing the depth buffer of non-selected objects
  renderer.set_render_target(Some(self._render_target_mask_buffer))
  renderer.set_render_object_function(
    Some({
      f: fn(
        object,
        scene,
        camera,
        geometry,
        material,
        group,
        lights_node,
        clipping_context,
        _,
      ) {
        if self._selection_cache.contains(object.id) {
          let base_material = if object.is_sprite() {
            self._prepare_mask_sprite_material
          } else {
            self._prepare_mask_material
          }
          let override_material = self.get_pass_material(
            self._prepare_mask_material_cache,
            base_material,
            material,
          )
          renderer.render_object(
            object,
            scene,
            camera,
            geometry,
            override_material,
            group,
            lights_node,
            clipping_context,
            None,
          )
        }
      },
    }),
  )
  scene.name = "Outline [ Selected Objects Pass ]"
  renderer.render(scene, camera)
  //
  renderer.set_render_object_function(
    _outline_node_renderer_state.val.unwrap().render_object_function,
  )
  self._selection_cache.clear()
  scene.name = current_scene_name
  // 3. Downsample to (at least) half resolution
  quad_mesh.set_material(self._material_copy)
  quad_mesh.object.name = "Outline [ Downsample ]"
  renderer.set_render_target(Some(self._render_target_mask_down_sample_buffer))
  quad_mesh.render(renderer)
  // 4. Perform edge detection (half resolution)
  quad_mesh.set_material(self._edge_detection_material)
  quad_mesh.object.name = "Outline [ Edge Detection ]"
  renderer.set_render_target(Some(self._render_target_edge_buffer1))
  quad_mesh.render(renderer)
  // 5. Apply blur (half resolution)
  @nodes.TextureNode::set_value(
    self._blur_color_texture_uniform,
    Some(self._render_target_edge_buffer1.texture()),
  )
  outline_node_uniform_vector2(self._blur_direction).copy(
    _outline_node_blur_direction_x,
  )
  |> ignore
  quad_mesh.set_material(self._separable_blur_material)
  quad_mesh.object.name = "Outline [ Blur Half Resolution ]"
  renderer.set_render_target(Some(self._render_target_blur_buffer1))
  quad_mesh.render(renderer)
  @nodes.TextureNode::set_value(
    self._blur_color_texture_uniform,
    Some(self._render_target_blur_buffer1.texture()),
  )
  outline_node_uniform_vector2(self._blur_direction).copy(
    _outline_node_blur_direction_y,
  )
  |> ignore
  renderer.set_render_target(Some(self._render_target_edge_buffer1))
  quad_mesh.render(renderer)
  // 6. Apply blur (quarter resolution)
  @nodes.TextureNode::set_value(
    self._blur_color_texture_uniform,
    Some(self._render_target_edge_buffer1.texture()),
  )
  outline_node_uniform_vector2(self._blur_direction).copy(
    _outline_node_blur_direction_x,
  )
  |> ignore
  quad_mesh.set_material(self._separable_blur_material2)
  quad_mesh.object.name = "Outline [ Blur Quarter Resolution ]"
  renderer.set_render_target(Some(self._render_target_blur_buffer2))
  quad_mesh.render(renderer)
  @nodes.TextureNode::set_value(
    self._blur_color_texture_uniform,
    Some(self._render_target_blur_buffer2.texture()),
  )
  outline_node_uniform_vector2(self._blur_direction).copy(
    _outline_node_blur_direction_y,
  )
  |> ignore
  renderer.set_render_target(Some(self._render_target_edge_buffer2))
  quad_mesh.render(renderer)
  // 7. Composite
  quad_mesh.set_material(self._composite_material)
  quad_mesh.object.name = "Outline [ Blur Quarter Resolution ]"
  renderer.set_render_target(Some(self._render_target_composite))
  quad_mesh.render(renderer)
  // restore
  @nodes.restore_renderer_and_scene_state(
    renderer,
    scene,
    _outline_node_renderer_state.val.unwrap(),
  )
  None
}

///|
pub impl @nodes.NodeClass for OutlineNode with fn setup(self, _, _) {
  // prepare mask material
  let prepare_mask = fn() {
    let depth = self._depth_texture_uniform.sample(@nodes.screen_uv)
    let view_z_node = if self.camera.is_perspective_camera() {
      @nodes.perspective_depth_to_view_z.call([
        depth,
        self._camera_near,
        self._camera_far,
      ])
    } else {
      @nodes.orthographic_depth_to_view_z.call([
        depth,
        self._camera_near,
        self._camera_far,
      ])
    }
    let depth_test = @nodes.position_view
      .z()
      .less_than_equal(view_z_node)
      .select(1, else_node=0)
    @nodes.vec3_of([0.0, depth_test, 1.0])
  }
  @nodes.NodeMaterial::of(self._prepare_mask_material).unwrap().color_node = Some(
    prepare_mask(),
  )
  self._prepare_mask_material.set_needs_update(true)
  @nodes.NodeMaterial::of(self._prepare_mask_sprite_material).unwrap().color_node
  = Some(prepare_mask())
  self._prepare_mask_sprite_material.set_needs_update(true)
  // copy material
  @nodes.NodeMaterial::of(self._material_copy).unwrap().fragment_node = Some(
    self._mask_texture_uniform,
  )
  self._material_copy.set_needs_update(true)
  // edge detection material
  let edge_detection = @nodes.fn_(fn(_, _) {
    let resolution = @nodes.texture_size(
      self._mask_textures_down_sample_uniform,
    )
    let inv_size = @nodes.vec2(1).div(resolution).to_var()
    let uv_offset = @nodes.vec4_of([1.0, 0.0, 0.0, 1.0]).mul(
      @nodes.vec4_of([inv_size, inv_size]),
    )
    let uv_node = @nodes.uv()
    let c1 = self._mask_textures_down_sample_uniform
      .sample(uv_node.add(uv_offset.xy()))
      .to_var()
    let c2 = self._mask_textures_down_sample_uniform
      .sample(uv_node.sub(uv_offset.xy()))
      .to_var()
    let c3 = self._mask_textures_down_sample_uniform
      .sample(uv_node.add(uv_offset.yw()))
      .to_var()
    let c4 = self._mask_textures_down_sample_uniform
      .sample(uv_node.sub(uv_offset.yw()))
      .to_var()
    let diff1 = @nodes.mul(c1.r().sub(c2.r()), 0.5)
    let diff2 = @nodes.mul(c3.r().sub(c4.r()), 0.5)
    let d = @nodes.vec2_of([diff1, diff2]).length()
    let a1 = @nodes.min(c1.g(), c2.g())
    let a2 = @nodes.min(c3.g(), c4.g())
    let visibility_factor = @nodes.min(a1, a2)
    let edge_color = visibility_factor
      .one_minus()
      .greater_than(0.001)
      .select(self._visible_edge_color, else_node=self._hidden_edge_color)
    Some(@nodes.vec4_of([edge_color, 1]).mul(d))
  })
  @nodes.NodeMaterial::of(self._edge_detection_material).unwrap().fragment_node
  = Some(edge_detection.call([]))
  self._edge_detection_material.set_needs_update(true)
  // separable blur material
  let max_radius = 4
  let gaussian_pdf = @nodes.fn_(fn(inputs, _) {
    let x = addon_arg(inputs, 0)
    let sigma = addon_arg(inputs, 1)
    Some(
      @nodes.float(0.39894).mul(
        @nodes.exp(@nodes.float(-0.5).mul(x).mul(x).div(sigma.mul(sigma))).div(
          sigma,
        ),
      ),
    )
  })
  let separable_blur = @nodes.fn_(fn(inputs, _) {
    let kernel_radius = addon_arg(inputs, 0)
    let resolution = @nodes.texture_size(
      self._mask_textures_down_sample_uniform,
    )
    let inv_size = @nodes.vec2(1).div(resolution).to_var()
    let uv_node = @nodes.uv()
    let sigma = kernel_radius.div(2).to_var()
    let weight_sum = gaussian_pdf.call([0, sigma]).to_var()
    let diffuse_sum = self._blur_color_texture_uniform
      .sample(uv_node)
      .mul(weight_sum)
      .to_var()
    let delta = self._blur_direction
      .mul(inv_size)
      .mul(kernel_radius)
      .div(max_radius)
      .to_var()
    let uv_offset = delta.to_var()
    @nodes.loop_(
      [
        @nodes.loop_range(
          start=@nodes.int(1),
          end=@nodes.int(max_radius),
          type_="int",
          condition="<=",
        ),
      ],
      fn(inputs) {
        let i = inputs.named("i").unwrap()
        let x = kernel_radius.mul(@nodes.float(i)).div(max_radius)
        let w = gaussian_pdf.call([x, sigma])
        let sample1 = self._blur_color_texture_uniform.sample(
          uv_node.add(uv_offset),
        )
        let sample2 = self._blur_color_texture_uniform.sample(
          uv_node.sub(uv_offset),
        )
        diffuse_sum.add_assign(sample1.add(sample2).mul(w))
        weight_sum.add_assign(w.mul(2))
        uv_offset.add_assign(delta)
      },
    )
    Some(diffuse_sum.div(weight_sum))
  })
  @nodes.NodeMaterial::of(self._separable_blur_material).unwrap().fragment_node
  = Some(separable_blur.call([self.edge_thickness_node]))
  self._separable_blur_material.set_needs_update(true)
  @nodes.NodeMaterial::of(self._separable_blur_material2).unwrap().fragment_node
  = Some(separable_blur.call([max_radius]))
  self._separable_blur_material2.set_needs_update(true)
  // composite material
  let composite = @nodes.fn_(fn(_, _) {
    let edge_value1 = self._edge1_texture_uniform
    let edge_value2 = self._edge2_texture_uniform
    let mask_color = self._mask_texture_uniform
    let edge_value = edge_value1.add(edge_value2.mul(self.edge_glow_node))
    Some(mask_color.r().mul(edge_value))
  })
  @nodes.NodeMaterial::of(self._composite_material).unwrap().fragment_node = Some(
    composite.call([]),
  )
  self._composite_material.set_needs_update(true)
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for OutlineNode with fn dispose(self, node) {
  node.dispose_base()
  self.selected_objects.clear()
  self._render_target_depth_buffer.dispose()
  self._render_target_mask_buffer.dispose()
  self._render_target_mask_down_sample_buffer.dispose()
  self._render_target_edge_buffer1.dispose()
  self._render_target_edge_buffer2.dispose()
  self._render_target_blur_buffer1.dispose()
  self._render_target_blur_buffer2.dispose()
  self._render_target_composite.dispose()
  self._depth_material.dispose()
  self._depth_sprite_material.dispose()
  self._prepare_mask_material.dispose()
  self._prepare_mask_sprite_material.dispose()
  self._material_copy.dispose()
  self._edge_detection_material.dispose()
  self._separable_blur_material.dispose()
  self._separable_blur_material2.dispose()
  self._composite_material.dispose()
  for cache in [self._depth_material_cache, self._prepare_mask_material_cache] {
    for _, entry in cache {
      let (original_material, pass_material) = entry
      original_material.remove_event_listener(
        "dispose",
        self._on_material_dispose,
      )
      pass_material.dispose()
    }
    cache.clear()
  }
}

///|
/// `visibleEdge`: the visible edges of the outline (`this.r`).
pub fn OutlineNode::visible_edge(node : @nodes.Node) -> @nodes.Node {
  node.r()
}

///|
/// `hiddenEdge`: the hidden edges of the outline (`this.g`).
pub fn OutlineNode::hidden_edge(node : @nodes.Node) -> @nodes.Node {
  node.g()
}

///|
/// `getTextureNode()`: the outline result.
pub fn OutlineNode::get_texture_node(self : OutlineNode) -> @nodes.Node {
  self._texture_node
}

///|
/// `setSize( width, height )`: the full resolution and the downsampled targets.
pub fn OutlineNode::set_size(
  self : OutlineNode,
  width : Double,
  height : Double,
) -> Unit {
  self._render_target_depth_buffer.set_size(width.to_int(), height.to_int())
  self._render_target_mask_buffer.set_size(width.to_int(), height.to_int())
  self._render_target_composite.set_size(width.to_int(), height.to_int())
  // downsample 1
  let mut resx = outline_node_math_round(width / self.down_sample_ratio)
  let mut resy = outline_node_math_round(height / self.down_sample_ratio)
  self._render_target_mask_down_sample_buffer.set_size(
    resx.to_int(),
    resy.to_int(),
  )
  self._render_target_edge_buffer1.set_size(resx.to_int(), resy.to_int())
  self._render_target_blur_buffer1.set_size(resx.to_int(), resy.to_int())
  // downsample 2
  resx = outline_node_math_round(resx / 2.0)
  resy = outline_node_math_round(resy / 2.0)
  self._render_target_edge_buffer2.set_size(resx.to_int(), resy.to_int())
  self._render_target_blur_buffer2.set_size(resx.to_int(), resy.to_int())
}

///|
/// `_updateSelectionCache()`: the selected meshes and sprites, with their descendants.
fn OutlineNode::update_selection_cache(self : OutlineNode) -> Unit {
  for selected_object in self.selected_objects {
    selected_object.traverse(fn(object) {
      if object.is_mesh() || object.is_sprite() {
        self._selection_cache.set(object.id, object)
      }
    })
  }
}

///|
/// `_getPassMaterial( cache, baseMaterial, originalMaterial )`: `baseMaterial`, or a clone
/// of it carrying the original material's `positionNode`.
fn OutlineNode::get_pass_material(
  self : OutlineNode,
  cache : Map[Int32, (@core.Material, @core.Material)],
  base_material : @core.Material,
  original_material : @core.Material,
) -> @core.Material {
  let original_position_node = match
    @nodes.NodeMaterial::of(original_material) {
    Some(m) => m.position_node
    None => None
  }
  if original_position_node is None {
    return base_material // early out if there are no node modifications
  }
  let mut force = false
  let pass_material = match cache.get(original_material.id) {
    Some((_, pass_material)) => pass_material
    // create
    None => {
      let pass_material = base_material.clone()
      cache.set(original_material.id, (original_material, pass_material))
      original_material.add_event_listener("dispose", self._on_material_dispose)
      force = true
      pass_material
    }
  }
  // update
  if pass_material.version != original_material.version || force {
    @nodes.NodeMaterial::of(pass_material).unwrap().position_node = original_position_node
    pass_material.version = original_material.version
  }
  pass_material
}

///|
fn outline_node_uniform_vector2(node : @nodes.Node) -> @math.Vector2 {
  match @nodes.InputNode::get_value(node) {
    Vector2(v) => v
    _ => abort("uniform value is not a Vector2")
  }
}

///|
/// `new OutlineNode( scene, camera, params = {} )`; the params are `selectedObjects`
/// (default `[]`), `edgeThickness` (`float( 1 )`), `edgeGlow` (`float( 0 )`) and
/// `downSampleRatio` (2).
pub fn OutlineNode::new(
  scene : @core.Object3D,
  camera : @core.Object3D,
  selected_objects? : Array[@core.Object3D],
  edge_thickness? : &@nodes.IntoTsl,
  edge_glow? : &@nodes.IntoTsl,
  down_sample_ratio~ : Double = 2.0,
) -> @nodes.Node {
  display_outline_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="vec4")
  let selected_objects = match selected_objects {
    Some(objects) => objects
    None => []
  }
  let edge_thickness : &@nodes.IntoTsl = match edge_thickness {
    Some(v) => v
    None => @nodes.float(1)
  }
  let edge_glow : &@nodes.IntoTsl = match edge_glow {
    Some(v) => v
    None => @nodes.float(0)
  }
  let edge_thickness_node = addon_node_object(edge_thickness)
  let edge_glow_node = addon_node_object(edge_glow)
  node.update_before_type = @nodes.NodeUpdateType::frame()
  // render targets
  let render_target_depth_buffer = @core.RenderTarget::new()
  render_target_depth_buffer.set_depth_texture(Some(@core.DepthTexture::new()))
  render_target_depth_buffer.depth_texture().unwrap().type_ = @core.FloatType
  let render_target_mask_buffer = @core.RenderTarget::new()
  let render_target_mask_down_sample_buffer = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
  )
  let render_target_edge_buffer1 = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
  )
  let render_target_edge_buffer2 = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
  )
  let render_target_blur_buffer1 = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
  )
  let render_target_blur_buffer2 = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
  )
  let render_target_composite = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
  )
  // uniforms
  let camera_near = @nodes.reference("near", "float", object=Object3D(camera))
  let camera_far = @nodes.reference("far", "float", object=Object3D(camera))
  let blur_direction = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let depth_texture_uniform = @nodes.texture(
    render_target_depth_buffer.depth_texture().unwrap(),
  )
  let mask_texture_uniform = @nodes.texture(render_target_mask_buffer.texture())
  let mask_textures_down_sample_uniform = @nodes.texture(
    render_target_mask_down_sample_buffer.texture(),
  )
  let edge1_texture_uniform = @nodes.texture(
    render_target_edge_buffer1.texture(),
  )
  let edge2_texture_uniform = @nodes.texture(
    render_target_edge_buffer2.texture(),
  )
  let blur_color_texture_uniform = @nodes.texture(
    render_target_edge_buffer1.texture(),
  )
  // constants
  let visible_edge_color = @nodes.vec3_of([1, 0, 0])
  let hidden_edge_color = @nodes.vec3_of([0, 1, 0])
  // materials
  let depth_material = @nodes.NodeMaterial::new()
  @nodes.NodeMaterial::of(depth_material).unwrap().color_node = Some(
    @nodes.color_of([0, 0, 0]),
  )
  depth_material.name = "OutlineNode.depth"
  let depth_sprite_material = @nodes.SpriteNodeMaterial::new()
  @nodes.NodeMaterial::of(depth_sprite_material).unwrap().color_node = Some(
    @nodes.color_of([0, 0, 0]),
  )
  depth_sprite_material.name = "OutlineNode.depthSprite"
  let prepare_mask_material = @nodes.NodeMaterial::new()
  prepare_mask_material.name = "OutlineNode.prepareMask"
  let prepare_mask_sprite_material = @nodes.SpriteNodeMaterial::new()
  prepare_mask_sprite_material.name = "OutlineNode.prepareMaskSprite"
  let material_copy = @nodes.NodeMaterial::new()
  material_copy.name = "OutlineNode.copy"
  let edge_detection_material = @nodes.NodeMaterial::new()
  edge_detection_material.name = "OutlineNode.edgeDetection"
  let separable_blur_material = @nodes.NodeMaterial::new()
  separable_blur_material.name = "OutlineNode.separableBlur"
  let separable_blur_material2 = @nodes.NodeMaterial::new()
  separable_blur_material2.name = "OutlineNode.separableBlur2"
  let composite_material = @nodes.NodeMaterial::new()
  composite_material.name = "OutlineNode.composite"
  let depth_material_cache : Map[Int32, (@core.Material, @core.Material)] = Map([],
  )
  let prepare_mask_material_cache : Map[Int32, (@core.Material, @core.Material)] = Map([],
  )
  let on_material_dispose : Ref[(@core.Event) -> Unit] = Ref(fn(_) { () })
  on_material_dispose.val = fn(event) {
    guard event.target is Some(Material(original_material)) else { return }
    original_material.remove_event_listener("dispose", on_material_dispose.val)
    for cache in [depth_material_cache, prepare_mask_material_cache] {
      if cache.get(original_material.id) is Some((_, pass_material)) {
        pass_material.dispose()
        cache.remove(original_material.id)
      }
    }
  }
  let texture_node_out = @nodes.pass_texture(
    node,
    render_target_composite.texture(),
  )
  node.set_class(OutlineNode::{
    scene,
    camera,
    selected_objects,
    edge_thickness_node,
    edge_glow_node,
    down_sample_ratio,
    _render_target_depth_buffer: render_target_depth_buffer,
    _render_target_mask_buffer: render_target_mask_buffer,
    _render_target_mask_down_sample_buffer: render_target_mask_down_sample_buffer,
    _render_target_edge_buffer1: render_target_edge_buffer1,
    _render_target_edge_buffer2: render_target_edge_buffer2,
    _render_target_blur_buffer1: render_target_blur_buffer1,
    _render_target_blur_buffer2: render_target_blur_buffer2,
    _render_target_composite: render_target_composite,
    _camera_near: camera_near,
    _camera_far: camera_far,
    _blur_direction: blur_direction,
    _depth_texture_uniform: depth_texture_uniform,
    _mask_texture_uniform: mask_texture_uniform,
    _mask_textures_down_sample_uniform: mask_textures_down_sample_uniform,
    _edge1_texture_uniform: edge1_texture_uniform,
    _edge2_texture_uniform: edge2_texture_uniform,
    _blur_color_texture_uniform: blur_color_texture_uniform,
    _visible_edge_color: visible_edge_color,
    _hidden_edge_color: hidden_edge_color,
    _depth_material: depth_material,
    _depth_sprite_material: depth_sprite_material,
    _prepare_mask_material: prepare_mask_material,
    _prepare_mask_sprite_material: prepare_mask_sprite_material,
    _material_copy: material_copy,
    _edge_detection_material: edge_detection_material,
    _separable_blur_material: separable_blur_material,
    _separable_blur_material2: separable_blur_material2,
    _composite_material: composite_material,
    _depth_material_cache: depth_material_cache,
    _prepare_mask_material_cache: prepare_mask_material_cache,
    _on_material_dispose: on_material_dispose.val,
    _selection_cache: Map([]),
    _last_selection_count: 0,
    _texture_node: texture_node_out,
  })
}

///|
pub fn OutlineNode::of(node : @nodes.Node) -> OutlineNode? {
  addon_class_of(node, "OutlineNode")
}

///|
/// `outline( scene, camera, params )`; the params are labelled arguments.
pub fn outline(
  scene : @core.Object3D,
  camera : @core.Object3D,
  selected_objects? : Array[@core.Object3D],
  edge_thickness? : &@nodes.IntoTsl,
  edge_glow? : &@nodes.IntoTsl,
  down_sample_ratio~ : Double = 2.0,
) -> @nodes.Node {
  display_outline_node_module.get() |> ignore
  OutlineNode::new(
    scene,
    camera,
    selected_objects?,
    edge_thickness?,
    edge_glow?,
    down_sample_ratio~,
  )
}
