// materials/nodes/NodeMaterial.js: the base of all node materials. A node material is a
// core `Material` whose extension is the `NodeMaterial` payload; subclasses plug in
// through `NodeMaterialClass` (the class chain of core_node.mbt: each payload embeds its
// superclass payload and returns it from `parent`, every default walks to `parent` and
// ends at the `NodeMaterial::*_base` body).

///|
/// The overridable members of `NodeMaterial` subclasses; defaults walk to `parent`.
pub(open) trait NodeMaterialClass {
  fn class_name(Self) -> String
  /// Upstream's `static get type()`; defaults to `class_name`.
  fn type_name(Self) -> String = _
  fn parent(Self) -> &NodeMaterialClass? = _
  fn payload(Self) -> @core.JsValue = _
  fn has_flag(Self, String) -> Bool = _
  /// `new this.constructor()`.
  fn construct(Self) -> @core.Material = _
  /// Reads a property the class adds (a node slot such as `emissiveNode`, or a getter
  /// such as `useClearcoat`) by upstream name, for code that enumerates a material's
  /// keys (`RenderObject.getMaterialCacheKey`); `None` falls back to the base fields.
  /// Declared by G7.
  fn get_property(Self, @core.Material, String) -> MaterialPropertyValue? = _
  /// A node slot the class adds (`emissiveNode`, `sizeNode`, ...) by upstream name.
  fn node_slot(Self, String) -> Node?? = _
  /// The node slots the class adds, in upstream's own-property order (after the
  /// parent's): `_getNodeChildren` and `toJSON` enumerate them.
  fn own_node_slots(Self, Array[(String, Node?)]) -> Unit = _
  /// Sets a node slot the class adds by upstream name (`NodeMaterialLoader`); false
  /// when the class has no such slot.
  fn set_node_slot(Self, String, Node?) -> Bool = _
  /// `material[ key ]` for a non-node property the class adds (`dashOffset`), read by
  /// reference nodes.
  fn reference_value(Self, @core.Material, String) -> TslValue? = _
  /// The rest of `copy( source )` for the members the class adds; runs after the base
  /// fields and the node slots are copied.
  fn copy_members(Self, @core.Material, @core.Material) -> Unit = _
  /// `build( builder )`.
  fn build(Self, @core.Material, NodeBuilder) -> Unit = _
  /// `setup( builder )`.
  fn setup(Self, @core.Material, NodeBuilder) -> Unit = _
  /// `setupObserver( builder )`.
  fn setup_observer(Self, @core.Material, NodeBuilder) -> NodeMaterialObserver = _
  /// `setupClipping( builder )`; `None` is `null`.
  fn setup_clipping(Self, @core.Material, NodeBuilder) -> Node? = _
  /// `setupHardwareClipping( builder )`.
  fn setup_hardware_clipping(Self, @core.Material, NodeBuilder) -> Unit = _
  /// `setupDepth( builder )`.
  fn setup_depth(Self, @core.Material, NodeBuilder) -> Unit = _
  /// `setupPositionView( builder )`.
  fn setup_position_view(Self, @core.Material, NodeBuilder) -> Node = _
  /// `setupModelViewProjection( builder )`.
  fn setup_model_view_projection(Self, @core.Material, NodeBuilder) -> Node = _
  /// `setupVertex( builder )`.
  fn setup_vertex(Self, @core.Material, NodeBuilder) -> Node = _
  /// `setupPosition( builder )`.
  fn setup_position(Self, @core.Material, NodeBuilder) -> Node = _
  /// `setupDiffuseColor( builder )`.
  fn setup_diffuse_color(Self, @core.Material, NodeBuilder) -> Unit = _
  /// `setupVariants( builder )`.
  fn setup_variants(Self, @core.Material, NodeBuilder) -> Unit = _
  /// `setupOutgoingLight( builder )`.
  fn setup_outgoing_light(Self, @core.Material, NodeBuilder) -> Node = _
  /// `setupNormal( builder )`.
  fn setup_normal(Self, @core.Material, NodeBuilder) -> Node = _
  /// `setupEnvironment( builder )`; `None` is `null`.
  fn setup_environment(Self, @core.Material, NodeBuilder) -> Node? = _
  /// `setupLightMap( builder )`; `None` is `null`.
  fn setup_light_map(Self, @core.Material, NodeBuilder) -> Node? = _
  /// `setupMaterialLightings( builder )`.
  fn setup_material_lightings(Self, @core.Material, NodeBuilder) -> Array[Node] = _
  /// `setupAmbientOcclusion( builder )`.
  fn setup_ambient_occlusion(Self, @core.Material, NodeBuilder) -> Unit = _
  /// `setupLightingModel( builder )`; `None` is `undefined`/`null`.
  fn setup_lighting_model(Self, @core.Material, NodeBuilder) -> LightingModel? = _
  /// `setupLighting( builder )`.
  fn setup_lighting(Self, @core.Material, NodeBuilder) -> Node = _
  /// `setupFog( builder, outputNode )`.
  fn setup_fog(Self, @core.Material, NodeBuilder, Node) -> Node = _
  /// `setupPremultipliedAlpha( builder, outputNode )`.
  fn setup_premultiplied_alpha(Self, @core.Material, NodeBuilder, Node) -> Node = _
  /// `setupOutput( builder, outputNode )`.
  fn setup_output(Self, @core.Material, NodeBuilder, Node) -> Node = _
  /// `setupSpecular()`, introduced by `MeshStandardNodeMaterial`.
  fn setup_specular(Self, @core.Material) -> Unit = _
}

///|
impl NodeMaterialClass with fn type_name(self) {
  self.class_name()
}

///|
impl NodeMaterialClass with fn parent(_) {
  None
}

///|
impl NodeMaterialClass with fn payload(self) {
  @core.JsValue::of(self)
}

///|
impl NodeMaterialClass with fn has_flag(self, flag) {
  match self.parent() {
    Some(p) => p.has_flag(flag)
    None => false
  }
}

///|
impl NodeMaterialClass with fn construct(self) {
  match self.parent() {
    Some(p) => p.construct()
    None => NodeMaterial::new()
  }
}

///|
impl NodeMaterialClass with fn get_property(self, material, name) {
  match self.parent() {
    Some(p) => p.get_property(material, name)
    None => None
  }
}

///|
impl NodeMaterialClass with fn node_slot(self, name) {
  match self.parent() {
    Some(p) => p.node_slot(name)
    None => None
  }
}

///|
impl NodeMaterialClass with fn own_node_slots(self, out) {
  match self.parent() {
    Some(p) => p.own_node_slots(out)
    None => ()
  }
}

///|
impl NodeMaterialClass with fn set_node_slot(self, name, value) {
  match self.parent() {
    Some(p) => p.set_node_slot(name, value)
    None => false
  }
}

///|
impl NodeMaterialClass with fn reference_value(self, material, key) {
  match self.parent() {
    Some(p) => p.reference_value(material, key)
    None => None
  }
}

///|
impl NodeMaterialClass with fn copy_members(self, material, source) {
  match self.parent() {
    Some(p) => p.copy_members(material, source)
    None => ()
  }
}

///|
impl NodeMaterialClass with fn build(self, material, builder) {
  match self.parent() {
    Some(p) => p.build(material, builder)
    None => NodeMaterial::build_base(material, builder)
  }
}

///|
impl NodeMaterialClass with fn setup(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup(material, builder)
    None => NodeMaterial::setup_base(material, builder)
  }
}

///|
impl NodeMaterialClass with fn setup_observer(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_observer(material, builder)
    None => NodeMaterialObserver::new(builder)
  }
}

///|
impl NodeMaterialClass with fn setup_clipping(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_clipping(material, builder)
    None => NodeMaterial::setup_clipping_base(material, builder)
  }
}

///|
impl NodeMaterialClass with fn setup_hardware_clipping(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_hardware_clipping(material, builder)
    None => NodeMaterial::setup_hardware_clipping_base(material, builder)
  }
}

///|
impl NodeMaterialClass with fn setup_depth(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_depth(material, builder)
    None => NodeMaterial::setup_depth_base(material, builder)
  }
}

///|
impl NodeMaterialClass with fn setup_position_view(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_position_view(material, builder)
    None => model_view_matrix.mul(position_local).xyz()
  }
}

///|
impl NodeMaterialClass with fn setup_model_view_projection(
  self,
  material,
  builder,
) {
  match self.parent() {
    Some(p) => p.setup_model_view_projection(material, builder)
    None => camera_projection_matrix.mul(position_view)
  }
}

///|
impl NodeMaterialClass with fn setup_vertex(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_vertex(material, builder)
    None => NodeMaterial::setup_vertex_base(material, builder)
  }
}

///|
impl NodeMaterialClass with fn setup_position(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_position(material, builder)
    None => NodeMaterial::setup_position_base(material, builder)
  }
}

///|
impl NodeMaterialClass with fn setup_diffuse_color(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_diffuse_color(material, builder)
    None => NodeMaterial::setup_diffuse_color_base(material, builder)
  }
}

///|
impl NodeMaterialClass with fn setup_variants(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_variants(material, builder)
    None => ()
  }
}

///|
impl NodeMaterialClass with fn setup_outgoing_light(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_outgoing_light(material, builder)
    None =>
      if material.lights == Some(true) {
        vec3(0)
      } else {
        diffuse_color.rgb()
      }
  }
}

///|
impl NodeMaterialClass with fn setup_normal(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_normal(material, builder)
    None =>
      match NodeMaterial::payload_of(material).normal_node {
        Some(n) => vec3(n)
        None => material_normal
      }
  }
}

///|
impl NodeMaterialClass with fn setup_environment(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_environment(material, builder)
    None => NodeMaterial::setup_environment_base(material)
  }
}

///|
impl NodeMaterialClass with fn setup_light_map(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_light_map(material, builder)
    None =>
      if node_material_builder_material(builder).light_map is Some(_) {
        Some(IrradianceNode::new(material_light_map))
      } else {
        None
      }
  }
}

///|
impl NodeMaterialClass with fn setup_material_lightings(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_material_lightings(material, builder)
    None => NodeMaterial::setup_material_lightings_base(material, builder)
  }
}

///|
impl NodeMaterialClass with fn setup_ambient_occlusion(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_ambient_occlusion(material, builder)
    None => NodeMaterial::setup_ambient_occlusion_base(material, builder)
  }
}

///|
impl NodeMaterialClass with fn setup_lighting_model(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_lighting_model(material, builder)
    None => None
  }
}

///|
impl NodeMaterialClass with fn setup_lighting(self, material, builder) {
  match self.parent() {
    Some(p) => p.setup_lighting(material, builder)
    None => NodeMaterial::setup_lighting_base(material, builder)
  }
}

///|
impl NodeMaterialClass with fn setup_fog(self, material, builder, output_node) {
  match self.parent() {
    Some(p) => p.setup_fog(material, builder, output_node)
    None =>
      match builder.fog_node {
        Some(fog_node) => {
          output.assign(output_node)
          vec4(fog_node.to_var())
        }
        None => output_node
      }
  }
}

///|
impl NodeMaterialClass with fn setup_premultiplied_alpha(
  self,
  material,
  builder,
  output_node,
) {
  match self.parent() {
    Some(p) => p.setup_premultiplied_alpha(material, builder, output_node)
    None => premultiply_alpha.call([output_node])
  }
}

///|
impl NodeMaterialClass with fn setup_output(
  self,
  material,
  builder,
  output_node,
) {
  match self.parent() {
    Some(p) => p.setup_output(material, builder, output_node)
    None => NodeMaterial::setup_output_base(material, builder, output_node)
  }
}

///|
impl NodeMaterialClass with fn setup_specular(self, material) {
  match self.parent() {
    Some(p) => p.setup_specular(material)
    None => abort("TypeError: this.setupSpecular is not a function")
  }
}

///|
/// The class of a plain `new NodeMaterial()`.
pub(all) struct BaseNodeMaterial {}

///|
pub impl NodeMaterialClass for BaseNodeMaterial with fn class_name(_) {
  "NodeMaterial"
}

///|
/// `geometryNode` and `receivedShadowNode`, the slots G7's base lookup lacks.
pub impl NodeMaterialClass for BaseNodeMaterial with fn get_property(
  _,
  material,
  name,
) {
  let nm = NodeMaterial::payload_of(material)
  match name {
    "geometryNode" => Some(node_material_slot_value(nm.geometry_node))
    "receivedShadowNode" =>
      Some(node_material_slot_value(nm.received_shadow_node))
    _ => None
  }
}

///|
/// Upstream's `NodeMaterial` fields (the node slots).
pub(all) struct NodeMaterial {
  mut class_ : &NodeMaterialClass
  mut lights_node : Node?
  mut env_node : Node?
  mut ao_node : Node?
  mut color_node : Node?
  mut normal_node : Node?
  mut opacity_node : Node?
  mut backdrop_node : Node?
  mut backdrop_alpha_node : Node?
  mut alpha_test_node : Node?
  mut mask_node : Node?
  mut mask_shadow_node : Node?
  mut position_node : Node?
  mut depth_node : Node?
  mut received_shadow_position_node : Node?
  /// `receivedShadowNode`, a `Fn` called with the shadow (read by ShadowNode, G3).
  mut received_shadow_node : Node?
  mut cast_shadow_position_node : Node?
  mut cast_shadow_node : Node?
  mut output_node : Node?
  mut mrt_node : Node?
  mut fragment_node : Node?
  mut vertex_node : Node?
  mut context_node : Node?
  /// `geometryNode`, a `Fn` bypassed after the vertex output.
  mut geometry_node : Node?
}

///|
pub impl @core.MaterialExtension for NodeMaterial with fn type_name(self) {
  self.class_.type_name()
}

///|
pub impl @core.MaterialExtension for NodeMaterial with fn construct(self) {
  self.class_.construct()
}

///|
pub impl @core.MaterialExtension for NodeMaterial with fn payload(self) {
  @core.JsValue::of(self)
}

///|
pub impl @core.MaterialExtension for NodeMaterial with fn has_flag(self, flag) {
  flag == "isNodeMaterial" ||
  self.class_.has_flag(flag) ||
  (
    node_material_defaults.get(self) is Some(defaults) &&
    node_material_defaults_flag(defaults, flag)
  )
}

///|
/// The material `setDefaultValues` took the defaults from, per node material: its own
/// `isFoo` flags are among the properties upstream copies (`isMeshStandardMaterial`, ...).
let node_material_defaults : @webgl.WeakMap[NodeMaterial, @core.Material] = @webgl.WeakMap::new()

///|
/// Whether the defaults material has the `isFoo` flag `flag`.
fn node_material_defaults_flag(
  defaults : @core.Material,
  flag : String,
) -> Bool {
  match flag {
    "isMeshBasicMaterial" => defaults.is_mesh_basic_material()
    "isMeshLambertMaterial" => defaults.is_mesh_lambert_material()
    "isMeshPhongMaterial" => defaults.is_mesh_phong_material()
    "isMeshStandardMaterial" => defaults.is_mesh_standard_material()
    "isMeshPhysicalMaterial" => defaults.is_mesh_physical_material()
    "isMeshToonMaterial" => defaults.is_mesh_toon_material()
    "isMeshNormalMaterial" => defaults.is_mesh_normal_material()
    "isMeshMatcapMaterial" => defaults.is_mesh_matcap_material()
    "isMeshDepthMaterial" => defaults.is_mesh_depth_material()
    "isMeshDistanceMaterial" => defaults.is_mesh_distance_material()
    "isLineBasicMaterial" => defaults.is_line_basic_material()
    "isLineDashedMaterial" => defaults.is_line_dashed_material()
    "isPointsMaterial" => defaults.is_points_material()
    "isSpriteMaterial" => defaults.is_sprite_material()
    "isShadowMaterial" => defaults.is_shadow_material()
    _ => false
  }
}

///|
/// `copy( source )`: the core part (`Material::copy_base`) has run; this copies the
/// flat subclass fields, the node slots and the members of the class.
pub impl @core.MaterialExtension for NodeMaterial with fn copy_from(
  self,
  material,
  source,
) {
  NodeMaterial::copy_rest(material, source, self)
}

///|
/// Adds `inputNodes` (the node slots by uuid) to `Material.prototype.toJSON`'s output.
pub impl @core.MaterialExtension for NodeMaterial with fn to_json(
  _,
  material,
  meta,
  data,
) {
  match meta {
    Some(meta) => NodeMaterial::to_json_input_nodes(material, meta, data)
    // the root is serialized by `NodeMaterial::to_json`, which passes a meta
    None =>
      NodeMaterial::to_json_input_nodes(material, @core.ToJsonMeta::new(), data)
  }
}

///|
pub impl @core.MaterialExtension for NodeMaterial with fn custom_program_cache_key(
  _,
  material,
) {
  Some(NodeMaterial::custom_program_cache_key(material))
}

///|
/// `new NodeMaterial()`.
pub fn NodeMaterial::new() -> @core.Material {
  NodeMaterial::create(BaseNodeMaterial::{ })
}

///|
/// `super()` of a subclass constructor: a node material whose class is `class_`, with
/// upstream's base fields (`fog = true`, `lights = false`, every node slot `null`).
pub fn NodeMaterial::create(class_ : &NodeMaterialClass) -> @core.Material {
  let material = @core.Material::new()
  material.fog = Some(true)
  material.lights = Some(false)
  material.set_extension(NodeMaterial::{
    class_,
    lights_node: None,
    env_node: None,
    ao_node: None,
    color_node: None,
    normal_node: None,
    opacity_node: None,
    backdrop_node: None,
    backdrop_alpha_node: None,
    alpha_test_node: None,
    mask_node: None,
    mask_shadow_node: None,
    position_node: None,
    depth_node: None,
    received_shadow_position_node: None,
    received_shadow_node: None,
    cast_shadow_position_node: None,
    cast_shadow_node: None,
    output_node: None,
    mrt_node: None,
    fragment_node: None,
    vertex_node: None,
    context_node: None,
    geometry_node: None,
  })
}

///|
/// The `NodeMaterial` payload of a node material; `None` for other materials.
pub fn NodeMaterial::of(material : @core.Material) -> NodeMaterial? {
  match material.extension {
    Some(extension) if extension.has_flag("isNodeMaterial") =>
      Some(extension.payload().cast())
    _ => None
  }
}

///|
/// `NodeMaterial::of` for code that only runs on node materials.
fn NodeMaterial::payload_of(material : @core.Material) -> NodeMaterial {
  match NodeMaterial::of(material) {
    Some(nm) => nm
    None => abort("TypeError: \{material.type_} is not a NodeMaterial")
  }
}

///|
/// The most derived class of a node material (`this` for virtual calls).
fn node_material_class(material : @core.Material) -> &NodeMaterialClass {
  NodeMaterial::payload_of(material).class_
}

///|
/// Finds the payload of class `name` in the material's class chain, for `X::of`.
pub fn NodeMaterial::class_payload(
  material : @core.Material,
  name : String,
) -> @core.JsValue? {
  let mut c : &NodeMaterialClass? = match NodeMaterial::of(material) {
    Some(nm) => Some(nm.class_)
    None => None
  }
  while c is Some(k) {
    if k.class_name() == name {
      return Some(k.payload())
    }
    c = k.parent()
  }
  None
}

///|
fn node_material_slot_value(node : Node?) -> MaterialPropertyValue {
  match node {
    Some(_) => Object
    None => Null
  }
}

///|
extern "js" fn node_material_js_string(x : Double) -> String = "(x) => String(x)"

///|
/// `builder.material`, which `setup` reads for some properties.
fn node_material_builder_material(builder : NodeBuilder) -> @core.Material {
  match builder.material {
    Some(m) => m
    None =>
      abort("TypeError: Cannot read properties of null (builder.material)")
  }
}

///|
/// `builder.object` as a 3D object.
fn node_material_builder_object(builder : NodeBuilder) -> @core.Object3D {
  match builder.object {
    Object3D(o) => o
    _ => abort("TypeError: Cannot read properties of null (builder.object)")
  }
}

///|
/// `builder.geometry`.
fn node_material_builder_geometry(
  builder : NodeBuilder,
) -> @core.BufferGeometry {
  match builder.geometry {
    Some(g) => g
    None =>
      abort("TypeError: Cannot read properties of null (builder.geometry)")
  }
}

///|
/// `builder.camera`.
fn node_material_builder_camera(builder : NodeBuilder) -> @core.Object3D {
  match builder.camera {
    Some(c) => c
    None => abort("TypeError: Cannot read properties of null (builder.camera)")
  }
}

///|
/// `builder.context.getOutput( outputNode, builder )`, set by render pipelines.
pub(all) struct ContextGetOutput {
  f : (Node, NodeBuilder) -> Node
}

///|
/// `builder.context.getOutput`, if set.
pub fn NodeContext::get_output(self : NodeContext) -> ContextGetOutput? {
  match self.get("getOutput") {
    Other(_) as v => v.cast()
    _ => None
  }
}

///|
fn node_material_context_setup(f : () -> Node) -> ContextValue {
  Other(@core.JsValue::of(ContextSetup::{ f, }))
}

// ---------------------------------------------------------------------------
// Node slots

///|
/// The `NodeMaterial` node slots in upstream's own-property order.
fn NodeMaterial::base_node_slots(nm : NodeMaterial) -> Array[(String, Node?)] {
  [
    ("lightsNode", nm.lights_node),
    ("envNode", nm.env_node),
    ("aoNode", nm.ao_node),
    ("colorNode", nm.color_node),
    ("normalNode", nm.normal_node),
    ("opacityNode", nm.opacity_node),
    ("backdropNode", nm.backdrop_node),
    ("backdropAlphaNode", nm.backdrop_alpha_node),
    ("alphaTestNode", nm.alpha_test_node),
    ("maskNode", nm.mask_node),
    ("maskShadowNode", nm.mask_shadow_node),
    ("positionNode", nm.position_node),
    ("geometryNode", nm.geometry_node),
    ("depthNode", nm.depth_node),
    ("receivedShadowPositionNode", nm.received_shadow_position_node),
    ("castShadowPositionNode", nm.cast_shadow_position_node),
    ("receivedShadowNode", nm.received_shadow_node),
    ("castShadowNode", nm.cast_shadow_node),
    ("outputNode", nm.output_node),
    ("mrtNode", nm.mrt_node),
    ("fragmentNode", nm.fragment_node),
    ("vertexNode", nm.vertex_node),
    ("contextNode", nm.context_node),
  ]
}

///|
/// Every node slot of the material (base, then the class's) in own-property order.
pub fn NodeMaterial::node_slots(
  material : @core.Material,
) -> Array[(String, Node?)] {
  let nm = NodeMaterial::payload_of(material)
  let slots = NodeMaterial::base_node_slots(nm)
  nm.class_.own_node_slots(slots)
  slots
}

///|
/// Sets a node slot by upstream name (`material[ property ] = node`); false when the
/// material has no such slot.
pub fn NodeMaterial::set_node_slot(
  material : @core.Material,
  name : String,
  value : Node?,
) -> Bool {
  let nm = NodeMaterial::payload_of(material)
  match name {
    "lightsNode" => nm.lights_node = value
    "envNode" => nm.env_node = value
    "aoNode" => nm.ao_node = value
    "colorNode" => nm.color_node = value
    "normalNode" => nm.normal_node = value
    "opacityNode" => nm.opacity_node = value
    "backdropNode" => nm.backdrop_node = value
    "backdropAlphaNode" => nm.backdrop_alpha_node = value
    "alphaTestNode" => nm.alpha_test_node = value
    "maskNode" => nm.mask_node = value
    "maskShadowNode" => nm.mask_shadow_node = value
    "positionNode" => nm.position_node = value
    "geometryNode" => nm.geometry_node = value
    "depthNode" => nm.depth_node = value
    "receivedShadowPositionNode" => nm.received_shadow_position_node = value
    "castShadowPositionNode" => nm.cast_shadow_position_node = value
    "receivedShadowNode" => nm.received_shadow_node = value
    "castShadowNode" => nm.cast_shadow_node = value
    "outputNode" => nm.output_node = value
    "mrtNode" => nm.mrt_node = value
    "fragmentNode" => nm.fragment_node = value
    "vertexNode" => nm.vertex_node = value
    "contextNode" => nm.context_node = value
    _ => return nm.class_.set_node_slot(name, value)
  }
  true
}

///|
/// `_getNodeChildren()`: the slots holding a node.
pub fn NodeMaterial::get_node_children(
  material : @core.Material,
) -> Array[(String, Node)] {
  let children = []
  for slot in NodeMaterial::node_slots(material) {
    if slot.1 is Some(node) {
      children.push((slot.0, node))
    }
  }
  children
}

///|
/// `customProgramCacheKey()`.
pub fn NodeMaterial::custom_program_cache_key(
  material : @core.Material,
) -> String {
  let values : Array[Double] = []
  for child in NodeMaterial::get_node_children(material) {
    let (property, child_node) = child
    let trimmed = if property.length() > 4 {
      property.unsafe_substring(start=0, end=property.length() - 4)
    } else {
      ""
    }
    values.push(hash_string(trimmed))
    values.push(child_node.get_cache_key(force=true))
  }
  material.type_ + node_material_js_string(hash_array(values))
}

// ---------------------------------------------------------------------------
// build / setup

///|
/// `build( builder )`.
pub fn NodeMaterial::build(
  material : @core.Material,
  builder : NodeBuilder,
) -> Unit {
  match node_material_instance_of(material) {
    // `NodeMaterialInstance.build`: the node material builds itself
    Some(node_material) => NodeMaterial::build(node_material, builder)
    None => node_material_class(material).build(material, builder)
  }
}

///|
/// `NodeMaterial.prototype.build`.
pub fn NodeMaterial::build_base(
  material : @core.Material,
  builder : NodeBuilder,
) -> Unit {
  node_material_class(material).setup(material, builder)
}

///|
/// `setup( builder )` of the material's class.
pub fn NodeMaterial::setup(
  material : @core.Material,
  builder : NodeBuilder,
) -> Unit {
  node_material_class(material).setup(material, builder)
}

///|
/// `NodeMaterial.prototype.setup`.
pub fn NodeMaterial::setup_base(
  material : @core.Material,
  builder : NodeBuilder,
) -> Unit {
  let nm = NodeMaterial::payload_of(material)
  let class_ = nm.class_
  builder.context.set(
    "setupNormal",
    node_material_context_setup(fn() {
      sub_build(class_.setup_normal(material, builder), "NORMAL", type_="vec3")
    }),
  )
  builder.context.set(
    "setupPositionView",
    node_material_context_setup(fn() {
      class_.setup_position_view(material, builder)
    }),
  )
  builder.context.set(
    "setupModelViewProjection",
    node_material_context_setup(fn() {
      class_.setup_model_view_projection(material, builder)
    }),
  )
  let renderer = builder.renderer
  let render_target = renderer.get_render_target()

  // < VERTEX STAGE >
  builder.add_stack() |> ignore
  let mvp = class_.setup_vertex(material, builder)
  let vertex_node = sub_build(
    match nm.vertex_node {
      Some(v) => v
      None => mvp
    },
    "VERTEX",
  )
  builder.context.set("clipSpace", Node(vertex_node))
  builder.stack.output_node = Some(vertex_node)
  class_.setup_hardware_clipping(material, builder)
  if nm.geometry_node is Some(geometry_node) {
    builder.stack.output_node = Some(
      builder.stack.output_node.unwrap().bypass(geometry_node),
    )
  }
  builder.add_flow("vertex", builder.remove_stack().node) |> ignore

  // < FRAGMENT STAGE >
  builder.add_stack() |> ignore
  let clipping_node = class_.setup_clipping(material, builder)
  if material.depth_write || material.depth_test {
    // only write depth if depth buffer is configured
    match render_target {
      Some(render_target) =>
        if render_target.depth_buffer {
          class_.setup_depth(material, builder)
        }
      None => if renderer.depth { class_.setup_depth(material, builder) }
    }
  }
  let result_node = match nm.fragment_node {
    None => {
      class_.setup_diffuse_color(material, builder)
      class_.setup_ambient_occlusion(material, builder)
      class_.setup_variants(material, builder)
      let outgoing_light_node = class_.setup_lighting(material, builder)
      if clipping_node is Some(clipping_node) {
        builder.stack.add_to_stack(clipping_node) |> ignore
      }
      // force unsigned floats - useful for RenderTargets
      let basic_output = vec4_of([outgoing_light_node, diffuse_color.a()]).max(
        0,
      )
      let mut result_node = class_.setup_output(material, builder, basic_output)
      // OUTPUT NODE
      output.assign(result_node)
      let is_custom_output = nm.output_node is Some(_)
      if nm.output_node is Some(output_node) {
        result_node = output_node
      }
      if builder.context.get_output() is Some(get_output) {
        result_node = (get_output.f)(result_node, builder)
      }
      // MRT
      if render_target is Some(_) {
        let mrt = renderer.get_mrt()
        let material_mrt = nm.mrt_node
        match mrt {
          Some(mrt) => {
            if is_custom_output {
              output.assign(result_node)
            }
            result_node = mrt
            if material_mrt is Some(material_mrt) {
              result_node = MRTNode::of(mrt)
                .unwrap()
                .merge(MRTNode::of(material_mrt).unwrap())
            }
          }
          None =>
            if material_mrt is Some(material_mrt) {
              result_node = material_mrt
            }
        }
      }
      result_node
    }
    Some(fragment_node) => {
      let fragment_node = if fragment_node.has_flag("isOutputStructNode") {
        fragment_node
      } else {
        fragment_node.convert(builder.get_output_type())
      }
      class_.setup_output(material, builder, fragment_node)
    }
  }
  builder.stack.output_node = Some(result_node)
  builder.add_flow("fragment", builder.remove_stack().node) |> ignore

  // < OBSERVER >
  builder.observer = Some(class_.setup_observer(material, builder))
}

///|
/// `NodeMaterial.prototype.setupClipping`.
pub fn NodeMaterial::setup_clipping_base(
  material : @core.Material,
  builder : NodeBuilder,
) -> Node? {
  let clipping_context = match builder.clipping_context {
    Some(c) => c
    None => return None
  }
  let mut result = None
  if clipping_context.union_planes.length() > 0 ||
    clipping_context.intersection_planes.length() > 0 {
    let samples = builder.renderer.current_samples()
    if material.alpha_to_coverage && samples > 1 {
      // to be added to flow when the color/alpha value has been determined
      result = Some(clipping_alpha())
    } else {
      builder.stack.add_to_stack(clipping()) |> ignore
    }
  }
  result
}

///|
/// `NodeMaterial.prototype.setupHardwareClipping`.
pub fn NodeMaterial::setup_hardware_clipping_base(
  _material : @core.Material,
  builder : NodeBuilder,
) -> Unit {
  builder.hardware_clipping = false
  let clipping_context = match builder.clipping_context {
    Some(c) => c
    None => return
  }
  let candidate_count = clipping_context.union_planes.length()
  // 8 planes supported by WebGL ANGLE_clip_cull_distance and WebGPU clip-distances
  if candidate_count > 0 &&
    candidate_count <= 8 &&
    builder.is_available("clipDistance") {
    builder.stack.add_to_stack(hardware_clipping()) |> ignore
    builder.hardware_clipping = true
  }
}

///|
/// `NodeMaterial.prototype.setupDepth`.
pub fn NodeMaterial::setup_depth_base(
  material : @core.Material,
  builder : NodeBuilder,
) -> Unit {
  let renderer = builder.renderer
  let mut depth_node = NodeMaterial::payload_of(material).depth_node
  if depth_node is None {
    let mrt = renderer.get_mrt()
    match mrt {
      Some(mrt) if MRTNode::of(mrt).unwrap().has("depth") =>
        depth_node = MRTNode::of(mrt).unwrap().get("depth")
      _ =>
        if renderer.logarithmic_depth_buffer {
          let camera = node_material_builder_camera(builder)
          if !camera.is_orthographic_camera() {
            depth_node = Some(
              view_z_to_logarithmic_depth(
                position_view.z(),
                camera_near,
                camera_far,
              ),
            )
          } else {
            depth_node = Some(
              view_z_to_orthographic_depth(
                position_view.z(),
                camera_near,
                camera_far,
              ),
            )
          }
        }
    }
  }
  if depth_node is Some(depth_node) {
    depth.assign_node(depth_node).to_stack() |> ignore
  }
}

///|
/// `NodeMaterial.prototype.setupVertex`.
pub fn NodeMaterial::setup_vertex_base(
  material : @core.Material,
  builder : NodeBuilder,
) -> Node {
  builder.add_stack() |> ignore
  node_material_class(material).setup_position(material, builder) |> ignore
  builder.context.set("position", Node(builder.remove_stack().node))
  model_view_projection
}

///|
/// `NodeMaterial.prototype.setupPosition`.
pub fn NodeMaterial::setup_position_base(
  material : @core.Material,
  builder : NodeBuilder,
) -> Node {
  let object = node_material_builder_object(builder)
  let geometry = node_material_builder_geometry(builder)
  if geometry.morph_attributes.get("position") is Some(_) ||
    geometry.morph_attributes.get("normal") is Some(_) ||
    geometry.morph_attributes.get("color") is Some(_) {
    morph_reference.call([object]) |> ignore
  }
  if object.is_skinned_mesh() {
    skinning.call([object]) |> ignore
  }
  if material.displacement_map is Some(_) {
    let displacement_map = material_reference("displacementMap", "texture")
    let displacement_scale = material_reference("displacementScale", "float")
    let displacement_bias = material_reference("displacementBias", "float")
    position_local.add_assign(
      normal_local
      .normalize()
      .mul(displacement_map.x().mul(displacement_scale).add(displacement_bias)),
    )
  }
  if object.is_batched_mesh() {
    batch.call([object]) |> ignore
  }
  if object.is_instanced_mesh() &&
    instance_matrix_of(object).is_instanced_buffer_attribute() {
    instanced_mesh.call([object]) |> ignore
  }
  if NodeMaterial::payload_of(material).position_node is Some(position_node) {
    position_local.assign(sub_build(position_node, "POSITION", type_="vec3"))
  }
  position_local
}

///|
/// `NodeMaterial.prototype.setupDiffuseColor`.
pub fn NodeMaterial::setup_diffuse_color_base(
  material : @core.Material,
  builder : NodeBuilder,
) -> Unit {
  let nm = NodeMaterial::payload_of(material)
  let object = node_material_builder_object(builder)
  let geometry = node_material_builder_geometry(builder)

  // MASK
  if nm.mask_node is Some(mask_node) {
    // Discard if the mask is `false`
    bool(mask_node).not_().discard()
  }

  // COLOR
  let mut color_node = match nm.color_node {
    Some(c) => vec4(c)
    None => material_color
  }

  // VERTEX COLORS
  let mut vertex_color_node : Node? = None
  if material.vertex_colors && geometry.has_attribute("color") {
    vertex_color_node = Some(vertex_color())
  }

  // INSTANCED COLORS
  if instance_color_of(object) is Some(_) {
    vertex_color_node = Some(
      match vertex_color_node {
        Some(v) => v.mul(instance_color)
        None => instance_color
      },
    )
  }
  if object.is_batched_mesh() && batch_mesh(object)._colors_texture is Some(_) {
    vertex_color_node = Some(
      match vertex_color_node {
        Some(v) => v.mul(batch_color)
        None => batch_color
      },
    )
  }

  // MORPHED COLORS
  if material.vertex_colors && geometry.morph_attributes.get("color") is Some(_) {
    vertex_color_node = Some(
      morph_color.call([
        match vertex_color_node {
          Some(v) => vec4(v)
          None => vec4(1)
        },
      ]),
    )
  }
  if vertex_color_node is Some(v) {
    color_node = color_node.mul(v)
  }

  // DIFFUSE COLOR
  diffuse_color.assign(color_node)

  // OPACITY
  let opacity_node = match nm.opacity_node {
    Some(o) => float(o)
    None => material_opacity
  }
  diffuse_color.a().assign(diffuse_color.a().mul(opacity_node))

  // ALPHA TEST
  if nm.alpha_test_node is Some(_) || material.alpha_test() > 0.0 {
    let alpha_test_node = match nm.alpha_test_node {
      Some(a) => float(a)
      None => material_alpha_test
    }
    if material.alpha_to_coverage {
      diffuse_color
      .a()
      .assign(
        smoothstep(
          alpha_test_node,
          alpha_test_node.add(fwidth(diffuse_color.a())),
          diffuse_color.a(),
        ),
      )
      diffuse_color.a().less_than_equal(0).discard()
    } else {
      diffuse_color.a().less_than_equal(alpha_test_node).discard()
    }
  }

  // ALPHA HASH
  if material.alpha_hash {
    diffuse_color
    .a()
    .less_than(get_alpha_hash_threshold.call([position_local]))
    .discard()
  }

  // OPAQUE
  if builder.is_opaque() {
    diffuse_color.a().assign(1.0)
  }
}

///|
/// `NodeMaterial.prototype.setupEnvironment`.
pub fn NodeMaterial::setup_environment_base(material : @core.Material) -> Node? {
  match NodeMaterial::payload_of(material).env_node {
    Some(env_node) => Some(env_node)
    None =>
      match material.env_map {
        Some(env_map) =>
          if env_map.is_cube_texture() {
            Some(material_reference("envMap", "cubeTexture"))
          } else {
            Some(material_reference("envMap", "texture"))
          }
        None => None
      }
  }
}

///|
/// `NodeMaterial.prototype.setupMaterialLightings`.
pub fn NodeMaterial::setup_material_lightings_base(
  material : @core.Material,
  builder : NodeBuilder,
) -> Array[Node] {
  let class_ = node_material_class(material)
  let material_lights_node = []
  let env_node = class_.setup_environment(material, builder)
  if env_node is Some(env_node) && env_node.has_flag("isLightingNode") {
    material_lights_node.push(env_node)
  }
  let light_map_node = class_.setup_light_map(material, builder)
  if light_map_node is Some(light_map_node) &&
    light_map_node.has_flag("isLightingNode") {
    material_lights_node.push(light_map_node)
  }
  if builder.context.get_node("ambientOcclusion") is Some(ao) {
    material_lights_node.push(AONode::new(ao_node=ao))
  }
  if builder.context.get_gi() is Some(get_gi) {
    let gi_node = (get_gi.f)(None, builder)
    if gi_node is Some(gi_node) {
      material_lights_node.push(IrradianceNode::new(gi_node))
    }
  }
  material_lights_node
}

///|
/// `NodeMaterial.prototype.setupAmbientOcclusion`.
pub fn NodeMaterial::setup_ambient_occlusion_base(
  material : @core.Material,
  builder : NodeBuilder,
) -> Unit {
  let mut ao_node = NodeMaterial::payload_of(material).ao_node
  if ao_node is None &&
    node_material_builder_material(builder).ao_map is Some(_) {
    ao_node = Some(material_ao)
  }
  if builder.context.get_ao() is Some(get_ao) {
    ao_node = (get_ao.f)(ao_node, builder)
  }
  if ao_node is Some(ao_node) {
    ambient_occlusion.assign(ao_node)
    builder.context.set("ambientOcclusion", Node(ambient_occlusion))
  }
}

///|
/// `NodeMaterial.prototype.setupLighting`.
pub fn NodeMaterial::setup_lighting_base(
  material : @core.Material,
  builder : NodeBuilder,
) -> Node {
  let nm = NodeMaterial::payload_of(material)
  let class_ = nm.class_
  let builder_material = node_material_builder_material(builder)
  let backdrop_node = nm.backdrop_node
  let backdrop_alpha_node = nm.backdrop_alpha_node
  let emissive_node = match class_.node_slot("emissiveNode") {
    Some(slot) => slot
    None => None
  }

  // OUTGOING LIGHT
  let scene_lighting = material.lights == Some(true) &&
    builder.renderer.lighting.enabled
  let lights = scene_lighting || nm.lights_node is Some(_)
  let material_lightings = if scene_lighting {
    class_.setup_material_lightings(material, builder)
  } else {
    []
  }
  let lights_node = if lights {
    match nm.lights_node {
      Some(l) => Some(l)
      None => builder.lights_node
    }
  } else {
    None
  }
  let mut outgoing_light_node = class_.setup_outgoing_light(material, builder)
  match lights_node {
    Some(lights_node) if material_lightings.length() > 0 ||
      LightsNode::has_lights(lights_node.get_scope()) => {
      let lighting_model = class_.setup_lighting_model(material, builder)
      outgoing_light_node = lighting_context(
        lights_node,
        lighting_model?,
        material_lightings~,
        backdrop_node?,
        backdrop_alpha_node?,
      )
    }
    _ =>
      if backdrop_node is Some(backdrop_node) {
        outgoing_light_node = vec3(
          match backdrop_alpha_node {
            Some(alpha) => mix(outgoing_light_node, backdrop_node, alpha)
            None => backdrop_node
          },
        )
      }
  }

  // EMISSIVE
  if emissive_node is Some(_) || builder_material.emissive is Some(_) {
    emissive.assign(
      vec3(
        match emissive_node {
          Some(e) => e
          None => material_emissive
        },
      ),
    )
    outgoing_light_node = outgoing_light_node.add(emissive)
  }
  outgoing_light_node
}

///|
/// `NodeMaterial.prototype.setupOutput`.
pub fn NodeMaterial::setup_output_base(
  material : @core.Material,
  builder : NodeBuilder,
  output_node : Node,
) -> Node {
  let class_ = node_material_class(material)
  let mut output_node = output_node
  // FOG
  if material.fog == Some(true) {
    output_node = class_.setup_fog(material, builder, output_node)
  }
  // PREMULTIPLIED ALPHA
  if material.premultiplied_alpha {
    output_node = class_.setup_premultiplied_alpha(
      material, builder, output_node,
    )
  }
  output_node
}

// ---------------------------------------------------------------------------
// setDefaultValues / copy / toJSON

///|
/// `setDefaultValues( material )`: every property `material` has that this node
/// material leaves `undefined` takes its value (cloned when it has `clone`). The
/// prototype getters of `material` (`MeshPhysicalMaterial`'s `clearcoat`, ...) are
/// `Material` methods here already.
pub fn NodeMaterial::set_default_values(
  material : @core.Material,
  defaults : @core.Material,
) -> Unit {
  node_material_set_default_fields(material, defaults)
  if NodeMaterial::of(material) is Some(nm) {
    node_material_defaults.set(nm, defaults)
  }
}

///|
/// The part of `copy( source )` after the base `Material` fields: the flat subclass
/// fields, the node slots (by reference) and the class members.
fn NodeMaterial::copy_rest(
  material : @core.Material,
  source : @core.Material,
  nm : NodeMaterial,
) -> Unit {
  node_material_copy_fields(material, source)
  match NodeMaterial::of(source) {
    Some(_) =>
      for slot in NodeMaterial::node_slots(source) {
        NodeMaterial::set_node_slot(material, slot.0, slot.1) |> ignore
      }
    None => ()
  }
  nm.class_.copy_members(material, source)
}

///|
/// `toJSON( meta )`. `meta` is the shared cache of a parent serialization; the root
/// call extracts the cached textures, images and nodes into the result.
pub fn NodeMaterial::to_json(
  material : @core.Material,
  meta? : @core.ToJsonMeta,
) -> Json {
  let is_root = meta is None
  let meta = match meta {
    Some(m) => m
    None => @core.ToJsonMeta::new()
  }
  let data = material.to_json(meta~)
  guard data is Object(data) else { abort("unreachable: material JSON") }
  if is_root {
    let textures = node_material_extract_from_cache(meta.textures)
    let images = node_material_extract_from_cache(meta.images)
    let nodes = node_material_extract_from_cache(meta.nodes)
    if textures.length() > 0 {
      data["textures"] = Json::array(textures)
    }
    if images.length() > 0 {
      data["images"] = Json::array(images)
    }
    if nodes.length() > 0 {
      data["nodes"] = Json::array(nodes)
    }
  }
  Json::object(data)
}

///|
/// `extractFromCache( cache )`: the values without their `metadata`.
fn node_material_extract_from_cache(cache : Map[String, Json]) -> Array[Json] {
  let values = []
  for _, data in cache {
    match data {
      Object(fields) => {
        let copy = Map([])
        for k, v in fields {
          if k != "metadata" {
            copy[k] = v
          }
        }
        values.push(Json::object(copy))
      }
      other => values.push(other)
    }
  }
  values
}

///|
/// `data.inputNodes[ property ] = childNode.toJSON( meta ).uuid` for each node slot.
/// Nodes serialize into a JS meta object (`Node::to_json`); its texture, image and node
/// caches are carried over from and back to `meta`.
fn NodeMaterial::to_json_input_nodes(
  material : @core.Material,
  meta : @core.ToJsonMeta,
  data : Map[String, Json],
) -> Unit {
  let js_meta = @core.JsValue::object()
  let js_textures = node_material_cache_to_js(meta.textures)
  let js_images = node_material_cache_to_js(meta.images)
  let js_nodes = node_material_cache_to_js(meta.nodes)
  js_meta.set("textures", js_textures)
  js_meta.set("images", js_images)
  js_meta.set("nodes", js_nodes)
  let input_nodes : Map[String, Json] = Map([])
  for child in NodeMaterial::get_node_children(material) {
    let (property, child_node) = child
    let uuid : String = child_node.to_json(meta=js_meta).get("uuid").cast()
    input_nodes[property] = Json::string(uuid)
  }
  data["inputNodes"] = Json::object(input_nodes)
  node_material_cache_from_js(js_textures, meta.textures)
  node_material_cache_from_js(js_images, meta.images)
  node_material_cache_from_js(js_nodes, meta.nodes)
}

///|
extern "js" fn node_material_json_parse(text : String) -> @core.JsValue = "(t) => JSON.parse(t)"

///|
extern "js" fn node_material_js_keys(
  value : @core.JsValue,
) -> FixedArray[String] = "(v) => Object.keys(v)"

///|
extern "js" fn node_material_js_type_of(value : @core.JsValue) -> String = "(v) => v === null ? 'null' : Array.isArray(v) ? 'array' : typeof v"

///|
/// A JSON cache as a JS object (insertion order kept).
fn node_material_cache_to_js(cache : Map[String, Json]) -> @core.JsValue {
  let object = @core.JsValue::object()
  for key, value in cache {
    object.set(key, node_material_json_parse(value.stringify()))
  }
  object
}

///|
/// A plain JS value (JSON data) as `Json`.
pub fn node_material_js_to_json(value : @core.JsValue) -> Json {
  match node_material_js_type_of(value) {
    "null" | "undefined" => Json::null()
    "number" => Json::number(value.cast())
    "boolean" => Json::boolean(value.cast())
    "string" => Json::string(value.cast())
    "array" => {
      let items : Array[@core.JsValue] = value.cast()
      Json::array(items.map(node_material_js_to_json))
    }
    _ => {
      let fields : Map[String, Json] = Map([])
      for key in node_material_js_keys(value) {
        let v = value.get(key)
        if !v.is_undefined() {
          fields[key] = node_material_js_to_json(v)
        }
      }
      Json::object(fields)
    }
  }
}

///|
/// Copies the entries a JS cache gained into `cache`.
fn node_material_cache_from_js(
  object : @core.JsValue,
  cache : Map[String, Json],
) -> Unit {
  for key in node_material_js_keys(object) {
    if !cache.contains(key) {
      cache[key] = node_material_js_to_json(object.get(key))
    }
  }
}

///|
/// `setDefaultValues( material )` for the flat subclass fields: each one this material
/// leaves `undefined` takes the default (cloned when it has `clone`).
fn node_material_set_default_fields(
  target : @core.Material,
  defaults : @core.Material,
) -> Unit {
  if target.defines is None {
    target.defines = defaults.defines
  }
  if target.color is None {
    target.color = defaults.color.map(v => v.clone())
  }
  if target.map is None {
    target.map = defaults.map.map(v => v.clone())
  }
  if target.linewidth is None {
    target.linewidth = defaults.linewidth
  }
  if target.linecap is None {
    target.linecap = defaults.linecap
  }
  if target.linejoin is None {
    target.linejoin = defaults.linejoin
  }
  if target.fog is None {
    target.fog = defaults.fog
  }
  if target.scale is None {
    target.scale = defaults.scale
  }
  if target.dash_size is None {
    target.dash_size = defaults.dash_size
  }
  if target.gap_size is None {
    target.gap_size = defaults.gap_size
  }
  if target.light_map is None {
    target.light_map = defaults.light_map.map(v => v.clone())
  }
  if target.light_map_intensity is None {
    target.light_map_intensity = defaults.light_map_intensity
  }
  if target.ao_map is None {
    target.ao_map = defaults.ao_map.map(v => v.clone())
  }
  if target.ao_map_intensity is None {
    target.ao_map_intensity = defaults.ao_map_intensity
  }
  if target.specular_map is None {
    target.specular_map = defaults.specular_map.map(v => v.clone())
  }
  if target.alpha_map is None {
    target.alpha_map = defaults.alpha_map.map(v => v.clone())
  }
  if target.env_map is None {
    target.env_map = defaults.env_map.map(v => v.clone())
  }
  if target.env_map_rotation is None {
    target.env_map_rotation = defaults.env_map_rotation.map(v => v.clone())
  }
  if target.env_map_intensity is None {
    target.env_map_intensity = defaults.env_map_intensity
  }
  if target.combine is None {
    target.combine = defaults.combine
  }
  if target.reflectivity is None {
    target.reflectivity = defaults.reflectivity
  }
  if target.refraction_ratio is None {
    target.refraction_ratio = defaults.refraction_ratio
  }
  if target.wireframe is None {
    target.wireframe = defaults.wireframe
  }
  if target.wireframe_linewidth is None {
    target.wireframe_linewidth = defaults.wireframe_linewidth
  }
  if target.wireframe_linecap is None {
    target.wireframe_linecap = defaults.wireframe_linecap
  }
  if target.wireframe_linejoin is None {
    target.wireframe_linejoin = defaults.wireframe_linejoin
  }
  if target.depth_packing is None {
    target.depth_packing = defaults.depth_packing
  }
  if target.displacement_map is None {
    target.displacement_map = defaults.displacement_map.map(v => v.clone())
  }
  if target.displacement_scale is None {
    target.displacement_scale = defaults.displacement_scale
  }
  if target.displacement_bias is None {
    target.displacement_bias = defaults.displacement_bias
  }
  if target.emissive is None {
    target.emissive = defaults.emissive.map(v => v.clone())
  }
  if target.emissive_intensity is None {
    target.emissive_intensity = defaults.emissive_intensity
  }
  if target.emissive_map is None {
    target.emissive_map = defaults.emissive_map.map(v => v.clone())
  }
  if target.bump_map is None {
    target.bump_map = defaults.bump_map.map(v => v.clone())
  }
  if target.bump_scale is None {
    target.bump_scale = defaults.bump_scale
  }
  if target.normal_map is None {
    target.normal_map = defaults.normal_map.map(v => v.clone())
  }
  if target.normal_map_type is None {
    target.normal_map_type = defaults.normal_map_type
  }
  if target.normal_scale is None {
    target.normal_scale = defaults.normal_scale.map(v => v.clone())
  }
  if target.flat_shading is None {
    target.flat_shading = defaults.flat_shading
  }
  if target.matcap is None {
    target.matcap = defaults.matcap.map(v => v.clone())
  }
  if target.gradient_map is None {
    target.gradient_map = defaults.gradient_map.map(v => v.clone())
  }
  if target.specular is None {
    target.specular = defaults.specular.map(v => v.clone())
  }
  if target.shininess is None {
    target.shininess = defaults.shininess
  }
  if target.roughness is None {
    target.roughness = defaults.roughness
  }
  if target.metalness is None {
    target.metalness = defaults.metalness
  }
  if target.roughness_map is None {
    target.roughness_map = defaults.roughness_map.map(v => v.clone())
  }
  if target.metalness_map is None {
    target.metalness_map = defaults.metalness_map.map(v => v.clone())
  }
  if target.size is None {
    target.size = defaults.size
  }
  if target.size_attenuation is None {
    target.size_attenuation = defaults.size_attenuation
  }
  if target.rotation is None {
    target.rotation = defaults.rotation
  }
  if target.lights is None {
    target.lights = defaults.lights
  }
  if target.anisotropy_rotation is None {
    target.anisotropy_rotation = defaults.anisotropy_rotation
  }
  if target.anisotropy_map is None {
    target.anisotropy_map = defaults.anisotropy_map.map(v => v.clone())
  }
  if target.clearcoat_map is None {
    target.clearcoat_map = defaults.clearcoat_map.map(v => v.clone())
  }
  if target.clearcoat_roughness is None {
    target.clearcoat_roughness = defaults.clearcoat_roughness
  }
  if target.clearcoat_roughness_map is None {
    target.clearcoat_roughness_map = defaults.clearcoat_roughness_map.map(v => {
      v.clone()
    })
  }
  if target.clearcoat_normal_scale is None {
    target.clearcoat_normal_scale = defaults.clearcoat_normal_scale.map(v => {
      v.clone()
    })
  }
  if target.clearcoat_normal_map is None {
    target.clearcoat_normal_map = defaults.clearcoat_normal_map.map(v => {
      v.clone()
    })
  }
  if target.diffuse_roughness_map is None {
    target.diffuse_roughness_map = defaults.diffuse_roughness_map.map(v => {
      v.clone()
    })
  }
  if target.ior is None {
    target.ior = defaults.ior
  }
  if target.iridescence_map is None {
    target.iridescence_map = defaults.iridescence_map.map(v => v.clone())
  }
  if target.iridescence_ior is None {
    target.iridescence_ior = defaults.iridescence_ior
  }
  if target.iridescence_thickness_minimum is None {
    target.iridescence_thickness_minimum = defaults.iridescence_thickness_minimum
  }
  if target.iridescence_thickness_maximum is None {
    target.iridescence_thickness_maximum = defaults.iridescence_thickness_maximum
  }
  if target.iridescence_thickness_map is None {
    target.iridescence_thickness_map = defaults.iridescence_thickness_map.map(v => {
      v.clone()
    })
  }
  if target.sheen_color is None {
    target.sheen_color = defaults.sheen_color.map(v => v.clone())
  }
  if target.sheen_color_map is None {
    target.sheen_color_map = defaults.sheen_color_map.map(v => v.clone())
  }
  if target.sheen_roughness is None {
    target.sheen_roughness = defaults.sheen_roughness
  }
  if target.sheen_roughness_map is None {
    target.sheen_roughness_map = defaults.sheen_roughness_map.map(v => v.clone())
  }
  if target.transmission_map is None {
    target.transmission_map = defaults.transmission_map.map(v => v.clone())
  }
  if target.thickness is None {
    target.thickness = defaults.thickness
  }
  if target.thickness_map is None {
    target.thickness_map = defaults.thickness_map.map(v => v.clone())
  }
  if target.attenuation_distance is None {
    target.attenuation_distance = defaults.attenuation_distance
  }
  if target.attenuation_color is None {
    target.attenuation_color = defaults.attenuation_color.map(v => v.clone())
  }
  if target.specular_intensity is None {
    target.specular_intensity = defaults.specular_intensity
  }
  if target.specular_intensity_map is None {
    target.specular_intensity_map = defaults.specular_intensity_map.map(v => {
      v.clone()
    })
  }
  if target.specular_color is None {
    target.specular_color = defaults.specular_color.map(v => v.clone())
  }
  if target.specular_color_map is None {
    target.specular_color_map = defaults.specular_color_map.map(v => v.clone())
  }
  if target._anisotropy is None {
    target._anisotropy = defaults._anisotropy
  }
  if target._clearcoat is None {
    target._clearcoat = defaults._clearcoat
  }
  if target._diffuse_roughness is None {
    target._diffuse_roughness = defaults._diffuse_roughness
  }
  if target._dispersion is None {
    target._dispersion = defaults._dispersion
  }
  if target._iridescence is None {
    target._iridescence = defaults._iridescence
  }
  if target._retroreflectivity is None {
    target._retroreflectivity = defaults._retroreflectivity
  }
  if target._sheen is None {
    target._sheen = defaults._sheen
  }
  if target._transmission is None {
    target._transmission = defaults._transmission
  }
}

///|
/// The own-property loop of `copy( source )` over the flat subclass fields (`.copy` in
/// place where the current value has one; `_`-prefixed fields are skipped).
fn node_material_copy_fields(
  target : @core.Material,
  source : @core.Material,
) -> Unit {
  target.defines = source.defines
  match (target.color, source.color) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.color = s
  }
  match (target.map, source.map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.map = s
  }
  target.linewidth = source.linewidth
  target.linecap = source.linecap
  target.linejoin = source.linejoin
  target.fog = source.fog
  target.scale = source.scale
  target.dash_size = source.dash_size
  target.gap_size = source.gap_size
  match (target.light_map, source.light_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.light_map = s
  }
  target.light_map_intensity = source.light_map_intensity
  match (target.ao_map, source.ao_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.ao_map = s
  }
  target.ao_map_intensity = source.ao_map_intensity
  match (target.specular_map, source.specular_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.specular_map = s
  }
  match (target.alpha_map, source.alpha_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.alpha_map = s
  }
  match (target.env_map, source.env_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.env_map = s
  }
  match (target.env_map_rotation, source.env_map_rotation) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.env_map_rotation = s
  }
  target.env_map_intensity = source.env_map_intensity
  target.combine = source.combine
  target.reflectivity = source.reflectivity
  target.refraction_ratio = source.refraction_ratio
  target.wireframe = source.wireframe
  target.wireframe_linewidth = source.wireframe_linewidth
  target.wireframe_linecap = source.wireframe_linecap
  target.wireframe_linejoin = source.wireframe_linejoin
  target.depth_packing = source.depth_packing
  match (target.displacement_map, source.displacement_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.displacement_map = s
  }
  target.displacement_scale = source.displacement_scale
  target.displacement_bias = source.displacement_bias
  match (target.emissive, source.emissive) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.emissive = s
  }
  target.emissive_intensity = source.emissive_intensity
  match (target.emissive_map, source.emissive_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.emissive_map = s
  }
  match (target.bump_map, source.bump_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.bump_map = s
  }
  target.bump_scale = source.bump_scale
  match (target.normal_map, source.normal_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.normal_map = s
  }
  target.normal_map_type = source.normal_map_type
  match (target.normal_scale, source.normal_scale) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.normal_scale = s
  }
  target.flat_shading = source.flat_shading
  match (target.matcap, source.matcap) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.matcap = s
  }
  match (target.gradient_map, source.gradient_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.gradient_map = s
  }
  match (target.specular, source.specular) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.specular = s
  }
  target.shininess = source.shininess
  target.roughness = source.roughness
  target.metalness = source.metalness
  match (target.roughness_map, source.roughness_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.roughness_map = s
  }
  match (target.metalness_map, source.metalness_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.metalness_map = s
  }
  target.size = source.size
  // `sizeAttenuation` is an accessor of the sprite classes (SpriteNodeMaterial copies
  // it); other node materials do not have it
  target.rotation = source.rotation
  target.lights = source.lights
  target.anisotropy_rotation = source.anisotropy_rotation
  match (target.anisotropy_map, source.anisotropy_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.anisotropy_map = s
  }
  match (target.clearcoat_map, source.clearcoat_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.clearcoat_map = s
  }
  target.clearcoat_roughness = source.clearcoat_roughness
  match (target.clearcoat_roughness_map, source.clearcoat_roughness_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.clearcoat_roughness_map = s
  }
  match (target.clearcoat_normal_scale, source.clearcoat_normal_scale) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.clearcoat_normal_scale = s
  }
  match (target.clearcoat_normal_map, source.clearcoat_normal_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.clearcoat_normal_map = s
  }
  match (target.diffuse_roughness_map, source.diffuse_roughness_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.diffuse_roughness_map = s
  }
  target.ior = source.ior
  match (target.iridescence_map, source.iridescence_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.iridescence_map = s
  }
  target.iridescence_ior = source.iridescence_ior
  target.iridescence_thickness_minimum = source.iridescence_thickness_minimum
  target.iridescence_thickness_maximum = source.iridescence_thickness_maximum
  match (target.iridescence_thickness_map, source.iridescence_thickness_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.iridescence_thickness_map = s
  }
  match (target.sheen_color, source.sheen_color) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.sheen_color = s
  }
  match (target.sheen_color_map, source.sheen_color_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.sheen_color_map = s
  }
  target.sheen_roughness = source.sheen_roughness
  match (target.sheen_roughness_map, source.sheen_roughness_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.sheen_roughness_map = s
  }
  match (target.transmission_map, source.transmission_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.transmission_map = s
  }
  target.thickness = source.thickness
  match (target.thickness_map, source.thickness_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.thickness_map = s
  }
  target.attenuation_distance = source.attenuation_distance
  match (target.attenuation_color, source.attenuation_color) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.attenuation_color = s
  }
  target.specular_intensity = source.specular_intensity
  match (target.specular_intensity_map, source.specular_intensity_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.specular_intensity_map = s
  }
  match (target.specular_color, source.specular_color) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.specular_color = s
  }
  match (target.specular_color_map, source.specular_color_map) {
    (Some(t), Some(s)) => t.copy(s) |> ignore
    (_, s) => target.specular_color_map = s
  }
}

///|
/// `nodeMaterial[ key ] = material[ key ]` for the flat subclass fields `material` has
/// (a field without a value is a property its class does not define).
pub fn NodeMaterial::assign_defined_fields(
  target : @core.Material,
  source : @core.Material,
) -> Unit {
  if source.defines is Some(_) {
    target.defines = source.defines
  }
  if source.color is Some(_) {
    target.color = source.color
  }
  if source.map is Some(_) {
    target.map = source.map
  }
  if source.linewidth is Some(_) {
    target.linewidth = source.linewidth
  }
  if source.linecap is Some(_) {
    target.linecap = source.linecap
  }
  if source.linejoin is Some(_) {
    target.linejoin = source.linejoin
  }
  if source.fog is Some(_) {
    target.fog = source.fog
  }
  if source.scale is Some(_) {
    target.scale = source.scale
  }
  if source.dash_size is Some(_) {
    target.dash_size = source.dash_size
  }
  if source.gap_size is Some(_) {
    target.gap_size = source.gap_size
  }
  if source.light_map is Some(_) {
    target.light_map = source.light_map
  }
  if source.light_map_intensity is Some(_) {
    target.light_map_intensity = source.light_map_intensity
  }
  if source.ao_map is Some(_) {
    target.ao_map = source.ao_map
  }
  if source.ao_map_intensity is Some(_) {
    target.ao_map_intensity = source.ao_map_intensity
  }
  if source.specular_map is Some(_) {
    target.specular_map = source.specular_map
  }
  if source.alpha_map is Some(_) {
    target.alpha_map = source.alpha_map
  }
  if source.env_map is Some(_) {
    target.env_map = source.env_map
  }
  if source.env_map_rotation is Some(_) {
    target.env_map_rotation = source.env_map_rotation
  }
  if source.env_map_intensity is Some(_) {
    target.env_map_intensity = source.env_map_intensity
  }
  if source.combine is Some(_) {
    target.combine = source.combine
  }
  if source.reflectivity is Some(_) {
    target.reflectivity = source.reflectivity
  }
  if source.refraction_ratio is Some(_) {
    target.refraction_ratio = source.refraction_ratio
  }
  if source.wireframe is Some(_) {
    target.wireframe = source.wireframe
  }
  if source.wireframe_linewidth is Some(_) {
    target.wireframe_linewidth = source.wireframe_linewidth
  }
  if source.wireframe_linecap is Some(_) {
    target.wireframe_linecap = source.wireframe_linecap
  }
  if source.wireframe_linejoin is Some(_) {
    target.wireframe_linejoin = source.wireframe_linejoin
  }
  if source.depth_packing is Some(_) {
    target.depth_packing = source.depth_packing
  }
  if source.displacement_map is Some(_) {
    target.displacement_map = source.displacement_map
  }
  if source.displacement_scale is Some(_) {
    target.displacement_scale = source.displacement_scale
  }
  if source.displacement_bias is Some(_) {
    target.displacement_bias = source.displacement_bias
  }
  if source.emissive is Some(_) {
    target.emissive = source.emissive
  }
  if source.emissive_intensity is Some(_) {
    target.emissive_intensity = source.emissive_intensity
  }
  if source.emissive_map is Some(_) {
    target.emissive_map = source.emissive_map
  }
  if source.bump_map is Some(_) {
    target.bump_map = source.bump_map
  }
  if source.bump_scale is Some(_) {
    target.bump_scale = source.bump_scale
  }
  if source.normal_map is Some(_) {
    target.normal_map = source.normal_map
  }
  if source.normal_map_type is Some(_) {
    target.normal_map_type = source.normal_map_type
  }
  if source.normal_scale is Some(_) {
    target.normal_scale = source.normal_scale
  }
  if source.flat_shading is Some(_) {
    target.flat_shading = source.flat_shading
  }
  if source.matcap is Some(_) {
    target.matcap = source.matcap
  }
  if source.gradient_map is Some(_) {
    target.gradient_map = source.gradient_map
  }
  if source.specular is Some(_) {
    target.specular = source.specular
  }
  if source.shininess is Some(_) {
    target.shininess = source.shininess
  }
  if source.roughness is Some(_) {
    target.roughness = source.roughness
  }
  if source.metalness is Some(_) {
    target.metalness = source.metalness
  }
  if source.roughness_map is Some(_) {
    target.roughness_map = source.roughness_map
  }
  if source.metalness_map is Some(_) {
    target.metalness_map = source.metalness_map
  }
  if source.size is Some(_) {
    target.size = source.size
  }
  if source.size_attenuation is Some(_) {
    target.size_attenuation = source.size_attenuation
  }
  if source.rotation is Some(_) {
    target.rotation = source.rotation
  }
  if source.uniforms is Some(_) {
    target.uniforms = source.uniforms
  }
  if source.uniforms_groups is Some(_) {
    target.uniforms_groups = source.uniforms_groups
  }
  if source.vertex_shader is Some(_) {
    target.vertex_shader = source.vertex_shader
  }
  if source.fragment_shader is Some(_) {
    target.fragment_shader = source.fragment_shader
  }
  if source.lights is Some(_) {
    target.lights = source.lights
  }
  if source.clipping is Some(_) {
    target.clipping = source.clipping
  }
  if source.extensions is Some(_) {
    target.extensions = source.extensions
  }
  if source.default_attribute_values is Some(_) {
    target.default_attribute_values = source.default_attribute_values
  }
  if source.index0_attribute_name is Some(_) {
    target.index0_attribute_name = source.index0_attribute_name
  }
  if source.uniforms_need_update is Some(_) {
    target.uniforms_need_update = source.uniforms_need_update
  }
  if source.glsl_version is Some(_) {
    target.glsl_version = source.glsl_version
  }
  if source.anisotropy_rotation is Some(_) {
    target.anisotropy_rotation = source.anisotropy_rotation
  }
  if source.anisotropy_map is Some(_) {
    target.anisotropy_map = source.anisotropy_map
  }
  if source.clearcoat_map is Some(_) {
    target.clearcoat_map = source.clearcoat_map
  }
  if source.clearcoat_roughness is Some(_) {
    target.clearcoat_roughness = source.clearcoat_roughness
  }
  if source.clearcoat_roughness_map is Some(_) {
    target.clearcoat_roughness_map = source.clearcoat_roughness_map
  }
  if source.clearcoat_normal_scale is Some(_) {
    target.clearcoat_normal_scale = source.clearcoat_normal_scale
  }
  if source.clearcoat_normal_map is Some(_) {
    target.clearcoat_normal_map = source.clearcoat_normal_map
  }
  if source.diffuse_roughness_map is Some(_) {
    target.diffuse_roughness_map = source.diffuse_roughness_map
  }
  if source.ior is Some(_) {
    target.ior = source.ior
  }
  if source.iridescence_map is Some(_) {
    target.iridescence_map = source.iridescence_map
  }
  if source.iridescence_ior is Some(_) {
    target.iridescence_ior = source.iridescence_ior
  }
  if source.iridescence_thickness_minimum is Some(_) {
    target.iridescence_thickness_minimum = source.iridescence_thickness_minimum
  }
  if source.iridescence_thickness_maximum is Some(_) {
    target.iridescence_thickness_maximum = source.iridescence_thickness_maximum
  }
  if source.iridescence_thickness_map is Some(_) {
    target.iridescence_thickness_map = source.iridescence_thickness_map
  }
  if source.sheen_color is Some(_) {
    target.sheen_color = source.sheen_color
  }
  if source.sheen_color_map is Some(_) {
    target.sheen_color_map = source.sheen_color_map
  }
  if source.sheen_roughness is Some(_) {
    target.sheen_roughness = source.sheen_roughness
  }
  if source.sheen_roughness_map is Some(_) {
    target.sheen_roughness_map = source.sheen_roughness_map
  }
  if source.transmission_map is Some(_) {
    target.transmission_map = source.transmission_map
  }
  if source.thickness is Some(_) {
    target.thickness = source.thickness
  }
  if source.thickness_map is Some(_) {
    target.thickness_map = source.thickness_map
  }
  if source.attenuation_distance is Some(_) {
    target.attenuation_distance = source.attenuation_distance
  }
  if source.attenuation_color is Some(_) {
    target.attenuation_color = source.attenuation_color
  }
  if source.specular_intensity is Some(_) {
    target.specular_intensity = source.specular_intensity
  }
  if source.specular_intensity_map is Some(_) {
    target.specular_intensity_map = source.specular_intensity_map
  }
  if source.specular_color is Some(_) {
    target.specular_color = source.specular_color
  }
  if source.specular_color_map is Some(_) {
    target.specular_color_map = source.specular_color_map
  }
  if source._anisotropy is Some(_) {
    target._anisotropy = source._anisotropy
  }
  if source._clearcoat is Some(_) {
    target._clearcoat = source._clearcoat
  }
  if source._diffuse_roughness is Some(_) {
    target._diffuse_roughness = source._diffuse_roughness
  }
  if source._dispersion is Some(_) {
    target._dispersion = source._dispersion
  }
  if source._iridescence is Some(_) {
    target._iridescence = source._iridescence
  }
  if source._retroreflectivity is Some(_) {
    target._retroreflectivity = source._retroreflectivity
  }
  if source._sheen is Some(_) {
    target._sheen = source._sheen
  }
  if source._transmission is Some(_) {
    target._transmission = source._transmission
  }
}

///|
/// The names of those fields (the JS keys `NodeLibrary.fromMaterial` leaves to
/// `assign_defined_fields`).
pub let node_material_optional_fields : Array[String] = [
  "defines", "color", "map", "linewidth", "linecap", "linejoin", "fog", "scale",
  "dash_size", "gap_size", "light_map", "light_map_intensity", "ao_map", "ao_map_intensity",
  "specular_map", "alpha_map", "env_map", "env_map_rotation", "env_map_intensity",
  "combine", "reflectivity", "refraction_ratio", "wireframe", "wireframe_linewidth",
  "wireframe_linecap", "wireframe_linejoin", "depth_packing", "displacement_map",
  "displacement_scale", "displacement_bias", "emissive", "emissive_intensity", "emissive_map",
  "bump_map", "bump_scale", "normal_map", "normal_map_type", "normal_scale", "flat_shading",
  "matcap", "gradient_map", "specular", "shininess", "roughness", "metalness", "roughness_map",
  "metalness_map", "size", "size_attenuation", "rotation", "uniforms", "uniforms_groups",
  "vertex_shader", "fragment_shader", "lights", "clipping", "extensions", "default_attribute_values",
  "index0_attribute_name", "uniforms_need_update", "glsl_version", "anisotropy_rotation",
  "anisotropy_map", "clearcoat_map", "clearcoat_roughness", "clearcoat_roughness_map",
  "clearcoat_normal_scale", "clearcoat_normal_map", "diffuse_roughness_map", "ior",
  "iridescence_map", "iridescence_ior", "iridescence_thickness_minimum", "iridescence_thickness_maximum",
  "iridescence_thickness_map", "sheen_color", "sheen_color_map", "sheen_roughness",
  "sheen_roughness_map", "transmission_map", "thickness", "thickness_map", "attenuation_distance",
  "attenuation_color", "specular_intensity", "specular_intensity_map", "specular_color",
  "specular_color_map", "_anisotropy", "_clearcoat", "_diffuse_roughness", "_dispersion",
  "_iridescence", "_retroreflectivity", "_sheen", "_transmission",
]
