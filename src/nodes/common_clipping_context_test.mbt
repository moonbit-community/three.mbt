// Port of test/unit/src/renderers/common/ClippingContext.tests.js.

///|
fn clipping_context_test_distance(
  point : @math.Vector3,
  plane : @math.Vector4,
) -> Double {
  point.x * plane.x + point.y * plane.y + point.z * plane.z - plane.w
}

///|
fn clipping_context_test_group(
  planes : Array[@math.Plane],
  clip_intersection~ : Bool = false,
) -> @core.Object3D {
  let group = @core.ClippingGroup::new()
  match group.kind {
    ClippingGroup(g) => {
      g.clipping_planes = planes
      g.clip_intersection = clip_intersection
    }
    _ => abort("not a clipping group")
  }
  group
}

///|
test "ClippingContext updateGlobal" {
  let scene = @core.Scene::new()
  let root = @nodes.ClippingContext::new()
  let parent_plane = @math.Plane::new(
    normal=@math.Vector3::new(1, 2, 3).normalize(),
    constant=-2,
  )
  let parent = clipping_context_test_group([parent_plane])
  let child_plane = @math.Plane::new(
    normal=@math.Vector3::new(-2, 1, 1).normalize(),
    constant=3,
  )
  let child = clipping_context_test_group([child_plane], clip_intersection=true)
  let world_point = @math.Vector3::new(4, -1, 2)

  // ArrayCamera: planes are shared by all sub-cameras, so they must stay in world space.
  let array_camera = @core.ArrayCamera::new()
  array_camera.position.set(8, -4, 3) |> ignore
  array_camera.rotation.set(0.4, 0.7, -0.2) |> ignore
  array_camera.update_matrix_world()
  root.update_global(scene, array_camera)
  let context = root.get_group_context(parent).get_group_context(child)
  assert_true(
    (clipping_context_test_distance(world_point, context.union_planes[0]) +
    parent_plane.distance_to_point(world_point)).abs() <
    1.0e-12,
  )
  assert_true(
    (clipping_context_test_distance(world_point, context.intersection_planes[0]) +
    child_plane.distance_to_point(world_point)).abs() <
    1.0e-12,
  )

  // Ordinary camera: planes are in view space.
  let camera = @core.PerspectiveCamera::new()
  camera.position.set(-3, 7, 5) |> ignore
  camera.rotation.set(0.5, -0.6, 0.2) |> ignore
  camera.update_matrix_world()
  root.update_global(scene, camera)
  let matrix_world_inverse = match camera.kind {
    Camera(c) => c.matrix_world_inverse
    _ => abort("not a camera")
  }
  let view_point = world_point.clone().apply_matrix4(matrix_world_inverse)
  assert_true(
    physical_equal(
      root.get_group_context(parent).get_group_context(child),
      context,
    ),
  )
  assert_true(
    (clipping_context_test_distance(view_point, context.union_planes[0]) +
    parent_plane.distance_to_point(world_point)).abs() <
    1.0e-12,
  )
  assert_true(
    (clipping_context_test_distance(view_point, context.intersection_planes[0]) +
    child_plane.distance_to_point(world_point)).abs() <
    1.0e-12,
  )
}
