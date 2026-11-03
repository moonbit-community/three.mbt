// examples/jsm/tsl/display/radialBlur.js

///|
priv struct RadialBlurModule {
  radial_blur : @nodes.Node
}

///|
let display_radial_blur_module : AddonModule[RadialBlurModule] = AddonModule::new(fn() {
    let radial_blur = @nodes.fn_(fn(inputs, _) {
      let texture_node = addon_arg(inputs, 0)
      let options = inputs.value(1)
      let texture_node = @nodes.convert_to_texture(texture_node)
      let center = a4_option_node_or(options, "center", fn() {
        @nodes.vec2_of([0.5, 0.5])
      })
      let weight = a4_option_node_or(options, "weight", fn() {
        @nodes.float(0.9)
      })
      let decay = a4_option_node_or(options, "decay", fn() {
        @nodes.float(0.95)
      })
      let count = a4_option_node_or(options, "count", fn() { @nodes.int(32) })
      let exposure = a4_option_node_or(options, "exposure", fn() {
        @nodes.float(5)
      })
      let premultiplied_alpha = addon_truthy(
        addon_option(options, "premultipliedAlpha"),
      )
      let tap = fn(uv : @nodes.Node) {
        let sample = texture_node.sample(uv)
        if premultiplied_alpha {
          @nodes.premultiply_alpha.call([sample])
        } else {
          sample
        }
      }
      let sample_uv = @nodes.vec2(
        match a4_texture_uv_node(texture_node) {
          Some(n) => n
          None => @nodes.uv()
        },
      )
      let base = tap(sample_uv).to_const()
      let blur = @nodes.vec4_of([]).to_var()
      let offset = center.sub(sample_uv).div(count).to_const()
      let w = @nodes.float(weight).to_var()
      let noise = @nodes.interleaved_gradient_noise.call([
        @nodes.screen_coordinate,
      ])
      sample_uv.add_assign(offset.mul(noise)) // mitigate banding
      @nodes.loop_(
        [
          @nodes.loop_range(
            start=@nodes.int(0),
            end=@nodes.int(count),
            type_="int",
            condition="<",
          ),
        ],
        fn(_) {
          sample_uv.add_assign(offset)
          let sample = tap(sample_uv)
          blur.add_assign(sample.mul(w))
          w.mul_assign(decay)
        },
      )
      blur.div_assign(count)
      blur.mul_assign(exposure)
      let color = @nodes.mix(blur, base.mul(2), 0.5)
      Some(
        if premultiplied_alpha {
          @nodes.unpremultiply_alpha.call([color])
        } else {
          color
        },
      )
    })
    { radial_blur, }
  },
)

///|
/// Evaluates radialBlur.js, as `import` does.
pub fn load_display_radial_blur() -> Unit {
  display_radial_blur_module.get() |> ignore
}

///|
/// `radialBlur( textureNode, options = {} )`; options `center`, `weight`, `decay`,
/// `count`, `exposure`, `premultipliedAlpha` (an `addon_options` object).
pub fn radial_blur() -> @nodes.Node {
  display_radial_blur_module.get().radial_blur
}
