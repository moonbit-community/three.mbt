// Upstream src/animation/PropertyMixer.js. The buffer is an `Array[Double]` for every
// value type: upstream uses a `Float64Array` for numbers and a plain `Array` for
// booleans and strings, which are encoded as numbers here (see property_binding.mbt).

///|
/// Which mix functions a mixer uses, picked from the track's `ValueTypeName`.
priv enum MixMode {
  Slerp
  Select
  Numeric
}

///|
/// Buffers and mixes one animated property.
pub(all) struct PropertyMixer {
  binding : AnyPropertyBinding
  value_size : Int32
  /// Layout: [ incoming | accu0 | accu1 | orig | addAccu | (optional work) ].
  buffer : Array[Double]
  priv mode : MixMode
  _work_index : Int32
  _orig_index : Int32
  _add_index : Int32
  mut cumulative_weight : Double
  mut cumulative_weight_additive : Double
  mut use_count : Int32
  mut reference_count : Int32
  /// Set by the mixer's memory manager.
  mut _cache_index : Int32?
}

///|
pub fn PropertyMixer::new(
  binding : AnyPropertyBinding,
  type_name : String,
  value_size : Int32,
) -> PropertyMixer {
  // 'work' is optional and is only present for quaternion types. It is used
  // to store intermediate quaternion multiplication results
  let (mode, buffer, work_index) = match type_name {
    "quaternion" => (Slerp, Array::make(value_size * 6, 0.0), 5)
    // a new `Array` holds `undefined`
    "string" | "bool" =>
      (Select, Array::make(value_size * 5, undefined_slot_value), -1)
    _ => (Numeric, Array::make(value_size * 5, 0.0), -1)
  }
  {
    binding,
    value_size,
    buffer,
    mode,
    _work_index: work_index,
    _orig_index: 3,
    _add_index: 4,
    cumulative_weight: 0.0,
    cumulative_weight_additive: 0.0,
    use_count: 0,
    reference_count: 0,
    _cache_index: None,
  }
}

///|
/// Accumulates data in the `incoming` region into `accu<i>`.
pub fn PropertyMixer::accumulate(
  self : PropertyMixer,
  accu_index : Int32,
  weight : Double,
) -> Unit {
  // note: happily accumulating nothing when weight = 0, the caller knows
  // the weight and shouldn't have made the call in the first place
  let buffer = self.buffer
  let stride = self.value_size
  let offset = accu_index * stride + stride
  let mut current_weight = self.cumulative_weight
  if current_weight == 0.0 {
    // accuN := incoming * weight
    for i = 0; i != stride; i = i + 1 {
      buffer[offset + i] = buffer[i]
    }
    current_weight = weight
  } else {
    // accuN := accuN + incoming * weight
    current_weight += weight
    let mix = weight / current_weight
    self.mix_buffer_region(buffer, offset, 0, mix, stride)
  }
  self.cumulative_weight = current_weight
}

///|
/// Accumulates data in the `incoming` region into `add`.
pub fn PropertyMixer::accumulate_additive(
  self : PropertyMixer,
  weight : Double,
) -> Unit {
  let buffer = self.buffer
  let stride = self.value_size
  let offset = stride * self._add_index
  if self.cumulative_weight_additive == 0.0 {
    // add = identity
    self.set_identity()
  }

  // add := add + incoming * weight
  self.mix_buffer_region_additive(buffer, offset, 0, weight, stride)
  self.cumulative_weight_additive += weight
}

///|
/// Applies the state of `accu<i>` to the binding when accus differ.
pub fn PropertyMixer::apply(self : PropertyMixer, accu_index : Int32) -> Unit {
  let stride = self.value_size
  let buffer = self.buffer
  let offset = accu_index * stride + stride
  let weight = self.cumulative_weight
  let weight_additive = self.cumulative_weight_additive
  let binding = self.binding
  self.cumulative_weight = 0.0
  self.cumulative_weight_additive = 0.0
  if weight < 1.0 {
    // accuN := accuN + original * ( 1 - cumulativeWeight )
    let original_value_offset = stride * self._orig_index
    self.mix_buffer_region(
      buffer,
      offset,
      original_value_offset,
      1.0 - weight,
      stride,
    )
  }
  if weight_additive > 0.0 {
    // accuN := accuN + additive accuN
    self.mix_buffer_region_additive(
      buffer,
      offset,
      self._add_index * stride,
      1.0,
      stride,
    )
  }
  let e = stride + stride
  for i = stride; i != e; i = i + 1 {
    if buffer[i] != buffer[i + stride] {
      // value has changed -> update scene graph
      binding.set_value(buffer, offset)
      break
    }
  }
}

///|
/// Remembers the state of the bound property and copies it to both accus.
pub fn PropertyMixer::save_original_state(self : PropertyMixer) -> Unit {
  let binding = self.binding
  let buffer = self.buffer
  let stride = self.value_size
  let original_value_offset = stride * self._orig_index
  binding.get_value(buffer, original_value_offset)

  // accu[0..1] := orig -- initially detect changes against the original
  let e = original_value_offset
  for i = stride; i != e; i = i + 1 {
    buffer[i] = buffer[original_value_offset + i % stride]
  }

  // Add to identity for additive
  self.set_identity()
  self.cumulative_weight = 0.0
  self.cumulative_weight_additive = 0.0
}

///|
/// Applies the state previously taken via `save_original_state` to the binding.
pub fn PropertyMixer::restore_original_state(self : PropertyMixer) -> Unit {
  let original_value_offset = self.value_size * 3
  self.binding.set_value(self.buffer, original_value_offset)
}

// --- internals ---------------------------------------------------------------------

///|
fn PropertyMixer::set_identity(self : PropertyMixer) -> Unit {
  match self.mode {
    Numeric => self.set_additive_identity_numeric()
    Slerp => {
      self.set_additive_identity_numeric()
      self.buffer[self._add_index * self.value_size + 3] = 1.0
    }
    Select => {
      let start_index = self._orig_index * self.value_size
      let target_index = self._add_index * self.value_size
      for i = 0; i < self.value_size; i = i + 1 {
        self.buffer[target_index + i] = self.buffer[start_index + i]
      }
    }
  }
}

///|
fn PropertyMixer::set_additive_identity_numeric(self : PropertyMixer) -> Unit {
  let start_index = self._add_index * self.value_size
  let end_index = start_index + self.value_size
  for i = start_index; i < end_index; i = i + 1 {
    self.buffer[i] = 0.0
  }
}

///|
fn PropertyMixer::mix_buffer_region(
  self : PropertyMixer,
  buffer : Array[Double],
  dst_offset : Int32,
  src_offset : Int32,
  t : Double,
  stride : Int32,
) -> Unit {
  match self.mode {
    Slerp => property_mixer_slerp(buffer, dst_offset, src_offset, t)
    Select => property_mixer_select(buffer, dst_offset, src_offset, t, stride)
    Numeric => property_mixer_lerp(buffer, dst_offset, src_offset, t, stride)
  }
}

///|
fn PropertyMixer::mix_buffer_region_additive(
  self : PropertyMixer,
  buffer : Array[Double],
  dst_offset : Int32,
  src_offset : Int32,
  t : Double,
  stride : Int32,
) -> Unit {
  match self.mode {
    Slerp => {
      let work_offset = self._work_index * stride

      // Store result in intermediate buffer offset
      @math.Quaternion::multiply_quaternions_flat(
        buffer, work_offset, buffer, dst_offset, buffer, src_offset,
      )
      |> ignore

      // Slerp to the intermediate result
      @math.Quaternion::slerp_flat(
        buffer, dst_offset, buffer, dst_offset, buffer, work_offset, t,
      )
    }
    // additive is not relevant for non-numeric types
    Select => property_mixer_select(buffer, dst_offset, src_offset, t, stride)
    Numeric =>
      property_mixer_lerp_additive(buffer, dst_offset, src_offset, t, stride)
  }
}

///|
fn property_mixer_select(
  buffer : Array[Double],
  dst_offset : Int32,
  src_offset : Int32,
  t : Double,
  stride : Int32,
) -> Unit {
  if t >= 0.5 {
    for i = 0; i != stride; i = i + 1 {
      buffer[dst_offset + i] = buffer[src_offset + i]
    }
  }
}

///|
fn property_mixer_slerp(
  buffer : Array[Double],
  dst_offset : Int32,
  src_offset : Int32,
  t : Double,
) -> Unit {
  @math.Quaternion::slerp_flat(
    buffer, dst_offset, buffer, dst_offset, buffer, src_offset, t,
  )
}

///|
fn property_mixer_lerp(
  buffer : Array[Double],
  dst_offset : Int32,
  src_offset : Int32,
  t : Double,
  stride : Int32,
) -> Unit {
  let s = 1.0 - t
  for i = 0; i != stride; i = i + 1 {
    let j = dst_offset + i
    buffer[j] = buffer[j] * s + buffer[src_offset + i] * t
  }
}

///|
fn property_mixer_lerp_additive(
  buffer : Array[Double],
  dst_offset : Int32,
  src_offset : Int32,
  t : Double,
  stride : Int32,
) -> Unit {
  for i = 0; i != stride; i = i + 1 {
    let j = dst_offset + i
    buffer[j] = buffer[j] + buffer[src_offset + i] * t
  }
}
