// Upstream src/animation/AnimationObjectGroup.js. The variadic `add( ...objects )`,
// `remove` and `uncache` take arrays.

///|
/// A group of objects that share animation state, used as a mixer root.
pub(all) struct AnimationObjectGroup {
  uuid : String
  /// Cached objects followed by the active ones.
  _objects : Array[@core.Object3D]
  /// Read by `Composite`.
  mut n_cached_objects_ : Int32
  _indices_by_uuid : Map[String, Int32]
  _paths : Array[String]
  _parsed_paths : Array[ParsedPath]
  _bindings : Array[Array[PropertyBinding?]]
  _bindings_indices_by_path : Map[String, Int32]
}

///|
pub fn AnimationObjectGroup::new(
  objects~ : Array[@core.Object3D] = [],
) -> AnimationObjectGroup {
  let indices : Map[String, Int32] = Map([])
  let n = objects.length()
  for i = 0; i != n; i = i + 1 {
    indices[objects[i].uuid] = i
  }
  {
    uuid: @math.generate_uuid(),
    _objects: objects.copy(),
    n_cached_objects_: 0,
    _indices_by_uuid: indices,
    _paths: [],
    _parsed_paths: [],
    _bindings: [],
    _bindings_indices_by_path: Map([]),
  }
}

///|
/// `group.stats`.
pub(all) struct AnimationObjectGroupStats {
  objects_total : Int32
  objects_in_use : Int32
  bindings_per_object : Int32
}

///|
pub fn AnimationObjectGroup::stats(
  self : AnimationObjectGroup,
) -> AnimationObjectGroupStats {
  {
    objects_total: self._objects.length(),
    objects_in_use: self._objects.length() - self.n_cached_objects_,
    bindings_per_object: self._bindings.length(),
  }
}

///|
/// Adds objects to the active region.
pub fn AnimationObjectGroup::add(
  self : AnimationObjectGroup,
  objects : Array[@core.Object3D],
) -> Unit {
  let objects_ = self._objects
  let indices_by_uuid = self._indices_by_uuid
  let paths = self._paths
  let parsed_paths = self._parsed_paths
  let bindings = self._bindings
  let n_bindings = bindings.length()
  let mut known_object : @core.Object3D? = None
  let mut n_objects = objects_.length()
  let mut n_cached_objects = self.n_cached_objects_
  let n = objects.length()
  for i = 0; i != n; i = i + 1 {
    let object = objects[i]
    let uuid = object.uuid
    match indices_by_uuid.get(uuid) {
      None => {
        // unknown object -> add it to the ACTIVE region
        let index = n_objects
        n_objects += 1
        indices_by_uuid[uuid] = index
        objects_.push(object)

        // accounting is done, now do the same for all bindings
        let m = n_bindings
        for j = 0; j != m; j = j + 1 {
          bindings[j].push(
            Some(
              PropertyBinding::new(
                object,
                paths[j],
                parsed_path=parsed_paths[j],
              ),
            ),
          )
        }
      }
      Some(index) if index < n_cached_objects => {
        known_object = Some(objects_[index])

        // move existing object to the ACTIVE region
        n_cached_objects -= 1
        let first_active_index = n_cached_objects
        let last_cached_object = objects_[first_active_index]
        indices_by_uuid[last_cached_object.uuid] = index
        objects_[index] = last_cached_object
        indices_by_uuid[uuid] = first_active_index
        objects_[first_active_index] = object

        // accounting is done, now do the same for all bindings
        let m = n_bindings
        for j = 0; j != m; j = j + 1 {
          let bindings_for_path = bindings[j]
          let last_cached = bindings_for_path[first_active_index]
          let mut binding = bindings_for_path[index]
          bindings_for_path[index] = last_cached
          if binding is None {
            // since we do not bother to create new bindings
            // for objects that are cached, the binding may
            // or may not exist
            binding = Some(
              PropertyBinding::new(
                object,
                paths[j],
                parsed_path=parsed_paths[j],
              ),
            )
          }
          bindings_for_path[first_active_index] = binding
        }
      }
      Some(index) =>
        if !(known_object is Some(known) &&
          physical_equal(objects_[index], known)) {
          @core.error(
            "AnimationObjectGroup: Different objects with the same UUID " +
            "detected. Clean the caches or recreate your infrastructure when reloading scenes.",
          )
        } // else the object is already where we want it to be
    }
  }
  self.n_cached_objects_ = n_cached_objects
}

///|
/// Moves objects to the cached region.
pub fn AnimationObjectGroup::remove(
  self : AnimationObjectGroup,
  objects : Array[@core.Object3D],
) -> Unit {
  let objects_ = self._objects
  let indices_by_uuid = self._indices_by_uuid
  let bindings = self._bindings
  let n_bindings = bindings.length()
  let mut n_cached_objects = self.n_cached_objects_
  let n = objects.length()
  for i = 0; i != n; i = i + 1 {
    let object = objects[i]
    let uuid = object.uuid
    if indices_by_uuid.get(uuid) is Some(index) && index >= n_cached_objects {
      // move existing object into the CACHED region
      let last_cached_index = n_cached_objects
      n_cached_objects += 1
      let first_active_object = objects_[last_cached_index]
      indices_by_uuid[first_active_object.uuid] = index
      objects_[index] = first_active_object
      indices_by_uuid[uuid] = last_cached_index
      objects_[last_cached_index] = object

      // accounting is done, now do the same for all bindings
      let m = n_bindings
      for j = 0; j != m; j = j + 1 {
        let bindings_for_path = bindings[j]
        let first_active = bindings_for_path[last_cached_index]
        let binding = bindings_for_path[index]
        bindings_for_path[index] = first_active
        bindings_for_path[last_cached_index] = binding
      }
    }
  }
  self.n_cached_objects_ = n_cached_objects
}

///|
/// Forgets objects.
pub fn AnimationObjectGroup::uncache(
  self : AnimationObjectGroup,
  objects : Array[@core.Object3D],
) -> Unit {
  let objects_ = self._objects
  let indices_by_uuid = self._indices_by_uuid
  let bindings = self._bindings
  let n_bindings = bindings.length()
  let mut n_cached_objects = self.n_cached_objects_
  let mut n_objects = objects_.length()
  let n = objects.length()
  for i = 0; i != n; i = i + 1 {
    let object = objects[i]
    let uuid = object.uuid
    if indices_by_uuid.get(uuid) is Some(index) {
      indices_by_uuid.remove(uuid)
      if index < n_cached_objects {
        // object is cached, shrink the CACHED region
        n_cached_objects -= 1
        let first_active_index = n_cached_objects
        let last_cached_object = objects_[first_active_index]
        n_objects -= 1
        let last_index = n_objects
        let last_object = objects_[last_index]
        if index != first_active_index {
          // last cached object takes this object's place
          indices_by_uuid[last_cached_object.uuid] = index
        }
        objects_[index] = last_cached_object
        if first_active_index != last_index {
          // last object goes to the activated slot and pop
          indices_by_uuid[last_object.uuid] = first_active_index
        }
        objects_[first_active_index] = last_object
        objects_.pop() |> ignore

        // accounting is done, now do the same for all bindings
        let m = n_bindings
        for j = 0; j != m; j = j + 1 {
          let bindings_for_path = bindings[j]
          let last_cached = bindings_for_path[first_active_index]
          let last = bindings_for_path[last_index]
          bindings_for_path[index] = last_cached
          bindings_for_path[first_active_index] = last
          bindings_for_path.pop() |> ignore
        }
      } else {
        // object is active, just swap with the last and pop
        n_objects -= 1
        let last_index = n_objects
        let last_object = objects_[last_index]
        if index != last_index {
          indices_by_uuid[last_object.uuid] = index
        }
        objects_[index] = last_object
        objects_.pop() |> ignore

        // accounting is done, now do the same for all bindings
        let m = n_bindings
        for j = 0; j != m; j = j + 1 {
          let bindings_for_path = bindings[j]
          bindings_for_path[index] = bindings_for_path[last_index]
          bindings_for_path.pop() |> ignore
        }
      }
    }
  }
  self.n_cached_objects_ = n_cached_objects
}

///|
/// The bindings for `path`, kept up to date as objects come and go. Used by `Composite`.
pub fn AnimationObjectGroup::subscribe_(
  self : AnimationObjectGroup,
  path : String,
  parsed_path : ParsedPath,
) -> Array[PropertyBinding?] {
  let indices_by_path = self._bindings_indices_by_path
  let bindings = self._bindings
  if indices_by_path.get(path) is Some(index) {
    return bindings[index]
  }
  let paths = self._paths
  let parsed_paths = self._parsed_paths
  let objects = self._objects
  let n_objects = objects.length()
  let n_cached_objects = self.n_cached_objects_
  let bindings_for_path : Array[PropertyBinding?] = Array::make(n_objects, None)
  let index = bindings.length()
  indices_by_path[path] = index
  paths.push(path)
  parsed_paths.push(parsed_path)
  bindings.push(bindings_for_path)
  let n = objects.length()
  for i = n_cached_objects; i != n; i = i + 1 {
    let object = objects[i]
    bindings_for_path[i] = Some(
      PropertyBinding::new(object, path, parsed_path~),
    )
  }
  bindings_for_path
}

///|
/// Stops updating the array `subscribe_` returned for `path`.
pub fn AnimationObjectGroup::unsubscribe_(
  self : AnimationObjectGroup,
  path : String,
) -> Unit {
  let indices_by_path = self._bindings_indices_by_path
  if indices_by_path.get(path) is Some(index) {
    let paths = self._paths
    let parsed_paths = self._parsed_paths
    let bindings = self._bindings
    let last_bindings_index = bindings.length() - 1
    let last_bindings = bindings[last_bindings_index]
    let last_bindings_path = paths[last_bindings_index]
    indices_by_path[last_bindings_path] = index
    bindings[index] = last_bindings
    bindings.pop() |> ignore
    parsed_paths[index] = parsed_paths[last_bindings_index]
    parsed_paths.pop() |> ignore
    paths[index] = paths[last_bindings_index]
    paths.pop() |> ignore
  }
}
