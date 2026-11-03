// renderers/webgpu/nodes/WGSLNodeParser.js

///|
/// `new WGSLNodeParser()`: a `NodeParser` whose `parseFunction` returns a
/// `WGSLNodeFunction`.
#external
pub type WGSLNodeParser

///|
/// `new WGSLNodeParser()`.
pub fn WGSLNodeParser::new() -> @nodes.NodeParser {
  let parser = @nodes.NodeParser::new()
  parser.parse_function_impl = Some(fn(source) { WGSLNodeFunction::new(source) })
  parser
}
