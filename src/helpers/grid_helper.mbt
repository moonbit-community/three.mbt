///|
/// A two-dimensional grid of lines in the XZ plane. A `LineSegments`.
pub(all) struct GridHelper {}

///|
pub impl @core.Object3DExtension for GridHelper with fn type_name(_) {
  "GridHelper"
}

///|
pub impl @core.Object3DExtension for GridHelper with fn construct(_) {
  GridHelper::new()
}

///|
pub impl @core.Object3DExtension for GridHelper with fn dispose(_, object) {
  object.dispose_kind()
  geometry_of(object).dispose()
  material_of(object).dispose()
}

///|
#deprecated
pub extend GridHelper with @core.Object3DExtension::{
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
/// `new GridHelper( size, divisions, color1, color2 )`.
pub fn GridHelper::new(
  size~ : Double = 10.0,
  divisions~ : Double = 10.0,
  color1~ : @math.Color = @math.Color::from_hex(0x444444),
  color2~ : @math.Color = @math.Color::from_hex(0x888888),
) -> @core.Object3D {
  let color1 = color1.clone()
  let color2 = color2.clone()
  let center = divisions / 2.0
  let step = size / divisions
  let half_size = size / 2.0
  let vertices : Array[Double] = []
  let colors : Array[Double] = []
  let mut i = 0
  let mut k = -half_size
  while i.to_double() <= divisions {
    vertices.push(-half_size)
    vertices.push(0.0)
    vertices.push(k)
    vertices.push(half_size)
    vertices.push(0.0)
    vertices.push(k)
    vertices.push(k)
    vertices.push(0.0)
    vertices.push(-half_size)
    vertices.push(k)
    vertices.push(0.0)
    vertices.push(half_size)
    let color = if i.to_double() == center { color1 } else { color2 }
    for _ in 0..<4 {
      colors.push(color.r)
      colors.push(color.g)
      colors.push(color.b)
    }
    i += 1
    k += step
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
  let helper : GridHelper = GridHelper::{ }
  @core.LineSegments::new(geometry~, material=Single(material)).set_extension(
    helper,
  )
}
