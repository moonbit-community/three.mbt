// Group 2: WebGLProgram first use with shader logs: link failure with default error
// reporting, a custom onShaderError, a program info-log warning and shader-log-only
// diagnostics. Notes program.diagnostics, including both GLSL prefixes byte for byte.
import { createRequire } from 'node:module';
const { createCanvas } = createRequire(import.meta.url)('./programs_common.cjs');

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { WebGLAttributes } = await import(src + '/renderers/webgl/WebGLAttributes.js');
  const { WebGLBindingStates } = await import(src + '/renderers/webgl/WebGLBindingStates.js');
  const { WebGLEnvironments } = await import(src + '/renderers/webgl/WebGLEnvironments.js');
  const { WebGLClipping } = await import(src + '/renderers/webgl/WebGLClipping.js');
  const { WebGLPrograms } = await import(src + '/renderers/webgl/WebGLPrograms.js');
  const source = Array.from({ length: 20 }, (_, i) => 'line ' + (i + 1)).join('\n');
  const canvas = { width: 64, height: 32 };
  const glA = createMockGL({ linkStatus: false, compileStatus: false, shaderInfoLog: '  ERROR: 0:12: bad token\n', programInfoLog: ' link failed ', shaderSource: source, canvas });
  const glB = createMockGL({ programInfoLog: 'warning: unused', canvas });
  const glC = createMockGL({ shaderInfoLog: 'note', canvas });
  function setup(g) {
    const renderer = new WebGLRenderer({ canvas: createCanvas(g, 64, 32), context: g });
    const bindingStates = new WebGLBindingStates(g, new WebGLAttributes(g));
    const programs = new WebGLPrograms(renderer, new WebGLEnvironments(renderer), renderer.extensions, renderer.capabilities, bindingStates, new WebGLClipping(renderer.properties));
    g.__clear();
    return { gl: g, renderer, programs };
  }
  const lights = { numSpotLightShadowsWithMaps: 0, numLightProbes: 0 };
  for (const k of ['sun', 'directional', 'point', 'spot', 'spotLightMap', 'rectArea', 'hemi', 'sunShadowMap', 'directionalShadowMap', 'pointShadowMap', 'spotShadowMap']) lights[k] = [];
  function compile(R, material) {
    const object = new T.Mesh(new T.BufferGeometry(), material);
    const params = R.programs.getParameters(material, lights, [], new T.Scene(), object, []);
    const key = R.programs.getProgramCacheKey(params);
    params.uniforms = R.programs.getUniforms(material);
    const program = R.programs.acquireProgram(params, key);
    program.getUniforms();
    const d = program.diagnostics;
    R.gl.__note('diagnostics', d === undefined ? 'undefined' : [d.runnable, d.programLog, d.vertexShader.log, d.fragmentShader.log].join('|'));
    if (d !== undefined) {
      R.gl.__note('vertex prefix', d.vertexShader.prefix);
      R.gl.__note('fragment prefix', d.fragmentShader.prefix);
    }
    return program;
  }
  const A = setup(glA);
  const B = setup(glB);
  const C = setup(glC);
  compile(A, new T.MeshBasicMaterial());
  A.renderer.debug.onShaderError = (g, program, vs, fs) => g.__note('onShaderError', [program, vs, fs]);
  compile(A, new T.MeshLambertMaterial());
  compile(B, new T.MeshStandardMaterial());
  const raw = new T.RawShaderMaterial({ vertexShader: 'void main() {}', fragmentShader: 'void main() {}' });
  raw.defines = { FOO: 1 };
  compile(B, raw);
  compile(C, new T.MeshPhongMaterial());
  glA.__note('B', glB.__log);
  glA.__note('C', glC.__log);
  return glA.__log;
}
