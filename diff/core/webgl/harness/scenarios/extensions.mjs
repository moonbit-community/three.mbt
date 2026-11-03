export async function run({ src, createMockGL }) {
  const { WebGLExtensions } = await import(src + '/renderers/webgl/WebGLExtensions.js');
  const gl = createMockGL({ extensions: ['Extension1', 'Extension2', 'EXT_color_buffer_float'] });
  const e = new WebGLExtensions(gl);
  gl.__note('has Extension1', e.has('Extension1'));
  gl.__note('has Extension2', e.has('Extension2'));
  gl.__note('has Extension1', e.has('Extension1'));
  gl.__note('has NonExisting', e.has('NonExistingExtension'));
  gl.__note('get Extension2', e.get('Extension2') !== null);
  gl.__note('get NonExisting', e.get('NonExistingExtension') !== null);
  e.init();
  return gl.__log;
}
