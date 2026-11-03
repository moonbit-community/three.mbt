// renderers/webgpu/nodes/BasicNodeLibrary.js: the library of a renderer that only needs
// tone mapping (no node materials), and the light node registrations both libraries
// make at module load.

///|
/// `PointLight.registerNode( PointLightNode )` and the other light classes, as both
/// library modules do when they load.
fn _wgsl_register_light_nodes() -> Unit {
  @core.Light::register_node("PointLight", @nodes.PointLightNode::node_class())
  @core.Light::register_node(
    "DirectionalLight",
    @nodes.DirectionalLightNode::node_class(),
  )
  @core.Light::register_node(
    "RectAreaLight",
    @nodes.RectAreaLightNode::node_class(),
  )
  @core.Light::register_node("SpotLight", @nodes.SpotLightNode::node_class())
  @core.Light::register_node(
    "AmbientLight",
    @nodes.AmbientLightNode::node_class(),
  )
  @core.Light::register_node(
    "HemisphereLight",
    @nodes.HemisphereLightNode::node_class(),
  )
  @core.Light::register_node("LightProbe", @nodes.LightProbeNode::node_class())
  @core.Light::register_node(
    "IESSpotLight",
    @nodes.IESSpotLightNode::node_class(),
  )
  @core.Light::register_node(
    "ProjectorLight",
    @nodes.ProjectorLightNode::node_class(),
  )
}

///|
fn init {
  _wgsl_register_light_nodes()
}

///|
/// `addToneMapping` of the six built-in tone mappings, as both library constructors do.
fn _wgsl_add_tone_mappings(library : @nodes.NodeLibrary) -> Unit {
  library.add_tone_mapping(@nodes.linear_tone_mapping, @core.LinearToneMapping)
  library.add_tone_mapping(
    @nodes.reinhard_tone_mapping,
    @core.ReinhardToneMapping,
  )
  library.add_tone_mapping(@nodes.cineon_tone_mapping, @core.CineonToneMapping)
  library.add_tone_mapping(
    @nodes.aces_filmic_tone_mapping,
    @core.ACESFilmicToneMapping,
  )
  library.add_tone_mapping(@nodes.agx_tone_mapping, @core.AgXToneMapping)
  library.add_tone_mapping(
    @nodes.neutral_tone_mapping,
    @core.NeutralToneMapping,
  )
}

///|
/// `new BasicNodeLibrary()`: a `NodeLibrary` with the tone mapping functions.
#external
pub type BasicNodeLibrary

///|
/// `new BasicNodeLibrary()`.
pub fn BasicNodeLibrary::new() -> @nodes.NodeLibrary {
  let library = @nodes.NodeLibrary::new()
  _wgsl_add_tone_mappings(library)
  library
}
