// renderers/webgpu/nodes/WGSLNodeBuilder.js: the NodeBuilder that writes WGSL.
//
// `WGSLNodeBuilder::new( object, renderer )` returns a `@nodes.NodeBuilder` whose class
// payload is the `WGSLNodeBuilder` struct below (upstream's own instance fields). The
// methods upstream overrides are the `NodeBuilderClass` impls; the WGSL-only methods
// (`getBuiltin`, `enableDirective`, `generateWrapFunction`, ...) are methods on the
// payload taking the builder. This file: tables, fields, constructor and the small
// overrides; textures are in nodes_wgsl_node_builder_texture.mbt, the code assembly
// (`buildCode`, `getUniforms`, ...) in nodes_wgsl_node_builder_code.mbt, and what the
// builder reads from WebGPUBackend before G9 exists in
// nodes_wgsl_node_builder_backend.mbt.

///|
/// `accessNames[ access ]` (`undefined` for anything else).
fn _wgsl_access_name(access : String?) -> String {
  match access {
    Some("readOnly") => "read"
    Some("writeOnly") => "write"
    Some("readWrite") => "read_write"
    _ => "undefined"
  }
}

///|
/// `wrapNames[ wrap ]`.
fn _wgsl_wrap_name(wrap : Int32) -> String {
  if wrap == @core.RepeatWrapping {
    "repeat"
  } else if wrap == @core.ClampToEdgeWrapping {
    "clamp"
  } else if wrap == @core.MirroredRepeatWrapping {
    "mirror"
  } else {
    "undefined"
  }
}

///|
/// `gpuShaderStageLib[ shaderStage ]`.
fn _wgsl_gpu_shader_stage(shader_stage : String) -> Int32 {
  match shader_stage {
    "vertex" => @gpu.GPU_SHADER_STAGE_VERTEX
    "fragment" => @gpu.GPU_SHADER_STAGE_FRAGMENT
    "compute" => @gpu.GPU_SHADER_STAGE_COMPUTE
    // `setVisibility( undefined )`.
    _ => 0
  }
}

///|
/// `supports`: a module-level cache (`isAvailable` adds the features it looked up;
/// `None` is a cached `undefined`).
let _wgsl_supports : Map[String, Bool?] = {
  "instance": Some(true),
  "swizzleAssign": Some(false),
  "storageBuffer": Some(true),
}

///|
/// `wgslFnOpLib[ op ]`.
fn _wgsl_fn_op(op : String) -> String? {
  match op {
    "^^" => Some("tsl_xor")
    _ => None
  }
}

///|
/// `wgslTypeLib[ type ]`.
fn _wgsl_type_lib(type_ : String) -> String? {
  match type_ {
    "float" => Some("f32")
    "int" => Some("i32")
    "uint" => Some("u32")
    "bool" => Some("bool")
    "color" => Some("vec3<f32>")
    "vec2" => Some("vec2<f32>")
    "ivec2" => Some("vec2<i32>")
    "uvec2" => Some("vec2<u32>")
    "bvec2" => Some("vec2<bool>")
    "vec3" => Some("vec3<f32>")
    "ivec3" => Some("vec3<i32>")
    "uvec3" => Some("vec3<u32>")
    "bvec3" => Some("vec3<bool>")
    "vec4" => Some("vec4<f32>")
    "ivec4" => Some("vec4<i32>")
    "uvec4" => Some("vec4<u32>")
    "bvec4" => Some("vec4<bool>")
    "mat2" => Some("mat2x2<f32>")
    "mat3" => Some("mat3x3<f32>")
    "mat4" => Some("mat4x4<f32>")
    _ => None
  }
}

///|
/// `wgslCodeCache`: the wrap functions of `generateWrapFunction`, by function name,
/// shared by every builder.
let _wgsl_code_cache : Map[String, @nodes.Node] = Map([])

///|
/// `wgslPolyfill`: one `CodeNode` per polyfill, created at module load.
let _wgsl_polyfill : Map[String, @nodes.Node] = @nodes.module_nodes(
  "renderers/webgpu/nodes/WGSLNodeBuilder.js:wgslPolyfill",
  fn() {
    let map = Map([])
    for entry in _wgsl_polyfill_sources {
      map.set(entry.0, @nodes.CodeNode::new(code=entry.1))
    }
    map
  },
)

///|
/// `wgslMethods[ method ]`.
fn _wgsl_methods(method_ : String) -> String? {
  match method_ {
    "dFdx" => Some("dpdx")
    "dFdy" => Some("- dpdy")
    "mod_float" => Some("tsl_mod_float")
    "mod_vec2" => Some("tsl_mod_vec2")
    "mod_vec3" => Some("tsl_mod_vec3")
    "mod_vec4" => Some("tsl_mod_vec4")
    "equals_bool" => Some("tsl_equals_bool")
    "equals_bvec2" => Some("tsl_equals_bvec2")
    "equals_bvec3" => Some("tsl_equals_bvec3")
    "equals_bvec4" => Some("tsl_equals_bvec4")
    "inverse_mat2" => Some("tsl_inverse_mat2")
    "inverse_mat3" => Some("tsl_inverse_mat3")
    "inverse_mat4" => Some("tsl_inverse_mat4")
    "inversesqrt" => Some("inverseSqrt")
    "faceforward" => Some("faceForward")
    "bitcast" => Some("bitcast<f32>")
    "floatpack_snorm_2x16" => Some("pack2x16snorm")
    "floatpack_unorm_2x16" => Some("pack2x16unorm")
    "floatpack_float16_2x16" => Some("pack2x16float")
    "floatpack_snorm_4x8" => Some("pack4x8snorm")
    "floatpack_unorm_4x8" => Some("pack4x8unorm")
    "floatunpack_snorm_2x16" => Some("unpack2x16snorm")
    "floatunpack_unorm_2x16" => Some("unpack2x16unorm")
    "floatunpack_float16_2x16" => Some("unpack2x16float")
    "floatunpack_snorm_4x8" => Some("unpack4x8snorm")
    "floatunpack_unorm_4x8" => Some("unpack4x8unorm")
    _ => None
  }
}

///|
/// `wgslReservedKeywords` (WGSL keywords, reserved words and the entry point name).
let _wgsl_reserved_keywords : Map[String, Bool] = Map::from_array(
  [
    // keywords
    "alias", "break", "case", "const", "const_assert", "continue", "continuing",
    "default", "diagnostic", "discard", "else", "enable", "false", "fn", "for", "if",
    "let", "loop", "override", "requires", "return", "struct", "switch", "true",
    "var", "while",
    // reserved words
     "NULL", "Self", "abstract", "active", "alignas", "alignof", "as", "asm", "asm_fragment",
    "async", "attribute", "auto", "await", "become", "binding_array", "cast", "catch",
    "class", "co_await", "co_return", "co_yield", "coherent", "column_major", "common",
    "compile", "compile_fragment", "concept", "const_cast", "consteval", "constexpr",
    "constinit", "crate", "debugger", "decltype", "delete", "demote", "demote_to_helper",
    "do", "dynamic_cast", "enum", "explicit", "export", "extends", "extern", "external",
    "fallthrough", "filter", "final", "finally", "friend", "from", "fxgroup", "get",
    "goto", "groupshared", "highp", "impl", "implements", "import", "inline", "instanceof",
    "interface", "layout", "lowp", "macro", "macro_rules", "match", "mediump", "meta",
    "mod", "module", "move", "mut", "mutable", "namespace", "new", "nil", "noexcept",
    "noinline", "nointerpolation", "non_coherent", "noncoherent", "noperspective",
    "null", "nullptr", "of", "operator", "package", "packoffset", "partition", "pass",
    "patch", "pixelfragment", "precise", "precision", "premerge", "priv", "protected",
    "pub", "public", "readonly", "ref", "regardless", "register", "reinterpret_cast",
    "require", "resource", "restrict", "self", "set", "shared", "sizeof", "smooth",
    "snorm", "static", "static_assert", "static_cast", "std", "subroutine", "super",
    "target", "template", "this", "thread_local", "throw", "trait", "try", "type",
    "typedef", "typeid", "typename", "typeof", "union", "unless", "unorm", "unsafe",
    "unsized", "use", "using", "varying", "virtual", "volatile", "wgsl", "where",
    "with", "writeonly", "yield",
    // generated entry points
     "main",
  ].map(fn(k) { (k, true) }),
)

///|
/// `diagnostics`: `diagnostic( off, derivative_uniformity );` except in Firefox and Deno
/// (decided at module load from `navigator.userAgent`).
extern "js" fn _wgsl_diagnostics_js() -> String =
  #|() => {
  #|  let diagnostics = '';
  #|  if ( ( typeof navigator !== 'undefined' && /Firefox|Deno/g.test( navigator.userAgent ) ) !== true ) {
  #|    diagnostics += 'diagnostic( off, derivative_uniformity );\n';
  #|  }
  #|  return diagnostics;
  #|}

///|
let _wgsl_diagnostics : String = _wgsl_diagnostics_js()

///|
/// A `builtins[ shaderStage ]` entry: `{ name, property, type }`.
pub(all) struct WGSLBuiltin {
  name : String
  property : String
  type_ : String
}

///|
/// A `scopedArrays` entry: `{ name, scope, bufferType, bufferCount, isAtomic }`.
pub(all) struct WGSLScopedArray {
  name : String
  scope : String
  buffer_type : String
  buffer_count : Int32
  is_atomic : Bool
}

///|
/// The keys `generateTextureDimension` adds to the data of a texture
/// (`getDataFromNode( texture, ... )`).
pub(all) struct WGSLTextureData {
  /// `dimensionsSnippet`: level snippet -> `VarNode` of `textureDimensions( ... )`.
  mut dimensions_snippet : Map[String, @nodes.Node]?
  mut array_layer_count : @nodes.Node?
  mut cube_face_count : @nodes.Node?
}

///|
/// `nodeData.uniformGPU`: the bindings `getUniformFromNode` created for a uniform.
pub(all) enum WGSLUniformGPU {
  /// `[ sampler, texture ]` or `[ texture ]`.
  Textures(Array[@nodes.Binding])
  /// A `NodeUniformBuffer` or `NodeStorageBuffer`.
  Buffer(@nodes.Binding)
  /// A uniform of a `NodeUniformsGroup`.
  Uniform(@nodes.Uniform)
}

///|
/// WGSLNodeBuilder's own instance fields (the class payload of the builder).
pub(all) struct WGSLNodeBuilder {
  /// `uniformGroups[ groupName ]`: the `NodeUniformsGroup` shared by all stages.
  uniform_groups : Map[String, @nodes.Binding]
  /// `uniformGroupsBindings[ groupName ]` = `{ index, id }`.
  uniform_groups_bindings : Map[String, (Int32, Int32)]
  /// `builtins[ shaderStage ]`: name -> builtin, in insertion order.
  builtins : Map[String, Map[String, WGSLBuiltin]]
  /// `directives[ shaderStage ]`: a `Set` in insertion order.
  directives : Map[String, Array[String]]
  scoped_arrays : Map[String, WGSLScopedArray]
  /// The texture data of `getDataFromNode( texture, shaderStage, cache )`: cache id ->
  /// texture id -> shader stage -> data (looked up through the parent caches).
  texture_data : Map[Int32, Map[Int32, Map[String, WGSLTextureData]]]
  /// The varyings `getVaryings( 'vertex' )` pushed into `vars.vertex` as the vars that
  /// stand for them (`vars.includes( varying )`).
  varying_vars : Array[(@nodes.NodeVarying, @nodes.NodeVar)]
}

///|
/// `new WGSLNodeBuilder( object, renderer )`.
pub fn WGSLNodeBuilder::new(
  object : @nodes.BuilderObject,
  renderer : @nodes.Renderer,
) -> @nodes.NodeBuilder {
  let parser = WGSLNodeParser::new()
  let payload : WGSLNodeBuilder = {
    uniform_groups: Map([]),
    uniform_groups_bindings: Map([]),
    builtins: Map([]),
    directives: Map([]),
    scoped_arrays: Map([]),
    texture_data: Map([]),
    varying_vars: [],
  }
  let builder = @nodes.NodeBuilder::new(
    object,
    renderer,
    Some(parser),
    class_=payload,
  )
  builder.allow_early_returns = true
  builder.allow_global_variables = true
  builder
}

///|
/// The WGSL payload of a builder made by `WGSLNodeBuilder::new`.
pub fn WGSLNodeBuilder::of(builder : @nodes.NodeBuilder) -> WGSLNodeBuilder? {
  if builder.class_.class_name() == "WGSLNodeBuilder" {
    Some(builder.class_.payload().cast())
  } else {
    None
  }
}

///|
fn _wgsl_of(builder : @nodes.NodeBuilder) -> WGSLNodeBuilder {
  match WGSLNodeBuilder::of(builder) {
    Some(w) => w
    None => abort("WGSLNodeBuilder: not a WGSL builder")
  }
}

///|
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn class_name(_) {
  "WGSLNodeBuilder"
}

///|
/// A snippet as a template literal prints it (`null` for `None`).
fn _wgsl_str(s : String?) -> String {
  match s {
    Some(s) => s
    None => "null"
  }
}

///|
/// JS truthiness of a snippet.
fn _wgsl_truthy(s : String?) -> Bool {
  match s {
    Some(s) => s != ""
    None => false
  }
}

///|
/// `this.shaderStage` as a JS value prints (`null` before a stage is set).
fn _wgsl_stage(b : @nodes.NodeBuilder, shader_stage : String?) -> String {
  match shader_stage {
    Some(s) => s
    None =>
      match b.shader_stage {
        Some(s) => s
        None => "null"
      }
  }
}

// ---------------------------------------------------------------------------
// Names, types and methods.

///|
/// `getPropertyName( node, shaderStage = this.shaderStage )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_property_name(
  _,
  b,
  node,
  shader_stage,
) {
  match node {
    Varying(varying) if varying.needs_interpolation =>
      if _wgsl_stage(b, shader_stage) == "vertex" {
        return "varyings.\{varying.name}"
      }
    Uniform(uniform) => {
      let name = uniform.name
      let type_ = uniform.type_
      match type_ {
        "texture"
        | "cubeTexture"
        | "cubeDepthTexture"
        | "storageTexture"
        | "texture3D" => return name
        "buffer" | "storageBuffer" | "indirectStorageBuffer" =>
          return name + ".value"
        _ => return _wgsl_node_name(uniform.group_node()) + "." + name
      }
    }
    _ => ()
  }
  // `super.getPropertyName( node )`.
  node.name()
}

///|
/// `node.name` of a node as a template literal prints it.
fn _wgsl_node_name(node : @nodes.Node) -> String {
  match node.name {
    Some(n) => n
    None => "undefined"
  }
}

///|
/// `getDeclarationName( node )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_declaration_name(
  _,
  b,
  node,
) {
  if node is Uniform(uniform) {
    match uniform.type_ {
      "buffer" | "storageBuffer" | "indirectStorageBuffer" =>
        return uniform.name
      _ => ()
    }
  }
  b.get_declaration_name_base(node)
}

///|
/// `isReservedKeyword( name )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn is_reserved_keyword(
  _,
  _,
  name,
) {
  _wgsl_reserved_keywords.contains(name)
}

///|
/// `getOutputStructName()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_output_struct_name(
  _,
  _,
) {
  "output"
}

///|
/// `getFunctionOperator( op )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_function_operator(
  self,
  b,
  op,
) {
  match _wgsl_fn_op(op) {
    Some(fn_op) => {
      self._include(b, fn_op) |> ignore
      Some(fn_op)
    }
    None => None
  }
}

///|
/// `getNodeAccess( node, shaderStage )`: the access of a storage node in a stage
/// (`None` is `undefined`).
pub fn WGSLNodeBuilder::get_node_access(
  _self : WGSLNodeBuilder,
  node : @nodes.Node,
  shader_stage : String,
) -> String? {
  if shader_stage != "compute" {
    if _wgsl_is_atomic(node) {
      // Per the WGSL spec, atomic built-in functions are only allowed in the fragment
      // and compute stages, not in the vertex stage.
      if shader_stage == "vertex" {
        @core.warn(
          "WebGPURenderer: Atomic operations are not supported in the vertex stage. They are only available in the fragment and compute stages.",
        )
        return Some(@nodes.node_access_read_only)
      }
      return Some(@nodes.node_access_read_write)
    }
    // Honor read-write for storage texture in the fragment stage.
    if shader_stage == "fragment" &&
      node.has_flag("isStorageTextureNode") &&
      _wgsl_node_access(node) == Some(@nodes.node_access_read_write) {
      return Some(@nodes.node_access_read_write)
    }
    return Some(@nodes.node_access_read_only)
  }
  _wgsl_node_access(node)
}

///|
/// `node.isAtomic === true` (StorageBufferNode, WorkgroupInfoNode).
fn _wgsl_is_atomic(node : @nodes.Node) -> Bool {
  match @nodes.StorageBufferNode::of(node) {
    Some(s) => s.is_atomic
    None => false
  }
}

///|
/// `node.access` of a storage buffer or storage texture node (`None` is `undefined`).
fn _wgsl_node_access(node : @nodes.Node) -> String? {
  match @nodes.StorageBufferNode::of(node) {
    Some(s) => Some(s.access)
    None =>
      match @nodes.StorageTextureNode::of(node) {
        Some(s) => Some(s.access)
        None => None
      }
  }
}

///|
/// `getStorageAccess( node, shaderStage )`.
pub fn WGSLNodeBuilder::get_storage_access(
  self : WGSLNodeBuilder,
  node : @nodes.Node,
  shader_stage : String,
) -> String {
  _wgsl_access_name(self.get_node_access(node, shader_stage))
}

///|
/// `getUniformFromNode( node, type, shaderStage, name = null )`: also creates the
/// bindings of the uniform.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_uniform_from_node(
  self,
  b,
  node,
  type_,
  shader_stage,
  name,
) {
  let uniform_node = b.get_uniform_from_node_base(
    node, type_, shader_stage, name,
  )
  let shader_stage = _wgsl_str(shader_stage)
  let node_data = b.get_data_from_node(
    node,
    shader_stage~,
    cache=b.global_cache,
  )
  if node_data.extra.get("uniformGPU") is None {
    let group = match @nodes.UniformNode::of(node) {
      Some(u) => u.group_node
      None =>
        abort("TypeError: Cannot read properties of undefined (reading 'name')")
    }
    let group_name = _wgsl_node_name(group)
    let bindings = b.get_bind_group_array(group_name, shader_stage)
    let uniform_gpu : WGSLUniformGPU = match type_ {
      "texture"
      | "cubeTexture"
      | "cubeDepthTexture"
      | "storageTexture"
      | "texture3D" => {
        let access = self.get_node_access(node, shader_stage)
        let value = @nodes.TextureNode::get_value(node)
        let texture = match type_ {
          "texture" | "storageTexture" =>
            if value.has_extension_flag("is3DTexture") {
              @nodes.NodeSampledTexture3D::new(
                uniform_node.name,
                Some(uniform_node.node),
                Some(group),
                access?,
              )
            } else {
              @nodes.NodeSampledTexture::new(
                uniform_node.name,
                Some(uniform_node.node),
                Some(group),
                access?,
              )
            }
          "cubeTexture" | "cubeDepthTexture" =>
            @nodes.NodeSampledCubeTexture::new(
              uniform_node.name,
              Some(uniform_node.node),
              Some(group),
              access?,
            )
          _ =>
            @nodes.NodeSampledTexture3D::new(
              uniform_node.name,
              Some(uniform_node.node),
              Some(group),
              access?,
            )
        }
        texture.set_store(node.has_flag("isStorageTextureNode"))
        texture.set_mip_level(
          if texture.store() {
            match @nodes.StorageTextureNode::of(node) {
              Some(s) => s.mip_level
              None => 0
            }
          } else {
            0
          },
        )
        texture.set_visibility(_wgsl_gpu_shader_stage(shader_stage))
        // Cube textures always need samplers (they use textureSampleLevel, not
        // textureLoad). Also textureGather always need sampler.
        let needs_sampler = value.is_cube_texture() ||
          (!self.is_unfilterable(b, value) && !texture.store()) ||
          _wgsl_gather_node(node) is Some(_)
        if needs_sampler {
          let sampler = @nodes.NodeSampler::new(
            "\{uniform_node.name}_sampler",
            Some(uniform_node.node),
            Some(group),
          )
          sampler.set_visibility(_wgsl_gpu_shader_stage(shader_stage))
          bindings.push(sampler)
          bindings.push(texture)
          Textures([sampler, texture])
        } else {
          bindings.push(texture)
          Textures([texture])
        }
      }
      "buffer" | "storageBuffer" | "indirectStorageBuffer" => {
        let buffer = if type_ == "buffer" {
          @nodes.NodeUniformBuffer::new(node, Some(group))
        } else {
          @nodes.NodeStorageBuffer::new(node, Some(group))
        }
        buffer.set_visibility(_wgsl_gpu_shader_stage(shader_stage))
        bindings.push(buffer)
        Buffer(buffer)
      }
      _ => {
        let uniforms_group = match self.uniform_groups.get(group_name) {
          Some(g) => g
          None => {
            let g = @nodes.NodeUniformsGroup::new(group_name, group)
            g.set_visibility(
              @gpu.GPU_SHADER_STAGE_VERTEX |
              @gpu.GPU_SHADER_STAGE_FRAGMENT |
              @gpu.GPU_SHADER_STAGE_COMPUTE,
            )
            self.uniform_groups.set(group_name, g)
            g
          }
        }
        // Add to bindings for this stage if not already present
        if !bindings.iter().any(fn(x) { physical_equal(x, uniforms_group) }) {
          bindings.push(uniforms_group)
        }
        let uniform_gpu = b.get_node_uniform(uniform_node, type_)
        // Only add uniform if not already present in the group (check by name to
        // avoid duplicates across stages)
        let uniform_name = uniform_gpu.name
        let already_exists = uniforms_group
          .uniforms()
          .iter()
          .any(fn(u) { u.name == uniform_name })
        if !already_exists {
          uniforms_group.add_uniform(uniform_gpu) |> ignore
        }
        Uniform(uniform_gpu)
      }
    }
    node_data.extra.set("uniformGPU", @core.JsValue::of(uniform_gpu))
  }
  uniform_node
}

///|
/// `nodeData.uniformGPU` of a uniform node in a stage (`None` is `undefined`).
pub fn WGSLNodeBuilder::uniform_gpu(
  builder : @nodes.NodeBuilder,
  node : @nodes.Node,
  shader_stage : String,
) -> WGSLUniformGPU? {
  let node_data = builder.get_data_from_node(
    node,
    shader_stage~,
    cache=builder.global_cache,
  )
  match node_data.extra.get("uniformGPU") {
    Some(v) => Some(v.cast())
    None => None
  }
}

///|
/// `textureNode.gatherNode` (`None` is `null`; nodes outside the TextureNode family
/// have `undefined`, which `!== null` treats as set).
fn _wgsl_gather_node(node : @nodes.Node) -> @nodes.Node? {
  match @nodes.TextureNode::of(node) {
    Some(t) => t.gather_node
    None => Some(node)
  }
}

///|
/// `getBuiltin( name, property, type, shaderStage = this.shaderStage )`.
pub fn WGSLNodeBuilder::get_builtin(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  name : String,
  property : String,
  type_ : String,
  shader_stage? : String,
) -> String {
  let shader_stage = _wgsl_stage(b, shader_stage)
  let map = match self.builtins.get(shader_stage) {
    Some(m) => m
    None => {
      let m = Map([])
      self.builtins.set(shader_stage, m)
      m
    }
  }
  if !map.contains(name) {
    map.set(name, { name, property, type_, })
  }
  property
}

///|
/// `hasBuiltin( name, shaderStage = this.shaderStage )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn has_builtin(
  self,
  b,
  name,
  shader_stage,
) {
  match self.builtins.get(_wgsl_stage(b, shader_stage)) {
    Some(map) => map.contains(name)
    None => false
  }
}

///|
/// `getVertexIndex()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_vertex_index(
  self,
  b,
) {
  if b.shader_stage == Some("vertex") {
    return self.get_builtin(
      b,
      "vertex_index",
      "vertexIndex",
      "u32",
      shader_stage="attribute",
    )
  }
  "vertexIndex"
}

///|
/// `buildFunctionCode( shaderNode )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn build_function_code(
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
    parameters.push(input.name + " : " + b.get_type(input.type_))
  }
  let return_type = match layout.type_ {
    Some(t) => b.get_type(t)
    None => "undefined"
  }
  let vars = match flow_data.vars {
    Some(v) => v
    None => "undefined"
  }
  let mut code = "fn \{layout.name}( \{parameters.join(", ")} ) -> \{return_type} {\n\{vars}\n\{flow_data.code}\n"
  let result = flow_data.result_snippet()
  if result != "" {
    code += "\treturn \{result};\n"
  }
  code += "\n}\n"
  code
}

///|
/// `getInstanceIndex()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_instance_index(
  self,
  b,
) {
  if b.shader_stage == Some("vertex") {
    return self.get_builtin(
      b,
      "instance_index",
      "instanceIndex",
      "u32",
      shader_stage="attribute",
    )
  }
  "instanceIndex"
}

///|
/// `getInvocationLocalIndex()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_invocation_local_index(
  self,
  b,
) {
  self.get_builtin(
    b,
    "local_invocation_index",
    "invocationLocalIndex",
    "u32",
    shader_stage="attribute",
  )
}

///|
/// `getSubgroupSize()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_subgroup_size(
  self,
  b,
) {
  b.enable_sub_groups()
  self.get_builtin(
    b,
    "subgroup_size",
    "subgroupSize",
    "u32",
    shader_stage="attribute",
  )
}

///|
/// `getInvocationSubgroupIndex()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_invocation_subgroup_index(
  self,
  b,
) {
  b.enable_sub_groups()
  self.get_builtin(
    b,
    "subgroup_invocation_id",
    "invocationSubgroupIndex",
    "u32",
    shader_stage="attribute",
  )
}

///|
/// `getSubgroupIndex()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_subgroup_index(
  self,
  b,
) {
  b.enable_sub_groups()
  self.get_builtin(
    b,
    "subgroup_id",
    "subgroupIndex",
    "u32",
    shader_stage="attribute",
  )
}

///|
/// `getDrawIndex()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_draw_index(
  _,
  _,
) {
  None
}

///|
/// `getFrontFacing()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_front_facing(
  self,
  b,
) {
  self.get_builtin(b, "front_facing", "isFront", "bool")
}

///|
/// `getFragCoord()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_frag_coord(
  self,
  b,
) {
  self.get_builtin(b, "position", "fragCoord", "vec4<f32>") + ".xy"
}

///|
/// `getFragDepth()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_frag_depth(
  self,
  b,
) {
  "output." +
  self.get_builtin(b, "frag_depth", "depth", "f32", shader_stage="output")
}

///|
/// `getClipDistance()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_clip_distance(
  _,
  _,
) {
  "varyings.hw_clip_distances"
}

///|
/// `isFlipY()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn is_flip_y(_, _) {
  false
}

///|
/// `enableDirective( name, shaderStage = this.shaderStage )`.
pub fn WGSLNodeBuilder::enable_directive(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  name : String,
  shader_stage? : String,
) -> Unit {
  let shader_stage = _wgsl_stage(b, shader_stage)
  let stage = match self.directives.get(shader_stage) {
    Some(s) => s
    None => {
      let s = []
      self.directives.set(shader_stage, s)
      s
    }
  }
  if !stage.contains(name) {
    stage.push(name)
  }
}

///|
/// `getDirectives( shaderStage )`.
pub fn WGSLNodeBuilder::get_directives(
  self : WGSLNodeBuilder,
  shader_stage : String,
) -> String {
  let snippets = []
  match self.directives.get(shader_stage) {
    Some(directives) =>
      for directive in directives {
        snippets.push("enable \{directive};")
      }
    None => ()
  }
  snippets.join("\n")
}

///|
/// `enableSubGroups()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn enable_sub_groups(
  self,
  b,
) {
  if !wgsl_renderer_has_feature(b.renderer, "subgroups") {
    @core.error(
      "WGSLNodeBuilder: The 'subgroups' feature is not supported by the current device.",
    )
  }
  self.enable_directive(b, "subgroups")
}

///|
/// `enableClipDistances()`.
pub fn WGSLNodeBuilder::enable_clip_distances(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
) -> Unit {
  self.enable_directive(b, "clip_distances")
}

///|
/// `enableShaderF16()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn enable_shader_f16(
  self,
  b,
) {
  self.enable_directive(b, "f16")
}

///|
/// `enableDualSourceBlending()`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn enable_dual_source_blending(
  self,
  b,
) {
  self.enable_directive(b, "dual_source_blending")
}

///|
/// `enableHardwareClipping( planeCount )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn enable_hardware_clipping(
  self,
  b,
  plane_count,
) {
  self.enable_clip_distances(b)
  self.get_builtin(
    b,
    "clip_distances",
    "hw_clip_distances",
    "array<f32, \{plane_count} >",
    shader_stage="vertex",
  )
  |> ignore
}

///|
/// `getBuiltins( shaderStage )`.
pub fn WGSLNodeBuilder::get_builtins(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  shader_stage : String,
) -> String {
  let snippets = []
  match self.builtins.get(shader_stage) {
    Some(builtins) =>
      for _, builtin in builtins {
        let invariant = if b.context.get_bool("invariant") == Some(true) &&
          shader_stage == "vertex" &&
          builtin.name == "position" {
          "@invariant "
        } else {
          ""
        }
        snippets.push(
          "\{invariant}@builtin( \{builtin.name} ) \{builtin.property} : \{builtin.type_}",
        )
      }
    None => ()
  }
  snippets.join(",\n\t")
}

///|
/// `getScopedArray( name, scope, bufferType, bufferCount, isAtomic )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_scoped_array(
  self,
  _,
  name,
  scope,
  buffer_type,
  buffer_count,
  is_atomic,
) {
  if !self.scoped_arrays.contains(name) {
    self.scoped_arrays.set(name, {
      name,
      scope,
      buffer_type,
      buffer_count,
      is_atomic,
    })
  }
  name
}

///|
/// `getScopedArrays( shaderStage )` (`None` is `undefined`, outside compute).
pub fn WGSLNodeBuilder::get_scoped_arrays(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  shader_stage : String,
) -> String? {
  if shader_stage != "compute" {
    return None
  }
  let snippets = []
  for _, scoped in self.scoped_arrays {
    let mut type_ = b.get_type(scoped.buffer_type)
    if scoped.is_atomic {
      type_ = "atomic<\{type_}>"
    }
    snippets.push(
      "var<\{scoped.scope}> \{scoped.name}: array< \{type_}, \{scoped.buffer_count} >;",
    )
  }
  Some(snippets.join("\n"))
}

///|
/// `getVar( type, name, count = null, qualifier = '' )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_var(
  _,
  b,
  type_,
  name,
  count,
  qualifier,
) {
  let mut snippet = "var\{qualifier} \{name} : "
  match count {
    Some(_) => snippet += b.generate_array_declaration(type_, count)
    None => snippet += b.get_type(type_)
  }
  snippet
}

///|
/// `generateArrayDeclaration( type, count )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_array_declaration(
  _,
  b,
  type_,
  count,
) {
  let count = match count {
    Some(c) => c.to_string()
    None => "null"
  }
  "array< \{b.get_type(type_)}, \{count} >"
}

///|
/// `generateConstStatement( type, name )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_const_statement(
  _,
  _,
  _,
  name,
  _,
) {
  "const \{name}"
}

///|
/// `generateVarStatement( type, name, count = null )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_var_statement(
  _,
  b,
  type_,
  name,
  count,
) {
  b.get_var(type_, name, count?)
}

///|
/// `generateLetStatement( type, name )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn generate_let_statement(
  _,
  _,
  _,
  name,
  _,
) {
  "let \{name}"
}

///|
/// `getVars( shaderStage, global = false )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_vars(
  _,
  b,
  shader_stage,
  global,
) {
  let qualifier = if global { "<private>" } else { "" }
  let snippets = []
  match b.vars.get(shader_stage) {
    Some(vars) =>
      for variable in vars {
        let v = b.get_var(
          variable.type_,
          variable.name,
          count?=variable.count,
          qualifier~,
        )
        snippets.push("\{v};")
      }
    None => ()
  }
  if global {
    snippets.join("\n")
  } else {
    "\n\t\{snippets.join("\n\t")}\n"
  }
}

///|
/// `getMethod( method, output = null )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_method(
  self,
  b,
  method_,
  output,
) {
  let mut wgsl_method = None
  match output {
    Some(output) =>
      wgsl_method = self._get_wgsl_method(b, method_ + "_" + output)
    None => ()
  }
  if wgsl_method is None {
    wgsl_method = self._get_wgsl_method(b, method_)
  }
  match wgsl_method {
    Some(m) if m != "" => m
    _ => method_
  }
}

///|
/// `getBitcastMethod( type )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_bitcast_method(
  _,
  b,
  type_,
  _,
) {
  let data_type = b.get_type(type_)
  "bitcast<\{data_type}>"
}

///|
/// `getFloatPackingMethod( encoding, layout = '2x16' )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_float_packing_method(
  _,
  b,
  encoding,
  layout,
) {
  b.get_method("floatpack_\{encoding}_\{layout}")
}

///|
/// `getFloatUnpackingMethod( encoding, layout = '2x16' )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_float_unpacking_method(
  _,
  b,
  encoding,
  layout,
) {
  b.get_method("floatunpack_\{encoding}_\{layout}")
}

///|
/// `getTernary( condSnippet, ifSnippet, elseSnippet )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_ternary(
  _,
  _,
  cond_snippet,
  if_snippet,
  else_snippet,
) {
  Some("select( \{else_snippet}, \{if_snippet}, \{cond_snippet} )")
}

///|
/// `getType( type )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_type(
  _,
  _,
  type_,
) {
  match _wgsl_type_lib(type_) {
    Some(t) => t
    None => type_
  }
}

///|
/// `isAvailable( name )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn is_available(
  _,
  b,
  name,
) {
  let result = match _wgsl_supports.get(name) {
    Some(Some(r)) => Some(r)
    _ => {
      let result = if name == "float32Filterable" {
        Some(wgsl_renderer_has_feature(b.renderer, "float32-filterable"))
      } else if name == "clipDistance" {
        Some(wgsl_renderer_has_feature(b.renderer, "clip-distances"))
      } else {
        None
      }
      _wgsl_supports.set(name, result)
      result
    }
  }
  result.unwrap_or(false)
}

///|
/// `_getWGSLMethod( method )`.
fn WGSLNodeBuilder::_get_wgsl_method(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  method_ : String,
) -> String? {
  if _wgsl_polyfill.contains(method_) {
    self._include(b, method_) |> ignore
  }
  _wgsl_methods(method_)
}

///|
/// `_include( name )`: builds the polyfill and adds it to the current function's
/// includes.
fn WGSLNodeBuilder::_include(
  _self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  name : String,
) -> @nodes.Node {
  let code_node = match _wgsl_polyfill.get(name) {
    Some(c) => c
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'build')")
  }
  code_node.build(b) |> ignore
  b.add_include(code_node)
  code_node
}
