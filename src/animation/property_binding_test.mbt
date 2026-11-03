///|
fn binding_test_mesh() -> (@core.Object3D, @core.Material) {
  let material = @core.MeshBasicMaterial::new()
  let mesh = @core.Mesh::new(
    geometry=@core.BufferGeometry::new(),
    material=Single(material),
  )
  (mesh, material)
}

///|
test "PropertyBinding: Instancing" {
  let (mesh, _) = binding_test_mesh()
  let path = ".material.opacity"
  let parsed_path : @animation.ParsedPath = {
    node_name: Some(""),
    object_name: Some("material"),
    object_index: None,
    property_name: "opacity",
    property_index: None,
  }

  // mesh, path
  let object = @animation.PropertyBinding::new(mesh, path)
  assert_eq(object.path, path)

  // mesh, path, parsedPath
  let object_all = @animation.PropertyBinding::new(mesh, path, parsed_path~)
  assert_eq(object_all.parsed_path, parsed_path)
}

///|
test "PropertyBinding: sanitizeNodeName" {
  assert_eq(
    @animation.PropertyBinding::sanitize_node_name("valid-name-123_"),
    "valid-name-123_",
  )
  assert_eq(@animation.PropertyBinding::sanitize_node_name("急須"), "急須")
  assert_eq(
    @animation.PropertyBinding::sanitize_node_name(
      "space separated name 123_ -",
    ),
    "space_separated_name_123__-",
  )
  assert_eq(
    @animation.PropertyBinding::sanitize_node_name("\"Mátyás\" %_* 😇"),
    "\"Mátyás\"_%_*_😇",
  )
  assert_eq(
    @animation.PropertyBinding::sanitize_node_name("/invalid: name ^123.[_]"),
    "invalid_name_^123_",
  )
}

///|
test "PropertyBinding: parseTrackName" {
  fn path(
    node_name : String?,
    object_name : String?,
    object_index : String?,
    property_name : String,
    property_index : String?,
  ) -> @animation.ParsedPath {
    { node_name, object_name, object_index, property_name, property_index, }
  }

  let paths = [
    (".property", path(None, None, None, "property", None)),
    ("nodeName.property", path(Some("nodeName"), None, None, "property", None)),
    ("a.property", path(Some("a"), None, None, "property", None)),
    (
      "no.de.Name.property",
      path(Some("no.de.Name"), None, None, "property", None),
    ),
    (
      "no.d-e.Name.property",
      path(Some("no.d-e.Name"), None, None, "property", None),
    ),
    (
      "nodeName.property[accessor]",
      path(Some("nodeName"), None, None, "property", Some("accessor")),
    ),
    (
      "nodeName.material.property[accessor]",
      path(
        Some("nodeName"),
        Some("material"),
        None,
        "property",
        Some("accessor"),
      ),
    ),
    (
      "no.de.Name.material.property",
      path(Some("no.de.Name"), Some("material"), None, "property", None),
    ),
    (
      "no.de.Name.material[materialIndex].property",
      path(
        Some("no.de.Name"),
        Some("material"),
        Some("materialIndex"),
        "property",
        None,
      ),
    ),
    (
      "uuid.property[accessor]",
      path(Some("uuid"), None, None, "property", Some("accessor")),
    ),
    (
      "uuid.objectName[objectIndex].propertyName[propertyIndex]",
      path(
        Some("uuid"),
        Some("objectName"),
        Some("objectIndex"),
        "propertyName",
        Some("propertyIndex"),
      ),
    ),
    (
      "parentName/nodeName.property",
      // directoryName is currently unused.
      path(Some("nodeName"), None, None, "property", None),
    ),
    (
      "parentName/no.de.Name.property",
      path(Some("no.de.Name"), None, None, "property", None),
    ),
    (
      "parentName/parentName/nodeName.property[index]",
      path(Some("nodeName"), None, None, "property", Some("index")),
    ),
    (
      ".bone[Armature.DEF_cog].position",
      path(None, Some("bone"), Some("Armature.DEF_cog"), "position", None),
    ),
    (
      "scene:helium_balloon_model:helium_balloon_model.position",
      path(Some("helium_balloon_model"), None, None, "position", None),
    ),
    (
      "急須.材料[零]",
      path(Some("急須"), None, None, "材料", Some("零")),
    ),
    ("📦.🎨[🔴]", path(Some("📦"), None, None, "🎨", Some("🔴"))),
  ]
  for entry in paths {
    let (name, expected) = entry
    assert_eq(@animation.PropertyBinding::parse_track_name(name), expected)
  }
}

///|
test "PropertyBinding: setValue" {
  let paths = [".material.opacity", ".material[opacity]"]
  for path in paths {
    let original_value = 0.0
    let expected_value = 1.0
    let (mesh, material) = binding_test_mesh()
    material.opacity = original_value
    let binding = @animation.PropertyBinding::new(mesh, path)
    binding.bind()
    assert_eq(material.opacity, original_value)
    binding.set_value([expected_value], 0)
    assert_eq(material.opacity, expected_value)
  }
}

///|
test "PropertyBinding: bones, morph targets and versioning" {
  let bone = @core.Bone::new()
  bone.name = "Hips"
  let skeleton = @core.Skeleton::new(bones=[bone])
  let geometry = @core.BufferGeometry::new()
  let material = @core.MeshStandardMaterial::new()
  let mesh = @core.SkinnedMesh::new(geometry~, material=Single(material))
  mesh.add(bone) |> ignore
  mesh.bind(skeleton)
  let binding = @animation.PropertyBinding::new(mesh, ".bones[Hips].position")
  binding.set_value([1.0, 2.0, 3.0], 0)
  assert_eq(bone.position.x, 1.0)
  assert_eq(bone.position.z, 3.0)
  assert_eq(binding.target_object_kind(), Some("Object3D"))
  assert_true(bone.matrix_world_needs_update)
  let version = material.version
  let color = @animation.PropertyBinding::new(mesh, ".material.color")
  color.set_value([0.25, 0.5, 0.75], 0)
  assert_eq(material.color.unwrap().g, 0.5)
  assert_eq(material.version, version + 1)
  let buffer = [0.0, 0.0, 0.0, 0.0]
  color.get_value(buffer, 1)
  assert_eq(buffer, [0.0, 0.25, 0.5, 0.75])
  // a property this material lacks binds to nothing
  let missing = @animation.PropertyBinding::new(mesh, ".material.dashSize")
  missing.bind()
  assert_false(missing.is_bound())
}
