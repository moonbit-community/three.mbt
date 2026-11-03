// Upstream examples/jsm/objects/Water2Mesh.js (its class is also called `WaterMesh`;
// here `Water2Mesh`): the flowing water of Water2.js for WebGPURenderer, a `WaterNode`
// color node mixing a `reflector()` and the viewport behind the surface.

///|
/// `Water2Mesh` adds no state of its own; the payload marks the class.
pub(all) struct Water2Mesh {}

///|
pub impl @core.Object3DExtension for Water2Mesh with fn type_name(_) {
  "Mesh"
}

///|
pub impl @core.Object3DExtension for Water2Mesh with fn construct(_) {
  Water2Mesh::new(None)
}

///|
pub impl @core.Object3DExtension for Water2Mesh with fn has_flag(_, flag) {
  flag == "isWater" || flag == "class:Water2Mesh"
}

///|
#deprecated
pub extend Water2Mesh with @core.Object3DExtension::{
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
/// The payload of a Water2Mesh.js `WaterMesh`, or `None` for other objects.
pub fn Water2Mesh::of(object : @core.Object3D) -> Water2Mesh? {
  objects_payload(object, "class:Water2Mesh")
}

///|
/// `new WaterMesh( geometry, options )` of Water2Mesh.js. `color` is a hex (default
/// `0xffffff`); maps left out are upstream's `texture( undefined )`.
pub fn Water2Mesh::new(
  geometry : @core.BufferGeometry?,
  normal_map0? : @core.Texture,
  normal_map1? : @core.Texture,
  flow_map? : @core.Texture,
  color? : Int32,
  flow_direction? : @math.Vector2,
  flow_speed~ : Double = 0.03,
  reflectivity~ : Double = 0.02,
  scale~ : Double = 1.0,
) -> @core.Object3D {
  let material = @nodes.NodeMaterial::new()
  material.transparent = true
  let object = @core.Mesh::new(geometry?, material=Single(material))
  object.set_extension(Water2Mesh::{ }) |> ignore
  @nodes.NodeMaterial::of(material).unwrap().color_node = Some(
    WaterNode::new(
      object,
      normal_map0?,
      normal_map1?,
      flow_map?,
      color?,
      flow_direction?,
      flow_speed~,
      reflectivity~,
      scale~,
    ),
  )
  object
}

///|
/// The `WaterNode` of Water2Mesh.js: the water color, updated before each render.
pub(all) struct WaterNode {
  water_body : @core.Object3D
  normal_map0 : @nodes.Node
  normal_map1 : @nodes.Node
  flow_map : @nodes.Node
  color : @nodes.Node
  flow_direction : @nodes.Node
  flow_speed : @nodes.Node
  reflectivity : @nodes.Node
  scale : @nodes.Node
  flow_config : @nodes.Node
  _cycle : Double
  _half_cycle : Double
  _use_flow : Bool
}

///|
pub impl @nodes.NodeClass for WaterNode with fn class_name(_) {
  "WaterNode"
}

///|
pub impl @nodes.NodeClass for WaterNode with fn children(self, _, out) {
  @nodes.push_child(out, "normalMap0", Some(self.normal_map0))
  @nodes.push_child(out, "normalMap1", Some(self.normal_map1))
  @nodes.push_child(out, "flowMap", Some(self.flow_map))
  @nodes.push_child(out, "color", Some(self.color))
  @nodes.push_child(out, "flowDirection", Some(self.flow_direction))
  @nodes.push_child(out, "flowSpeed", Some(self.flow_speed))
  @nodes.push_child(out, "reflectivity", Some(self.reflectivity))
  @nodes.push_child(out, "scale", Some(self.scale))
  @nodes.push_child(out, "flowConfig", Some(self.flow_config))
}

///|
pub impl @nodes.NodeClass for WaterNode with fn update_before(self, _, frame) {
  self.update_flow(frame.delta_time)
  None
}

///|
pub impl @nodes.NodeClass for WaterNode with fn setup(self, _, _) {
  let output_node = @nodes.fn_(fn(_, _) {
    let flow_map_offset0 = self.flow_config.x()
    let flow_map_offset1 = self.flow_config.y()
    let half_cycle = self.flow_config.z()
    let to_eye = @nodes.normalize(
      @nodes.camera_position.sub(@nodes.position_world),
    )
    let flow = if self._use_flow {
      self.flow_map.rg().mul(2).sub(1)
    } else {
      @nodes.vec2_of([self.flow_direction.x(), self.flow_direction.y()])
    }
    flow.x().mul_assign(-1)
    // sample normal maps (distort uvs with flowdata)
    let uvs = @nodes.uv()
    let normal_uv0 = uvs.mul(self.scale).add(flow.mul(flow_map_offset0))
    let normal_uv1 = uvs.mul(self.scale).add(flow.mul(flow_map_offset1))
    let normal_color0 = self.normal_map0.sample(normal_uv0)
    let normal_color1 = self.normal_map1.sample(normal_uv1)
    // linear interpolate to get the final normal color
    let flow_lerp = @nodes.abs(half_cycle.sub(flow_map_offset0)).div(half_cycle)
    let normal_color = @nodes.mix(normal_color0, normal_color1, flow_lerp)
    // calculate normal vector
    let normal = @nodes.normalize(
      @nodes.vec3_of([
        normal_color.r().mul(2).sub(1),
        normal_color.b(),
        normal_color.g().mul(2).sub(1),
      ]),
    )
    // calculate the fresnel term to blend reflection and refraction maps
    let theta = @nodes.max(@nodes.dot(to_eye, normal), 0)
    let reflectance = @nodes.pow(@nodes.float(1.0).sub(theta), 5.0)
      .mul(@nodes.float(1.0).sub(self.reflectivity))
      .add(self.reflectivity)
    // reflector, refractor
    let offset = normal.xz().mul(0.05).to_var()
    let reflection_sampler = @nodes.reflector()
    self.water_body.add(@nodes.ReflectorNode::target(reflection_sampler))
    |> ignore
    let sampler = @nodes.TextureNode::of(reflection_sampler).unwrap()
    sampler.uv_node = Some(sampler.uv_node.unwrap().add(offset))
    let refractor_uv = @nodes.screen_uv.add(offset)
    let refraction_sampler = @nodes.viewport_shared_texture(
      uv_node=@nodes.viewport_safe_uv.call([refractor_uv]),
    )
    // calculate final uv coords
    Some(
      @nodes.vec4_of([self.color, 1.0]).mul(
        @nodes.mix(refraction_sampler, reflection_sampler, reflectance),
      ),
    )
  }).call([])
  Some(output_node)
}

///|
/// `new WaterNode( options, waterBody )`.
pub fn WaterNode::new(
  water_body : @core.Object3D,
  normal_map0? : @core.Texture,
  normal_map1? : @core.Texture,
  flow_map? : @core.Texture,
  color? : Int32,
  flow_direction? : @math.Vector2,
  flow_speed~ : Double = 0.03,
  reflectivity~ : Double = 0.02,
  scale~ : Double = 1.0,
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  let water : WaterNode = {
    water_body,
    normal_map0: objects_texture_node(normal_map0),
    normal_map1: objects_texture_node(normal_map1),
    flow_map: objects_texture_node(flow_map),
    color: @nodes.uniform(
      match color {
        Some(hex) => @math.Color::from_hex(hex)
        None => @math.Color::from_hex(0xffffff)
      },
    ),
    flow_direction: @nodes.uniform(
      match flow_direction {
        Some(v) => v
        None => @math.Vector2::new(1.0, 0.0)
      },
    ),
    flow_speed: @nodes.uniform(flow_speed),
    reflectivity: @nodes.uniform(reflectivity),
    scale: @nodes.uniform(scale),
    flow_config: @nodes.uniform(@math.Vector3::new(0.0, 0.0, 0.0)),
    _cycle: 0.15, // a cycle of a flow map phase
    _half_cycle: 0.15 * 0.5,
    _use_flow: flow_map is Some(_),
  }
  node.update_before_type = @nodes.NodeUpdateType::render()
  node.set_class(water)
}

///|
pub fn WaterNode::of(node : @nodes.Node) -> WaterNode? {
  match node.class_payload("WaterNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `updateFlow( delta )`: advances the two flow map offsets, half a cycle apart.
pub fn WaterNode::update_flow(self : WaterNode, delta : Double) -> Unit {
  let config = match @nodes.InputNode::get_value(self.flow_config) {
    Vector3(v) => v
    _ => abort("TypeError: flowConfig.value is not a Vector3")
  }
  let flow_speed = match @nodes.InputNode::get_value(self.flow_speed) {
    Number(v) => v
    _ => 0.0 / 0.0
  }
  config.x += flow_speed * delta // flowMapOffset0
  config.y = config.x + self._half_cycle // flowMapOffset1
  // Important: The distance between offsets should be always the value of "halfCycle".
  // Moreover, both offsets should be in the range of [ 0, cycle ].
  // This approach ensures a smooth water flow and avoids "reset" effects.
  if config.x >= self._cycle {
    config.x = 0.0
    config.y = self._half_cycle
  } else if config.y >= self._cycle {
    config.y = config.y - self._cycle
  }
  config.z = self._half_cycle
}
