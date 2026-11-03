// materials/nodes/LineDashedNodeMaterial.js

///|
let line_dashed_node_material_defaults : @core.Material = @core.LineDashedMaterial::new()

///|
pub(all) struct LineDashedNodeMaterial {
  /// The dash offset.
  mut dash_offset : Double
  mut offset_node : Node?
  mut dash_scale_node : Node?
  mut dash_size_node : Node?
  mut gap_size_node : Node?
}

///|
pub impl NodeMaterialClass for LineDashedNodeMaterial with fn class_name(_) {
  "LineDashedNodeMaterial"
}

///|
pub impl NodeMaterialClass for LineDashedNodeMaterial with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
pub impl NodeMaterialClass for LineDashedNodeMaterial with fn has_flag(_, flag) {
  flag == "isLineDashedNodeMaterial" ||
  flag == "isLineDashedMaterial" ||
  flag == "isLineBasicMaterial"
}

///|
pub impl NodeMaterialClass for LineDashedNodeMaterial with fn construct(_) {
  LineDashedNodeMaterial::new()
}

///|
pub impl NodeMaterialClass for LineDashedNodeMaterial with fn node_slot(
  self,
  name,
) {
  match name {
    "offsetNode" => Some(self.offset_node)
    "dashScaleNode" => Some(self.dash_scale_node)
    "dashSizeNode" => Some(self.dash_size_node)
    "gapSizeNode" => Some(self.gap_size_node)
    _ => None
  }
}

///|
pub impl NodeMaterialClass for LineDashedNodeMaterial with fn own_node_slots(
  self,
  out,
) {
  out.push(("offsetNode", self.offset_node))
  out.push(("dashScaleNode", self.dash_scale_node))
  out.push(("dashSizeNode", self.dash_size_node))
  out.push(("gapSizeNode", self.gap_size_node))
}

///|
pub impl NodeMaterialClass for LineDashedNodeMaterial with fn set_node_slot(
  self,
  name,
  value,
) {
  match name {
    "offsetNode" => self.offset_node = value
    "dashScaleNode" => self.dash_scale_node = value
    "dashSizeNode" => self.dash_size_node = value
    "gapSizeNode" => self.gap_size_node = value
    _ => return false
  }
  true
}

///|
pub impl NodeMaterialClass for LineDashedNodeMaterial with fn get_property(
  self,
  material,
  name,
) {
  match name {
    "dashOffset" => Some(Number(self.dash_offset))
    _ =>
      match self.node_slot(name) {
        Some(slot) => Some(node_material_slot_value(slot))
        None => BaseNodeMaterial::{ }.get_property(material, name)
      }
  }
}

///|
pub impl NodeMaterialClass for LineDashedNodeMaterial with fn reference_value(
  self,
  _,
  key,
) {
  match key {
    "dashOffset" => Some(Number(self.dash_offset))
    _ => None
  }
}

///|
pub impl NodeMaterialClass for LineDashedNodeMaterial with fn copy_members(
  self,
  _,
  source,
) {
  if LineDashedNodeMaterial::of(source) is Some(s) {
    self.dash_offset = s.dash_offset
  }
}

///|
pub impl NodeMaterialClass for LineDashedNodeMaterial with fn setup_variants(
  self,
  _,
  _,
) {
  let offset_node = match self.offset_node {
    Some(o) => float(o)
    None => material_line_dash_offset
  }
  let dash_scale_node = match self.dash_scale_node {
    Some(d) => float(d)
    None => material_line_scale
  }
  let dash_size_node = match self.dash_size_node {
    Some(d) => float(d)
    None => material_line_dash_size
  }
  let gap_size_node = match self.gap_size_node {
    Some(g) => float(g)
    None => material_line_gap_size
  }
  dash_size.assign(dash_size_node)
  gap_size.assign(gap_size_node)
  let v_line_distance = varying(attribute("lineDistance").mul(dash_scale_node))
  let v_line_distance_offset = v_line_distance.add(offset_node)
  v_line_distance_offset
  .mod(dash_size.add(gap_size))
  .greater_than(dash_size)
  .discard()
}

///|
/// `new LineDashedNodeMaterial()`.
pub fn LineDashedNodeMaterial::new() -> @core.Material {
  let material = NodeMaterial::create(LineDashedNodeMaterial::{
    dash_offset: 0,
    offset_node: None,
    dash_scale_node: None,
    dash_size_node: None,
    gap_size_node: None,
  })
  NodeMaterial::set_default_values(material, line_dashed_node_material_defaults)
  material
}

///|
pub fn LineDashedNodeMaterial::of(
  material : @core.Material,
) -> LineDashedNodeMaterial? {
  match NodeMaterial::class_payload(material, "LineDashedNodeMaterial") {
    Some(p) => Some(p.cast())
    None => None
  }
}
