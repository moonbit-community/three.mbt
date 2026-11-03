///|
test "AnimationObjectGroup: Instancing" {
  let group_a = @animation.AnimationObjectGroup::new()
  assert_eq(group_a.stats().objects_total, 0)
}

///|
test "AnimationObjectGroup: smoke test" {
  let object_a = @core.Object3D::new()
  let object_b = @core.Object3D::new()
  let object_c = @core.Object3D::new()
  let path_a = "object.position"
  let path_b = "object.rotation"
  let path_c = "object.scale"
  let parsed_path_a = @animation.PropertyBinding::parse_track_name(path_a)
  let parsed_path_b = @animation.PropertyBinding::parse_track_name(path_b)
  let parsed_path_c = @animation.PropertyBinding::parse_track_name(path_c)
  fn expect(
    group : @animation.AnimationObjectGroup,
    bindings : Array[@animation.PropertyBinding?],
    path : String,
    cached : Int32,
    roots : Array[@core.Object3D],
  ) -> Unit raise {
    let root_nodes = []
    let mut paths_ok = true
    let mut nodes_ok = true
    for i = group.n_cached_objects_; i != bindings.length(); i = i + 1 {
      let binding = bindings[i].unwrap()
      if binding.path != path {
        paths_ok = false
      }
      root_nodes.push(binding.root_node)
    }
    for root in roots {
      if !root_nodes.iter().any(node => physical_equal(node, root)) {
        nodes_ok = false
      }
    }
    assert_true(paths_ok)
    assert_true(nodes_ok)
    assert_eq(group.n_cached_objects_, cached)
    assert_eq(bindings.length() - group.n_cached_objects_, roots.length())
  }

  // initial state
  let group_a = @animation.AnimationObjectGroup::new()
  let bindings_aa = group_a.subscribe_(path_a, parsed_path_a)
  expect(group_a, bindings_aa, path_a, 0, [])
  let group_b = @animation.AnimationObjectGroup::new(objects=[
    object_a, object_b,
  ])
  let bindings_bb = group_b.subscribe_(path_b, parsed_path_b)
  expect(group_b, bindings_bb, path_b, 0, [object_a, object_b])

  // add
  group_a.add([object_a, object_b])
  expect(group_a, bindings_aa, path_a, 0, [object_a, object_b])
  group_b.add([object_c])
  expect(group_b, bindings_bb, path_b, 0, [object_a, object_b, object_c])

  // remove
  group_a.remove([object_a, object_c])
  expect(group_a, bindings_aa, path_a, 1, [object_b])
  group_b.remove([object_a, object_b, object_c])
  expect(group_b, bindings_bb, path_b, 3, [])

  // subscribe after re-add
  group_a.add([object_c])
  expect(group_a, bindings_aa, path_a, 1, [object_b, object_c])
  let bindings_ac = group_a.subscribe_(path_c, parsed_path_c)
  expect(group_a, bindings_ac, path_c, 1, [object_b, object_c])

  // re-add after subscribe
  let bindings_bc = group_b.subscribe_(path_c, parsed_path_c)
  group_b.add([object_a, object_b])
  expect(group_b, bindings_bb, path_b, 1, [object_a, object_b])

  // unsubscribe
  let copy_of_bindings_bc = bindings_bc.copy()
  group_b.unsubscribe_(path_c)
  group_b.add([object_c])
  assert_eq(bindings_bc.length(), copy_of_bindings_bc.length())
  for i, b in bindings_bc {
    assert_true(
      match (b, copy_of_bindings_bc[i]) {
        (Some(x), Some(y)) => physical_equal(x, y)
        (None, None) => true
        _ => false
      },
    )
  }

  // uncache active
  group_b.uncache([object_a])
  expect(group_b, bindings_bb, path_b, 0, [object_b, object_c])

  // uncache cached
  group_a.uncache([object_a])
  expect(group_a, bindings_ac, path_c, 0, [object_b, object_c])
}

///|
test "AnimationObjectGroup: drives every object" {
  let a = @core.Object3D::new()
  let b = @core.Object3D::new()
  let group = @animation.AnimationObjectGroup::new(objects=[a, b])
  let mixer = @animation.AnimationMixer::new(group)
  let clip = @animation.AnimationClip::new(tracks=[
    @animation.VectorKeyframeTrack::new(".position", [0, 1], [0, 0, 0, 2, 4, 6]),
  ])
  mixer.clip_action(clip).play() |> ignore
  mixer.update(0.5) |> ignore
  assert_eq(a.position.y, 2.0)
  assert_eq(b.position.z, 3.0)
}
