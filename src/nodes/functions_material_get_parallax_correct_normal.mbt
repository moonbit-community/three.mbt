// nodes/functions/material/getParallaxCorrectNormal.js

///|
/// `getParallaxCorrectNormal( normal, cubeSize, cubePos )`: a box-projected
/// environment lookup direction.
pub let get_parallax_correct_normal : Node = module_nodes(
  "nodes/functions/material/getParallaxCorrectNormal.js:getParallaxCorrectNormal",
  fn() {
    fn_(fn(inputs, _) {
      let normal = inputs.get(0).unwrap()
      let cube_size = inputs.get(1).unwrap()
      let cube_pos = inputs.get(2).unwrap()
      let n_dir = normalize(normal).to_const()
      let positive = n_dir.greater_than_equal(0)
      let safe_dir = positive.select(
        n_dir.max(epsilon),
        else_node=n_dir.min(epsilon.negate()),
      )
      let extent = cube_size.mul(0.5).to_const()
      let distances = positive
        .select(extent, else_node=extent.negate())
        .add(cube_pos)
        .sub(position_world)
        .div(safe_dir)
        .to_const()
      let correction = min_of([distances.x(), distances.y(), distances.z()]).to_const()
      Some(position_world.add(n_dir.mul(correction)).sub(cube_pos))
    })
  },
)
