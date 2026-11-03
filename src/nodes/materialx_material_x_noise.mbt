// nodes/materialx/MaterialXNoise.js: the MaterialX noise library (Perlin, cell, Worley,
// fractal and unified noise). Exports that clash with MaterialXNodes take an `_impl` suffix.

///|
/// `mx_select`.
pub let mx_select : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_select",
  fn() {
    fn_(
      fn(inputs, _) {
        let b_immutable = inputs.get(0).unwrap()
        let t_immutable = inputs.get(1).unwrap()
        let f_immutable = inputs.get(2).unwrap()
        let f = float(f_immutable).to_var()
        let t = float(t_immutable).to_var()
        let b = bool(b_immutable).to_var()
        Some(select(b, t, else_node=f).uniform_flow())
      },
      layout=FnLayout::short(
        [("b", "bool"), ("t", "float"), ("f", "float")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_select",
      ),
    )
  },
)

///|
/// `mx_negate_if`.
pub let mx_negate_if : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_negate_if",
  fn() {
    fn_(
      fn(inputs, _) {
        let val_immutable = inputs.get(0).unwrap()
        let b_immutable = inputs.get(1).unwrap()
        let b = bool(b_immutable).to_var()
        let val = float(val_immutable).to_var()
        Some(select(b, val.negate(), else_node=val).uniform_flow())
      },
      layout=FnLayout::short(
        [("val", "float"), ("b", "bool")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_negate_if",
      ),
    )
  },
)

///|
/// `mx_floor`.
pub let mx_floor : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_floor",
  fn() {
    fn_(
      fn(inputs, _) {
        let x_immutable = inputs.get(0).unwrap()
        let x = float(x_immutable).to_var()
        Some(int(floor(x)))
      },
      layout=FnLayout::short(
        [("x", "float")],
        return_="int",
        upstream="nodes/materialx/MaterialXNoise.js:mx_floor",
      ),
    )
  },
)

///|
/// `mx_floorfrac`.
pub let mx_floorfrac : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_floorfrac",
  fn() {
    fn_(fn(inputs, _) {
      let x_immutable = inputs.get(0).unwrap()
      let i = inputs.get(1).unwrap()
      let x = float(x_immutable).to_var()
      i.assign(mx_floor.call([x]))
      Some(x.sub(float(i)))
    })
  },
)

///|
fn mx_bilerp_value(
  v0 : Node,
  v1 : Node,
  v2 : Node,
  v3 : Node,
  s : Node,
  t : Node,
) -> Node {
  let s1 = float(sub(1, s)).to_var()
  sub(1, t).mul(v0.mul(s1).add(v1.mul(s))).add(t.mul(v2.mul(s1).add(v3.mul(s))))
}

///|
fn mx_trilerp_value(
  v0 : Node,
  v1 : Node,
  v2 : Node,
  v3 : Node,
  v4 : Node,
  v5 : Node,
  v6 : Node,
  v7 : Node,
  s : Node,
  t : Node,
  r : Node,
) -> Node {
  let s1 = float(sub(1, s)).to_var()
  let t1 = float(sub(1, t)).to_var()
  let r1 = float(sub(1, r)).to_var()
  r1
  .mul(t1.mul(v0.mul(s1).add(v1.mul(s))).add(t.mul(v2.mul(s1).add(v3.mul(s)))))
  .add(
    r.mul(
      t1.mul(v4.mul(s1).add(v5.mul(s))).add(t.mul(v6.mul(s1).add(v7.mul(s)))),
    ),
  )
}

///|
/// `mx_bilerp_0`.
pub let mx_bilerp_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_bilerp_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let v0_immutable = inputs.get(0).unwrap()
        let v1_immutable = inputs.get(1).unwrap()
        let v2_immutable = inputs.get(2).unwrap()
        let v3_immutable = inputs.get(3).unwrap()
        let s_immutable = inputs.get(4).unwrap()
        let t_immutable = inputs.get(5).unwrap()
        let t = float(t_immutable).to_var()
        let s = float(s_immutable).to_var()
        let v3 = float(v3_immutable).to_var()
        let v2 = float(v2_immutable).to_var()
        let v1 = float(v1_immutable).to_var()
        let v0 = float(v0_immutable).to_var()
        Some(mx_bilerp_value(v0, v1, v2, v3, s, t))
      },
      layout=FnLayout::short(
        [
          ("v0", "float"),
          ("v1", "float"),
          ("v2", "float"),
          ("v3", "float"),
          ("s", "float"),
          ("t", "float"),
        ],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_bilerp_0",
      ),
    )
  },
)

///|
/// `mx_bilerp_1`.
pub let mx_bilerp_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_bilerp_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let v0_immutable = inputs.get(0).unwrap()
        let v1_immutable = inputs.get(1).unwrap()
        let v2_immutable = inputs.get(2).unwrap()
        let v3_immutable = inputs.get(3).unwrap()
        let s_immutable = inputs.get(4).unwrap()
        let t_immutable = inputs.get(5).unwrap()
        let t = float(t_immutable).to_var()
        let s = float(s_immutable).to_var()
        let v3 = vec3(v3_immutable).to_var()
        let v2 = vec3(v2_immutable).to_var()
        let v1 = vec3(v1_immutable).to_var()
        let v0 = vec3(v0_immutable).to_var()
        Some(mx_bilerp_value(v0, v1, v2, v3, s, t))
      },
      layout=FnLayout::short(
        [
          ("v0", "vec3"),
          ("v1", "vec3"),
          ("v2", "vec3"),
          ("v3", "vec3"),
          ("s", "float"),
          ("t", "float"),
        ],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_bilerp_1",
      ),
    )
  },
)

///|
/// `mx_bilerp`: picks the overload matching the argument types.
pub let mx_bilerp : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_bilerp_0, mx_bilerp_1,
])

///|
/// `mx_trilerp_0`.
pub let mx_trilerp_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_trilerp_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let v0_immutable = inputs.get(0).unwrap()
        let v1_immutable = inputs.get(1).unwrap()
        let v2_immutable = inputs.get(2).unwrap()
        let v3_immutable = inputs.get(3).unwrap()
        let v4_immutable = inputs.get(4).unwrap()
        let v5_immutable = inputs.get(5).unwrap()
        let v6_immutable = inputs.get(6).unwrap()
        let v7_immutable = inputs.get(7).unwrap()
        let s_immutable = inputs.get(8).unwrap()
        let t_immutable = inputs.get(9).unwrap()
        let r_immutable = inputs.get(10).unwrap()
        let r = float(r_immutable).to_var()
        let t = float(t_immutable).to_var()
        let s = float(s_immutable).to_var()
        let v7 = float(v7_immutable).to_var()
        let v6 = float(v6_immutable).to_var()
        let v5 = float(v5_immutable).to_var()
        let v4 = float(v4_immutable).to_var()
        let v3 = float(v3_immutable).to_var()
        let v2 = float(v2_immutable).to_var()
        let v1 = float(v1_immutable).to_var()
        let v0 = float(v0_immutable).to_var()
        Some(mx_trilerp_value(v0, v1, v2, v3, v4, v5, v6, v7, s, t, r))
      },
      layout=FnLayout::short(
        [
          ("v0", "float"),
          ("v1", "float"),
          ("v2", "float"),
          ("v3", "float"),
          ("v4", "float"),
          ("v5", "float"),
          ("v6", "float"),
          ("v7", "float"),
          ("s", "float"),
          ("t", "float"),
          ("r", "float"),
        ],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_trilerp_0",
      ),
    )
  },
)

///|
/// `mx_trilerp_1`.
pub let mx_trilerp_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_trilerp_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let v0_immutable = inputs.get(0).unwrap()
        let v1_immutable = inputs.get(1).unwrap()
        let v2_immutable = inputs.get(2).unwrap()
        let v3_immutable = inputs.get(3).unwrap()
        let v4_immutable = inputs.get(4).unwrap()
        let v5_immutable = inputs.get(5).unwrap()
        let v6_immutable = inputs.get(6).unwrap()
        let v7_immutable = inputs.get(7).unwrap()
        let s_immutable = inputs.get(8).unwrap()
        let t_immutable = inputs.get(9).unwrap()
        let r_immutable = inputs.get(10).unwrap()
        let r = float(r_immutable).to_var()
        let t = float(t_immutable).to_var()
        let s = float(s_immutable).to_var()
        let v7 = vec3(v7_immutable).to_var()
        let v6 = vec3(v6_immutable).to_var()
        let v5 = vec3(v5_immutable).to_var()
        let v4 = vec3(v4_immutable).to_var()
        let v3 = vec3(v3_immutable).to_var()
        let v2 = vec3(v2_immutable).to_var()
        let v1 = vec3(v1_immutable).to_var()
        let v0 = vec3(v0_immutable).to_var()
        Some(mx_trilerp_value(v0, v1, v2, v3, v4, v5, v6, v7, s, t, r))
      },
      layout=FnLayout::short(
        [
          ("v0", "vec3"),
          ("v1", "vec3"),
          ("v2", "vec3"),
          ("v3", "vec3"),
          ("v4", "vec3"),
          ("v5", "vec3"),
          ("v6", "vec3"),
          ("v7", "vec3"),
          ("s", "float"),
          ("t", "float"),
          ("r", "float"),
        ],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_trilerp_1",
      ),
    )
  },
)

///|
/// `mx_trilerp`: picks the overload matching the argument types.
pub let mx_trilerp : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_trilerp_0, mx_trilerp_1,
])

///|
/// `mx_gradient_float_0`.
pub let mx_gradient_float_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_gradient_float_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let hash_immutable = inputs.get(0).unwrap()
        let x_immutable = inputs.get(1).unwrap()
        let y_immutable = inputs.get(2).unwrap()
        let y = float(y_immutable).to_var()
        let x = float(x_immutable).to_var()
        let hash = uint(hash_immutable).to_var()
        let h = uint(hash.bit_and(uint(7))).to_var()
        let u = float(mx_select.call([h.less_than(uint(4)), x, y])).to_var()
        let v = float(mul(2, mx_select.call([h.less_than(uint(4)), y, x]))).to_var()
        Some(
          mx_negate_if
          .call([u, bool(h.bit_and(uint(1)))])
          .add(mx_negate_if.call([v, bool(h.bit_and(uint(2)))])),
        )
      },
      layout=FnLayout::short(
        [("hash", "uint"), ("x", "float"), ("y", "float")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_gradient_float_0",
      ),
    )
  },
)

///|
/// `mx_gradient_float_1`.
pub let mx_gradient_float_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_gradient_float_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let hash_immutable = inputs.get(0).unwrap()
        let x_immutable = inputs.get(1).unwrap()
        let y_immutable = inputs.get(2).unwrap()
        let z_immutable = inputs.get(3).unwrap()
        let z = float(z_immutable).to_var()
        let y = float(y_immutable).to_var()
        let x = float(x_immutable).to_var()
        let hash = uint(hash_immutable).to_var()
        let h = uint(hash.bit_and(uint(15))).to_var()
        let u = float(mx_select.call([h.less_than(uint(8)), x, y])).to_var()
        let v = float(
          mx_select.call([
            h.less_than(uint(4)),
            y,
            mx_select.call([h.equal(uint(12)).or(h.equal(uint(14))), x, z]),
          ]),
        ).to_var()
        Some(
          mx_negate_if
          .call([u, bool(h.bit_and(uint(1)))])
          .add(mx_negate_if.call([v, bool(h.bit_and(uint(2)))])),
        )
      },
      layout=FnLayout::short(
        [("hash", "uint"), ("x", "float"), ("y", "float"), ("z", "float")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_gradient_float_1",
      ),
    )
  },
)

///|
/// `mx_gradient_float`: picks the overload matching the argument types.
pub let mx_gradient_float : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_gradient_float_0, mx_gradient_float_1,
])

///|
/// `mx_gradient_vec3_0`.
pub let mx_gradient_vec3_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_gradient_vec3_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let hash_immutable = inputs.get(0).unwrap()
        let x_immutable = inputs.get(1).unwrap()
        let y_immutable = inputs.get(2).unwrap()
        let y = float(y_immutable).to_var()
        let x = float(x_immutable).to_var()
        let hash = uvec3(hash_immutable).to_var()
        Some(
          vec3_of([
            mx_gradient_float([hash.x(), x, y]),
            mx_gradient_float([hash.y(), x, y]),
            mx_gradient_float([hash.z(), x, y]),
          ]),
        )
      },
      layout=FnLayout::short(
        [("hash", "uvec3"), ("x", "float"), ("y", "float")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_gradient_vec3_0",
      ),
    )
  },
)

///|
/// `mx_gradient_vec3_1`.
pub let mx_gradient_vec3_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_gradient_vec3_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let hash_immutable = inputs.get(0).unwrap()
        let x_immutable = inputs.get(1).unwrap()
        let y_immutable = inputs.get(2).unwrap()
        let z_immutable = inputs.get(3).unwrap()
        let z = float(z_immutable).to_var()
        let y = float(y_immutable).to_var()
        let x = float(x_immutable).to_var()
        let hash = uvec3(hash_immutable).to_var()
        Some(
          vec3_of([
            mx_gradient_float([hash.x(), x, y, z]),
            mx_gradient_float([hash.y(), x, y, z]),
            mx_gradient_float([hash.z(), x, y, z]),
          ]),
        )
      },
      layout=FnLayout::short(
        [("hash", "uvec3"), ("x", "float"), ("y", "float"), ("z", "float")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_gradient_vec3_1",
      ),
    )
  },
)

///|
/// `mx_gradient_vec3`: picks the overload matching the argument types.
pub let mx_gradient_vec3 : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_gradient_vec3_0, mx_gradient_vec3_1,
])

///|
/// `mx_gradient_scale2d_0`.
pub let mx_gradient_scale2d_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_gradient_scale2d_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let v_immutable = inputs.get(0).unwrap()
        let v = float(v_immutable).to_var()
        Some(mul(0.6616, v))
      },
      layout=FnLayout::short(
        [("v", "float")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_gradient_scale2d_0",
      ),
    )
  },
)

///|
/// `mx_gradient_scale3d_0`.
pub let mx_gradient_scale3d_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_gradient_scale3d_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let v_immutable = inputs.get(0).unwrap()
        let v = float(v_immutable).to_var()
        Some(mul(0.982, v))
      },
      layout=FnLayout::short(
        [("v", "float")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_gradient_scale3d_0",
      ),
    )
  },
)

///|
/// `mx_gradient_scale2d_1`.
pub let mx_gradient_scale2d_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_gradient_scale2d_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let v_immutable = inputs.get(0).unwrap()
        let v = vec3(v_immutable).to_var()
        Some(mul(0.6616, v))
      },
      layout=FnLayout::short(
        [("v", "vec3")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_gradient_scale2d_1",
      ),
    )
  },
)

///|
/// `mx_gradient_scale2d`: picks the overload matching the argument types.
pub let mx_gradient_scale2d : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_gradient_scale2d_0, mx_gradient_scale2d_1,
])

///|
/// `mx_gradient_scale3d_1`.
pub let mx_gradient_scale3d_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_gradient_scale3d_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let v_immutable = inputs.get(0).unwrap()
        let v = vec3(v_immutable).to_var()
        Some(mul(0.982, v))
      },
      layout=FnLayout::short(
        [("v", "vec3")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_gradient_scale3d_1",
      ),
    )
  },
)

///|
/// `mx_gradient_scale3d`: picks the overload matching the argument types.
pub let mx_gradient_scale3d : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_gradient_scale3d_0, mx_gradient_scale3d_1,
])

///|
/// `mx_rotl32`.
pub let mx_rotl32 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_rotl32",
  fn() {
    fn_(
      fn(inputs, _) {
        let x_immutable = inputs.get(0).unwrap()
        let k_immutable = inputs.get(1).unwrap()
        let k = int(k_immutable).to_var()
        let x = uint(x_immutable).to_var()
        Some(x.shift_left(k).bit_or(x.shift_right(int(32).sub(k))))
      },
      layout=FnLayout::short(
        [("x", "uint"), ("k", "int")],
        return_="uint",
        upstream="nodes/materialx/MaterialXNoise.js:mx_rotl32",
      ),
    )
  },
)

///|
/// `mx_bjmix`.
pub let mx_bjmix : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_bjmix",
  fn() {
    fn_(
      fn(inputs, _) {
        let mut a = inputs.get(0).unwrap()
        let mut b = inputs.get(1).unwrap()
        let mut c = inputs.get(2).unwrap()
        a = uint(a).to_var()
        b = uint(b).to_var()
        c = uint(c).to_var()
        a.sub_assign(c)
        a.bit_xor_assign(mx_rotl32.call([c, int(4)]))
        c.add_assign(b)
        b.sub_assign(a)
        b.bit_xor_assign(mx_rotl32.call([a, int(6)]))
        a.add_assign(c)
        c.sub_assign(b)
        c.bit_xor_assign(mx_rotl32.call([b, int(8)]))
        b.add_assign(a)
        a.sub_assign(c)
        a.bit_xor_assign(mx_rotl32.call([c, int(16)]))
        c.add_assign(b)
        b.sub_assign(a)
        b.bit_xor_assign(mx_rotl32.call([a, int(19)]))
        a.add_assign(c)
        c.sub_assign(b)
        c.bit_xor_assign(mx_rotl32.call([b, int(4)]))
        b.add_assign(a)
        Some(uvec3_of([a, b, c]))
      },
      layout=FnLayout::short(
        [("a", "uint"), ("b", "uint"), ("c", "uint")],
        return_="uvec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_bjmix",
      ),
    )
  },
)

///|
/// `mx_bjfinal`.
pub let mx_bjfinal : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_bjfinal",
  fn() {
    fn_(
      fn(inputs, _) {
        let a_immutable = inputs.get(0).unwrap()
        let b_immutable = inputs.get(1).unwrap()
        let c_immutable = inputs.get(2).unwrap()
        let c = uint(c_immutable).to_var()
        let b = uint(b_immutable).to_var()
        let a = uint(a_immutable).to_var()
        c.bit_xor_assign(b)
        c.sub_assign(mx_rotl32.call([b, int(14)]))
        a.bit_xor_assign(c)
        a.sub_assign(mx_rotl32.call([c, int(11)]))
        b.bit_xor_assign(a)
        b.sub_assign(mx_rotl32.call([a, int(25)]))
        c.bit_xor_assign(b)
        c.sub_assign(mx_rotl32.call([b, int(16)]))
        a.bit_xor_assign(c)
        a.sub_assign(mx_rotl32.call([c, int(4)]))
        b.bit_xor_assign(a)
        b.sub_assign(mx_rotl32.call([a, int(14)]))
        c.bit_xor_assign(b)
        c.sub_assign(mx_rotl32.call([b, int(24)]))
        Some(c)
      },
      layout=FnLayout::short(
        [("a", "uint"), ("b", "uint"), ("c", "uint")],
        return_="uint",
        upstream="nodes/materialx/MaterialXNoise.js:mx_bjfinal",
      ),
    )
  },
)

///|
/// `mx_bits_to_01`.
pub let mx_bits_to_01 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_bits_to_01",
  fn() {
    fn_(
      fn(inputs, _) {
        let bits_immutable = inputs.get(0).unwrap()
        let bits = uint(bits_immutable).to_var()
        Some(float(bits).div(float(uint(4294967295.0))))
      },
      layout=FnLayout::short(
        [("bits", "uint")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_bits_to_01",
      ),
    )
  },
)

///|
/// `mx_fade`.
pub let mx_fade : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_fade",
  fn() {
    fn_(
      fn(inputs, _) {
        let t_immutable = inputs.get(0).unwrap()
        let t = float(t_immutable).to_var()
        Some(t.mul(t).mul(t).mul(t.mul(t.mul(6).sub(15)).add(10)))
      },
      layout=FnLayout::short(
        [("t", "float")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_fade",
      ),
    )
  },
)

///|
/// `mx_hash_int_0`.
pub let mx_hash_int_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_hash_int_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let x_immutable = inputs.get(0).unwrap()
        let x = int(x_immutable).to_var()
        let len = uint(uint(1)).to_var()
        let seed = uint(
          uint(3735928559.0).add(len.shift_left(uint(2))).add(uint(13)),
        ).to_var()
        Some(mx_bjfinal.call([seed.add(uint(x)), seed, seed]))
      },
      layout=FnLayout::short(
        [("x", "int")],
        return_="uint",
        upstream="nodes/materialx/MaterialXNoise.js:mx_hash_int_0",
      ),
    )
  },
)

///|
/// `mx_hash_int_1`.
pub let mx_hash_int_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_hash_int_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let x_immutable = inputs.get(0).unwrap()
        let y_immutable = inputs.get(1).unwrap()
        let y = int(y_immutable).to_var()
        let x = int(x_immutable).to_var()
        let len = uint(uint(2)).to_var()
        let a = uint_of([]).to_var()
        let b = uint_of([]).to_var()
        let c = uint_of([]).to_var()
        a.assign(
          b.assign_node(
            c.assign_node(
              uint(3735928559.0).add(len.shift_left(uint(2))).add(uint(13)),
            ),
          ),
        )
        a.add_assign(uint(x))
        b.add_assign(uint(y))
        Some(mx_bjfinal.call([a, b, c]))
      },
      layout=FnLayout::short(
        [("x", "int"), ("y", "int")],
        return_="uint",
        upstream="nodes/materialx/MaterialXNoise.js:mx_hash_int_1",
      ),
    )
  },
)

///|
/// `mx_hash_int_2`.
pub let mx_hash_int_2 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_hash_int_2",
  fn() {
    fn_(
      fn(inputs, _) {
        let x_immutable = inputs.get(0).unwrap()
        let y_immutable = inputs.get(1).unwrap()
        let z_immutable = inputs.get(2).unwrap()
        let z = int(z_immutable).to_var()
        let y = int(y_immutable).to_var()
        let x = int(x_immutable).to_var()
        let len = uint(uint(3)).to_var()
        let a = uint_of([]).to_var()
        let b = uint_of([]).to_var()
        let c = uint_of([]).to_var()
        a.assign(
          b.assign_node(
            c.assign_node(
              uint(3735928559.0).add(len.shift_left(uint(2))).add(uint(13)),
            ),
          ),
        )
        a.add_assign(uint(x))
        b.add_assign(uint(y))
        c.add_assign(uint(z))
        Some(mx_bjfinal.call([a, b, c]))
      },
      layout=FnLayout::short(
        [("x", "int"), ("y", "int"), ("z", "int")],
        return_="uint",
        upstream="nodes/materialx/MaterialXNoise.js:mx_hash_int_2",
      ),
    )
  },
)

///|
/// `mx_hash_int_3`.
pub let mx_hash_int_3 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_hash_int_3",
  fn() {
    fn_(
      fn(inputs, _) {
        let x_immutable = inputs.get(0).unwrap()
        let y_immutable = inputs.get(1).unwrap()
        let z_immutable = inputs.get(2).unwrap()
        let xx_immutable = inputs.get(3).unwrap()
        let xx = int(xx_immutable).to_var()
        let z = int(z_immutable).to_var()
        let y = int(y_immutable).to_var()
        let x = int(x_immutable).to_var()
        let len = uint(uint(4)).to_var()
        let a = uint_of([]).to_var()
        let b = uint_of([]).to_var()
        let c = uint_of([]).to_var()
        a.assign(
          b.assign_node(
            c.assign_node(
              uint(3735928559.0).add(len.shift_left(uint(2))).add(uint(13)),
            ),
          ),
        )
        a.add_assign(uint(x))
        b.add_assign(uint(y))
        c.add_assign(uint(z))
        let mixed = uvec3(mx_bjmix.call([a, b, c])).to_var()
        a.assign(mixed.x())
        b.assign(mixed.y())
        c.assign(mixed.z())
        a.add_assign(uint(xx))
        Some(mx_bjfinal.call([a, b, c]))
      },
      layout=FnLayout::short(
        [("x", "int"), ("y", "int"), ("z", "int"), ("xx", "int")],
        return_="uint",
        upstream="nodes/materialx/MaterialXNoise.js:mx_hash_int_3",
      ),
    )
  },
)

///|
/// `mx_hash_int_4`.
pub let mx_hash_int_4 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_hash_int_4",
  fn() {
    fn_(
      fn(inputs, _) {
        let x_immutable = inputs.get(0).unwrap()
        let y_immutable = inputs.get(1).unwrap()
        let z_immutable = inputs.get(2).unwrap()
        let xx_immutable = inputs.get(3).unwrap()
        let yy_immutable = inputs.get(4).unwrap()
        let yy = int(yy_immutable).to_var()
        let xx = int(xx_immutable).to_var()
        let z = int(z_immutable).to_var()
        let y = int(y_immutable).to_var()
        let x = int(x_immutable).to_var()
        let len = uint(uint(5)).to_var()
        let a = uint_of([]).to_var()
        let b = uint_of([]).to_var()
        let c = uint_of([]).to_var()
        a.assign(
          b.assign_node(
            c.assign_node(
              uint(3735928559.0).add(len.shift_left(uint(2))).add(uint(13)),
            ),
          ),
        )
        a.add_assign(uint(x))
        b.add_assign(uint(y))
        c.add_assign(uint(z))
        let mixed = uvec3(mx_bjmix.call([a, b, c])).to_var()
        a.assign(mixed.x())
        b.assign(mixed.y())
        c.assign(mixed.z())
        a.add_assign(uint(xx))
        b.add_assign(uint(yy))
        Some(mx_bjfinal.call([a, b, c]))
      },
      layout=FnLayout::short(
        [("x", "int"), ("y", "int"), ("z", "int"), ("xx", "int"), ("yy", "int")],
        return_="uint",
        upstream="nodes/materialx/MaterialXNoise.js:mx_hash_int_4",
      ),
    )
  },
)

///|
/// `mx_hash_int`: picks the overload matching the argument types.
pub let mx_hash_int : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_hash_int_0, mx_hash_int_1, mx_hash_int_2, mx_hash_int_3, mx_hash_int_4,
])

///|
/// `mx_hash_vec3_0`.
pub let mx_hash_vec3_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_hash_vec3_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let x_immutable = inputs.get(0).unwrap()
        let y_immutable = inputs.get(1).unwrap()
        let y = int(y_immutable).to_var()
        let x = int(x_immutable).to_var()
        let h = uint(mx_hash_int([x, y])).to_var()
        let result = uvec3_of([]).to_var()
        result.x().assign(h.bit_and(int(255)))
        result.y().assign(h.shift_right(int(8)).bit_and(int(255)))
        result.z().assign(h.shift_right(int(16)).bit_and(int(255)))
        Some(result)
      },
      layout=FnLayout::short(
        [("x", "int"), ("y", "int")],
        return_="uvec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_hash_vec3_0",
      ),
    )
  },
)

///|
/// `mx_hash_vec3_1`.
pub let mx_hash_vec3_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_hash_vec3_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let x_immutable = inputs.get(0).unwrap()
        let y_immutable = inputs.get(1).unwrap()
        let z_immutable = inputs.get(2).unwrap()
        let z = int(z_immutable).to_var()
        let y = int(y_immutable).to_var()
        let x = int(x_immutable).to_var()
        let h = uint(mx_hash_int([x, y, z])).to_var()
        let result = uvec3_of([]).to_var()
        result.x().assign(h.bit_and(int(255)))
        result.y().assign(h.shift_right(int(8)).bit_and(int(255)))
        result.z().assign(h.shift_right(int(16)).bit_and(int(255)))
        Some(result)
      },
      layout=FnLayout::short(
        [("x", "int"), ("y", "int"), ("z", "int")],
        return_="uvec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_hash_vec3_1",
      ),
    )
  },
)

///|
/// `mx_hash_vec3`: picks the overload matching the argument types.
pub let mx_hash_vec3 : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_hash_vec3_0, mx_hash_vec3_1,
])

///|
/// `mx_perlin_noise_float_0`.
pub let mx_perlin_noise_float_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_perlin_noise_float_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let p = vec2(p_immutable).to_var()
        let k_x = int_of([]).to_var()
        let k_y = int_of([]).to_var()
        let fx = float(mx_floorfrac.call([p.x(), k_x])).to_var()
        let fy = float(mx_floorfrac.call([p.y(), k_y])).to_var()
        let u = float(mx_fade.call([fx])).to_var()
        let v = float(mx_fade.call([fy])).to_var()
        let result = float(
          mx_bilerp([
            mx_gradient_float([mx_hash_int([k_x, k_y]), fx, fy]),
            mx_gradient_float([
              mx_hash_int([k_x.add(int(1)), k_y]),
              fx.sub(1),
              fy,
            ]),
            mx_gradient_float([
              mx_hash_int([k_x, k_y.add(int(1))]),
              fx,
              fy.sub(1),
            ]),
            mx_gradient_float([
              mx_hash_int([k_x.add(int(1)), k_y.add(int(1))]),
              fx.sub(1),
              fy.sub(1),
            ]),
            u,
            v,
          ]),
        ).to_var()
        Some(mx_gradient_scale2d([result]))
      },
      layout=FnLayout::short(
        [("p", "vec2")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_perlin_noise_float_0",
      ),
    )
  },
)

///|
/// `mx_perlin_noise_float_1`.
pub let mx_perlin_noise_float_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_perlin_noise_float_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let p = vec3(p_immutable).to_var()
        let k_x = int_of([]).to_var()
        let k_y = int_of([]).to_var()
        let k_z = int_of([]).to_var()
        let fx = float(mx_floorfrac.call([p.x(), k_x])).to_var()
        let fy = float(mx_floorfrac.call([p.y(), k_y])).to_var()
        let fz = float(mx_floorfrac.call([p.z(), k_z])).to_var()
        let u = float(mx_fade.call([fx])).to_var()
        let v = float(mx_fade.call([fy])).to_var()
        let w = float(mx_fade.call([fz])).to_var()
        let result = float(
          mx_trilerp([
            mx_gradient_float([mx_hash_int([k_x, k_y, k_z]), fx, fy, fz]),
            mx_gradient_float([
              mx_hash_int([k_x.add(int(1)), k_y, k_z]),
              fx.sub(1),
              fy,
              fz,
            ]),
            mx_gradient_float([
              mx_hash_int([k_x, k_y.add(int(1)), k_z]),
              fx,
              fy.sub(1),
              fz,
            ]),
            mx_gradient_float([
              mx_hash_int([k_x.add(int(1)), k_y.add(int(1)), k_z]),
              fx.sub(1),
              fy.sub(1),
              fz,
            ]),
            mx_gradient_float([
              mx_hash_int([k_x, k_y, k_z.add(int(1))]),
              fx,
              fy,
              fz.sub(1),
            ]),
            mx_gradient_float([
              mx_hash_int([k_x.add(int(1)), k_y, k_z.add(int(1))]),
              fx.sub(1),
              fy,
              fz.sub(1),
            ]),
            mx_gradient_float([
              mx_hash_int([k_x, k_y.add(int(1)), k_z.add(int(1))]),
              fx,
              fy.sub(1),
              fz.sub(1),
            ]),
            mx_gradient_float([
              mx_hash_int([k_x.add(int(1)), k_y.add(int(1)), k_z.add(int(1))]),
              fx.sub(1),
              fy.sub(1),
              fz.sub(1),
            ]),
            u,
            v,
            w,
          ]),
        ).to_var()
        Some(mx_gradient_scale3d([result]))
      },
      layout=FnLayout::short(
        [("p", "vec3")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_perlin_noise_float_1",
      ),
    )
  },
)

///|
/// `mx_perlin_noise_float`: picks the overload matching the argument types.
pub let mx_perlin_noise_float : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_perlin_noise_float_0, mx_perlin_noise_float_1,
])

///|
/// `mx_perlin_noise_vec3_0`.
pub let mx_perlin_noise_vec3_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_perlin_noise_vec3_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let p = vec2(p_immutable).to_var()
        let k_x = int_of([]).to_var()
        let k_y = int_of([]).to_var()
        let fx = float(mx_floorfrac.call([p.x(), k_x])).to_var()
        let fy = float(mx_floorfrac.call([p.y(), k_y])).to_var()
        let u = float(mx_fade.call([fx])).to_var()
        let v = float(mx_fade.call([fy])).to_var()
        let result = vec3(
          mx_bilerp([
            mx_gradient_vec3([mx_hash_vec3([k_x, k_y]), fx, fy]),
            mx_gradient_vec3([
              mx_hash_vec3([k_x.add(int(1)), k_y]),
              fx.sub(1),
              fy,
            ]),
            mx_gradient_vec3([
              mx_hash_vec3([k_x, k_y.add(int(1))]),
              fx,
              fy.sub(1),
            ]),
            mx_gradient_vec3([
              mx_hash_vec3([k_x.add(int(1)), k_y.add(int(1))]),
              fx.sub(1),
              fy.sub(1),
            ]),
            u,
            v,
          ]),
        ).to_var()
        Some(mx_gradient_scale2d([result]))
      },
      layout=FnLayout::short(
        [("p", "vec2")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_perlin_noise_vec3_0",
      ),
    )
  },
)

///|
/// `mx_perlin_noise_vec3_1`.
pub let mx_perlin_noise_vec3_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_perlin_noise_vec3_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let p = vec3(p_immutable).to_var()
        let k_x = int_of([]).to_var()
        let k_y = int_of([]).to_var()
        let k_z = int_of([]).to_var()
        let fx = float(mx_floorfrac.call([p.x(), k_x])).to_var()
        let fy = float(mx_floorfrac.call([p.y(), k_y])).to_var()
        let fz = float(mx_floorfrac.call([p.z(), k_z])).to_var()
        let u = float(mx_fade.call([fx])).to_var()
        let v = float(mx_fade.call([fy])).to_var()
        let w = float(mx_fade.call([fz])).to_var()
        let result = vec3(
          mx_trilerp([
            mx_gradient_vec3([mx_hash_vec3([k_x, k_y, k_z]), fx, fy, fz]),
            mx_gradient_vec3([
              mx_hash_vec3([k_x.add(int(1)), k_y, k_z]),
              fx.sub(1),
              fy,
              fz,
            ]),
            mx_gradient_vec3([
              mx_hash_vec3([k_x, k_y.add(int(1)), k_z]),
              fx,
              fy.sub(1),
              fz,
            ]),
            mx_gradient_vec3([
              mx_hash_vec3([k_x.add(int(1)), k_y.add(int(1)), k_z]),
              fx.sub(1),
              fy.sub(1),
              fz,
            ]),
            mx_gradient_vec3([
              mx_hash_vec3([k_x, k_y, k_z.add(int(1))]),
              fx,
              fy,
              fz.sub(1),
            ]),
            mx_gradient_vec3([
              mx_hash_vec3([k_x.add(int(1)), k_y, k_z.add(int(1))]),
              fx.sub(1),
              fy,
              fz.sub(1),
            ]),
            mx_gradient_vec3([
              mx_hash_vec3([k_x, k_y.add(int(1)), k_z.add(int(1))]),
              fx,
              fy.sub(1),
              fz.sub(1),
            ]),
            mx_gradient_vec3([
              mx_hash_vec3([k_x.add(int(1)), k_y.add(int(1)), k_z.add(int(1))]),
              fx.sub(1),
              fy.sub(1),
              fz.sub(1),
            ]),
            u,
            v,
            w,
          ]),
        ).to_var()
        Some(mx_gradient_scale3d([result]))
      },
      layout=FnLayout::short(
        [("p", "vec3")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_perlin_noise_vec3_1",
      ),
    )
  },
)

///|
/// `mx_perlin_noise_vec3`: picks the overload matching the argument types.
pub let mx_perlin_noise_vec3 : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_perlin_noise_vec3_0, mx_perlin_noise_vec3_1,
])

///|
/// `mx_cell_noise_float_0`.
pub let mx_cell_noise_float_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_cell_noise_float_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let p = float(p_immutable).to_var()
        let ix = int(mx_floor.call([p])).to_var()
        Some(mx_bits_to_01.call([mx_hash_int([ix])]))
      },
      layout=FnLayout::short(
        [("p", "float")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_cell_noise_float_0",
      ),
    )
  },
)

///|
/// `mx_cell_noise_float_1`.
pub let mx_cell_noise_float_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_cell_noise_float_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let p = vec2(p_immutable).to_var()
        let ix = int(mx_floor.call([p.x()])).to_var()
        let iy = int(mx_floor.call([p.y()])).to_var()
        Some(mx_bits_to_01.call([mx_hash_int([ix, iy])]))
      },
      layout=FnLayout::short(
        [("p", "vec2")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_cell_noise_float_1",
      ),
    )
  },
)

///|
/// `mx_cell_noise_float_2`.
pub let mx_cell_noise_float_2 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_cell_noise_float_2",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let p = vec3(p_immutable).to_var()
        let ix = int(mx_floor.call([p.x()])).to_var()
        let iy = int(mx_floor.call([p.y()])).to_var()
        let iz = int(mx_floor.call([p.z()])).to_var()
        Some(mx_bits_to_01.call([mx_hash_int([ix, iy, iz])]))
      },
      layout=FnLayout::short(
        [("p", "vec3")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_cell_noise_float_2",
      ),
    )
  },
)

///|
/// `mx_cell_noise_float_3`.
pub let mx_cell_noise_float_3 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_cell_noise_float_3",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let p = vec4(p_immutable).to_var()
        let ix = int(mx_floor.call([p.x()])).to_var()
        let iy = int(mx_floor.call([p.y()])).to_var()
        let iz = int(mx_floor.call([p.z()])).to_var()
        let iw = int(mx_floor.call([p.w()])).to_var()
        Some(mx_bits_to_01.call([mx_hash_int([ix, iy, iz, iw])]))
      },
      layout=FnLayout::short(
        [("p", "vec4")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_cell_noise_float_3",
      ),
    )
  },
)

///|
/// `mx_cell_noise_float`: picks the overload matching the argument types.
pub let mx_cell_noise_float_impl : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_cell_noise_float_0, mx_cell_noise_float_1, mx_cell_noise_float_2, mx_cell_noise_float_3,
])

///|
/// `mx_cell_noise_vec3_0`.
pub let mx_cell_noise_vec3_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_cell_noise_vec3_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let p = float(p_immutable).to_var()
        let ix = int(mx_floor.call([p])).to_var()
        Some(
          vec3_of([
            mx_bits_to_01.call([mx_hash_int([ix, int(0)])]),
            mx_bits_to_01.call([mx_hash_int([ix, int(1)])]),
            mx_bits_to_01.call([mx_hash_int([ix, int(2)])]),
          ]),
        )
      },
      layout=FnLayout::short(
        [("p", "float")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_cell_noise_vec3_0",
      ),
    )
  },
)

///|
/// `mx_cell_noise_vec3_1`.
pub let mx_cell_noise_vec3_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_cell_noise_vec3_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let p = vec2(p_immutable).to_var()
        let ix = int(mx_floor.call([p.x()])).to_var()
        let iy = int(mx_floor.call([p.y()])).to_var()
        Some(
          vec3_of([
            mx_bits_to_01.call([mx_hash_int([ix, iy, int(0)])]),
            mx_bits_to_01.call([mx_hash_int([ix, iy, int(1)])]),
            mx_bits_to_01.call([mx_hash_int([ix, iy, int(2)])]),
          ]),
        )
      },
      layout=FnLayout::short(
        [("p", "vec2")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_cell_noise_vec3_1",
      ),
    )
  },
)

///|
/// `mx_cell_noise_vec3_2`.
pub let mx_cell_noise_vec3_2 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_cell_noise_vec3_2",
  fn() {
    fn_(
      fn(inputs, _) {
        let position_input = inputs.get(0).unwrap()
        let position = vec3(position_input).to_var()
        let ix = int(floor(position.x())).to_var()
        let iy = int(floor(position.y())).to_var()
        let iz = int(floor(position.z())).to_var()
        let seed = uint(3735928588.0).to_var()
        let a = uint_of([]).to_var()
        let b = uint_of([]).to_var()
        let c = uint_of([]).to_var()
        a.assign(b.assign_node(c.assign_node(seed)))
        a.add_assign(uint(ix))
        b.add_assign(uint(iy))
        c.add_assign(uint(iz))
        let mixed = uvec3(mx_bjmix.call([a, b, c])).to_var()
        let hash0 = mx_bjfinal.call([mixed.x(), mixed.y(), mixed.z()])
        let hash1 = mx_bjfinal.call([
          add(mixed.x(), uint(1)),
          mixed.y(),
          mixed.z(),
        ])
        let hash2 = mx_bjfinal.call([
          add(mixed.x(), uint(2)),
          mixed.y(),
          mixed.z(),
        ])
        Some(
          vec3_of([
            mx_bits_to_01.call([hash0]),
            mx_bits_to_01.call([hash1]),
            mx_bits_to_01.call([hash2]),
          ]),
        )
      },
      layout=FnLayout::short(
        [("p", "vec3")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_cell_noise_vec3_2",
      ),
    )
  },
)

///|
/// `mx_cell_noise_vec3_3`.
pub let mx_cell_noise_vec3_3 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_cell_noise_vec3_3",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let p = vec4(p_immutable).to_var()
        let ix = int(mx_floor.call([p.x()])).to_var()
        let iy = int(mx_floor.call([p.y()])).to_var()
        let iz = int(mx_floor.call([p.z()])).to_var()
        let iw = int(mx_floor.call([p.w()])).to_var()
        let seed = uint(3735928592.0).to_var()
        let a = uint_of([]).to_var()
        let b = uint_of([]).to_var()
        let c = uint_of([]).to_var()
        a.assign(b.assign_node(c.assign_node(seed)))
        a.add_assign(uint(ix))
        b.add_assign(uint(iy))
        c.add_assign(uint(iz))
        let mixed = uvec3(mx_bjmix.call([a, b, c])).to_var()
        a.assign(mixed.x())
        b.assign(mixed.y())
        c.assign(mixed.z())
        a.add_assign(uint(iw))
        Some(
          vec3_of([
            mx_bits_to_01.call([mx_bjfinal.call([a, b, c])]),
            mx_bits_to_01.call([mx_bjfinal.call([a, add(b, uint(1)), c])]),
            mx_bits_to_01.call([mx_bjfinal.call([a, add(b, uint(2)), c])]),
          ]),
        )
      },
      layout=FnLayout::short(
        [("p", "vec4")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_cell_noise_vec3_3",
      ),
    )
  },
)

///|
/// `mx_cell_noise_vec3`: picks the overload matching the argument types.
pub let mx_cell_noise_vec3_impl : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_cell_noise_vec3_0, mx_cell_noise_vec3_1, mx_cell_noise_vec3_2, mx_cell_noise_vec3_3,
])

///|
let mx_cell_noise_vec3_3d : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_cell_noise_vec3_3d",
  fn() {
    fn_(
      fn(inputs, _) {
        let position_input = inputs.get(0).unwrap()
        let position = vec3(position_input).to_var()
        let ix = int(floor(position.x())).to_var()
        let iy = int(floor(position.y())).to_var()
        let iz = int(floor(position.z())).to_var()
        let seed = uint(3735928588.0).to_var()
        let a = uint_of([]).to_var()
        let b = uint_of([]).to_var()
        let c = uint_of([]).to_var()
        a.assign(b.assign_node(c.assign_node(seed)))
        a.add_assign(uint(ix))
        b.add_assign(uint(iy))
        c.add_assign(uint(iz))
        let mixed = uvec3(mx_bjmix.call([a, b, c])).to_var()
        let hash0 = mx_bjfinal.call([mixed.x(), mixed.y(), mixed.z()])
        let hash1 = mx_bjfinal.call([
          add(mixed.x(), uint(1)),
          mixed.y(),
          mixed.z(),
        ])
        let hash2 = mx_bjfinal.call([
          add(mixed.x(), uint(2)),
          mixed.y(),
          mixed.z(),
        ])
        Some(
          vec3_of([
            mx_bits_to_01.call([hash0]),
            mx_bits_to_01.call([hash1]),
            mx_bits_to_01.call([hash2]),
          ]),
        )
      },
      layout=FnLayout::short(
        [("position", "vec3")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_cell_noise_vec3_3d",
      ),
    )
  },
)

///|
/// `mx_fractal_noise_float_2d`.
pub let mx_fractal_noise_float_2d_impl : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_fractal_noise_float_2d",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let octaves_immutable = inputs.get(1).unwrap()
        let lacunarity_immutable = inputs.get(2).unwrap()
        let diminish_immutable = inputs.get(3).unwrap()
        let diminish = float(diminish_immutable).to_var()
        let lacunarity = float(lacunarity_immutable).to_var()
        let octaves = int(octaves_immutable).to_var()
        let p = vec2(p_immutable).to_var()
        let result = float(0).to_var()
        let amplitude = float(1).to_var()
        loop_([octaves], fn(_) {
          result.add_assign(amplitude.mul(mx_perlin_noise_float([p])))
          amplitude.mul_assign(diminish)
          p.mul_assign(lacunarity)
        })
        Some(result)
      },
      layout=FnLayout::short(
        [
          ("p", "vec2"),
          ("octaves", "int"),
          ("lacunarity", "float"),
          ("diminish", "float"),
        ],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_fractal_noise_float_2d",
      ),
    )
  },
)

///|
/// `mx_fractal_noise_float`.
pub let mx_fractal_noise_float_impl : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_fractal_noise_float",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let octaves_immutable = inputs.get(1).unwrap()
        let lacunarity_immutable = inputs.get(2).unwrap()
        let diminish_immutable = inputs.get(3).unwrap()
        let diminish = float(diminish_immutable).to_var()
        let lacunarity = float(lacunarity_immutable).to_var()
        let octaves = int(octaves_immutable).to_var()
        let p = vec3(p_immutable).to_var()
        let result = float(0).to_var()
        let amplitude = float(1).to_var()
        loop_([octaves], fn(_) {
          result.add_assign(amplitude.mul(mx_perlin_noise_float([p])))
          amplitude.mul_assign(diminish)
          p.mul_assign(lacunarity)
        })
        Some(result)
      },
      layout=FnLayout::short(
        [
          ("p", "vec3"),
          ("octaves", "int"),
          ("lacunarity", "float"),
          ("diminish", "float"),
        ],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_fractal_noise_float",
      ),
    )
  },
)

///|
/// `mx_fractal_noise_vec3`.
pub let mx_fractal_noise_vec3_impl : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_fractal_noise_vec3",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let octaves_immutable = inputs.get(1).unwrap()
        let lacunarity_immutable = inputs.get(2).unwrap()
        let diminish_immutable = inputs.get(3).unwrap()
        let diminish = float(diminish_immutable).to_var()
        let lacunarity = float(lacunarity_immutable).to_var()
        let octaves = int(octaves_immutable).to_var()
        let p = vec3(p_immutable).to_var()
        let result = vec3(0).to_var()
        let amplitude = float(1).to_var()
        loop_([octaves], fn(_) {
          result.add_assign(amplitude.mul(mx_perlin_noise_vec3([p])))
          amplitude.mul_assign(diminish)
          p.mul_assign(lacunarity)
        })
        Some(result)
      },
      layout=FnLayout::short(
        [
          ("p", "vec3"),
          ("octaves", "int"),
          ("lacunarity", "float"),
          ("diminish", "float"),
        ],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_fractal_noise_vec3",
      ),
    )
  },
)

///|
/// `mx_fractal_noise_vec2`.
pub let mx_fractal_noise_vec2_impl : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_fractal_noise_vec2",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let octaves_immutable = inputs.get(1).unwrap()
        let lacunarity_immutable = inputs.get(2).unwrap()
        let diminish_immutable = inputs.get(3).unwrap()
        let diminish = float(diminish_immutable).to_var()
        let lacunarity = float(lacunarity_immutable).to_var()
        let octaves = int(octaves_immutable).to_var()
        let p = vec3(p_immutable).to_var()
        Some(
          vec2_of([
            mx_fractal_noise_float_impl.call([p, octaves, lacunarity, diminish]),
            mx_fractal_noise_float_impl.call([
              p.add(vec3_of([int(19), int(193), int(17)])),
              octaves,
              lacunarity,
              diminish,
            ]),
          ]),
        )
      },
      layout=FnLayout::short(
        [
          ("p", "vec3"),
          ("octaves", "int"),
          ("lacunarity", "float"),
          ("diminish", "float"),
        ],
        return_="vec2",
        upstream="nodes/materialx/MaterialXNoise.js:mx_fractal_noise_vec2",
      ),
    )
  },
)

///|
/// `mx_fractal_noise_vec4`.
pub let mx_fractal_noise_vec4_impl : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_fractal_noise_vec4",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let octaves_immutable = inputs.get(1).unwrap()
        let lacunarity_immutable = inputs.get(2).unwrap()
        let diminish_immutable = inputs.get(3).unwrap()
        let diminish = float(diminish_immutable).to_var()
        let lacunarity = float(lacunarity_immutable).to_var()
        let octaves = int(octaves_immutable).to_var()
        let p = vec3(p_immutable).to_var()
        let c = vec3(
          mx_fractal_noise_vec3_impl.call([p, octaves, lacunarity, diminish]),
        ).to_var()
        let f = float(
          mx_fractal_noise_float_impl.call([
            p.add(vec3_of([int(19), int(193), int(17)])),
            octaves,
            lacunarity,
            diminish,
          ]),
        ).to_var()
        Some(vec4_of([c, f]))
      },
      layout=FnLayout::short(
        [
          ("p", "vec3"),
          ("octaves", "int"),
          ("lacunarity", "float"),
          ("diminish", "float"),
        ],
        return_="vec4",
        upstream="nodes/materialx/MaterialXNoise.js:mx_fractal_noise_vec4",
      ),
    )
  },
)

///|
/// `mx_worley_distance_0`.
pub let mx_worley_distance_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_worley_distance_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let x_immutable = inputs.get(1).unwrap()
        let y_immutable = inputs.get(2).unwrap()
        let xoff_immutable = inputs.get(3).unwrap()
        let yoff_immutable = inputs.get(4).unwrap()
        let jitter_immutable = inputs.get(5).unwrap()
        let metric_immutable = inputs.get(6).unwrap()
        let metric = int(metric_immutable).to_var()
        let jitter = float(jitter_immutable).to_var()
        let yoff = int(yoff_immutable).to_var()
        let xoff = int(xoff_immutable).to_var()
        let y = int(y_immutable).to_var()
        let x = int(x_immutable).to_var()
        let p = vec2(p_immutable).to_var()
        let tmp = vec3(
          mx_cell_noise_vec3_impl([vec2_of([x.add(xoff), y.add(yoff)])]),
        ).to_var()
        let off = vec2_of([tmp.x(), tmp.y()]).to_var()
        off.sub_assign(0.5)
        off.mul_assign(jitter)
        off.add_assign(0.5)
        let cellpos = vec2(vec2_of([float(x), float(y)]).add(off)).to_var()
        let diff = vec2(cellpos.sub(p)).to_var()
        if_value(metric.equal(int(2)), fn() { abs(diff.x()).add(abs(diff.y())) })
        |> ignore
        if_value(metric.equal(int(3)), fn() {
          max(abs(diff.x()), abs(diff.y()))
        })
        |> ignore
        Some(dot(diff, diff))
      },
      layout=FnLayout::short(
        [
          ("p", "vec2"),
          ("x", "int"),
          ("y", "int"),
          ("xoff", "int"),
          ("yoff", "int"),
          ("jitter", "float"),
          ("metric", "int"),
        ],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_worley_distance_0",
      ),
    )
  },
)

///|
/// `mx_worley_distance_1`.
pub let mx_worley_distance_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_worley_distance_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let x_immutable = inputs.get(1).unwrap()
        let y_immutable = inputs.get(2).unwrap()
        let z_immutable = inputs.get(3).unwrap()
        let xoff_immutable = inputs.get(4).unwrap()
        let yoff_immutable = inputs.get(5).unwrap()
        let zoff_immutable = inputs.get(6).unwrap()
        let jitter_immutable = inputs.get(7).unwrap()
        let metric_immutable = inputs.get(8).unwrap()
        let metric = int(metric_immutable).to_var()
        let jitter = float(jitter_immutable).to_var()
        let zoff = int(zoff_immutable).to_var()
        let yoff = int(yoff_immutable).to_var()
        let xoff = int(xoff_immutable).to_var()
        let z = int(z_immutable).to_var()
        let y = int(y_immutable).to_var()
        let x = int(x_immutable).to_var()
        let p = vec3(p_immutable).to_var()
        let off = vec3(
          mx_cell_noise_vec3_3d.call([
            vec3_of([x.add(xoff), y.add(yoff), z.add(zoff)]),
          ]),
        ).to_var()
        off.sub_assign(0.5)
        off.mul_assign(jitter)
        off.add_assign(0.5)
        let cellpos = vec3(vec3_of([float(x), float(y), float(z)]).add(off)).to_var()
        let diff = vec3(cellpos.sub(p)).to_var()
        if_value(metric.equal(int(2)), fn() {
          abs(diff.x()).add(abs(diff.y())).add(abs(diff.z()))
        })
        |> ignore
        if_value(metric.equal(int(3)), fn() {
          max_of([abs(diff.x()), abs(diff.y()), abs(diff.z())])
        })
        |> ignore
        Some(dot(diff, diff))
      },
      layout=FnLayout::short(
        [
          ("p", "vec3"),
          ("x", "int"),
          ("y", "int"),
          ("z", "int"),
          ("xoff", "int"),
          ("yoff", "int"),
          ("zoff", "int"),
          ("jitter", "float"),
          ("metric", "int"),
        ],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_worley_distance_1",
      ),
    )
  },
)

///|
/// `mx_worley_distance`: picks the overload matching the argument types.
pub let mx_worley_distance : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_worley_distance_0, mx_worley_distance_1,
])

///|
fn mx_perlin_noise_float_scaled(
  texcoord : Node,
  amplitude? : &IntoTsl,
  pivot? : &IntoTsl,
) -> Node {
  let amplitude : &IntoTsl = match amplitude {
    Some(v) => v
    None => 1
  }
  let pivot : &IntoTsl = match pivot {
    Some(v) => v
    None => 0
  }
  mx_perlin_noise_float([texcoord]).mul(amplitude).add(pivot)
}

///|
/// `mx_worley_noise_float_3d`.
pub let mx_worley_noise_float_3d_impl : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_worley_noise_float_3d",
  fn() {
    fn_(
      fn(inputs, _) {
        let position_input = inputs.get(0).unwrap()
        let jitter_input = inputs.get(1).unwrap()
        let style_input = inputs.get(2).unwrap()
        let position = vec3(position_input).to_var()
        let jitter = float(jitter_input).to_var()
        let style = int(style_input).to_var()
        let k_x = int_of([]).to_var()
        let k_y = int_of([]).to_var()
        let k_z = int_of([]).to_var()
        let localpos = vec3_of([
          mx_floorfrac.call([position.x(), k_x]),
          mx_floorfrac.call([position.y(), k_y]),
          mx_floorfrac.call([position.z(), k_z]),
        ]).to_var()
        let sqdist = float(1000000).to_var()
        let minpos = vec3_of([0, 0, 0]).to_var()
        loop_(
          [
            TslValue::Object({
              "start": Number(-1.0),
              "end": Node(int(1)),
              "name": String("x"),
              "condition": String("<="),
            }),
          ],
          fn(inputs) {
            let x = inputs.named("x").unwrap()
            loop_(
              [
                TslValue::Object({
                  "start": Number(-1.0),
                  "end": Node(int(1)),
                  "name": String("y"),
                  "condition": String("<="),
                }),
              ],
              fn(inputs) {
                let y = inputs.named("y").unwrap()
                loop_(
                  [
                    TslValue::Object({
                      "start": Number(-1.0),
                      "end": Node(int(1)),
                      "name": String("z"),
                      "condition": String("<="),
                    }),
                  ],
                  fn(inputs) {
                    let z = inputs.named("z").unwrap()
                    let dist = float(
                      mx_worley_distance([
                        localpos,
                        x,
                        y,
                        z,
                        k_x,
                        k_y,
                        k_z,
                        jitter,
                        int(0),
                      ]),
                    ).to_var()
                    let off = vec3(
                      mx_cell_noise_vec3_3d.call([
                        vec3_of([k_x.add(x), k_y.add(y), k_z.add(z)]),
                      ]),
                    ).to_var()
                    off.sub_assign(0.5)
                    off.mul_assign(jitter)
                    off.add_assign(0.5)
                    let cellpos = vec3(
                      vec3_of([float(x), float(y), float(z)])
                      .add(off)
                      .sub(localpos),
                    ).to_var()
                    if_(dist.less_than(sqdist), fn() {
                      sqdist.assign(dist)
                      minpos.assign(cellpos)
                    })
                    |> ignore
                  },
                )
              },
            )
          },
        )
        if_(style.equal(int(1)), fn() {
          sqdist.assign(mx_cell_noise_float_impl([minpos.add(position)]))
        }).else_(fn() { sqdist.assign(sqrt(sqdist)) })
        Some(sqdist)
      },
      layout=FnLayout::short(
        [("position", "vec3"), ("jitter", "float"), ("style", "int")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_worley_noise_float_3d",
      ),
    )
  },
)

///|
/// `mx_worley_noise_float_2d`.
pub let mx_worley_noise_float_2d_impl : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_worley_noise_float_2d",
  fn() {
    fn_(
      fn(inputs, _) {
        let texcoord_input = inputs.get(0).unwrap()
        let jitter_input = inputs.get(1).unwrap()
        let style_input = inputs.get(2).unwrap()
        let texcoord = vec2(texcoord_input).to_var()
        let jitter = float(jitter_input).to_var()
        let style = int(style_input).to_var()
        let floor_pos = floor(texcoord).to_var()
        let localpos = vec2_of([fract(texcoord.x()), fract(texcoord.y())]).to_var()
        let sqdist = float(1000000).to_var()
        let minpos = vec2_of([0, 0]).to_var()
        loop_(
          [
            TslValue::Object({
              "start": Number(-1.0),
              "end": Node(int(1)),
              "name": String("x"),
              "condition": String("<="),
            }),
          ],
          fn(inputs) {
            let x = inputs.named("x").unwrap()
            loop_(
              [
                TslValue::Object({
                  "start": Number(-1.0),
                  "end": Node(int(1)),
                  "name": String("y"),
                  "condition": String("<="),
                }),
              ],
              fn(inputs) {
                let y = inputs.named("y").unwrap()
                let cell = vec2_of([float(x), float(y)]).to_var()
                let seed = vec2_of([
                  cell.x().add(floor_pos.x()),
                  cell.y().add(floor_pos.y()),
                ]).to_var()
                let off = vec2_of([
                  mx_cell_noise_float_impl([vec3_of([seed.x(), seed.y(), 0])]),
                  mx_cell_noise_float_impl([vec3_of([seed.x(), seed.y(), 1])]),
                ]).to_var()
                off.sub_assign(0.5)
                off.mul_assign(jitter)
                off.add_assign(0.5)
                let cellpos = vec2(cell.add(off).sub(localpos)).to_var()
                let dist = dot(cellpos, cellpos).to_var()
                if_(dist.less_than(sqdist), fn() {
                  sqdist.assign(dist)
                  minpos.assign(cellpos)
                })
                |> ignore
              },
            )
          },
        )
        if_(style.equal(int(1)), fn() {
          sqdist.assign(mx_cell_noise_float_impl([minpos.add(texcoord)]))
        }).else_(fn() { sqdist.assign(sqrt(sqdist)) })
        Some(sqdist)
      },
      layout=FnLayout::short(
        [("texcoord", "vec2"), ("jitter", "float"), ("style", "int")],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_worley_noise_float_2d",
      ),
    )
  },
)

///|
/// `mx_worley_noise_float`: picks the overload matching the argument types.
pub let mx_worley_noise_float_impl : (Array[&IntoTsl]) -> Node = overloading_fn([
    mx_worley_noise_float_2d_impl, mx_worley_noise_float_3d_impl,
  ],
)

///|
/// `mx_worley_noise_vec2_0`.
pub let mx_worley_noise_vec2_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_worley_noise_vec2_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let jitter_immutable = inputs.get(1).unwrap()
        let metric_immutable = inputs.get(2).unwrap()
        let metric = int(metric_immutable).to_var()
        let jitter = float(jitter_immutable).to_var()
        let p = vec2(p_immutable).to_var()
        let k_x = int_of([]).to_var()
        let k_y = int_of([]).to_var()
        let localpos = vec2_of([
          mx_floorfrac.call([p.x(), k_x]),
          mx_floorfrac.call([p.y(), k_y]),
        ]).to_var()
        let sqdist = vec2_of([1000000, 1000000]).to_var()
        loop_(
          [
            TslValue::Object({
              "start": Number(-1.0),
              "end": Node(int(1)),
              "name": String("x"),
              "condition": String("<="),
            }),
          ],
          fn(inputs) {
            let x = inputs.named("x").unwrap()
            loop_(
              [
                TslValue::Object({
                  "start": Number(-1.0),
                  "end": Node(int(1)),
                  "name": String("y"),
                  "condition": String("<="),
                }),
              ],
              fn(inputs) {
                let y = inputs.named("y").unwrap()
                let dist = float(
                  mx_worley_distance([localpos, x, y, k_x, k_y, jitter, metric]),
                ).to_var()
                if_(dist.less_than(sqdist.x()), fn() {
                  sqdist.y().assign(sqdist.x())
                  sqdist.x().assign(dist)
                }).else_if(dist.less_than(sqdist.y()), fn() {
                  sqdist.y().assign(dist)
                })
                |> ignore
              },
            )
          },
        )
        if_(metric.equal(int(0)), fn() { sqdist.assign(sqrt(sqdist)) })
        |> ignore
        Some(sqdist)
      },
      layout=FnLayout::short(
        [("p", "vec2"), ("jitter", "float"), ("metric", "int")],
        return_="vec2",
        upstream="nodes/materialx/MaterialXNoise.js:mx_worley_noise_vec2_0",
      ),
    )
  },
)

///|
/// `mx_worley_noise_vec3_0`.
pub let mx_worley_noise_vec3_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_worley_noise_vec3_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let jitter_immutable = inputs.get(1).unwrap()
        let metric_immutable = inputs.get(2).unwrap()
        let metric = int(metric_immutable).to_var()
        let jitter = float(jitter_immutable).to_var()
        let p = vec2(p_immutable).to_var()
        let k_x = int_of([]).to_var()
        let k_y = int_of([]).to_var()
        let localpos = vec2_of([
          mx_floorfrac.call([p.x(), k_x]),
          mx_floorfrac.call([p.y(), k_y]),
        ]).to_var()
        let sqdist = vec3_of([1000000, 1000000, 1000000]).to_var()
        loop_(
          [
            TslValue::Object({
              "start": Number(-1.0),
              "end": Node(int(1)),
              "name": String("x"),
              "condition": String("<="),
            }),
          ],
          fn(inputs) {
            let x = inputs.named("x").unwrap()
            loop_(
              [
                TslValue::Object({
                  "start": Number(-1.0),
                  "end": Node(int(1)),
                  "name": String("y"),
                  "condition": String("<="),
                }),
              ],
              fn(inputs) {
                let y = inputs.named("y").unwrap()
                let dist = float(
                  mx_worley_distance([localpos, x, y, k_x, k_y, jitter, metric]),
                ).to_var()
                if_(dist.less_than(sqdist.x()), fn() {
                  sqdist.z().assign(sqdist.y())
                  sqdist.y().assign(sqdist.x())
                  sqdist.x().assign(dist)
                })
                .else_if(dist.less_than(sqdist.y()), fn() {
                  sqdist.z().assign(sqdist.y())
                  sqdist.y().assign(dist)
                })
                .else_if(dist.less_than(sqdist.z()), fn() {
                  sqdist.z().assign(dist)
                })
                |> ignore
              },
            )
          },
        )
        if_(metric.equal(int(0)), fn() { sqdist.assign(sqrt(sqdist)) })
        |> ignore
        Some(sqdist)
      },
      layout=FnLayout::short(
        [("p", "vec2"), ("jitter", "float"), ("metric", "int")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_worley_noise_vec3_0",
      ),
    )
  },
)

///|
/// `mx_worley_noise_vec2_1`.
pub let mx_worley_noise_vec2_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_worley_noise_vec2_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let jitter_immutable = inputs.get(1).unwrap()
        let metric_immutable = inputs.get(2).unwrap()
        let metric = int(metric_immutable).to_var()
        let jitter = float(jitter_immutable).to_var()
        let p = vec3(p_immutable).to_var()
        let k_x = int_of([]).to_var()
        let k_y = int_of([]).to_var()
        let k_z = int_of([]).to_var()
        let localpos = vec3_of([
          mx_floorfrac.call([p.x(), k_x]),
          mx_floorfrac.call([p.y(), k_y]),
          mx_floorfrac.call([p.z(), k_z]),
        ]).to_var()
        let sqdist = vec2_of([1000000, 1000000]).to_var()
        loop_(
          [
            TslValue::Object({
              "start": Number(-1.0),
              "end": Node(int(1)),
              "name": String("x"),
              "condition": String("<="),
            }),
          ],
          fn(inputs) {
            let x = inputs.named("x").unwrap()
            loop_(
              [
                TslValue::Object({
                  "start": Number(-1.0),
                  "end": Node(int(1)),
                  "name": String("y"),
                  "condition": String("<="),
                }),
              ],
              fn(inputs) {
                let y = inputs.named("y").unwrap()
                loop_(
                  [
                    TslValue::Object({
                      "start": Number(-1.0),
                      "end": Node(int(1)),
                      "name": String("z"),
                      "condition": String("<="),
                    }),
                  ],
                  fn(inputs) {
                    let z = inputs.named("z").unwrap()
                    let dist = float(
                      mx_worley_distance([
                        localpos, x, y, z, k_x, k_y, k_z, jitter, metric,
                      ]),
                    ).to_var()
                    if_(dist.less_than(sqdist.x()), fn() {
                      sqdist.y().assign(sqdist.x())
                      sqdist.x().assign(dist)
                    }).else_if(dist.less_than(sqdist.y()), fn() {
                      sqdist.y().assign(dist)
                    })
                    |> ignore
                  },
                )
              },
            )
          },
        )
        if_(metric.equal(int(0)), fn() { sqdist.assign(sqrt(sqdist)) })
        |> ignore
        Some(sqdist)
      },
      layout=FnLayout::short(
        [("p", "vec3"), ("jitter", "float"), ("metric", "int")],
        return_="vec2",
        upstream="nodes/materialx/MaterialXNoise.js:mx_worley_noise_vec2_1",
      ),
    )
  },
)

///|
/// `mx_worley_noise_vec2`: picks the overload matching the argument types.
pub let mx_worley_noise_vec2_impl : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_worley_noise_vec2_0, mx_worley_noise_vec2_1,
])

///|
/// `mx_worley_noise_vec3_1`.
pub let mx_worley_noise_vec3_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_worley_noise_vec3_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let jitter_immutable = inputs.get(1).unwrap()
        let metric_immutable = inputs.get(2).unwrap()
        let metric = int(metric_immutable).to_var()
        let jitter = float(jitter_immutable).to_var()
        let p = vec3(p_immutable).to_var()
        let k_x = int_of([]).to_var()
        let k_y = int_of([]).to_var()
        let k_z = int_of([]).to_var()
        let localpos = vec3_of([
          mx_floorfrac.call([p.x(), k_x]),
          mx_floorfrac.call([p.y(), k_y]),
          mx_floorfrac.call([p.z(), k_z]),
        ]).to_var()
        let sqdist = vec3_of([1000000, 1000000, 1000000]).to_var()
        loop_(
          [
            TslValue::Object({
              "start": Number(-1.0),
              "end": Node(int(1)),
              "name": String("x"),
              "condition": String("<="),
            }),
          ],
          fn(inputs) {
            let x = inputs.named("x").unwrap()
            loop_(
              [
                TslValue::Object({
                  "start": Number(-1.0),
                  "end": Node(int(1)),
                  "name": String("y"),
                  "condition": String("<="),
                }),
              ],
              fn(inputs) {
                let y = inputs.named("y").unwrap()
                loop_(
                  [
                    TslValue::Object({
                      "start": Number(-1.0),
                      "end": Node(int(1)),
                      "name": String("z"),
                      "condition": String("<="),
                    }),
                  ],
                  fn(inputs) {
                    let z = inputs.named("z").unwrap()
                    let dist = float(
                      mx_worley_distance([
                        localpos, x, y, z, k_x, k_y, k_z, jitter, metric,
                      ]),
                    ).to_var()
                    if_(dist.less_than(sqdist.x()), fn() {
                      sqdist.z().assign(sqdist.y())
                      sqdist.y().assign(sqdist.x())
                      sqdist.x().assign(dist)
                    })
                    .else_if(dist.less_than(sqdist.y()), fn() {
                      sqdist.z().assign(sqdist.y())
                      sqdist.y().assign(dist)
                    })
                    .else_if(dist.less_than(sqdist.z()), fn() {
                      sqdist.z().assign(dist)
                    })
                    |> ignore
                  },
                )
              },
            )
          },
        )
        if_(metric.equal(int(0)), fn() { sqdist.assign(sqrt(sqdist)) })
        |> ignore
        Some(sqdist)
      },
      layout=FnLayout::short(
        [("p", "vec3"), ("jitter", "float"), ("metric", "int")],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_worley_noise_vec3_1",
      ),
    )
  },
)

///|
/// `mx_worley_noise_vec3`: picks the overload matching the argument types.
pub let mx_worley_noise_vec3_impl : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_worley_noise_vec3_0, mx_worley_noise_vec3_1,
])

///|
/// `mx_worley_noise_vec3_style_0`.
pub let mx_worley_noise_vec3_style_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_worley_noise_vec3_style_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let jitter_immutable = inputs.get(1).unwrap()
        let style_immutable = inputs.get(2).unwrap()
        let metric_immutable = inputs.get(3).unwrap()
        let metric = int(metric_immutable).to_var()
        let style = int(style_immutable).to_var()
        let jitter = float(jitter_immutable).to_var()
        let p = vec2(p_immutable).to_var()
        let k_x = int_of([]).to_var()
        let k_y = int_of([]).to_var()
        let localpos = vec2_of([
          mx_floorfrac.call([p.x(), k_x]),
          mx_floorfrac.call([p.y(), k_y]),
        ]).to_var()
        let sqdist = float(1000000).to_var()
        let minpos = vec2_of([0, 0]).to_var()
        loop_(
          [
            TslValue::Object({
              "start": Number(-1.0),
              "end": Node(int(1)),
              "name": String("x"),
              "condition": String("<="),
            }),
          ],
          fn(inputs) {
            let x = inputs.named("x").unwrap()
            loop_(
              [
                TslValue::Object({
                  "start": Number(-1.0),
                  "end": Node(int(1)),
                  "name": String("y"),
                  "condition": String("<="),
                }),
              ],
              fn(inputs) {
                let y = inputs.named("y").unwrap()
                let dist = float(
                  mx_worley_distance([localpos, x, y, k_x, k_y, jitter, metric]),
                ).to_var()
                let tmp = vec3(
                  mx_cell_noise_vec3_impl([vec2_of([k_x.add(x), k_y.add(y)])]),
                ).to_var()
                let off = vec2_of([tmp.x(), tmp.y()]).to_var()
                off.sub_assign(0.5)
                off.mul_assign(jitter)
                off.add_assign(0.5)
                let cellpos = vec2(
                  vec2_of([float(x), float(y)]).add(off).sub(localpos),
                ).to_var()
                if_(dist.less_than(sqdist), fn() {
                  sqdist.assign(dist)
                  minpos.assign(cellpos)
                })
                |> ignore
              },
            )
          },
        )
        let result = vec3(mx_worley_noise_vec3_impl([p, jitter, metric])).to_var()
        if_(style.equal(int(1)), fn() {
          result.assign(mx_cell_noise_vec3_impl([minpos.add(p)]))
        })
        |> ignore
        Some(result)
      },
      layout=FnLayout::short(
        [
          ("p", "vec2"),
          ("jitter", "float"),
          ("style", "int"),
          ("metric", "int"),
        ],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_worley_noise_vec3_style_0",
      ),
    )
  },
)

///|
/// `mx_worley_noise_vec3_style_1`.
pub let mx_worley_noise_vec3_style_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_worley_noise_vec3_style_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let p_immutable = inputs.get(0).unwrap()
        let jitter_immutable = inputs.get(1).unwrap()
        let style_immutable = inputs.get(2).unwrap()
        let metric_immutable = inputs.get(3).unwrap()
        let metric = int(metric_immutable).to_var()
        let style = int(style_immutable).to_var()
        let jitter = float(jitter_immutable).to_var()
        let p = vec3(p_immutable).to_var()
        let k_x = int_of([]).to_var()
        let k_y = int_of([]).to_var()
        let k_z = int_of([]).to_var()
        let localpos = vec3_of([
          mx_floorfrac.call([p.x(), k_x]),
          mx_floorfrac.call([p.y(), k_y]),
          mx_floorfrac.call([p.z(), k_z]),
        ]).to_var()
        let sqdist = float(1000000).to_var()
        let minpos = vec3_of([0, 0, 0]).to_var()
        loop_(
          [
            TslValue::Object({
              "start": Number(-1.0),
              "end": Node(int(1)),
              "name": String("x"),
              "condition": String("<="),
            }),
          ],
          fn(inputs) {
            let x = inputs.named("x").unwrap()
            loop_(
              [
                TslValue::Object({
                  "start": Number(-1.0),
                  "end": Node(int(1)),
                  "name": String("y"),
                  "condition": String("<="),
                }),
              ],
              fn(inputs) {
                let y = inputs.named("y").unwrap()
                loop_(
                  [
                    TslValue::Object({
                      "start": Number(-1.0),
                      "end": Node(int(1)),
                      "name": String("z"),
                      "condition": String("<="),
                    }),
                  ],
                  fn(inputs) {
                    let z = inputs.named("z").unwrap()
                    let dist = float(
                      mx_worley_distance([
                        localpos, x, y, z, k_x, k_y, k_z, jitter, metric,
                      ]),
                    ).to_var()
                    let off = vec3(
                      mx_cell_noise_vec3_3d.call([
                        vec3_of([k_x.add(x), k_y.add(y), k_z.add(z)]),
                      ]),
                    ).to_var()
                    off.sub_assign(0.5)
                    off.mul_assign(jitter)
                    off.add_assign(0.5)
                    let cellpos = vec3(
                      vec3_of([float(x), float(y), float(z)])
                      .add(off)
                      .sub(localpos),
                    ).to_var()
                    if_(dist.less_than(sqdist), fn() {
                      sqdist.assign(dist)
                      minpos.assign(cellpos)
                    })
                    |> ignore
                  },
                )
              },
            )
          },
        )
        let result = vec3(mx_worley_noise_vec3_impl([p, jitter, metric])).to_var()
        if_(style.equal(int(1)), fn() {
          result.assign(mx_cell_noise_vec3_3d.call([minpos.add(p)]))
        })
        |> ignore
        Some(result)
      },
      layout=FnLayout::short(
        [
          ("p", "vec3"),
          ("jitter", "float"),
          ("style", "int"),
          ("metric", "int"),
        ],
        return_="vec3",
        upstream="nodes/materialx/MaterialXNoise.js:mx_worley_noise_vec3_style_1",
      ),
    )
  },
)

///|
/// `mx_worley_noise_vec3_style`: picks the overload matching the argument types.
pub let mx_worley_noise_vec3_style_impl : (Array[&IntoTsl]) -> Node = overloading_fn([
    mx_worley_noise_vec3_style_0, mx_worley_noise_vec3_style_1,
  ],
)

///|
/// `mx_unifiednoise2d`.
pub let mx_unifiednoise2d_impl : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_unifiednoise2d",
  fn() {
    fn_(
      fn(inputs, _) {
        let noise_type_input = inputs.get(0).unwrap()
        let texcoord_input = inputs.get(1).unwrap()
        let freq_input = inputs.get(2).unwrap()
        let offset_input = inputs.get(3).unwrap()
        let jitter_input = inputs.get(4).unwrap()
        let outmin_input = inputs.get(5).unwrap()
        let outmax_input = inputs.get(6).unwrap()
        let clampoutput_input = inputs.get(7).unwrap()
        let octaves_input = inputs.get(8).unwrap()
        let lacunarity_input = inputs.get(9).unwrap()
        let diminish_input = inputs.get(10).unwrap()
        let style_input = inputs.get(11).unwrap()
        let noise_type = int(noise_type_input).to_var()
        let texcoord = vec2(texcoord_input).to_var()
        let freq = vec2(freq_input).to_var()
        let offset = vec2(offset_input).to_var()
        let jitter = float(jitter_input).to_var()
        let outmin = float(outmin_input).to_var()
        let outmax = float(outmax_input).to_var()
        let clampoutput = float(clampoutput_input).to_var()
        let octaves = int(octaves_input).to_var()
        let lacunarity = float(lacunarity_input).to_var()
        let diminish = float(diminish_input).to_var()
        let style = int(style_input).to_var()
        let apply_freq = mul(texcoord, freq).to_var()
        let apply_offset = add(apply_freq, offset).to_var()
        let cell_jitter_mult = mul(sub(jitter, 1), 90000).to_var()
        let apply_cell_jitter = mx_rotate2d(
          apply_offset,
          amount=cell_jitter_mult,
        ).to_var()
        let fractal_input = vec3_of([
          apply_offset.x(),
          apply_offset.y(),
          cell_jitter_mult,
        ]).to_var()
        let result = float(0).to_var()
        if_(noise_type.equal(int(0)), fn() {
          result.assign(
            mx_perlin_noise_float_scaled(
              apply_cell_jitter,
              amplitude=0.5,
              pivot=0.5,
            ),
          )
        })
        |> ignore
        if_(noise_type.equal(int(1)), fn() {
          result.assign(mx_cell_noise_float_impl([apply_cell_jitter]))
        })
        |> ignore
        if_(noise_type.equal(int(2)), fn() {
          result.assign(
            mx_worley_noise_float_2d_impl.call([apply_offset, jitter, style]),
          )
        })
        |> ignore
        if_(noise_type.equal(int(3)), fn() {
          result.assign(
            mx_fractal_noise_float_impl.call([
              fractal_input, octaves, lacunarity, diminish,
            ]),
          )
        })
        |> ignore
        let ranged = add(outmin, mul(result, sub(outmax, outmin))).to_var()
        let clamped = clamp(ranged, low=outmin, high=outmax).to_var()
        let output = ranged.to_var()
        if_(clampoutput.equal(float(1)), fn() { output.assign(clamped) })
        |> ignore
        Some(output)
      },
      layout=FnLayout::short(
        [
          ("noiseType", "int"),
          ("texcoord", "vec2"),
          ("freq", "vec2"),
          ("offset", "vec2"),
          ("jitter", "float"),
          ("outmin", "float"),
          ("outmax", "float"),
          ("clampoutput", "float"),
          ("octaves", "int"),
          ("lacunarity", "float"),
          ("diminish", "float"),
          ("style", "int"),
        ],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_unifiednoise2d",
      ),
    )
  },
)

///|
/// `mx_unifiednoise3d`.
pub let mx_unifiednoise3d_impl : Node = module_nodes(
  "nodes/materialx/MaterialXNoise.js:mx_unifiednoise3d",
  fn() {
    fn_(
      fn(inputs, _) {
        let noise_type_input = inputs.get(0).unwrap()
        let position_input = inputs.get(1).unwrap()
        let freq_input = inputs.get(2).unwrap()
        let offset_input = inputs.get(3).unwrap()
        let jitter_input = inputs.get(4).unwrap()
        let outmin_input = inputs.get(5).unwrap()
        let outmax_input = inputs.get(6).unwrap()
        let clampoutput_input = inputs.get(7).unwrap()
        let octaves_input = inputs.get(8).unwrap()
        let lacunarity_input = inputs.get(9).unwrap()
        let diminish_input = inputs.get(10).unwrap()
        let style_input = inputs.get(11).unwrap()
        let noise_type = int(noise_type_input).to_var()
        let position = vec3(position_input).to_var()
        let freq = vec3(freq_input).to_var()
        let offset = vec3(offset_input).to_var()
        let jitter = float(jitter_input).to_var()
        let outmin = float(outmin_input).to_var()
        let outmax = float(outmax_input).to_var()
        let clampoutput = float(clampoutput_input).to_var()
        let octaves = int(octaves_input).to_var()
        let lacunarity = float(lacunarity_input).to_var()
        let diminish = float(diminish_input).to_var()
        let style = int(style_input).to_var()
        let apply_freq = mul(position, freq).to_var()
        let apply_offset = add(apply_freq, offset).to_var()
        let cell_jitter_mult = mul(sub(jitter, 1), 90000).to_var()
        let apply_cell_jitter = mx_rotate3d(
          apply_offset,
          amount=cell_jitter_mult,
          axis=vec3_of([0.1, 1, 0]),
        ).to_var()
        let perlin = mx_perlin_noise_float_scaled(
          apply_cell_jitter,
          amplitude=0.5,
          pivot=0.5,
        )
        let cell = mx_cell_noise_float_impl([apply_cell_jitter])
        let worley = mx_worley_noise_float_3d_impl.call([
          apply_offset, jitter, style,
        ])
        let fractal = mx_fractal_noise_float_impl.call([
          apply_cell_jitter, octaves, lacunarity, diminish,
        ])
        let result = perlin.to_var()
        if_(noise_type.equal(int(1)), fn() { result.assign(cell) }) |> ignore
        if_(noise_type.equal(int(2)), fn() { result.assign(worley) }) |> ignore
        if_(noise_type.equal(int(3)), fn() { result.assign(fractal) }) |> ignore
        let ranged = add(outmin, mul(result, sub(outmax, outmin))).to_var()
        let clamped = clamp(ranged, low=outmin, high=outmax).to_var()
        let output = ranged.to_var()
        if_(clampoutput.equal(float(1)), fn() { output.assign(clamped) })
        |> ignore
        Some(output)
      },
      layout=FnLayout::short(
        [
          ("noiseType", "int"),
          ("position", "vec3"),
          ("freq", "vec3"),
          ("offset", "vec3"),
          ("jitter", "float"),
          ("outmin", "float"),
          ("outmax", "float"),
          ("clampoutput", "float"),
          ("octaves", "int"),
          ("lacunarity", "float"),
          ("diminish", "float"),
          ("style", "int"),
        ],
        return_="float",
        upstream="nodes/materialx/MaterialXNoise.js:mx_unifiednoise3d",
      ),
    )
  },
)
