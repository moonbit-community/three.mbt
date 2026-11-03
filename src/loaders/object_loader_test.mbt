///|
fn object_loader_test_eps() -> Double {
  0.0001
}

///|
test "ObjectLoader parse (pivot)" {
  let object = @core.Object3D::new()
  object.position.set(1.0, 2.0, 3.0) |> ignore
  object.rotation.set(0.3, -0.7, 1.2) |> ignore
  object.scale.set(2.0, 3.0, 4.0) |> ignore
  object.pivot = Some(@math.Vector3::new(1.0, -2.0, 3.0))
  object.update_matrix()
  let loaded = @loaders.ObjectLoader::new().parse(object.to_json())
  guard loaded.pivot is Some(pivot) else { fail("Pivot is restored") }
  assert_true(pivot.equals(object.pivot.unwrap()))
  assert_true(
    loaded.position.distance_to(object.position) < object_loader_test_eps(),
  )
}

///|
test "ObjectLoader parse (Sprite center)" {
  let sprite = @core.Sprite::new()
  guard sprite.kind is Sprite(data) else { fail("not a sprite") }
  data.center.set(0.5, 0.0) |> ignore
  let loaded = @loaders.ObjectLoader::new().parse(sprite.to_json())
  guard loaded.kind is Sprite(loaded_data) else { fail("not a sprite") }
  assert_true(loaded_data.center.equals(data.center))
}

///|
test "ObjectLoader parse calls on_load when there are no images" {
  let calls = []
  let mesh = @core.Mesh::new()
  let loaded = @loaders.ObjectLoader::new().parse(mesh.to_json(), on_load=o => {
    calls.push(o.uuid)
  })
  assert_eq(calls, [mesh.uuid])
  assert_eq(loaded.uuid, mesh.uuid)
  assert_true(loaded.is_mesh())
}

///|
test "ObjectLoader binds light targets and skeletons" {
  let scene = @core.Scene::new()
  let light = @core.DirectionalLight::new()
  let target = @core.Object3D::new()
  scene.add(target) |> ignore
  guard light.as_light().kind is DirectionalLight(directional) else {
    fail("not a directional light")
  }
  directional.target = target
  scene.add(light) |> ignore
  let lonely = @core.SpotLight::new()
  scene.add(lonely) |> ignore
  let bone = @core.Bone::new()
  let mesh = @core.SkinnedMesh::new()
  mesh.add(bone) |> ignore
  mesh.bind(@core.Skeleton::new(bones=[bone]))
  scene.add(mesh) |> ignore
  let loaded = @loaders.ObjectLoader::new().parse(scene.to_json())
  let loaded_light = loaded.children[1]
  guard loaded_light.as_light().kind is DirectionalLight(loaded_directional) else {
    fail("not a directional light")
  }
  assert_true(physical_equal(loaded_directional.target, loaded.children[0]))
  guard loaded.children[2].as_light().kind is SpotLight(spot) else {
    fail("not a spot light")
  }
  // a target outside the scene becomes a new object
  assert_true(spot.target.parent is None)
  assert_true(spot.target.uuid != lonely.as_spot_light().target.uuid)
  guard loaded.children[3].kind is Mesh({ kind: SkinnedMesh(skinned), .. }) else {
    fail("not a skinned mesh")
  }
  guard skinned.skeleton is Some(skeleton) else { fail("no skeleton") }
  assert_eq(skeleton.bones.length(), 1)
  assert_true(physical_equal(skeleton.bones[0], loaded.children[3].children[0]))
}

///|
test "ObjectLoader LOD levels and textures" {
  let lod = @core.LOD::new()
  let near = @core.Mesh::new()
  let far = @core.Points::new()
  lod.add_level(near, distance=0.0) |> ignore
  lod.add_level(far, distance=50.0, hysteresis=0.5) |> ignore
  let loaded = @loaders.ObjectLoader::new().parse(lod.to_json())
  guard loaded.kind is LOD(levels) else { fail("not a LOD") }
  assert_eq(levels.levels.length(), 2)
  assert_eq(levels.levels[1].distance, 50.0)
  assert_eq(levels.levels[1].hysteresis, 0.5)
  assert_true(physical_equal(levels.levels[1].object, loaded.children[1]))
}

///|
test "ObjectLoader parses data textures" {
  let texture = @core.DataTexture::new(
    data=@core.TypedArray::uint8([1, 2, 3, 4]),
    width=1,
    height=1,
  )
  texture.wrap_s = @core.RepeatWrapping
  let material = @core.MeshBasicMaterial::new()
  material.map = Some(texture)
  let mesh = @core.Mesh::new(material=Single(material))
  let loaded = @loaders.ObjectLoader::new().parse(mesh.to_json())
  guard loaded.get_material() is Some(Single(loaded_material)) &&
    loaded_material.map is Some(map) else {
    fail("no map")
  }
  assert_eq(map.uuid, texture.uuid)
  assert_true(map.texture_type is DataTexture)
  assert_eq(map.wrap_s, @core.RepeatWrapping)
  guard map.image() is DataImage({ data: Some(data), .. }) else {
    fail("no data")
  }
  assert_eq(data.to_array(), [1.0, 2, 3, 4])
}

///|
test "ObjectLoader registerGeometry" {
  @loaders.ObjectLoader::register_geometry("CustomGeometry", (_, _) => {
    let geometry = @core.BufferGeometry::new()
    geometry.type_ = "CustomGeometry"
    geometry
  })
  let json = @json.parse(
    (
      #|{"metadata":{"type":"Object"},"geometries":[{"uuid":"g","type":"CustomGeometry","name":"custom"}],
      #| "object":{"uuid":"o","type":"Mesh","geometry":"g"}}
    ),
  )
  let loaded = @loaders.ObjectLoader::new().parse(json)
  guard loaded.get_geometry() is Some(geometry) else { fail("no geometry") }
  assert_eq(geometry.type_, "CustomGeometry")
  assert_eq(geometry.uuid, "g")
  assert_eq(geometry.name, "custom")
}
