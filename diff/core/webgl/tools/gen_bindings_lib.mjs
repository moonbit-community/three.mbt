// Shared by gen_bindings.mjs, gen_mock.mjs and check_coverage.mjs.
export function snake(name) {
  return name
    .replace(/([a-z])([A-Z])/g, '$1_$2')
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1_$2')
    .toLowerCase();
}

export function parse(spec) {
  const m = /^(\w+)(?:=(\w+))?\((.*)\)(?:\s*->\s*(.+))?$/.exec(spec);
  if (!m) throw new Error('bad spec ' + spec);
  const [, js, moon, params, ret] = m;
  return {
    js,
    moon: moon || snake(js),
    params: params.trim() === '' ? [] : params.split(',').map((p) => {
      const [n, t] = p.trim().split(':');
      return { name: n, type: t };
    }),
    ret: ret ? ret.trim() : 'Unit',
  };
}

