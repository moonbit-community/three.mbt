// Differential scenarios for WebGLTextures (group 1). Each test mirrors
// harness/scenarios/textures_<name>.mjs in the diff/core/webgl harness step by step;
// run_diff.mjs compares the two call logs. Without the harness the tests still run
// against the mock and check a few results directly.

///|
/// The modules `WebGLTextures` needs, built as `WebGLRenderer.initGLContext` builds them.
struct TexturesEnv {
  gl : @webgl.WebGL2RenderingContext
  properties : @webgl.WebGLProperties
  info : @webgl.WebGLInfo
  textures : @webgl.WebGLTextures
}

///|
fn textures_env(options~ : String = "{}") -> TexturesEnv {
  let gl = mock_gl(options~)
  let extensions = @webgl.WebGLExtensions::new(gl)
  let utils = @webgl.WebGLUtils::new(gl, extensions)
  let capabilities = @webgl.WebGLCapabilities::new(
    gl,
    extensions,
    {
      precision: None,
      logarithmic_depth_buffer: false,
      reversed_depth_buffer: false,
    },
    utils,
  )
  let state = @webgl.WebGLState::new(gl, extensions)
  let properties = @webgl.WebGLProperties::new()
  let info = @webgl.WebGLInfo::new(gl)
  let textures = @webgl.WebGLTextures::new(
    gl, extensions, state, properties, capabilities, utils, info,
  )
  mock_clear(gl)
  { gl, properties, info, textures, }
}

///|
fn textures_mem(env : TexturesEnv, label : String) -> Unit {
  note_int(env.gl, label, env.info.memory.textures)
}

///|
fn textures_u8(n : Int32) -> @core.TypedArray {
  @core.TypedArray::uint8(n)
}

///|
fn textures_data_image(
  data : @core.TypedArray?,
  width : Int32,
  height : Int32,
  depth? : Int32,
) -> @core.TextureImage {
  DataImage(@core.DataImage::new(data?, width~, height~, depth?))
}

///|
fn textures_dom(json : Json) -> @core.TextureImage {
  DomImage(@core.JsValue::from_json(json))
}

///|
test "diff textures_2d" {
  let env = textures_env()
  let gl = env.gl
  let textures = env.textures
  // texture units
  note_int(gl, "unit", textures.allocate_texture_unit())
  note_int(gl, "unit", textures.allocate_texture_unit())
  note_int(gl, "units", textures.get_texture_units())
  textures.set_texture_units(5)
  note_int(gl, "unit", textures.allocate_texture_unit())
  textures.reset_texture_units()
  note_int(gl, "units", textures.get_texture_units())

  // data texture: upload, rebind, reupload
  let data = @core.TypedArray::uint8(Array::makei(64, i => i))
  let t1 = @core.DataTexture::new(data~, width=4, height=4)
  textures.set_texture2d(t1, 0)
  note_str(gl, "version 0", "no upload")
  t1.set_needs_update(true)
  textures.set_texture2d(t1, 0)
  textures_mem(env, "memory")
  textures.set_texture2d(t1, 0)
  textures.set_texture2d(t1, 1)
  t1.set_needs_update(true)
  textures.set_texture2d(t1, 0)

  // parameters change the cache key: new GL texture, old one deleted
  t1.min_filter = @core.LinearMipmapLinearFilter
  t1.mag_filter = @core.LinearFilter
  t1.anisotropy = 8
  t1.generate_mipmaps = true
  t1.wrap_s = @core.RepeatWrapping
  t1.wrap_t = @core.MirroredRepeatWrapping
  t1.set_needs_update(true)
  textures.set_texture2d(t1, 0)
  textures_mem(env, "memory")

  // update ranges are merged
  t1.add_update_range(8, 4)
  t1.add_update_range(0, 8)
  t1.add_update_range(32, 4)
  t1.add_update_range(13, 6)
  t1.set_needs_update(true)
  textures.set_texture2d(t1, 0)
  note_int(gl, "ranges", t1.update_ranges.length())
  t1.add_update_range(5, 3)
  t1.add_update_range(0, 4)
  t1.add_update_range(40, 8)
  t1.add_update_range(48, 8)
  t1.set_needs_update(true)
  textures.set_texture2d(t1, 0)

  // clone shares the source
  let t2 = t1.clone()
  textures.set_texture2d(t2, 2)
  textures_mem(env, "memory")
  textures.set_texture2d(t1, 0)

  // float, red, sRGB, named and normalized internal formats
  let t3 = @core.DataTexture::new(
    data=@core.TypedArray::float32(4),
    width=1,
    height=1,
    format=@core.RGBAFormat,
    type_=@core.FloatType,
  )
  t3.set_needs_update(true)
  textures.set_texture2d(t3, 3)
  let t4 = @core.DataTexture::new(
    data=textures_u8(4),
    width=2,
    height=2,
    format=@core.RedFormat,
  )
  t4.set_needs_update(true)
  textures.set_texture2d(t4, 3)
  let t5 = @core.DataTexture::new(data=textures_u8(4), width=1, height=1)
  t5.color_space = @core.SRGBColorSpace
  t5.flip_y = true
  t5.premultiply_alpha = true
  t5.unpack_alignment = 1
  t5.set_needs_update(true)
  textures.set_texture2d(t5, 3)
  let t6 = @core.DataTexture::new(
    data=@core.TypedArray::float32(4),
    width=1,
    height=1,
    format=@core.RGBAFormat,
    type_=@core.HalfFloatType,
  )
  t6.internal_format = Some("RGBA16F")
  t6.set_needs_update(true)
  textures.set_texture2d(t6, 3)
  let t7 = @core.DataTexture::new(data=textures_u8(4), width=1, height=1)
  t7.internal_format = Some("NOT_A_FORMAT")
  t7.set_needs_update(true)
  textures.set_texture2d(t7, 3)
  let t8 = @core.DataTexture::new(
    data=@core.TypedArray::uint16(4),
    width=1,
    height=1,
    format=@core.RGBAFormat,
    type_=@core.UnsignedShortType,
  )
  t8.normalized = true
  t8.set_needs_update(true)
  textures.set_texture2d(t8, 3)
  let t9 = @core.DataTexture::new(
    data=textures_u8(8),
    width=2,
    height=1,
    format=@core.RGFormat,
  )
  t9.compare_function = Some(@core.LessEqualCompare)
  t9.set_needs_update(true)
  textures.set_texture2d(t9, 3)

  // data texture mipmaps
  let t10 = @core.DataTexture::new(width=4, height=4)
  t10.mipmaps = [
    textures_data_image(Some(textures_u8(64)), 4, 4),
    textures_data_image(Some(textures_u8(16)), 2, 2),
    textures_data_image(Some(textures_u8(4)), 1, 1),
  ]
  t10.generate_mipmaps = true
  t10.min_filter = @core.LinearMipmapLinearFilter
  t10.set_needs_update(true)
  textures.set_texture2d(t10, 4)
  note_bool(gl, "generateMipmaps", t10.generate_mipmaps)

  // non-power-of-two mip chain: fractional level count, as upstream
  let t11 = @core.DataTexture::new(data=textures_u8(72), width=6, height=3)
  t11.generate_mipmaps = true
  t11.min_filter = @core.LinearMipmapNearestFilter
  t11.set_needs_update(true)
  textures.set_texture2d(t11, 4)

  // image textures
  let t12 = @core.Texture::new(image=textures_dom({ "width": 8, "height": 8 }))
  t12.set_needs_update(true)
  textures.set_texture2d(t12, 5)
  let t13 = @core.Texture::new(
    image=textures_dom({ "width": 8, "height": 8, "complete": false }),
  )
  t13.set_needs_update(true)
  textures.set_texture2d(t13, 5)
  let t14 = @core.Texture::new()
  t14.set_needs_update(true)
  textures.set_texture2d(t14, 5)
  let t15 = @core.Texture::new(image=textures_dom({ "width": 4, "height": 2 }))
  t15.mipmaps = [
    textures_dom({ "width": 4, "height": 2 }),
    textures_dom({ "width": 2, "height": 1 }),
  ]
  t15.set_needs_update(true)
  textures.set_texture2d(t15, 5)
  note_bool(gl, "generateMipmaps", t15.generate_mipmaps)

  // data not ready, onUpdate
  let t16 = @core.DataTexture::new(data=textures_u8(4), width=1, height=1)
  t16.source.data_ready = false
  let updates = Ref(0)
  t16.on_update = Some(_ => updates.val += 1)
  t16.set_needs_update(true)
  textures.set_texture2d(t16, 6)
  note_int(gl, "onUpdate", updates.val)
  t16.source.data_ready = true
  t16.set_needs_update(true)
  textures.set_texture2d(t16, 6)
  note_int(gl, "onUpdate", updates.val)

  // disposal: shared GL texture survives until the last user goes
  t1.dispose()
  textures_mem(env, "memory")
  t2.dispose()
  textures_mem(env, "memory")
  t1.dispose()
  t3.dispose()
  textures_mem(env, "memory")
  textures.set_texture2d(t2, 2)
  note_str(gl, "t2 after dispose", "bound")
  t2.set_needs_update(true)
  textures.set_texture2d(t2, 2)
  textures_mem(env, "memory")
  let log = emit_log("textures_2d", gl)
  assert_true(log.length() > 100)
  inspect(env.info.memory.textures, content="12")
}

///|
fn textures_seq(n : Int32) -> @core.TypedArray {
  @core.TypedArray::uint8(Array::makei(n, i => i))
}

///|
fn textures_mip(n : Int32, width : Int32, height : Int32) -> @core.TextureImage {
  textures_data_image(Some(textures_seq(n)), width, height)
}

///|
test "diff textures_kinds" {
  let env = textures_env()
  let gl = env.gl
  let textures = env.textures

  // DataArrayTexture, whole and per layer
  let a1 = @core.DataArrayTexture::new(
    data=textures_seq(32),
    width=2,
    height=2,
    depth=2,
  )
  a1.set_needs_update(true)
  textures.set_texture2d_array(a1, 0)
  a1.add_layer_update(1)
  a1.set_needs_update(true)
  textures.set_texture2d_array(a1, 0)
  note_int(gl, "layerUpdates", a1.layer_updates.unwrap().length())
  textures.set_texture2d_array(a1, 1)

  // Data3DTexture
  let d1 = @core.Data3DTexture::new(
    data=textures_seq(32),
    width=2,
    height=2,
    depth=2,
  )
  d1.wrap_r = @core.RepeatWrapping
  d1.set_needs_update(true)
  textures.set_texture3d(d1, 2)
  textures.set_texture3d(d1, 2)

  // CompressedTexture: supported, RGBA and unsupported formats
  let c1 = @core.CompressedTexture::new(
    mipmaps=[textures_mip(8, 4, 4), textures_mip(8, 2, 2)],
    width=4,
    height=4,
    format=@core.RGBA_S3TC_DXT1_Format,
  )
  c1.set_needs_update(true)
  textures.set_texture2d(c1, 3)
  let c2 = @core.CompressedTexture::new(
    mipmaps=[textures_mip(16, 2, 2)],
    width=2,
    height=2,
    format=@core.RGBAFormat,
  )
  c2.set_needs_update(true)
  textures.set_texture2d(c2, 3)
  let c3 = @core.CompressedTexture::new(
    mipmaps=[textures_mip(8, 4, 4)],
    width=4,
    height=4,
    format=@core.RGB_PVRTC_4BPPV1_Format,
  )
  c3.set_needs_update(true)
  textures.set_texture2d(c3, 3)
  let c4 = @core.CompressedTexture::new(
    mipmaps=[textures_mip(16, 4, 4)],
    width=4,
    height=4,
    format=@core.RGBA_ASTC_4x4_Format,
  )
  c4.color_space = @core.SRGBColorSpace
  c4.set_needs_update(true)
  textures.set_texture2d(c4, 3)

  // CompressedArrayTexture, whole and per layer
  let ca = @core.CompressedArrayTexture::new(
    mipmaps=[textures_mip(24, 4, 4)],
    width=4,
    height=4,
    depth=3,
    format=@core.RGBA_S3TC_DXT1_Format,
  )
  ca.set_needs_update(true)
  textures.set_texture2d_array(ca, 4)
  ca.add_layer_update(2)
  ca.add_layer_update(0)
  ca.set_needs_update(true)
  textures.set_texture2d_array(ca, 4)
  note_int(gl, "layerUpdates", ca.layer_updates.unwrap().length())
  let cb = @core.CompressedArrayTexture::new(
    mipmaps=[textures_mip(32, 2, 2)],
    width=2,
    height=2,
    depth=2,
    format=@core.RGBAFormat,
  )
  cb.set_needs_update(true)
  textures.set_texture2d_array(cb, 4)

  // DepthTexture formats and compare functions
  let z1 = @core.DepthTexture::new(width=4, height=4)
  z1.set_needs_update(true)
  textures.set_texture2d(z1, 5)
  let z2 = @core.DepthTexture::new(
    width=4,
    height=4,
    type_=@core.UnsignedInt248Type,
  )
  z2.format = @core.DepthStencilFormat
  z2.compare_function = Some(@core.LessCompare)
  z2.set_needs_update(true)
  textures.set_texture2d(z2, 5)
  let z3 = @core.DepthTexture::new(width=4, height=4, type_=@core.FloatType)
  z3.set_needs_update(true)
  textures.set_texture2d(z3, 5)
  let z4 = @core.DepthTexture::new(
    width=4,
    height=4,
    type_=@core.UnsignedShortType,
  )
  z4.format = @core.DepthStencilFormat
  z4.set_needs_update(true)
  textures.set_texture2d(z4, 5)
  let z5 = @core.DepthTexture::new(
    width=4,
    height=4,
    type_=@core.UnsignedShortType,
  )
  z5.set_needs_update(true)
  textures.set_texture2d(z5, 5)

  // FramebufferTexture: base level, then a mip chain from minFilter
  let f1 = @core.FramebufferTexture::new(width=8, height=8)
  textures.set_texture2d(f1, 6)
  let f2 = @core.FramebufferTexture::new(width=8, height=8)
  f2.min_filter = @core.LinearMipmapLinearFilter
  textures.set_texture2d(f2, 6)

  // ExternalTexture
  let handle = gl.create_texture()
  let e1 = @core.ExternalTexture::new(external_source=@core.JsValue::of(handle))
  textures.set_texture2d(e1, 7)
  textures.set_texture2d_array(e1, 8)
  let e2 = @core.ExternalTexture::new()
  textures.set_texture2d(e2, 9)

  // VideoTexture: no texStorage, linear transfer, once per frame
  let video = @core.JsValue::from_json({
    "width": 4,
    "height": 4,
    "readyState": 4,
    "HAVE_CURRENT_DATA": 2,
  })
  let v1 = @core.VideoTexture::new(video)
  v1.color_space = @core.SRGBColorSpace
  textures.set_texture2d(v1, 10)
  note_int(gl, "video version", v1.version)
  textures.set_texture2d(v1, 10)
  note_int(gl, "video version", v1.version)
  env.info.render.frame = 1
  textures.set_texture2d(v1, 10)
  note_int(gl, "video version", v1.version)
  v1.dispose()
  textures_mem(env, "memory")
  let log = emit_log("textures_kinds", gl)
  assert_true(log.length() > 100)
  inspect(a1.layer_updates.unwrap().length(), content="0")
}

///|
fn textures_faces(
  f : (Int32) -> @core.TextureImage,
) -> Array[@core.TextureImage] {
  Array::makei(6, f)
}

///|
test "diff textures_cube" {
  let env = textures_env()
  let gl = env.gl
  let textures = env.textures

  // images, generated mipmaps
  let k1 = @core.CubeTexture::new(
    images=textures_faces(_ => textures_dom({ "width": 4, "height": 4 })),
  )
  k1.set_needs_update(true)
  textures.set_texture_cube(k1, 0)
  textures.set_texture_cube(k1, 0)
  // fewer than six images: nothing happens
  let k2 = @core.CubeTexture::new(images=[
    textures_dom({ "width": 4, "height": 4 }),
  ])
  k2.set_needs_update(true)
  textures.set_texture_cube(k2, 1)
  note_str(gl, "k2", "skipped")

  // images with user mipmaps (cube textures as mip levels)
  let k3 = @core.CubeTexture::new(
    images=textures_faces(_ => textures_dom({ "width": 4, "height": 4 })),
  )
  k3.mipmaps = [
    TextureImage(
      @core.CubeTexture::new(
        images=textures_faces(_ => textures_dom({ "width": 2, "height": 2 })),
      ),
    ),
    TextureImage(
      @core.CubeTexture::new(
        images=textures_faces(_ => textures_dom({ "width": 1, "height": 1 })),
      ),
    ),
  ]
  k3.generate_mipmaps = false
  k3.min_filter = @core.LinearMipmapLinearFilter
  k3.color_space = @core.SRGBColorSpace
  k3.set_needs_update(true)
  textures.set_texture_cube(k3, 2)

  // data texture faces with mipmaps
  let k4 = @core.CubeTexture::new(
    images=textures_faces(_ => {
      TextureImage(
        @core.DataTexture::new(data=textures_seq(16), width=2, height=2),
      )
    }),
  )
  k4.mipmaps = [
    TextureImage(
      @core.CubeTexture::new(
        images=textures_faces(_ => {
          TextureImage(
            @core.DataTexture::new(data=textures_seq(4), width=1, height=1),
          )
        }),
      ),
    ),
  ]
  k4.generate_mipmaps = false
  k4.min_filter = @core.LinearFilter
  k4.set_needs_update(true)
  textures.set_texture_cube(k4, 3)
  k4.set_needs_update(true)
  textures.set_texture_cube(k4, 3)

  // compressed cube
  let k5 = @core.CompressedCubeTexture::new(
    textures_faces(_ => {
      DataImage(
        @core.DataImage::new(width=4, height=4, mipmaps=[
          @core.DataImage::new(data=textures_seq(8), width=4, height=4),
          @core.DataImage::new(data=textures_seq(8), width=2, height=2),
        ]),
      )
    }),
    format=@core.RGBA_S3TC_DXT1_Format,
  )
  k5.set_needs_update(true)
  textures.set_texture_cube(k5, 4)
  let k6 = @core.CompressedCubeTexture::new(
    textures_faces(_ => {
      DataImage(
        @core.DataImage::new(width=2, height=2, mipmaps=[
          @core.DataImage::new(data=textures_seq(16), width=2, height=2),
        ]),
      )
    }),
    format=@core.RGBAFormat,
  )
  k6.set_needs_update(true)
  textures.set_texture_cube(k6, 4)

  // cube depth texture
  let k7 = @core.CubeDepthTexture::new(size=8)
  k7.set_needs_update(true)
  textures.set_texture_cube(k7, 5)
  let k8 = @core.CubeDepthTexture::new(size=8, type_=@core.FloatType)
  k8.format = @core.DepthStencilFormat
  k8.set_needs_update(true)
  textures.set_texture_cube(k8, 5)
  textures_mem(env, "memory")
  k1.dispose()
  k4.dispose()
  textures_mem(env, "memory")
  let log = emit_log("textures_cube", gl)
  assert_true(log.length() > 50)
  inspect(env.info.memory.textures, content="5")
}

///|
test "diff textures_render_targets" {
  let env = textures_env()
  let gl = env.gl
  let textures = env.textures
  let properties = env.properties
  let step = (label : String) => note_str(gl, "step", label)
  step("plain")
  let r1 = @webgl.WebGLRenderTarget::new(width=4, height=4)
  textures.setup_render_target(r1)
  note_bool(gl, "useMultisampledRTT", textures.use_multisampled_rtt(r1))
  textures.setup_depth_renderbuffer(r1)
  textures.rebind_textures(
    r1,
    properties.get_texture(r1.texture()).__webgl_texture,
    None,
  )
  textures_mem(env, "memory")
  step("stencil + depth texture")
  let r2 = @webgl.WebGLRenderTarget::new(
    width=4,
    height=4,
    stencil_buffer=true,
    depth_texture=@core.DepthTexture::new(width=4, height=4),
  )
  textures.setup_render_target(r2)
  textures.rebind_textures(
    r2,
    None,
    properties.get_texture(r2.depth_texture().unwrap()).__webgl_texture,
  )
  step("swap depth texture")
  let z2 = @core.DepthTexture::new(
    width=4,
    height=4,
    type_=@core.UnsignedInt248Type,
  )
  z2.format = @core.DepthStencilFormat
  r2.set_depth_texture(Some(z2))
  textures.setup_depth_renderbuffer(r2)
  step("resize depth texture")
  r2.width = 8
  r2.height = 8
  textures.setup_depth_renderbuffer(r2)
  mock_note(
    gl,
    "depth size",
    @core.JsValue::of(
      FixedArray::from_array([z2.width().to_int(), z2.height().to_int()]),
    ),
  )
  step("dispose bound depth texture")
  z2.dispose()
  textures.setup_depth_renderbuffer(r2)
  step("auto allocated depth buffer")
  let r2b = @webgl.WebGLRenderTarget::new(
    width=4,
    height=4,
    depth_texture=@core.DepthTexture::new(width=4, height=4),
  )
  properties.get_render_target(r2b).__auto_allocate_depth_buffer = true
  textures.setup_render_target(r2b)
  step("generated mipmaps")
  let r3 = @webgl.WebGLRenderTarget::new(
    width=8,
    height=8,
    generate_mipmaps=true,
    min_filter=@core.LinearMipmapLinearFilter,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  textures.setup_render_target(r3)
  textures.update_render_target_mipmap(r3)
  r3.texture().mipmaps_auto_update = false
  textures.update_render_target_mipmap(r3)
  step("mip level framebuffers")
  let r4 = @webgl.WebGLRenderTarget::new(width=8, height=8, stencil_buffer=true)
  r4.texture().mipmaps = [NoImage, NoImage, NoImage]
  textures.setup_render_target(r4)
  step("cube")
  let r5 = @webgl.WebGLCubeRenderTarget::new(size=4)
  textures.setup_render_target(r5)
  textures.update_render_target_mipmap(r5)
  step("cube with mip levels")
  let r5b = @webgl.WebGLCubeRenderTarget::new(size=4, depth_buffer=false)
  r5b.texture().mipmaps = [NoImage, NoImage]
  textures.setup_render_target(r5b)
  step("cube with generated mipmaps")
  let r5c = @webgl.WebGLCubeRenderTarget::new(
    size=4,
    depth_buffer=false,
    generate_mipmaps=true,
    min_filter=@core.LinearMipmapLinearFilter,
  )
  textures.setup_render_target(r5c)
  textures.update_render_target_mipmap(r5c)
  step("cube with depth texture")
  let r6 = @webgl.WebGLCubeRenderTarget::new(
    size=4,
    depth_texture=@core.CubeDepthTexture::new(size=4),
  )
  textures.setup_render_target(r6)
  step("3D")
  let r7 = @webgl.WebGL3DRenderTarget::new(width=2, height=2, depth=3)
  textures.setup_render_target(r7)
  step("array")
  let r8 = @webgl.WebGLArrayRenderTarget::new(
    width=2,
    height=2,
    depth=3,
    depth_buffer=false,
    generate_mipmaps=true,
  )
  textures.setup_render_target(r8)
  textures.update_render_target_mipmap(r8)
  step("MRT")
  let r9 = @webgl.WebGLRenderTarget::new(
    width=4,
    height=4,
    count=2,
    depth_buffer=false,
  )
  r9.textures[1].type_ = @core.FloatType
  r9.textures[1].format = @core.RedFormat
  textures.setup_render_target(r9)
  textures_mem(env, "memory")
  step("MRT array")
  let r9b = @webgl.WebGLArrayRenderTarget::new(
    width=2,
    height=2,
    depth=2,
    count=2,
    depth_buffer=false,
  )
  r9b.textures[1].generate_mipmaps = true
  textures.setup_render_target(r9b)
  step("multisample")
  let r10 = @webgl.WebGLRenderTarget::new(width=4, height=4, samples=4)
  textures.setup_render_target(r10)
  textures.update_multisample_render_target(r10)
  r10.resolve_depth_buffer = false
  textures.update_multisample_render_target(r10)
  step("multisample MRT with stencil")
  let r11 = @webgl.WebGLRenderTarget::new(
    width=4,
    height=4,
    samples=8,
    count=2,
    stencil_buffer=true,
  )
  textures.setup_render_target(r11)
  textures.update_multisample_render_target(r11)
  r11.resolve_stencil_buffer = false
  textures.update_multisample_render_target(r11)
  step("multisample mip levels")
  let r12 = @webgl.WebGLRenderTarget::new(
    width=4,
    height=4,
    samples=2,
    depth_buffer=false,
  )
  r12.texture().mipmaps = [NoImage, NoImage]
  textures.setup_render_target(r12)
  textures.update_multisample_render_target(r12)
  textures.update_multisample_render_target(r1)
  step("external textures")
  let r13 = @webgl.WebGLRenderTarget::new(width=4, height=4, depth_buffer=false)
  properties.get_render_target(r13).__has_external_textures = true
  textures.setup_render_target(r13)
  step("dispose")
  textures_mem(env, "memory")
  r1.dispose()
  r2.dispose()
  r5.dispose()
  r5b.dispose()
  r6.dispose()
  r9.dispose()
  r10.dispose()
  r11.dispose()
  r12.dispose()
  textures_mem(env, "memory")
  r1.dispose()
  step("reuse after dispose")
  textures.setup_render_target(r1)
  textures_mem(env, "memory")
  let log = emit_log("textures_render_targets", gl)
  assert_true(log.length() > 200)
}

///|
let textures_default_extensions : Array[String] = [
  "EXT_color_buffer_float", "EXT_color_buffer_half_float", "OES_texture_float_linear",
  "EXT_texture_filter_anisotropic", "WEBGL_multi_draw", "KHR_parallel_shader_compile",
  "WEBGL_lose_context", "EXT_clip_control", "WEBGL_compressed_texture_s3tc", "WEBGL_compressed_texture_astc",
  "WEBGL_compressed_texture_etc",
]

///|
fn textures_extensions_option(names : Array[String]) -> String {
  let list : Json = Json::array(names.map(Json::string))
  ({ "extensions": list } : Json).stringify()
}

///|
extern "js" fn textures_mock_log_push(
  gl : @webgl.WebGL2RenderingContext,
  entries : FixedArray[String],
) -> Unit = "(gl, e) => { gl.__log.push(...e); }"

///|
test "diff textures_formats" {
  let formats = [
    @core.RedFormat,
    @core.RedIntegerFormat,
    @core.RGFormat,
    @core.RGIntegerFormat,
    @core.RGBAIntegerFormat,
    @core.RGBFormat,
    @core.RGBAFormat,
    @core.AlphaFormat,
  ]
  let types = [
    @core.UnsignedByteType,
    @core.ByteType,
    @core.ShortType,
    @core.UnsignedShortType,
    @core.IntType,
    @core.UnsignedIntType,
    @core.FloatType,
    @core.HalfFloatType,
    @core.UnsignedShort4444Type,
    @core.UnsignedShort5551Type,
    @core.UnsignedInt5999Type,
    @core.UnsignedInt101111Type,
  ]
  let logs : Array[String] = []
  for
    case in [
      ("default", textures_default_extensions),
      ("norm16", [..textures_default_extensions, "EXT_texture_norm16"]),
    ] {
    let (label, list) = case
    let env = textures_env(options=textures_extensions_option(list))
    let gl = env.gl
    note_str(gl, "extensions", label)
    for format in formats {
      for type_ in types {
        for normalized in [false, true] {
          let t = @core.DataTexture::new(
            data=textures_u8(4),
            width=1,
            height=1,
            format~,
            type_~,
          )
          t.normalized = normalized
          t.set_needs_update(true)
          env.textures.set_texture2d(t, 0)
        }
      }
    }
    let rt = @webgl.WebGLRenderTarget::new(
      width=2,
      height=2,
      depth_buffer=false,
      format=@core.RGFormat,
      type_=@core.ShortType,
    )
    rt.texture().normalized = true
    env.textures.setup_render_target(rt)
    logs.append(mock_log(gl))
  }
  // no anisotropic filtering and no float linear filtering
  {
    let env = textures_env(
      options=textures_extensions_option(["EXT_color_buffer_float"]),
    )
    let t = @core.DataTexture::new(
      data=@core.TypedArray::float32(4),
      width=1,
      height=1,
      format=@core.RGBAFormat,
      type_=@core.FloatType,
    )
    t.anisotropy = 4
    t.mag_filter = @core.LinearFilter
    t.min_filter = @core.LinearMipmapLinearFilter
    t.set_needs_update(true)
    env.textures.set_texture2d(t, 0)
    logs.append(mock_log(env.gl))
  }
  let env = textures_env(
    options=textures_extensions_option(["EXT_texture_filter_anisotropic"]),
  )
  let gl = env.gl
  let t = @core.DataTexture::new(
    data=@core.TypedArray::float32(4),
    width=1,
    height=1,
    format=@core.RGBAFormat,
    type_=@core.FloatType,
  )
  t.anisotropy = 4
  t.mag_filter = @core.LinearFilter
  t.min_filter = @core.LinearMipmapLinearFilter
  t.set_needs_update(true)
  env.textures.set_texture2d(t, 0)
  let u = @core.DataTexture::new(data=textures_u8(4), width=1, height=1)
  u.anisotropy = 32
  u.mag_filter = @core.LinearFilter
  u.min_filter = @core.NearestMipmapLinearFilter
  u.set_needs_update(true)
  env.textures.set_texture2d(u, 1)
  note_opt_int(
    gl,
    "currentAnisotropy",
    env.properties.get_texture(u).__current_anisotropy,
  )
  u.anisotropy = 1
  u.set_needs_update(true)
  env.textures.set_texture2d(u, 1)
  u.min_filter = @core.LinearMipmapNearestFilter
  u.anisotropy = 2
  u.set_needs_update(true)
  env.textures.set_texture2d(u, 1)
  u.min_filter = @core.LinearMipmapLinearFilter
  u.mag_filter = @core.NearestFilter
  u.set_needs_update(true)
  env.textures.set_texture2d(u, 1)
  logs.append(mock_log(gl))
  // run_diff compares one log per scenario: emit everything through the last context
  mock_clear(gl)
  textures_mock_log_push(gl, FixedArray::from_array(logs))
  let log = emit_log("textures_formats", gl)
  assert_true(log.length() > 1000)
}

///|
test "diff textures_msrtt" {
  let env = textures_env(
    options=textures_extensions_option(
      [..textures_default_extensions, "WEBGL_multisampled_render_to_texture"],
    ),
  )
  let gl = env.gl
  let textures = env.textures
  let r1 = @webgl.WebGLRenderTarget::new(
    width=4,
    height=4,
    samples=4,
    stencil_buffer=true,
  )
  textures.setup_render_target(r1)
  note_bool(gl, "useMultisampledRTT", textures.use_multisampled_rtt(r1))
  textures.update_multisample_render_target(r1)
  r1.store_multisampled_depth_buffer = false
  textures.update_multisample_render_target(r1)
  let r2 = @webgl.WebGLRenderTarget::new(
    width=4,
    height=4,
    samples=2,
    depth_texture=@core.DepthTexture::new(width=4, height=4),
  )
  textures.setup_render_target(r2)
  let z = @core.DepthTexture::new(width=4, height=4)
  z.format = @core.DepthStencilFormat
  let r3 = @webgl.WebGLRenderTarget::new(
    width=4,
    height=4,
    samples=2,
    depth_texture=z,
  )
  textures.setup_render_target(r3)
  let r4 = @webgl.WebGLRenderTarget::new(width=4, height=4, samples=4)
  env.properties.get_render_target(r4).__use_render_to_texture = Some(false)
  note_bool(gl, "useMultisampledRTT", textures.use_multisampled_rtt(r4))
  textures.setup_render_target(r4)
  textures.update_multisample_render_target(r4)
  let r5 = @webgl.WebGLRenderTarget::new(
    width=4,
    height=4,
    samples=4,
    depth_buffer=false,
  )
  textures.setup_render_target(r5)
  r1.dispose()
  r2.dispose()
  r4.dispose()
  textures_mem(env, "memory")
  let log = emit_log("textures_msrtt", gl)
  assert_true(log.length() > 50)
}

///|
test "diff textures_dispose" {
  let env = textures_env()
  let gl = env.gl
  let textures = env.textures
  let t1 = @core.DataTexture::new(data=textures_u8(4), width=1, height=1)
  t1.set_needs_update(true)
  textures.set_texture2d(t1, 0)
  let r1 = @webgl.WebGLRenderTarget::new(
    width=2,
    height=2,
    depth_texture=@core.DepthTexture::new(width=2, height=2),
  )
  textures.setup_render_target(r1)
  let t2 = t1.clone()
  textures.set_texture2d(t2, 1)
  let t3 = @core.DataTexture::new(data=textures_u8(4), width=1, height=1)
  t3.set_needs_update(true)
  textures.set_texture2d(t3, 2)
  t3.dispose()
  // a depth texture another target owns
  let shared = @core.DepthTexture::new(width=2, height=2)
  let r2 = @webgl.WebGLRenderTarget::new(
    width=2,
    height=2,
    depth_texture=shared,
  )
  let r3 = @webgl.WebGLRenderTarget::new(
    width=2,
    height=2,
    depth_texture=shared,
  )
  textures.setup_render_target(r2)
  textures.setup_render_target(r3)
  let r4 = @webgl.WebGLRenderTarget::new(width=2, height=2, count=2, samples=4)
  textures.setup_render_target(r4)
  // set up twice: tracked twice, the older entry is removed while dispose runs
  let r5 = @webgl.WebGLRenderTarget::new(width=2, height=2, depth_buffer=false)
  textures.setup_render_target(r5)
  textures.setup_render_target(r5)
  textures_mem(env, "memory")
  note_str(gl, "step", "dispose")
  textures.dispose()
  textures_mem(env, "memory")
  note_str(gl, "step", "dispose again")
  textures.dispose()
  t1.dispose()
  r1.dispose()
  note_str(gl, "step", "reuse")
  t1.set_needs_update(true)
  textures.set_texture2d(t1, 0)
  textures.setup_render_target(r1)
  textures_mem(env, "memory")
  t1.dispose()
  r1.dispose()
  textures_mem(env, "memory")
  let log = emit_log("textures_dispose", gl)
  assert_true(log.length() > 50)
  // r5's second setup counted its texture twice, as upstream
  inspect(env.info.memory.textures, content="1")
}

///|
/// Gives the mock canvas the HTML-in-Canvas methods, recording into the log.
extern "js" fn textures_html_canvas(gl : @webgl.WebGL2RenderingContext) -> Unit =
  #|(gl) => {
  #|  const attrs = {};
  #|  const canvas = gl.canvas;
  #|  canvas.hasAttribute = (n) => { gl.__log.push('canvas.hasAttribute(' + n + ')'); return n in attrs; };
  #|  canvas.setAttribute = (n, v) => { gl.__log.push('canvas.setAttribute(' + n + ', ' + v + ')'); attrs[n] = v; };
  #|  canvas.appendChild = (e) => { gl.__log.push('canvas.appendChild(' + e.id + ')'); e.parentNode = canvas; };
  #|  canvas.requestPaint = () => { gl.__log.push('canvas.requestPaint()'); };
  #|}

///|
/// `canvas.onpaint( { changedElements } )`.
extern "js" fn textures_html_paint(
  gl : @webgl.WebGL2RenderingContext,
  changed : FixedArray[@core.JsValue],
) -> Unit = "(gl, c) => gl.canvas.onpaint({ changedElements: Array.from(c) })"

///|
extern "js" fn textures_html_three_arg(
  gl : @webgl.WebGL2RenderingContext,
) -> Unit =
  #|(gl) => { gl.texElementImage2D = function (a, b, c) { gl.__log.push('texElementImage2D(' + a + ', ' + b + ', ' + c.id + ')'); }; }

///|
extern "js" fn textures_html_remove(gl : @webgl.WebGL2RenderingContext) -> Unit = "(gl) => { delete gl.texElementImage2D; }"

///|
extern "js" fn textures_html_onpaint(
  gl : @webgl.WebGL2RenderingContext,
) -> String = "(gl) => gl.canvas.onpaint === null ? 'null' : typeof gl.canvas.onpaint"

///|
extern "js" fn textures_html_element(id : Int32, size : Int32) -> @core.JsValue = "(id, s) => ({ id, width: s, height: s, parentNode: null })"

///|
test "diff textures_html" {
  let gl = mock_gl()
  textures_html_canvas(gl)
  let extensions = @webgl.WebGLExtensions::new(gl)
  let utils = @webgl.WebGLUtils::new(gl, extensions)
  let capabilities = @webgl.WebGLCapabilities::new(
    gl,
    extensions,
    {
      precision: None,
      logarithmic_depth_buffer: false,
      reversed_depth_buffer: false,
    },
    utils,
  )
  let state = @webgl.WebGLState::new(gl, extensions)
  let info = @webgl.WebGLInfo::new(gl)
  let textures = @webgl.WebGLTextures::new(
    gl,
    extensions,
    state,
    @webgl.WebGLProperties::new(),
    capabilities,
    utils,
    info,
  )
  mock_clear(gl)
  let e1 = textures_html_element(1, 4)
  let e2 = textures_html_element(2, 8)
  let h1 = @core.HTMLTexture::new(element=e1)
  let h2 = @core.HTMLTexture::new(element=e2)
  let versions = () => {
    mock_note(
      gl,
      "version",
      @core.JsValue::of(FixedArray::from_array([h1.version, h2.version])),
    )
  }
  versions()
  textures.set_texture2d(h1, 0)
  textures.set_texture2d(h2, 1)
  textures.set_texture2d(h1, 0)
  versions()
  textures_html_paint(gl, [e2])
  versions()
  textures.set_texture2d(h2, 1)
  textures.set_texture2d(h1, 0)
  // the Chrome 150+ form
  textures_html_three_arg(gl)
  textures_html_paint(gl, [e1, e2])
  versions()
  textures.set_texture2d(h1, 0)
  textures.set_texture2d(h2, 1)
  h2.dispose()
  note_str(gl, "onpaint", textures_html_onpaint(gl))
  // no HTML-in-Canvas support
  textures_html_remove(gl)
  h1.set_needs_update(true)
  textures.set_texture2d(h1, 0)
  note_int(gl, "memory", info.memory.textures)
  let log = emit_log("textures_html", gl)
  assert_true(log.length() > 20)
}

///|
/// Installs fake DOM classes recording into the log; the same source as
/// harness/scenarios/textures_dom.mjs.
extern "js" fn textures_install_dom(
  gl : @webgl.WebGL2RenderingContext,
) -> @core.JsValue =
  #|(gl) => {
  #|  let n = 0;
  #|  const id = (o) => (o && o.__mock ? o.__mock + '#' + o.__id : 'object');
  #|  class HTMLCanvasElement { constructor(w, h) { this.__mock = 'Canvas'; this.__id = ++n; this.width = w; this.height = h; }
  #|    getContext(t) { const c = this; gl.__log.push('getContext(' + t + ') on ' + id(c)); return { drawImage(i, x, y, w, h) { gl.__log.push('drawImage(' + id(i) + ', ' + [x, y, w, h].join(', ') + ') on ' + id(c) + ' ' + c.width + 'x' + c.height); } }; } }
  #|  class HTMLImageElement { constructor(nw, nh, w, h) { this.__mock = 'Image'; this.__id = ++n; this.naturalWidth = nw; this.naturalHeight = nh; this.width = w; this.height = h; } }
  #|  class ImageBitmap { constructor(w, h) { this.__mock = 'Bitmap'; this.__id = ++n; this.width = w; this.height = h; } }
  #|  class VideoFrame { constructor(w, h) { this.__mock = 'Frame'; this.__id = ++n; this.displayWidth = w; this.displayHeight = h; } }
  #|  const saved = { document: globalThis.document };
  #|  globalThis.HTMLCanvasElement = HTMLCanvasElement;
  #|  globalThis.HTMLImageElement = HTMLImageElement;
  #|  globalThis.ImageBitmap = ImageBitmap;
  #|  globalThis.VideoFrame = VideoFrame;
  #|  globalThis.document = { createElementNS(ns, name) { gl.__log.push('createElementNS(' + name + ')'); return new HTMLCanvasElement(300, 150); } };
  #|  return {
  #|    canvas: (w, h) => new HTMLCanvasElement(w, h),
  #|    image: (nw, nh, w, h) => new HTMLImageElement(nw, nh, w, h),
  #|    bitmap: (w, h) => new ImageBitmap(w, h),
  #|    frame: (w, h) => new VideoFrame(w, h),
  #|    uninstall: () => { delete globalThis.HTMLCanvasElement; delete globalThis.HTMLImageElement; delete globalThis.ImageBitmap; delete globalThis.VideoFrame; if (saved.document === undefined) delete globalThis.document; else globalThis.document = saved.document; },
  #|  };
  #|}

///|
extern "js" fn textures_dom_make(
  dom : @core.JsValue,
  kind : String,
  args : FixedArray[Int32],
) -> @core.JsValue = "(d, k, a) => d[k](...a)"

///|
extern "js" fn textures_dom_uninstall(dom : @core.JsValue) -> Unit = "(d) => d.uninstall()"

///|
test "diff textures_dom" {
  let env = textures_env(
    options="{\"parameters\":{\"MAX_TEXTURE_SIZE\":4,\"MAX_CUBE_MAP_TEXTURE_SIZE\":2}}",
  )
  let gl = env.gl
  let textures = env.textures
  // the scenario installs the fakes before building the modules; nothing above reads them
  let dom = textures_install_dom(gl)
  let make = (kind : String, args : Array[Int32]) => {
    @core.TextureImage::DomImage(
      textures_dom_make(dom, kind, FixedArray::from_array(args)),
    )
  }
  let upload = (image : @core.TextureImage, slot : Int32) => {
    let t = @core.Texture::new(image~)
    t.set_needs_update(true)
    textures.set_texture2d(t, slot)
    t
  }
  note_str(gl, "step", "canvas too big")
  ignore(upload(make("canvas", [8, 4]), 0))
  note_str(gl, "step", "fractional scale")
  ignore(upload(make("canvas", [10, 3]), 0))
  note_str(gl, "step", "image: natural size, shared canvas")
  ignore(upload(make("image", [16, 16, 1, 1]), 1))
  note_str(gl, "step", "image without natural size")
  ignore(upload(make("image", [0, 0, 2, 2]), 2))
  note_str(gl, "step", "image bitmap")
  ignore(upload(make("bitmap", [2, 2]), 3))
  note_str(gl, "step", "video frame")
  ignore(upload(make("frame", [8, 2]), 4))
  note_str(gl, "step", "small canvas")
  let t = upload(make("canvas", [2, 2]), 5)
  t.mipmaps = [make("image", [4, 4, 4, 4]), make("canvas", [2, 2])]
  t.set_needs_update(true)
  textures.set_texture2d(t, 5)
  note_str(gl, "step", "plain object with data")
  ignore(
    upload(textures_dom({ "width": 8, "height": 8, "data": Json::null() }), 6),
  )
  note_str(gl, "step", "data texture too big")
  let d = @core.DataTexture::new(data=textures_u8(4), width=8, height=8)
  d.set_needs_update(true)
  textures.set_texture2d(d, 7)
  note_str(gl, "step", "cube faces get their own canvases")
  let k = @core.CubeTexture::new(
    images=textures_faces(_ => make("canvas", [4, 4])),
  )
  k.set_needs_update(true)
  textures.set_texture_cube(k, 8)
  textures_dom_uninstall(dom)
  let log = emit_log("textures_dom", gl)
  assert_true(log.length() > 50)
}

///|
/// Constructs `WebGLTextures` while `navigator.userAgent` names the Oculus browser.
extern "js" fn textures_with_oculus_agent(f : () -> Unit) -> Unit =
  #|(f) => {
  #|  const saved = Object.getOwnPropertyDescriptor(globalThis, 'navigator');
  #|  Object.defineProperty(globalThis, 'navigator', { value: { userAgent: 'Mozilla/5.0 OculusBrowser/30.0' }, configurable: true, writable: true });
  #|  try { f(); } finally { if (saved) Object.defineProperty(globalThis, 'navigator', saved); else delete globalThis.navigator; }
  #|}

///|
test "diff textures_oculus" {
  let logs : Array[String] = []
  let mut last = mock_gl()
  for
    list in [
      textures_default_extensions,
      [..textures_default_extensions, "WEBGL_multisampled_render_to_texture"],
    ] {
    let gl = mock_gl(options=textures_extensions_option(list))
    let extensions = @webgl.WebGLExtensions::new(gl)
    let utils = @webgl.WebGLUtils::new(gl, extensions)
    let capabilities = @webgl.WebGLCapabilities::new(
      gl,
      extensions,
      {
        precision: None,
        logarithmic_depth_buffer: false,
        reversed_depth_buffer: false,
      },
      utils,
    )
    let state = @webgl.WebGLState::new(gl, extensions)
    let properties = @webgl.WebGLProperties::new()
    let info = @webgl.WebGLInfo::new(gl)
    let textures : Ref[@webgl.WebGLTextures?] = Ref(None)
    textures_with_oculus_agent(() => {
      textures.val = Some(
        @webgl.WebGLTextures::new(
          gl, extensions, state, properties, capabilities, utils, info,
        ),
      )
    })
    let textures = textures.val.unwrap()
    assert_true(textures.supports_invalidate_framebuffer)
    mock_clear(gl)
    let r1 = @webgl.WebGLRenderTarget::new(
      width=4,
      height=4,
      samples=4,
      stencil_buffer=true,
    )
    textures.setup_render_target(r1)
    textures.update_multisample_render_target(r1)
    r1.store_multisampled_depth_buffer = false
    textures.update_multisample_render_target(r1)
    let r2 = @webgl.WebGLRenderTarget::new(
      width=4,
      height=4,
      samples=4,
      count=2,
      depth_buffer=false,
    )
    textures.setup_render_target(r2)
    textures.update_multisample_render_target(r2)
    logs.append(mock_log(gl))
    last = gl
  }
  mock_clear(last)
  textures_mock_log_push(last, FixedArray::from_array(logs))
  let log = emit_log("textures_oculus", last)
  assert_true(log.length() > 50)
}
