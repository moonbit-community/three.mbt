// Upstream src/cameras/CubeCamera.js. `CubeCamera` is the payload struct, so
// `CubeCamera::new` returns the `Object3D` that holds it.

///|
/// negative fov is not an error
const CUBE_CAMERA_FOV : Double = -90.0

///|
const CUBE_CAMERA_ASPECT : Double = 1.0

///|
/// The renderer members `CubeCamera.update` calls. Core cannot name renderer types, so
/// `WebGLRenderer` and the WebGPU renderer implement this above core.
pub(open) trait CubeCameraRenderer {
  /// `renderer.coordinateSystem`.
  fn coordinate_system(Self) -> Int32
  /// `renderer.getRenderTarget()`.
  fn get_render_target(Self) -> RenderTarget?
  /// `renderer.getActiveCubeFace()`.
  fn get_active_cube_face(Self) -> Int32
  /// `renderer.getActiveMipmapLevel()`.
  fn get_active_mipmap_level(Self) -> Int32
  /// `renderer.xr.enabled`.
  fn xr_enabled(Self) -> Bool
  /// `renderer.xr.enabled = value`.
  fn set_xr_enabled(Self, Bool) -> Unit
  /// `renderer.state.buffers.depth.getReversed()` on `WebGLRenderer`, otherwise
  /// `renderer.reversedDepthBuffer`.
  fn reversed_depth_buffer(Self) -> Bool
  /// `renderer.autoClear`.
  fn auto_clear(Self) -> Bool
  /// `renderer.setRenderTarget( renderTarget, activeCubeFace, activeMipmapLevel )`.
  fn set_render_target(Self, RenderTarget?, Int32, Int32) -> Unit
  /// `renderer.clearDepth()`.
  fn clear_depth(Self) -> Unit
  /// `renderer.render( scene, camera )`.
  fn render(Self, Object3D, Object3D) -> Unit
}

///|
/// `new CubeCamera( near, far, renderTarget )`.
pub fn CubeCamera::new(
  near~ : Double = 0.1,
  far~ : Double = 2000.0,
  render_target? : RenderTarget,
) -> Object3D {
  let cube_camera = Object3D::new(
    kind=CubeCamera({
      render_target,
      coordinate_system: None,
      active_mipmap_level: 0,
    }),
    type_="CubeCamera",
  )
  for _ in 0..<6 {
    let camera = PerspectiveCamera::new(
      fov=CUBE_CAMERA_FOV,
      aspect=CUBE_CAMERA_ASPECT,
      near~,
      far~,
    )
    camera.layers = cube_camera.layers
    ignore(cube_camera.add(camera))
  }
  cube_camera
}

///|
/// The `CubeCamera` data. Aborts on other kinds.
pub fn Object3D::as_cube_camera(self : Object3D) -> CubeCamera {
  guard self.kind is CubeCamera(cube_camera) else {
    abort("Object3D: not a CubeCamera")
  }
  cube_camera
}

///|
fn cube_camera_face_look_at(
  camera : Object3D,
  up_x : Double,
  up_y : Double,
  up_z : Double,
  x : Double,
  y : Double,
  z : Double,
) -> Unit {
  ignore(camera.up.set(up_x, up_y, up_z))
  camera.look_at_xyz(x, y, z)
}

///|
/// `cubeCamera.updateCoordinateSystem()`.
pub fn Object3D::update_coordinate_system(self : Object3D) -> Unit {
  let coordinate_system = self.as_cube_camera().coordinate_system
  let cameras = self.children.copy()
  let camera_px = cameras[0]
  let camera_nx = cameras[1]
  let camera_py = cameras[2]
  let camera_ny = cameras[3]
  let camera_pz = cameras[4]
  let camera_nz = cameras[5]
  for camera in cameras {
    ignore(self.remove(camera))
  }
  if coordinate_system == Some(WebGLCoordinateSystem) {
    cube_camera_face_look_at(camera_px, 0, 1, 0, 1, 0, 0)
    cube_camera_face_look_at(camera_nx, 0, 1, 0, -1, 0, 0)
    cube_camera_face_look_at(camera_py, 0, 0, -1, 0, 1, 0)
    cube_camera_face_look_at(camera_ny, 0, 0, 1, 0, -1, 0)
    cube_camera_face_look_at(camera_pz, 0, 1, 0, 0, 0, 1)
    cube_camera_face_look_at(camera_nz, 0, 1, 0, 0, 0, -1)
  } else if coordinate_system == Some(WebGPUCoordinateSystem) {
    cube_camera_face_look_at(camera_px, 0, -1, 0, -1, 0, 0)
    cube_camera_face_look_at(camera_nx, 0, -1, 0, 1, 0, 0)
    cube_camera_face_look_at(camera_py, 0, 0, 1, 0, 1, 0)
    cube_camera_face_look_at(camera_ny, 0, 0, -1, 0, -1, 0)
    cube_camera_face_look_at(camera_pz, 0, -1, 0, 0, 0, 1)
    cube_camera_face_look_at(camera_nz, 0, -1, 0, 0, 0, -1)
  } else {
    let name = match coordinate_system {
      Some(value) => value.to_string()
      None => "null"
    }
    abort(
      "THREE.CubeCamera.updateCoordinateSystem(): Invalid coordinate system: " +
      name,
    )
  }
  for camera in cameras {
    ignore(self.add(camera))
    camera.update_matrix_world()
  }
}

///|
/// `cubeCamera.update( renderer, scene )`, named apart from `LOD.update`, which also
/// lives on `Object3D`.
pub fn Object3D::update_cube_camera(
  self : Object3D,
  renderer : &CubeCameraRenderer,
  scene : Object3D,
) -> Unit {
  if self.parent is None {
    self.update_matrix_world()
  }
  let cube_camera = self.as_cube_camera()
  let render_target = cube_camera.render_target
  let active_mipmap_level = cube_camera.active_mipmap_level
  if cube_camera.coordinate_system != Some(renderer.coordinate_system()) {
    cube_camera.coordinate_system = Some(renderer.coordinate_system())
    self.update_coordinate_system()
  }
  let camera_px = self.children[0]
  let camera_nx = self.children[1]
  let camera_py = self.children[2]
  let camera_ny = self.children[3]
  let camera_pz = self.children[4]
  let camera_nz = self.children[5]
  let current_render_target = renderer.get_render_target()
  let current_active_cube_face = renderer.get_active_cube_face()
  let current_active_mipmap_level = renderer.get_active_mipmap_level()
  let current_xr_enabled = renderer.xr_enabled()
  renderer.set_xr_enabled(false)
  guard render_target is Some(target) else {
    abort("CubeCamera.update: renderTarget is not set")
  }
  let texture = target.textures[0]
  let mipmaps_auto_update = texture.mipmaps_auto_update
  texture.mipmaps_auto_update = false
  // https://github.com/mrdoob/three.js/issues/31413#issuecomment-3095966812
  let reversed_depth_buffer = renderer.reversed_depth_buffer()
  fn render_face(face : Int32, camera : Object3D) -> Unit {
    renderer.set_render_target(render_target, face, active_mipmap_level)
    if reversed_depth_buffer && !renderer.auto_clear() {
      renderer.clear_depth()
    }
    renderer.render(scene, camera)
  }

  render_face(0, camera_px)
  render_face(1, camera_nx)
  render_face(2, camera_py)
  render_face(3, camera_ny)
  render_face(4, camera_pz)
  // mipmaps are generated during the last call of render()
  // at this point, all sides of the cube render target are defined
  texture.mipmaps_auto_update = mipmaps_auto_update
  render_face(5, camera_nz)
  renderer.set_render_target(
    current_render_target, current_active_cube_face, current_active_mipmap_level,
  )
  renderer.set_xr_enabled(current_xr_enabled)
  // `texture.needsPMREMUpdate = true`
  texture.pmrem_version += 1
}

///|
/// `new this.constructor()`.
fn hook_cube_camera_new_like(_object : Object3D) -> Object3D {
  CubeCamera::new()
}
