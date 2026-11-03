// The G5 loader records (`g5_json_*`): NodeMaterial.toJSON, then NodeMaterialLoader /
// NodeObjectLoader parse and toJSON again, compared with harness/shader_diff/
// upstream_g5.mjs by run.mjs (uuids normalized to their order of appearance).

///|
extern "js" fn g5_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.SHADER_DIFF === '1'"

///|
extern "js" fn g5_json3(
  code : String,
  result : String,
  vars : String,
) -> String = "(code, result, vars) => JSON.stringify({ code, result, vars })"

///|
extern "js" fn g5_json_code_result(code : String, result : String) -> String = "(code, result) => JSON.stringify({ code, result })"

///|
extern "js" fn g5_normalize(text : String) -> String =
  #|(s) => {
  #|  const ids = new Map();
  #|  s = s.replace( /"version":\d+,"shared"/g, '"version":#,"shared"' );
  #|  return s.replace( /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, ( u ) => {
  #|    if ( ! ids.has( u ) ) ids.set( u, '#' + ids.size );
  #|    return ids.get( u );
  #|  } );
  #|}

///|
fn g5_emit(name : String, record : String) -> Unit {
  if g5_enabled() {
    println("@@SHADER \{name} \{record}")
  }
}

///|
fn g5_nm(m : @core.Material) -> @tsl.NodeMaterial {
  @tsl.NodeMaterial::of(m).unwrap()
}

///|
fn g5_parse_node_material(json : Json) -> @core.Material {
  let loader = @nodes.NodeMaterialLoader::new()
  loader.set_node_materials(@tsl.node_materials()) |> ignore
  loader.parse(json)
}

///|
/// The error upstream's `NodeLoader` throws for any node (`node.uuid` has only a
/// getter); the MoonBit loader aborts with it, so these records do not run it.
let g5_uuid_error : String = "TypeError: Cannot set property uuid of #<Node> which has only a getter"

///|
fn g5_has_nodes(json : Json) -> Bool {
  match json {
    Object(o) => o.get("nodes") is Some(Array(a)) && a.length() > 0
    _ => false
  }
}

///|
test "g5 JSON records" {
  let cases : Array[(String, () -> @core.Material)] = [
    (
      "standard",
      fn() {
        let m = @tsl.MeshStandardNodeMaterial::new()
        m.name = "std"
        m.roughness = Some(0.25)
        m.color.unwrap().set_hex(0x123456) |> ignore
        g5_nm(m).color_node = Some(
          @tsl.uniform(@math.Color::from_hex(0xff0000)),
        )
        g5_nm(m).opacity_node = Some(@tsl.float(0.5))
        @tsl.MeshStandardNodeMaterial::of(m).unwrap().roughness_node = Some(
          @tsl.uniform(0.75),
        )
        m
      },
    ),
    (
      "physical",
      fn() {
        let m = @tsl.MeshPhysicalNodeMaterial::new()
        m.set_clearcoat(1)
        m.sheen_color.unwrap().set_hex(0x00ff00) |> ignore
        @tsl.MeshPhysicalNodeMaterial::of(m).unwrap().clearcoat_node = Some(
          @tsl.float(0.25),
        )
        let map = @core.Texture::new()
        m.map = Some(map)
        @tsl.MeshPhysicalNodeMaterial::of(m).unwrap().standard.emissive_node = Some(
          @tsl.texture(map),
        )
        m
      },
    ),
    ("basic_empty", @tsl.MeshBasicNodeMaterial::new),
    (
      "line_dashed",
      fn() {
        let m = @tsl.LineDashedNodeMaterial::new()
        let p = @tsl.LineDashedNodeMaterial::of(m).unwrap()
        p.dash_offset = 3
        p.dash_size_node = Some(@tsl.float(2))
        m
      },
    ),
    (
      "points",
      fn() {
        let m = @tsl.PointsNodeMaterial::new()
        @tsl.PointsNodeMaterial::of(m).unwrap().size_node = Some(
          @tsl.uniform(4),
        )
        m.size = Some(2)
        m
      },
    ),
  ]
  for entry in cases {
    let material = (entry.1)()
    let json = @tsl.NodeMaterial::to_json(material)
    let first = g5_normalize(json.stringify())
    if g5_has_nodes(json) {
      g5_emit("g5_json_" + entry.0, g5_json3(first, g5_uuid_error, ""))
      continue
    }
    let parsed = g5_parse_node_material(json)
    g5_emit(
      "g5_json_" + entry.0,
      g5_json3(
        first,
        g5_normalize(@tsl.NodeMaterial::to_json(parsed).stringify()),
        parsed.type_ + ",0",
      ),
    )
  }
}

///|
test "g5 object loader records" {
  // a scene whose node material has node slots: upstream's NodeLoader throws
  let m = @tsl.MeshPhongNodeMaterial::new()
  g5_nm(m).color_node = Some(@tsl.uniform(@math.Color::from_hex(0x00ff00)))
  @tsl.MeshPhongNodeMaterial::of(m).unwrap().shininess_node = Some(
    @tsl.float(8),
  )
  let mesh = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(),
    material=Single(m),
  )
  mesh.name = "box"
  let scene = @core.Scene::new()
  scene.add(mesh) |> ignore
  let json = scene.to_json()
  g5_emit(
    "g5_json_object_loader",
    g5_json_code_result(g5_normalize(json.stringify()), g5_uuid_error),
  )
  // a scene whose node material has no node slots parses
  let plain = @core.Scene::new()
  plain.add(
    @core.Mesh::new(
      geometry=@geometries.BoxGeometry::new(),
      material=Single(@tsl.MeshToonNodeMaterial::new()),
    ),
  )
  |> ignore
  let plain_json = plain.to_json()
  let loader = @nodes.NodeObjectLoader::new()
  loader.set_node_materials(@tsl.node_materials()) |> ignore
  let parsed = loader.parse(plain_json)
  let material = match parsed.children[0].get_material() {
    Some(Single(m)) => m
    _ => abort("no material")
  }
  g5_emit(
    "g5_json_object_loader_plain",
    g5_json3(
      g5_normalize(plain_json.stringify()),
      g5_normalize(parsed.to_json().stringify()),
      material.type_,
    ),
  )
}
