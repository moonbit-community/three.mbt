// renderers/webgl-fallback/nodes/GLSLNodeBuilder.js: the NodeBuilder that writes GLSL ES
// 3.0 for the WebGL backend.
//
// `GLSLNodeBuilder::new( object, renderer )` returns a `@nodes.NodeBuilder` whose class
// payload is the `GLSLNodeBuilder` struct below (upstream's own instance fields). The
// methods upstream overrides are the `NodeBuilderClass` impls; the GLSL-only methods
// (`enableExtension`, `getExtensions`, `getStructs`, `getTransforms`, ...) are methods on
// the payload taking the builder. The polyfill sources, `defaultPrecisions` and the
// reserved keywords are generated into nodes_glsl_node_builder_tables.mbt.

///|
/// `glslPolyfills`: one `CodeNode` per polyfill, created at module load.
let _glsl_polyfills : Map[String, @nodes.Node] = @nodes.module_nodes(
  "renderers/webgl-fallback/nodes/GLSLNodeBuilder.js:glslPolyfills",
  fn() {
    let map = Map([])
    for entry in _glsl_polyfill_sources {
      map.set(entry.0, @nodes.CodeNode::new(code=entry.1))
    }
    map
  },
)

///|
/// `glslMethods[ method ]`.
fn _glsl_methods(method_ : String) -> String? {
  match method_ {
    "equals" => Some("equal")
    "bitcast_float_int" => Some("floatBitsToInt")
    "bitcast_int_float" => Some("intBitsToFloat")
    "bitcast_uint_float" => Some("uintBitsToFloat")
    "bitcast_float_uint" => Some("floatBitsToUint")
    "floatpack_snorm_2x16" => Some("packSnorm2x16")
    "floatpack_unorm_2x16" => Some("packUnorm2x16")
    "floatpack_float16_2x16" => Some("packHalf2x16")
    "floatpack_snorm_4x8" => Some("tsl_packSnorm4x8")
    "floatpack_unorm_4x8" => Some("tsl_packUnorm4x8")
    "floatunpack_snorm_2x16" => Some("unpackSnorm2x16")
    "floatunpack_unorm_2x16" => Some("unpackUnorm2x16")
    "floatunpack_float16_2x16" => Some("unpackHalf2x16")
    "floatunpack_snorm_4x8" => Some("tsl_unpackSnorm4x8")
    "floatunpack_unorm_4x8" => Some("tsl_unpackUnorm4x8")
    _ => None
  }
}

///|
/// `precisionLib[ precision ]` (`undefined` for anything else).
fn _glsl_precision_lib(precision : String) -> String {
  match precision {
    "low" => "lowp"
    "medium" => "mediump"
    "high" => "highp"
    _ => "undefined"
  }
}

///|
/// `supports`: a module-level cache (`isAvailable` adds what it looked up).
let _glsl_supports : Map[String, Bool] = {
  "swizzleAssign": true,
  "storageBuffer": false,
}

///|
/// `interpolationTypeMap[ type ] || type`.
fn _glsl_interpolation_type(type_ : String) -> String {
  match type_ {
    "perspective" => "smooth"
    "linear" => "noperspective"
    t => t
  }
}

///|
/// `interpolationModeMap[ sampling ] || ''`.
fn _glsl_interpolation_mode(sampling : String?) -> String {
  match sampling {
    Some("centroid") => "centroid"
    _ => ""
  }
}

///|
/// `glslReservedKeywords`.
let _glsl_reserved_keywords : Map[String, Bool] = Map::from_array(
  _glsl_reserved_keyword_list.map(fn(k) { (k, true) }),
)

///|
/// `nodeData.uniformGPU` of a uniform: the binding `getUniformFromNode` created.
pub(all) enum GLSLUniformGPU {
  /// A `NodeSampledTexture` (2D, cube or 3D) or a `NodeUniformBuffer`.
  Binding(@nodes.Binding)
  /// A uniform of a `NodeUniformsGroup`.
  Uniform(@nodes.Uniform)
}

///|
/// A `this.extensions[ shaderStage ]` entry: `{ name, behavior }`.
pub(all) struct GLSLExtension {
  name : String
  behavior : String
}

///|
/// GLSLNodeBuilder's own instance fields (the class payload of the builder).
pub(all) struct GLSLNodeBuilder {
  /// `uniformGroups[ groupName ]`: the `NodeUniformsGroup` shared by all stages.
  uniform_groups : Map[String, @nodes.Binding]
  /// `transforms`: the varyings and attributes of transform feedback.
  transforms : Array[@nodes.NodeTransform]
  /// `extensions[ shaderStage ]`: name -> extension, in insertion order.
  extensions : Map[String, Map[String, GLSLExtension]]
  /// `builtins[ shaderStage ]`.
  builtins : Map[String, Array[String]]
}

///|
/// `new GLSLNodeBuilder( object, renderer )`.
pub fn GLSLNodeBuilder::new(
  object : @nodes.BuilderObject,
  renderer : @nodes.Renderer,
) -> @nodes.NodeBuilder {
  let parser = @nodes.GLSLNodeParser::new()
  let payload : GLSLNodeBuilder = {
    uniform_groups: Map([]),
    transforms: [],
    extensions: Map([]),
    builtins: { "vertex": [], "fragment": [], "compute": [] },
  }
  @nodes.NodeBuilder::new(object, renderer, Some(parser), class_=payload)
}

///|
/// The GLSL payload of a builder made by `GLSLNodeBuilder::new`.
pub fn GLSLNodeBuilder::of(builder : @nodes.NodeBuilder) -> GLSLNodeBuilder? {
  if builder.class_.class_name() == "GLSLNodeBuilder" {
    Some(builder.class_.payload().cast())
  } else {
    None
  }
}

///|
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn class_name(_) {
  "GLSLNodeBuilder"
}

///|
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn has_flag(_, flag) {
  flag == "isGLSLNodeBuilder"
}

///|
/// A snippet as a template literal prints it (`null` for `None`).
fn _glsl_str(s : String?) -> String {
  match s {
    Some(s) => s
    None => "null"
  }
}

///|
/// JS truthiness of a snippet.
fn _glsl_truthy(s : String?) -> Bool {
  match s {
    Some(s) => s != ""
    None => false
  }
}

///|
/// `shaderStage = this.shaderStage` as a JS value prints (`null` before a stage is set).
fn _glsl_stage(b : @nodes.NodeBuilder, shader_stage : String?) -> String {
  match shader_stage {
    Some(s) => s
    None => _glsl_str(b.shader_stage)
  }
}

///|
/// `node.name` of a node as a template literal prints it.
fn _glsl_node_name(node : @nodes.Node) -> String {
  match node.name {
    Some(n) => n
    None => "undefined"
  }
}

///|
/// `this.context.nodeName` (`None` is `undefined`).
fn _glsl_context_node_name(b : @nodes.NodeBuilder) -> String? {
  match b.context.get("nodeName") {
    String(s) => Some(s)
    _ => None
  }
}

///|
/// `this.renderer.backend.extensions`: the backend's `WebGLExtensions`.
fn _glsl_backend_extensions(b : @nodes.NodeBuilder) -> WebGLExtensions {
  match WebGLBackend::of(b.renderer.backend) {
    Some(backend) =>
      match backend.extensions {
        Some(e) => e
        None =>
          abort("TypeError: Cannot read properties of null (reading 'has')")
      }
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'has')")
  }
}

// ---------------------------------------------------------------------------
// Small overrides.

///|
/// `needsToWorkingColorSpace( texture )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn needs_to_working_color_space(
  _,
  _,
  texture,
) {
  texture.is_video_texture() == true &&
  texture.color_space != @core.NoColorSpace
}

///|
/// `_include( name )`: builds the polyfill and adds it to the current function's
/// includes.
fn GLSLNodeBuilder::_include(
  _self : GLSLNodeBuilder,
  b : @nodes.NodeBuilder,
  name : String,
) -> @nodes.Node {
  let code_node = match _glsl_polyfills.get(name) {
    Some(c) => c
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'build')")
  }
  code_node.build(b) |> ignore
  b.add_include(code_node)
  code_node
}

///|
/// `getMethod( method )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_method(
  self,
  b,
  method_,
  _,
) {
  if _glsl_polyfills.contains(method_) {
    self._include(b, method_) |> ignore
  }
  match _glsl_methods(method_) {
    Some(m) => m
    None => method_
  }
}

///|
/// `getBitcastMethod( type, inputType )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_bitcast_method(
  _,
  b,
  type_,
  input_type,
) {
  let input_component_type = b.get_component_type(input_type)
  let component_type = b.get_component_type(Some(type_))
  // integer types support bitcast implicitly via the type constructor
  if input_component_type != Some("float") &&
    component_type != Some("float") &&
    b.get_type_length(input_type) == b.get_type_length(Some(type_)) {
    return b.get_type(type_)
  }
  b.get_method(
    "bitcast_\{_glsl_str(input_component_type)}_\{_glsl_str(component_type)}",
  )
}

///|
/// `getFloatPackingMethod( encoding, layout = '2x16' )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_float_packing_method(
  _,
  b,
  encoding,
  layout,
) {
  b.get_method("floatpack_\{encoding}_\{layout}")
}

///|
/// `getFloatUnpackingMethod( encoding, layout = '2x16' )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_float_unpacking_method(
  _,
  b,
  encoding,
  layout,
) {
  b.get_method("floatunpack_\{encoding}_\{layout}")
}

///|
/// `getTernary( condSnippet, ifSnippet, elseSnippet )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_ternary(
  _,
  _,
  cond_snippet,
  if_snippet,
  else_snippet,
) {
  Some("\{cond_snippet} ? \{if_snippet} : \{else_snippet}")
}

///|
/// `getVectorSelect( condSnippet, ifSnippet, elseSnippet, type )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_vector_select(
  _,
  b,
  cond_snippet,
  if_snippet,
  else_snippet,
  type_,
) {
  let component_type = b.get_component_type(type_)
  if component_type == Some("float") {
    return Some("mix( \{else_snippet}, \{if_snippet}, \{cond_snippet} )")
  }
  let glsl_type = b.get_type(_glsl_str(type_))
  if component_type == Some("bool") {
    let int_type = b.get_type(
      b.get_type_from_length(b.get_type_length(type_), component_type="int"),
    )
    let mask_snippet = "\{int_type}( \{cond_snippet} )"
    let if_int_snippet = "\{int_type}( \{if_snippet} )"
    let else_int_snippet = "\{int_type}( \{else_snippet} )"
    return Some(
      "\{glsl_type}( \{else_int_snippet} + \{mask_snippet} * ( \{if_int_snippet} - \{else_int_snippet} ) )",
    )
  }
  let mask_snippet = "\{glsl_type}( \{cond_snippet} )"
  Some(
    "\{else_snippet} + \{mask_snippet} * ( \{if_snippet} - \{else_snippet} )",
  )
}

///|
/// `getOutputStructName()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_output_struct_name(
  _,
  _,
) {
  ""
}

///|
/// `buildFunctionCode( shaderNode )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn build_function_code(
  _,
  b,
  shader_node,
) {
  let layout = match @nodes.ShaderNodeInternal::get_layout(shader_node) {
    Some(l) => l
    None =>
      abort("TypeError: Cannot read properties of null (reading 'inputs')")
  }
  let flow_data = b.flow_shader_node(shader_node)
  let parameters = []
  for input in layout.inputs {
    parameters.push(b.get_type(input.type_) + " " + input.name)
  }
  let return_type = match layout.type_ {
    Some(t) => b.get_type(t)
    None => "undefined"
  }
  let vars = match flow_data.vars {
    Some(v) => v
    None => "undefined"
  }
  let result = match flow_data.result {
    Snippet(s) => s
    Null => "null"
    NodeResult(_) => "[object Object]"
  }
  "\{return_type} \{layout.name}( \{parameters.join(", ")} ) {\n\n\t\{vars}\n\n\{flow_data.code}\n\treturn \{result};\n\n}"
}

// ---------------------------------------------------------------------------
// Storage buffers through a PBO texture.

///|
/// `attribute.pbo` and `attribute.pboNode`, which `setupPBO` adds to a storage buffer
/// attribute.
priv struct GLSLAttributePBO {
  /// `attribute.pboNode`, the `TextureNode` of the PBO texture.
  pbo_node : @nodes.Node
  /// `attribute.pbo`, the `DataTexture` holding the attribute's data.
  pbo : @core.Texture
}

///|
let _glsl_attribute_pbos : @webgl.WeakMap[
  @core.BufferAttribute,
  GLSLAttributePBO,
] = @webgl.WeakMap::new()

///|
/// `attribute.pbo` (`None` is `undefined`).
pub fn glsl_attribute_pbo(attribute : @core.BufferAttribute) -> @core.Texture? {
  match _glsl_attribute_pbos.get(attribute) {
    Some(p) => Some(p.pbo)
    None => None
  }
}

///|
/// `attribute.pboNode` (`None` is `undefined`).
pub fn glsl_attribute_pbo_node(
  attribute : @core.BufferAttribute,
) -> @nodes.Node? {
  match _glsl_attribute_pbos.get(attribute) {
    Some(p) => Some(p.pbo_node)
    None => None
  }
}

///|
/// `Math.pow( 2, Math.ceil( Math.log2( Math.sqrt( numElements / itemSize ) ) ) )`.
extern "js" fn _glsl_pbo_width(
  num_elements : Int32,
  item_size : Int32,
) -> Int32 = "(n, s) => Math.pow( 2, Math.ceil( Math.log2( Math.sqrt( n / s ) ) ) )"

///|
/// `Math.ceil( ( numElements / itemSize ) / width )`.
extern "js" fn _glsl_pbo_height(
  num_elements : Int32,
  item_size : Int32,
  width : Int32,
) -> Int32 = "(n, s, w) => Math.ceil( ( n / s ) / w )"

///|
/// The storage buffer attribute of a `StorageBufferNode` (`node.value`).
fn _glsl_storage_attribute(node : @nodes.Node) -> @core.BufferAttribute {
  match @nodes.StorageBufferNode::of(node) {
    Some(s) => s.storage_attribute
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'pbo')")
  }
}

///|
/// `setupPBO( storageBufferNode )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn setup_pbo(
  _,
  b,
  storage_buffer_node,
) {
  let attribute = _glsl_storage_attribute(storage_buffer_node)
  if _glsl_attribute_pbos.get(attribute) is None {
    let original_array = attribute.array
    let num_elements = attribute.count * attribute.item_size
    let item_size = attribute.item_size
    let is_integer = original_array.type_name().to_lower().contains("int")
    let mut format = if is_integer {
      @core.RedIntegerFormat
    } else {
      @core.RedFormat
    }
    if item_size == 2 {
      format = if is_integer { @core.RGIntegerFormat } else { @core.RGFormat }
    } else if item_size == 3 {
      format = if is_integer { @core.RGBIntegerFormat } else { @core.RGBFormat }
    } else if item_size == 4 {
      format = if is_integer {
        @core.RGBAIntegerFormat
      } else {
        @core.RGBAFormat
      }
    }
    let width = _glsl_pbo_width(num_elements, item_size)
    let mut height = _glsl_pbo_height(num_elements, item_size, width)
    if width * height * item_size < num_elements {
      height += 1 // Ensure enough space
    }
    let new_size = width * height * item_size
    let new_array = original_array.new_like(new_size)
    new_array.set_from(original_array, offset=0)
    attribute.array = new_array
    let type_ = match attribute.array.type_name() {
      "Float32Array" => @core.FloatType
      "Uint8Array" => @core.UnsignedByteType
      "Uint16Array" => @core.UnsignedShortType
      "Uint32Array" => @core.UnsignedIntType
      "Int8Array" => @core.ByteType
      "Int16Array" => @core.ShortType
      "Int32Array" => @core.IntType
      "Uint8ClampedArray" => @core.UnsignedByteType
      _ => @core.FloatType
    }
    let pbo_texture = @core.DataTexture::new(
      data=attribute.array,
      width~,
      height~,
      format~,
      type_~,
    )
    pbo_texture.set_needs_update(true)
    let pbo = @nodes.TextureNode::new(value=Some(pbo_texture))
    pbo.set_precision(Some("high")) |> ignore
    _glsl_attribute_pbos.set(attribute, {
      pbo_node: pbo,
      pbo: @nodes.TextureNode::get_value(pbo),
    })
    b.get_uniform_from_node(
      pbo,
      "texture",
      shader_stage?=b.shader_stage,
      name?=_glsl_context_node_name(b),
    )
    |> ignore
  }
}

///|
/// `getPropertyName( node, shaderStage = this.shaderStage )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_property_name(
  _,
  _,
  node,
  _,
) {
  if node is Uniform(uniform) &&
    !uniform.node.has_flag("isTextureNode") &&
    !uniform.node.has_flag("isBufferNode") {
    return uniform.name
  }
  // `super.getPropertyName( node, shaderStage )`.
  node.name()
}

///|
/// `isReservedKeyword( name )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn is_reserved_keyword(
  _,
  _,
  name,
) {
  _glsl_reserved_keywords.contains(name)
}

///|
/// The `propertySizeName` key `generatePBO` adds to a storage buffer node's data.
let _glsl_property_size_key : String = "propertySizeName"

///|
/// `generatePBO( storageArrayElementNode )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn generate_pbo(
  _,
  b,
  storage_array_element_node,
) {
  let element = match
    @nodes.StorageArrayElementNode::of(storage_array_element_node) {
    Some(e) => e.array_element
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'value')")
  }
  let node = element.node
  let index_node = element.index_node
  let attribute = _glsl_storage_attribute(node)
  let backend = b.renderer.backend
  if backend.has(@core.JsValue::of(attribute)) {
    let attribute_data = backend.get(@core.JsValue::of(attribute))
    attribute_data.set(
      "pbo",
      match glsl_attribute_pbo(attribute) {
        Some(t) => @core.JsValue::of(t)
        None => @core.JsValue::undefined()
      },
    )
  }
  let pbo_node = match glsl_attribute_pbo_node(attribute) {
    Some(n) => n
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'isNode')")
  }
  let node_uniform = b.get_uniform_from_node(
    pbo_node,
    "texture",
    shader_stage?=b.shader_stage,
    name?=_glsl_context_node_name(b),
  )
  let texture_name = b.get_property_name(Uniform(node_uniform))
  b.increase_usage(index_node) |> ignore // force cache generate to be used as index in x,y
  let index_snippet = index_node.build(b, output="uint")
  let element_node_data = b.get_data_from_node(storage_array_element_node)
  match element_node_data.property_name {
    Some(property_name) => property_name
    None => {
      // property element
      let node_var = b.get_var_from_node(
        storage_array_element_node,
        None,
        None,
        None,
        false,
        false,
        "variable",
      )
      let property_name = b.get_property_name(Var(node_var))
      // property size
      let buffer_node_data = b.get_data_from_node(node)
      let property_size_name = match
        buffer_node_data.extra.get(_glsl_property_size_key) {
        Some(v) => v.cast()
        None => {
          let property_size_name = property_name + "Size"
          b.get_var_from_node(
            node,
            Some(property_size_name),
            Some("uint"),
            None,
            false,
            false,
            "variable",
          )
          |> ignore
          b.add_line_flow_code(
            "\{property_size_name} = uint( textureSize( \{texture_name}, 0 ).x )",
            node=storage_array_element_node,
          )
          |> ignore
          buffer_node_data.extra.set(
            _glsl_property_size_key,
            @core.JsValue::of(property_size_name),
          )
          property_size_name
        }
      }
      let item_size = attribute.item_size
      let channel = "." + _glsl_slice_components(item_size)
      let uv_snippet = "ivec2(\{index_snippet} % \{property_size_name}, \{index_snippet} / \{property_size_name})"
      let snippet = _glsl_generate_texture_load(
        None,
        texture_name,
        uv_snippet,
        Some("0"),
        None,
        None,
      )
      let pbo_type = match glsl_attribute_pbo(attribute) {
        Some(t) => t.type_
        None => -1
      }
      let prefix = if pbo_type == @core.UnsignedIntType {
        "uvec4"
      } else if pbo_type == @core.IntType {
        "ivec4"
      } else {
        "vec4"
      }
      let texel_type = b.get_type_from_length(
        item_size,
        component_type=_glsl_str(b.get_component_type(Some(prefix))),
      )
      let element_type = storage_array_element_node.get_node_type(b)
      b.add_line_flow_code(
        "\{property_name} = \{b.format("\{prefix}(\{snippet})\{channel}", Some(texel_type), element_type)}",
        node=storage_array_element_node,
      )
      |> ignore
      element_node_data.property_name = Some(property_name)
      property_name
    }
  }
}

///|
/// `vectorComponents.join( '' ).slice( 0, itemSize )`.
fn _glsl_slice_components(item_size : Int32) -> String {
  let out = StringBuilder()
  for i, c in @nodes.vector_components {
    if i < item_size {
      out.write_string(c)
    }
  }
  out.to_string()
}
