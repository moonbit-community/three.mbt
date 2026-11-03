// Upstream has no test file for ImageUtils. Node has no DOM, so this covers the data path.

///|
extern "js" fn image_with_data(values : @core.JsValue) -> @core.JsValue =
  #|(values) => ({ data: new Float32Array( values ), width: values.length, height: 1 })

///|
extern "js" fn image_first_value(image : @core.JsValue) -> Double = "(image) => image.data[ 0 ]"

///|
extern "js" fn fround(x : Double) -> Double = "Math.fround"

///|
test "ImageUtils srgb_to_linear converts data images into a new object" {
  let image = image_with_data(@core.JsValue::of([0.5, 1.0]))
  let result = @extras.ImageUtils::srgb_to_linear(image)
  assert_false(result.strict_equal(image))
  assert_eq(image_first_value(result), fround(@math.srgb_to_linear(0.5)))
  assert_eq(image_first_value(image), 0.5)
}

///|
test "ImageUtils srgb_to_linear returns an unsupported image unchanged" {
  let image = @core.JsValue::object()
  assert_true(@extras.ImageUtils::srgb_to_linear(image).strict_equal(image))
}

///|
test "ImageUtils get_data_url forwards core's data URL case" {
  let image = @core.JsValue::object()
  image.set("src", @core.JsValue::of("data:image/png;base64,AAAA"))
  assert_eq(
    @extras.ImageUtils::get_data_url(image),
    "data:image/png;base64,AAAA",
  )
}
