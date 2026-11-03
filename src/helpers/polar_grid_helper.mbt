///|
/// A polar grid of sectors and rings in the XZ plane. A `LineSegments`.
pub(all) struct PolarGridHelper {}

///|
pub impl @core.Object3DExtension for PolarGridHelper with fn type_name(_) {
  "PolarGridHelper"
}

///|
pub impl @core.Object3DExtension for PolarGridHelper with fn construct(_) {
  PolarGridHelper::new()
}

///|
pub impl @core.Object3DExtension for PolarGridHelper with fn dispose(_, object) {
  object.dispose_kind()
  geometry_of(object).dispose()
  material_of(object).dispose()
}

///|
#deprecated
pub extend PolarGridHelper with @core.Object3DExtension::{
  type_name,
  construct,
  payload,
  has_flag,
  raycast,
  copy_from,
  to_json,
  update_matrix_world,
  update_world_matrix,
  intersects_frustum,
  get_world_direction,
  dispose,
}

///|
/// `new PolarGridHelper( radius, sectors, rings, divisions, color1, color2 )`.
pub fn PolarGridHelper::new(
  radius~ : Double = 10.0,
  sectors~ : Double = 16.0,
  rings~ : Double = 8.0,
  divisions~ : Double = 64.0,
  color1~ : @math.Color = @math.Color::from_hex(0x444444),
  color2~ : @math.Color = @math.Color::from_hex(0x888888),
) -> @core.Object3D {
  let color1 = color1.clone()
  let color2 = color2.clone()
  let vertices : Array[Double] = []
  let colors : Array[Double] = []
  fn push_color(color : @math.Color) {
    colors.push(color.r)
    colors.push(color.g)
    colors.push(color.b)
  }

  // create the sectors
  if sectors > 1.0 {
    for i = 0; i.to_double() < sectors; i = i + 1 {
      let v = i.to_double() / sectors * (@cmath.PI * 2.0)
      let x = @cmath.sin(v) * radius
      let z = @cmath.cos(v) * radius
      vertices.push(0.0)
      vertices.push(0.0)
      vertices.push(0.0)
      vertices.push(x)
      vertices.push(0.0)
      vertices.push(z)
      let color = if (i & 1) != 0 { color1 } else { color2 }
      push_color(color)
      push_color(color)
    }
  }
  // create the rings
  for i = 0; i.to_double() < rings; i = i + 1 {
    let color = if (i & 1) != 0 { color1 } else { color2 }
    let r = radius - radius / rings * i.to_double()
    for j = 0; j.to_double() < divisions; j = j + 1 {
      // first vertex
      let mut v = j.to_double() / divisions * (@cmath.PI * 2.0)
      let mut x = @cmath.sin(v) * r
      let mut z = @cmath.cos(v) * r
      vertices.push(x)
      vertices.push(0.0)
      vertices.push(z)
      push_color(color)
      // second vertex
      v = (j + 1).to_double() / divisions * (@cmath.PI * 2.0)
      x = @cmath.sin(v) * r
      z = @cmath.cos(v) * r
      vertices.push(x)
      vertices.push(0.0)
      vertices.push(z)
      push_color(color)
    }
  }
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(vertices, 3),
    ),
  )
  ignore(
    geometry.set_attribute(
      "color",
      @core.Float32BufferAttribute::new(colors, 3),
    ),
  )
  let material = @core.LineBasicMaterial::new()
  material.vertex_colors = true
  material.tone_mapped = false
  let helper : PolarGridHelper = PolarGridHelper::{ }
  @core.LineSegments::new(geometry~, material=Single(material)).set_extension(
    helper,
  )
}
