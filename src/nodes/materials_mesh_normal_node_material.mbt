// materials/nodes/MeshNormalNodeMaterial.js

///|
let mesh_normal_node_material_defaults : @core.Material = @core.MeshNormalMaterial::new()

///|
pub(all) struct MeshNormalNodeMaterial {}

///|
pub impl NodeMaterialClass for MeshNormalNodeMaterial with fn class_name(_) {
  "MeshNormalNodeMaterial"
}

///|
pub impl NodeMaterialClass for MeshNormalNodeMaterial with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
pub impl NodeMaterialClass for MeshNormalNodeMaterial with fn has_flag(_, flag) {
  flag == "isMeshNormalNodeMaterial" || flag == "isMeshNormalMaterial"
}

///|
pub impl NodeMaterialClass for MeshNormalNodeMaterial with fn construct(_) {
  MeshNormalNodeMaterial::new()
}

///|
/// By convention, a normal packed to RGB is in sRGB color space; it is converted to
/// the working color space.
pub impl NodeMaterialClass for MeshNormalNodeMaterial with fn setup_diffuse_color(
  _,
  material,
  _,
) {
  let opacity_node = match NodeMaterial::payload_of(material).opacity_node {
    Some(o) => float(o)
    None => material_opacity
  }
  diffuse_color.assign(
    color_space_to_working(
      vec4_of([pack_normal_to_rgb(normal_view), opacity_node]),
      @core.SRGBColorSpace,
    ),
  )
}

///|
/// `new MeshNormalNodeMaterial()`.
pub fn MeshNormalNodeMaterial::new() -> @core.Material {
  let material = NodeMaterial::create(MeshNormalNodeMaterial::{ })
  NodeMaterial::set_default_values(material, mesh_normal_node_material_defaults)
  material
}
