// A stand-in for a class above core, checking the extension protocol end to end.

///|
struct TestHelper {
  size : Double
  log : Array[String]
}

///|
impl @core.Object3DExtension for TestHelper with fn type_name(_) {
  "TestHelper"
}

///|
impl @core.Object3DExtension for TestHelper with fn construct(self) {
  test_helper(self.size, self.log)
}

///|
impl @core.Object3DExtension for TestHelper with fn has_flag(_, flag) {
  flag == "isTestHelper"
}

///|
impl @core.Object3DExtension for TestHelper with fn update_matrix_world(
  self,
  object,
  force,
) {
  self.log.push("update_matrix_world")
  object.update_matrix_world_kind(force)
}

///|
impl @core.Object3DExtension for TestHelper with fn copy_from(
  self,
  target,
  source,
  recursive,
) {
  self.log.push("copy_from")
  target.copy_kind(source, recursive)
}

///|
impl @core.Object3DExtension for TestHelper with fn to_json(self, _, _, data) {
  data["size"] = Json::number(self.size)
}

///|
impl @core.Object3DExtension for TestHelper with fn dispose(self, object) {
  self.log.push("dispose")
  object.dispose_kind()
}

///|
fn test_helper(size : Double, log : Array[String]) -> @core.Object3D {
  let helper : TestHelper = { size, log, }
  @core.Object3D::new().set_extension(helper)
}

///|
test "an extension overrides methods and reaches super" {
  let log = []
  let helper = test_helper(2, log)
  assert_eq(helper.type_, "TestHelper")
  assert_true(helper.has_extension_flag("isTestHelper"))
  assert_false(helper.has_extension_flag("isAudio"))
  ignore(helper.position.set(1, 2, 3))
  helper.update_matrix_world()
  assert_eq(helper.matrix_world.elements[12], 1)
  // children dispatch through their own extension
  let parent = @core.Object3D::new()
  ignore(parent.add(helper))
  parent.update_matrix_world()
  assert_eq(log, ["update_matrix_world", "update_matrix_world"])
  let mut disposed = false
  helper.add_event_listener("dispose", _ => disposed = true)
  helper.dispose()
  assert_true(disposed)
  assert_eq(log.last(), Some("dispose"))
}

///|
test "an extension keeps its payload through clone and toJSON" {
  let log = []
  let helper = test_helper(2, log)
  ignore(helper.position.set(4, 5, 6))
  let cloned = helper.clone()
  assert_eq(cloned.type_, "TestHelper")
  assert_true(cloned.position.equals(vec3(4, 5, 6)))
  assert_true(log.contains("copy_from"))
  let payload : TestHelper = cloned.extension.unwrap().payload().cast()
  assert_eq(payload.size, 2)
  guard helper.to_json() is Object(output) &&
    output.get("object") is Some(Object(object)) else {
    fail("no object")
  }
  assert_eq(object.get("type").unwrap(), Json::string("TestHelper"))
  assert_eq(object.get("size").unwrap(), Json::number(2))
}

///|
struct TestClip {
  uuid : String
}

///|
impl @core.SerializableResource for TestClip with fn uuid(self) {
  self.uuid
}

///|
impl @core.SerializableResource for TestClip with fn to_json(self) {
  Json::object({ "uuid": Json::string(self.uuid), "metadata": Json::null() })
}

///|
test "animations serialize through SerializableResource" {
  let object = @core.Object3D::new()
  let clip : TestClip = { uuid: "clip", }
  object.animations.push(clip)
  object.animations.push(clip)
  guard object.to_json() is Object(output) else { fail("not an object") }
  assert_eq(
    output.get("animations").unwrap(),
    Json::array([Json::object({ "uuid": Json::string("clip") })]),
  )
  guard output.get("object") is Some(Object(json)) else { fail("no object") }
  assert_eq(
    json.get("animations").unwrap(),
    Json::array([Json::string("clip"), Json::string("clip")]),
  )
  let back : TestClip = object.animations[0].payload().cast()
  assert_eq(back.uuid, "clip")
}

///|
struct TestControls {
  dispatcher : @core.EventDispatcher
}

///|
impl @core.EventSource for TestControls with fn event_dispatcher(self) {
  self.dispatcher
}

///|
impl @core.EventSource for TestControls with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
test "an event source above core" {
  let controls : TestControls = { dispatcher: @core.EventDispatcher::new(), }
  let mut name = ""
  @core.EventSource::add_event_listener(controls, "change", event => {
    guard event.target is Some(Other(target)) else { abort("no target") }
    let back : TestControls = target.cast()
    name = if physical_equal(back, controls) { "same" } else { "other" }
  })
  @core.EventSource::dispatch_event(controls, @core.Event::new("change"))
  assert_eq(name, "same")
}
