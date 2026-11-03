// GLSLNodeBuilder.js, the shader assembly: uniforms and their bindings, attributes,
// structs, varyings, builtins, extensions, transforms, `buildCode` and the vertex and
// fragment templates.

///|
/// `getUniformBufferName( uniform, shaderStage )`.
pub fn GLSLNodeBuilder::get_uniform_buffer_name(
  _self : GLSLNodeBuilder,
  b : @nodes.NodeBuilder,
  uniform : @nodes.NodeUniform,
  shader_stage : String,
) -> String {
  match GLSLNodeBuilder::uniform_gpu(b, uniform.node, shader_stage) {
    Some(Binding(binding)) => binding.name
    Some(Uniform(u)) => u.name
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'name')")
  }
}

///|
/// `_getBindGroup( groupName, bindings )`: uniform blocks are named after their position
/// in the group.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn _get_bind_group(
  _,
  b,
  group_name,
  bindings,
) {
  for i, binding in bindings {
    if binding.has_flag("isNodeUniformBuffer") {
      binding.name = "NodeBuffer_" + group_name + "_" + i.to_string()
    }
  }
  b._get_bind_group_base(group_name, bindings)
}

///|
/// The `NodeUniform` of a uniform of a `NodeUniformsGroup` (`sharedUniform.nodeUniform`).
fn _glsl_node_uniform_of(uniform : @nodes.Uniform) -> @nodes.NodeUniform {
  match @nodes.NumberNodeUniform::of(uniform) {
    Some(u) => return u.node_uniform
    None => ()
  }
  match @nodes.Vector2NodeUniform::of(uniform) {
    Some(u) => return u.node_uniform
    None => ()
  }
  match @nodes.Vector3NodeUniform::of(uniform) {
    Some(u) => return u.node_uniform
    None => ()
  }
  match @nodes.Vector4NodeUniform::of(uniform) {
    Some(u) => return u.node_uniform
    None => ()
  }
  match @nodes.ColorNodeUniform::of(uniform) {
    Some(u) => return u.node_uniform
    None => ()
  }
  match @nodes.Matrix2NodeUniform::of(uniform) {
    Some(u) => return u.node_uniform
    None => ()
  }
  match @nodes.Matrix3NodeUniform::of(uniform) {
    Some(u) => return u.node_uniform
    None => ()
  }
  match @nodes.Matrix4NodeUniform::of(uniform) {
    Some(u) => return u.node_uniform
    None => ()
  }
  abort("TypeError: Cannot read properties of undefined (reading 'node')")
}

///|
/// `node.precision` of a uniform's node (`None` is `null`).
fn _glsl_precision(node : @nodes.Node) -> String? {
  match @nodes.InputNode::of(node) {
    Some(i) => i.precision
    None => None
  }
}

///|
/// `getUniforms( shaderStage )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_uniforms(
  self,
  b,
  shader_stage,
) {
  let uniforms = b.uniforms.stage(shader_stage)
  let binding_snippets = []
  let uniform_groups : Map[String, Array[String]] = Map([])
  for uniform in uniforms {
    let mut snippet = "null"
    let mut group = false
    if uniform.type_ == "texture" || uniform.type_ == "texture3D" {
      let texture_node = uniform.node
      let texture = @nodes.TextureNode::get_value(texture_node)
      let component_type = b.get_component_type_from_texture(texture)
      let type_prefix = if component_type == "float" {
        ""
      } else {
        _glsl_js_slice(component_type, 0, 1)
      }
      snippet = if uniform.type_ == "texture3D" &&
        texture.is_array_texture == false {
        "\{type_prefix}sampler3D \{uniform.name};"
      } else if texture.compare_function is Some(_) &&
        @nodes.TextureNode::is_sample_compare(texture_node) {
        if texture.is_array_texture == true {
          "sampler2DArrayShadow \{uniform.name};"
        } else {
          "sampler2DShadow \{uniform.name};"
        }
      } else if texture.is_array_texture == true ||
        texture.texture_type is DataArrayTexture ||
        texture.texture_type is CompressedArrayTexture {
        "\{type_prefix}sampler2DArray \{uniform.name};"
      } else {
        "\{type_prefix}sampler2D \{uniform.name};"
      }
    } else if uniform.type_ == "cubeTexture" {
      snippet = "samplerCube \{uniform.name};"
    } else if uniform.type_ == "cubeDepthTexture" {
      let texture = @nodes.TextureNode::get_value(uniform.node)
      snippet = if texture.compare_function is Some(_) {
        "samplerCubeShadow \{uniform.name};"
      } else {
        "samplerCube \{uniform.name};"
      }
    } else if uniform.type_ == "buffer" {
      let buffer_node = uniform.node
      let buffer = @nodes.BufferNode::of(buffer_node)
      let buffer_type = b.get_type(
        match buffer {
          Some(bn) => _glsl_str(bn.buffer_type)
          None => "undefined"
        },
      )
      let buffer_count = match buffer {
        Some(bn) => bn.buffer_count
        None => 0
      }
      let buffer_count_snippet = if buffer_count > 0 {
        buffer_count.to_string()
      } else {
        ""
      }
      snippet = "\{self.get_uniform_buffer_name(b, uniform, shader_stage)} {\n\t\{buffer_type} \{uniform.name}[\{buffer_count_snippet}];\n};\n"
    } else {
      let group_name = _glsl_node_name(uniform.group_node())
      // Check if this group has already been processed
      if !uniform_groups.contains(group_name) {
        // Get the shared uniform group that contains uniforms from all stages
        match self.uniform_groups.get(group_name) {
          Some(shared_uniform_group) => {
            // Generate snippets for ALL uniforms in this shared group
            let snippets = []
            for shared_uniform in shared_uniform_group.uniforms() {
              let type_ = shared_uniform.get_type()
              let vector_type = _glsl_str(b.get_vector_type(Some(type_)))
              let precision = _glsl_precision(
                _glsl_node_uniform_of(shared_uniform).node,
              )
              let mut uniform_snippet = "\{vector_type} \{shared_uniform.name};"
              match precision {
                Some(p) =>
                  uniform_snippet = _glsl_precision_lib(p) +
                    " " +
                    uniform_snippet
                None => ()
              }
              snippets.push("\t" + uniform_snippet)
            }
            uniform_groups.set(group_name, snippets)
          }
          None => ()
        }
      }
      group = true
    }
    if !group {
      match _glsl_precision(uniform.node) {
        Some(p) => snippet = _glsl_precision_lib(p) + " " + snippet
        None => ()
      }
      snippet = "uniform " + snippet
      binding_snippets.push(snippet)
    }
  }
  let mut output = ""
  for name, group_snippets in uniform_groups {
    output += _glsl_uniform_struct(name, group_snippets.join("\n")) + "\n"
  }
  output += binding_snippets.join("\n")
  output
}

///|
/// `/^[iu]/.test( type )`.
fn _glsl_is_int_type(type_ : String) -> Bool {
  type_.has_prefix("i") || type_.has_prefix("u")
}

///|
/// `getTypeFromAttribute( attribute )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_type_from_attribute(
  _,
  b,
  attribute,
) {
  let mut node_type = b.get_type_from_attribute_base(attribute)
  let gpu_type = match attribute {
    Buffer(a) => Some(a.gpu_type)
    _ => None
  }
  if _glsl_is_int_type(node_type) && gpu_type != Some(@core.IntType) {
    let array = attribute.array()
    let kind = array.kind()
    if (kind is Uint32Array || kind is Int32Array) == false {
      node_type = _glsl_js_slice(node_type, 1, node_type.length())
    }
  }
  node_type
}

///|
/// `getAttributes( shaderStage )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_attributes(
  _,
  b,
  shader_stage,
) {
  let mut snippet = ""
  if shader_stage == "vertex" || shader_stage == "compute" {
    let attributes = b.get_attributes_array()
    let mut location = 0
    for attribute in attributes {
      snippet += "layout( location = \{location} ) in \{attribute.type_} \{attribute.name};\n"
      location += 1
    }
  }
  snippet
}

///|
/// `getStructMembers( struct )`.
pub fn GLSLNodeBuilder::get_struct_members(
  _self : GLSLNodeBuilder,
  struct_ : @nodes.StructType,
) -> String {
  let snippets = []
  for struct_member in struct_.members {
    snippets.push("\t\{struct_member.type_} \{struct_member.name};")
  }
  snippets.join("\n")
}

///|
/// `getStructs( shaderStage )`.
pub fn GLSLNodeBuilder::get_structs(
  self : GLSLNodeBuilder,
  b : @nodes.NodeBuilder,
  shader_stage : String,
) -> String {
  let snippets = []
  let structs = b.structs.stage(shader_stage)
  let output_snippet = []
  for struct_ in structs {
    if struct_.output {
      for struct_member in struct_.members {
        let index = match struct_member.index {
          Some(i) => i.to_string()
          None => "undefined"
        }
        output_snippet.push(
          "layout( location = \{index} ) out \{struct_member.type_} \{struct_member.name};",
        )
      }
    } else {
      let mut snippet = "struct " + struct_.name + " {\n"
      snippet += self.get_struct_members(struct_)
      snippet += "\n};\n"
      snippets.push(snippet)
    }
  }
  if shader_stage == "fragment" && output_snippet.length() == 0 {
    output_snippet.push(
      "layout( location = 0 ) out \{b.get_output_type()} fragColor;",
    )
  }
  "\n" + output_snippet.join("\n") + "\n\n" + snippets.join("\n")
}

///|
/// `generateConstStatement( type, name, count = null )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn generate_const_statement(
  _,
  b,
  type_,
  name,
  count,
) {
  "const \{b.get_var(type_, name, count?)}"
}

///|
/// `generateVarStatement( type, name, count = null )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn generate_var_statement(
  _,
  b,
  type_,
  name,
  count,
) {
  b.get_var(type_, name, count?)
}

///|
/// The `flat ` qualifier of a varying without an interpolation type.
fn _glsl_flat(type_ : String) -> String {
  if type_.contains("int") || type_.contains("uv") || type_.contains("iv") {
    "flat "
  } else {
    ""
  }
}

///|
/// `getVaryings( shaderStage )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_varyings(
  self,
  b,
  shader_stage,
) {
  let mut snippet = if shader_stage == "vertex" &&
    b.context.get_bool("invariant") == Some(true) {
    "invariant gl_Position;\n"
  } else {
    ""
  }
  let varyings = b.varyings
  if shader_stage == "vertex" || shader_stage == "compute" {
    for varying in varyings {
      if shader_stage == "compute" {
        varying.needs_interpolation = true
      }
      let type_ = b.get_type(varying.type_)
      if varying.needs_interpolation {
        match varying.interpolation_type {
          Some(interpolation) if interpolation != "" => {
            let interpolation_type = _glsl_interpolation_type(interpolation)
            let sampling = _glsl_interpolation_mode(
              varying.interpolation_sampling,
            )
            snippet += "\{interpolation_type} \{sampling} out \{type_} \{varying.name};\n"
          }
          _ => {
            let flat = _glsl_flat(type_)
            snippet += "\{flat}out \{type_} \{varying.name};\n"
          }
        }
      } else {
        snippet += "\{type_} \{varying.name};\n" // generate variable (no varying required)
      }
    }
  } else if shader_stage == "fragment" {
    for varying in varyings {
      if varying.needs_interpolation {
        let type_ = b.get_type(varying.type_)
        match varying.interpolation_type {
          Some(interpolation) if interpolation != "" => {
            let interpolation_type = _glsl_interpolation_type(interpolation)
            let sampling = _glsl_interpolation_mode(
              varying.interpolation_sampling,
            )
            snippet += "\{interpolation_type} \{sampling} in \{type_} \{varying.name};\n"
          }
          _ => {
            let flat = _glsl_flat(type_)
            snippet += "\{flat}in \{type_} \{varying.name};\n"
          }
        }
      }
    }
  }
  match self.builtins.get(shader_stage) {
    Some(builtins) =>
      for builtin in builtins {
        snippet += "\{builtin};\n"
      }
    None =>
      abort(
        "TypeError: this.builtins[ shaderStage ] is not iterable (cannot read property undefined)",
      )
  }
  snippet
}

///|
/// `getVertexIndex()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_vertex_index(
  _,
  _,
) {
  "uint( gl_VertexID )"
}

///|
/// `getInstanceIndex()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_instance_index(
  _,
  _,
) {
  "uint( gl_InstanceID )"
}

///|
/// `getInvocationLocalIndex()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_invocation_local_index(
  _,
  b,
) {
  let workgroup_size = match b.compute {
    Some(c) =>
      match @nodes.ComputeNode::of(c) {
        Some(compute) => compute.workgroup_size
        None =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'reduce')",
          )
      }
    None =>
      abort(
        "TypeError: Cannot read properties of null (reading 'workgroupSize')",
      )
  }
  let size = workgroup_size.fold(init=1, fn(acc, curr) { acc * curr })
  "uint( gl_InstanceID ) % \{size}u"
}

///|
/// `getSubgroupSize()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_subgroup_size(
  _,
  _,
) {
  @core.error(
    "GLSLNodeBuilder: WebGLBackend does not support the subgroupSize node",
  )
  // `undefined`, which the index node's snippet prints as nothing.
  ""
}

///|
/// `getInvocationSubgroupIndex()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_invocation_subgroup_index(
  _,
  _,
) {
  @core.error(
    "GLSLNodeBuilder: WebGLBackend does not support the invocationSubgroupIndex node",
  )
  // `undefined`, which the index node's snippet prints as nothing.
  ""
}

///|
/// `getSubgroupIndex()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_subgroup_index(
  _,
  _,
) {
  @core.error(
    "GLSLNodeBuilder: WebGLBackend does not support the subgroupIndex node",
  )
  // `undefined`, which the index node's snippet prints as nothing.
  ""
}

///|
/// `enableSubGroups()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn enable_sub_groups(
  _,
  _,
) {
  @core.error(
    "GLSLNodeBuilder: WebGLBackend does not support subgroup operations",
  )
}

///|
/// `enableShaderF16()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn enable_shader_f16(
  _,
  _,
) {
  @core.error("GLSLNodeBuilder: WebGLBackend does not support 16 bit floats")
}

///|
/// `enableDualSourceBlending()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn enable_dual_source_blending(
  _,
  _,
) {
  @core.error(
    "GLSLNodeBuilder: WebGLBackend does not support dual source blending",
  )
}

///|
/// `getDrawIndex()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_draw_index(
  _,
  b,
) {
  let extensions = _glsl_backend_extensions(b)
  if extensions.has("WEBGL_multi_draw") {
    Some("uint( gl_DrawID )")
  } else {
    Some("nodeUniformDrawId") // fallback to uniform
  }
}

///|
/// `getFrontFacing()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_front_facing(
  _,
  _,
) {
  "gl_FrontFacing"
}

///|
/// `getFragCoord()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_frag_coord(
  _,
  _,
) {
  "gl_FragCoord.xy"
}

///|
/// `getFragDepth()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_frag_depth(
  _,
  _,
) {
  "gl_FragDepth"
}

///|
/// `enableExtension( name, behavior, shaderStage = this.shaderStage )`.
pub fn GLSLNodeBuilder::enable_extension(
  self : GLSLNodeBuilder,
  b : @nodes.NodeBuilder,
  name : String,
  behavior : String,
  shader_stage? : String,
) -> Unit {
  let shader_stage = _glsl_stage(b, shader_stage)
  let map = match self.extensions.get(shader_stage) {
    Some(m) => m
    None => {
      let m = Map([])
      self.extensions.set(shader_stage, m)
      m
    }
  }
  if map.contains(name) == false {
    map.set(name, { name, behavior, })
  }
}

///|
/// `this.object.isBatchedMesh`.
fn _glsl_is_batched_mesh(b : @nodes.NodeBuilder) -> Bool {
  match b.object {
    Object3D(o) => o.is_batched_mesh()
    NoObject =>
      abort(
        "TypeError: Cannot read properties of null (reading 'isBatchedMesh')",
      )
    Compute(_) => false
  }
}

///|
/// `getExtensions( shaderStage )`.
pub fn GLSLNodeBuilder::get_extensions(
  self : GLSLNodeBuilder,
  b : @nodes.NodeBuilder,
  shader_stage : String,
) -> String {
  let snippets = []
  if shader_stage == "vertex" {
    let ext = _glsl_backend_extensions(b)
    let is_batched_mesh = _glsl_is_batched_mesh(b)
    if is_batched_mesh && ext.has("WEBGL_multi_draw") {
      self.enable_extension(b, "GL_ANGLE_multi_draw", "require", shader_stage~)
    }
  }
  match self.extensions.get(shader_stage) {
    Some(extensions) =>
      for _, extension in extensions {
        snippets.push("#extension \{extension.name} : \{extension.behavior}")
      }
    None => ()
  }
  snippets.join("\n")
}

///|
/// `getClipDistance()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_clip_distance(
  _,
  _,
) {
  "gl_ClipDistance"
}

///|
/// `isAvailable( name )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn is_available(
  _,
  b,
  name,
) {
  match _glsl_supports.get(name) {
    Some(r) => r
    None => {
      let extension_name = match name {
        "float32Filterable" => Some("OES_texture_float_linear")
        "clipDistance" => Some("WEBGL_clip_cull_distance")
        _ => None
      }
      let mut result = false
      match extension_name {
        Some(extension_name) => {
          let extensions = _glsl_backend_extensions(b)
          if extensions.has(extension_name) {
            extensions.get(extension_name) |> ignore
            result = true
          }
        }
        None => ()
      }
      _glsl_supports.set(name, result)
      result
    }
  }
}

///|
/// `isFlipY()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn is_flip_y(_, _) {
  true
}

///|
/// `this.builtins[ stage ].push( snippet )`.
fn GLSLNodeBuilder::_push_builtin(
  self : GLSLNodeBuilder,
  stage : String,
  snippet : String,
) -> Unit {
  match self.builtins.get(stage) {
    Some(list) => list.push(snippet)
    None => self.builtins.set(stage, [snippet])
  }
}

///|
/// `enableHardwareClipping( planeCount )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn enable_hardware_clipping(
  self,
  b,
  plane_count,
) {
  self.enable_extension(b, "GL_ANGLE_clip_cull_distance", "require")
  self._push_builtin("vertex", "out float gl_ClipDistance[ \{plane_count} ]")
}

///|
/// `enableMultiview()`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn enable_multiview(
  self,
  b,
) {
  self.enable_extension(
    b,
    "GL_OVR_multiview2",
    "require",
    shader_stage="fragment",
  )
  self.enable_extension(
    b,
    "GL_OVR_multiview2",
    "require",
    shader_stage="vertex",
  )
  self._push_builtin("vertex", "layout(num_views = 2) in")
}

///|
/// `registerTransform( varyingName, attributeNode )`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn register_transform(
  self,
  _,
  varying_name,
  attribute_node,
) {
  self.transforms.push({ varying_name, attribute_node, })
}

///|
/// `nodeBuilder.transforms`.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn transforms(self, _) {
  Some(self.transforms)
}

///|
/// The `NodeVariable` an `attributeNode` names in `getPropertyName( attributeNode )`.
fn _glsl_transform_attribute_name(
  b : @nodes.NodeBuilder,
  attribute_node : @nodes.Node,
) -> String {
  // `getPropertyName( node )` of a node (not a node variable) reads `node.name`.
  ignore(b)
  match attribute_node.name {
    Some(n) => n
    None => ""
  }
}

///|
/// `getTransforms( shaderStage )`.
pub fn GLSLNodeBuilder::get_transforms(
  self : GLSLNodeBuilder,
  b : @nodes.NodeBuilder,
  _shader_stage : String,
) -> String {
  let transforms = self.transforms
  let mut snippet = ""
  for transform in transforms {
    let attribute_name = _glsl_transform_attribute_name(
      b,
      transform.attribute_node,
    )
    if attribute_name != "" {
      snippet += "\{transform.varying_name} = \{attribute_name};\n\t"
    }
  }
  snippet
}

///|
/// `_getGLSLUniformStruct( name, vars )`.
fn _glsl_uniform_struct(name : String, vars : String) -> String {
  "\nlayout( std140 ) uniform \{name} {\n\{vars}\n};"
}

///|
/// The stage data `buildCode` collects for a template.
priv struct GLSLStageData {
  mut extensions : String
  mut uniforms : String
  mut attributes : String
  mut varyings : String
  mut vars : String
  mut structs : String
  mut codes : String
  mut transforms : String
  mut flow : String
}

///|
/// `_getGLSLVertexCode( shaderData )`.
fn GLSLNodeBuilder::_get_glsl_vertex_code(
  _self : GLSLNodeBuilder,
  b : @nodes.NodeBuilder,
  shader_data : GLSLStageData,
) -> String {
  "#version 300 es\n\n\{b.get_signature()}\n\n// extensions\n\{shader_data.extensions}\n\n// precision\n\{_glsl_default_precisions}\n\n// structs\n\{shader_data.structs}\n\n// uniforms\n\{shader_data.uniforms}\n\n// varyings\n\{shader_data.varyings}\n\n// attributes\n\{shader_data.attributes}\n\n// vars\n\{shader_data.vars}\n\n// codes\n\{shader_data.codes}\n\nvoid main() {\n\n\t// transforms\n\t\{shader_data.transforms}\n\n\t// flow\n\t\{shader_data.flow}\n\n\tgl_PointSize = 1.0;\n\n}\n"
}

///|
/// `_getGLSLFragmentCode( shaderData )`.
fn GLSLNodeBuilder::_get_glsl_fragment_code(
  _self : GLSLNodeBuilder,
  b : @nodes.NodeBuilder,
  shader_data : GLSLStageData,
) -> String {
  "#version 300 es\n\n\{b.get_signature()}\n\n// extensions\n\{shader_data.extensions}\n\n// precision\n\{_glsl_default_precisions}\n\n// structs\n\{shader_data.structs}\n\n// uniforms\n\{shader_data.uniforms}\n\n// varyings\n\{shader_data.varyings}\n\n// vars\n\{shader_data.vars}\n\n// codes\n\{shader_data.codes}\n\nvoid main() {\n\n\t// flow\n\t\{shader_data.flow}\n\n}\n"
}

///|
/// `String( result )` of a flow result.
fn _glsl_result_string(result : @nodes.BuildResult) -> String {
  match result {
    Snippet(s) => s
    Null => "null"
    NodeResult(_) => "[object Object]"
  }
}

///|
/// `node.outputNode.isOutputStructNode` of a flow node.
fn _glsl_is_output_struct(node : @nodes.Node) -> Bool {
  match @nodes.StackNode::of(node) {
    Some(stack) =>
      match stack.output_node {
        Some(o) => o.has_flag("isOutputStructNode")
        None =>
          abort(
            "TypeError: Cannot read properties of null (reading 'isOutputStructNode')",
          )
      }
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'isOutputStructNode')",
      )
  }
}

///|
/// `buildCode()`: assembles `vertexShader`/`fragmentShader` (material) or
/// `computeShader` (compute).
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn build_code(self, b) {
  let stages = if b.material is Some(_) {
    ["fragment", "vertex"]
  } else {
    ["compute"]
  }
  let shaders_data : Map[String, GLSLStageData] = Map([])
  b.sort_binding_groups()
  for shader_stage in stages {
    let mut flow = "// code\n\n"
    flow += match b.flow_code.get(shader_stage) {
      Some(c) => c
      None => "undefined"
    }
    let flow_nodes = b.flow_nodes.get(shader_stage).unwrap_or([])
    let main_node = flow_nodes[flow_nodes.length() - 1]
    for node in flow_nodes {
      let flow_slot_data = match b.get_flow_data(node) {
        Some(d) => d
        None =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'code')",
          )
      }
      match node.name {
        Some(slot_name) if slot_name != "" => {
          if flow.length() > 0 {
            flow += "\n"
          }
          flow += "\t// flow -> \{slot_name}\n\t"
        }
        _ => ()
      }
      flow += "\{flow_slot_data.code}\n\t"
      if physical_equal(node, main_node) && shader_stage != "compute" {
        flow += "// result\n\t"
        if shader_stage == "vertex" {
          flow += "gl_Position = "
          flow += "\{b.format(_glsl_result_string(flow_slot_data.result), main_node.get_node_type(b), Some("vec4"))};"
        } else if shader_stage == "fragment" {
          if !_glsl_is_output_struct(node) {
            flow += "fragColor = "
            flow += "\{b.format(_glsl_result_string(flow_slot_data.result), main_node.get_node_type(b), Some(b.get_output_type()))};"
          }
        }
      }
    }
    let stage_data : GLSLStageData = {
      extensions: "",
      uniforms: "",
      attributes: "",
      varyings: "",
      vars: "",
      structs: "",
      codes: "",
      transforms: "",
      flow: "",
    }
    shaders_data.set(shader_stage, stage_data)
    stage_data.extensions = self.get_extensions(b, shader_stage)
    stage_data.uniforms = b.get_uniforms(shader_stage)
    stage_data.attributes = b.get_attributes(shader_stage)
    stage_data.varyings = b.get_varyings(shader_stage)
    stage_data.vars = b.get_vars(shader_stage, global=true)
    stage_data.structs = self.get_structs(b, shader_stage)
    stage_data.codes = b.get_codes(shader_stage)
    stage_data.transforms = self.get_transforms(b, shader_stage)
    stage_data.flow = flow
    // fallbacks
    if shader_stage == "vertex" {
      let ext = _glsl_backend_extensions(b)
      if _glsl_is_batched_mesh(b) && ext.has("WEBGL_multi_draw") == false {
        stage_data.uniforms += "\nuniform uint nodeUniformDrawId;\n"
      }
    }
  }
  if b.material is Some(_) {
    b.vertex_shader = Some(
      self._get_glsl_vertex_code(b, shaders_data.get("vertex").unwrap()),
    )
    b.fragment_shader = Some(
      self._get_glsl_fragment_code(b, shaders_data.get("fragment").unwrap()),
    )
  } else {
    b.compute_shader = Some(
      self._get_glsl_vertex_code(b, shaders_data.get("compute").unwrap()),
    )
  }
}

///|
/// `getUniformFromNode( node, type, shaderStage, name = null )`: also creates the
/// bindings of the uniform.
pub impl @nodes.NodeBuilderClass for GLSLNodeBuilder with fn get_uniform_from_node(
  self,
  b,
  node,
  type_,
  shader_stage,
  name,
) {
  let uniform_node = b.get_uniform_from_node_base(
    node,
    type_,
    shader_stage,
    if type_ == "buffer" {
      None
    } else {
      name
    },
  )
  let shader_stage = _glsl_str(shader_stage)
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
    let group_name = _glsl_node_name(group)
    let bindings = b.get_bind_group_array(group_name, shader_stage)
    let uniform_gpu : GLSLUniformGPU = if type_ == "texture" {
      let binding = @nodes.NodeSampledTexture::new(
        uniform_node.name,
        Some(uniform_node.node),
        Some(group),
      )
      bindings.push(binding)
      Binding(binding)
    } else if type_ == "cubeTexture" || type_ == "cubeDepthTexture" {
      let binding = @nodes.NodeSampledCubeTexture::new(
        uniform_node.name,
        Some(uniform_node.node),
        Some(group),
      )
      bindings.push(binding)
      Binding(binding)
    } else if type_ == "texture3D" {
      let binding = @nodes.NodeSampledTexture3D::new(
        uniform_node.name,
        Some(uniform_node.node),
        Some(group),
      )
      bindings.push(binding)
      Binding(binding)
    } else if type_ == "buffer" {
      let buffer = @nodes.NodeUniformBuffer::new(node, Some(group))
      bindings.push(buffer)
      Binding(buffer)
    } else {
      let uniforms_group = match self.uniform_groups.get(group_name) {
        Some(g) => {
          // Add to bindings for this stage if not already present
          if !bindings.iter().any(fn(x) { physical_equal(x, g) }) {
            bindings.push(g)
          }
          g
        }
        None => {
          let g = @nodes.NodeUniformsGroup::new(group_name, group)
          self.uniform_groups.set(group_name, g)
          bindings.push(g)
          g
        }
      }
      let uniform_gpu = b.get_node_uniform(uniform_node, type_)
      // Only add uniform if not already present in the group (check by name to avoid
      // duplicates across stages)
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
    node_data.extra.set("uniformGPU", @core.JsValue::of(uniform_gpu))
  }
  uniform_node
}

///|
/// `nodeData.uniformGPU` of a uniform node in a stage (`None` is `undefined`).
pub fn GLSLNodeBuilder::uniform_gpu(
  builder : @nodes.NodeBuilder,
  node : @nodes.Node,
  shader_stage : String,
) -> GLSLUniformGPU? {
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
/// `string.slice( start, end )`.
extern "js" fn _glsl_js_slice(s : String, start : Int32, end : Int32) -> String = "(s, a, b) => s.slice( a, b )"
