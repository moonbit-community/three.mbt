// Upstream src/animation/AnimationAction.js.

///|
/// A weight or time scale interpolant lent by the mixer, with its `__cacheIndex`.
pub(all) struct ControlInterpolant {
  interpolant : @math.Interpolant
  mut _cache_index : Int32
}

///|
/// Schedules the playback of an `AnimationClip` on a mixer.
pub(all) struct AnimationAction {
  _mixer : AnimationMixer
  _clip : AnimationClip
  _local_root : AnimationRoot?
  mut blend_mode : Int32
  _interpolant_settings : @math.InterpolantSettings
  /// Bound by the mixer.
  _interpolants : Array[@math.Interpolant]
  /// Managed by the mixer.
  _property_bindings : Array[PropertyMixer?]
  /// For the memory manager.
  mut _cache_index : Int32?
  mut _by_clip_cache_index : Int32?
  mut _time_scale_interpolant : ControlInterpolant?
  mut _restore_time_scale : Double?
  mut _weight_interpolant : ControlInterpolant?
  mut loop_ : Int32
  mut _loop_count : Double
  /// Global mixer time when the action is to be started; `None` once it started.
  mut _start_time : Double?
  mut time : Double
  mut time_scale : Double
  mut _effective_time_scale : Double
  mut weight : Double
  mut _effective_weight : Double
  mut repetitions : Double
  mut paused : Bool
  mut enabled : Bool
  mut clamp_when_finished : Bool
  mut zero_slope_at_start : Bool
  mut zero_slope_at_end : Bool
}

///|
/// Use `AnimationMixer::clip_action` instead, which binds the action.
pub fn AnimationAction::new(
  mixer : AnimationMixer,
  clip : AnimationClip,
  local_root? : AnimationRoot,
  blend_mode? : Int32,
) -> AnimationAction {
  let blend_mode = blend_mode.unwrap_or(clip.blend_mode)
  let tracks = clip.tracks
  let n_tracks = tracks.length()
  let interpolant_settings = @math.InterpolantSettings::new(
    ending_start=@math.ZeroCurvatureEnding,
    ending_end=@math.ZeroCurvatureEnding,
  )
  let interpolants = []
  for i = 0; i != n_tracks; i = i + 1 {
    let interpolant = tracks[i].create_interpolant()
    interpolants.push(interpolant)
    interpolant.settings = Some(interpolant_settings)
  }
  {
    _mixer: mixer,
    _clip: clip,
    _local_root: local_root,
    blend_mode,
    _interpolant_settings: interpolant_settings,
    _interpolants: interpolants,
    _property_bindings: Array::make(n_tracks, None),
    _cache_index: None,
    _by_clip_cache_index: None,
    _time_scale_interpolant: None,
    _restore_time_scale: None,
    _weight_interpolant: None,
    loop_: @core.LoopRepeat,
    _loop_count: -1.0,
    _start_time: None,
    time: 0.0,
    time_scale: 1.0,
    _effective_time_scale: 1.0,
    weight: 1.0,
    _effective_weight: 1.0,
    repetitions: @double.infinity,
    paused: false,
    enabled: true,
    clamp_when_finished: false,
    zero_slope_at_start: true,
    zero_slope_at_end: true,
  }
}

///|
fn AnimationAction::binding_at(
  self : AnimationAction,
  i : Int32,
) -> PropertyMixer {
  match self._property_bindings[i] {
    Some(binding) => binding
    None => abort("TypeError: Cannot read properties of undefined")
  }
}

///|
/// Starts the action.
pub fn AnimationAction::play(self : AnimationAction) -> AnimationAction {
  self._mixer._activate_action(self)
  self
}

///|
pub fn AnimationAction::stop(self : AnimationAction) -> AnimationAction {
  self._mixer._deactivate_action(self)
  self.reset()
}

///|
pub fn AnimationAction::reset(self : AnimationAction) -> AnimationAction {
  self.paused = false
  self.enabled = true
  self.time = 0.0 // restart clip
  self._loop_count = -1.0 // forget previous loops
  self._start_time = None // forget scheduling
  self.stop_fading().stop_warping()
}

///|
pub fn AnimationAction::is_running(self : AnimationAction) -> Bool {
  self.enabled &&
  !self.paused &&
  self.time_scale != 0.0 &&
  self._start_time is None &&
  self._mixer._is_active_action(self)
}

///|
pub fn AnimationAction::is_scheduled(self : AnimationAction) -> Bool {
  self._mixer._is_active_action(self)
}

///|
pub fn AnimationAction::start_at(
  self : AnimationAction,
  time : Double,
) -> AnimationAction {
  self._start_time = Some(time)
  self
}

///|
/// `repetitions` defaults to upstream's `undefined`, which compares as NaN.
pub fn AnimationAction::set_loop(
  self : AnimationAction,
  mode : Int32,
  repetitions~ : Double = @double.not_a_number,
) -> AnimationAction {
  self.loop_ = mode
  self.repetitions = repetitions
  self
}

///|
pub fn AnimationAction::set_effective_weight(
  self : AnimationAction,
  weight : Double,
) -> AnimationAction {
  self.weight = weight

  // note: same logic as when updated at runtime
  self._effective_weight = if self.enabled { weight } else { 0.0 }
  self.stop_fading()
}

///|
pub fn AnimationAction::get_effective_weight(self : AnimationAction) -> Double {
  self._effective_weight
}

///|
pub fn AnimationAction::fade_in(
  self : AnimationAction,
  duration : Double,
) -> AnimationAction {
  self._schedule_fading(duration, 0.0, 1.0)
}

///|
pub fn AnimationAction::fade_out(
  self : AnimationAction,
  duration : Double,
) -> AnimationAction {
  self._schedule_fading(duration, 1.0, 0.0)
}

///|
pub fn AnimationAction::cross_fade_from(
  self : AnimationAction,
  fade_out_action : AnimationAction,
  duration : Double,
  warp~ : Bool = false,
) -> AnimationAction {
  fade_out_action.fade_out(duration) |> ignore
  self.fade_in(duration) |> ignore
  if warp {
    let fade_in_duration = self._clip.duration
    let fade_out_duration = fade_out_action._clip.duration
    let start_end_ratio = fade_out_duration / fade_in_duration
    let end_start_ratio = fade_in_duration / fade_out_duration
    fade_out_action._restore_time_scale = Some(fade_out_action.time_scale)
    self._restore_time_scale = Some(self.time_scale)
    fade_out_action.warp(1.0, start_end_ratio, duration) |> ignore
    self.warp(end_start_ratio, 1.0, duration) |> ignore
  }
  self
}

///|
pub fn AnimationAction::cross_fade_to(
  self : AnimationAction,
  fade_in_action : AnimationAction,
  duration : Double,
  warp~ : Bool = false,
) -> AnimationAction {
  fade_in_action.cross_fade_from(self, duration, warp~)
}

///|
pub fn AnimationAction::stop_fading(self : AnimationAction) -> AnimationAction {
  if self._weight_interpolant is Some(weight_interpolant) {
    self._weight_interpolant = None
    self._mixer._take_back_control_interpolant(weight_interpolant)
  }
  self
}

///|
pub fn AnimationAction::set_effective_time_scale(
  self : AnimationAction,
  time_scale : Double,
) -> AnimationAction {
  self.time_scale = time_scale
  self._effective_time_scale = if self.paused { 0.0 } else { time_scale }
  self.stop_warping()
}

///|
pub fn AnimationAction::get_effective_time_scale(
  self : AnimationAction,
) -> Double {
  self._effective_time_scale
}

///|
pub fn AnimationAction::set_duration(
  self : AnimationAction,
  duration : Double,
) -> AnimationAction {
  self.time_scale = self._clip.duration / duration
  self.stop_warping()
}

///|
pub fn AnimationAction::sync_with(
  self : AnimationAction,
  action : AnimationAction,
) -> AnimationAction {
  self.time = action.time
  self.time_scale = action.time_scale
  self.stop_warping()
}

///|
pub fn AnimationAction::halt(
  self : AnimationAction,
  duration : Double,
) -> AnimationAction {
  self.warp(self._effective_time_scale, 0.0, duration)
}

///|
pub fn AnimationAction::warp(
  self : AnimationAction,
  start_time_scale : Double,
  end_time_scale : Double,
  duration : Double,
) -> AnimationAction {
  let mixer = self._mixer
  let now = mixer.time
  let time_scale = self.time_scale
  let interpolant = match self._time_scale_interpolant {
    Some(interpolant) => interpolant
    None => {
      let interpolant = mixer._lend_control_interpolant()
      self._time_scale_interpolant = Some(interpolant)
      interpolant
    }
  }
  let times = interpolant.interpolant.parameter_positions
  let values = interpolant.interpolant.sample_values
  times[0] = now
  times[1] = now + duration
  values[0] = start_time_scale / time_scale
  values[1] = end_time_scale / time_scale
  self
}

///|
pub fn AnimationAction::stop_warping(self : AnimationAction) -> AnimationAction {
  if self._time_scale_interpolant is Some(time_scale_interpolant) {
    self._time_scale_interpolant = None
    self._mixer._take_back_control_interpolant(time_scale_interpolant)
  }
  self._restore_time_scale = None
  self
}

///|
pub fn AnimationAction::get_mixer(self : AnimationAction) -> AnimationMixer {
  self._mixer
}

///|
pub fn AnimationAction::get_clip(self : AnimationAction) -> AnimationClip {
  self._clip
}

///|
pub fn AnimationAction::get_root(self : AnimationAction) -> AnimationRoot {
  match self._local_root {
    Some(root) => root
    None => self._mixer._root
  }
}

// --- Internal ----------------------------------------------------------------------

///|
/// Called by the mixer.
pub fn AnimationAction::_update(
  self : AnimationAction,
  time : Double,
  delta_time : Double,
  time_direction : Double,
  accu_index : Int32,
) -> Unit {
  if !self.enabled {
    // call ._updateWeight() to update ._effectiveWeight
    self._update_weight(time) |> ignore
    return
  }
  let mut delta_time = delta_time
  if self._start_time is Some(start_time) {
    // check for scheduled start of action
    let time_running = (time - start_time) * time_direction
    if time_running < 0.0 || time_direction == 0.0 {
      delta_time = 0.0
    } else {
      self._start_time = None // unschedule
      delta_time = time_direction * time_running
    }
  }

  // apply time scale and advance time
  delta_time *= self._update_time_scale(time)
  let clip_time = self._update_time(delta_time)

  // note: _updateTime may disable the action resulting in
  // an effective weight of 0
  let weight = self._update_weight(time)
  if weight > 0.0 {
    let interpolants = self._interpolants
    if self.blend_mode == @core.AdditiveAnimationBlendMode {
      let m = interpolants.length()
      for j = 0; j != m; j = j + 1 {
        interpolants[j].evaluate(clip_time) |> ignore
        self.binding_at(j).accumulate_additive(weight)
      }
    } else {
      let m = interpolants.length()
      for j = 0; j != m; j = j + 1 {
        interpolants[j].evaluate(clip_time) |> ignore
        self.binding_at(j).accumulate(accu_index, weight)
      }
    }
  }
}

///|
pub fn AnimationAction::_update_weight(
  self : AnimationAction,
  time : Double,
) -> Double {
  let mut weight = 0.0
  if self.enabled {
    weight = self.weight
    if self._weight_interpolant is Some(interpolant) {
      let interpolant_value = interpolant.interpolant.evaluate(time)[0]
      weight *= interpolant_value
      if time > interpolant.interpolant.parameter_positions[1] {
        self.stop_fading() |> ignore
        if interpolant_value == 0.0 {
          // faded out, disable
          self.enabled = false
        }
      }
    }
  }
  self._effective_weight = weight
  weight
}

///|
pub fn AnimationAction::_update_time_scale(
  self : AnimationAction,
  time : Double,
) -> Double {
  let mut time_scale = 0.0
  if !self.paused {
    time_scale = self.time_scale
    if self._time_scale_interpolant is Some(interpolant) {
      let interpolant_value = interpolant.interpolant.evaluate(time)[0]
      time_scale *= interpolant_value
      if time > interpolant.interpolant.parameter_positions[1] {
        if time_scale == 0.0 {
          // motion has halted, pause
          self.paused = true
        } else {
          if self._restore_time_scale is Some(restore) {
            time_scale = restore
          }

          // warp done - apply final time scale
          self.time_scale = time_scale
        }
        self.stop_warping() |> ignore
      }
    }
  }
  self._effective_time_scale = time_scale
  time_scale
}

///|
fn AnimationAction::dispatch_finished(
  self : AnimationAction,
  direction : Double,
) -> Unit {
  let data = @core.JsValue::object()
  data.set("action", @core.JsValue::of(self))
  data.set("direction", @core.JsValue::of(direction))
  self._mixer.dispatch_event(@core.Event::new("finished", data~))
}

///|
pub fn AnimationAction::_update_time(
  self : AnimationAction,
  delta_time : Double,
) -> Double {
  let duration = self._clip.duration
  let loop_ = self.loop_
  let mut time = self.time + delta_time
  let mut loop_count = self._loop_count
  let ping_pong = loop_ == @core.LoopPingPong
  if delta_time == 0.0 {
    if loop_count == -1.0 {
      return time
    }
    return if ping_pong && js_and1(loop_count) == 1 {
      duration - time
    } else {
      time
    }
  }
  if loop_ == @core.LoopOnce {
    if loop_count == -1.0 {
      // just started
      self._loop_count = 0.0
      self._set_endings(true, true, false)
    }
    let mut stop = true
    if time >= duration {
      time = duration
    } else if time < 0.0 {
      time = 0.0
    } else {
      self.time = time
      stop = false
    }
    if stop {
      if self.clamp_when_finished {
        self.paused = true
      } else {
        self.enabled = false
      }
      self.time = time
      self.dispatch_finished(if delta_time < 0.0 { -1.0 } else { 1.0 })
    }
  } else { // repetitive Repeat or PingPong
    if loop_count == -1.0 {
      // just started
      if delta_time >= 0.0 {
        loop_count = 0.0
        self._set_endings(true, self.repetitions == 0.0, ping_pong)
      } else {
        // when looping in reverse direction, the initial
        // transition through zero counts as a repetition,
        // so leave loopCount at -1
        self._set_endings(self.repetitions == 0.0, true, ping_pong)
      }
    }
    if time >= duration || time < 0.0 {
      // wrap around
      let loop_delta = js_math_floor(time / duration) // signed
      time -= duration * loop_delta
      loop_count += js_math_abs(loop_delta)
      let pending = self.repetitions - loop_count
      if pending <= 0.0 {
        // have to stop (switch state, clamp time, fire event)
        if self.clamp_when_finished {
          self.paused = true
        } else {
          self.enabled = false
        }
        time = if delta_time > 0.0 { duration } else { 0.0 }
        self.time = time
        self.dispatch_finished(if delta_time > 0.0 { 1.0 } else { -1.0 })
      } else {
        // keep running
        if pending == 1.0 {
          // entering the last round
          let at_start = delta_time < 0.0
          self._set_endings(at_start, !at_start, ping_pong)
        } else {
          self._set_endings(false, false, ping_pong)
        }
        self._loop_count = loop_count
        self.time = time
        let data = @core.JsValue::object()
        data.set("action", @core.JsValue::of(self))
        data.set("loopDelta", @core.JsValue::of(loop_delta))
        self._mixer.dispatch_event(@core.Event::new("loop", data~))
      }
    } else {
      self._loop_count = loop_count
      self.time = time
    }
    if ping_pong && js_and1(loop_count) == 1 {
      // invert time for the "pong round"
      return duration - time
    }
  }
  time
}

///|
pub fn AnimationAction::_set_endings(
  self : AnimationAction,
  at_start : Bool,
  at_end : Bool,
  ping_pong : Bool,
) -> Unit {
  let settings = self._interpolant_settings
  if ping_pong {
    settings.ending_start = @math.ZeroSlopeEnding
    settings.ending_end = @math.ZeroSlopeEnding
  } else {
    // assuming for LoopOnce atStart == atEnd == true
    settings.ending_start = if at_start {
      if self.zero_slope_at_start {
        @math.ZeroSlopeEnding
      } else {
        @math.ZeroCurvatureEnding
      }
    } else {
      @math.WrapAroundEnding
    }
    settings.ending_end = if at_end {
      if self.zero_slope_at_end {
        @math.ZeroSlopeEnding
      } else {
        @math.ZeroCurvatureEnding
      }
    } else {
      @math.WrapAroundEnding
    }
  }
}

///|
pub fn AnimationAction::_schedule_fading(
  self : AnimationAction,
  duration : Double,
  weight_now : Double,
  weight_then : Double,
) -> AnimationAction {
  let mixer = self._mixer
  let now = mixer.time
  let interpolant = match self._weight_interpolant {
    Some(interpolant) => interpolant
    None => {
      let interpolant = mixer._lend_control_interpolant()
      self._weight_interpolant = Some(interpolant)
      interpolant
    }
  }
  let times = interpolant.interpolant.parameter_positions
  let values = interpolant.interpolant.sample_values
  times[0] = now
  values[0] = weight_now
  times[1] = now + duration
  values[1] = weight_then
  self
}

// --- Events ------------------------------------------------------------------------

///|
/// `event.action` of a mixer's `finished` or `loop` event.
pub fn animation_event_action(event : @core.Event) -> AnimationAction? {
  guard event.data is Some(data) else { return None }
  let action = data.get("action")
  if action.is_undefined() {
    None
  } else {
    Some(action.cast())
  }
}

///|
/// `event.direction` of a `finished` event.
pub fn animation_event_direction(event : @core.Event) -> Double? {
  guard event.data is Some(data) else { return None }
  let direction = data.get("direction")
  if direction.is_undefined() {
    None
  } else {
    Some(direction.cast())
  }
}

///|
/// `event.loopDelta` of a `loop` event.
pub fn animation_event_loop_delta(event : @core.Event) -> Double? {
  guard event.data is Some(data) else { return None }
  let delta = data.get("loopDelta")
  if delta.is_undefined() {
    None
  } else {
    Some(delta.cast())
  }
}
