// nodes/functions/material/getGeometryRoughness.js

///|
/// `getGeometryRoughness()`: the roughness from the screen-space normal derivatives.
pub let get_geometry_roughness : Node = module_nodes(
  "nodes/functions/material/getGeometryRoughness.js:getGeometryRoughness",
  fn() {
    fn_(fn(_, builder) {
      let geometry = match builder.geometry {
        Some(g) => g
        None =>
          abort(
            "TypeError: Cannot read properties of null (reading 'hasAttribute')",
          )
      }
      if geometry.has_attribute("normal") == false {
        return Some(float(0))
      }
      let dxy = normal_view_geometry
        .d_fdx()
        .abs()
        .max(normal_view_geometry.d_fdy().abs())
      let geometry_roughness = dxy.x().max(dxy.y()).max(dxy.z())
      Some(geometry_roughness)
    })
  },
)
