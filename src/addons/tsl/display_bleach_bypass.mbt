// examples/jsm/tsl/display/BleachBypass.js

///|
priv struct BleachBypassModule {
  bleach : @nodes.Node
}

///|
let display_bleach_bypass_module : AddonModule[BleachBypassModule] = AddonModule::new(fn() {
    let bleach = @nodes.fn_(fn(inputs, _) {
      let color = addon_arg(inputs, 0)
      let opacity = a4_arg_or(inputs, 1, Number(1.0))
      let base = color
      let lum = @nodes.luminance(base.rgb())
      let blend = @nodes.vec3(lum)
      let l = @nodes.min(
        1.0,
        @nodes.max(0.0, @nodes.float(10.0).mul(lum.sub(0.45))),
      )
      let result1 = blend.mul(base.rgb()).mul(2.0)
      let result2 = @nodes.float(2.0)
        .mul(blend.one_minus())
        .mul(base.rgb().one_minus())
        .one_minus()
      let new_color = @nodes.mix(result1, result2, l)
      let a2 = base.a().mul(opacity)
      let mix_rgb = a2.mul(new_color.rgb())
      mix_rgb.add_assign(base.rgb().mul(a2.one_minus()))
      Some(@nodes.vec4_of([mix_rgb, base.a()]))
    })
    { bleach, }
  },
)

///|
/// Evaluates BleachBypass.js, as `import` does.
pub fn load_display_bleach_bypass() -> Unit {
  display_bleach_bypass_module.get() |> ignore
}

///|
/// `bleach( color, opacity = 1 )`: the bleach bypass effect (call with `.call([...])`).
pub fn bleach() -> @nodes.Node {
  display_bleach_bypass_module.get().bleach
}
