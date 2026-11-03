// `toJSON` text as upstream's `JSON.stringify( object.toJSON() )`, and the order in which
// constructors draw uuids and ids. The webgl-free differential check of both is the
// json_uuid_diff harness; these are the in-repo guards.

///|
extern "js" fn json_fidelity_infinity() -> Double = "() => Infinity"

///|
fn json_fidelity_key(json : Json, key : String) -> String {
  guard json is { "object": Object(object), .. } else { abort("no object") }
  match object.get(key) {
    Some(value) => value.stringify()
    None => "undefined"
  }
}

///|
test "InstancedBufferGeometry writes its default instanceCount as null" {
  let text = @core.InstancedBufferGeometry::new().to_json().stringify()
  assert_true(text.contains("\"instanceCount\":null"))
}

///|
test "non-finite camera and light numbers are written as null" {
  let inf = json_fidelity_infinity()
  let camera = @core.PerspectiveCamera::new(far=inf)
  inspect(json_fidelity_key(camera.to_json(), "far"), content="null")
  let light = @core.PointLight::new(distance=inf)
  inspect(json_fidelity_key(light.to_json(), "distance"), content="null")
  let lod = @core.LOD::new()
  ignore(lod.add_level(@core.Object3D::new(), distance=inf))
  inspect(
    json_fidelity_key(lod.to_json(), "levels").contains("\"distance\":null"),
    content="true",
  )
}

///|
test "Material::from_json keeps a null attenuationDistance" {
  let material = @core.MeshPhysicalMaterial::new()
  let json = material.to_json()
  guard json is Object(data) else { abort("not an object") }
  inspect(data.get("attenuationDistance"), content="Some(Null)")
  let back = @core.MeshPhysicalMaterial::new().from_json(json)
  inspect(
    back.to_json().stringify().contains("\"attenuationDistance\":null"),
    content="true",
  )
}

///|
test "BatchedMesh geometryInfo keys are in upstream's order" {
  let mesh = @core.BatchedMesh::new(1, 3, max_index_count=3)
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.BufferAttribute::new(
        @core.TypedArray::float32([0.0, 0, 0, 1, 0, 0, 0, 1, 0]),
        3,
      ),
    ),
  )
  ignore(geometry.set_index([0, 1, 2]))
  let id = mesh.add_geometry(geometry)
  ignore(mesh.get_bounding_box_at(id, @math.Box3::new()))
  ignore(mesh.get_bounding_sphere_at(id, @math.Sphere::new()))
  let info = json_fidelity_key(mesh.to_json(), "geometryInfo")
  let box = info.find("\"boundingBox\"").unwrap()
  let sphere = info.find("\"boundingSphere\"").unwrap()
  let active = info.find("\"active\"").unwrap()
  assert_true(box < sphere && sphere < active)
}

///|
test "lights draw ids in upstream's order: light, target, shadow camera" {
  let directional = @core.DirectionalLight::new()
  guard directional.as_light().kind is DirectionalLight(d) else {
    abort("not a DirectionalLight")
  }
  let camera = directional.as_light().shadow.unwrap().camera
  inspect(
    (d.target.id - directional.id, camera.id - directional.id),
    content="(1, 2)",
  )
  let spot = @core.SpotLight::new()
  guard spot.as_light().kind is SpotLight(s) else { abort("not a SpotLight") }
  let camera = spot.as_light().shadow.unwrap().camera
  inspect((s.target.id - spot.id, camera.id - spot.id), content="(1, 2)")
  let point = @core.PointLight::new()
  let camera = point.as_light().shadow.unwrap().camera
  inspect(camera.id - point.id, content="1")
}

///|
/// Replaces `Math.random` with a seeded generator; `json_fidelity_unseed` restores it.
extern "js" fn json_fidelity_seed(seed : Int32) -> Unit = "(s) => { if (globalThis.__jf_random === undefined) globalThis.__jf_random = Math.random; let x = s >>> 0; Math.random = () => { x = (Math.imul(x, 1103515245) + 12345) >>> 0; return x / 4294967296; }; }"

///|
extern "js" fn json_fidelity_unseed() -> Unit = "() => { if (globalThis.__jf_random !== undefined) Math.random = globalThis.__jf_random; }"

///|
test "constructors draw uuids in upstream's order" {
  // the uuids a seed gives, in order
  json_fidelity_seed(7)
  let expected = [
    @math.generate_uuid(),
    @math.generate_uuid(),
    @math.generate_uuid(),
  ]
  // light, then target, then shadow camera
  json_fidelity_seed(7)
  let light = @core.DirectionalLight::new()
  guard light.as_light().kind is DirectionalLight(d) else { abort("no target") }
  let camera = light.as_light().shadow.unwrap().camera
  let directional = [light.uuid, d.target.uuid, camera.uuid]
  // the default material (a default argument), then the sprite
  json_fidelity_seed(7)
  let sprite = @core.Sprite::new()
  guard sprite.kind is Sprite(data) else { abort("not a sprite") }
  let sprite_uuids = [data.material.uuid, sprite.uuid]
  json_fidelity_unseed()
  assert_eq(directional, expected)
  assert_eq(sprite_uuids, expected[0:2].to_array())
}
