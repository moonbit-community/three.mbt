// Types for upstream src/objects and `Object3D`. A class's data sits in the payload of
// `Object3DKind`; subclass chains nest (`Mesh` -> `MeshKind`). Classes above core keep
// their data behind `Object3D.extension`, alongside whatever `kind` they extend.

///|
pub(all) struct Object3D {
  id : Int32
  dispatcher : EventDispatcher
  mut uuid : String
  mut name : String
  mut type_ : String
  mut parent : Object3D?
  mut children : Array[Object3D]
  mut up : @math.Vector3
  position : @math.Vector3
  rotation : @math.Euler
  quaternion : @math.Quaternion
  scale : @math.Vector3
  model_view_matrix : @math.Matrix4
  normal_matrix : @math.Matrix3
  mut matrix : @math.Matrix4
  mut matrix_world : @math.Matrix4
  mut matrix_auto_update : Bool
  mut matrix_world_auto_update : Bool
  mut matrix_world_needs_update : Bool
  mut layers : Layers
  mut visible : Bool
  mut cast_shadow : Bool
  mut receive_shadow : Bool
  mut frustum_culled : Bool
  mut render_order : Double
  /// `AnimationClip`s, which live above core.
  mut animations : Array[&SerializableResource]
  mut custom_depth_material : Material?
  mut custom_distance_material : Material?
  mut static_ : Bool
  mut user_data : JsValue
  mut pivot : @math.Vector3?
  // Renderer callbacks. The first argument of each is the renderer, opaque to core.
  mut on_before_shadow : (
    JsValue,
    Object3D,
    Object3D,
    Object3D,
    BufferGeometry,
    Material,
    GeometryGroup?,
  ) -> Unit
  mut on_after_shadow : (
    JsValue,
    Object3D,
    Object3D,
    Object3D,
    BufferGeometry,
    Material,
    GeometryGroup?,
  ) -> Unit
  mut on_before_render : (
    JsValue,
    Object3D,
    Object3D,
    BufferGeometry,
    Material,
    GeometryGroup?,
  ) -> Unit
  mut on_after_render : (
    JsValue,
    Object3D,
    Object3D,
    BufferGeometry,
    Material,
    GeometryGroup?,
  ) -> Unit
  mut kind : Object3DKind
  mut extension : &Object3DExtension?
}

///|
/// The class of an `Object3D` defined in core, carrying its data.
pub(all) enum Object3DKind {
  /// A plain `Object3D`.
  Base
  Group
  ClippingGroup(ClippingGroup)
  Bone
  Mesh(Mesh)
  Line(Line)
  Points(Points)
  Sprite(Sprite)
  LOD(LOD)
  Camera(Camera)
  CubeCamera(CubeCamera)
  Light(Light)
  Scene(Scene)
}

///|
pub(all) struct ClippingGroup {
  mut clipping_planes : Array[@math.Plane]
  mut enabled : Bool
  mut clip_intersection : Bool
  mut clip_shadows : Bool
}

///|
/// `object.material`: one material, or an array used with geometry groups.
pub(all) enum MaterialSlot {
  Single(Material)
  Multiple(Array[Material])
}

///|
/// The subclass of a `Mesh`.
pub(all) enum MeshKind {
  PlainMesh
  SkinnedMesh(SkinnedMesh)
  InstancedMesh(InstancedMesh)
  BatchedMesh(BatchedMesh)
}

///|
pub(all) struct Mesh {
  mut geometry : BufferGeometry
  mut material : MaterialSlot
  mut morph_target_dictionary : Map[String, Int32]?
  mut morph_target_influences : Array[Double]?
  /// `InstancedMesh.count` shares this field.
  mut count : Int32
  mut kind : MeshKind
}

///|
pub(all) struct SkinnedMesh {
  mut bind_mode : String
  mut bind_matrix : @math.Matrix4
  mut bind_matrix_inverse : @math.Matrix4
  mut bounding_box : @math.Box3?
  mut bounding_sphere : @math.Sphere?
  mut skeleton : Skeleton?
}

///|
pub(all) struct InstancedMesh {
  mut instance_matrix : BufferAttribute
  mut instance_color : BufferAttribute?
  mut morph_texture : Texture?
  mut bounding_box : @math.Box3?
  mut bounding_sphere : @math.Sphere?
}

///|
/// One entry of `BatchedMesh._instanceInfo`.
pub(all) struct BatchedInstanceInfo {
  mut visible : Bool
  mut active : Bool
  mut geometry_index : Int32
}

///|
/// One entry of `BatchedMesh._geometryInfo`.
pub(all) struct BatchedGeometryInfo {
  mut vertex_start : Int32
  mut vertex_count : Int32
  mut reserved_vertex_count : Int32
  mut index_start : Int32
  mut index_count : Int32
  mut reserved_index_count : Int32
  mut start : Int32
  mut count : Int32
  mut bounding_box : @math.Box3?
  mut bounding_sphere : @math.Sphere?
  mut active : Bool
}

///|
/// One `{ start, count, z, index }` entry of the list `customSort` receives.
pub(all) struct MultiDrawItem {
  mut start : Int32
  mut count : Int32
  mut z : Double
  mut index : Int32
}

///|
pub(all) struct BatchedMesh {
  mut per_object_frustum_culled : Bool
  mut sort_objects : Bool
  mut bounding_box : @math.Box3?
  mut bounding_sphere : @math.Sphere?
  mut custom_sort : ((Array[MultiDrawItem], Object3D) -> Unit)?
  mut _instance_info : Array[BatchedInstanceInfo]
  mut _geometry_info : Array[BatchedGeometryInfo]
  mut _available_instance_ids : Array[Int32]
  mut _available_geometry_ids : Array[Int32]
  mut _next_index_start : Int32
  mut _next_vertex_start : Int32
  mut _geometry_count : Int32
  mut _visibility_changed : Bool
  mut _geometry_initialized : Bool
  mut _max_instance_count : Int32
  mut _max_vertex_count : Int32
  mut _max_index_count : Int32
  mut _multi_draw_counts : TypedArray
  mut _multi_draw_starts : TypedArray
  mut _multi_draw_count : Int32
  mut _multi_draw_bytes_per_element : Int32
  mut _merged_draw_counts : TypedArray
  mut _merged_draw_starts : TypedArray
  mut _merged_draw_instance_counts : TypedArray
  mut _merged_draw_count : Int32
  mut _matrices_texture : Texture?
  mut _indirect_texture : Texture?
  mut _colors_texture : Texture?
  mut _previous_matrices_texture : Texture?
}

///|
/// The subclass of a `Line`.
pub(all) enum LineKind {
  PlainLine
  LineLoop
  LineSegments
}

///|
pub(all) struct Line {
  mut geometry : BufferGeometry
  mut material : MaterialSlot
  mut morph_target_dictionary : Map[String, Int32]?
  mut morph_target_influences : Array[Double]?
  mut kind : LineKind
}

///|
pub(all) struct Points {
  mut geometry : BufferGeometry
  mut material : MaterialSlot
  mut morph_target_dictionary : Map[String, Int32]?
  mut morph_target_influences : Array[Double]?
}

///|
pub(all) struct Sprite {
  mut geometry : BufferGeometry
  mut material : Material
  mut center : @math.Vector2
  mut count : Int32
}

///|
pub(all) struct LODLevel {
  mut object : Object3D
  mut distance : Double
  mut hysteresis : Double
}

///|
pub(all) struct LOD {
  mut _current_level : Int32
  levels : Array[LODLevel]
  mut auto_update : Bool
}

///|
pub(all) struct Skeleton {
  mut uuid : String
  mut bones : Array[Object3D]
  mut bone_inverses : Array[@math.Matrix4]
  mut bone_matrices : TypedArray?
  mut previous_bone_matrices : TypedArray?
  mut bone_texture : Texture?
  mut previous_bone_texture : Texture?
}
