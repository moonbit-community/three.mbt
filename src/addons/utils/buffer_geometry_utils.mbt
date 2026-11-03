// Upstream examples/jsm/utils/BufferGeometryUtils.js. The module's functions are static
// methods of the `BufferGeometryUtils` namespace type (`import * as BufferGeometryUtils`).

///|
/// The `BufferGeometryUtils` module namespace.
#external
pub type BufferGeometryUtils

///|
extern "js" fn bgu_math_max(a : Double, b : Double) -> Double = "Math.max"

///|
extern "js" fn bgu_math_min(a : Double, b : Double) -> Double = "Math.min"

///|
extern "js" fn bgu_math_trunc(x : Double) -> Double = "Math.trunc"

///|
extern "js" fn bgu_math_log10(x : Double) -> Double = "Math.log10"

///|
extern "js" fn bgu_math_pow(x : Double, y : Double) -> Double = "Math.pow"

///|
extern "js" fn bgu_math_cos(x : Double) -> Double = "Math.cos"

///|
extern "js" fn bgu_math_sqrt(x : Double) -> Double = "Math.sqrt"

///|
extern "js" fn bgu_math_imul(a : Double, b : Double) -> Int32 = "Math.imul"

///|
/// `String( x )`, as a template literal prints a number.
extern "js" fn bgu_number_string(x : Double) -> String = "(x) => String(x)"

///|
extern "js" fn bgu_nan() -> Double = "() => NaN"

///|
extern "js" fn bgu_infinity() -> Double = "() => Infinity"

///|
/// `Number.EPSILON`.
let bgu_epsilon : Double = 2.220446049250313e-16

///|
/// `x || 1` for a length: 0 and NaN are falsy.
fn bgu_or_one(x : Double) -> Double {
  if x == 0.0 || x != x {
    1.0
  } else {
    x
  }
}

///|
/// Whether `key` is an array index, which JS objects enumerate first, in ascending order.
fn bgu_is_array_index(key : String) -> Bool {
  if key.length() == 0 || key.length() > 10 {
    return false
  }
  if key.length() > 1 && key.has_prefix("0") {
    return false
  }
  for c in key {
    if c < '0' || c > '9' {
      return false
    }
  }
  bgu_index_value(key) < 4294967295.0
}

///|
fn bgu_index_value(key : String) -> Double {
  let mut value = 0.0
  for c in key {
    value = value * 10.0 + (c.to_int() - '0'.to_int()).to_double()
  }
  value
}

///|
/// The keys of a map in the order `for ( const key in object )` visits them upstream.
fn[V] bgu_keys(map : Map[String, V]) -> Array[String] {
  let indices = []
  let others = []
  for key, _ in map {
    if bgu_is_array_index(key) {
      indices.push(key)
    } else {
      others.push(key)
    }
  }
  if indices.length() > 1 {
    indices.sort_by((a, b) => bgu_index_value(a).compare(bgu_index_value(b)))
  }
  indices.append(others)
  indices
}

///|
/// `attribute[ [ 'getX', 'getY', 'getZ', 'getW' ][ k ] ]( index )`.
fn bgu_get(
  attribute : @core.GeometryAttribute,
  k : Int32,
  index : Int32,
) -> Double {
  match k {
    0 => attribute.get_x(index)
    1 => attribute.get_y(index)
    2 => attribute.get_z(index)
    3 => attribute.get_w(index)
    _ =>
      abort(
        "TypeError: attribute[ getters[ " +
        k.to_string() +
        " ] ] is not a function",
      )
  }
}

///|
/// `attribute[ [ 'setX', 'setY', 'setZ', 'setW' ][ k ] ]( index, value )`.
fn bgu_set(
  attribute : @core.InterleavedBufferAttribute,
  k : Int32,
  index : Int32,
  value : Double,
) -> Unit {
  match k {
    0 => ignore(attribute.set_x(index, value))
    1 => ignore(attribute.set_y(index, value))
    2 => ignore(attribute.set_z(index, value))
    3 => ignore(attribute.set_w(index, value))
    _ =>
      abort(
        "TypeError: iba[ setters[ " + k.to_string() + " ] ] is not a function",
      )
  }
}

///|
/// `! MikkTSpace || ! MikkTSpace.isReady`, negated.
extern "js" fn bgu_mikktspace_is_ready(mikktspace : @core.JsValue) -> Bool = "(m) => !!(m && m.isReady)"

///|
extern "js" fn bgu_mikktspace_generate_tangents(
  mikktspace : @core.JsValue,
  position : @core.TypedArray,
  normal : @core.TypedArray,
  uv : @core.TypedArray,
) -> @core.TypedArray = "(m, p, n, t) => m.generateTangents(p, n, t)"

///|
fn bgu_get_attribute_array(
  attribute : @core.GeometryAttribute,
) -> @core.TypedArray {
  if attribute.normalized() || attribute is Interleaved(_) {
    let item_size = attribute.item_size()
    let dst_array = @core.TypedArray::float32(attribute.count() * item_size)
    let mut j = 0
    for i in 0..<attribute.count() {
      dst_array[j] = attribute.get_x(i)
      j += 1
      dst_array[j] = attribute.get_y(i)
      j += 1
      if item_size > 2 {
        dst_array[j] = attribute.get_z(i)
        j += 1
      }
    }
    return dst_array
  }
  let array = attribute.array()
  if array.type_name() == "Float32Array" {
    return array
  }
  @core.TypedArray::float32(array)
}

///|
/// Computes MikkTSpace tangents with upstream's `MikkTSpace` module (a JS value with
/// `isReady` and `generateTangents`); de-indexes indexed geometries.
pub fn BufferGeometryUtils::compute_mikktspace_tangents(
  geometry : @core.BufferGeometry,
  mikktspace : @core.JsValue,
  negate_sign~ : Bool = true,
) -> @core.BufferGeometry {
  if !bgu_mikktspace_is_ready(mikktspace) {
    abort("THREE.BufferGeometryUtils: Initialized MikkTSpace library required.")
  }
  if !geometry.has_attribute("position") ||
    !geometry.has_attribute("normal") ||
    !geometry.has_attribute("uv") {
    abort(
      "THREE.BufferGeometryUtils: Tangents require \"position\", \"normal\", and \"uv\" attributes.",
    )
  }
  // MikkTSpace algorithm requires non-indexed input.
  let geometry2 = if geometry.index is Some(_) {
    geometry.to_non_indexed()
  } else {
    geometry
  }
  // Compute vertex tangents.
  let tangents = bgu_mikktspace_generate_tangents(
    mikktspace,
    bgu_get_attribute_array(geometry2.attributes.get("position").unwrap()),
    bgu_get_attribute_array(geometry2.attributes.get("normal").unwrap()),
    bgu_get_attribute_array(geometry2.attributes.get("uv").unwrap()),
  )
  // Texture coordinate convention of glTF differs from the apparent
  // default of the MikkTSpace library; .w component must be flipped.
  if negate_sign {
    let mut i = 3
    while i < tangents.length() {
      tangents[i] = tangents[i] * -1.0
      i += 4
    }
  }
  // Quantized normals get tangents of the same precision.
  let normal = geometry2.attributes.get("normal").unwrap()
  let normal_array = normal.array()
  let normal_type = normal_array.type_name()
  if normal.normalized() &&
    (normal_type == "Int8Array" || normal_type == "Int16Array") {
    let quantized = normal_array.new_like(tangents.length())
    for i in 0..<tangents.length() {
      quantized[i] = @math.normalize(tangents[i], quantized.kind())
    }
    ignore(
      geometry2.set_attribute(
        "tangent",
        @core.BufferAttribute::new(quantized, 4, normalized=true),
      ),
    )
  } else {
    ignore(
      geometry2.set_attribute(
        "tangent",
        @core.BufferAttribute::new(tangents, 4),
      ),
    )
  }
  if !physical_equal(geometry, geometry2) {
    ignore(geometry.copy(geometry2))
  }
  geometry
}

///|
/// Merges compatible geometries into one; `None` (upstream's `null`) if they differ.
pub fn BufferGeometryUtils::merge_geometries(
  geometries : Array[@core.BufferGeometry],
  use_groups~ : Bool = false,
) -> @core.BufferGeometry? {
  let is_indexed = geometries[0].index is Some(_)
  let attributes_used = bgu_keys(geometries[0].attributes)
  let morph_attributes_used = bgu_keys(geometries[0].morph_attributes)
  let attributes : Map[String, Array[@core.GeometryAttribute]] = Map([])
  let morph_attributes : Map[String, Array[Array[@core.GeometryAttribute]]] = Map([],
  )
  let morph_targets_relative = geometries[0].morph_targets_relative
  let merged_geometry = @core.BufferGeometry::new()
  merged_geometry.morph_targets_relative = morph_targets_relative
  let mut offset = 0
  for i, geometry in geometries {
    let mut attributes_count = 0
    let mut morph_attributes_count = 0
    // ensure that all geometries are indexed, or none
    if is_indexed != (geometry.index is Some(_)) {
      println(
        "THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index " +
        i.to_string() +
        ". All geometries must have compatible attributes; make sure index attribute exists among all geometries, or in none of them.",
      )
      return None
    }
    // gather attributes, exit early if they're different
    for name in bgu_keys(geometry.attributes) {
      if !attributes_used.contains(name) {
        println(
          "THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index " +
          i.to_string() +
          ". All geometries must have compatible attributes; make sure \"" +
          name +
          "\" attribute exists among all geometries, or in none of them.",
        )
        return None
      }
      if !attributes.contains(name) {
        attributes[name] = []
      }
      attributes[name].push(geometry.attributes[name])
      attributes_count += 1
    }
    // ensure geometries have the same number of attributes
    if attributes_count != attributes_used.length() {
      println(
        "THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index " +
        i.to_string() +
        ". Make sure all geometries have the same number of attributes.",
      )
      return None
    }
    // gather morph attributes, exit early if they're different
    if morph_targets_relative != geometry.morph_targets_relative {
      println(
        "THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index " +
        i.to_string() +
        ". .morphTargetsRelative must be consistent throughout all geometries.",
      )
      return None
    }
    for name in bgu_keys(geometry.morph_attributes) {
      if !morph_attributes_used.contains(name) {
        println(
          "THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index " +
          i.to_string() +
          ".  .morphAttributes must be consistent throughout all geometries.",
        )
        return None
      }
      if geometry.morph_attributes[name].length() !=
        geometries[0].morph_attributes[name].length() {
        println(
          "THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index " +
          i.to_string() +
          ". All geometries must have the same number of morph targets for the \"" +
          name +
          "\" morph attribute.",
        )
        return None
      }
      if !morph_attributes.contains(name) {
        morph_attributes[name] = []
      }
      morph_attributes[name].push(geometry.morph_attributes[name])
      morph_attributes_count += 1
    }
    // ensure geometries have the same number of morph attributes
    if morph_attributes_count != morph_attributes_used.length() {
      println(
        "THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index " +
        i.to_string() +
        ". Make sure all geometries have the same number of morph attributes.",
      )
      return None
    }
    if use_groups {
      let count = if is_indexed {
        geometry.index.unwrap().count()
      } else if geometry.attributes.get("position") is Some(position) {
        position.count()
      } else {
        println(
          "THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index " +
          i.to_string() +
          ". The geometry must have either an index or a position attribute",
        )
        return None
      }
      merged_geometry.add_group(offset, count.to_double(), material_index=i)
      offset += count
    }
  }
  // merge indices
  if is_indexed {
    let mut index_offset = 0.0
    let merged_index : Array[Double] = []
    for geometry in geometries {
      let index = geometry.index.unwrap()
      for j in 0..<index.count() {
        merged_index.push(index.get_x(j) + index_offset)
      }
      guard geometry.attributes.get("position") is Some(position) else {
        abort(
          "TypeError: Cannot read properties of undefined (reading 'count')",
        )
      }
      index_offset += position.count().to_double()
    }
    ignore(merged_geometry.set_index(merged_index))
  }
  // merge attributes
  for name in bgu_keys(attributes) {
    guard BufferGeometryUtils::merge_attributes(attributes[name])
      is Some(merged_attribute) else {
      println(
        "THREE.BufferGeometryUtils: .mergeGeometries() failed while trying to merge the " +
        name +
        " attribute.",
      )
      return None
    }
    ignore(merged_geometry.set_attribute(name, merged_attribute))
  }
  // merge morph attributes
  for name in bgu_keys(morph_attributes) {
    let num_morph_targets = morph_attributes[name][0].length()
    if num_morph_targets == 0 {
      continue
    }
    merged_geometry.morph_attributes[name] = []
    for i in 0..<num_morph_targets {
      let morph_attributes_to_merge = []
      for j in 0..<morph_attributes[name].length() {
        morph_attributes_to_merge.push(morph_attributes[name][j][i])
      }
      guard BufferGeometryUtils::merge_attributes(morph_attributes_to_merge)
        is Some(merged_morph_attribute) else {
        println(
          "THREE.BufferGeometryUtils: .mergeGeometries() failed while trying to merge the " +
          name +
          " morphAttribute.",
        )
        return None
      }
      merged_geometry.morph_attributes[name].push(
        Buffer(merged_morph_attribute),
      )
    }
  }
  Some(merged_geometry)
}

///|
/// `attribute.gpuType`; an interleaved attribute has none (`undefined`).
fn bgu_gpu_type(attribute : @core.GeometryAttribute) -> Int32? {
  match attribute {
    Buffer(a) => Some(a.gpu_type)
    _ => None
  }
}

///|
/// Merges attributes of one type, item size and normalization; `None` if they differ.
pub fn BufferGeometryUtils::merge_attributes(
  attributes : Array[@core.GeometryAttribute],
) -> @core.BufferAttribute? {
  let mut typed_array : @core.TypedArray? = None
  let mut item_size : Int32? = None
  let mut normalized : Bool? = None
  // `None` is `undefined`; upstream starts at -1
  let mut gpu_type : Int32? = Some(-1)
  let mut array_length = 0
  for attribute in attributes {
    let array = attribute.array()
    if typed_array is None {
      typed_array = Some(array)
    }
    if typed_array.unwrap().type_name() != array.type_name() {
      println(
        "THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.array must be of consistent array types across matching attributes.",
      )
      return None
    }
    if item_size is None {
      item_size = Some(attribute.item_size())
    }
    if item_size != Some(attribute.item_size()) {
      println(
        "THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.itemSize must be consistent across matching attributes.",
      )
      return None
    }
    if normalized is None {
      normalized = Some(attribute.normalized())
    }
    if normalized != Some(attribute.normalized()) {
      println(
        "THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.normalized must be consistent across matching attributes.",
      )
      return None
    }
    if gpu_type == Some(-1) {
      gpu_type = bgu_gpu_type(attribute)
    }
    if gpu_type != bgu_gpu_type(attribute) {
      println(
        "THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.gpuType must be consistent across matching attributes.",
      )
      return None
    }
    array_length += attribute.count() * item_size.unwrap()
  }
  guard typed_array is Some(typed_array) else {
    abort("TypeError: TypedArray is not a constructor")
  }
  let item_size = item_size.unwrap()
  let array = typed_array.new_like(array_length)
  let result = @core.BufferAttribute::new(
    array,
    item_size,
    normalized=normalized.unwrap(),
  )
  let mut offset = 0
  for attribute in attributes {
    match attribute {
      Interleaved(a) => {
        let tuple_offset = offset / item_size
        for j in 0..<a.count() {
          for c in 0..<item_size {
            let value = a.get_component(j, c)
            ignore(result.set_component(j + tuple_offset, c, value))
          }
        }
      }
      _ => array.set_from(attribute.array(), offset~)
    }
    offset += attribute.count() * item_size
  }
  if gpu_type is Some(gpu_type) {
    result.gpu_type = gpu_type
  }
  Some(result)
}

///|
/// A deep copy; interleaved attributes come back de-interleaved.
pub fn BufferGeometryUtils::deep_clone_attribute(
  attribute : @core.GeometryAttribute,
) -> @core.BufferAttribute {
  match attribute {
    Interleaved(a) => BufferGeometryUtils::deinterleave_attribute(a)
    Buffer(a) =>
      if a.is_instanced_buffer_attribute() {
        @core.InstancedBufferAttribute::new(a.array, a.item_size).copy(a)
      } else {
        @core.BufferAttribute::new(a.array, a.item_size).copy(a)
      }
    GL(_) =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'constructor')",
      )
  }
}

///|
/// Interleaves attributes into one `InterleavedBuffer`; `None` if their types differ.
pub fn BufferGeometryUtils::interleave_attributes(
  attributes : Array[@core.GeometryAttribute],
) -> Array[@core.InterleavedBufferAttribute]? {
  // Interleaves the provided attributes into an InterleavedBuffer and returns
  // a set of InterleavedBufferAttributes for each attribute
  let mut typed_array : @core.TypedArray? = None
  let mut array_length = 0
  let mut stride = 0
  // calculate the length and type of the interleavedBuffer
  for attribute in attributes {
    let array = attribute.array()
    if typed_array is None {
      typed_array = Some(array)
    }
    if typed_array.unwrap().type_name() != array.type_name() {
      println("AttributeBuffers of different types cannot be interleaved")
      return None
    }
    array_length += array.length()
    stride += attribute.item_size()
  }
  guard typed_array is Some(typed_array) else {
    abort("TypeError: TypedArray is not a constructor")
  }
  // Create the set of buffer attributes
  let interleaved_buffer = @core.InterleavedBuffer::new(
    typed_array.new_like(array_length),
    stride,
  )
  let mut offset = 0
  let res = []
  for attribute in attributes {
    let item_size = attribute.item_size()
    let count = attribute.count()
    let iba = @core.InterleavedBufferAttribute::new(
      interleaved_buffer,
      item_size,
      offset,
      normalized=attribute.normalized(),
    )
    res.push(iba)
    offset += item_size
    // Move the data for each attribute into the new interleavedBuffer
    // at the appropriate offset
    for c in 0..<count {
      for k in 0..<item_size {
        bgu_set(iba, k, c, bgu_get(attribute, k, c))
      }
    }
  }
  Some(res)
}

///|
/// A non-interleaved copy of an interleaved attribute.
pub fn BufferGeometryUtils::deinterleave_attribute(
  attribute : @core.InterleavedBufferAttribute,
) -> @core.BufferAttribute {
  let count = attribute.count()
  let item_size = attribute.item_size
  let normalized = attribute.normalized
  let array = attribute.data.array.new_like(count * item_size)
  // upstream's `isInstancedInterleavedBufferAttribute` branch: three.js has no such class
  let new_attribute = @core.BufferAttribute::new(array, item_size, normalized~)
  for i in 0..<count {
    ignore(new_attribute.set_x(i, attribute.get_x(i)))
    if item_size >= 2 {
      ignore(new_attribute.set_y(i, attribute.get_y(i)))
    }
    if item_size >= 3 {
      ignore(new_attribute.set_z(i, attribute.get_z(i)))
    }
    if item_size >= 4 {
      ignore(new_attribute.set_w(i, attribute.get_w(i)))
    }
  }
  new_attribute
}

///|
fn bgu_deinterleave_cached(
  attr_map : Array[(@core.InterleavedBufferAttribute, @core.BufferAttribute)],
  attr : @core.InterleavedBufferAttribute,
) -> @core.BufferAttribute {
  for entry in attr_map {
    if physical_equal(entry.0, attr) {
      return entry.1
    }
  }
  let result = BufferGeometryUtils::deinterleave_attribute(attr)
  attr_map.push((attr, result))
  result
}

///|
/// De-interleaves every attribute and morph attribute of `geometry` in place.
pub fn BufferGeometryUtils::deinterleave_geometry(
  geometry : @core.BufferGeometry,
) -> Unit {
  let attributes = geometry.attributes
  let morph_attributes = geometry.morph_attributes
  let attr_map = []
  for key in bgu_keys(attributes) {
    if attributes[key] is Interleaved(attr) {
      attributes[key] = Buffer(bgu_deinterleave_cached(attr_map, attr))
    }
  }
  for key in bgu_keys(morph_attributes) {
    let morph_attribute = morph_attributes[key]
    for i in 0..<morph_attribute.length() {
      if morph_attribute[i] is Interleaved(attr) {
        morph_attribute[i] = Buffer(bgu_deinterleave_cached(attr_map, attr))
      }
    }
  }
}

///|
/// The bytes the attributes and the index of `geometry` use.
pub fn BufferGeometryUtils::estimate_bytes_used(
  geometry : @core.BufferGeometry,
) -> Int32 {
  // Return the estimated memory used by this geometry in bytes
  // Calculate using itemSize, count, and BYTES_PER_ELEMENT to account
  // for InterleavedBufferAttributes.
  let mut mem = 0
  for name in bgu_keys(geometry.attributes) {
    let attr = geometry.get_attribute(name).unwrap()
    mem += attr.count() * attr.item_size() * attr.array().bytes_per_element()
  }
  let indices = geometry.get_index()
  mem += match indices {
    Some(indices) =>
      indices.count() *
      indices.item_size() *
      indices.array().bytes_per_element()
    None => 0
  }
  mem
}

///|
/// A new indexed geometry whose vertices with equal attributes (within `tolerance`) are
/// merged.
pub fn BufferGeometryUtils::merge_vertices(
  geometry : @core.BufferGeometry,
  tolerance~ : Double = 1.0e-4,
) -> @core.BufferGeometry {
  let tolerance = bgu_math_max(tolerance, bgu_epsilon)
  // Generate an index buffer if the geometry doesn't have one, or optimize it
  // if it's already available.
  let hash_to_index : Map[String, Int32] = Map([])
  let indices = geometry.get_index()
  let vertex_count = match indices {
    Some(indices) => indices.count()
    None =>
      match geometry.get_attribute("position") {
        Some(positions) => positions.count()
        None =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'count')",
          )
      }
  }
  // next value for triangle indices
  let mut next_index = 0
  // attributes and new attribute arrays
  let attribute_names = bgu_keys(geometry.attributes)
  let source_indices : Array[Int32] = []
  let buffers = RemapBuffers::new()
  let new_indices : Array[Int32] = []
  // convert the error tolerance to an amount of decimal places to truncate to
  let half_tolerance = tolerance * 0.5
  let exponent = bgu_math_log10(1.0 / tolerance)
  let hash_multiplier = bgu_math_pow(10.0, exponent)
  let hash_additive = half_tolerance * hash_multiplier
  for i in 0..<vertex_count {
    let index = match indices {
      Some(indices) => indices.get_x(i).to_int()
      None => i
    }
    // Generate a hash for the vertex attributes at the current index 'i'
    let hash = StringBuilder()
    for name in attribute_names {
      let attribute = geometry.get_attribute(name).unwrap()
      let item_size = attribute.item_size()
      for k in 0..<item_size {
        // Math.trunc() preserves the full Number range, ~~ would wrap to int32
        hash.write_string(
          bgu_number_string(
            bgu_math_trunc(
              bgu_get(attribute, k, index) * hash_multiplier + hash_additive,
            ),
          ),
        )
        hash.write_char(',')
      }
    }
    let hash = hash.to_string()
    // Add another reference to the vertex if it's already
    // used by another index
    match hash_to_index.get(hash) {
      Some(existing) => new_indices.push(existing)
      None => {
        source_indices.push(index)
        hash_to_index[hash] = next_index
        new_indices.push(next_index)
        next_index += 1
      }
    }
  }
  // generate result BufferGeometry
  let result = geometry.clone()
  for name in bgu_keys(geometry.attributes) {
    ignore(
      result.set_attribute(
        name,
        BufferGeometryUtils::remap_attribute(
          geometry.attributes[name],
          source_indices,
          buffers~,
        ),
      ),
    )
  }
  for name in bgu_keys(geometry.morph_attributes) {
    result.morph_attributes[name] = geometry.morph_attributes[name].map(attribute => {
      BufferGeometryUtils::remap_attribute(attribute, source_indices, buffers~)
    })
  }
  // indices
  ignore(result.set_index(new_indices))
  result
}

///|
/// Rewrites the index of a `TriangleStripDrawMode` or `TriangleFanDrawMode` geometry as
/// triangles, in place.
pub fn BufferGeometryUtils::to_triangles_draw_mode(
  geometry : @core.BufferGeometry,
  draw_mode : Int32,
) -> @core.BufferGeometry {
  if draw_mode == @core.TrianglesDrawMode {
    println(
      "THREE.BufferGeometryUtils.toTrianglesDrawMode(): Geometry already defined as triangles.",
    )
    return geometry
  }
  if draw_mode == @core.TriangleFanDrawMode ||
    draw_mode == @core.TriangleStripDrawMode {
    let mut index = geometry.get_index()
    // generate index if not present
    if index is None {
      let indices : Array[Int32] = []
      match geometry.get_attribute("position") {
        Some(position) => {
          for i in 0..<position.count() {
            indices.push(i)
          }
          ignore(geometry.set_index(indices))
          index = geometry.get_index()
        }
        None => {
          println(
            "THREE.BufferGeometryUtils.toTrianglesDrawMode(): Undefined position attribute. Processing not possible.",
          )
          return geometry
        }
      }
    }
    let index = index.unwrap()
    let number_of_triangles = index.count() - 2
    let new_indices : Array[Double] = []
    if draw_mode == @core.TriangleFanDrawMode {
      // gl.TRIANGLE_FAN
      for i in 1..<=number_of_triangles {
        new_indices.push(index.get_x(0))
        new_indices.push(index.get_x(i))
        new_indices.push(index.get_x(i + 1))
      }
    } else {
      // gl.TRIANGLE_STRIP
      for i in 0..<number_of_triangles {
        if i % 2 == 0 {
          new_indices.push(index.get_x(i))
          new_indices.push(index.get_x(i + 1))
          new_indices.push(index.get_x(i + 2))
        } else {
          new_indices.push(index.get_x(i + 2))
          new_indices.push(index.get_x(i + 1))
          new_indices.push(index.get_x(i))
        }
      }
    }
    if new_indices.length().to_double() / 3.0 != number_of_triangles.to_double() {
      println(
        "THREE.BufferGeometryUtils.toTrianglesDrawMode(): Unable to generate correct amount of triangles.",
      )
    }
    // updated indices
    ignore(geometry.set_index(new_indices))
    geometry.clear_groups()
    geometry
  } else {
    println(
      "THREE.BufferGeometryUtils.toTrianglesDrawMode(): Unknown draw mode: " +
      draw_mode.to_string(),
    )
    geometry
  }
}

///|
/// What `computeMorphedAttributes` returns.
pub(all) struct MorphedAttributes {
  position_attribute : @core.GeometryAttribute
  normal_attribute : @core.GeometryAttribute
  morphed_position_attribute : @core.BufferAttribute
  morphed_normal_attribute : @core.BufferAttribute
}

///|
/// The scratch vectors upstream creates per `computeMorphedAttributes` call.
priv struct BguMorphScratch {
  v_a : @math.Vector3
  v_b : @math.Vector3
  v_c : @math.Vector3
  temp_a : @math.Vector3
  temp_b : @math.Vector3
  temp_c : @math.Vector3
  morph_a : @math.Vector3
  morph_b : @math.Vector3
  morph_c : @math.Vector3
}

///|
fn bgu_calculate_morphed_attribute_data(
  s : BguMorphScratch,
  object : @core.Object3D,
  attribute : @core.GeometryAttribute,
  morph_attribute : Array[@core.GeometryAttribute]?,
  morph_targets_relative : Bool,
  a : Int32,
  b : Int32,
  c : Int32,
  modified_attribute_array : @core.TypedArray,
) -> Unit {
  ignore(s.v_a.from_buffer_attribute(attribute, a))
  ignore(s.v_b.from_buffer_attribute(attribute, b))
  ignore(s.v_c.from_buffer_attribute(attribute, c))
  let morph_influences = object.morph_targets().1
  if morph_attribute is Some(morph_attribute) &&
    morph_influences is Some(morph_influences) {
    ignore(s.morph_a.set(0.0, 0.0, 0.0))
    ignore(s.morph_b.set(0.0, 0.0, 0.0))
    ignore(s.morph_c.set(0.0, 0.0, 0.0))
    for i in 0..<morph_attribute.length() {
      // `morphInfluences[ i ]` past the end is `undefined`, which scales to NaN
      let influence = if i < morph_influences.length() {
        morph_influences[i]
      } else {
        bgu_nan()
      }
      let morph = morph_attribute[i]
      if influence == 0.0 {
        continue
      }
      ignore(s.temp_a.from_buffer_attribute(morph, a))
      ignore(s.temp_b.from_buffer_attribute(morph, b))
      ignore(s.temp_c.from_buffer_attribute(morph, c))
      if morph_targets_relative {
        ignore(s.morph_a.add_scaled_vector(s.temp_a, influence))
        ignore(s.morph_b.add_scaled_vector(s.temp_b, influence))
        ignore(s.morph_c.add_scaled_vector(s.temp_c, influence))
      } else {
        ignore(s.morph_a.add_scaled_vector(s.temp_a.sub(s.v_a), influence))
        ignore(s.morph_b.add_scaled_vector(s.temp_b.sub(s.v_b), influence))
        ignore(s.morph_c.add_scaled_vector(s.temp_c.sub(s.v_c), influence))
      }
    }
    ignore(s.v_a.add(s.morph_a))
    ignore(s.v_b.add(s.morph_b))
    ignore(s.v_c.add(s.morph_c))
  }
  if object.is_skinned_mesh() {
    ignore(object.apply_bone_transform(a, s.v_a))
    ignore(object.apply_bone_transform(b, s.v_b))
    ignore(object.apply_bone_transform(c, s.v_c))
  }
  modified_attribute_array[a * 3 + 0] = s.v_a.x
  modified_attribute_array[a * 3 + 1] = s.v_a.y
  modified_attribute_array[a * 3 + 2] = s.v_a.z
  modified_attribute_array[b * 3 + 0] = s.v_b.x
  modified_attribute_array[b * 3 + 1] = s.v_b.y
  modified_attribute_array[b * 3 + 2] = s.v_b.z
  modified_attribute_array[c * 3 + 0] = s.v_c.x
  modified_attribute_array[c * 3 + 1] = s.v_c.y
  modified_attribute_array[c * 3 + 2] = s.v_c.z
}

///|
/// The positions and normals of a morphed and/or skinned `Mesh`, `Line` or `Points`.
pub fn BufferGeometryUtils::compute_morphed_attributes(
  object : @core.Object3D,
) -> MorphedAttributes {
  let s : BguMorphScratch = {
    v_a: @math.Vector3::new(0.0, 0.0, 0.0),
    v_b: @math.Vector3::new(0.0, 0.0, 0.0),
    v_c: @math.Vector3::new(0.0, 0.0, 0.0),
    temp_a: @math.Vector3::new(0.0, 0.0, 0.0),
    temp_b: @math.Vector3::new(0.0, 0.0, 0.0),
    temp_c: @math.Vector3::new(0.0, 0.0, 0.0),
    morph_a: @math.Vector3::new(0.0, 0.0, 0.0),
    morph_b: @math.Vector3::new(0.0, 0.0, 0.0),
    morph_c: @math.Vector3::new(0.0, 0.0, 0.0),
  }
  guard object.get_geometry() is Some(geometry) else {
    abort("TypeError: Cannot read properties of undefined (reading 'index')")
  }
  let material = object.get_material()
  let index = geometry.index
  guard geometry.attributes.get("position") is Some(position_attribute) else {
    abort("TypeError: Cannot read properties of undefined (reading 'count')")
  }
  let morph_position = geometry.morph_attributes.get("position")
  let morph_targets_relative = geometry.morph_targets_relative
  guard geometry.attributes.get("normal") is Some(normal_attribute) else {
    abort("TypeError: Cannot read properties of undefined (reading 'count')")
  }
  let morph_normal = geometry.morph_attributes.get("normal")
  let groups = geometry.groups
  let draw_range = geometry.draw_range
  let modified_position = @core.TypedArray::float32(
    position_attribute.count() * position_attribute.item_size(),
  )
  let modified_normal = @core.TypedArray::float32(
    normal_attribute.count() * normal_attribute.item_size(),
  )
  let is_multi_material = material is Some(Multiple(_))
  fn triangle(a : Int32, b : Int32, c : Int32) -> Unit {
    bgu_calculate_morphed_attribute_data(
      s, object, position_attribute, morph_position, morph_targets_relative, a, b,
      c, modified_position,
    )
    bgu_calculate_morphed_attribute_data(
      s, object, normal_attribute, morph_normal, morph_targets_relative, a, b, c,
      modified_normal,
    )
  }

  match index {
    Some(index) =>
      // indexed buffer geometry
      if is_multi_material {
        for group in groups {
          let start = bgu_math_max(
            group.start.to_double(),
            draw_range.start.to_double(),
          )
          let end = bgu_math_min(
            group.start.to_double() + group.count,
            draw_range.start.to_double() + draw_range.count,
          )
          let mut j = start
          while j < end {
            let ji = j.to_int()
            triangle(
              index.get_x(ji).to_int(),
              index.get_x(ji + 1).to_int(),
              index.get_x(ji + 2).to_int(),
            )
            j += 3.0
          }
        }
      } else {
        let start = bgu_math_max(0.0, draw_range.start.to_double())
        let end = bgu_math_min(
          index.count().to_double(),
          draw_range.start.to_double() + draw_range.count,
        )
        let mut i = start
        while i < end {
          let ii = i.to_int()
          triangle(
            index.get_x(ii).to_int(),
            index.get_x(ii + 1).to_int(),
            index.get_x(ii + 2).to_int(),
          )
          i += 3.0
        }
      }
    None =>
      // non-indexed buffer geometry
      if is_multi_material {
        for group in groups {
          let start = bgu_math_max(
            group.start.to_double(),
            draw_range.start.to_double(),
          )
          let end = bgu_math_min(
            group.start.to_double() + group.count,
            draw_range.start.to_double() + draw_range.count,
          )
          let mut j = start
          while j < end {
            let ji = j.to_int()
            triangle(ji, ji + 1, ji + 2)
            j += 3.0
          }
        }
      } else {
        let start = bgu_math_max(0.0, draw_range.start.to_double())
        let end = bgu_math_min(
          position_attribute.count().to_double(),
          draw_range.start.to_double() + draw_range.count,
        )
        let mut i = start
        while i < end {
          let ii = i.to_int()
          triangle(ii, ii + 1, ii + 2)
          i += 3.0
        }
      }
  }
  let morphed_position_attribute = @core.Float32BufferAttribute::new(
    modified_position, 3,
  )
  let morphed_normal_attribute = @core.Float32BufferAttribute::new(
    modified_normal, 3,
  )
  {
    position_attribute,
    normal_attribute,
    morphed_position_attribute,
    morphed_normal_attribute,
  }
}

///|
/// Sorts the groups of `geometry` by material and merges neighbours with the same one.
pub fn BufferGeometryUtils::merge_groups(
  geometry : @core.BufferGeometry,
) -> @core.BufferGeometry {
  if geometry.groups.length() == 0 {
    println(
      "THREE.BufferGeometryUtils.mergeGroups(): No groups are defined. Nothing to merge.",
    )
    return geometry
  }
  let groups = geometry.groups
  // sort groups by material index
  @webgl.stable_sort_by(groups, (a, b) => {
    if a.material_index != b.material_index {
      return (a.material_index - b.material_index).to_double()
    }
    (a.start - b.start).to_double()
  })
  // create index for non-indexed geometries
  if geometry.get_index() is None {
    guard geometry.get_attribute("position") is Some(position_attribute) else {
      abort("TypeError: Cannot read properties of undefined (reading 'count')")
    }
    let indices : Array[Int32] = []
    let mut i = 0
    while i < position_attribute.count() {
      indices.push(i)
      indices.push(i + 1)
      indices.push(i + 2)
      i += 3
    }
    ignore(geometry.set_index(indices))
  }
  // sort index
  let index = geometry.get_index().unwrap()
  let new_indices : Array[Double] = []
  let infinity = bgu_infinity()
  for group in groups {
    if group.count == infinity {
      group.count = (index.count() - group.start).to_double()
    }
    let group_start = group.start
    let group_length = group_start.to_double() + group.count
    let mut j = group_start
    while j.to_double() < group_length {
      new_indices.push(index.get_x(j))
      j += 1
    }
  }
  geometry.dispose() // Required to force buffer recreation
  ignore(geometry.set_index(new_indices))
  // update groups indices
  let mut start = 0.0
  for group in groups {
    group.start = start.to_int()
    start += group.count
  }
  // merge groups
  let mut current_group = groups[0]
  geometry.groups = [current_group]
  for i in 1..<groups.length() {
    let group = groups[i]
    if current_group.material_index == group.material_index {
      current_group.count += group.count
    } else {
      current_group = group
      geometry.groups.push(current_group)
    }
  }
  geometry
}

///|
/// Smooth normals except across edges sharper than `crease_angle`; de-indexes indexed
/// geometries.
pub fn BufferGeometryUtils::to_creased_normals(
  geometry : @core.BufferGeometry,
  crease_angle~ : Double = 3.141592653589793 / 3.0, // 60 degrees
) -> @core.BufferGeometry {
  // BufferGeometry.toNonIndexed() warns if the geometry is non-indexed
  // and returns the original geometry
  let result_geometry = if geometry.index is Some(_) {
    geometry.to_non_indexed()
  } else {
    geometry
  }
  guard result_geometry.attributes.get("position") is Some(pos_attr) else {
    abort("TypeError: Cannot read properties of undefined (reading 'count')")
  }
  let vertex_count = pos_attr.count()
  let positions = match pos_attr {
    Buffer(a) if a.item_size == 3 && !a.normalized => a.array
    _ => {
      // flatten the position buffer so the math below operates on plain numbers
      let positions = @core.TypedArray::float64(vertex_count * 3)
      for i in 0..<vertex_count {
        positions[3 * i + 0] = pos_attr.get_x(i)
        positions[3 * i + 1] = pos_attr.get_y(i)
        positions[3 * i + 2] = pos_attr.get_z(i)
      }
      positions
    }
  }
  let crease_dot = bgu_math_cos(crease_angle)
  let hash_multiplier = (1.0 + 1.0e-10) * 1.0e2
  let face_count = vertex_count / 3
  // compute the normal of each face
  let face_normals : FixedArray[Double] = FixedArray::make(face_count * 3, 0.0)
  for f in 0..<face_count {
    let f9 = 9 * f
    let ax = positions[f9 + 0]
    let ay = positions[f9 + 1]
    let az = positions[f9 + 2]
    let bx = positions[f9 + 3]
    let by = positions[f9 + 4]
    let bz = positions[f9 + 5]
    let cx = positions[f9 + 6]
    let cy = positions[f9 + 7]
    let cz = positions[f9 + 8]
    let v1x = cx - bx
    let v1y = cy - by
    let v1z = cz - bz
    let v2x = ax - bx
    let v2y = ay - by
    let v2z = az - bz
    let nx = v1y * v2z - v1z * v2y
    let ny = v1z * v2x - v1x * v2z
    let nz = v1x * v2y - v1y * v2x
    let inv_length = 1.0 /
      bgu_or_one(bgu_math_sqrt(nx * nx + ny * ny + nz * nz))
    face_normals[3 * f + 0] = nx * inv_length
    face_normals[3 * f + 1] = ny * inv_length
    face_normals[3 * f + 2] = nz * inv_length
  }
  // assign an id to each vertex, sharing the id between vertices with the same
  // quantized position via an open-addressed hash table (slots hold id + 1, 0 means empty)
  let vertex_ids : FixedArray[Int32] = FixedArray::make(vertex_count, 0)
  let quantized : FixedArray[Double] = FixedArray::make(vertex_count * 3, 0.0)
  let mut table_size = 1
  while table_size < vertex_count * 2 {
    table_size = table_size << 1
  }
  let table_mask = table_size - 1
  let table : FixedArray[Int32] = FixedArray::make(table_size, 0)
  let mut unique_count = 0
  for i in 0..<vertex_count {
    let i3 = 3 * i
    let qx = bgu_math_trunc(positions[i3 + 0] * hash_multiplier)
    let qy = bgu_math_trunc(positions[i3 + 1] * hash_multiplier)
    let qz = bgu_math_trunc(positions[i3 + 2] * hash_multiplier)
    let mut slot = (
        bgu_math_imul(qx, 73856093.0) ^
        bgu_math_imul(qy, 19349663.0) ^
        bgu_math_imul(qz, 83492791.0)
      ) &
      table_mask
    while true {
      let id = table[slot]
      if id == 0 {
        let q3 = 3 * unique_count
        quantized[q3 + 0] = qx
        quantized[q3 + 1] = qy
        quantized[q3 + 2] = qz
        table[slot] = unique_count + 1
        vertex_ids[i] = unique_count
        unique_count += 1
        break
      }
      let q3 = 3 * (id - 1)
      if quantized[q3 + 0] == qx &&
        quantized[q3 + 1] == qy &&
        quantized[q3 + 2] == qz {
        vertex_ids[i] = id - 1
        break
      }
      slot = (slot + 1) & table_mask
    }
  }
  // bucket the faces surrounding each unique vertex position
  let bucket_offsets : FixedArray[Int32] = FixedArray::make(unique_count + 1, 0)
  for i in 0..<vertex_count {
    bucket_offsets[vertex_ids[i] + 1] += 1
  }
  for i in 0..<unique_count {
    bucket_offsets[i + 1] += bucket_offsets[i]
  }
  let bucket_faces : FixedArray[Int32] = FixedArray::make(vertex_count, 0)
  let bucket_cursors : FixedArray[Int32] = FixedArray::make(unique_count, 0)
  for i in 0..<unique_count {
    bucket_cursors[i] = bucket_offsets[i]
  }
  for f in 0..<face_count {
    let f3 = 3 * f
    for n in 0..<3 {
      let id = vertex_ids[f3 + n]
      bucket_faces[bucket_cursors[id]] = f
      bucket_cursors[id] += 1
    }
  }
  // average the normals of the faces surrounding each vertex if they are within the
  // provided crease threshold
  let normal_array = @core.TypedArray::float32(vertex_count * 3)
  for f in 0..<face_count {
    let f3 = 3 * f
    let nx = face_normals[f3 + 0]
    let ny = face_normals[f3 + 1]
    let nz = face_normals[f3 + 2]
    for n in 0..<3 {
      let i = f3 + n
      let id = vertex_ids[i]
      let mut sum_x = 0.0
      let mut sum_y = 0.0
      let mut sum_z = 0.0
      for k in bucket_offsets[id]..<bucket_offsets[id + 1] {
        let o3 = 3 * bucket_faces[k]
        let ox = face_normals[o3 + 0]
        let oy = face_normals[o3 + 1]
        let oz = face_normals[o3 + 2]
        if nx * ox + ny * oy + nz * oz > crease_dot {
          sum_x += ox
          sum_y += oy
          sum_z += oz
        }
      }
      let inv_length = 1.0 /
        bgu_or_one(bgu_math_sqrt(sum_x * sum_x + sum_y * sum_y + sum_z * sum_z))
      normal_array[3 * i + 0] = sum_x * inv_length
      normal_array[3 * i + 1] = sum_y * inv_length
      normal_array[3 * i + 2] = sum_z * inv_length
    }
  }
  ignore(
    result_geometry.set_attribute(
      "normal",
      @core.BufferAttribute::new(normal_array, 3, normalized=false),
    ),
  )
  result_geometry
}

///|
/// Upstream's `Map<InterleavedBuffer, InterleavedBuffer>` of `remapAttribute`, keyed by
/// identity.
pub struct RemapBuffers {
  priv entries : Array[(@core.InterleavedBuffer, @core.InterleavedBuffer)]
}

///|
pub fn RemapBuffers::new() -> RemapBuffers {
  { entries: [], }
}

///|
fn RemapBuffers::get(
  self : RemapBuffers,
  source : @core.InterleavedBuffer,
) -> @core.InterleavedBuffer? {
  for entry in self.entries {
    if physical_equal(entry.0, source) {
      return Some(entry.1)
    }
  }
  None
}

///|
fn RemapBuffers::set(
  self : RemapBuffers,
  source : @core.InterleavedBuffer,
  data : @core.InterleavedBuffer,
) -> Unit {
  for i, entry in self.entries {
    if physical_equal(entry.0, source) {
      self.entries[i] = (source, data)
      return
    }
  }
  self.entries.push((source, data))
}

///|
/// `new attribute.constructor( array, itemSize, normalized, meshPerAttribute )` for the
/// attribute classes the port tells apart by `kind`.
fn bgu_construct_like(
  attribute : @core.BufferAttribute,
  array : @core.TypedArray,
) -> @core.BufferAttribute {
  match attribute.kind {
    PlainAttribute =>
      @core.BufferAttribute::new(
        array,
        attribute.item_size,
        normalized=attribute.normalized,
      )
    Float16Attribute =>
      @core.Float16BufferAttribute::new(
        array,
        attribute.item_size,
        normalized=attribute.normalized,
      )
    InstancedAttribute =>
      @core.InstancedBufferAttribute::new(
        array,
        attribute.item_size,
        normalized=attribute.normalized,
        mesh_per_attribute=attribute.mesh_per_attribute,
      )
    // `StorageBufferAttribute( array, itemSize )` ignores the other arguments
    StorageAttribute => {
      let result = @core.BufferAttribute::new(array, attribute.item_size)
      result.kind = StorageAttribute
      result
    }
    StorageInstancedAttribute => {
      let result = @core.InstancedBufferAttribute::new(
        array,
        attribute.item_size,
      )
      result.kind = StorageInstancedAttribute
      result
    }
  }
}

///|
/// Copies the entries of `attribute` in the order of `source_indices`, keeping raw values,
/// type and metadata; `buffers` shares the copies of interleaved buffers across calls.
pub fn BufferGeometryUtils::remap_attribute(
  attribute : @core.GeometryAttribute,
  source_indices : Array[Int32],
  buffers~ : RemapBuffers = RemapBuffers::new(),
) -> @core.GeometryAttribute {
  match attribute {
    Interleaved(attribute) => {
      let source = attribute.data
      let stride = source.stride
      let data = match buffers.get(source) {
        Some(data) => data
        None => {
          let array = source.array.new_like(source_indices.length() * stride)
          for i in 0..<source_indices.length() {
            for j in 0..<stride {
              array[i * stride + j] = source.array[source_indices[i] * stride +
                j]
            }
          }
          let data = if source.is_instanced_interleaved_buffer {
            @core.InstancedInterleavedBuffer::new(
              array,
              stride,
              mesh_per_attribute=source.mesh_per_attribute,
            )
          } else {
            @core.InterleavedBuffer::new(array, stride)
          }
          ignore(data.set_usage(source.usage))
          buffers.set(source, data)
          data
        }
      }
      let result = @core.InterleavedBufferAttribute::new(
        data,
        attribute.item_size,
        attribute.offset,
        normalized=attribute.normalized,
      )
      result.name = attribute.name
      Interleaved(result)
    }
    Buffer(attribute) => {
      let stride = attribute.item_size
      let array = attribute.array.new_like(source_indices.length() * stride)
      for i in 0..<source_indices.length() {
        for j in 0..<stride {
          array[i * stride + j] = attribute.array[source_indices[i] * stride + j]
        }
      }
      let data = bgu_construct_like(attribute, array)
      ignore(data.set_usage(attribute.usage))
      data.name = attribute.name
      data.gpu_type = attribute.gpu_type
      Buffer(data)
    }
    GL(_) =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'constructor')",
      )
  }
}
