// renderers/common/nodes/NodeSampledTexture.js

///|
test "a sampled texture binding reads the texture its node references" {
  // PMREMGenerator's cubemap material: `cubeTexture()` sampled once, the texture
  // assigned to the base node before each render
  let env_map = @nodes.cube_texture_empty()
  let sampled = env_map.sample(@nodes.position_world_direction)
  let cube = @core.CubeTexture::new()
  @nodes.TextureNode::set_value(env_map, Some(cube))
  let binding = @nodes.NodeSampledCubeTexture::new(
    "envMap",
    Some(sampled),
    None,
  )
  assert_true(physical_equal(binding.texture().unwrap(), cube))
  // and follows a later assignment on update
  let other = @core.CubeTexture::new()
  @nodes.TextureNode::set_value(env_map, Some(other))
  assert_true(binding.update())
  assert_true(physical_equal(binding.texture().unwrap(), other))
}
