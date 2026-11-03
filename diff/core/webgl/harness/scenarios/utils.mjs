export const FORMATS = [1009, 1017, 1018, 35902, 35899, 1010, 1011, 1012, 1013, 1014, 1015, 1016, 1021, 1022, 1023, 1026, 1027, 1028, 1029, 1030, 1031, 1033,
  33776, 33777, 33778, 33779, 35840, 36196, 37492, 37496, 37488, 37489, 37490, 37491, 37808, 37815, 37821, 36492, 36283, 1020, 99999];
export async function run({ src, createMockGL }) {
  const { WebGLExtensions } = await import(src + '/renderers/webgl/WebGLExtensions.js');
  const { WebGLUtils } = await import(src + '/renderers/webgl/WebGLUtils.js');
  const gl = createMockGL({});
  const utils = new WebGLUtils(gl, new WebGLExtensions(gl));
  for (const cs of ['', 'srgb']) for (const p of FORMATS) gl.__note('convert ' + p + ' ' + cs, utils.convert(p, cs));
  return gl.__log;
}
