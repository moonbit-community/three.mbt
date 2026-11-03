///|
test "DataTextureLoader createDataTexture applies the parsed data" {
  let loader = @loaders.DataTextureLoader::new(parse=_ => {
    let data = @loaders.DataTexData::new()
    data.data = Some(@core.TypedArray::uint8([1, 2, 3, 4, 5, 6, 7, 8]))
    data.width = Some(2)
    data.height = Some(1)
    data.wrap_s = Some(@core.RepeatWrapping)
    data.color_space = Some(@core.SRGBColorSpace)
    data.mipmaps = Some([])
    data
  })
  let texture = loader.create_data_texture(@core.JsValue::null())
  guard texture.image() is DataImage(image) else { fail("no data image") }
  assert_eq(image.width, 2)
  assert_eq(image.height, 1)
  assert_eq(image.data.unwrap().length(), 8)
  assert_eq(texture.wrap_s, @core.RepeatWrapping)
  assert_eq(texture.wrap_t, @core.ClampToEdgeWrapping)
  assert_eq(texture.mag_filter, @core.LinearFilter)
  // `mipmaps` switch to trilinear filtering
  assert_eq(texture.min_filter, @core.LinearMipmapLinearFilter)
  assert_eq(texture.anisotropy, 1)
  assert_eq(texture.color_space, @core.SRGBColorSpace)
  assert_eq(texture.version, 1)
}

///|
test "DataTextureLoader mipmapCount 1 keeps linear filtering" {
  let loader = @loaders.DataTextureLoader::new(parse=_ => {
    let data = @loaders.DataTexData::new()
    data.image = Some(DataImage(@core.DataImage::new(width=4, height=4)))
    data.mipmaps = Some([])
    data.mipmap_count = Some(1)
    data.generate_mipmaps = Some(true)
    data
  })
  let texture = loader.create_data_texture(@core.JsValue::null())
  assert_eq(texture.image().width(), 4.0)
  assert_eq(texture.min_filter, @core.LinearFilter)
  assert_true(texture.generate_mipmaps)
}
