// Unit tests of the WebGPU backend pieces that run without a GPU (the call order on a
// GPU is checked against upstream by the mock-GPU harness, diff/core/g9).

///|
extern "js" fn web_gpu_test_canvas() -> @core.JsValue = "() => ( { width: 4, height: 4, style: {} } )"

///|
fn web_gpu_test_format(texture : @core.Texture) -> String {
  @webgpu.wgpu_get_format_device(texture, None).unwrap_or("undefined")
}

///|
test "getFormat maps texture formats and types" {
  let t = @core.DataTexture::new(
    data=@core.TypedArray::uint8(16),
    width=2,
    height=2,
  )
  inspect(web_gpu_test_format(t), content="rgba8unorm")
  t.color_space = @math.SRGBColorSpace
  inspect(web_gpu_test_format(t), content="rgba8unorm-srgb")
  t.type_ = @core.HalfFloatType
  inspect(web_gpu_test_format(t), content="rgba16float")
  t.format = @core.RedIntegerFormat
  t.type_ = @core.UnsignedIntType
  inspect(web_gpu_test_format(t), content="r32uint")
  let d = @core.DepthTexture::new(width=2, height=2)
  inspect(web_gpu_test_format(d), content="depth24plus")
  d.format = @core.DepthStencilFormat
  d.type_ = @core.UnsignedInt248Type
  inspect(web_gpu_test_format(d), content="depth24plus-stencil8")
  let c = @core.CompressedTexture::new(
    mipmaps=[],
    width=4,
    height=4,
    format=@core.RGBA_ASTC_6x6_Format,
  )
  c.color_space = @math.SRGBColorSpace
  inspect(web_gpu_test_format(c), content="astc-6x6-unorm-srgb")
  c.format = @core.RGBA_BPTC_Format
  c.color_space = @math.NoColorSpace
  inspect(web_gpu_test_format(c), content="bc7-rgba-unorm")
}

///|
test "WebGPUConstants" {
  inspect(@webgpu.gpu_feature_names.length(), content="20")
  inspect(@webgpu.gpu_feature_names[0], content="core-features-and-limits")
  inspect(
    @webgpu.gpu_feature_map("texture-compression-s3tc").unwrap_or(""),
    content="texture-compression-bc",
  )
  assert_true(@webgpu.gpu_feature_map("timestamp-query") is None)
  inspect(
    @webgpu.GPUTextureFormat_Depth24PlusStencil8,
    content="depth24plus-stencil8",
  )
  inspect(@webgpu.GPUColorWriteFlags_All, content="15")
}

///|
test "WebGPUBackend defaults" {
  let parameters = @core.JsValue::object()
  parameters.set("canvas", web_gpu_test_canvas())
  let backend = @webgpu.WebGPUBackend::new(parameters~)
  inspect(backend.class_.class_name(), content="WebGPUBackend")
  assert_true(backend.has_flag("isWebGPUBackend"))
  assert_true(backend.coordinate_system() == @core.WebGPUCoordinateSystem)
  assert_true(backend.has_timestamp())
  assert_true(backend.has_bundles())
  inspect(backend.get_max_anisotropy(), content="16")
  // `alpha` defaults to true, `requiredLimits` to {}
  let alpha : Bool = backend.parameters.get("alpha").cast()
  assert_true(alpha)
  inspect(backend.parameters.get("requiredLimits").key_count(), content="0")
  let payload = @webgpu.WebGPUBackend::of(backend).unwrap()
  assert_true(payload.compatibility_mode is None)
  assert_true(payload.device is None)
  // the base class has no compatibility entries
  assert_true(!backend.has_compatibility("unknown"))
}

///|
test "WebGPURenderer" {
  let renderer = @webgpu.WebGPURenderer::new(
    canvas=web_gpu_test_canvas(),
    antialias=true,
  )
  assert_true(@webgpu.is_web_gpu_renderer(renderer))
  assert_true(renderer.backend.has_flag("isWebGPUBackend"))
  inspect(renderer.samples(), content="4")
  assert_true(!renderer.initialized())
}
