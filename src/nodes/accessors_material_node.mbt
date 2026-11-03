// nodes/accessors/MaterialNode.js: the standard material properties (`materialColor`,
// `materialRoughness`, ...), combining a material property with its map.

///|
extern "js" fn material_node_cos(x : Double) -> Double = "Math.cos"

///|
extern "js" fn material_node_sin(x : Double) -> Double = "Math.sin"

///|
/// `_propertyCache`: property -> material reference node.
let _material_node_property_cache : Map[String, Node] = {}

///|
pub(all) struct MaterialNode {
  mut scope : String
}

///|
pub impl NodeClass for MaterialNode with fn class_name(_) {
  "MaterialNode"
}

///|
pub impl NodeClass for MaterialNode with fn is_cacheable(_, _, _) {
  false
}

///|
/// `getCache( property, type )`.
pub fn MaterialNode::get_cache(property : String, type_ : String?) -> Node {
  match _material_node_property_cache.get(property) {
    Some(n) => n
    None => {
      let n = MaterialReferenceNode::new(property, type_)
      _material_node_property_cache.set(property, n)
      n
    }
  }
}

///|
/// `getFloat( property )`.
pub fn MaterialNode::get_float(property : String) -> Node {
  MaterialNode::get_cache(property, Some("float"))
}

///|
/// `getColor( property )`.
pub fn MaterialNode::get_color(property : String) -> Node {
  MaterialNode::get_cache(property, Some("color"))
}

///|
/// `getTexture( property )`: `map`, or `<property>Map`.
pub fn MaterialNode::get_texture(property : String) -> Node {
  MaterialNode::get_cache(
    if property == "map" {
      "map"
    } else {
      property + "Map"
    },
    Some("texture"),
  )
}

///|
pub impl NodeClass for MaterialNode with fn setup(self, node, builder) {
  let material = match builder.context.get("material") {
    Material(m) => m
    _ => abort("TypeError: Cannot read properties of undefined (material)")
  }
  let scope = self.scope
  let has = fn(t : @core.Texture?) { t is Some(_) }
  let node = if scope == MaterialNode::color() {
    let color_node = if material.color is Some(_) {
      MaterialNode::get_color(scope)
    } else {
      vec3_of([])
    }
    if has(material.map) {
      color_node.mul(MaterialNode::get_texture("map"))
    } else {
      color_node
    }
  } else if scope == MaterialNode::opacity() {
    let opacity_node = MaterialNode::get_float(scope)
    if has(material.alpha_map) {
      opacity_node.mul(MaterialNode::get_texture("alpha"))
    } else {
      opacity_node
    }
  } else if scope == MaterialNode::specular_strength() {
    if has(material.specular_map) {
      MaterialNode::get_texture("specular").r()
    } else {
      float(1)
    }
  } else if scope == MaterialNode::specular_intensity() {
    let specular_intensity_node = MaterialNode::get_float(scope)
    if has(material.specular_intensity_map) {
      specular_intensity_node.mul(MaterialNode::get_texture(scope).a())
    } else {
      specular_intensity_node
    }
  } else if scope == MaterialNode::specular_color() {
    let specular_color_node = MaterialNode::get_color(scope)
    if has(material.specular_color_map) {
      specular_color_node.mul(MaterialNode::get_texture(scope).rgb())
    } else {
      specular_color_node
    }
  } else if scope == MaterialNode::roughness() {
    let roughness_node = MaterialNode::get_float(scope)
    if has(material.roughness_map) {
      roughness_node.mul(MaterialNode::get_texture(scope).g())
    } else {
      roughness_node
    }
  } else if scope == MaterialNode::diffuse_roughness() {
    let diffuse_roughness_node = MaterialNode::get_float(scope)
    if has(material.diffuse_roughness_map) {
      diffuse_roughness_node.mul(MaterialNode::get_texture(scope).r())
    } else {
      diffuse_roughness_node
    }
  } else if scope == MaterialNode::metalness() {
    let metalness_node = MaterialNode::get_float(scope)
    if has(material.metalness_map) {
      metalness_node.mul(MaterialNode::get_texture(scope).b())
    } else {
      metalness_node
    }
  } else if scope == MaterialNode::emissive() {
    let emissive_intensity_node = MaterialNode::get_float("emissiveIntensity")
    let emissive_node = MaterialNode::get_color(scope).mul(
      emissive_intensity_node,
    )
    if has(material.emissive_map) {
      emissive_node.mul(MaterialNode::get_texture(scope))
    } else {
      emissive_node
    }
  } else if scope == MaterialNode::normal() {
    match material.normal_map {
      Some(normal_map_texture) => {
        let n = material_node_normal_map(
          MaterialNode::get_texture("normal"),
          MaterialNode::get_cache("normalScale", Some("vec2")),
        )
        material_node_set_normal_map_type(n, material.normal_map_type)
        let format = normal_map_texture.format
        if format == @core.RGFormat ||
          format == @core.RED_GREEN_RGTC2_Format ||
          format == @core.RG11_EAC_Format {
          material_node_set_unpack_normal_mode(n, @core.NormalRGPacking)
        }
        n
      }
      None =>
        if material.bump_map is Some(_) {
          material_node_bump_map(
            MaterialNode::get_texture("bump").r(),
            MaterialNode::get_float("bumpScale"),
          )
        } else {
          normal_view
        }
    }
  } else if scope == MaterialNode::clearcoat() {
    let clearcoat_node = MaterialNode::get_float(scope)
    if has(material.clearcoat_map) {
      clearcoat_node.mul(MaterialNode::get_texture(scope).r())
    } else {
      clearcoat_node
    }
  } else if scope == MaterialNode::clearcoat_roughness() {
    let clearcoat_roughness_node = MaterialNode::get_float(scope)
    if has(material.clearcoat_roughness_map) {
      clearcoat_roughness_node.mul(MaterialNode::get_texture(scope).g())
    } else {
      clearcoat_roughness_node
    }
  } else if scope == MaterialNode::clearcoat_normal() {
    if material.clearcoat_normal_map is Some(_) {
      material_node_normal_map(
        MaterialNode::get_texture(scope),
        MaterialNode::get_cache(scope + "Scale", Some("vec2")),
      )
    } else {
      normal_view
    }
  } else if scope == MaterialNode::sheen() {
    // Move this mul() to CPU
    let sheen_node = MaterialNode::get_color("sheenColor").mul(
      MaterialNode::get_float("sheen"),
    )
    if has(material.sheen_color_map) {
      sheen_node.mul(MaterialNode::get_texture("sheenColor").rgb())
    } else {
      sheen_node
    }
  } else if scope == MaterialNode::sheen_roughness() {
    let sheen_roughness_node = MaterialNode::get_float(scope)
    let n = if has(material.sheen_roughness_map) {
      sheen_roughness_node.mul(MaterialNode::get_texture(scope).a())
    } else {
      sheen_roughness_node
    }
    n.clamp(low=0.0001, high=1.0)
  } else if scope == MaterialNode::anisotropy() {
    if has(material.anisotropy_map) {
      let anisotropy_polar = MaterialNode::get_texture(scope)
      let anisotropy_mat = mat2_of([
        material_anisotropy_vector.x(),
        material_anisotropy_vector.y(),
        material_anisotropy_vector.y().negate(),
        material_anisotropy_vector.x(),
      ])
      anisotropy_mat.mul(
        anisotropy_polar
        .rg()
        .mul(2.0)
        .sub(vec2(1.0))
        .normalize()
        .mul(anisotropy_polar.b()),
      )
    } else {
      material_anisotropy_vector
    }
  } else if scope == MaterialNode::iridescence_thickness() {
    let iridescence_thickness_maximum = MaterialNode::get_float(
      "iridescenceThicknessMaximum",
    )
    if material.iridescence_thickness_map is Some(_) {
      let iridescence_thickness_minimum = MaterialNode::get_float(
        "iridescenceThicknessMinimum",
      )
      iridescence_thickness_maximum
      .sub(iridescence_thickness_minimum)
      .mul(MaterialNode::get_texture(scope).g())
      .add(iridescence_thickness_minimum)
    } else {
      iridescence_thickness_maximum
    }
  } else if scope == MaterialNode::transmission() {
    let transmission_node = MaterialNode::get_float(scope)
    if material.transmission_map is Some(_) {
      transmission_node.mul(MaterialNode::get_texture(scope).r())
    } else {
      transmission_node
    }
  } else if scope == MaterialNode::thickness() {
    let thickness_node = MaterialNode::get_float(scope)
    if material.thickness_map is Some(_) {
      thickness_node.mul(MaterialNode::get_texture(scope).g())
    } else {
      thickness_node
    }
  } else if scope == MaterialNode::ior() {
    MaterialNode::get_float(scope)
  } else if scope == MaterialNode::light_map() {
    if material.light_map is Some(_) {
      MaterialNode::get_texture(scope)
      .rgb()
      .mul(MaterialNode::get_float("lightMapIntensity"))
    } else {
      vec3(0.0)
    }
  } else if scope == MaterialNode::ao() {
    if material.ao_map is Some(_) {
      MaterialNode::get_texture(scope)
      .r()
      .sub(1.0)
      .mul(MaterialNode::get_float("aoMapIntensity"))
      .add(1.0)
    } else {
      float(1.0)
    }
  } else if scope == MaterialNode::line_dash_offset() {
    // `material.dashOffset`: a LineDashedNodeMaterial property core materials lack.
    match reference_material_value(material, "dashOffset") {
      Number(x) if x != 0.0 && !x.is_nan() => MaterialNode::get_float(scope)
      _ => float(0)
    }
  } else {
    let output_type = node.get_node_type(builder)
    MaterialNode::get_cache(scope, output_type)
  }
  Some(node)
}

///|
/// `normalMap( node, scaleNode )`.
fn material_node_normal_map(node : Node, scale_node : Node) -> Node {
  normal_map(node, scale_node~)
}

///|
/// `node.normalMapType = material.normalMapType`. Materials without the property
/// assign `undefined`, which NormalMapNode treats as an unsupported type (falling
/// back to `normalView`); -1 is that value here.
fn material_node_set_normal_map_type(node : Node, type_ : Int32?) -> Unit {
  NormalMapNode::of(node).unwrap().normal_map_type = type_.unwrap_or(-1)
}

///|
/// `node.unpackNormalMode = mode`.
fn material_node_set_unpack_normal_mode(node : Node, mode : String) -> Unit {
  NormalMapNode::of(node).unwrap().unpack_normal_mode = mode
}

///|
/// `bumpMap( textureNode, scaleNode )`.
fn material_node_bump_map(node : Node, scale_node : Node) -> Node {
  bump_map(node, scale_node~)
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn MaterialNode::construct(_node : Node, scope : String) -> MaterialNode {
  { scope, }
}

///|
/// `new MaterialNode( scope )`.
pub fn MaterialNode::new(scope : String) -> Node {
  let node = Node::alloc()
  node.set_class(MaterialNode::construct(node, scope))
}

///|
pub fn MaterialNode::of(node : Node) -> MaterialNode? {
  match node.class_payload("MaterialNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `MaterialNode.ALPHA_TEST` and the other scopes.
pub fn MaterialNode::alpha_test() -> String {
  "alphaTest"
}

///|
pub fn MaterialNode::color() -> String {
  "color"
}

///|
pub fn MaterialNode::opacity() -> String {
  "opacity"
}

///|
pub fn MaterialNode::shininess() -> String {
  "shininess"
}

///|
pub fn MaterialNode::specular() -> String {
  "specular"
}

///|
pub fn MaterialNode::specular_strength() -> String {
  "specularStrength"
}

///|
pub fn MaterialNode::specular_intensity() -> String {
  "specularIntensity"
}

///|
pub fn MaterialNode::specular_color() -> String {
  "specularColor"
}

///|
pub fn MaterialNode::reflectivity() -> String {
  "reflectivity"
}

///|
pub fn MaterialNode::roughness() -> String {
  "roughness"
}

///|
pub fn MaterialNode::diffuse_roughness() -> String {
  "diffuseRoughness"
}

///|
pub fn MaterialNode::metalness() -> String {
  "metalness"
}

///|
pub fn MaterialNode::normal() -> String {
  "normal"
}

///|
pub fn MaterialNode::clearcoat() -> String {
  "clearcoat"
}

///|
pub fn MaterialNode::clearcoat_roughness() -> String {
  "clearcoatRoughness"
}

///|
pub fn MaterialNode::clearcoat_normal() -> String {
  "clearcoatNormal"
}

///|
pub fn MaterialNode::emissive() -> String {
  "emissive"
}

///|
pub fn MaterialNode::rotation() -> String {
  "rotation"
}

///|
pub fn MaterialNode::sheen() -> String {
  "sheen"
}

///|
pub fn MaterialNode::sheen_roughness() -> String {
  "sheenRoughness"
}

///|
pub fn MaterialNode::anisotropy() -> String {
  "anisotropy"
}

///|
pub fn MaterialNode::iridescence() -> String {
  "iridescence"
}

///|
pub fn MaterialNode::iridescence_ior() -> String {
  "iridescenceIOR"
}

///|
pub fn MaterialNode::iridescence_thickness() -> String {
  "iridescenceThickness"
}

///|
pub fn MaterialNode::ior() -> String {
  "ior"
}

///|
pub fn MaterialNode::transmission() -> String {
  "transmission"
}

///|
pub fn MaterialNode::thickness() -> String {
  "thickness"
}

///|
pub fn MaterialNode::attenuation_distance() -> String {
  "attenuationDistance"
}

///|
pub fn MaterialNode::attenuation_color() -> String {
  "attenuationColor"
}

///|
pub fn MaterialNode::line_scale() -> String {
  "scale"
}

///|
pub fn MaterialNode::line_dash_size() -> String {
  "dashSize"
}

///|
pub fn MaterialNode::line_gap_size() -> String {
  "gapSize"
}

///|
pub fn MaterialNode::line_width() -> String {
  "linewidth"
}

///|
pub fn MaterialNode::line_dash_offset() -> String {
  "dashOffset"
}

///|
pub fn MaterialNode::point_size() -> String {
  "size"
}

///|
pub fn MaterialNode::dispersion() -> String {
  "dispersion"
}

///|
pub fn MaterialNode::retroreflectivity() -> String {
  "retroreflectivity"
}

///|
pub fn MaterialNode::light_map() -> String {
  "light"
}

///|
pub fn MaterialNode::ao() -> String {
  "ao"
}

///|
pub let material_alpha_test : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialAlphaTest",
  fn() { MaterialNode::new(MaterialNode::alpha_test()) },
)

///|
pub let material_color : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialColor",
  fn() { MaterialNode::new(MaterialNode::color()) },
)

///|
pub let material_shininess : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialShininess",
  fn() { MaterialNode::new(MaterialNode::shininess()) },
)

///|
pub let material_emissive : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialEmissive",
  fn() { MaterialNode::new(MaterialNode::emissive()) },
)

///|
pub let material_opacity : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialOpacity",
  fn() { MaterialNode::new(MaterialNode::opacity()) },
)

///|
pub let material_specular : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialSpecular",
  fn() { MaterialNode::new(MaterialNode::specular()) },
)

///|
pub let material_specular_intensity : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialSpecularIntensity",
  fn() { MaterialNode::new(MaterialNode::specular_intensity()) },
)

///|
pub let material_specular_color : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialSpecularColor",
  fn() { MaterialNode::new(MaterialNode::specular_color()) },
)

///|
pub let material_specular_strength : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialSpecularStrength",
  fn() { MaterialNode::new(MaterialNode::specular_strength()) },
)

///|
pub let material_reflectivity : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialReflectivity",
  fn() { MaterialNode::new(MaterialNode::reflectivity()) },
)

///|
pub let material_roughness : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialRoughness",
  fn() { MaterialNode::new(MaterialNode::roughness()) },
)

///|
pub let material_diffuse_roughness : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialDiffuseRoughness",
  fn() { MaterialNode::new(MaterialNode::diffuse_roughness()) },
)

///|
pub let material_metalness : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialMetalness",
  fn() { MaterialNode::new(MaterialNode::metalness()) },
)

///|
pub let material_normal : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialNormal",
  fn() { MaterialNode::new(MaterialNode::normal()) },
)

///|
pub let material_clearcoat : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialClearcoat",
  fn() { MaterialNode::new(MaterialNode::clearcoat()) },
)

///|
pub let material_clearcoat_roughness : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialClearcoatRoughness",
  fn() { MaterialNode::new(MaterialNode::clearcoat_roughness()) },
)

///|
pub let material_clearcoat_normal : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialClearcoatNormal",
  fn() { MaterialNode::new(MaterialNode::clearcoat_normal()) },
)

///|
pub let material_rotation : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialRotation",
  fn() { MaterialNode::new(MaterialNode::rotation()) },
)

///|
pub let material_sheen : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialSheen",
  fn() { MaterialNode::new(MaterialNode::sheen()) },
)

///|
pub let material_sheen_roughness : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialSheenRoughness",
  fn() { MaterialNode::new(MaterialNode::sheen_roughness()) },
)

///|
pub let material_anisotropy : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialAnisotropy",
  fn() { MaterialNode::new(MaterialNode::anisotropy()) },
)

///|
pub let material_iridescence : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialIridescence",
  fn() { MaterialNode::new(MaterialNode::iridescence()) },
)

///|
/// `materialIridescenceIOR`.
pub let material_iridescence_ior : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialIridescenceIOR",
  fn() { MaterialNode::new(MaterialNode::iridescence_ior()) },
)

///|
pub let material_iridescence_thickness : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialIridescenceThickness",
  fn() { MaterialNode::new(MaterialNode::iridescence_thickness()) },
)

///|
pub let material_transmission : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialTransmission",
  fn() { MaterialNode::new(MaterialNode::transmission()) },
)

///|
pub let material_thickness : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialThickness",
  fn() { MaterialNode::new(MaterialNode::thickness()) },
)

///|
/// `materialIOR`.
pub let material_ior : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialIOR",
  fn() { MaterialNode::new(MaterialNode::ior()) },
)

///|
pub let material_attenuation_distance : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialAttenuationDistance",
  fn() { MaterialNode::new(MaterialNode::attenuation_distance()) },
)

///|
pub let material_attenuation_color : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialAttenuationColor",
  fn() { MaterialNode::new(MaterialNode::attenuation_color()) },
)

///|
pub let material_line_scale : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialLineScale",
  fn() { MaterialNode::new(MaterialNode::line_scale()) },
)

///|
pub let material_line_dash_size : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialLineDashSize",
  fn() { MaterialNode::new(MaterialNode::line_dash_size()) },
)

///|
pub let material_line_gap_size : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialLineGapSize",
  fn() { MaterialNode::new(MaterialNode::line_gap_size()) },
)

///|
pub let material_line_width : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialLineWidth",
  fn() { MaterialNode::new(MaterialNode::line_width()) },
)

///|
pub let material_line_dash_offset : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialLineDashOffset",
  fn() { MaterialNode::new(MaterialNode::line_dash_offset()) },
)

///|
pub let material_point_size : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialPointSize",
  fn() { MaterialNode::new(MaterialNode::point_size()) },
)

///|
pub let material_dispersion : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialDispersion",
  fn() { MaterialNode::new(MaterialNode::dispersion()) },
)

///|
pub let material_retroreflectivity : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialRetroreflectivity",
  fn() { MaterialNode::new(MaterialNode::retroreflectivity()) },
)

///|
pub let material_light_map : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialLightMap",
  fn() { MaterialNode::new(MaterialNode::light_map()) },
)

///|
/// `materialAO`.
pub let material_ao : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialAO",
  fn() { MaterialNode::new(MaterialNode::ao()) },
)

///|
/// `materialAnisotropyVector`.
pub let material_anisotropy_vector : Node = module_nodes(
  "nodes/accessors/MaterialNode.js:materialAnisotropyVector",
  fn() {
    uniform(@math.Vector2::new(0.0, 0.0))
    .on_reference(fn(_, state) { material_properties_reference(state) })
    .on_render_update(fn(self_, frame) {
      let material = frame.material.unwrap()
      let anisotropy = material._anisotropy.unwrap_or(0.0 / 0.0)
      let rotation = material.anisotropy_rotation.unwrap_or(0.0 / 0.0)
      match InputNode::get_value(self_) {
        Vector2(v) =>
          v.set(
            anisotropy * material_node_cos(rotation),
            anisotropy * material_node_sin(rotation),
          )
          |> ignore
        _ => ()
      }
      None
    })
  },
)
