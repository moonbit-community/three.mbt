// Upstream src/animation/AnimationMixer.js. Upstream keys its caches by uuid and track
// name in plain objects and iterates them with `for ... in`; `Map` keeps the same
// insertion order (keys are uuids and track names, not array indices).

///|
let animation_mixer_control_interpolants_result_buffer : Array[Double] = float32_buffer(
  1,
)

///|
/// `actionsByClip[ clipUuid ]`.
pub(all) struct ActionsForClip {
  known_actions : Array[AnimationAction]
  action_by_root : Map[String, AnimationAction]
}

///|
/// A player for animations on an object or an `AnimationObjectGroup`.
pub(all) struct AnimationMixer {
  dispatcher : @core.EventDispatcher
  _root : AnimationRoot
  mut _accu_index : Int32
  mut time : Double
  mut time_scale : Double
  /// 'nActiveActions' followed by inactive ones.
  /// Like `_bindings`, may gain holes.
  _actions : Array[AnimationAction?]
  mut _n_active_actions : Int32
  _actions_by_clip : Map[String, ActionsForClip]
  /// 'nActiveBindings' followed by inactive ones.
  /// Upstream's plain array can gain holes (see `mixer_slot_set`); `None` is a hole.
  _bindings : Array[PropertyMixer?]
  mut _n_active_bindings : Int32
  _bindings_by_root_and_name : Map[String, Map[String, PropertyMixer]]
  _control_interpolants : Array[ControlInterpolant]
  mut _n_active_control_interpolants : Int32
}

///|
pub fn[R : ToAnimationRoot] AnimationMixer::new(root : R) -> AnimationMixer {
  {
    dispatcher: @core.EventDispatcher::new(),
    _root: root.to_animation_root(),
    _accu_index: 0,
    time: 0.0,
    time_scale: 1.0,
    _actions: [],
    _n_active_actions: 0,
    _actions_by_clip: Map([]),
    _bindings: [],
    _n_active_bindings: 0,
    _bindings_by_root_and_name: Map([]),
    _control_interpolants: [],
    _n_active_control_interpolants: 0,
  }
}

///|
pub impl @core.EventSource for AnimationMixer with fn event_dispatcher(self) {
  self.dispatcher
}

///|
pub impl @core.EventSource for AnimationMixer with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend AnimationMixer with @core.EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
/// The mixer that dispatched an event (`event.target`).
pub fn AnimationMixer::from_event_target(
  target : @core.EventTarget,
) -> AnimationMixer? {
  match target {
    Other(value) => Some(value.cast())
    _ => None
  }
}

///|
fn AnimationMixer::_bind_action(
  self : AnimationMixer,
  action : AnimationAction,
  prototype_action : AnimationAction?,
) -> Unit {
  let root = match action._local_root {
    Some(root) => root
    None => self._root
  }
  let tracks = action._clip.tracks
  let n_tracks = tracks.length()
  let bindings = action._property_bindings
  let interpolants = action._interpolants
  let root_uuid = root.uuid()
  let bindings_by_root = self._bindings_by_root_and_name
  let bindings_by_name = match bindings_by_root.get(root_uuid) {
    Some(bindings_by_name) => bindings_by_name
    None => {
      let bindings_by_name = Map([])
      bindings_by_root[root_uuid] = bindings_by_name
      bindings_by_name
    }
  }
  for i = 0; i != n_tracks; i = i + 1 {
    let track = tracks[i]
    let track_name = track.name
    let binding = match bindings_by_name.get(track_name) {
      Some(binding) => {
        binding.reference_count += 1
        bindings[i] = Some(binding)
        binding
      }
      None => {
        if bindings[i] is Some(binding) {
          // existing binding, make sure the cache knows
          if binding._cache_index is None {
            binding.reference_count += 1
            self._add_inactive_binding(binding, root_uuid, track_name)
          }
          continue
        }
        let path = match prototype_action {
          Some(prototype) => prototype.binding_at(i).binding.parsed_path()
          None => None
        }
        let binding = PropertyMixer::new(
          PropertyBinding::create(root, track_name, parsed_path?=path),
          track.value_type_name,
          track.get_value_size().to_int(),
        )
        binding.reference_count += 1
        self._add_inactive_binding(binding, root_uuid, track_name)
        bindings[i] = Some(binding)
        binding
      }
    }
    interpolants[i].result_buffer = binding.buffer
  }
}

///|
fn AnimationMixer::_activate_action(
  self : AnimationMixer,
  action : AnimationAction,
) -> Unit {
  if !self._is_active_action(action) {
    if action._cache_index is None {
      // this action has been forgotten by the cache, but the user
      // appears to be still using it -> rebind
      let root_uuid = match action._local_root {
        Some(root) => root.uuid()
        None => self._root.uuid()
      }
      let clip_uuid = action._clip.uuid
      let actions_for_clip = self._actions_by_clip.get(clip_uuid)
      self._bind_action(action, actions_for_clip.map(a => a.known_actions[0]))
      self._add_inactive_action(action, clip_uuid, root_uuid)
    }
    let bindings = action._property_bindings

    // increment reference counts / sort out state
    let n = bindings.length()
    for i = 0; i != n; i = i + 1 {
      let binding = action.binding_at(i)
      let use_count = binding.use_count
      binding.use_count += 1
      if use_count == 0 {
        self._lend_binding(binding)
        binding.save_original_state()
      }
    }
    self._lend_action(action)
  }
}

///|
fn AnimationMixer::_deactivate_action(
  self : AnimationMixer,
  action : AnimationAction,
) -> Unit {
  if self._is_active_action(action) {
    let bindings = action._property_bindings

    // decrement reference counts / sort out state
    let n = bindings.length()
    for i = 0; i != n; i = i + 1 {
      let binding = action.binding_at(i)
      binding.use_count -= 1
      if binding.use_count == 0 {
        binding.restore_original_state()
        self._take_back_binding(binding)
      }
    }
    self._take_back_action(action)
  }
}

///|
/// `mixer.stats`.
pub(all) struct AnimationMixerStats {
  actions_total : Int32
  actions_in_use : Int32
  bindings_total : Int32
  bindings_in_use : Int32
  control_interpolants_total : Int32
  control_interpolants_in_use : Int32
}

///|
pub fn AnimationMixer::stats(self : AnimationMixer) -> AnimationMixerStats {
  {
    actions_total: self._actions.length(),
    actions_in_use: self._n_active_actions,
    bindings_total: self._bindings.length(),
    bindings_in_use: self._n_active_bindings,
    control_interpolants_total: self._control_interpolants.length(),
    control_interpolants_in_use: self._n_active_control_interpolants,
  }
}

// --- Memory management for AnimationAction objects ---------------------------------

///|
fn AnimationMixer::_is_active_action(
  self : AnimationMixer,
  action : AnimationAction,
) -> Bool {
  action._cache_index is Some(index) && index < self._n_active_actions
}

///|
fn AnimationMixer::_add_inactive_action(
  self : AnimationMixer,
  action : AnimationAction,
  clip_uuid : String,
  root_uuid : String,
) -> Unit {
  let actions = self._actions
  let actions_by_clip = self._actions_by_clip
  let actions_for_clip = match actions_by_clip.get(clip_uuid) {
    None => {
      let actions_for_clip = {
        known_actions: [action],
        action_by_root: Map([]),
      }
      action._by_clip_cache_index = Some(0)
      actions_by_clip[clip_uuid] = actions_for_clip
      actions_for_clip
    }
    Some(actions_for_clip) => {
      let known_actions = actions_for_clip.known_actions
      action._by_clip_cache_index = Some(known_actions.length())
      known_actions.push(action)
      actions_for_clip
    }
  }
  action._cache_index = Some(actions.length())
  actions.push(Some(action))
  actions_for_clip.action_by_root[root_uuid] = action
}

///|
fn AnimationMixer::_remove_inactive_action(
  self : AnimationMixer,
  action : AnimationAction,
) -> Unit {
  let actions = self._actions
  let last_inactive_action = actions.get(actions.length() - 1).bind(x => x)
  let cache_index = action._cache_index.unwrap()
  action_set_cache_index(last_inactive_action, cache_index)
  mixer_slot_set(actions, cache_index, last_inactive_action)
  actions.pop() |> ignore
  action._cache_index = None
  let clip_uuid = action._clip.uuid
  let actions_by_clip = self._actions_by_clip
  let actions_for_clip = actions_by_clip.get(clip_uuid).unwrap()
  let known_actions_for_clip = actions_for_clip.known_actions
  let last_known_action = known_actions_for_clip[known_actions_for_clip.length() -
    1]
  let by_clip_cache_index = action._by_clip_cache_index.unwrap()
  last_known_action._by_clip_cache_index = Some(by_clip_cache_index)
  known_actions_for_clip[by_clip_cache_index] = last_known_action
  known_actions_for_clip.pop() |> ignore
  action._by_clip_cache_index = None
  let action_by_root = actions_for_clip.action_by_root
  let root_uuid = match action._local_root {
    Some(root) => root.uuid()
    None => self._root.uuid()
  }
  action_by_root.remove(root_uuid)
  if known_actions_for_clip.length() == 0 {
    actions_by_clip.remove(clip_uuid)
  }
  self._remove_inactive_bindings_for_action(action)
}

///|
fn AnimationMixer::_remove_inactive_bindings_for_action(
  self : AnimationMixer,
  action : AnimationAction,
) -> Unit {
  let bindings = action._property_bindings
  let n = bindings.length()
  for i = 0; i != n; i = i + 1 {
    let binding = action.binding_at(i)
    binding.reference_count -= 1
    if binding.reference_count == 0 {
      self._remove_inactive_binding(binding)
    }
  }
}

///|
fn AnimationMixer::_lend_action(
  self : AnimationMixer,
  action : AnimationAction,
) -> Unit {
  // [ active actions |  inactive actions  ]
  // [  active actions >| inactive actions ]
  //                 s        a
  //                  <-swap->
  //                 a        s
  let actions = self._actions
  let prev_index = action._cache_index.unwrap()
  let last_active_index = self._n_active_actions
  self._n_active_actions += 1
  let first_inactive_action = actions.get(last_active_index).bind(x => x)
  action._cache_index = Some(last_active_index)
  mixer_slot_set(actions, last_active_index, Some(action))
  action_set_cache_index(first_inactive_action, prev_index)
  mixer_slot_set(actions, prev_index, first_inactive_action)
}

///|
fn AnimationMixer::_take_back_action(
  self : AnimationMixer,
  action : AnimationAction,
) -> Unit {
  // [  active actions  | inactive actions ]
  // [ active actions |< inactive actions  ]
  //        a        s
  //         <-swap->
  //        s        a
  let actions = self._actions
  let prev_index = action._cache_index.unwrap()
  self._n_active_actions -= 1
  let first_inactive_index = self._n_active_actions
  let last_active_action = actions.get(first_inactive_index).bind(x => x)
  action._cache_index = Some(first_inactive_index)
  mixer_slot_set(actions, first_inactive_index, Some(action))
  action_set_cache_index(last_active_action, prev_index)
  mixer_slot_set(actions, prev_index, last_active_action)
}

// --- Memory management for PropertyMixer objects -----------------------------------

///|
fn AnimationMixer::_add_inactive_binding(
  self : AnimationMixer,
  binding : PropertyMixer,
  root_uuid : String,
  track_name : String,
) -> Unit {
  let bindings_by_root = self._bindings_by_root_and_name
  let bindings = self._bindings
  let binding_by_name = match bindings_by_root.get(root_uuid) {
    Some(binding_by_name) => binding_by_name
    None => {
      let binding_by_name = Map([])
      bindings_by_root[root_uuid] = binding_by_name
      binding_by_name
    }
  }
  binding_by_name[track_name] = binding
  binding._cache_index = Some(bindings.length())
  bindings.push(Some(binding))
}

///|
/// `array[ index ] = value` on upstream's JS arrays: writing past the end grows it,
/// leaving holes. This happens when an uncached action plays again, as
/// `_removeInactiveBinding` leaves a stale `_cacheIndex` behind.
fn[T] mixer_slot_set(bindings : Array[T?], index : Int32, value : T?) -> Unit {
  while bindings.length() <= index {
    bindings.push(None)
  }
  bindings[index] = value
}

///|
/// `actions[ index ]._cacheIndex = value`, which throws on a hole.
fn action_set_cache_index(action : AnimationAction?, value : Int32) -> Unit {
  match action {
    Some(action) => action._cache_index = Some(value)
    None =>
      abort(
        "TypeError: Cannot set properties of undefined (setting '_cacheIndex')",
      )
  }
}

///|
/// `actions[ index ]` before a method call, which throws on a hole.
fn mixer_action_at(
  actions : Array[AnimationAction?],
  index : Int32,
  name : String,
) -> AnimationAction {
  match actions.get(index).bind(x => x) {
    Some(action) => action
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading '" +
        name +
        "')",
      )
  }
}

///|
/// `bindings[ index ]._cacheIndex = value`, which throws on a hole.
fn mixer_set_cache_index(binding : PropertyMixer?, value : Int32) -> Unit {
  match binding {
    Some(binding) => binding._cache_index = Some(value)
    None =>
      abort(
        "TypeError: Cannot set properties of undefined (setting '_cacheIndex')",
      )
  }
}

///|
fn AnimationMixer::_remove_inactive_binding(
  self : AnimationMixer,
  binding : PropertyMixer,
) -> Unit {
  let bindings = self._bindings
  let prop_binding = match binding.binding {
    Single(prop_binding) => prop_binding
    // upstream reads `binding.binding.rootNode.uuid`, which a Composite lacks
    Composite(_) =>
      abort("TypeError: Cannot read properties of undefined (reading 'uuid')")
  }
  let root_uuid = prop_binding.root_node.uuid
  let track_name = prop_binding.path
  let bindings_by_root = self._bindings_by_root_and_name
  let last_inactive_binding = bindings.get(bindings.length() - 1).bind(x => x)
  let cache_index = binding._cache_index.unwrap()
  mixer_set_cache_index(last_inactive_binding, cache_index)
  mixer_slot_set(bindings, cache_index, last_inactive_binding)
  bindings.pop() |> ignore
  match bindings_by_root.get(root_uuid) {
    Some(binding_by_name) => {
      binding_by_name.remove(track_name)
      if binding_by_name.length() == 0 {
        bindings_by_root.remove(root_uuid)
      }
    }
    None => abort("TypeError: Cannot convert undefined or null to object")
  }
}

///|
fn AnimationMixer::_lend_binding(
  self : AnimationMixer,
  binding : PropertyMixer,
) -> Unit {
  let bindings = self._bindings
  let prev_index = binding._cache_index.unwrap()
  let last_active_index = self._n_active_bindings
  self._n_active_bindings += 1
  let first_inactive_binding = bindings.get(last_active_index).bind(x => x)
  binding._cache_index = Some(last_active_index)
  mixer_slot_set(bindings, last_active_index, Some(binding))
  mixer_set_cache_index(first_inactive_binding, prev_index)
  mixer_slot_set(bindings, prev_index, first_inactive_binding)
}

///|
fn AnimationMixer::_take_back_binding(
  self : AnimationMixer,
  binding : PropertyMixer,
) -> Unit {
  let bindings = self._bindings
  let prev_index = binding._cache_index.unwrap()
  self._n_active_bindings -= 1
  let first_inactive_index = self._n_active_bindings
  let last_active_binding = bindings.get(first_inactive_index).bind(x => x)
  binding._cache_index = Some(first_inactive_index)
  mixer_slot_set(bindings, first_inactive_index, Some(binding))
  mixer_set_cache_index(last_active_binding, prev_index)
  mixer_slot_set(bindings, prev_index, last_active_binding)
}

// --- Memory management of Interpolants for weight and time scale -------------------

///|
fn AnimationMixer::_lend_control_interpolant(
  self : AnimationMixer,
) -> ControlInterpolant {
  let interpolants = self._control_interpolants
  let last_active_index = self._n_active_control_interpolants
  self._n_active_control_interpolants += 1
  match interpolants.get(last_active_index) {
    Some(interpolant) => interpolant
    None => {
      let interpolant = {
        interpolant: @math.LinearInterpolant::new(
          float32_buffer(2),
          float32_buffer(2),
          1,
          result_buffer=animation_mixer_control_interpolants_result_buffer,
        ),
        _cache_index: last_active_index,
      }
      interpolants.push(interpolant)
      interpolant
    }
  }
}

///|
fn AnimationMixer::_take_back_control_interpolant(
  self : AnimationMixer,
  interpolant : ControlInterpolant,
) -> Unit {
  let interpolants = self._control_interpolants
  let prev_index = interpolant._cache_index
  self._n_active_control_interpolants -= 1
  let first_inactive_index = self._n_active_control_interpolants
  let last_active_interpolant = interpolants[first_inactive_index]
  interpolant._cache_index = first_inactive_index
  interpolants[first_inactive_index] = interpolant
  last_active_interpolant._cache_index = prev_index
  interpolants[prev_index] = last_active_interpolant
}

// --- Public ------------------------------------------------------------------------

///|
fn AnimationMixer::clip_action_impl(
  self : AnimationMixer,
  clip : AnimationClip?,
  clip_uuid : String,
  optional_root : AnimationRoot?,
  blend_mode : Int32?,
) -> AnimationAction? {
  let root = match optional_root {
    Some(root) => root
    None => self._root
  }
  let root_uuid = root.uuid()
  let mut clip_object = clip
  let actions_for_clip = self._actions_by_clip.get(clip_uuid)
  let mut prototype_action = None
  let blend_mode = match blend_mode {
    Some(blend_mode) => blend_mode
    None =>
      match clip_object {
        Some(clip) => clip.blend_mode
        None => @core.NormalAnimationBlendMode
      }
  }
  if actions_for_clip is Some(actions_for_clip) {
    if actions_for_clip.action_by_root.get(root_uuid) is Some(existing_action) &&
      existing_action.blend_mode == blend_mode {
      return Some(existing_action)
    }

    // we know the clip, so we don't have to parse all
    // the bindings again but can just copy
    let prototype = actions_for_clip.known_actions[0]
    prototype_action = Some(prototype)

    // also, take the clip from the prototype action
    if clip_object is None {
      clip_object = Some(prototype._clip)
    }
  }

  // clip must be known when specified via string
  guard clip_object is Some(clip_object) else { return None }

  // allocate all resources required to run it
  let new_action = AnimationAction::new(
    self,
    clip_object,
    local_root?=optional_root,
    blend_mode~,
  )
  self._bind_action(new_action, prototype_action)

  // and make the action known to the memory manager
  self._add_inactive_action(new_action, clip_uuid, root_uuid)
  Some(new_action)
}

///|
/// The action of `clip` on the mixer's root or `optional_root`, created when needed.
pub fn AnimationMixer::clip_action(
  self : AnimationMixer,
  clip : AnimationClip,
  optional_root? : AnimationRoot,
  blend_mode? : Int32,
) -> AnimationAction {
  self
  .clip_action_impl(Some(clip), clip.uuid, optional_root, blend_mode)
  .unwrap()
}

///|
/// Upstream's `clipAction` given a clip name, looked up in the root's `animations`.
pub fn AnimationMixer::clip_action_by_name(
  self : AnimationMixer,
  name : String,
  optional_root? : AnimationRoot,
  blend_mode? : Int32,
) -> AnimationAction? {
  let root = optional_root.unwrap_or(self._root)
  let clip = animation_mixer_find_by_name(root, name)
  let clip_uuid = match clip {
    Some(clip) => clip.uuid
    None => name
  }
  self.clip_action_impl(clip, clip_uuid, optional_root, blend_mode)
}

///|
fn animation_mixer_find_by_name(
  root : AnimationRoot,
  name : String,
) -> AnimationClip? {
  match root {
    Object3D(object) => AnimationClip::find_by_name_in_object(object, name)
    // a group has no `animations`
    Group(_) =>
      abort("TypeError: Cannot read properties of undefined (reading 'length')")
  }
}

///|
pub fn AnimationMixer::existing_action(
  self : AnimationMixer,
  clip : AnimationClip,
  optional_root? : AnimationRoot,
) -> AnimationAction? {
  self.existing_action_impl(clip.uuid, optional_root)
}

///|
pub fn AnimationMixer::existing_action_by_name(
  self : AnimationMixer,
  name : String,
  optional_root? : AnimationRoot,
) -> AnimationAction? {
  let root = optional_root.unwrap_or(self._root)
  let clip_uuid = match animation_mixer_find_by_name(root, name) {
    Some(clip) => clip.uuid
    None => name
  }
  self.existing_action_impl(clip_uuid, optional_root)
}

///|
fn AnimationMixer::existing_action_impl(
  self : AnimationMixer,
  clip_uuid : String,
  optional_root : AnimationRoot?,
) -> AnimationAction? {
  let root = optional_root.unwrap_or(self._root)
  match self._actions_by_clip.get(clip_uuid) {
    Some(actions_for_clip) => actions_for_clip.action_by_root.get(root.uuid())
    None => None
  }
}

///|
pub fn AnimationMixer::stop_all_action(self : AnimationMixer) -> AnimationMixer {
  let actions = self._actions
  let n_actions = self._n_active_actions
  for i = n_actions - 1; i >= 0; i = i - 1 {
    mixer_action_at(actions, i, "stop").stop() |> ignore
  }
  self
}

///|
/// Advances the global mixer time and updates the animation.
pub fn AnimationMixer::update(
  self : AnimationMixer,
  delta_time : Double,
) -> AnimationMixer {
  let delta_time = delta_time * self.time_scale
  let actions = self._actions
  let n_actions = self._n_active_actions
  self.time += delta_time
  let time = self.time
  let time_direction = js_math_sign(delta_time)
  self._accu_index = self._accu_index ^ 1
  let accu_index = self._accu_index

  // run active actions
  for i = 0; i != n_actions; i = i + 1 {
    let action = mixer_action_at(actions, i, "_update")
    action._update(time, delta_time, time_direction, accu_index)
  }

  // update scene graph
  let bindings = self._bindings
  let n_bindings = self._n_active_bindings
  for i = 0; i != n_bindings; i = i + 1 {
    match bindings.get(i).bind(x => x) {
      Some(binding) => binding.apply(accu_index)
      None =>
        abort(
          "TypeError: Cannot read properties of undefined (reading 'apply')",
        )
    }
  }
  self
}

///|
/// Sets the global mixer time and updates the animation.
pub fn AnimationMixer::set_time(
  self : AnimationMixer,
  time : Double,
) -> AnimationMixer {
  self.time = 0.0 // Zero out time attribute for AnimationMixer object;
  for i = 0; i < self._actions.length(); i = i + 1 {
    match self._actions[i] {
      Some(action) => action.time = 0.0
      None =>
        abort("TypeError: Cannot set properties of undefined (setting 'time')")
    } // Zero out time attribute for all associated AnimationAction objects.
  }
  self.update(time) // Update used to set exact time. Returns "this" AnimationMixer object.
}

///|
pub fn AnimationMixer::get_root(self : AnimationMixer) -> AnimationRoot {
  self._root
}

///|
/// Frees the resources of `clip`.
pub fn AnimationMixer::uncache_clip(
  self : AnimationMixer,
  clip : AnimationClip,
) -> Unit {
  let actions = self._actions
  let clip_uuid = clip.uuid
  let actions_by_clip = self._actions_by_clip
  if actions_by_clip.get(clip_uuid) is Some(actions_for_clip) {
    // note: just calling _removeInactiveAction would mess up the
    // iteration state and also require updating the state we can
    // just throw away
    let actions_to_remove = actions_for_clip.known_actions
    let n = actions_to_remove.length()
    for i = 0; i != n; i = i + 1 {
      let action = actions_to_remove[i]
      self._deactivate_action(action)
      let cache_index = action._cache_index.unwrap()
      let last_inactive_action = actions.get(actions.length() - 1).bind(x => x)
      action._cache_index = None
      action._by_clip_cache_index = None
      action_set_cache_index(last_inactive_action, cache_index)
      mixer_slot_set(actions, cache_index, last_inactive_action)
      actions.pop() |> ignore
      self._remove_inactive_bindings_for_action(action)
    }
    actions_by_clip.remove(clip_uuid)
  }
}

///|
/// Frees the resources of `root`.
pub fn[R : ToAnimationRoot] AnimationMixer::uncache_root(
  self : AnimationMixer,
  root : R,
) -> Unit {
  let root_uuid = root.to_animation_root().uuid()
  let actions_by_clip = self._actions_by_clip
  for clip_uuid in actions_by_clip.keys().collect() {
    guard actions_by_clip.get(clip_uuid) is Some(actions_for_clip) else {
      continue
    }
    if actions_for_clip.action_by_root.get(root_uuid) is Some(action) {
      self._deactivate_action(action)
      self._remove_inactive_action(action)
    }
  }
  let bindings_by_root = self._bindings_by_root_and_name
  if bindings_by_root.get(root_uuid) is Some(binding_by_name) {
    for track_name in binding_by_name.keys().collect() {
      guard binding_by_name.get(track_name) is Some(binding) else { continue }
      binding.restore_original_state()
      self._remove_inactive_binding(binding)
    }
  }
}

///|
/// Frees the resources of the action of `clip` on the root.
pub fn AnimationMixer::uncache_action(
  self : AnimationMixer,
  clip : AnimationClip,
  optional_root? : AnimationRoot,
) -> Unit {
  if self.existing_action(clip, optional_root?) is Some(action) {
    self._deactivate_action(action)
    self._remove_inactive_action(action)
  }
}

///|
/// `uncacheAction` given a clip name.
pub fn AnimationMixer::uncache_action_by_name(
  self : AnimationMixer,
  name : String,
  optional_root? : AnimationRoot,
) -> Unit {
  if self.existing_action_by_name(name, optional_root?) is Some(action) {
    self._deactivate_action(action)
    self._remove_inactive_action(action)
  }
}
