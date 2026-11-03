// nodes/lighting/RectAreaLightNode.js

///|
let rect_area_light_node_matrix4 : @math.Matrix4 = @math.Matrix4::new()

///|
/// The BRDF approximation textures of `RectAreaLightTexturesLib` (`setLTC( ltc )`).
pub(all) struct RectAreaLightLtc {
  ltc_float_1 : @core.Texture
  ltc_float_2 : @core.Texture
  ltc_half_1 : @core.Texture
  ltc_half_2 : @core.Texture
}

///|
/// `_ltcLib`.
let rect_area_light_node_ltc_lib : Ref[RectAreaLightLtc?] = Ref(None)

///|
pub(all) struct RectAreaLightNode {
  analytic : AnalyticLightNode
  half_height : Node
  half_width : Node
  /// The values of `halfHeight` and `halfWidth`.
  half_height_value : @math.Vector3
  half_width_value : @math.Vector3
}

///|
pub impl NodeClass for RectAreaLightNode with fn class_name(_) {
  "RectAreaLightNode"
}

///|
pub impl NodeClass for RectAreaLightNode with fn parent(self) {
  Some(self.analytic)
}

///|
pub impl NodeClass for RectAreaLightNode with fn children(self, node, out) {
  NodeClass::children(self.analytic, node, out)
  push_child(out, "halfHeight", Some(self.half_height))
  push_child(out, "halfWidth", Some(self.half_width))
}

///|
pub impl NodeClass for RectAreaLightNode with fn update(self, node, frame) {
  NodeClass::update(self.analytic, node, frame) |> ignore
  let light = self.analytic.light.unwrap()
  guard light.as_light().kind is RectAreaLight(rect) else { return None }
  rect_area_light_node_matrix4.extract_rotation(light.matrix_world) |> ignore
  self.half_width_value.set(rect.width * 0.5, 0.0, 0.0) |> ignore
  self.half_height_value.set(0.0, rect.height * 0.5, 0.0) |> ignore
  self.half_width_value.apply_matrix4(rect_area_light_node_matrix4) |> ignore
  self.half_height_value.apply_matrix4(rect_area_light_node_matrix4) |> ignore
  None
}

///|
pub impl AnalyticLightNodeClass for RectAreaLightNode with fn analytic_parent(
  self,
) {
  Some(self.analytic)
}

///|
pub impl AnalyticLightNodeClass for RectAreaLightNode with fn setup_direct_rect_area(
  self,
  _,
  builder,
) {
  let ltc_lib = match rect_area_light_node_ltc_lib.val {
    Some(l) => l
    None =>
      abort("TypeError: Cannot read properties of null (reading 'LTC_HALF_1')")
  }
  let (ltc_1, ltc_2) = if builder.is_available("float32Filterable") {
    (texture(ltc_lib.ltc_float_1), texture(ltc_lib.ltc_float_2))
  } else {
    (texture(ltc_lib.ltc_half_1), texture(ltc_lib.ltc_half_2))
  }
  let color_node = self.analytic.color_node.unwrap()
  let light = self.analytic.light.unwrap()
  let light_position = light_view_position(light)
  let half_width = camera_view_matrix.mul(vec4_of([self.half_width, 0])).xyz()
  let half_height = camera_view_matrix.mul(vec4_of([self.half_height, 0])).xyz()
  Some({
    light_direction: None,
    light_color: Some(color_node),
    light_position: Some(light_position),
    half_width: Some(half_width),
    half_height: Some(half_height),
    ltc_1: Some(ltc_1),
    ltc_2: Some(ltc_2),
    light_node: None,
    reflected_light: None,
  })
}

///|
/// `new RectAreaLightNode( light = null )`.
pub fn RectAreaLightNode::new(light? : @core.Object3D) -> Node {
  let node = AnalyticLightNode::alloc()
  let analytic = AnalyticLightNode::construct(node, light)
  let half_height_value = @math.Vector3::new(0.0, 0.0, 0.0)
  let half_width_value = @math.Vector3::new(0.0, 0.0, 0.0)
  let half_height = uniform(half_height_value).set_group(render_group)
  let half_width = uniform(half_width_value).set_group(render_group)
  node.update_type = NodeUpdateType::render()
  let payload = RectAreaLightNode::{
    analytic,
    half_height,
    half_width,
    half_height_value,
    half_width_value,
  }
  payload.analytic.class_ = payload
  node.set_class(payload)
}

///|
pub fn RectAreaLightNode::of(node : Node) -> RectAreaLightNode? {
  match node.class_payload("RectAreaLightNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `RectAreaLightNode.setLTC( ltc )`.
pub fn RectAreaLightNode::set_ltc(ltc : RectAreaLightLtc) -> Unit {
  rect_area_light_node_ltc_lib.val = Some(ltc)
}

///|
/// The value `RectAreaLight.registerNode( RectAreaLightNode )` stores.
pub fn RectAreaLightNode::node_class() -> @core.JsValue {
  @core.JsValue::of(LightNodeClass::{
    create: fn(light) { RectAreaLightNode::new(light~) },
  })
}
