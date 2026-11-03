// examples/jsm/math/SimplexNoise.js

///|
extern "js" fn simplex_noise_math_random() -> Double = "Math.random"

///|
/// JS `x & 255` (ToInt32 wraps; NaN and the infinities give 0).
extern "js" fn simplex_noise_and255(x : Double) -> Int32 = "(x) => x & 255"

///|
/// Simplex noise in 2, 3 and 4 dimensions (Stefan Gustavson's "Simplex noise demystified").
pub struct SimplexNoise {
  grad3 : Array[Array[Double]]
  grad4 : Array[Array[Double]]
  p : Array[Int32]
  perm : Array[Int32]
  simplex : Array[Array[Int32]]
}

///|
/// `new SimplexNoise( r = Math )`: `random` replaces `r.random()` (default `Math.random`).
pub fn SimplexNoise::new(random? : () -> Double) -> SimplexNoise {
  let random = match random {
    Some(f) => f
    None => simplex_noise_math_random
  }
  let grad3 : Array[Array[Double]] = [
    [1, 1, 0],
    [-1, 1, 0],
    [1, -1, 0],
    [-1, -1, 0],
    [1, 0, 1],
    [-1, 0, 1],
    [1, 0, -1],
    [-1, 0, -1],
    [0, 1, 1],
    [0, -1, 1],
    [0, 1, -1],
    [0, -1, -1],
  ]
  let grad4 : Array[Array[Double]] = [
    [0, 1, 1, 1],
    [0, 1, 1, -1],
    [0, 1, -1, 1],
    [0, 1, -1, -1],
    [0, -1, 1, 1],
    [0, -1, 1, -1],
    [0, -1, -1, 1],
    [0, -1, -1, -1],
    [1, 0, 1, 1],
    [1, 0, 1, -1],
    [1, 0, -1, 1],
    [1, 0, -1, -1],
    [-1, 0, 1, 1],
    [-1, 0, 1, -1],
    [-1, 0, -1, 1],
    [-1, 0, -1, -1],
    [1, 1, 0, 1],
    [1, 1, 0, -1],
    [1, -1, 0, 1],
    [1, -1, 0, -1],
    [-1, 1, 0, 1],
    [-1, 1, 0, -1],
    [-1, -1, 0, 1],
    [-1, -1, 0, -1],
    [1, 1, 1, 0],
    [1, 1, -1, 0],
    [1, -1, 1, 0],
    [1, -1, -1, 0],
    [-1, 1, 1, 0],
    [-1, 1, -1, 0],
    [-1, -1, 1, 0],
    [-1, -1, -1, 0],
  ]
  let p = []
  for _ in 0..<256 {
    p.push((random() * 256.0).floor().to_int())
  }
  // To remove the need for index wrapping, double the permutation table length
  let perm = []
  for i in 0..<512 {
    perm.push(p[i & 255])
  }
  // A lookup table to traverse the simplex around a given point in 4D.
  // Details can be found where this table is used, in the 4D noise method.
  let simplex = [
    [0, 1, 2, 3],
    [0, 1, 3, 2],
    [0, 0, 0, 0],
    [0, 2, 3, 1],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [1, 2, 3, 0],
    [0, 2, 1, 3],
    [0, 0, 0, 0],
    [0, 3, 1, 2],
    [0, 3, 2, 1],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [1, 3, 2, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [1, 2, 0, 3],
    [0, 0, 0, 0],
    [1, 3, 0, 2],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [2, 3, 0, 1],
    [2, 3, 1, 0],
    [1, 0, 2, 3],
    [1, 0, 3, 2],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [2, 0, 3, 1],
    [0, 0, 0, 0],
    [2, 1, 3, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [2, 0, 1, 3],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [3, 0, 1, 2],
    [3, 0, 2, 1],
    [0, 0, 0, 0],
    [3, 1, 2, 0],
    [2, 1, 0, 3],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [3, 1, 0, 2],
    [0, 0, 0, 0],
    [3, 2, 0, 1],
    [3, 2, 1, 0],
  ]
  { grad3, grad4, p, perm, simplex, }
}

///|
/// A 2D simplex noise value in [-1, 1].
pub fn SimplexNoise::noise(
  self : SimplexNoise,
  xin : Double,
  yin : Double,
) -> Double {
  // Noise contributions from the three corners
  // Skew the input space to determine which simplex cell we're in
  let f2 = 0.5 * ((3.0 : Double).sqrt() - 1.0)
  let s = (xin + yin) * f2 // Hairy factor for 2D
  let i = (xin + s).floor()
  let j = (yin + s).floor()
  let g2 = (3.0 - (3.0 : Double).sqrt()) / 6.0
  let t = (i + j) * g2
  let x0_ = i - t // Unskew the cell origin back to (x,y) space
  let y0_ = j - t
  let x0 = xin - x0_ // The x,y distances from the cell origin
  let y0 = yin - y0_
  // For the 2D case, the simplex shape is an equilateral triangle.
  // Determine which simplex we are in.
  // Offsets for second (middle) corner of simplex in (i,j) coords
  let (i1, j1) = if x0 > y0 {
    // lower triangle, XY order: (0,0)->(1,0)->(1,1)
    (1, 0)
  } else {
    // upper triangle, YX order: (0,0)->(0,1)->(1,1)
    (0, 1)
  }
  // A step of (1,0) in (i,j) means a step of (1-c,-c) in (x,y), and
  // a step of (0,1) in (i,j) means a step of (-c,1-c) in (x,y), where
  // c = (3-sqrt(3))/6
  let x1 = x0 - i1.to_double() + g2 // Offsets for middle corner in (x,y) unskewed coords
  let y1 = y0 - j1.to_double() + g2
  let x2 = x0 - 1.0 + 2.0 * g2 // Offsets for last corner in (x,y) unskewed coords
  let y2 = y0 - 1.0 + 2.0 * g2
  // Work out the hashed gradient indices of the three simplex corners
  let ii = simplex_noise_and255(i)
  let jj = simplex_noise_and255(j)
  let perm = self.perm
  let gi0 = perm[ii + perm[jj]] % 12
  let gi1 = perm[ii + i1 + perm[jj + j1]] % 12
  let gi2 = perm[ii + 1 + perm[jj + 1]] % 12
  // Calculate the contribution from the three corners
  let mut t0 = 0.5 - x0 * x0 - y0 * y0
  let n0 = if t0 < 0.0 {
    0.0
  } else {
    t0 *= t0
    t0 * t0 * simplex_noise_dot(self.grad3[gi0], x0, y0) // (x,y) of grad3 used for 2D gradient
  }
  let mut t1 = 0.5 - x1 * x1 - y1 * y1
  let n1 = if t1 < 0.0 {
    0.0
  } else {
    t1 *= t1
    t1 * t1 * simplex_noise_dot(self.grad3[gi1], x1, y1)
  }
  let mut t2 = 0.5 - x2 * x2 - y2 * y2
  let n2 = if t2 < 0.0 {
    0.0
  } else {
    t2 *= t2
    t2 * t2 * simplex_noise_dot(self.grad3[gi2], x2, y2)
  }
  // Add contributions from each corner to get the final noise value.
  // The result is scaled to return values in the interval [-1,1].
  70.0 * (n0 + n1 + n2)
}

///|
/// A 3D simplex noise value (just inside [-1, 1]).
pub fn SimplexNoise::noise3d(
  self : SimplexNoise,
  xin : Double,
  yin : Double,
  zin : Double,
) -> Double {
  // Noise contributions from the four corners
  // Skew the input space to determine which simplex cell we're in
  let f3 = 1.0 / 3.0
  let s = (xin + yin + zin) * f3 // Very nice and simple skew factor for 3D
  let i = (xin + s).floor()
  let j = (yin + s).floor()
  let k = (zin + s).floor()
  let g3 = 1.0 / 6.0 // Very nice and simple unskew factor, too
  let t = (i + j + k) * g3
  let x0_ = i - t // Unskew the cell origin back to (x,y,z) space
  let y0_ = j - t
  let z0_ = k - t
  let x0 = xin - x0_ // The x,y,z distances from the cell origin
  let y0 = yin - y0_
  let z0 = zin - z0_
  // For the 3D case, the simplex shape is a slightly irregular tetrahedron.
  // Determine which simplex we are in.
  // Offsets for second corner of simplex in (i,j,k) coords
  // Offsets for third corner of simplex in (i,j,k) coords
  let (i1, j1, k1, i2, j2, k2) = if x0 >= y0 {
    if y0 >= z0 {
      // X Y Z order
      (1, 0, 0, 1, 1, 0)
    } else if x0 >= z0 {
      // X Z Y order
      (1, 0, 0, 1, 0, 1)
    } else {
      // Z X Y order
      (0, 0, 1, 1, 0, 1)
    } // x0<y0
  } else if y0 < z0 {
    // Z Y X order
    (0, 0, 1, 0, 1, 1)
  } else if x0 < z0 {
    // Y Z X order
    (0, 1, 0, 0, 1, 1)
  } else {
    // Y X Z order
    (0, 1, 0, 1, 1, 0)
  }
  // A step of (1,0,0) in (i,j,k) means a step of (1-c,-c,-c) in (x,y,z),
  // a step of (0,1,0) in (i,j,k) means a step of (-c,1-c,-c) in (x,y,z), and
  // a step of (0,0,1) in (i,j,k) means a step of (-c,-c,1-c) in (x,y,z), where
  // c = 1/6.
  let x1 = x0 - i1.to_double() + g3 // Offsets for second corner in (x,y,z) coords
  let y1 = y0 - j1.to_double() + g3
  let z1 = z0 - k1.to_double() + g3
  let x2 = x0 - i2.to_double() + 2.0 * g3 // Offsets for third corner in (x,y,z) coords
  let y2 = y0 - j2.to_double() + 2.0 * g3
  let z2 = z0 - k2.to_double() + 2.0 * g3
  let x3 = x0 - 1.0 + 3.0 * g3 // Offsets for last corner in (x,y,z) coords
  let y3 = y0 - 1.0 + 3.0 * g3
  let z3 = z0 - 1.0 + 3.0 * g3
  // Work out the hashed gradient indices of the four simplex corners
  let ii = simplex_noise_and255(i)
  let jj = simplex_noise_and255(j)
  let kk = simplex_noise_and255(k)
  let perm = self.perm
  let gi0 = perm[ii + perm[jj + perm[kk]]] % 12
  let gi1 = perm[ii + i1 + perm[jj + j1 + perm[kk + k1]]] % 12
  let gi2 = perm[ii + i2 + perm[jj + j2 + perm[kk + k2]]] % 12
  let gi3 = perm[ii + 1 + perm[jj + 1 + perm[kk + 1]]] % 12
  // Calculate the contribution from the four corners
  let mut t0 = 0.6 - x0 * x0 - y0 * y0 - z0 * z0
  let n0 = if t0 < 0.0 {
    0.0
  } else {
    t0 *= t0
    t0 * t0 * simplex_noise_dot3(self.grad3[gi0], x0, y0, z0)
  }
  let mut t1 = 0.6 - x1 * x1 - y1 * y1 - z1 * z1
  let n1 = if t1 < 0.0 {
    0.0
  } else {
    t1 *= t1
    t1 * t1 * simplex_noise_dot3(self.grad3[gi1], x1, y1, z1)
  }
  let mut t2 = 0.6 - x2 * x2 - y2 * y2 - z2 * z2
  let n2 = if t2 < 0.0 {
    0.0
  } else {
    t2 *= t2
    t2 * t2 * simplex_noise_dot3(self.grad3[gi2], x2, y2, z2)
  }
  let mut t3 = 0.6 - x3 * x3 - y3 * y3 - z3 * z3
  let n3 = if t3 < 0.0 {
    0.0
  } else {
    t3 *= t3
    t3 * t3 * simplex_noise_dot3(self.grad3[gi3], x3, y3, z3)
  }
  // Add contributions from each corner to get the final noise value.
  // The result is scaled to stay just inside [-1,1]
  32.0 * (n0 + n1 + n2 + n3)
}

///|
/// A 4D simplex noise value in [-1, 1].
pub fn SimplexNoise::noise4d(
  self : SimplexNoise,
  x : Double,
  y : Double,
  z : Double,
  w : Double,
) -> Double {
  // For faster and easier lookups
  let grad4 = self.grad4
  let simplex = self.simplex
  let perm = self.perm
  // The skewing and unskewing factors are hairy again for the 4D case
  let f4 = ((5.0 : Double).sqrt() - 1.0) / 4.0
  let g4 = (5.0 - (5.0 : Double).sqrt()) / 20.0
  // Noise contributions from the five corners
  // Skew the (x,y,z,w) space to determine which cell of 24 simplices we're in
  let s = (x + y + z + w) * f4 // Factor for 4D skewing
  let i = (x + s).floor()
  let j = (y + s).floor()
  let k = (z + s).floor()
  let l = (w + s).floor()
  let t = (i + j + k + l) * g4 // Factor for 4D unskewing
  let x0_ = i - t // Unskew the cell origin back to (x,y,z,w) space
  let y0_ = j - t
  let z0_ = k - t
  let w0_ = l - t
  let x0 = x - x0_ // The x,y,z,w distances from the cell origin
  let y0 = y - y0_
  let z0 = z - z0_
  let w0 = w - w0_
  // For the 4D case, the simplex is a 4D shape I won't even try to describe.
  // To find out which of the 24 possible simplices we're in, we need to
  // determine the magnitude ordering of x0, y0, z0 and w0.
  // The method below is a good way of finding the ordering of x,y,z,w and
  // then find the correct traversal order for the simplex we’re in.
  // First, six pair-wise comparisons are performed between each possible pair
  // of the four coordinates, and the results are used to add up binary bits
  // for an integer index.
  let c1 = if x0 > y0 { 32 } else { 0 }
  let c2 = if x0 > z0 { 16 } else { 0 }
  let c3 = if y0 > z0 { 8 } else { 0 }
  let c4 = if x0 > w0 { 4 } else { 0 }
  let c5 = if y0 > w0 { 2 } else { 0 }
  let c6 = if z0 > w0 { 1 } else { 0 }
  let c = c1 + c2 + c3 + c4 + c5 + c6
  // simplex[c] is a 4-vector with the numbers 0, 1, 2 and 3 in some order.
  // Many values of c will never occur, since e.g. x>y>z>w makes x<z, y<w and x<w
  // impossible. Only the 24 indices which have non-zero entries make any sense.
  // We use a thresholding to set the coordinates in turn from the largest magnitude.
  // The number 3 in the "simplex" array is at the position of the largest coordinate.
  let i1 = if simplex[c][0] >= 3 { 1 } else { 0 }
  let j1 = if simplex[c][1] >= 3 { 1 } else { 0 }
  let k1 = if simplex[c][2] >= 3 { 1 } else { 0 }
  let l1 = if simplex[c][3] >= 3 { 1 } else { 0 }
  // The number 2 in the "simplex" array is at the second largest coordinate.
  let i2 = if simplex[c][0] >= 2 { 1 } else { 0 }
  let j2 = if simplex[c][1] >= 2 { 1 } else { 0 }
  let k2 = if simplex[c][2] >= 2 { 1 } else { 0 }
  let l2 = if simplex[c][3] >= 2 { 1 } else { 0 }
  // The number 1 in the "simplex" array is at the second smallest coordinate.
  let i3 = if simplex[c][0] >= 1 { 1 } else { 0 }
  let j3 = if simplex[c][1] >= 1 { 1 } else { 0 }
  let k3 = if simplex[c][2] >= 1 { 1 } else { 0 }
  let l3 = if simplex[c][3] >= 1 { 1 } else { 0 }
  // The fifth corner has all coordinate offsets = 1, so no need to look that up.
  let x1 = x0 - i1.to_double() + g4 // Offsets for second corner in (x,y,z,w) coords
  let y1 = y0 - j1.to_double() + g4
  let z1 = z0 - k1.to_double() + g4
  let w1 = w0 - l1.to_double() + g4
  let x2 = x0 - i2.to_double() + 2.0 * g4 // Offsets for third corner in (x,y,z,w) coords
  let y2 = y0 - j2.to_double() + 2.0 * g4
  let z2 = z0 - k2.to_double() + 2.0 * g4
  let w2 = w0 - l2.to_double() + 2.0 * g4
  let x3 = x0 - i3.to_double() + 3.0 * g4 // Offsets for fourth corner in (x,y,z,w) coords
  let y3 = y0 - j3.to_double() + 3.0 * g4
  let z3 = z0 - k3.to_double() + 3.0 * g4
  let w3 = w0 - l3.to_double() + 3.0 * g4
  let x4 = x0 - 1.0 + 4.0 * g4 // Offsets for last corner in (x,y,z,w) coords
  let y4 = y0 - 1.0 + 4.0 * g4
  let z4 = z0 - 1.0 + 4.0 * g4
  let w4 = w0 - 1.0 + 4.0 * g4
  // Work out the hashed gradient indices of the five simplex corners
  let ii = simplex_noise_and255(i)
  let jj = simplex_noise_and255(j)
  let kk = simplex_noise_and255(k)
  let ll = simplex_noise_and255(l)
  let gi0 = perm[ii + perm[jj + perm[kk + perm[ll]]]] % 32
  let gi1 = perm[ii + i1 + perm[jj + j1 + perm[kk + k1 + perm[ll + l1]]]] % 32
  let gi2 = perm[ii + i2 + perm[jj + j2 + perm[kk + k2 + perm[ll + l2]]]] % 32
  let gi3 = perm[ii + i3 + perm[jj + j3 + perm[kk + k3 + perm[ll + l3]]]] % 32
  let gi4 = perm[ii + 1 + perm[jj + 1 + perm[kk + 1 + perm[ll + 1]]]] % 32
  // Calculate the contribution from the five corners
  let mut t0 = 0.6 - x0 * x0 - y0 * y0 - z0 * z0 - w0 * w0
  let n0 = if t0 < 0.0 {
    0.0
  } else {
    t0 *= t0
    t0 * t0 * simplex_noise_dot4(grad4[gi0], x0, y0, z0, w0)
  }
  let mut t1 = 0.6 - x1 * x1 - y1 * y1 - z1 * z1 - w1 * w1
  let n1 = if t1 < 0.0 {
    0.0
  } else {
    t1 *= t1
    t1 * t1 * simplex_noise_dot4(grad4[gi1], x1, y1, z1, w1)
  }
  let mut t2 = 0.6 - x2 * x2 - y2 * y2 - z2 * z2 - w2 * w2
  let n2 = if t2 < 0.0 {
    0.0
  } else {
    t2 *= t2
    t2 * t2 * simplex_noise_dot4(grad4[gi2], x2, y2, z2, w2)
  }
  let mut t3 = 0.6 - x3 * x3 - y3 * y3 - z3 * z3 - w3 * w3
  let n3 = if t3 < 0.0 {
    0.0
  } else {
    t3 *= t3
    t3 * t3 * simplex_noise_dot4(grad4[gi3], x3, y3, z3, w3)
  }
  let mut t4 = 0.6 - x4 * x4 - y4 * y4 - z4 * z4 - w4 * w4
  let n4 = if t4 < 0.0 {
    0.0
  } else {
    t4 *= t4
    t4 * t4 * simplex_noise_dot4(grad4[gi4], x4, y4, z4, w4)
  }
  // Sum up and scale the result to cover the range [-1,1]
  27.0 * (n0 + n1 + n2 + n3 + n4)
}

// private

///|
fn simplex_noise_dot(g : Array[Double], x : Double, y : Double) -> Double {
  g[0] * x + g[1] * y
}

///|
fn simplex_noise_dot3(
  g : Array[Double],
  x : Double,
  y : Double,
  z : Double,
) -> Double {
  g[0] * x + g[1] * y + g[2] * z
}

///|
fn simplex_noise_dot4(
  g : Array[Double],
  x : Double,
  y : Double,
  z : Double,
  w : Double,
) -> Double {
  g[0] * x + g[1] * y + g[2] * z + g[3] * w
}
