// Upstream src/renderers/webgl/WebGLObjects.js.

///|
pub struct WebGLObjects {
  gl : WebGL2RenderingContext
  geometries : WebGLGeometries
  attributes : WebGLAttributes
  binding_states : WebGLBindingStates
  info : WebGLInfo
  /// geometry, instanced mesh or skeleton -> frame it was last updated in
  mut update_map : WeakMap[@core.JsValue, Int32]
  /// `onInstancedMeshDispose`, kept so it can be removed
  mut on_instanced_mesh_dispose : (@core.Event) -> Unit
}

///|
/// `new WebGLObjects( gl, geometries, attributes, bindingStates, info )`.
pub fn WebGLObjects::new(
  gl : WebGL2RenderingContext,
  geometries : WebGLGeometries,
  attributes : WebGLAttributes,
  binding_states : WebGLBindingStates,
  info : WebGLInfo,
) -> WebGLObjects {
  let self : WebGLObjects = {
    gl,
    geometries,
    attributes,
    binding_states,
    info,
    update_map: WeakMap::new(),
    on_instanced_mesh_dispose: _ => (),
  }
  self.on_instanced_mesh_dispose = event => {
    match event.target {
      Some(Object3D(instanced_mesh)) =>
        self.on_instanced_mesh_dispose_impl(instanced_mesh)
      _ => ()
    }
  }
  self
}

///|
/// `objects.update( object )`: uploads the object's geometry (and instance attributes,
/// skeleton) once per frame; returns the geometry.
pub fn WebGLObjects::update(
  self : WebGLObjects,
  object : @core.Object3D,
) -> @core.BufferGeometry {
  let frame = self.info.render.frame
  guard object.get_geometry() is Some(geometry) else {
    abort("WebGLObjects.update: object has no geometry")
  }
  let buffergeometry = self.geometries.get(object, geometry)
  // Update once per frame
  let geometry_key = @core.JsValue::of(buffergeometry)
  if self.update_map.get(geometry_key) != Some(frame) {
    self.geometries.update(buffergeometry)
    self.update_map.set(geometry_key, frame)
  }
  if object.kind is Mesh({ kind: InstancedMesh(instanced_mesh), .. }) {
    if !object.has_event_listener("dispose", self.on_instanced_mesh_dispose) {
      object.add_event_listener("dispose", self.on_instanced_mesh_dispose)
    }
    let object_key = @core.JsValue::of(object)
    if self.update_map.get(object_key) != Some(frame) {
      self.attributes.update(
        Buffer(instanced_mesh.instance_matrix),
        GL_ARRAY_BUFFER,
      )
      if instanced_mesh.instance_color is Some(instance_color) {
        self.attributes.update(Buffer(instance_color), GL_ARRAY_BUFFER)
      }
      self.update_map.set(object_key, frame)
    }
  }
  if object.kind
    is Mesh({ kind: SkinnedMesh({ skeleton: Some(skeleton), .. }), .. }) {
    let skeleton_key = @core.JsValue::of(skeleton)
    if self.update_map.get(skeleton_key) != Some(frame) {
      skeleton.update()
      self.update_map.set(skeleton_key, frame)
    }
  }
  buffergeometry
}

///|
/// `objects.dispose()`.
pub fn WebGLObjects::dispose(self : WebGLObjects) -> Unit {
  self.update_map = WeakMap::new()
}

///|
fn WebGLObjects::on_instanced_mesh_dispose_impl(
  self : WebGLObjects,
  instanced_mesh : @core.Object3D,
) -> Unit {
  instanced_mesh.remove_event_listener(
    "dispose",
    self.on_instanced_mesh_dispose,
  )
  self.binding_states.release_states_of_object(instanced_mesh)
  guard instanced_mesh.kind is Mesh({ kind: InstancedMesh(data), .. }) else {
    return
  }
  self.attributes.remove(Buffer(data.instance_matrix))
  if data.instance_color is Some(instance_color) {
    self.attributes.remove(Buffer(instance_color))
  }
}
