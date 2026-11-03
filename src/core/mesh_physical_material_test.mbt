///|
test "MeshPhysicalMaterial Extending" {
  let object = @core.MeshPhysicalMaterial::new()
  assert_true(object.is_mesh_standard_material())
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "MeshPhysicalMaterial type" {
  let object = @core.MeshPhysicalMaterial::new()
  assert_eq(object.type_, "MeshPhysicalMaterial")
}

///|
test "MeshPhysicalMaterial isMeshPhysicalMaterial" {
  assert_true(@core.MeshPhysicalMaterial::new().is_mesh_physical_material())
  assert_true(!@core.Material::new().is_mesh_physical_material())
}

///|
test "MeshPhysicalMaterial clone keeps the class" {
  let object = @core.MeshPhysicalMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_mesh_physical_material())
  assert_eq(cloned.type_, "MeshPhysicalMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "MeshPhysicalMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.MeshPhysicalMaterial::new().to_json()),
    material_json_base_keys +
    ",color,roughness,metalness,sheen,sheenColor,sheenRoughness,emissive,emissiveIntensity,specularIntensity,specularColor,clearcoat,clearcoatRoughness,diffuseRoughness,dispersion,retroreflectivity,iridescence,iridescenceIOR,iridescenceThicknessMinimum,iridescenceThicknessMaximum,anisotropy,anisotropyRotation,envMapRotation,envMapIntensity,reflectivity,transmission,thickness,attenuationDistance,attenuationColor,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,flatShading,fog",
  )
}

///|
test "MeshPhysicalMaterial retroreflectivity" {
  let object = @core.MeshPhysicalMaterial::new()
  assert_eq(object.retroreflectivity(), Some(0.0))
  object.set_retroreflectivity(0.75)
  assert_eq(object.retroreflectivity(), Some(0.75))
}

///|
test "MeshPhysicalMaterial copy copies retroreflectivity" {
  let source = @core.MeshPhysicalMaterial::new()
  source.set_values(values=Map([("retroreflectivity", Number(0.5))]))
  let object = @core.MeshPhysicalMaterial::new()
  ignore(object.copy(source))
  assert_eq(object.retroreflectivity(), Some(0.5))
}

///|
test "MeshPhysicalMaterial fromJSON restores retroreflectivity" {
  let source = @core.MeshPhysicalMaterial::new()
  source.set_values(values=Map([("retroreflectivity", Number(0.25))]))
  let json = source.to_json()
  let object = @core.MeshPhysicalMaterial::new()
  ignore(object.from_json(json))
  guard json is { "retroreflectivity": Number(value, ..), .. } else {
    fail("key")
  }
  assert_eq(value, 0.25)
  assert_eq(object.retroreflectivity(), Some(0.25))
}

///|
test "MeshPhysicalMaterial reflectivity derives from ior" {
  let object = @core.MeshPhysicalMaterial::new()
  // the field stays unset: `reflectivity()` is the accessor
  assert_true(object.reflectivity is None)
  assert_true(approx(object.reflectivity().unwrap(), 0.5))
  object.set_reflectivity(1.0)
  assert_true(approx(object.ior.unwrap(), 1.4 / 0.6))
  assert_true(approx(object.reflectivity().unwrap(), 1.0))
  object.ior = Some(1.0)
  assert_eq(object.reflectivity(), Some(0.0))
  object.ior = Some(1000.0)
  assert_true(object.reflectivity().unwrap() <= 1.0)
}

///|
test "MeshPhysicalMaterial accessors bump version when crossing zero" {
  let object = @core.MeshPhysicalMaterial::new()
  let setters : Array[(Double) -> Unit] = [
    v => object.set_anisotropy(v),
    v => object.set_clearcoat(v),
    v => object.set_diffuse_roughness(v),
    v => object.set_dispersion(v),
    v => object.set_iridescence(v),
    v => object.set_retroreflectivity(v),
    v => object.set_sheen(v),
    v => object.set_transmission(v),
  ]
  for setter in setters {
    let version = object.version
    setter(0.5)
    assert_eq(object.version, version + 1)
    setter(0.75)
    assert_eq(object.version, version + 1)
    setter(0.0)
    assert_eq(object.version, version + 2)
  }
}

///|
test "accessors of MeshPhysicalMaterial are plain properties on other classes" {
  let object = @core.MeshStandardMaterial::new()
  assert_eq(object.clearcoat(), None)
  assert_eq(object.reflectivity(), None)
  object.set_clearcoat(1.0)
  assert_eq(object.clearcoat(), Some(1.0))
  assert_eq(object.version, 0)
  object.set_reflectivity(0.5)
  assert_eq(object.reflectivity(), Some(0.5))
}
