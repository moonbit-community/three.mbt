// materials/nodes/NodeMaterials.js: the node materials (the flat package re-exports
// them). `node_materials()` is the `import * as NodeMaterials` object that
// `NodeObjectLoader.setNodeMaterials` takes.

///|
/// The node material classes of NodeMaterials.js that construct without arguments,
/// by `type`.
pub fn node_materials() -> Map[String, () -> @core.Material] {
  Map([
    ("NodeMaterial", NodeMaterial::new),
    ("LineBasicNodeMaterial", LineBasicNodeMaterial::new),
    ("LineDashedNodeMaterial", LineDashedNodeMaterial::new),
    ("Line2NodeMaterial", fn() { Line2NodeMaterial::new() }),
    ("MeshNormalNodeMaterial", MeshNormalNodeMaterial::new),
    ("MeshBasicNodeMaterial", MeshBasicNodeMaterial::new),
    ("MeshLambertNodeMaterial", MeshLambertNodeMaterial::new),
    ("MeshPhongNodeMaterial", MeshPhongNodeMaterial::new),
    ("MeshStandardNodeMaterial", MeshStandardNodeMaterial::new),
    ("MeshPhysicalNodeMaterial", MeshPhysicalNodeMaterial::new),
    ("MeshSSSNodeMaterial", MeshSSSNodeMaterial::new),
    ("MeshToonNodeMaterial", MeshToonNodeMaterial::new),
    ("MeshMatcapNodeMaterial", MeshMatcapNodeMaterial::new),
    ("PointsNodeMaterial", PointsNodeMaterial::new),
    ("SpriteNodeMaterial", SpriteNodeMaterial::new),
    ("ShadowNodeMaterial", ShadowNodeMaterial::new),
    ("VolumeNodeMaterial", VolumeNodeMaterial::new),
  ])
}

///|
/// The core material types `StandardNodeLibrary` maps to node materials
/// (`addMaterial( MeshPhongNodeMaterial, 'MeshPhongMaterial' )`, ...), in its order.
pub fn standard_node_material_library() -> Array[(() -> @core.Material, String)] {
  [
    (MeshPhongNodeMaterial::new, "MeshPhongMaterial"),
    (MeshStandardNodeMaterial::new, "MeshStandardMaterial"),
    (MeshPhysicalNodeMaterial::new, "MeshPhysicalMaterial"),
    (MeshToonNodeMaterial::new, "MeshToonMaterial"),
    (MeshBasicNodeMaterial::new, "MeshBasicMaterial"),
    (MeshLambertNodeMaterial::new, "MeshLambertMaterial"),
    (MeshNormalNodeMaterial::new, "MeshNormalMaterial"),
    (MeshMatcapNodeMaterial::new, "MeshMatcapMaterial"),
    (LineBasicNodeMaterial::new, "LineBasicMaterial"),
    (LineDashedNodeMaterial::new, "LineDashedMaterial"),
    (PointsNodeMaterial::new, "PointsMaterial"),
    (SpriteNodeMaterial::new, "SpriteMaterial"),
    (ShadowNodeMaterial::new, "ShadowMaterial"),
  ]
}
