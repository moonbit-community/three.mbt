// nodes/parsers/GLSLNodeFunction.js. The regular expressions run in JS, so their
// semantics (`\s`, `i` flags, lazy matching) are upstream's.

///|
/// The GLSL-specific parts of a parsed function: `inputsCode`, `blockCode`,
/// `headerCode`. Stored as the `NodeFunction` payload.
pub(all) struct GLSLNodeFunction {
  mut inputs_code : String
  mut block_code : String
  mut header_code : String
}

///|
/// `mainCode`: the source after `#pragma main` (if any), without leading comments
/// and whitespace; and the index of the pragma (-1 without one).
extern "js" fn glsl_node_function_main_code(source : String) -> @core.JsValue =
  #|(source) => {
  #|  const pragmaMain = '#pragma main';
  #|  const pragmaMainIndex = source.indexOf( pragmaMain );
  #|  const mainCode = ( pragmaMainIndex !== - 1 ? source.slice( pragmaMainIndex + pragmaMain.length ) : source ).replace( /^(?:\s*\/\/[^\r\n]*|\s*\/\*[\s\S]*?\*\/|\s*)+/, '' );
  #|  return [ pragmaMainIndex, mainCode ];
  #|}

///|
/// `mainCode.match( declarationRegexp )` as `[ match, precision, type, name, inputs ]`
/// with `''` for unmatched groups and a flag for each, or `null`.
extern "js" fn glsl_node_function_declaration(
  main_code : String,
) -> @core.JsValue =
  #|(mainCode) => {
  #|  const m = mainCode.match( /^\s*(highp|mediump|lowp)?\s*([a-z_0-9]+)\s*([a-z_0-9]+)?\s*\(([\s\S]*?)\)/i );
  #|  if ( m === null || m.length !== 5 ) return null;
  #|  return [ m[ 0 ], m[ 1 ] ?? '', m[ 2 ], m[ 3 ] ?? '', m[ 4 ], m[ 1 ] !== undefined, m[ 3 ] !== undefined ];
  #|}

///|
/// The tokens of `/[a-z_0-9]+/ig` in the inputs code.
extern "js" fn glsl_node_function_tokens_js(
  inputs_code : String,
) -> @core.JsValue = "(inputsCode) => inputsCode.match( /[a-z_0-9]+/ig ) ?? []"

///|
extern "js" fn glsl_node_function_length(value : @core.JsValue) -> Int32 = "(a) => a.length"

///|
fn glsl_node_function_tokens(inputs_code : String) -> Array[String] {
  let tokens = glsl_node_function_tokens_js(inputs_code)
  Array::makei(glsl_node_function_length(tokens), fn(i) {
    glsl_node_function_get_string(tokens, i)
  })
}

///|
/// `Number.parseInt( token )`, `None` for `NaN`.
extern "js" fn glsl_node_function_parse_int_js(token : String) -> Double = "(s) => Number.parseInt( s )"

///|
extern "js" fn glsl_node_function_trim(s : String) -> String = "(s) => s.trim()"

///|
extern "js" fn glsl_node_function_get_int(
  value : @core.JsValue,
  i : Int32,
) -> Int32 = "(a, i) => a[ i ]"

///|
extern "js" fn glsl_node_function_get_string(
  value : @core.JsValue,
  i : Int32,
) -> String = "(a, i) => a[ i ]"

///|
extern "js" fn glsl_node_function_get_bool(
  value : @core.JsValue,
  i : Int32,
) -> Bool = "(a, i) => a[ i ]"

///|
fn glsl_node_function_token(tokens : Array[String], i : Int32) -> String {
  if i < tokens.length() {
    tokens[i]
  } else {
    abort("TypeError: Cannot read properties of undefined (reading '0')")
  }
}

///|
/// `new GLSLNodeFunction( source )`: parses a GLSL function declaration.
pub fn GLSLNodeFunction::new(source : String) -> NodeFunction {
  let source = glsl_node_function_trim(source)
  let main = glsl_node_function_main_code(source)
  let pragma_main_index = glsl_node_function_get_int(main, 0)
  let main_code = glsl_node_function_get_string(main, 1)
  let declaration = glsl_node_function_declaration(main_code)
  if declaration.is_null() {
    abort("THREE.FunctionNode: Function is not a GLSL code.")
  }
  // tokenizer
  let inputs_code = glsl_node_function_get_string(declaration, 4)
  let props_matches = glsl_node_function_tokens(inputs_code)
  // parser
  let inputs = []
  let mut i = 0
  while i < props_matches.length() {
    let is_const = glsl_node_function_token(props_matches, i) == "const"
    if is_const {
      i += 1
    }
    let mut qualifier = glsl_node_function_token(props_matches, i)
    if qualifier == "in" || qualifier == "out" || qualifier == "inout" {
      i += 1
    } else {
      qualifier = ""
    }
    let type_ = glsl_node_function_token(props_matches, i)
    i += 1
    let parsed = glsl_node_function_parse_int_js(
      glsl_node_function_token(props_matches, i),
    )
    let count = if parsed.is_nan() {
      None
    } else {
      i += 1
      Some(parsed.to_int())
    }
    let name = glsl_node_function_token(props_matches, i)
    i += 1
    inputs.push(
      NodeFunctionInput::new(type_, name, count?, qualifier~, is_const~),
    )
  }
  let block_code = main_code.unsafe_substring(
    start=glsl_node_function_get_string(declaration, 0).length(),
    end=main_code.length(),
  )
  let name = if glsl_node_function_get_bool(declaration, 6) {
    glsl_node_function_get_string(declaration, 3)
  } else {
    ""
  }
  let type_ = glsl_node_function_get_string(declaration, 2)
  let precision = if glsl_node_function_get_bool(declaration, 5) {
    glsl_node_function_get_string(declaration, 1)
  } else {
    ""
  }
  let header_code = if pragma_main_index != -1 {
    source.unsafe_substring(start=0, end=pragma_main_index)
  } else {
    ""
  }
  let glsl = GLSLNodeFunction::{ inputs_code, block_code, header_code, }
  let node_function = NodeFunction::new(type_, inputs, name~, precision~)
  node_function.payload = @core.JsValue::of(glsl)
  node_function.get_code_impl = Some(fn(f, name) { glsl.get_code(f, name) })
  node_function
}

///|
/// The GLSL parts of a `NodeFunction` made by `GLSLNodeFunction::new`.
pub fn GLSLNodeFunction::of(node_function : NodeFunction) -> GLSLNodeFunction? {
  if node_function.payload.is_undefined() {
    None
  } else {
    Some(node_function.payload.cast())
  }
}

///|
/// `getCode( name = this.name )`: the function's GLSL code under `name`.
pub fn GLSLNodeFunction::get_code(
  self : GLSLNodeFunction,
  node_function : NodeFunction,
  name : String,
) -> String {
  let block_code = self.block_code
  if block_code != "" {
    let type_ = node_function.type_
    let precision = node_function.precision
    let mut declaration_code = "\{type_} \{name} ( \{glsl_node_function_trim(self.inputs_code)} )"
    if precision != "" {
      declaration_code = "\{precision} \{declaration_code}"
    }
    self.header_code + declaration_code + block_code
  } else {
    // interface function
    ""
  }
}
