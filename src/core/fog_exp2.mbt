// Upstream src/scenes/FogExp2.js.

///|
/// `new FogExp2( color, density )`.
pub fn FogExp2::new(
  color? : @math.Color,
  density~ : Double = 0.00025,
) -> FogExp2 {
  { name: "", color: light_new_color(color), density, }
}

///|
pub fn FogExp2::clone(self : FogExp2) -> FogExp2 {
  FogExp2::new(color=self.color, density=self.density)
}

///|
pub fn FogExp2::to_json(self : FogExp2) -> Json {
  Json::object({
    "type": Json::string("FogExp2"),
    "name": Json::string(self.name),
    "color": json_int(self.color.get_hex()),
    "density": @math.json_number(self.density),
  })
}
