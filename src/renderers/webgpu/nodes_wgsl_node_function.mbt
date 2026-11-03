// renderers/webgpu/nodes/WGSLNodeFunction.js. The regular expressions run in JS, so
// their semantics (`\s`, the `i`/`g` flags, lazy matching) are upstream's.

///|
/// The WGSL-specific parts of a parsed function, stored as the `NodeFunction` payload.
pub(all) struct WGSLNodeFunction {
  mut inputs_code : String
  mut block_code : String
  mut output_type : String
}

///|
/// `parse( source )` of WGSLNodeFunction.js, verbatim (with its `wgslTypeLib`):
/// `[ type, [ [ type, name ] ], name, inputsCode, blockCode, outputType ]`, or `null`
/// when the source is not a WGSL function. An input type upstream maps to `undefined`
/// is the string `'undefined'`.
extern "js" fn _wgsl_node_function_parse(source : String) -> @core.JsValue =
  #|( source ) => {
  #|  const declarationRegexp = /^[fn]*\s*([a-z_0-9]+)?\s*\(([\s\S]*?)\)\s*[\-\>]*\s*([a-z_0-9]+(?:<[\s\S]+?>)?)/i;
  #|  const propertiesRegexp = /([a-z_0-9]+)\s*:\s*([a-z_0-9]+(?:<[\s\S]+?>)?)/ig;
  #|  const wgslTypeLib = {
  #|    'f32': 'float', 'i32': 'int', 'u32': 'uint', 'bool': 'bool',
  #|    'vec2<f32>': 'vec2', 'vec2<i32>': 'ivec2', 'vec2<u32>': 'uvec2', 'vec2<bool>': 'bvec2',
  #|    'vec2f': 'vec2', 'vec2i': 'ivec2', 'vec2u': 'uvec2', 'vec2b': 'bvec2',
  #|    'vec3<f32>': 'vec3', 'vec3<i32>': 'ivec3', 'vec3<u32>': 'uvec3', 'vec3<bool>': 'bvec3',
  #|    'vec3f': 'vec3', 'vec3i': 'ivec3', 'vec3u': 'uvec3', 'vec3b': 'bvec3',
  #|    'vec4<f32>': 'vec4', 'vec4<i32>': 'ivec4', 'vec4<u32>': 'uvec4', 'vec4<bool>': 'bvec4',
  #|    'vec4f': 'vec4', 'vec4i': 'ivec4', 'vec4u': 'uvec4', 'vec4b': 'bvec4',
  #|    'mat2x2<f32>': 'mat2', 'mat2x2f': 'mat2',
  #|    'mat3x3<f32>': 'mat3', 'mat3x3f': 'mat3',
  #|    'mat4x4<f32>': 'mat4', 'mat4x4f': 'mat4',
  #|    'sampler': 'sampler', 'sampler_comparison': 'samplerComparison',
  #|    'texture_1d': 'texture',
  #|    'texture_2d': 'texture', 'texture_2d_array': 'texture', 'texture_multisampled_2d': 'cubeTexture',
  #|    'texture_depth_2d': 'depthTexture', 'texture_depth_2d_array': 'depthTexture',
  #|    'texture_depth_multisampled_2d': 'depthTexture', 'texture_depth_cube': 'depthTexture',
  #|    'texture_depth_cube_array': 'depthTexture',
  #|    'texture_3d': 'texture3D',
  #|    'texture_cube': 'cubeTexture', 'texture_cube_array': 'cubeTexture',
  #|    'texture_storage_1d': 'storageTexture', 'texture_storage_2d': 'storageTexture',
  #|    'texture_storage_2d_array': 'storageTexture', 'texture_storage_3d': 'storageTexture'
  #|  };
  #|  source = source.replace( /^(?:\s*\/\/[^\r\n]*|\s*\/\*[\s\S]*?\*\/|\s*)+/, '' );
  #|  const declaration = source.match( declarationRegexp );
  #|  if ( declaration !== null && declaration.length === 4 ) {
  #|    const inputsCode = declaration[ 2 ];
  #|    const propsMatches = [];
  #|    let match = null;
  #|    while ( ( match = propertiesRegexp.exec( inputsCode ) ) !== null ) {
  #|      propsMatches.push( { name: match[ 1 ], type: match[ 2 ] } );
  #|    }
  #|    const inputs = [];
  #|    for ( let i = 0; i < propsMatches.length; i ++ ) {
  #|      const { name, type } = propsMatches[ i ];
  #|      let resolvedType = type;
  #|      if ( resolvedType.startsWith( 'ptr' ) ) {
  #|        resolvedType = 'pointer';
  #|      } else {
  #|        if ( resolvedType.startsWith( 'texture' ) ) {
  #|          resolvedType = type.split( '<' )[ 0 ];
  #|        }
  #|        resolvedType = wgslTypeLib[ resolvedType ];
  #|      }
  #|      inputs.push( [ String( resolvedType ), name ] );
  #|    }
  #|    const blockCode = source.substring( declaration[ 0 ].length );
  #|    const outputType = declaration[ 3 ] || 'void';
  #|    const name = declaration[ 1 ] !== undefined ? declaration[ 1 ] : '';
  #|    const type = wgslTypeLib[ outputType ] || outputType;
  #|    return [ type, inputs, name, inputsCode, blockCode, outputType ];
  #|  }
  #|  return null;
  #|}

///|
extern "js" fn _wgsl_node_function_get(
  value : @core.JsValue,
  i : Int32,
) -> @core.JsValue = "(a, i) => a[ i ]"

///|
extern "js" fn _wgsl_node_function_length(value : @core.JsValue) -> Int32 = "(a) => a.length"

///|
extern "js" fn _wgsl_node_function_trim(s : String) -> String = "(s) => s.trim()"

///|
/// `new WGSLNodeFunction( source )`: parses a WGSL function declaration.
pub fn WGSLNodeFunction::new(source : String) -> @nodes.NodeFunction {
  let parsed = _wgsl_node_function_parse(source)
  if parsed.is_null() {
    abort("THREE.WGSLNodeFunction: Function is not a WGSL code.")
  }
  let get = fn(i : Int32) -> String {
    _wgsl_node_function_get(parsed, i).cast()
  }
  let js_inputs = _wgsl_node_function_get(parsed, 1)
  let inputs = []
  for i in 0..<_wgsl_node_function_length(js_inputs) {
    let input = _wgsl_node_function_get(js_inputs, i)
    inputs.push(
      @nodes.NodeFunctionInput::new(
        _wgsl_node_function_get(input, 0).cast(),
        _wgsl_node_function_get(input, 1).cast(),
      ),
    )
  }
  let f = @nodes.NodeFunction::new(get(0), inputs, name=get(2))
  let payload : WGSLNodeFunction = {
    inputs_code: get(3),
    block_code: get(4),
    output_type: get(5),
  }
  f.payload = @core.JsValue::of(payload)
  f.get_code_impl = Some(WGSLNodeFunction::get_code)
  f
}

///|
/// The WGSL payload of a function parsed by `WGSLNodeFunction::new`.
pub fn WGSLNodeFunction::of(f : @nodes.NodeFunction) -> WGSLNodeFunction {
  f.payload.cast()
}

///|
/// `getCode( name = this.name )`.
fn WGSLNodeFunction::get_code(f : @nodes.NodeFunction, name : String) -> String {
  let self = WGSLNodeFunction::of(f)
  let output_type = if self.output_type != "void" {
    "-> " + self.output_type
  } else {
    ""
  }
  "fn \{name} ( \{_wgsl_node_function_trim(self.inputs_code)} ) \{output_type}" +
  self.block_code
}
