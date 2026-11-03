///|
/// Shows the three axes in red (X), green (Y) and blue (Z). A `LineSegments`.
pub(all) struct AxesHelper {}

///|
pub impl @core.Object3DExtension for AxesHelper with fn type_name(_) {
  "AxesHelper"
}

///|
pub impl @core.Object3DExtension for AxesHelper with fn construct(_) {
  AxesHelper::new()
}

///|
pub impl @core.Object3DExtension for AxesHelper with fn dispose(_, object) {
  object.dispose_kind()
  geometry_of(object).dispose()
  material_of(object).dispose()
}

///|
/// `new AxesHelper( size )`.
pub fn AxesHelper::new(size~ : Double = 1.0) -> @core.Object3D {
  let vertices : Array[Double] = [
    0.0, 0.0, 0.0, size, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, size,
  ]
  let colors : Array[Double] = [
    1.0, 0.0, 0.0, 1.0, 0.6, 0.0, 0.0, 1.0, 0.0, 0.6, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0,
    0.6, 1.0,
  ]
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
  let helper : AxesHelper = AxesHelper::{ }
  @core.LineSegments::new(geometry~, material=Single(material)).set_extension(
    helper,
  )
}

///|
/// `helper.setColors( xAxisColor, yAxisColor, zAxisColor )`.
pub fn AxesHelper::set_colors(
  helper : @core.Object3D,
  x_axis_color : @math.Color,
  y_axis_color : @math.Color,
  z_axis_color : @math.Color,
) -> @core.Object3D {
  let color = @math.Color::new(1.0, 1.0, 1.0)
  let attribute = geometry_of(helper).attributes["color"]
  let array = attribute.array()
  fn to_array(offset : Int32) {
    array[offset] = color.r
    array[offset + 1] = color.g
    array[offset + 2] = color.b
  }

  ignore(color.copy(x_axis_color))
  to_array(0)
  to_array(3)
  ignore(color.copy(y_axis_color))
  to_array(6)
  to_array(9)
  ignore(color.copy(z_axis_color))
  to_array(12)
  to_array(15)
  attribute.set_needs_update(true)
  helper
}

///|
#deprecated
pub extend AxesHelper with @core.Object3DExtension::{
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
