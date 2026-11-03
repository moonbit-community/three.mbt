// MoonBit side of the animation differential test: interprets a JSON scenario with the
// port and records every bound property after each step. run.mjs does the same with
// upstream three.js and compares the two logs.

///|
extern "js" fn js_array() -> @core.JsValue = "() => []"

///|
extern "js" fn js_push(a : @core.JsValue, v : @core.JsValue) -> Unit = "(a, v) => { a.push(v); }"

///|
let log_entries : Ref[@core.JsValue] = { val: js_array(), }

///|
fn log(label : String, values : Array[@core.JsValue]) -> Unit {
  let entry = js_array()
  js_push(entry, @core.JsValue::of(label))
  for v in values {
    js_push(entry, v)
  }
  js_push(log_entries.val, entry)
}

///|
fn n(x : Double) -> @core.JsValue {
  @core.JsValue::of(x)
}

///|
fn b(x : Bool) -> @core.JsValue {
  @core.JsValue::of(x)
}

///|
fn s(x : String) -> @core.JsValue {
  @core.JsValue::of(x)
}

///|
fn on(x : Double?) -> @core.JsValue {
  match x {
    Some(x) => n(x)
    None => @core.JsValue::null()
  }
}

// --- JSON access -------------------------------------------------------------------

///|
fn get(j : Json, k : String) -> Json? {
  match j {
    Object(m) => m.get(k)
    _ => None
  }
}

///|
fn num(j : Json) -> Double {
  match j {
    Number(x, ..) => x
    String("NaN") => @double.not_a_number
    _ => abort("not a number")
  }
}

///|
fn int(j : Json) -> Int32 {
  num(j).to_int()
}

///|
fn str(j : Json) -> String {
  match j {
    String(x) => x
    _ => abort("not a string")
  }
}

///|
fn arr(j : Json) -> Array[Json] {
  match j {
    Array(x) => x
    _ => abort("not an array")
  }
}

///|
fn nums(j : Json) -> Array[Double] {
  arr(j).map(num)
}

///|
fn get_num(j : Json, k : String, d : Double) -> Double {
  match get(j, k) {
    Some(Number(x, ..)) => x
    _ => d
  }
}

///|
fn get_bool(j : Json, k : String) -> Bool {
  get(j, k) is Some(True)
}

// --- Scene building ----------------------------------------------------------------

///|
struct World {
  materials : Array[@core.Material]
  objects : Array[@core.Object3D]
  roots : Array[@core.Object3D]
}

///|
fn build_material(spec : Json) -> @core.Material {
  let m = match str(get(spec, "type").unwrap()) {
    "MeshBasicMaterial" => @core.MeshBasicMaterial::new()
    "MeshStandardMaterial" => @core.MeshStandardMaterial::new()
    "MeshPhysicalMaterial" => @core.MeshPhysicalMaterial::new()
    "MeshPhongMaterial" => @core.MeshPhongMaterial::new()
    "SpriteMaterial" => @core.SpriteMaterial::new()
    "PointsMaterial" => @core.PointsMaterial::new()
    "LineBasicMaterial" => @core.LineBasicMaterial::new()
    "LineDashedMaterial" => @core.LineDashedMaterial::new()
    "MeshLambertMaterial" => @core.MeshLambertMaterial::new()
    t => abort("material " + t)
  }
  if get(spec, "name") is Some(String(name)) {
    m.name = name
  }
  if get_bool(spec, "map") {
    m.map = Some(@core.Texture::new())
  }
  m
}

///|
/// By the name given in the spec, which a string track may have changed since.
let names_at_build : Map[String, @core.Object3D] = Map([])

///|
fn find(_objects : Array[@core.Object3D], name : String) -> @core.Object3D {
  match names_at_build.get(name) {
    Some(o) => o
    None => abort("no object " + name)
  }
}

///|
fn build_node(
  world : World,
  spec : Json,
  skinned : Array[(@core.Object3D, Array[String])],
) -> @core.Object3D {
  let t = str(get(spec, "type").unwrap())
  let material = match get(spec, "material") {
    Some(Number(i, ..)) =>
      Some(@core.MaterialSlot::Single(world.materials[i.to_int()]))
    Some(Array(list)) =>
      Some(@core.MaterialSlot::Multiple(list.map(i => world.materials[int(i)])))
    _ => None
  }
  let geometry = @core.BufferGeometry::new()
  if get(spec, "morph") is Some(Array(names)) {
    let list = []
    for name in names {
      let attribute = @core.Float32BufferAttribute::new(
        [0.0, 0.0, 0.0, 1.0, 1.0, 1.0],
        3,
      )
      attribute.name = str(name)
      list.push(@core.GeometryAttribute::Buffer(attribute))
    }
    geometry.morph_attributes["position"] = list
  }
  let o = match t {
    "Object3D" => @core.Object3D::new()
    "Group" => @core.Group::new()
    "Bone" => @core.Bone::new()
    "Scene" => {
      let scene = @core.Scene::new()
      match get(spec, "fog") {
        Some(String("Fog")) =>
          scene.as_scene().fog = Some(
            Fog(
              @core.Fog::new(
                color=@math.Color::new(1.0, 1.0, 1.0),
                near=1.0,
                far=100.0,
              ),
            ),
          )
        Some(String("FogExp2")) =>
          scene.as_scene().fog = Some(
            FogExp2(
              @core.FogExp2::new(
                color=@math.Color::new(1.0, 1.0, 1.0),
                density=0.5,
              ),
            ),
          )
        _ => ()
      }
      scene
    }
    "Mesh" => @core.Mesh::new(geometry~, material?)
    "SkinnedMesh" => @core.SkinnedMesh::new(geometry~, material?)
    "Points" => @core.Points::new(geometry~, material?)
    "Line" => @core.Line::new(geometry~, material?)
    "LOD" => @core.LOD::new()
    "ClippingGroup" => @core.ClippingGroup::new()
    "RectAreaLight" => @core.RectAreaLight::new()
    "LightProbe" => @core.LightProbe::new()
    "Sprite" =>
      match material {
        Some(Single(m)) => @core.Sprite::new(material=m)
        _ => @core.Sprite::new()
      }
    "PointLight" =>
      @core.PointLight::new(
        color=@math.Color::new(1.0, 0.5, 0.25),
        intensity=2.0,
      )
    "SpotLight" => @core.SpotLight::new()
    "DirectionalLight" => @core.DirectionalLight::new()
    "HemisphereLight" => @core.HemisphereLight::new()
    "PerspectiveCamera" => @core.PerspectiveCamera::new(fov=50.0)
    "OrthographicCamera" => @core.OrthographicCamera::new()
    t => abort("node " + t)
  }
  if get(spec, "name") is Some(String(name)) {
    o.name = name
    names_at_build[name] = o
  }
  if get(spec, "uuid") is Some(String(uuid)) {
    o.uuid = uuid
  }
  if get_bool(spec, "spotMap") {
    match o.kind {
      Light({ kind: SpotLight(spot), .. }) =>
        spot.map = Some(@core.Texture::new())
      _ => ()
    }
  }
  if get(spec, "position") is Some(p) {
    o.position.from_array(nums(p)) |> ignore
  }
  if get(spec, "quaternion") is Some(q) {
    o.quaternion.from_array(nums(q)) |> ignore
  }
  if get(spec, "scale") is Some(p) {
    o.scale.from_array(nums(p)) |> ignore
  }
  world.objects.push(o)
  if get(spec, "children") is Some(Array(children)) {
    for child in children {
      o.add(build_node(world, child, skinned)) |> ignore
    }
  }
  if get(spec, "skeleton") is Some(Array(names)) {
    skinned.push((o, names.map(str)))
  }
  o
}

///|
fn build_world(spec : Json) -> World {
  let world = {
    materials: match get(spec, "materials") {
      Some(Array(list)) => list.map(build_material)
      _ => []
    },
    objects: [],
    roots: [],
  }
  let skinned = []
  for root in arr(get(spec, "roots").unwrap()) {
    world.roots.push(build_node(world, root, skinned))
  }
  for entry in skinned {
    let (mesh, names) = entry
    let bones = names.map(name => find(world.objects, name))
    mesh.bind(@core.Skeleton::new(bones~))
  }
  world
}

// --- Clips -------------------------------------------------------------------------

///|
fn build_track(spec : Json) -> @animation.KeyframeTrack {
  let name = str(get(spec, "name").unwrap())
  let times = nums(get(spec, "times").unwrap())
  let values = get(spec, "values").unwrap()
  let interpolation = match get(spec, "interpolation") {
    Some(Number(i, ..)) => Some(i.to_int())
    _ => None
  }
  let track = match str(get(spec, "type").unwrap()) {
    "number" =>
      @animation.NumberKeyframeTrack::new(
        name,
        times,
        nums(values),
        interpolation?,
      )
    "vector" =>
      @animation.VectorKeyframeTrack::new(
        name,
        times,
        nums(values),
        interpolation?,
      )
    "color" =>
      @animation.ColorKeyframeTrack::new(
        name,
        times,
        nums(values),
        interpolation?,
      )
    "quaternion" =>
      @animation.QuaternionKeyframeTrack::new(
        name,
        times,
        nums(values),
        interpolation?,
      )
    "base" =>
      @animation.KeyframeTrack::new(name, times, nums(values), interpolation?)
    "bool" =>
      @animation.BooleanKeyframeTrack::new(
        name,
        times,
        arr(values).map(v => v is True),
      )
    "string" =>
      @animation.StringKeyframeTrack::new(name, times, arr(values).map(str))
    t => abort("track " + t)
  }
  if get(spec, "settings") is Some(settings) {
    track.settings = Some(
      @animation.KeyframeTrackSettings::new(
        in_tangents=@core.TypedArray::float32(
          nums(get(settings, "inTangents").unwrap()),
        ),
        out_tangents=@core.TypedArray::float32(
          nums(get(settings, "outTangents").unwrap()),
        ),
      ),
    )
  }
  track
}

///|
fn build_clip(spec : Json) -> @animation.AnimationClip {
  let tracks = arr(get(spec, "tracks").unwrap()).map(build_track)
  let clip = @animation.AnimationClip::new(
    name=match get(spec, "name") {
      Some(String(x)) => x
      _ => ""
    },
    duration=get_num(spec, "duration", -1.0),
    tracks~,
    blend_mode=get_num(spec, "blendMode", 2500.0).to_int(),
  )
  clip
}

///|
extern "js" fn json_to_js(text : String) -> @core.JsValue = "(s) => JSON.parse(s)"

///|
fn log_clip(label : String, clip : @animation.AnimationClip) -> Unit {
  let uuid = clip.uuid
  clip.uuid = "fixed"
  // through a JS object, so number formatting is upstream's JSON.stringify
  log(label, [json_to_js(clip.to_json().stringify())])
  clip.uuid = uuid
}

///|
fn log_track_arrays(label : String, clip : @animation.AnimationClip) -> Unit {
  for i, track in clip.tracks {
    let values = match track.values {
      Numbers(v) => @core.JsValue::of(v)
      Booleans(v) => @core.JsValue::of(v.map(b))
      Strings(v) => @core.JsValue::of(v.map(s))
    }
    log(label + ".track" + i.to_string(), [
      s(track.name),
      @core.JsValue::of(track.times),
      values,
      n(track.get_value_size()),
      on(track.get_interpolation().map(x => x.to_double())),
    ])
  }
}

// --- Dumps -------------------------------------------------------------------------

///|
fn dump_object(o : @core.Object3D) -> Unit {
  let r = o.rotation
  log("obj " + o.name, [
    n(o.position.x),
    n(o.position.y),
    n(o.position.z),
    n(o.quaternion.x),
    n(o.quaternion.y),
    n(o.quaternion.z),
    n(o.quaternion.w),
    n(o.scale.x),
    n(o.scale.y),
    n(o.scale.z),
    n(r.x),
    n(r.y),
    n(r.z),
    s(r.order),
    b(o.visible),
    b(o.matrix_world_needs_update),
    b(o.cast_shadow),
    n(o.render_order),
    s(o.name),
  ])
  if o.morph_targets().1 is Some(influences) {
    log("morph " + o.name, influences.map(n))
  }
  match o.kind {
    Light(light) => {
      log("light " + o.name, [
        n(light.intensity),
        n(light.color.r),
        n(light.color.g),
        n(light.color.b),
      ])
      match light.kind {
        PointLight(p) => log("point " + o.name, [n(p.distance), n(p.decay)])
        SpotLight(p) =>
          log("spot " + o.name, [
            n(p.distance),
            n(p.decay),
            n(p.angle),
            n(p.penumbra),
          ])
        HemisphereLight(h) =>
          log("hemi " + o.name, [
            n(h.ground_color.r),
            n(h.ground_color.g),
            n(h.ground_color.b),
          ])
        _ => ()
      }
      match light.shadow {
        Some(shadow) =>
          log("shadow " + o.name, [n(shadow.bias), n(shadow.radius)])
        None => ()
      }
    }
    Camera({ kind: PerspectiveCamera(c), .. }) =>
      log("camera " + o.name, [n(c.fov), n(c.zoom), n(c.near), n(c.far)])
    Camera({ kind: OrthographicCamera(c), .. }) =>
      log("ortho " + o.name, [n(c.zoom), n(c.left), n(c.right), n(c.top)])
    Scene(scene) => {
      log("scene " + o.name, [
        n(scene.background_intensity),
        n(scene.background_blurriness),
      ])
      match scene.fog {
        Some(Fog(f)) => log("fog", [n(f.near), n(f.far), n(f.color.r)])
        Some(FogExp2(f)) => log("fog2", [n(f.density), n(f.color.g)])
        None => ()
      }
    }
    Sprite(sprite) =>
      log("sprite " + o.name, [n(sprite.center.x), n(sprite.center.y)])
    _ => ()
  }
}

///|
fn c3(c : @math.Color?) -> Array[@core.JsValue] {
  match c {
    Some(c) => [n(c.r), n(c.g), n(c.b)]
    None => [@core.JsValue::null()]
  }
}

///|
fn dump_material(i : Int32, m : @core.Material) -> Unit {
  let values = [
    n(m.opacity),
    b(m.transparent),
    b(m.visible),
    n(m.version.to_double()),
    n(m.alpha_test()),
    on(m.roughness),
    on(m.metalness),
    on(m.emissive_intensity),
    on(m.sheen()),
    on(m.shininess),
    on(m.size),
    s(m.name),
  ]
  values.append(c3(m.color))
  values.append(c3(m.emissive))
  match m.map {
    Some(t) =>
      values.append([
        n(t.offset.x),
        n(t.offset.y),
        n(t.repeat.x),
        n(t.repeat.y),
        n(t.rotation),
      ])
    None => ()
  }
  log("mat " + i.to_string(), values)
}

///|
fn dump_action(i : Int32, a : @animation.AnimationAction) -> Unit {
  log("action " + i.to_string(), [
    n(a.time),
    n(a.time_scale),
    n(a._effective_time_scale),
    n(a.weight),
    n(a._effective_weight),
    b(a.enabled),
    b(a.paused),
    n(a._loop_count),
    b(a.is_running()),
    b(a.is_scheduled()),
    n(a.repetitions),
    n(a.loop_.to_double()),
  ])
}

///|
fn dump(
  world : World,
  mixer : @animation.AnimationMixer,
  actions : Array[@animation.AnimationAction],
) -> Unit {
  for o in world.objects {
    dump_object(o)
  }
  for i, m in world.materials {
    dump_material(i, m)
  }
  for i, a in actions {
    dump_action(i, a)
  }
  let st = mixer.stats()
  match mixer.get_root() {
    Group(group) => {
      let st = group.stats()
      log("group", [
        n(st.objects_total.to_double()),
        n(st.objects_in_use.to_double()),
        n(st.bindings_per_object.to_double()),
      ])
    }
    _ => ()
  }
  log("mixer", [
    n(mixer.time),
    n(mixer.time_scale),
    n(st.actions_total.to_double()),
    n(st.actions_in_use.to_double()),
    n(st.bindings_total.to_double()),
    n(st.bindings_in_use.to_double()),
    n(st.control_interpolants_total.to_double()),
    n(st.control_interpolants_in_use.to_double()),
  ])
}

// --- Running -----------------------------------------------------------------------

///|
fn action_index(
  actions : Array[@animation.AnimationAction],
  a : @animation.AnimationAction,
) -> Int32 {
  for i, x in actions {
    if physical_equal(x, a) {
      return i
    }
  }
  -1
}

///|
fn run(spec : Json) -> Unit {
  let world = build_world(spec)
  let clips = match get(spec, "clips") {
    Some(Array(list)) => list.map(build_clip)
    _ => []
  }

  // clip operations
  if get(spec, "clipOps") is Some(Array(ops)) {
    for op in ops {
      let op = arr(op)
      match str(op[0]) {
        "makeAdditive" => {
          let target = clips[int(op[1])]
          let reference_clip = match op[3] {
            Null => None
            i => Some(clips[int(i)])
          }
          @animation.make_clip_additive(
            target,
            reference_frame=num(op[2]),
            reference_clip?,
            fps=num(op[4]),
          )
          |> ignore
        }
        "subclip" =>
          clips.push(
            @animation.subclip(
              clips[int(op[1])],
              str(op[2]),
              num(op[3]),
              num(op[4]),
              fps=num(op[5]),
            ),
          )
        "optimize" => clips[int(op[1])].optimize() |> ignore
        "trim" => clips[int(op[1])].trim() |> ignore
        "resetDuration" => clips[int(op[1])].reset_duration() |> ignore
        "validate" => log("validate", [b(clips[int(op[1])].validate())])
        "trackScale" =>
          clips[int(op[1])].tracks[int(op[2])].scale(num(op[3])) |> ignore
        "trackShift" =>
          clips[int(op[1])].tracks[int(op[2])].shift(num(op[3])) |> ignore
        "trackTrim" =>
          clips[int(op[1])].tracks[int(op[2])].trim(num(op[3]), num(op[4]))
          |> ignore
        "trackOptimize" =>
          clips[int(op[1])].tracks[int(op[2])].optimize() |> ignore
        "trackValidate" =>
          log("trackValidate", [
            b(clips[int(op[1])].tracks[int(op[2])].validate()),
          ])
        "trackInterpolation" =>
          clips[int(op[1])].tracks[int(op[2])].set_interpolation(int(op[3]))
          |> ignore
        "clone" => clips.push(clips[int(op[1])].clone())
        "roundTrip" => {
          let clip = clips[int(op[1])]
          clips[int(op[1])] = @animation.AnimationClip::parse(
            @json.parse(clip.to_json().stringify()) catch {
              _ => abort("json")
            },
          )
        }
        "fromMorph" =>
          clips.push(
            @animation.AnimationClip::create_from_morph_target_sequence(
              str(op[1]),
              arr(op[2]).map(str),
              num(op[3]),
              op[4] is True,
            ),
          )
        "fromMorphs" =>
          clips.append(
            @animation.AnimationClip::create_clips_from_morph_target_sequences(
              arr(op[1]).map(str),
              num(op[2]),
              op[3] is True,
            ),
          )
        "evaluate" => {
          let track = clips[int(op[1])].tracks[int(op[2])]
          let interpolant = track.create_interpolant()
          for t in arr(op[3]) {
            let result = interpolant.evaluate(num(t))
            log("eval", [n(num(t)), @core.JsValue::of(result)])
          }
        }
        "keyframeOrder" => {
          let order = @animation.get_keyframe_order(nums(op[1]))
          log("order", order.map(i => n(i.to_double())))
          log("sorted", [
            @core.JsValue::of(
              @animation.sorted_array(nums(op[2]), int(op[3]), order),
            ),
          ])
        }
        o => abort("clip op " + o)
      }
    }
  }
  for i, clip in clips {
    log_clip("clip " + i.to_string(), clip)
    log_track_arrays("clip " + i.to_string(), clip)
  }
  if get_bool(spec, "rootAnimations") {
    for clip in clips {
      world.roots[0].animations.push(clip.as_resource())
    }
  }
  if get(spec, "ops") is None {
    return
  }
  let group = match get(spec, "group") {
    Some(Array(names)) =>
      Some(
        @animation.AnimationObjectGroup::new(
          objects=names.map(name => find(world.objects, str(name))),
        ),
      )
    _ => None
  }
  let mixer = match group {
    Some(group) => @animation.AnimationMixer::new(group)
    _ => @animation.AnimationMixer::new(world.roots[0])
  }
  let actions : Array[@animation.AnimationAction] = []
  fn act(j : Json) -> @animation.AnimationAction {
    actions[int(j)]
  }

  for op in arr(get(spec, "ops").unwrap()) {
    let op = arr(op)
    match str(op[0]) {
      "action" => {
        let root : @animation.AnimationRoot? = match op.get(2) {
          Some(String(name)) => Some(Object3D(find(world.objects, name)))
          _ => None
        }
        let blend_mode = match op.get(3) {
          Some(Number(x, ..)) => Some(x.to_int())
          _ => None
        }
        let action = mixer.clip_action(
          clips[int(op[1])],
          optional_root?=root,
          blend_mode?,
        )
        log("actionIndex", [n(action_index(actions, action).to_double())])
        if action_index(actions, action) == -1 {
          actions.push(action)
        }
      }
      "actionByName" =>
        match mixer.clip_action_by_name(str(op[1])) {
          Some(action) => {
            log("actionIndex", [n(action_index(actions, action).to_double())])
            if action_index(actions, action) == -1 {
              actions.push(action)
            }
          }
          None => log("actionIndex", [@core.JsValue::null()])
        }
      "play" => act(op[1]).play() |> ignore
      "stop" => act(op[1]).stop() |> ignore
      "reset" => act(op[1]).reset() |> ignore
      "fadeIn" => act(op[1]).fade_in(num(op[2])) |> ignore
      "fadeOut" => act(op[1]).fade_out(num(op[2])) |> ignore
      "crossFadeTo" =>
        act(op[1]).cross_fade_to(act(op[2]), num(op[3]), warp=op[4] is True)
        |> ignore
      "crossFadeFrom" =>
        act(op[1]).cross_fade_from(act(op[2]), num(op[3]), warp=op[4] is True)
        |> ignore
      "setLoop" => {
        let reps = match op[3] {
          Null => @double.not_a_number
          String("Infinity") => @double.infinity
          x => num(x)
        }
        act(op[1]).set_loop(int(op[2]), repetitions=reps) |> ignore
      }
      "set" => {
        let a = act(op[1])
        let v = op[3]
        match str(op[2]) {
          "clampWhenFinished" => a.clamp_when_finished = v is True
          "zeroSlopeAtStart" => a.zero_slope_at_start = v is True
          "zeroSlopeAtEnd" => a.zero_slope_at_end = v is True
          "paused" => a.paused = v is True
          "enabled" => a.enabled = v is True
          "timeScale" => a.time_scale = num(v)
          "weight" => a.weight = num(v)
          "time" => a.time = num(v)
          f => abort("field " + f)
        }
      }
      "setEffectiveWeight" =>
        act(op[1]).set_effective_weight(num(op[2])) |> ignore
      "setEffectiveTimeScale" =>
        act(op[1]).set_effective_time_scale(num(op[2])) |> ignore
      "setDuration" => act(op[1]).set_duration(num(op[2])) |> ignore
      "syncWith" => act(op[1]).sync_with(act(op[2])) |> ignore
      "halt" => act(op[1]).halt(num(op[2])) |> ignore
      "warp" => act(op[1]).warp(num(op[2]), num(op[3]), num(op[4])) |> ignore
      "startAt" => act(op[1]).start_at(num(op[2])) |> ignore
      "stopFading" => act(op[1]).stop_fading() |> ignore
      "stopWarping" => act(op[1]).stop_warping() |> ignore
      "update" => mixer.update(num(op[1])) |> ignore
      "setTime" => mixer.set_time(num(op[1])) |> ignore
      "mixerTimeScale" => mixer.time_scale = num(op[1])
      "stopAllAction" => mixer.stop_all_action() |> ignore
      "uncacheClip" => mixer.uncache_clip(clips[int(op[1])])
      "uncacheRoot" =>
        match op.get(1) {
          Some(String(name)) => mixer.uncache_root(find(world.objects, name))
          _ => mixer.uncache_root(mixer.get_root())
        }
      "uncacheAction" => mixer.uncache_action(clips[int(op[1])])
      "groupAdd" =>
        group.unwrap().add(arr(op[1]).map(x => find(world.objects, str(x))))
      "groupRemove" =>
        group.unwrap().remove(arr(op[1]).map(x => find(world.objects, str(x))))
      "groupUncache" =>
        group.unwrap().uncache(arr(op[1]).map(x => find(world.objects, str(x))))
      "probe" => {
        let binding = @animation.PropertyBinding::new(
          world.roots[0],
          str(op[1]),
        )
        let buffer = Array::make(int(op[2]), 0.0)
        binding.get_value(buffer, 0)
        log("probe", [s(str(op[1])), @core.JsValue::of(buffer)])
      }
      "poke" => {
        let binding = @animation.PropertyBinding::new(
          world.roots[0],
          str(op[1]),
        )
        binding.set_value(nums(op[2]), 0)
      }
      "listen" => {
        let mode = str(op[2])
        mixer.add_event_listener(str(op[1]), event => {
          let action = @animation.animation_event_action(event).unwrap()
          let i = action_index(actions, action)
          let extra = match event.type_ {
            "loop" => on(@animation.animation_event_loop_delta(event))
            _ => on(@animation.animation_event_direction(event))
          }
          log("event", [s(event.type_), n(i.to_double()), extra, n(mixer.time)])
          if mode == "reverse" {
            action.time_scale *= -1.0
            action.paused = false
            action.start_at(mixer.time + 0.5).play() |> ignore
          }
        })
      }
      o => abort("op " + o)
    }
    log("op", [s(str(op[0]))])
    dump(world, mixer, actions)
  }
}

///|
pub fn run_scenario(text : String) -> @core.JsValue {
  log_entries.val = js_array()
  names_at_build.clear()
  let spec = @json.parse(text) catch { _ => abort("bad json") }
  run(spec)
  log_entries.val
}

///|
/// The log so far, after `run_scenario` aborted.
pub fn last_log() -> @core.JsValue {
  log_entries.val
}
