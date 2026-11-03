// materials/nodes/manager/NodeMaterialObserver.js: decides whether a render object needs
// a refresh before it is rendered.

///|
/// Overrides of `NodeMaterialObserver` members (a JS subclass); added by G6 so the
/// renderer can run before the materials group ports the class.
pub(open) trait NodeMaterialObserverClass {
  /// `needsRefresh( renderObject, nodeFrame )`: a `RenderObjectRefreshType`.
  fn needs_refresh(Self, NodeMaterialObserver, RenderObject, NodeFrame) -> Int32
}

///|
let node_material_observer_refresh_uniforms : Array[String] = [
  "alphaMap", "alphaTest", "anisotropy", "anisotropyMap", "anisotropyRotation", "aoMap",
  "aoMapIntensity", "attenuationColor", "attenuationDistance", "bumpMap", "bumpScale",
  "clearcoat", "clearcoatMap", "clearcoatNormalMap", "clearcoatNormalScale", "clearcoatRoughness",
  "clearcoatRoughnessMap", "color", "dashOffset", "dashSize", "diffuseRoughness",
  "diffuseRoughnessMap", "dispersion", "displacementBias", "displacementMap", "displacementScale",
  "emissive", "emissiveIntensity", "emissiveMap", "envMap", "envMapIntensity", "envMapRotation",
  "gapSize", "gradientMap", "ior", "iridescence", "iridescenceIOR", "iridescenceMap",
  "iridescenceThicknessMap", "iridescenceThicknessMaximum", "iridescenceThicknessMinimum",
  "lightMap", "lightMapIntensity", "linewidth", "map", "matcap", "metalness", "metalnessMap",
  "normalMap", "normalScale", "opacity", "reflectivity", "refractionRatio", "retroreflectivity",
  "rotation", "roughness", "roughnessMap", "scale", "sheen", "sheenColor", "sheenColorMap",
  "sheenRoughness", "sheenRoughnessMap", "shininess", "size", "specular", "specularColor",
  "specularColorMap", "specularIntensity", "specularIntensityMap", "specularMap",
  "steps", "thickness", "thicknessMap", "transmission", "transmissionMap", "wireframe",
]

///|
/// `{ offset, repeat, center, rotation, matrix }` of a monitored texture.
priv struct ObserverTextureTransform {
  offset : @math.Vector2
  repeat : @math.Vector2
  center : @math.Vector2
  mut rotation : Double
  matrix : @math.Matrix3
}

///|
/// `{ id, version, cacheVersion, transform }` of a monitored texture property.
priv struct ObserverTextureValue {
  mut id : Int32
  mut version : Int32
  mut cache_version : Int32
  transform : ObserverTextureTransform
}

///|
/// A monitored material property value (`null`, a clone of an object, a texture
/// record or a primitive).
priv enum ObserverValue {
  Null
  Number(Double)
  Bool(Bool)
  Color(@math.Color)
  Vector2(@math.Vector2)
  Euler(@math.Euler)
  Texture(ObserverTextureValue)
  /// A texture as read from the material (not yet a record).
  TextureRef(@core.Texture)
}

///|
/// `{ _renderId, _version, [ property ]: value }` of a material.
priv struct ObserverMaterialData {
  mut _render_id : Int32
  mut _version : Int32
  /// The monitored properties, in insertion order.
  entries : Array[(String, Ref[ObserverValue])]
}

///|
/// `{ id, version }` of a geometry attribute (`id` is `attribute.id` or, for
/// interleaved attributes, `attribute.data.uuid`).
priv struct ObserverAttributeData {
  mut id : String
  mut version : Int32
}

///|
priv struct ObserverGeometryData {
  mut _render_id : Int32
  mut _version : Int32
  mut attributes : Map[String, ObserverAttributeData]
  mut index_id : String?
  mut index_version : Int32?
  mut draw_range_start : Int32
  mut draw_range_count : Double
}

///|
priv struct ObserverTextureData {
  mut _version : Int32
}

///|
priv struct ObserverOutputTargetData {
  mut _version : Int32
  mut width : Int32
  mut height : Int32
}

///|
/// `{ map, cacheVersion, shadowMapWidth, shadowMapHeight }` of a light (`None` is
/// `undefined`).
priv struct ObserverLightData {
  mut map : Int32?
  mut cache_version : Int32?
  mut shadow_map_width : Double?
  mut shadow_map_height : Double?
}

///|
priv struct ObserverLightsCache {
  mut render_id : Int32
  lights_data : Array[ObserverLightData]
}

///|
/// The output target of a renderer: a render target or the canvas target.
priv enum ObserverOutputTarget {
  RenderTarget(@core.RenderTarget)
  Canvas(CanvasTarget)
}

///|
fn ObserverOutputTarget::key(self : ObserverOutputTarget) -> @core.JsValue {
  match self {
    RenderTarget(t) => @core.JsValue::of(t)
    Canvas(c) => @core.JsValue::of(c)
  }
}

///|
fn ObserverOutputTarget::same(
  self : ObserverOutputTarget,
  other : ObserverOutputTarget,
) -> Bool {
  match (self, other) {
    (RenderTarget(a), RenderTarget(b)) => physical_equal(a, b)
    (Canvas(a), Canvas(b)) => physical_equal(a, b)
    _ => false
  }
}

///|
/// The monitoring data of a render object.
priv struct ObserverRenderObjectData {
  mut geometry_id : Int32
  mut geometry_version : Int32
  mut material_version : Int32
  mut attributes_dispose_version : Int32
  world_matrix : @math.Matrix4
  center : @math.Vector2?
  morph_target_influences : Array[Double]?
  mut instance_matrix : @core.BufferAttribute?
  mut instance_matrix_version : Int32
  mut instance_color : @core.BufferAttribute?
  mut instance_color_version : Int32?
  mut morph_texture_version : Int32?
  mut matrices_texture_version : Int32
  mut colors_texture_version : Int32?
  mut indirect_texture_version : Int32
  mut version : Int32?
  mut output_target : ObserverOutputTarget
  mut output_target_version : Int32
  mut environment_intensity : Double
  environment_rotation : @math.Euler
  mut environment_version : Int32?
  lights : Array[ObserverLightData]
}

///|
let node_material_observer_lights_cache : @webgl.WeakMap[
  Node,
  ObserverLightsCache,
] = @webgl.WeakMap::new()

///|
let node_material_observer_material_cache : @webgl.WeakMap[
  @core.Material,
  ObserverMaterialData,
] = @webgl.WeakMap::new()

///|
let node_material_observer_geometry_cache : @webgl.WeakMap[
  @core.BufferGeometry,
  ObserverGeometryData,
] = @webgl.WeakMap::new()

///|
let node_material_observer_texture_cache : @webgl.WeakMap[
  @core.Texture,
  ObserverTextureData,
] = @webgl.WeakMap::new()

///|
let node_material_observer_output_target_cache : @webgl.WeakMap[
  @core.JsValue,
  ObserverOutputTargetData,
] = @webgl.WeakMap::new()

///|
pub(all) struct NodeMaterialObserver {
  /// `renderObjects`, keyed by render object.
  priv render_objects : @webgl.WeakMap[RenderObject, ObserverRenderObjectData]
  /// Whether the builder's context uses node objects.
  mut has_node : Bool
  /// Whether the builder's 3D object is animated (a skinned mesh).
  mut has_animation : Bool
  /// The material properties that are monitored.
  refresh_uniforms : Array[String]
  /// The render id of the last `needsRefresh`.
  mut render_id : Int32
  /// The subclass overriding members; `None` is the base class. Added by G6.
  mut class_ : &NodeMaterialObserverClass?
}

///|
/// `new NodeMaterialObserver( builder )`.
pub fn NodeMaterialObserver::new(builder : NodeBuilder) -> NodeMaterialObserver {
  let observer = {
    render_objects: @webgl.WeakMap::new(),
    has_node: false,
    has_animation: false,
    refresh_uniforms: node_material_observer_refresh_uniforms,
    render_id: 0,
    class_: None,
  }
  observer.has_node = observer.contains_node(builder)
  observer.has_animation = match builder.object {
    Object3D(o) => o.is_skinned_mesh()
    _ => false
  }
  observer
}

///|
/// `firstInitialization( renderObject )`.
pub fn NodeMaterialObserver::first_initialization(
  self : NodeMaterialObserver,
  render_object : RenderObject,
) -> Bool {
  let has_initialized = self.render_objects.has(render_object)
  if has_initialized == false {
    self.get_render_object_data(render_object) |> ignore
    return true
  }
  false
}

///|
/// `hasDynamicInstancing( object )`.
pub fn NodeMaterialObserver::has_dynamic_instancing(
  _self : NodeMaterialObserver,
  object : @core.Object3D,
) -> Bool {
  match object.kind {
    Mesh({ kind: InstancedMesh(m), .. }) =>
      m.instance_matrix.usage == @core.DynamicDrawUsage ||
      (m.instance_color is Some(c) && c.usage == @core.DynamicDrawUsage)
    _ => false
  }
}

///|
/// `needsVelocity( renderer )`.
pub fn NodeMaterialObserver::needs_velocity(
  _self : NodeMaterialObserver,
  renderer : Renderer,
) -> Bool {
  match renderer.get_mrt() {
    Some(mrt) => MRTNode::of(mrt).unwrap().has("velocity")
    None => false
  }
}

///|
/// `object.morphTargetInfluences`.
fn node_material_observer_morph_influences(
  object : @core.Object3D,
) -> Array[Double]? {
  match object.kind {
    Mesh(m) => m.morph_target_influences
    Line(l) => l.morph_target_influences
    Points(p) => p.morph_target_influences
    _ => None
  }
}

///|
/// `object.center` (sprites).
fn node_material_observer_center(object : @core.Object3D) -> @math.Vector2? {
  match object.kind {
    Sprite(s) => Some(s.center)
    _ => None
  }
}

///|
let node_material_observer_nan : Double = 0.0 / 0.0

///|
fn node_material_observer_scene(scene : @core.Object3D) -> @core.Scene {
  match scene.kind {
    Scene(s) => s
    _ => abort("TypeError: renderObject.scene is not a Scene")
  }
}

///|
fn node_material_observer_texture_version(t : @core.Texture?) -> Int32? {
  match t {
    Some(t) => Some(t.version)
    None => None
  }
}

///|
/// `getRenderObjectData( renderObject )`.
fn NodeMaterialObserver::get_render_object_data(
  self : NodeMaterialObserver,
  render_object : RenderObject,
) -> ObserverRenderObjectData {
  match self.render_objects.get(render_object) {
    Some(data) => data
    None => {
      let geometry = render_object.geometry
      let object = render_object.object
      let geometry_version = self.get_geometry_data(geometry)._version
      let material_version = self.get_material_data(render_object.material)._version
      let mut instance_matrix = None
      let mut instance_matrix_version = 0
      let mut instance_color = None
      let mut instance_color_version = None
      let mut morph_texture_version = None
      match object.kind {
        Mesh({ kind: InstancedMesh(m), .. }) => {
          instance_matrix = Some(m.instance_matrix)
          instance_matrix_version = m.instance_matrix.version
          instance_color = m.instance_color
          instance_color_version = match m.instance_color {
            Some(c) => Some(c.version)
            None => None
          }
          morph_texture_version = node_material_observer_texture_version(
            m.morph_texture,
          )
        }
        _ => ()
      }
      let mut matrices_texture_version = 0
      let mut colors_texture_version = None
      let mut indirect_texture_version = 0
      match object.kind {
        Mesh({ kind: BatchedMesh(b), .. }) => {
          matrices_texture_version = b._matrices_texture.unwrap().version
          colors_texture_version = node_material_observer_texture_version(
            b._colors_texture,
          )
          indirect_texture_version = b._indirect_texture.unwrap().version
        }
        _ => ()
      }
      let version = match render_object.bundle {
        Some(bundle) => Some(BundleGroup::of(bundle).unwrap().version)
        None => None
      }
      // global data
      let output_target = self.get_output_target(render_object.renderer)
      let output_target_version = self.get_output_target_data(
          output_target,
          render_object.context,
        )._version
      let scene = node_material_observer_scene(render_object.scene)
      let data : ObserverRenderObjectData = {
        geometry_id: geometry.id,
        geometry_version,
        material_version,
        attributes_dispose_version: render_object._geometries.attributes.dispose_version,
        world_matrix: object.matrix_world.clone(),
        center: node_material_observer_center(object).map(c => c.clone()),
        morph_target_influences: node_material_observer_morph_influences(object).map(a => {
            a.copy()
          },
        ),
        instance_matrix,
        instance_matrix_version,
        instance_color,
        instance_color_version,
        morph_texture_version,
        matrices_texture_version,
        colors_texture_version,
        indirect_texture_version,
        version,
        output_target,
        output_target_version,
        environment_intensity: scene.environment_intensity,
        environment_rotation: scene.environment_rotation.clone(),
        environment_version: match scene.environment {
          Some(environment) => Some(self.get_texture_data(environment)._version)
          None => None
        },
        lights: self.get_lights_data(
          LightsNode::get_builtin_lights(render_object.lights_node),
          [],
        ),
      }
      self.render_objects.set(render_object, data)
      data
    }
  }
}

///|
/// `getOutputTarget( renderer )`.
fn NodeMaterialObserver::get_output_target(
  _self : NodeMaterialObserver,
  renderer : Renderer,
) -> ObserverOutputTarget {
  match renderer.get_render_target() {
    Some(render_target) => RenderTarget(render_target)
    None =>
      match renderer.get_output_render_target() {
        Some(t) => RenderTarget(t)
        None => Canvas(renderer.get_canvas_target())
      }
  }
}

///|
/// `getOutputTargetData( outputTarget, renderContext )`.
fn NodeMaterialObserver::get_output_target_data(
  _self : NodeMaterialObserver,
  output_target : ObserverOutputTarget,
  render_context : RenderContext,
) -> ObserverOutputTargetData {
  let width = render_context.width
  let height = render_context.height
  let key = output_target.key()
  match node_material_observer_output_target_cache.get(key) {
    None => {
      let data = { _version: 0, width, height, }
      node_material_observer_output_target_cache.set(key, data)
      data
    }
    Some(data) => {
      if data.width != width || data.height != height {
        data.width = width
        data.height = height
        data._version += 1
      }
      data
    }
  }
}

///|
/// `attribute.isInterleavedBufferAttribute ? attribute.data.uuid : attribute.id` and the
/// matching version.
fn node_material_observer_attribute_id(
  attribute : @core.GeometryAttribute,
) -> (String, Int32) {
  match attribute {
    Buffer(a) => ("#" + a.id.to_string(), a.version)
    Interleaved(a) => (a.data.uuid, a.data.version)
    GL(a) => ("undefined", a.version)
  }
}

///|
/// `getAttributesData( attributes )`.
fn NodeMaterialObserver::get_attributes_data(
  _self : NodeMaterialObserver,
  attributes : Map[String, @core.GeometryAttribute],
) -> Map[String, ObserverAttributeData] {
  let attributes_data = Map([])
  for name, attribute in attributes {
    let (id, version) = node_material_observer_attribute_id(attribute)
    attributes_data[name] = { id, version, }
  }
  attributes_data
}

///|
/// `containsNode( builder )`.
pub fn NodeMaterialObserver::contains_node(
  _self : NodeMaterialObserver,
  builder : NodeBuilder,
) -> Bool {
  // material
  match builder.material {
    Some(material) =>
      if NodeMaterial::of(material) is Some(_) {
        for slot in NodeMaterial::node_slots(material) {
          if slot.1 is Some(_) {
            return true
          }
        }
      }
    None => abort("TypeError: Cannot convert undefined or null to object")
  }
  // context
  let context = builder.context
  if context.get("modelViewMatrix") is Node(_) ||
    context.get("modelNormalViewMatrix") is Node(_) ||
    context.get_ao() is Some(_) ||
    context.get_shadow() is Some(_) ||
    context.get_gi() is Some(_) {
    return true
  }
  false
}

///|
fn node_material_observer_index(
  index : @core.GeometryAttribute?,
) -> (String?, Int32?) {
  match index {
    Some(Buffer(a)) => (Some("#" + a.id.to_string()), Some(a.version))
    Some(Interleaved(_)) => (Some("undefined"), None)
    Some(GL(a)) => (Some("undefined"), Some(a.version))
    None => (None, None)
  }
}

///|
/// `getGeometryData( geometry )`.
fn NodeMaterialObserver::get_geometry_data(
  self : NodeMaterialObserver,
  geometry : @core.BufferGeometry,
) -> ObserverGeometryData {
  match node_material_observer_geometry_cache.get(geometry) {
    Some(data) => data
    None => {
      let (index_id, index_version) = node_material_observer_index(
        geometry.index,
      )
      let data : ObserverGeometryData = {
        _render_id: -1,
        _version: 0,
        attributes: self.get_attributes_data(geometry.attributes),
        index_id,
        index_version,
        draw_range_start: geometry.draw_range.start,
        draw_range_count: geometry.draw_range.count,
      }
      // force refresh on dispose
      geometry.add_event_listener("dispose", fn(_) { data._version += 1 })
      node_material_observer_geometry_cache.set(geometry, data)
      data
    }
  }
}

///|
/// `getTextureData( texture )`.
fn NodeMaterialObserver::get_texture_data(
  _self : NodeMaterialObserver,
  texture : @core.Texture,
) -> ObserverTextureData {
  match node_material_observer_texture_cache.get(texture) {
    Some(data) => data
    None => {
      let data = { _version: 0, }
      // force refresh on dispose
      let on_dispose = fn(_) { data._version += 1 }
      match texture.render_target {
        Some(render_target) =>
          render_target.add_event_listener("dispose", on_dispose)
        None => texture.add_event_listener("dispose", on_dispose)
      }
      node_material_observer_texture_cache.set(texture, data)
      data
    }
  }
}

///|
/// `getTextureTransformData( texture )`.
fn NodeMaterialObserver::get_texture_transform_data(
  _self : NodeMaterialObserver,
  texture : @core.Texture,
) -> ObserverTextureTransform {
  {
    offset: texture.offset.clone(),
    repeat: texture.repeat.clone(),
    center: texture.center.clone(),
    rotation: texture.rotation,
    matrix: texture.matrix.clone(),
  }
}

///|
/// `equalsTextureTransform( transformData, texture )`.
fn NodeMaterialObserver::equals_texture_transform(
  _self : NodeMaterialObserver,
  transform_data : ObserverTextureTransform,
  texture : @core.Texture,
) -> Bool {
  if texture.matrix_auto_update == true {
    return transform_data.rotation == texture.rotation &&
      transform_data.offset.equals(texture.offset) &&
      transform_data.repeat.equals(texture.repeat) &&
      transform_data.center.equals(texture.center)
  }
  transform_data.matrix.equals(texture.matrix)
}

///|
/// Whether the material defines the property (`material[ property ] !== undefined` with
/// `null` counted as defined): the class's recorded keys, plus core fields that hold a
/// value.
fn node_material_observer_defines(
  material : @core.Material,
  property : String,
) -> Bool {
  if property == "opacity" || property == "alphaTest" {
    return true
  }
  if NodeMaterial::of(material) is Some(_) {
    let (own, getters) = _render_object_class_keys(material)
    if own.contains(property) || getters.contains(property) {
      return true
    }
  }
  false
}

///|
fn node_material_observer_opt_number(v : Double?) -> ObserverValue? {
  match v {
    Some(v) => Some(Number(v))
    None => None
  }
}

///|
fn node_material_observer_opt_texture(v : @core.Texture?) -> ObserverValue? {
  match v {
    Some(t) => Some(TextureRef(t))
    None => None
  }
}

///|
/// `material[ property ]` for the monitored properties; `None` is `undefined`, and a
/// core field without a value is `null` when the class defines the property.
fn node_material_observer_read(
  material : @core.Material,
  property : String,
) -> ObserverValue? {
  let m = material
  // a property assigned on the instance (`reference_set_instance_property`)
  match reference_instance_property(@core.JsValue::of(material), property) {
    Some(Number(x)) => return Some(Number(x))
    Some(Bool(b)) => return Some(Bool(b))
    Some(Color(c)) => return Some(Color(c))
    Some(Vector2(v)) => return Some(Vector2(v))
    Some(Texture(t)) => return Some(TextureRef(t))
    Some(Null) => return Some(Null)
    _ => ()
  }
  let value : ObserverValue? = match property {
    "alphaMap" => node_material_observer_opt_texture(m.alpha_map)
    "alphaTest" => Some(Number(m.alpha_test()))
    "anisotropy" => node_material_observer_opt_number(m.anisotropy())
    "anisotropyMap" => node_material_observer_opt_texture(m.anisotropy_map)
    "anisotropyRotation" =>
      node_material_observer_opt_number(m.anisotropy_rotation)
    "aoMap" => node_material_observer_opt_texture(m.ao_map)
    "aoMapIntensity" => node_material_observer_opt_number(m.ao_map_intensity)
    "attenuationColor" => m.attenuation_color.map(c => Color(c))
    "attenuationDistance" =>
      node_material_observer_opt_number(m.attenuation_distance)
    "bumpMap" => node_material_observer_opt_texture(m.bump_map)
    "bumpScale" => node_material_observer_opt_number(m.bump_scale)
    "clearcoat" => node_material_observer_opt_number(m.clearcoat())
    "clearcoatMap" => node_material_observer_opt_texture(m.clearcoat_map)
    "clearcoatNormalMap" =>
      node_material_observer_opt_texture(m.clearcoat_normal_map)
    "clearcoatNormalScale" => m.clearcoat_normal_scale.map(v => Vector2(v))
    "clearcoatRoughness" =>
      node_material_observer_opt_number(m.clearcoat_roughness)
    "clearcoatRoughnessMap" =>
      node_material_observer_opt_texture(m.clearcoat_roughness_map)
    "color" => m.color.map(c => Color(c))
    "dashSize" => node_material_observer_opt_number(m.dash_size)
    "diffuseRoughness" =>
      node_material_observer_opt_number(m.diffuse_roughness())
    "diffuseRoughnessMap" =>
      node_material_observer_opt_texture(m.diffuse_roughness_map)
    "dispersion" => node_material_observer_opt_number(m.dispersion())
    "displacementBias" => node_material_observer_opt_number(m.displacement_bias)
    "displacementMap" => node_material_observer_opt_texture(m.displacement_map)
    "displacementScale" =>
      node_material_observer_opt_number(m.displacement_scale)
    "emissive" => m.emissive.map(c => Color(c))
    "emissiveIntensity" =>
      node_material_observer_opt_number(m.emissive_intensity)
    "emissiveMap" => node_material_observer_opt_texture(m.emissive_map)
    "envMap" => node_material_observer_opt_texture(m.env_map)
    "envMapIntensity" => node_material_observer_opt_number(m.env_map_intensity)
    "envMapRotation" => m.env_map_rotation.map(e => Euler(e))
    "gapSize" => node_material_observer_opt_number(m.gap_size)
    "gradientMap" => node_material_observer_opt_texture(m.gradient_map)
    "ior" => node_material_observer_opt_number(m.ior)
    "iridescence" => node_material_observer_opt_number(m.iridescence())
    "iridescenceIOR" => node_material_observer_opt_number(m.iridescence_ior)
    "iridescenceMap" => node_material_observer_opt_texture(m.iridescence_map)
    "iridescenceThicknessMap" =>
      node_material_observer_opt_texture(m.iridescence_thickness_map)
    "iridescenceThicknessMaximum" =>
      node_material_observer_opt_number(m.iridescence_thickness_maximum)
    "iridescenceThicknessMinimum" =>
      node_material_observer_opt_number(m.iridescence_thickness_minimum)
    "lightMap" => node_material_observer_opt_texture(m.light_map)
    "lightMapIntensity" =>
      node_material_observer_opt_number(m.light_map_intensity)
    "linewidth" => node_material_observer_opt_number(m.linewidth)
    "map" => node_material_observer_opt_texture(m.map)
    "matcap" => node_material_observer_opt_texture(m.matcap)
    "metalness" => node_material_observer_opt_number(m.metalness)
    "metalnessMap" => node_material_observer_opt_texture(m.metalness_map)
    "normalMap" => node_material_observer_opt_texture(m.normal_map)
    "normalScale" => m.normal_scale.map(v => Vector2(v))
    "opacity" => Some(Number(m.opacity))
    "reflectivity" => node_material_observer_opt_number(m.reflectivity())
    "refractionRatio" => node_material_observer_opt_number(m.refraction_ratio)
    "retroreflectivity" =>
      node_material_observer_opt_number(m.retroreflectivity())
    "rotation" => node_material_observer_opt_number(m.rotation)
    "roughness" => node_material_observer_opt_number(m.roughness)
    "roughnessMap" => node_material_observer_opt_texture(m.roughness_map)
    "scale" => node_material_observer_opt_number(m.scale)
    "sheen" => node_material_observer_opt_number(m.sheen())
    "sheenColor" => m.sheen_color.map(c => Color(c))
    "sheenColorMap" => node_material_observer_opt_texture(m.sheen_color_map)
    "sheenRoughness" => node_material_observer_opt_number(m.sheen_roughness)
    "sheenRoughnessMap" =>
      node_material_observer_opt_texture(m.sheen_roughness_map)
    "shininess" => node_material_observer_opt_number(m.shininess)
    "size" => node_material_observer_opt_number(m.size)
    "specular" => m.specular.map(c => Color(c))
    "specularColor" => m.specular_color.map(c => Color(c))
    "specularColorMap" =>
      node_material_observer_opt_texture(m.specular_color_map)
    "specularIntensity" =>
      node_material_observer_opt_number(m.specular_intensity)
    "specularIntensityMap" =>
      node_material_observer_opt_texture(m.specular_intensity_map)
    "specularMap" => node_material_observer_opt_texture(m.specular_map)
    "thickness" => node_material_observer_opt_number(m.thickness)
    "thicknessMap" => node_material_observer_opt_texture(m.thickness_map)
    "transmission" => node_material_observer_opt_number(m.transmission())
    "transmissionMap" => node_material_observer_opt_texture(m.transmission_map)
    "wireframe" => m.wireframe.map(b => Bool(b))
    // members of node material classes (`dashOffset`, `steps`)
    _ =>
      match NodeMaterial::of(m) {
        Some(nm) =>
          match nm.class_.reference_value(m, property) {
            Some(Number(x)) => Some(Number(x))
            Some(Bool(b)) => Some(Bool(b))
            _ => None
          }
        None => None
      }
  }
  match value {
    Some(v) => Some(v)
    None =>
      if node_material_observer_defines(material, property) {
        Some(Null)
      } else {
        None
      }
  }
}

///|
/// `getMaterialData( material )`.
fn NodeMaterialObserver::get_material_data(
  self : NodeMaterialObserver,
  material : @core.Material,
) -> ObserverMaterialData {
  match node_material_observer_material_cache.get(material) {
    Some(data) => data
    None => {
      let data = { _render_id: -1, _version: 0, entries: [], }
      for property in self.refresh_uniforms {
        let value = match node_material_observer_read(material, property) {
          None => continue
          Some(v) => v
        }
        let tracked : ObserverValue = match value {
          // track unset properties
          Null => Null
          TextureRef(texture) =>
            Texture({
              id: texture.id,
              version: 0,
              cache_version: self.get_texture_data(texture)._version,
              transform: self.get_texture_transform_data(texture),
            })
          Color(c) => Color(c.clone())
          Vector2(v) => Vector2(v.clone())
          Euler(e) => Euler(e.clone())
          other => other
        }
        data.entries.push((property, Ref(tracked)))
      }
      node_material_observer_material_cache.set(material, data)
      data
    }
  }
}

///|
/// `value !== mtlValue` for primitives and `null`.
fn node_material_observer_same_primitive(
  a : ObserverValue,
  b : ObserverValue,
) -> Bool {
  match (a, b) {
    (Null, Null) => true
    (Number(x), Number(y)) => x == y
    (Bool(x), Bool(y)) => x == y
    _ => false
  }
}

///|
/// `equals( renderObject, lightsData, renderId )`.
fn NodeMaterialObserver::equals(
  self : NodeMaterialObserver,
  render_object : RenderObject,
  lights_data : Array[ObserverLightData],
  render_id : Int32,
) -> Bool {
  let object = render_object.object
  let material = render_object.material
  let geometry = render_object.geometry
  let render_object_data = self.get_render_object_data(render_object)

  // world matrix
  if render_object_data.world_matrix.equals(object.matrix_world) != true {
    render_object_data.world_matrix.copy(object.matrix_world) |> ignore
    return false
  }

  // material
  let material_data = self.get_material_data(render_object.material)

  // check the material properties just once per render for all render objects
  if material_data._render_id != render_id {
    material_data._render_id = render_id
    let mut changed = false
    for entry in material_data.entries {
      let (property, slot) = entry
      let value = slot.val
      let mtl_value = node_material_observer_read(material, property)
      match (value, mtl_value) {
        (Null, _) | (_, None) | (_, Some(Null)) => {
          // a property was assigned or removed since the last observation so a new
          // snapshot is required
          let current = match mtl_value {
            None => ObserverValue::Null
            Some(v) => v
          }
          if !node_material_observer_same_primitive(value, current) {
            slot.val = match current {
              Null => Null
              TextureRef(texture) =>
                Texture({
                  id: texture.id,
                  version: texture.version,
                  cache_version: self.get_texture_data(texture)._version,
                  transform: self.get_texture_transform_data(texture),
                })
              Color(c) => Color(c.clone())
              Vector2(v) => Vector2(v.clone())
              Euler(e) => Euler(e.clone())
              other => other
            }
            changed = true
          }
        }
        (Color(c), Some(Color(m))) =>
          if c.equals(m) == false {
            c.copy(m) |> ignore
            changed = true
          }
        (Vector2(v), Some(Vector2(m))) =>
          if v.equals(m) == false {
            v.copy(m) |> ignore
            changed = true
          }
        (Euler(e), Some(Euler(m))) =>
          if e.equals(m) == false {
            e.copy(m) |> ignore
            changed = true
          }
        (Texture(value), Some(TextureRef(texture))) => {
          let texture_data = self.get_texture_data(texture)
          if value.id != texture.id ||
            value.version != texture.version ||
            value.cache_version != texture_data._version ||
            self.equals_texture_transform(value.transform, texture) == false {
            value.id = texture.id
            value.version = texture.version
            value.cache_version = texture_data._version
            value.transform.offset.copy(texture.offset) |> ignore
            value.transform.repeat.copy(texture.repeat) |> ignore
            value.transform.center.copy(texture.center) |> ignore
            value.transform.rotation = texture.rotation
            value.transform.matrix.copy(texture.matrix) |> ignore
            changed = true
          }
        }
        (_, Some(current)) =>
          if !node_material_observer_same_primitive(value, current) {
            slot.val = current
            changed = true
          }
      }
    }
    if changed == true {
      material_data._version += 1
    }
  }

  // a version mismatch means the material has changed since this render object was
  // last refreshed
  if render_object_data.material_version != material_data._version {
    render_object_data.material_version = material_data._version
    return false
  }
  let output_target_data = self.get_output_target_data(
    render_object_data.output_target,
    render_object.context,
  )

  // a version mismatch means the output target has been resized since this render
  // object was last refreshed
  if render_object_data.output_target_version != output_target_data._version {
    render_object_data.output_target_version = output_target_data._version
    return false
  }

  // geometry
  if render_object_data.geometry_id != geometry.id {
    render_object_data.geometry_id = geometry.id
    render_object_data.geometry_version = self.get_geometry_data(geometry)._version
    return false
  }
  let geometry_data = self.get_geometry_data(render_object.geometry)

  // check the geometry properties just once per render for all render objects
  if geometry_data._render_id != render_id {
    geometry_data._render_id = render_id
    let mut changed = false
    // attributes
    let attributes = geometry.attributes
    let stored_attributes = geometry_data.attributes
    let current_attribute_count = attributes.length()
    let mut stored_attribute_count = 0
    let names = stored_attributes.keys().collect()
    for name in names {
      stored_attribute_count += 1
      let stored_attribute_data = stored_attributes.get(name).unwrap()
      let attribute = match attributes.get(name) {
        Some(a) => a
        None => {
          // attribute was removed
          stored_attributes.remove(name)
          changed = true
          continue
        }
      }
      let (id, version) = node_material_observer_attribute_id(attribute)
      if stored_attribute_data.id != id ||
        stored_attribute_data.version != version {
        stored_attribute_data.id = id
        stored_attribute_data.version = version
        changed = true
      }
    }
    if stored_attribute_count != current_attribute_count {
      geometry_data.attributes = self.get_attributes_data(attributes)
      changed = true
    }
    // check index
    let (current_index_id, current_index_version) = node_material_observer_index(
      geometry.index,
    )
    if geometry_data.index_id != current_index_id ||
      geometry_data.index_version != current_index_version {
      geometry_data.index_id = current_index_id
      geometry_data.index_version = current_index_version
      changed = true
    }
    // check drawRange
    if geometry_data.draw_range_start != geometry.draw_range.start ||
      geometry_data.draw_range_count != geometry.draw_range.count {
      geometry_data.draw_range_start = geometry.draw_range.start
      geometry_data.draw_range_count = geometry.draw_range.count
      changed = true
    }
    if changed == true {
      geometry_data._version += 1
    }
  }

  // a version mismatch means the geometry has changed since this render object was
  // last refreshed
  if render_object_data.geometry_version != geometry_data._version {
    render_object_data.geometry_version = geometry_data._version
    return false
  }

  // morph targets
  if render_object_data.morph_target_influences is Some(stored) {
    let current = node_material_observer_morph_influences(object).unwrap()
    let mut morph_changed = false
    for i in 0..<stored.length() {
      let c = if i < current.length() {
        current[i]
      } else {
        node_material_observer_nan
      }
      if stored[i] != c {
        stored[i] = c
        morph_changed = true
      }
    }
    if morph_changed {
      return false
    }
  }

  // instancing
  match object.kind {
    Mesh({ kind: InstancedMesh(m), .. }) => {
      let instance_color_version = match m.instance_color {
        Some(c) => Some(c.version)
        None => None
      }
      let morph_texture_version = node_material_observer_texture_version(
        m.morph_texture,
      )
      let same_matrix = match render_object_data.instance_matrix {
        Some(a) => physical_equal(a, m.instance_matrix)
        None => false
      }
      let same_color = match
        (render_object_data.instance_color, m.instance_color) {
        (Some(a), Some(b)) => physical_equal(a, b)
        (None, None) => true
        _ => false
      }
      if !same_matrix ||
        render_object_data.instance_matrix_version != m.instance_matrix.version ||
        !same_color ||
        render_object_data.instance_color_version != instance_color_version ||
        render_object_data.morph_texture_version != morph_texture_version {
        render_object_data.instance_matrix = Some(m.instance_matrix)
        render_object_data.instance_matrix_version = m.instance_matrix.version
        render_object_data.instance_color = m.instance_color
        render_object_data.instance_color_version = instance_color_version
        render_object_data.morph_texture_version = morph_texture_version
        return false
      }
    }
    _ => ()
  }

  // batching
  match object.kind {
    Mesh({ kind: BatchedMesh(b), .. }) => {
      let colors_texture_version = node_material_observer_texture_version(
        b._colors_texture,
      )
      let matrices_version = b._matrices_texture.unwrap().version
      let indirect_version = b._indirect_texture.unwrap().version
      if render_object_data.matrices_texture_version != matrices_version ||
        render_object_data.colors_texture_version != colors_texture_version ||
        render_object_data.indirect_texture_version != indirect_version {
        render_object_data.matrices_texture_version = matrices_version
        render_object_data.colors_texture_version = colors_texture_version
        render_object_data.indirect_texture_version = indirect_version
        return false
      }
    }
    _ => ()
  }

  // lights
  for i in 0..<lights_data.length() {
    if i >= render_object_data.lights.length() {
      abort("TypeError: Cannot read properties of undefined (reading 'map')")
    }
    let light_data = render_object_data.lights[i]
    let current_light_data = lights_data[i]
    if light_data.map != current_light_data.map ||
      light_data.cache_version != current_light_data.cache_version ||
      light_data.shadow_map_width != current_light_data.shadow_map_width ||
      light_data.shadow_map_height != current_light_data.shadow_map_height {
      light_data.map = current_light_data.map
      light_data.cache_version = current_light_data.cache_version
      light_data.shadow_map_width = current_light_data.shadow_map_width
      light_data.shadow_map_height = current_light_data.shadow_map_height
      return false
    }
  }

  // scene
  let scene = node_material_observer_scene(render_object.scene)
  if scene.environment is Some(environment) && material.env_map is None {
    let environment_version = self.get_texture_data(environment)._version
    if render_object_data.environment_intensity != scene.environment_intensity ||
      render_object_data.environment_rotation.equals(scene.environment_rotation) ==
      false ||
      render_object_data.environment_version != Some(environment_version) {
      render_object_data.environment_intensity = scene.environment_intensity
      render_object_data.environment_rotation.copy(scene.environment_rotation)
      |> ignore
      render_object_data.environment_version = Some(environment_version)
      return false
    }
  }

  // center
  if render_object_data.center is Some(center) {
    let current = node_material_observer_center(object).unwrap()
    if center.equals(current) == false {
      center.copy(current) |> ignore
      return false
    }
  }

  // bundle
  if render_object.bundle is Some(bundle) {
    render_object_data.version = Some(BundleGroup::of(bundle).unwrap().version)
  }
  true
}

///|
/// `getLightsData( materialLights, lights )`.
fn NodeMaterialObserver::get_lights_data(
  self : NodeMaterialObserver,
  material_lights : Array[@core.Object3D],
  lights : Array[ObserverLightData],
) -> Array[ObserverLightData] {
  lights.clear()
  for light in material_lights {
    let mut data : ObserverLightData? = None
    match light.kind {
      Light({ kind: SpotLight({ map: Some(map), .. }), .. }) =>
        // only add lights that have a map
        data = Some({
          map: Some(map.version),
          cache_version: Some(self.get_texture_data(map)._version),
          shadow_map_width: None,
          shadow_map_height: None,
        })
      _ => ()
    }
    match light.kind {
      Light({ shadow: Some(shadow), .. }) if light.cast_shadow == true => {
        // resizing a shadow map recreates its textures so the bindings of all
        // related render objects must be updated
        let d = match data {
          Some(d) => d
          None =>
            {
              map: None,
              cache_version: None,
              shadow_map_width: None,
              shadow_map_height: None,
            }
        }
        d.shadow_map_width = Some(shadow.map_size.x)
        d.shadow_map_height = Some(shadow.map_size.y)
        data = Some(d)
      }
      _ => ()
    }
    if data is Some(d) {
      lights.push(d)
    }
  }
  lights
}

///|
/// `getLights( lightsNode, renderId )`.
fn NodeMaterialObserver::get_lights(
  self : NodeMaterialObserver,
  lights_node : Node,
  render_id : Int32,
) -> Array[ObserverLightData] {
  let cached = match node_material_observer_lights_cache.get(lights_node) {
    Some(c) => c
    None => {
      let c = { render_id: -1, lights_data: [], }
      node_material_observer_lights_cache.set(lights_node, c)
      c
    }
  }
  if cached.render_id == render_id {
    return cached.lights_data
  }
  cached.render_id = render_id
  self.get_lights_data(
    LightsNode::get_builtin_lights(lights_node),
    cached.lights_data,
  )
  |> ignore
  cached.lights_data
}

///|
/// `hasDisposedAttributes( renderObject, renderObjectData )`.
fn NodeMaterialObserver::has_disposed_attributes(
  _self : NodeMaterialObserver,
  render_object : RenderObject,
  render_object_data : ObserverRenderObjectData,
) -> Bool {
  let attributes = render_object._geometries.attributes
  for vertex_buffer in render_object.get_vertex_buffers() {
    if attributes.has(vertex_buffer) == false {
      return true
    }
  }
  match render_object.get_index() {
    Some(index) =>
      if attributes.has(
          match index {
            Buffer(a) => Buffer(a)
            Interleaved(a) => interleaved_attribute_buffer(a)
            GL(a) => GL(a)
          },
        ) ==
        false {
        return true
      }
    None => ()
  }
  render_object_data.attributes_dispose_version = attributes.dispose_version
  false
}

///|
/// `needsRefresh( renderObject, nodeFrame )`: a `RenderObjectRefreshType`.
pub fn NodeMaterialObserver::needs_refresh(
  self : NodeMaterialObserver,
  render_object : RenderObject,
  node_frame : NodeFrame,
) -> Int32 {
  match self.class_ {
    Some(c) => c.needs_refresh(self, render_object, node_frame)
    None => self.needs_refresh_base(render_object, node_frame)
  }
}

///|
/// `NodeMaterialObserver.prototype.needsRefresh`.
pub fn NodeMaterialObserver::needs_refresh_base(
  self : NodeMaterialObserver,
  render_object : RenderObject,
  node_frame : NodeFrame,
) -> Int32 {
  let renderer = match node_frame.renderer {
    Some(r) => r
    None =>
      abort("TypeError: Cannot read properties of null (nodeFrame.renderer)")
  }
  if self.has_node ||
    self.has_animation ||
    self.has_dynamic_instancing(render_object.object) ||
    self.first_initialization(render_object) ||
    self.needs_velocity(renderer) {
    return @core.RenderObjectRefreshType_FULL
  }
  let render_id = node_frame.render_id
  let mut refresh_type = @core.RenderObjectRefreshType_NONE

  // shared UBOs are potentially never updated when objects don't change. Below block
  // make sure these UBOs are updated at least once.
  if self.render_id != render_id {
    self.render_id = render_id
    // no early out here. instead, use the equals() code path below so the internal
    // cache state gets synched
    refresh_type = @core.RenderObjectRefreshType_SHARED
  }

  // bindings might refer to per-target resources so a target switch needs a full
  // refresh
  let render_object_data = self.get_render_object_data(render_object)
  let output_target = self.get_output_target(renderer)
  if !render_object_data.output_target.same(output_target) {
    render_object_data.output_target = output_target
    refresh_type = @core.RenderObjectRefreshType_FULL
  }
  let attributes = render_object._geometries.attributes

  // re-upload disposed attributes. checked before the static early out since other
  // geometries can destroy shared buffers
  if render_object_data.attributes_dispose_version != attributes.dispose_version {
    if self.has_disposed_attributes(render_object, render_object_data) {
      refresh_type = @core.RenderObjectRefreshType_FULL
    }
  }
  let is_static = render_object.object.static_ == true
  let is_bundle = match render_object.bundle {
    Some(bundle) => {
      let b = BundleGroup::of(bundle).unwrap()
      b.static_ == true && render_object_data.version == Some(b.version)
    }
    None => false
  }
  if is_static || is_bundle {
    return refresh_type
  }
  let lights_data = self.get_lights(render_object.lights_node, render_id)
  if self.equals(render_object, lights_data, render_id) == false {
    refresh_type = @core.RenderObjectRefreshType_FULL
  }
  refresh_type
}
