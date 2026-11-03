// examples/jsm/tsl/display/FXAANode.js

///|
/// Post processing node for applying FXAA (fast approximate anti-aliasing).
pub(all) struct FXAANode {
  mut texture_node : @nodes.Node
  _inv_size : @nodes.Node
}

///|
pub impl @nodes.NodeClass for FXAANode with fn class_name(_) {
  "FXAANode"
}

///|
pub impl @nodes.NodeClass for FXAANode with fn children(self, _, out) {
  @nodes.push_child(out, "textureNode", Some(self.texture_node))
}

///|
pub impl @nodes.NodeClass for FXAANode with fn update_before(self, _, _) {
  let map = @nodes.TextureNode::get_value(self.texture_node)
  a4_uniform_vector2(self._inv_size).set(
    1.0 / map.image().width(),
    1.0 / map.image().height(),
  )
  |> ignore
  None
}

///|
/// The luminance neighborhood of a pixel (`SampleLuminanceNeighborhood`'s object).
priv struct FXAALuminance {
  m : @nodes.Node
  n : @nodes.Node
  e : @nodes.Node
  s : @nodes.Node
  w : @nodes.Node
  ne : @nodes.Node
  nw : @nodes.Node
  se : @nodes.Node
  sw : @nodes.Node
  highest : @nodes.Node
  lowest : @nodes.Node
  contrast : @nodes.Node
}

///|
/// `DetermineEdge`'s object.
priv struct FXAAEdge {
  is_horizontal : @nodes.Node
  pixel_step : @nodes.Node
  opposite_luminance : @nodes.Node
  gradient : @nodes.Node
}

///|
pub impl @nodes.NodeClass for FXAANode with fn setup(self, _, _) {
  let texture_node = self.texture_node.bias(-100)
  let uv_node = match a4_texture_uv_node(texture_node) {
    Some(n) => n
    None => @nodes.uv()
  }
  let edge_step_count = @nodes.float(6)
  let edge_guess = @nodes.float(8.0)
  let edge_steps = @nodes.uniform_array(
    @nodes.TslValue::Array([
      Number(1.0),
      Number(1.5),
      Number(2.0),
      Number(2.0),
      Number(2.0),
      Number(4.0),
    ]),
  )
  let contrast_threshold = @nodes.float(0.0312)
  let relative_threshold = @nodes.float(0.063)
  let subpixel_blending = @nodes.float(1.0)
  let sample = @nodes.fn_(fn(inputs, _) {
    let uv = inputs.get(0).unwrap()
    Some(texture_node.sample(uv))
  })
  let sample_luminance = @nodes.fn_(fn(inputs, _) {
    let uv = inputs.get(0).unwrap()
    Some(@nodes.dot(sample.call([uv]).rgb(), @nodes.vec3_of([0.3, 0.59, 0.11])))
  })
  let sample_luminance_offset = @nodes.fn_(fn(inputs, _) {
    let tex_size = inputs.get(0).unwrap()
    let uv = inputs.get(1).unwrap()
    let u_offset = inputs.get(2).unwrap()
    let v_offset = inputs.get(3).unwrap()
    let shifted_uv = uv.add(tex_size.mul(@nodes.vec2_of([u_offset, v_offset])))
    Some(sample_luminance.call([shifted_uv]))
  })
  let should_skip_pixel = fn(l : FXAALuminance) {
    let threshold = @nodes.max(
      contrast_threshold,
      relative_threshold.mul(l.highest),
    )
    l.contrast.less_than(threshold)
  }
  let sample_luminance_neighborhood = fn(
    tex_size : @nodes.Node,
    uv : @nodes.Node,
  ) {
    let m = sample_luminance.call([uv])
    let n = sample_luminance_offset.call([tex_size, uv, 0.0, -1.0])
    let e = sample_luminance_offset.call([tex_size, uv, 1.0, 0.0])
    let s = sample_luminance_offset.call([tex_size, uv, 0.0, 1.0])
    let w = sample_luminance_offset.call([tex_size, uv, -1.0, 0.0])
    let ne = sample_luminance_offset.call([tex_size, uv, 1.0, -1.0])
    let nw = sample_luminance_offset.call([tex_size, uv, -1.0, -1.0])
    let se = sample_luminance_offset.call([tex_size, uv, 1.0, 1.0])
    let sw = sample_luminance_offset.call([tex_size, uv, -1.0, 1.0])
    let highest = @nodes.max_of([s, e, n, w, m])
    let lowest = @nodes.min_of([s, e, n, w, m])
    let contrast = highest.sub(lowest)
    { m, n, e, s, w, ne, nw, se, sw, highest, lowest, contrast, }
  }
  let determine_pixel_blend_factor = fn(l : FXAALuminance) {
    let mut f = @nodes.float(2.0).mul(l.s.add(l.e).add(l.n).add(l.w))
    f = f.add(l.se.add(l.sw).add(l.ne).add(l.nw))
    f = f.mul(1.0 / 12.0)
    f = @nodes.abs(f.sub(l.m))
    f = @nodes.clamp(f.div(@nodes.max(l.contrast, 0)), low=0.0, high=1.0)
    let blend_factor = @nodes.smoothstep(0.0, 1.0, f)
    blend_factor.mul(blend_factor).mul(subpixel_blending)
  }
  let determine_edge = fn(tex_size : @nodes.Node, l : FXAALuminance) {
    let horizontal = @nodes.abs(l.s.add(l.n).sub(l.m.mul(2.0)))
      .mul(2.0)
      .add(
        @nodes.abs(l.se.add(l.ne).sub(l.e.mul(2.0))).add(
          @nodes.abs(l.sw.add(l.nw).sub(l.w.mul(2.0))),
        ),
      )
    let vertical = @nodes.abs(l.e.add(l.w).sub(l.m.mul(2.0)))
      .mul(2.0)
      .add(
        @nodes.abs(l.se.add(l.sw).sub(l.s.mul(2.0))).add(
          @nodes.abs(l.ne.add(l.nw).sub(l.n.mul(2.0))),
        ),
      )
    let is_horizontal = horizontal.greater_than_equal(vertical)
    let p_luminance = @nodes.select(is_horizontal, l.s, else_node=l.e)
    let n_luminance = @nodes.select(is_horizontal, l.n, else_node=l.w)
    let p_gradient = @nodes.abs(p_luminance.sub(l.m))
    let n_gradient = @nodes.abs(n_luminance.sub(l.m))
    let pixel_step = @nodes.select(
      is_horizontal,
      tex_size.y(),
      else_node=tex_size.x(),
    ).to_var()
    let opposite_luminance = @nodes.float_of([]).to_var()
    let gradient = @nodes.float_of([]).to_var()
    @nodes.if_(p_gradient.less_than(n_gradient), fn() {
      pixel_step.assign(pixel_step.negate())
      opposite_luminance.assign(n_luminance)
      gradient.assign(n_gradient)
    }).else_(fn() {
      opposite_luminance.assign(p_luminance)
      gradient.assign(p_gradient)
    })
    { is_horizontal, pixel_step, opposite_luminance, gradient, }
  }
  let determine_edge_blend_factor = fn(
    tex_size : @nodes.Node,
    l : FXAALuminance,
    e : FXAAEdge,
    uv : @nodes.Node,
  ) {
    let uv_edge = uv.to_var()
    let edge_step = @nodes.vec2_of([]).to_var()
    @nodes.if_(e.is_horizontal, fn() {
      uv_edge.y().add_assign(e.pixel_step.mul(0.5))
      edge_step.assign(@nodes.vec2_of([tex_size.x(), 0.0]))
    }).else_(fn() {
      uv_edge.x().add_assign(e.pixel_step.mul(0.5))
      edge_step.assign(@nodes.vec2_of([0.0, tex_size.y()]))
    })
    let edge_luminance = l.m.add(e.opposite_luminance).mul(0.5)
    let gradient_threshold = e.gradient.mul(0.25)
    let puv = uv_edge.add(edge_step.mul(edge_steps.element(0))).to_var()
    let p_luminance_delta = sample_luminance
      .call([puv])
      .sub(edge_luminance)
      .to_var()
    let p_at_end = @nodes.abs(p_luminance_delta)
      .greater_than_equal(gradient_threshold)
      .to_var()
    @nodes.loop_([@nodes.loop_range(start=1, end=edge_step_count)], fn(inputs) {
      let i = inputs.named("i").unwrap()
      @nodes.if_(p_at_end, fn() { @nodes.break_() }) |> ignore
      puv.add_assign(edge_step.mul(edge_steps.element(i)))
      p_luminance_delta.assign(sample_luminance.call([puv]).sub(edge_luminance))
      p_at_end.assign(
        @nodes.abs(p_luminance_delta).greater_than_equal(gradient_threshold),
      )
    })
    @nodes.if_(p_at_end.not_(), fn() {
      puv.add_assign(edge_step.mul(edge_guess))
    })
    |> ignore
    let nuv = uv_edge.sub(edge_step.mul(edge_steps.element(0))).to_var()
    let n_luminance_delta = sample_luminance
      .call([nuv])
      .sub(edge_luminance)
      .to_var()
    let n_at_end = @nodes.abs(n_luminance_delta)
      .greater_than_equal(gradient_threshold)
      .to_var()
    @nodes.loop_([@nodes.loop_range(start=1, end=edge_step_count)], fn(inputs) {
      let i = inputs.named("i").unwrap()
      @nodes.if_(n_at_end, fn() { @nodes.break_() }) |> ignore
      nuv.sub_assign(edge_step.mul(edge_steps.element(i)))
      n_luminance_delta.assign(sample_luminance.call([nuv]).sub(edge_luminance))
      n_at_end.assign(
        @nodes.abs(n_luminance_delta).greater_than_equal(gradient_threshold),
      )
    })
    @nodes.if_(n_at_end.not_(), fn() {
      nuv.sub_assign(edge_step.mul(edge_guess))
    })
    |> ignore
    let p_distance = @nodes.float_of([]).to_var()
    let n_distance = @nodes.float_of([]).to_var()
    @nodes.if_(e.is_horizontal, fn() {
      p_distance.assign(puv.x().sub(uv.x()))
      n_distance.assign(uv.x().sub(nuv.x()))
    }).else_(fn() {
      p_distance.assign(puv.y().sub(uv.y()))
      n_distance.assign(uv.y().sub(nuv.y()))
    })
    let shortest_distance = @nodes.float_of([]).to_var()
    let delta_sign = @nodes.bool_of([]).to_var()
    @nodes.if_(p_distance.less_than_equal(n_distance), fn() {
      shortest_distance.assign(p_distance)
      delta_sign.assign(p_luminance_delta.greater_than_equal(0.0))
    }).else_(fn() {
      shortest_distance.assign(n_distance)
      delta_sign.assign(n_luminance_delta.greater_than_equal(0.0))
    })
    let blend_factor = @nodes.float_of([]).to_var()
    @nodes.if_(
      delta_sign.equal(l.m.sub(edge_luminance).greater_than_equal(0.0)),
      fn() { blend_factor.assign(0.0) },
    ).else_(fn() {
      blend_factor.assign(
        @nodes.float(0.5).sub(shortest_distance.div(p_distance.add(n_distance))),
      )
    })
    blend_factor
  }
  let apply_fxaa = @nodes.fn_(fn(inputs, _) {
    let uv = inputs.get(0).unwrap()
    let tex_size = inputs.get(1).unwrap()
    let luminance = sample_luminance_neighborhood(tex_size, uv)
    let final_uv = @nodes.vec2(uv).to_var()
    @nodes.if_(should_skip_pixel(luminance).not_(), fn() {
      let pixel_blend = determine_pixel_blend_factor(luminance)
      let edge = determine_edge(tex_size, luminance)
      let edge_blend = determine_edge_blend_factor(
        tex_size, luminance, edge, uv,
      )
      let final_blend = @nodes.max(pixel_blend, edge_blend)
      @nodes.if_(edge.is_horizontal, fn() {
        final_uv.y().add_assign(edge.pixel_step.mul(final_blend))
      }).else_(fn() {
        final_uv.x().add_assign(edge.pixel_step.mul(final_blend))
      })
    })
    |> ignore
    Some(sample.call([final_uv]))
  })
  let fxaa = @nodes.fn_(fn(_, _) {
    Some(apply_fxaa.call([uv_node, self._inv_size]))
  })
  let output_node = fxaa.call([])
  Some(output_node)
}

///|
/// `new FXAANode( textureNode )`.
pub fn FXAANode::new(texture_node : @nodes.Node) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  node.update_before_type = @nodes.NodeUpdateType::frame()
  let _inv_size = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  node.set_class(FXAANode::{ texture_node, _inv_size, })
}

///|
pub fn FXAANode::of(node : @nodes.Node) -> FXAANode? {
  addon_class_of(node, "FXAANode")
}

///|
/// `fxaa( node )`.
pub fn fxaa(node : @nodes.Node) -> @nodes.Node {
  FXAANode::new(@nodes.convert_to_texture(node))
}
