// renderers/common/ClippingContext.js

///|
let _clipping_context_plane : @math.Plane = @math.Plane::new()

///|
let _clipping_context_id : Ref[Int32] = Ref(0)

///|
/// The clipping planes in effect for a scene and its clipping groups, in view space.
pub(all) struct ClippingContext {
  id : Int32
  mut version : Int32
  /// `null` until a clipping group sets it.
  mut clip_intersection : Bool?
  mut cache_key : String
  mut shadow_pass : Bool
  mut view_matrix : @math.Matrix4
  mut view_normal_matrix : @math.Matrix3
  mut clipping_group_contexts : @webgl.WeakMap[@core.Object3D, ClippingContext]
  mut intersection_planes : Array[@math.Vector4]
  mut union_planes : Array[@math.Vector4]
  /// `null` until synchronized with the parent context.
  mut parent_version : Int32?
}

///|
/// `new ClippingContext( parentContext = null )`.
pub fn ClippingContext::new(
  parent_context? : ClippingContext,
) -> ClippingContext {
  let id = _clipping_context_id.val
  _clipping_context_id.val += 1
  let context : ClippingContext = {
    id,
    version: 0,
    clip_intersection: None,
    cache_key: "",
    shadow_pass: false,
    view_matrix: @math.Matrix4::new(),
    view_normal_matrix: @math.Matrix3::new(),
    clipping_group_contexts: @webgl.WeakMap::new(),
    intersection_planes: [],
    union_planes: [],
    parent_version: None,
  }
  match parent_context {
    Some(parent) => {
      context.view_matrix = parent.view_matrix
      context.view_normal_matrix = parent.view_normal_matrix
      context.clipping_group_contexts = parent.clipping_group_contexts
      context.shadow_pass = parent.shadow_pass
    }
    None => ()
  }
  context
}

///|
/// `projectPlanes( source, destination, offset )`: view-space planes as vectors.
pub fn ClippingContext::project_planes(
  self : ClippingContext,
  source : Array[@math.Plane],
  destination : Array[@math.Vector4],
  offset : Int32,
) -> Unit {
  let l = source.length()
  for i in 0..<l {
    _clipping_context_plane
    .copy(source[i])
    .apply_matrix4(
      self.view_matrix,
      optional_normal_matrix=self.view_normal_matrix,
    )
    |> ignore
    let v = destination[offset + i]
    let normal = _clipping_context_plane.normal
    v.x = -normal.x
    v.y = -normal.y
    v.z = -normal.z
    v.w = _clipping_context_plane.constant
  }
}

///|
/// `updateGlobal( scene, camera )`.
pub fn ClippingContext::update_global(
  self : ClippingContext,
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  self.shadow_pass = match scene.kind {
    Scene({ override_material: Some(m), .. }) =>
      m.has_extension_flag("isShadowPassMaterial")
    _ => false
  }
  if camera.is_array_camera() {
    self.view_matrix.identity() |> ignore
  } else {
    match camera.kind {
      Camera(c) => self.view_matrix.copy(c.matrix_world_inverse) |> ignore
      _ =>
        abort(
          "TypeError: Cannot read properties of undefined (reading 'elements')",
        )
    }
  }
  self.view_normal_matrix.get_normal_matrix(self.view_matrix) |> ignore
}

///|
/// The `ClippingGroup` payload of a clipping group.
fn _clipping_context_group(
  clipping_group : @core.Object3D,
) -> @core.ClippingGroup {
  match clipping_group.kind {
    ClippingGroup(g) => g
    _ => abort("ClippingContext: not a ClippingGroup")
  }
}

///|
/// `update( parentContext, clippingGroup )`.
pub fn ClippingContext::update(
  self : ClippingContext,
  parent_context : ClippingContext,
  clipping_group : @core.Object3D,
) -> Unit {
  let group = _clipping_context_group(clipping_group)
  let mut update = false
  if Some(parent_context.version) != self.parent_version {
    self.intersection_planes = parent_context.intersection_planes.copy()
    self.union_planes = parent_context.union_planes.copy()
    self.parent_version = Some(parent_context.version)
  }
  if self.clip_intersection != Some(group.clip_intersection) {
    self.clip_intersection = Some(group.clip_intersection)
    if group.clip_intersection {
      _clipping_context_set_length(
        self.union_planes,
        parent_context.union_planes.length(),
      )
    } else {
      _clipping_context_set_length(
        self.intersection_planes,
        parent_context.intersection_planes.length(),
      )
    }
  }
  let src_clipping_planes = group.clipping_planes
  let l = src_clipping_planes.length()
  let (dst_clipping_planes, offset) = if group.clip_intersection {
    (self.intersection_planes, parent_context.intersection_planes.length())
  } else {
    (self.union_planes, parent_context.union_planes.length())
  }
  if dst_clipping_planes.length() != offset + l {
    _clipping_context_set_length(dst_clipping_planes, offset + l)
    for i in 0..<l {
      dst_clipping_planes[offset + i] = @math.Vector4::new(0.0, 0.0, 0.0, 0.0)
    }
    update = true
  }
  self.project_planes(src_clipping_planes, dst_clipping_planes, offset)
  if update {
    self.version += 1
    self.cache_key = "\{self.id}:\{self.intersection_planes.length()}:\{self.union_planes.length()}"
  }
}

///|
/// `array.length = n`: truncates, or grows with new vectors (upstream's holes are
/// always overwritten before use).
fn _clipping_context_set_length(
  array : Array[@math.Vector4],
  n : Int32,
) -> Unit {
  if array.length() > n {
    array.truncate(n)
  } else {
    while array.length() < n {
      array.push(@math.Vector4::new(0.0, 0.0, 0.0, 0.0))
    }
  }
}

///|
/// `getGroupContext( clippingGroup )`: the context of a clipping group below this one.
pub fn ClippingContext::get_group_context(
  self : ClippingContext,
  clipping_group : @core.Object3D,
) -> ClippingContext {
  let group = _clipping_context_group(clipping_group)
  if self.shadow_pass && !group.clip_shadows {
    return self
  }
  let context = match self.clipping_group_contexts.get(clipping_group) {
    Some(c) => c
    None => {
      let c = ClippingContext::new(parent_context=self)
      self.clipping_group_contexts.set(clipping_group, c)
      c
    }
  }
  context.update(self, clipping_group)
  context
}

///|
/// `get unionClippingCount()`.
pub fn ClippingContext::union_clipping_count(self : ClippingContext) -> Int32 {
  self.union_planes.length()
}
