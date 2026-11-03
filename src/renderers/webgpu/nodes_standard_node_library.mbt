// renderers/webgpu/nodes/StandardNodeLibrary.js: the library of WebGPURenderer, mapping
// the core materials to node materials and adding the tone mapping functions (its light
// node registrations are in nodes_basic_node_library.mbt, run at package load).

///|
/// `new StandardNodeLibrary()`.
#external
pub type StandardNodeLibrary

///|
/// `new StandardNodeLibrary()`.
pub fn StandardNodeLibrary::new() -> @nodes.NodeLibrary {
  let library = @nodes.NodeLibrary::new()
  library.add_material(@nodes.MeshPhongNodeMaterial::new, "MeshPhongMaterial")
  library.add_material(
    @nodes.MeshStandardNodeMaterial::new,
    "MeshStandardMaterial",
  )
  library.add_material(
    @nodes.MeshPhysicalNodeMaterial::new,
    "MeshPhysicalMaterial",
  )
  library.add_material(@nodes.MeshToonNodeMaterial::new, "MeshToonMaterial")
  library.add_material(@nodes.MeshBasicNodeMaterial::new, "MeshBasicMaterial")
  library.add_material(
    @nodes.MeshLambertNodeMaterial::new,
    "MeshLambertMaterial",
  )
  library.add_material(@nodes.MeshNormalNodeMaterial::new, "MeshNormalMaterial")
  library.add_material(@nodes.MeshMatcapNodeMaterial::new, "MeshMatcapMaterial")
  library.add_material(@nodes.LineBasicNodeMaterial::new, "LineBasicMaterial")
  library.add_material(@nodes.LineDashedNodeMaterial::new, "LineDashedMaterial")
  library.add_material(@nodes.PointsNodeMaterial::new, "PointsMaterial")
  library.add_material(@nodes.SpriteNodeMaterial::new, "SpriteMaterial")
  library.add_material(@nodes.ShadowNodeMaterial::new, "ShadowMaterial")
  _wgsl_add_tone_mappings(library)
  library
}
