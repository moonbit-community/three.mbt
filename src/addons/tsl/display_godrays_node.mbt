// examples/jsm/tsl/display/GodraysNode.js

///|
/// The module-level state of GodraysNode.js (`_quadMesh`, `_size`, `_DIRECTIONS`,
/// `_PLANES`, the scratch objects and `_rendererState`).
priv struct GodraysNodeModule {
  quad_mesh : @nodes.QuadMesh
  size : @math.Vector2
  directions : Array[@math.Vector3]
  planes : Array[@math.Plane]
  scratch_vector : @math.Vector3
  scratch_mat4 : @math.Matrix4
  scratch_frustum : @math.Frustum
  mut renderer_state : @nodes.RendererState?
}

///|
let _godrays_node_module : AddonModule[GodraysNodeModule] = AddonModule::new(fn() {
  let quad_mesh = @nodes.QuadMesh::new()
  let size = @math.Vector2::new(0.0, 0.0)
  let directions = [
    @math.Vector3::new(1, 0, 0),
    @math.Vector3::new(-1, 0, 0),
    @math.Vector3::new(0, 1, 0),
    @math.Vector3::new(0, -1, 0),
    @math.Vector3::new(0, 0, 1),
    @math.Vector3::new(0, 0, -1),
  ]
  let planes = directions.map(fn(_) { @math.Plane::new() })
  {
    quad_mesh,
    size,
    directions,
    planes,
    scratch_vector: @math.Vector3::new(0, 0, 0),
    scratch_mat4: @math.Matrix4::new(),
    scratch_frustum: @math.Frustum::new(),
    renderer_state: None,
  }
})

///|
/// Evaluates GodraysNode.js's module-level statements (as its ES `import` does).
pub fn load_display_godrays_node() -> Unit {
  _godrays_node_module.get() |> ignore
}

///|
extern "js" fn godrays_node_math_round(x : Double) -> Double = "Math.round"

///|
/// Post processing node for volumetric light shafts (godrays) of a shadow-casting point
/// or directional light, ray marched against its shadow map.
pub(all) struct GodraysNode {
  mut depth_node : @nodes.Node
  raymarch_steps : @nodes.Node
  density : @nodes.Node
  max_density : @nodes.Node
  distance_attenuation : @nodes.Node
  mut resolution_scale : Double
  _camera_matrix_world : @nodes.Node
  _camera_projection_matrix_inverse : @nodes.Node
  _premultiplied_light_camera_matrix : @nodes.Node
  _camera_position : @nodes.Node
  _camera_near : @nodes.Node
  _camera_far : @nodes.Node
  _shadow_camera_near : @nodes.Node
  _shadow_camera_far : @nodes.Node
  _f_normals : @nodes.Node
  _f_constants : @nodes.Node
  _light : @core.Object3D
  _camera : @core.Object3D
  _godrays_render_target : @core.RenderTarget
  _material : @core.Material
  mut _texture_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for GodraysNode with fn class_name(_) {
  "GodraysNode"
}

///|
pub impl @nodes.NodeClass for GodraysNode with fn children(self, _, out) {
  @nodes.push_child(out, "depthNode", Some(self.depth_node))
  @nodes.push_child(out, "raymarchSteps", Some(self.raymarch_steps))
  @nodes.push_child(out, "density", Some(self.density))
  @nodes.push_child(out, "maxDensity", Some(self.max_density))
  @nodes.push_child(out, "distanceAttenuation", Some(self.distance_attenuation))
}

///|
pub impl @nodes.NodeClass for GodraysNode with fn set_size(
  self,
  _,
  width,
  height,
) {
  self.set_size(width, height)
  true
}

///|
/// `getTextureNode()`: the texture node holding the godrays (rgb) and depth (a).
pub fn GodraysNode::get_texture_node(self : GodraysNode) -> @nodes.Node {
  self._texture_node
}

///|
/// `setSize( width, height )`.
pub fn GodraysNode::set_size(
  self : GodraysNode,
  width : Double,
  height : Double,
) -> Unit {
  let width = godrays_node_math_round(self.resolution_scale * width)
  let height = godrays_node_math_round(self.resolution_scale * height)
  self._godrays_render_target.set_size(width.to_int(), height.to_int())
}

///|
pub impl @nodes.NodeClass for GodraysNode with fn update_before(self, _, frame) {
  let m = _godrays_node_module.get()
  let renderer = frame.renderer.unwrap()
  m.renderer_state = Some(
    @nodes.reset_renderer_state(renderer, state?=m.renderer_state),
  )
  //
  let size = renderer.get_drawing_buffer_size(m.size)
  self.set_size(size.x, size.y)
  //
  m.quad_mesh.set_material(self._material)
  m.quad_mesh.object.name = "Godrays"
  self.update_light_params()
  a4_uniform_vector3(self._camera_position).set_from_matrix_position(
    self._camera.matrix_world,
  )
  |> ignore
  // clear
  renderer.set_clear_color_hex(0xffffff, alpha=1)
  // godrays
  renderer.set_render_target(Some(self._godrays_render_target))
  m.quad_mesh.render(renderer)
  // restore
  @nodes.restore_renderer_state(renderer, m.renderer_state.unwrap())
  None
}

///|
/// The light payload of `light`.
fn godrays_node_light(light : @core.Object3D) -> @core.Light {
  match light.kind {
    Light(l) => l
    _ => abort("THREE.GodraysNode: \{light.type_} is not a light")
  }
}

///|
/// `light.shadow`.
fn godrays_node_shadow(light : @core.Object3D) -> @core.LightShadow {
  godrays_node_light(light).shadow.unwrap()
}

///|
fn godrays_node_is_point_light(light : @core.Object3D) -> Bool {
  godrays_node_light(light).kind is PointLight(_)
}

///|
fn godrays_node_is_directional_light(light : @core.Object3D) -> Bool {
  godrays_node_light(light).kind is DirectionalLight(_)
}

///|
/// `light.shadow.map.depthTexture`.
fn godrays_node_shadow_depth_texture(light : @core.Object3D) -> @core.Texture {
  godrays_node_shadow(light).map.unwrap().depth_texture().unwrap()
}

///|
/// `_updateLightParams()`: the shadow frustum planes of the light.
fn GodraysNode::update_light_params(self : GodraysNode) -> Unit {
  let m = _godrays_node_module.get()
  let light = self._light
  let shadow_camera = godrays_node_shadow(light).camera
  match @nodes.InputNode::get_value(self._premultiplied_light_camera_matrix) {
    Matrix4(v) =>
      v.multiply_matrices(
        shadow_camera.projection_matrix(),
        shadow_camera.matrix_world_inverse(),
      )
      |> ignore
    _ => ()
  }
  let normals = @nodes.UniformArrayNode::of(self._f_normals).unwrap()
  let constants = @nodes.UniformArrayNode::of(self._f_constants).unwrap()
  let normal_at = fn(i : Int32) {
    match normals.array[i] {
      Vector3(v) => v
      _ => abort("GodraysNode: _fNormals holds Vector3s")
    }
  }
  if godrays_node_is_point_light(light) {
    for i in 0..<m.directions.length() {
      let direction = m.directions[i]
      let plane = m.planes[i]
      m.scratch_vector.copy(light.position) |> ignore
      m.scratch_vector.add_scaled_vector(
        direction,
        godrays_node_camera_far(shadow_camera),
      )
      |> ignore
      plane.set_from_normal_and_coplanar_point(direction, m.scratch_vector)
      |> ignore
      normal_at(i).copy(plane.normal) |> ignore
      constants.array[i] = Number(plane.constant)
    }
  } else if godrays_node_is_directional_light(light) {
    m.scratch_mat4.multiply_matrices(
      shadow_camera.projection_matrix(),
      shadow_camera.matrix_world_inverse(),
    )
    |> ignore
    m.scratch_frustum.set_from_projection_matrix(m.scratch_mat4) |> ignore
    for i in 0..<6 {
      let plane = m.scratch_frustum.planes[i]
      normal_at(i).copy(plane.normal).multiply_scalar(-1) |> ignore
      constants.array[i] = Number(plane.constant * -1)
    }
  }
}

///|
/// `camera.far` of a perspective or orthographic camera.
fn godrays_node_camera_far(camera : @core.Object3D) -> Double {
  match camera.kind {
    Camera(c) =>
      match c.kind {
        PerspectiveCamera(p) => p.far
        OrthographicCamera(o) => o.far
        _ => abort("GodraysNode: the shadow camera has no far plane")
      }
    _ => abort("GodraysNode: the shadow camera is not a camera")
  }
}

///|
pub impl @nodes.NodeClass for GodraysNode with fn setup(self, _, builder) {
  let uv_node = @nodes.uv()
  let light_pos = @nodes.light_position(self._light)
  let sample_depth = fn(uv : @nodes.Node) {
    @nodes.projection_depth.call([
      self.depth_node.sample(uv).r(),
      self._camera_near,
      self._camera_far,
    ])
  }
  let sd_plane = fn(p : @nodes.Node, n : @nodes.Node, h : @nodes.Node) {
    @nodes.dot(p, n).add(h)
  }
  let intersect_ray_plane = fn(
    ray_origin : @nodes.Node,
    ray_direction : @nodes.Node,
    plane_normal : @nodes.Node,
    plane_distance : @nodes.Node,
  ) {
    let denom = @nodes.dot(plane_normal, ray_direction)
    sd_plane(ray_origin, plane_normal, plane_distance).div(denom).negate()
  }
  let compute_shadow_coord = fn(world_pos : @nodes.Node) {
    let shadow_position = @nodes.light_shadow_matrix(self._light).mul(world_pos)
    let shadow_coord = shadow_position.xyz().div(shadow_position.w())
    @nodes.vec3_of([
      shadow_coord.x(),
      shadow_coord.y().one_minus(),
      shadow_coord.z(),
    ])
  }
  let in_shadow = fn(world_pos : @nodes.Node) {
    if godrays_node_is_point_light(self._light) {
      let light_to_pos = world_pos.sub(light_pos).to_const()
      let shadow_position_abs = light_to_pos.abs().to_const()
      let view_z = shadow_position_abs
        .x()
        .max(shadow_position_abs.y())
        .max(shadow_position_abs.z())
        .negate()
      let depth = @nodes.view_z_to_perspective_depth(
        view_z,
        self._shadow_camera_near,
        self._shadow_camera_far,
      )
      let result = @nodes.cube_texture(
          godrays_node_shadow_depth_texture(self._light),
          uv_node=light_to_pos,
        )
        .compare(depth)
        .r()
      @nodes.vec2_of([result.one_minus().add(0.005), view_z.negate()])
    } else if godrays_node_is_directional_light(self._light) {
      let shadow_coord = compute_shadow_coord(world_pos).to_const()
      let frustum_test = shadow_coord
        .x()
        .greater_than_equal(0)
        .and_(shadow_coord.x().less_than_equal(1))
        .and_(shadow_coord.y().greater_than_equal(0))
        .and_(shadow_coord.y().less_than_equal(1))
        .and_(shadow_coord.z().greater_than_equal(0))
        .and_(shadow_coord.z().less_than_equal(1))
      let output = @nodes.vec2_of([1, 0])
      @nodes.if_(frustum_test.equal(true), fn() {
        let result = @nodes.texture(
            godrays_node_shadow_depth_texture(self._light),
            uv_node=shadow_coord.xy(),
          )
          .compare(shadow_coord.z())
          .r()
        let view_z = @nodes.perspective_depth_to_view_z.call([
          shadow_coord.z(),
          self._shadow_camera_near,
          self._shadow_camera_far,
        ])
        output.assign(@nodes.vec2_of([result.one_minus(), view_z.negate()]))
      })
      |> ignore
      output
    } else {
      abort("THREE.GodraysNode: Unsupported light type.")
    }
  }
  let godrays = @nodes.fn_(fn(_, _) {
    let output = @nodes.vec4_of([0, 0, 0, 1]).to_var()
    let is_early_out = @nodes.bool(false)
    let depth = sample_depth(uv_node).to_const()
    let view_position = @nodes.get_view_position
      .call([uv_node, depth, self._camera_projection_matrix_inverse])
      .to_const()
    let world_position = self._camera_matrix_world.mul(view_position)
    let in_box_dist = @nodes.float(-10000.0).to_var()
    @nodes.loop_([6], fn(inputs) {
      let i = inputs.named("i").unwrap()
      in_box_dist.assign(
        @nodes.max(
          in_box_dist,
          sd_plane(
            self._camera_position,
            self._f_normals.element(i),
            self._f_constants.element(i),
          ),
        ),
      )
    })
    let start_position = self._camera_position.to_var()
    @nodes.if_(in_box_dist.less_than(0), fn() {
      // If the ray target is outside the shadow box, move it to the nearest
      // point on the box to avoid marching through unlit space
      @nodes.loop_([6], fn(inputs) {
        let i = inputs.named("i").unwrap()
        @nodes.if_(
          sd_plane(
            world_position,
            self._f_normals.element(i),
            self._f_constants.element(i),
          ).greater_than(0),
          fn() {
            let direction = world_position.sub(self._camera_position).to_const()
            let t = intersect_ray_plane(
              self._camera_position,
              direction,
              self._f_normals.element(i),
              self._f_constants.element(i),
            )
            world_position.assign(self._camera_position.add(t.mul(direction)))
          },
        )
        |> ignore
      })
    }).else_(fn() {
      // Find the first point where the ray intersects the shadow box (startPos)
      let direction = world_position.sub(self._camera_position).to_const()
      let min_t = @nodes.float(10000).to_var()
      @nodes.loop_([6], fn(inputs) {
        let i = inputs.named("i").unwrap()
        let t = intersect_ray_plane(
          self._camera_position,
          direction,
          self._f_normals.element(i),
          self._f_constants.element(i),
        )
        @nodes.if_(t.less_than(min_t).and_(t.greater_than(0)), fn() {
          min_t.assign(t)
        })
        |> ignore
      })
      @nodes.if_(min_t.equal(10000), fn() { is_early_out.assign(true) }).else_(fn() {
        start_position.assign(
          self._camera_position.add(min_t.add(0.001).mul(direction)),
        )
        // If the ray target is outside the shadow box, move it to the nearest
        // point on the box to avoid marching through unlit space
        let end_in_box_dist = @nodes.float(-10000).to_var()
        @nodes.loop_([6], fn(inputs) {
          let i = inputs.named("i").unwrap()
          end_in_box_dist.assign(
            @nodes.max(
              end_in_box_dist,
              sd_plane(
                world_position,
                self._f_normals.element(i),
                self._f_constants.element(i),
              ),
            ),
          )
        })
        @nodes.if_(end_in_box_dist.greater_than_equal(0), fn() {
          let min_t = @nodes.float(10000).to_var()
          @nodes.loop_([6], fn(inputs) {
            let i = inputs.named("i").unwrap()
            @nodes.if_(
              sd_plane(
                world_position,
                self._f_normals.element(i),
                self._f_constants.element(i),
              ).greater_than(0),
              fn() {
                let t = intersect_ray_plane(
                  start_position,
                  direction,
                  self._f_normals.element(i),
                  self._f_constants.element(i),
                )
                @nodes.if_(t.less_than(min_t).and_(t.greater_than(0)), fn() {
                  min_t.assign(t)
                })
                |> ignore
              },
            )
            |> ignore
          })
          @nodes.if_(min_t.less_than(world_position.distance(start_position)), fn() {
            world_position.assign(start_position.add(min_t.mul(direction)))
          })
          |> ignore
        })
        |> ignore
      })
    })
    @nodes.if_(is_early_out.equal(false), fn() {
      let illum = @nodes.float(0).to_var()
      let noise = @nodes.interleaved_gradient_noise
        .call([@nodes.screen_coordinate])
        .to_const()
      let samples_float = @nodes.round(
        @nodes.add(
          self.raymarch_steps,
          @nodes.mul(self.raymarch_steps.div(8).add(2), noise),
        ),
      ).to_const()
      let samples = @nodes.uint(samples_float).to_const()
      @nodes.loop_([samples], fn(inputs) {
        let i = inputs.named("i").unwrap()
        let sample_pos = @nodes.mix(
          start_position,
          world_position,
          @nodes.float(i).div(samples_float),
        ).to_const()
        let shadow_info = in_shadow(sample_pos)
        let shadow_amount = shadow_info.x().one_minus().to_const()
        illum.add_assign(
          shadow_amount
          .mul(
            @nodes.distance(start_position, world_position).mul(
              self.density.div(100),
            ),
          )
          .mul(
            @nodes.pow(
              shadow_info.y().div(self._shadow_camera_far).one_minus(),
              self.distance_attenuation,
            ),
          ),
        )
      })
      illum.div_assign(samples_float)
      output.assign(
        @nodes.vec4_of([
          @nodes.vec3(
            @nodes.clamp(
              @nodes.exp(illum.negate()).one_minus(),
              low=0,
              high=self.max_density,
            ),
          ),
          depth,
        ]),
      )
    })
    |> ignore
    Some(output)
  })
  let node_material = @nodes.NodeMaterial::of(self._material).unwrap()
  node_material.context_node = Some(
    @nodes.context(value=builder.get_shared_context()),
  )
  node_material.fragment_node = Some(godrays.call([]))
  self._material.set_needs_update(true)
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for GodraysNode with fn dispose(self, node) {
  node.dispose_base()
  self._godrays_render_target.dispose()
  self._material.dispose()
}

///|
/// `new GodraysNode( depthNode, camera, light )`: `light` is a shadow-casting point or
/// directional light.
pub fn GodraysNode::new(
  depth_node : @nodes.Node,
  camera : @core.Object3D,
  light : @core.Object3D,
) -> @nodes.Node {
  let m = _godrays_node_module.get()
  let node = @nodes.Node::alloc(node_type="vec4")
  let raymarch_steps = @nodes.uniform(@nodes.uint(60))
  let density = @nodes.uniform(@nodes.float(0.7))
  let max_density = @nodes.uniform(@nodes.float(0.5))
  let distance_attenuation = @nodes.uniform(@nodes.float(2))
  node.update_before_type = @nodes.NodeUpdateType::frame()
  // private uniforms
  let camera_matrix_world = @nodes.uniform(camera.matrix_world)
  let camera_projection_matrix_inverse = @nodes.uniform(
    camera.projection_matrix_inverse(),
  )
  let premultiplied_light_camera_matrix = @nodes.uniform(@math.Matrix4::new())
  let camera_position = @nodes.uniform(@math.Vector3::new(0, 0, 0))
  let camera_near = @nodes.reference("near", "float", object=Object3D(camera))
  let camera_far = @nodes.reference("far", "float", object=Object3D(camera))
  let shadow_camera = godrays_node_shadow(light).camera
  let shadow_camera_near = @nodes.reference(
    "near",
    "float",
    object=Object3D(shadow_camera),
  )
  let shadow_camera_far = @nodes.reference(
    "far",
    "float",
    object=Object3D(shadow_camera),
  )
  let f_normals = @nodes.uniform_array(
    @nodes.TslValue::Array(
      m.directions.map(fn(_) { Vector3(@math.Vector3::new(0, 0, 0)) }),
    ),
  )
  let f_constants = @nodes.uniform_array(
    @nodes.TslValue::Array(m.directions.map(fn(_) { Number(0) })),
  )
  let godrays_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
  )
  godrays_render_target.texture().name = "Godrays"
  let material = @nodes.NodeMaterial::new()
  material.name = "Godrays"
  let payload = GodraysNode::{
    depth_node,
    raymarch_steps,
    density,
    max_density,
    distance_attenuation,
    resolution_scale: 0.5,
    _camera_matrix_world: camera_matrix_world,
    _camera_projection_matrix_inverse: camera_projection_matrix_inverse,
    _premultiplied_light_camera_matrix: premultiplied_light_camera_matrix,
    _camera_position: camera_position,
    _camera_near: camera_near,
    _camera_far: camera_far,
    _shadow_camera_near: shadow_camera_near,
    _shadow_camera_far: shadow_camera_far,
    _f_normals: f_normals,
    _f_constants: f_constants,
    _light: light,
    _camera: camera,
    _godrays_render_target: godrays_render_target,
    _material: material,
    _texture_node: node,
  }
  payload._texture_node = @nodes.pass_texture(
    node,
    godrays_render_target.texture(),
  )
  node.set_class(payload)
}

///|
pub fn GodraysNode::of(node : @nodes.Node) -> GodraysNode? {
  addon_class_of(node, "GodraysNode")
}

///|
/// `godrays( depthNode, camera, light )`.
pub fn godrays(
  depth_node : @nodes.Node,
  camera : @core.Object3D,
  light : @core.Object3D,
) -> @nodes.Node {
  GodraysNode::new(depth_node, camera, light)
}
