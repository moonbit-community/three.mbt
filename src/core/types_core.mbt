// Types for upstream src/core. Fields keep upstream names in snake_case; a leading
// underscore marks upstream's private `_foo` fields. Upstream's keyword-named members
// take a trailing underscore: `type_`, `static_`, `Layers::test_`.

///|
/// Listener storage. Types extending upstream `EventDispatcher` hold one of these and
/// implement `EventSource`.
pub(all) struct EventDispatcher {
  mut _listeners : Map[String, Array[(Event) -> Unit]]?
}

///|
/// The `{ type, target, ... }` object passed to listeners.
pub(all) struct Event {
  mut type_ : String
  mut target : EventTarget?
  /// `child` of `childadded` and `childremoved`.
  mut child : Object3D?
  /// Any other payload, for events defined above core.
  mut data : JsValue?
}

///|
/// What `event.target` can be. `Other` is for dispatchers defined above core.
pub(all) enum EventTarget {
  Dispatcher(EventDispatcher)
  Object3D(Object3D)
  BufferAttribute(BufferAttribute)
  BufferGeometry(BufferGeometry)
  Material(Material)
  Texture(Texture)
  RenderTarget(RenderTarget)
  UniformsGroup(UniformsGroup)
  Other(JsValue)
}

///|
/// Bitmask layers. `mask` is a `Double` because `set( 31 )` stores 2147483648 upstream.
pub(all) struct Layers {
  mut mask : Double
}

///|
pub(all) struct UpdateRange {
  mut start : Int32
  mut count : Int32
}

///|
/// The subclass of a `BufferAttribute`. `Storage*` are the renderers/common subclasses,
/// which add no fields; they sit here so `clone` keeps them.
pub(all) enum BufferAttributeKind {
  PlainAttribute
  Float16Attribute
  InstancedAttribute
  StorageAttribute
  StorageInstancedAttribute
}

///|
/// Upstream `BufferAttribute` and all its typed subclasses, plus
/// `InstancedBufferAttribute` (`mesh_per_attribute`).
pub(all) struct BufferAttribute {
  id : Int32
  dispatcher : EventDispatcher
  mut name : String
  mut array : TypedArray
  mut item_size : Int32
  mut count : Int32
  mut normalized : Bool
  mut usage : Int32
  mut update_ranges : Array[UpdateRange]
  mut gpu_type : Int32
  mut version : Int32
  mut on_upload_callback : () -> Unit
  mut _normalization_scale : Double?
  mut kind : BufferAttributeKind
  mut mesh_per_attribute : Int32
}

///|
/// Upstream `InterleavedBuffer` and `InstancedInterleavedBuffer`.
pub(all) struct InterleavedBuffer {
  mut array : TypedArray
  mut stride : Int32
  mut count : Int32
  mut usage : Int32
  mut update_ranges : Array[UpdateRange]
  mut version : Int32
  mut uuid : String
  mut on_upload_callback : () -> Unit
  mut is_instanced_interleaved_buffer : Bool
  mut mesh_per_attribute : Int32
}

///|
pub(all) struct InterleavedBufferAttribute {
  mut name : String
  mut data : InterleavedBuffer
  mut item_size : Int32
  mut offset : Int32
  mut normalized : Bool
  mut _normalization_scale : Double?
}

///|
/// `buffer` is the `WebGLBuffer` the application created.
pub(all) struct GLBufferAttribute {
  mut name : String
  mut buffer : JsValue
  mut type_ : Int32
  mut item_size : Int32
  mut element_size : Int32
  mut count : Int32
  mut normalized : Bool
  mut version : Int32
}

///|
/// What `geometry.attributes[ name ]` can hold.
pub(all) enum GeometryAttribute {
  Buffer(BufferAttribute)
  Interleaved(InterleavedBufferAttribute)
  GL(GLBufferAttribute)
}

///|
/// The `data` argument of `clone( data )`: copies shared across one geometry copy.
pub(all) struct AttributeCloneData {
  array_buffers : Map[String, ArrayBuffer]
  interleaved_buffers : Map[String, InterleavedBuffer]
}

///|
/// `count` is `Double` because `Infinity` is valid.
pub(all) struct GeometryGroup {
  mut start : Int32
  mut count : Double
  mut material_index : Int32
}

///|
/// `count` is `Double` because it defaults to `Infinity`.
pub(all) struct DrawRange {
  mut start : Int32
  mut count : Double
}

///|
/// What a `geometries` subclass stores in `parameters`. `values` are serialized as they
/// are; `shapes` hold `extras.Shape` values, which live above core. Values upstream holds
/// by reference are added with `set_lazy`; read any value with `get`.
pub(all) struct GeometryParameters {
  values : Map[String, Json]
  shapes : Array[&SerializableResource]
}

///|
/// Upstream `BufferGeometry` and `InstancedBufferGeometry`. Subclasses in `geometries`
/// set `type_` and `parameters` in their constructors.
pub(all) struct BufferGeometry {
  id : Int32
  dispatcher : EventDispatcher
  mut uuid : String
  mut name : String
  mut type_ : String
  mut index : GeometryAttribute?
  mut indirect : BufferAttribute?
  /// Upstream's number-or-array, always as an array here.
  mut indirect_offset : Array[Int32]
  mut attributes : Map[String, GeometryAttribute]
  mut morph_attributes : Map[String, Array[GeometryAttribute]]
  mut morph_targets_relative : Bool
  mut groups : Array[GeometryGroup]
  mut bounding_box : @math.Box3?
  mut bounding_sphere : @math.Sphere?
  draw_range : DrawRange
  mut user_data : JsValue
  mut _transformed : Bool
  mut parameters : GeometryParameters?
  mut is_instanced_buffer_geometry : Bool
  /// `Double` because it defaults to `Infinity`.
  mut instance_count : Double
}

///|
/// The value of a `Uniform`. `Other` holds anything else, including types above core.
pub(all) enum UniformValue {
  Null
  Bool(Bool)
  Int(Int32)
  Number(Double)
  Numbers(Array[Double])
  Vector2(@math.Vector2)
  Vector3(@math.Vector3)
  Vector4(@math.Vector4)
  Color(@math.Color)
  Quaternion(@math.Quaternion)
  Matrix3(@math.Matrix3)
  Matrix4(@math.Matrix4)
  Plane(@math.Plane)
  Texture(Texture)
  TypedArray(TypedArray)
  Array(Array[UniformValue])
  Struct(Map[String, UniformValue])
  Other(JsValue)
}

///|
pub(all) struct Uniform {
  mut value : UniformValue
}

///|
/// One entry of `UniformsGroup.uniforms`: a uniform or an array of them.
pub(all) enum UniformsGroupEntry {
  Single(Uniform)
  Multiple(Array[Uniform])
}

///|
pub(all) struct UniformsGroup {
  id : Int32
  dispatcher : EventDispatcher
  mut name : String
  mut usage : Int32
  mut uniforms : Array[UniformsGroupEntry]
}

///|
pub(all) struct Clock {
  mut auto_start : Bool
  mut start_time : Double
  mut old_time : Double
  mut elapsed_time : Double
  mut running : Bool
}

///|
pub(all) struct Timer {
  mut _previous_time : Double
  mut _current_time : Double
  mut _start_time : Double
  mut _delta : Double
  mut _elapsed : Double
  mut _timescale : Double
  /// The DOM `document`.
  mut _document : JsValue?
  /// The DOM event handler.
  mut _page_visibility_handler : JsValue?
}

///|
/// The class of a `RenderTarget`; subclasses above core use `Plain` plus `extension`.
pub(all) enum RenderTargetType {
  PlainRenderTarget
  RenderTarget3D
}

///|
pub(all) struct RenderTarget {
  dispatcher : EventDispatcher
  mut width : Int32
  mut height : Int32
  mut depth : Int32
  scissor : @math.Vector4
  mut scissor_test : Bool
  viewport : @math.Vector4
  mut textures : Array[Texture]
  mut depth_buffer : Bool
  mut stencil_buffer : Bool
  mut resolve_color_buffer : Bool
  mut resolve_depth_buffer : Bool
  mut resolve_stencil_buffer : Bool
  mut store_multisampled_color_buffer : Bool
  mut store_multisampled_depth_buffer : Bool
  mut store_multisampled_stencil_buffer : Bool
  mut _depth_texture : Texture?
  mut samples : Int32
  mut multiview : Bool
  mut use_array_depth_texture : Bool
  mut render_target_type : RenderTargetType
  mut extension : &RenderTargetExtension?
}

///|
/// `params.Line` and `params.Points`.
pub(all) struct RaycasterThreshold {
  mut threshold : Double
}

///|
/// `Mesh`, `LOD` and `Sprite` are empty JS objects upstream, free for custom use.
pub(all) struct RaycasterParams {
  mut mesh : JsValue
  line : RaycasterThreshold
  mut lod : JsValue
  points : RaycasterThreshold
  mut sprite : JsValue
}

///|
pub(all) struct Raycaster {
  mut ray : @math.Ray
  mut near : Double
  mut far : Double
  mut camera : Object3D?
  mut layers : Layers
  mut params : RaycasterParams
}

///|
/// The `face` of an intersection.
pub(all) struct Face {
  mut a : Int32
  mut b : Int32
  mut c : Int32
  mut normal : @math.Vector3
  mut material_index : Int32
}

///|
/// One result of `Object3D::raycast`. Fields no class sets are `None`.
pub(all) struct Intersection {
  mut distance : Double
  mut distance_to_ray : Double?
  mut point : @math.Vector3
  mut index : Int32?
  mut face : Face?
  mut face_index : Int32?
  mut barycoord : @math.Vector3?
  mut uv : @math.Vector2?
  mut uv1 : @math.Vector2?
  mut normal : @math.Vector3?
  mut instance_id : Int32?
  mut batch_id : Int32?
  mut object : Object3D
}

///|
/// The hash upstream passes as `meta` through `toJSON`.
pub(all) struct ToJsonMeta {
  geometries : Map[String, Json]
  materials : Map[String, Json]
  textures : Map[String, Json]
  images : Map[String, Json]
  shapes : Map[String, Json]
  skeletons : Map[String, Json]
  animations : Map[String, Json]
  nodes : Map[String, Json]
}
