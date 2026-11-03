// Upstream src/objects/LOD.js.

///|
let _lod_v1 : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _lod_v2 : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
pub fn LOD::new() -> Object3D {
  let lod : LOD = { _current_level: 0, levels: [], auto_update: true, }
  Object3D::new(kind=LOD(lod), type_="LOD")
}

///|
fn Object3D::lod_data(self : Object3D) -> LOD {
  guard self.kind is LOD(lod) else { abort("Object3D: not a LOD") }
  lod
}

///|
/// Adds a mesh shown from `distance` on.
pub fn Object3D::add_level(
  self : Object3D,
  object : Object3D,
  distance~ : Double = 0.0,
  hysteresis~ : Double = 0.0,
) -> Object3D {
  let distance = distance.abs()
  let levels = self.lod_data().levels
  let mut l = 0
  while l < levels.length() {
    if distance < levels[l].distance {
      break
    }
    l += 1
  }
  levels.insert(l, { distance, hysteresis, object, })
  ignore(self.add(object))
  self
}

///|
/// Removes the level at exactly `distance`; returns whether one existed.
pub fn Object3D::remove_level(self : Object3D, distance : Double) -> Bool {
  let levels = self.lod_data().levels
  for i in 0..<levels.length() {
    if levels[i].distance == distance {
      let removed = levels.remove(i)
      ignore(self.remove(removed.object))
      return true
    }
  }
  false
}

///|
pub fn Object3D::get_current_level(self : Object3D) -> Int32 {
  self.lod_data()._current_level
}

///|
pub fn Object3D::get_object_for_distance(
  self : Object3D,
  distance : Double,
) -> Object3D? {
  let levels = self.lod_data().levels
  if levels.length() > 0 {
    let mut i = 1
    let l = levels.length()
    while i < l {
      let mut level_distance = levels[i].distance
      if levels[i].object.visible {
        level_distance = level_distance - level_distance * levels[i].hysteresis
      }
      if distance < level_distance {
        break
      }
      i += 1
    }
    return Some(levels[i - 1].object)
  }
  None
}

///|
/// Upstream `raycast`.
fn hook_lod_raycast(
  object : Object3D,
  raycaster : Raycaster,
  intersects : Array[Intersection],
) -> Unit {
  if object.lod_data().levels.length() > 0 {
    ignore(_lod_v1.set_from_matrix_position(object.matrix_world))
    let distance = raycaster.ray.origin.distance_to(_lod_v1)
    if object.get_object_for_distance(distance) is Some(level_object) {
      level_object.raycast(raycaster, intersects)
    }
  }
}

///|
/// `camera.zoom`, which is `undefined` on cameras without one.
fn lod_camera_zoom(camera : Object3D) -> Double {
  match camera.kind {
    Camera({ kind: PerspectiveCamera(perspective), .. }) => perspective.zoom
    Camera({ kind: OrthographicCamera(orthographic), .. }) => orthographic.zoom
    _ => objects_nan()
  }
}

///|
/// Upstream `LOD.update`: shows the level matching the camera distance.
pub fn Object3D::update(self : Object3D, camera : Object3D) -> Unit {
  let lod = self.lod_data()
  let levels = lod.levels
  if levels.length() > 1 {
    ignore(_lod_v1.set_from_matrix_position(camera.matrix_world))
    ignore(_lod_v2.set_from_matrix_position(self.matrix_world))
    let distance = _lod_v1.distance_to(_lod_v2) / lod_camera_zoom(camera)
    levels[0].object.visible = true
    let mut i = 1
    let l = levels.length()
    while i < l {
      let mut level_distance = levels[i].distance
      if levels[i].object.visible {
        level_distance = level_distance - level_distance * levels[i].hysteresis
      }
      if distance >= level_distance {
        levels[i - 1].object.visible = false
        levels[i].object.visible = true
      } else {
        break
      }
      i += 1
    }
    lod._current_level = i - 1
    while i < l {
      levels[i].object.visible = false
      i += 1
    }
  }
}

///|
/// `new this.constructor()`.
fn hook_lod_new_like(_object : Object3D) -> Object3D {
  LOD::new()
}

///|
/// Calls `object.copy_base( source, false )` first: children arrive through `add_level`.
fn hook_lod_copy(
  object : Object3D,
  source : Object3D,
  _recursive : Bool,
) -> Unit {
  object.copy_base(source, false)
  let source_lod = source.lod_data()
  for level in source_lod.levels {
    ignore(
      object.add_level(
        level.object.clone(),
        distance=level.distance,
        hysteresis=level.hysteresis,
      ),
    )
  }
  object.lod_data().auto_update = source_lod.auto_update
}

///|
/// Adds the class's fields to `data`, which is upstream's `data.object`.
fn hook_lod_to_json(
  object : Object3D,
  _meta : ToJsonMeta,
  data : Map[String, Json],
) -> Unit {
  let lod = object.lod_data()
  data["autoUpdate"] = Json::boolean(lod.auto_update)
  data["levels"] = Json::array(
    lod.levels.map(level => {
      Json::object({
        "object": Json::string(level.object.uuid),
        "distance": @math.json_number(level.distance),
        "hysteresis": @math.json_number(level.hysteresis),
      })
    }),
  )
}
