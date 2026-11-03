// Upstream examples/jsm/utils/SkeletonUtils.js. The module's functions are static
// methods of the `SkeletonUtils` namespace type (`import * as SkeletonUtils`).

///|
/// The `SkeletonUtils` module namespace.
#external
pub type SkeletonUtils

///|
extern "js" fn sku_math_round(x : Double) -> Double = "Math.round"

///|
extern "js" fn sku_math_min(a : Double, b : Double) -> Double = "Math.min"

///|
extern "js" fn sku_math_max(a : Double, b : Double) -> Double = "Math.max"

///|
extern "js" fn sku_neg_infinity() -> Double = "() => -Infinity"

///|
/// What `retarget` accepts for `target` and `source`: an object with a `skeleton` (a
/// `SkinnedMesh`) or a `Skeleton`.
pub(all) enum SkeletonRef {
  Object(@core.Object3D)
  Skeleton(@core.Skeleton)
}

///|
/// Upstream's `RetargetOptions` object, with its defaults. `retarget` and
/// `retarget_clip` write back to it as upstream does (`fps`, and the `Skeleton`-target
/// overrides).
pub(all) struct RetargetOptions {
  mut use_first_frame_position : Bool
  mut fps : Double?
  mut names : Map[String, String]
  mut get_bone_name : ((@core.Object3D) -> String?)?
  mut trim : (Double, Double)?
  mut preserve_bone_matrix : Bool
  mut preserve_bone_positions : Bool
  mut use_target_matrix : Bool
  mut hip : String
  mut hip_influence : @math.Vector3
  mut scale : Double
  mut local_offsets : Map[String, @math.Matrix4]?
  mut hip_position : @math.Vector3?
}

///|
pub fn RetargetOptions::new(
  use_first_frame_position~ : Bool = false,
  fps? : Double,
  names~ : Map[String, String] = Map([]),
  get_bone_name? : (@core.Object3D) -> String?,
  trim? : (Double, Double),
  preserve_bone_matrix~ : Bool = true,
  preserve_bone_positions~ : Bool = true,
  use_target_matrix~ : Bool = false,
  hip~ : String = "hip",
  hip_influence~ : @math.Vector3 = @math.Vector3::new(1.0, 1.0, 1.0),
  scale~ : Double = 1.0,
  local_offsets? : Map[String, @math.Matrix4],
  hip_position? : @math.Vector3,
) -> RetargetOptions {
  {
    use_first_frame_position,
    fps,
    names,
    get_bone_name,
    trim,
    preserve_bone_matrix,
    preserve_bone_positions,
    use_target_matrix,
    hip,
    hip_influence,
    scale,
    local_offsets,
    hip_position,
  }
}

///|
fn sku_get_bone_name(
  bone : @core.Object3D,
  options : RetargetOptions,
) -> String? {
  match options.get_bone_name {
    Some(get_bone_name) => get_bone_name(bone)
    None => options.names.get(bone.name)
  }
}

///|
/// `getBoneName( bone, options ) || bone.name`.
fn sku_get_bone_name_or_own(
  bone : @core.Object3D,
  options : RetargetOptions,
) -> String {
  match sku_get_bone_name(bone, options) {
    Some(name) if name != "" => name
    _ => bone.name
  }
}

///|
/// `object.skeleton`, which upstream reads on any object; here a `SkinnedMesh`.
fn sku_skeleton_of(object : @core.Object3D) -> @core.Skeleton {
  match object.kind {
    Mesh({ kind: SkinnedMesh({ skeleton: Some(skeleton), .. }), .. }) =>
      skeleton
    _ =>
      abort("TypeError: Cannot read properties of undefined (reading 'bones')")
  }
}

///|
fn sku_bones_of(subject : SkeletonRef) -> Array[@core.Object3D] {
  match subject {
    Object(object) => sku_skeleton_of(object).bones
    Skeleton(skeleton) => skeleton.bones
  }
}

///|
/// Retargets the pose of the `source` skeleton onto the `target` one.
pub fn SkeletonUtils::retarget(
  target : SkeletonRef,
  source : SkeletonRef,
  options~ : RetargetOptions = RetargetOptions::new(),
) -> Unit {
  let quat = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0)
  let scale = @math.Vector3::new(0.0, 0.0, 0.0)
  let relative_matrix = @math.Matrix4::new()
  let global_matrix = @math.Matrix4::new()
  let source_bones = sku_bones_of(source)
  let bones = sku_bones_of(target)
  // reset bones
  match target {
    Object(object) => sku_skeleton_of(object).pose()
    Skeleton(_) => {
      options.use_target_matrix = true
      options.preserve_bone_matrix = false
    }
  }
  let bones_position = []
  if options.preserve_bone_positions {
    for bone in bones {
      bones_position.push(bone.position.clone())
    }
  }
  if options.preserve_bone_matrix {
    guard target is Object(target) else { abort("unreachable") }
    // reset matrix
    target.update_matrix_world()
    ignore(target.matrix_world.identity())
    // reset children matrix
    for child in target.children {
      child.update_matrix_world(force=true)
    }
  }
  for bone in bones {
    let name = sku_get_bone_name(bone, options)
    let bone_to = sku_get_bone_by_name(name, source_bones)
    ignore(global_matrix.copy(bone.matrix_world))
    if bone_to is Some(bone_to) {
      bone_to.update_matrix_world()
      if options.use_target_matrix {
        ignore(relative_matrix.copy(bone_to.matrix_world))
      } else {
        guard target is Object(target) else {
          abort(
            "TypeError: Cannot read properties of undefined (reading 'elements')",
          )
        }
        ignore(relative_matrix.copy(target.matrix_world).invert())
        ignore(relative_matrix.multiply(bone_to.matrix_world))
      }
      // ignore scale to extract rotation
      ignore(scale.set_from_matrix_scale(relative_matrix))
      ignore(
        relative_matrix.scale(
          scale.set(1.0 / scale.x, 1.0 / scale.y, 1.0 / scale.z),
        ),
      )
      // apply to global matrix
      ignore(
        global_matrix.make_rotation_from_quaternion(
          quat.set_from_rotation_matrix(relative_matrix),
        ),
      )
      if target is Object(_) {
        if options.local_offsets is Some(local_offsets) {
          if local_offsets.get(bone.name) is Some(local_offset) {
            ignore(global_matrix.multiply(local_offset))
          }
        }
      }
      ignore(global_matrix.copy_position(relative_matrix))
    }
    if name == Some(options.hip) {
      let e = global_matrix.elements
      e[12] *= options.scale * options.hip_influence.x
      e[13] *= options.scale * options.hip_influence.y
      e[14] *= options.scale * options.hip_influence.z
      if options.hip_position is Some(hip_position) {
        e[12] += hip_position.x * options.scale
        e[13] += hip_position.y * options.scale
        e[14] += hip_position.z * options.scale
      }
    }
    match bone.parent {
      Some(parent) => {
        ignore(bone.matrix.copy(parent.matrix_world).invert())
        ignore(bone.matrix.multiply(global_matrix))
      }
      None => ignore(bone.matrix.copy(global_matrix))
    }
    ignore(bone.matrix.decompose(bone.position, bone.quaternion, bone.scale))
    bone.update_matrix_world()
  }
  if options.preserve_bone_positions {
    for i, bone in bones {
      let name = sku_get_bone_name_or_own(bone, options)
      if name != options.hip {
        ignore(bone.position.copy(bones_position[i]))
      }
    }
  }
  if options.preserve_bone_matrix {
    guard target is Object(target) else { abort("unreachable") }
    // restore matrix
    target.update_matrix_world(force=true)
  }
}

///|
/// The position or quaternion keyframes `retarget_clip` records for one bone.
priv struct SkuTrackData {
  times : @core.TypedArray
  values : @core.TypedArray
}

///|
priv struct SkuBoneData {
  bone : @core.Object3D
  mut pos : SkuTrackData?
  mut quat : SkuTrackData?
}

///|
/// Retargets `clip`, played on `source`, to the skeleton of `target`.
pub fn SkeletonUtils::retarget_clip(
  target : @core.Object3D,
  source : SkeletonRef,
  clip : @animation.AnimationClip,
  options~ : RetargetOptions = RetargetOptions::new(),
) -> @animation.AnimationClip {
  // Calculate the fps from the source clip based on the track with the most frames, unless fps is already provided.
  let fps = match options.fps {
    Some(fps) => fps
    None => {
      let mut max = sku_neg_infinity()
      for track in clip.tracks {
        max = sku_math_max(max, track.times.length().to_double())
      }
      max / clip.duration
    }
  }
  options.fps = Some(fps)
  let source = match source {
    Object(object) => object
    Skeleton(skeleton) => sku_get_helper_from_skeleton(skeleton)
  }
  let num_frames = sku_math_round(clip.duration * (fps / 1000.0) * 1000.0)
  let delta = clip.duration / (num_frames - 1.0)
  let converted_tracks = []
  let mixer = @animation.AnimationMixer::new(source)
  let bones = sku_skeleton_of(target).bones
  let bone_datas : Array[SkuBoneData?] = []
  let mut position_offset : @math.Vector3? = None
  ignore(mixer.clip_action(clip).play())
  // trim
  let mut end = num_frames
  match options.trim {
    Some((trim0, trim1)) => {
      let start = sku_math_round(trim0 * fps)
      end = sku_math_min(sku_math_round(trim1 * fps), num_frames) - start
      ignore(mixer.update(trim0))
    }
    None => ignore(mixer.update(0.0))
  }
  source.update_matrix_world()
  let source_skeleton = sku_skeleton_of(source)
  let end_length = end.to_int()
  let mut frame = 0
  while frame.to_double() < end {
    let time = frame.to_double() * delta
    SkeletonUtils::retarget(Object(target), Object(source), options~)
    for j, bone in bones {
      let name = sku_get_bone_name_or_own(bone, options)
      let bone_to = sku_get_bone_by_name(Some(name), source_skeleton.bones)
      if bone_to is Some(_) {
        while bone_datas.length() <= j {
          bone_datas.push(None)
        }
        let bone_data = match bone_datas[j] {
          Some(bone_data) => bone_data
          None => {
            let bone_data = { bone, pos: None, quat: None, }
            bone_datas[j] = Some(bone_data)
            bone_data
          }
        }
        if options.hip == name {
          let pos = match bone_data.pos {
            Some(pos) => pos
            None => {
              let pos = {
                times: @core.TypedArray::float32(end_length),
                values: @core.TypedArray::float32(end_length * 3),
              }
              bone_data.pos = Some(pos)
              pos
            }
          }
          if options.use_first_frame_position {
            if frame == 0 {
              position_offset = Some(bone.position.clone())
            }
            guard position_offset is Some(offset) else {
              abort(
                "TypeError: Cannot read properties of undefined (reading 'x')",
              )
            }
            ignore(bone.position.sub(offset))
          }
          pos.times[frame] = time
          pos.values[frame * 3 + 0] = bone.position.x
          pos.values[frame * 3 + 1] = bone.position.y
          pos.values[frame * 3 + 2] = bone.position.z
        }
        let quat = match bone_data.quat {
          Some(quat) => quat
          None => {
            let quat = {
              times: @core.TypedArray::float32(end_length),
              values: @core.TypedArray::float32(end_length * 4),
            }
            bone_data.quat = Some(quat)
            quat
          }
        }
        quat.times[frame] = time
        quat.values[frame * 4 + 0] = bone.quaternion.x
        quat.values[frame * 4 + 1] = bone.quaternion.y
        quat.values[frame * 4 + 2] = bone.quaternion.z
        quat.values[frame * 4 + 3] = bone.quaternion.w
      }
    }
    if frame.to_double() == end - 2.0 {
      // last mixer update before final loop iteration
      // make sure we do not go over or equal to clip duration
      ignore(mixer.update(delta - 0.0000001))
    } else {
      ignore(mixer.update(delta))
    }
    source.update_matrix_world()
    frame += 1
  }
  for bone_data in bone_datas {
    if bone_data is Some(bone_data) {
      if bone_data.pos is Some(pos) {
        converted_tracks.push(
          @animation.VectorKeyframeTrack::new(
            ".bones[" + bone_data.bone.name + "].position",
            pos.times,
            pos.values,
          ),
        )
      }
      let quat = bone_data.quat.unwrap()
      converted_tracks.push(
        @animation.QuaternionKeyframeTrack::new(
          ".bones[" + bone_data.bone.name + "].quaternion",
          quat.times,
          quat.values,
        ),
      )
    }
  }
  mixer.uncache_action(clip)
  @animation.AnimationClip::new(
    name=clip.name,
    duration=-1.0,
    tracks=converted_tracks,
  )
}

///|
/// Clones `source` and its descendants, rebinding every cloned `SkinnedMesh` to the cloned
/// bones (which must be descendants of `source`).
pub fn SkeletonUtils::clone(source : @core.Object3D) -> @core.Object3D {
  let source_lookup : Map[Int32, @core.Object3D] = Map([])
  let clone_lookup : Map[Int32, @core.Object3D] = Map([])
  let clone = source.clone()
  sku_parallel_traverse(source, clone, (source_node, cloned_node) => {
    source_lookup[cloned_node.id] = source_node
    clone_lookup[source_node.id] = cloned_node
  })
  clone.traverse(node => {
    guard node.kind is Mesh({ kind: SkinnedMesh(cloned_mesh), .. }) else {
      return
    }
    guard source_lookup.get(node.id) is Some(source_node) &&
      source_node.kind is Mesh({ kind: SkinnedMesh(source_mesh), .. }) else {
      abort("SkeletonUtils.clone: no source for a cloned SkinnedMesh")
    }
    guard source_mesh.skeleton is Some(source_skeleton) else {
      abort("TypeError: Cannot read properties of undefined (reading 'bones')")
    }
    let source_bones = source_skeleton.bones
    let skeleton = source_skeleton.clone()
    cloned_mesh.skeleton = Some(skeleton)
    ignore(cloned_mesh.bind_matrix.copy(source_mesh.bind_matrix))
    skeleton.bones = source_bones.map(bone => {
      match clone_lookup.get(bone.id) {
        Some(cloned) => cloned
        // a bone outside `source`: upstream stores `undefined`, which `Skeleton` treats
        // as an identity matrix; a detached `Bone` has one
        None => @core.Bone::new()
      }
    })
    node.bind(skeleton, bind_matrix=cloned_mesh.bind_matrix)
  })
  clone
}

///|
fn sku_get_bone_by_name(
  name : String?,
  bones : Array[@core.Object3D],
) -> @core.Object3D? {
  for bone in bones {
    if name == Some(bone.name) {
      return Some(bone)
    }
  }
  None
}

///|
/// Upstream's `new SkeletonHelper( skeleton.bones[ 0 ] )` with `skeleton` assigned. The
/// port's `PropertyBinding` reaches bones only through a `SkinnedMesh`, so the stand-in is
/// a `SkinnedMesh` holding the skeleton (unbound: its bones and their matrices are left
/// alone, as `SkeletonHelper` leaves them).
fn sku_get_helper_from_skeleton(skeleton : @core.Skeleton) -> @core.Object3D {
  ignore(skeleton.bones[0])
  let source = @core.SkinnedMesh::new()
  if source.kind is Mesh({ kind: SkinnedMesh(skinned), .. }) {
    skinned.skeleton = Some(skeleton)
  }
  source
}

///|
fn sku_parallel_traverse(
  a : @core.Object3D,
  b : @core.Object3D,
  callback : (@core.Object3D, @core.Object3D) -> Unit,
) -> Unit {
  callback(a, b)
  for i in 0..<a.children.length() {
    sku_parallel_traverse(a.children[i], b.children[i], callback)
  }
}
