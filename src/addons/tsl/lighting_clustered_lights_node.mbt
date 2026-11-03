// examples/jsm/tsl/lighting/ClusteredLightsNode.js

///|
let _clustered_lights_node_vector3 : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _clustered_lights_node_direction : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _clustered_lights_node_target_position : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _clustered_lights_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

// light data texture rows

///|
/// world position, cutoff distance
const CLUSTERED_LIGHTS_NODE_POSITION_ROW : Int32 = 0

///|
/// color * intensity, decay
const CLUSTERED_LIGHTS_NODE_COLOR_ROW : Int32 = 1

///|
/// scaled world spot direction, scaled cone cosine
const CLUSTERED_LIGHTS_NODE_SPOT_ROW : Int32 = 2

///|
/// world bounding sphere center, radius ( negative if unbounded )
const CLUSTERED_LIGHTS_NODE_BOUNDS_ROW : Int32 = 3

///|
const CLUSTERED_LIGHTS_NODE_ROWS : Int32 = 4

///|
extern "js" fn clustered_lights_node_math_cos(x : Double) -> Double = "Math.cos"

///|
extern "js" fn clustered_lights_node_math_sin(x : Double) -> Double = "Math.sin"

///|
extern "js" fn clustered_lights_node_math_min(a : Double, b : Double) -> Double = "Math.min"

///|
extern "js" fn clustered_lights_node_math_max(a : Double, b : Double) -> Double = "Math.max"

///|
extern "js" fn clustered_lights_node_math_pow(a : Double, b : Double) -> Double = "Math.pow"

///|
extern "js" fn clustered_lights_node_math_ceil(x : Double) -> Double = "Math.ceil"

///|
extern "js" fn clustered_lights_node_math_floor(x : Double) -> Double = "Math.floor"

///|
/// Forward+ clustered shading: the view frustum is split into a 3D grid of clusters
/// (screen tiles times exponential depth slices), each holding the point and spot lights
/// whose bounding spheres intersect it; fragments loop over their cluster's lights only.
pub(all) struct ClusteredLightsNode {
  lights : @nodes.LightsNode
  material_lights : Array[@core.Object3D]
  clustered_lights : Array[@core.Object3D]
  max_lights : Int32
  tile_size : Int32
  z_slices : Int32
  max_lights_per_cluster : Int32
  _chunks_per_cluster : Int32
  mut _buffer_size : @math.Vector2?
  mut _is_webgl_backend : Bool
  mut _needs_rebuild : Bool
  mut _invocations_per_cluster : Int32
  mut _light_indexes : @nodes.Node?
  mut _renderer : @nodes.Renderer?
  mut _screen_cluster_index : @nodes.Node?
  mut _compute : @nodes.Node?
  _lights_texture : @core.Texture
  // Per Z-slice light range for Z-culling (CPU-sorted, uploaded each frame)
  _z_slice_ranges_data : @core.TypedArray
  _z_slice_ranges_texture : @core.Texture
  _light_view_z : @core.TypedArray
  _light_sort_order : Array[Int32]
  _lights_count : @nodes.Node
  _camera_near : @nodes.Node
  _camera_far : @nodes.Node
  _camera_view_matrix : @nodes.Node
  _camera_projection_matrix : @nodes.Node
  _grid_dimensions : @nodes.Node
}

///|
pub impl @nodes.NodeClass for ClusteredLightsNode with fn class_name(_) {
  "ClusteredLightsNode"
}

///|
pub impl @nodes.NodeClass for ClusteredLightsNode with fn parent(self) {
  Some(self.lights)
}

///|
pub impl @nodes.NodeClass for ClusteredLightsNode with fn has_flag(self, flag) {
  flag == "isClusteredLightsNode" ||
  @nodes.NodeClass::has_flag(self.lights, flag)
}

///|
pub impl @nodes.NodeClass for ClusteredLightsNode with fn custom_cache_key(
  self,
  node,
) {
  // First use allocates the grid after material cache keys have been computed.
  // Keep that allocation stable, but never share bindings between lights nodes.
  @nodes.hash([
    node.id.to_double(),
    node.version.to_double(),
    @nodes.NodeClass::custom_cache_key(self.lights, node),
  ])
}

///|
pub impl @nodes.NodeClass for ClusteredLightsNode with fn update_before(
  self,
  node,
  frame,
) {
  let renderer = frame.renderer.unwrap()
  let camera = frame.camera.unwrap()
  self._init_grid(node, renderer)
  self._update_lights_texture(camera)
  @nodes.InputNode::set_value(
    self._camera_near,
    Number(@nodes.camera_near_of(camera)),
  )
  @nodes.InputNode::set_value(
    self._camera_far,
    Number(@nodes.camera_far_of(camera)),
  )
  @nodes.InputNode::set_value(
    self._camera_view_matrix,
    Matrix4(camera.as_camera().matrix_world_inverse),
  )
  @nodes.InputNode::set_value(
    self._camera_projection_matrix,
    Matrix4(camera.as_camera().projection_matrix),
  )
  renderer.compute(self._compute.unwrap())
  None
}

///|
pub impl @nodes.NodeClass for ClusteredLightsNode with fn dispose(self, node) {
  if self._compute is Some(compute) {
    compute.dispose()
  }
  if self._light_indexes is Some(light_indexes) {
    clustered_lights_node_storage_attribute(light_indexes).dispose()
  }
  self._lights_texture.dispose()
  self._z_slice_ranges_texture.dispose()
  @nodes.NodeClass::dispose(self.lights, node)
}

///|
pub impl @nodes.LightsNodeClass for ClusteredLightsNode with fn lights_parent(
  self,
) {
  Some(self.lights)
}

///|
pub impl @nodes.LightsNodeClass for ClusteredLightsNode with fn set_lights(
  self,
  node,
  lights,
) {
  let { clustered_lights, material_lights, .. } = self
  material_lights.clear()
  clustered_lights.clear()
  for light in lights {
    if self._is_clustered_light(light) {
      clustered_lights.push(light)
    } else {
      material_lights.push(light)
    }
  }
  @nodes.LightsNodeClass::set_lights(self.lights, node, lights)
}

///|
pub impl @nodes.LightsNodeClass for ClusteredLightsNode with fn get_builtin_lights(
  self,
  _,
) {
  self.material_lights
}

///|
pub impl @nodes.LightsNodeClass for ClusteredLightsNode with fn setup_lights(
  self,
  node,
  builder,
  light_nodes,
) {
  self._init_grid(node, builder.renderer)
  //
  let lighting_model = @nodes.NodeContext::reflected_light(builder.context).unwrap()
  lighting_model.direct_diffuse.to_stack() |> ignore
  lighting_model.direct_specular.to_stack() |> ignore
  @nodes.LightsNodeClass::setup_lights(self.lights, node, builder, light_nodes)
  @nodes.fn_(
    fn(_, _) {
      @nodes.loop_([self.max_lights_per_cluster], fn(inputs) {
        let i = inputs.named("i").unwrap()
        let light_index = self._get_tile(i)
        @nodes.if_(light_index.equal(@nodes.int(0)), fn() { @nodes.break_() })
        |> ignore
        let {
          color,
          decay,
          view_position,
          distance,
          spot_direction,
          spot_offset,
        } = self._get_light_data(light_index.sub(1))
        let light_vector = view_position.sub(@nodes.position_view)
        // spot cone attenuation, always 1 for point lights
        let spot_attenuation = @nodes.smoothstep(
          0,
          1,
          @nodes.dot(light_vector.normalize(), spot_direction).sub(spot_offset),
        ).to_var()
        // Early-out: skip full BRDF if fragment is beyond the light's cutoff or outside the spot cone
        let in_range = distance
          .equal(0)
          .or(
            @nodes.dot(light_vector, light_vector).less_than_equal(
              distance.mul(distance),
            ),
          )
        @nodes.if_(in_range.and_(spot_attenuation.greater_than(0)), fn() {
          @nodes.LightsNode::setup_direct_light(
            builder.lights_node.unwrap(),
            builder,
            node,
            @nodes.direct_point_light(
              color=color.mul(spot_attenuation),
              light_vector~,
              cutoff_distance=distance,
              decay_exponent=decay,
            ),
          )
        })
        |> ignore
      })
      None
    },
    layout=ReturnType("void"),
  ).call([])
  |> ignore
}

///|
/// `this._lightIndexes.value`.
fn clustered_lights_node_storage_attribute(
  node : @nodes.Node,
) -> @core.BufferAttribute {
  @nodes.StorageBufferNode::of(node).unwrap().storage_attribute
}

///|
/// The light data of `_getLightData( index )`.
priv struct ClusteredLightsNodeLightData {
  view_position : @nodes.Node
  distance : @nodes.Node
  color : @nodes.Node
  decay : @nodes.Node
  spot_direction : @nodes.Node
  spot_offset : @nodes.Node
}

///|
/// `_updateLightsTexture( camera )`: writes the light data sorted by the view-space
/// depth of their bounding spheres, and the light range of each depth slice.
pub fn ClusteredLightsNode::_update_lights_texture(
  self : ClusteredLightsNode,
  camera : @core.Object3D,
) -> Unit {
  let { _lights_texture: lights_texture, clustered_lights, .. } = self
  guard lights_texture.image() is DataImage(image) else {
    abort("ClusteredLightsNode: the lights texture has no data")
  }
  let data = image.data.unwrap()
  let line_size = image.width * 4
  let count = if clustered_lights.length() < self.max_lights {
    clustered_lights.length()
  } else {
    self.max_lights
  }
  @nodes.InputNode::set_value(self._lights_count, Number(count.to_double()))
  // Sort lights by the view-space depth of their bounding spheres for Z-culling
  let view_z = self._light_view_z
  let order = self._light_sort_order
  let view_matrix = camera.as_camera().matrix_world_inverse
  for i in 0..<count {
    self._get_bounding_sphere_center(
      clustered_lights[i],
      _clustered_lights_node_vector3,
    )
    |> ignore
    _clustered_lights_node_vector3.apply_matrix4(view_matrix) |> ignore
    view_z.set(i, _clustered_lights_node_vector3.z)
    if i < order.length() {
      order[i] = i
    } else {
      order.push(i)
    }
  }
  order.truncate(count)
  @webgl.stable_sort_by(order, fn(a, b) { view_z.get(a) - view_z.get(b) })
  // Write sorted lights to texture
  for i in 0..<count {
    let light = clustered_lights[order[i]]
    let light_data = light.as_light()
    let offset = i * 4
    _clustered_lights_node_vector3.set_from_matrix_position(light.matrix_world)
    |> ignore
    let mut row_offset = line_size * CLUSTERED_LIGHTS_NODE_POSITION_ROW + offset
    data.set(row_offset + 0, _clustered_lights_node_vector3.x)
    data.set(row_offset + 1, _clustered_lights_node_vector3.y)
    data.set(row_offset + 2, _clustered_lights_node_vector3.z)
    data.set(row_offset + 3, clustered_lights_node_distance(light))
    row_offset = line_size * CLUSTERED_LIGHTS_NODE_COLOR_ROW + offset
    data.set(row_offset + 0, light_data.color.r * light_data.intensity)
    data.set(row_offset + 1, light_data.color.g * light_data.intensity)
    data.set(row_offset + 2, light_data.color.b * light_data.intensity)
    data.set(row_offset + 3, clustered_lights_node_decay(light))
    // The spot attenuation smoothstep( coneCos, penumbraCos, dot( L, direction ) ) is stored
    // as smoothstep( 0, 1, dot( L, direction * scale ) - coneCos * scale ) with
    // scale = 1 / ( penumbraCos - coneCos ). Point lights store a constant attenuation of 1.
    row_offset = line_size * CLUSTERED_LIGHTS_NODE_SPOT_ROW + offset
    match light_data.kind {
      SpotLight(spot) => {
        let cone_cos = clustered_lights_node_math_cos(spot.angle)
        let penumbra_cos = clustered_lights_node_math_cos(
          spot.angle * (1.0 - spot.penumbra),
        )
        let scale = 1.0 /
          clustered_lights_node_math_max(penumbra_cos - cone_cos, 1.0e-4)
        self
        ._get_spot_direction(light, _clustered_lights_node_direction)
        .multiply_scalar(scale)
        |> ignore
        data.set(row_offset + 0, _clustered_lights_node_direction.x)
        data.set(row_offset + 1, _clustered_lights_node_direction.y)
        data.set(row_offset + 2, _clustered_lights_node_direction.z)
        data.set(row_offset + 3, cone_cos * scale)
      }
      _ => {
        data.set(row_offset + 0, 0.0)
        data.set(row_offset + 1, 0.0)
        data.set(row_offset + 2, 0.0)
        data.set(row_offset + 3, -1.0)
      }
    }
    self._get_bounding_sphere_center(light, _clustered_lights_node_vector3)
    |> ignore
    row_offset = line_size * CLUSTERED_LIGHTS_NODE_BOUNDS_ROW + offset
    data.set(row_offset + 0, _clustered_lights_node_vector3.x)
    data.set(row_offset + 1, _clustered_lights_node_vector3.y)
    data.set(row_offset + 2, _clustered_lights_node_vector3.z)
    data.set(row_offset + 3, self._get_bounding_sphere_radius(light))
  }
  lights_texture.set_needs_update(true)
  // Compute per Z-slice light ranges
  let z_ranges = self._z_slice_ranges_data
  let near = @nodes.camera_near_of(camera)
  let far = @nodes.camera_far_of(camera)
  let nz = self.z_slices
  for z in 0..<nz {
    // Exponential Z-slice bounds (view-space, negative values)
    let slice_near = -(near *
      clustered_lights_node_math_pow(far / near, z.to_double() / nz.to_double()))
    let slice_far = -(near *
      clustered_lights_node_math_pow(
        far / near,
        (z + 1).to_double() / nz.to_double(),
      ))
    let mut range_start = count
    let mut range_end = 0
    for i in 0..<count {
      let vz = view_z.get(order[i])
      let r = data.get(line_size * CLUSTERED_LIGHTS_NODE_BOUNDS_ROW + i * 4 + 3)
      let radius = if r >= 0.0 { r } else { far }
      // Bounding sphere Z: [vz - radius, vz + radius]
      // Slice Z: [sliceFar, sliceNear] (both negative, sliceFar < sliceNear)
      if vz + radius >= slice_far && vz - radius <= slice_near {
        if i < range_start {
          range_start = i
        }
        if i + 1 > range_end {
          range_end = i + 1
        }
      }
    }
    if range_start >= count {
      range_start = 0
      range_end = 0
    }
    z_ranges.set(z * 4, range_start.to_double())
    z_ranges.set(z * 4 + 1, range_end.to_double())
  }
  self._z_slice_ranges_texture.set_needs_update(true)
}

///|
/// `light.distance` of a point or spot light.
fn clustered_lights_node_distance(light : @core.Object3D) -> Double {
  match light.as_light().kind {
    PointLight(p) => p.distance
    SpotLight(s) => s.distance
    _ => 0.0 / 0.0
  }
}

///|
/// `light.decay` of a point or spot light.
fn clustered_lights_node_decay(light : @core.Object3D) -> Double {
  match light.as_light().kind {
    PointLight(p) => p.decay
    SpotLight(s) => s.decay
    _ => 0.0 / 0.0
  }
}

///|
/// `_getSpotDirection( light, target )`: the normalized world-space direction from the
/// spot light's target to the light.
fn ClusteredLightsNode::_get_spot_direction(
  _self : ClusteredLightsNode,
  light : @core.Object3D,
  target : @math.Vector3,
) -> @math.Vector3 {
  _clustered_lights_node_target_position.set_from_matrix_position(
    light.light_target().matrix_world,
  )
  |> ignore
  target
  .set_from_matrix_position(light.matrix_world)
  .sub(_clustered_lights_node_target_position)
  .normalize()
}

///|
/// `_getBoundingSphereCenter( light, target )`: the world-space center of the light's
/// bounding sphere (for spot lights, of the smallest sphere enclosing the cone).
fn ClusteredLightsNode::_get_bounding_sphere_center(
  self : ClusteredLightsNode,
  light : @core.Object3D,
  target : @math.Vector3,
) -> @math.Vector3 {
  target.set_from_matrix_position(light.matrix_world) |> ignore
  if light.as_light().kind is SpotLight(spot) && spot.distance > 0.0 {
    let angle = clustered_lights_node_math_min(spot.angle, ADDON_PI / 2.0)
    let offset = if angle > ADDON_PI / 4.0 {
      spot.distance * clustered_lights_node_math_cos(angle)
    } else {
      spot.distance / (2.0 * clustered_lights_node_math_cos(angle))
    }
    // _getSpotDirection() points away from the cone, so step backwards
    target.add_scaled_vector(
      self._get_spot_direction(light, _clustered_lights_node_direction),
      -offset,
    )
    |> ignore
  }
  target
}

///|
/// `_getBoundingSphereRadius( light )`; `-1` if the light has no cutoff distance.
fn ClusteredLightsNode::_get_bounding_sphere_radius(
  _self : ClusteredLightsNode,
  light : @core.Object3D,
) -> Double {
  let distance = clustered_lights_node_distance(light)
  if distance <= 0.0 {
    return -1.0
  }
  if light.as_light().kind is SpotLight(spot) {
    let angle = clustered_lights_node_math_min(spot.angle, ADDON_PI / 2.0)
    return if angle > ADDON_PI / 4.0 {
      spot.distance * clustered_lights_node_math_sin(angle)
    } else {
      spot.distance / (2.0 * clustered_lights_node_math_cos(angle))
    }
  }
  distance
}

///|
/// `_isClusteredLight( light )`: point and spot lights shaded by the plain point and
/// spot light nodes, without shadows, color nodes or projected maps.
fn ClusteredLightsNode::_is_clustered_light(
  _self : ClusteredLightsNode,
  light : @core.Object3D,
) -> Bool {
  // Shadows, color nodes (any light) and projected maps (spot lights) are not supported.
  if light.cast_shadow == true || light.as_light().color_node is Some(_) {
    return false
  }
  // Only lights shaded by the plain point and spot light nodes are clustered. Subclasses
  // registered with their own light node (e.g. IESSpotLight, ProjectorLight) keep the
  // default lighting, since clustering would shade them as plain spot lights.
  let light_node = light.light_node()
  let is_light_node = fn(class_name : String) {
    match (light_node, @core.Light::light_node_of(class_name)) {
      (Some(a), Some(b)) => a.strict_equal(b)
      _ => false
    }
  }
  if is_light_node("PointLight") {
    return true
  }
  is_light_node("SpotLight") &&
  !(light.as_light().kind is SpotLight({ map: Some(_), .. }))
}

///|
/// `_getTile( element )`: the 1-based light index at a slot of the fragment's cluster
/// (`0` ends the list).
fn ClusteredLightsNode::_get_tile(
  self : ClusteredLightsNode,
  element : &@nodes.IntoTsl,
) -> @nodes.Node {
  let element = @nodes.int(element)
  let stride = @nodes.int(4)
  let chunk_offset = element.div(stride)
  let idx = self._screen_cluster_index
    .unwrap()
    .mul(@nodes.int(self._chunks_per_cluster))
    .add(chunk_offset)
  self._light_indexes.unwrap().element(idx).element(element.mod(stride))
}

///|
/// `getClusterLightCount( zSliceNode )`: the number of lights in the fragment's cluster
/// (or, for a non-negative `zSliceNode`, in that depth slice of the fragment's tile).
pub fn ClusteredLightsNode::get_cluster_light_count(
  node : @nodes.Node,
  z_slice_node : &@nodes.IntoTsl,
) -> @nodes.Node {
  let self = ClusteredLightsNode::of(node).unwrap()
  let get_count = @nodes.fn_(fn(inputs, _) {
    let z_slice_node = inputs.get(0).unwrap()
    let count = @nodes.int(0).to_var()
    let debug_cluster_index = self._screen_cluster_index.unwrap().to_var()
    @nodes.if_(z_slice_node.greater_than_equal(@nodes.int(0)), fn() {
      let tile_size = @nodes.int(self.tile_size)
      let screen_tile = @nodes.screen_coordinate.div(tile_size).floor()
      let nx = @nodes.int(self._grid_dimensions.x())
      let ny = @nodes.int(self._grid_dimensions.y())
      debug_cluster_index.assign(
        @nodes.int(screen_tile.x())
        .add(@nodes.int(screen_tile.y()).mul(nx))
        .add(z_slice_node.mul(nx.mul(ny))),
      )
    })
    |> ignore
    @nodes.loop_([self.max_lights_per_cluster], fn(inputs) {
      let i = inputs.named("i").unwrap()
      let element = @nodes.int(i)
      let stride = @nodes.int(4)
      let chunk_offset = element.div(stride)
      let idx = debug_cluster_index
        .mul(@nodes.int(self._chunks_per_cluster))
        .add(chunk_offset)
      let light_index = self._light_indexes
        .unwrap()
        .element(idx)
        .element(element.mod(stride))
      @nodes.if_(light_index.equal(@nodes.int(0)), fn() { @nodes.break_() })
      |> ignore
      count.add_assign(@nodes.int(1))
    })
    Some(count)
  })
  get_count.call([z_slice_node])
}

///|
/// `_getLightData( index )`: the light's view position, distance, color, decay,
/// view-space spot direction and spot offset.
fn ClusteredLightsNode::_get_light_data(
  self : ClusteredLightsNode,
  index : &@nodes.IntoTsl,
) -> ClusteredLightsNodeLightData {
  let index = @nodes.int(index)
  let data_a = @nodes.texture_load(
    self._lights_texture,
    uv_node=@nodes.ivec2_of([index, CLUSTERED_LIGHTS_NODE_POSITION_ROW]),
  )
  let data_b = @nodes.texture_load(
    self._lights_texture,
    uv_node=@nodes.ivec2_of([index, CLUSTERED_LIGHTS_NODE_COLOR_ROW]),
  )
  let data_c = @nodes.texture_load(
    self._lights_texture,
    uv_node=@nodes.ivec2_of([index, CLUSTERED_LIGHTS_NODE_SPOT_ROW]),
  )
  let view_position = self._camera_view_matrix
    .mul(@nodes.vec4_of([data_a.xyz(), 1.0]))
    .xyz()
  let distance = data_a.w()
  let color = data_b.rgb()
  let decay = data_b.w()
  let spot_direction = self._camera_view_matrix
    .mul(@nodes.vec4_of([data_c.xyz(), 0.0]))
    .xyz()
  let spot_offset = data_c.w()
  { view_position, distance, color, decay, spot_direction, spot_offset, }
}

///|
/// `_getLightBounds( index )`: the view-space center and radius of the light's
/// bounding sphere (a negative radius marks an unbounded light).
fn ClusteredLightsNode::_get_light_bounds(
  self : ClusteredLightsNode,
  index : &@nodes.IntoTsl,
) -> (@nodes.Node, @nodes.Node) {
  let data = @nodes.texture_load(
    self._lights_texture,
    uv_node=@nodes.ivec2_of([
      @nodes.int(index),
      CLUSTERED_LIGHTS_NODE_BOUNDS_ROW,
    ]),
  )
  let center = self._camera_view_matrix
    .mul(@nodes.vec4_of([data.xyz(), 1.0]))
    .xyz()
  let radius = data.w()
  (center, radius)
}

///|
/// `_getBufferFitSize( value )`: rounds up to a multiple of the tile size.
fn ClusteredLightsNode::_get_buffer_fit_size(
  self : ClusteredLightsNode,
  value : Double,
) -> Double {
  let multiple = self.tile_size.to_double()
  clustered_lights_node_math_ceil(value / multiple) * multiple
}

///|
/// `setSize( width, height )`: sets the grid size; must be called outside of rendering.
pub fn ClusteredLightsNode::set_size(
  node : @nodes.Node,
  width : Double,
  height : Double,
) -> @nodes.Node {
  let self = ClusteredLightsNode::of(node).unwrap()
  self._resize(
    node,
    self._get_buffer_fit_size(width),
    self._get_buffer_fit_size(height),
  )
  node
}

///|
/// `updateSize()`: fits the grid to the framebuffer of the render about to start.
pub fn ClusteredLightsNode::update_size(node : @nodes.Node) -> Unit {
  let self = ClusteredLightsNode::of(node).unwrap()
  if self._renderer is Some(renderer) {
    self._fit_to_renderer(node, renderer)
  }
}

///|
/// `_initGrid( renderer )`: creates the grid on first use (never rebuilt while
/// rendering).
pub fn ClusteredLightsNode::_init_grid(
  self : ClusteredLightsNode,
  node : @nodes.Node,
  renderer : @nodes.Renderer,
) -> Unit {
  self._renderer = Some(renderer)
  if self._compute is None {
    self._fit_to_renderer(node, renderer)
  }
}

///|
/// `_fitToRenderer( renderer )`: fits the grid to the framebuffer being rendered.
fn ClusteredLightsNode::_fit_to_renderer(
  self : ClusteredLightsNode,
  node : @nodes.Node,
  renderer : @nodes.Renderer,
) -> Unit {
  // the grid must match the framebuffer being rendered: a render target (e.g. a reflector
  // with a resolution scale) can differ from the drawing buffer
  match renderer.get_render_target() {
    Some(render_target) =>
      _clustered_lights_node_size.set(
        render_target.width.to_double(),
        render_target.height.to_double(),
      )
      |> ignore
    None =>
      renderer.get_drawing_buffer_size(_clustered_lights_node_size) |> ignore
  }
  // the compute differs per backend, so a backend change requires a rebuild
  let is_webgl_backend = renderer.backend.has_flag("isWebGLBackend") == true
  if self._compute is Some(_) && self._is_webgl_backend != is_webgl_backend {
    self._needs_rebuild = true
  }
  self._is_webgl_backend = is_webgl_backend
  self._resize(
    node,
    self._get_buffer_fit_size(_clustered_lights_node_size.x),
    self._get_buffer_fit_size(_clustered_lights_node_size.y),
  )
}

///|
/// `_resize( width, height )`: updates the grid uniforms and the compute count; the
/// storage and compute are rebuilt only when the storage must grow (or the backend
/// changed).
fn ClusteredLightsNode::_resize(
  self : ClusteredLightsNode,
  node : @nodes.Node,
  width : Double,
  height : Double,
) -> Unit {
  if self._needs_rebuild == false &&
    self._buffer_size is Some(size) &&
    size.x == width &&
    size.y == height {
    return
  }
  let nx = clustered_lights_node_math_floor(width / self.tile_size.to_double())
  let ny = clustered_lights_node_math_floor(height / self.tile_size.to_double())
  let cluster_count = (nx * ny * self.z_slices.to_double()).to_int()
  let required_elements = cluster_count * self._chunks_per_cluster
  let needs_create = self._needs_rebuild == true ||
    self._compute is None ||
    clustered_lights_node_storage_attribute(self._light_indexes.unwrap()).array
    .length()
    .to_double() /
    4.0 <
    required_elements.to_double()
  if needs_create {
    self._create(node, cluster_count)
  }
  match @nodes.InputNode::get_value(self._grid_dimensions) {
    Vector2(v) => v.set(nx, ny) |> ignore
    _ => ()
  }
  @nodes.ComputeNode::of(self._compute.unwrap()).unwrap().count = Some(
    cluster_count * self._invocations_per_cluster,
  )
  let buffer_size = match self._buffer_size {
    Some(s) => s
    None => {
      let s = @math.Vector2::new(0.0, 0.0)
      self._buffer_size = Some(s)
      s
    }
  }
  buffer_size.set(width, height) |> ignore
}

///|
/// `_create( clusterCount )`: the light index storage, the compute that fills it and
/// the fragment's cluster lookup.
fn ClusteredLightsNode::_create(
  self : ClusteredLightsNode,
  node : @nodes.Node,
  cluster_count : Int32,
) -> Unit {
  let { tile_size, z_slices, _chunks_per_cluster: chunks_per_cluster, .. } = self
  let nz = z_slices
  // grid dimensions as uniforms: shaders do not depend on the drawing buffer size
  let grid = self._grid_dimensions
  let nx = @nodes.int(grid.x())
  let ny = @nodes.int(grid.y())
  // Per-cluster light-index storage (ivec4 chunks), grown geometrically.
  let required_elements = cluster_count * chunks_per_cluster
  let previous_elements = match self._light_indexes {
    Some(n) =>
      clustered_lights_node_storage_attribute(n).array.length().to_double() /
      4.0
    None => 0.0
  }
  let elements = (if previous_elements == 0.0 {
    clustered_lights_node_math_ceil(required_elements.to_double() * 1.5)
  } else {
    clustered_lights_node_math_max(
      required_elements.to_double(),
      previous_elements * 2.0,
    )
  }).to_int()
  // rebuilds only happen outside of rendering (see _initGrid()), so the replaced resources can be freed
  if self._compute is Some(compute) {
    // Replacing storage requires new material bindings. The initial allocation does not.
    node.set_needs_update(true)
    compute.dispose()
    clustered_lights_node_storage_attribute(self._light_indexes.unwrap()).dispose()
  }
  // instanced storage: WebGL computes use gl_InstanceID as instanceIndex; PBO: random access in the fragment stage
  let light_indexes = @nodes.instanced_array(elements, type_="ivec4")
    .set_pbo(true)
    .set_name("lightIndexes")
  // view-space AABB of the given cluster
  let get_cluster_bounds = fn(cluster_index : @nodes.Node) {
    // view-space scale factors derived from the projection matrix:
    //   view_x = ndc_x * (-view_z) / focal_x = ndc_x * (-view_z) * invFocalX
    //   view_y = ndc_y * (-view_z) / focal_y = ndc_y * (-view_z) * invFocalY
    // where focal_x = projMatrix[0][0] and focal_y = projMatrix[1][1].
    let inv_focal_x = @nodes.float(1).div(
      self._camera_projection_matrix.element(0).element(0),
    )
    let inv_focal_y = @nodes.float(1).div(
      self._camera_projection_matrix.element(1).element(1),
    )
    // 3D cluster coordinates
    let cx = cluster_index.mod(nx)
    let cy = cluster_index.div(nx).mod(ny)
    let cz = cluster_index.div(nx.mul(ny))
    // NDC X/Y bounds of the cluster.
    // Y is flipped: cy=0 is the top screen row (fragment y=0), which is NDC y=+1.
    let ndc_xmin = @nodes.float(cx).mul(2.0).div(grid.x()).sub(1.0)
    let ndc_xmax = @nodes.float(cx.add(@nodes.int(1)))
      .mul(2.0)
      .div(grid.x())
      .sub(1.0)
    let ndc_ymax = @nodes.float(1).sub(@nodes.float(cy).mul(2.0).div(grid.y()))
    let ndc_ymin = @nodes.float(1).sub(
      @nodes.float(cy.add(@nodes.int(1))).mul(2.0).div(grid.y()),
    )
    // View-space Z bounds (negative, exponential slicing)
    let far_over_near = self._camera_far.div(self._camera_near)
    let z_near_cluster = self._camera_near
      .mul(
        @nodes.pow(far_over_near, @nodes.float(cz).mul(1.0 / nz.to_double())),
      )
      .negate()
    let z_far_cluster = self._camera_near
      .mul(
        @nodes.pow(
          far_over_near,
          @nodes.float(cz.add(@nodes.int(1))).mul(1.0 / nz.to_double()),
        ),
      )
      .negate()
    let scale_near_x = z_near_cluster.negate().mul(inv_focal_x)
    let scale_far_x = z_far_cluster.negate().mul(inv_focal_x)
    let scale_near_y = z_near_cluster.negate().mul(inv_focal_y)
    let scale_far_y = z_far_cluster.negate().mul(inv_focal_y)
    let x_min_near = ndc_xmin.mul(scale_near_x)
    let x_max_near = ndc_xmax.mul(scale_near_x)
    let x_min_far = ndc_xmin.mul(scale_far_x)
    let x_max_far = ndc_xmax.mul(scale_far_x)
    let y_min_near = ndc_ymin.mul(scale_near_y)
    let y_max_near = ndc_ymax.mul(scale_near_y)
    let y_min_far = ndc_ymin.mul(scale_far_y)
    let y_max_far = ndc_ymax.mul(scale_far_y)
    // AABB of the 8 view-space corners (tile boundaries can straddle the view axis)
    let aabb_min_x = @nodes.min(x_min_near, x_min_far)
    let aabb_max_x = @nodes.max(x_max_near, x_max_far)
    let aabb_min_y = @nodes.min(y_min_near, y_min_far)
    let aabb_max_y = @nodes.max(y_max_near, y_max_far)
    let aabb_min = @nodes.vec3_of([aabb_min_x, aabb_min_y, z_far_cluster])
    let aabb_max = @nodes.vec3_of([aabb_max_x, aabb_max_y, z_near_cluster])
    (cz, aabb_min, aabb_max)
  }
  // sphere-AABB intersection in view space
  let intersects_cluster = fn(
    light_idx : @nodes.Node,
    aabb_min : @nodes.Node,
    aabb_max : @nodes.Node,
  ) {
    let (center, radius) = self._get_light_bounds(light_idx)
    let closest = @nodes.max(aabb_min, @nodes.min(center, aabb_max))
    let diff = center.sub(closest)
    let dist_sq = @nodes.dot(diff, diff)
    radius.less_than(0).or(dist_sq.less_than_equal(radius.mul(radius)))
  }
  // Each invocation fills `chunksPerInvocation` ivec4 chunks of one cluster. WebGL computes
  // run via transform feedback and can only write their own element, so there each
  // invocation fills a single chunk; WebGPU uses one invocation per cluster.
  let chunks_per_invocation = if self._is_webgl_backend {
    1
  } else {
    chunks_per_cluster
  }
  let invocations_per_cluster = chunks_per_cluster / chunks_per_invocation
  self._invocations_per_cluster = invocations_per_cluster
  let is_webgl_backend = self._is_webgl_backend
  let compute = @nodes.fn_(fn(_, _) {
      let cluster_index = @nodes.int(
        @nodes.instance_index.div(invocations_per_cluster),
      )
      let first_chunk = @nodes.int(
        @nodes.instance_index.mod(invocations_per_cluster),
      ).mul(chunks_per_invocation)
      let first_slot = first_chunk.mul(4)
      let last_slot = first_slot.add(chunks_per_invocation * 4)
      let (cz, aabb_min, aabb_max) = get_cluster_bounds(cluster_index)
      let chunks = @nodes.ivec4(0).to_array(chunks_per_invocation).to_var()
      let index = @nodes.int(0).to_var()
      // Z-culling: only test lights that can reach this cluster's Z-slice
      let z_range = @nodes.texture_load(
        self._z_slice_ranges_texture,
        uv_node=@nodes.ivec2_of([cz, 0]),
      )
      let range_start = @nodes.int(z_range.x())
      let range_end = @nodes.int(z_range.y())
      @nodes.loop_([self.max_lights], fn(inputs) {
        let i = inputs.named("i").unwrap()
        let light_idx = range_start.add(i)
        @nodes.if_(
          index
          .greater_than_equal(last_slot)
          .or(light_idx.greater_than_equal(range_end)),
          fn() { @nodes.break_() },
        )
        |> ignore
        @nodes.if_(intersects_cluster(light_idx, aabb_min, aabb_max), fn() {
          // slots before firstSlot belong to other invocations of this cluster
          @nodes.if_(index.greater_than_equal(first_slot), fn() {
            let slot = index.sub(first_slot)
            chunks
            .element(slot.div(4))
            .element(slot.mod(4))
            .assign(light_idx.add(@nodes.int(1)))
          })
          |> ignore
          index.add_assign(@nodes.int(1))
        })
        |> ignore
      })
      let first_element = cluster_index.mul(chunks_per_cluster).add(first_chunk)
      let write_chunks = fn() {
        @nodes.loop_([chunks_per_invocation], fn(inputs) {
          let i = inputs.named("i").unwrap()
          light_indexes.element(first_element.add(i)).assign(chunks.element(i))
        })
      }
      if is_webgl_backend == true {
        // WebGL binds the transform feedback buffers per compute program, and programs are shared by
        // identical code. The (always true) capacity and node id constants give each node and storage
        // allocation its own program, so a compute never writes to the storage of another one.
        @nodes.if_(
          first_element
          .less_than(@nodes.int(elements))
          .and_(@nodes.int(node.id).not_equal(@nodes.int(-1))),
          write_chunks,
        )
        |> ignore
      } else {
        write_chunks()
      }
      None
    })
    .call([])
    .compute(cluster_count * invocations_per_cluster)
    .set_name("Update Clustered Lights")
  // shading-side: fragment → cluster index
  let get_screen_cluster_index = @nodes.fn_(fn(_, _) {
    let screen_tile = @nodes.screen_coordinate.div(tile_size).floor()
    // view-space depth from positionView (negative in front); take magnitude
    let view_depth = @nodes.position_view.z().negate()
    // exponential Z slice: tz = floor( log(depth/near) / log(far/near) * NZ )
    let inv_log_far_over_near = @nodes.float(1).div(
      @nodes.log(self._camera_far.div(self._camera_near)),
    )
    let slice_float = @nodes.log(view_depth.div(self._camera_near))
      .mul(inv_log_far_over_near)
      .mul(@nodes.float(nz))
    let z_slice = @nodes.clamp(
      slice_float.floor(),
      low=@nodes.float(0),
      high=@nodes.float(nz - 1),
    )
    Some(
      @nodes.int(screen_tile.x())
      .add(@nodes.int(screen_tile.y()).mul(nx))
      .add(@nodes.int(z_slice).mul(nx.mul(ny))),
    )
  })
  let screen_cluster_index = get_screen_cluster_index.call([]).to_var()
  // assigns
  self._light_indexes = Some(light_indexes)
  self._screen_cluster_index = Some(screen_cluster_index)
  self._compute = Some(compute)
  self._needs_rebuild = false
}

///|
/// The constructor body after `super()` (LightsNode).
pub fn ClusteredLightsNode::construct(
  node : @nodes.Node,
  max_lights : Int32,
  tile_size : Int32,
  z_slices : Int32,
  max_lights_per_cluster : Int32,
) -> ClusteredLightsNode {
  let lights = @nodes.LightsNode::construct(node)
  let lights_data = @core.TypedArray::new(
    Float32Array,
    max_lights * 4 * CLUSTERED_LIGHTS_NODE_ROWS,
  )
  let _lights_texture = @core.DataTexture::new(
    data=lights_data,
    width=max_lights,
    height=CLUSTERED_LIGHTS_NODE_ROWS,
    format=@core.RGBAFormat,
    type_=@core.FloatType,
  )
  // Per Z-slice light range for Z-culling (CPU-sorted, uploaded each frame)
  let _z_slice_ranges_data = @core.TypedArray::new(Float32Array, z_slices * 4)
  let _z_slice_ranges_texture = @core.DataTexture::new(
    data=_z_slice_ranges_data,
    width=z_slices,
    height=1,
    format=@core.RGBAFormat,
    type_=@core.FloatType,
  )
  let _light_view_z = @core.TypedArray::new(Float32Array, max_lights)
  let _lights_count = @nodes.uniform(0, type_="int")
  // Render-group uniforms: shared between compute and fragment passes,
  // updated manually each frame in updateBefore (compute lacks a camera context).
  let _camera_near = @nodes.uniform(0)
    .set_name("clusteredCameraNear")
    .set_group(@nodes.render_group)
  let _camera_far = @nodes.uniform(0)
    .set_name("clusteredCameraFar")
    .set_group(@nodes.render_group)
  let _camera_view_matrix = @nodes.uniform("mat4")
    .set_name("clusteredCameraViewMatrix")
    .set_group(@nodes.render_group)
  let _camera_projection_matrix = @nodes.uniform("mat4")
    .set_name("clusteredCameraProjectionMatrix")
    .set_group(@nodes.render_group)
  let _grid_dimensions = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  node.update_before_type = @nodes.NodeUpdateType::render()
  {
    lights,
    material_lights: [],
    clustered_lights: [],
    max_lights,
    tile_size,
    z_slices,
    max_lights_per_cluster,
    _chunks_per_cluster: clustered_lights_node_math_ceil(
      max_lights_per_cluster.to_double() / 4.0,
    ).to_int(),
    _buffer_size: None,
    _is_webgl_backend: false,
    _needs_rebuild: false,
    _invocations_per_cluster: 1,
    _light_indexes: None,
    _renderer: None,
    _screen_cluster_index: None,
    _compute: None,
    _lights_texture,
    _z_slice_ranges_data,
    _z_slice_ranges_texture,
    _light_view_z,
    _light_sort_order: [],
    _lights_count,
    _camera_near,
    _camera_far,
    _camera_view_matrix,
    _camera_projection_matrix,
    _grid_dimensions,
  }
}

///|
/// `new ClusteredLightsNode( maxLights = 1024, tileSize = 32, zSlices = 24,
/// maxLightsPerCluster = 64 )`.
pub fn ClusteredLightsNode::new(
  max_lights~ : Int32 = 1024,
  tile_size~ : Int32 = 32,
  z_slices~ : Int32 = 24,
  max_lights_per_cluster~ : Int32 = 64,
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec3")
  let payload = ClusteredLightsNode::construct(
    node, max_lights, tile_size, z_slices, max_lights_per_cluster,
  )
  payload.lights.class_ = payload
  node.set_class(payload)
}

///|
pub fn ClusteredLightsNode::of(node : @nodes.Node) -> ClusteredLightsNode? {
  addon_class_of(node, "ClusteredLightsNode")
}

///|
/// `clusteredLights( maxLights, tileSize, zSlices, maxLightsPerCluster )`.
pub fn clustered_lights(
  max_lights~ : Int32 = 1024,
  tile_size~ : Int32 = 32,
  z_slices~ : Int32 = 24,
  max_lights_per_cluster~ : Int32 = 64,
) -> @nodes.Node {
  ClusteredLightsNode::new(
    max_lights~,
    tile_size~,
    z_slices~,
    max_lights_per_cluster~,
  )
}
