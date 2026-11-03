// The MoonBit side of the audio_diff scenarios: each test drives the recording mock and
// ends with `emit_log`. harness/scenarios/<name>.mjs does the same steps on upstream, and
// harness/run_diff.mjs compares the two logs entry by entry.

///|
fn opt_node(node : @audio.AudioNode?) -> @core.JsValue {
  match node {
    Some(node) => node.to_js()
    None => @core.JsValue::undefined()
  }
}

///|
fn null_node(node : @audio.AudioNode?) -> @core.JsValue {
  match node {
    Some(node) => node.to_js()
    None => @core.JsValue::null()
  }
}

///|
test "diff: context_lazy" {
  let ctx = mock_audio()
  @audio.AudioContext::set_context(
    @audio.AudioContext::of_js(@core.JsValue::undefined()),
  )
  ffi_install_window(ctx, "standard")
  let a = @audio.AudioContext::get_context()
  let b = @audio.AudioContext::get_context()
  note_bool(ctx, "same", ffi_same(a.to_js(), b.to_js()))
  note_bool(ctx, "isMock", ffi_same(a.to_js(), ctx.to_js()))
  @audio.AudioContext::set_context(
    @audio.AudioContext::of_js(@core.JsValue::undefined()),
  )
  ffi_install_window(ctx, "webkit")
  let c = @audio.AudioContext::get_context()
  note_bool(ctx, "webkit", ffi_same(c.to_js(), ctx.to_js()))
  @audio.AudioContext::set_context(ctx)
  let listener = @audio.AudioListener::new()
  note_bool(
    ctx,
    "listener.context",
    ffi_same(listener.context.to_js(), ctx.to_js()),
  )
  note_str(ctx, "type", listener.object.type_)
  let log = emit_log("context_lazy", ctx)
  assert_true(log.contains("new window.AudioContext()"))
  assert_true(log.contains("new window.webkitAudioContext()"))
}

///|
test "diff: listener_params" {
  let ctx = mock_audio()
  let listener = @audio.AudioListener::new()
  note_str(ctx, "type", listener.object.type_)
  note_num(ctx, "timeDelta", listener.time_delta)
  let camera = @core.Object3D::new()
  ignore(camera.add(listener.object))
  ignore(camera.position.set(1, 2, 3))
  ignore(camera.rotation.set(0.3, -0.7, 0.1))
  ignore(listener.object.position.set(0.5, 0, -0.25))
  ffi_set_time(ctx, 0.5)
  ffi_set_now(ctx, 16)
  camera.update_matrix_world()
  note_num(ctx, "timeDelta", listener.time_delta)
  ffi_set_time(ctx, 1.25)
  ffi_set_now(ctx, 48.5)
  ignore(listener.object.rotate_y(0.4))
  listener.update_matrix_world(force=true)
  note_num(ctx, "timeDelta", listener.time_delta)
  note_num(ctx, "getMasterVolume", listener.get_master_volume())
  ignore(listener.set_master_volume(0.3))
  note(ctx, "getInput", listener.get_input().as_node().to_js())
  let f1 = ffi_create_filter(ctx)
  let f2 = ffi_create_filter(ctx)
  ignore(listener.set_filter(f1))
  ignore(listener.set_filter(f2))
  note(ctx, "getFilter", null_node(listener.get_filter()))
  ignore(listener.remove_filter())
  ignore(listener.remove_filter())
  note(ctx, "getFilter", null_node(listener.get_filter()))
  camera.update_matrix_world()
  note_num(ctx, "timeDelta", listener.time_delta)
  ignore(camera.scale.set(2, 0.5, -1))
  ffi_set_now(ctx, 1000.125)
  camera.update_matrix_world()
  note_num(ctx, "timeDelta", listener.time_delta)
  let log = emit_log("listener_params", ctx)
  assert_true(log.contains("note timeDelta 0.016"))
}

///|
test "diff: listener_legacy" {
  let ctx = mock_audio(options="{\"listenerParams\":false}")
  let listener = @audio.AudioListener::new()
  let parent = @core.Object3D::new()
  ignore(parent.add(listener.object))
  ignore(parent.quaternion.set(0.1, 0.2, 0.3, 0.9).normalize())
  ignore(parent.scale.set(1.5, 1.5, 1.5))
  ignore(listener.object.position.set(-4, 0.5, 7))
  ffi_set_time(ctx, 2)
  ffi_set_now(ctx, 5)
  parent.update_matrix_world()
  note_num(ctx, "timeDelta", listener.time_delta)
  listener.object.look_at_xyz(10, -3, 2)
  ffi_set_now(ctx, 21.75)
  parent.update_matrix_world()
  note_num(ctx, "timeDelta", listener.time_delta)
  ignore(emit_log("listener_legacy", ctx))
}

///|
test "diff: audio_playback" {
  let ctx = mock_audio()
  let listener = @audio.AudioListener::new()
  let sound = @audio.Audio::new(listener)
  note_str(ctx, "type", sound.object.type_)
  note_str(ctx, "sourceType", sound.source_type)
  let buffer = ffi_buffer(ctx, 4)
  ignore(sound.set_buffer(buffer))
  note_str(ctx, "sourceType", sound.source_type)
  ignore(sound.set_loop_start(0.5).set_loop_end(3.5))
  ffi_set_time(ctx, 1)
  ignore(sound.play(delay=0.25))
  note_state(ctx, "a", sound)
  ignore(sound.play())
  ffi_set_time(ctx, 2)
  ignore(sound.set_detune(100))
  ignore(sound.set_playback_rate(1.5))
  ignore(sound.set_loop(true))
  note_bool(ctx, "getLoop", sound.get_loop())
  ffi_set_time(ctx, 3.5)
  ignore(sound.pause())
  note_state(ctx, "b", sound)
  sound.offset = 0.125
  sound.duration = Some(2)
  ffi_set_time(ctx, 4)
  ignore(sound.play())
  ffi_set_time(ctx, 6.75)
  ignore(sound.pause())
  note_state(ctx, "c", sound)
  ignore(sound.set_loop(false))
  ignore(sound.play())
  ffi_end(ctx, sound.source.unwrap())
  note_state(ctx, "d", sound)
  ignore(sound.stop(delay=0.5))
  note_state(ctx, "e", sound)
  ignore(sound.set_volume(0.25))
  note_num(ctx, "getVolume", sound.get_volume())
  note_num(ctx, "getDetune", sound.get_detune())
  note_num(ctx, "getPlaybackRate", sound.get_playback_rate())
  ignore(sound.set_detune(-50))
  sound.duration = Some(0)
  ignore(sound.set_loop(true))
  ffi_set_time(ctx, 7)
  ignore(sound.play())
  ffi_set_time(ctx, 12.5)
  ignore(sound.pause())
  note_state(ctx, "f", sound)
  ignore(sound.pause())
  ffi_set_time(ctx, 13)
  ignore(sound.play(delay=1))
  ignore(sound.pause())
  note_state(ctx, "g", sound)
  ignore(sound.stop())
  note_state(ctx, "h", sound)
  sound.duration = Some(0.0 / 0.0)
  ffi_set_time(ctx, 20)
  ignore(sound.play())
  ffi_set_time(ctx, 26)
  ignore(sound.pause())
  note_state(ctx, "i", sound)
  let auto = @audio.Audio::new(listener)
  auto.autoplay = true
  ignore(auto.set_buffer(buffer))
  note_state(ctx, "auto", auto)
  let fresh = @audio.Audio::new(listener)
  ignore(fresh.stop())
  note_state(ctx, "fresh", fresh)
  let log = emit_log("audio_playback", ctx)
  assert_true(log.contains("warn THREE.Audio: Audio is already playing."))
}

///|
test "diff: audio_no_detune" {
  let ctx = mock_audio(options="{\"detune\":false}")
  let listener = @audio.AudioListener::new()
  let sound = @audio.Audio::new(listener)
  ignore(sound.set_buffer(ffi_buffer(ctx, 1.5)))
  sound.detune = 30
  ffi_set_time(ctx, 0.5)
  ignore(sound.play())
  ignore(sound.set_detune(12))
  ignore(sound.set_playback_rate(0.5))
  note_state(ctx, "a", sound)
  ignore(emit_log("audio_no_detune", ctx))
}

///|
test "diff: audio_filters" {
  let ctx = mock_audio()
  let listener = @audio.AudioListener::new()
  let sound = @audio.Audio::new(listener)
  let f1 = ffi_create_filter(ctx)
  let f2 = ffi_create_filter(ctx)
  let f3 = ffi_create_filter(ctx)
  let list = [f1, f2]
  ignore(sound.set_filters(value=list))
  list.push(f3)
  note(ctx, "filters", @core.JsValue::of(sound.get_filters()))
  note(ctx, "getFilter", opt_node(sound.get_filter()))
  ignore(sound.set_buffer(ffi_buffer(ctx, 2)))
  ignore(sound.play())
  ignore(sound.set_filters(value=[f3]))
  ignore(sound.set_filter(filter=f2))
  ignore(sound.set_filter())
  note(ctx, "getFilter", opt_node(sound.get_filter()))
  ignore(sound.set_filters(value=[f1, f2, f3]))
  ignore(sound.set_filters())
  note(ctx, "filters", @core.JsValue::of(sound.get_filters()))
  ignore(sound.disconnect())
  ignore(sound.disconnect())
  note_bool(ctx, "_connected", sound._connected)
  ignore(sound.connect())
  let list2 = [f1, f2]
  ignore(sound.set_filters(value=list2))
  list2.push(f3)
  note(ctx, "filters", @core.JsValue::of(sound.get_filters()))
  ignore(sound.set_filters(value=[f1, f2, f3]))
  ignore(sound.disconnect())
  ignore(sound.set_filters(value=[f2]))
  note(ctx, "filters", @core.JsValue::of(sound.get_filters()))
  ignore(emit_log("audio_filters", ctx))
}

///|
test "diff: audio_node_sources" {
  let ctx = mock_audio()
  let listener = @audio.AudioListener::new()
  let sound = @audio.Audio::new(listener)
  let osc = ffi_create_oscillator(ctx)
  ignore(sound.set_node_source(osc))
  note_str(ctx, "sourceType", sound.source_type)
  note_bool(ctx, "hasPlaybackControl", sound.has_playback_control)
  note(ctx, "source", null_node(sound.source))
  ignore(sound.play())
  ignore(sound.pause())
  ignore(sound.stop())
  ignore(sound.set_playback_rate(2))
  note_bool(ctx, "getLoop", sound.get_loop())
  ignore(sound.set_loop(true))
  ignore(sound.set_detune(5))
  note_num(ctx, "getDetune", sound.get_detune())
  let element = @audio.Audio::new(listener)
  ignore(element.set_media_element_source(ffi_media_element(ctx)))
  note_str(ctx, "sourceType", element.source_type)
  note(ctx, "source", null_node(element.source))
  let stream = @audio.Audio::new(listener)
  ignore(stream.set_media_stream_source(ffi_media_stream(ctx)))
  note_str(ctx, "sourceType", stream.source_type)
  ignore(stream.set_filters(value=[ffi_create_filter(ctx)]))
  ignore(stream.disconnect())
  let log = emit_log("audio_node_sources", ctx)
  assert_true(
    log.contains("warn THREE.Audio: this Audio has no playback control."),
  )
}

///|
test "diff: positional_params" {
  let ctx = mock_audio()
  let listener = @audio.AudioListener::new()
  let camera = @core.Object3D::new()
  ignore(camera.add(listener.object))
  ignore(camera.position.set(0, 1.5, 4))
  let pa = @audio.PositionalAudio::new(listener)
  note_str(ctx, "type", pa.object.type_)
  note_num(ctx, "getRefDistance", pa.get_ref_distance())
  note_num(ctx, "getRolloffFactor", pa.get_rolloff_factor())
  note_str(ctx, "getDistanceModel", pa.get_distance_model())
  note_num(ctx, "getMaxDistance", pa.get_max_distance())
  note(ctx, "getOutput", pa.get_output().to_js())
  ignore(
    pa
    .set_ref_distance(2.5)
    .set_rolloff_factor(0.75)
    .set_distance_model("linear")
    .set_max_distance(80)
    .set_directional_cone(90, 220, 0.2),
  )
  note_num(ctx, "getRefDistance", pa.get_ref_distance())
  note_num(ctx, "getRolloffFactor", pa.get_rolloff_factor())
  note_str(ctx, "getDistanceModel", pa.get_distance_model())
  note_num(ctx, "getMaxDistance", pa.get_max_distance())
  let scene = @core.Object3D::new()
  ignore(scene.add(camera))
  ignore(scene.add(pa.object))
  ignore(pa.object.position.set(3, 1, -2))
  ignore(pa.object.rotation.set(0.2, 1.1, -0.4))
  ffi_set_time(ctx, 0.5)
  ffi_set_now(ctx, 20)
  scene.update_matrix_world()
  ignore(pa.set_buffer(ffi_buffer(ctx, 3)))
  ignore(pa.play())
  ffi_set_time(ctx, 0.75)
  ffi_set_now(ctx, 36)
  scene.update_matrix_world()
  let f1 = ffi_create_filter(ctx)
  ignore(pa.set_filters(value=[f1]))
  ignore(pa.pause())
  note_state(ctx, "pa", pa)
  scene.update_matrix_world()
  ignore(pa.disconnect())
  ignore(pa.disconnect())
  let pa2 = @audio.PositionalAudio::new(listener)
  ignore(pa2.set_node_source(ffi_create_oscillator(ctx)))
  ignore(scene.add(pa2.object))
  ignore(pa2.object.position.set(-1, -2, -3))
  ffi_set_time(ctx, 1)
  ffi_set_now(ctx, 52.5)
  scene.update_matrix_world()
  pa2.update_matrix_world(force=true)
  ignore(emit_log("positional_params", ctx))
}

///|
test "diff: positional_legacy" {
  let ctx = mock_audio(
    options="{\"listenerParams\":false,\"pannerParams\":false}",
  )
  let listener = @audio.AudioListener::new()
  let root = @core.Object3D::new()
  ignore(root.add(listener.object))
  let pa = @audio.PositionalAudio::new(listener)
  ignore(root.add(pa.object))
  ignore(pa.object.position.set(5, 0.25, -1))
  ignore(pa.object.quaternion.set(0.3, -0.5, 0.1, 0.8).normalize())
  ignore(pa.object.scale.set(1, -2, 0.5))
  ignore(pa.set_buffer(ffi_buffer(ctx, 10)))
  ffi_set_time(ctx, 3)
  ffi_set_now(ctx, 100)
  ignore(pa.play())
  root.update_matrix_world()
  pa.object.look_at_xyz(0, 0, 0)
  root.update_matrix_world(force=true)
  ignore(emit_log("positional_legacy", ctx))
}

///|
test "diff: analyser" {
  let ctx = mock_audio()
  let listener = @audio.AudioListener::new()
  let sound = @audio.Audio::new(listener)
  let an = @audio.AudioAnalyser::new(sound, fft_size=32)
  note(ctx, "data", @core.JsValue::of(an.data))
  note(ctx, "getFrequencyData", @core.JsValue::of(an.get_frequency_data()))
  note_num(ctx, "getAverageFrequency", an.get_average_frequency())
  let pa = @audio.PositionalAudio::new(listener)
  let an2 = @audio.AudioAnalyser::new(pa)
  note_num(ctx, "data.length", an2.data.length().to_double())
  note_num(ctx, "getAverageFrequency", an2.get_average_frequency())
  note_num(ctx, "getAverageFrequency", an.get_average_frequency())
  let an3 = @audio.AudioAnalyser::new(sound, fft_size=0)
  note_num(ctx, "getAverageFrequency", an3.get_average_frequency())
  ignore(emit_log("analyser", ctx))
}

///|
fn note_fields(
  ctx : @audio.AudioContext,
  label : String,
  a : @audio.Audio,
) -> Unit {
  note_str(ctx, label + ".type", a.object.type_)
  note_str(ctx, label + ".name", a.object.name)
  note_bool(ctx, label + ".autoplay", a.autoplay)
  note_num(ctx, label + ".detune", a.detune)
  note_bool(ctx, label + ".loop", a.loop_)
  note_num(ctx, label + ".loopStart", a.loop_start)
  note_num(ctx, label + ".loopEnd", a.loop_end)
  note_num(ctx, label + ".offset", a.offset)
  note(
    ctx,
    label + ".duration",
    match a.duration {
      Some(d) => @core.JsValue::of(d)
      None => @core.JsValue::undefined()
    },
  )
  note_num(ctx, label + ".playbackRate", a.playback_rate)
  note_bool(ctx, label + ".hasPlaybackControl", a.has_playback_control)
  note_str(ctx, label + ".sourceType", a.source_type)
  note_bool(ctx, label + ".isPlaying", a.is_playing)
  note(ctx, label + ".filters", @core.JsValue::of(a.filters))
  note(
    ctx,
    label + ".buffer",
    match a.buffer {
      Some(b) => b.to_js()
      None => @core.JsValue::null()
    },
  )
  note_num(ctx, label + ".position.x", a.object.position.x)
  note_num(ctx, label + ".children", a.object.children.length().to_double())
}

///|
test "diff: copy_clone" {
  let ctx = mock_audio()
  let listener = @audio.AudioListener::new()
  let sound = @audio.Audio::new(listener)
  let buffer = ffi_buffer(ctx, 5)
  let f1 = ffi_create_filter(ctx)
  ignore(sound.set_buffer(buffer))
  sound.detune = 10
  sound.loop_ = true
  sound.loop_start = 0.5
  sound.loop_end = 2
  sound.offset = 0.25
  sound.duration = Some(3)
  sound.playback_rate = 1.25
  ignore(sound.set_filters(value=[f1]))
  ignore(sound.object.position.set(1, 2, 3))
  sound.object.name = "snd"
  ignore(sound.object.add(@core.Object3D::new()))
  let c = sound.clone()
  note_fields(ctx, "c", c)
  note_bool(ctx, "c.filters copied", !physical_equal(c.filters, sound.filters))
  note_bool(ctx, "c.listener", physical_equal(c.listener, listener))
  let pa = @audio.PositionalAudio::new(listener)
  ignore(pa.set_buffer(buffer))
  ignore(pa.set_ref_distance(5))
  let pc = pa.clone()
  note_num(ctx, "pc.getRefDistance", pc.get_ref_distance())
  note_str(ctx, "pc.type", pc.object.type_)
  note(ctx, "pc.getOutput", pc.get_output().to_js())
  let node_audio = @audio.Audio::new(listener)
  ignore(node_audio.set_node_source(ffi_create_oscillator(ctx)))
  let target = @audio.Audio::new(listener)
  ignore(target.copy(node_audio))
  note_fields(ctx, "target", target)
  ignore(target.object.copy(@core.Object3D::new()))
  let lc = @audio.AudioListener::from_object(listener.object.clone()).unwrap()
  note_str(ctx, "lc.type", lc.object.type_)
  note_num(ctx, "lc.timeDelta", lc.time_delta)
  let c2 = sound.clone(recursive=false)
  note_num(ctx, "c2.children", c2.object.children.length().to_double())
  ignore(emit_log("copy_clone", ctx))
}
