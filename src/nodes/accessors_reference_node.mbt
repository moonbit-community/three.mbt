// nodes/accessors/ReferenceNode.js: a uniform (texture, buffer, array) whose value is
// read from a property path of an object on every update.
//
// Upstream reads `object[ property ]` dynamically. Here the object is a
// `ReferenceObject`, and each kind maps upstream's property names to its fields
// (`reference_object_value`): materials, objects (cameras, skinned and instanced
// meshes, sprites), light shadows, fogs, the renderer and plain JS objects.

///|
/// A custom reference target: its identity (the update key) and its properties.
pub(open) trait ReferenceSource {
  fn identity(Self) -> @core.JsValue
  /// `object[ property ]`.
  fn get_property(Self, String) -> TslValue
}

///|
/// The object a reference node reads.
pub(all) enum ReferenceObject {
  Material(@core.Material)
  Object3D(@core.Object3D)
  Shadow(@core.LightShadow)
  Fog(@core.SceneFog)
  Renderer(Renderer)
  /// A plain JS object (`userData`), read with JS property access.
  Js(@core.JsValue)
  Custom(&ReferenceSource)
}

///|
/// The JS identity of a reference object (`updateReference` returns it).
pub fn ReferenceObject::identity(self : ReferenceObject) -> @core.JsValue {
  match self {
    Material(m) => @core.JsValue::of(m)
    Object3D(o) => @core.JsValue::of(o)
    Shadow(s) => @core.JsValue::of(s)
    Fog(f) => @core.JsValue::of(f)
    Renderer(r) => @core.JsValue::of(r)
    Js(v) => v
    Custom(c) => c.identity()
  }
}

///|
extern "js" fn reference_js_get(
  object : @core.JsValue,
  key : String,
) -> @core.JsValue = "(o, k) => (o === null || o === undefined) ? undefined : o[k]"

///|
extern "js" fn reference_js_type_of(value : @core.JsValue) -> String = "(v) => v === null ? 'null' : Array.isArray(v) ? 'array' : typeof v"

///|
/// `camelCase` -> `snake_case`, the MoonBit field name of an upstream property.
extern "js" fn reference_snake_case(key : String) -> String = "(k) => k.replace(/[A-Z]/g, (m) => '_' + m.toLowerCase())"

///|
/// A JS value as TSL sees it.
pub fn reference_tsl_of_js(value : @core.JsValue) -> TslValue {
  match reference_js_type_of(value) {
    "undefined" => Undefined
    "null" => Null
    "number" => Number(value.cast())
    "boolean" => Bool(value.cast())
    "string" => String(value.cast())
    "array" => {
      let items : Array[@core.JsValue] = value.cast()
      Array(items.map(reference_tsl_of_js))
    }
    _ => Js(value)
  }
}

///|
fn reference_number(value : Double?) -> TslValue {
  match value {
    Some(v) => Number(v)
    None => Undefined
  }
}

///|
fn reference_texture(value : @core.Texture?) -> TslValue {
  match value {
    Some(t) => Texture(t)
    None => Null
  }
}

///|
fn reference_color(value : @math.Color?) -> TslValue {
  match value {
    Some(c) => Color(c)
    None => Undefined
  }
}

///|
fn reference_vector2(value : @math.Vector2?) -> TslValue {
  match value {
    Some(v) => Vector2(v)
    None => Undefined
  }
}

///|
/// `material[ key ]` for the properties materials have.
pub fn reference_material_value(m : @core.Material, key : String) -> TslValue {
  match key {
    "opacity" => Number(m.opacity)
    "alphaTest" => Number(m.alpha_test())
    "transparent" => Bool(m.transparent)
    "side" => Number(m.side.to_double())
    "vertexColors" => Bool(m.vertex_colors)
    "visible" => Bool(m.visible)
    "version" => Number(m.version.to_double())
    "userData" => Js(m.user_data)
    "color" => reference_color(m.color)
    "map" => reference_texture(m.map)
    "linewidth" => reference_number(m.linewidth)
    "scale" => reference_number(m.scale)
    "dashSize" => reference_number(m.dash_size)
    "gapSize" => reference_number(m.gap_size)
    "lightMap" => reference_texture(m.light_map)
    "lightMapIntensity" => reference_number(m.light_map_intensity)
    "aoMap" => reference_texture(m.ao_map)
    "aoMapIntensity" => reference_number(m.ao_map_intensity)
    "specularMap" => reference_texture(m.specular_map)
    "alphaMap" => reference_texture(m.alpha_map)
    "envMap" => reference_texture(m.env_map)
    "envMapIntensity" => reference_number(m.env_map_intensity)
    "reflectivity" => reference_number(m.reflectivity())
    "refractionRatio" => reference_number(m.refraction_ratio)
    "displacementMap" => reference_texture(m.displacement_map)
    "displacementScale" => reference_number(m.displacement_scale)
    "displacementBias" => reference_number(m.displacement_bias)
    "emissive" => reference_color(m.emissive)
    "emissiveIntensity" => reference_number(m.emissive_intensity)
    "emissiveMap" => reference_texture(m.emissive_map)
    "bumpMap" => reference_texture(m.bump_map)
    "bumpScale" => reference_number(m.bump_scale)
    "normalMap" => reference_texture(m.normal_map)
    "normalScale" => reference_vector2(m.normal_scale)
    "matcap" => reference_texture(m.matcap)
    "gradientMap" => reference_texture(m.gradient_map)
    "specular" => reference_color(m.specular)
    "shininess" => reference_number(m.shininess)
    "roughness" => reference_number(m.roughness)
    "metalness" => reference_number(m.metalness)
    "roughnessMap" => reference_texture(m.roughness_map)
    "metalnessMap" => reference_texture(m.metalness_map)
    "size" => reference_number(m.size)
    "rotation" => reference_number(m.rotation)
    "anisotropy" => reference_number(m._anisotropy)
    "anisotropyRotation" => reference_number(m.anisotropy_rotation)
    "anisotropyMap" => reference_texture(m.anisotropy_map)
    "clearcoat" => reference_number(m._clearcoat)
    "clearcoatMap" => reference_texture(m.clearcoat_map)
    "clearcoatRoughness" => reference_number(m.clearcoat_roughness)
    "clearcoatRoughnessMap" => reference_texture(m.clearcoat_roughness_map)
    "clearcoatNormalScale" => reference_vector2(m.clearcoat_normal_scale)
    "clearcoatNormalMap" => reference_texture(m.clearcoat_normal_map)
    "diffuseRoughness" => reference_number(m._diffuse_roughness)
    "diffuseRoughnessMap" => reference_texture(m.diffuse_roughness_map)
    "dispersion" => reference_number(m._dispersion)
    "ior" => reference_number(m.ior)
    "iridescence" => reference_number(m._iridescence)
    "iridescenceMap" => reference_texture(m.iridescence_map)
    "iridescenceIOR" => reference_number(m.iridescence_ior)
    "iridescenceThicknessMinimum" =>
      reference_number(m.iridescence_thickness_minimum)
    "iridescenceThicknessMaximum" =>
      reference_number(m.iridescence_thickness_maximum)
    "iridescenceThicknessMap" => reference_texture(m.iridescence_thickness_map)
    "retroreflectivity" => reference_number(m._retroreflectivity)
    "sheen" => reference_number(m._sheen)
    "sheenColor" => reference_color(m.sheen_color)
    "sheenColorMap" => reference_texture(m.sheen_color_map)
    "sheenRoughness" => reference_number(m.sheen_roughness)
    "sheenRoughnessMap" => reference_texture(m.sheen_roughness_map)
    "transmission" => reference_number(m._transmission)
    "transmissionMap" => reference_texture(m.transmission_map)
    "thickness" => reference_number(m.thickness)
    "thicknessMap" => reference_texture(m.thickness_map)
    "attenuationDistance" => reference_number(m.attenuation_distance)
    "attenuationColor" => reference_color(m.attenuation_color)
    "specularIntensity" => reference_number(m.specular_intensity)
    "specularIntensityMap" => reference_texture(m.specular_intensity_map)
    "specularColor" => reference_color(m.specular_color)
    "specularColorMap" => reference_texture(m.specular_color_map)
    // members of node material classes (`dashOffset`, `steps`), added by G5
    _ =>
      match NodeMaterial::of(m) {
        Some(nm) =>
          match nm.class_.reference_value(m, key) {
            Some(v) => v
            None => Undefined
          }
        None => Undefined
      }
  }
}

///|
/// `object[ properties[ 0 ] ][ properties[ 1 ] ]...` for an `Object3D`.
fn reference_object3d_value(
  o : @core.Object3D,
  properties : ArrayView[String],
) -> TslValue {
  match properties {
    ["matrixWorld"] => Matrix4(o.matrix_world)
    ["matrix"] => Matrix4(o.matrix)
    ["position"] => Vector3(o.position)
    ["scale"] => Vector3(o.scale)
    ["modelViewMatrix"] => Matrix4(o.model_view_matrix)
    ["normalMatrix"] => Matrix3(o.normal_matrix)
    ["userData", .. rest] => reference_js_path(o.user_data, rest)
    ["near"] if o.is_camera() => Number(camera_near_of(o))
    ["far"] if o.is_camera() => Number(camera_far_of(o))
    ["projectionMatrix"] if o.is_camera() =>
      Matrix4(camera_data(o).projection_matrix)
    ["bindMatrix"] =>
      match o.kind {
        Mesh({ kind: SkinnedMesh(s), .. }) => Matrix4(s.bind_matrix)
        _ => Undefined
      }
    ["bindMatrixInverse"] =>
      match o.kind {
        Mesh({ kind: SkinnedMesh(s), .. }) => Matrix4(s.bind_matrix_inverse)
        _ => Undefined
      }
    ["skeleton", "boneMatrices"] =>
      match o.kind {
        Mesh({ kind: SkinnedMesh({ skeleton: Some(s), .. }), .. }) =>
          match s.bone_matrices {
            Some(a) => Js(@core.JsValue::of(a))
            None => Null
          }
        _ => abort("TypeError: Cannot read properties of undefined (skeleton)")
      }
    ["skeleton", "previousBoneMatrices"] =>
      match o.kind {
        Mesh({ kind: SkinnedMesh({ skeleton: Some(s), .. }), .. }) =>
          match s.previous_bone_matrices {
            Some(a) => Js(@core.JsValue::of(a))
            None => Null
          }
        _ => abort("TypeError: Cannot read properties of undefined (skeleton)")
      }
    ["morphTargetInfluences"] =>
      match o.kind {
        Mesh({ morph_target_influences: Some(a), .. }) =>
          Array(a.map(fn(x) { Number(x) }))
        _ => Undefined
      }
    ["count"] =>
      match o.kind {
        Mesh(m) => Number(m.count.to_double())
        Sprite(s) => Number(s.count.to_double())
        _ => Undefined
      }
    ["center"] =>
      match o.kind {
        Sprite(s) => Vector2(s.center)
        _ => Undefined
      }
    _ => Undefined
  }
}

///|
/// A property path of a light shadow.
fn reference_shadow_value(
  s : @core.LightShadow,
  properties : ArrayView[String],
) -> TslValue {
  match properties {
    ["radius"] => Number(s.radius)
    ["mapSize"] => Vector2(s.map_size)
    ["bias"] => Number(s.bias)
    ["normalBias"] => Number(s.normal_bias)
    ["blurSamples"] => Number(s.blur_samples.to_double())
    ["intensity"] => Number(s.intensity)
    ["matrix"] => Matrix4(s.matrix)
    ["camera", .. rest] => reference_object3d_value(s.camera, rest)
    _ => Undefined
  }
}

///|
/// A property path of a fog.
fn reference_fog_value(
  fog : @core.SceneFog,
  properties : ArrayView[String],
) -> TslValue {
  match (fog, properties) {
    (Fog(f), ["color"]) => Color(f.color)
    (Fog(f), ["near"]) => Number(f.near)
    (Fog(f), ["far"]) => Number(f.far)
    (FogExp2(f), ["color"]) => Color(f.color)
    (FogExp2(f), ["density"]) => Number(f.density)
    _ => Undefined
  }
}

///|
/// A property path of a JS object.
fn reference_js_path(
  object : @core.JsValue,
  properties : ArrayView[String],
) -> TslValue {
  let mut value = object
  for p in properties {
    value = reference_js_get(value, p)
  }
  reference_tsl_of_js(value)
}

///|
/// `getValueFromReference( object )`: `object[ properties[ 0 ] ][ ... ]`.
pub fn reference_object_value(
  object : ReferenceObject,
  properties : Array[String],
) -> TslValue {
  let path = properties[:]
  // properties assigned on the instance (`reference_set_instance_property`)
  match (object, path) {
    (Material(m), [key]) =>
      if reference_instance_property(@core.JsValue::of(m), key) is Some(v) {
        return v
      }
    (Object3D(o), [key]) =>
      if reference_instance_property(@core.JsValue::of(o), key) is Some(v) {
        return v
      }
    _ => ()
  }
  match object {
    Material(m) =>
      match path {
        [key] => reference_material_value(m, key)
        ["userData", .. rest] => reference_js_path(m.user_data, rest)
        _ => Undefined
      }
    Object3D(o) => reference_object3d_value(o, path)
    Shadow(s) => reference_shadow_value(s, path)
    Fog(f) => reference_fog_value(f, path)
    // Renderer fields keep upstream's names in snake_case.
    Renderer(r) =>
      reference_js_path(
        @core.JsValue::of(r),
        path.iter().map(reference_snake_case).collect()[:],
      )
    Js(v) => reference_js_path(v, path)
    Custom(c) =>
      match path {
        [key] => c.get_property(key)
        _ => Undefined
      }
  }
}

///|
/// `this.node.value = value` (or `.array` for arrays) on the node a reference made.
pub fn reference_set_node_value(node : Node, value : TslValue) -> Unit {
  match value {
    Array(items) if UniformArrayNode::of(node) is Some(u) => u.array = items
    _ =>
      if TextureNode::of(node) is Some(_) {
        TextureNode::set_value(
          node,
          match value {
            Texture(t) => Some(t)
            Js(v) => Some(v.cast())
            _ => None
          },
        )
      } else {
        InputNode::set_value(node, value)
      }
  }
}

///|
/// `{ object }` of a build or a frame.
fn reference_state_object(state : NodeUpdateState) -> @core.Object3D? {
  match state {
    Builder(b) =>
      match b.object {
        Object3D(o) => Some(o)
        _ => None
      }
    Frame(f) => f.object
  }
}

///|
pub(all) struct ReferenceNode {
  property : String
  uniform_type : String?
  object : ReferenceObject?
  count : Int32?
  properties : Array[String]
  mut reference : ReferenceObject?
  mut node : Node?
  mut group : Node?
}

///|
pub impl NodeClass for ReferenceNode with fn class_name(_) {
  "ReferenceNode"
}

///|
pub impl NodeClass for ReferenceNode with fn children(self, _, out) {
  push_child(out, "node", self.node)
  push_child(out, "group", self.group)
}

///|
pub impl NodeClass for ReferenceNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for ReferenceNode with fn element(_, node, index_node) {
  Some(ReferenceElementNode::new(node, index_node))
}

///|
pub impl NodeClass for ReferenceNode with fn set_name(_, node, name) {
  node.name = Some(name)
  Some(node)
}

///|
pub impl NodeClass for ReferenceNode with fn label(_, node, name) {
  // @deprecated r179
  @core.warn("TSL: \"label()\" has been deprecated. Use \"setName()\" instead.")
  Some(node.set_name(name))
}

///|
pub impl NodeClass for ReferenceNode with fn generate_node_type(
  self,
  node,
  builder,
  _,
) {
  if self.node is None {
    node.update_reference(Builder(builder)) |> ignore
    ReferenceNode::update_value(node)
  }
  self.node.unwrap().get_node_type(builder)
}

///|
pub impl NodeClass for ReferenceNode with fn update_reference(self, _, state) {
  self.reference = match self.object {
    Some(o) => Some(o)
    None => reference_state_object(state).map(fn(o) { Object3D(o) })
  }
  ReferenceNode::reference_identity(self)
}

///|
pub impl NodeClass for ReferenceNode with fn setup(self, node, _) {
  ReferenceNode::update_value(node)
  self.node
}

///|
pub impl NodeClass for ReferenceNode with fn update(_, node, _) {
  ReferenceNode::update_value(node)
  None
}

///|
fn ReferenceNode::reference_identity(self : ReferenceNode) -> @core.JsValue {
  match self.reference {
    Some(r) => r.identity()
    None => @core.JsValue::null()
  }
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn ReferenceNode::construct(
  node : Node,
  property : String,
  uniform_type : String?,
  object : ReferenceObject?,
  count : Int32?,
) -> ReferenceNode {
  node.name = None
  node.update_type = NodeUpdateType::object()
  {
    property,
    uniform_type,
    object,
    count,
    properties: property.split(".").map(fn(s) { s.to_owned() }).collect(),
    reference: object,
    node: None,
    group: None,
  }
}

///|
/// `new ReferenceNode( property, uniformType, object = null, count = null )`.
pub fn ReferenceNode::new(
  property : String,
  uniform_type : String?,
  object? : ReferenceObject,
  count? : Int32,
) -> Node {
  let node = Node::alloc()
  node.set_class(
    ReferenceNode::construct(node, property, uniform_type, object, count),
  )
}

///|
pub fn ReferenceNode::of(node : Node) -> ReferenceNode? {
  match node.class_payload("ReferenceNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn reference_node_payload(node : Node) -> ReferenceNode {
  match ReferenceNode::of(node) {
    Some(r) => r
    None => abort("TypeError: \{node.type_()} is not a ReferenceNode")
  }
}

///|
/// `setGroup( group )` of a reference node (`Node::set_group` is UniformNode's).
pub fn ReferenceNode::set_group(node : Node, group : Node) -> Node {
  reference_node_payload(node).group = Some(group)
  node
}

///|
/// `setNodeType( uniformType )`: creates the uniform the reference feeds.
pub fn ReferenceNode::set_node_type(
  node : Node,
  uniform_type : String?,
) -> Unit {
  let r = reference_node_payload(node)
  let n = match r.count {
    Some(count) => BufferNode::new(Null, uniform_type, buffer_count=count)
    None =>
      if ReferenceNode::get_value_from_reference(node) is Array(_) {
        let n = uniform_array(TslValue::Null, element_type?=uniform_type)
        n.update_type = NodeUpdateType::object()
        n
      } else if uniform_type == Some("texture") {
        texture(TslValue::Null)
      } else if uniform_type == Some("cubeTexture") {
        cube_texture(TslValue::Null)
      } else {
        uniform(TslValue::Null, type_?=uniform_type)
      }
  }
  match r.group {
    Some(g) => n.set_group(g) |> ignore
    None => ()
  }
  match node.name {
    Some(name) => n.set_name(name) |> ignore
    None => ()
  }
  r.node = Some(n)
}

///|
/// `getValueFromReference( object = this.reference )`.
pub fn ReferenceNode::get_value_from_reference(
  node : Node,
  object? : ReferenceObject,
) -> TslValue {
  let r = reference_node_payload(node)
  let object = match object {
    Some(o) => Some(o)
    None => r.reference
  }
  match object {
    Some(o) => reference_object_value(o, r.properties)
    None =>
      abort(
        "TypeError: Cannot read properties of null (reading '\{r.properties[0]}')",
      )
  }
}

///|
/// `updateValue()`.
pub fn ReferenceNode::update_value(node : Node) -> Unit {
  let r = reference_node_payload(node)
  if r.node is None {
    ReferenceNode::set_node_type(node, r.uniform_type)
  }
  reference_set_node_value(
    r.node.unwrap(),
    ReferenceNode::get_value_from_reference(node),
  )
}

///|
/// `reference( name, type, object )`.
pub fn reference(
  name : String,
  type_ : String,
  object? : ReferenceObject,
) -> Node {
  ReferenceNode::new(name, Some(type_), object?)
}

///|
/// `referenceBuffer( name, type, count, object )`.
pub fn reference_buffer(
  name : String,
  type_ : String,
  count : Int32,
  object? : ReferenceObject,
) -> Node {
  ReferenceNode::new(name, Some(type_), object?, count~)
}

///|
/// Properties that code assigns on one material or object outside its class
/// (`material2.scale = new Vector2()`, `mesh2.color = ...` in LensflareMesh.js), keyed by
/// the instance's JS identity: name -> getter.
let _reference_instance_properties : @webgl.WeakMap[
  @core.JsValue,
  Map[String, () -> TslValue],
] = @webgl.WeakMap::new()

///|
/// Assigns `instance[ key ]` for a property the instance's class does not have
/// (`JsValue::of(material)` or `JsValue::of(object)`); reference nodes and the
/// material observer read it before the class's own properties.
pub fn reference_set_instance_property(
  instance : @core.JsValue,
  key : String,
  getter : () -> TslValue,
) -> Unit {
  match _reference_instance_properties.get(instance) {
    Some(properties) => properties[key] = getter
    None => _reference_instance_properties.set(instance, Map([(key, getter)]))
  }
}

///|
/// `instance[ key ]` for a property set with `reference_set_instance_property`.
pub fn reference_instance_property(
  instance : @core.JsValue,
  key : String,
) -> TslValue? {
  match _reference_instance_properties.get(instance) {
    Some(properties) =>
      match properties.get(key) {
        Some(getter) => Some(getter())
        None => None
      }
    None => None
  }
}
