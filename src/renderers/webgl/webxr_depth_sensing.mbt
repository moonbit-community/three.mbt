// Upstream src/renderers/webxr/WebXRDepthSensing.js.

///|
let _webxr_depth_sensing_occlusion_vertex : String =
  #|
  #|void main() {
  #|
  #|	gl_Position = vec4( position, 1.0 );
  #|
  #|}

///|
let _webxr_depth_sensing_occlusion_fragment : String =
  #|
  #|uniform sampler2DArray depthColor;
  #|uniform float depthWidth;
  #|uniform float depthHeight;
  #|
  #|void main() {
  #|
  #|	vec2 coord = vec2( gl_FragCoord.x / depthWidth, gl_FragCoord.y / depthHeight );
  #|
  #|	if ( coord.x >= 1.0 ) {
  #|
  #|		gl_FragDepth = texture( depthColor, vec3( coord.x - 1.0, coord.y, 1 ) ).r;
  #|
  #|	} else {
  #|
  #|		gl_FragDepth = texture( depthColor, vec3( coord.x, coord.y, 0 ) ).r;
  #|
  #|	}
  #|
  #|}

///|
/// `WebXRDepthSensing`: the Depth Sensing API texture and its occlusion mesh.
pub struct WebXRDepthSensing {
  /// An `ExternalTexture` holding the depth of the user's environment.
  mut texture : @core.Texture?
  mut mesh : @core.Object3D?
  mut depth_near : Double
  mut depth_far : Double
}

///|
/// `new WebXRDepthSensing()`.
pub fn WebXRDepthSensing::new() -> WebXRDepthSensing {
  { texture: None, mesh: None, depth_near: 0.0, depth_far: 0.0, }
}

///|
/// `depthSensing.init( depthData, renderState )`.
pub fn WebXRDepthSensing::init(
  self : WebXRDepthSensing,
  depth_data : XRWebGLDepthInformation,
  render_state : XRRenderState,
) -> Unit {
  if self.texture is None {
    let texture = @core.ExternalTexture::new(
      external_source?=depth_data.texture().map(@core.JsValue::of),
    )
    if depth_data.depth_near() != render_state.depth_near() ||
      depth_data.depth_far() != render_state.depth_far() {
      self.depth_near = depth_data.depth_near()
      self.depth_far = depth_data.depth_far()
    }
    self.texture = Some(texture)
  }
}

///|
/// `depthSensing.getMesh( cameraXR )`: a plane writing the sensed depth.
pub fn WebXRDepthSensing::get_mesh(
  self : WebXRDepthSensing,
  camera_xr : @core.Object3D,
) -> @core.Object3D? {
  if self.texture is Some(texture) {
    if self.mesh is None {
      let first = match camera_xr.kind {
        Camera(
          { kind: PerspectiveCamera({ array_camera: Some(array), .. }), .. }
        ) => array.cameras[0]
        _ => abort("WebXRDepthSensing.getMesh: cameraXR is not an ArrayCamera")
      }
      let viewport = match camera_viewport(first) {
        Some(viewport) => viewport
        None => abort("WebXRDepthSensing.getMesh: camera without viewport")
      }
      let material = @core.ShaderMaterial::new()
      material.vertex_shader = Some(_webxr_depth_sensing_occlusion_vertex)
      material.fragment_shader = Some(_webxr_depth_sensing_occlusion_fragment)
      material.uniforms = Some(
        Map([
          ("depthColor", @core.Uniform::new(Texture(texture))),
          ("depthWidth", @core.Uniform::new(Number(viewport.z))),
          ("depthHeight", @core.Uniform::new(Number(viewport.w))),
        ]),
      )
      self.mesh = Some(
        @core.Mesh::new(
          geometry=@geometries.PlaneGeometry::new(width=20, height=20),
          material=Single(material),
        ),
      )
    }
  }
  self.mesh
}

///|
/// `depthSensing.reset()`.
pub fn WebXRDepthSensing::reset(self : WebXRDepthSensing) -> Unit {
  self.texture = None
  self.mesh = None
}

///|
/// `depthSensing.getDepthTexture()`.
pub fn WebXRDepthSensing::get_depth_texture(
  self : WebXRDepthSensing,
) -> @core.Texture? {
  self.texture
}
