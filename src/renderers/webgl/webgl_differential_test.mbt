// Differential scenarios for the foundation modules. Each test mirrors
// harness/scenarios/<name>.mjs in the diff/core/webgl harness step by step; run_diff.mjs
// compares the two call logs. Without the harness the tests still run against the mock
// and check a few results directly.

///|
test "diff extensions" {
  let gl = mock_gl(
    options="{\"extensions\":[\"Extension1\",\"Extension2\",\"EXT_color_buffer_float\"]}",
  )
  let e = @webgl.WebGLExtensions::new(gl)
  note_bool(gl, "has Extension1", e.has("Extension1"))
  note_bool(gl, "has Extension2", e.has("Extension2"))
  note_bool(gl, "has Extension1", e.has("Extension1"))
  note_bool(gl, "has NonExisting", e.has("NonExistingExtension"))
  note_bool(gl, "get Extension2", e.get("Extension2") is Some(_))
  note_bool(gl, "get NonExisting", e.get("NonExistingExtension") is Some(_))
  e.init()
  let log = emit_log("extensions", gl)
  inspect(log.length(), content="15")
}

///|
test "diff capabilities" {
  let gl = mock_gl(
    options="{\"precision\":{\"HIGH_FLOAT\":0},\"extensions\":[\"EXT_texture_filter_anisotropic\",\"EXT_color_buffer_float\"],\"parameters\":{\"IMPLEMENTATION_COLOR_READ_TYPE\":5123}}",
  )
  let extensions = @webgl.WebGLExtensions::new(gl)
  let utils = @webgl.WebGLUtils::new(gl, extensions)
  let c = @webgl.WebGLCapabilities::new(
    gl,
    extensions,
    {
      precision: Some("highp"),
      logarithmic_depth_buffer: true,
      reversed_depth_buffer: true,
    },
    utils,
  )
  note_str(gl, "precision", c.precision)
  note_bool(gl, "logarithmicDepthBuffer", c.logarithmic_depth_buffer)
  note_bool(gl, "reversedDepthBuffer", c.reversed_depth_buffer)
  note_int(gl, "maxTextures", c.max_textures)
  note_int(gl, "maxVertexTextures", c.max_vertex_textures)
  note_int(gl, "maxTextureSize", c.max_texture_size)
  note_int(gl, "maxCubemapSize", c.max_cubemap_size)
  note_int(gl, "maxAttributes", c.max_attributes)
  note_int(gl, "maxVertexUniforms", c.max_vertex_uniforms)
  note_int(gl, "maxVaryings", c.max_varyings)
  note_int(gl, "maxFragmentUniforms", c.max_fragment_uniforms)
  note_int(gl, "maxSamples", c.max_samples)
  note_int(gl, "samples", c.samples)
  note_bool(gl, "isWebGL2", c.is_webgl2)
  note_num(gl, "getMaxAnisotropy", c.get_max_anisotropy())
  note_num(gl, "getMaxAnisotropy", c.get_max_anisotropy())
  note_str(gl, "getMaxPrecision lowp", c.get_max_precision("lowp"))
  note_bool(gl, "formatReadable RGBA", c.texture_format_readable(1023))
  note_bool(gl, "formatReadable Red", c.texture_format_readable(1028))
  note_bool(gl, "typeReadable HalfFloat", c.texture_type_readable(1016))
  note_bool(gl, "typeReadable UnsignedShort", c.texture_type_readable(1012))
  note_bool(gl, "typeReadable Int", c.texture_type_readable(1013))
  let c2 = @webgl.WebGLCapabilities::new(
    gl,
    extensions,
    {
      precision: None,
      logarithmic_depth_buffer: false,
      reversed_depth_buffer: false,
    },
    utils,
  )
  note_str(gl, "default precision", c2.precision)
  ignore(emit_log("capabilities", gl))
  inspect(c.precision, content="mediump")
  inspect(c.logarithmic_depth_buffer, content="true")
  inspect(c.reversed_depth_buffer, content="false")
}

///|
let diff_utils_formats : Array[Int32] = [
  1009, 1017, 1018, 35902, 35899, 1010, 1011, 1012, 1013, 1014, 1015, 1016, 1021,
  1022, 1023, 1026, 1027, 1028, 1029, 1030, 1031, 1033, 33776, 33777, 33778, 33779,
  35840, 36196, 37492, 37496, 37488, 37489, 37490, 37491, 37808, 37815, 37821, 36492,
  36283, 1020, 99999,
]

///|
test "diff utils" {
  let gl = mock_gl()
  let utils = @webgl.WebGLUtils::new(gl, @webgl.WebGLExtensions::new(gl))
  for cs in ["", "srgb"] {
    for p in diff_utils_formats {
      note_opt_int(gl, "convert \{p} \{cs}", utils.convert(p, color_space=cs))
    }
  }
  ignore(emit_log("utils", gl))
  debug_inspect(utils.convert(@core.FloatType), content="Some(5126)")
  debug_inspect(utils.convert(@core.RGB_PVRTC_4BPPV1_Format), content="None")
}

///|
fn diff_note_attribute(
  gl : @webgl.WebGL2RenderingContext,
  attrs : @webgl.WebGLAttributes,
  label : String,
  attribute : @core.GeometryAttribute,
) -> Unit {
  match attrs.get(attribute) {
    None => note_str(gl, label, "undefined")
    Some(d) => {
      let size = match d.size {
        Some(size) => @core.JsValue::of(size)
        None => @core.JsValue::of("undefined")
      }
      let values : FixedArray[@core.JsValue] = [
        @core.JsValue::of(d.buffer),
        @core.JsValue::of(d.type_),
        @core.JsValue::of(d.bytes_per_element),
        @core.JsValue::of(d.version),
        size,
      ]
      mock_note(gl, label, @core.JsValue::of(values))
    }
  }
}

///|
test "diff attributes" {
  let gl = mock_gl()
  let attrs = @webgl.WebGLAttributes::new(gl)
  let a = @core.BufferAttribute::new(
    @core.TypedArray::float32([0.0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]),
    3,
  )
  attrs.update(Buffer(a), @webgl.GL_ARRAY_BUFFER)
  diff_note_attribute(gl, attrs, "a", Buffer(a))
  attrs.update(Buffer(a), @webgl.GL_ARRAY_BUFFER)
  a.set_needs_update(true)
  attrs.update(Buffer(a), @webgl.GL_ARRAY_BUFFER)
  diff_note_attribute(gl, attrs, "a", Buffer(a))
  a.add_update_range(6, 3)
  a.add_update_range(0, 2)
  a.add_update_range(2, 1)
  a.add_update_range(10, 2)
  a.set_needs_update(true)
  attrs.update(Buffer(a), @webgl.GL_ARRAY_BUFFER)
  note_int(gl, "ranges", a.update_ranges.length())
  diff_note_attribute(gl, attrs, "a", Buffer(a))
  let index = @core.Uint16BufferAttribute::new([0, 1, 2, 2, 3, 0], 1)
  attrs.update(Buffer(index), @webgl.GL_ELEMENT_ARRAY_BUFFER)
  diff_note_attribute(gl, attrs, "index", Buffer(index))
  let half = @core.Float16BufferAttribute::new([1.0, 2.0], 1)
  attrs.update(Buffer(half), @webgl.GL_ARRAY_BUFFER)
  diff_note_attribute(gl, attrs, "half", Buffer(half))
  let kinds = [
    ("Int8Array", 1.0),
    ("Uint8Array", 2.0),
    ("Uint8ClampedArray", 3.0),
    ("Int16Array", 4.0),
    ("Int32Array", 5.0),
    ("Uint32Array", 6.0),
  ]
  for kind in kinds {
    let (name, v) = kind
    let b = @core.BufferAttribute::new(
      @core.TypedArray::new_by_name(name, [v, v]),
      1,
    )
    ignore(b.set_usage(@core.DynamicDrawUsage))
    attrs.update(Buffer(b), @webgl.GL_ARRAY_BUFFER)
    diff_note_attribute(gl, attrs, name, Buffer(b))
  }
  let ib = @core.InterleavedBuffer::new(@core.TypedArray::float32(12), 4)
  let p = @core.InterleavedBufferAttribute::new(ib, 3, 0)
  let w = @core.InterleavedBufferAttribute::new(ib, 1, 3)
  attrs.update(Interleaved(p), @webgl.GL_ARRAY_BUFFER)
  attrs.update(Interleaved(w), @webgl.GL_ARRAY_BUFFER)
  diff_note_attribute(gl, attrs, "interleaved p", Interleaved(p))
  diff_note_attribute(gl, attrs, "interleaved w", Interleaved(w))
  ib.set_needs_update(true)
  attrs.update(Interleaved(w), @webgl.GL_ARRAY_BUFFER)
  diff_note_attribute(gl, attrs, "interleaved w", Interleaved(w))
  let gl_buffer = gl.create_buffer()
  let g = @core.GLBufferAttribute::new(
    @core.JsValue::of(gl_buffer),
    @webgl.GL_FLOAT,
    3,
    4,
    3,
  )
  attrs.update(GL(g), @webgl.GL_ARRAY_BUFFER)
  diff_note_attribute(gl, attrs, "gl", GL(g))
  g.set_needs_update(true)
  attrs.update(GL(g), @webgl.GL_ARRAY_BUFFER)
  diff_note_attribute(gl, attrs, "gl", GL(g))
  attrs.remove(Buffer(a))
  diff_note_attribute(gl, attrs, "a removed", Buffer(a))
  attrs.remove(Buffer(a))
  attrs.remove(Interleaved(w))
  diff_note_attribute(gl, attrs, "interleaved p removed", Interleaved(p))
  let log = emit_log("attributes", gl)
  inspect(log[0], content="createBuffer()")
  inspect(
    log[1],
    content=(
      #|bindBuffer(34962, "Buffer#1")
    ),
  )
}

///|
fn diff_note_info(
  gl : @webgl.WebGL2RenderingContext,
  info : @webgl.WebGLInfo,
) -> Unit {
  let r = info.render
  let values : FixedArray[Double] = [
    r.frame.to_double(),
    r.calls.to_double(),
    r.triangles,
    r.lines,
    r.points,
  ]
  mock_note(gl, "render", @core.JsValue::of(values))
}

///|
test "diff buffer_renderers" {
  let gl = mock_gl()
  let info = @webgl.WebGLInfo::new(gl)
  let ext = @webgl.WebGLExtensions::new(gl)
  let br = @webgl.WebGLBufferRenderer::new(gl, ext, info)
  br.set_mode(@webgl.GL_TRIANGLES)
  br.render(0, 6)
  br.render_instances(0, 6, 3)
  br.render_instances(0, 6, 0)
  br.render_multi_draw(
    @core.TypedArray::int32([0, 3]),
    @core.TypedArray::int32([3, 3]),
    2,
  )
  br.render_multi_draw(
    @core.TypedArray::int32([0]),
    @core.TypedArray::int32([3]),
    0,
  )
  diff_note_info(gl, info)
  let ibr = @webgl.WebGLIndexedBufferRenderer::new(gl, ext, info)
  ibr.set_mode(@webgl.GL_LINES)
  ibr.set_index({
    buffer: gl.create_buffer(),
    type_: @webgl.GL_UNSIGNED_SHORT,
    bytes_per_element: 2,
    version: 0,
    size: None,
  })
  ibr.render(3, 6)
  ibr.render_instances(1, 4, 2)
  ibr.render_instances(1, 4, 0)
  ibr.render_multi_draw(
    @core.TypedArray::int32([0, 6]),
    @core.TypedArray::int32([4, 2]),
    2,
  )
  diff_note_info(gl, info)
  info.update(5, @webgl.GL_LINE_STRIP, 2)
  info.update(4, @webgl.GL_LINE_LOOP, 1)
  info.update(7, @webgl.GL_POINTS, 3)
  info.update(4, @webgl.GL_TRIANGLES, 1)
  diff_note_info(gl, info)
  info.reset()
  diff_note_info(gl, info)
  ignore(emit_log("buffer_renderers", gl))
  inspect(info.render.calls, content="0")
}

///|
test "diff shader" {
  let gl = mock_gl()
  ignore(@webgl.webgl_shader(gl, @webgl.GL_VERTEX_SHADER, "void main() {}"))
  ignore(
    @webgl.webgl_shader(
      gl,
      @webgl.GL_FRAGMENT_SHADER,
      "void main() { gl_FragColor = vec4( 1.0 ); }",
    ),
  )
  let log = emit_log("shader", gl)
  inspect(log.length(), content="6")
  inspect(
    log[1],
    content=(
      #|shaderSource("Shader#1", "void main() {}")
    ),
  )
}

///|
fn diff_note_wire(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  wire : @core.BufferAttribute,
) -> Unit {
  let values : FixedArray[@core.JsValue] = [
    @core.JsValue::of(wire.array),
    @core.JsValue::of(wire.version),
  ]
  mock_note(gl, label, @core.JsValue::of(values))
}

///|
test "diff geometries_objects" {
  let gl = mock_gl()
  let attributes = @webgl.WebGLAttributes::new(gl)
  let binding_states = @webgl.WebGLBindingStates::new(gl, attributes)
  let info = @webgl.WebGLInfo::new(gl)
  let geometries = @webgl.WebGLGeometries::new(
    gl, attributes, info, binding_states,
  )
  let objects = @webgl.WebGLObjects::new(
    gl, geometries, attributes, binding_states, info,
  )
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(
        [0.0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0],
        3,
      ),
    ),
  )
  ignore(
    geometry.set_attribute(
      "normal",
      @core.Float32BufferAttribute::new(
        [0.0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
        3,
      ),
    ),
  )
  ignore(geometry.set_index([0, 1, 2, 2, 1, 3]))
  let material = @core.MeshBasicMaterial::new()
  let mesh = @core.Mesh::new(geometry~, material=Single(material))
  note_bool(gl, "same geometry", physical_equal(objects.update(mesh), geometry))
  ignore(objects.update(mesh))
  info.render.frame += 1
  geometry.attributes["position"].set_needs_update(true)
  ignore(objects.update(mesh))
  note_int(gl, "geometries", info.memory.geometries)
  let wire = geometries.get_wireframe_attribute(geometry).unwrap()
  diff_note_wire(gl, "wire", wire)
  note_bool(
    gl,
    "wire cached",
    physical_equal(geometries.get_wireframe_attribute(geometry).unwrap(), wire),
  )
  attributes.update(Buffer(wire), @webgl.GL_ELEMENT_ARRAY_BUFFER)
  geometry.index.unwrap().set_needs_update(true)
  let wire = geometries.get_wireframe_attribute(geometry).unwrap()
  diff_note_wire(gl, "wire", wire)
  attributes.update(Buffer(wire), @webgl.GL_ELEMENT_ARRAY_BUFFER)
  let geometry2 = @core.BufferGeometry::new()
  ignore(
    geometry2.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(
        [0.0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 2, 2, 2],
        3,
      ),
    ),
  )
  let mesh2 = @core.Mesh::new(geometry=geometry2, material=Single(material))
  ignore(objects.update(mesh2))
  let wire2 = geometries.get_wireframe_attribute(geometry2).unwrap()
  diff_note_wire(gl, "wire2", wire2)
  note_bool(
    gl,
    "no position",
    geometries.get_wireframe_attribute(@core.BufferGeometry::new()) is None,
  )
  let im = @core.InstancedMesh::new(geometry~, material=Single(material), 2)
  ignore(objects.update(im))
  ignore(objects.update(im))
  info.render.frame += 1
  guard im.kind is Mesh({ kind: InstancedMesh(im_data), .. }) else {
    fail("not an instanced mesh")
  }
  im_data.instance_matrix.set_needs_update(true)
  ignore(objects.update(im))
  im.dispose()
  ignore(objects.update(im))
  note_int(gl, "geometries", info.memory.geometries)
  geometry.dispose()
  note_int(gl, "geometries", info.memory.geometries)
  geometries.dispose()
  note_int(gl, "geometries", info.memory.geometries)
  objects.dispose()
  ignore(emit_log("geometries_objects", gl))
  inspect(info.memory.geometries, content="0")
}

///|
/// A `WebGLProgram` with fixed attribute locations, standing in for a compiled program.
fn diff_fake_program(
  gl : @webgl.WebGL2RenderingContext,
  id : Int32,
  attributes : Map[String, @webgl.ProgramAttribute],
) -> @webgl.WebGLProgram {
  {
    type_: "",
    name: "",
    id,
    cache_key: "",
    used_times: 1,
    program: None,
    vertex_shader: @webgl.uninitialized(),
    fragment_shader: @webgl.uninitialized(),
    diagnostics: None,
    renderer: @webgl.uninitialized(),
    gl,
    binding_states: @webgl.uninitialized(),
    prefix_vertex: "",
    prefix_fragment: "",
    cached_uniforms: None,
    cached_attributes: Some(attributes),
    program_ready: true,
  }
}

///|
test "diff binding_states" {
  let gl = mock_gl()
  let attributes = @webgl.WebGLAttributes::new(gl)
  let bs = @webgl.WebGLBindingStates::new(gl, attributes)
  let program = diff_fake_program(gl, 7, {
    "position": { type_: 0x8B51, location: 0, location_size: 1, },
    "normal": { type_: 0x8B51, location: 1, location_size: 1, },
    "aInt": { type_: 0x1404, location: 2, location_size: 1, },
    "color": { type_: 0x8B51, location: 3, location_size: 1, },
    "instanceMatrix": { type_: 0x8B5C, location: 4, location_size: 4, },
    "unused": { type_: 0x1406, location: -1, location_size: 1, },
  })
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new([0.0, 0, 0, 1, 0, 0, 0, 1, 0], 3),
    ),
  )
  ignore(
    geometry.set_attribute(
      "normal",
      @core.Float32BufferAttribute::new([0.0, 0, 1, 0, 0, 1, 0, 0, 1], 3),
    ),
  )
  ignore(
    geometry.set_attribute(
      "aInt",
      @core.Int32BufferAttribute::new([1.0, 2, 3], 1),
    ),
  )
  ignore(geometry.set_index([0, 1, 2]))
  let material = @core.ShaderMaterial::new()
  material.default_attribute_values = Some({ "color": [1.0, 0, 0] })
  let mesh = @core.Mesh::new(geometry~, material=Single(material))
  for _, attribute in geometry.attributes {
    attributes.update(attribute, @webgl.GL_ARRAY_BUFFER)
  }
  bs.setup(mesh, material, program, geometry, geometry.index)
  bs.setup(mesh, material, program, geometry, geometry.index)
  material.wireframe = Some(true)
  bs.setup(mesh, material, program, geometry, geometry.index)
  material.wireframe = Some(false)
  bs.setup(mesh, material, program, geometry, geometry.index)
  let geometry3 = @core.BufferGeometry::new()
  let ib = @core.InterleavedBuffer::new(@core.TypedArray::float32(18), 6)
  ignore(
    geometry3.set_attribute(
      "position",
      @core.InterleavedBufferAttribute::new(ib, 3, 0),
    ),
  )
  ignore(
    geometry3.set_attribute(
      "normal",
      @core.InterleavedBufferAttribute::new(ib, 3, 3),
    ),
  )
  ignore(
    geometry3.set_attribute(
      "color",
      @core.InstancedBufferAttribute::new(
        @core.TypedArray::float32([1.0, 1, 1, 0, 0, 0]),
        3,
        normalized=false,
        mesh_per_attribute=2,
      ),
    ),
  )
  let mesh3 = @core.Mesh::new(geometry=geometry3, material=Single(material))
  for _, attribute in geometry3.attributes {
    attributes.update(attribute, @webgl.GL_ARRAY_BUFFER)
  }
  bs.setup(mesh3, material, program, geometry3, None)
  match @webgl.geometry_max_instance_count(geometry3) {
    Some(count) => note_int(gl, "maxInstanceCount", count)
    None => note_str(gl, "maxInstanceCount", "undefined")
  }
  let im = @core.InstancedMesh::new(geometry~, material=Single(material), 2)
  guard im.kind is Mesh({ kind: InstancedMesh(im_data), .. }) else {
    fail("not an instanced mesh")
  }
  attributes.update(Buffer(im_data.instance_matrix), @webgl.GL_ARRAY_BUFFER)
  bs.setup(im, material, program, geometry, geometry.index)
  bs.reset()
  bs.reset()
  bs.setup(mesh, material, program, geometry, geometry.index)
  bs.release_states_of_object(im)
  bs.release_states_of_geometry(geometry3)
  bs.release_states_of_program(program)
  bs.setup(mesh, material, program, geometry, geometry.index)
  bs.dispose()
  let log = emit_log("binding_states", gl)
  inspect(
    log.contains("vertexAttribIPointer(2, 1, 5124, 4, 0)"),
    content="true",
  )
  inspect(
    log.contains(
      (
        #|vertexAttrib3fv(3, [1,0,0])
      ),
    ),
    content="true",
  )
}

///|
fn diff_note_clipping(
  gl : @webgl.WebGL2RenderingContext,
  clipping : @webgl.WebGLClipping,
  label : String,
) -> Unit {
  let value = match clipping.uniform.value {
    TypedArray(array) => @core.JsValue::of(array)
    _ => @core.JsValue::null()
  }
  let needs_update = match @webgl.uniform_needs_update(clipping.uniform) {
    Some(b) => @core.JsValue::of(b)
    None => @core.JsValue::of("undefined")
  }
  let values : FixedArray[@core.JsValue] = [
    value,
    needs_update,
    @core.JsValue::of(clipping.num_planes),
    @core.JsValue::of(clipping.num_intersection),
  ]
  mock_note(gl, label, @core.JsValue::of(values))
}

///|
test "diff clipping" {
  let gl = mock_gl()
  let clipping = @webgl.WebGLClipping::new(@webgl.WebGLProperties::new())
  let camera = @core.PerspectiveCamera::new(fov=50, aspect=1, near=0.1, far=100)
  ignore(camera.position.set(1, 2, 3))
  camera.look_at_xyz(0, 0, 0)
  camera.update_matrix_world()
  let p1 = @math.Plane::new(normal=@math.Vector3::new(1, 0, 0), constant=1)
  let p2 = @math.Plane::new(normal=@math.Vector3::new(0, 1, 0), constant=-2)
  let p3 = @math.Plane::new(
    normal=@math.Vector3::new(0, 0.6, 0.8),
    constant=0.5,
  )
  note_bool(gl, "init", clipping.init([p1], true))
  clipping.set_global_state([p1], camera)
  diff_note_clipping(gl, clipping, "global")
  let material = @core.MeshBasicMaterial::new()
  material.clipping_planes = Some([p2, p3])
  material.clip_intersection = true
  clipping.set_state(material, camera, false)
  diff_note_clipping(gl, clipping, "local")
  clipping.set_state(material, camera, true)
  diff_note_clipping(gl, clipping, "local cached")
  let m2 = @core.MeshBasicMaterial::new()
  clipping.set_state(m2, camera, false)
  diff_note_clipping(gl, clipping, "none")
  clipping.begin_shadows()
  diff_note_clipping(gl, clipping, "shadows")
  clipping.set_state(material, camera, false)
  diff_note_clipping(gl, clipping, "shadows no clip")
  material.clip_shadows = true
  clipping.set_state(material, camera, false)
  diff_note_clipping(gl, clipping, "shadows clip")
  clipping.end_shadows()
  note_bool(gl, "init", clipping.init([], false))
  note_bool(gl, "init", clipping.init([], false))
  clipping.set_state(material, camera, false)
  diff_note_clipping(gl, clipping, "disabled")
  ignore(emit_log("clipping", gl))
  inspect(clipping.num_planes, content="0")
}

///|
test "diff animation" {
  let gl = mock_gl()
  let ctx = mock_animation_context(gl)
  let anim = @webgl.WebGLAnimation::new()
  anim.start()
  anim.set_animation_loop(
    Some(fn(time, frame) {
      let values : FixedArray[@core.JsValue] = [
        @core.JsValue::of(time),
        if frame.is_undefined() {
          @core.JsValue::of("undefined")
        } else {
          frame
        },
      ]
      mock_note(gl, "frame", @core.JsValue::of(values))
    }),
  )
  anim.start()
  anim.set_context(Some(ctx))
  anim.start()
  anim.start()
  mock_tick(ctx, 16)
  mock_tick(ctx, 32)
  anim.stop()
  anim.stop()
  anim.start()
  mock_tick(ctx, 48)
  let log = emit_log("animation", gl)
  inspect(log.length(), content="10")
}

///|
fn diff_names(items : Array[@webgl.RenderItem]) -> @core.JsValue {
  @core.JsValue::of(
    FixedArray::from_array(
      items.map(it => {
        it.object.name + "@" + @webgl.js_to_string(@core.JsValue::of(it.z))
      })[:],
    ),
  )
}

///|
test "diff render_lists" {
  let gl = mock_gl()
  let camera = @core.PerspectiveCamera::new()
  let geometry = @core.BufferGeometry::new()
  let opaque_a = @core.MeshBasicMaterial::new()
  let opaque_b = @core.MeshBasicMaterial::new()
  let transparent = @core.MeshBasicMaterial::new()
  transparent.transparent = true
  let transmissive = @core.MeshPhysicalMaterial::new()
  transmissive.set_transmission(0.5)
  let render_orders = [0.0, 1, 0, 0, 1, 0, 0, 2]
  let objects = []
  for i in 0..<8 {
    let o = if i == 5 {
      @core.InstancedMesh::new(geometry~, material=Single(opaque_a), 1)
    } else {
      @core.Mesh::new(geometry~, material=Single(opaque_a))
    }
    o.name = "o\{i}"
    o.render_order = render_orders[i]
    objects.push(o)
  }
  let list = @webgl.WebGLRenderList::new()
  let fill = () => {
    list.init()
    list.push(objects[0], geometry, opaque_b, 0, 5, None, camera)
    list.push(objects[1], geometry, opaque_a, 0, 1, None, camera)
    list.push(objects[2], geometry, opaque_a, 0, 3, None, camera)
    list.push(objects[3], geometry, opaque_a, 1, 2, None, camera)
    list.push(objects[4], geometry, transparent, 0, 4, None, camera)
    list.push(objects[5], geometry, opaque_a, 0, 3, None, camera)
    list.push(objects[6], geometry, transparent, 0, 9, None, camera)
    list.push(objects[7], geometry, transmissive, 0, 1, None, camera)
    list.push(objects[6], geometry, transmissive, 0, 2, None, camera)
    list.unshift(objects[2], geometry, transparent, 0, 0.5, None)
    list.push(objects[0], geometry, opaque_a, 0, 3, None, camera)
  }
  fill()
  list.sort(None, None)
  mock_note(gl, "opaque", diff_names(list.opaque_))
  mock_note(gl, "transparent", diff_names(list.transparent))
  mock_note(gl, "transmissive", diff_names(list.transmissive))
  fill()
  list.sort(Some((a, b) => b.z - a.z), Some((a, b) => a.z - b.z))
  mock_note(gl, "opaque custom", diff_names(list.opaque_))
  mock_note(gl, "transparent custom", diff_names(list.transparent))
  list.init()
  list.push(objects[1], geometry, opaque_a, 0, 1, None, camera)
  list.finish()
  mock_note(gl, "opaque after finish", diff_names(list.opaque_))
  ignore(emit_log("render_lists", gl))
  inspect(list.render_items[1].released, content="true")
}
