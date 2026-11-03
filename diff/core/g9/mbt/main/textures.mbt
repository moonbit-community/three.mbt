///|
fn data_tex(kind : String, n : Int, format : Int, type_ : Int) -> @core.Texture {
  let data = @core.TypedArray::new_by_name(kind, 4 * 4 * n)
  for i = 0; i < data.length(); i = i + 1 {
    data.set(i, (i % 7).to_double())
  }
  let t = @core.DataTexture::new(data~, width=4, height=4, format~, type_~)
  t.set_needs_update(true)
  t
}

///|
fn img(w : Int, h : Int) -> @core.TextureImage {
  let o = @core.JsValue::object()
  o.set("width", @core.JsValue::of(w))
  o.set("height", @core.JsValue::of(h))
  DomImage(o)
}

///|
fn data_image(data : @core.TypedArray, width : Int, height : Int) -> @core.TextureImage {
  DataImage(@core.DataImage::new(data~, width~, height~))
}

///|
fn register_textures() -> Unit {
  scenario("textures_formats", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let list = [
        data_tex("Uint8Array", 4, @core.RGBAFormat, @core.UnsignedByteType),
        data_tex("Float32Array", 4, @core.RGBAFormat, @core.FloatType),
        data_tex("Uint16Array", 4, @core.RGBAFormat, @core.HalfFloatType),
        data_tex("Float32Array", 1, @core.RedFormat, @core.FloatType),
        data_tex("Uint8Array", 2, @core.RGFormat, @core.UnsignedByteType),
        data_tex("Int32Array", 1, @core.RedIntegerFormat, @core.IntType),
        data_tex("Uint32Array", 4, @core.RGBAIntegerFormat, @core.UnsignedIntType),
        data_tex("Int8Array", 4, @core.RGBAFormat, @core.ByteType),
        data_tex("Uint32Array", 1, @core.RGBFormat, @core.UnsignedInt5999Type),
        data_tex("Uint16Array", 1, @core.RedFormat, @core.HalfFloatType),
        data_tex("Float32Array", 2, @core.RGFormat, @core.FloatType),
      ]
      list[0].color_space = @math.SRGBColorSpace
      let flipped = data_tex("Uint8Array", 4, @core.RGBAFormat, @core.UnsignedByteType)
      flipped.flip_y = true
      list.push(flipped)
      let mipmapped = data_tex("Uint8Array", 4, @core.RGBAFormat, @core.UnsignedByteType)
      mipmapped.generate_mipmaps = true
      mipmapped.min_filter = @core.LinearMipmapLinearFilter
      list.push(mipmapped)
      let with_mips = data_tex("Uint8Array", 4, @core.RGBAFormat, @core.UnsignedByteType)
      with_mips.mipmaps = [
        data_image(@core.TypedArray::uint8(64), 4, 4),
        data_image(@core.TypedArray::uint8(16), 2, 2),
        data_image(@core.TypedArray::uint8(4), 1, 1),
      ]
      list.push(with_mips)
      for t in list {
        r.init_texture(t)
      }
      // sample one with a sampler: anisotropy and mipmaps
      let scene = @core.Scene::new()
      let m = @nodes.MeshBasicNodeMaterial::new()
      mipmapped.anisotropy = 4
      mipmapped.wrap_s = @core.RepeatWrapping
      mipmapped.wrap_t = @core.MirroredRepeatWrapping
      m.map = Some(mipmapped)
      scene.add(@core.Mesh::new(geometry=@geometries.PlaneGeometry::new(), material=Single(m))) |> ignore
      let m2 = @nodes.MeshBasicNodeMaterial::new()
      list[1].mag_filter = @core.NearestFilter
      list[1].wrap_s = @core.RepeatWrapping
      list[1].wrap_t = @core.MirroredRepeatWrapping
      m2.map = Some(list[1])
      scene.add(@core.Mesh::new(geometry=@geometries.PlaneGeometry::new(), material=Single(m2))) |> ignore
      r.render(scene, camera())
      // switching textures back and forth reuses the cached bind groups
      m.map = Some(list[0])
      r.render(scene, camera())
      m.map = Some(mipmapped)
      r.render(scene, camera())
      m.map = Some(list[0])
      r.render(scene, camera())
      done()
    })
  })
  scenario("textures_kinds", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let cube = @core.CubeTexture::new(images=[img(2, 2), img(2, 2), img(2, 2), img(2, 2), img(2, 2), img(2, 2)])
      cube.set_needs_update(true)
      let d3 = @core.Data3DTexture::new(data=@core.TypedArray::uint8(4 * 2 * 2 * 2), width=2, height=2, depth=2)
      d3.set_needs_update(true)
      let arr = @core.DataArrayTexture::new(data=@core.TypedArray::uint8(4 * 2 * 2 * 3), width=2, height=2, depth=3)
      arr.set_needs_update(true)
      let arr2 = @core.DataArrayTexture::new(data=@core.TypedArray::uint8(4 * 2 * 2 * 3), width=2, height=2, depth=3)
      arr2.set_needs_update(true)
      arr2.add_layer_update(1)
      let dxt = @core.CompressedTexture::new(mipmaps=[data_image(@core.TypedArray::uint8(8), 4, 4), data_image(@core.TypedArray::uint8(8), 2, 2)], width=4, height=4, format=@core.RGBA_S3TC_DXT1_Format)
      dxt.set_needs_update(true)
      let astc = @core.CompressedTexture::new(mipmaps=[data_image(@core.TypedArray::uint8(16), 5, 4)], width=5, height=4, format=@core.RGBA_ASTC_5x4_Format)
      astc.color_space = @math.SRGBColorSpace
      astc.set_needs_update(true)
      let carr = @core.CompressedArrayTexture::new(mipmaps=[data_image(@core.TypedArray::uint8(32), 4, 4)], width=4, height=4, depth=2, format=@core.RGBA_ETC2_EAC_Format)
      carr.set_needs_update(true)
      let canvas_tex = @core.CanvasTexture::new(canvas=img(4, 4).to_js())
      let image_tex = @core.Texture::new(image=img(4, 2))
      image_tex.flip_y = false
      image_tex.premultiply_alpha = true
      image_tex.set_needs_update(true)
      let video = img(4, 4).to_js()
      video.set("readyState", @core.JsValue::of(4))
      let video_tex = @core.VideoTexture::new(video)
      for t in [cube, d3, arr, arr2, dxt, astc, carr, canvas_tex, image_tex, video_tex] {
        r.init_texture(t)
      }
      let scene = @core.Scene::new()
      let m = @nodes.MeshBasicNodeMaterial::new()
      m.map = Some(image_tex)
      m.env_map = Some(cube)
      scene.add(@core.Mesh::new(geometry=@geometries.BoxGeometry::new(), material=Single(m))) |> ignore
      r.render(scene, camera())
      done()
    })
  })
}
