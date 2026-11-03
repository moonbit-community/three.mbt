// nodes/accessors/TextureBicubic.js: bicubic texture filtering with four bilinear taps.

///|
let _texture_bicubic_b_c : Double = 1.0 / 6.0

///|
fn texture_bicubic_w0(a : Node) -> Node {
  mul(
    _texture_bicubic_b_c,
    mul(a, mul(a, a.negate().add(3.0)).sub(3.0)).add(1.0),
  )
}

///|
fn texture_bicubic_w1(a : Node) -> Node {
  mul(_texture_bicubic_b_c, mul(a, mul(a, mul(3.0, a).sub(6.0))).add(4.0))
}

///|
fn texture_bicubic_w2(a : Node) -> Node {
  mul(
    _texture_bicubic_b_c,
    mul(a, mul(a, mul(-3.0, a).add(3.0)).add(3.0)).add(1.0),
  )
}

///|
fn texture_bicubic_w3(a : Node) -> Node {
  mul(_texture_bicubic_b_c, pow(a, 3))
}

///|
/// `bicubicWeights( a )`: `{ g0, g1, h0, h1 }`.
fn texture_bicubic_weights(a : Node) -> (Node, Node, Node, Node) {
  let w0a = texture_bicubic_w0(a)
  let w1a = texture_bicubic_w1(a)
  let w2a = texture_bicubic_w2(a)
  let w3a = texture_bicubic_w3(a)
  let g0a = w0a.add(w1a)
  let g1a = w2a.add(w3a)
  let h0a = add(-1.0, w1a.div(g0a))
  let h1a = add(1.0, w3a.div(g1a))
  (g0a, g1a, h0a, h1a)
}

///|
/// `bicubic( textureNode, p0, p3, g0, g1, lod )`.
fn texture_bicubic_sample(
  texture_node : Node,
  p0 : Node,
  p3 : Node,
  g0 : Node,
  g1 : Node,
  lod : Node,
) -> Node {
  let p1 = vec2_of([p3.x(), p0.y()])
  let p2 = vec2_of([p0.x(), p3.y()])
  let a = g0
    .y()
    .mul(
      add(
        g0.x().mul(texture_node.sample(p0).level(lod)),
        g1.x().mul(texture_node.sample(p1).level(lod)),
      ),
    )
  let b = g1
    .y()
    .mul(
      add(
        g0.x().mul(texture_node.sample(p2).level(lod)),
        g1.x().mul(texture_node.sample(p3).level(lod)),
      ),
    )
  a.add(b)
}

///|
/// `textureBicubicLevel( textureNode, lodNode )`.
pub let texture_bicubic_level : Node = module_nodes(
  "nodes/accessors/TextureBicubic.js:textureBicubicLevel",
  fn() {
    fn_(fn(inputs, _) {
      let texture_node = inputs.get(0).unwrap()
      let lod_node = inputs.get(1).unwrap()
      let f_lod_size = vec2(texture_node.size(level_node=int(lod_node)))
      let c_lod_size = vec2(
        texture_node.size(level_node=int(lod_node.add(1.0))),
      )
      let lod_size = vec4_of([f_lod_size, c_lod_size])
      let lod_size_inv = div(1.0, lod_size)
      let uv_scaled = TextureNode::of(texture_node).unwrap().uv_node
        .unwrap()
        .xyxy()
        .mul(lod_size)
        .add(0.5)
      let iuv = floor(uv_scaled)
      let fuv = fract(uv_scaled)
      let (g0, g1, h0, h1) = texture_bicubic_weights(fuv)
      let p0 = iuv.add(h0).sub(0.5).mul(lod_size_inv)
      let p3 = iuv.add(h1).sub(0.5).mul(lod_size_inv)
      let f_sample = texture_bicubic_sample(
        texture_node,
        p0.xy(),
        p3.xy(),
        g0.xy(),
        g1.xy(),
        floor(lod_node),
      )
      let c_sample = texture_bicubic_sample(
        texture_node,
        p0.zw(),
        p3.zw(),
        g0.zw(),
        g1.zw(),
        ceil(lod_node),
      )
      Some(fract(lod_node).mix(f_sample, c_sample))
    })
  },
)

///|
/// `textureBicubic( textureNode, strength )`.
pub let texture_bicubic : Node = module_nodes(
  "nodes/accessors/TextureBicubic.js:textureBicubic",
  fn() {
    fn_(fn(inputs, _) {
      let texture_node = inputs.get(0).unwrap()
      let strength = inputs.get(1).unwrap()
      let lod = strength.mul(max_mip_level(texture_node))
      Some(texture_bicubic_level.call([texture_node, lod]))
    })
  },
)
