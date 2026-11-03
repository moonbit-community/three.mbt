// examples/jsm/tsl/math/Bayer.js

///|
/// `bayer16Texture`: created on the first call of `bayer16`.
let _bayer_bayer16_texture : Ref[@core.Texture?] = Ref(None)

///|
let _bayer_bayer16_base64 : String = "data:image/png;base64,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"

///|
priv struct BayerModule {
  bayer16 : @nodes.Node
  bayer_dither : @nodes.Node
}

///|
let math_bayer_module : AddonModule[BayerModule] = AddonModule::new(fn() {
  let bayer16 = @nodes.fn_(fn(inputs, _) {
    let uv = addon_arg(inputs, 0)
    if _bayer_bayer16_texture.val is None {
      let texture = @core.Texture::new()
      _bayer_bayer16_texture.val = Some(texture)
      let loader = @loaders.ImageBitmapLoader::new()
      loader.set_options({
        "imageOrientation": Json::string("flipY"),
        "premultiplyAlpha": Json::string("none"),
      })
      |> ignore
      loader.load(_bayer_bayer16_base64, on_load=fn(image_bitmap) {
        texture.set_image(DomImage(image_bitmap))
        texture.flip_y = false
        texture.set_needs_update(true)
      })
    }
    Some(
      @nodes.texture_load(
        _bayer_bayer16_texture.val.unwrap(),
        uv_node=@nodes.ivec2(uv).mod(@nodes.int(16)),
      ),
    )
  })
  let bayer_dither = @nodes.fn_(fn(inputs, _) {
    let color = addon_arg(inputs, 0)
    let steps = inputs.get(1).or_else(fn() { @nodes.float(32.0) })
    let screen_pos = @nodes.screen_uv.mul(@nodes.screen_size)
    let x = @nodes.mod(@nodes.floor(screen_pos.x()), @nodes.float(4.0))
    let y = @nodes.mod(@nodes.floor(screen_pos.y()), @nodes.float(4.0))
    // Simplified Bayer matrix approximation
    let bayer = @nodes.mod(
        @nodes.floor(x.add(1.0)).mul(@nodes.floor(y.add(1.0))).mul(17.0),
        16.0,
      )
      .div(16.0)
      .sub(0.5)
    // Apply dither offset before quantization
    let dither_offset = bayer.div(steps)
    Some(
      @nodes.vec3_of([
        color.r().add(dither_offset),
        color.g().add(dither_offset),
        color.b().add(dither_offset),
      ]),
    )
  })
  { bayer16, bayer_dither, }
})

///|
/// Evaluates Bayer.js, as `import` does.
pub fn load_math_bayer() -> Unit {
  math_bayer_module.get() |> ignore
}

///|
/// `bayer16( uv )`: a texel of the 16x16 Bayer matrix texture (loaded on first use).
pub fn bayer16() -> @nodes.Node {
  math_bayer_module.get().bayer16
}

///|
/// `bayerDither( color, steps = 32 )`: ordered dithering offset applied to a color.
pub fn bayer_dither() -> @nodes.Node {
  math_bayer_module.get().bayer_dither
}
