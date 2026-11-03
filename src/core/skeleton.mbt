// Upstream src/objects/Skeleton.js.

///|
let _skeleton_offset_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
/// `bone_inverses` is kept as passed; when empty it is computed from the bones.
pub fn Skeleton::new(
  bones? : Array[Object3D],
  bone_inverses? : Array[@math.Matrix4],
) -> Skeleton {
  let skeleton : Skeleton = {
    uuid: @math.generate_uuid(),
    bones: match bones {
      Some(bones) => bones.copy()
      None => []
    },
    bone_inverses: match bone_inverses {
      Some(bone_inverses) => bone_inverses
      None => []
    },
    bone_matrices: None,
    previous_bone_matrices: None,
    bone_texture: None,
    previous_bone_texture: None,
  }
  skeleton.init()
  skeleton
}

///|
pub fn Skeleton::init(self : Skeleton) -> Unit {
  let bones = self.bones
  let bone_inverses = self.bone_inverses
  self.bone_matrices = Some(TypedArray::float32(bones.length() * 16))
  // calculate inverse bone matrices if necessary
  if bone_inverses.length() == 0 {
    self.calculate_inverses()
  } else if bones.length() != bone_inverses.length() {
    // handle special case
    warn(
      "Skeleton: Number of inverse bone matrices does not match amount of bones.",
    )
    self.bone_inverses = []
    for _ in 0..<self.bones.length() {
      self.bone_inverses.push(@math.Matrix4::new())
    }
  }
}

///|
/// Sets `bone_inverses` from the current world matrices of the bones.
pub fn Skeleton::calculate_inverses(self : Skeleton) -> Unit {
  self.bone_inverses.clear()
  for bone in self.bones {
    let inverse = @math.Matrix4::new()
    ignore(inverse.copy(bone.matrix_world).invert())
    self.bone_inverses.push(inverse)
  }
}

///|
/// Returns the skeleton to the bind pose.
pub fn Skeleton::pose(self : Skeleton) -> Unit {
  // recover the bind-time world matrices
  for i, bone in self.bones {
    ignore(bone.matrix_world.copy(self.bone_inverses[i]).invert())
  }
  // compute the local matrices, positions, rotations and scales
  for bone in self.bones {
    match bone.parent {
      Some(parent) if parent.is_bone() => {
        ignore(bone.matrix.copy(parent.matrix_world).invert())
        ignore(bone.matrix.multiply(bone.matrix_world))
      }
      _ => ignore(bone.matrix.copy(bone.matrix_world))
    }
    ignore(bone.matrix.decompose(bone.position, bone.quaternion, bone.scale))
  }
}

///|
/// Flattens the bone offset matrices into `bone_matrices`.
pub fn Skeleton::update(self : Skeleton) -> Unit {
  let bones = self.bones
  let bone_inverses = self.bone_inverses
  guard self.bone_matrices is Some(bone_matrices) else {
    abort("Skeleton.update: boneMatrices is not initialized")
  }
  // flatten bone matrices to array
  for i, bone in bones {
    // compute the offset between the current and the original transform
    ignore(
      _skeleton_offset_matrix.multiply_matrices(
        bone.matrix_world,
        bone_inverses[i],
      ),
    )
    typed_array_write_matrix4(bone_matrices, _skeleton_offset_matrix, i * 16)
  }
  if self.bone_texture is Some(bone_texture) {
    bone_texture.set_needs_update(true)
  }
}

///|
pub fn Skeleton::clone(self : Skeleton) -> Skeleton {
  Skeleton::new(bones=self.bones, bone_inverses=self.bone_inverses)
}

///|
/// Moves the bone data into a `DataTexture`, for use in the vertex shader.
pub fn Skeleton::compute_bone_texture(self : Skeleton) -> Skeleton {
  // layout (1 matrix = 4 pixels)
  //      RGBA RGBA RGBA RGBA (=> column1, column2, column3, column4)
  //  with  8x8  pixel texture max   16 bones * 4 pixels =  (8 * 8)
  //       16x16 pixel texture max   64 bones * 4 pixels = (16 * 16)
  //       32x32 pixel texture max  256 bones * 4 pixels = (32 * 32)
  //       64x64 pixel texture max 1024 bones * 4 pixels = (64 * 64)
  let size = objects_matrices_texture_size(self.bones.length())
  // 4 floats per RGBA pixel
  let bone_matrices = TypedArray::float32(size * size * 4)
  // copy current values
  guard self.bone_matrices is Some(current) else {
    abort("Skeleton.computeBoneTexture: boneMatrices is not initialized")
  }
  bone_matrices.set_from(current)
  let bone_texture = DataTexture::new(
    data=bone_matrices,
    width=size,
    height=size,
    format=RGBAFormat,
    type_=FloatType,
  )
  bone_texture.set_needs_update(true)
  self.bone_matrices = Some(bone_matrices)
  self.bone_texture = Some(bone_texture)
  self
}

///|
/// The side of a square RGBA texture holding `count` matrices, at 4 pixels per matrix.
fn objects_matrices_texture_size(count : Int32) -> Int32 {
  let size = (count.to_double() * 4.0).sqrt()
  let size = (size / 4.0).ceil() * 4.0
  utils_math_max(size, 4.0).to_int()
}

///|
pub fn Skeleton::get_bone_by_name(self : Skeleton, name : String) -> Object3D? {
  for bone in self.bones {
    if bone.name == name {
      return Some(bone)
    }
  }
  None
}

///|
pub fn Skeleton::dispose(self : Skeleton) -> Unit {
  if self.bone_texture is Some(bone_texture) {
    bone_texture.dispose()
    self.bone_texture = None
  }
  if self.previous_bone_texture is Some(previous_bone_texture) {
    previous_bone_texture.dispose()
    self.previous_bone_texture = None
  }
}

///|
/// Reads the output of `to_json`; `bones` maps uuids to the bones of the scene.
pub fn Skeleton::from_json(
  self : Skeleton,
  json : Json,
  bones : Map[String, Object3D],
) -> Skeleton {
  guard json is Object(data) &&
    data.get("uuid") is Some(String(uuid)) &&
    data.get("bones") is Some(Array(bone_uuids)) &&
    data.get("boneInverses") is Some(Array(bone_inverses)) else {
    abort("Skeleton.fromJSON: malformed data")
  }
  self.uuid = uuid
  for i, bone_uuid in bone_uuids {
    guard bone_uuid is String(bone_uuid) else {
      abort("Skeleton.fromJSON: malformed bone uuid")
    }
    let bone = match bones.get(bone_uuid) {
      Some(bone) => bone
      None => {
        warn("Skeleton: No bone found with UUID: " + bone_uuid)
        Bone::new()
      }
    }
    self.bones.push(bone)
    guard bone_inverses[i] is Array(elements) else {
      abort("Skeleton.fromJSON: malformed bone inverse")
    }
    let array = elements.map(element => {
      guard @math.json_to_number(element) is Some(value) else {
        abort("Skeleton.fromJSON: malformed bone inverse")
      }
      value
    })
    self.bone_inverses.push(@math.Matrix4::new().from_array(array))
  }
  self.init()
  self
}

///|
pub fn Skeleton::to_json(self : Skeleton) -> Json {
  let bones : Array[Json] = []
  let bone_inverses : Array[Json] = []
  for i, bone in self.bones {
    bones.push(Json::string(bone.uuid))
    bone_inverses.push(json_numbers(self.bone_inverses[i].to_array()))
  }
  let data : Map[String, Json] = {
    "metadata": Json::object({
      "version": Json::number(4.7),
      "type": Json::string("Skeleton"),
      "generator": Json::string("Skeleton.toJSON"),
    }),
    "bones": Json::array(bones),
    "boneInverses": Json::array(bone_inverses),
    "uuid": Json::string(self.uuid),
  }
  Json::object(data)
}
