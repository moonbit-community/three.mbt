// Upstream examples/jsm/objects/ShadowMesh.js: a planar projected shadow of a mesh,
// drawn with a stencil test so overlapping parts darken once.

///|
let _shadow_mesh_shadow_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
pub(all) struct ShadowMesh {
  /// `meshMatrix`: the world matrix of the shadowed mesh.
  mut mesh_matrix : @math.Matrix4
}

///|
pub impl @core.Object3DExtension for ShadowMesh with fn type_name(_) {
  "Mesh"
}

///|
pub impl @core.Object3DExtension for ShadowMesh with fn construct(_) {
  abort("TypeError: Cannot read properties of undefined (reading 'geometry')")
}

///|
pub impl @core.Object3DExtension for ShadowMesh with fn has_flag(_, flag) {
  flag == "isShadowMesh" || flag == "class:ShadowMesh"
}

///|
#deprecated
pub extend ShadowMesh with @core.Object3DExtension::{
  type_name,
  construct,
  payload,
  has_flag,
  raycast,
  copy_from,
  to_json,
  update_matrix_world,
  update_world_matrix,
  intersects_frustum,
  get_world_direction,
  dispose,
}

///|
/// `new ShadowMesh( mesh )`: shares `mesh`'s geometry; call `update` each frame.
pub fn ShadowMesh::new(mesh : @core.Object3D) -> @core.Object3D {
  let shadow_material = @core.MeshBasicMaterial::new()
  shadow_material.color.unwrap().set_hex(0x000000) |> ignore
  shadow_material.transparent = true
  shadow_material.opacity = 0.6
  shadow_material.depth_write = false
  shadow_material.stencil_write = true
  shadow_material.stencil_func = @core.EqualStencilFunc
  shadow_material.stencil_ref = 0
  shadow_material.stencil_z_pass = @core.IncrementStencilOp
  let geometry = match mesh.kind {
    Mesh(m) => m.geometry
    _ => abort("TypeError: mesh.geometry is undefined")
  }
  let object = @core.Mesh::new(geometry~, material=Single(shadow_material))
  object.set_extension(ShadowMesh::{ mesh_matrix: mesh.matrix_world, })
  |> ignore
  object.frustum_culled = false
  object.matrix_auto_update = false
  object
}

///|
/// The payload of a `ShadowMesh`, or `None` for other objects.
pub fn ShadowMesh::of(object : @core.Object3D) -> ShadowMesh? {
  objects_payload(object, "class:ShadowMesh")
}

///|
/// `update( plane, lightPosition4D )`: projects the mesh onto `plane` from the light.
pub fn ShadowMesh::update(
  object : @core.Object3D,
  plane : @math.Plane,
  light_position4d : @math.Vector4,
) -> Unit {
  let shadow_mesh : ShadowMesh = objects_require(object, "class:ShadowMesh")
  // based on https://www.opengl.org/archives/resources/features/StencilTalk/tsld021.htm
  let dot = plane.normal.x * light_position4d.x +
    plane.normal.y * light_position4d.y +
    plane.normal.z * light_position4d.z +
    -plane.constant * light_position4d.w
  let sme = _shadow_mesh_shadow_matrix.elements
  sme[0] = dot - light_position4d.x * plane.normal.x
  sme[4] = -light_position4d.x * plane.normal.y
  sme[8] = -light_position4d.x * plane.normal.z
  sme[12] = -light_position4d.x * -plane.constant
  sme[1] = -light_position4d.y * plane.normal.x
  sme[5] = dot - light_position4d.y * plane.normal.y
  sme[9] = -light_position4d.y * plane.normal.z
  sme[13] = -light_position4d.y * -plane.constant
  sme[2] = -light_position4d.z * plane.normal.x
  sme[6] = -light_position4d.z * plane.normal.y
  sme[10] = dot - light_position4d.z * plane.normal.z
  sme[14] = -light_position4d.z * -plane.constant
  sme[3] = -light_position4d.w * plane.normal.x
  sme[7] = -light_position4d.w * plane.normal.y
  sme[11] = -light_position4d.w * plane.normal.z
  sme[15] = dot - light_position4d.w * -plane.constant
  object.matrix.multiply_matrices(
    _shadow_mesh_shadow_matrix,
    shadow_mesh.mesh_matrix,
  )
  |> ignore
}
