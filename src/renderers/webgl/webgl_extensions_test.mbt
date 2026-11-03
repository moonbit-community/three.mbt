// Upstream test/unit/src/renderers/webgl/WebGLExtensions.tests.js.

///|
test "WebGLExtensions Instancing" {
  let gl = mock_gl(options="{\"extensions\":[]}")
  let extensions = @webgl.WebGLExtensions::new(gl)
  inspect(extensions.has("Extension1"), content="false")
}

///|
test "WebGLExtensions has" {
  let gl = mock_gl(options="{\"extensions\":[\"Extension1\",\"Extension2\"]}")
  let extensions = @webgl.WebGLExtensions::new(gl)
  assert_true(extensions.has("Extension1"))
  assert_true(extensions.has("Extension2"))
  assert_true(extensions.has("Extension1"))
  assert_true(!extensions.has("NonExistingExtension"))
}

///|
test "WebGLExtensions get" {
  let gl = mock_gl(options="{\"extensions\":[\"Extension1\",\"Extension2\"]}")
  let extensions = @webgl.WebGLExtensions::new(gl)
  assert_true(extensions.get("Extension1") is Some(_))
  assert_true(extensions.get("Extension2") is Some(_))
  assert_true(extensions.get("Extension1") is Some(_))
  // upstream silences the "extension not supported" warning here
  assert_true(extensions.get("NonExistingExtension") is None)
  // `getExtension` is asked once per name
  inspect(
    mock_log(gl).filter(l => l.has_prefix("getExtension")).length(),
    content="3",
  )
}
