// renderers/webgpu/utils/WebGPUPipelineUtils.js: render and compute pipelines, render
// bundle encoders and the blend / stencil / depth state of materials.

///|
let _web_gpu_pipeline_utils_compute_pipeline_descriptor : @gpu.GPUComputePipelineDescriptor = @gpu.GPUComputePipelineDescriptor::default()

///|
let _web_gpu_pipeline_utils_pipeline_layout_descriptor : @gpu.GPUPipelineLayoutDescriptor = @gpu.GPUPipelineLayoutDescriptor::default()

///|
let _web_gpu_pipeline_utils_render_bundle_encoder_descriptor : @gpu.GPURenderBundleEncoderDescriptor = @gpu.GPURenderBundleEncoderDescriptor::default()

///|
let _web_gpu_pipeline_utils_render_pipeline_descriptor : @gpu.GPURenderPipelineDescriptor = @gpu.GPURenderPipelineDescriptor::default()

///|
/// `new Promise( ( resolve ) => executor( resolve ) )`.
extern "js" fn wgpu_new_promise(
  executor : (() -> Unit) -> Unit,
) -> @core.JsValue = "(f) => new Promise( ( resolve ) => { f( () => resolve() ); } )"

///|
/// `ReversedDepthFuncs[ depthFunc ]` (utils.js); `None` is `undefined`.
fn wgpu_reversed_depth_func(depth_func : Int32) -> Int32? {
  match depth_func {
    @core.NeverDepth => Some(@core.NeverDepth)
    @core.LessDepth => Some(@core.GreaterDepth)
    @core.EqualDepth => Some(@core.EqualDepth)
    @core.LessEqualDepth => Some(@core.GreaterEqualDepth)
    @core.AlwaysDepth => Some(@core.AlwaysDepth)
    @core.GreaterDepth => Some(@core.LessDepth)
    @core.NotEqualDepth => Some(@core.NotEqualDepth)
    @core.GreaterEqualDepth => Some(@core.LessEqualDepth)
    _ => None
  }
}

///|
/// What `_getBlending( object )` reads of a material or a `BlendMode`.
priv struct WebGPUBlendSource {
  blending : Int32
  blend_src : Int32
  blend_dst : Int32
  blend_equation : Int32
  blend_src_alpha : Int32?
  blend_dst_alpha : Int32?
  blend_equation_alpha : Int32?
  /// `object.premultipliedAlpha` (`undefined`, i.e. false, for a `BlendMode`).
  premultiplied_alpha : Bool
  is_material : Bool
}

///|
fn WebGPUBlendSource::of_material(
  material : @core.Material,
) -> WebGPUBlendSource {
  {
    blending: material.blending,
    blend_src: material.blend_src,
    blend_dst: material.blend_dst,
    blend_equation: material.blend_equation,
    blend_src_alpha: material.blend_src_alpha,
    blend_dst_alpha: material.blend_dst_alpha,
    blend_equation_alpha: material.blend_equation_alpha,
    premultiplied_alpha: material.premultiplied_alpha,
    is_material: true,
  }
}

///|
fn WebGPUBlendSource::of_blend_mode(
  mode : @nodes.BlendMode,
) -> WebGPUBlendSource {
  {
    blending: mode.blending,
    blend_src: mode.blend_src,
    blend_dst: mode.blend_dst,
    blend_equation: mode.blend_equation,
    blend_src_alpha: mode.blend_src_alpha,
    blend_dst_alpha: mode.blend_dst_alpha,
    blend_equation_alpha: mode.blend_equation_alpha,
    premultiplied_alpha: false,
    is_material: false,
  }
}

///|
/// A stage of `_reportShaderDiagnostics`: `{ program, module }`.
priv struct WebGPUShaderStageInfo {
  program : @nodes.ProgrammableStage
  module_ : @gpu.GPUShaderModule
}

///|
/// `WebGPUPipelineUtils`.
pub(all) struct WebGPUPipelineUtils {
  /// `backend`, linked right after the backend is built.
  mut backend_ : WebGPUBackend?
}

///|
/// `new WebGPUPipelineUtils( backend )` (the backend is linked by `WebGPUBackend::new`).
fn WebGPUPipelineUtils::new() -> WebGPUPipelineUtils {
  { backend_: None, }
}

///|
fn WebGPUPipelineUtils::backend(self : WebGPUPipelineUtils) -> WebGPUBackend {
  self.backend_.unwrap()
}

///|
/// `_getSampleCount( renderContext )`.
fn WebGPUPipelineUtils::_get_sample_count(
  self : WebGPUPipelineUtils,
  render_context : @nodes.RenderContext,
) -> Int32 {
  self.backend().utils.get_sample_count_render_context(render_context)
}

///|
/// `backend.get( program ).module`.
fn wgpu_program_module(
  backend : WebGPUBackend,
  program : @nodes.ProgrammableStage,
) -> WebGPUProgramModule {
  backend.get(@core.JsValue::of(program)).get("module").cast()
}

///|
/// `createRenderPipeline( renderObject, promises )`.
pub fn WebGPUPipelineUtils::create_render_pipeline(
  self : WebGPUPipelineUtils,
  render_object : @nodes.RenderObject,
  promises : Array[@core.JsValue]?,
) -> Unit {
  let object = render_object.object
  let material = render_object.material
  let geometry = render_object.geometry
  let pipeline = render_object.pipeline.unwrap()
  let vertex_program = pipeline.vertex_program()
  let fragment_program = pipeline.fragment_program()
  let backend = self.backend()
  let device = backend.gpu_device()
  let utils = backend.utils
  let pipeline_data = backend.get(@core.JsValue::of(pipeline))
  // bind group layouts
  let bind_group_layouts = []
  for bind_group in render_object.get_bindings() {
    let bindings_data = backend.get(@core.JsValue::of(bind_group))
    let layout : WebGPUBindGroupLayout = bindings_data.get("layout").cast()
    bind_group_layouts.push(layout.layout_gpu)
  }
  // vertex buffers
  let vertex_buffers = backend.attribute_utils.get_vertex_buffer_layout(
    render_object,
  )
  // material blending
  let mut material_blending = None
  if material.blending != @core.NoBlending &&
    (material.blending != @core.NormalBlending || material.transparent != false) {
    material_blending = self._get_blending(
      WebGPUBlendSource::of_material(material),
    )
  }
  // stencil
  let mut stencil_front = @gpu.GPUStencilFaceState::new()
  if material.stencil_write == true {
    stencil_front = @gpu.GPUStencilFaceState::new(
      compare?=self._get_stencil_compare(material),
      fail_op?=self._get_stencil_operation(material.stencil_fail),
      depth_fail_op?=self._get_stencil_operation(material.stencil_z_fail),
      pass_op?=self._get_stencil_operation(material.stencil_z_pass),
    )
  }
  let color_write_mask = self._get_color_write_mask(material)
  let targets = []
  match render_object.context.textures {
    Some(textures) => {
      let mrt = render_object.context.mrt
      for texture in textures {
        let color_format = utils.get_texture_format_gpu(texture)
        // mrt blending
        let mut blending = None
        match mrt {
          Some(mrt) =>
            if backend.compatibility_mode != Some(true) {
              let blend_mode = @nodes.MRTNode::of(mrt)
                .unwrap()
                .get_blend_mode(texture.name)
              if blend_mode.blending == @core.MaterialBlending {
                blending = material_blending
              } else if blend_mode.blending != @core.NoBlending {
                blending = self._get_blending(
                  WebGPUBlendSource::of_blend_mode(blend_mode),
                )
              }
            } else {
              @core.warn_once(
                "WebGPURenderer: Multiple Render Targets (MRT) blending configuration is not fully supported in compatibility mode. The material blending will be used for all render targets.",
              )
              blending = material_blending
            }
          None => blending = material_blending
        }
        targets.push(
          @gpu.GPUColorTargetState::new(
            format=color_format.unwrap_or("undefined"),
            blend?=blending,
            write_mask=color_write_mask,
          ),
        )
      }
    }
    None => {
      let color_format = utils.get_current_color_format(render_object.context)
      targets.push(
        @gpu.GPUColorTargetState::new(
          format=color_format.unwrap_or("undefined"),
          blend?=material_blending,
          write_mask=color_write_mask,
        ),
      )
    }
  }
  let vertex_module = wgpu_program_module(backend, vertex_program)
  let fragment_module = wgpu_program_module(backend, fragment_program)
  let primitive_state = self._get_primitive_state(object, geometry, material)
  let depth_compare = self._get_depth_compare(material)
  let depth_stencil_format = utils.get_current_depth_stencil_format(
    render_object.context,
  )
  let sample_count = self._get_sample_count(render_object.context)
  let pld = _web_gpu_pipeline_utils_pipeline_layout_descriptor
  pld.bind_group_layouts = Some(bind_group_layouts)
  let pipeline_layout = device.create_pipeline_layout(pld)
  pld.reset()
  let rpd = _web_gpu_pipeline_utils_render_pipeline_descriptor
  let material_name = if material.name != "" {
    material.name
  } else {
    material.type_
  }
  rpd.label = Some("renderPipeline_\{material_name}_\{material.id}")
  rpd.vertex = Some(
    @gpu.GPUVertexState::new(
      module_=vertex_module.module_,
      entry_point=vertex_module.entry_point,
      buffers=vertex_buffers,
    ),
  )
  rpd.fragment = Some(
    @gpu.GPUFragmentState::new(
      module_=fragment_module.module_,
      entry_point=fragment_module.entry_point,
      targets~,
    ),
  )
  rpd.primitive = Some(primitive_state)
  let multisample = rpd.multisample.unwrap()
  multisample.count = Some(sample_count)
  multisample.alpha_to_coverage_enabled = Some(
    material.alpha_to_coverage && sample_count > 1,
  )
  rpd.layout = Some(Layout(pipeline_layout))
  let depth_stencil = @gpu.GPUDepthStencilState::new()
  let render_depth = render_object.context.depth
  let render_stencil = render_object.context.stencil
  if render_depth == true || render_stencil == true {
    if render_depth == true {
      depth_stencil.format = depth_stencil_format
      depth_stencil.depth_write_enabled = Some(material.depth_write)
      depth_stencil.depth_compare = depth_compare
    }
    if render_stencil == true {
      depth_stencil.stencil_front = Some(stencil_front)
      depth_stencil.stencil_back = Some(stencil_front) // apply the same stencil ops to both faces, matching gl.stencilOp() which is not face-separated
      depth_stencil.stencil_read_mask = Some(material.stencil_func_mask)
      depth_stencil.stencil_write_mask = Some(material.stencil_write_mask)
    }
    if material.polygon_offset == true &&
      primitive_state.topology == Some(GPUPrimitiveTopology_TriangleList) {
      let reversed = wgpu_truthy(
        backend.base().parameters.get("reversedDepthBuffer"),
      )
      depth_stencil.depth_bias = Some(
        (if reversed {
          -material.polygon_offset_units
        } else {
          material.polygon_offset_units
        }).to_int(),
      )
      depth_stencil.depth_bias_slope_scale = Some(
        if reversed {
          -material.polygon_offset_factor
        } else {
          material.polygon_offset_factor
        },
      )
      depth_stencil.depth_bias_clamp = Some(0.0) // three.js does not provide an API to configure this value
    }
    rpd.depth_stencil = Some(depth_stencil)
  }
  // create pipeline
  device.push_error_scope("validation")
  let stages = [
    { program: vertex_program, module_: vertex_module.module_, },
    { program: fragment_program, module_: fragment_module.module_, },
  ]
  let pipeline_label = rpd.label.unwrap()
  match promises {
    None => {
      pipeline_data.set(
        "pipeline",
        @core.JsValue::of(device.create_render_pipeline(rpd)),
      )
      rpd.reset()
      device.pop_error_scope(fn(err) {
        match err {
          Some(err) => {
            pipeline_data.set("error", @core.JsValue::of(true))
            @core.error(
              "WebGPURenderer: Render pipeline creation failed (\{pipeline_label}): \{err.message()}",
            )
            self._report_shader_diagnostics(stages, pipeline_label, fn() {  })
          }
          None => ()
        }
      })
    }
    Some(promises) => {
      let p = wgpu_new_promise(fn(resolve) {
        let pipeline_promise = device.create_render_pipeline_async_promise(rpd)
        rpd.reset()
        // Pop the error scope before awaiting the pipeline, so several pipelines
        // can be created at the same time without mixing their error scopes.
        let error_scope_promise = device.pop_error_scope_promise()
        let async_error : Ref[String?] = Ref(None)
        let after_pipeline = fn() {
          wgpu_await(
            error_scope_promise,
            fn(error_scope) {
              let error_scope : @gpu.GPUError? = if error_scope.is_null() {
                None
              } else {
                Some(error_scope.cast())
              }
              if error_scope is Some(_) || async_error.val is Some(_) {
                pipeline_data.set("error", @core.JsValue::of(true))
                let reason = match error_scope {
                  Some(e) if e.message() != "" => e.message()
                  _ =>
                    match async_error.val {
                      Some(m) if m != "" => m
                      _ => "unknown"
                    }
                }
                @core.error(
                  "WebGPURenderer: Async render pipeline creation failed (\{pipeline_label}): \{reason}",
                )
                self._report_shader_diagnostics(stages, pipeline_label, resolve)
              } else {
                resolve()
              }
            },
            fn(_) { resolve() },
          )
        }
        wgpu_await(
          pipeline_promise,
          fn(v) {
            pipeline_data.set("pipeline", v)
            after_pipeline()
          },
          fn(err) {
            async_error.val = Some(wgpu_error_string(err))
            after_pipeline()
          },
        )
      })
      promises.push(p)
    }
  }
}

///|
/// `createBundleEncoder( renderContext, label = 'renderBundleEncoder' )`.
pub fn WebGPUPipelineUtils::create_bundle_encoder(
  self : WebGPUPipelineUtils,
  render_context : @nodes.RenderContext,
  label~ : String = "renderBundleEncoder",
) -> @gpu.GPURenderBundleEncoder {
  let backend = self.backend()
  let utils = backend.utils
  let device = backend.gpu_device()
  let depth_stencil_format = utils.get_current_depth_stencil_format(
    render_context,
  )
  let color_formats = utils.get_current_color_formats(render_context)
  let sample_count = self._get_sample_count(render_context)
  let rbd = _web_gpu_pipeline_utils_render_bundle_encoder_descriptor
  rbd.label = Some(label)
  rbd.color_formats = Some(
    color_formats.map(fn(f) { f.unwrap_or("undefined") }),
  )
  rbd.depth_stencil_format = depth_stencil_format
  rbd.sample_count = Some(sample_count)
  let bundle_encoder = device.create_render_bundle_encoder(rbd)
  rbd.reset()
  bundle_encoder
}

///|
/// `createComputePipeline( pipeline, bindings, promises = null )`.
pub fn WebGPUPipelineUtils::create_compute_pipeline(
  self : WebGPUPipelineUtils,
  pipeline : @nodes.Pipeline,
  bindings : Array[@nodes.BindGroup],
  promises : Array[@core.JsValue]?,
) -> Unit {
  let backend = self.backend()
  let device = backend.gpu_device()
  let compute_stage = pipeline.compute_program()
  let compute_program = wgpu_program_module(backend, compute_stage)
  let pipeline_gpu = backend.get(@core.JsValue::of(pipeline))
  // bind group layouts
  let bind_group_layouts = []
  for bindings_group in bindings {
    let bindings_data = backend.get(@core.JsValue::of(bindings_group))
    let layout : WebGPUBindGroupLayout = bindings_data.get("layout").cast()
    bind_group_layouts.push(layout.layout_gpu)
  }
  let pipeline_label = "computePipeline_\{compute_stage.stage}" +
    (if compute_stage.name != "" { "_\{compute_stage.name}" } else { "" })
  device.push_error_scope("validation")
  let pld = _web_gpu_pipeline_utils_pipeline_layout_descriptor
  pld.bind_group_layouts = Some(bind_group_layouts)
  let pipeline_layout = device.create_pipeline_layout(pld)
  pld.reset()
  let cpd = _web_gpu_pipeline_utils_compute_pipeline_descriptor
  cpd.label = Some(pipeline_label)
  cpd.compute = Some(
    @gpu.GPUProgrammableStage::new(
      module_=compute_program.module_,
      entry_point=compute_program.entry_point,
    ),
  )
  cpd.layout = Some(Layout(pipeline_layout))
  let stages = [{ program: compute_stage, module_: compute_program.module_, }]
  match promises {
    None => {
      pipeline_gpu.set(
        "pipeline",
        @core.JsValue::of(device.create_compute_pipeline(cpd)),
      )
      cpd.reset()
      device.pop_error_scope(fn(err) {
        match err {
          Some(err) => {
            pipeline_gpu.set("error", @core.JsValue::of(true))
            @core.error(
              "WebGPURenderer: Compute pipeline creation failed (\{pipeline_label}): \{err.message()}",
            )
            self._report_shader_diagnostics(stages, pipeline_label, fn() {  })
          }
          None => ()
        }
      })
    }
    Some(promises) => {
      let promise = wgpu_new_promise(fn(resolve) {
        let pipeline_promise = device.create_compute_pipeline_async_promise(cpd)
        cpd.reset()
        // Pop the error scope before awaiting the pipeline, so several pipelines
        // can be created at the same time without mixing their error scopes.
        let error_scope_promise = device.pop_error_scope_promise()
        let async_error : Ref[String?] = Ref(None)
        let after_pipeline = fn() {
          wgpu_await(
            error_scope_promise,
            fn(error_scope) {
              let error_scope : @gpu.GPUError? = if error_scope.is_null() {
                None
              } else {
                Some(error_scope.cast())
              }
              if error_scope is Some(_) || async_error.val is Some(_) {
                pipeline_gpu.set("error", @core.JsValue::of(true))
                let reason = match error_scope {
                  Some(e) if e.message() != "" => e.message()
                  _ =>
                    match async_error.val {
                      Some(m) if m != "" => m
                      _ => "unknown"
                    }
                }
                @core.error(
                  "WebGPURenderer: Async compute pipeline creation failed (\{pipeline_label}): \{reason}",
                )
                self._report_shader_diagnostics(stages, pipeline_label, resolve)
              } else {
                resolve()
              }
            },
            fn(_) { resolve() },
          )
        }
        wgpu_await(
          pipeline_promise,
          fn(v) {
            pipeline_gpu.set("pipeline", v)
            after_pipeline()
          },
          fn(err) {
            async_error.val = Some(wgpu_error_string(err))
            after_pipeline()
          },
        )
      })
      promises.push(promise)
    }
  }
}

///|
/// `async _reportShaderDiagnostics( stages, pipelineLabel )`.
fn WebGPUPipelineUtils::_report_shader_diagnostics(
  self : WebGPUPipelineUtils,
  stages : Array[WebGPUShaderStageInfo],
  pipeline_label : String,
  on_done : () -> Unit,
) -> Unit {
  ignore(self)
  fn next(i : Int32) -> Unit {
    if i >= stages.length() {
      return on_done()
    }
    let { program, module_, } = stages[i]
    wgpu_await(
      module_.get_compilation_info_promise(),
      fn(info_value) {
        let info : @gpu.GPUCompilationInfo = info_value.cast()
        let messages = info.messages()
        if messages.length() == 0 {
          return next(i + 1)
        }
        let source_lines = program.code
          .split("\n")
          .map(fn(s) { s.to_owned() })
          .to_array()
        for msg in messages {
          let line_num = msg.line_num()
          let line_pos = msg.line_pos()
          let location = if line_num > 0 {
            " at line \{line_num}" +
            (if line_pos > 0 { ":\{line_pos}" } else { "" })
          } else {
            ""
          }
          let header = "WebGPURenderer [\{pipeline_label} / \{program.stage} \{msg.type_()}]\{location}: \{msg.message()}"
          let mut excerpt = ""
          if line_num > 0 && line_num <= source_lines.length() {
            excerpt = "\n  \{source_lines[line_num - 1]}"
            if line_pos > 0 {
              excerpt = excerpt + "\n  " + " ".repeat(line_pos - 1) + "^"
            }
          }
          if msg.type_() == "error" {
            @core.error(header + excerpt)
          } else {
            @core.warn(header + excerpt)
          }
        }
        next(i + 1)
      },
      fn(_) { on_done() },
    )
  }

  next(0)
}

///|
/// `_getBlending( object )`; `None` is `undefined` (invalid blending).
fn WebGPUPipelineUtils::_get_blending(
  self : WebGPUPipelineUtils,
  object : WebGPUBlendSource,
) -> @gpu.GPUBlendState? {
  let mut color = None
  let mut alpha = None
  let blending = object.blending
  let blend_src = object.blend_src
  let blend_dst = object.blend_dst
  let blend_equation = object.blend_equation
  if blending == @core.CustomBlending {
    let blend_src_alpha = object.blend_src_alpha.unwrap_or(blend_src)
    let blend_dst_alpha = object.blend_dst_alpha.unwrap_or(blend_dst)
    let blend_equation_alpha = object.blend_equation_alpha.unwrap_or(
      blend_equation,
    )
    color = Some(
      @gpu.GPUBlendComponent::new(
        src_factor?=self._get_blend_factor(blend_src),
        dst_factor?=self._get_blend_factor(blend_dst),
        operation?=self._get_blend_operation(blend_equation),
      ),
    )
    alpha = Some(
      @gpu.GPUBlendComponent::new(
        src_factor?=self._get_blend_factor(blend_src_alpha),
        dst_factor?=self._get_blend_factor(blend_dst_alpha),
        operation?=self._get_blend_operation(blend_equation_alpha),
      ),
    )
  } else {
    let premultiplied_alpha = object.premultiplied_alpha
    let set_blend = fn(
      src_rgb : String,
      dst_rgb : String,
      src_alpha : String,
      dst_alpha : String,
    ) {
      color = Some(
        @gpu.GPUBlendComponent::new(
          src_factor=src_rgb,
          dst_factor=dst_rgb,
          operation=GPUBlendOperation_Add,
        ),
      )
      alpha = Some(
        @gpu.GPUBlendComponent::new(
          src_factor=src_alpha,
          dst_factor=dst_alpha,
          operation=GPUBlendOperation_Add,
        ),
      )
    }
    if premultiplied_alpha {
      if blending == @core.NormalBlending {
        set_blend(
          GPUBlendFactor_One,
          GPUBlendFactor_OneMinusSrcAlpha,
          GPUBlendFactor_One,
          GPUBlendFactor_OneMinusSrcAlpha,
        )
      } else if blending == @core.AdditiveBlending {
        set_blend(
          GPUBlendFactor_One,
          GPUBlendFactor_One,
          GPUBlendFactor_One,
          GPUBlendFactor_One,
        )
      } else if blending == @core.SubtractiveBlending {
        set_blend(
          GPUBlendFactor_Zero,
          GPUBlendFactor_OneMinusSrc,
          GPUBlendFactor_Zero,
          GPUBlendFactor_One,
        )
      } else if blending == @core.MultiplyBlending {
        set_blend(
          GPUBlendFactor_Dst,
          GPUBlendFactor_OneMinusSrcAlpha,
          GPUBlendFactor_Zero,
          GPUBlendFactor_One,
        )
      }
    } else {
      let what = if object.is_material { "material" } else { "blendMode" }
      if blending == @core.NormalBlending {
        set_blend(
          GPUBlendFactor_SrcAlpha,
          GPUBlendFactor_OneMinusSrcAlpha,
          GPUBlendFactor_One,
          GPUBlendFactor_OneMinusSrcAlpha,
        )
      } else if blending == @core.AdditiveBlending {
        set_blend(
          GPUBlendFactor_SrcAlpha,
          GPUBlendFactor_One,
          GPUBlendFactor_One,
          GPUBlendFactor_One,
        )
      } else if blending == @core.SubtractiveBlending {
        @core.error(
          "WebGPURenderer: \"SubtractiveBlending\" requires \"\{what}.premultipliedAlpha = true\".",
        )
      } else if blending == @core.MultiplyBlending {
        @core.error(
          "WebGPURenderer: \"MultiplyBlending\" requires \"\{what}.premultipliedAlpha = true\".",
        )
      }
    }
  }
  match (color, alpha) {
    (Some(color), Some(alpha)) => Some(@gpu.GPUBlendState::new(color~, alpha~))
    _ => {
      @core.error("WebGPURenderer: Invalid blending:  \{blending}")
      None
    }
  }
}

///|
/// `_getBlendFactor( blend )`; `None` is `undefined`.
fn WebGPUPipelineUtils::_get_blend_factor(
  self : WebGPUPipelineUtils,
  blend : Int32,
) -> String? {
  ignore(self)
  match blend {
    @core.ZeroFactor => Some(GPUBlendFactor_Zero)
    @core.OneFactor => Some(GPUBlendFactor_One)
    @core.SrcColorFactor => Some(GPUBlendFactor_Src)
    @core.OneMinusSrcColorFactor => Some(GPUBlendFactor_OneMinusSrc)
    @core.SrcAlphaFactor => Some(GPUBlendFactor_SrcAlpha)
    @core.OneMinusSrcAlphaFactor => Some(GPUBlendFactor_OneMinusSrcAlpha)
    @core.DstColorFactor => Some(GPUBlendFactor_Dst)
    @core.OneMinusDstColorFactor => Some(GPUBlendFactor_OneMinusDst)
    @core.DstAlphaFactor => Some(GPUBlendFactor_DstAlpha)
    @core.OneMinusDstAlphaFactor => Some(GPUBlendFactor_OneMinusDstAlpha)
    @core.SrcAlphaSaturateFactor => Some(GPUBlendFactor_SrcAlphaSaturated)
    // WebGPU has no dedicated constant alpha blend factors
    @core.ConstantColorFactor | @core.ConstantAlphaFactor =>
      Some(GPUBlendFactor_Constant)
    // WebGPU has no dedicated constant alpha blend factors
    @core.OneMinusConstantColorFactor | @core.OneMinusConstantAlphaFactor =>
      Some(GPUBlendFactor_OneMinusConstant)
    _ => {
      @core.error("WebGPURenderer: Blend factor not supported. \{blend}")
      None
    }
  }
}

///|
/// `_getStencilCompare( material )`; `None` is `undefined`.
fn WebGPUPipelineUtils::_get_stencil_compare(
  self : WebGPUPipelineUtils,
  material : @core.Material,
) -> String? {
  ignore(self)
  let stencil_func = material.stencil_func
  match stencil_func {
    @core.NeverStencilFunc => Some(GPUCompareFunction_Never)
    @core.AlwaysStencilFunc => Some(GPUCompareFunction_Always)
    @core.LessStencilFunc => Some(GPUCompareFunction_Less)
    @core.LessEqualStencilFunc => Some(GPUCompareFunction_LessEqual)
    @core.EqualStencilFunc => Some(GPUCompareFunction_Equal)
    @core.GreaterEqualStencilFunc => Some(GPUCompareFunction_GreaterEqual)
    @core.GreaterStencilFunc => Some(GPUCompareFunction_Greater)
    @core.NotEqualStencilFunc => Some(GPUCompareFunction_NotEqual)
    _ => {
      @core.error("WebGPURenderer: Invalid stencil function. \{stencil_func}")
      None
    }
  }
}

///|
/// `_getStencilOperation( op )`; `None` is `undefined`.
fn WebGPUPipelineUtils::_get_stencil_operation(
  self : WebGPUPipelineUtils,
  op : Int32,
) -> String? {
  ignore(self)
  match op {
    @core.KeepStencilOp => Some(GPUStencilOperation_Keep)
    @core.ZeroStencilOp => Some(GPUStencilOperation_Zero)
    @core.ReplaceStencilOp => Some(GPUStencilOperation_Replace)
    @core.InvertStencilOp => Some(GPUStencilOperation_Invert)
    @core.IncrementStencilOp => Some(GPUStencilOperation_IncrementClamp)
    @core.DecrementStencilOp => Some(GPUStencilOperation_DecrementClamp)
    @core.IncrementWrapStencilOp => Some(GPUStencilOperation_IncrementWrap)
    @core.DecrementWrapStencilOp => Some(GPUStencilOperation_DecrementWrap)
    _ => {
      @core.error("WebGPURenderer: Invalid stencil operation. undefined")
      None
    }
  }
}

///|
/// `_getBlendOperation( blendEquation )`; `None` is `undefined`.
fn WebGPUPipelineUtils::_get_blend_operation(
  self : WebGPUPipelineUtils,
  blend_equation : Int32,
) -> String? {
  ignore(self)
  match blend_equation {
    @core.AddEquation => Some(GPUBlendOperation_Add)
    @core.SubtractEquation => Some(GPUBlendOperation_Subtract)
    @core.ReverseSubtractEquation => Some(GPUBlendOperation_ReverseSubtract)
    @core.MinEquation => Some(GPUBlendOperation_Min)
    @core.MaxEquation => Some(GPUBlendOperation_Max)
    _ => {
      @core.error(
        "WebGPUPipelineUtils: Blend equation not supported. \{blend_equation}",
      )
      None
    }
  }
}

///|
/// `_getPrimitiveState( object, geometry, material )`.
fn WebGPUPipelineUtils::_get_primitive_state(
  self : WebGPUPipelineUtils,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  material : @core.Material,
) -> @gpu.GPUPrimitiveState {
  let descriptor = @gpu.GPUPrimitiveState::new()
  let utils = self.backend().utils
  //
  descriptor.topology = utils.get_primitive_topology(object, material)
  descriptor.strip_index_format = utils.get_strip_index_format(object, geometry)
  //
  let mut flip_sided = material.side == @core.BackSide
  if object.is_mesh() && object.matrix_world.determinant_affine() < 0.0 {
    flip_sided = !flip_sided
  }
  descriptor.front_face = Some(
    if flip_sided == true {
      GPUFrontFace_CW
    } else {
      GPUFrontFace_CCW
    },
  )
  //
  descriptor.cull_mode = Some(
    if material.side == @core.DoubleSide {
      GPUCullMode_None
    } else {
      GPUCullMode_Back
    },
  )
  descriptor
}

///|
/// `_getColorWriteMask( material )`.
fn WebGPUPipelineUtils::_get_color_write_mask(
  self : WebGPUPipelineUtils,
  material : @core.Material,
) -> Int32 {
  ignore(self)
  if material.color_write == true {
    GPUColorWriteFlags_All
  } else {
    GPUColorWriteFlags_None
  }
}

///|
/// `_getDepthCompare( material )`; `None` is `undefined`.
fn WebGPUPipelineUtils::_get_depth_compare(
  self : WebGPUPipelineUtils,
  material : @core.Material,
) -> String? {
  if material.depth_test == false {
    return Some(GPUCompareFunction_Always)
  }
  let depth_func = if wgpu_truthy(
      self.backend().base().parameters.get("reversedDepthBuffer"),
    ) {
    wgpu_reversed_depth_func(material.depth_func)
  } else {
    Some(material.depth_func)
  }
  match depth_func {
    Some(@core.NeverDepth) => Some(GPUCompareFunction_Never)
    Some(@core.AlwaysDepth) => Some(GPUCompareFunction_Always)
    Some(@core.LessDepth) => Some(GPUCompareFunction_Less)
    Some(@core.LessEqualDepth) => Some(GPUCompareFunction_LessEqual)
    Some(@core.EqualDepth) => Some(GPUCompareFunction_Equal)
    Some(@core.GreaterEqualDepth) => Some(GPUCompareFunction_GreaterEqual)
    Some(@core.GreaterDepth) => Some(GPUCompareFunction_Greater)
    Some(@core.NotEqualDepth) => Some(GPUCompareFunction_NotEqual)
    _ => {
      @core.error(
        "WebGPUPipelineUtils: Invalid depth function. \{match depth_func { Some(f) => f.to_string(); None => "undefined" }}",
      )
      None
    }
  }
}
