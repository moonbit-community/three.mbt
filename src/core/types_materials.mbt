// Types for upstream src/materials. `Material` is one flat struct. Properties of the
// base class are plain fields. Properties of subclasses are `Option`: `None` means
// upstream's `undefined` or `null`, so a check like `material.color !== undefined`
// becomes `material.color is Some(_)` and `toJSON` keeps its conditions.

///|
/// The class of a `Material`. `Material` also covers `NodeMaterial` and other subclasses
/// above core, which add an `extension`.
pub(all) enum MaterialType {
  Material
  LineBasicMaterial
  LineDashedMaterial
  MeshBasicMaterial
  MeshDepthMaterial
  MeshDistanceMaterial
  MeshLambertMaterial
  MeshMatcapMaterial
  MeshNormalMaterial
  MeshPhongMaterial
  MeshPhysicalMaterial
  MeshStandardMaterial
  MeshToonMaterial
  PointsMaterial
  RawShaderMaterial
  ShaderMaterial
  ShadowMaterial
  SpriteMaterial
}

///|
/// `ShaderMaterial.extensions`.
pub(all) struct ShaderExtensions {
  mut clip_cull_distance : Bool
  mut multi_draw : Bool
}

///|
/// The object passed to `on_before_compile`. `parameters` is the renderer's full
/// parameter object, opaque to core.
pub(all) struct ShaderObject {
  mut name : String
  mut uniforms : Map[String, Uniform]
  mut vertex_shader : String
  mut fragment_shader : String
  mut parameters : JsValue
}

///|
pub(all) struct Material {
  id : Int32
  dispatcher : EventDispatcher
  mut uuid : String
  mut name : String
  mut type_ : String
  mut material_type : MaterialType
  mut extension : &MaterialExtension?
  // Material
  mut blending : Int32
  mut side : Int32
  mut vertex_colors : Bool
  mut opacity : Double
  mut transparent : Bool
  mut alpha_hash : Bool
  mut blend_src : Int32
  mut blend_dst : Int32
  mut blend_equation : Int32
  mut blend_src_alpha : Int32?
  mut blend_dst_alpha : Int32?
  mut blend_equation_alpha : Int32?
  mut blend_color : @math.Color
  mut blend_alpha : Double
  mut depth_func : Int32
  mut depth_test : Bool
  mut depth_write : Bool
  mut stencil_write_mask : Int32
  mut stencil_func : Int32
  mut stencil_ref : Int32
  mut stencil_func_mask : Int32
  mut stencil_fail : Int32
  mut stencil_z_fail : Int32
  mut stencil_z_pass : Int32
  mut stencil_write : Bool
  mut clipping_planes : Array[@math.Plane]?
  mut clip_intersection : Bool
  mut clip_shadows : Bool
  mut shadow_side : Int32?
  mut color_write : Bool
  mut precision : String?
  mut polygon_offset : Bool
  mut polygon_offset_factor : Double
  mut polygon_offset_units : Double
  mut dithering : Bool
  mut alpha_to_coverage : Bool
  mut premultiplied_alpha : Bool
  mut force_single_pass : Bool
  mut allow_override : Bool
  mut visible : Bool
  mut tone_mapped : Bool
  mut user_data : JsValue
  mut version : Int32
  mut _alpha_test : Double
  // Renderer callbacks. The first argument of each is the renderer, opaque to core.
  mut on_before_render : (
    JsValue,
    Object3D,
    Object3D,
    BufferGeometry,
    Object3D,
    GeometryGroup?,
  ) -> Unit
  mut on_before_compile : ((ShaderObject, JsValue) -> Unit)?
  mut custom_program_cache_key : (() -> String)?
  // Subclass properties
  mut defines : Map[String, Json]?
  mut color : @math.Color?
  mut map : Texture?
  mut linewidth : Double?
  mut linecap : String?
  mut linejoin : String?
  mut fog : Bool?
  mut scale : Double?
  mut dash_size : Double?
  mut gap_size : Double?
  mut light_map : Texture?
  mut light_map_intensity : Double?
  mut ao_map : Texture?
  mut ao_map_intensity : Double?
  mut specular_map : Texture?
  mut alpha_map : Texture?
  mut env_map : Texture?
  mut env_map_rotation : @math.Euler?
  mut env_map_intensity : Double?
  mut combine : Int32?
  mut reflectivity : Double?
  mut refraction_ratio : Double?
  mut wireframe : Bool?
  mut wireframe_linewidth : Double?
  mut wireframe_linecap : String?
  mut wireframe_linejoin : String?
  mut depth_packing : Int32?
  mut displacement_map : Texture?
  mut displacement_scale : Double?
  mut displacement_bias : Double?
  mut emissive : @math.Color?
  mut emissive_intensity : Double?
  mut emissive_map : Texture?
  mut bump_map : Texture?
  mut bump_scale : Double?
  mut normal_map : Texture?
  mut normal_map_type : Int32?
  mut normal_scale : @math.Vector2?
  mut flat_shading : Bool?
  mut matcap : Texture?
  mut gradient_map : Texture?
  mut specular : @math.Color?
  mut shininess : Double?
  mut roughness : Double?
  mut metalness : Double?
  mut roughness_map : Texture?
  mut metalness_map : Texture?
  // PointsMaterial, SpriteMaterial
  mut size : Double?
  mut size_attenuation : Bool?
  mut rotation : Double?
  // ShaderMaterial
  mut uniforms : Map[String, Uniform]?
  mut uniforms_groups : Array[UniformsGroup]?
  mut vertex_shader : String?
  mut fragment_shader : String?
  mut lights : Bool?
  mut clipping : Bool?
  mut extensions : ShaderExtensions?
  mut default_attribute_values : Map[String, Array[Double]]?
  mut index0_attribute_name : String?
  mut uniforms_need_update : Bool?
  mut glsl_version : String?
  // MeshPhysicalMaterial
  mut anisotropy_rotation : Double?
  mut anisotropy_map : Texture?
  mut clearcoat_map : Texture?
  mut clearcoat_roughness : Double?
  mut clearcoat_roughness_map : Texture?
  mut clearcoat_normal_scale : @math.Vector2?
  mut clearcoat_normal_map : Texture?
  mut diffuse_roughness_map : Texture?
  mut ior : Double?
  mut iridescence_map : Texture?
  mut iridescence_ior : Double?
  mut iridescence_thickness_minimum : Double?
  mut iridescence_thickness_maximum : Double?
  mut iridescence_thickness_map : Texture?
  mut sheen_color : @math.Color?
  mut sheen_color_map : Texture?
  mut sheen_roughness : Double?
  mut sheen_roughness_map : Texture?
  mut transmission_map : Texture?
  mut thickness : Double?
  mut thickness_map : Texture?
  mut attenuation_distance : Double?
  mut attenuation_color : @math.Color?
  mut specular_intensity : Double?
  mut specular_intensity_map : Texture?
  mut specular_color : @math.Color?
  mut specular_color_map : Texture?
  mut _anisotropy : Double?
  mut _clearcoat : Double?
  mut _diffuse_roughness : Double?
  mut _dispersion : Double?
  mut _iridescence : Double?
  mut _retroreflectivity : Double?
  mut _sheen : Double?
  mut _transmission : Double?
}
