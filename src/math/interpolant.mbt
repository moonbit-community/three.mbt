///|
/// The `endingStart`/`endingEnd` settings read by the cubic interpolant.
pub(all) struct InterpolantSettings {
  mut ending_start : Int32
  mut ending_end : Int32
}

///|
pub fn InterpolantSettings::new(
  ending_start~ : Int32 = ZeroCurvatureEnding,
  ending_end~ : Int32 = ZeroCurvatureEnding,
) -> InterpolantSettings {
  { ending_start, ending_end, }
}

///|
/// Upstream's `Interpolant` and its subclasses: the state is shared, and the
/// three `*_impl` function fields stand for the methods a subclass overrides.
pub(all) struct Interpolant {
  mut parameter_positions : Array[Double]
  mut cached_index : Int32
  mut result_buffer : Array[Double]
  mut sample_values : Array[Double]
  mut value_size : Int32
  mut settings : InterpolantSettings?
  mut default_settings : InterpolantSettings
  mut interpolate_impl : (Interpolant, Int32, Double, Double, Double) -> Array[
    Double,
  ]
  mut interval_changed_impl : (Interpolant, Int32, Double, Double) -> Unit
  mut copy_sample_value_impl : (Interpolant, Int32) -> Array[Double]
  // `CubicInterpolant` state
  mut weight_prev : Double
  mut offset_prev : Int32
  mut weight_next : Double
  mut offset_next : Int32
  // `BezierInterpolant` state
  mut in_tangents : Array[Double]?
  mut out_tangents : Array[Double]?
}

///|
fn abstract_interpolate(
  _self : Interpolant,
  _i1 : Int32,
  _t0 : Double,
  _t : Double,
  _t1 : Double,
) -> Array[Double] {
  abort("THREE.Interpolant: Call to abstract method.")
}

///|
fn empty_interval_changed(
  _self : Interpolant,
  _i1 : Int32,
  _t0 : Double,
  _t1 : Double,
) -> Unit {
  // empty
}

///|
fn base_copy_sample_value(
  interpolant : Interpolant,
  index : Int32,
) -> Array[Double] {
  // copies a sample value to the result buffer
  let result = interpolant.result_buffer
  let values = interpolant.sample_values
  let stride = interpolant.value_size
  let offset = index * stride
  for i = 0; i != stride; i = i + 1 {
    result[i] = values[offset + i]
  }
  result
}

///|
/// Omitted function arguments keep the base class behaviour.
pub fn Interpolant::new(
  parameter_positions : Array[Double],
  sample_values : Array[Double],
  sample_size : Int32,
  result_buffer~ : Array[Double] = Array::make(sample_size, 0.0),
  interpolate~ : (Interpolant, Int32, Double, Double, Double) -> Array[Double] = abstract_interpolate,
  interval_changed~ : (Interpolant, Int32, Double, Double) -> Unit = empty_interval_changed,
  copy_sample_value~ : (Interpolant, Int32) -> Array[Double] = base_copy_sample_value,
) -> Interpolant {
  // writes past the end of a plain upstream array grow it
  while result_buffer.length() < sample_size {
    result_buffer.push(0.0)
  }
  {
    parameter_positions,
    cached_index: 0,
    result_buffer,
    sample_values,
    value_size: sample_size,
    settings: None,
    default_settings: InterpolantSettings::new(),
    interpolate_impl: interpolate,
    interval_changed_impl: interval_changed,
    copy_sample_value_impl: copy_sample_value,
    weight_prev: -0.0,
    offset_prev: 0,
    weight_next: -0.0,
    offset_next: 0,
    in_tangents: None,
    out_tangents: None,
  }
}

///|
/// Upstream's `t < x`, where an out of range `x` is undefined.
fn seek_less(t : Double, x : Double?) -> Bool {
  match x {
    Some(x) => t < x
    None => false
  }
}

///|
/// Upstream's `t >= x`, where an out of range `x` is undefined.
fn seek_at_least(t : Double, x : Double?) -> Bool {
  match x {
    Some(x) => t >= x
    None => false
  }
}

///|
/// How the linear scan of `Interpolant::evaluate` ended.
priv enum LinearScan {
  Unfinished
  Arrived
  BinarySearch(Int32)
}

///|
pub fn Interpolant::evaluate(self : Interpolant, t : Double) -> Array[Double] {
  let pp = self.parameter_positions
  let mut i1 = self.cached_index
  let mut t1 = pp.get(i1)
  let mut t0 = pp.get(i1 - 1)
  let mut scan = Unfinished
  if !seek_less(t, t1) {
    let give_up_at = i1 + 2
    while true {
      if t1 is None {
        if seek_less(t, t0) {
          break
        }

        // after end
        i1 = pp.length()
        self.cached_index = i1
        return self.copy_sample_value_(i1 - 1)
      }
      if i1 == give_up_at {
        // prepare binary search on the right side of the index
        scan = BinarySearch(pp.length())
        break
      }
      t0 = t1
      i1 += 1
      t1 = pp.get(i1)
      if seek_less(t, t1) {
        // we have arrived at the sought interval
        scan = Arrived
        break
      }
    }
  }
  if scan is Unfinished {
    if seek_at_least(t, t0) {
      // the interval is valid
      return self.interpolate_(i1, t0.unwrap(), t, t1.unwrap())
    }

    // looping?
    let t1global = pp.get(1)
    if seek_less(t, t1global) {
      i1 = 2 // + 1, using the scan for the details
      t0 = t1global
    }

    // linear reverse scan
    let give_up_at = i1 - 2
    while true {
      if t0 is None {
        // before start
        self.cached_index = 0
        return self.copy_sample_value_(0)
      }
      if i1 == give_up_at {
        // prepare binary search on the left side of the index
        scan = BinarySearch(i1)
        i1 = 0
        break
      }
      t1 = t0
      i1 -= 1
      t0 = pp.get(i1 - 1)
      if seek_at_least(t, t0) {
        // we have arrived at the sought interval
        scan = Arrived
        break
      }
    }
  }
  if scan is BinarySearch(r) {
    // binary search
    let mut right = r
    while i1 < right {
      let mid = (i1 + right) >> 1
      if t < pp[mid] {
        right = mid
      } else {
        i1 = mid + 1
      }
    }
    t1 = pp.get(i1)
    t0 = pp.get(i1 - 1)

    // check boundary cases, again
    if t0 is None {
      self.cached_index = 0
      return self.copy_sample_value_(0)
    }
    if t1 is None {
      i1 = pp.length()
      self.cached_index = i1
      return self.copy_sample_value_(i1 - 1)
    }
  }
  self.cached_index = i1
  self.interval_changed_(i1, t0.unwrap(), t1.unwrap())
  self.interpolate_(i1, t0.unwrap(), t, t1.unwrap())
}

///|
pub fn Interpolant::get_settings_(self : Interpolant) -> InterpolantSettings {
  match self.settings {
    Some(settings) => settings
    None => self.default_settings
  }
}

///|
pub fn Interpolant::copy_sample_value_(
  self : Interpolant,
  index : Int32,
) -> Array[Double] {
  (self.copy_sample_value_impl)(self, index)
}

///|
pub fn Interpolant::interpolate_(
  self : Interpolant,
  i1 : Int32,
  t0 : Double,
  t : Double,
  t1 : Double,
) -> Array[Double] {
  (self.interpolate_impl)(self, i1, t0, t, t1)
}

///|
pub fn Interpolant::interval_changed_(
  self : Interpolant,
  i1 : Int32,
  t0 : Double,
  t1 : Double,
) -> Unit {
  (self.interval_changed_impl)(self, i1, t0, t1)
}
