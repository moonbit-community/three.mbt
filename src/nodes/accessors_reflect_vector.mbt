// nodes/accessors/ReflectVector.js

///|
pub let reflect_view : Node = module_nodes(
  "nodes/accessors/ReflectVector.js:reflectView",
  fn() { position_view_direction.negate().reflect(normal_view) },
)

///|
pub let refract_view : Node = module_nodes(
  "nodes/accessors/ReflectVector.js:refractView",
  fn() {
    position_view_direction
    .negate()
    .refract(normal_view, material_refraction_ratio)
  },
)

///|
pub let reflect_vector : Node = module_nodes(
  "nodes/accessors/ReflectVector.js:reflectVector",
  fn() {
    reflect_view
    .transform_direction(camera_world_matrix)
    .to_var(name="reflectVector")
  },
)

///|
pub let refract_vector : Node = module_nodes(
  "nodes/accessors/ReflectVector.js:refractVector",
  fn() {
    refract_view
    .transform_direction(camera_world_matrix)
    .to_var(name="refractVector")
  },
)
