// Types for upstream src/lights and src/lights/webgpu.

///|
/// The subclass of a `Light`.
pub(all) enum LightKind {
  BaseLight
  AmbientLight
  DirectionalLight(DirectionalLight)
  HemisphereLight(HemisphereLight)
  LightProbe(LightProbe)
  PointLight(PointLight)
  RectAreaLight(RectAreaLight)
  SpotLight(SpotLight)
}

///|
/// `shadow` is here, not in the subclasses, so renderers read it from any light.
pub(all) struct Light {
  mut color : @math.Color
  mut intensity : Double
  mut shadow : LightShadow?
  /// Upstream's dynamic `light.colorNode`, a `nodes` value.
  mut color_node : JsValue?
  mut kind : LightKind
}

///|
pub(all) struct DirectionalLight {
  mut target : Object3D
}

///|
pub(all) struct HemisphereLight {
  mut ground_color : @math.Color
}

///|
pub(all) struct LightProbe {
  mut sh : @math.SphericalHarmonics3
}

///|
pub(all) struct PointLight {
  mut distance : Double
  mut decay : Double
}

///|
pub(all) struct RectAreaLight {
  mut width : Double
  mut height : Double
}

///|
/// The subclass of a `SpotLight`, from src/lights/webgpu.
pub(all) enum SpotLightVariant {
  PlainSpotLight
  IESSpotLight
  ProjectorLight
}

///|
pub(all) struct SpotLight {
  mut target : Object3D
  mut distance : Double
  mut angle : Double
  mut penumbra : Double
  mut decay : Double
  mut map : Texture?
  /// `IESSpotLight.iesMap`.
  mut ies_map : Texture?
  /// `ProjectorLight.aspect`.
  mut aspect : Double?
  mut variant : SpotLightVariant
}

///|
/// The subclass of a `LightShadow`.
pub(all) enum LightShadowKind {
  BaseLightShadow
  DirectionalLightShadow
  PointLightShadow
  SpotLightShadow(SpotLightShadow)
}

///|
pub(all) struct SpotLightShadow {
  mut focus : Double
  mut aspect : Double
}

///|
pub(all) struct LightShadow {
  mut camera : Object3D
  mut intensity : Double
  mut bias : Double
  /// `nodes` values, opaque to core.
  mut bias_node : JsValue?
  mut shadow_node : JsValue?
  mut filter_node : JsValue?
  mut normal_bias : Double
  mut radius : Double
  mut blur_samples : Int32
  mut map_size : @math.Vector2
  mut map_type : Int32
  mut map : RenderTarget?
  mut map_pass : RenderTarget?
  mut matrix : @math.Matrix4
  mut auto_update : Bool
  mut needs_update : Bool
  mut _frustum : @math.Frustum
  mut _frame_extents : @math.Vector2
  mut _viewport_count : Int32
  mut _viewports : Array[@math.Vector4]
  mut kind : LightShadowKind
}
