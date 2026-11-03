// renderers/webgpu/utils/WebGPUConstants.js: the WebGPU enums three.js uses. `GPULoadOp.Clear`
// is `GPULoadOp_Clear`; `Object.values( GPUFeatureName )` is `gpu_feature_names`.

///|
pub const GPUAddressMode_ClampToEdge : String = "clamp-to-edge"

///|
pub const GPUAddressMode_Repeat : String = "repeat"

///|
pub const GPUAddressMode_MirrorRepeat : String = "mirror-repeat"

///|
pub const GPUBlendFactor_Zero : String = "zero"

///|
pub const GPUBlendFactor_One : String = "one"

///|
pub const GPUBlendFactor_Src : String = "src"

///|
pub const GPUBlendFactor_OneMinusSrc : String = "one-minus-src"

///|
pub const GPUBlendFactor_SrcAlpha : String = "src-alpha"

///|
pub const GPUBlendFactor_OneMinusSrcAlpha : String = "one-minus-src-alpha"

///|
pub const GPUBlendFactor_Dst : String = "dst"

///|
pub const GPUBlendFactor_OneMinusDst : String = "one-minus-dst"

///|
pub const GPUBlendFactor_DstAlpha : String = "dst-alpha"

///|
pub const GPUBlendFactor_OneMinusDstAlpha : String = "one-minus-dst-alpha"

///|
pub const GPUBlendFactor_SrcAlphaSaturated : String = "src-alpha-saturated"

///|
pub const GPUBlendFactor_Constant : String = "constant"

///|
pub const GPUBlendFactor_OneMinusConstant : String = "one-minus-constant"

///|
pub const GPUBlendOperation_Add : String = "add"

///|
pub const GPUBlendOperation_Subtract : String = "subtract"

///|
pub const GPUBlendOperation_ReverseSubtract : String = "reverse-subtract"

///|
pub const GPUBlendOperation_Min : String = "min"

///|
pub const GPUBlendOperation_Max : String = "max"

///|
pub const GPUBufferBindingType_Uniform : String = "uniform"

///|
pub const GPUBufferBindingType_Storage : String = "storage"

///|
pub const GPUBufferBindingType_ReadOnlyStorage : String = "read-only-storage"

///|
pub const GPUColorWriteFlags_None : Int32 = 0

///|
pub const GPUColorWriteFlags_Red : Int32 = 1

///|
pub const GPUColorWriteFlags_Green : Int32 = 2

///|
pub const GPUColorWriteFlags_Blue : Int32 = 4

///|
pub const GPUColorWriteFlags_Alpha : Int32 = 8

///|
pub const GPUColorWriteFlags_All : Int32 = 15

///|
pub const GPUCompareFunction_Never : String = "never"

///|
pub const GPUCompareFunction_Less : String = "less"

///|
pub const GPUCompareFunction_Equal : String = "equal"

///|
pub const GPUCompareFunction_LessEqual : String = "less-equal"

///|
pub const GPUCompareFunction_Greater : String = "greater"

///|
pub const GPUCompareFunction_NotEqual : String = "not-equal"

///|
pub const GPUCompareFunction_GreaterEqual : String = "greater-equal"

///|
pub const GPUCompareFunction_Always : String = "always"

///|
pub const GPUCullMode_None : String = "none"

///|
pub const GPUCullMode_Front : String = "front"

///|
pub const GPUCullMode_Back : String = "back"

///|
pub const GPUFeatureName_CoreFeaturesAndLimits : String = "core-features-and-limits"

///|
pub const GPUFeatureName_DepthClipControl : String = "depth-clip-control"

///|
pub const GPUFeatureName_Depth32FloatStencil8 : String = "depth32float-stencil8"

///|
pub const GPUFeatureName_TextureCompressionBC : String = "texture-compression-bc"

///|
pub const GPUFeatureName_TextureCompressionBCSliced3D : String = "texture-compression-bc-sliced-3d"

///|
pub const GPUFeatureName_TextureCompressionETC2 : String = "texture-compression-etc2"

///|
pub const GPUFeatureName_TextureCompressionASTC : String = "texture-compression-astc"

///|
pub const GPUFeatureName_TextureCompressionASTCSliced3D : String = "texture-compression-astc-sliced-3d"

///|
pub const GPUFeatureName_TimestampQuery : String = "timestamp-query"

///|
pub const GPUFeatureName_IndirectFirstInstance : String = "indirect-first-instance"

///|
pub const GPUFeatureName_ShaderF16 : String = "shader-f16"

///|
pub const GPUFeatureName_RG11B10UFloat : String = "rg11b10ufloat-renderable"

///|
pub const GPUFeatureName_BGRA8UNormStorage : String = "bgra8unorm-storage"

///|
pub const GPUFeatureName_Float32Filterable : String = "float32-filterable"

///|
pub const GPUFeatureName_Float32Blendable : String = "float32-blendable"

///|
pub const GPUFeatureName_ClipDistances : String = "clip-distances"

///|
pub const GPUFeatureName_DualSourceBlending : String = "dual-source-blending"

///|
pub const GPUFeatureName_Subgroups : String = "subgroups"

///|
pub const GPUFeatureName_TextureFormatsTier1 : String = "texture-formats-tier1"

///|
pub const GPUFeatureName_TextureFormatsTier2 : String = "texture-formats-tier2"

///|
pub const GPUFilterMode_Linear : String = "linear"

///|
pub const GPUFilterMode_Nearest : String = "nearest"

///|
pub const GPUFrontFace_CCW : String = "ccw"

///|
pub const GPUFrontFace_CW : String = "cw"

///|
pub const GPUIndexFormat_Uint16 : String = "uint16"

///|
pub const GPUIndexFormat_Uint32 : String = "uint32"

///|
pub const GPUInputStepMode_Vertex : String = "vertex"

///|
pub const GPUInputStepMode_Instance : String = "instance"

///|
pub const GPULoadOp_Load : String = "load"

///|
pub const GPULoadOp_Clear : String = "clear"

///|
pub const GPUPrimitiveTopology_PointList : String = "point-list"

///|
pub const GPUPrimitiveTopology_LineList : String = "line-list"

///|
pub const GPUPrimitiveTopology_LineStrip : String = "line-strip"

///|
pub const GPUPrimitiveTopology_TriangleList : String = "triangle-list"

///|
pub const GPUPrimitiveTopology_TriangleStrip : String = "triangle-strip"

///|
pub const GPUSamplerBindingType_Filtering : String = "filtering"

///|
pub const GPUSamplerBindingType_NonFiltering : String = "non-filtering"

///|
pub const GPUSamplerBindingType_Comparison : String = "comparison"

///|
pub const GPUShaderStage_VERTEX : Int32 = 1

///|
pub const GPUShaderStage_FRAGMENT : Int32 = 2

///|
pub const GPUShaderStage_COMPUTE : Int32 = 4

///|
pub const GPUStencilOperation_Keep : String = "keep"

///|
pub const GPUStencilOperation_Zero : String = "zero"

///|
pub const GPUStencilOperation_Replace : String = "replace"

///|
pub const GPUStencilOperation_Invert : String = "invert"

///|
pub const GPUStencilOperation_IncrementClamp : String = "increment-clamp"

///|
pub const GPUStencilOperation_DecrementClamp : String = "decrement-clamp"

///|
pub const GPUStencilOperation_IncrementWrap : String = "increment-wrap"

///|
pub const GPUStencilOperation_DecrementWrap : String = "decrement-wrap"

///|
pub const GPUStorageTextureAccess_WriteOnly : String = "write-only"

///|
pub const GPUStorageTextureAccess_ReadOnly : String = "read-only"

///|
pub const GPUStorageTextureAccess_ReadWrite : String = "read-write"

///|
pub const GPUStoreOp_Store : String = "store"

///|
pub const GPUStoreOp_Discard : String = "discard"

///|
pub const GPUTextureAspect_All : String = "all"

///|
pub const GPUTextureAspect_StencilOnly : String = "stencil-only"

///|
pub const GPUTextureAspect_DepthOnly : String = "depth-only"

///|
pub const GPUTextureDimension_OneD : String = "1d"

///|
pub const GPUTextureDimension_TwoD : String = "2d"

///|
pub const GPUTextureDimension_ThreeD : String = "3d"

///|
pub const GPUTextureFormat_R8Unorm : String = "r8unorm"

///|
pub const GPUTextureFormat_R8Snorm : String = "r8snorm"

///|
pub const GPUTextureFormat_R8Uint : String = "r8uint"

///|
pub const GPUTextureFormat_R8Sint : String = "r8sint"

///|
pub const GPUTextureFormat_R16Uint : String = "r16uint"

///|
pub const GPUTextureFormat_R16Sint : String = "r16sint"

///|
pub const GPUTextureFormat_R16Float : String = "r16float"

///|
pub const GPUTextureFormat_RG8Unorm : String = "rg8unorm"

///|
pub const GPUTextureFormat_RG8Snorm : String = "rg8snorm"

///|
pub const GPUTextureFormat_RG8Uint : String = "rg8uint"

///|
pub const GPUTextureFormat_RG8Sint : String = "rg8sint"

///|
pub const GPUTextureFormat_R16Unorm : String = "r16unorm"

///|
pub const GPUTextureFormat_R16Snorm : String = "r16snorm"

///|
pub const GPUTextureFormat_R32Uint : String = "r32uint"

///|
pub const GPUTextureFormat_R32Sint : String = "r32sint"

///|
pub const GPUTextureFormat_R32Float : String = "r32float"

///|
pub const GPUTextureFormat_RG16Uint : String = "rg16uint"

///|
pub const GPUTextureFormat_RG16Sint : String = "rg16sint"

///|
pub const GPUTextureFormat_RG16Float : String = "rg16float"

///|
pub const GPUTextureFormat_RGBA8Unorm : String = "rgba8unorm"

///|
pub const GPUTextureFormat_RGBA8UnormSRGB : String = "rgba8unorm-srgb"

///|
pub const GPUTextureFormat_RGBA8Snorm : String = "rgba8snorm"

///|
pub const GPUTextureFormat_RGBA8Uint : String = "rgba8uint"

///|
pub const GPUTextureFormat_RGBA8Sint : String = "rgba8sint"

///|
pub const GPUTextureFormat_BGRA8Unorm : String = "bgra8unorm"

///|
pub const GPUTextureFormat_BGRA8UnormSRGB : String = "bgra8unorm-srgb"

///|
pub const GPUTextureFormat_RG16Unorm : String = "rg16unorm"

///|
pub const GPUTextureFormat_RG16Snorm : String = "rg16snorm"

///|
pub const GPUTextureFormat_RGB9E5UFloat : String = "rgb9e5ufloat"

///|
pub const GPUTextureFormat_RGB10A2Unorm : String = "rgb10a2unorm"

///|
pub const GPUTextureFormat_RG11B10UFloat : String = "rg11b10ufloat"

///|
pub const GPUTextureFormat_RG32Uint : String = "rg32uint"

///|
pub const GPUTextureFormat_RG32Sint : String = "rg32sint"

///|
pub const GPUTextureFormat_RG32Float : String = "rg32float"

///|
pub const GPUTextureFormat_RGBA16Uint : String = "rgba16uint"

///|
pub const GPUTextureFormat_RGBA16Sint : String = "rgba16sint"

///|
pub const GPUTextureFormat_RGBA16Float : String = "rgba16float"

///|
pub const GPUTextureFormat_RGBA16Unorm : String = "rgba16unorm"

///|
pub const GPUTextureFormat_RGBA16Snorm : String = "rgba16snorm"

///|
pub const GPUTextureFormat_RGBA32Uint : String = "rgba32uint"

///|
pub const GPUTextureFormat_RGBA32Sint : String = "rgba32sint"

///|
pub const GPUTextureFormat_RGBA32Float : String = "rgba32float"

///|
pub const GPUTextureFormat_Stencil8 : String = "stencil8"

///|
pub const GPUTextureFormat_Depth16Unorm : String = "depth16unorm"

///|
pub const GPUTextureFormat_Depth24Plus : String = "depth24plus"

///|
pub const GPUTextureFormat_Depth24PlusStencil8 : String = "depth24plus-stencil8"

///|
pub const GPUTextureFormat_Depth32Float : String = "depth32float"

///|
pub const GPUTextureFormat_Depth32FloatStencil8 : String = "depth32float-stencil8"

///|
pub const GPUTextureFormat_BC1RGBAUnorm : String = "bc1-rgba-unorm"

///|
pub const GPUTextureFormat_BC1RGBAUnormSRGB : String = "bc1-rgba-unorm-srgb"

///|
pub const GPUTextureFormat_BC2RGBAUnorm : String = "bc2-rgba-unorm"

///|
pub const GPUTextureFormat_BC2RGBAUnormSRGB : String = "bc2-rgba-unorm-srgb"

///|
pub const GPUTextureFormat_BC3RGBAUnorm : String = "bc3-rgba-unorm"

///|
pub const GPUTextureFormat_BC3RGBAUnormSRGB : String = "bc3-rgba-unorm-srgb"

///|
pub const GPUTextureFormat_BC4RUnorm : String = "bc4-r-unorm"

///|
pub const GPUTextureFormat_BC4RSnorm : String = "bc4-r-snorm"

///|
pub const GPUTextureFormat_BC5RGUnorm : String = "bc5-rg-unorm"

///|
pub const GPUTextureFormat_BC5RGSnorm : String = "bc5-rg-snorm"

///|
pub const GPUTextureFormat_BC6HRGBUFloat : String = "bc6h-rgb-ufloat"

///|
pub const GPUTextureFormat_BC6HRGBFloat : String = "bc6h-rgb-float"

///|
pub const GPUTextureFormat_BC7RGBAUnorm : String = "bc7-rgba-unorm"

///|
pub const GPUTextureFormat_BC7RGBAUnormSRGB : String = "bc7-rgba-unorm-srgb"

///|
pub const GPUTextureFormat_ETC2RGB8Unorm : String = "etc2-rgb8unorm"

///|
pub const GPUTextureFormat_ETC2RGB8UnormSRGB : String = "etc2-rgb8unorm-srgb"

///|
pub const GPUTextureFormat_ETC2RGB8A1Unorm : String = "etc2-rgb8a1unorm"

///|
pub const GPUTextureFormat_ETC2RGB8A1UnormSRGB : String = "etc2-rgb8a1unorm-srgb"

///|
pub const GPUTextureFormat_ETC2RGBA8Unorm : String = "etc2-rgba8unorm"

///|
pub const GPUTextureFormat_ETC2RGBA8UnormSRGB : String = "etc2-rgba8unorm-srgb"

///|
pub const GPUTextureFormat_EACR11Unorm : String = "eac-r11unorm"

///|
pub const GPUTextureFormat_EACR11Snorm : String = "eac-r11snorm"

///|
pub const GPUTextureFormat_EACRG11Unorm : String = "eac-rg11unorm"

///|
pub const GPUTextureFormat_EACRG11Snorm : String = "eac-rg11snorm"

///|
pub const GPUTextureFormat_ASTC4x4Unorm : String = "astc-4x4-unorm"

///|
pub const GPUTextureFormat_ASTC4x4UnormSRGB : String = "astc-4x4-unorm-srgb"

///|
pub const GPUTextureFormat_ASTC5x4Unorm : String = "astc-5x4-unorm"

///|
pub const GPUTextureFormat_ASTC5x4UnormSRGB : String = "astc-5x4-unorm-srgb"

///|
pub const GPUTextureFormat_ASTC5x5Unorm : String = "astc-5x5-unorm"

///|
pub const GPUTextureFormat_ASTC5x5UnormSRGB : String = "astc-5x5-unorm-srgb"

///|
pub const GPUTextureFormat_ASTC6x5Unorm : String = "astc-6x5-unorm"

///|
pub const GPUTextureFormat_ASTC6x5UnormSRGB : String = "astc-6x5-unorm-srgb"

///|
pub const GPUTextureFormat_ASTC6x6Unorm : String = "astc-6x6-unorm"

///|
pub const GPUTextureFormat_ASTC6x6UnormSRGB : String = "astc-6x6-unorm-srgb"

///|
pub const GPUTextureFormat_ASTC8x5Unorm : String = "astc-8x5-unorm"

///|
pub const GPUTextureFormat_ASTC8x5UnormSRGB : String = "astc-8x5-unorm-srgb"

///|
pub const GPUTextureFormat_ASTC8x6Unorm : String = "astc-8x6-unorm"

///|
pub const GPUTextureFormat_ASTC8x6UnormSRGB : String = "astc-8x6-unorm-srgb"

///|
pub const GPUTextureFormat_ASTC8x8Unorm : String = "astc-8x8-unorm"

///|
pub const GPUTextureFormat_ASTC8x8UnormSRGB : String = "astc-8x8-unorm-srgb"

///|
pub const GPUTextureFormat_ASTC10x5Unorm : String = "astc-10x5-unorm"

///|
pub const GPUTextureFormat_ASTC10x5UnormSRGB : String = "astc-10x5-unorm-srgb"

///|
pub const GPUTextureFormat_ASTC10x6Unorm : String = "astc-10x6-unorm"

///|
pub const GPUTextureFormat_ASTC10x6UnormSRGB : String = "astc-10x6-unorm-srgb"

///|
pub const GPUTextureFormat_ASTC10x8Unorm : String = "astc-10x8-unorm"

///|
pub const GPUTextureFormat_ASTC10x8UnormSRGB : String = "astc-10x8-unorm-srgb"

///|
pub const GPUTextureFormat_ASTC10x10Unorm : String = "astc-10x10-unorm"

///|
pub const GPUTextureFormat_ASTC10x10UnormSRGB : String = "astc-10x10-unorm-srgb"

///|
pub const GPUTextureFormat_ASTC12x10Unorm : String = "astc-12x10-unorm"

///|
pub const GPUTextureFormat_ASTC12x10UnormSRGB : String = "astc-12x10-unorm-srgb"

///|
pub const GPUTextureFormat_ASTC12x12Unorm : String = "astc-12x12-unorm"

///|
pub const GPUTextureFormat_ASTC12x12UnormSRGB : String = "astc-12x12-unorm-srgb"

///|
pub const GPUTextureSampleType_Float : String = "float"

///|
pub const GPUTextureSampleType_UnfilterableFloat : String = "unfilterable-float"

///|
pub const GPUTextureSampleType_Depth : String = "depth"

///|
pub const GPUTextureSampleType_SInt : String = "sint"

///|
pub const GPUTextureSampleType_UInt : String = "uint"

///|
pub const GPUTextureViewDimension_OneD : String = "1d"

///|
pub const GPUTextureViewDimension_TwoD : String = "2d"

///|
pub const GPUTextureViewDimension_TwoDArray : String = "2d-array"

///|
pub const GPUTextureViewDimension_Cube : String = "cube"

///|
pub const GPUTextureViewDimension_CubeArray : String = "cube-array"

///|
pub const GPUTextureViewDimension_ThreeD : String = "3d"

///|
pub const GPUVertexFormat_Uint8x2 : String = "uint8x2"

///|
pub const GPUVertexFormat_Uint8x4 : String = "uint8x4"

///|
pub const GPUVertexFormat_Sint8x2 : String = "sint8x2"

///|
pub const GPUVertexFormat_Sint8x4 : String = "sint8x4"

///|
pub const GPUVertexFormat_Unorm8x2 : String = "unorm8x2"

///|
pub const GPUVertexFormat_Unorm8x4 : String = "unorm8x4"

///|
pub const GPUVertexFormat_Snorm8x2 : String = "snorm8x2"

///|
pub const GPUVertexFormat_Snorm8x4 : String = "snorm8x4"

///|
pub const GPUVertexFormat_Uint16x2 : String = "uint16x2"

///|
pub const GPUVertexFormat_Uint16x4 : String = "uint16x4"

///|
pub const GPUVertexFormat_Sint16x2 : String = "sint16x2"

///|
pub const GPUVertexFormat_Sint16x4 : String = "sint16x4"

///|
pub const GPUVertexFormat_Unorm16x2 : String = "unorm16x2"

///|
pub const GPUVertexFormat_Unorm16x4 : String = "unorm16x4"

///|
pub const GPUVertexFormat_Snorm16x2 : String = "snorm16x2"

///|
pub const GPUVertexFormat_Snorm16x4 : String = "snorm16x4"

///|
pub const GPUVertexFormat_Float16x2 : String = "float16x2"

///|
pub const GPUVertexFormat_Float16x4 : String = "float16x4"

///|
pub const GPUVertexFormat_Float32 : String = "float32"

///|
pub const GPUVertexFormat_Float32x2 : String = "float32x2"

///|
pub const GPUVertexFormat_Float32x3 : String = "float32x3"

///|
pub const GPUVertexFormat_Float32x4 : String = "float32x4"

///|
pub const GPUVertexFormat_Uint32 : String = "uint32"

///|
pub const GPUVertexFormat_Uint32x2 : String = "uint32x2"

///|
pub const GPUVertexFormat_Uint32x3 : String = "uint32x3"

///|
pub const GPUVertexFormat_Uint32x4 : String = "uint32x4"

///|
pub const GPUVertexFormat_Sint32 : String = "sint32"

///|
pub const GPUVertexFormat_Sint32x2 : String = "sint32x2"

///|
pub const GPUVertexFormat_Sint32x3 : String = "sint32x3"

///|
pub const GPUVertexFormat_Sint32x4 : String = "sint32x4"

///|
/// `Object.values( GPUFeatureName )`, in declaration order.
pub let gpu_feature_names : Array[String] = [
  "core-features-and-limits", "depth-clip-control", "depth32float-stencil8", "texture-compression-bc",
  "texture-compression-bc-sliced-3d", "texture-compression-etc2", "texture-compression-astc",
  "texture-compression-astc-sliced-3d", "timestamp-query", "indirect-first-instance",
  "shader-f16", "rg11b10ufloat-renderable", "bgra8unorm-storage", "float32-filterable",
  "float32-blendable", "clip-distances", "dual-source-blending", "subgroups", "texture-formats-tier1",
  "texture-formats-tier2",
]

///|
/// `GPUFeatureMap[ name ]`: three.js feature names that differ from the WebGPU ones.
pub fn gpu_feature_map(name : String) -> String? {
  match name {
    "texture-compression-s3tc" => Some("texture-compression-bc")
    "texture-compression-etc1" => Some("texture-compression-etc2")
    _ => None
  }
}
