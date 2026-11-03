// Upstream examples/jsm/objects/Lensflare.js: a lens flare for WebGLRenderer. In its
// `onBeforeRender` it copies the framebuffer around the light, draws an occlusion test
// quad, restores the pixels and draws each `LensflareElement` additively.

///|
/// `Lensflare.Geometry`, created on first use (upstream: when the module loads).
let _lensflare_geometry : Ref[@core.BufferGeometry?] = Ref(None)

///|
/// Creates the module-level `Lensflare.Geometry`, as importing Lensflare.js does.
pub fn load_lensflare() -> Unit {
  Lensflare::geometry() |> ignore
}

///|
/// `Lensflare.Geometry`: a quad with interleaved positions and uvs.
pub fn Lensflare::geometry() -> @core.BufferGeometry {
  match _lensflare_geometry.val {
    Some(geometry) => geometry
    None => {
      let geometry = lensflare_quad_geometry()
      _lensflare_geometry.val = Some(geometry)
      geometry
    }
  }
}

///|
/// The quad of `Lensflare.Geometry` and `LensflareMesh.Geometry`.
fn lensflare_quad_geometry() -> @core.BufferGeometry {
  let geometry = @core.BufferGeometry::new()
  let float32_array = @core.TypedArray::float32([
    -1.0, -1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0,
    -1.0, 1.0, 0.0, 0.0, 1.0,
  ])
  let interleaved_buffer = @core.InterleavedBuffer::new(float32_array, 5)
  geometry.set_index([0, 1, 2, 0, 2, 3]) |> ignore
  geometry.set_attribute(
    "position",
    @core.InterleavedBufferAttribute::new(
      interleaved_buffer,
      3,
      0,
      normalized=false,
    ),
  )
  |> ignore
  geometry.set_attribute(
    "uv",
    @core.InterleavedBufferAttribute::new(
      interleaved_buffer,
      2,
      3,
      normalized=false,
    ),
  )
  |> ignore
  geometry
}

///|
/// `new LensflareElement( texture, size, distance, color )`: one flare sprite; `distance`
/// runs from the light (0) through the screen center (1). LensflareMesh.js's identical
/// class is the same type here.
pub(all) struct LensflareElement {
  mut texture : @core.Texture
  mut size : Double
  mut distance : Double
  mut color : @math.Color
}

///|
pub fn LensflareElement::new(
  texture : @core.Texture,
  size~ : Double = 1.0,
  distance~ : Double = 0.0,
  color? : @math.Color,
) -> LensflareElement {
  let color = match color {
    Some(c) => c
    None => @math.Color::from_hex(0xffffff)
  }
  { texture, size, distance, color, }
}

///|
/// `LensflareElement.Shader`.
pub let lensflare_element_shader : ShaderDefinition = {
  name: Some("LensflareElementShader"),
  uniforms: Map([
    ("map", { value: Null, }),
    ("occlusionMap", { value: Null, }),
    ("color", { value: Null, }),
    ("scale", { value: Null, }),
    ("screenPosition", { value: Null, }),
  ]),
  vertex_shader: _lensflare_element_vertex_shader,
  fragment_shader: _lensflare_element_fragment_shader,
}

///|
/// The state upstream keeps in the constructor's closure.
pub(all) struct Lensflare {
  position_screen : @math.Vector3
  position_view : @math.Vector3
  temp_map : @core.Texture
  occlusion_map : @core.Texture
  mut current_type : Int32
  material1a : @core.Material
  material1b : @core.Material
  mesh1 : @core.Object3D
  elements : Array[LensflareElement]
  material2 : @core.Material
  mesh2 : @core.Object3D
  scale : @math.Vector2
  screen_position_pixels : @math.Vector2
  valid_area : @math.Box2
  viewport : @math.Vector4
}

///|
pub impl @core.Object3DExtension for Lensflare with fn type_name(_) {
  "Lensflare"
}

///|
pub impl @core.Object3DExtension for Lensflare with fn construct(_) {
  Lensflare::new()
}

///|
pub impl @core.Object3DExtension for Lensflare with fn has_flag(_, flag) {
  flag == "isLensflare" || flag == "class:Lensflare"
}

///|
/// Upstream's instance `dispose`.
pub impl @core.Object3DExtension for Lensflare with fn dispose(self, _) {
  self.material1a.dispose()
  self.material1b.dispose()
  self.material2.dispose()
  self.temp_map.dispose()
  self.occlusion_map.dispose()
  for element in self.elements {
    element.texture.dispose()
  }
}

///|
#deprecated
pub extend Lensflare with @core.Object3DExtension::{
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
/// `new Lensflare()`: add it to a light and fill it with `add_element`.
pub fn Lensflare::new() -> @core.Object3D {
  let geometry = Lensflare::geometry()
  let base_material = @core.MeshBasicMaterial::new()
  base_material.opacity = 0.0
  base_material.transparent = true
  let object = @core.Mesh::new(geometry~, material=Single(base_material))
  object.frustum_culled = false
  object.render_order = 1.0 / 0.0
  //
  let position_screen = @math.Vector3::new(0.0, 0.0, 0.0)
  let position_view = @math.Vector3::new(0.0, 0.0, 0.0)
  // textures
  let temp_map = @core.FramebufferTexture::new(width=16, height=16)
  let occlusion_map = @core.FramebufferTexture::new(width=16, height=16)
  // material
  let material1a = @core.RawShaderMaterial::new()
  material1a.uniforms = Some(
    Map([("scale", { value: Null, }), ("screenPosition", { value: Null, })]),
  )
  material1a.vertex_shader = Some(_lensflare_1a_vertex_shader)
  material1a.fragment_shader = Some(_lensflare_1a_fragment_shader)
  material1a.depth_test = true
  material1a.depth_write = false
  material1a.transparent = false
  let material1b = @core.RawShaderMaterial::new()
  material1b.uniforms = Some(
    Map([
      ("map", { value: Texture(temp_map), }),
      ("scale", { value: Null, }),
      ("screenPosition", { value: Null, }),
    ]),
  )
  material1b.vertex_shader = Some(_lensflare_1b_vertex_shader)
  material1b.fragment_shader = Some(_lensflare_1b_fragment_shader)
  material1b.depth_test = false
  material1b.depth_write = false
  material1b.transparent = false
  // the following object is used for occlusionMap generation
  let mesh1 = @core.Mesh::new(geometry~, material=Single(material1a))
  //
  let shader = lensflare_element_shader
  let material2 = @core.RawShaderMaterial::new()
  material2.name = shader.name.unwrap()
  material2.uniforms = Some(
    Map([
      ("map", { value: Null, }),
      ("occlusionMap", { value: Texture(occlusion_map), }),
      ("color", { value: Color(@math.Color::from_hex(0xffffff)), }),
      ("scale", { value: Vector2(@math.Vector2::new(0.0, 0.0)), }),
      ("screenPosition", { value: Vector3(@math.Vector3::new(0.0, 0.0, 0.0)), }),
    ]),
  )
  material2.vertex_shader = Some(shader.vertex_shader)
  material2.fragment_shader = Some(shader.fragment_shader)
  material2.blending = @core.AdditiveBlending
  material2.transparent = true
  material2.depth_write = false
  let mesh2 = @core.Mesh::new(geometry~, material=Single(material2))
  let lensflare : Lensflare = {
    position_screen,
    position_view,
    temp_map,
    occlusion_map,
    current_type: @core.UnsignedByteType,
    material1a,
    material1b,
    mesh1,
    elements: [],
    material2,
    mesh2,
    scale: @math.Vector2::new(0.0, 0.0),
    screen_position_pixels: @math.Vector2::new(0.0, 0.0),
    valid_area: @math.Box2::new(),
    viewport: @math.Vector4::new(0.0, 0.0, 0.0, 1.0),
  }
  object.set_extension(lensflare) |> ignore
  object.on_before_render = fn(renderer, _, camera, _, _, _) {
    lensflare.on_before_render(object, objects_webgl_renderer(renderer), camera)
  }
  object
}

///|
/// The payload of a `Lensflare`, or `None` for other objects.
pub fn Lensflare::of(object : @core.Object3D) -> Lensflare? {
  objects_payload(object, "class:Lensflare")
}

///|
/// `addElement( element )`.
pub fn Lensflare::add_element(
  object : @core.Object3D,
  element : LensflareElement,
) -> Unit {
  let lensflare : Lensflare = objects_require(object, "class:Lensflare")
  lensflare.elements.push(element)
}

///|
/// `onBeforeRender( renderer, scene, camera )`, with `this` the lens flare.
fn Lensflare::on_before_render(
  self : Lensflare,
  this : @core.Object3D,
  renderer : @webgl.WebGLRenderer,
  camera : @core.Object3D,
) -> Unit {
  let viewport = self.viewport
  renderer.get_current_viewport(viewport) |> ignore
  let type_ = match renderer.get_render_target() {
    Some(render_target) => render_target.texture().type_
    None => @core.UnsignedByteType
  }
  if self.current_type != type_ {
    self.temp_map.dispose()
    self.occlusion_map.dispose()
    self.occlusion_map.type_ = type_
    self.temp_map.type_ = type_
    self.current_type = type_
  }
  let inv_aspect = viewport.w / viewport.z
  let half_viewport_width = viewport.z / 2.0
  let half_viewport_height = viewport.w / 2.0
  let mut size = 16.0 / viewport.w
  self.scale.set(size * inv_aspect, size) |> ignore
  self.valid_area.min.set(viewport.x, viewport.y) |> ignore
  self.valid_area.max.set(
    viewport.x + (viewport.z - 16.0),
    viewport.y + (viewport.w - 16.0),
  )
  |> ignore
  // calculate position in screen space
  self.position_view.set_from_matrix_position(this.matrix_world) |> ignore
  self.position_view.apply_matrix4(camera.matrix_world_inverse()) |> ignore
  if self.position_view.z > 0.0 {
    return // lensflare is behind the camera
  }
  self.position_screen
  .copy(self.position_view)
  .apply_matrix4(camera.projection_matrix())
  |> ignore
  // horizontal and vertical coordinate of the lower left corner of the pixels to copy
  self.screen_position_pixels.x = viewport.x +
    self.position_screen.x * half_viewport_width +
    half_viewport_width -
    8.0
  self.screen_position_pixels.y = viewport.y +
    self.position_screen.y * half_viewport_height +
    half_viewport_height -
    8.0
  // screen cull
  if self.valid_area.contains_point(self.screen_position_pixels) {
    let geometry = Lensflare::geometry()
    // save current RGB to temp texture
    renderer.copy_framebuffer_to_texture(
      self.temp_map,
      position=self.screen_position_pixels,
    )
    // render pink quad
    objects_uniform(self.material1a, "scale").value = Vector2(self.scale)
    objects_uniform(self.material1a, "screenPosition").value = Vector3(
      self.position_screen,
    )
    renderer.render_buffer_direct(
      camera,
      None,
      geometry,
      self.material1a,
      self.mesh1,
      None,
    )
    // copy result to occlusionMap
    renderer.copy_framebuffer_to_texture(
      self.occlusion_map,
      position=self.screen_position_pixels,
    )
    // restore graphics
    objects_uniform(self.material1b, "scale").value = Vector2(self.scale)
    objects_uniform(self.material1b, "screenPosition").value = Vector3(
      self.position_screen,
    )
    renderer.render_buffer_direct(
      camera,
      None,
      geometry,
      self.material1b,
      self.mesh1,
      None,
    )
    // render elements
    let vec_x = -self.position_screen.x * 2.0
    let vec_y = -self.position_screen.y * 2.0
    for element in self.elements {
      let material2 = self.material2
      match objects_uniform(material2, "color").value {
        Color(c) => c.copy(element.color) |> ignore
        _ => abort("TypeError: color uniform")
      }
      objects_uniform(material2, "map").value = Texture(element.texture)
      match objects_uniform(material2, "screenPosition").value {
        Vector3(v) => {
          v.x = self.position_screen.x + vec_x * element.distance
          v.y = self.position_screen.y + vec_y * element.distance
        }
        _ => abort("TypeError: screenPosition uniform")
      }
      size = element.size / viewport.w
      let inv_aspect = viewport.w / viewport.z
      match objects_uniform(material2, "scale").value {
        Vector2(v) => v.set(size * inv_aspect, size) |> ignore
        _ => abort("TypeError: scale uniform")
      }
      material2.uniforms_need_update = Some(true)
      renderer.render_buffer_direct(
        camera,
        None,
        geometry,
        material2,
        self.mesh2,
        None,
      )
    }
  }
}

///|
let _lensflare_1a_vertex_shader : String =
  #|
  #|
  #|				precision highp float;
  #|
  #|				uniform vec3 screenPosition;
  #|				uniform vec2 scale;
  #|
  #|				attribute vec3 position;
  #|
  #|				void main() {
  #|
  #|					gl_Position = vec4( position.xy * scale + screenPosition.xy, screenPosition.z, 1.0 );
  #|
  #|				}

///|
let _lensflare_1a_fragment_shader : String =
  #|
  #|
  #|				precision highp float;
  #|
  #|				void main() {
  #|
  #|					gl_FragColor = vec4( 1.0, 0.0, 1.0, 1.0 );
  #|
  #|				}

///|
let _lensflare_1b_vertex_shader : String =
  #|
  #|
  #|				precision highp float;
  #|
  #|				uniform vec3 screenPosition;
  #|				uniform vec2 scale;
  #|
  #|				attribute vec3 position;
  #|				attribute vec2 uv;
  #|
  #|				varying vec2 vUV;
  #|
  #|				void main() {
  #|
  #|					vUV = uv;
  #|
  #|					gl_Position = vec4( position.xy * scale + screenPosition.xy, screenPosition.z, 1.0 );
  #|
  #|				}

///|
let _lensflare_1b_fragment_shader : String =
  #|
  #|
  #|				precision highp float;
  #|
  #|				uniform sampler2D map;
  #|
  #|				varying vec2 vUV;
  #|
  #|				void main() {
  #|
  #|					gl_FragColor = texture2D( map, vUV );
  #|
  #|				}

///|
let _lensflare_element_vertex_shader : String =
  #|
  #|
  #|		precision highp float;
  #|
  #|		uniform vec3 screenPosition;
  #|		uniform vec2 scale;
  #|
  #|		uniform sampler2D occlusionMap;
  #|
  #|		attribute vec3 position;
  #|		attribute vec2 uv;
  #|
  #|		varying vec2 vUV;
  #|		varying float vVisibility;
  #|
  #|		void main() {
  #|
  #|			vUV = uv;
  #|
  #|			vec2 pos = position.xy;
  #|
  #|			vec4 visibility = texture2D( occlusionMap, vec2( 0.1, 0.1 ) );
  #|			visibility += texture2D( occlusionMap, vec2( 0.5, 0.1 ) );
  #|			visibility += texture2D( occlusionMap, vec2( 0.9, 0.1 ) );
  #|			visibility += texture2D( occlusionMap, vec2( 0.9, 0.5 ) );
  #|			visibility += texture2D( occlusionMap, vec2( 0.9, 0.9 ) );
  #|			visibility += texture2D( occlusionMap, vec2( 0.5, 0.9 ) );
  #|			visibility += texture2D( occlusionMap, vec2( 0.1, 0.9 ) );
  #|			visibility += texture2D( occlusionMap, vec2( 0.1, 0.5 ) );
  #|			visibility += texture2D( occlusionMap, vec2( 0.5, 0.5 ) );
  #|
  #|			vVisibility =        visibility.r / 9.0;
  #|			vVisibility *= 1.0 - visibility.g / 9.0;
  #|			vVisibility *=       visibility.b / 9.0;
  #|
  #|			gl_Position = vec4( ( pos * scale + screenPosition.xy ).xy, screenPosition.z, 1.0 );
  #|
  #|		}

///|
let _lensflare_element_fragment_shader : String =
  #|
  #|
  #|		precision highp float;
  #|
  #|		uniform sampler2D map;
  #|		uniform vec3 color;
  #|
  #|		varying vec2 vUV;
  #|		varying float vVisibility;
  #|
  #|		void main() {
  #|
  #|			vec4 texture = texture2D( map, vUV );
  #|			texture.a *= vVisibility;
  #|			gl_FragColor = texture;
  #|			gl_FragColor.rgb *= color;
  #|
  #|		}
