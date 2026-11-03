// examples/jsm/tsl/shadows/TileShadowNodeHelper.js. A `Group`: `TileShadowNodeHelper::new`
// returns the `Object3D`, whose `Object3DExtension` payload holds the helper's data.

///|
/// Displays the tiles of a `TileShadowNode` (one plane per shadow map layer) and the
/// tile shadow cameras.
pub(all) struct TileShadowNodeHelper {
  tile_shadow_node : @nodes.Node
  config : TileShadowNodeConfig
  tiles : Array[TileShadowNodeTile]
  mut _debug_meshes : Array[@core.Object3D]
  mut _shadow_cam_helpers : Array[@core.Object3D?]
  mut initialized : Bool
  /// `this.scene`, which `dispose()` reads; never set by the helper itself.
  mut scene : @core.Object3D?
}

///|
pub impl @core.Object3DExtension for TileShadowNodeHelper with fn type_name(_) {
  "Group"
}

///|
/// `new this.constructor()` throws, as `new TileShadowNodeHelper()` does upstream.
pub impl @core.Object3DExtension for TileShadowNodeHelper with fn construct(_) {
  abort("THREE.TileShadowNode instance is required for TileShadowNodeHelper.")
}

///|
pub impl @core.Object3DExtension for TileShadowNodeHelper with fn has_flag(
  _,
  flag,
) {
  // not an upstream flag: identifies the payload for `TileShadowNodeHelper::of`
  flag == "TileShadowNodeHelper"
}

///|
/// `new TileShadowNodeHelper( tileShadowNode )`.
pub fn TileShadowNodeHelper::new(
  tile_shadow_node : @nodes.Node,
) -> @core.Object3D {
  let object = @core.Group::new()
  let tsn = TileShadowNode::of(tile_shadow_node).unwrap()
  object.set_extension(TileShadowNodeHelper::{
    tile_shadow_node,
    config: tsn.config,
    tiles: tsn.tiles,
    _debug_meshes: [],
    _shadow_cam_helpers: [],
    initialized: false,
    scene: None,
  })
}

///|
pub fn TileShadowNodeHelper::of(
  object : @core.Object3D,
) -> TileShadowNodeHelper? {
  match object.extension {
    Some(e) if e.has_flag("TileShadowNodeHelper") => Some(e.payload().cast())
    _ => None
  }
}

///|
/// `mesh.material`, a single material.
fn tile_shadow_node_helper_material(mesh : @core.Object3D) -> @core.Material {
  guard mesh.get_material() is Some(Single(material)) else {
    abort("TileShadowNodeHelper: not a single material")
  }
  material
}

///|
extern "js" fn tile_shadow_node_helper_math_floor(x : Double) -> Double = "Math.floor"

///|
/// `init()`: creates a display plane and a camera helper per tile. Call it after the
/// `TileShadowNode` has set up its tile lights and shadow nodes.
pub fn TileShadowNodeHelper::init(object : @core.Object3D) -> Unit {
  let self = TileShadowNodeHelper::of(object).unwrap()
  let tsn = TileShadowNode::of(self.tile_shadow_node).unwrap()
  if tsn._shadow_nodes.length() != self.tiles.length() {
    println(
      "Cannot initialize TileShadowNodeHelper: Shadow nodes not ready or mismatch count.",
    )
    return
  }
  let tiles_x = self.config.tiles_x
  let tiles_y = self.config.tiles_y
  // Clear previous helpers if any (e.g., during a re-init)
  TileShadowNodeHelper::dispose(object)
  // Create a display for each shadow map tile
  for i in 0..<self.tiles.length() {
    // Create display plane
    let display = @core.Mesh::new(
      geometry=@geometries.PlaneGeometry::new(width=1.0, height=1.0),
      material=Single(@nodes.NodeMaterial::new()),
    )
    let material = tile_shadow_node_helper_material(display)
    display.render_order = 9999999.0 // Ensure they appear on top
    material.transparent = true
    display.frustum_culled = false
    // upstream's `display.side = DoubleSide` sets a property no renderer reads
    material.depth_test = false // Disable depth testing
    material.depth_write = false // Disable depth writing
    let col = i % tiles_x
    let row = tile_shadow_node_helper_math_floor(
      i.to_double() / tiles_x.to_double(),
    )
    let node_material = @nodes.NodeMaterial::of(material).unwrap()
    // Vertex shader logic for positioning the debug quad
    node_material.vertex_node = Some(
      @nodes.fn_(fn(_, _) {
        let aspect_ratio = @nodes.screen_size.x().div(@nodes.screen_size.y())
        let max_tiles = if tiles_x > tiles_y { tiles_x } else { tiles_y }
        let display_size = @nodes.float(0.8 / max_tiles.to_double()) // Size adapts to number of tiles
        let margin = @nodes.float(0.01)
        let corner_offset = @nodes.float(0.05)
        // Position tiles left-to-right, top-to-bottom
        let x_base = @nodes.float(-1.0)
          .add(corner_offset)
          .add(display_size.div(2).div(aspect_ratio))
          .add(
            @nodes.float(col).mul(display_size.div(aspect_ratio).add(margin)),
          )
        let y_base = @nodes.float(1.0)
          .sub(corner_offset)
          .sub(display_size.div(2))
          .sub(@nodes.float(row).mul(display_size.add(margin)))
        let scaled_pos = @nodes.vec2_of([
          @nodes.position_local.x().mul(display_size.div(aspect_ratio)),
          @nodes.position_local.y().mul(display_size),
        ])
        let final_pos = @nodes.vec2_of([
          scaled_pos.x().add(x_base),
          scaled_pos.y().add(y_base),
        ])
        Some(@nodes.vec4_of([final_pos.x(), final_pos.y(), 0.0, 1.0]))
      }).call([]),
    )
    node_material.output_node = Some(
      @nodes.fn_(fn(_, _) {
        // Ensure shadowMap and depthTexture are available
        let depth_texture = match tsn.shadow_map {
          Some(map) => map.depth_texture()
          None => None
        }
        guard depth_texture is Some(depth_texture) else {
          return Some(@nodes.vec4_of([1, 0, 1, 1])) // Magenta error color
        }
        let sampled_depth = @nodes.texture(depth_texture)
          .sample(@nodes.uv().flip_y())
          .depth(@nodes.int(i)) // Sample correct layer
          .compare(0.9) // Example comparison value
        // Simple tint based on index for visual distinction
        let r = @nodes.float(0.5 + (i % 3).to_double() * 0.16)
        let g = @nodes.float(0.5 + (i % 2).to_double() * 0.25)
        let b = @nodes.float(0.7 + (i % 4).to_double() * 0.075)
        Some(
          @nodes.vec4_of([
            @nodes.vec3_of([r, g, b]).mul(sampled_depth).saturate().rgb(),
            1.0,
          ]),
        )
      }).call([]),
    )
    object.add(display) |> ignore
    self._debug_meshes.push(display)
    let shadow_node = tsn._shadow_nodes.get(i)
    match shadow_node {
      Some(n) if @nodes.ShadowNode::of(n) is Some(s) => {
        let cam_helper = @helpers.CameraHelper::new(s.shadow.camera)
        // upstream's `camHelper.fog = false` sets a property no renderer reads
        object.add(cam_helper) |> ignore
        self._shadow_cam_helpers.push(Some(cam_helper))
      }
      _ => {
        println(
          "TileShadowNodeHelper: Could not create CameraHelper for tile index \{i}. Shadow node or camera missing.",
        )
        self._shadow_cam_helpers.push(None)
      }
    }
  }
  self.initialized = true
}

///|
/// `update()`: initializes on first use and updates the camera helpers.
pub fn TileShadowNodeHelper::update(object : @core.Object3D) -> Unit {
  let self = TileShadowNodeHelper::of(object).unwrap()
  if self.initialized == false {
    TileShadowNodeHelper::init(object)
  }
  for helper in self._shadow_cam_helpers {
    if helper is Some(helper) {
      @helpers.CameraHelper::update(helper) // Update CameraHelper matrices
      helper.update_matrix_world(force=true) // Ensure world matrix is current
    }
  }
}

///|
/// `dispose()`: removes the display planes and camera helpers from `scene`.
pub fn TileShadowNodeHelper::dispose(object : @core.Object3D) -> Unit {
  let self = TileShadowNodeHelper::of(object).unwrap()
  if self.scene is Some(scene) {
    for mesh in self._debug_meshes {
      mesh.get_geometry().unwrap().dispose()
      tile_shadow_node_helper_material(mesh).dispose()
      scene.remove(mesh) |> ignore
    }
    for helper in self._shadow_cam_helpers {
      if helper is Some(helper) {
        scene.remove(helper) |> ignore
      }
    }
  }
  self._debug_meshes = []
  self._shadow_cam_helpers = []
}

///|
/// The display meshes (`_debugMeshes`).
pub fn TileShadowNodeHelper::debug_meshes(
  object : @core.Object3D,
) -> Array[@core.Object3D] {
  TileShadowNodeHelper::of(object).unwrap()._debug_meshes
}
