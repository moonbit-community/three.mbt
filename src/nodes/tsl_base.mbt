// nodes/tsl/TSLBase.js only re-exports TSLCore and the core TSL modules (ArrayNode,
// UniformNode, PropertyNode, AssignNode, FunctionCallNode, OperatorNode, MathNode,
// ConditionalNode, ContextNode, VarNode, VaryingNode, ColorSpaceNode, ToneMappingNode,
// BufferAttributeNode, ComputeNode, IsolateNode, BypassNode, Remap, ExpressionNode,
// Discard, RenderOutputNode, DebugNode, SubBuildNode, InspectorNode). One package holds
// them all, so there is nothing to re-export here.

///|
/// `addNodeElement( name )`: removed upstream in favor of tree-shaking; only warns.
pub fn add_node_element(name : String) -> Unit {
  @core.warn(
    "TSL: AddNodeElement has been removed in favor of tree-shaking. Trying add \{name}",
  )
}
