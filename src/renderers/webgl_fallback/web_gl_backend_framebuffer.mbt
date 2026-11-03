// WebGLBackend.js: `_setFramebuffer`, `_resolveRenderTarget`, `_useMultisampledExtension`.
//
// The `descriptor` of `_setFramebuffer` is the render context, or a render target's
// record when the renderer copies outside a render pass (`FramebufferSource`); a record
// has no `activeCubeFace`/`activeMipmapLevel`/`width`/`height`, which read as 0 here
// (upstream: `undefined`).

///|
let _web_gl_backend_invalidation_array : Array[Int32] = []

///|
/// The fields `_setFramebuffer` reads from its descriptor.
priv struct WebGLFramebufferDescriptor {
  textures : Array[@core.Texture]?
  render_target : @core.RenderTarget?
  depth_texture : @core.Texture?
  active_cube_face : Int32
  active_mipmap_level : Int32
  width : Int32
  height : Int32
  context : @nodes.RenderContext?
}

///|
fn _wgl_descriptor(
  source : @nodes.FramebufferSource,
) -> WebGLFramebufferDescriptor {
  match source {
    Context(rc) =>
      {
        textures: rc.textures,
        render_target: rc.render_target,
        depth_texture: rc.depth_texture,
        active_cube_face: rc.active_cube_face,
        active_mipmap_level: rc.active_mipmap_level,
        width: rc.width,
        height: rc.height,
        context: Some(rc),
      }
    TargetData(data) =>
      {
        textures: data.textures,
        render_target: data.render_target,
        depth_texture: data.depth_texture,
        active_cube_face: 0,
        active_mipmap_level: 0,
        width: data.width.unwrap_or(0),
        height: data.height.unwrap_or(0),
        context: None,
      }
    NoContext =>
      abort("TypeError: Cannot read properties of null (reading 'textures')")
  }
}

///|
/// `getCacheKey( descriptor )` (renderers/common/RenderContext.js).
fn _wgl_descriptor_cache_key(d : WebGLFramebufferDescriptor) -> Double {
  match d.context {
    Some(rc) => @nodes.get_cache_key(rc)
    None => {
      let values = [
        d.active_cube_face.to_double(),
        d.active_mipmap_level.to_double(),
      ]
      for texture in d.textures.unwrap_or([]) {
        values.push(texture.id.to_double())
      }
      match d.depth_texture {
        Some(t) => values.push(t.id.to_double())
        None => ()
      }
      @nodes.hash_array(values)
    }
  }
}

///|
extern "js" fn _wgl_get_num(o : @core.JsValue, key : Double) -> @core.JsValue = "(o, k) => o[ k ]"

///|
extern "js" fn _wgl_set_num(
  o : @core.JsValue,
  key : Double,
  v : @core.JsValue,
) -> Unit = "(o, k, v) => { o[ k ] = v; }"

///|
/// `_setFramebuffer( descriptor )`: binds (creating when needed) the framebuffer of a
/// render context or render target record.
pub fn WebGLBackend::_set_framebuffer(
  self : WebGLBackend,
  source : @nodes.FramebufferSource,
) -> Unit {
  let gl = self.gl.unwrap()
  let state = self.state.unwrap()
  let mut current_frame_buffer : @webgl.GLFramebuffer? = None
  let descriptor = _wgl_descriptor(source)
  if descriptor.textures is Some(textures) {
    let render_target = match descriptor.render_target {
      Some(rt) => rt
      None =>
        abort(
          "TypeError: Cannot read properties of null (reading 'depthBuffer')",
        )
    }
    let render_target_context_data = self.get(@core.JsValue::of(render_target))
    let depth_buffer = render_target.depth_buffer
    let stencil_buffer = render_target.stencil_buffer
    let is_cube = render_target.has_extension_flag("isCubeRenderTarget")
    let is_xr_render_target = @nodes.is_xr_render_target(render_target)
    let props = @nodes.render_target_props(render_target)
    let _has_external_textures = is_xr_render_target == true &&
      props._has_external_textures == Some(true)
    let mut msaa_fb : @webgl.GLFramebuffer? = _wgl_handle(
      render_target_context_data.get("msaaFrameBuffer"),
    )
    let mut depth_renderbuffer = render_target_context_data.get(
      "depthRenderbuffer",
    )
    let extensions = self.extensions.unwrap()
    let multisampled_rtt_ext = extensions.get(
      "WEBGL_multisampled_render_to_texture",
    )
    let multiview_ext = extensions.get("OVR_multiview2")
    let use_multisampled_rtt = self._use_multisampled_extension(render_target)
    let mut samples = render_target.samples
    match descriptor.depth_texture {
      Some(depth_texture) if !(match depth_texture.render_target {
          Some(rt) => physical_equal(rt, render_target)
          None => false
        }) &&
        use_multisampled_rtt == false =>
        if samples > 0 {
          @core.warn_once(
            "WebGLBackend: Shared depth texture is not supported with MSAA when \"WEBGL_multisampled_render_to_texture\" is unsupported. Falling back to single-sample rendering.",
          )
          samples = 0
        }
      _ => ()
    }
    let cache_key = _wgl_descriptor_cache_key(descriptor)
    let mut fb : @webgl.GLFramebuffer? = None
    let mut fb_undefined = false
    if is_cube {
      if !_wgl_truthy(render_target_context_data.get("cubeFramebuffers")) {
        render_target_context_data.set(
          "cubeFramebuffers",
          @core.JsValue::object(),
        )
      }
      let v = _wgl_get_num(
        render_target_context_data.get("cubeFramebuffers"),
        cache_key,
      )
      fb_undefined = v.is_undefined()
      fb = _wgl_handle(v)
    } else if is_xr_render_target && _has_external_textures == false {
      fb = self._xr_framebuffer
      fb_undefined = false
    } else {
      if !_wgl_truthy(render_target_context_data.get("framebuffers")) {
        render_target_context_data.set("framebuffers", @core.JsValue::object())
      }
      let v = _wgl_get_num(
        render_target_context_data.get("framebuffers"),
        cache_key,
      )
      fb_undefined = v.is_undefined()
      fb = _wgl_handle(v)
    }
    let multiview_attach = fn(attachment : Int32, texture_gpu : @core.JsValue) {
      match multiview_ext {
        Some(ext) =>
          ext.framebuffer_texture_multisample_multiview_ovr(
            @webgl.GL_FRAMEBUFFER,
            attachment,
            _wgl_handle(texture_gpu),
            0,
            samples,
            0,
            2,
          )
        None =>
          abort(
            "TypeError: Cannot read properties of null (reading 'framebufferTextureMultisampleMultiviewOVR')",
          )
      }
    }
    let rtt_attach = fn(attachment : Int32, texture_gpu : @core.JsValue) {
      match multisampled_rtt_ext {
        Some(ext) =>
          ext.framebuffer_texture2d_multisample_ext(
            @webgl.GL_FRAMEBUFFER,
            attachment,
            @webgl.GL_TEXTURE_2D,
            _wgl_handle(texture_gpu),
            0,
            samples,
          )
        None =>
          abort(
            "TypeError: Cannot read properties of null (reading 'framebufferTexture2DMultisampleEXT')",
          )
      }
    }
    if fb_undefined {
      let new_fb = gl.create_framebuffer()
      fb = Some(new_fb)
      state.bind_framebuffer(@webgl.GL_FRAMEBUFFER, fb) |> ignore
      let depth_invalidation_array : Array[Int32] = []
      if is_cube {
        _wgl_set_num(
          render_target_context_data.get("cubeFramebuffers"),
          cache_key,
          @core.JsValue::of(new_fb),
        )
        let texture_gpu = self
          .get(@core.JsValue::of(textures[0]))
          .get("textureGPU")
        let cube_face = descriptor.active_cube_face
        let mip_level = descriptor.active_mipmap_level
        gl.framebuffer_texture2d(
          @webgl.GL_FRAMEBUFFER,
          @webgl.GL_COLOR_ATTACHMENT0,
          @webgl.GL_TEXTURE_CUBE_MAP_POSITIVE_X + cube_face,
          _wgl_handle(texture_gpu),
          mip_level,
        )
      } else {
        _wgl_set_num(
          render_target_context_data.get("framebuffers"),
          cache_key,
          @core.JsValue::of(new_fb),
        )
        for i, texture in textures {
          let texture_data = self.get(@core.JsValue::of(texture))
          let attachment = @webgl.GL_COLOR_ATTACHMENT0 + i
          let gl_texture_type = _wgl_record_int(texture_data, "glTextureType")
          if render_target.multiview {
            multiview_attach(attachment, texture_data.get("textureGPU"))
          } else if gl_texture_type == @webgl.GL_TEXTURE_2D_ARRAY ||
            gl_texture_type == @webgl.GL_TEXTURE_3D {
            let layer = descriptor.active_cube_face
            let mip_level = descriptor.active_mipmap_level
            gl.framebuffer_texture_layer(
              @webgl.GL_FRAMEBUFFER,
              attachment,
              _wgl_handle(texture_data.get("textureGPU")),
              mip_level,
              layer,
            )
          } else if use_multisampled_rtt {
            rtt_attach(attachment, texture_data.get("textureGPU"))
          } else {
            let mip_level = descriptor.active_mipmap_level
            gl.framebuffer_texture2d(
              @webgl.GL_FRAMEBUFFER,
              attachment,
              @webgl.GL_TEXTURE_2D,
              _wgl_handle(texture_data.get("textureGPU")),
              mip_level,
            )
          }
        }
      }
      let depth_style = if stencil_buffer {
        @webgl.GL_DEPTH_STENCIL_ATTACHMENT
      } else {
        @webgl.GL_DEPTH_ATTACHMENT
      }
      if props._auto_allocate_depth_buffer == Some(true) {
        let renderbuffer = gl.create_renderbuffer()
        self.texture_utils
        .unwrap()
        .setup_render_buffer_storage(
          renderbuffer,
          source,
          0,
          use_multisampled_rtt~,
        )
        render_target_context_data.set(
          "xrDepthRenderbuffer",
          @core.JsValue::of(renderbuffer),
        )
        depth_invalidation_array.push(
          if stencil_buffer {
            @webgl.GL_DEPTH_STENCIL_ATTACHMENT
          } else {
            @webgl.GL_DEPTH_ATTACHMENT
          },
        )
        gl.bind_renderbuffer(@webgl.GL_RENDERBUFFER, Some(renderbuffer))
        gl.framebuffer_renderbuffer(
          @webgl.GL_FRAMEBUFFER,
          depth_style,
          @webgl.GL_RENDERBUFFER,
          Some(renderbuffer),
        )
      } else {
        match descriptor.depth_texture {
          Some(depth_texture) => {
            depth_invalidation_array.push(
              if stencil_buffer {
                @webgl.GL_DEPTH_STENCIL_ATTACHMENT
              } else {
                @webgl.GL_DEPTH_ATTACHMENT
              },
            )
            let texture_data = self.get(@core.JsValue::of(depth_texture))
            if render_target.multiview {
              multiview_attach(depth_style, texture_data.get("textureGPU"))
            } else if _has_external_textures && use_multisampled_rtt {
              rtt_attach(depth_style, texture_data.get("textureGPU"))
            } else if depth_texture.is_array_texture {
              let layer = descriptor.active_cube_face
              gl.framebuffer_texture_layer(
                @webgl.GL_FRAMEBUFFER,
                depth_style,
                _wgl_handle(texture_data.get("textureGPU")),
                0,
                layer,
              )
            } else if depth_texture.is_cube_texture() {
              let cube_face = descriptor.active_cube_face
              gl.framebuffer_texture2d(
                @webgl.GL_FRAMEBUFFER,
                depth_style,
                @webgl.GL_TEXTURE_CUBE_MAP_POSITIVE_X + cube_face,
                _wgl_handle(texture_data.get("textureGPU")),
                0,
              )
            } else {
              gl.framebuffer_texture2d(
                @webgl.GL_FRAMEBUFFER,
                depth_style,
                @webgl.GL_TEXTURE_2D,
                _wgl_handle(texture_data.get("textureGPU")),
                0,
              )
            }
          }
          None => ()
        }
      }
      render_target_context_data.set(
        "depthInvalidationArray",
        @core.JsValue::of(FixedArray::from_array(depth_invalidation_array)),
      )
    } else {
      let is_render_camera_depth_array = match descriptor.context {
        Some(rc) => self._is_render_camera_depth_array(rc)
        None => false
      }
      if is_render_camera_depth_array {
        state.bind_framebuffer(@webgl.GL_FRAMEBUFFER, fb) |> ignore
        let layer = descriptor.active_cube_face
        let depth_data = self.get(_wgl_js(descriptor.depth_texture))
        let depth_style = if stencil_buffer {
          @webgl.GL_DEPTH_STENCIL_ATTACHMENT
        } else {
          @webgl.GL_DEPTH_ATTACHMENT
        }
        gl.framebuffer_texture_layer(
          @webgl.GL_FRAMEBUFFER,
          depth_style,
          _wgl_handle(depth_data.get("textureGPU")),
          0,
          layer,
        )
      }
      // rebind external XR textures
      if (
          is_xr_render_target || use_multisampled_rtt || render_target.multiview
        ) &&
        props._is_opaque_framebuffer != Some(true) {
        state.bind_framebuffer(@webgl.GL_FRAMEBUFFER, fb) |> ignore
        // rebind color
        if textures.length() > 0 {
          let texture_data = self.get(@core.JsValue::of(textures[0]))
          if render_target.multiview {
            multiview_attach(
              @webgl.GL_COLOR_ATTACHMENT0,
              texture_data.get("textureGPU"),
            )
          } else if use_multisampled_rtt {
            rtt_attach(
              @webgl.GL_COLOR_ATTACHMENT0,
              texture_data.get("textureGPU"),
            )
          } else {
            gl.framebuffer_texture2d(
              @webgl.GL_FRAMEBUFFER,
              @webgl.GL_COLOR_ATTACHMENT0,
              @webgl.GL_TEXTURE_2D,
              _wgl_handle(texture_data.get("textureGPU")),
              0,
            )
          }
        }
        // rebind depth
        let depth_style = if stencil_buffer {
          @webgl.GL_DEPTH_STENCIL_ATTACHMENT
        } else {
          @webgl.GL_DEPTH_ATTACHMENT
        }
        if props._auto_allocate_depth_buffer == Some(true) {
          let renderbuffer : @webgl.GLRenderbuffer? = _wgl_handle(
            render_target_context_data.get("xrDepthRenderbuffer"),
          )
          gl.bind_renderbuffer(@webgl.GL_RENDERBUFFER, renderbuffer)
          gl.framebuffer_renderbuffer(
            @webgl.GL_FRAMEBUFFER,
            depth_style,
            @webgl.GL_RENDERBUFFER,
            renderbuffer,
          )
        } else {
          let texture_data = self.get(_wgl_js(descriptor.depth_texture))
          if render_target.multiview {
            multiview_attach(depth_style, texture_data.get("textureGPU"))
          } else if use_multisampled_rtt {
            rtt_attach(depth_style, texture_data.get("textureGPU"))
          } else {
            gl.framebuffer_texture2d(
              @webgl.GL_FRAMEBUFFER,
              depth_style,
              @webgl.GL_TEXTURE_2D,
              _wgl_handle(texture_data.get("textureGPU")),
              0,
            )
          }
        }
      }
    }
    if samples > 0 && use_multisampled_rtt == false && !render_target.multiview {
      if msaa_fb is None {
        let new_msaa_fb = gl.create_framebuffer()
        msaa_fb = Some(new_msaa_fb)
        state.bind_framebuffer(@webgl.GL_FRAMEBUFFER, msaa_fb) |> ignore
        let msaa_renderbuffers : Array[@webgl.GLRenderbuffer] = []
        for i, texture in textures {
          let renderbuffer = gl.create_renderbuffer()
          msaa_renderbuffers.push(renderbuffer)
          gl.bind_renderbuffer(@webgl.GL_RENDERBUFFER, Some(renderbuffer))
          let texture_data = self.get(@core.JsValue::of(texture))
          gl.renderbuffer_storage_multisample(
            @webgl.GL_RENDERBUFFER,
            samples,
            _wgl_record_int(texture_data, "glInternalFormat"),
            descriptor.width,
            descriptor.height,
          )
          gl.framebuffer_renderbuffer(
            @webgl.GL_FRAMEBUFFER,
            @webgl.GL_COLOR_ATTACHMENT0 + i,
            @webgl.GL_RENDERBUFFER,
            Some(renderbuffer),
          )
        }
        gl.bind_renderbuffer(@webgl.GL_RENDERBUFFER, None)
        render_target_context_data.set(
          "msaaFrameBuffer",
          @core.JsValue::of(new_msaa_fb),
        )
        render_target_context_data.set(
          "msaaRenderbuffers",
          @core.JsValue::of(FixedArray::from_array(msaa_renderbuffers)),
        )
        if depth_buffer && depth_renderbuffer.is_undefined() {
          let renderbuffer = gl.create_renderbuffer()
          depth_renderbuffer = @core.JsValue::of(renderbuffer)
          self.texture_utils
          .unwrap()
          .setup_render_buffer_storage(renderbuffer, source, samples)
          render_target_context_data.set(
            "depthRenderbuffer", depth_renderbuffer,
          )
        }
      }
      current_frame_buffer = _wgl_handle(
        render_target_context_data.get("msaaFrameBuffer"),
      )
    } else {
      current_frame_buffer = fb
    }
    state.draw_buffers(source, fb)
  }
  state.bind_framebuffer(@webgl.GL_FRAMEBUFFER, current_frame_buffer) |> ignore
}

///|
/// `_resolveRenderTarget( renderContext )`: blits the MSAA renderbuffers into the
/// render target's textures.
pub fn WebGLBackend::_resolve_render_target(
  self : WebGLBackend,
  render_context : @nodes.RenderContext,
) -> Unit {
  let gl = self.gl.unwrap()
  let state = self.state.unwrap()
  match (render_context.textures, render_context.render_target) {
    (Some(textures), Some(render_target)) => {
      let render_target_context_data = self.get(
        @core.JsValue::of(render_target),
      )
      let props = @nodes.render_target_props(render_target)
      if render_target.samples > 0 &&
        !render_target_context_data.get("msaaFrameBuffer").is_undefined() &&
        self._use_multisampled_extension(render_target) == false {
        let fb : @webgl.GLFramebuffer? = _wgl_handle(
          _wgl_get_num(
            render_target_context_data.get("framebuffers"),
            render_context.get_cache_key(),
          ),
        )
        let mut mask = if render_target.resolve_color_buffer == false ||
          textures.length() == 0 {
          0
        } else {
          @webgl.GL_COLOR_BUFFER_BIT
        }
        if render_target.resolve_depth_buffer {
          if render_target.depth_buffer {
            mask = mask | @webgl.GL_DEPTH_BUFFER_BIT
          }
          if render_target.stencil_buffer &&
            render_target.resolve_stencil_buffer {
            mask = mask | @webgl.GL_STENCIL_BUFFER_BIT
          }
        }
        let msaa_frame_buffer : @webgl.GLFramebuffer? = _wgl_handle(
          render_target_context_data.get("msaaFrameBuffer"),
        )
        let msaa_renderbuffers = render_target_context_data.get(
          "msaaRenderbuffers",
        )
        let is_mrt = textures.length() > 1
        // Depth-only render targets have no color attachment but still resolve their
        // depth.
        let blit_count = if textures.length() > 1 {
          textures.length()
        } else {
          1
        }
        state.bind_framebuffer(@webgl.GL_READ_FRAMEBUFFER, msaa_frame_buffer)
        |> ignore
        state.bind_framebuffer(@webgl.GL_DRAW_FRAMEBUFFER, fb) |> ignore
        if is_mrt {
          // blitFramebuffer() can only copy/resolve the first color attachment of a
          // framebuffer. When using MRT, the engine temporarily removes all
          // attachments and then configures each attachment for the resolve.
          for i in 0..<textures.length() {
            gl.framebuffer_renderbuffer(
              @webgl.GL_READ_FRAMEBUFFER,
              @webgl.GL_COLOR_ATTACHMENT0 + i,
              @webgl.GL_RENDERBUFFER,
              None,
            )
            gl.framebuffer_texture2d(
              @webgl.GL_DRAW_FRAMEBUFFER,
              @webgl.GL_COLOR_ATTACHMENT0 + i,
              @webgl.GL_TEXTURE_2D,
              None,
              0,
            )
          }
        }
        for i in 0..<blit_count {
          if is_mrt {
            // configure attachment for resolve
            let texture_gpu = self
              .get(@core.JsValue::of(textures[i]))
              .get("textureGPU")
            gl.framebuffer_renderbuffer(
              @webgl.GL_READ_FRAMEBUFFER,
              @webgl.GL_COLOR_ATTACHMENT0,
              @webgl.GL_RENDERBUFFER,
              _wgl_handle(_wgl_index(msaa_renderbuffers, i)),
            )
            gl.framebuffer_texture2d(
              @webgl.GL_DRAW_FRAMEBUFFER,
              @webgl.GL_COLOR_ATTACHMENT0,
              @webgl.GL_TEXTURE_2D,
              _wgl_handle(texture_gpu),
              0,
            )
          }
          if render_context.scissor {
            let s = render_context.scissor_value
            let x = s.x.to_int()
            let y = s.y.to_int()
            let width = s.z.to_int()
            let height = s.w.to_int()
            let view_y = render_context.height - height - y
            gl.blit_framebuffer(
              x,
              view_y,
              x + width,
              view_y + height,
              x,
              view_y,
              x + width,
              view_y + height,
              mask,
              @webgl.GL_NEAREST,
            )
          } else {
            gl.blit_framebuffer(
              0,
              0,
              render_context.width,
              render_context.height,
              0,
              0,
              render_context.width,
              render_context.height,
              mask,
              @webgl.GL_NEAREST,
            )
          }
        }
        if is_mrt {
          // restore attachments
          for i, texture in textures {
            let texture_gpu = self
              .get(@core.JsValue::of(texture))
              .get("textureGPU")
            gl.framebuffer_renderbuffer(
              @webgl.GL_READ_FRAMEBUFFER,
              @webgl.GL_COLOR_ATTACHMENT0 + i,
              @webgl.GL_RENDERBUFFER,
              _wgl_handle(_wgl_index(msaa_renderbuffers, i)),
            )
            gl.framebuffer_texture2d(
              @webgl.GL_DRAW_FRAMEBUFFER,
              @webgl.GL_COLOR_ATTACHMENT0 + i,
              @webgl.GL_TEXTURE_2D,
              _wgl_handle(texture_gpu),
              0,
            )
          }
        }
        if self._supports_invalidate_framebuffer == true {
          if render_target.store_multisampled_color_buffer == false {
            for i in 0..<textures.length() {
              _web_gl_backend_invalidation_array.push(
                @webgl.GL_COLOR_ATTACHMENT0 + i,
              )
            }
          }
          if render_target.depth_buffer &&
            render_target.store_multisampled_depth_buffer == false {
            _web_gl_backend_invalidation_array.push(
              if render_target.stencil_buffer {
                @webgl.GL_DEPTH_STENCIL_ATTACHMENT
              } else {
                @webgl.GL_DEPTH_ATTACHMENT
              },
            )
          }
          if _web_gl_backend_invalidation_array.length() > 0 {
            gl.invalidate_framebuffer(
              @webgl.GL_READ_FRAMEBUFFER,
              _web_gl_backend_invalidation_array,
            )
            _web_gl_backend_invalidation_array.clear()
          }
        }
      } else if self._supports_invalidate_framebuffer == true &&
        _wgl_truthy(render_target_context_data.get("framebuffers")) &&
        (
          props._auto_allocate_depth_buffer == Some(true) ||
          (
            render_target.samples > 0 &&
            render_target.store_multisampled_depth_buffer == false
          )
        ) {
        let fb : @webgl.GLFramebuffer? = _wgl_handle(
          _wgl_get_num(
            render_target_context_data.get("framebuffers"),
            render_context.get_cache_key(),
          ),
        )
        state.bind_framebuffer(@webgl.GL_DRAW_FRAMEBUFFER, fb) |> ignore
        let array : FixedArray[Int32] = render_target_context_data
          .get("depthInvalidationArray")
          .cast()
        gl.invalidate_framebuffer(
          @webgl.GL_DRAW_FRAMEBUFFER,
          Array::from_fixed_array(array),
        )
      }
    }
    _ => ()
  }
}

///|
/// `_useMultisampledExtension( renderTarget )`.
pub fn WebGLBackend::_use_multisampled_extension(
  self : WebGLBackend,
  render_target : @core.RenderTarget,
) -> Bool {
  if render_target.multiview == true {
    return true
  }
  render_target.samples > 0 &&
  self.extensions.unwrap().has("WEBGL_multisampled_render_to_texture") == true &&
  @nodes.render_target_props(render_target)._auto_allocate_depth_buffer !=
  Some(false)
}
