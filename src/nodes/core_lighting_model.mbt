// nodes/core/LightingModel.js: the base of BasicLightingModel, PhysicalLightingModel,
// ... Subclasses implement `LightingModelClass`; every default is the base body.

///|
/// The overridable methods of `LightingModel`.
pub(open) trait LightingModelClass {
  /// The JS class name.
  fn class_name(Self) -> String
  /// The payload as a JS value, so `X::of` can cast it back.
  fn payload(Self) -> @core.JsValue = _
  /// The superclass payload, `None` for direct subclasses of `LightingModel`.
  fn parent(Self) -> &LightingModelClass? = _
  /// `start( builder )`: sets up the direct lights, then the indirect light.
  fn start(Self, LightingModel, NodeBuilder) -> Unit = _
  /// `finish( builder )`.
  fn finish(Self, LightingModel, NodeBuilder) -> Unit = _
  /// `direct( lightData, builder )`.
  fn direct(Self, LightingModel, @core.JsValue, NodeBuilder) -> Unit = _
  /// `directRectArea( lightData, builder )`.
  fn direct_rect_area(Self, LightingModel, @core.JsValue, NodeBuilder) -> Unit = _
  /// `indirect( builder )`.
  fn indirect(Self, LightingModel, NodeBuilder) -> Unit = _
  /// `ambientOcclusion( builder )`.
  fn ambient_occlusion(Self, LightingModel, NodeBuilder) -> Unit = _
}

///|
impl LightingModelClass with fn payload(self) {
  @core.JsValue::of(self)
}

///|
impl LightingModelClass with fn parent(_) {
  None
}

///|
impl LightingModelClass with fn start(self, model, builder) {
  match self.parent() {
    Some(p) => p.start(model, builder)
    None => model.start_base(builder)
  }
}

///|
impl LightingModelClass with fn finish(self, model, builder) {
  match self.parent() {
    Some(p) => p.finish(model, builder)
    None => ()
  }
}

///|
impl LightingModelClass with fn direct(self, model, light_data, builder) {
  match self.parent() {
    Some(p) => p.direct(model, light_data, builder)
    None => ()
  }
}

///|
impl LightingModelClass with fn direct_rect_area(
  self,
  model,
  light_data,
  builder,
) {
  match self.parent() {
    Some(p) => p.direct_rect_area(model, light_data, builder)
    None => ()
  }
}

///|
impl LightingModelClass with fn indirect(self, model, builder) {
  match self.parent() {
    Some(p) => p.indirect(model, builder)
    None => ()
  }
}

///|
impl LightingModelClass with fn ambient_occlusion(self, model, builder) {
  match self.parent() {
    Some(p) => p.ambient_occlusion(model, builder)
    None => ()
  }
}

///|
/// The class of a plain `new LightingModel()`.
pub(all) struct BaseLightingModel {}

///|
pub impl LightingModelClass for BaseLightingModel with fn class_name(_) {
  "LightingModel"
}

///|
/// A lighting model; `class_` is the most derived class payload.
pub(all) struct LightingModel {
  mut class_ : &LightingModelClass
}

///|
/// `new LightingModel()`; subclasses pass their class payload.
pub fn LightingModel::new(class_? : &LightingModelClass) -> LightingModel {
  {
    class_: match class_ {
      Some(c) => c
      None => BaseLightingModel::{ }
    },
  }
}

///|
/// Finds the payload of class `name` in the chain, for `X::of`.
pub fn LightingModel::class_payload(
  self : LightingModel,
  name : String,
) -> @core.JsValue? {
  let mut c : &LightingModelClass? = Some(self.class_)
  while c is Some(k) {
    if k.class_name() == name {
      return Some(k.payload())
    }
    c = k.parent()
  }
  None
}

///|
pub fn LightingModel::start(
  self : LightingModel,
  builder : NodeBuilder,
) -> Unit {
  self.class_.start(self, builder)
}

///|
/// `LightingModel.prototype.start`.
pub fn LightingModel::start_base(
  self : LightingModel,
  builder : NodeBuilder,
) -> Unit {
  let lights_node = builder.lights_node.unwrap()
  LightsNode::setup_lights(
    lights_node,
    builder,
    LightsNode::get_light_nodes(lights_node, builder),
  )
  self.indirect(builder)
}

///|
pub fn LightingModel::finish(
  self : LightingModel,
  builder : NodeBuilder,
) -> Unit {
  self.class_.finish(self, builder)
}

///|
pub fn LightingModel::direct(
  self : LightingModel,
  light_data : @core.JsValue,
  builder : NodeBuilder,
) -> Unit {
  self.class_.direct(self, light_data, builder)
}

///|
pub fn LightingModel::direct_rect_area(
  self : LightingModel,
  light_data : @core.JsValue,
  builder : NodeBuilder,
) -> Unit {
  self.class_.direct_rect_area(self, light_data, builder)
}

///|
pub fn LightingModel::indirect(
  self : LightingModel,
  builder : NodeBuilder,
) -> Unit {
  self.class_.indirect(self, builder)
}

///|
pub fn LightingModel::ambient_occlusion(
  self : LightingModel,
  builder : NodeBuilder,
) -> Unit {
  self.class_.ambient_occlusion(self, builder)
}
