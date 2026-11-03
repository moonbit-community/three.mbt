// examples/jsm/tsl/shadows/TileShadowNode.js

///|
let _tile_shadow_node_renderer_state : Ref[@nodes.RendererState?] = Ref(None)

///|
let _tile_shadow_node_camera_layers : Array[Double] = []

///|
let _tile_shadow_node_vec3_temp1 : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _tile_shadow_node_vec3_temp2 : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _tile_shadow_node_vec3_temp3 : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _tile_shadow_node_quat_temp1 : @math.Quaternion = @math.Quaternion::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
/// `LightShadow.updateMatrices`' scratch vectors, for the tile lights.
let _tile_shadow_node_light_position_world : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _tile_shadow_node_look_target : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
extern "js" fn tile_shadow_node_js_and(a : Double, b : Double) -> Double = "(a, b) => a & b"

///|
extern "js" fn tile_shadow_node_js_or(a : Double, b : Double) -> Double = "(a, b) => a | b"

///|
/// `class LwLight extends Object3D`: a tile's light, an `Object3D` with a `target` and
/// the tile's `shadow`.
pub(all) struct TileShadowNodeLwLight {
  mut target : @core.Object3D
  mut shadow : @core.LightShadow?
}

///|
pub impl @core.Object3DExtension for TileShadowNodeLwLight with fn type_name(_) {
  "Object3D"
}

///|
pub impl @core.Object3DExtension for TileShadowNodeLwLight with fn construct(_) {
  TileShadowNodeLwLight::new()
}

///|
pub impl @core.Object3DExtension for TileShadowNodeLwLight with fn has_flag(
  _,
  flag,
) {
  // not an upstream flag: identifies the payload for `TileShadowNodeLwLight::of`
  flag == "TileShadowNode.LwLight"
}

///|
/// `new LwLight()`.
pub fn TileShadowNodeLwLight::new() -> @core.Object3D {
  let object = @core.Object3D::new()
  let target = @core.Object3D::new()
  object.set_extension(TileShadowNodeLwLight::{ target, shadow: None, })
}

///|
pub fn TileShadowNodeLwLight::of(
  object : @core.Object3D,
) -> TileShadowNodeLwLight? {
  match object.extension {
    Some(e) if e.has_flag("TileShadowNode.LwLight") => Some(e.payload().cast())
    _ => None
  }
}

///|
fn tile_shadow_node_lw(object : @core.Object3D) -> TileShadowNodeLwLight {
  TileShadowNodeLwLight::of(object).unwrap()
}

///|
/// `light.target` of the original light or of a tile light.
fn tile_shadow_node_target(light : @core.Object3D) -> @core.Object3D {
  match TileShadowNodeLwLight::of(light) {
    Some(lw) => lw.target
    None => light.light_target()
  }
}

///|
/// `shadow.updateMatrices( light )` for a tile light: `LightShadow.updateMatrices` with
/// the `LwLight`'s `target` (core's reads the target of core lights only).
fn tile_shadow_node_update_matrices(
  shadow : @core.LightShadow,
  light : @core.Object3D,
) -> Unit {
  if TileShadowNodeLwLight::of(light) is None {
    shadow.update_matrices(light)
    return
  }
  let shadow_camera = shadow.camera
  _tile_shadow_node_light_position_world.set_from_matrix_position(
    light.matrix_world,
  )
  |> ignore
  shadow_camera.position.copy(_tile_shadow_node_light_position_world) |> ignore
  _tile_shadow_node_look_target.set_from_matrix_position(
    tile_shadow_node_target(light).matrix_world,
  )
  |> ignore
  shadow_camera.look_at(_tile_shadow_node_look_target)
  shadow_camera.update_matrix_world()
  shadow._update_matrix(shadow_camera, shadow.matrix, shadow._frustum)
}

///|
/// The orthographic fields of a shadow camera.
fn tile_shadow_node_ortho(camera : @core.Object3D) -> @core.OrthographicCamera {
  match camera.as_camera().kind {
    OrthographicCamera(o) => o
    _ => abort("TileShadowNode: the shadow camera is not orthographic")
  }
}

///|
/// The tiled shadow configuration (`this.config`).
pub(all) struct TileShadowNodeConfig {
  tiles_x : Int32
  tiles_y : Int32
  resolution : @math.Vector2
  depth_type : Int32
  debug : Bool
}

///|
/// A tile: its `x` and `y` bounds in the full shadow camera, and its `index`.
pub(all) struct TileShadowNodeTile {
  x : (Double, Double)
  y : (Double, Double)
  index : Int32
}

///|
/// `this.shadowSize`.
pub(all) struct TileShadowNodeShadowSize {
  top : Double
  bottom : Double
  left : Double
  right : Double
}

///|
/// The class of a tile's shadow node: a `ShadowNode` whose `setupRenderTarget` returns
/// the shared array shadow map (upstream assigns it on the instance).
priv struct TileShadowNodeTileShadowClass {
  parent : @nodes.ShadowNode
  target : @nodes.ShadowRenderTarget
}

///|
impl @nodes.ShadowNodeClass for TileShadowNodeTileShadowClass with fn shadow_parent(
  self,
) {
  Some(self.parent)
}

///|
impl @nodes.ShadowNodeClass for TileShadowNodeTileShadowClass with fn setup_render_target(
  self,
  _,
  _,
  _,
) {
  self.target
}

///|
/// Tiled shadow mapping: splits a shadow map into tiles, each with its own light and
/// camera, rendered into the layers of one array shadow map.
pub(all) struct TileShadowNode {
  base : @nodes.ShadowBaseNode
  config : TileShadowNodeConfig
  mut debug : Bool
  original_light : @core.Object3D
  light_plane : @math.Plane
  line : @math.Line3
  initial_light_direction : @math.Vector3
  /// `this._cameraFrameId[ frame.camera ]`: a property of a `WeakMap` object keyed by
  /// `String( camera )`, which is `'[object Object]'` for every camera, so one slot.
  mut _camera_frame_id : Int32?
  shadow_size : TileShadowNodeShadowSize
  mut lights : Array[@core.Object3D]
  mut _shadow_nodes : Array[@nodes.Node]
  tiles : Array[TileShadowNodeTile]
  mut shadow_map : @core.RenderTarget?
  mut camera_array : @core.Object3D?
}

///|
pub impl @nodes.NodeClass for TileShadowNode with fn class_name(_) {
  "TileShadowNode"
}

///|
pub impl @nodes.NodeClass for TileShadowNode with fn type_name(_) {
  "ShadowBaseNode"
}

///|
pub impl @nodes.NodeClass for TileShadowNode with fn parent(self) {
  Some(self.base)
}

///|
pub impl @nodes.NodeClass for TileShadowNode with fn update(self, node, _) {
  TileShadowNode::update_tiles(self, node)
  None
}

///|
pub impl @nodes.NodeClass for TileShadowNode with fn update_before(
  self,
  node,
  frame,
) {
  let shadow = self.original_light.as_light().shadow.unwrap()
  let mut needs_update = shadow.needs_update || shadow.auto_update
  if needs_update {
    if self._camera_frame_id == Some(frame.frame_id) {
      needs_update = false
    }
    self._camera_frame_id = Some(frame.frame_id)
  }
  if needs_update {
    TileShadowNode::update_tiles(self, node)
    TileShadowNode::update_shadow(node, frame)
    shadow.needs_update = false
  }
  None
}

///|
pub impl @nodes.NodeClass for TileShadowNode with fn setup(self, node, builder) {
  if self.lights.length() == 0 {
    TileShadowNode::init(node, builder)
  }
  // Hardware-filtered depth comparisons for PCF, as in ShadowNode. The shadow type can change between
  // builds, so this is checked every time; disposing the shadow map recreates it with the new filter.
  let renderer = builder.renderer
  let filter = if renderer.shadow_map.type_ == @core.PCFShadowMap &&
    renderer.has_compatibility(@core.Compatibility_TEXTURE_COMPARE) {
    @core.LinearFilter
  } else {
    @core.NearestFilter
  }
  let depth_texture = self.shadow_map.unwrap().depth_texture().unwrap()
  if depth_texture.mag_filter != filter {
    depth_texture.min_filter = filter
    depth_texture.mag_filter = filter
    self.shadow_map.unwrap().dispose()
  }
  Some(
    @nodes.fn_(fn(_, builder) {
      self.base.setup_shadow_position(builder)
      // The fragment's position in the full shadow camera gives its tile and the coordinate within it.
      let { tiles_x, tiles_y, .. } = self.config
      let tile_shadow_node = self._shadow_nodes[0]
      let tile_shadow_payload = @nodes.ShadowNode::of(tile_shadow_node).unwrap()
      let tile_shadow = tile_shadow_node_lw(self.lights[0]).shadow.unwrap()
      let shadow = self.original_light.as_light().shadow.unwrap()
      let normal_bias = @nodes.ReferenceNode::set_group(
        @nodes.shadow_reference("normalBias", "float", shadow),
        @nodes.render_group,
      )
      let shadow_position = @nodes.light_shadow_matrix(self.original_light).mul(
        @nodes.vec4_of([
          @nodes.shadow_position_world.add(@nodes.normal_world.mul(normal_bias)),
          1,
        ]),
      )
      let shadow_coord = tile_shadow_payload.class_.setup_shadow_coord(
        tile_shadow_node, builder, shadow_position,
      )
      let grid = shadow_coord.xy().mul(@nodes.vec2_of([tiles_x, tiles_y])) // tiles start from the top row
      let tile = grid
        .floor()
        .clamp(
          low=@nodes.vec2(0),
          high=@nodes.vec2_of([tiles_x - 1, tiles_y - 1]),
        )
      let depth_layer = @nodes.int(tile.y().mul(tiles_x).add(tile.x()))
      let tile_coord = @nodes.vec3_of([grid.sub(tile), shadow_coord.z()])
      let filter_fn = match tile_shadow.filter_node {
        Some(f) => Some((f.cast() : @nodes.Node))
        None =>
          tile_shadow_payload.class_.get_shadow_filter_fn(
            tile_shadow_node,
            builder.renderer.shadow_map.type_,
          )
      }
      guard filter_fn is Some(filter_fn) else {
        abort("TypeError: filterFn is not a function")
      }
      let shadow_value = tile_shadow_node_setup_shadow_filter(
        filter_fn, depth_texture, tile_coord, tile_shadow, depth_layer,
      )
      let shadow_intensity = @nodes.ReferenceNode::set_group(
        @nodes.shadow_reference("intensity", "float", shadow),
        @nodes.render_group,
      )
      let mut shadow_output = if builder.renderer.shadow_map.transmitted == true {
        let shadow_color = @nodes.texture(
          self.shadow_map.unwrap().texture(),
          uv_node=tile_coord,
        ).depth(depth_layer)
        @nodes.mix(
          1,
          shadow_value.rgb().mix(shadow_color, 1),
          shadow_intensity.mul(shadow_color.a()),
        ).to_var(name="shadowValue")
      } else {
        @nodes.mix(1, shadow_value, shadow_intensity).to_var(name="shadowValue")
      }
      // As in ShadowNode.setup(), which the tiles no longer go through.
      match @nodes.NodeMaterial::of(builder.material.unwrap()) {
        Some({ received_shadow_node: Some(received), .. }) =>
          shadow_output = received.call([shadow_output])
        _ => ()
      }
      Some(shadow_output)
    }).call([]),
  )
}

///|
pub impl @nodes.NodeClass for TileShadowNode with fn dispose(self, node) {
  // Dispose lights, nodes, and shadow map
  TileShadowNode::dispose_lights_and_nodes(node)
  self.base.dispose_shadow_material()
  @nodes.NodeClass::dispose(self.base, node)
}

///|
/// `ShadowNode.prototype.setupShadowFilter( builder, { filterFn, depthTexture,
/// shadowCoord, shadow, depthLayer } )` of the first tile's shadow node, with the tile
/// layer as a node (`ShadowFilterInputs` holds a constant layer).
fn tile_shadow_node_setup_shadow_filter(
  filter_fn : @nodes.Node,
  depth_texture : @core.Texture,
  shadow_coord : @nodes.Node,
  shadow : @core.LightShadow,
  depth_layer : @nodes.Node,
) -> @nodes.Node {
  let frustum_test = shadow_coord
    .x()
    .greater_than_equal(0)
    .and_(shadow_coord.x().less_than_equal(1))
    .and_(shadow_coord.y().greater_than_equal(0))
    .and_(shadow_coord.y().less_than_equal(1))
    .and_(shadow_coord.z().less_than_equal(1))
  let shadow_node = filter_fn.call([
    @nodes.TslValue::Object({
      "depthTexture": Texture(depth_texture),
      "shadowCoord": Node(shadow_coord),
      "shadow": @nodes.shadow_filter_shadow_value(shadow),
      "depthLayer": Node(depth_layer),
    }),
  ])
  frustum_test.select(shadow_node, else_node=@nodes.float(1))
}

///|
/// `generateTiles( tilesX, tilesY )`: the tile bounds, starting from the top row.
pub fn TileShadowNode::generate_tiles(
  tiles_x : Int32,
  tiles_y : Int32,
) -> Array[TileShadowNodeTile] {
  let tiles = []
  let tile_width = 1.0 / tiles_x.to_double()
  let tile_height = 1.0 / tiles_y.to_double()
  for y in 0..<tiles_y {
    for x in 0..<tiles_x {
      tiles.push({
        x: (x.to_double() * tile_width, (x + 1).to_double() * tile_width),
        y: (
          (tiles_y - 1 - y).to_double() * tile_height,
          (tiles_y - y).to_double() * tile_height,
        ), // Start from top row
        index: y * tiles_x + x,
      })
    }
  }
  tiles
}

///|
/// `updateLightDirection()`: from the light to its target.
pub fn TileShadowNode::update_light_direction(self : TileShadowNode) -> Unit {
  self.initial_light_direction
  .sub_vectors(
    tile_shadow_node_target(self.original_light).get_world_position(
      @math.Vector3::new(0.0, 0.0, 0.0),
    ),
    self.original_light.get_world_position(@math.Vector3::new(0.0, 0.0, 0.0)),
  )
  .normalize()
  |> ignore
}

///|
/// `init( builder )`: creates the array shadow map and a light, camera and shadow node
/// for each tile.
pub fn TileShadowNode::init(
  node : @nodes.Node,
  builder : @nodes.NodeBuilder,
) -> Unit {
  let self = TileShadowNode::of(node).unwrap()
  let light = self.original_light
  let light_shadow = light.as_light().shadow.unwrap()
  let parent = light.parent
  let width = self.shadow_size.right - self.shadow_size.left
  let height = self.shadow_size.top - self.shadow_size.bottom
  let tile_count = self.tiles.length()
  let shadow_width = self.config.resolution.x.to_int()
  let shadow_height = self.config.resolution.y.to_int()
  // Clear existing lights/nodes if re-initializing
  TileShadowNode::dispose_lights_and_nodes(node)
  let depth_texture = @core.DepthTexture::new(
    width=shadow_width,
    height=shadow_height,
    type_=self.config.depth_type,
    depth=tile_count,
  )
  depth_texture.compare_function = Some(
    if builder.renderer.reversed_depth_buffer {
      @core.GreaterEqualCompare
    } else {
      @core.LessCompare
    },
  )
  depth_texture.name = "ShadowDepthArrayTexture"
  // The color attachment is only sampled for transmitted shadows.
  let count = if builder.renderer.shadow_map.transmitted == true {
    1
  } else {
    0
  }
  let shadow_map = builder.create_render_target(
    shadow_width,
    shadow_height,
    options=@nodes.RenderTargetOptions::new(
      count~,
      format=@core.RedFormat,
      depth=tile_count,
    ),
  )
  shadow_map.use_array_depth_texture = true
  shadow_map.set_depth_texture(Some(depth_texture))
  if count > 0 {
    shadow_map.texture().name = "ShadowTexture"
  }
  self.shadow_map = Some(shadow_map)
  let cameras = []
  // Create lights, one for each tile
  for i in 0..<tile_count {
    let lw_light = TileShadowNodeLwLight::new()
    lw_light.cast_shadow = true
    let l_shadow = light_shadow.clone()
    l_shadow.filter_node = light_shadow.filter_node
    let tile = self.tiles[i]
    let camera = tile_shadow_node_ortho(l_shadow.camera)
    camera.left = self.shadow_size.left + width * tile.x.0
    camera.right = self.shadow_size.left + width * tile.x.1
    camera.top = self.shadow_size.bottom + height * tile.y.1
    camera.bottom = self.shadow_size.bottom + height * tile.y.0
    l_shadow.bias = light_shadow.bias
    let light_camera = tile_shadow_node_ortho(light_shadow.camera)
    camera.near = light_camera.near
    camera.far = light_camera.far
    l_shadow.camera.user_data.set("tileIndex", @core.JsValue::of(i))
    tile_shadow_node_lw(lw_light).shadow = Some(l_shadow)
    match parent {
      Some(parent) => {
        parent.add(lw_light) |> ignore
        parent.add(tile_shadow_node_lw(lw_light).target) |> ignore
      }
      None =>
        println(
          "TileShadowNode: Original light has no parent during init. Tile lights not added to scene graph directly.",
        )
    }
    TileShadowNode::sync_light_transformation(lw_light, light)
    self.lights.push(lw_light)
    l_shadow.camera.update_matrix_world()
    cameras.push(l_shadow.camera)
    let shadow_node = @nodes.shadow(lw_light, shadow=l_shadow)
    let shadow_payload = @nodes.ShadowNode::of(shadow_node).unwrap()
    shadow_payload.depth_layer = i
    shadow_node.update_before_type = @nodes.NodeUpdateType::none()
    shadow_payload.class_ = TileShadowNodeTileShadowClass::{
      parent: shadow_payload,
      target: { shadow_map, depth_texture, },
    }
    self._shadow_nodes.push(shadow_node)
  }
  let camera_array = @core.ArrayCamera::new(array=cameras)
  self.camera_array = Some(camera_array)
  // setup() reads depth through this camera.
  light_shadow.camera.as_camera().coordinate_system = builder.renderer.coordinate_system()
  light_shadow.camera.as_camera()._reversed_depth = builder.renderer.reversed_depth_buffer
}

///|
/// `update()`: syncs the tile lights with the light and fits the tile cameras into
/// the light's shadow camera.
pub fn TileShadowNode::update_tiles(
  self : TileShadowNode,
  _node : @nodes.Node,
) -> Unit {
  let light = self.original_light
  let light_shadow = light.as_light().shadow.unwrap()
  let shadow_cam = tile_shadow_node_ortho(light_shadow.camera)
  let ls_min = @math.Vector2::new(shadow_cam.left, shadow_cam.bottom)
  let ls_max = @math.Vector2::new(shadow_cam.right, shadow_cam.top)
  let full_width = ls_max.x - ls_min.x
  let full_height = ls_max.y - ls_min.y
  for i in 0..<self.lights.length() {
    let lw_light = self.lights[i]
    let tile = self.tiles[i]
    TileShadowNode::sync_light_transformation(lw_light, light)
    let l_shadow = tile_shadow_node_lw(lw_light).shadow.unwrap()
    let tile_left = ls_min.x + tile.x.0 * full_width
    let tile_right = ls_min.x + tile.x.1 * full_width
    let tile_bottom = ls_min.y + tile.y.0 * full_height
    let tile_top = ls_min.y + tile.y.1 * full_height
    let camera = tile_shadow_node_ortho(l_shadow.camera)
    camera.left = tile_left
    camera.right = tile_right
    camera.bottom = tile_bottom
    camera.top = tile_top
    camera.near = shadow_cam.near
    camera.far = shadow_cam.far
    l_shadow.camera.update_projection_matrix()
    l_shadow.camera.update_world_matrix(true, false)
    l_shadow.camera.update_matrix_world(force=true)
    @nodes.ShadowNode::of(self._shadow_nodes[i]).unwrap().shadow.needs_update = true
  }
  // The original light does not render a shadow map, but setup() uses its shadow matrix.
  light_shadow.camera.update_projection_matrix()
  light_shadow.update_matrices(light)
}

///|
/// `updateShadow( frame )`: renders every tile into its layer of the shadow map.
pub fn TileShadowNode::update_shadow(
  node : @nodes.Node,
  frame : @nodes.NodeFrame,
) -> Unit {
  let self = TileShadowNode::of(node).unwrap()
  let shadow_map = self.shadow_map.unwrap()
  let light = self.base.light
  let renderer = frame.renderer.unwrap()
  let scene = frame.scene.unwrap()
  let camera = frame.camera.unwrap()
  let camera_array = self.camera_array.unwrap()
  let shadow_type = renderer.shadow_map.type_
  let current_render_object_function = renderer.get_render_object_function()
  _tile_shadow_node_renderer_state.val = Some(
    @nodes.reset_renderer_and_scene_state(
      renderer,
      scene,
      state?=_tile_shadow_node_renderer_state.val,
    ),
  )
  scene.as_scene().override_material = Some(self.base.get_shadow_material())
  renderer.set_render_target(self.shadow_map)
  let camera_array_layers = camera_array.layers.mask
  camera_array.layers.mask = 0.0
  for index in 0..<self.lights.length() {
    let light = self.lights[index]
    let shadow = tile_shadow_node_lw(light).shadow.unwrap()
    let _shadow_camera_layer = shadow.camera.layers.mask
    _tile_shadow_node_camera_layers.push(_shadow_camera_layer)
    if tile_shadow_node_js_and(shadow.camera.layers.mask, 0xFFFFFFFE) == 0.0 {
      shadow.camera.layers.mask = camera.layers.mask
    }
    tile_shadow_node_update_matrices(shadow, light)
    // The tiles render through the array camera, so it has to see every tile's layers.
    camera_array.layers.mask = tile_shadow_node_js_or(
      camera_array.layers.mask,
      shadow.camera.layers.mask,
    )
    renderer.set_render_object_function(
      Some(self.base.get_shadow_render_object_function(renderer, shadow~)),
    )
    shadow_map.set_size(
      shadow.map_size.x.to_int(),
      shadow.map_size.y.to_int(),
      depth=shadow_map.depth,
    )
  }
  renderer.render(scene, camera_array)
  renderer.set_render_object_function(current_render_object_function)
  if !(light.as_light().kind is PointLight(_)) &&
    shadow_type == @core.VSMShadowMap {
    println("THREE.TileShadowNode: VSM shadow map is not supported yet.")
    // this.vsmPass( renderer );
  }
  @nodes.restore_renderer_and_scene_state(
    renderer,
    scene,
    _tile_shadow_node_renderer_state.val.unwrap(),
  )
  camera_array.layers.mask = camera_array_layers
  for index in 0..<self.lights.length() {
    let light = self.lights[index]
    let shadow = tile_shadow_node_lw(light).shadow.unwrap()
    shadow.camera.layers.mask = _tile_shadow_node_camera_layers[index]
  }
  _tile_shadow_node_camera_layers.clear()
}

///|
/// `syncLightTransformation( lwLight, sourceLight )`: copies the source light's world
/// transform (and its target's position) to a tile light.
pub fn TileShadowNode::sync_light_transformation(
  lw_light : @core.Object3D,
  source_light : @core.Object3D,
) -> Unit {
  let lw = tile_shadow_node_lw(lw_light)
  let source_world_pos = source_light.get_world_position(
    _tile_shadow_node_vec3_temp1,
  )
  let target_world_pos = tile_shadow_node_target(source_light).get_world_position(
    _tile_shadow_node_vec3_temp2,
  )
  let forward = _tile_shadow_node_vec3_temp3.sub_vectors(
    target_world_pos, source_world_pos,
  )
  let target_distance = forward.length()
  forward.normalize() |> ignore
  lw_light.position.copy(source_world_pos) |> ignore
  lw.target.position
  .copy(source_world_pos)
  .add(forward.multiply_scalar(target_distance))
  |> ignore
  lw_light.quaternion.copy(
    source_light.get_world_quaternion(_tile_shadow_node_quat_temp1),
  )
  |> ignore
  lw_light.scale.copy(source_light.scale) |> ignore
  lw_light.update_matrix()
  lw_light.update_matrix_world(force=true)
  lw.target.update_matrix()
  lw.target.update_matrix_world(force=true)
}

///|
/// `disposeLightsAndNodes()`: removes the tile lights and frees the shadow map.
pub fn TileShadowNode::dispose_lights_and_nodes(node : @nodes.Node) -> Unit {
  let self = TileShadowNode::of(node).unwrap()
  for light in self.lights {
    if light.parent is Some(parent) {
      parent.remove(tile_shadow_node_lw(light).target) |> ignore
      parent.remove(light) |> ignore
    }
  }
  self.lights = []
  self._shadow_nodes = []
  if self.shadow_map is Some(shadow_map) {
    shadow_map.dispose() // Disposes render target and textures
    self.shadow_map = None
  }
}

///|
/// The tile lights' shadow nodes (`_shadowNodes`).
pub fn TileShadowNode::shadow_nodes(node : @nodes.Node) -> Array[@nodes.Node] {
  TileShadowNode::of(node).unwrap()._shadow_nodes
}

///|
/// The constructor body after `super( light )`.
pub fn TileShadowNode::construct(
  node : @nodes.Node,
  light : @core.Object3D,
  tiles_x : Int32?,
  tiles_y : Int32?,
  resolution : @math.Vector2?,
  depth_type : Int32?,
  debug : Bool?,
) -> TileShadowNode {
  let base = @nodes.ShadowBaseNode::construct(node, light)
  let light_shadow = light.as_light().shadow.unwrap()
  // `options.x || default`
  let or_default = fn(v : Int32?, d : Int32) {
    match v {
      Some(v) if v != 0 => v
      _ => d
    }
  }
  // Default configuration with sensible defaults
  let config : TileShadowNodeConfig = {
    tiles_x: or_default(tiles_x, 2),
    tiles_y: or_default(tiles_y, 2),
    resolution: match resolution {
      Some(r) => r
      None => light_shadow.map_size
    },
    depth_type: or_default(depth_type, @core.UnsignedIntType),
    debug: match debug {
      Some(d) => d
      None => false
    },
  }
  let camera = tile_shadow_node_ortho(light_shadow.camera)
  let self : TileShadowNode = {
    base,
    config,
    debug: config.debug,
    original_light: light,
    light_plane: @math.Plane::new(
      normal=@math.Vector3::new(0.0, 1.0, 0.0),
      constant=0.0,
    ),
    line: @math.Line3::new(),
    initial_light_direction: @math.Vector3::new(0.0, 0.0, 0.0),
    _camera_frame_id: None,
    shadow_size: {
      top: camera.top,
      bottom: camera.bottom,
      left: camera.left,
      right: camera.right,
    },
    lights: [],
    _shadow_nodes: [],
    tiles: TileShadowNode::generate_tiles(config.tiles_x, config.tiles_y),
    shadow_map: None,
    camera_array: None,
  }
  self.update_light_direction()
  self
}

///|
/// `new TileShadowNode( light, options )`, with the options as labelled arguments.
pub fn TileShadowNode::new(
  light : @core.Object3D,
  tiles_x? : Int32,
  tiles_y? : Int32,
  resolution? : @math.Vector2,
  depth_type? : Int32,
  debug? : Bool,
) -> @nodes.Node {
  let node = @nodes.Node::alloc()
  node.set_class(
    TileShadowNode::construct(
      node, light, tiles_x, tiles_y, resolution, depth_type, debug,
    ),
  )
}

///|
pub fn TileShadowNode::of(node : @nodes.Node) -> TileShadowNode? {
  addon_class_of(node, "TileShadowNode")
}
