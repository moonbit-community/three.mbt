// Upstream src/animation/PropertyBinding.js.
//
// Upstream resolves a track name such as `bones[Hips].quaternion` or `material.opacity`
// by reading `object[ name ]` at runtime. Here every step goes through a binding table
// (`Target::lookup`): for each kind of object a path can reach (`Object3D` and its core
// subclasses, `Material`, `Texture`, fog, light shadows, bone/child/material arrays,
// vectors, quaternions, Eulers, colors, matrices, number arrays) it maps upstream's
// property names to a typed accessor. A name the table knows but this object lacks is
// upstream's `undefined` (logged, and the binding does nothing, as upstream). A name the
// table does not know aborts with upstream's error text.
//
// Mixer buffers are `Array[Double]`: booleans are stored as 0 / 1 and strings as indices
// into a string table (see `intern_string`), so the mixing code stays numeric.

///|
/// The result of `parseTrackName`; `None` is upstream's `undefined`.
#derive(Eq, Debug)
pub(all) struct ParsedPath {
  mut node_name : String?
  mut object_name : String?
  mut object_index : String?
  mut property_name : String
  mut property_index : String?
}

///|
pub extend ParsedPath with Eq::{equal, not_equal}

///|
pub extend ParsedPath with Debug::{to_repr}

///|
/// `propertyIndex` after binding: a name, or a morph target index looked up by name.
#derive(Eq, Debug)
pub(all) enum PropertyKey {
  Name(String)
  Index(Int32)
}

///|
pub extend PropertyKey with Eq::{equal, not_equal}

///|
pub extend PropertyKey with Debug::{to_repr}

///|
fn PropertyKey::to_key(self : PropertyKey) -> String {
  match self {
    Name(name) => name
    Index(index) => index.to_string()
  }
}

///|
/// The root a mixer or binding animates: an object, or an `AnimationObjectGroup`.
pub(all) enum AnimationRoot {
  Object3D(@core.Object3D)
  Group(AnimationObjectGroup)
}

///|
pub fn AnimationRoot::uuid(self : AnimationRoot) -> String {
  match self {
    Object3D(object) => object.uuid
    Group(group) => group.uuid
  }
}

///|
/// Values that can be the root of an `AnimationMixer`.
pub(open) trait ToAnimationRoot {
  fn to_animation_root(Self) -> AnimationRoot
}

///|
pub impl ToAnimationRoot for @core.Object3D with fn to_animation_root(self) {
  Object3D(self)
}

///|
pub impl ToAnimationRoot for AnimationObjectGroup with fn to_animation_root(
  self,
) {
  Group(self)
}

///|
pub impl ToAnimationRoot for AnimationRoot with fn to_animation_root(self) {
  self
}

///|
pub extend AnimationObjectGroup with ToAnimationRoot::{to_animation_root}

///|
pub extend AnimationRoot with ToAnimationRoot::{to_animation_root}

// --- The binding table -------------------------------------------------------------

///|
/// A value a track path reaches.
priv enum Target {
  Object3D(@core.Object3D)
  Material(@core.Material)
  Texture(@core.Texture)
  Fog(@core.SceneFog)
  Shadow(@core.LightShadow)
  Objects(Array[@core.Object3D])
  Materials(Array[@core.Material])
  Numbers(Array[Double])
  Vector2(@math.Vector2)
  Vector3(@math.Vector3)
  Vector4(@math.Vector4)
  Quaternion(@math.Quaternion)
  Euler(@math.Euler)
  Color(@math.Color)
  Matrix3(@math.Matrix3)
  Matrix4(@math.Matrix4)
  SphericalHarmonics3(@math.SphericalHarmonics3)
  /// A number, boolean or string reached as an object.
  Primitive
  /// `null`.
  Null
}

///|
/// A primitive property, encoded as a buffer number.
priv struct Scalar {
  get : () -> Double
  set : (Double) -> Unit
}

///|
/// What `object[ name ]` gives.
priv enum Lookup {
  /// Not in the binding table.
  Unknown
  /// An upstream property the table cannot bind (textures, integer enums, ...).
  Unsupported
  /// Upstream's `undefined`: the name exists in the table, but not on this object.
  Undefined
  /// `undefined` too, but the object has a slot for it: `object[ name ] = value`
  /// creates the property, as an array element binding does upstream.
  Absent(Scalar)
  Value(Target)
  Scalar(Scalar)
}

///|
fn num(get : () -> Double, set : (Double) -> Unit) -> Lookup {
  Scalar({ get, set, })
}

///|
fn flag(get : () -> Bool, set : (Bool) -> Unit) -> Lookup {
  Scalar({
    get: () => if get() { 1.0 } else { 0.0 },
    // `undefined` is falsy
    set: v => set(v != undefined_slot_value && js_truthy(v)),
  })
}

///|
fn text(get : () -> String, set : (String) -> Unit) -> Lookup {
  Scalar({ get: () => intern_string(get()), set: v => set(interned_string(v)), })
}

///|
fn opt_num(get : () -> Double?, set : (Double) -> Unit) -> Lookup {
  let scalar = { get: () => get().unwrap_or(@double.not_a_number), set, }
  if get() is None {
    Absent(scalar)
  } else {
    Scalar(scalar)
  }
}

///|
/// `Absent` counts as `undefined` except for array element bindings.
fn Lookup::defined(self : Lookup) -> Lookup {
  match self {
    Absent(_) => Undefined
    other => other
  }
}

///|
fn opt_flag(get : () -> Bool?, set : (Bool) -> Unit) -> Lookup {
  guard flag(() => get().unwrap_or(false), set) is Scalar(scalar) else {
    panic()
  }
  if get() is None {
    Absent(scalar)
  } else {
    Scalar(scalar)
  }
}

///|
fn opt_value(value : Target?) -> Lookup {
  match value {
    Some(value) => Value(value)
    None => Undefined
  }
}

///|
fn Target::identity(self : Target) -> @core.JsValue {
  match self {
    Object3D(o) => @core.JsValue::of(o)
    Material(m) => @core.JsValue::of(m)
    Texture(t) => @core.JsValue::of(t)
    Fog(f) => @core.JsValue::of(f)
    Shadow(s) => @core.JsValue::of(s)
    Objects(a) => @core.JsValue::of(a)
    Materials(a) => @core.JsValue::of(a)
    Numbers(a) => @core.JsValue::of(a)
    Vector2(v) => @core.JsValue::of(v)
    Vector3(v) => @core.JsValue::of(v)
    Vector4(v) => @core.JsValue::of(v)
    Quaternion(q) => @core.JsValue::of(q)
    Euler(e) => @core.JsValue::of(e)
    Color(c) => @core.JsValue::of(c)
    Matrix3(m) => @core.JsValue::of(m)
    Matrix4(m) => @core.JsValue::of(m)
    SphericalHarmonics3(sh) => @core.JsValue::of(sh)
    Primitive | Null => @core.JsValue::null()
  }
}

///|
/// `object[ key ]`.
fn Target::lookup(self : Target, key : String) -> Lookup {
  match self {
    Object3D(o) => object3d_lookup(o, key)
    Material(m) => material_lookup(m, key)
    Texture(t) => texture_lookup(t, key)
    Fog(f) => fog_lookup(f, key)
    Shadow(s) => shadow_lookup(s, key)
    Objects(a) =>
      match array_index_of_key(key) {
        Some(i) if i < a.length() => Value(Object3D(a[i]))
        _ => Undefined
      }
    Materials(a) =>
      match array_index_of_key(key) {
        Some(i) if i < a.length() => Value(Material(a[i]))
        _ => Undefined
      }
    Numbers(a) =>
      match array_index_of_key(key) {
        Some(i) if i < a.length() => num(() => a[i], v => a[i] = v)
        _ => Undefined
      }
    Vector2(v) =>
      match key {
        "x" => num(() => v.x, x => v.x = x)
        "y" => num(() => v.y, y => v.y = y)
        "width" => num(() => v.width(), x => v.set_width(x))
        "height" => num(() => v.height(), y => v.set_height(y))
        _ => Undefined
      }
    Vector3(v) =>
      match key {
        "x" => num(() => v.x, x => v.x = x)
        "y" => num(() => v.y, y => v.y = y)
        "z" => num(() => v.z, z => v.z = z)
        _ => Undefined
      }
    Vector4(v) =>
      match key {
        "x" => num(() => v.x, x => v.x = x)
        "y" => num(() => v.y, y => v.y = y)
        "z" => num(() => v.z, z => v.z = z)
        "w" => num(() => v.w, w => v.w = w)
        "width" => num(() => v.width(), z => v.set_width(z))
        "height" => num(() => v.height(), w => v.set_height(w))
        _ => Undefined
      }
    Quaternion(q) =>
      match key {
        "x" => num(() => q.x, x => q.set_x(x))
        "y" => num(() => q.y, y => q.set_y(y))
        "z" => num(() => q.z, z => q.set_z(z))
        "w" => num(() => q.w, w => q.set_w(w))
        _ => Undefined
      }
    Euler(e) =>
      match key {
        "x" => num(() => e.x, x => e.set_x(x))
        "y" => num(() => e.y, y => e.set_y(y))
        "z" => num(() => e.z, z => e.set_z(z))
        "order" => text(() => e.order, order => e.set_order(order))
        _ => Undefined
      }
    Color(c) =>
      match key {
        "r" => num(() => c.r, r => c.r = r)
        "g" => num(() => c.g, g => c.g = g)
        "b" => num(() => c.b, b => c.b = b)
        _ => Undefined
      }
    Matrix3(m) =>
      if key == "elements" {
        Value(Numbers(m.elements))
      } else {
        Undefined
      }
    Matrix4(m) =>
      if key == "elements" {
        Value(Numbers(m.elements))
      } else {
        Undefined
      }
    SphericalHarmonics3(_) => Undefined
    Primitive => Undefined
    Null =>
      abort("TypeError: Cannot read properties of null (reading '" + key + "')")
  }
}

///|
fn object3d_lookup(o : @core.Object3D, key : String) -> Lookup {
  match key {
    "position" => Value(Vector3(o.position))
    "scale" => Value(Vector3(o.scale))
    "up" => Value(Vector3(o.up))
    "quaternion" => Value(Quaternion(o.quaternion))
    "rotation" => Value(Euler(o.rotation))
    "matrix" => Value(Matrix4(o.matrix))
    "matrixWorld" => Value(Matrix4(o.matrix_world))
    "visible" => flag(() => o.visible, v => o.visible = v)
    "castShadow" => flag(() => o.cast_shadow, v => o.cast_shadow = v)
    "receiveShadow" => flag(() => o.receive_shadow, v => o.receive_shadow = v)
    "frustumCulled" => flag(() => o.frustum_culled, v => o.frustum_culled = v)
    "matrixAutoUpdate" =>
      flag(() => o.matrix_auto_update, v => o.matrix_auto_update = v)
    "matrixWorldAutoUpdate" =>
      flag(() => o.matrix_world_auto_update, v => o.matrix_world_auto_update = v)
    "matrixWorldNeedsUpdate" =>
      flag(() => o.matrix_world_needs_update, v => {
        o.matrix_world_needs_update = v
      })
    "renderOrder" => num(() => o.render_order, v => o.render_order = v)
    "name" => text(() => o.name, v => o.name = v)
    "children" => Value(Objects(o.children))
    "parent" =>
      match o.parent {
        Some(parent) => Value(Object3D(parent))
        None => Value(Null)
      }
    "morphTargetInfluences" =>
      opt_value(o.morph_targets().1.map(x => Numbers(x)))
    "material" =>
      match o.get_material() {
        Some(Single(material)) => Value(Material(material))
        Some(Multiple(materials)) => Value(Materials(materials))
        None => Undefined
      }
    "center" =>
      match o.kind {
        Sprite(sprite) => Value(Vector2(sprite.center))
        _ => Undefined
      }
    "autoUpdate" =>
      match o.kind {
        LOD(lod) => flag(() => lod.auto_update, v => lod.auto_update = v)
        _ => Undefined
      }
    "enabled" | "clipIntersection" | "clipShadows" =>
      match o.kind {
        ClippingGroup(group) =>
          match key {
            "enabled" => flag(() => group.enabled, v => group.enabled = v)
            "clipIntersection" =>
              flag(() => group.clip_intersection, v => {
                group.clip_intersection = v
              })
            _ => flag(() => group.clip_shadows, v => group.clip_shadows = v)
          }
        _ => Undefined
      }
    // lights
    "intensity"
    | "color"
    | "power"
    | "distance"
    | "decay"
    | "angle"
    | "penumbra"
    | "groundColor"
    | "width"
    | "height"
    | "target"
    | "shadow"
    | "map"
    | "sh" =>
      match o.kind {
        Light(light) => light_lookup(o, light, key)
        _ => Undefined
      }
    // cameras
    "fov"
    | "zoom"
    | "near"
    | "far"
    | "focus"
    | "aspect"
    | "filmGauge"
    | "filmOffset"
    | "left"
    | "right"
    | "top"
    | "bottom" =>
      match o.kind {
        Camera({ kind: PerspectiveCamera(camera), .. }) =>
          match key {
            "fov" => num(() => camera.fov, v => camera.fov = v)
            "zoom" => num(() => camera.zoom, v => camera.zoom = v)
            "near" => num(() => camera.near, v => camera.near = v)
            "far" => num(() => camera.far, v => camera.far = v)
            "focus" => num(() => camera.focus, v => camera.focus = v)
            "aspect" => num(() => camera.aspect, v => camera.aspect = v)
            "filmGauge" =>
              num(() => camera.film_gauge, v => camera.film_gauge = v)
            "filmOffset" =>
              num(() => camera.film_offset, v => camera.film_offset = v)
            _ => Undefined
          }
        Camera({ kind: OrthographicCamera(camera), .. }) =>
          match key {
            "zoom" => num(() => camera.zoom, v => camera.zoom = v)
            "near" => num(() => camera.near, v => camera.near = v)
            "far" => num(() => camera.far, v => camera.far = v)
            "left" => num(() => camera.left, v => camera.left = v)
            "right" => num(() => camera.right, v => camera.right = v)
            "top" => num(() => camera.top, v => camera.top = v)
            "bottom" => num(() => camera.bottom, v => camera.bottom = v)
            _ => Undefined
          }
        _ => Undefined
      }
    // scenes
    "backgroundBlurriness"
    | "backgroundIntensity"
    | "environmentIntensity"
    | "backgroundRotation"
    | "environmentRotation"
    | "fog" =>
      match o.kind {
        Scene(scene) =>
          match key {
            "backgroundBlurriness" =>
              num(() => scene.background_blurriness, v => {
                scene.background_blurriness = v
              })
            "backgroundIntensity" =>
              num(() => scene.background_intensity, v => {
                scene.background_intensity = v
              })
            "environmentIntensity" =>
              num(() => scene.environment_intensity, v => {
                scene.environment_intensity = v
              })
            "backgroundRotation" => Value(Euler(scene.background_rotation))
            "environmentRotation" => Value(Euler(scene.environment_rotation))
            _ =>
              match scene.fog {
                Some(fog) => Value(Fog(fog))
                None => Value(Null)
              }
          }
        _ => Undefined
      }
    "geometry" =>
      if o.get_geometry() is Some(_) {
        Unsupported
      } else {
        Undefined
      }
    "id"
    | "uuid"
    | "type"
    | "layers"
    | "userData"
    | "animations"
    | "modelViewMatrix"
    | "normalMatrix"
    | "customDepthMaterial"
    | "customDistanceMaterial"
    | "static"
    | "pivot"
    | "skeleton"
    | "bindMode"
    | "bindMatrix"
    | "bindMatrixInverse"
    | "morphTargetDictionary"
    | "count"
    | "instanceMatrix"
    | "instanceColor"
    | "levels"
    | "background"
    | "environment"
    | "overrideMaterial"
    | "projectionMatrix"
    | "projectionMatrixInverse"
    | "matrixWorldInverse"
    | "view" => Unsupported
    _ => Unknown
  }
}

///|
fn light_lookup(
  o : @core.Object3D,
  light : @core.Light,
  key : String,
) -> Lookup {
  match (key, light.kind) {
    ("intensity", _) => num(() => light.intensity, v => light.intensity = v)
    ("color", _) => Value(Color(light.color))
    ("shadow", _) => opt_value(light.shadow.map(x => Shadow(x)))
    ("power", PointLight(_) | SpotLight(_) | RectAreaLight(_)) =>
      num(() => o.power(), v => o.set_power(v))
    ("distance", PointLight(point)) =>
      num(() => point.distance, v => point.distance = v)
    ("decay", PointLight(point)) => num(() => point.decay, v => point.decay = v)
    ("distance", SpotLight(spot)) =>
      num(() => spot.distance, v => spot.distance = v)
    ("decay", SpotLight(spot)) => num(() => spot.decay, v => spot.decay = v)
    ("angle", SpotLight(spot)) => num(() => spot.angle, v => spot.angle = v)
    ("penumbra", SpotLight(spot)) =>
      num(() => spot.penumbra, v => spot.penumbra = v)
    ("map", SpotLight(spot)) =>
      match spot.map {
        Some(map) => Value(Texture(map))
        None => Value(Null)
      }
    ("target", SpotLight(spot)) => Value(Object3D(spot.target))
    ("target", DirectionalLight(directional)) =>
      Value(Object3D(directional.target))
    ("groundColor", HemisphereLight(hemisphere)) =>
      Value(Color(hemisphere.ground_color))
    ("width", RectAreaLight(rect)) => num(() => rect.width, v => rect.width = v)
    ("height", RectAreaLight(rect)) =>
      num(() => rect.height, v => rect.height = v)
    ("sh", LightProbe(probe)) => Value(SphericalHarmonics3(probe.sh))
    _ => Undefined
  }
}

///|
fn material_lookup(m : @core.Material, key : String) -> Lookup {
  match key {
    "opacity" => num(() => m.opacity, v => m.opacity = v)
    "alphaTest" => num(() => m.alpha_test(), v => m.set_alpha_test(v))
    "blendAlpha" => num(() => m.blend_alpha, v => m.blend_alpha = v)
    "polygonOffsetFactor" =>
      num(() => m.polygon_offset_factor, v => m.polygon_offset_factor = v)
    "polygonOffsetUnits" =>
      num(() => m.polygon_offset_units, v => m.polygon_offset_units = v)
    "blendColor" => Value(Color(m.blend_color))
    "name" => text(() => m.name, v => m.name = v)
    "transparent" => flag(() => m.transparent, v => m.transparent = v)
    "alphaHash" => flag(() => m.alpha_hash, v => m.alpha_hash = v)
    "vertexColors" => flag(() => m.vertex_colors, v => m.vertex_colors = v)
    "depthTest" => flag(() => m.depth_test, v => m.depth_test = v)
    "depthWrite" => flag(() => m.depth_write, v => m.depth_write = v)
    "stencilWrite" => flag(() => m.stencil_write, v => m.stencil_write = v)
    "clipIntersection" =>
      flag(() => m.clip_intersection, v => m.clip_intersection = v)
    "clipShadows" => flag(() => m.clip_shadows, v => m.clip_shadows = v)
    "colorWrite" => flag(() => m.color_write, v => m.color_write = v)
    "polygonOffset" => flag(() => m.polygon_offset, v => m.polygon_offset = v)
    "dithering" => flag(() => m.dithering, v => m.dithering = v)
    "alphaToCoverage" =>
      flag(() => m.alpha_to_coverage, v => m.alpha_to_coverage = v)
    "premultipliedAlpha" =>
      flag(() => m.premultiplied_alpha, v => m.premultiplied_alpha = v)
    "forceSinglePass" =>
      flag(() => m.force_single_pass, v => m.force_single_pass = v)
    "allowOverride" => flag(() => m.allow_override, v => m.allow_override = v)
    "visible" => flag(() => m.visible, v => m.visible = v)
    "toneMapped" => flag(() => m.tone_mapped, v => m.tone_mapped = v)
    // subclass numbers
    "linewidth" => opt_num(() => m.linewidth, v => m.linewidth = Some(v))
    "scale" => opt_num(() => m.scale, v => m.scale = Some(v))
    "dashSize" => opt_num(() => m.dash_size, v => m.dash_size = Some(v))
    "gapSize" => opt_num(() => m.gap_size, v => m.gap_size = Some(v))
    "lightMapIntensity" =>
      opt_num(() => m.light_map_intensity, v => m.light_map_intensity = Some(v))
    "aoMapIntensity" =>
      opt_num(() => m.ao_map_intensity, v => m.ao_map_intensity = Some(v))
    "envMapIntensity" =>
      opt_num(() => m.env_map_intensity, v => m.env_map_intensity = Some(v))
    "refractionRatio" =>
      opt_num(() => m.refraction_ratio, v => m.refraction_ratio = Some(v))
    "wireframeLinewidth" =>
      opt_num(() => m.wireframe_linewidth, v => m.wireframe_linewidth = Some(v))
    "displacementScale" =>
      opt_num(() => m.displacement_scale, v => m.displacement_scale = Some(v))
    "displacementBias" =>
      opt_num(() => m.displacement_bias, v => m.displacement_bias = Some(v))
    "emissiveIntensity" =>
      opt_num(() => m.emissive_intensity, v => m.emissive_intensity = Some(v))
    "bumpScale" => opt_num(() => m.bump_scale, v => m.bump_scale = Some(v))
    "shininess" => opt_num(() => m.shininess, v => m.shininess = Some(v))
    "roughness" => opt_num(() => m.roughness, v => m.roughness = Some(v))
    "metalness" => opt_num(() => m.metalness, v => m.metalness = Some(v))
    "size" => opt_num(() => m.size, v => m.size = Some(v))
    "rotation" => opt_num(() => m.rotation, v => m.rotation = Some(v))
    "anisotropyRotation" =>
      opt_num(() => m.anisotropy_rotation, v => m.anisotropy_rotation = Some(v))
    "clearcoatRoughness" =>
      opt_num(() => m.clearcoat_roughness, v => m.clearcoat_roughness = Some(v))
    "ior" => opt_num(() => m.ior, v => m.ior = Some(v))
    "iridescenceIOR" =>
      opt_num(() => m.iridescence_ior, v => m.iridescence_ior = Some(v))
    "sheenRoughness" =>
      opt_num(() => m.sheen_roughness, v => m.sheen_roughness = Some(v))
    "thickness" => opt_num(() => m.thickness, v => m.thickness = Some(v))
    "attenuationDistance" =>
      opt_num(() => m.attenuation_distance, v => {
        m.attenuation_distance = Some(v)
      })
    "specularIntensity" =>
      opt_num(() => m.specular_intensity, v => m.specular_intensity = Some(v))
    // accessors
    "reflectivity" =>
      opt_num(() => m.reflectivity(), v => m.set_reflectivity(v))
    "anisotropy" => opt_num(() => m.anisotropy(), v => m.set_anisotropy(v))
    "clearcoat" => opt_num(() => m.clearcoat(), v => m.set_clearcoat(v))
    "diffuseRoughness" =>
      opt_num(() => m.diffuse_roughness(), v => m.set_diffuse_roughness(v))
    "dispersion" => opt_num(() => m.dispersion(), v => m.set_dispersion(v))
    "iridescence" => opt_num(() => m.iridescence(), v => m.set_iridescence(v))
    "retroreflectivity" =>
      opt_num(() => m.retroreflectivity(), v => m.set_retroreflectivity(v))
    "sheen" => opt_num(() => m.sheen(), v => m.set_sheen(v))
    "transmission" =>
      opt_num(() => m.transmission(), v => m.set_transmission(v))
    // subclass booleans and strings
    "fog" => opt_flag(() => m.fog, v => m.fog = Some(v))
    "wireframe" => opt_flag(() => m.wireframe, v => m.wireframe = Some(v))
    "flatShading" =>
      opt_flag(() => m.flat_shading, v => m.flat_shading = Some(v))
    "sizeAttenuation" =>
      opt_flag(() => m.size_attenuation, v => m.size_attenuation = Some(v))
    "lights" => opt_flag(() => m.lights, v => m.lights = Some(v))
    "clipping" => opt_flag(() => m.clipping, v => m.clipping = Some(v))
    "linecap" =>
      match m.linecap {
        Some(_) => text(() => m.linecap.unwrap_or(""), v => m.linecap = Some(v))
        None => Undefined
      }
    "linejoin" =>
      match m.linejoin {
        Some(_) =>
          text(() => m.linejoin.unwrap_or(""), v => m.linejoin = Some(v))
        None => Undefined
      }
    // subclass colors and vectors
    "color" => opt_value(m.color.map(x => Color(x)))
    "emissive" => opt_value(m.emissive.map(x => Color(x)))
    "specular" => opt_value(m.specular.map(x => Color(x)))
    "sheenColor" => opt_value(m.sheen_color.map(x => Color(x)))
    "attenuationColor" => opt_value(m.attenuation_color.map(x => Color(x)))
    "specularColor" => opt_value(m.specular_color.map(x => Color(x)))
    "normalScale" => opt_value(m.normal_scale.map(x => Vector2(x)))
    "clearcoatNormalScale" =>
      opt_value(m.clearcoat_normal_scale.map(x => Vector2(x)))
    "envMapRotation" => opt_value(m.env_map_rotation.map(x => Euler(x)))
    "id"
    | "uuid"
    | "type"
    | "blending"
    | "side"
    | "blendSrc"
    | "blendDst"
    | "blendEquation"
    | "blendSrcAlpha"
    | "blendDstAlpha"
    | "blendEquationAlpha"
    | "depthFunc"
    | "stencilWriteMask"
    | "stencilFunc"
    | "stencilRef"
    | "stencilFuncMask"
    | "stencilFail"
    | "stencilZFail"
    | "stencilZPass"
    | "clippingPlanes"
    | "shadowSide"
    | "precision"
    | "userData"
    | "version"
    | "defines"
    | "combine"
    | "depthPacking"
    | "normalMapType"
    | "wireframeLinecap"
    | "wireframeLinejoin"
    | "uniforms"
    | "uniformsGroups"
    | "vertexShader"
    | "fragmentShader"
    | "extensions"
    | "defaultAttributeValues"
    | "index0AttributeName"
    | "uniformsNeedUpdate"
    | "glslVersion"
    | "iridescenceThicknessRange"
    | "map"
    | "lightMap"
    | "aoMap"
    | "specularMap"
    | "alphaMap"
    | "envMap"
    | "displacementMap"
    | "emissiveMap"
    | "bumpMap"
    | "normalMap"
    | "matcap"
    | "gradientMap"
    | "roughnessMap"
    | "metalnessMap"
    | "anisotropyMap"
    | "clearcoatMap"
    | "clearcoatRoughnessMap"
    | "clearcoatNormalMap"
    | "diffuseRoughnessMap"
    | "iridescenceMap"
    | "iridescenceThicknessMap"
    | "sheenColorMap"
    | "sheenRoughnessMap"
    | "transmissionMap"
    | "thicknessMap"
    | "specularIntensityMap"
    | "specularColorMap" => Unsupported
    _ => Unknown
  }
}

///|
fn texture_lookup(t : @core.Texture, key : String) -> Lookup {
  match key {
    "offset" => Value(Vector2(t.offset))
    "repeat" => Value(Vector2(t.repeat))
    "center" => Value(Vector2(t.center))
    "rotation" => num(() => t.rotation, v => t.rotation = v)
    "matrix" => Value(Matrix3(t.matrix))
    "name" => text(() => t.name, v => t.name = v)
    "flipY" => flag(() => t.flip_y, v => t.flip_y = v)
    "matrixAutoUpdate" =>
      flag(() => t.matrix_auto_update, v => t.matrix_auto_update = v)
    "premultiplyAlpha" =>
      flag(() => t.premultiply_alpha, v => t.premultiply_alpha = v)
    "generateMipmaps" =>
      flag(() => t.generate_mipmaps, v => t.generate_mipmaps = v)
    "id"
    | "uuid"
    | "image"
    | "source"
    | "mipmaps"
    | "mapping"
    | "channel"
    | "wrapS"
    | "wrapT"
    | "wrapR"
    | "magFilter"
    | "minFilter"
    | "anisotropy"
    | "format"
    | "internalFormat"
    | "type"
    | "unpackAlignment"
    | "colorSpace"
    | "userData"
    | "version" => Unsupported
    _ => Unknown
  }
}

///|
fn fog_lookup(fog : @core.SceneFog, key : String) -> Lookup {
  match (fog, key) {
    (Fog(f), "name") => text(() => f.name, v => f.name = v)
    (Fog(f), "color") => Value(Color(f.color))
    (Fog(f), "near") => num(() => f.near, v => f.near = v)
    (Fog(f), "far") => num(() => f.far, v => f.far = v)
    (Fog(_), "density") => Undefined
    (FogExp2(f), "name") => text(() => f.name, v => f.name = v)
    (FogExp2(f), "color") => Value(Color(f.color))
    (FogExp2(f), "density") => num(() => f.density, v => f.density = v)
    (FogExp2(_), "near" | "far") => Undefined
    _ => Unknown
  }
}

///|
fn shadow_lookup(s : @core.LightShadow, key : String) -> Lookup {
  match key {
    "intensity" => num(() => s.intensity, v => s.intensity = v)
    "bias" => num(() => s.bias, v => s.bias = v)
    "normalBias" => num(() => s.normal_bias, v => s.normal_bias = v)
    "radius" => num(() => s.radius, v => s.radius = v)
    "mapSize" => Value(Vector2(s.map_size))
    "camera" => Value(Object3D(s.camera))
    "matrix" => Value(Matrix4(s.matrix))
    "autoUpdate" => flag(() => s.auto_update, v => s.auto_update = v)
    "needsUpdate" => flag(() => s.needs_update, v => s.needs_update = v)
    "blurSamples" | "mapType" | "map" | "mapPass" => Unsupported
    _ => Unknown
  }
}

///|
/// `toArray` / `fromArray` of the values that have them. Reads past the end of the
/// buffer give NaN, writes past it are dropped, as with upstream's `Float64Array`.
fn Target::to_from_array(
  self : Target,
) -> ((Array[Double], Int32) -> Unit, (Array[Double], Int32) -> Unit)? {
  fn read(buffer : Array[Double], offset : Int32, n : Int32) -> Array[Double] {
    Array::makei(n, i => buffer_get(buffer, offset + i))
  }

  fn write(
    buffer : Array[Double],
    offset : Int32,
    values : Array[Double],
  ) -> Unit {
    for i, v in values {
      buffer_set(buffer, offset + i, v)
    }
  }

  match self {
    Vector2(v) =>
      Some(
        (
          (b, o) => write(b, o, [v.x, v.y]),
          (b, o) => v.from_array(read(b, o, 2)) |> ignore,
        ),
      )
    Vector3(v) =>
      Some(
        (
          (b, o) => write(b, o, [v.x, v.y, v.z]),
          (b, o) => v.from_array(read(b, o, 3)) |> ignore,
        ),
      )
    Vector4(v) =>
      Some(
        (
          (b, o) => write(b, o, [v.x, v.y, v.z, v.w]),
          (b, o) => v.from_array(read(b, o, 4)) |> ignore,
        ),
      )
    Quaternion(q) =>
      Some(
        (
          (b, o) => write(b, o, [q.x, q.y, q.z, q.w]),
          (b, o) => q.from_array(read(b, o, 4)) |> ignore,
        ),
      )
    Color(c) =>
      Some(
        (
          (b, o) => write(b, o, [c.r, c.g, c.b]),
          (b, o) => c.from_array(read(b, o, 3)) |> ignore,
        ),
      )
    Matrix3(m) =>
      Some(
        (
          (b, o) => write(b, o, m.elements.copy()),
          (b, o) => m.from_array(read(b, o, 9)) |> ignore,
        ),
      )
    Matrix4(m) =>
      Some(
        (
          (b, o) => write(b, o, m.elements.copy()),
          (b, o) => m.from_array(read(b, o, 16)) |> ignore,
        ),
      )
    SphericalHarmonics3(sh) =>
      Some(
        (
          (b, o) => write(b, o, sh.to_array()),
          (b, o) => sh.from_array(read(b, o, 27)) |> ignore,
        ),
      )
    _ => None
  }
}

// --- Parsing -----------------------------------------------------------------------

///|
/// Upstream's `_trackRe`, built from the same source strings.
extern "js" fn js_track_re_exec(track_name : String) -> @core.JsValue =
  #|(() => {
  #|  const _RESERVED_CHARS_RE = '\\[\\]\\.:\\/';
  #|  const _wordChar = '[^' + _RESERVED_CHARS_RE + ']';
  #|  const _wordCharOrDot = '[^' + _RESERVED_CHARS_RE.replace( '\\.', '' ) + ']';
  #|  const _directoryRe = /((?:WC+[\/:])*)/.source.replace( 'WC', _wordChar );
  #|  const _nodeRe = /(WCOD+)?/.source.replace( 'WCOD', _wordCharOrDot );
  #|  const _objectRe = /(?:\.(WC+)(?:\[(.+)\])?)?/.source.replace( 'WC', _wordChar );
  #|  const _propertyRe = /\.(WC+)(?:\[(.+)\])?/.source.replace( 'WC', _wordChar );
  #|  const _trackRe = new RegExp( ''
  #|    + '^'
  #|    + _directoryRe
  #|    + _nodeRe
  #|    + _objectRe
  #|    + _propertyRe
  #|    + '$'
  #|  );
  #|  return ( trackName ) => _trackRe.exec( trackName );
  #|})()

///|
/// Upstream's `sanitizeNodeName` with its `_reservedRe`.
extern "js" fn js_sanitize_node_name(name : String) -> String =
  #|(() => {
  #|  const _RESERVED_CHARS_RE = '\\[\\]\\.:\\/';
  #|  const _reservedRe = new RegExp( '[' + _RESERVED_CHARS_RE + ']', 'g' );
  #|  return ( name ) => name.replace( /\s/g, '_' ).replace( _reservedRe, '' );
  #|})()

///|
let property_binding_supported_object_names : Array[String] = [
  "material", "materials", "bones", "map",
]

///|
priv enum BindingState {
  Unbound
  Unavailable
  Bound((Array[Double], Int32) -> Unit, (Array[Double], Int32) -> Unit)
}

///|
/// Holds a reference to a property in the scene graph.
pub(all) struct PropertyBinding {
  path : String
  parsed_path : ParsedPath
  mut node : @core.Object3D?
  root_node : @core.Object3D
  /// Set by `bind` for direct bindings.
  mut property_name : String?
  /// Set by `bind` for array element bindings.
  mut property_index : PropertyKey?
  priv mut target_object : Target?
  priv mut state : BindingState
}

///|
pub fn PropertyBinding::new(
  root_node : @core.Object3D,
  path : String,
  parsed_path? : ParsedPath,
) -> PropertyBinding {
  let parsed_path = match parsed_path {
    Some(parsed_path) => parsed_path
    None => PropertyBinding::parse_track_name(path)
  }
  {
    path,
    parsed_path,
    node: PropertyBinding::find_node(root_node, parsed_path.node_name),
    root_node,
    property_name: None,
    property_index: None,
    target_object: None,
    state: Unbound,
  }
}

///|
/// A binding, or a `Composite` when `root` is an `AnimationObjectGroup`.
pub fn[R : ToAnimationRoot] PropertyBinding::create(
  root : R,
  path : String,
  parsed_path? : ParsedPath,
) -> AnyPropertyBinding {
  match root.to_animation_root() {
    Object3D(root) => Single(PropertyBinding::new(root, path, parsed_path?))
    Group(group) => Composite(Composite::new(group, path, parsed_path?))
  }
}

///|
/// Replaces spaces with underscores and removes reserved characters, so the name can be
/// used in a track name.
pub fn PropertyBinding::sanitize_node_name(name : String) -> String {
  js_sanitize_node_name(name)
}

///|
extern "js" fn js_match_group(
  matches : @core.JsValue,
  index : Int32,
) -> @core.JsValue = "(m, i) => m[i]"

///|
pub fn PropertyBinding::parse_track_name(track_name : String) -> ParsedPath {
  let matches = js_track_re_exec(track_name)
  if matches.is_null() {
    abort("THREE.PropertyBinding: Cannot parse trackName: " + track_name)
  }
  fn group(i : Int32) -> String? {
    let value = js_match_group(matches, i)
    if value.is_undefined() {
      None
    } else {
      Some(value.cast())
    }
  }

  let results = {
    // directoryName: matches[ 1 ], // (tschw) currently unused
    node_name: group(2),
    object_name: group(3),
    object_index: group(4),
    property_name: group(5).unwrap_or(""), // required
    property_index: group(6),
  }
  if results.node_name is Some(node_name) {
    let last_dot = js_last_index_of(node_name, ".")
    if last_dot != -1 {
      let object_name = js_substring(node_name, last_dot + 1, -1)

      // Object names must be checked against an allowlist. Otherwise, there
      // is no way to parse 'foo.bar.baz': 'baz' must be a property, but
      // 'bar' could be the objectName, or part of a nodeName (which can
      // include '.' characters).
      if property_binding_supported_object_names.contains(object_name) {
        results.node_name = Some(js_substring(node_name, 0, last_dot))
        results.object_name = Some(object_name)
      }
    }
  }
  if results.property_name.length() == 0 {
    abort(
      "THREE.PropertyBinding: can not parse propertyName from trackName: " +
      track_name,
    )
  }
  results
}

///|
/// Searches `root`, its skeleton's bones and its subtree for a node by name or uuid.
pub fn PropertyBinding::find_node(
  root : @core.Object3D,
  node_name : String?,
) -> @core.Object3D? {
  guard node_name is Some(node_name) else { return Some(root) }
  if node_name == "" ||
    node_name == "." ||
    node_name == root.name ||
    node_name == root.uuid {
    return Some(root)
  }

  // search into skeleton bones.
  if root.kind
    is Mesh({ kind: SkinnedMesh({ skeleton: Some(skeleton), .. }), .. }) {
    if skeleton.get_bone_by_name(node_name) is Some(bone) {
      return Some(bone)
    }
  }

  // search into node subtree.
  fn search_node_subtree(children : Array[@core.Object3D]) -> @core.Object3D? {
    for i = 0; i < children.length(); i = i + 1 {
      let child_node = children[i]
      if child_node.name == node_name || child_node.uuid == node_name {
        return Some(child_node)
      }
      if search_node_subtree(child_node.children) is Some(result) {
        return Some(result)
      }
    }
    None
  }

  search_node_subtree(root.children)
}

// --- Binding -----------------------------------------------------------------------

///|
pub fn PropertyBinding::get_value(
  self : PropertyBinding,
  target_array : Array[Double],
  offset : Int32,
) -> Unit {
  match self.state {
    Unbound => {
      self.bind()
      self.get_value(target_array, offset)
    }
    Unavailable => ()
    Bound(getter, _) => getter(target_array, offset)
  }
}

///|
pub fn PropertyBinding::set_value(
  self : PropertyBinding,
  source_array : Array[Double],
  offset : Int32,
) -> Unit {
  match self.state {
    Unbound => {
      self.bind()
      self.set_value(source_array, offset)
    }
    Unavailable => ()
    Bound(_, setter) => setter(source_array, offset)
  }
}

///|
fn property_binding_unknown(message : String) -> Unit {
  abort("THREE." + message)
}

///|
fn property_binding_unsupported(path : String, name : String) -> Unit {
  abort(
    "THREE.PropertyBinding: Can not bind to " +
    name +
    " for track: " +
    path +
    "; the MoonBit binding table does not support this property.",
  )
}

///|
/// The accessor for `resolvedProperty[ propertyIndex ]`.
fn element_scalar(
  path : String,
  resolved : Lookup,
  key : PropertyKey,
) -> Scalar {
  match resolved {
    Scalar(_) =>
      // a primitive has no elements; strict mode throws on the write
      {
        get: () => @double.not_a_number,
        set: _ => {
          abort(
            "TypeError: Cannot create property '" +
            key.to_key() +
            "' on a primitive",
          )
        },
      }
    Value(Numbers(array)) =>
      match key {
        Index(i) if i >= 0 && i < array.length() =>
          { get: () => array[i], set: v => array[i] = v, }
        Name(name) if array_index_of_key(name) is Some(i) && i < array.length() =>
          { get: () => array[i], set: v => array[i] = v, }
        _ => {
          let holder = @core.JsValue::of(array)
          let name = key.to_key()
          {
            get: () => expando_get(holder, name),
            set: v => expando_set(holder, name, v),
          }
        }
      }
    Value(Null) =>
      abort(
        "TypeError: Cannot read properties of null (reading '" +
        key.to_key() +
        "')",
      )
    Value(target) =>
      match target.lookup(key.to_key()) {
        Scalar(scalar) | Absent(scalar) => scalar
        Undefined => {
          let holder = target.identity()
          let name = key.to_key()
          {
            get: () => expando_get(holder, name),
            set: v => expando_set(holder, name, v),
          }
        }
        Value(_) => {
          property_binding_unsupported(path, key.to_key())
          panic()
        }
        Unknown | Unsupported => {
          property_binding_unsupported(path, key.to_key())
          panic()
        }
      }
    Unknown | Unsupported | Undefined | Absent(_) => panic()
  }
}

///|
/// Creates the getter / setter pair for the property of this binding.
pub fn PropertyBinding::bind(self : PropertyBinding) -> Unit {
  let parsed_path = self.parsed_path
  let object_name = parsed_path.object_name
  let property_name = parsed_path.property_name
  let property_index : PropertyKey? = parsed_path.property_index.map(name => {
    Name(name)
  })
  if self.node is None {
    self.node = PropertyBinding::find_node(
      self.root_node,
      parsed_path.node_name,
    )
  }

  // set fail state so we can just 'return' on error
  self.state = Unavailable

  // ensure there is a value node
  guard self.node is Some(node) else {
    @core.warn(
      "PropertyBinding: No target node found for track: " + self.path + ".",
    )
    return
  }
  let mut target_object : Target = Object3D(node)
  if object_name is Some(object_name) && object_name != "" {
    let mut object_index : PropertyKey? = parsed_path.object_index.map(x => {
      Name(x)
    })

    // special cases were we need to reach deeper into the hierarchy to get the face materials....
    match object_name {
      "materials" => {
        if node.get_material() is None {
          @core.error(
            "PropertyBinding: Can not bind to material as node does not have a material.",
          )
          return
        }
        // neither a material nor an array of them has `materials`
        @core.error(
          "PropertyBinding: Can not bind to material.materials as node.material does not have a materials array.",
        )
        return
      }
      "bones" => {
        guard node.kind
          is Mesh({ kind: SkinnedMesh({ skeleton: Some(skeleton), .. }), .. }) else {
          @core.error(
            "PropertyBinding: Can not bind to bones as node does not have a skeleton.",
          )
          return
        }
        let bones = skeleton.bones
        target_object = Objects(bones)

        // support resolving morphTarget names into indices.
        for i = 0; i < bones.length(); i = i + 1 {
          if parsed_path.object_index == Some(bones[i].name) {
            object_index = Some(Index(i))
            break
          }
        }
      }
      "map" =>
        match node.kind {
          Light({ kind: SpotLight(spot), .. }) =>
            target_object = match spot.map {
              Some(map) => Texture(map)
              None => Null
            }
          _ => {
            guard node.get_material() is Some(slot) else {
              @core.error(
                "PropertyBinding: Can not bind to material as node does not have a material.",
              )
              return
            }
            guard slot is Single({ map: Some(map), .. }) else {
              @core.error(
                "PropertyBinding: Can not bind to material.map as node.material does not have a map.",
              )
              return
            }
            target_object = Texture(map)
          }
        }
      _ =>
        match target_object.lookup(object_name).defined() {
          Value(target) => target_object = target
          Scalar(_) => target_object = Primitive
          Undefined | Absent(_) => {
            @core.error(
              "PropertyBinding: Can not bind to objectName of node undefined.",
            )
            return
          }
          Unknown => {
            property_binding_unknown(
              "PropertyBinding: Can not bind to objectName of node undefined.",
            )
            return
          }
          Unsupported => {
            property_binding_unsupported(self.path, object_name)
            return
          }
        }
    }
    if object_index is Some(object_index) {
      match target_object.lookup(object_index.to_key()).defined() {
        Value(target) => target_object = target
        Scalar(_) => target_object = Primitive
        Undefined | Absent(_) => {
          @core.error(
            "PropertyBinding: Trying to bind to objectIndex of objectName, but is undefined.",
          )
          return
        }
        Unknown => {
          property_binding_unknown(
            "PropertyBinding: Trying to bind to objectIndex of objectName, but is undefined.",
          )
          return
        }
        Unsupported => {
          property_binding_unsupported(self.path, object_index.to_key())
          return
        }
      }
    }
  }

  // resolve property
  let node_property = target_object.lookup(property_name).defined()
  let not_found = "PropertyBinding: Trying to update property for track: " +
    parsed_path.node_name.unwrap_or("undefined") +
    "." +
    property_name +
    " but it wasn't found."
  match node_property {
    Undefined | Absent(_) => {
      @core.error(not_found)
      return
    }
    Unknown => {
      property_binding_unknown(not_found)
      return
    }
    Unsupported => {
      property_binding_unsupported(self.path, property_name)
      return
    }
    _ => ()
  }

  // determine versioning scheme
  self.target_object = Some(target_object)
  let versioning : () -> Unit = match target_object {
    Material(material) => () => material.set_needs_update(true)
    Object3D(object) => () => object.matrix_world_needs_update = true
    _ => () => ()
  }

  // determine how the property gets bound
  let (getter, setter) : (
    (Array[Double], Int32) -> Unit,
    (Array[Double], Int32) -> Unit,
  ) = if property_index is Some(index) {
    // access a sub element of the property array (only primitives are supported right now)
    let mut index = index
    if property_name == "morphTargetInfluences" {
      // support resolving morphTarget names into indices.
      guard target_object is Object3D(object) &&
        object.get_geometry() is Some(_) else {
        @core.error(
          "PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.",
        )
        return
      }
      // `geometry.morphAttributes` always exists
      guard object.morph_targets().0 is Some(dictionary) else {
        abort(
          "TypeError: Cannot read properties of undefined (reading '" +
          index.to_key() +
          "')",
        )
      }
      if dictionary.get(index.to_key()) is Some(i) {
        index = Index(i)
      }
    }
    self.property_index = Some(index)
    let element = element_scalar(self.path, node_property, index)
    (
      (buffer, offset) => buffer_set(buffer, offset, (element.get)()),
      (buffer, offset) => {
        (element.set)(buffer_get(buffer, offset))
        versioning()
      },
    )
  } else {
    match node_property {
      Value(Euler(_)) => {
        // upstream's `Euler.fromArray` ignores the offset and stores a number in `order`
        property_binding_unsupported(self.path, property_name)
        return
      }
      Value(Numbers(dest)) =>
        (
          (buffer, offset) => {
            let n = dest.length()
            for i = 0; i != n; i = i + 1 {
              buffer_set(buffer, offset + i, dest[i])
            }
          },
          (buffer, offset) => {
            let n = dest.length()
            for i = 0; i != n; i = i + 1 {
              dest[i] = buffer_get(buffer, offset + i)
            }
            versioning()
          },
        )
      Value(target) =>
        match target.to_from_array() {
          // must use copy for Object3D.Euler/Quaternion
          Some((to_array, from_array)) =>
            (
              to_array,
              (buffer, offset) => {
                from_array(buffer, offset)
                versioning()
              },
            )
          None => {
            // binding would replace an object (or an array of objects) with a number
            property_binding_unsupported(self.path, property_name)
            return
          }
        }
      Scalar(scalar) => {
        self.property_name = Some(property_name)
        (
          (buffer, offset) => buffer_set(buffer, offset, (scalar.get)()),
          (buffer, offset) => {
            (scalar.set)(buffer_get(buffer, offset))
            versioning()
          },
        )
      }
      Unknown | Unsupported | Undefined | Absent(_) => panic()
    }
  }

  // select getter / setter
  self.state = Bound(getter, setter)
}

///|
pub fn PropertyBinding::unbind(self : PropertyBinding) -> Unit {
  self.node = None

  // back to the unbound getValue / setValue
  self.state = Unbound
}

///|
/// Whether `bind` found the property (false before binding and when it failed).
pub fn PropertyBinding::is_bound(self : PropertyBinding) -> Bool {
  self.state is Bound(_, _)
}

// --- Composite ---------------------------------------------------------------------

///|
/// `PropertyBinding.Composite`: the bindings of one path in an `AnimationObjectGroup`.
pub struct Composite {
  _target_group : AnimationObjectGroup
  _bindings : Array[PropertyBinding?]
}

///|
pub fn Composite::new(
  target_group : AnimationObjectGroup,
  path : String,
  parsed_path? : ParsedPath,
) -> Composite {
  let parsed_path = match parsed_path {
    Some(parsed_path) => parsed_path
    None => PropertyBinding::parse_track_name(path)
  }
  {
    _target_group: target_group,
    _bindings: target_group.subscribe_(path, parsed_path),
  }
}

///|
fn Composite::binding_at(self : Composite, i : Int32) -> PropertyBinding {
  match self._bindings[i] {
    Some(binding) => binding
    None => abort("TypeError: Cannot read properties of undefined")
  }
}

///|
pub fn Composite::get_value(
  self : Composite,
  array : Array[Double],
  offset : Int32,
) -> Unit {
  self.bind() // bind all binding
  let first_valid_index = self._target_group.n_cached_objects_

  // and only call .getValue on the first
  if self._bindings.get(first_valid_index) is Some(Some(binding)) {
    binding.get_value(array, offset)
  }
}

///|
pub fn Composite::set_value(
  self : Composite,
  array : Array[Double],
  offset : Int32,
) -> Unit {
  let bindings = self._bindings
  let n = bindings.length()
  for i = self._target_group.n_cached_objects_; i != n; i = i + 1 {
    self.binding_at(i).set_value(array, offset)
  }
}

///|
pub fn Composite::bind(self : Composite) -> Unit {
  let bindings = self._bindings
  let n = bindings.length()
  for i = self._target_group.n_cached_objects_; i != n; i = i + 1 {
    self.binding_at(i).bind()
  }
}

///|
pub fn Composite::unbind(self : Composite) -> Unit {
  let bindings = self._bindings
  let n = bindings.length()
  for i = self._target_group.n_cached_objects_; i != n; i = i + 1 {
    self.binding_at(i).unbind()
  }
}

///|
/// What `PropertyBinding.create` returns.
pub(all) enum AnyPropertyBinding {
  Single(PropertyBinding)
  Composite(Composite)
}

///|
pub fn AnyPropertyBinding::get_value(
  self : AnyPropertyBinding,
  array : Array[Double],
  offset : Int32,
) -> Unit {
  match self {
    Single(binding) => binding.get_value(array, offset)
    Composite(composite) => composite.get_value(array, offset)
  }
}

///|
pub fn AnyPropertyBinding::set_value(
  self : AnyPropertyBinding,
  array : Array[Double],
  offset : Int32,
) -> Unit {
  match self {
    Single(binding) => binding.set_value(array, offset)
    Composite(composite) => composite.set_value(array, offset)
  }
}

///|
pub fn AnyPropertyBinding::bind(self : AnyPropertyBinding) -> Unit {
  match self {
    Single(binding) => binding.bind()
    Composite(composite) => composite.bind()
  }
}

///|
pub fn AnyPropertyBinding::unbind(self : AnyPropertyBinding) -> Unit {
  match self {
    Single(binding) => binding.unbind()
    Composite(composite) => composite.unbind()
  }
}

///|
/// `binding.parsedPath`; a `Composite` has none.
pub fn AnyPropertyBinding::parsed_path(
  self : AnyPropertyBinding,
) -> ParsedPath? {
  match self {
    Single(binding) => Some(binding.parsed_path)
    Composite(_) => None
  }
}

///|
/// The class of `binding.targetObject` after a successful `bind`, such as
/// `"Object3D"`, `"Material"` or `"Vector3"`.
pub fn PropertyBinding::target_object_kind(self : PropertyBinding) -> String? {
  match self.target_object {
    None => None
    Some(target) =>
      Some(
        match target {
          Object3D(_) => "Object3D"
          Material(_) => "Material"
          Texture(_) => "Texture"
          Fog(_) => "Fog"
          Shadow(_) => "LightShadow"
          Objects(_) => "Array<Object3D>"
          Materials(_) => "Array<Material>"
          Numbers(_) => "Array<number>"
          Vector2(_) => "Vector2"
          Vector3(_) => "Vector3"
          Vector4(_) => "Vector4"
          Quaternion(_) => "Quaternion"
          Euler(_) => "Euler"
          Color(_) => "Color"
          Matrix3(_) => "Matrix3"
          Matrix4(_) => "Matrix4"
          SphericalHarmonics3(_) => "SphericalHarmonics3"
          Primitive => "primitive"
          Null => "null"
        },
      )
  }
}
