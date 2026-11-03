// Upstream src/lights/SpotLight.js. `SpotLight` is the payload struct, so `SpotLight::new`
// returns the `Object3D` that holds it. `dispose` is in light.mbt.

///|
extern "js" fn _spot_light_math_pi() -> Double = "() => Math.PI"

///|
/// `Math.PI / 3`.
let _spot_light_default_angle : Double = _spot_light_math_pi() / 3.0

///|
/// `SpotLight`, `IESSpotLight` and `ProjectorLight`, which differ in `variant`.
fn spot_light_new(
  color : @math.Color?,
  intensity : Double,
  distance : Double,
  angle : Double,
  penumbra : Double,
  decay : Double,
  variant : SpotLightVariant,
) -> Object3D {
  // Upstream draws the uuids (and ids) of the light, then `target`, then the shadow
  // camera, so the light is built first and its payload filled in afterwards.
  let light = Object3D::new(type_="SpotLight")
  ignore(light.position.copy(object3d_default_up))
  light.update_matrix()
  let spot : SpotLight = {
    target: Object3D::new(),
    distance,
    angle,
    penumbra,
    decay,
    map: None,
    ies_map: None,
    aspect: None,
    variant,
  }
  let shadow = SpotLightShadow::new()
  light.kind = Light(
    light_data_new(color, intensity, Some(shadow), SpotLight(spot)),
  )
  light
}

///|
/// `new SpotLight( color, intensity, distance, angle, penumbra, decay )`.
pub fn SpotLight::new(
  color? : @math.Color,
  intensity~ : Double = 1.0,
  distance~ : Double = 0.0,
  angle~ : Double = _spot_light_default_angle,
  penumbra~ : Double = 0.0,
  decay~ : Double = 2.0,
) -> Object3D {
  spot_light_new(
    color,
    intensity,
    distance,
    angle,
    penumbra,
    decay,
    PlainSpotLight,
  )
}

///|
/// The `SpotLight` data of a light. Aborts on other kinds.
pub fn Object3D::as_spot_light(self : Object3D) -> SpotLight {
  guard self.as_light().kind is SpotLight(spot) else {
    abort("Object3D: not a SpotLight")
  }
  spot
}

///|
/// Compute the light's luminous power (in lumens) from its intensity (in candela).
/// By convention for a spotlight, luminous power (lm) = pi * luminous intensity (cd).
fn spot_light_power(light : Light) -> Double {
  light.intensity * _spot_light_math_pi()
}

///|
/// Set the light's intensity (in candela) from the desired luminous power (in lumens).
fn spot_light_set_power(light : Light, power : Double) -> Unit {
  light.intensity = power / _spot_light_math_pi()
}

///|
/// Includes `IESSpotLight.copy` and `ProjectorLight.copy`.
fn SpotLight::copy_fields(self : SpotLight, source : Light) -> Unit {
  guard source.kind is SpotLight(spot) else {
    abort("SpotLight.copy: source is not a SpotLight")
  }
  self.distance = spot.distance
  self.angle = spot.angle
  self.penumbra = spot.penumbra
  self.decay = spot.decay
  self.target = spot.target.clone()
  self.map = spot.map
  match self.variant {
    PlainSpotLight => ()
    IESSpotLight => self.ies_map = spot.ies_map
    ProjectorLight => self.aspect = spot.aspect
  }
}

///|
fn SpotLight::add_to_json(
  self : SpotLight,
  light : Light,
  meta : ToJsonMeta,
  data : Map[String, Json],
) -> Unit {
  data["distance"] = @math.json_number(self.distance)
  data["angle"] = @math.json_number(self.angle)
  data["decay"] = @math.json_number(self.decay)
  data["penumbra"] = @math.json_number(self.penumbra)
  data["target"] = Json::string(self.target.uuid)
  if self.map is Some(map) {
    ignore(map.to_json(meta~))
    data["map"] = Json::string(map.uuid)
  }
  data["shadow"] = light.require_shadow().to_json()
}
