// Group `lighting` of the A5 shader scenarios (upstream: shader_diff/a5/lighting.mjs):
// tsl/lighting (DynamicLightsNode and its data nodes, ClusteredLightsNode,
// LightProbeGridNode) and tsl/shadows (TileShadowNode, TileShadowNodeHelper).

///|
extern "js" fn a5_lighting_num(x : Double) -> String = "(x) => String(x)"

///|
fn a5_lighting_vec4(v : @math.Vector4) -> String {
  [v.x, v.y, v.z, v.w].map(a5_lighting_num).join(",")
}

///|
fn a5_lighting_vec3(v : @math.Vector3) -> String {
  [v.x, v.y, v.z].map(a5_lighting_num).join(",")
}

///|
fn a5_lighting_col(c : @math.Color) -> String {
  [c.r, c.g, c.b].map(a5_lighting_num).join(",")
}

///|
fn a5_lighting_point(x : Double, cast_shadow~ : Bool = false) -> @core.Object3D {
  let l = @core.PointLight::new(
    color=@math.Color::new(1.0, 0.5, 0.25),
    intensity=2.0,
    distance=10.0,
    decay=2.0,
  )
  l.position.set(x, 1.0, 2.0) |> ignore
  l.cast_shadow = cast_shadow
  l.update_matrix_world()
  l
}

///|
fn a5_lighting_spot(x : Double, map? : @core.Texture) -> @core.Object3D {
  let l = @core.SpotLight::new(
    color=@math.Color::new(0.25, 0.75, 1.0),
    intensity=3.0,
    distance=20.0,
    angle=0.6,
    penumbra=0.3,
    decay=1.5,
  )
  l.position.set(x, 4.0, -1.0) |> ignore
  let target = l.light_target()
  target.position.set(0.0, -1.0, 1.0) |> ignore
  guard l.as_light().kind is SpotLight(spot) else { abort("spot") }
  spot.map = map
  l.update_matrix_world()
  target.update_matrix_world()
  l
}

///|
fn a5_lighting_directional(x : Double) -> @core.Object3D {
  let l = @core.DirectionalLight::new(
    color=@math.Color::new(1.0, 1.0, 0.5),
    intensity=1.5,
  )
  l.position.set(x, 5.0, 3.0) |> ignore
  l.update_matrix_world()
  l.light_target().update_matrix_world()
  l
}

///|
fn a5_lighting_hemisphere() -> @core.Object3D {
  let l = @core.HemisphereLight::new(
    sky_color=@math.Color::new(0.5, 0.75, 1.0),
    ground_color=@math.Color::new(0.25, 0.125, 0.0),
    intensity=0.8,
  )
  l.position.set(0.0, 3.0, 1.0) |> ignore
  l.update_matrix_world()
  l
}

///|
fn a5_lighting_ambient(i : Int32) -> @core.Object3D {
  @core.AmbientLight::new(
    color=@math.Color::new(0.1 * i.to_double(), 0.2, 0.3),
    intensity=0.5 * i.to_double(),
  )
}

///|
fn a5_lighting_camera() -> @core.Object3D {
  let c = @core.PerspectiveCamera::new(fov=60.0, aspect=1.5, near=0.5, far=80.0)
  c.position.set(1.0, 2.0, 8.0) |> ignore
  c.look_at_xyz(0.0, 0.0, 0.0)
  c.update_matrix_world()
  c
}

///|
/// `custom( name, ( r, isGLSL ) => buildMaterial( material, r, isGLSL, { lightsNode } ) )`.
fn A5Scenarios::lit(
  self : A5Scenarios,
  name : String,
  make_material : () -> @core.Material,
  make_lights_node : () -> @nodes.Node,
  glsl~ : Bool = false,
) -> Unit {
  self.custom(
    name,
    fn(r, is_glsl) {
      a5_build_material(
        make_material(),
        r,
        is_glsl,
        lights_node=make_lights_node(),
      )
    },
    glsl~,
  )
}

///|
fn a5_lighting_set(
  node : @nodes.Node,
  lights : Array[@core.Object3D],
) -> @nodes.Node {
  @nodes.LightsNode::set_lights(node, lights)
}

///|
fn a5_lighting_dynamic_dump(
  out : Array[String],
  type_name : String,
  d : @nodes.Node,
  cam : @core.Object3D,
) -> Unit {
  let frame = @nodes.NodeFrame::new()
  frame.camera = Some(cam)
  d.update(frame) |> ignore
  let count = fn(n : @nodes.Node) {
    match @nodes.InputNode::get_value(n) {
      Number(v) => a5_lighting_num(v)
      _ => "?"
    }
  }
  if @tsl.AmbientLightDataNode::of(d) is Some(a) {
    out.push(type_name + " count -")
    out.push(" color " + a5_lighting_col(a._color))
  }
  if @tsl.DirectionalLightDataNode::of(d) is Some(a) {
    out.push(type_name + " count " + count(a.count_node))
    out.push(" colors " + a._colors.map(a5_lighting_col).join(" "))
    out.push(" dirs " + a._directions.map(a5_lighting_vec3).join(" "))
  }
  if @tsl.HemisphereLightDataNode::of(d) is Some(a) {
    out.push(type_name + " count " + count(a.count_node))
    out.push(
      " sky " +
      a._sky_colors.map(a5_lighting_col).join(" ") +
      " ground " +
      a._ground_colors.map(a5_lighting_col).join(" "),
    )
    out.push(" dirs " + a._directions.map(a5_lighting_vec3).join(" "))
  }
  if @tsl.PointLightDataNode::of(d) is Some(a) {
    out.push(type_name + " count " + count(a.count_node))
    out.push(" colors " + a._colors.map(a5_lighting_col).join(" "))
    out.push(" pos " + a._positions_and_cutoff.map(a5_lighting_vec4).join(" "))
    out.push(" decays " + a._decays.map(a5_lighting_vec4).join(" "))
  }
  if @tsl.SpotLightDataNode::of(d) is Some(a) {
    out.push(type_name + " count " + count(a.count_node))
    out.push(" colors " + a._colors.map(a5_lighting_col).join(" "))
    out.push(" pos " + a._positions_and_cutoff.map(a5_lighting_vec4).join(" "))
    out.push(
      " dirdecay " + a._directions_and_decay.map(a5_lighting_vec4).join(" "),
    )
    out.push(" cones " + a._cones.map(a5_lighting_vec4).join(" "))
  }
}

///|
fn a5_lighting_ids(a : Array[@core.Object3D], base : @core.Object3D) -> String {
  a.map(fn(l) { (l.id - base.id).to_string() }).join(",")
}

///|
fn a5_lighting_typed(t : @core.TypedArray) -> String {
  t.to_array().map(a5_lighting_num).join(",")
}

///|
fn a5_lighting_vec2(v : @math.Vector2) -> String {
  [v.x, v.y].map(a5_lighting_num).join(",")
}

///|
fn a5_lighting_clustered_mix() -> Array[@core.Object3D] {
  [
    a5_lighting_point(1.0),
    a5_lighting_point(-2.0, cast_shadow=true),
    a5_lighting_spot(2.0),
    a5_lighting_spot(1.0, map=a5_tex("cmap")),
    a5_lighting_directional(1.0),
    a5_lighting_ambient(1),
    @core.IESSpotLight::new(),
    a5_lighting_point(3.0),
  ]
}

///|
fn a5_lighting_spot_payload(l : @core.Object3D) -> @core.SpotLight {
  guard l.as_light().kind is SpotLight(spot) else { abort("spot") }
  spot
}

///|
fn a5_lighting_point_payload(l : @core.Object3D) -> @core.PointLight {
  guard l.as_light().kind is PointLight(point) else { abort("point") }
  point
}

///|
/// A stand-in for an `examples/jsm/lighting/LightProbeGrid.js` light (not ported): a
/// `Light` whose grid data is registered as a `LightProbeGridSource`.
priv struct A5ProbeGrid {
  texture : @core.Texture?
  bounding_box : @math.Box3
  resolution : @math.Vector3
  mut priority : Double
}

///|
impl @webgl.LightProbeGridSource for A5ProbeGrid with fn texture(self) {
  self.texture
}

///|
impl @webgl.LightProbeGridSource for A5ProbeGrid with fn bounding_box(self) {
  self.bounding_box
}

///|
impl @webgl.LightProbeGridSource for A5ProbeGrid with fn resolution(self) {
  self.resolution
}

///|
impl @webgl.LightProbeGridSource for A5ProbeGrid with fn priority(self) {
  self.priority
}

///|
fn a5_lighting_grid(
  priority~ : Double = 0.0,
  x~ : Double = 0.0,
) -> (@core.Object3D, A5ProbeGrid) {
  let l = @core.Light::new(color=@math.Color::new(1.0, 1.0, 1.0), intensity=1.5)
  let bounding_box = @math.Box3::new(
    min=@math.Vector3::new(-2.0 + x, -1.0, -3.0),
    max=@math.Vector3::new(2.0 + x, 3.0, 1.0),
  )
  let resolution = @math.Vector3::new(4.0, 3.0, 2.0)
  let texture = @core.Data3DTexture::new(width=4, height=3, depth=28)
  texture.name = "probeAtlas"
  let source = A5ProbeGrid::{
    texture: Some(texture),
    bounding_box,
    resolution,
    priority,
  }
  @webgl.register_light_probe_grid(l, source)
  (l, source)
}

///|
fn a5_lighting_grid_light(
  priority~ : Double = 0.0,
  x~ : Double = 0.0,
) -> @core.Object3D {
  a5_lighting_grid(priority~, x~).0
}

///|
fn a5_lighting_tile_light() -> @core.Object3D {
  let l = @core.DirectionalLight::new(
    color=@math.Color::new(1.0, 1.0, 0.8),
    intensity=2.0,
  )
  l.position.set(10.0, 20.0, 5.0) |> ignore
  l.cast_shadow = true
  let shadow = l.as_light().shadow.unwrap()
  guard shadow.camera.as_camera().kind is OrthographicCamera(c) else {
    abort("ortho")
  }
  c.near = 1.0
  c.far = 60.0
  c.left = -30.0
  c.right = 30.0
  c.top = 20.0
  c.bottom = -25.0
  shadow.map_size.set(512.0, 256.0) |> ignore
  let group = @core.Group::new()
  group.add(l) |> ignore
  group.add(l.light_target()) |> ignore
  l.light_target().position.set(1.0, 0.0, -2.0) |> ignore
  group.update_matrix_world()
  l
}

///|
fn a5_lighting_tile_mesh(material : @core.Material) -> @core.Object3D {
  let m = @core.Mesh::new(geometry=a5_geometry(), material=Single(material))
  m.receive_shadow = true
  m
}

///|
fn[T] a5_lighting_with_shadows(
  r : @nodes.Renderer,
  type_ : Int32,
  transmitted : Bool,
  f : () -> T,
) -> T {
  let prev = (
    r.shadow_map.enabled,
    r.shadow_map.type_,
    r.shadow_map.transmitted,
  )
  r.shadow_map.enabled = true
  r.shadow_map.type_ = type_
  r.shadow_map.transmitted = transmitted
  let v = f()
  r.shadow_map.enabled = prev.0
  r.shadow_map.type_ = prev.1
  r.shadow_map.transmitted = prev.2
  v
}

///|
fn a5_lighting_tile_build(
  r : @nodes.Renderer,
  is_glsl : Bool,
  type_ : Int32,
  make_node : (@core.Object3D) -> @nodes.Node,
  transmitted~ : Bool = false,
  material? : () -> @core.Material,
) -> (@core.Object3D, @nodes.Node, String) {
  a5_lighting_with_shadows(r, type_, transmitted, fn() {
    let l = a5_lighting_tile_light()
    let tsn = make_node(l)
    l.as_light().shadow.unwrap().shadow_node = Some(@core.JsValue::of(tsn))
    let m = match material {
      Some(f) => f()
      None => @nodes.MeshStandardNodeMaterial::new()
    }
    let text = a5_build_material(
      m,
      r,
      is_glsl,
      lights_node=a5_lighting_set(@nodes.LightsNode::new(), [l]),
      object=a5_lighting_tile_mesh(m),
    )
    (l, tsn, text)
  })
}

///|
fn a5_lighting_ortho(camera : @core.Object3D) -> @core.OrthographicCamera {
  guard camera.as_camera().kind is OrthographicCamera(c) else { abort("ortho") }
  c
}

///|
fn a5_lighting_matrix(m : @math.Matrix4) -> String {
  m.elements.map(a5_lighting_num).join(",")
}

///|
test "a5 lighting shader scenarios (compared with upstream by run.mjs)" {
  a5_run(
    fn() {
      // `LightProbeGrid.registerNode( LightProbeGridNode )`: the stand-in grids are `Light`s
      @core.Light::register_node("Light", @tsl.LightProbeGridNode::node_class())
    },
    fn() {
      let s = A5Scenarios::new()
      // DynamicLightsNode
      s.lit(
        "dynamic_standard_batched",
        @nodes.MeshStandardNodeMaterial::new,
        fn() {
          a5_lighting_set(@tsl.dynamic_lights(), [
            a5_lighting_ambient(1),
            a5_lighting_hemisphere(),
            a5_lighting_directional(1.0),
            a5_lighting_point(1.0),
            a5_lighting_point(-2.0),
            a5_lighting_spot(2.0),
            a5_lighting_ambient(2),
          ])
        },
        glsl=true,
      )
      s.lit(
        "dynamic_phong_builtin_mix",
        @nodes.MeshPhongNodeMaterial::new,
        fn() {
          a5_lighting_set(@tsl.dynamic_lights(), [
            a5_lighting_point(1.0, cast_shadow=true),
            a5_lighting_spot(1.0, map=a5_tex("spotMap")),
            @core.IESSpotLight::new(),
            a5_lighting_directional(2.0),
            a5_lighting_point(3.0),
          ])
        },
        glsl=true,
      )
      s.lit("dynamic_small_max", @nodes.MeshStandardNodeMaterial::new, fn() {
        a5_lighting_set(
          @tsl.DynamicLightsNode::new(
            max_directional_lights=1,
            max_point_lights=2,
            max_spot_lights=1,
            max_hemisphere_lights=1,
          ),
          [
            a5_lighting_point(1.0),
            a5_lighting_point(2.0),
            a5_lighting_point(3.0),
            a5_lighting_directional(1.0),
            a5_lighting_directional(2.0),
            a5_lighting_spot(1.0),
            a5_lighting_spot(2.0),
            a5_lighting_hemisphere(),
            a5_lighting_hemisphere(),
          ],
        )
      })
      s.lit("dynamic_only_builtin", @nodes.MeshLambertNodeMaterial::new, fn() {
        a5_lighting_set(@tsl.dynamic_lights(), [
          a5_lighting_point(1.0, cast_shadow=true),
          a5_lighting_spot(1.0, map=a5_tex("map")),
        ])
      })
      s.lit("dynamic_empty", @nodes.MeshStandardNodeMaterial::new, fn() {
        @tsl.dynamic_lights()
      })
      s.lit("dynamic_relight", @nodes.MeshPhysicalNodeMaterial::new, fn() {
        let n = @tsl.dynamic_lights(max_point_lights=4)
        a5_lighting_set(n, [
          a5_lighting_point(1.0),
          a5_lighting_directional(1.0),
          a5_lighting_ambient(1),
        ])
        |> ignore
        a5_lighting_set(n, [a5_lighting_point(2.0)])
      })
      s.lit("dynamic_color_node_spot", @nodes.MeshStandardNodeMaterial::new, fn() {
        let sp = a5_lighting_spot(1.0)
        sp.as_light().color_node = Some(
          @core.JsValue::of(
            @nodes.fn_(fn(inputs, _) {
              Some(inputs.get(0).unwrap().xyz().mul(0.5))
            }),
          ),
        )
        a5_lighting_set(@tsl.dynamic_lights(), [sp, a5_lighting_spot(2.0)])
      })
      s.custom("dynamic_cpu", fn(_, _) {
        let out = []
        let cam = a5_lighting_camera()
        let lights = [
          a5_lighting_ambient(1),
          a5_lighting_ambient(2),
          a5_lighting_hemisphere(),
          a5_lighting_directional(1.0),
          a5_lighting_directional(-1.0),
          a5_lighting_point(1.0),
          a5_lighting_point(-2.0),
          a5_lighting_point(5.0, cast_shadow=true),
          a5_lighting_spot(2.0),
          a5_lighting_spot(-3.0),
          a5_lighting_spot(1.0, map=a5_tex("m")),
        ]
        let n = @tsl.DynamicLightsNode::new(
          max_point_lights=1,
          max_spot_lights=4,
        )
        a5_lighting_set(n, lights) |> ignore
        out.push(
          "builtin " +
          @nodes.LightsNode::get_builtin_lights(n)
          .map(fn(l) { (l.id - lights[0].id).to_string() })
          .join(","),
        )
        let payload = @tsl.DynamicLightsNode::of(n).unwrap()
        out.push(
          "hasLights \{@nodes.LightsNode::has_lights(n)} types " +
          payload._data_nodes.keys().collect().join(","),
        )
        out.push("cacheKey " + a5_lighting_num(n.custom_cache_key()))
        for type_name, d in payload._data_nodes {
          a5_lighting_dynamic_dump(out, type_name, d, cam)
        }
        a5_lighting_set(n, [a5_lighting_point(0.0)]) |> ignore
        out.push(
          "relit builtin \{@nodes.LightsNode::get_builtin_lights(n).length()} hasLights \{@nodes.LightsNode::has_lights(n)} cacheKey " +
          a5_lighting_num(n.custom_cache_key()),
        )
        let empty = @tsl.dynamic_lights()
        out.push(
          "empty hasLights \{@nodes.LightsNode::has_lights(empty)} cacheKey " +
          a5_lighting_num(empty.custom_cache_key()),
        )
        out.join("\n")
      })
      // ClusteredLightsNode
      s.lit(
        "clustered_standard",
        @nodes.MeshStandardNodeMaterial::new,
        fn() {
          a5_lighting_set(
            @tsl.ClusteredLightsNode::new(),
            a5_lighting_clustered_mix(),
          )
        },
        glsl=true,
      )
      s.lit(
        "clustered_options",
        @nodes.MeshPhongNodeMaterial::new,
        fn() {
          a5_lighting_set(
            @tsl.ClusteredLightsNode::new(
              max_lights=64,
              tile_size=16,
              z_slices=8,
              max_lights_per_cluster=6,
            ),
            [a5_lighting_point(1.0), a5_lighting_spot(2.0)],
          )
        },
        glsl=true,
      )
      s.lit("clustered_tsl_default", @nodes.MeshLambertNodeMaterial::new, fn() {
        a5_lighting_set(@tsl.clustered_lights(), [a5_lighting_point(1.0)])
      })
      s.lit("clustered_only_builtin", @nodes.MeshPhysicalNodeMaterial::new, fn() {
        a5_lighting_set(
          @tsl.ClusteredLightsNode::new(
            max_lights=16,
            tile_size=32,
            z_slices=4,
            max_lights_per_cluster=4,
          ),
          [
            a5_lighting_directional(1.0),
            a5_lighting_point(2.0, cast_shadow=true),
          ],
        )
      })
      s.lit("clustered_color_node", @nodes.MeshStandardNodeMaterial::new, fn() {
        let p = a5_lighting_point(1.0)
        p.as_light().color_node = Some(
          @core.JsValue::of(@nodes.color_of([1, 0, 0])),
        )
        a5_lighting_set(
          @tsl.ClusteredLightsNode::new(
            max_lights=16,
            tile_size=32,
            z_slices=4,
            max_lights_per_cluster=4,
          ),
          [p, a5_lighting_point(2.0)],
        )
      })
      s.custom(
        "clustered_compute",
        fn(r, is_glsl) {
          let n = a5_lighting_set(
            @tsl.ClusteredLightsNode::new(
              max_lights=32,
              tile_size=16,
              z_slices=4,
              max_lights_per_cluster=8,
            ),
            [a5_lighting_point(1.0), a5_lighting_spot(2.0)],
          )
          let mat = a5_build_material(
            @nodes.MeshStandardNodeMaterial::new(),
            r,
            is_glsl,
            lights_node=n,
          )
          let payload = @tsl.ClusteredLightsNode::of(n).unwrap()
          let compute = payload._compute.unwrap()
          let b = a5_builder(NoObject, r, is_glsl)
          b.compute = Some(compute)
          b.build() |> ignore
          let count = match @nodes.ComputeNode::of(compute).unwrap().count {
            Some(c) => c.to_string()
            None => "null"
          }
          mat +
          "\n####\n" +
          b.vertex_shader.unwrap_or("null") +
          "\n@@@@\n" +
          b.fragment_shader.unwrap_or("null") +
          "\n@@@@\n" +
          b.compute_shader.unwrap_or("null") +
          "\n@@@@\n" +
          a5_bindings(b) +
          "\n\{count} \{payload._invocations_per_cluster}"
        },
        glsl=true,
      )
      s.custom(
        "clustered_debug_count",
        fn(r, is_glsl) {
          let n = @tsl.ClusteredLightsNode::new(
            max_lights=16,
            tile_size=32,
            z_slices=6,
            max_lights_per_cluster=4,
          )
          @tsl.ClusteredLightsNode::set_size(n, 320.0, 160.0) |> ignore
          a5_lighting_set(n, [a5_lighting_point(1.0)]) |> ignore
          let m = @nodes.MeshStandardNodeMaterial::new()
          @nodes.NodeMaterial::of(m).unwrap().color_node = Some(
            @nodes.vec3_of([
              @nodes.float(
                @tsl.ClusteredLightsNode::get_cluster_light_count(
                  n,
                  @nodes.int(-1),
                ),
              ).div(8),
              @nodes.float(
                @tsl.ClusteredLightsNode::get_cluster_light_count(
                  n,
                  @nodes.int(2),
                ),
              ),
              0,
            ]),
          )
          a5_build_material(m, r, is_glsl, lights_node=n)
        },
        glsl=true,
      )
      s.custom("clustered_cpu", fn(r, _) {
        let out = []
        let cam = a5_lighting_camera()
        let n = @tsl.ClusteredLightsNode::new(
          max_lights=8,
          tile_size=16,
          z_slices=6,
          max_lights_per_cluster=6,
        )
        let wide = a5_lighting_spot(-3.0)
        a5_lighting_spot_payload(wide).angle = 1.2
        let unbounded = a5_lighting_spot(3.0)
        a5_lighting_spot_payload(unbounded).distance = 0.0
        let far = a5_lighting_point(0.0)
        far.position.set(0.0, 0.0, -60.0) |> ignore
        a5_lighting_point_payload(far).distance = 0.0
        far.update_matrix_world()
        let lights = [
          a5_lighting_point(1.0),
          a5_lighting_point(-2.0),
          a5_lighting_spot(2.0),
          wide,
          a5_lighting_point(4.0, cast_shadow=true),
          a5_lighting_spot(1.0, map=a5_tex("cm")),
          a5_lighting_directional(1.0),
          unbounded,
          far,
          a5_lighting_point(6.0),
          a5_lighting_point(7.0),
          a5_lighting_point(8.0),
        ]
        a5_lighting_set(n, lights) |> ignore
        let p = @tsl.ClusteredLightsNode::of(n).unwrap()
        out.push(
          "clustered " +
          a5_lighting_ids(p.clustered_lights, lights[0]) +
          " material " +
          a5_lighting_ids(p.material_lights, lights[0]) +
          " builtin " +
          a5_lighting_ids(@nodes.LightsNode::get_builtin_lights(n), lights[0]),
        )
        p._update_lights_texture(cam)
        let count = fn(n : @nodes.Node) {
          match @nodes.InputNode::get_value(n) {
            Number(v) => a5_lighting_num(v)
            _ => "?"
          }
        }
        out.push(
          "count " +
          count(p._lights_count) +
          " order " +
          p._light_sort_order.map(fn(i) { i.to_string() }).join(","),
        )
        out.push("viewZ " + a5_lighting_typed(p._light_view_z))
        guard p._lights_texture.image() is DataImage(image) else {
          abort("data")
        }
        out.push("data " + a5_lighting_typed(image.data.unwrap()))
        out.push("z " + a5_lighting_typed(p._z_slice_ranges_data))
        out.push(
          "needsUpdate \{p._lights_texture.version} \{p._z_slice_ranges_texture.version}",
        )
        let grid = fn() {
          let dims = match @nodes.InputNode::get_value(p._grid_dimensions) {
            Vector2(v) => a5_lighting_vec2(v)
            _ => "?"
          }
          let compute_count = match
            @nodes.ComputeNode::of(p._compute.unwrap()).unwrap().count {
            Some(c) => c.to_string()
            None => "null"
          }
          let elements = @nodes.StorageBufferNode::of(p._light_indexes.unwrap()).unwrap().storage_attribute.array.length()
          out.push(
            "grid " +
            a5_lighting_vec2(p._buffer_size.unwrap()) +
            " dims " +
            dims +
            " count " +
            compute_count +
            " elements \{elements} version \{n.version} inv \{p._invocations_per_cluster} cacheKey " +
            a5_lighting_num(n.custom_cache_key()),
          )
        }
        @tsl.ClusteredLightsNode::set_size(n, 300.0, 150.0) |> ignore
        grid()
        @tsl.ClusteredLightsNode::set_size(n, 1000.0, 700.0) |> ignore
        grid()
        @tsl.ClusteredLightsNode::set_size(n, 100.0, 50.0) |> ignore
        grid()
        @tsl.ClusteredLightsNode::set_size(n, 100.0, 50.0) |> ignore
        grid()
        @tsl.ClusteredLightsNode::update_size(n)
        out.push("renderer \{p._renderer is None}")
        p._init_grid(n, r)
        @tsl.ClusteredLightsNode::update_size(n)
        grid()
        a5_lighting_set(n, [a5_lighting_point(0.0)]) |> ignore
        p._update_lights_texture(cam)
        out.push(
          "relit count " +
          count(p._lights_count) +
          " order " +
          p._light_sort_order.map(fn(i) { i.to_string() }).join(",") +
          " z " +
          a5_lighting_typed(p._z_slice_ranges_data),
        )
        out.join("\n")
      })
      // LightProbeGridNode (the light: a stand-in for examples/jsm/lighting/LightProbeGrid.js)
      s.lit(
        "probe_grid_standard",
        @nodes.MeshStandardNodeMaterial::new,
        fn() {
          a5_lighting_set(@nodes.LightsNode::new(), [a5_lighting_grid_light()])
        },
        glsl=true,
      )
      s.lit(
        "probe_grid_priorities",
        @nodes.MeshPhongNodeMaterial::new,
        fn() {
          a5_lighting_set(@tsl.dynamic_lights(), [
            a5_lighting_grid_light(priority=1.0),
            a5_lighting_point(1.0),
            a5_lighting_grid_light(priority=0.0, x=3.0),
            a5_lighting_ambient(1),
          ])
        },
        glsl=true,
      )
      s.flow(
        "probe_grid_irradiance",
        fn() {
          @tsl.light_probe_grid_irradiance(
            a5_lighting_grid_light(priority=2.0),
            @nodes.vec3_of([0.5, 1, -0.5]).to_var(name="p"),
            @nodes.vec3_of([0, 1, 0]).to_var(name="n"),
          )
        },
        glsl=true,
      )
      s.custom("probe_grid_cpu", fn(_, _) {
        let (g, source) = a5_lighting_grid(priority=3.0, x=1.0)
        let n = @tsl.LightProbeGridNode::new(light=g)
        n.update(@nodes.NodeFrame::new()) |> ignore
        let p = @tsl.LightProbeGridNode::of(n).unwrap()
        let v = fn(u : @nodes.Node) {
          match @nodes.InputNode::get_value(u) {
            Vector3(v) => a5_lighting_vec3(v)
            Number(x) => a5_lighting_num(x)
            _ => "?"
          }
        }
        let out = [
          [p._min, p._max, p._resolution, p._intensity, p._priority]
          .map(v)
          .join(" "),
        ]
        source.bounding_box.min.set(-5.0, -5.0, -5.0) |> ignore
        g.as_light().intensity = 0.25
        source.priority = -1.0
        n.update(@nodes.NodeFrame::new()) |> ignore
        out.push(
          [p._min, p._max, p._resolution, p._intensity, p._priority]
          .map(v)
          .join(" ") +
          " " +
          n.update_type +
          " " +
          n.type_(),
        )
        out.join("\n") + " \{@tsl.ATLAS_PADDING}"
      })
      // TileShadowNode
      s.custom(
        "tile_shadow_basic",
        fn(r, is_glsl) {
          a5_lighting_tile_build(r, is_glsl, @core.BasicShadowMap, fn(l) {
            @tsl.TileShadowNode::new(l, tiles_x=3, tiles_y=2)
          }).2
        },
        glsl=true,
      )
      s.custom(
        "tile_shadow_pcf_default",
        fn(r, is_glsl) {
          a5_lighting_tile_build(r, is_glsl, @core.PCFShadowMap, fn(l) {
            @tsl.TileShadowNode::new(l)
          }).2
        },
        glsl=true,
      )
      s.custom("tile_shadow_vsm", fn(r, is_glsl) {
        a5_lighting_tile_build(r, is_glsl, @core.VSMShadowMap, fn(l) {
          @tsl.TileShadowNode::new(l, tiles_x=2, tiles_y=3)
        }).2
      })
      s.custom(
        "tile_shadow_options",
        fn(r, is_glsl) {
          a5_lighting_tile_build(
            r,
            is_glsl,
            @core.BasicShadowMap,
            fn(l) {
              @tsl.TileShadowNode::new(
                l,
                tiles_x=1,
                tiles_y=3,
                resolution=@math.Vector2::new(256.0, 128.0),
                depth_type=@core.UnsignedShortType,
                debug=true,
              )
            },
            transmitted=true,
            material=fn() {
              let m = @nodes.MeshPhongNodeMaterial::new()
              @nodes.NodeMaterial::of(m).unwrap().received_shadow_node = Some(
                @nodes.fn_(fn(inputs, _) {
                  Some(inputs.get(0).unwrap().mul(0.5))
                }),
              )
              m
            },
          ).2
        },
        glsl=true,
      )
      s.custom("tile_shadow_filter_node", fn(r, is_glsl) {
        a5_lighting_tile_build(r, is_glsl, @core.PCFShadowMap, fn(l) {
          l.as_light().shadow.unwrap().filter_node = Some(
            @core.JsValue::of(
              @nodes.fn_(fn(inputs, _) {
                let shadow_coord = inputs.named("shadowCoord").unwrap()
                let depth_layer = inputs.named("depthLayer").unwrap()
                Some(
                  shadow_coord.z().one_minus().mul(@nodes.float(depth_layer)),
                )
              }),
            ),
          )
          @tsl.TileShadowNode::new(l, tiles_x=2, tiles_y=2)
        }).2
      })
      s.custom("tile_shadow_cpu", fn(r, _) {
        let (l, tsn_node, _) = a5_lighting_tile_build(
          r,
          false,
          @core.PCFShadowMap,
          fn(l) { @tsl.TileShadowNode::new(l, tiles_x=2, tiles_y=3) },
        )
        let tsn = @tsl.TileShadowNode::of(tsn_node).unwrap()
        let shadow = l.as_light().shadow.unwrap()
        let out = []
        let cfg = tsn.config
        out.push(
          "config \{cfg.tiles_x},\{cfg.tiles_y},\{a5_lighting_num(cfg.resolution.x)},\{a5_lighting_num(cfg.resolution.y)},\{cfg.depth_type},\{cfg.debug},\{tsn.debug} same \{physical_equal(cfg.resolution, shadow.map_size)}",
        )
        out.push(
          "tiles " +
          tsn.tiles
          .map(fn(t) {
            [t.x.0, t.x.1, t.y.0, t.y.1, t.index.to_double()]
            .map(a5_lighting_num)
            .join(",")
          })
          .join(" "),
        )
        let sz = tsn.shadow_size
        out.push(
          "size " +
          [sz.top, sz.bottom, sz.left, sz.right].map(a5_lighting_num).join(",") +
          " dir " +
          a5_lighting_vec3(tsn.initial_light_direction),
        )
        let sm = tsn.shadow_map.unwrap()
        let dt = sm.depth_texture().unwrap()
        guard dt.image() is DataImage(dt_image) else { abort("image") }
        out.push(
          "map \{sm.width},\{sm.height},\{sm.depth},\{sm.textures.length()},\{sm.use_array_depth_texture},\{dt.name},\{dt.type_},\{dt_image.depth.unwrap()},\{dt.compare_function.unwrap()},\{dt.min_filter},\{dt.mag_filter}",
        )
        let dump_lights = fn() {
          for i in 0..<tsn.lights.length() {
            let lw = tsn.lights[i]
            let lw_payload = @tsl.TileShadowNodeLwLight::of(lw).unwrap()
            let lw_shadow = lw_payload.shadow.unwrap()
            let c = lw_shadow.camera
            let o = a5_lighting_ortho(c)
            let sn = tsn._shadow_nodes[i]
            let snp = @nodes.ShadowNode::of(sn).unwrap()
            let q = lw.quaternion
            let tile_index : Int32 = c.user_data.get("tileIndex").cast()
            out.push(
              "tile \{i} \{lw.type_} \{lw.cast_shadow} pos " +
              a5_lighting_vec3(lw.position) +
              " target " +
              a5_lighting_vec3(lw_payload.target.position) +
              " q " +
              [q.x, q.y, q.z, q.w].map(a5_lighting_num).join(",") +
              " cam " +
              [
                o.left,
                o.right,
                o.top,
                o.bottom,
                o.near,
                o.far,
                tile_index.to_double(),
              ]
              .map(a5_lighting_num)
              .join(",") +
              " proj " +
              a5_lighting_matrix(c.as_camera().projection_matrix) +
              " world " +
              a5_lighting_matrix(c.matrix_world) +
              " node \{snp.depth_layer} \{sn.update_before_type} \{snp.shadow.needs_update} \{physical_equal(snp.shadow, lw_shadow)} \{physical_equal(snp.base.light, lw)} bias " +
              a5_lighting_num(lw_shadow.bias),
            )
          }
        }
        dump_lights()
        out.push(
          "parent \{l.parent.unwrap().children.length()} array \{@nodes.camera_sub_cameras(tsn.camera_array.unwrap()).length()} coord \{shadow.camera.as_camera().coordinate_system} \{tsn_node.type_()} \{tsn_node.update_before_type}",
        )
        let lc = a5_lighting_ortho(shadow.camera)
        lc.left = -40.0
        lc.top = 30.0
        l.position.set(-5.0, 25.0, 10.0) |> ignore
        l.update_matrix_world()
        tsn.update_tiles(tsn_node)
        dump_lights()
        out.push("shadowMatrix " + a5_lighting_matrix(shadow.matrix))
        @tsl.TileShadowNode::dispose_lights_and_nodes(tsn_node)
        out.push(
          "disposed \{l.parent.unwrap().children.length()} \{tsn.lights.length()} " +
          (if tsn.shadow_map is None { "null" } else { "?" }),
        )
        out.join("\n")
      })
      s.custom(
        "tile_shadow_helper",
        fn(r, is_glsl) {
          let (_, tsn, _) = a5_lighting_tile_build(
            r,
            is_glsl,
            @core.BasicShadowMap,
            fn(l) { @tsl.TileShadowNode::new(l, tiles_x=3, tiles_y=2) },
          )
          let h = @tsl.TileShadowNodeHelper::new(tsn)
          let hp = @tsl.TileShadowNodeHelper::of(h).unwrap()
          let out = [
            "helper \{h.type_} \{h.children.length()} \{hp.initialized}",
          ]
          @tsl.TileShadowNodeHelper::update(h)
          out.push(
            "init \{h.children.length()} \{hp.initialized} \{hp._debug_meshes.length()} \{hp._shadow_cam_helpers.length()}",
          )
          for mesh in hp._debug_meshes[0:3] {
            guard mesh.get_material() is Some(Single(m)) else { abort("mat") }
            out.push(
              "\{a5_lighting_num(mesh.render_order)} \{mesh.frustum_culled} \{m.transparent} \{m.depth_test} \{m.depth_write}",
            )
            out.push(a5_build_material(m, r, is_glsl, object=mesh))
          }
          @tsl.TileShadowNodeHelper::dispose(h)
          out.push(
            "disposed \{hp._debug_meshes.length()} \{h.children.length()}",
          )
          out.join("\n")
        },
        glsl=true,
      )
      s
    },
  )
}
