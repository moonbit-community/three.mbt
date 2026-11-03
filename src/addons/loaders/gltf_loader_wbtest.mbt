// Tests of GLTFLoader's synchronous parts, including upstream
// test/unit/addons/loaders/GLTFLoader.tests.js ('child credentials' and the CUBICSPLINE
// additive clip). Whole-asset loads are compared against upstream by the differential
// harness (diff/addons/gltf/gltf_diff).

///|
fn gltf_test_json(text : String) -> JsValue {
  gltf_json_parse(gltf_js_string(text))
}

///|
test "child credentials" {
  let loader = GLTFLoader::new()
  loader.set_with_credentials(true) |> ignore
  let captured : Ref[GLTFParser?] = Ref::new(None)
  let capture = fn(parser) -> &GLTFPlugin {
    captured.val = Some(parser)
    GLTFMeshQuantizationTestPlugin::{ }
  }
  loader.register(capture) |> ignore
  loader.parse(gltf_test_json("{\"asset\":{\"version\":\"2.0\"}}"), "", _ => ())
  let parser = captured.val.unwrap()
  assert_true(parser.file_loader.base.with_credentials)
  match parser.texture_loader {
    TextureLoader(l) => assert_true(l.base.with_credentials)
    ImageBitmapLoader(l) => assert_true(l.base.with_credentials)
    KTX2Loader(_) => fail("unexpected loader")
  }
}

///|
priv struct GLTFMeshQuantizationTestPlugin {}

///|
impl GLTFPlugin for GLTFMeshQuantizationTestPlugin with fn name(_) {
  "TEST"
}

///|
test "register and unregister compare callbacks by identity" {
  let loader = GLTFLoader::new()
  inspect(loader.plugin_callbacks.length(), content="19")
  let callback = fn(_ : GLTFParser) -> &GLTFPlugin {
    GLTFMeshQuantizationTestPlugin::{ }
  }
  loader.register(callback).register(callback) |> ignore
  inspect(loader.plugin_callbacks.length(), content="20")
  loader.unregister(callback) |> ignore
  inspect(loader.plugin_callbacks.length(), content="19")
}

///|
test "CUBICSPLINE animations can be made additive at an interpolated frame" {
  let json = gltf_test_json("{\"asset\":{\"version\":\"2.0\"},\"nodes\":[{}]}")
  let parser = GLTFParser::new(json, {
    path: "",
    cross_origin: "anonymous",
    priority: "auto",
    cache: "default",
    with_credentials: false,
    request_header: {},
    manager: @loaders.default_loading_manager,
    ktx2_loader: None,
    meshopt_decoder: None,
  })
  let times = @core.BufferAttribute::new(
    @core.TypedArray::float32([0.0, 1.0]),
    1,
  )
  let values = @core.BufferAttribute::new(
    @core.TypedArray::float32([
      0.0, 0.0, 0.0, 1.0, 2.0, 3.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 4.0, 5.0,
      0.0, 0.0, 0.0,
    ]),
    3,
  )
  let node = @core.Object3D::new()
  let tracks = parser.create_animation_tracks(
    node,
    Buffer(times),
    Buffer(values),
    gltf_test_json("{\"interpolation\":\"CUBICSPLINE\"}"),
    gltf_test_json("{\"node\":0,\"path\":\"translation\"}"),
  )
  inspect(tracks[0].name, content=node.uuid + ".position")
  let clip = @animation.AnimationClip::new(name="a", tracks~)
  @animation.make_clip_additive(
    clip,
    reference_frame=15,
    reference_clip=clip,
    fps=30,
  )
  |> ignore
  inspect(
    clip.tracks[0].values.numbers().to_array(),
    content="[0, 0, 0, -1, -1, -1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0]",
  )
  // the interpolant: halfway along the spline with zero tangents
  inspect(
    clip.tracks[0].create_interpolant().evaluate(0.5),
    content="[0, 0, 0]",
  )
  inspect(tracks[0].get_interpolation(), content="None")
}

///|
test "cubic spline quaternion interpolant normalizes" {
  let times = [0.0, 1.0]
  let values = [
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  ]
  let i = gltf_cubic_spline_interpolant(times, values, 4, quaternion=true)
  let r = i.evaluate(0.5)
  inspect(r, content="[0, 0.7071067811865475, 0, 0.7071067811865475]")
  let p = gltf_cubic_spline_interpolant(times, values, 4)
  // without normalization, and written to a Float32Array result buffer
  inspect(p.evaluate(0.5), content="[0, 0.5, 0, 0.5]")
  inspect(p.evaluate(-1), content="[0, 0, 0, 1]")
}

///|
/// A minimal `.glb` with the given JSON text and an 8-byte BIN chunk.
extern "js" fn gltf_test_glb(json : String, version : Int32) -> JsValue =
  #|(json, version) => {
  #|  const text = new TextEncoder().encode(json);
  #|  const jl = Math.ceil(text.length / 4) * 4;
  #|  const out = new Uint8Array(12 + 8 + jl + 8 + 8);
  #|  const dv = new DataView(out.buffer);
  #|  out.set(new TextEncoder().encode('glTF'), 0); dv.setUint32(4, version, true); dv.setUint32(8, out.length, true);
  #|  dv.setUint32(12, jl, true); dv.setUint32(16, 0x4E4F534A, true); out.fill(0x20, 20, 20 + jl); out.set(text, 20);
  #|  dv.setUint32(20 + jl, 8, true); dv.setUint32(24 + jl, 0x004E4942, true); out.set([1, 2, 3, 4, 5, 6, 7, 8], 28 + jl);
  #|  return out.buffer;
  #|}

///|
test "binary glTF container" {
  let glb = GLTFBinaryExtension::new(gltf_test_glb("{\"asset\":{}}", 2))
  inspect(glb.header.magic, content="glTF")
  inspect(glb.header.version, content="2")
  inspect(glb.content, content="Some({\"asset\":{}})")
  inspect(gltf_byte_length(glb.body.unwrap()), content="8")
  let error = @utils.addon_try(fn() {
    ignore(GLTFBinaryExtension::new(gltf_test_glb("{}", 1)))
  })
  inspect(
    gltf_string(gltf_error_message(error.unwrap())),
    content="THREE.GLTFLoader: Legacy binary file detected.",
  )
}

///|
extern "js" fn gltf_error_message(e : JsValue) -> JsValue = "(e) => e.message"

///|
test "unsupported assets reach onError" {
  let errors = []
  GLTFLoader::new().parse(
    gltf_test_json("{\"asset\":{\"version\":\"1.0\"}}"),
    "",
    _ => (),
    on_error=e => errors.push(gltf_string(gltf_error_message(e))),
  )
  inspect(
    errors,
    content="[THREE.GLTFLoader: Unsupported asset. glTF versions >=2.0 are supported.]",
  )
}

///|
test "primitive keys" {
  inspect(
    gltf_create_primitive_key(
      gltf_test_json(
        "{\"attributes\":{\"POSITION\":1,\"NORMAL\":2},\"indices\":0,\"targets\":[{\"POSITION\":3}]}",
      ),
    ),
    content="0:NORMAL:2;POSITION:1;:undefined:POSITION:3;",
  )
  inspect(
    gltf_create_primitive_key(
      gltf_test_json(
        "{\"attributes\":{\"POSITION\":1},\"mode\":4,\"extensions\":{\"KHR_draco_mesh_compression\":{\"bufferView\":5,\"attributes\":{\"POSITION\":0}}}}",
      ),
    ),
    content="draco:5:undefined:POSITION:0;",
  )
}

///|
test "unique names" {
  let parser = GLTFParser::new(gltf_test_json("{}"), {
    path: "",
    cross_origin: "anonymous",
    priority: "auto",
    cache: "default",
    with_credentials: false,
    request_header: {},
    manager: @loaders.default_loading_manager,
    ktx2_loader: None,
    meshopt_decoder: None,
  })
  let names = [
    parser.create_unique_name(gltf_js_string("a b")),
    parser.create_unique_name(gltf_js_string("a b")),
    parser.create_unique_name(gltf_js_string("a.b")),
    parser.create_unique_name(JsValue::undefined()),
    parser.create_unique_name(gltf_js_string("")),
  ]
  inspect(names, content="[a_b, a_b_1, ab, , _1]")
}

///|
test "texture transform" {
  let ext = GLTFTextureTransformExtension::new()
  let texture = @core.Texture::new()
  assert_true(
    physical_equal(ext.extend_texture(texture, gltf_test_json("{}")), texture),
  )
  let t = ext.extend_texture(
    texture,
    gltf_test_json(
      "{\"offset\":[0.5,0.25],\"rotation\":0,\"scale\":[2,4],\"texCoord\":1}",
    ),
  )
  assert_false(physical_equal(t, texture))
  inspect(t.channel, content="1")
  inspect(t.matrix_auto_update, content="false")
  inspect(t.matrix.elements, content="[2, 0, 0, 0, 4, 0, 0.5, 0.25, 1]")
}
