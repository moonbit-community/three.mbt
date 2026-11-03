// Upstream has no test file for Earcut. The expected triangles come from upstream's
// earcut.js.

///|
test "Earcut triangulate a square" {
  let data = [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0]
  assert_eq(@extras.Earcut::triangulate(data, []), [2, 3, 0, 0, 1, 2])
}

///|
test "Earcut triangulate a square with a hole" {
  let data = [
    0.0, 0.0, 4.0, 0.0, 4.0, 4.0, 0.0, 4.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 2.0, 1.0,
  ]
  let triangles = @extras.Earcut::triangulate(data, [4])
  assert_eq(triangles.length(), 24)
  assert_eq(@extras.earcut_deviation(data, [4], 2, triangles), 0.0)
}

///|
test "Earcut triangulate with three coordinates per vertex" {
  let data = [0.0, 0.0, 9.0, 1.0, 0.0, 9.0, 1.0, 1.0, 9.0, 0.0, 1.0, 9.0]
  assert_eq(@extras.Earcut::triangulate(data, [], dim=3), [2, 3, 0, 0, 1, 2])
}

///|
test "Earcut degenerate inputs give no triangles" {
  assert_eq(@extras.Earcut::triangulate([], []), [])
  assert_eq(@extras.Earcut::triangulate([1.0, 2.0], []), [])
  assert_eq(@extras.Earcut::triangulate([0.0, 0.0, 1.0, 1.0], []), [])
}

///|
test "earcut_flatten" {
  let result = @extras.earcut_flatten([
    [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0]],
    [[0.2, 0.2], [0.4, 0.2], [0.4, 0.4]],
  ])
  assert_eq(result.vertices.length(), 12)
  assert_eq(result.holes, [3])
  assert_eq(result.dimensions, 2)
}
