// Upstream src/constants.js. Color-space, coordinate-system and ending constants
// live in src/math and are re-exported by the `using` block at the end of this file.
// Object-valued upstream constants become one constant per key, `MOUSE.LEFT` -> `MOUSE_LEFT`.

///|
pub const REVISION : String = "187"

///|
pub const MOUSE_LEFT : Int32 = 0

///|
pub const MOUSE_MIDDLE : Int32 = 1

///|
pub const MOUSE_RIGHT : Int32 = 2

///|
pub const MOUSE_ROTATE : Int32 = 0

///|
pub const MOUSE_DOLLY : Int32 = 1

///|
pub const MOUSE_PAN : Int32 = 2

///|
pub const TOUCH_ROTATE : Int32 = 0

///|
pub const TOUCH_PAN : Int32 = 1

///|
pub const TOUCH_DOLLY_PAN : Int32 = 2

///|
pub const TOUCH_DOLLY_ROTATE : Int32 = 3

///|
pub const CullFaceNone : Int32 = 0

///|
pub const CullFaceBack : Int32 = 1

///|
pub const CullFaceFront : Int32 = 2

///|
pub const CullFaceFrontBack : Int32 = 3

///|
pub const BasicShadowMap : Int32 = 0

///|
pub const PCFShadowMap : Int32 = 1

///|
pub const PCFSoftShadowMap : Int32 = 2

///|
pub const VSMShadowMap : Int32 = 3

///|
pub const FrontSide : Int32 = 0

///|
pub const BackSide : Int32 = 1

///|
pub const DoubleSide : Int32 = 2

///|
pub const NoBlending : Int32 = 0

///|
pub const NormalBlending : Int32 = 1

///|
pub const AdditiveBlending : Int32 = 2

///|
pub const SubtractiveBlending : Int32 = 3

///|
pub const MultiplyBlending : Int32 = 4

///|
pub const CustomBlending : Int32 = 5

///|
pub const MaterialBlending : Int32 = 6

///|
pub const AddEquation : Int32 = 100

///|
pub const SubtractEquation : Int32 = 101

///|
pub const ReverseSubtractEquation : Int32 = 102

///|
pub const MinEquation : Int32 = 103

///|
pub const MaxEquation : Int32 = 104

///|
pub const ZeroFactor : Int32 = 200

///|
pub const OneFactor : Int32 = 201

///|
pub const SrcColorFactor : Int32 = 202

///|
pub const OneMinusSrcColorFactor : Int32 = 203

///|
pub const SrcAlphaFactor : Int32 = 204

///|
pub const OneMinusSrcAlphaFactor : Int32 = 205

///|
pub const DstAlphaFactor : Int32 = 206

///|
pub const OneMinusDstAlphaFactor : Int32 = 207

///|
pub const DstColorFactor : Int32 = 208

///|
pub const OneMinusDstColorFactor : Int32 = 209

///|
pub const SrcAlphaSaturateFactor : Int32 = 210

///|
pub const ConstantColorFactor : Int32 = 211

///|
pub const OneMinusConstantColorFactor : Int32 = 212

///|
pub const ConstantAlphaFactor : Int32 = 213

///|
pub const OneMinusConstantAlphaFactor : Int32 = 214

///|
pub const NeverDepth : Int32 = 0

///|
pub const AlwaysDepth : Int32 = 1

///|
pub const LessDepth : Int32 = 2

///|
pub const LessEqualDepth : Int32 = 3

///|
pub const EqualDepth : Int32 = 4

///|
pub const GreaterEqualDepth : Int32 = 5

///|
pub const GreaterDepth : Int32 = 6

///|
pub const NotEqualDepth : Int32 = 7

///|
pub const MultiplyOperation : Int32 = 0

///|
pub const MixOperation : Int32 = 1

///|
pub const AddOperation : Int32 = 2

///|
pub const NoToneMapping : Int32 = 0

///|
pub const LinearToneMapping : Int32 = 1

///|
pub const ReinhardToneMapping : Int32 = 2

///|
pub const CineonToneMapping : Int32 = 3

///|
pub const ACESFilmicToneMapping : Int32 = 4

///|
pub const CustomToneMapping : Int32 = 5

///|
pub const AgXToneMapping : Int32 = 6

///|
pub const NeutralToneMapping : Int32 = 7

///|
pub const AttachedBindMode : String = "attached"

///|
pub const DetachedBindMode : String = "detached"

///|
pub const UVMapping : Int32 = 300

///|
pub const CubeReflectionMapping : Int32 = 301

///|
pub const CubeRefractionMapping : Int32 = 302

///|
pub const EquirectangularReflectionMapping : Int32 = 303

///|
pub const EquirectangularRefractionMapping : Int32 = 304

///|
pub const RepeatWrapping : Int32 = 1000

///|
pub const ClampToEdgeWrapping : Int32 = 1001

///|
pub const MirroredRepeatWrapping : Int32 = 1002

///|
pub const NearestFilter : Int32 = 1003

///|
pub const NearestMipmapNearestFilter : Int32 = 1004

///|
pub const NearestMipMapNearestFilter : Int32 = 1004

///|
pub const NearestMipmapLinearFilter : Int32 = 1005

///|
pub const NearestMipMapLinearFilter : Int32 = 1005

///|
pub const LinearFilter : Int32 = 1006

///|
pub const LinearMipmapNearestFilter : Int32 = 1007

///|
pub const LinearMipMapNearestFilter : Int32 = 1007

///|
pub const LinearMipmapLinearFilter : Int32 = 1008

///|
pub const LinearMipMapLinearFilter : Int32 = 1008

///|
pub const UnsignedByteType : Int32 = 1009

///|
pub const ByteType : Int32 = 1010

///|
pub const ShortType : Int32 = 1011

///|
pub const UnsignedShortType : Int32 = 1012

///|
pub const IntType : Int32 = 1013

///|
pub const UnsignedIntType : Int32 = 1014

///|
pub const FloatType : Int32 = 1015

///|
pub const HalfFloatType : Int32 = 1016

///|
pub const UnsignedShort4444Type : Int32 = 1017

///|
pub const UnsignedShort5551Type : Int32 = 1018

///|
pub const UnsignedInt248Type : Int32 = 1020

///|
pub const UnsignedInt5999Type : Int32 = 35902

///|
pub const UnsignedInt101111Type : Int32 = 35899

///|
pub const AlphaFormat : Int32 = 1021

///|
pub const RGBFormat : Int32 = 1022

///|
pub const RGBAFormat : Int32 = 1023

///|
pub const DepthFormat : Int32 = 1026

///|
pub const DepthStencilFormat : Int32 = 1027

///|
pub const RedFormat : Int32 = 1028

///|
pub const RedIntegerFormat : Int32 = 1029

///|
pub const RGFormat : Int32 = 1030

///|
pub const RGIntegerFormat : Int32 = 1031

///|
pub const RGBIntegerFormat : Int32 = 1032

///|
pub const RGBAIntegerFormat : Int32 = 1033

///|
pub const RGB_S3TC_DXT1_Format : Int32 = 33776

///|
pub const RGBA_S3TC_DXT1_Format : Int32 = 33777

///|
pub const RGBA_S3TC_DXT3_Format : Int32 = 33778

///|
pub const RGBA_S3TC_DXT5_Format : Int32 = 33779

///|
pub const RGB_PVRTC_4BPPV1_Format : Int32 = 35840

///|
pub const RGB_PVRTC_2BPPV1_Format : Int32 = 35841

///|
pub const RGBA_PVRTC_4BPPV1_Format : Int32 = 35842

///|
pub const RGBA_PVRTC_2BPPV1_Format : Int32 = 35843

///|
pub const RGB_ETC1_Format : Int32 = 36196

///|
pub const RGB_ETC2_Format : Int32 = 37492

///|
pub const RGBA_ETC2_EAC_Format : Int32 = 37496

///|
pub const R11_EAC_Format : Int32 = 37488

///|
pub const SIGNED_R11_EAC_Format : Int32 = 37489

///|
pub const RG11_EAC_Format : Int32 = 37490

///|
pub const SIGNED_RG11_EAC_Format : Int32 = 37491

///|
pub const RGBA_ASTC_4x4_Format : Int32 = 37808

///|
pub const RGBA_ASTC_5x4_Format : Int32 = 37809

///|
pub const RGBA_ASTC_5x5_Format : Int32 = 37810

///|
pub const RGBA_ASTC_6x5_Format : Int32 = 37811

///|
pub const RGBA_ASTC_6x6_Format : Int32 = 37812

///|
pub const RGBA_ASTC_8x5_Format : Int32 = 37813

///|
pub const RGBA_ASTC_8x6_Format : Int32 = 37814

///|
pub const RGBA_ASTC_8x8_Format : Int32 = 37815

///|
pub const RGBA_ASTC_10x5_Format : Int32 = 37816

///|
pub const RGBA_ASTC_10x6_Format : Int32 = 37817

///|
pub const RGBA_ASTC_10x8_Format : Int32 = 37818

///|
pub const RGBA_ASTC_10x10_Format : Int32 = 37819

///|
pub const RGBA_ASTC_12x10_Format : Int32 = 37820

///|
pub const RGBA_ASTC_12x12_Format : Int32 = 37821

///|
pub const RGBA_BPTC_Format : Int32 = 36492

///|
pub const RGB_BPTC_SIGNED_Format : Int32 = 36494

///|
pub const RGB_BPTC_UNSIGNED_Format : Int32 = 36495

///|
pub const RED_RGTC1_Format : Int32 = 36283

///|
pub const SIGNED_RED_RGTC1_Format : Int32 = 36284

///|
pub const RED_GREEN_RGTC2_Format : Int32 = 36285

///|
pub const SIGNED_RED_GREEN_RGTC2_Format : Int32 = 36286

///|
pub const LoopOnce : Int32 = 2200

///|
pub const LoopRepeat : Int32 = 2201

///|
pub const LoopPingPong : Int32 = 2202

///|
pub const InterpolateDiscrete : Int32 = 2300

///|
pub const InterpolateLinear : Int32 = 2301

///|
pub const InterpolateSmooth : Int32 = 2302

///|
pub const InterpolateBezier : Int32 = 2303

///|
pub const NormalAnimationBlendMode : Int32 = 2500

///|
pub const AdditiveAnimationBlendMode : Int32 = 2501

///|
pub const TrianglesDrawMode : Int32 = 0

///|
pub const TriangleStripDrawMode : Int32 = 1

///|
pub const TriangleFanDrawMode : Int32 = 2

///|
pub const BasicDepthPacking : Int32 = 3200

///|
pub const RGBADepthPacking : Int32 = 3201

///|
pub const RGBDepthPacking : Int32 = 3202

///|
pub const RGDepthPacking : Int32 = 3203

///|
pub const TangentSpaceNormalMap : Int32 = 0

///|
pub const ObjectSpaceNormalMap : Int32 = 1

///|
pub const NoNormalPacking : String = ""

///|
pub const NormalRGPacking : String = "rg"

///|
pub const NormalGAPacking : String = "ga"

///|
pub const ZeroStencilOp : Int32 = 0

///|
pub const KeepStencilOp : Int32 = 7680

///|
pub const ReplaceStencilOp : Int32 = 7681

///|
pub const IncrementStencilOp : Int32 = 7682

///|
pub const DecrementStencilOp : Int32 = 7683

///|
pub const IncrementWrapStencilOp : Int32 = 34055

///|
pub const DecrementWrapStencilOp : Int32 = 34056

///|
pub const InvertStencilOp : Int32 = 5386

///|
pub const NeverStencilFunc : Int32 = 512

///|
pub const LessStencilFunc : Int32 = 513

///|
pub const EqualStencilFunc : Int32 = 514

///|
pub const LessEqualStencilFunc : Int32 = 515

///|
pub const GreaterStencilFunc : Int32 = 516

///|
pub const NotEqualStencilFunc : Int32 = 517

///|
pub const GreaterEqualStencilFunc : Int32 = 518

///|
pub const AlwaysStencilFunc : Int32 = 519

///|
pub const NeverCompare : Int32 = 512

///|
pub const LessCompare : Int32 = 513

///|
pub const EqualCompare : Int32 = 514

///|
pub const LessEqualCompare : Int32 = 515

///|
pub const GreaterCompare : Int32 = 516

///|
pub const NotEqualCompare : Int32 = 517

///|
pub const GreaterEqualCompare : Int32 = 518

///|
pub const AlwaysCompare : Int32 = 519

///|
pub const StaticDrawUsage : Int32 = 35044

///|
pub const DynamicDrawUsage : Int32 = 35048

///|
pub const StreamDrawUsage : Int32 = 35040

///|
pub const StaticReadUsage : Int32 = 35045

///|
pub const DynamicReadUsage : Int32 = 35049

///|
pub const StreamReadUsage : Int32 = 35041

///|
pub const StaticCopyUsage : Int32 = 35046

///|
pub const DynamicCopyUsage : Int32 = 35050

///|
pub const StreamCopyUsage : Int32 = 35042

///|
pub const GLSL1 : String = "100"

///|
pub const GLSL3 : String = "300 es"

///|
pub const TimestampQuery_COMPUTE : String = "compute"

///|
pub const TimestampQuery_RENDER : String = "render"

///|
pub const InterpolationSamplingType_PERSPECTIVE : String = "perspective"

///|
pub const InterpolationSamplingType_LINEAR : String = "linear"

///|
pub const InterpolationSamplingType_FLAT : String = "flat"

///|
pub const InterpolationSamplingMode_NORMAL : String = "normal"

///|
pub const InterpolationSamplingMode_CENTROID : String = "centroid"

///|
pub const InterpolationSamplingMode_SAMPLE : String = "sample"

///|
pub const InterpolationSamplingMode_FIRST : String = "first"

///|
pub const InterpolationSamplingMode_EITHER : String = "either"

///|
pub const Compatibility_TEXTURE_COMPARE : String = "depthTextureCompare"

///|
pub const RenderObjectRefreshType_NONE : Int32 = 0

///|
pub const RenderObjectRefreshType_SHARED : Int32 = 1

///|
pub const RenderObjectRefreshType_FULL : Int32 = 2

///|
pub using @math {
  LinearSRGBColorSpace,
  LinearTransfer,
  NoColorSpace,
  SRGBColorSpace,
  SRGBTransfer,
  WebGLCoordinateSystem,
  WebGPUCoordinateSystem,
  WrapAroundEnding,
  ZeroCurvatureEnding,
  ZeroSlopeEnding,
}
