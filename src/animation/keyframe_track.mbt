// Upstream src/animation/KeyframeTrack.js. One struct covers the base class and the six
// track classes in tracks/: `kind` names the class, and the prototype members a
// subclass overrides (`ValueTypeName`, `DefaultInterpolation`,
// `InterpolantFactoryMethod*`) are fields set from it. An `InterpolantFactory` is
// compared by identity, as upstream compares the functions in `getInterpolation`.

///|
/// The class of a `KeyframeTrack`.
pub(all) enum KeyframeTrackKind {
  Base
  BooleanTrack
  ColorTrack
  NumberTrack
  QuaternionTrack
  StringTrack
  VectorTrack
}

///|
/// `track.values`: a `Float32Array` for numeric tracks, a plain array for the
/// `bool` and `string` tracks.
pub(all) enum TrackValues {
  Numbers(@core.TypedArray)
  Booleans(Array[Bool])
  Strings(Array[String])
}

///|
/// `track.settings`, holding the Bezier tangents.
pub(all) struct KeyframeTrackSettings {
  mut in_tangents : @core.TypedArray?
  mut out_tangents : @core.TypedArray?
}

///|
pub fn KeyframeTrackSettings::new(
  in_tangents? : @core.TypedArray,
  out_tangents? : @core.TypedArray,
) -> KeyframeTrackSettings {
  { in_tangents, out_tangents, }
}

///|
/// An `InterpolantFactoryMethod*`, or a custom `createInterpolant`. The flag is the
/// property `GLTFLoader` sets on its factory, read by `makeClipAdditive`.
pub(all) struct InterpolantFactory {
  create : (KeyframeTrack, Array[Double]?) -> @math.Interpolant
  is_interpolant_factory_method_gltf_cubic_spline : Bool
}

///|
pub fn InterpolantFactory::new(
  create : (KeyframeTrack, Array[Double]?) -> @math.Interpolant,
  is_interpolant_factory_method_gltf_cubic_spline~ : Bool = false,
) -> InterpolantFactory {
  { create, is_interpolant_factory_method_gltf_cubic_spline, }
}

///|
pub(all) struct KeyframeTrack {
  mut name : String
  mut times : @core.TypedArray
  mut values : TrackValues
  mut settings : KeyframeTrackSettings?
  /// `createInterpolant`; `None` only while the constructor runs.
  mut create_interpolant_factory : InterpolantFactory?
  kind : KeyframeTrackKind
  value_type_name : String
  default_interpolation : Int32
  interpolant_factory_method_discrete : InterpolantFactory?
  interpolant_factory_method_linear : InterpolantFactory?
  interpolant_factory_method_smooth : InterpolantFactory?
  interpolant_factory_method_bezier : InterpolantFactory?
}

// --- TrackValues -------------------------------------------------------------------

///|
pub fn TrackValues::length(self : TrackValues) -> Int32 {
  match self {
    Numbers(a) => a.length()
    Booleans(a) => a.length()
    Strings(a) => a.length()
  }
}

///|
/// `values.slice( start, end )`.
pub fn TrackValues::slice(
  self : TrackValues,
  start~ : Int32 = 0,
  end? : Int32,
) -> TrackValues {
  fn clamp(i : Int32, n : Int32) -> Int32 {
    if i < 0 {
      if i + n < 0 {
        0
      } else {
        i + n
      }
    } else if i > n {
      n
    } else {
      i
    }
  }

  match self {
    Numbers(a) => Numbers(a.slice(start~, end?))
    Booleans(a) => {
      let n = a.length()
      let s = clamp(start, n)
      let e = clamp(end.unwrap_or(n), n)
      Booleans(if s < e { a[s:e].to_owned() } else { [] })
    }
    Strings(a) => {
      let n = a.length()
      let s = clamp(start, n)
      let e = clamp(end.unwrap_or(n), n)
      Strings(if s < e { a[s:e].to_owned() } else { [] })
    }
  }
}

///|
/// `values[ i ] === values[ j ]`.
fn TrackValues::same(self : TrackValues, i : Int32, j : Int32) -> Bool {
  match self {
    Numbers(a) => a[i] == a[j]
    Booleans(a) => a[i] == a[j]
    Strings(a) => a[i] == a[j]
  }
}

///|
/// `values[ dst ] = values[ src ]`.
fn TrackValues::copy_within(
  self : TrackValues,
  dst : Int32,
  src : Int32,
) -> Unit {
  match self {
    Numbers(a) => a[dst] = a[src]
    Booleans(a) => a[dst] = a[src]
    Strings(a) => a[dst] = a[src]
  }
}

///|
/// A new array of the same type holding `values[ indices[ i ] ]`.
fn TrackValues::gather(
  self : TrackValues,
  indices : Array[Int32],
) -> TrackValues {
  match self {
    Numbers(a) => Numbers(@core.TypedArray::float32(indices.map(i => a[i])))
    Booleans(a) => Booleans(indices.map(i => a[i]))
    Strings(a) => Strings(indices.map(i => a[i]))
  }
}

///|
/// The values as interpolant samples: the typed array itself for numeric tracks;
/// 0 / 1 for booleans; table indices for strings (see `intern_string`).
fn TrackValues::sample_values(self : TrackValues) -> Array[Double] {
  match self {
    Numbers(a) => typed_as_array(a)
    Booleans(a) => a.map(b => if b { 1.0 } else { 0.0 })
    Strings(a) => a.map(intern_string)
  }
}

///|
/// `AnimationUtils.convertArray( values, Array )` as JSON.
pub fn TrackValues::to_json(self : TrackValues) -> Json {
  match self {
    Numbers(a) => Json::array(a.to_array().map(json_number))
    Booleans(a) => Json::array(a.map(x => Json::boolean(x)))
    Strings(a) => Json::array(a.map(x => Json::string(x)))
  }
}

///|
/// The numeric values; aborts on `bool` and `string` tracks.
pub fn TrackValues::numbers(self : TrackValues) -> @core.TypedArray {
  match self {
    Numbers(a) => a
    _ => abort("KeyframeTrack: values are not numeric")
  }
}

// --- Interpolant factories ---------------------------------------------------------

///|
fn KeyframeTrack::interpolant_args(
  self : KeyframeTrack,
  result : Array[Double]?,
) -> (Array[Double], Array[Double], Int32, Array[Double]) {
  let size = self.get_value_size().to_int()
  let result = match result {
    Some(result) => result
    // `new sampleValues.constructor( sampleSize )`
    None =>
      match self.values {
        Numbers(_) => float32_buffer(size)
        _ => Array::make(size, 0.0)
      }
  }
  (typed_as_array(self.times), self.values.sample_values(), size, result)
}

///|
let keyframe_track_discrete_factory : InterpolantFactory = InterpolantFactory::new(fn(
    track,
    result,
  ) {
    let (times, values, size, result) = track.interpolant_args(result)
    @math.DiscreteInterpolant::new(times, values, size, result_buffer=result)
  },
)

///|
let keyframe_track_linear_factory : InterpolantFactory = InterpolantFactory::new(fn(
    track,
    result,
  ) {
    let (times, values, size, result) = track.interpolant_args(result)
    @math.LinearInterpolant::new(times, values, size, result_buffer=result)
  },
)

///|
let keyframe_track_smooth_factory : InterpolantFactory = InterpolantFactory::new(fn(
    track,
    result,
  ) {
    let (times, values, size, result) = track.interpolant_args(result)
    @math.CubicInterpolant::new(times, values, size, result_buffer=result)
  },
)

///|
let keyframe_track_bezier_factory : InterpolantFactory = InterpolantFactory::new(fn(
    track,
    result,
  ) {
    let (times, values, size, result) = track.interpolant_args(result)
    let interpolant = @math.BezierInterpolant::new(
      times,
      values,
      size,
      result_buffer=result,
    )
    if track.settings is Some(settings) {
      interpolant.in_tangents = settings.in_tangents.map(typed_as_array)
      interpolant.out_tangents = settings.out_tangents.map(typed_as_array)
    }
    interpolant
  },
)

///|
let quaternion_keyframe_track_linear_factory : InterpolantFactory = InterpolantFactory::new(fn(
    track,
    result,
  ) {
    let (times, values, size, result) = track.interpolant_args(result)
    @math.QuaternionLinearInterpolant::new(
      times,
      values,
      size,
      result_buffer=result,
    )
  },
)

// --- Construction ------------------------------------------------------------------

///|
fn keyframe_track_make(
  kind : KeyframeTrackKind,
  name : String,
  times : @core.TypedArray,
  values : TrackValues,
  interpolation : Int32?,
) -> KeyframeTrack {
  if times.length() == 0 {
    abort("THREE.KeyframeTrack: no keyframes in track named " + name)
  }
  let (value_type_name, default_interpolation) = match kind {
    Base => ("", @core.InterpolateLinear)
    BooleanTrack => ("bool", @core.InterpolateDiscrete)
    ColorTrack => ("color", @core.InterpolateLinear)
    NumberTrack => ("number", @core.InterpolateLinear)
    QuaternionTrack => ("quaternion", @core.InterpolateLinear)
    StringTrack => ("string", @core.InterpolateDiscrete)
    VectorTrack => ("vector", @core.InterpolateLinear)
  }
  let (linear, smooth) = match kind {
    BooleanTrack | StringTrack => (None, None)
    QuaternionTrack => (Some(quaternion_keyframe_track_linear_factory), None)
    _ =>
      (Some(keyframe_track_linear_factory), Some(keyframe_track_smooth_factory))
  }
  let track = {
    name,
    times,
    values,
    settings: None,
    create_interpolant_factory: None,
    kind,
    value_type_name,
    default_interpolation,
    interpolant_factory_method_discrete: Some(keyframe_track_discrete_factory),
    interpolant_factory_method_linear: linear,
    interpolant_factory_method_smooth: smooth,
    interpolant_factory_method_bezier: Some(keyframe_track_bezier_factory),
  }
  track.set_interpolation(interpolation.unwrap_or(default_interpolation))
  |> ignore
  track
}

///|
/// The base class. `times` and `values` are converted to `Float32Array`s; a
/// `Float32Array` is kept as is.
pub fn[T : @core.TypedArrayInit, V : @core.TypedArrayInit] KeyframeTrack::new(
  name : String,
  times : T,
  values : V,
  interpolation? : Int32,
) -> KeyframeTrack {
  keyframe_track_make(
    Base,
    name,
    to_float32(times),
    Numbers(to_float32(values)),
    interpolation,
  )
}

///|
/// `new this.constructor( name, times, values )` for a track of the given class.
fn keyframe_track_construct(
  kind : KeyframeTrackKind,
  name : String,
  times : @core.TypedArray,
  values : TrackValues,
  interpolation : Int32?,
) -> KeyframeTrack {
  let values = match (kind, values) {
    (BooleanTrack, Booleans(_)) | (StringTrack, Strings(_)) => values
    (BooleanTrack | StringTrack, _) =>
      abort("KeyframeTrack: values do not match the track type")
    (_, Numbers(a)) => Numbers(to_float32(a))
    _ => abort("KeyframeTrack: values do not match the track type")
  }
  match kind {
    // these constructors take no interpolation argument
    BooleanTrack | StringTrack =>
      keyframe_track_make(kind, name, to_float32(times), values, None)
    _ =>
      keyframe_track_make(kind, name, to_float32(times), values, interpolation)
  }
}

// --- Static ------------------------------------------------------------------------

///|
/// Upstream's static `KeyframeTrack.toJSON( track )`.
pub fn KeyframeTrack::to_json(self : KeyframeTrack) -> Json {
  let json : Map[String, Json] = Map([])
  json["name"] = Json::string(self.name)
  json["times"] = Json::array(self.times.to_array().map(json_number))
  json["values"] = self.values.to_json()
  let interpolation = self.get_interpolation()
  if interpolation != Some(self.default_interpolation) {
    // `undefined` is dropped by `JSON.stringify`
    if interpolation is Some(interpolation) {
      json["interpolation"] = Json::number(interpolation.to_double())
    }
  }
  if has_tangents(self.settings) {
    let settings = self.settings.unwrap()
    json["settings"] = Json::object(
      Map([
        (
          "inTangents",
          Json::array(settings.in_tangents.unwrap().to_array().map(json_number)),
        ),
        (
          "outTangents",
          Json::array(
            settings.out_tangents.unwrap().to_array().map(json_number),
          ),
        ),
      ]),
    )
  }
  json["type"] = Json::string(self.value_type_name) // mandatory
  Json::object(json)
}

// --- Interpolation -----------------------------------------------------------------

///|
/// `track.createInterpolant( result )`.
pub fn KeyframeTrack::create_interpolant(
  self : KeyframeTrack,
  result? : Array[Double],
) -> @math.Interpolant {
  match self.create_interpolant_factory {
    Some(factory) => (factory.create)(self, result)
    None => abort("TypeError: track.createInterpolant is not a function")
  }
}

///|
pub fn KeyframeTrack::set_interpolation(
  self : KeyframeTrack,
  interpolation : Int32,
) -> KeyframeTrack {
  let factory_method = if interpolation == @core.InterpolateDiscrete {
    self.interpolant_factory_method_discrete
  } else if interpolation == @core.InterpolateLinear {
    self.interpolant_factory_method_linear
  } else if interpolation == @core.InterpolateSmooth {
    self.interpolant_factory_method_smooth
  } else if interpolation == @core.InterpolateBezier {
    self.interpolant_factory_method_bezier
  } else {
    None
  }
  match factory_method {
    Some(factory) => {
      self.create_interpolant_factory = Some(factory)
      self
    }
    None => {
      let message = "unsupported interpolation for " +
        self.value_type_name +
        " keyframe track named " +
        self.name
      if self.create_interpolant_factory is None {
        // fall back to default, unless the default itself is messed up
        if interpolation != self.default_interpolation {
          self.set_interpolation(self.default_interpolation) |> ignore
        } else {
          abort(message) // fatal, in this case
        }
      }
      @core.warn("KeyframeTrack: " + message)
      self
    }
  }
}

///|
/// `None` stands for upstream's `undefined`, for a custom `createInterpolant`.
pub fn KeyframeTrack::get_interpolation(self : KeyframeTrack) -> Int32? {
  fn same(a : InterpolantFactory?, b : InterpolantFactory?) -> Bool {
    match (a, b) {
      (Some(a), Some(b)) => physical_equal(a, b)
      (None, None) => true
      _ => false
    }
  }

  let current = self.create_interpolant_factory
  if same(current, self.interpolant_factory_method_discrete) {
    Some(@core.InterpolateDiscrete)
  } else if same(current, self.interpolant_factory_method_linear) {
    Some(@core.InterpolateLinear)
  } else if same(current, self.interpolant_factory_method_smooth) {
    Some(@core.InterpolateSmooth)
  } else if same(current, self.interpolant_factory_method_bezier) {
    Some(@core.InterpolateBezier)
  } else {
    None
  }
}

///|
pub fn KeyframeTrack::get_value_size(self : KeyframeTrack) -> Double {
  self.values.length().to_double() / self.times.length().to_double()
}

// --- Editing -----------------------------------------------------------------------

///|
pub fn KeyframeTrack::shift(
  self : KeyframeTrack,
  time_offset : Double,
) -> KeyframeTrack {
  if time_offset != 0.0 {
    let times = self.times
    let n = times.length()
    for i = 0; i != n; i = i + 1 {
      times[i] = times[i] + time_offset
    }
    if has_tangents(self.settings) {
      let settings = self.settings.unwrap()
      shift_tangent_times(settings.in_tangents.unwrap(), time_offset)
      shift_tangent_times(settings.out_tangents.unwrap(), time_offset)
    }
  }
  self
}

///|
pub fn KeyframeTrack::scale(
  self : KeyframeTrack,
  time_scale : Double,
) -> KeyframeTrack {
  if time_scale != 1.0 {
    let times = self.times
    let n = times.length()
    for i = 0; i != n; i = i + 1 {
      times[i] = times[i] * time_scale
    }
    if has_tangents(self.settings) {
      let settings = self.settings.unwrap()
      scale_tangent_times(settings.in_tangents.unwrap(), time_scale)
      scale_tangent_times(settings.out_tangents.unwrap(), time_scale)
    }
  }
  self
}

///|
pub fn KeyframeTrack::trim(
  self : KeyframeTrack,
  start_time : Double,
  end_time : Double,
) -> KeyframeTrack {
  let times = self.times
  let n_keys = times.length()
  let mut from = 0
  let mut to = n_keys - 1
  while from != n_keys && times[from] < start_time {
    from += 1
  }
  while to != -1 && times[to] > end_time {
    to -= 1
  }
  to += 1 // inclusive -> exclusive bound
  if from != 0 || to != n_keys {
    // empty tracks are forbidden, so keep at least one keyframe
    if from >= to {
      to = if to > 1 { to } else { 1 }
      from = to - 1
    }
    let stride = self.get_value_size()
    self.times = times.slice(start=from, end=to)
    self.values = self.values.slice(
      start=(from.to_double() * stride).to_int(),
      end=(to.to_double() * stride).to_int(),
    )
  }
  self
}

///|
pub fn KeyframeTrack::validate(self : KeyframeTrack) -> Bool {
  let mut valid = true
  let value_size = self.get_value_size()
  if value_size - js_math_floor(value_size) != 0.0 {
    @core.error("KeyframeTrack: Invalid value size in track.")
    valid = false
  }
  let times = self.times
  let values = self.values
  let n_keys = times.length()
  if n_keys == 0 {
    @core.error("KeyframeTrack: Track is empty.")
    valid = false
  }
  let mut prev_time : Double? = None
  for i = 0; i != n_keys; i = i + 1 {
    let curr_time = times[i]
    if js_is_nan(curr_time) {
      @core.error("KeyframeTrack: Time is not a valid number.")
      valid = false
      break
    }
    if prev_time is Some(prev_time) && prev_time > curr_time {
      @core.error("KeyframeTrack: Out of order keys.")
      valid = false
      break
    }
    prev_time = Some(curr_time)
  }
  if values is Numbers(values) {
    let n = values.length()
    for i = 0; i != n; i = i + 1 {
      let value = values[i]
      if js_is_nan(value) {
        @core.error("KeyframeTrack: Value is not a valid number.")
        valid = false
        break
      }
    }
  }
  valid
}

///|
/// Removes equivalent sequential keys, which are common in morph target sequences.
pub fn KeyframeTrack::optimize(self : KeyframeTrack) -> KeyframeTrack {
  // (0,0,0,0,1,1,1,0,0,0,0,0,0,0) --> (0,0,1,1,0,0)

  // times or values may be shared with other tracks, so overwriting is unsafe
  let times = self.times.slice()
  let values = self.values.slice()
  let stride = self.get_value_size().to_int()
  let smooth_interpolation = self.get_interpolation() ==
    Some(@core.InterpolateSmooth)
  let last_index = times.length() - 1
  let mut write_index = 1
  for i = 1; i < last_index; i = i + 1 {
    let mut keep = false
    let time = times[i]
    let time_next = times[i + 1]

    // remove adjacent keyframes scheduled at the same time
    if time != time_next && (i != 1 || time != times[0]) {
      if !smooth_interpolation {
        // remove unnecessary keyframes same as their neighbors
        let offset = i * stride
        let offset_p = offset - stride
        let offset_n = offset + stride
        for j = 0; j != stride; j = j + 1 {
          if !values.same(offset + j, offset_p + j) ||
            !values.same(offset + j, offset_n + j) {
            keep = true
            break
          }
        }
      } else {
        keep = true
      }
    }

    // in-place compaction
    if keep {
      if i != write_index {
        times[write_index] = times[i]
        let read_offset = i * stride
        let write_offset = write_index * stride
        for j = 0; j != stride; j = j + 1 {
          values.copy_within(write_offset + j, read_offset + j)
        }
      }
      write_index += 1
    }
  }

  // flush last keyframe (compaction looks ahead)
  if last_index > 0 {
    times[write_index] = times[last_index]
    let read_offset = last_index * stride
    let write_offset = write_index * stride
    for j = 0; j != stride; j = j + 1 {
      values.copy_within(write_offset + j, read_offset + j)
    }
    write_index += 1
  }
  if write_index != times.length() {
    self.times = times.slice(start=0, end=write_index)
    self.values = values.slice(start=0, end=write_index * stride)
  } else {
    self.times = times
    self.values = values
  }
  self
}

///|
pub fn KeyframeTrack::clone(self : KeyframeTrack) -> KeyframeTrack {
  let times = self.times.slice()
  let values = self.values.slice()
  let track = keyframe_track_construct(
    self.kind,
    self.name,
    times,
    values,
    None,
  )

  // Interpolant argument to constructor is not saved, so copy the factory method directly.
  track.create_interpolant_factory = self.create_interpolant_factory
  if has_tangents(self.settings) {
    let settings = self.settings.unwrap()
    track.settings = Some({
      in_tangents: Some(settings.in_tangents.unwrap().slice()),
      out_tangents: Some(settings.out_tangents.unwrap().slice()),
    })
  }
  track
}

///|
fn shift_tangent_times(
  tangents : @core.TypedArray,
  time_offset : Double,
) -> Unit {
  // tangents are [ time, value ] pairs, so only every second entry is a time
  let n = tangents.length()
  for i = 0; i < n; i = i + 2 {
    tangents[i] = tangents[i] + time_offset
  }
}

///|
fn scale_tangent_times(
  tangents : @core.TypedArray,
  time_scale : Double,
) -> Unit {
  let n = tangents.length()
  for i = 0; i < n; i = i + 2 {
    tangents[i] = tangents[i] * time_scale
  }
}

// --- Parsing (AnimationClip.js's parseKeyframeTrack) -------------------------------

///|
fn get_track_type_for_value_type_name(type_name : String) -> KeyframeTrackKind {
  match type_name.to_lower() {
    "scalar" | "double" | "float" | "number" | "integer" => NumberTrack
    "vector" | "vector2" | "vector3" | "vector4" => VectorTrack
    "color" => ColorTrack
    "quaternion" => QuaternionTrack
    "bool" | "boolean" => BooleanTrack
    "string" => StringTrack
    _ => abort("THREE.KeyframeTrack: Unsupported typeName: " + type_name)
  }
}

///|
fn json_float32(json : Json) -> @core.TypedArray {
  js_float32_of_js(@core.JsValue::from_json(json))
}

///|
/// Upstream's `parseKeyframeTrack( json )`. As upstream, a track given as `keys` gets
/// `times` and `values` written into `json`.
pub fn KeyframeTrack::parse(json : Json) -> KeyframeTrack {
  guard json is Object(object) else {
    abort("THREE.KeyframeTrack: track type undefined, can not parse")
  }
  let type_name = match object.get("type") {
    Some(String(type_name)) => type_name
    Some(Null) | None =>
      abort("THREE.KeyframeTrack: track type undefined, can not parse")
    Some(other) => @core.JsValue::from_json(other) |> js_value_to_string
  }
  let kind = get_track_type_for_value_type_name(type_name)
  if object.get("times") is None {
    let times : Array[Json] = []
    let values : Array[Json] = []
    let keys = match object.get("keys") {
      Some(Array(keys)) => keys
      _ => []
    }
    flatten_json(keys, times, values, "value")
    object["times"] = Json::array(times)
    object["values"] = Json::array(values)
  }
  let name = match object.get("name") {
    Some(String(name)) => name
    Some(Null) | None => abort("THREE.KeyframeTrack: track name is undefined")
    Some(other) => @core.JsValue::from_json(other) |> js_value_to_string
  }
  let times = json_float32(object.get("times").unwrap())
  let values_json = match object.get("values") {
    Some(Array(values)) => values
    _ => []
  }
  let values : TrackValues = match kind {
    BooleanTrack =>
      Booleans(
        values_json.map(v => {
          match v {
            True => true
            False => false
            v => js_value_truthy(@core.JsValue::from_json(v))
          }
        }),
      )
    StringTrack =>
      Strings(
        values_json.map(v => {
          match v {
            String(s) => s
            v => js_value_to_string(@core.JsValue::from_json(v))
          }
        }),
      )
    _ => Numbers(json_float32(Json::array(values_json)))
  }
  let interpolation = match object.get("interpolation") {
    Some(Number(n, ..)) if n != 0.0 => Some(n.to_int())
    _ => None
  }
  let track = keyframe_track_construct(kind, name, times, values, interpolation)
  if object.get("settings") is Some(Object(settings)) &&
    settings.get("inTangents") is Some(in_tangents) &&
    settings.get("outTangents") is Some(out_tangents) {
    track.settings = Some({
      in_tangents: Some(json_float32(in_tangents)),
      out_tangents: Some(json_float32(out_tangents)),
    })
  }
  track
}
