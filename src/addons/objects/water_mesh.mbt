// Upstream examples/jsm/objects/WaterMesh.js: the ocean of Water.js as TSL on a
// `NodeMaterial` (WebGPURenderer), reflecting through a `reflector()` node.

///|
/// The uniforms and settings upstream exposes on the instance.
pub(all) struct WaterMesh {
  mut resolution_scale : Double
  water_normals : @nodes.Node
  alpha : @nodes.Node
  size : @nodes.Node
  sun_color : @nodes.Node
  sun_direction : @nodes.Node
  water_color : @nodes.Node
  distortion_scale : @nodes.Node
}

///|
pub impl @core.Object3DExtension for WaterMesh with fn type_name(_) {
  "Mesh"
}

///|
/// `new this.constructor()`: upstream reads `options.resolutionScale` of an undefined
/// `options` and throws.
pub impl @core.Object3DExtension for WaterMesh with fn construct(_) {
  abort(
    "TypeError: Cannot read properties of undefined (reading 'resolutionScale')",
  )
}

///|
pub impl @core.Object3DExtension for WaterMesh with fn has_flag(_, flag) {
  flag == "isWaterMesh" || flag == "class:WaterMesh"
}

///|
#deprecated
pub extend WaterMesh with @core.Object3DExtension::{
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
/// The payload of a `WaterMesh`, or `None` for other objects.
pub fn WaterMesh::of(object : @core.Object3D) -> WaterMesh? {
  objects_payload(object, "class:WaterMesh")
}

///|
/// `new WaterMesh( geometry, options )`. Colors are hex values; `water_normals` is the
/// normal map of the waves (upstream's `texture( undefined )`, the empty texture, when
/// left out).
pub fn WaterMesh::new(
  geometry : @core.BufferGeometry?,
  resolution_scale~ : Double = 0.5,
  water_normals? : @core.Texture,
  alpha~ : Double = 1.0,
  size~ : Double = 1.0,
  sun_color~ : Int32 = 0xffffff,
  sun_direction? : @math.Vector3,
  water_color~ : Int32 = 0x7f7f7f,
  distortion_scale~ : Double = 20.0,
) -> @core.Object3D {
  let material = @nodes.NodeMaterial::new()
  let object = @core.Mesh::new(geometry?, material=Single(material))
  // Uniforms
  let water : WaterMesh = {
    resolution_scale,
    water_normals: objects_texture_node(water_normals),
    alpha: @nodes.uniform(alpha),
    size: @nodes.uniform(size),
    sun_color: @nodes.uniform(@math.Color::from_hex(sun_color)),
    sun_direction: @nodes.uniform(
      match sun_direction {
        Some(v) => v
        None => @math.Vector3::new(0.70707, 0.70707, 0.0)
      },
    ),
    water_color: @nodes.uniform(@math.Color::from_hex(water_color)),
    distortion_scale: @nodes.uniform(distortion_scale),
  }
  object.set_extension(water) |> ignore
  // TSL
  let get_noise = @nodes.fn_(fn(inputs, _) {
    let uv = inputs.get(0).unwrap()
    let offset = @nodes.time
    let uv0 = @nodes.add(
      @nodes.div(uv, 103),
      @nodes.vec2_of([@nodes.div(offset, 17), @nodes.div(offset, 29)]),
    ).to_var()
    let uv1 = @nodes.div(uv, 107)
      .sub(@nodes.vec2_of([@nodes.div(offset, -19), @nodes.div(offset, 31)]))
      .to_var()
    let uv2 = @nodes.add(
      @nodes.div(uv, @nodes.vec2_of([8907.0, 9803.0])),
      @nodes.vec2_of([@nodes.div(offset, 101), @nodes.div(offset, 97)]),
    ).to_var()
    let uv3 = @nodes.sub(
      @nodes.div(uv, @nodes.vec2_of([1091.0, 1027.0])),
      @nodes.vec2_of([@nodes.div(offset, 109), @nodes.div(offset, -113)]),
    ).to_var()
    let sample0 = water.water_normals.sample(uv0)
    let sample1 = water.water_normals.sample(uv1)
    let sample2 = water.water_normals.sample(uv2)
    let sample3 = water.water_normals.sample(uv3)
    let noise = sample0.add(sample1).add(sample2).add(sample3)
    Some(noise.mul(0.5).sub(1))
  })
  let noise = get_noise.call([@nodes.position_world.xz().mul(water.size)])
  let surface_normal = @nodes.normalize(noise.xzy().mul_of([1.5, 1.0, 1.5]))
  let world_to_eye = @nodes.camera_position.sub(@nodes.position_world)
  let eye_direction = @nodes.normalize(world_to_eye)
  let reflection = @nodes.normalize(
    @nodes.reflect(water.sun_direction.negate(), surface_normal),
  )
  let direction = @nodes.max(0.0, @nodes.dot(eye_direction, reflection))
  let specular_light = @nodes.pow(direction, 100).mul(water.sun_color).mul(2.0)
  let diffuse_light = @nodes.max(
      @nodes.dot(water.sun_direction, surface_normal),
      0.0,
    )
    .mul(water.sun_color)
    .mul(0.5)
  let distance = @nodes.length(world_to_eye)
  let distortion = surface_normal
    .xz()
    .mul(@nodes.float(0.001).add(@nodes.float(1.0).div(distance)))
    .mul(water.distortion_scale)
  // Material
  material.transparent = true
  let node_material = @nodes.NodeMaterial::of(material).unwrap()
  node_material.opacity_node = Some(water.alpha)
  node_material.received_shadow_position_node = Some(
    @nodes.position_world.add(distortion),
  )
  node_material.color_node = Some(
    @nodes.fn_(fn(_, _) {
      let mirror_sampler = @nodes.reflector()
      let sampler = @nodes.TextureNode::of(mirror_sampler).unwrap()
      sampler.uv_node = Some(sampler.uv_node.unwrap().add(distortion))
      @nodes.ReflectorBaseNode::of(
        @nodes.ReflectorNode::reflector(mirror_sampler),
      ).unwrap().resolution_scale
      = water.resolution_scale
      object.add(@nodes.ReflectorNode::target(mirror_sampler)) |> ignore
      let theta = @nodes.max(@nodes.dot(eye_direction, surface_normal), 0.0)
      let rf0 = @nodes.float(0.02)
      let reflectance = @nodes.mul(
        @nodes.pow(@nodes.float(1.0).sub(theta), 5.0),
        @nodes.float(1.0).sub(rf0),
      ).add(rf0)
      let scatter = @nodes.max(0.0, @nodes.dot(surface_normal, eye_direction)).mul(
        water.water_color,
      )
      let albedo = @nodes.mix(
        water.sun_color.mul(diffuse_light).mul(0.3).add(scatter),
        mirror_sampler.rgb().add(specular_light),
        reflectance,
      )
      Some(albedo)
    }).call([]),
  )
  object
}
