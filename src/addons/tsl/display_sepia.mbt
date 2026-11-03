// examples/jsm/tsl/display/Sepia.js

///|
priv struct SepiaModule {
  sepia : @nodes.Node
}

///|
let display_sepia_module : AddonModule[SepiaModule] = AddonModule::new(fn() {
  let sepia = @nodes.fn_(fn(inputs, _) {
    let color = addon_arg(inputs, 0)
    let c = @nodes.vec3(color)
    // https://github.com/evanw/glfx.js/blob/master/src/filters/adjust/sepia.js
    Some(
      @nodes.vec4_of([
        @nodes.dot(c, @nodes.vec3_of([0.393, 0.769, 0.189])),
        @nodes.dot(c, @nodes.vec3_of([0.349, 0.686, 0.168])),
        @nodes.dot(c, @nodes.vec3_of([0.272, 0.534, 0.131])),
        color.a(),
      ]),
    )
  })
  { sepia, }
})

///|
/// Evaluates Sepia.js, as `import` does.
pub fn load_display_sepia() -> Unit {
  display_sepia_module.get() |> ignore
}

///|
/// `sepia( color )`: the sepia-toned color (the module-level `Fn`; `.call([color])`).
pub fn sepia() -> @nodes.Node {
  display_sepia_module.get().sepia
}
