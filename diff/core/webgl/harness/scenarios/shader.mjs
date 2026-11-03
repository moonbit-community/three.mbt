export async function run({ src, createMockGL }) {
  const { WebGLShader } = await import(src + '/renderers/webgl/WebGLShader.js');
  const gl = createMockGL({});
  WebGLShader(gl, gl.VERTEX_SHADER, 'void main() {}');
  WebGLShader(gl, gl.FRAGMENT_SHADER, 'void main() { gl_FragColor = vec4( 1.0 ); }');
  return gl.__log;
}
