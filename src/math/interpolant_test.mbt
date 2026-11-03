///|
/// Upstream's `Mock`, recording calls as `(name, args)`.
fn interpolant_test_mock(
  parameter_positions : Array[Double],
  sample_values : Array[Double],
  sample_size : Int32,
  calls : Array[(String, Array[Double])],
  result_buffer? : Array[Double],
) -> @math.Interpolant {
  @math.Interpolant::new(
    parameter_positions,
    sample_values,
    sample_size,
    result_buffer?,
    interval_changed=(_, i1, t0, t1) => {
      calls.push(("intervalChanged", [i1.to_double(), t0, t1]))
    },
    interpolate=(interpolant, i1, t0, t, t1) => {
      calls.push(("interpolate", [i1.to_double(), t0, t, t1]))
      interpolant.copy_sample_value_(i1 - 1)
    },
  )
}

///|
test "Interpolant: Instancing" {
  let interpolant : @math.Interpolant = interpolant_test_mock(
    [],
    [1.0, 11.0, 2.0, 22.0, 3.0, 33.0],
    2,
    [],
    result_buffer=[],
  )
  assert_eq(interpolant.value_size, 2)
}

///|
test "Interpolant: copySampleValue_" {
  let interpolant = interpolant_test_mock(
    [],
    [1.0, 11.0, 2.0, 22.0, 3.0, 33.0],
    2,
    [],
    result_buffer=[],
  )
  assert_eq(interpolant.copy_sample_value_(0), [1.0, 11.0])
  assert_eq(interpolant.copy_sample_value_(1), [2.0, 22.0])
  assert_eq(interpolant.copy_sample_value_(2), [3.0, 33.0])
}

///|
test "Interpolant: evaluate -> intervalChanged_ / interpolate_" {
  let calls = []
  let interpolant = interpolant_test_mock(
    [11.0, 22.0, 33.0, 44.0, 55.0, 66.0, 77.0, 88.0, 99.0],
    [],
    0,
    calls,
  )
  ignore(interpolant.evaluate(11.0))
  assert_eq(calls, [
    ("intervalChanged", [1.0, 11.0, 22.0]),
    ("interpolate", [1.0, 11.0, 11.0, 22.0]),
  ])
  calls.clear()
  ignore(interpolant.evaluate(12.0)) // same interval
  assert_eq(calls, [("interpolate", [1.0, 11.0, 12.0, 22.0])])
  calls.clear()
  ignore(interpolant.evaluate(22.0)) // step forward
  assert_eq(calls, [
    ("intervalChanged", [2.0, 22.0, 33.0]),
    ("interpolate", [2.0, 22.0, 22.0, 33.0]),
  ])
  calls.clear()
  ignore(interpolant.evaluate(21.0)) // step back
  assert_eq(calls, [
    ("intervalChanged", [1.0, 11.0, 22.0]),
    ("interpolate", [1.0, 11.0, 21.0, 22.0]),
  ])
  calls.clear()
  ignore(interpolant.evaluate(20.0)) // same interval
  assert_eq(calls, [("interpolate", [1.0, 11.0, 20.0, 22.0])])
  calls.clear()
  ignore(interpolant.evaluate(43.0)) // two steps forward
  assert_eq(calls, [
    ("intervalChanged", [3.0, 33.0, 44.0]),
    ("interpolate", [3.0, 33.0, 43.0, 44.0]),
  ])
  calls.clear()
  ignore(interpolant.evaluate(12.0)) // two steps back
  assert_eq(calls, [
    ("intervalChanged", [1.0, 11.0, 22.0]),
    ("interpolate", [1.0, 11.0, 12.0, 22.0]),
  ])
  calls.clear()
  ignore(interpolant.evaluate(77.0)) // random access
  assert_eq(calls, [
    ("intervalChanged", [7.0, 77.0, 88.0]),
    ("interpolate", [7.0, 77.0, 77.0, 88.0]),
  ])
  calls.clear()
  ignore(interpolant.evaluate(80.0)) // same interval
  assert_eq(calls, [("interpolate", [7.0, 77.0, 80.0, 88.0])])
  calls.clear()
  ignore(interpolant.evaluate(36.0)) // random access
  assert_eq(calls, [
    ("intervalChanged", [3.0, 33.0, 44.0]),
    ("interpolate", [3.0, 33.0, 36.0, 44.0]),
  ])
  calls.clear()
  ignore(interpolant.evaluate(24.0)) // fast reset / loop (2nd)
  assert_eq(calls, [
    ("intervalChanged", [2.0, 22.0, 33.0]),
    ("interpolate", [2.0, 22.0, 24.0, 33.0]),
  ])
  calls.clear()
  ignore(interpolant.evaluate(16.0)) // fast reset / loop (2nd)
  assert_eq(calls, [
    ("intervalChanged", [1.0, 11.0, 22.0]),
    ("interpolate", [1.0, 11.0, 16.0, 22.0]),
  ])
}
