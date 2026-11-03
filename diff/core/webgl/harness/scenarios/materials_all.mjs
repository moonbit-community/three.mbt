import { noteUniforms } from '../group3_util.mjs';

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLProperties } = await import(src + '/renderers/webgl/WebGLProperties.js');
  const { WebGLMaterials } = await import(src + '/renderers/webgl/WebGLMaterials.js');
  const { ShaderLib } = await import(src + '/renderers/shaders/ShaderLib.js');
  const { cloneUniforms } = await import(src + '/renderers/shaders/UniformsUtils.js');
  const gl = createMockGL({});
  const properties = new WebGLProperties();
  const renderer = { getRenderTarget: () => null, outputColorSpace: T.SRGBColorSpace };
  const materials = new WebGLMaterials(renderer, properties);
  let n = 0;
  const tex = (name) => {
    const t = new T.Texture(); t.name = name; n ++;
    t.offset.set(0.1 * n, 0.05 * n); t.repeat.set(1 + n, 2 - 0.1 * n); t.rotation = 0.2 * n; t.center.set(0.5, 0.25);
    if (n % 3 === 0) t.matrixAutoUpdate = false;
    return t;
  };
  const cube = (name, rtt) => { const t = new T.CubeTexture(); t.name = name; t.isRenderTargetTexture = rtt; return t; };
  const lib = (key) => cloneUniforms(ShaderLib[key].uniforms);
  const run = (label, key, material, extra) => {
    const uniforms = lib(key);
    materials.refreshMaterialUniforms(uniforms, material, 2, 600, extra);
    noteUniforms(gl, label, uniforms);
  };
  const envProps = (material, envMap, x, y, z) => {
    const p = properties.get(material);
    p.envMap = envMap; p.envMapRotation = new T.Euler(x, y, z);
  };

  const basic = new T.MeshBasicMaterial();
  basic.color.setRGB(0.2, 0.4, 0.6); basic.opacity = 0.5;
  basic.map = tex('basic.map'); basic.alphaMap = tex('basic.alphaMap'); basic.specularMap = tex('basic.specularMap');
  basic.alphaTest = 0.3; basic.lightMap = tex('basic.lightMap'); basic.lightMapIntensity = 0.7;
  basic.aoMap = tex('basic.aoMap'); basic.aoMapIntensity = 0.4; basic.reflectivity = 0.6; basic.refractionRatio = 0.9;
  envProps(basic, cube('basic.env', false), 0.1, 0.2, 0.3);
  run('basic', 'basic', basic);

  const lambert = new T.MeshLambertMaterial();
  lambert.color.setRGB(0.7, 0.1, 0.2); lambert.emissive.setRGB(0.1, 0.2, 0.3); lambert.emissiveIntensity = 2;
  lambert.bumpMap = tex('lambert.bumpMap'); lambert.bumpScale = 2; lambert.side = T.BackSide;
  lambert.normalMap = tex('lambert.normalMap'); lambert.normalScale.set(0.5, 0.7);
  lambert.displacementMap = tex('lambert.displacementMap'); lambert.displacementScale = 3; lambert.displacementBias = - 1;
  lambert.emissiveMap = tex('lambert.emissiveMap');
  lambert.envMap = tex('lambert.envMap'); lambert.envMapIntensity = 0.3;
  envProps(lambert, lambert.envMap, 0.5, 0, 0);
  run('lambert', 'lambert', lambert);

  const toon = new T.MeshToonMaterial();
  toon.gradientMap = tex('toon.gradientMap'); toon.color.setRGB(0.3, 0.3, 0.9);
  run('toon', 'toon', toon);

  const phong = new T.MeshPhongMaterial();
  phong.specular.setRGB(0.3, 0.2, 0.1); phong.shininess = 0;
  phong.envMap = cube('phong.env', false); phong.envMapIntensity = 2;
  envProps(phong, phong.envMap, 0, 0.7, 0);
  run('phong', 'phong', phong);

  const standard = new T.MeshStandardMaterial();
  standard.metalness = 0.8; standard.metalnessMap = tex('standard.metalnessMap');
  standard.roughness = 0.3; standard.roughnessMap = tex('standard.roughnessMap');
  standard.envMap = cube('standard.env', true); standard.envMapIntensity = 1.5;
  envProps(standard, standard.envMap, 0.2, 0.4, 0.6);
  run('standard', 'standard', standard);

  const physical = new T.MeshPhysicalMaterial();
  physical.ior = 1.8; physical.side = T.BackSide;
  physical.diffuseRoughness = 0.5; physical.diffuseRoughnessMap = tex('physical.diffuseRoughnessMap');
  physical.sheen = 0.6; physical.sheenColor.setRGB(1, 0.5, 0); physical.sheenRoughness = 0.2;
  physical.sheenColorMap = tex('physical.sheenColorMap'); physical.sheenRoughnessMap = tex('physical.sheenRoughnessMap');
  physical.clearcoat = 0.7; physical.clearcoatRoughness = 0.1; physical.clearcoatMap = tex('physical.clearcoatMap');
  physical.clearcoatRoughnessMap = tex('physical.clearcoatRoughnessMap');
  physical.clearcoatNormalMap = tex('physical.clearcoatNormalMap'); physical.clearcoatNormalScale.set(2, 3);
  physical.dispersion = 0.2; physical.retroreflectivity = 0.3;
  physical.iridescence = 0.4; physical.iridescenceIOR = 1.5; physical.iridescenceThicknessMinimum = 200; physical.iridescenceThicknessMaximum = 500;
  physical.iridescenceMap = tex('physical.iridescenceMap'); physical.iridescenceThicknessMap = tex('physical.iridescenceThicknessMap');
  physical.transmission = 0.9; physical.transmissionMap = tex('physical.transmissionMap');
  physical.thickness = 0.5; physical.thicknessMap = tex('physical.thicknessMap');
  physical.attenuationDistance = 10; physical.attenuationColor.setRGB(0.9, 0.8, 0.7);
  physical.anisotropy = 0.6; physical.anisotropyRotation = 0.7; physical.anisotropyMap = tex('physical.anisotropyMap');
  physical.specularIntensity = 0.8; physical.specularColor.setRGB(0.5, 0.6, 0.7);
  physical.specularColorMap = tex('physical.specularColorMap'); physical.specularIntensityMap = tex('physical.specularIntensityMap');
  physical.envMap = cube('physical.env', false);
  envProps(physical, physical.envMap, 0.3, 0.2, 0.1);
  const transmissionRT = new T.RenderTarget(128, 64);
  transmissionRT.texture.name = 'transmissionRT';
  run('physical', 'physical', physical, transmissionRT);

  const physical2 = new T.MeshPhysicalMaterial();
  run('physical2', 'physical', physical2, null);

  const matcap = new T.MeshMatcapMaterial();
  matcap.matcap = tex('matcap.matcap'); matcap.normalMap = tex('matcap.normalMap'); matcap.side = T.BackSide;
  run('matcap', 'matcap', matcap);

  const depth = new T.MeshDepthMaterial();
  depth.map = tex('depth.map'); depth.alphaTest = 0.5; depth.displacementMap = tex('depth.displacementMap');
  run('depth', 'depth', depth);

  const distance = new T.MeshDistanceMaterial();
  const point = new T.PointLight();
  point.position.set(1, 2, 3); point.updateMatrixWorld();
  point.shadow.camera.near = 0.5; point.shadow.camera.far = 40;
  properties.get(distance).light = point;
  run('distance', 'distance', distance);

  const normal = new T.MeshNormalMaterial();
  normal.bumpMap = tex('normal.bumpMap'); normal.normalMap = tex('normal.normalMap');
  normal.displacementMap = tex('normal.displacementMap'); normal.displacementScale = 0.25;
  run('normal', 'normal', normal);

  const line = new T.LineBasicMaterial();
  line.color.setRGB(0.1, 0.9, 0.1); line.opacity = 0.6; line.map = tex('line.map');
  run('line', 'basic', line);

  const dashed = new T.LineDashedMaterial();
  dashed.dashSize = 2; dashed.gapSize = 0.5; dashed.scale = 3; dashed.map = tex('dashed.map');
  run('dashed', 'dashed', dashed);

  const points = new T.PointsMaterial();
  points.size = 4; points.color.setRGB(0.4, 0.5, 0.6); points.map = tex('points.map');
  points.alphaMap = tex('points.alphaMap'); points.alphaTest = 0.2;
  run('points', 'points', points);

  const sprite = new T.SpriteMaterial();
  sprite.rotation = 0.4; sprite.map = tex('sprite.map'); sprite.alphaMap = tex('sprite.alphaMap'); sprite.alphaTest = 0.1;
  run('sprite', 'sprite', sprite);

  const shadow = new T.ShadowMaterial();
  shadow.color.setRGB(0.1, 0.2, 0.3); shadow.opacity = 0.4;
  run('shadow', 'shadow', shadow);

  const shader = new T.ShaderMaterial();
  shader.uniformsNeedUpdate = true;
  materials.refreshMaterialUniforms({}, shader, 1, 1, null);
  gl.__note('shader uniformsNeedUpdate', shader.uniformsNeedUpdate);
  const raw = new T.RawShaderMaterial();
  raw.uniformsNeedUpdate = true;
  materials.refreshMaterialUniforms({}, raw, 1, 1, null);
  gl.__note('raw uniformsNeedUpdate', raw.uniformsNeedUpdate);

  const fogUniforms = lib('basic');
  materials.refreshFogUniforms(fogUniforms, new T.Fog(0x808080, 2, 30));
  gl.__note('fog', [fogUniforms.fogColor.value.toArray(), fogUniforms.fogNear.value, fogUniforms.fogFar.value, fogUniforms.fogDensity.value]);
  materials.refreshFogUniforms(fogUniforms, new T.FogExp2(0x112233, 0.05));
  gl.__note('fogExp2', [fogUniforms.fogColor.value.toArray(), fogUniforms.fogNear.value, fogUniforms.fogFar.value, fogUniforms.fogDensity.value]);
  renderer.outputColorSpace = T.LinearSRGBColorSpace;
  materials.refreshFogUniforms(fogUniforms, new T.FogExp2(0x112233, 0.05));
  gl.__note('fogExp2 linear', fogUniforms.fogColor.value.toArray());
  return gl.__log;
}
