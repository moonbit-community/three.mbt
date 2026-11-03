// WGSLNodeBuilder.js, the shader assembly: attributes, structs, varyings, uniforms and
// bindings, `buildCode` and the vertex/fragment/compute entry point templates.

///|
/// `getAttributes( shaderStage )`.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_attributes(
  self,
  b,
  shader_stage,
) {
  let snippets = []
  if shader_stage == "compute" {
    self.get_builtin(
      b,
      "global_invocation_id",
      "globalId",
      "vec3<u32>",
      shader_stage="attribute",
    )
    |> ignore
    self.get_builtin(
      b,
      "workgroup_id",
      "workgroupId",
      "vec3<u32>",
      shader_stage="attribute",
    )
    |> ignore
    self.get_builtin(
      b,
      "local_invocation_id",
      "localId",
      "vec3<u32>",
      shader_stage="attribute",
    )
    |> ignore
    self.get_builtin(
      b,
      "num_workgroups",
      "numWorkgroups",
      "vec3<u32>",
      shader_stage="attribute",
    )
    |> ignore
    if wgsl_renderer_has_feature(b.renderer, "subgroups") {
      self.enable_directive(b, "subgroups", shader_stage~)
      self.get_builtin(
        b,
        "subgroup_size",
        "subgroupSize",
        "u32",
        shader_stage="attribute",
      )
      |> ignore
    }
  }
  if shader_stage == "vertex" || shader_stage == "compute" {
    let builtins = self.get_builtins(b, "attribute")
    if builtins != "" {
      snippets.push(builtins)
    }
    let attributes = b.get_attributes_array()
    for index, attribute in attributes {
      let name = attribute.name
      let type_ = b.get_type(attribute.type_)
      snippets.push("@location( \{index} ) \{name} : \{type_}")
    }
  }
  snippets.join(",\n\t")
}

///|
/// `getStructMembers( struct )`.
pub fn WGSLNodeBuilder::get_struct_members(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  struct_ : @nodes.StructType,
) -> String {
  let snippets = []
  for struct_member in struct_.members {
    let prefix = if struct_.output {
      let index = match struct_member.index {
        Some(i) => i.to_string()
        None => "undefined"
      }
      "@location( " + index + " ) "
    } else {
      ""
    }
    let mut type_ = b.get_type(struct_member.type_)
    if struct_member.atomic_ {
      type_ = "atomic< " + type_ + " >"
    }
    snippets.push("\t\{prefix + struct_member.name} : \{type_}")
  }
  if struct_.output {
    snippets.push("\t\{self.get_builtins(b, "output")}")
  }
  snippets.join(",\n")
}

///|
/// `getStructs( shaderStage )`.
pub fn WGSLNodeBuilder::get_structs(
  self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  shader_stage : String,
) -> String {
  let mut result = ""
  let structs = b.structs.stage(shader_stage)
  if structs.length() > 0 {
    let snippets = []
    for struct_ in structs {
      let mut snippet = "struct \{struct_.name} {\n"
      snippet += self.get_struct_members(b, struct_)
      snippet += "\n};"
      snippets.push(snippet)
    }
    result = "\n" + snippets.join("\n\n") + "\n"
  }
  result
}

///|
/// `/^(int|uint|ivec|uvec)/.test( type )`.
fn _wgsl_is_integer_varying(type_ : String) -> Bool {
  type_.has_prefix("int") ||
  type_.has_prefix("uint") ||
  type_.has_prefix("ivec") ||
  type_.has_prefix("uvec")
}

///|
/// `getVaryings( shaderStage )`: the `VaryingsStruct` (vertex) or the fragment entry
/// point's parameters.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_varyings(
  self,
  b,
  shader_stage,
) {
  let snippets = []
  if shader_stage == "vertex" {
    self.get_builtin(
      b,
      "position",
      "builtinClipSpace",
      "vec4<f32>",
      shader_stage="vertex",
    )
    |> ignore
  }
  if shader_stage == "vertex" || shader_stage == "fragment" {
    let varyings = b.varyings
    let vars = b.vars.get(shader_stage)
    let mut varying_index = 0
    for varying in varyings {
      if varying.needs_interpolation {
        let mut attributes_snippet = "@location( \{varying_index} )"
        varying_index += 1
        match varying.interpolation_type {
          Some(interpolation_type) if interpolation_type != "" => {
            let sampling_snippet = match varying.interpolation_sampling {
              Some(sampling) => ", \{sampling} )"
              None => " )"
            }
            attributes_snippet += " @interpolate( \{interpolation_type}\{sampling_snippet}"
          }
          // Otherwise, optimize interpolation when sensible
          _ =>
            if _wgsl_is_integer_varying(varying.type_) {
              attributes_snippet += " @interpolate(flat, either)"
            }
        }
        snippets.push(
          "\{attributes_snippet} \{varying.name} : \{b.get_type(varying.type_)}",
        )
      } else if shader_stage == "vertex" {
        let vars = match vars {
          Some(v) => v
          None =>
            abort(
              "TypeError: Cannot read properties of undefined (reading 'includes')",
            )
        }
        if !self._vars_include_varying(vars, varying) {
          let variable = @nodes.NodeVar::new(
            varying.name,
            varying.type_,
            read_only=varying.read_only,
            count?=varying.count,
            local_=varying.local_,
          )
          self.varying_vars.push((varying, variable))
          vars.push(variable)
        }
      }
    }
  }
  let builtins = self.get_builtins(b, shader_stage)
  if builtins != "" {
    snippets.push(builtins)
  }
  let code = snippets.join(",\n\t")
  if shader_stage == "vertex" {
    _wgsl_struct("VaryingsStruct", "\t" + code)
  } else {
    code
  }
}

///|
/// `vars.includes( varying )`: whether `vars` holds the var pushed for `varying`.
fn WGSLNodeBuilder::_vars_include_varying(
  self : WGSLNodeBuilder,
  vars : Array[@nodes.NodeVar],
  varying : @nodes.NodeVarying,
) -> Bool {
  for entry in self.varying_vars {
    if physical_equal(entry.0, varying) &&
      vars.iter().any(fn(v) { physical_equal(v, entry.1) }) {
      return true
    }
  }
  false
}

///|
/// `bindingsIndexes[ groupName ]` = `{ binding, group }`; `binding ++` returns the
/// index and advances it.
fn _wgsl_next_binding(b : @nodes.NodeBuilder, group_name : String) -> Int32 {
  match b.bindings_indexes.get(group_name) {
    Some((binding, group)) => {
      b.bindings_indexes.set(group_name, (binding + 1, group))
      binding
    }
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'binding')",
      )
  }
}

///|
fn _wgsl_binding_group(b : @nodes.NodeBuilder, group_name : String) -> Int32 {
  match b.bindings_indexes.get(group_name) {
    Some((_, group)) => group
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'group')")
  }
}

///|
/// `getUniforms( shaderStage )`: the texture, sampler, buffer and uniform group
/// declarations of a stage.
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn get_uniforms(
  self,
  b,
  shader_stage,
) {
  let uniforms = b.uniforms.stage(shader_stage)
  let binding_snippets = []
  let buffer_snippets = []
  let struct_snippets = []
  // `uniformGroups`: group name -> `{ index, id, snippets }`.
  let uniform_groups : Map[String, (Int32, Int32, Array[String])] = Map([])
  for uniform in uniforms {
    let group_name = _wgsl_node_name(uniform.group_node())
    match uniform.type_ {
      "texture"
      | "cubeTexture"
      | "cubeDepthTexture"
      | "storageTexture"
      | "texture3D" => {
        let texture_node = uniform.node
        let texture = @nodes.TextureNode::get_value(texture_node)
        // Cube textures always need samplers (they use textureSampleLevel, not
        // textureLoad). Also textureGather always need sampler.
        let needs_sampler = texture.is_cube_texture() ||
          (
            !self.is_unfilterable(b, texture) &&
            !texture_node.has_flag("isStorageTextureNode")
          ) ||
          _wgsl_gather_node(texture_node) is Some(_)
        if needs_sampler {
          if self.is_sample_compare(b, texture) &&
            @nodes.TextureNode::is_sample_compare(texture_node) {
            let binding = _wgsl_next_binding(b, group_name)
            let group = _wgsl_binding_group(b, group_name)
            binding_snippets.push(
              "@binding( \{binding} ) @group( \{group} ) var \{uniform.name}_sampler : sampler_comparison;",
            )
          } else {
            let binding = _wgsl_next_binding(b, group_name)
            let group = _wgsl_binding_group(b, group_name)
            binding_snippets.push(
              "@binding( \{binding} ) @group( \{group} ) var \{uniform.name}_sampler : sampler;",
            )
          }
        }
        let mut multisampled = ""
        let { primary_samples, .. } = wgsl_get_texture_sample_data(
          b.renderer,
          texture,
        )
        if primary_samples > 1 {
          multisampled = "_multisampled"
        }
        let texture_type = if texture.is_cube_texture() &&
          texture.is_depth_texture() {
          "texture_depth_cube"
        } else if texture.is_cube_texture() {
          "texture_cube<f32>"
        } else if texture.is_depth_texture() {
          if wgsl_backend_compatibility_mode(b.renderer) &&
            texture.compare_function is None {
            "texture\{multisampled}_2d<f32>"
          } else {
            let array = if texture.is_array_texture { "_array" } else { "" }
            "texture_depth\{multisampled}_2d\{array}"
          }
        } else if texture_node.has_flag("isStorageTextureNode") {
          let format = wgsl_get_format(b.renderer, texture)
          let access = self.get_storage_access(texture_node, shader_stage)
          let value = @nodes.TextureNode::get_value(texture_node)
          let is_3d = value.has_extension_flag("is3DTexture")
          let dimension = if is_3d {
            "3d"
          } else if value.is_array_texture {
            "2d_array"
          } else {
            "2d"
          }
          "texture_storage_\{dimension}<\{format}, \{access}>"
        } else if texture.is_array_texture ||
          texture.texture_type is DataArrayTexture ||
          texture.texture_type is CompressedArrayTexture {
          let component_prefix = _wgsl_char_at0(
            b.get_component_type_from_texture(texture),
          )
          "texture_2d_array<\{component_prefix}32>"
        } else if _wgsl_is_3d(texture) {
          let component_prefix = _wgsl_char_at0(
            b.get_component_type_from_texture(texture),
          )
          "texture_3d<\{component_prefix}32>"
        } else {
          let component_prefix = _wgsl_char_at0(
            b.get_component_type_from_texture(texture),
          )
          "texture\{multisampled}_2d<\{component_prefix}32>"
        }
        let binding = _wgsl_next_binding(b, group_name)
        let group = _wgsl_binding_group(b, group_name)
        binding_snippets.push(
          "@binding( \{binding} ) @group( \{group} ) var \{uniform.name} : \{texture_type};",
        )
      }
      "buffer" | "storageBuffer" | "indirectStorageBuffer" => {
        let buffer_node = uniform.node
        let buffer_type = b.get_type(
          match buffer_node.get_node_type(b) {
            Some(t) => t
            None => "null"
          },
        )
        let buffer_count = match @nodes.BufferNode::of(buffer_node) {
          Some(buffer) => buffer.buffer_count
          None => 0
        }
        let buffer_count_snippet = if buffer_count > 0 &&
          uniform.type_ == "buffer" {
          ", " + buffer_count.to_string()
        } else {
          ""
        }
        let buffer_access_mode = if buffer_node.has_flag("isStorageBufferNode") {
          "storage, \{self.get_storage_access(buffer_node, shader_stage)}"
        } else {
          "uniform"
        }
        let buffer_type_snippet = if _wgsl_is_atomic(buffer_node) {
          "atomic<\{buffer_type}>"
        } else {
          "\{buffer_type}"
        }
        let buffer_snippet = "\tvalue : array< \{buffer_type_snippet}\{buffer_count_snippet} >"
        let binding = _wgsl_next_binding(b, group_name)
        let group = _wgsl_binding_group(b, group_name)
        buffer_snippets.push(
          _wgsl_struct_binding(
            uniform.name,
            buffer_snippet,
            buffer_access_mode,
            binding,
            group,
          ),
        )
      }
      _ =>
        // Check if this group has already been processed in this shader stage
        if !uniform_groups.contains(group_name) {
          // Get the shared uniform group that contains uniforms from all stages
          match self.uniform_groups.get(group_name) {
            Some(shared_uniform_group) => {
              // Generate snippets for ALL uniforms in this shared group
              let snippets = []
              for shared_uniform in shared_uniform_group.uniforms() {
                let type_ = shared_uniform.get_type()
                let vector_type = b.get_type(
                  match b.get_vector_type(Some(type_)) {
                    Some(t) => t
                    None => "null"
                  },
                )
                snippets.push("\t\{shared_uniform.name} : \{vector_type}")
              }
              // Check if this group already has an assigned binding index (from
              // another shader stage)
              let group_binding = match
                self.uniform_groups_bindings.get(group_name) {
                Some(g) => g
                None => {
                  // First time processing this group - assign a new binding index
                  let index = _wgsl_next_binding(b, group_name)
                  let g = (index, _wgsl_binding_group(b, group_name))
                  self.uniform_groups_bindings.set(group_name, g)
                  g
                }
              }
              uniform_groups.set(
                group_name,
                (group_binding.0, group_binding.1, snippets),
              )
            }
            None => ()
          }
        }
    }
  }
  for name, group in uniform_groups {
    struct_snippets.push(
      _wgsl_struct_binding(
        name,
        group.2.join(",\n"),
        "uniform",
        group.0,
        group.1,
      ),
    )
  }
  (binding_snippets + buffer_snippets + struct_snippets).join("\n")
}

///|
/// `mainNode.outputNode` of a flow node: `None` is `undefined` (nodes without the
/// property), `Some(None)` a `null` output.
fn _wgsl_output_node(node : @nodes.Node) -> @nodes.Node?? {
  match @nodes.StackNode::of(node) {
    Some(stack) => Some(stack.output_node)
    None => None
  }
}

///|
/// The stage data `buildCode` collects for a template.
priv struct WGSLStageData {
  uniforms : String
  attributes : String
  varyings : String
  mut structs : String
  vars : String
  codes : String
  directives : String
  /// `None` is `undefined` (outside compute).
  scoped_arrays : String?
  mut flow : String
  /// `None` is `undefined`.
  mut return_type : String?
}

///|
/// `String( result )` of a flow result.
fn _wgsl_result_string(result : @nodes.BuildResult) -> String {
  match result {
    Snippet(s) => s
    Null => "null"
    NodeResult(_) => "[object Object]"
  }
}

///|
/// `buildCode()`: assembles `vertexShader`/`fragmentShader` (material) or
/// `computeShader` (compute).
pub impl @nodes.NodeBuilderClass for WGSLNodeBuilder with fn build_code(self, b) {
  let stages = if b.material is Some(_) {
    ["fragment", "vertex"]
  } else {
    ["compute"]
  }
  let shaders_data : Map[String, WGSLStageData] = Map([])
  b.sort_binding_groups()
  for shader_stage in stages {
    b.shader_stage = Some(shader_stage)
    let allow_global = b.allow_global_variables
    let uniforms = b.get_uniforms(shader_stage)
    let attributes = b.get_attributes(shader_stage)
    let varyings = b.get_varyings(shader_stage)
    let structs = self.get_structs(b, shader_stage)
    let vars = b.get_vars(shader_stage, global=allow_global)
    let codes = b.get_codes(shader_stage)
    let directives = self.get_directives(shader_stage)
    let scoped_arrays = self.get_scoped_arrays(b, shader_stage)
    let stage_data : WGSLStageData = {
      uniforms,
      attributes,
      varyings,
      structs,
      vars,
      codes,
      directives,
      scoped_arrays,
      flow: "",
      return_type: None,
    }
    shaders_data.set(shader_stage, stage_data)
    let mut flow = "// code\n\n"
    flow += b.flow_code.get(shader_stage).unwrap_or("")
    let flow_nodes = b.flow_nodes.get(shader_stage).unwrap_or([])
    let main_node = flow_nodes[flow_nodes.length() - 1]
    let output_node = _wgsl_output_node(main_node)
    let is_output_struct = match output_node {
      None => false
      Some(Some(o)) => o.has_flag("isOutputStructNode")
      Some(None) =>
        abort(
          "TypeError: Cannot read properties of null (reading 'isOutputStructNode')",
        )
    }
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
          flow += "\t// flow -> \{slot_name}\n"
        }
        _ => ()
      }
      flow += "\{flow_slot_data.code}\n\t"
      if physical_equal(node, main_node) && shader_stage != "compute" {
        flow += "// result\n\n\t"
        let result = _wgsl_result_string(flow_slot_data.result)
        if shader_stage == "vertex" {
          flow += "varyings.builtinClipSpace = \{result};"
        } else if shader_stage == "fragment" {
          if is_output_struct {
            let return_type = _wgsl_str(
              output_node.unwrap().unwrap().get_node_type(b),
            )
            stage_data.return_type = Some(return_type)
            stage_data.structs += "var<private> output : " + return_type + ";"
            flow += "return \{result};"
          } else {
            let mut struct_snippet = "\t@location( 0 ) color: \{b.get_type(b.get_output_type())}"
            let builtins = self.get_builtins(b, "output")
            if builtins != "" {
              struct_snippet += ",\n\t" + builtins
            }
            stage_data.return_type = Some("OutputStruct")
            stage_data.structs += _wgsl_struct("OutputStruct", struct_snippet)
            stage_data.structs += "\nvar<private> output : OutputStruct;"
            let formatted = b.format(
              result,
              main_node.get_node_type(b),
              Some(b.get_output_type()),
            )
            flow += "output.color = \{formatted};\n\n\treturn output;"
          }
        }
      }
    }
    stage_data.flow = flow
  }
  b.shader_stage = None
  if b.material is Some(_) {
    b.vertex_shader = Some(
      self._get_wgsl_vertex_code(b, shaders_data.get("vertex").unwrap()),
    )
    b.fragment_shader = Some(
      self._get_wgsl_fragment_code(b, shaders_data.get("fragment").unwrap()),
    )
  } else {
    // Early strictly validated in computeNode
    let workgroup_size = match b.compute {
      Some(c) =>
        match @nodes.ComputeNode::of(c) {
          Some(compute) => compute.workgroup_size
          None =>
            abort(
              "TypeError: workgroupSize is not iterable (cannot read property undefined)",
            )
        }
      None =>
        abort(
          "TypeError: Cannot read properties of null (reading 'workgroupSize')",
        )
    }
    b.compute_shader = Some(
      self._get_wgsl_compute_code(
        b,
        shaders_data.get("compute").unwrap(),
        workgroup_size,
      ),
    )
  }
}

///|
/// `_getWGSLVertexCode( shaderData )`.
fn WGSLNodeBuilder::_get_wgsl_vertex_code(
  _self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  shader_data : WGSLStageData,
) -> String {
  [
    "\{b.get_signature()}",
    "// directives",
    "\{shader_data.directives}",
    "",
    "// structs",
    "\{shader_data.structs}",
    "",
    "// uniforms",
    "\{shader_data.uniforms}",
    "",
    "// varyings",
    "\{shader_data.varyings}",
    "var<private> varyings : VaryingsStruct;",
    "",
    "// vars",
    "\{shader_data.vars}",
    "",
    "// codes",
    "\{shader_data.codes}",
    "",
    "@vertex",
    "fn main( \{shader_data.attributes} ) -> VaryingsStruct {",
    "",
    "\t// flow",
    "\t\{shader_data.flow}",
    "",
    "\treturn varyings;",
    "",
    "}",
    "",
  ].join("\n")
}

///|
/// `_getWGSLFragmentCode( shaderData )`.
fn WGSLNodeBuilder::_get_wgsl_fragment_code(
  _self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  shader_data : WGSLStageData,
) -> String {
  let return_type = match shader_data.return_type {
    Some(t) => t
    None => "undefined"
  }
  [
    "\{b.get_signature()}",
    "// global",
    "\{_wgsl_diagnostics}",
    "",
    "// directives",
    "\{shader_data.directives}",
    "",
    "// structs",
    "\{shader_data.structs}",
    "",
    "// uniforms",
    "\{shader_data.uniforms}",
    "",
    "// vars",
    "\{shader_data.vars}",
    "",
    "// codes",
    "\{shader_data.codes}",
    "",
    "@fragment",
    "fn main( \{shader_data.varyings} ) -> \{return_type} {",
    "",
    "\t// flow",
    "\t\{shader_data.flow}",
    "",
    "}",
    "",
  ].join("\n")
}

///|
/// `_getWGSLComputeCode( shaderData, workgroupSize )`.
fn WGSLNodeBuilder::_get_wgsl_compute_code(
  _self : WGSLNodeBuilder,
  b : @nodes.NodeBuilder,
  shader_data : WGSLStageData,
  workgroup_size : Array[Int32],
) -> String {
  let size = fn(i : Int32) -> String {
    if i < workgroup_size.length() {
      workgroup_size[i].to_string()
    } else {
      "undefined"
    }
  }
  let x = size(0)
  let y = size(1)
  let z = size(2)
  let scoped_arrays = match shader_data.scoped_arrays {
    Some(s) => s
    None => "undefined"
  }
  let global_vars = if b.allow_global_variables { shader_data.vars } else { "" }
  let local_vars = if b.allow_global_variables { "" } else { shader_data.vars }
  [
    "\{b.get_signature()}",
    "// directives",
    "\{shader_data.directives}",
    "",
    "// system",
    "var<private> instanceIndex : u32;",
    "",
    "// locals",
    "\{scoped_arrays}",
    "",
    "// structs",
    "\{shader_data.structs}",
    "",
    "// uniforms",
    "\{shader_data.uniforms}",
    "",
    "// vars",
    "\{global_vars}",
    "",
    "// codes",
    "\{shader_data.codes}",
    "",
    "@compute @workgroup_size( \{x}, \{y}, \{z} )",
    "fn main( \{shader_data.attributes} ) {",
    "",
    "\t// local vars",
    "\t\{local_vars}",
    "",
    "\t// system",
    "\tinstanceIndex = globalId.x",
    "\t\t+ globalId.y * ( \{x} * numWorkgroups.x )",
    "\t\t+ globalId.z * ( \{x} * numWorkgroups.x ) * ( \{y} * numWorkgroups.y );",
    "",
    "\t// flow",
    "\t\{shader_data.flow}",
    "",
    "}",
    "",
  ].join("\n")
}

///|
/// `_getWGSLStruct( name, vars )`.
fn _wgsl_struct(name : String, vars : String) -> String {
  "\nstruct \{name} {\n\{vars}\n};"
}

///|
/// `_getWGSLStructBinding( name, vars, access, binding = 0, group = 0 )`.
fn _wgsl_struct_binding(
  name : String,
  vars : String,
  access : String,
  binding : Int32,
  group : Int32,
) -> String {
  let struct_name = name + "Struct"
  let struct_snippet = _wgsl_struct(struct_name, vars)
  "\{struct_snippet}\n@binding( \{binding} ) @group( \{group} )\nvar<\{access}> \{name} : \{struct_name};"
}
