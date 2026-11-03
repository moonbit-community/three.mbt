// SimplexNoise against upstream: with SIMPLEX_DIFF=1 this prints the same lines as
// diff/addons/tsl/a5/simplex/upstream.mjs (seeded mulberry32, fixed point sets, values as
// IEEE bits), which compare.sh diffs; the asserted values below come from upstream.

///|
extern "js" fn simplex_test_mulberry32(seed : Int32) -> () -> Double =
  #|(a) => () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul( a ^ a >>> 15, 1 | a ); t = t + Math.imul( t ^ t >>> 7, 61 | t ) ^ t; return ( ( t ^ t >>> 14 ) >>> 0 ) / 4294967296; }

///|
extern "js" fn simplex_test_bits(x : Double) -> String =
  #|(x) => { const f = new Float64Array( [ x ] ); return new BigUint64Array( f.buffer )[ 0 ].toString( 16 ); }

///|
extern "js" fn simplex_test_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.SIMPLEX_DIFF === '1'"

///|
fn simplex_test_coord(g : () -> Double, i : Int32) -> Double {
  let r = g()
  match i % 5 {
    0 => (r - 0.5) * 100.0
    1 => ((r - 0.5) * 40.0).floor()
    2 => (r - 0.5) * 4.0e9
    3 => r * 3.0
    _ => (r - 0.5) * 1.0e-3
  }
}

///|
fn simplex_test_lines() -> Array[String] {
  let out = []
  let bits = simplex_test_bits
  for seed in [1, 12345] {
    let s = @addon_math.SimplexNoise::new(random=simplex_test_mulberry32(seed))
    let perm : Array[Int32] = s.perm
    out.push("perm \{seed} " + perm.map(fn(v) { v.to_string() }).join(","))
    let g = simplex_test_mulberry32(seed * 7 + 3)
    let c = fn(i) { simplex_test_coord(g, i) }
    for i in 0..<2000 {
      let x = c(i)
      let y = c(i + 1)
      out.push("n2 \{seed} \{i} \{bits(s.noise(x, y))}")
    }
    for i in 0..<2000 {
      let x = c(i)
      let y = c(i + 2)
      let z = c(i + 4)
      out.push("n3 \{seed} \{i} \{bits(s.noise3d(x, y, z))}")
    }
    for i in 0..<2000 {
      let x = c(i)
      let y = c(i + 1)
      let z = c(i + 3)
      let w = c(i + 2)
      out.push("n4 \{seed} \{i} \{bits(s.noise4d(x, y, z, w))}")
    }
    // specials
    let inf = 1.0 / 0.0
    let sp = [
      0.0,
      -0.0,
      1.0,
      -1.0,
      0.5,
      255.5,
      256.0,
      -256.25,
      2147483648.5,
      -2147483649.5,
      1.0e300,
      0.0 / 0.0,
      inf,
      -inf,
    ]
    for a in sp {
      for b in sp {
        out.push(
          "s2 \{seed} \{bits(a)} \{bits(b)} \{bits(s.noise(a, b))} \{bits(s.noise3d(a, b, a))} \{bits(s.noise4d(a, b, b, a))}",
        )
      }
    }
  }
  out
}

///|
test "SimplexNoise matches upstream (seeded)" {
  let lines = simplex_test_lines()
  if simplex_test_enabled() {
    for l in lines {
      println("@@SIMPLEX " + l)
    }
  }
  assert_eq(lines.length(), 12394)
  // values printed by upstream.mjs
  assert_eq(lines[1], "n2 1 0 bfdb901bcd914ff0")
  assert_eq(lines[2], "n2 1 1 3fc5cd4065265a3d")
  assert_eq(lines[2002], "n3 1 1 3fd392d8b9cf2dba")
  assert_eq(lines[4002], "n4 1 1 bfe075b8cef074e6")
  assert_eq(lines[12197], "n4 12345 1999 3fd1ee4a3eed08ca")
  let s = @addon_math.SimplexNoise::new(random=simplex_test_mulberry32(1))
  assert_eq(s.perm.length(), 512)
  assert_eq(s.perm[0], 160)
  assert_eq(s.perm[256], 160)
  assert_eq(s.noise(0.0, 0.0), 0.0)
}
