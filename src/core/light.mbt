// Upstream src/lights/Light.js. The hooks also dispatch to the subclasses, each in its
// own file.

///|
/// `Foo.prototype._lightNode` for each class `Foo`, keyed by upstream's class name.
let _light_nodes : Map[String, JsValue] = Map([])

///|
/// `new Color( color )`; `None` gives white.
fn light_new_color(color : @math.Color?) -> @math.Color {
  match color {
    Some(color) => color.clone()
    None => @math.Color::new(1.0, 1.0, 1.0)
  }
}

///|
/// The `Light` fields with upstream's defaults.
fn light_data_new(
  color : @math.Color?,
  intensity : Double,
  shadow : LightShadow?,
  kind : LightKind,
) -> Light {
  { color: light_new_color(color), intensity, shadow, color_node: None, kind, }
}

///|
/// `new Light( color, intensity )`.
pub fn Light::new(color? : @math.Color, intensity~ : Double = 1.0) -> Object3D {
  Object3D::new(
    kind=Light(light_data_new(color, intensity, None, BaseLight)),
    type_="Light",
  )
}

///|
/// The `Light` data of a light. Aborts on other kinds.
pub fn Object3D::as_light(self : Object3D) -> Light {
  guard self.kind is Light(light) else { abort("Object3D: not a light") }
  light
}

///|
/// `light.shadow`. Aborts on lights without one, as upstream throws on `undefined`.
fn Light::require_shadow(self : Light) -> LightShadow {
  guard self.shadow is Some(shadow) else { abort("Light: no shadow") }
  shadow
}

///|
/// `light.target`, on a `DirectionalLight` or `SpotLight`. Aborts on other kinds.
pub fn Object3D::light_target(self : Object3D) -> Object3D {
  match self.as_light().kind {
    DirectionalLight(directional) => directional.target
    SpotLight(spot) => spot.target
    _ => abort("Light: no target")
  }
}

///|
/// `Foo.registerNode( lightNodeClass )`, where `class_name` is `Foo`.
pub fn Light::register_node(
  class_name : String,
  light_node_class : JsValue,
) -> Unit {
  _light_nodes[class_name] = light_node_class
}

///|
/// `Foo.prototype._lightNode`, following the prototype chain, or `None`.
pub fn Light::light_node_of(class_name : String) -> JsValue? {
  if _light_nodes.get(class_name) is Some(node) {
    return Some(node)
  }
  match class_name {
    "Light" => None
    "IESSpotLight" | "ProjectorLight" => Light::light_node_of("SpotLight")
    _ => Light::light_node_of("Light")
  }
}

///|
/// `light._lightNode`.
pub fn Object3D::light_node(self : Object3D) -> JsValue? {
  let class_name = match self.as_light().kind {
    BaseLight => "Light"
    AmbientLight => "AmbientLight"
    DirectionalLight(_) => "DirectionalLight"
    HemisphereLight(_) => "HemisphereLight"
    LightProbe(_) => "LightProbe"
    PointLight(_) => "PointLight"
    RectAreaLight(_) => "RectAreaLight"
    SpotLight({ variant: PlainSpotLight, .. }) => "SpotLight"
    SpotLight({ variant: IESSpotLight, .. }) => "IESSpotLight"
    SpotLight({ variant: ProjectorLight, .. }) => "ProjectorLight"
  }
  Light::light_node_of(class_name)
}

///|
/// `light.power`, on the classes that define it. Aborts on other kinds.
pub fn Object3D::power(self : Object3D) -> Double {
  let light = self.as_light()
  match light.kind {
    PointLight(_) => point_light_power(light)
    RectAreaLight(rect_area) => rect_area.power(light)
    SpotLight(_) => spot_light_power(light)
    _ => abort("Light: no power")
  }
}

///|
/// `light.power = power`, on the classes that define it. Aborts on other kinds.
pub fn Object3D::set_power(self : Object3D, power : Double) -> Unit {
  let light = self.as_light()
  match light.kind {
    PointLight(_) => point_light_set_power(light, power)
    RectAreaLight(rect_area) => rect_area.set_power(light, power)
    SpotLight(_) => spot_light_set_power(light, power)
    _ => abort("Light: no power")
  }
}

///|
/// `new this.constructor()`.
fn hook_light_new_like(object : Object3D) -> Object3D {
  match object.as_light().kind {
    BaseLight => Light::new()
    AmbientLight => AmbientLight::new()
    DirectionalLight(_) => DirectionalLight::new()
    HemisphereLight(_) => HemisphereLight::new()
    LightProbe(_) => LightProbe::new()
    PointLight(_) => PointLight::new()
    RectAreaLight(_) => RectAreaLight::new()
    SpotLight({ variant: PlainSpotLight, .. }) => SpotLight::new()
    SpotLight({ variant: IESSpotLight, .. }) => IESSpotLight::new()
    SpotLight({ variant: ProjectorLight, .. }) => ProjectorLight::new()
  }
}

///|
/// Upstream `copy` of `Light` and its subclasses.
fn hook_light_copy(
  object : Object3D,
  source : Object3D,
  recursive : Bool,
) -> Unit {
  let light = object.as_light()
  // these classes declare `copy( source )`, so `Object3D.copy` takes its default
  let recursive = match light.kind {
    DirectionalLight(_) | LightProbe(_) | RectAreaLight(_) => true
    _ => recursive
  }
  object.copy_base(source, recursive)
  let source_light = source.as_light()
  ignore(light.color.copy(source_light.color))
  light.intensity = source_light.intensity
  match light.kind {
    BaseLight | AmbientLight => ()
    DirectionalLight(directional) => {
      directional.target = source.light_target().clone()
      light.shadow = Some(source_light.require_shadow().clone())
    }
    HemisphereLight(hemisphere) => hemisphere.copy_fields(source_light)
    LightProbe(probe) => probe.copy_fields(source_light)
    PointLight(point) => {
      point.copy_fields(source_light)
      light.shadow = Some(source_light.require_shadow().clone())
    }
    RectAreaLight(rect_area) => rect_area.copy_fields(source_light)
    SpotLight(spot) => {
      spot.copy_fields(source_light)
      light.shadow = Some(source_light.require_shadow().clone())
    }
  }
}

///|
/// Upstream `toJSON` of `Light` and its subclasses.
fn hook_light_to_json(
  object : Object3D,
  meta : ToJsonMeta,
  data : Map[String, Json],
) -> Unit {
  let light = object.as_light()
  data["color"] = json_int(light.color.get_hex())
  data["intensity"] = @math.json_number(light.intensity)
  match light.kind {
    BaseLight | AmbientLight => ()
    DirectionalLight(directional) => {
      data["shadow"] = light.require_shadow().to_json()
      data["target"] = Json::string(directional.target.uuid)
    }
    HemisphereLight(hemisphere) =>
      data["groundColor"] = json_int(hemisphere.ground_color.get_hex())
    LightProbe(probe) => data["sh"] = json_numbers(probe.sh.to_array())
    PointLight(point) => {
      data["distance"] = @math.json_number(point.distance)
      data["decay"] = @math.json_number(point.decay)
      data["shadow"] = light.require_shadow().to_json()
    }
    RectAreaLight(rect_area) => {
      data["width"] = @math.json_number(rect_area.width)
      data["height"] = @math.json_number(rect_area.height)
    }
    SpotLight(spot) => spot.add_to_json(light, meta, data)
  }
}

///|
/// Upstream `dispose` of `DirectionalLight`, `PointLight` and `SpotLight`.
fn hook_light_dispose(object : Object3D) -> Unit {
  object.dispose_base()
  let light = object.as_light()
  match light.kind {
    DirectionalLight(_) | PointLight(_) | SpotLight(_) =>
      light.require_shadow().dispose()
    BaseLight
    | AmbientLight
    | HemisphereLight(_)
    | LightProbe(_)
    | RectAreaLight(_) => ()
  }
}
