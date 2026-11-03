// examples/jsm/tsl/display/RetroPassNode.js

///|
/// RetroPassNode.js's module-level nodes.
priv struct RetroPassNodeModule {
  _affine_uv : @nodes.Node
  _w : @nodes.Node
  _clip_space_retro : @nodes.Node
}

///|
let display_retro_pass_node_module : AddonModule[RetroPassNodeModule] = AddonModule::new(fn() {
    let _affine_uv = @nodes.varying(@nodes.vec2_of([]))
    let _w = @nodes.varying(@nodes.float_of([]))
    let _clip_space_retro = @nodes.fn_(fn(_, _) {
      let default_position = @nodes.camera_projection_matrix
        .mul(@nodes.camera_view_matrix)
        .mul(@nodes.position_world)
      let rounded_position = default_position
        .xy()
        .div(default_position.w().mul(2))
        .mul(@nodes.screen_size.xy())
        .round()
        .div(@nodes.screen_size.xy())
        .mul(default_position.w().mul(2))
      _affine_uv.assign(@nodes.uv().mul(default_position.w()))
      _w.assign(default_position.w())
      Some(@nodes.vec4_of([rounded_position.xy(), default_position.zw()]))
    }).call([])
    { _affine_uv, _w, _clip_space_retro, }
  },
)

///|
/// Evaluates RetroPassNode.js (`_affineUv`, `_w`, `_clipSpaceRetro`), as `import` does.
pub fn load_display_retro_pass_node() -> Unit {
  display_retro_pass_node_module.get() |> ignore
}

///|
/// `_materialCache` entries: the retro material made for a material and its version.
priv struct RetroPassNodeMaterialData {
  material : @core.Material
  version : Int32
}

///|
/// A retro (PS1 style) pass: low resolution, vertex snapping, optional affine texture
/// distortion and unfiltered textures, done by replacing each material while rendering.
pub(all) struct RetroPassNode {
  pass : @nodes.PassNode
  /// `affineDistortion`: the amount of affine texture distortion, `None` for none.
  mut affine_distortion_node : @nodes.Node?
  mut filter_textures : Bool
  priv _material_cache : Array[(@core.Material, RetroPassNodeMaterialData)]
}

///|
pub impl @nodes.NodeClass for RetroPassNode with fn class_name(_) {
  "RetroPassNode"
}

///|
/// RetroPassNode has no `static get type()`: PassNode's.
pub impl @nodes.NodeClass for RetroPassNode with fn type_name(self) {
  self.pass.type_name()
}

///|
pub impl @nodes.NodeClass for RetroPassNode with fn parent(self) {
  Some(self.pass)
}

///|
pub impl @nodes.NodeClass for RetroPassNode with fn children(self, node, out) {
  self.pass.children(node, out)
  @nodes.push_child(out, "affineDistortionNode", self.affine_distortion_node)
}

///|
pub impl @nodes.PassNodeClass for RetroPassNode with fn set_size(
  _,
  node,
  width,
  height,
) {
  @nodes.PassNode::set_size_base(node, width, height)
}

///|
fn RetroPassNode::cache_index(
  self : RetroPassNode,
  material : @core.Material,
) -> Int32? {
  self._material_cache.search_by(fn(e) { physical_equal(e.0, material) })
}

///|
/// The body of the render object function: the retro material of `material`.
fn RetroPassNode::retro_material(
  self : RetroPassNode,
  scene : @core.Object3D,
  material : @core.Material,
) -> @core.Material {
  let module_ = display_retro_pass_node_module.get()
  let index = self.cache_index(material)
  let retro_material_data = match index {
    Some(i) => Some(self._material_cache[i].1)
    None => None
  }
  let retro_material = if retro_material_data is None ||
    retro_material_data.unwrap().version != material.version {
    if retro_material_data is Some(data) {
      data.material.dispose()
    }
    let retro_material = if material.is_mesh_basic_material() ||
      material.has_extension_flag("isMeshBasicNodeMaterial") {
      @nodes.MeshBasicNodeMaterial::new()
    } else {
      @nodes.MeshPhongNodeMaterial::new()
    }
    let source = @nodes.NodeMaterial::of(material)
    let retro = @nodes.NodeMaterial::of(retro_material).unwrap()
    let source_color_node = source.bind(fn(s) { s.color_node })
    retro.color_node = source_color_node
    retro.opacity_node = source.bind(fn(s) { s.opacity_node })
    retro.position_node = source.bind(fn(s) { s.position_node })
    retro.vertex_node = match source.bind(fn(s) { s.vertex_node }) {
      Some(n) => Some(n)
      None => Some(module_._clip_space_retro)
    }
    let mut color_node = match source_color_node {
      Some(n) => n
      None => @nodes.material_color
    }
    if material.has_extension_flag("isMeshStandardNodeMaterial") ||
      material.is_mesh_standard_material() {
      let env_map = match material.env_map {
        Some(t) => Some(t)
        None => scene.as_scene().environment
      }
      if env_map is Some(env_map) {
        let reflection = @nodes.CubeMapNode::new(@nodes.texture(env_map))
        let metalness_node = match
          @nodes.MeshStandardNodeMaterial::of(material) {
          Some(m) => m.metalness_node
          None => None
        }
        let metalness = match metalness_node {
          Some(n) => n
          None => {
            let mut metalness = @nodes.uniform(material.metalness.unwrap()).on_render_update(fn(
                self_,
                frame,
              ) {
                match frame.material {
                  Some(m) =>
                    match m.metalness {
                      Some(v) => @nodes.InputNode::set_value(self_, Number(v))
                      None => ()
                    }
                  None => ()
                }
                None
              },
            )
            if material.metalness_map is Some(metalness_map) {
              let texture_uniform = @nodes.texture(metalness_map).on_render_update(fn(
                  self_,
                  frame,
                ) {
                  match frame.material {
                    Some(m) =>
                      match m.metalness_map {
                        Some(t) => @nodes.TextureNode::set_value(self_, Some(t))
                        None => ()
                      }
                    None => ()
                  }
                  None
                },
              )
              metalness = metalness.mul(texture_uniform.b())
            }
            metalness
          }
        }
        color_node = metalness.mix(color_node, reflection)
      }
    }
    retro.color_node = Some(color_node)
    //
    let context_data = @nodes.node_context([])
    if self.affine_distortion_node is Some(affine_distortion_node) {
      context_data.set(
        "getUV",
        Other(
          @core.JsValue::of(@nodes.ContextGetUV::{
            f: fn(texture, _) {
              let final_uv = if texture.has_flag("isCubeTextureNode") {
                @nodes.reflect_vector
              } else {
                affine_distortion_node.mix(
                  @nodes.uv(),
                  module_._affine_uv.div(module_._w),
                )
              }
              final_uv
            },
          }),
        ),
      )
    }
    if self.filter_textures != true {
      context_data.set(
        "getTextureLevel",
        Other(
          @core.JsValue::of(@nodes.ContextGetTextureLevel::{
            f: fn(_) { @nodes.uint(0) },
          }),
        ),
      )
    }
    retro.context_node = Some(@nodes.context(value=context_data))
    //
    let data = { material: retro_material, version: material.version, }
    match index {
      Some(i) => self._material_cache[i] = (material, data)
      None => self._material_cache.push((material, data))
    }
    retro_material
  } else {
    retro_material_data.unwrap().material
  }
  let nullable = if retro_material.has_extension_flag("isMeshBasicNodeMaterial") {
    retro_pass_node_basic_nullable
  } else {
    retro_pass_node_phong_nullable
  }
  retro_pass_node_copy_properties(retro_material, material, nullable)
  retro_material
}

///|
/// `for ( const property in material ) { if ( retroMaterial[ property ] === undefined )
/// continue; retroMaterial[ property ] = material[ property ]; }`: the base `Material`
/// properties (every material has them; `id` is not enumerable upstream and a node
/// material's `type` setter ignores the value), then each
/// subclass property `material` has (`Some`) that `target` has too (`Some`, or one of
/// `nullable`, the class's properties whose default is `null`), then the node slots and
/// the event listeners.
fn retro_pass_node_copy_properties(
  target : @core.Material,
  source : @core.Material,
  nullable : Array[String],
) -> Unit {
  target.uuid = source.uuid
  target.name = source.name
  target.blending = source.blending
  target.side = source.side
  target.vertex_colors = source.vertex_colors
  target.opacity = source.opacity
  target.transparent = source.transparent
  target.alpha_hash = source.alpha_hash
  target.blend_src = source.blend_src
  target.blend_dst = source.blend_dst
  target.blend_equation = source.blend_equation
  target.blend_src_alpha = source.blend_src_alpha
  target.blend_dst_alpha = source.blend_dst_alpha
  target.blend_equation_alpha = source.blend_equation_alpha
  target.blend_color = source.blend_color
  target.blend_alpha = source.blend_alpha
  target.depth_func = source.depth_func
  target.depth_test = source.depth_test
  target.depth_write = source.depth_write
  target.stencil_write_mask = source.stencil_write_mask
  target.stencil_func = source.stencil_func
  target.stencil_ref = source.stencil_ref
  target.stencil_func_mask = source.stencil_func_mask
  target.stencil_fail = source.stencil_fail
  target.stencil_z_fail = source.stencil_z_fail
  target.stencil_z_pass = source.stencil_z_pass
  target.stencil_write = source.stencil_write
  target.clipping_planes = source.clipping_planes
  target.clip_intersection = source.clip_intersection
  target.clip_shadows = source.clip_shadows
  target.shadow_side = source.shadow_side
  target.color_write = source.color_write
  target.precision = source.precision
  target.polygon_offset = source.polygon_offset
  target.polygon_offset_factor = source.polygon_offset_factor
  target.polygon_offset_units = source.polygon_offset_units
  target.dithering = source.dithering
  target.alpha_to_coverage = source.alpha_to_coverage
  target.premultiplied_alpha = source.premultiplied_alpha
  target.force_single_pass = source.force_single_pass
  target.allow_override = source.allow_override
  target.visible = source.visible
  target.tone_mapped = source.tone_mapped
  target.user_data = source.user_data
  target.version = source.version
  target._alpha_test = source._alpha_test
  if source.defines is Some(_) &&
    (target.defines is Some(_) || nullable.contains("defines")) {
    target.defines = source.defines
  }
  if source.color is Some(_) &&
    (target.color is Some(_) || nullable.contains("color")) {
    target.color = source.color
  }
  if source.map is Some(_) &&
    (target.map is Some(_) || nullable.contains("map")) {
    target.map = source.map
  }
  if source.linewidth is Some(_) &&
    (target.linewidth is Some(_) || nullable.contains("linewidth")) {
    target.linewidth = source.linewidth
  }
  if source.linecap is Some(_) &&
    (target.linecap is Some(_) || nullable.contains("linecap")) {
    target.linecap = source.linecap
  }
  if source.linejoin is Some(_) &&
    (target.linejoin is Some(_) || nullable.contains("linejoin")) {
    target.linejoin = source.linejoin
  }
  if source.fog is Some(_) &&
    (target.fog is Some(_) || nullable.contains("fog")) {
    target.fog = source.fog
  }
  if source.scale is Some(_) &&
    (target.scale is Some(_) || nullable.contains("scale")) {
    target.scale = source.scale
  }
  if source.dash_size is Some(_) &&
    (target.dash_size is Some(_) || nullable.contains("dash_size")) {
    target.dash_size = source.dash_size
  }
  if source.gap_size is Some(_) &&
    (target.gap_size is Some(_) || nullable.contains("gap_size")) {
    target.gap_size = source.gap_size
  }
  if source.light_map is Some(_) &&
    (target.light_map is Some(_) || nullable.contains("light_map")) {
    target.light_map = source.light_map
  }
  if source.light_map_intensity is Some(_) &&
    (
      target.light_map_intensity is Some(_) ||
      nullable.contains("light_map_intensity")
    ) {
    target.light_map_intensity = source.light_map_intensity
  }
  if source.ao_map is Some(_) &&
    (target.ao_map is Some(_) || nullable.contains("ao_map")) {
    target.ao_map = source.ao_map
  }
  if source.ao_map_intensity is Some(_) &&
    (
      target.ao_map_intensity is Some(_) ||
      nullable.contains("ao_map_intensity")
    ) {
    target.ao_map_intensity = source.ao_map_intensity
  }
  if source.specular_map is Some(_) &&
    (target.specular_map is Some(_) || nullable.contains("specular_map")) {
    target.specular_map = source.specular_map
  }
  if source.alpha_map is Some(_) &&
    (target.alpha_map is Some(_) || nullable.contains("alpha_map")) {
    target.alpha_map = source.alpha_map
  }
  if source.env_map is Some(_) &&
    (target.env_map is Some(_) || nullable.contains("env_map")) {
    target.env_map = source.env_map
  }
  if source.env_map_rotation is Some(_) &&
    (
      target.env_map_rotation is Some(_) ||
      nullable.contains("env_map_rotation")
    ) {
    target.env_map_rotation = source.env_map_rotation
  }
  if source.env_map_intensity is Some(_) &&
    (
      target.env_map_intensity is Some(_) ||
      nullable.contains("env_map_intensity")
    ) {
    target.env_map_intensity = source.env_map_intensity
  }
  if source.combine is Some(_) &&
    (target.combine is Some(_) || nullable.contains("combine")) {
    target.combine = source.combine
  }
  if source.reflectivity is Some(_) &&
    (target.reflectivity is Some(_) || nullable.contains("reflectivity")) {
    target.reflectivity = source.reflectivity
  }
  if source.refraction_ratio is Some(_) &&
    (
      target.refraction_ratio is Some(_) ||
      nullable.contains("refraction_ratio")
    ) {
    target.refraction_ratio = source.refraction_ratio
  }
  if source.wireframe is Some(_) &&
    (target.wireframe is Some(_) || nullable.contains("wireframe")) {
    target.wireframe = source.wireframe
  }
  if source.wireframe_linewidth is Some(_) &&
    (
      target.wireframe_linewidth is Some(_) ||
      nullable.contains("wireframe_linewidth")
    ) {
    target.wireframe_linewidth = source.wireframe_linewidth
  }
  if source.wireframe_linecap is Some(_) &&
    (
      target.wireframe_linecap is Some(_) ||
      nullable.contains("wireframe_linecap")
    ) {
    target.wireframe_linecap = source.wireframe_linecap
  }
  if source.wireframe_linejoin is Some(_) &&
    (
      target.wireframe_linejoin is Some(_) ||
      nullable.contains("wireframe_linejoin")
    ) {
    target.wireframe_linejoin = source.wireframe_linejoin
  }
  if source.depth_packing is Some(_) &&
    (target.depth_packing is Some(_) || nullable.contains("depth_packing")) {
    target.depth_packing = source.depth_packing
  }
  if source.displacement_map is Some(_) &&
    (
      target.displacement_map is Some(_) ||
      nullable.contains("displacement_map")
    ) {
    target.displacement_map = source.displacement_map
  }
  if source.displacement_scale is Some(_) &&
    (
      target.displacement_scale is Some(_) ||
      nullable.contains("displacement_scale")
    ) {
    target.displacement_scale = source.displacement_scale
  }
  if source.displacement_bias is Some(_) &&
    (
      target.displacement_bias is Some(_) ||
      nullable.contains("displacement_bias")
    ) {
    target.displacement_bias = source.displacement_bias
  }
  if source.emissive is Some(_) &&
    (target.emissive is Some(_) || nullable.contains("emissive")) {
    target.emissive = source.emissive
  }
  if source.emissive_intensity is Some(_) &&
    (
      target.emissive_intensity is Some(_) ||
      nullable.contains("emissive_intensity")
    ) {
    target.emissive_intensity = source.emissive_intensity
  }
  if source.emissive_map is Some(_) &&
    (target.emissive_map is Some(_) || nullable.contains("emissive_map")) {
    target.emissive_map = source.emissive_map
  }
  if source.bump_map is Some(_) &&
    (target.bump_map is Some(_) || nullable.contains("bump_map")) {
    target.bump_map = source.bump_map
  }
  if source.bump_scale is Some(_) &&
    (target.bump_scale is Some(_) || nullable.contains("bump_scale")) {
    target.bump_scale = source.bump_scale
  }
  if source.normal_map is Some(_) &&
    (target.normal_map is Some(_) || nullable.contains("normal_map")) {
    target.normal_map = source.normal_map
  }
  if source.normal_map_type is Some(_) &&
    (target.normal_map_type is Some(_) || nullable.contains("normal_map_type")) {
    target.normal_map_type = source.normal_map_type
  }
  if source.normal_scale is Some(_) &&
    (target.normal_scale is Some(_) || nullable.contains("normal_scale")) {
    target.normal_scale = source.normal_scale
  }
  if source.flat_shading is Some(_) &&
    (target.flat_shading is Some(_) || nullable.contains("flat_shading")) {
    target.flat_shading = source.flat_shading
  }
  if source.matcap is Some(_) &&
    (target.matcap is Some(_) || nullable.contains("matcap")) {
    target.matcap = source.matcap
  }
  if source.gradient_map is Some(_) &&
    (target.gradient_map is Some(_) || nullable.contains("gradient_map")) {
    target.gradient_map = source.gradient_map
  }
  if source.specular is Some(_) &&
    (target.specular is Some(_) || nullable.contains("specular")) {
    target.specular = source.specular
  }
  if source.shininess is Some(_) &&
    (target.shininess is Some(_) || nullable.contains("shininess")) {
    target.shininess = source.shininess
  }
  if source.roughness is Some(_) &&
    (target.roughness is Some(_) || nullable.contains("roughness")) {
    target.roughness = source.roughness
  }
  if source.metalness is Some(_) &&
    (target.metalness is Some(_) || nullable.contains("metalness")) {
    target.metalness = source.metalness
  }
  if source.roughness_map is Some(_) &&
    (target.roughness_map is Some(_) || nullable.contains("roughness_map")) {
    target.roughness_map = source.roughness_map
  }
  if source.metalness_map is Some(_) &&
    (target.metalness_map is Some(_) || nullable.contains("metalness_map")) {
    target.metalness_map = source.metalness_map
  }
  if source.size is Some(_) &&
    (target.size is Some(_) || nullable.contains("size")) {
    target.size = source.size
  }
  if source.size_attenuation is Some(_) &&
    (
      target.size_attenuation is Some(_) ||
      nullable.contains("size_attenuation")
    ) {
    target.size_attenuation = source.size_attenuation
  }
  if source.rotation is Some(_) &&
    (target.rotation is Some(_) || nullable.contains("rotation")) {
    target.rotation = source.rotation
  }
  if source.uniforms is Some(_) &&
    (target.uniforms is Some(_) || nullable.contains("uniforms")) {
    target.uniforms = source.uniforms
  }
  if source.uniforms_groups is Some(_) &&
    (target.uniforms_groups is Some(_) || nullable.contains("uniforms_groups")) {
    target.uniforms_groups = source.uniforms_groups
  }
  if source.vertex_shader is Some(_) &&
    (target.vertex_shader is Some(_) || nullable.contains("vertex_shader")) {
    target.vertex_shader = source.vertex_shader
  }
  if source.fragment_shader is Some(_) &&
    (target.fragment_shader is Some(_) || nullable.contains("fragment_shader")) {
    target.fragment_shader = source.fragment_shader
  }
  if source.lights is Some(_) &&
    (target.lights is Some(_) || nullable.contains("lights")) {
    target.lights = source.lights
  }
  if source.clipping is Some(_) &&
    (target.clipping is Some(_) || nullable.contains("clipping")) {
    target.clipping = source.clipping
  }
  if source.extensions is Some(_) &&
    (target.extensions is Some(_) || nullable.contains("extensions")) {
    target.extensions = source.extensions
  }
  if source.default_attribute_values is Some(_) &&
    (
      target.default_attribute_values is Some(_) ||
      nullable.contains("default_attribute_values")
    ) {
    target.default_attribute_values = source.default_attribute_values
  }
  if source.index0_attribute_name is Some(_) &&
    (
      target.index0_attribute_name is Some(_) ||
      nullable.contains("index0_attribute_name")
    ) {
    target.index0_attribute_name = source.index0_attribute_name
  }
  if source.uniforms_need_update is Some(_) &&
    (
      target.uniforms_need_update is Some(_) ||
      nullable.contains("uniforms_need_update")
    ) {
    target.uniforms_need_update = source.uniforms_need_update
  }
  if source.glsl_version is Some(_) &&
    (target.glsl_version is Some(_) || nullable.contains("glsl_version")) {
    target.glsl_version = source.glsl_version
  }
  if source.anisotropy_rotation is Some(_) &&
    (
      target.anisotropy_rotation is Some(_) ||
      nullable.contains("anisotropy_rotation")
    ) {
    target.anisotropy_rotation = source.anisotropy_rotation
  }
  if source.anisotropy_map is Some(_) &&
    (target.anisotropy_map is Some(_) || nullable.contains("anisotropy_map")) {
    target.anisotropy_map = source.anisotropy_map
  }
  if source.clearcoat_map is Some(_) &&
    (target.clearcoat_map is Some(_) || nullable.contains("clearcoat_map")) {
    target.clearcoat_map = source.clearcoat_map
  }
  if source.clearcoat_roughness is Some(_) &&
    (
      target.clearcoat_roughness is Some(_) ||
      nullable.contains("clearcoat_roughness")
    ) {
    target.clearcoat_roughness = source.clearcoat_roughness
  }
  if source.clearcoat_roughness_map is Some(_) &&
    (
      target.clearcoat_roughness_map is Some(_) ||
      nullable.contains("clearcoat_roughness_map")
    ) {
    target.clearcoat_roughness_map = source.clearcoat_roughness_map
  }
  if source.clearcoat_normal_scale is Some(_) &&
    (
      target.clearcoat_normal_scale is Some(_) ||
      nullable.contains("clearcoat_normal_scale")
    ) {
    target.clearcoat_normal_scale = source.clearcoat_normal_scale
  }
  if source.clearcoat_normal_map is Some(_) &&
    (
      target.clearcoat_normal_map is Some(_) ||
      nullable.contains("clearcoat_normal_map")
    ) {
    target.clearcoat_normal_map = source.clearcoat_normal_map
  }
  if source.diffuse_roughness_map is Some(_) &&
    (
      target.diffuse_roughness_map is Some(_) ||
      nullable.contains("diffuse_roughness_map")
    ) {
    target.diffuse_roughness_map = source.diffuse_roughness_map
  }
  if source.ior is Some(_) &&
    (target.ior is Some(_) || nullable.contains("ior")) {
    target.ior = source.ior
  }
  if source.iridescence_map is Some(_) &&
    (target.iridescence_map is Some(_) || nullable.contains("iridescence_map")) {
    target.iridescence_map = source.iridescence_map
  }
  if source.iridescence_ior is Some(_) &&
    (target.iridescence_ior is Some(_) || nullable.contains("iridescence_ior")) {
    target.iridescence_ior = source.iridescence_ior
  }
  if source.iridescence_thickness_minimum is Some(_) &&
    (
      target.iridescence_thickness_minimum is Some(_) ||
      nullable.contains("iridescence_thickness_minimum")
    ) {
    target.iridescence_thickness_minimum = source.iridescence_thickness_minimum
  }
  if source.iridescence_thickness_maximum is Some(_) &&
    (
      target.iridescence_thickness_maximum is Some(_) ||
      nullable.contains("iridescence_thickness_maximum")
    ) {
    target.iridescence_thickness_maximum = source.iridescence_thickness_maximum
  }
  if source.iridescence_thickness_map is Some(_) &&
    (
      target.iridescence_thickness_map is Some(_) ||
      nullable.contains("iridescence_thickness_map")
    ) {
    target.iridescence_thickness_map = source.iridescence_thickness_map
  }
  if source.sheen_color is Some(_) &&
    (target.sheen_color is Some(_) || nullable.contains("sheen_color")) {
    target.sheen_color = source.sheen_color
  }
  if source.sheen_color_map is Some(_) &&
    (target.sheen_color_map is Some(_) || nullable.contains("sheen_color_map")) {
    target.sheen_color_map = source.sheen_color_map
  }
  if source.sheen_roughness is Some(_) &&
    (target.sheen_roughness is Some(_) || nullable.contains("sheen_roughness")) {
    target.sheen_roughness = source.sheen_roughness
  }
  if source.sheen_roughness_map is Some(_) &&
    (
      target.sheen_roughness_map is Some(_) ||
      nullable.contains("sheen_roughness_map")
    ) {
    target.sheen_roughness_map = source.sheen_roughness_map
  }
  if source.transmission_map is Some(_) &&
    (
      target.transmission_map is Some(_) ||
      nullable.contains("transmission_map")
    ) {
    target.transmission_map = source.transmission_map
  }
  if source.thickness is Some(_) &&
    (target.thickness is Some(_) || nullable.contains("thickness")) {
    target.thickness = source.thickness
  }
  if source.thickness_map is Some(_) &&
    (target.thickness_map is Some(_) || nullable.contains("thickness_map")) {
    target.thickness_map = source.thickness_map
  }
  if source.attenuation_distance is Some(_) &&
    (
      target.attenuation_distance is Some(_) ||
      nullable.contains("attenuation_distance")
    ) {
    target.attenuation_distance = source.attenuation_distance
  }
  if source.attenuation_color is Some(_) &&
    (
      target.attenuation_color is Some(_) ||
      nullable.contains("attenuation_color")
    ) {
    target.attenuation_color = source.attenuation_color
  }
  if source.specular_intensity is Some(_) &&
    (
      target.specular_intensity is Some(_) ||
      nullable.contains("specular_intensity")
    ) {
    target.specular_intensity = source.specular_intensity
  }
  if source.specular_intensity_map is Some(_) &&
    (
      target.specular_intensity_map is Some(_) ||
      nullable.contains("specular_intensity_map")
    ) {
    target.specular_intensity_map = source.specular_intensity_map
  }
  if source.specular_color is Some(_) &&
    (target.specular_color is Some(_) || nullable.contains("specular_color")) {
    target.specular_color = source.specular_color
  }
  if source.specular_color_map is Some(_) &&
    (
      target.specular_color_map is Some(_) ||
      nullable.contains("specular_color_map")
    ) {
    target.specular_color_map = source.specular_color_map
  }
  if source._anisotropy is Some(_) &&
    (target._anisotropy is Some(_) || nullable.contains("_anisotropy")) {
    target._anisotropy = source._anisotropy
  }
  if source._clearcoat is Some(_) &&
    (target._clearcoat is Some(_) || nullable.contains("_clearcoat")) {
    target._clearcoat = source._clearcoat
  }
  if source._diffuse_roughness is Some(_) &&
    (
      target._diffuse_roughness is Some(_) ||
      nullable.contains("_diffuse_roughness")
    ) {
    target._diffuse_roughness = source._diffuse_roughness
  }
  if source._dispersion is Some(_) &&
    (target._dispersion is Some(_) || nullable.contains("_dispersion")) {
    target._dispersion = source._dispersion
  }
  if source._iridescence is Some(_) &&
    (target._iridescence is Some(_) || nullable.contains("_iridescence")) {
    target._iridescence = source._iridescence
  }
  if source._retroreflectivity is Some(_) &&
    (
      target._retroreflectivity is Some(_) ||
      nullable.contains("_retroreflectivity")
    ) {
    target._retroreflectivity = source._retroreflectivity
  }
  if source._sheen is Some(_) &&
    (target._sheen is Some(_) || nullable.contains("_sheen")) {
    target._sheen = source._sheen
  }
  if source._transmission is Some(_) &&
    (target._transmission is Some(_) || nullable.contains("_transmission")) {
    target._transmission = source._transmission
  }
  if source.is_node_material() {
    for slot in @nodes.NodeMaterial::node_slots(source) {
      @nodes.NodeMaterial::set_node_slot(target, slot.0, slot.1) |> ignore
    }
  }
  if source.dispatcher._listeners is Some(_) &&
    target.dispatcher._listeners is Some(_) {
    target.dispatcher._listeners = source.dispatcher._listeners
  }
}

///|
pub impl @nodes.NodeClass for RetroPassNode with fn update_before(
  self,
  node,
  frame,
) {
  let renderer = frame.renderer.unwrap()
  let current_render_object_function = renderer.get_render_object_function()
  renderer.set_render_object_function(
    Some({
      f: fn(
        object,
        scene,
        camera,
        geometry,
        material,
        group,
        lights_node,
        clipping_context,
        pass_id,
      ) {
        let retro_material = self.retro_material(scene, material)
        renderer.render_object(
          object, scene, camera, geometry, retro_material, group, lights_node, clipping_context,
          pass_id,
        )
      },
    }),
  )
  @nodes.PassNode::update_before_base(node, frame)
  renderer.set_render_object_function(current_render_object_function)
  None
}

///|
pub impl @nodes.NodeClass for RetroPassNode with fn dispose(self, node) {
  self.pass.dispose(node)
  for entry in self._material_cache {
    entry.1.material.dispose()
  }
  self._material_cache.clear()
}

///|
/// `new RetroPassNode( scene, camera, { affineDistortion = null, filterTextures = false } )`.
pub fn RetroPassNode::new(
  scene : @core.Object3D,
  camera : @core.Object3D,
  affine_distortion? : @nodes.Node,
  filter_textures~ : Bool = false,
) -> @nodes.Node {
  display_retro_pass_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="vec4")
  let pass = @nodes.PassNode::construct(
    node,
    @nodes.PassNode::color(),
    scene,
    camera,
    @nodes.PassNodeOptions::default(),
  )
  // `this.setResolutionScale( .25 )`
  pass._resolution_scale = 0.25
  pass.render_target.texture().type_ = @core.UnsignedByteType
  pass.render_target.texture().mag_filter = @core.NearestFilter
  pass.render_target.texture().min_filter = @core.NearestFilter
  let p = RetroPassNode::{
    pass,
    affine_distortion_node: affine_distortion,
    filter_textures,
    _material_cache: [],
  }
  pass.pass_class = p
  node.set_class(p)
}

///|
pub fn RetroPassNode::of(node : @nodes.Node) -> RetroPassNode? {
  addon_class_of(node, "RetroPassNode")
}

///|
/// `retroPass( scene, camera, options = {} )`.
pub fn retro_pass(
  scene : @core.Object3D,
  camera : @core.Object3D,
  affine_distortion? : @nodes.Node,
  filter_textures~ : Bool = false,
) -> @nodes.Node {
  RetroPassNode::new(scene, camera, affine_distortion?, filter_textures~)
}

///|
/// The `MeshBasicMaterial` properties whose default is `null` (MeshBasicNodeMaterial
/// has them through `setDefaultValues`).
let retro_pass_node_basic_nullable : Array[String] = [
  "map", "light_map", "ao_map", "specular_map", "alpha_map", "env_map",
]

///|
/// The `MeshPhongMaterial` properties whose default is `null`.
let retro_pass_node_phong_nullable : Array[String] = [
  "map", "light_map", "ao_map", "emissive_map", "bump_map", "normal_map", "displacement_map",
  "specular_map", "alpha_map", "env_map",
]
