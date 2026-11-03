// Upstream src/renderers/webgl/WebGLClipping.js. `uniform` is a core `Uniform` whose
// value is the plane array (`TypedArray`) or `Null`; its `needsUpdate` is kept with
// `set_uniform_needs_update`.

///|
pub struct WebGLClipping {
  properties : WebGLProperties
  mut global_state : @core.TypedArray?
  mut num_global_planes : Int32
  mut local_clipping_enabled : Bool
  mut rendering_shadows : Bool
  plane : @math.Plane
  view_normal_matrix : @math.Matrix3
  /// `{ value, needsUpdate }`, assigned to materials' `clippingPlanes` uniform
  uniform : @core.Uniform
  mut num_planes : Int32
  mut num_intersection : Int32
}

///|
/// `new WebGLClipping( properties )`.
pub fn WebGLClipping::new(properties : WebGLProperties) -> WebGLClipping {
  let uniform = @core.Uniform::new(Null)
  set_uniform_needs_update(uniform, false)
  {
    properties,
    global_state: None,
    num_global_planes: 0,
    local_clipping_enabled: false,
    rendering_shadows: false,
    plane: @math.Plane::new(),
    view_normal_matrix: @math.Matrix3::new(),
    uniform,
    num_planes: 0,
    num_intersection: 0,
  }
}

///|
fn WebGLClipping::uniform_array(self : WebGLClipping) -> @core.TypedArray? {
  match self.uniform.value {
    TypedArray(array) => Some(array)
    _ => None
  }
}

///|
fn WebGLClipping::set_uniform_array(
  self : WebGLClipping,
  array : @core.TypedArray?,
) -> Unit {
  self.uniform.value = match array {
    Some(array) => TypedArray(array)
    None => Null
  }
}

///|
/// `clipping.init( planes, enableLocalClipping )`.
pub fn WebGLClipping::init(
  self : WebGLClipping,
  planes : Array[@math.Plane],
  enable_local_clipping : Bool,
) -> Bool {
  let enabled = planes.length() != 0 ||
    enable_local_clipping ||
    // enable state of previous frame - the clipping code has to run another frame in
    // order to reset the state:
    self.num_global_planes != 0 ||
    self.local_clipping_enabled
  self.local_clipping_enabled = enable_local_clipping
  self.num_global_planes = planes.length()
  enabled
}

///|
/// `clipping.beginShadows()`.
pub fn WebGLClipping::begin_shadows(self : WebGLClipping) -> Unit {
  self.rendering_shadows = true
  ignore(self.project_planes(None, None, 0, false))
}

///|
/// `clipping.endShadows()`.
pub fn WebGLClipping::end_shadows(self : WebGLClipping) -> Unit {
  self.rendering_shadows = false
}

///|
/// `clipping.setGlobalState( planes, camera )`.
pub fn WebGLClipping::set_global_state(
  self : WebGLClipping,
  planes : Array[@math.Plane],
  camera : @core.Object3D,
) -> Unit {
  self.global_state = self.project_planes(Some(planes), Some(camera), 0, false)
}

///|
/// `clipping.setState( material, camera, useCache )`.
pub fn WebGLClipping::set_state(
  self : WebGLClipping,
  material : @core.Material,
  camera : @core.Object3D,
  use_cache : Bool,
) -> Unit {
  let planes = material.clipping_planes
  let clip_intersection = material.clip_intersection
  let clip_shadows = material.clip_shadows
  let material_properties = self.properties.get_material(material)
  let no_local = match planes {
    None => true
    Some(planes) => planes.length() == 0
  }
  if !self.local_clipping_enabled ||
    no_local ||
    (self.rendering_shadows && !clip_shadows) {
    // there's no local clipping
    if self.rendering_shadows {
      // there's no global clipping
      ignore(self.project_planes(None, None, 0, false))
    } else {
      self.reset_global_state()
    }
  } else {
    let n_global = if self.rendering_shadows {
      0
    } else {
      self.num_global_planes
    }
    let l_global = n_global * 4
    let dst_array = material_properties.clipping_state
    self.set_uniform_array(dst_array) // ensure unique state
    let dst_array = self.project_planes(
      planes,
      Some(camera),
      l_global,
      use_cache,
    )
    if dst_array is Some(dst) && self.global_state is Some(global_state) {
      for i in 0..<l_global {
        dst[i] = global_state[i]
      }
    }
    material_properties.clipping_state = dst_array
    self.num_intersection = if clip_intersection { self.num_planes } else { 0 }
    self.num_planes += n_global
  }
}

///|
fn WebGLClipping::reset_global_state(self : WebGLClipping) -> Unit {
  if !same_handle(self.uniform_array(), self.global_state) {
    self.set_uniform_array(self.global_state)
    set_uniform_needs_update(self.uniform, self.num_global_planes > 0)
  }
  self.num_planes = self.num_global_planes
  self.num_intersection = 0
}

///|
fn WebGLClipping::project_planes(
  self : WebGLClipping,
  planes : Array[@math.Plane]?,
  camera : @core.Object3D?,
  dst_offset : Int32,
  skip_transform : Bool,
) -> @core.TypedArray? {
  let n_planes = match planes {
    Some(planes) => planes.length()
    None => 0
  }
  let mut dst_array = None
  if n_planes != 0 {
    let planes = planes.unwrap()
    dst_array = self.uniform_array()
    if !skip_transform || dst_array is None {
      let flat_size = dst_offset + n_planes * 4
      let view_matrix = camera.unwrap().matrix_world_inverse()
      ignore(self.view_normal_matrix.get_normal_matrix(view_matrix))
      let dst = match dst_array {
        Some(dst) if dst.length() >= flat_size => dst
        _ => @core.TypedArray::float32(flat_size)
      }
      for i in 0..<n_planes {
        let i4 = dst_offset + i * 4
        ignore(
          self.plane
          .copy(planes[i])
          .apply_matrix4(
            view_matrix,
            optional_normal_matrix=self.view_normal_matrix,
          ),
        )
        dst[i4] = self.plane.normal.x
        dst[i4 + 1] = self.plane.normal.y
        dst[i4 + 2] = self.plane.normal.z
        dst[i4 + 3] = self.plane.constant
      }
      dst_array = Some(dst)
    }
    self.set_uniform_array(dst_array)
    set_uniform_needs_update(self.uniform, true)
  }
  self.num_planes = n_planes
  self.num_intersection = 0
  dst_array
}
