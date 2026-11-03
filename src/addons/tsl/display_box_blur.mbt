// examples/jsm/tsl/display/boxBlur.js

///|
priv struct BoxBlurModule {
  box_blur : @nodes.Node
}

///|
let display_box_blur_module : AddonModule[BoxBlurModule] = AddonModule::new(fn() {
  let box_blur = @nodes.fn_(fn(inputs, _) {
    let texture_node = @nodes.convert_to_texture(addon_arg(inputs, 0))
    let options = match inputs.value(1) {
      Undefined => @nodes.TslValue::Object(Map::from_array([]))
      v => v
    }
    let size = match addon_option(options, "size") {
      Undefined | Null => @nodes.int(1)
      v => @nodes.node_object(v)
    }
    let separation = match addon_option(options, "separation") {
      Undefined | Null => @nodes.int(1)
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
    let result = @nodes.vec4(0)
    let sep = @nodes.max(separation, 1)
    let count = @nodes.int(0)
    let pixel_step = @nodes.vec2(1).div(@nodes.texture_size(texture_node))
    @nodes.loop_(
      [
        @nodes.loop_range(
          start=size.negate(),
          end=size,
          name="i",
          condition="<=",
        ),
      ],
      fn(inputs) {
        let i = inputs.named("i").unwrap()
        @nodes.loop_(
          [
            @nodes.loop_range(
              start=size.negate(),
              end=size,
              name="j",
              condition="<=",
            ),
          ],
          fn(inputs) {
            let j = inputs.named("j").unwrap()
            let uvs = target_uv.add(
              @nodes.vec2_of([i, j]).mul(pixel_step).mul(sep),
            )
            result.add_assign(tap(uvs))
            count.add_assign(1)
          },
        )
      },
    )
    result.div_assign(count)
    Some(
      if premultiplied_alpha {
        @nodes.unpremultiply_alpha.call([result])
      } else {
        result
      },
    )
  })
  { box_blur, }
})

///|
/// Evaluates boxBlur.js, as `import` does.
pub fn load_display_box_blur() -> Unit {
  display_box_blur_module.get() |> ignore
}

///|
/// `boxBlur( textureNode, { size = 1, separation = 1, premultipliedAlpha = false } )`:
/// a box blur of `(2 * size + 1)²` taps (the module-level `Fn`; call it with
/// `.call([texture, addon_options([...])])`).
pub fn box_blur() -> @nodes.Node {
  display_box_blur_module.get().box_blur
}
