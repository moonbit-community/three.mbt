// Upstream src/animation/AnimationUtils.js. The functions are exported both bare and as
// statics of `AnimationUtils`; here they are package functions.

///|
/// `convertArray( array, type )` for typed-array types: returns `array` when it already
/// has the constructor named `type_name` (such as `"Float32Array"`), else a converted
/// copy.
pub fn[A : @core.TypedArrayInit] convert_array(
  array : A,
  type_name : String,
) -> @core.TypedArray {
  js_convert_array(array.to_js_init(), type_name)
}

///|
pub fn is_typed_array(object : @core.JsValue) -> Bool {
  js_is_typed_array(object)
}

///|
/// Whether the settings hold Bezier tangent data.
pub fn has_tangents(settings : KeyframeTrackSettings?) -> Bool {
  settings is Some(settings) &&
  settings.in_tangents is Some(_) &&
  settings.out_tangents is Some(_)
}

///|
/// The indices by which times and values can be sorted.
pub fn get_keyframe_order(times : Array[Double]) -> Array[Int32] {
  let n = times.length()
  let result = Array::makei(n, i => i)
  stable_sort(result, (i, j) => times[i] - times[j])
  result
}

///|
/// Sorts `values` by an order from `get_keyframe_order`.
pub fn sorted_array(
  values : Array[Double],
  stride : Int32,
  order : Array[Int32],
) -> Array[Double] {
  let n_values = values.length()
  let result = Array::make(n_values, 0.0)
  let mut i = 0
  let mut dst_offset = 0
  while dst_offset != n_values {
    let src_offset = order[i] * stride
    for j = 0; j != stride; j = j + 1 {
      result[dst_offset] = values[src_offset + j]
      dst_offset += 1
    }
    i += 1
  }
  result
}

///|
/// `sortedArray` of a typed array, giving a typed array of the same type.
pub fn sorted_typed_array(
  values : @core.TypedArray,
  stride : Int32,
  order : Array[Int32],
) -> @core.TypedArray {
  let n_values = values.length()
  let result = values.new_like(n_values)
  let mut i = 0
  let mut dst_offset = 0
  while dst_offset != n_values {
    let src_offset = order[i] * stride
    for j = 0; j != stride; j = j + 1 {
      result[dst_offset] = values[src_offset + j]
      dst_offset += 1
    }
    i += 1
  }
  result
}

///|
/// Flattens an AOS keyframe list, `[ { time, value }, ... ]`, into `times` and `values`.
pub fn flatten_json(
  json_keys : Array[Json],
  times : Array[Json],
  values : Array[Json],
  value_property_name : String,
) -> Unit {
  fn get(key : Json, name : String) -> Json? {
    match key {
      Object(object) => object.get(name)
      Null => abort("TypeError: Cannot read properties of null")
      _ => None
    }
  }

  fn time(key : Json) -> Json {
    get(key, "time").unwrap_or(Json::null())
  }

  let mut i = 1
  let mut key = json_keys.get(0)
  while key is Some(k) && get(k, value_property_name) is None {
    key = json_keys.get(i)
    i += 1
  }
  guard key is Some(first) else { return } // no data
  guard get(first, value_property_name) is Some(value) else { return } // no data
  if value is Array(_) {
    while key is Some(k) {
      if get(k, value_property_name) is Some(value) {
        times.push(time(k))
        match value {
          Array(elements) => values.append(elements) // push all elements
          // `values.push( ...value )` of a non-iterable throws
          _ => abort("TypeError: value is not iterable")
        }
      }
      key = json_keys.get(i)
      i += 1
    }
  } else {
    // otherwise push as-is
    while key is Some(k) {
      if get(k, value_property_name) is Some(value) {
        times.push(time(k))
        values.push(value)
      }
      key = json_keys.get(i)
      i += 1
    }
  }
}

///|
/// A new clip with the segment of `source_clip` between the given frames.
pub fn subclip(
  source_clip : AnimationClip,
  name : String,
  start_frame : Double,
  end_frame : Double,
  fps~ : Double = 30.0,
) -> AnimationClip {
  let clip = source_clip.clone()
  clip.name = name
  let tracks = []
  for i = 0; i < clip.tracks.length(); i = i + 1 {
    let track = clip.tracks[i]
    let value_size = track.get_value_size().to_int()
    let times : Array[Double] = []
    let indices : Array[Int32] = []
    for j = 0; j < track.times.length(); j = j + 1 {
      let frame = track.times[j] * fps
      if frame < start_frame || frame >= end_frame {
        continue
      }
      times.push(track.times[j])
      for k = 0; k < value_size; k = k + 1 {
        indices.push(j * value_size + k)
      }
    }
    if times.length() == 0 {
      continue
    }
    track.times = @core.TypedArray::float32(times)
    track.values = track.values.gather(indices)
    tracks.push(track)
  }
  clip.tracks = tracks

  // find minimum .times value across all tracks in the trimmed clip
  let mut min_start_time = @double.infinity
  for i = 0; i < clip.tracks.length(); i = i + 1 {
    if min_start_time > clip.tracks[i].times[0] {
      min_start_time = clip.tracks[i].times[0]
    }
  }

  // shift all tracks such that clip begins at t=0
  for i = 0; i < clip.tracks.length(); i = i + 1 {
    clip.tracks[i].shift(-1.0 * min_start_time) |> ignore
  }
  clip.reset_duration() |> ignore
  clip
}

///|
/// Makes the keyframes of `target_clip` relative to the reference frame.
pub fn make_clip_additive(
  target_clip : AnimationClip,
  reference_frame~ : Double = 0.0,
  reference_clip? : AnimationClip,
  fps~ : Double = 30.0,
) -> AnimationClip {
  let reference_clip = reference_clip.unwrap_or(target_clip)
  let fps = if fps <= 0.0 { 30.0 } else { fps }
  let num_tracks = reference_clip.tracks.length()
  let reference_time = reference_frame / fps

  // Make each track's values relative to the values at the reference frame
  for i = 0; i < num_tracks; i = i + 1 {
    let reference_track = reference_clip.tracks[i]
    let reference_track_type = reference_track.value_type_name

    // Skip this track if it's non-numeric
    if reference_track_type == "bool" || reference_track_type == "string" {
      continue
    }

    // Find the track in the target clip whose name and type matches the reference track
    let target_track = target_clip.tracks.search_by(track => {
      track.name == reference_track.name &&
      track.value_type_name == reference_track_type
    })
    guard target_track is Some(target_index) else { continue }
    let target_track = target_clip.tracks[target_index]
    let mut reference_offset = 0.0
    let reference_value_size = reference_track.get_value_size()
    if is_gltf_cubic_spline(reference_track) {
      reference_offset = reference_value_size / 3.0
    }
    let mut target_offset = 0.0
    let target_value_size = target_track.get_value_size()
    if is_gltf_cubic_spline(target_track) {
      target_offset = target_value_size / 3.0
    }
    let last_index = reference_track.times.length() - 1
    let reference_values = reference_track.values.numbers()

    // Find the value to subtract out of the track
    let reference_value = if reference_time <= reference_track.times[0] {
      // Reference frame is earlier than the first keyframe, so just use the first keyframe
      let start_index = reference_offset
      let end_index = reference_value_size - reference_offset
      reference_values.slice(start=start_index.to_int(), end=end_index.to_int())
    } else if reference_time >= reference_track.times[last_index] {
      // Reference frame is after the last keyframe, so just use the last keyframe
      let start_index = last_index.to_double() * reference_value_size +
        reference_offset
      let end_index = start_index + reference_value_size - reference_offset
      reference_values.slice(start=start_index.to_int(), end=end_index.to_int())
    } else {
      // Interpolate to the reference value
      let interpolant = reference_track.create_interpolant()
      interpolant.evaluate(reference_time) |> ignore
      js_result_buffer_slice(@core.JsValue::of(interpolant.result_buffer))
    }

    // Conjugate the quaternion
    if reference_track_type == "quaternion" {
      let reference_quat = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0)
        .from_array(typed_as_array(reference_value))
        .normalize()
        .conjugate()
      reference_quat.to_array(array=typed_as_array(reference_value)) |> ignore
    }

    // Subtract the reference value from all of the track values
    let target_values = target_track.values.numbers()
    let num_times = target_track.times.length()
    for j = 0; j < num_times; j = j + 1 {
      let value_start = (j.to_double() * target_value_size + target_offset).to_int()
      if reference_track_type == "quaternion" {
        // Multiply the conjugate for quaternion track types
        @math.Quaternion::multiply_quaternions_flat(
          typed_as_array(target_values),
          value_start,
          typed_as_array(reference_value),
          0,
          typed_as_array(target_values),
          value_start,
        )
        |> ignore
      } else {
        let value_end = target_value_size - target_offset * 2.0

        // Subtract each value for all other numeric track types
        for k = 0; k.to_double() < value_end; k = k + 1 {
          target_values[value_start + k] = target_values[value_start + k] -
            reference_value[k]
        }
      }
    }
  }
  target_clip.blend_mode = @core.AdditiveAnimationBlendMode
  target_clip
}

///|
fn is_gltf_cubic_spline(track : KeyframeTrack) -> Bool {
  track.create_interpolant_factory is Some(factory) &&
  factory.is_interpolant_factory_method_gltf_cubic_spline
}

///|
/// `resultBuffer.slice()`: the default result buffer of a numeric track is a
/// `Float32Array`.
extern "js" fn js_result_buffer_slice(
  buffer : @core.JsValue,
) -> @core.TypedArray =
  #|(b) => (ArrayBuffer.isView(b) ? b.slice() : new Float32Array(b))
