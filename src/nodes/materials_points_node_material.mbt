// materials/nodes/PointsNodeMaterial.js

///|
let points_node_material_defaults : @core.Material = @core.PointsMaterial::new()

///|
let points_node_material_size : @math.Vector2 = @math.Vector2::new(0, 0)

///|
/// Half the canvas height in logical units, for size attenuation.
let points_node_material_scale : Node = module_nodes(
  "materials/nodes/PointsNodeMaterial.js:scale",
  fn() {
    uniform(1)
    .set_group(render_group)
    .on_render_update(fn(n, frame) {
      match frame.renderer {
        Some(renderer) => {
          let size_y = renderer.get_size(points_node_material_size).y // logical units
          InputNode::set_value(n, Number(0.5 * size_y))
        }
        None =>
          abort("TypeError: Cannot read properties of null (reading 'getSize')")
      }
      None
    })
  },
)

///|
/// `alphaToCoverage` is the core `alpha_to_coverage` field (upstream's
/// `_useAlphaToCoverage` behind the accessor).
pub(all) struct PointsNodeMaterial {
  sprite : SpriteNodeMaterial
  /// The size of the points (`null` takes `material.size`).
  mut size_node : Node?
}

///|
pub impl NodeMaterialClass for PointsNodeMaterial with fn class_name(_) {
  "PointsNodeMaterial"
}

///|
pub impl NodeMaterialClass for PointsNodeMaterial with fn parent(self) {
  Some(self.sprite)
}

///|
pub impl NodeMaterialClass for PointsNodeMaterial with fn has_flag(self, flag) {
  flag == "isPointsNodeMaterial" ||
  flag == "isPointsMaterial" ||
  self.sprite.has_flag(flag)
}

///|
pub impl NodeMaterialClass for PointsNodeMaterial with fn construct(_) {
  PointsNodeMaterial::new()
}

///|
pub impl NodeMaterialClass for PointsNodeMaterial with fn node_slot(self, name) {
  match name {
    "sizeNode" => Some(self.size_node)
    _ => self.sprite.node_slot(name)
  }
}

///|
pub impl NodeMaterialClass for PointsNodeMaterial with fn own_node_slots(
  self,
  out,
) {
  self.sprite.own_node_slots(out)
  out.push(("sizeNode", self.size_node))
}

///|
pub impl NodeMaterialClass for PointsNodeMaterial with fn set_node_slot(
  self,
  name,
  value,
) {
  match name {
    "sizeNode" => self.size_node = value
    _ => return self.sprite.set_node_slot(name, value)
  }
  true
}

///|
pub impl NodeMaterialClass for PointsNodeMaterial with fn get_property(
  self,
  material,
  name,
) {
  match name {
    "sizeNode" => Some(node_material_slot_value(self.size_node))
    "alphaToCoverage" => Some(Bool(material.alpha_to_coverage))
    _ => self.sprite.get_property(material, name)
  }
}

///|
pub impl NodeMaterialClass for PointsNodeMaterial with fn setup_position_view(
  _,
  material,
  _,
) {
  let position_node = NodeMaterial::payload_of(material).position_node
  model_view_matrix
  .mul(
    vec3(
      match position_node {
        Some(p) => p
        None => position_local
      },
    ),
  )
  .xyz()
}

///|
/// `setupVertexSprite( builder )`.
pub fn PointsNodeMaterial::setup_vertex_sprite(
  self : PointsNodeMaterial,
  material : @core.Material,
  builder : NodeBuilder,
) -> Node {
  let builder_material = node_material_builder_material(builder)
  let camera = node_material_builder_camera(builder)
  let rotation_node = self.sprite.rotation_node
  let scale_node = self.sprite.scale_node
  let size_node = self.size_node
  let size_attenuation = SpriteNodeMaterial::size_attenuation(material)
  let mut mvp = self.sprite.setup_vertex(material, builder)
  // skip further processing if the material is not a node material
  if builder_material.is_node_material() != true {
    return mvp
  }
  // point size
  let mut point_size = match size_node {
    Some(s) => vec2(s)
    None => material_point_size
  }
  point_size = point_size.mul(screen_dpr)
  // size attenuation
  if camera.is_orthographic_camera() != true && size_attenuation == true {
    // follow WebGLRenderer's implementation, and scale by half the canvas height in
    // logical units
    point_size = point_size.mul(
      points_node_material_scale.div(position_view.z().negate()),
    )
  }
  // scale
  if scale_node is Some(scale_node) {
    point_size = point_size.mul(vec2(scale_node))
  }
  // compute offset
  let mut offset = position_geometry.xy()
  // apply rotation
  if rotation_node is Some(rotation_node) {
    let rotation = float(rotation_node)
    offset = rotate(offset, rotation)
  }
  // account for point size
  offset = offset.mul(point_size)
  // scale by viewport size
  offset = offset.div(viewport_size.div(2))
  // compensate for the perspective divide
  offset = offset.mul(mvp.w())
  // add offset
  mvp = mvp.add(vec4_of([offset, 0, 0]))
  mvp
}

///|
pub impl NodeMaterialClass for PointsNodeMaterial with fn setup_vertex(
  self,
  material,
  builder,
) {
  if node_material_builder_object(builder).is_points() {
    self.sprite.setup_vertex(material, builder)
  } else {
    self.setup_vertex_sprite(material, builder)
  }
}

///|
/// `set alphaToCoverage( value )`: bumps the version when the value changes.
pub fn PointsNodeMaterial::set_alpha_to_coverage(
  material : @core.Material,
  value : Bool,
) -> Unit {
  if material.alpha_to_coverage != value {
    material.alpha_to_coverage = value
    material.set_needs_update(true)
  }
}

///|
/// `new PointsNodeMaterial()`.
pub fn PointsNodeMaterial::new() -> @core.Material {
  let material = NodeMaterial::create(PointsNodeMaterial::{
    sprite: SpriteNodeMaterial::construct(),
    size_node: None,
  })
  SpriteNodeMaterial::init(material)
  NodeMaterial::set_default_values(material, points_node_material_defaults)
  material
}

///|
pub fn PointsNodeMaterial::of(material : @core.Material) -> PointsNodeMaterial? {
  match NodeMaterial::class_payload(material, "PointsNodeMaterial") {
    Some(p) => Some(p.cast())
    None => None
  }
}
