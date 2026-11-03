// Node module resolve hook for the a6 (objects add-on) scenarios: maps the bare
// specifiers the examples/jsm add-ons import to the upstream sources the harness drives,
// so add-ons and scenarios share one copy of three.js.
//   'three' -> src/Three.js, 'three/webgpu' -> src/Three.WebGPU.js,
//   'three/tsl' -> src/Three.TSL.js, 'three/addons/...' -> examples/jsm/...
let src;
export async function initialize(data) { src = data.src; }
export async function resolve(specifier, context, next) {
  const map = { three: '/Three.js', 'three/webgpu': '/Three.WebGPU.js', 'three/tsl': '/Three.TSL.js' };
  if (map[specifier]) return { url: src + map[specifier], shortCircuit: true };
  if (specifier.startsWith('three/addons/')) return { url: src.replace(/\/src$/, '/examples/jsm/') + specifier.slice('three/addons/'.length), shortCircuit: true };
  return next(specifier, context);
}
