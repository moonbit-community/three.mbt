// materials/nodes/MeshMatcapNodeMaterial.js

///|
let mesh_matcap_node_material_defaults : @core.Material = @core.MeshMatcapMaterial::new()

///|
pub(all) struct MeshMatcapNodeMaterial {}

///|
pub impl NodeMaterialClass for MeshMatcapNodeMaterial with fn class_name(_) {
  "MeshMatcapNodeMaterial"
}

///|
pub impl NodeMaterialClass for MeshMatcapNodeMaterial with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
pub impl NodeMaterialClass for MeshMatcapNodeMaterial with fn has_flag(_, flag) {
  flag == "isMeshMatcapNodeMaterial" || flag == "isMeshMatcapMaterial"
}

///|
pub impl NodeMaterialClass for MeshMatcapNodeMaterial with fn construct(_) {
  MeshMatcapNodeMaterial::new()
}

///|
pub impl NodeMaterialClass for MeshMatcapNodeMaterial with fn setup_variants(
  _,
  _,
  builder,
) {
  let uv = matcap_uv
  let matcap_color = if node_material_builder_material(builder).matcap
    is Some(_) {
    material_reference("matcap", "texture").context(
      value=node_context([
        (
          "getUV",
          Other(@core.JsValue::of(ContextGetUV::{ f: fn(_, _) { uv }, })),
        ),
      ]),
    )
  } else {
    vec3(mix(0.2, 0.8, uv.y())) // default if matcap is missing
  }
  diffuse_color.rgb().mul_assign(matcap_color.rgb())
}

///|
/// `new MeshMatcapNodeMaterial()`.
pub fn MeshMatcapNodeMaterial::new() -> @core.Material {
  let material = NodeMaterial::create(MeshMatcapNodeMaterial::{ })
  NodeMaterial::set_default_values(material, mesh_matcap_node_material_defaults)
  material
}
