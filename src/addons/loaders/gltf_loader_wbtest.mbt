// Tests of GLTFLoader's synchronous parts, including upstream
// test/unit/addons/loaders/GLTFLoader.tests.js ('child credentials' and the CUBICSPLINE
// additive clip). Whole-asset loads are compared against upstream by the differential
// harness (diff/addons/gltf/gltf_diff).

///|
/// `buffer.byteLength`.
extern "js" fn gltf_byte_length(buffer : JsValue) -> Int32 = "(b) => b.byteLength"

///|
fn gltf_test_json(text : String) -> JsValue {
  gltf_json_parse(gltf_js_string(text))
}

///|
async test "GLTFLoader parses scene arrays and node transforms" {
  let data = JsValue::from_json({
    "asset": { "version": "2.0" },
    "scene": 0,
    "scenes": [{ "nodes": [0] }],
    "nodes": [
      {
        "name": "parent",
        "children": [1],
        "translation": [1, 2, 3],
        "scale": [2, 3, 4],
      },
      {
        "name": "child",
        "matrix": [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 4, 5, 6, 1],
      },
    ],
    "cameras": [
      {
        "type": "perspective",
        "perspective": { "yfov": 1, "znear": 0.1, "zfar": 100 },
      },
    ],
  })
  let result = @base_loaders.loader_promise(fn(resolve, reject) {
    GLTFLoader::new().parse(data, "", resolve, on_error=reject)
  })
  assert_eq(result.scenes.length(), 1)
  assert_eq(result.animations.length(), 0)
  assert_eq(result.cameras.length(), 1)
  let parent = result.scene.unwrap().children[0]
  assert_eq(parent.position.to_array(), [1.0, 2, 3])
  assert_eq(parent.scale.to_array(), [2.0, 3, 4])
  assert_eq(parent.children[0].position.to_array(), [4.0, 5, 6])
  assert_eq(parent.children[0].matrix_world.elements[12:15].to_owned(), [
    9.0, 17, 27,
  ])
  assert_true(result.parser.associations.entries().length() >= 2)
}

///|
async test "AddonPromise all preserves mixed values and nested arrays" {
  let values = [JsValue::of(1), @utils.AddonPromise::resolve(2).to_js()]
  values.push(JsValue::of(99))
  ignore(values.pop())
  let result = @base_loaders.loader_promise(fn(resolve, reject) {
    @utils.AddonPromise::all([
      @utils.AddonPromise::all_values(values),
      @utils.AddonPromise::all([]),
    ])
    .then_(fn(result : FixedArray[JsValue]) { resolve(result) })
    .catch_(fn(error) { reject(error) })
    |> ignore
  })
  assert_eq(result[0].to_json(), [1, 2])
  assert_eq(result[1].to_json(), [])
}

///|
test "child credentials" {
  let loader = GLTFLoader::new()
  loader.set_with_credentials(true) |> ignore
  let captured : Ref[GLTFParser?] = Ref(None)
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
    manager: @base_loaders.default_loading_manager,
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
  debug_inspect(
    clip.tracks[0].values.numbers().to_array(),
    content="[0, 0, 0, -1, -1, -1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0]",
  )
  // the interpolant: halfway along the spline with zero tangents
  debug_inspect(
    clip.tracks[0].create_interpolant().evaluate(0.5),
    content="[0, 0, 0]",
  )
  debug_inspect(tracks[0].get_interpolation(), content="None")
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
  debug_inspect(r, content="[0, 0.7071067811865475, 0, 0.7071067811865475]")
  let p = gltf_cubic_spline_interpolant(times, values, 4)
  // without normalization, and written to a Float32Array result buffer
  debug_inspect(p.evaluate(0.5), content="[0, 0.5, 0, 0.5]")
  debug_inspect(p.evaluate(-1), content="[0, 0, 0, 1]")
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
  debug_inspect(
    glb.content,
    content=(
      #|Some("{\"asset\":{}}")
    ),
  )
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
  debug_inspect(
    errors,
    content=(
      #|["THREE.GLTFLoader: Unsupported asset. glTF versions >=2.0 are supported."]
    ),
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
    manager: @base_loaders.default_loading_manager,
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
  debug_inspect(
    names,
    content=(
      #|["a_b", "a_b_1", "ab", "", "_1"]
    ),
  )
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
  debug_inspect(t.matrix.elements, content="[2, 0, 0, 0, 4, 0, 0.5, 0.25, 1]")
}
