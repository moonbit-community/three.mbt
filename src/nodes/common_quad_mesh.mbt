// renderers/common/QuadMesh.js: a mesh covering the screen with one triangle, rendered
// with a fixed orthographic camera. The mesh is a core `Object3D` with a
// `QuadMeshExtension` (`has_extension_flag("isQuadMesh")`); `QuadMesh` wraps it.

///|
let _quad_mesh_camera : @core.Object3D = @core.OrthographicCamera::new(
  left=-1.0,
  right=1.0,
  top=1.0,
  bottom=-1.0,
  near=0.0,
  far=1.0,
)

///|
/// `new QuadGeometry( flipY = false )`.
fn quad_geometry(flip_y~ : Bool = false) -> @core.BufferGeometry {
  let geometry = @core.BufferGeometry::new()
  let uv : Array[Double] = if flip_y == false {
    [0.0, -1, 0, 1, 2, 1]
  } else {
    [0.0, 2, 0, 0, 2, 0]
  }
  geometry.set_attribute(
    "position",
    @core.Float32BufferAttribute::new(
      ([-1.0, 3, 0, -1, -1, 0, 3, -1, 0] : Array[Double]),
      3,
    ),
  )
  |> ignore
  geometry.set_attribute("uv", @core.Float32BufferAttribute::new(uv, 2))
  |> ignore
  geometry
}

///|
let _quad_mesh_geometry : @core.BufferGeometry = quad_geometry()

///|
let _quad_mesh_vertex_node : Node = module_nodes(
  "renderers/common/QuadMesh.js:_vertexNode",
  fn() {
    vec4_of([
      array([-1.0, -1.0, 3.0]).element(vertex_index),
      array([3.0, -1.0, -1.0]).element(vertex_index),
      0.0,
      1.0,
    ])
  },
)

///|
/// The extension of a quad mesh object.
pub(all) struct QuadMeshExtension {
  /// `quadMesh.camera`.
  mut camera : @core.Object3D
}

///|
pub impl @core.Object3DExtension for QuadMeshExtension with fn type_name(_) {
  "Mesh"
}

///|
pub impl @core.Object3DExtension for QuadMeshExtension with fn construct(_) {
  QuadMesh::new().object
}

///|
pub impl @core.Object3DExtension for QuadMeshExtension with fn has_flag(_, flag) {
  flag == "isQuadMesh"
}

///|
/// A full-screen quad rendered with one material.
pub(all) struct QuadMesh {
  /// The mesh.
  object : @core.Object3D
}

///|
/// `new QuadMesh( material = null )`.
pub fn QuadMesh::new(material? : @core.Material) -> QuadMesh {
  let object = @core.Mesh::new(
    geometry=_quad_mesh_geometry,
    material?=material.map(fn(m) { @core.MaterialSlot::Single(m) }),
  )
  object.set_extension(QuadMeshExtension::{ camera: _quad_mesh_camera, })
  |> ignore
  { object, }
}

///|
/// The quad mesh of a scene object, if it is one.
pub fn QuadMesh::from_object(object : @core.Object3D) -> QuadMesh? {
  if object.has_extension_flag("isQuadMesh") {
    Some({ object, })
  } else {
    None
  }
}

///|
/// `quadMesh.camera`.
pub fn QuadMesh::camera(self : QuadMesh) -> @core.Object3D {
  match self.object.extension {
    Some(e) => {
      let ext : QuadMeshExtension = e.payload().cast()
      ext.camera
    }
    None => _quad_mesh_camera
  }
}

///|
/// `quadMesh.material`.
pub fn QuadMesh::material(self : QuadMesh) -> @core.Material {
  match self.object.get_material() {
    Some(Single(m)) => m
    _ => abort("QuadMesh: the material is not a single material")
  }
}

///|
/// `quadMesh.material = material`.
pub fn QuadMesh::set_material(
  self : QuadMesh,
  material : @core.Material,
) -> Unit {
  match self.object.kind {
    Mesh(m) => m.material = Single(material)
    _ => ()
  }
}

///|
/// `render( renderer )`: draws the quad with the full-screen triangle's vertex node.
pub fn QuadMesh::render(self : QuadMesh, renderer : Renderer) -> Unit {
  let material = NodeMaterial::of(self.material())
  let previous_vertex_node = match material {
    Some(m) => {
      let previous = m.vertex_node
      m.vertex_node = Some(_quad_mesh_vertex_node)
      previous
    }
    None => None
  }
  renderer.render(self.object, _quad_mesh_camera)
  match material {
    Some(m) => m.vertex_node = previous_vertex_node
    None => ()
  }
}
