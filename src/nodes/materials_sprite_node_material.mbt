// materials/nodes/SpriteNodeMaterial.js

///|
let sprite_node_material_defaults : @core.Material = @core.SpriteMaterial::new()

///|
/// `sizeAttenuation` is the core `size_attenuation` field (upstream's
/// `_useSizeAttenuation` behind the accessor).
pub(all) struct SpriteNodeMaterial {
  /// The rotation of the sprite in radians.
  mut rotation_node : Node?
  /// The scale of the sprite.
  mut scale_node : Node?
}

///|
pub impl NodeMaterialClass for SpriteNodeMaterial with fn class_name(_) {
  "SpriteNodeMaterial"
}

///|
pub impl NodeMaterialClass for SpriteNodeMaterial with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
pub impl NodeMaterialClass for SpriteNodeMaterial with fn has_flag(_, flag) {
  flag == "isSpriteNodeMaterial" || flag == "isSpriteMaterial"
}

///|
pub impl NodeMaterialClass for SpriteNodeMaterial with fn construct(_) {
  SpriteNodeMaterial::new()
}

///|
pub impl NodeMaterialClass for SpriteNodeMaterial with fn node_slot(self, name) {
  match name {
    "rotationNode" => Some(self.rotation_node)
    "scaleNode" => Some(self.scale_node)
    _ => None
  }
}

///|
pub impl NodeMaterialClass for SpriteNodeMaterial with fn own_node_slots(
  self,
  out,
) {
  out.push(("rotationNode", self.rotation_node))
  out.push(("scaleNode", self.scale_node))
}

///|
pub impl NodeMaterialClass for SpriteNodeMaterial with fn set_node_slot(
  self,
  name,
  value,
) {
  match name {
    "rotationNode" => self.rotation_node = value
    "scaleNode" => self.scale_node = value
    _ => return false
  }
  true
}

///|
pub impl NodeMaterialClass for SpriteNodeMaterial with fn get_property(
  self,
  material,
  name,
) {
  match name {
    "sizeAttenuation" =>
      Some(Bool(SpriteNodeMaterial::size_attenuation(material)))
    _ =>
      match self.node_slot(name) {
        Some(slot) => Some(node_material_slot_value(slot))
        None => BaseNodeMaterial::{ }.get_property(material, name)
      }
  }
}

///|
/// The `sizeAttenuation` accessor of `copy( source )` (bumps the version on change).
pub impl NodeMaterialClass for SpriteNodeMaterial with fn copy_members(
  _,
  material,
  source,
) {
  if source.size_attenuation is Some(value) {
    SpriteNodeMaterial::set_size_attenuation(material, value)
  }
}

///|
pub impl NodeMaterialClass for SpriteNodeMaterial with fn setup_position_view(
  self,
  material,
  builder,
) {
  let object = node_material_builder_object(builder)
  let camera = node_material_builder_camera(builder)
  let position_node = NodeMaterial::payload_of(material).position_node
  let mv_position = model_view_matrix.mul(
    match position_node {
      Some(p) => vec3(p)
      None => vec3(0)
    },
  )
  let mut scale = vec2_of([
    model_world_matrix[0].xyz().length(),
    model_world_matrix[1].xyz().length(),
  ])
  if self.scale_node is Some(scale_node) {
    scale = scale.mul(vec2(scale_node))
  }
  if camera.is_orthographic_camera() != true &&
    SpriteNodeMaterial::size_attenuation(material) == false {
    scale = scale.mul(mv_position.z().negate())
  }
  let mut aligned_position = position_geometry.xy()
  if node_material_observer_center(object) is Some(_) {
    let center = reference_base("center", "vec2")
    aligned_position = aligned_position.sub(center.sub(0.5))
  }
  aligned_position = aligned_position.mul(scale)
  let rotation = float(
    match self.rotation_node {
      Some(r) => r
      None => material_rotation
    },
  )
  let rotated_position = rotate(aligned_position, rotation)
  vec4_of([mv_position.xy().add(rotated_position), mv_position.zw()])
}

///|
/// `get sizeAttenuation()`.
pub fn SpriteNodeMaterial::size_attenuation(material : @core.Material) -> Bool {
  material.size_attenuation == Some(true)
}

///|
/// `set sizeAttenuation( value )`: bumps the version when the value changes.
pub fn SpriteNodeMaterial::set_size_attenuation(
  material : @core.Material,
  value : Bool,
) -> Unit {
  if material.size_attenuation != Some(value) {
    material.size_attenuation = Some(value)
    material.set_needs_update(true)
  }
}

///|
/// The payload of a new `SpriteNodeMaterial`, for subclasses.
pub fn SpriteNodeMaterial::construct() -> SpriteNodeMaterial {
  { rotation_node: None, scale_node: None, }
}

///|
/// The constructor body after `super()`.
pub fn SpriteNodeMaterial::init(material : @core.Material) -> Unit {
  material.size_attenuation = Some(true)
  NodeMaterial::payload_of(material).position_node = None
  material.transparent = true
  NodeMaterial::set_default_values(material, sprite_node_material_defaults)
}

///|
/// `new SpriteNodeMaterial()`.
pub fn SpriteNodeMaterial::new() -> @core.Material {
  let material = NodeMaterial::create(SpriteNodeMaterial::construct())
  SpriteNodeMaterial::init(material)
  material
}

///|
pub fn SpriteNodeMaterial::of(material : @core.Material) -> SpriteNodeMaterial? {
  match NodeMaterial::class_payload(material, "SpriteNodeMaterial") {
    Some(p) => Some(p.cast())
    None => None
  }
}
