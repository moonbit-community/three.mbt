///|
test "ImageBitmapLoader options" {
  let loader = @loaders.ImageBitmapLoader::new()
  assert_eq(loader.options, { "premultiplyAlpha": Json::string("none") })
  let options = { "imageOrientation": Json::string("flipY") }
  assert_true(physical_equal(loader.set_options(options).options, options))
}
