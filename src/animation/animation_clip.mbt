// Upstream src/animation/AnimationClip.js. A clip is the `SerializableResource` that
// core's `Object3D.animations` holds; `AnimationClip::from_resource` gets it back.

///|
pub(all) struct AnimationClip {
  mut name : String
  mut tracks : Array[KeyframeTrack]
  mut duration : Double
  mut blend_mode : Int32
  mut uuid : String
  mut user_data : @core.JsValue
}

///|
/// A negative `duration` is computed from the tracks.
pub fn AnimationClip::new(
  name~ : String = "",
  duration~ : Double = -1.0,
  tracks~ : Array[KeyframeTrack] = [],
  blend_mode~ : Int32 = @core.NormalAnimationBlendMode,
) -> AnimationClip {
  let clip = {
    name,
    tracks,
    duration,
    blend_mode,
    uuid: @math.generate_uuid(),
    user_data: @core.JsValue::object(),
  }

  // this means it should figure out its duration by scanning the tracks
  if clip.duration < 0.0 {
    clip.reset_duration() |> ignore
  }
  clip
}

///|
pub impl @core.SerializableResource for AnimationClip with fn uuid(self) {
  self.uuid
}

///|
pub impl @core.SerializableResource for AnimationClip with fn to_json(self) {
  AnimationClip::to_json(self)
}

///|
/// Tagged, so `from_resource` can tell a clip from other resources.
pub impl @core.SerializableResource for AnimationClip with fn payload(self) {
  let tagged = @core.JsValue::object()
  tagged.set("__animation_clip", @core.JsValue::of(self))
  tagged
}

///|
pub extend AnimationClip with @core.SerializableResource::{payload}

///|
pub extend AnimationClip with @core.SerializableResource::{uuid}

///|
/// The clip as an entry of `Object3D.animations`.
pub fn AnimationClip::as_resource(
  self : AnimationClip,
) -> &@core.SerializableResource {
  self
}

///|
/// The clip behind an entry of `Object3D.animations`; `None` for other resources.
pub fn AnimationClip::from_resource(
  resource : &@core.SerializableResource,
) -> AnimationClip? {
  let clip = resource.payload().get("__animation_clip")
  if clip.is_undefined() {
    None
  } else {
    Some(clip.cast())
  }
}

///|
/// The clips in `object.animations`.
pub fn AnimationClip::animations_of(
  object : @core.Object3D,
) -> Array[AnimationClip] {
  let clips = []
  for resource in object.animations {
    if AnimationClip::from_resource(resource) is Some(clip) {
      clips.push(clip)
    }
  }
  clips
}

///|
/// Upstream's static `AnimationClip.parse( json )`.
pub fn AnimationClip::parse(json : Json) -> AnimationClip {
  guard json is Object(object) else {
    abort("TypeError: Cannot read properties of undefined (reading 'length')")
  }
  let json_tracks = match object.get("tracks") {
    Some(Array(tracks)) => tracks
    _ =>
      abort("TypeError: Cannot read properties of undefined (reading 'length')")
  }
  let fps = match object.get("fps") {
    Some(Number(fps, ..)) if fps != 0.0 && !js_is_nan(fps) => fps
    _ => 1.0
  }
  let frame_time = 1.0 / fps
  let tracks = []
  let n = json_tracks.length()
  for i = 0; i != n; i = i + 1 {
    tracks.push(KeyframeTrack::parse(json_tracks[i]).scale(frame_time))
  }
  let name = match object.get("name") {
    Some(String(name)) => name
    Some(other) => js_value_to_string(@core.JsValue::from_json(other))
    None => ""
  }
  // `null` (a non-finite duration as `JSON.stringify` writes it) is kept upstream: it is
  // not below 0, so no `resetDuration`, and `toJSON` writes `null` again
  let duration = match object.get("duration") {
    Some(Number(duration, ..)) => duration
    Some(Null as json) => @math.json_to_number(json).unwrap()
    _ => -1.0
  }
  let blend_mode = match object.get("blendMode") {
    Some(Number(mode, ..)) => mode.to_int()
    _ => @core.NormalAnimationBlendMode
  }
  let clip = AnimationClip::new(name~, duration~, tracks~, blend_mode~)
  if object.get("uuid") is Some(String(uuid)) {
    clip.uuid = uuid
  }
  let user_data = match object.get("userData") {
    Some(String(text)) if text != "" => text
    _ => "{}"
  }
  clip.user_data = js_json_parse(user_data)
  clip
}

///|
/// Upstream's static `AnimationClip.toJSON( clip )`, also its `toJSON()`.
pub fn AnimationClip::to_json(self : AnimationClip) -> Json {
  let tracks = []
  let n = self.tracks.length()
  for i = 0; i != n; i = i + 1 {
    tracks.push(KeyframeTrack::to_json(self.tracks[i]))
  }
  Json::object(
    Map([
      ("name", Json::string(self.name)),
      ("duration", json_number(self.duration)),
      ("tracks", Json::array(tracks)),
      ("uuid", Json::string(self.uuid)),
      ("blendMode", Json::number(self.blend_mode.to_double())),
      ("userData", Json::string(js_json_stringify(self.user_data))),
    ]),
  )
}

///|
/// What `CreateFromMorphTargetSequence` reads from a morph target: its name.
pub(open) trait MorphTarget {
  fn morph_target_name(Self) -> String
}

///|
pub impl MorphTarget for String with fn morph_target_name(self) {
  self
}

///|
pub impl MorphTarget for @core.GeometryAttribute with fn morph_target_name(self) {
  self.name()
}

///|
/// A clip that plays the morph targets in sequence, `fps` per second.
pub fn[T : MorphTarget] AnimationClip::create_from_morph_target_sequence(
  name : String,
  morph_target_sequence : Array[T],
  fps : Double,
  no_loop : Bool,
) -> AnimationClip {
  let num_morph_targets = morph_target_sequence.length()
  let tracks = []
  for i = 0; i < num_morph_targets; i = i + 1 {
    let mut times : Array[Double] = []
    let mut values : Array[Double] = []
    times.push(((i + num_morph_targets - 1) % num_morph_targets).to_double())
    times.push(i.to_double())
    times.push(((i + 1) % num_morph_targets).to_double())
    values.push(0.0)
    values.push(1.0)
    values.push(0.0)
    let order = get_keyframe_order(times)
    times = sorted_array(times, 1, order)
    values = sorted_array(values, 1, order)

    // if there is a key at the first frame, duplicate it as the
    // last frame as well for perfect loop.
    if !no_loop && times[0] == 0.0 {
      times.push(num_morph_targets.to_double())
      values.push(values[0])
    }
    tracks.push(
      NumberKeyframeTrack::new(
        ".morphTargetInfluences[" +
        morph_target_sequence[i].morph_target_name() +
        "]",
        times,
        values,
      ).scale(1.0 / fps),
    )
  }
  AnimationClip::new(name~, duration=-1.0, tracks~)
}

///|
/// Upstream's `findByName` given an array of clips.
pub fn AnimationClip::find_by_name(
  clip_array : Array[AnimationClip],
  name : String,
) -> AnimationClip? {
  for i = 0; i < clip_array.length(); i = i + 1 {
    if clip_array[i].name == name {
      return Some(clip_array[i])
    }
  }
  None
}

///|
/// Upstream's `findByName` given an object: searches `object.animations`.
pub fn AnimationClip::find_by_name_in_object(
  object : @core.Object3D,
  name : String,
) -> AnimationClip? {
  AnimationClip::find_by_name(AnimationClip::animations_of(object), name)
}

///|
extern "js" fn js_morph_sequence_name(name : String) -> @core.JsValue =
  #|(s) => { const parts = s.match(/^([\w-]*?)([\d]+)$/); return parts && parts.length > 1 ? parts[1] : undefined; }

///|
/// Clips from morph target names grouped by pattern, like `Walk_001, Walk_002,
/// Run_001, Run_002`.
pub fn[T : MorphTarget] AnimationClip::create_clips_from_morph_target_sequences(
  morph_targets : Array[T],
  fps : Double,
  no_loop : Bool,
) -> Array[AnimationClip] {
  let animation_to_morph_targets : Map[String, Array[T]] = Map([])

  // sort morph target names into animation groups based
  // patterns like Walk_001, Walk_002, Run_001, Run_002
  let il = morph_targets.length()
  for i = 0; i < il; i = i + 1 {
    let morph_target = morph_targets[i]
    let parts = js_morph_sequence_name(morph_target.morph_target_name())
    if !parts.is_undefined() {
      let name : String = parts.cast()
      match animation_to_morph_targets.get(name) {
        Some(targets) => targets.push(morph_target)
        None => animation_to_morph_targets[name] = [morph_target]
      }
    }
  }
  let clips = []
  for name, targets in animation_to_morph_targets {
    clips.push(
      AnimationClip::create_from_morph_target_sequence(
        name, targets, fps, no_loop,
      ),
    )
  }
  clips
}

///|
/// Sets the duration to that of the longest track.
pub fn AnimationClip::reset_duration(self : AnimationClip) -> AnimationClip {
  let tracks = self.tracks
  let mut duration = 0.0
  let n = tracks.length()
  for i = 0; i != n; i = i + 1 {
    let track = self.tracks[i]
    duration = js_math_max(duration, track.times[track.times.length() - 1])
  }
  self.duration = duration
  self
}

///|
pub fn AnimationClip::trim(self : AnimationClip) -> AnimationClip {
  for i = 0; i < self.tracks.length(); i = i + 1 {
    self.tracks[i].trim(0.0, self.duration) |> ignore
  }
  self
}

///|
pub fn AnimationClip::validate(self : AnimationClip) -> Bool {
  let mut valid = true
  for i = 0; i < self.tracks.length(); i = i + 1 {
    valid = valid && self.tracks[i].validate()
  }
  valid
}

///|
pub fn AnimationClip::optimize(self : AnimationClip) -> AnimationClip {
  for i = 0; i < self.tracks.length(); i = i + 1 {
    self.tracks[i].optimize() |> ignore
  }
  self
}

///|
pub fn AnimationClip::clone(self : AnimationClip) -> AnimationClip {
  let tracks = []
  for i = 0; i < self.tracks.length(); i = i + 1 {
    tracks.push(self.tracks[i].clone())
  }
  let clip = AnimationClip::new(
    name=self.name,
    duration=self.duration,
    tracks~,
    blend_mode=self.blend_mode,
  )
  clip.user_data = js_json_parse(js_json_stringify(self.user_data))
  clip
}
