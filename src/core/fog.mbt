// Upstream src/scenes/Fog.js.

///|
/// `new Fog( color, near, far )`.
pub fn Fog::new(
  color? : @math.Color,
  near~ : Double = 1.0,
  far~ : Double = 1000.0,
) -> Fog {
  { name: "", color: light_new_color(color), near, far, }
}

///|
pub fn Fog::clone(self : Fog) -> Fog {
  Fog::new(color=self.color, near=self.near, far=self.far)
}

///|
pub fn Fog::to_json(self : Fog) -> Json {
  Json::object({
    "type": Json::string("Fog"),
    "name": Json::string(self.name),
    "color": json_int(self.color.get_hex()),
    "near": @math.json_number(self.near),
    "far": @math.json_number(self.far),
  })
}
