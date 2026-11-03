// GLTFCubicSplineInterpolant and GLTFCubicSplineQuaternionInterpolant (upstream
// examples/jsm/loaders/GLTFLoader.js). Spline interpolation, specification:
// https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#appendix-c-spline-interpolation

///|
/// A typed array read and written in place as an `Array[Double]` (indexing compiles
/// to `a[ i ]`).
fn gltf_typed_as_array(array : @core.TypedArray) -> Array[Double] = "%identity"

///|
let gltf_interpolant_quaternion : @math.Quaternion = @math.Quaternion::new(
  0, 0, 0, 1,
)

///|
/// `copySampleValue_( index )`: copies a sample value to the result buffer. See the
/// CUBICSPLINE values layout in `gltf_cubic_spline_interpolate`.
fn gltf_cubic_spline_copy_sample_value(
  interp : @math.Interpolant,
  index : Int32,
) -> Array[Double] {
  let result = interp.result_buffer
  let values = interp.sample_values
  let value_size = interp.value_size
  let offset = index * value_size * 3 + value_size
  for i in 0..<value_size {
    result[i] = values[offset + i]
  }
  result
}

///|
/// `interpolate_( i1, t0, t, t1 )`.
fn gltf_cubic_spline_interpolate(
  interp : @math.Interpolant,
  i1 : Int32,
  t0 : Double,
  t : Double,
  t1 : Double,
) -> Array[Double] {
  let result = interp.result_buffer
  let values = interp.sample_values
  let stride = interp.value_size
  let stride2 = stride * 2
  let stride3 = stride * 3
  let td = t1 - t0
  let p = (t - t0) / td
  let pp = p * p
  let ppp = pp * p
  let offset1 = i1 * stride3
  let offset0 = offset1 - stride3
  let s2 = -2.0 * ppp + 3.0 * pp
  let s3 = ppp - pp
  let s0 = 1.0 - s2
  let s1 = s3 - pp + p

  // Layout of keyframe output values for CUBICSPLINE animations:
  //   [ inTangent_1, splineVertex_1, outTangent_1, inTangent_2, splineVertex_2, ... ]
  for i in 0..<stride {
    let p0 = values[offset0 + i + stride] // splineVertex_k
    let m0 = values[offset0 + i + stride2] * td // outTangent_k * (t_k+1 - t_k)
    let p1 = values[offset1 + i + stride] // splineVertex_k+1
    let m1 = values[offset1 + i] * td // inTangent_k+1 * (t_k+1 - t_k)
    result[i] = s0 * p0 + s1 * m0 + s2 * p1 + s3 * m1
  }
  result
}

///|
/// The quaternion variant's `interpolate_`: the spline result, normalized.
fn gltf_cubic_spline_quaternion_interpolate(
  interp : @math.Interpolant,
  i1 : Int32,
  t0 : Double,
  t : Double,
  t1 : Double,
) -> Array[Double] {
  let result = gltf_cubic_spline_interpolate(interp, i1, t0, t, t1)
  gltf_interpolant_quaternion
  .from_array(result)
  .normalize()
  .to_array(array=result)
  |> ignore
  result
}

///|
/// `new GLTFCubicSplineInterpolant( parameterPositions, sampleValues, sampleSize, resultBuffer )`.
pub fn gltf_cubic_spline_interpolant(
  parameter_positions : Array[Double],
  sample_values : Array[Double],
  sample_size : Int32,
  result_buffer? : Array[Double],
  quaternion~ : Bool = false,
) -> @math.Interpolant {
  // `new sampleValues.constructor( sampleSize )` for a missing result buffer
  let result_buffer = match result_buffer {
    Some(r) => r
    None =>
      if gltf_is_float32_array(@core.JsValue::of(sample_values)) {
        gltf_typed_as_array(@core.TypedArray::float32(sample_size))
      } else {
        Array::make(sample_size, 0.0)
      }
  }
  @math.Interpolant::new(
    parameter_positions,
    sample_values,
    sample_size,
    result_buffer~,
    interpolate=if quaternion {
      gltf_cubic_spline_quaternion_interpolate
    } else {
      gltf_cubic_spline_interpolate
    },
    copy_sample_value=gltf_cubic_spline_copy_sample_value,
  )
}

///|
extern "js" fn gltf_is_float32_array(v : @core.JsValue) -> Bool = "(v) => v instanceof Float32Array"

///|
/// `InterpolantFactoryMethodGLTFCubicSpline( result )`, set as a track's
/// `createInterpolant` for CUBICSPLINE samplers.
fn gltf_interpolant_factory_method_gltf_cubic_spline(
  track : @animation.KeyframeTrack,
  result : Array[Double]?,
) -> @math.Interpolant {
  // A CUBICSPLINE keyframe in glTF has three output values for each input value,
  // representing inTangent, splineVertex, and outTangent. As a result, track.getValueSize()
  // must be divided by three to get the interpolant's sampleSize argument.
  gltf_cubic_spline_interpolant(
    gltf_typed_as_array(track.times),
    gltf_typed_as_array(track.values.numbers()),
    (track.get_value_size() / 3.0).to_int(),
    result_buffer?=result,
    quaternion=track.kind is QuaternionTrack,
  )
}
