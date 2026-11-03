// nodes/core/NodeParser.js. Backends set `parse_function` (WGSLNodeParser,
// GLSLNodeParser).

///|
pub(all) struct NodeParser {
  /// `parseFunction( source )`; `None` is the abstract base, which warns.
  mut parse_function_impl : ((String) -> NodeFunction)?
}

///|
pub fn NodeParser::new() -> NodeParser {
  { parse_function_impl: None, }
}

///|
pub fn NodeParser::parse_function(
  self : NodeParser,
  source : String,
) -> NodeFunction? {
  match self.parse_function_impl {
    Some(f) => Some(f(source))
    None => {
      @core.warn("Abstract function.")
      None
    }
  }
}
