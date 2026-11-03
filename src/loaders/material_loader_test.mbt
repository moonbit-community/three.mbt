///|
test "MaterialLoader textures" {
  assert_eq(@loaders.MaterialLoader::new().textures.length(), 0)
}

///|
test "MaterialLoader parse" {
  let texture = @core.Texture::new()
  let loader = @loaders.MaterialLoader::new().set_textures({ "t": texture })
  let json = @json.parse(
    (
      #|{"uuid":"u","type":"MeshStandardMaterial","name":"n","color":255,"roughness":0.25,"map":"t","normalMap":"missing"}
    ),
  )
  let material = loader.parse(json)
  assert_true(material.is_mesh_standard_material())
  assert_eq(material.uuid, "u")
  assert_eq(material.name, "n")
  assert_eq(material.color.unwrap().get_hex(), 255)
  assert_eq(material.roughness, Some(0.25))
  assert_true(material.map is Some(map) && physical_equal(map, texture))
  // `textures[ json.normalMap ] || null`
  assert_true(material.normal_map is None)
}

///|
test "MaterialLoader createMaterialFromType" {
  let types = [
    "ShadowMaterial", "SpriteMaterial", "RawShaderMaterial", "ShaderMaterial", "PointsMaterial",
    "MeshPhysicalMaterial", "MeshStandardMaterial", "MeshPhongMaterial", "MeshToonMaterial",
    "MeshNormalMaterial", "MeshLambertMaterial", "MeshDepthMaterial", "MeshDistanceMaterial",
    "MeshBasicMaterial", "MeshMatcapMaterial", "LineDashedMaterial", "LineBasicMaterial",
    "Material",
  ]
  for type_ in types {
    assert_eq(
      @loaders.MaterialLoader::create_material_from_type_static(type_).type_,
      type_,
    )
  }
  // unknown types become a plain `Material`
  assert_eq(
    @loaders.MaterialLoader::new().create_material_from_type("Nope").type_,
    "Material",
  )
}

///|
test "MaterialLoader registerMaterial" {
  @loaders.MaterialLoader::register_material("CustomMaterial", () => {
    let material = @core.MeshBasicMaterial::new()
    material.type_ = "CustomMaterial"
    material
  })
  let material = @loaders.MaterialLoader::new().parse(
    @json.parse("{\"type\":\"CustomMaterial\",\"uuid\":\"c\"}"),
  )
  assert_eq(material.type_, "CustomMaterial")
  assert_true(material.is_mesh_basic_material())
  assert_eq(material.uuid, "c")
}
