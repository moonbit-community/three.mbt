// examples/jsm/tsl/display/hashBlur.js

///|
priv struct HashBlurModule {
  hash_blur : @nodes.Node
}

///|
let display_hash_blur_module : AddonModule[HashBlurModule] = AddonModule::new(fn() {
  let hash_blur = @nodes.fn_(fn(inputs, _) {
    let texture_node = @nodes.convert_to_texture(addon_arg(inputs, 0))
    let bluramount = inputs.get(1).unwrap_or_else(fn() { @nodes.float(0.1) })
    let options = match inputs.value(2) {
      Undefined => @nodes.TslValue::Object(Map::from_array([]))
      v => v
    }
    let repeats = match addon_option(options, "repeats") {
      Undefined | Null => @nodes.float(45)
      v => @nodes.node_object(v)
    }
    let premultiplied_alpha = addon_truthy(
      addon_option(options, "premultipliedAlpha"),
    )
    let tap = fn(uv : @nodes.Node) -> @nodes.Node {
      let sample = texture_node.sample(uv)
      if premultiplied_alpha {
        @nodes.premultiply_alpha.call([sample])
      } else {
        sample
      }
    }
    let target_uv = match addon_texture_uv_node(texture_node) {
      Some(u) => u
      None => @nodes.uv()
    }
    let blurred_image = @nodes.vec4(0.0)
    @nodes.loop_([@nodes.loop_range(start=0.0, end=repeats, type_="float")], fn(
      inputs,
    ) {
      let i = inputs.named("i").unwrap()
      let angle = i.div(repeats).mul(@nodes.two_pi).to_const()
      let q = @nodes.vec2_of([@nodes.cos(angle), @nodes.sin(angle)]).mul(
        @nodes.rand
        .call([@nodes.vec2_of([i, target_uv.x().add(target_uv.y())])])
        .add(bluramount),
      )
      let uv2 = @nodes.vec2(target_uv.add(q.mul(bluramount)))
      blurred_image.add_assign(tap(uv2))
    })
    blurred_image.div_assign(repeats)
    Some(
      if premultiplied_alpha {
        @nodes.unpremultiply_alpha.call([blurred_image])
      } else {
        blurred_image
      },
    )
  })
  { hash_blur, }
})

///|
/// Evaluates hashBlur.js, as `import` does.
pub fn load_display_hash_blur() -> Unit {
  display_hash_blur_module.get() |> ignore
}

///|
/// `hashBlur( textureNode, bluramount = float( 0.1 ), { repeats = float( 45 ),
/// premultipliedAlpha = false } )` (the module-level `Fn`; `.call([texture, amount?,
/// addon_options([...])?])`).
pub fn hash_blur() -> @nodes.Node {
  display_hash_blur_module.get().hash_blur
}
