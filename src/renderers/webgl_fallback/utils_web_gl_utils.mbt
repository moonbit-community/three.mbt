// renderers/webgl-fallback/utils/WebGLUtils.js: three.js constants to GL values, and the
// fence wait of async readbacks.

///|
pub(all) struct WebGLUtils {
  backend : WebGLBackend
  gl : @webgl.WebGL2RenderingContext
  extensions : WebGLExtensions
}

///|
/// `new WebGLUtils( backend )`.
pub fn WebGLUtils::new(backend : WebGLBackend) -> WebGLUtils {
  { backend, gl: backend.gl.unwrap(), extensions: backend.extensions.unwrap(), }
}

///|
/// `convert( p, colorSpace = NoColorSpace )`: a three.js format or type constant to its
/// GL value; `None` is upstream's `null` (unsupported compressed format or unknown
/// constant).
pub fn WebGLUtils::convert(
  self : WebGLUtils,
  p : Int32,
  color_space~ : String = @core.NoColorSpace,
) -> Int32? {
  let gl = self.gl
  let extensions = self.extensions
  let transfer = @math.color_management.get_transfer(color_space)
  let srgb = transfer == @core.SRGBTransfer
  match p {
    @core.UnsignedByteType => return Some(@webgl.GL_UNSIGNED_BYTE)
    @core.UnsignedShort4444Type => return Some(@webgl.GL_UNSIGNED_SHORT_4_4_4_4)
    @core.UnsignedShort5551Type => return Some(@webgl.GL_UNSIGNED_SHORT_5_5_5_1)
    @core.UnsignedInt5999Type => return Some(@webgl.GL_UNSIGNED_INT_5_9_9_9_REV)
    @core.UnsignedInt101111Type =>
      return Some(@webgl.GL_UNSIGNED_INT_10F_11F_11F_REV)
    @core.ByteType => return Some(@webgl.GL_BYTE)
    @core.ShortType => return Some(@webgl.GL_SHORT)
    @core.UnsignedShortType => return Some(@webgl.GL_UNSIGNED_SHORT)
    @core.IntType => return Some(@webgl.GL_INT)
    @core.UnsignedIntType => return Some(@webgl.GL_UNSIGNED_INT)
    @core.FloatType => return Some(@webgl.GL_FLOAT)
    @core.HalfFloatType => return Some(@webgl.GL_HALF_FLOAT)
    @core.AlphaFormat => return Some(@webgl.GL_ALPHA)
    @core.RGBFormat => return Some(@webgl.GL_RGB)
    @core.RGBAFormat => return Some(@webgl.GL_RGBA)
    @core.DepthFormat => return Some(@webgl.GL_DEPTH_COMPONENT)
    @core.DepthStencilFormat => return Some(@webgl.GL_DEPTH_STENCIL)
    // WebGL2 formats.
    @core.RedFormat => return Some(@webgl.GL_RED)
    @core.RedIntegerFormat => return Some(@webgl.GL_RED_INTEGER)
    @core.RGFormat => return Some(@webgl.GL_RG)
    @core.RGIntegerFormat => return Some(@webgl.GL_RG_INTEGER)
    @core.RGBAIntegerFormat => return Some(@webgl.GL_RGBA_INTEGER)
    _ => ()
  }
  // S3TC
  if p == @core.RGB_S3TC_DXT1_Format ||
    p == @core.RGBA_S3TC_DXT1_Format ||
    p == @core.RGBA_S3TC_DXT3_Format ||
    p == @core.RGBA_S3TC_DXT5_Format {
    if srgb {
      guard extensions.get("WEBGL_compressed_texture_s3tc_srgb")
        is Some(extension) else {
        return None
      }
      if p == @core.RGB_S3TC_DXT1_Format {
        return Some(extension.constant("COMPRESSED_SRGB_S3TC_DXT1_EXT"))
      }
      if p == @core.RGBA_S3TC_DXT1_Format {
        return Some(extension.constant("COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT"))
      }
      if p == @core.RGBA_S3TC_DXT3_Format {
        return Some(extension.constant("COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT"))
      }
      if p == @core.RGBA_S3TC_DXT5_Format {
        return Some(extension.constant("COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT"))
      }
    } else {
      guard extensions.get("WEBGL_compressed_texture_s3tc") is Some(extension) else {
        return None
      }
      if p == @core.RGB_S3TC_DXT1_Format {
        return Some(extension.constant("COMPRESSED_RGB_S3TC_DXT1_EXT"))
      }
      if p == @core.RGBA_S3TC_DXT1_Format {
        return Some(extension.constant("COMPRESSED_RGBA_S3TC_DXT1_EXT"))
      }
      if p == @core.RGBA_S3TC_DXT3_Format {
        return Some(extension.constant("COMPRESSED_RGBA_S3TC_DXT3_EXT"))
      }
      if p == @core.RGBA_S3TC_DXT5_Format {
        return Some(extension.constant("COMPRESSED_RGBA_S3TC_DXT5_EXT"))
      }
    }
  }
  // PVRTC
  if p == @core.RGB_PVRTC_4BPPV1_Format ||
    p == @core.RGB_PVRTC_2BPPV1_Format ||
    p == @core.RGBA_PVRTC_4BPPV1_Format ||
    p == @core.RGBA_PVRTC_2BPPV1_Format {
    guard extensions.get("WEBGL_compressed_texture_pvrtc") is Some(extension) else {
      return None
    }
    if p == @core.RGB_PVRTC_4BPPV1_Format {
      return Some(extension.constant("COMPRESSED_RGB_PVRTC_4BPPV1_IMG"))
    }
    if p == @core.RGB_PVRTC_2BPPV1_Format {
      return Some(extension.constant("COMPRESSED_RGB_PVRTC_2BPPV1_IMG"))
    }
    if p == @core.RGBA_PVRTC_4BPPV1_Format {
      return Some(extension.constant("COMPRESSED_RGBA_PVRTC_4BPPV1_IMG"))
    }
    if p == @core.RGBA_PVRTC_2BPPV1_Format {
      return Some(extension.constant("COMPRESSED_RGBA_PVRTC_2BPPV1_IMG"))
    }
  }
  // ETC
  if p == @core.RGB_ETC1_Format ||
    p == @core.RGB_ETC2_Format ||
    p == @core.RGBA_ETC2_EAC_Format ||
    p == @core.R11_EAC_Format ||
    p == @core.SIGNED_R11_EAC_Format ||
    p == @core.RG11_EAC_Format ||
    p == @core.SIGNED_RG11_EAC_Format {
    guard extensions.get("WEBGL_compressed_texture_etc") is Some(extension) else {
      return None
    }
    if p == @core.RGB_ETC1_Format || p == @core.RGB_ETC2_Format {
      return Some(
        extension.constant(
          if srgb {
            "COMPRESSED_SRGB8_ETC2"
          } else {
            "COMPRESSED_RGB8_ETC2"
          },
        ),
      )
    }
    if p == @core.RGBA_ETC2_EAC_Format {
      return Some(
        extension.constant(
          if srgb {
            "COMPRESSED_SRGB8_ALPHA8_ETC2_EAC"
          } else {
            "COMPRESSED_RGBA8_ETC2_EAC"
          },
        ),
      )
    }
    if p == @core.R11_EAC_Format {
      return Some(extension.constant("COMPRESSED_R11_EAC"))
    }
    if p == @core.SIGNED_R11_EAC_Format {
      return Some(extension.constant("COMPRESSED_SIGNED_R11_EAC"))
    }
    if p == @core.RG11_EAC_Format {
      return Some(extension.constant("COMPRESSED_RG11_EAC"))
    }
    if p == @core.SIGNED_RG11_EAC_Format {
      return Some(extension.constant("COMPRESSED_SIGNED_RG11_EAC"))
    }
  }
  // ASTC
  if _web_gl_utils_astc_block(p) is Some(block) {
    guard extensions.get("WEBGL_compressed_texture_astc") is Some(extension) else {
      return None
    }
    return Some(
      extension.constant(
        if srgb {
          "COMPRESSED_SRGB8_ALPHA8_ASTC_\{block}_KHR"
        } else {
          "COMPRESSED_RGBA_ASTC_\{block}_KHR"
        },
      ),
    )
  }
  // BPTC
  if p == @core.RGBA_BPTC_Format ||
    p == @core.RGB_BPTC_SIGNED_Format ||
    p == @core.RGB_BPTC_UNSIGNED_Format {
    guard extensions.get("EXT_texture_compression_bptc") is Some(extension) else {
      return None
    }
    if p == @core.RGBA_BPTC_Format {
      return Some(
        extension.constant(
          if srgb {
            "COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT"
          } else {
            "COMPRESSED_RGBA_BPTC_UNORM_EXT"
          },
        ),
      )
    }
    if p == @core.RGB_BPTC_SIGNED_Format {
      return Some(extension.constant("COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT"))
    }
    if p == @core.RGB_BPTC_UNSIGNED_Format {
      return Some(extension.constant("COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT"))
    }
  }
  // RGTC
  if p == @core.RED_RGTC1_Format ||
    p == @core.SIGNED_RED_RGTC1_Format ||
    p == @core.RED_GREEN_RGTC2_Format ||
    p == @core.SIGNED_RED_GREEN_RGTC2_Format {
    guard extensions.get("EXT_texture_compression_rgtc") is Some(extension) else {
      return None
    }
    if p == @core.RED_RGTC1_Format {
      return Some(extension.constant("COMPRESSED_RED_RGTC1_EXT"))
    }
    if p == @core.SIGNED_RED_RGTC1_Format {
      return Some(extension.constant("COMPRESSED_SIGNED_RED_RGTC1_EXT"))
    }
    if p == @core.RED_GREEN_RGTC2_Format {
      return Some(extension.constant("COMPRESSED_RED_GREEN_RGTC2_EXT"))
    }
    if p == @core.SIGNED_RED_GREEN_RGTC2_Format {
      return Some(extension.constant("COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT"))
    }
  }
  //
  if p == @core.UnsignedInt248Type {
    return Some(@webgl.GL_UNSIGNED_INT_24_8)
  }
  // if "p" can't be resolved, assume the user defines a WebGL constant as a string
  // (fallback/workaround for packed RGB formats)
  gl.get_constant(p.to_string())
}

///|
/// The block size in the ASTC extension's constant names, e.g. `4x4`.
fn _web_gl_utils_astc_block(p : Int32) -> String? {
  match p {
    @core.RGBA_ASTC_4x4_Format => Some("4x4")
    @core.RGBA_ASTC_5x4_Format => Some("5x4")
    @core.RGBA_ASTC_5x5_Format => Some("5x5")
    @core.RGBA_ASTC_6x5_Format => Some("6x5")
    @core.RGBA_ASTC_6x6_Format => Some("6x6")
    @core.RGBA_ASTC_8x5_Format => Some("8x5")
    @core.RGBA_ASTC_8x6_Format => Some("8x6")
    @core.RGBA_ASTC_8x8_Format => Some("8x8")
    @core.RGBA_ASTC_10x5_Format => Some("10x5")
    @core.RGBA_ASTC_10x6_Format => Some("10x6")
    @core.RGBA_ASTC_10x8_Format => Some("10x8")
    @core.RGBA_ASTC_10x10_Format => Some("10x10")
    @core.RGBA_ASTC_12x10_Format => Some("12x10")
    @core.RGBA_ASTC_12x12_Format => Some("12x12")
    _ => None
  }
}

///|
/// `requestAnimationFrame( f )` of the global scope.
extern "js" fn _web_gl_utils_request_animation_frame(f : () -> Unit) -> Unit = "(f) => { requestAnimationFrame( () => f() ); }"

///|
/// `_clientWaitAsync()`: resolves (`on_done(true)`) once the GPU has passed a fence, or
/// rejects (`on_done(false)`) when the wait fails.
pub fn WebGLUtils::_client_wait_async(
  self : WebGLUtils,
  on_done : (Bool) -> Unit,
) -> Unit {
  let gl = self.gl
  let sync = gl.fence_sync(@webgl.GL_SYNC_GPU_COMMANDS_COMPLETE, 0)
  gl.flush()
  fn poll() -> Unit {
    let res = gl.client_wait_sync(sync, @webgl.GL_SYNC_FLUSH_COMMANDS_BIT, 0.0)
    if res == @webgl.GL_WAIT_FAILED {
      gl.delete_sync(sync)
      on_done(false)
      return
    }
    if res == @webgl.GL_TIMEOUT_EXPIRED {
      _web_gl_utils_request_animation_frame(poll)
      return
    }
    gl.delete_sync(sync)
    on_done(true)
  }

  poll()
}
