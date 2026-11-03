// examples/jsm/tsl/display/lensDirt.js

///|
priv struct LensDirtModule {
  lens_dirt : @nodes.Node
}

///|
let display_lens_dirt_module : AddonModule[LensDirtModule] = AddonModule::new(fn() {
  let lens_dirt = @nodes.fn_(fn(inputs, _) {
    let texture_node = addon_arg(inputs, 0)
    let dirt_texture_node = addon_arg(inputs, 1)
    let intensity = inputs.get(2).or_else(fn() { @nodes.float(1) })
    let texture_node = @nodes.convert_to_texture(texture_node)
    let target_uv = match a4_texture_uv_node(texture_node) {
      Some(n) => n
      None => @nodes.uv()
    }
    let dirt_size = @nodes.vec2(dirt_texture_node.size(level_node=0)).to_const()
    let aspect = @nodes.screen_size
      .x()
      .div(@nodes.screen_size.y())
      .div(dirt_size.x().div(dirt_size.y()))
      .to_const()
    let dirt_uv = target_uv
      .sub(0.5)
      .mul(
        @nodes.vec2_of([
          @nodes.min(aspect, 1),
          @nodes.min(aspect.reciprocal(), 1),
        ]),
      )
      .add(0.5)
      .to_const()
    let dirt = dirt_texture_node
      .sample(dirt_uv)
      .rgb()
      .mul(texture_node.sample(target_uv).rgb())
      .mul(intensity)
    Some(@nodes.vec4_of([dirt, 1]))
  })
  { lens_dirt, }
})

///|
/// Evaluates lensDirt.js, as `import` does.
pub fn load_display_lens_dirt() -> Unit {
  display_lens_dirt_module.get() |> ignore
}

///|
/// `lensDirt( textureNode, dirtTextureNode, intensity = float( 1 ) )`.
pub fn lens_dirt() -> @nodes.Node {
  display_lens_dirt_module.get().lens_dirt
}
