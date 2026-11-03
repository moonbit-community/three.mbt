// nodes/parsers/GLSLNodeParser.js

///|
/// `new GLSLNodeParser()`: a `NodeParser` whose `parseFunction` returns a
/// `GLSLNodeFunction`.
#external
pub type GLSLNodeParser

///|
/// `new GLSLNodeParser()`.
pub fn GLSLNodeParser::new() -> NodeParser {
  let parser = NodeParser::new()
  parser.parse_function_impl = Some(fn(source) { GLSLNodeFunction::new(source) })
  parser
}
