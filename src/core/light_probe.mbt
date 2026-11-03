// Upstream src/lights/LightProbe.js. `LightProbe` is the payload struct, so
// `LightProbe::new` returns the `Object3D` that holds it. `toJSON` is in light.mbt.

///|
/// `new LightProbe( sh, intensity )`. Keeps `sh` by reference, as upstream.
pub fn LightProbe::new(
  sh~ : @math.SphericalHarmonics3 = @math.SphericalHarmonics3::new(),
  intensity~ : Double = 1.0,
) -> Object3D {
  Object3D::new(
    kind=Light(light_data_new(None, intensity, None, LightProbe({ sh, }))),
    type_="LightProbe",
  )
}

///|
fn LightProbe::copy_fields(self : LightProbe, source : Light) -> Unit {
  guard source.kind is LightProbe(probe) else {
    abort("LightProbe.copy: source has no sh")
  }
  ignore(self.sh.copy(probe.sh))
}
