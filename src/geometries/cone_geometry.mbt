// Upstream src/geometries/ConeGeometry.js.

///|
#external
pub type ConeGeometry

///|
pub fn ConeGeometry::new(
  radius~ : Double = 1.0,
  height~ : Double = 1.0,
  radial_segments~ : Double = 32.0,
  height_segments~ : Double = 1.0,
  open_ended~ : Bool = false,
  theta_start~ : Double = 0.0,
  theta_length~ : Double = _geometry_two_pi,
) -> @core.BufferGeometry {
  let geometry = CylinderGeometry::new(
    radius_top=0.0,
    radius_bottom=radius,
    height~,
    radial_segments~,
    height_segments~,
    open_ended~,
    theta_start~,
    theta_length~,
  )
  geometry.type_ = "ConeGeometry"
  geometry.parameters = Some({
    values: {
      "radius": @math.json_number(radius),
      "height": @math.json_number(height),
      "radialSegments": @math.json_number(radial_segments),
      "heightSegments": @math.json_number(height_segments),
      "openEnded": Json::boolean(open_ended),
      "thetaStart": @math.json_number(theta_start),
      "thetaLength": @math.json_number(theta_length),
    },
    shapes: [],
  })
  geometry
}

///|
pub fn ConeGeometry::from_json(data : Json) -> @core.BufferGeometry {
  ConeGeometry::new(
    radius?=json_number(data, "radius"),
    height?=json_number(data, "height"),
    radial_segments?=json_number(data, "radialSegments"),
    height_segments?=json_number(data, "heightSegments"),
    open_ended?=json_bool(data, "openEnded"),
    theta_start?=json_number(data, "thetaStart"),
    theta_length?=json_number(data, "thetaLength"),
  )
}
