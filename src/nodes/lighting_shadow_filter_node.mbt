// nodes/lighting/ShadowFilterNode.js: the shadow map filters (basic, PCF, VSM). They
// are `Fn`s called with `{ depthTexture, shadowCoord, shadow, depthLayer }`, whose
// texture and shadow members TSL passes through unconverted.

///|
/// `inputs.name` as the raw JS value (textures and light shadows are not nodes).
pub fn shadow_filter_input(inputs : FnInputs, name : String) -> TslValue {
  match inputs.params {
    [Object(object), ..] => object.get(name).unwrap_or(Undefined)
    _ => Undefined
  }
}

///|
/// The texture member of a filter's inputs.
fn shadow_filter_texture(inputs : FnInputs, name : String) -> @core.Texture {
  match shadow_filter_input(inputs, name) {
    Texture(t) => t
    _ => abort("TypeError: \{name} is not a texture")
  }
}

///|
/// The light shadow member of a filter's inputs.
fn shadow_filter_shadow(inputs : FnInputs) -> @core.LightShadow {
  match shadow_filter_input(inputs, "shadow") {
    Js(v) => v.cast()
    _ => abort("TypeError: shadow is not a LightShadow")
  }
}

///|
/// A light shadow as a value inside a TSL call object.
pub fn shadow_filter_shadow_value(shadow : @core.LightShadow) -> TslValue {
  Js(@core.JsValue::of(shadow))
}

///|
/// `{ mapSize, radius }` of a light shadow.
priv struct ShadowFilterUniforms {
  map_size : Node
  radius : Node
}

///|
let shadow_filter_uniforms : @webgl.WeakMap[
  @core.LightShadow,
  ShadowFilterUniforms,
] = @webgl.WeakMap::new()

///|
/// `getShadowUniforms( shadow )`.
fn shadow_filter_get_shadow_uniforms(
  shadow : @core.LightShadow,
) -> ShadowFilterUniforms {
  match shadow_filter_uniforms.get(shadow) {
    Some(u) => u
    None => {
      let u = ShadowFilterUniforms::{
        map_size: ReferenceNode::set_group(
          shadow_reference("mapSize", "vec2", shadow),
          render_group,
        ),
        radius: ReferenceNode::set_group(
          shadow_reference("radius", "float", shadow),
          render_group,
        ),
      }
      shadow_filter_uniforms.set(shadow, u)
      u
    }
  }
}

///|
/// `reference( name, type, shadow )` of a light shadow property.
pub fn shadow_reference(
  name : String,
  type_ : String,
  shadow : @core.LightShadow,
) -> Node {
  reference(name, type_, object=Shadow(shadow))
}

///|
/// `BasicShadowFilter( { depthTexture, shadowCoord, depthLayer } )`.
pub let basic_shadow_filter : Node = module_nodes(
  "nodes/lighting/ShadowFilterNode.js:BasicShadowFilter",
  fn() {
    fn_(fn(inputs, _) {
      let depth_texture = shadow_filter_texture(inputs, "depthTexture")
      let shadow_coord = inputs.named("shadowCoord").unwrap()
      let depth_layer = inputs.named("depthLayer")
      let mut basic = texture(depth_texture, uv_node=shadow_coord.xy()).set_name(
        "t_basic",
      )
      if depth_texture.is_array_texture {
        basic = basic.depth(physical_optional(depth_layer))
      }
      Some(basic.compare(shadow_coord.z()))
    })
  },
)

///|
/// `PCFShadowFilter( { depthTexture, shadowCoord, shadow, depthLayer } )`: five Vogel
/// disk samples rotated by interleaved gradient noise.
pub let pcf_shadow_filter : Node = module_nodes(
  "nodes/lighting/ShadowFilterNode.js:PCFShadowFilter",
  fn() {
    fn_(fn(inputs, _) {
      let depth_texture = shadow_filter_texture(inputs, "depthTexture")
      let shadow_coord = inputs.named("shadowCoord").unwrap()
      let shadow = shadow_filter_shadow(inputs)
      let depth_layer = inputs.named("depthLayer")
      let depth_compare = fn(uv : Node, compare : Node) {
        let mut depth = texture(depth_texture, uv_node=uv)
        if depth_texture.is_array_texture {
          depth = depth.depth(physical_optional(depth_layer))
        }
        depth.compare(compare)
      }
      let { map_size, radius, } = shadow_filter_get_shadow_uniforms(shadow)
      let texel_size = vec2(1).div(map_size)
      let radius_scaled = radius.mul(texel_size)
      let phi = interleaved_gradient_noise
        .call([screen_coordinate.xy()])
        .mul(6.28318530718)
      let sample = fn(i : Int32) {
        depth_compare(
          shadow_coord
          .xy()
          .add(vogel_disk_sample.call([i, 5, phi]).mul(radius_scaled)),
          shadow_coord.z(),
        )
      }
      Some(
        add_of([sample(0), sample(1), sample(2), sample(3), sample(4)]).mul(
          1.0 / 5.0,
        ),
      )
    })
  },
)

///|
/// `VSMShadowFilter( { depthTexture, shadowCoord, depthLayer } )`: variance shadow
/// maps with Chebyshev's upper bound.
pub let vsm_shadow_filter : Node = module_nodes(
  "nodes/lighting/ShadowFilterNode.js:VSMShadowFilter",
  fn() {
    fn_(fn(inputs, builder) {
      let depth_texture = shadow_filter_texture(inputs, "depthTexture")
      let shadow_coord = inputs.named("shadowCoord").unwrap()
      let depth_layer = inputs.named("depthLayer")
      let mut distribution = texture(depth_texture).sample(shadow_coord.xy())
      if depth_texture.is_array_texture {
        distribution = distribution.depth(physical_optional(depth_layer))
      }
      distribution = distribution.rg()
      let mean = distribution.x()
      let variance = max(0.0000001, distribution.y().mul(distribution.y()))
      let hard_shadow = if builder.renderer.reversed_depth_buffer {
        step(mean, shadow_coord.z())
      } else {
        step(shadow_coord.z(), mean)
      }
      let output = float(1).to_var()
      if_(hard_shadow.not_equal(1.0), fn() {
        let d = shadow_coord.z().sub(mean)
        let mut p_max = variance.div(variance.add(d.mul(d)))
        p_max = clamp(sub(p_max, 0.3).div(0.65))
        output.assign(max(hard_shadow, p_max))
      })
      |> ignore
      Some(output)
    })
  },
)
