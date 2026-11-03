// Scenes built with upstream three.js; their toJSON() output is the input of the
// round-trip tests. Each builder returns an Object3D.
import { MockImage } from './mock_env.mjs';
import { nonfiniteBuilders } from './nonfinite_fixtures.mjs';

export function builders(T) {
  const img = (name, w = 4, h = 2) => {
    const i = new MockImage();
    i._src = `data:image/png;base64,${name}`;
    i.width = w; i.height = h; i.complete = true;
    return i;
  };
  const tex = (name) => new T.Texture(img(name));
  const dataTex = (w = 2, h = 2) => {
    const t = new T.DataTexture(new Uint8Array(w * h * 4).map((_, i) => (i * 37) % 256), w, h);
    t.needsUpdate = true;
    return t;
  };
  const shape = () => {
    const s = new T.Shape();
    s.moveTo(0, 0).lineTo(2, 0).quadraticCurveTo(3, 1, 2, 2).bezierCurveTo(1.5, 3, 0.5, 3, 0, 2).lineTo(0, 0);
    const hole = new T.Path();
    hole.absarc(1, 1, 0.3, 0, Math.PI * 2, false);
    s.holes.push(hole);
    return s;
  };
  const clip = (name) => new T.AnimationClip(name, 2, [
    new T.NumberKeyframeTrack('.position[x]', [0, 1, 2], [0, 1, 0]),
    new T.VectorKeyframeTrack('.scale', [0, 2], [1, 1, 1, 2, 2, 2]),
    new T.QuaternionKeyframeTrack('.quaternion', [0, 1], [0, 0, 0, 1, 0, 0.7071067811865476, 0, 0.7071067811865476]),
    new T.ColorKeyframeTrack('.material.color', [0, 1], [1, 0, 0, 0, 1, 0], T.InterpolateDiscrete),
    new T.BooleanKeyframeTrack('.visible', [0, 1], [true, false]),
    new T.StringKeyframeTrack('.name', [0, 1], ['a', 'b']),
  ], T.AdditiveAnimationBlendMode);

  const B = {};

  B.empty_object = () => new T.Object3D();

  B.object_properties = () => {
    const o = new T.Group();
    o.name = 'props';
    o.position.set(1, 2, 3);
    o.rotation.set(0.1, 0.2, 0.3, 'ZYX');
    o.scale.set(2, 3, 4);
    o.up.set(0, 0, 1);
    o.castShadow = true; o.receiveShadow = true; o.visible = false; o.frustumCulled = false;
    o.renderOrder = 5; o.static = true; o.layers.set(3); o.layers.enable(7);
    o.userData = { a: 1, b: [1, 2, { c: 'x' }], 10: 'ten', 2: 'two', nested: { z: null } };
    const fixed = new T.Object3D();
    fixed.matrixAutoUpdate = false;
    fixed.matrix.makeRotationX(0.5).setPosition(1, 1, 1);
    o.add(fixed);
    const pivoted = new T.Object3D();
    pivoted.pivot = new T.Vector3(1, 0, 0);
    pivoted.position.set(0, 1, 0);
    pivoted.rotation.y = 0.7;
    pivoted.updateMatrix();
    o.add(pivoted);
    o.updateMatrix();
    return o;
  };

  B.scene_background_fog = () => {
    const s = new T.Scene();
    s.background = new T.Color(0x336699);
    s.fog = new T.Fog(0xaabbcc, 2, 50);
    s.fog.name = 'linear fog';
    s.backgroundBlurriness = 0.3; s.backgroundIntensity = 0.8;
    s.backgroundRotation.set(0.1, 0.2, 0.3);
    s.environmentIntensity = 0.5;
    s.environmentRotation.set(0.4, 0.5, 0.6, 'YXZ');
    s.add(new T.Mesh(new T.BoxGeometry(), new T.MeshBasicMaterial()));
    return s;
  };

  B.scene_fog_exp2_textures = () => {
    const s = new T.Scene();
    s.fog = new T.FogExp2(0x123456, 0.05);
    const bg = tex('background');
    bg.mapping = T.EquirectangularReflectionMapping;
    s.background = bg;
    const env = new T.CubeTexture([img('px'), img('nx'), img('py'), img('ny'), img('pz'), img('nz')]);
    env.needsUpdate = true;
    s.environment = env;
    return s;
  };

  B.cameras = () => {
    const g = new T.Group();
    const p = new T.PerspectiveCamera(60, 1.5, 0.5, 500);
    p.focus = 7; p.zoom = 2; p.filmGauge = 24; p.filmOffset = 1;
    p.setViewOffset(1920, 1080, 100, 50, 640, 480);
    p.position.set(0, 5, 10);
    p.lookAt(0, 0, 0);
    g.add(p);
    const o = new T.OrthographicCamera(-2, 3, 4, -5, 0.1, 99);
    o.zoom = 0.5;
    o.setViewOffset(100, 100, 10, 10, 50, 50);
    g.add(o);
    g.add(new T.PerspectiveCamera());
    g.add(new T.ArrayCamera([new T.PerspectiveCamera()]));
    g.add(new T.CubeCamera(1, 100, new T.WebGLCubeRenderTarget(16)));
    return g;
  };

  B.lights = () => {
    const s = new T.Scene();
    s.add(new T.AmbientLight(0x404040, 0.7));
    const d = new T.DirectionalLight(0xffeedd, 2.5);
    d.position.set(5, 10, 2);
    d.castShadow = true;
    d.shadow.bias = -0.001; d.shadow.normalBias = 0.02; d.shadow.radius = 3; d.shadow.blurSamples = 12;
    d.shadow.intensity = 0.6; d.shadow.mapSize.set(1024, 2048); d.shadow.mapType = T.HalfFloatType;
    d.shadow.camera.left = -20; d.shadow.camera.right = 20; d.shadow.camera.near = 1; d.shadow.camera.far = 80;
    d.shadow.camera.updateProjectionMatrix();
    const target = new T.Object3D();
    target.name = 'target';
    target.position.set(1, 0, 0);
    s.add(target);
    d.target = target;
    s.add(d);
    const p = new T.PointLight(0xff0000, 3, 20, 1.5);
    p.shadow.camera.near = 0.2;
    p.shadow.camera.updateProjectionMatrix();
    s.add(p);
    s.add(new T.RectAreaLight(0x00ff00, 4, 3, 2));
    const spot = new T.SpotLight(0x0000ff, 5, 30, Math.PI / 5, 0.3, 1.2);
    spot.map = tex('spotmap');
    spot.shadow.focus = 0.8;
    spot.shadow.camera.fov = 40;
    spot.shadow.camera.updateProjectionMatrix();
    s.add(spot); // target not in the scene
    s.add(new T.HemisphereLight(0x88ccff, 0x443322, 0.9));
    const sh = new T.SphericalHarmonics3();
    for (let i = 0; i < 9; i++) sh.coefficients[i].set(i * 0.1, i * 0.2, i * 0.3);
    s.add(new T.LightProbe(sh, 1.7));
    return s;
  };

  const geometryList = () => {
    const curve = new T.CatmullRomCurve3([new T.Vector3(0, 0, 0), new T.Vector3(1, 2, 0), new T.Vector3(3, 1, 1), new T.Vector3(4, 0, 2)], false, 'catmullrom', 0.3);
    return [
      new T.BoxGeometry(1, 2, 3, 2, 3, 4),
      new T.CapsuleGeometry(0.5, 1.5, 3, 6, 2),
      new T.CircleGeometry(2, 12, 0.5, 5),
      new T.ConeGeometry(1, 2, 7, 2, true, 0.3, 5),
      new T.CylinderGeometry(1, 2, 3, 9, 2, false, 0.1, 6),
      new T.DodecahedronGeometry(1.5, 1),
      new T.ExtrudeGeometry([shape()], { depth: 2, bevelEnabled: true, bevelThickness: 0.2, bevelSize: 0.1, bevelSegments: 2, curveSegments: 6, steps: 2 }),
      new T.ExtrudeGeometry(shape(), { steps: 5, extrudePath: curve, bevelEnabled: false }),
      new T.IcosahedronGeometry(1, 2),
      new T.LatheGeometry([new T.Vector2(0, -1), new T.Vector2(1, 0), new T.Vector2(0.5, 1)], 8, 0.2, 5),
      new T.OctahedronGeometry(2, 0),
      new T.PlaneGeometry(4, 3, 2, 5),
      new T.PolyhedronGeometry([1, 1, 1, -1, -1, 1, -1, 1, -1, 1, -1, -1], [2, 1, 0, 0, 3, 2, 1, 3, 0, 2, 3, 1], 2, 1),
      new T.RingGeometry(0.5, 2, 10, 3, 0.2, 5),
      new T.ShapeGeometry([shape(), shape()], 5),
      new T.SphereGeometry(1, 10, 8, 0.1, 6, 0.2, 2.5),
      new T.TetrahedronGeometry(1, 2),
      new T.TorusGeometry(2, 0.4, 6, 20, 5),
      new T.TorusKnotGeometry(1, 0.3, 30, 6, 3, 5),
      new T.TubeGeometry(curve, 12, 0.2, 5, false),
      new T.TubeGeometry(new T.LineCurve3(new T.Vector3(0, 0, 0), new T.Vector3(0, 3, 0)), 4, 0.5, 6, true),
    ];
  };

  B.all_geometries = () => {
    const g = new T.Group();
    for (const geometry of geometryList()) {
      geometry.name = geometry.type + '-named';
      geometry.userData = { kind: geometry.type };
      g.add(new T.Mesh(geometry, new T.MeshNormalMaterial()));
    }
    return g;
  };

  B.buffer_geometries = () => {
    const g = new T.Group();
    const a = new T.BufferGeometry();
    a.setAttribute('position', new T.Float32BufferAttribute([0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0], 3));
    a.setAttribute('normal', new T.Float32BufferAttribute([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1], 3));
    a.setAttribute('uv', new T.Float32BufferAttribute([0, 0, 1, 0, 0, 1, 1, 1], 2));
    const color = new T.Uint8BufferAttribute([255, 0, 0, 0, 255, 0, 0, 0, 255, 9, 9, 9], 3, true);
    color.name = 'vertex colors';
    color.setUsage(T.DynamicDrawUsage);
    a.setAttribute('color', color);
    const ids = new T.Int16BufferAttribute([1, 2, 3, 4], 1);
    ids.gpuType = T.IntType;
    a.setAttribute('ids', ids);
    a.setIndex([0, 1, 2, 2, 1, 3]);
    a.addGroup(0, 3, 0); a.addGroup(3, 3, 1);
    a.morphAttributes.position = [new T.Float32BufferAttribute([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1], 3), new T.Float32BufferAttribute([1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0], 3)];
    a.morphAttributes.normal = [new T.Float32BufferAttribute(new Array(12).fill(0.5), 3), new T.Float32BufferAttribute(new Array(12).fill(0.25), 3)];
    a.morphTargetsRelative = true;
    a.computeBoundingSphere();
    a.name = 'custom';
    a.userData = { tag: 'geo' };
    const mesh = new T.Mesh(a, [new T.MeshBasicMaterial({ color: 0xff0000 }), new T.MeshLambertMaterial({ color: 0x00ff00 })]);
    mesh.morphTargetInfluences[0] = 0.25; mesh.morphTargetInfluences[1] = 0.75;
    g.add(mesh);

    const big = new T.BufferGeometry();
    const positions = []; const index = [];
    for (let i = 0; i < 70000; i += 1000) { positions.push(i, 0, 0); index.push(i / 1000); }
    big.setAttribute('position', new T.Float32BufferAttribute(positions, 3));
    big.setIndex(index);
    g.add(new T.Points(big, new T.PointsMaterial({ size: 3, sizeAttenuation: false })));

    const ib = new T.InterleavedBuffer(new Float32Array([1, 2, 3, 0, 0, 4, 5, 6, 0, 1, 7, 8, 9, 1, 1]), 5);
    ib.setUsage(T.DynamicDrawUsage);
    const inter = new T.BufferGeometry();
    inter.setAttribute('position', new T.InterleavedBufferAttribute(ib, 3, 0));
    const iuv = new T.InterleavedBufferAttribute(ib, 2, 3);
    iuv.name = 'interleaved uv';
    inter.setAttribute('uv', iuv);
    inter.morphAttributes.position = [new T.InterleavedBufferAttribute(ib, 3, 0)];
    g.add(new T.Line(inter, new T.LineBasicMaterial({ color: 0x0000ff, linewidth: 2 })));

    const inst = new T.InstancedBufferGeometry();
    inst.setAttribute('position', new T.Float32BufferAttribute([0, 0, 0, 1, 0, 0, 0, 1, 0], 3));
    inst.setAttribute('offset', new T.InstancedBufferAttribute(new Float32Array([0, 0, 0, 1, 1, 1]), 3, false, 2));
    inst.instanceCount = 2;
    const iib = new T.InstancedInterleavedBuffer(new Float32Array([1, 2, 3, 4, 5, 6, 7, 8]), 4, 3);
    inst.setAttribute('instanceData', new T.InterleavedBufferAttribute(iib, 4, 0, true));
    g.add(new T.Mesh(inst, new T.MeshBasicMaterial()));

    const unindexed = new T.BufferGeometry();
    unindexed.setAttribute('position', new T.Float32BufferAttribute([0, 0, 0, 1, 1, 1], 3));
    g.add(new T.LineLoop(unindexed, new T.LineDashedMaterial({ dashSize: 2, gapSize: 0.5, scale: 3 })));
    g.add(new T.LineSegments(unindexed, new T.LineBasicMaterial()));
    const shared = new T.BoxGeometry();
    g.add(new T.Mesh(shared, new T.MeshBasicMaterial()), new T.Mesh(shared, new T.MeshBasicMaterial()));
    return g;
  };

  const allMaps = (m, keys) => {
    const shared = tex('shared');
    for (const k of keys) m[k] = k === 'aoMap' || k === 'lightMap' ? shared : tex(k);
  };

  B.materials_basic = () => {
    const g = new T.Group();
    const geo = new T.PlaneGeometry();
    const basic = new T.MeshBasicMaterial({ color: 0x123456, opacity: 0.5, transparent: true, side: T.DoubleSide, wireframe: true, wireframeLinewidth: 2, fog: false, reflectivity: 0.3, refractionRatio: 0.9, combine: T.MixOperation, lightMapIntensity: 0.5, aoMapIntensity: 0.25 });
    allMaps(basic, ['map', 'lightMap', 'aoMap', 'specularMap', 'alphaMap', 'envMap']);
    basic.envMapRotation.set(0.1, 0.2, 0.3);
    basic.name = 'basic';
    basic.userData = { m: 1 };
    basic.blending = T.CustomBlending; basic.blendSrc = T.OneFactor; basic.blendDst = T.DstColorFactor; basic.blendEquation = T.SubtractEquation;
    basic.blendSrcAlpha = T.SrcAlphaFactor; basic.blendDstAlpha = T.ZeroFactor; basic.blendEquationAlpha = T.MaxEquation;
    basic.blendColor.set(0x00ff00); basic.blendAlpha = 0.5;
    basic.depthFunc = T.GreaterDepth; basic.depthTest = false; basic.depthWrite = false; basic.colorWrite = false;
    basic.stencilWrite = true; basic.stencilWriteMask = 0x0f; basic.stencilFunc = T.EqualStencilFunc; basic.stencilRef = 2; basic.stencilFuncMask = 0xf0;
    basic.stencilFail = T.ReplaceStencilOp; basic.stencilZFail = T.IncrementStencilOp; basic.stencilZPass = T.InvertStencilOp;
    basic.clippingPlanes = [new T.Plane(new T.Vector3(1, 0, 0), 2), new T.Plane(new T.Vector3(0, 1, 0), -1)];
    basic.clipIntersection = true; basic.clipShadows = true; basic.shadowSide = T.BackSide;
    basic.polygonOffset = true; basic.polygonOffsetFactor = 1.5; basic.polygonOffsetUnits = 2;
    basic.dithering = true; basic.alphaTest = 0.4; basic.alphaHash = true; basic.alphaToCoverage = true; basic.premultipliedAlpha = true;
    basic.forceSinglePass = true; basic.allowOverride = false; basic.visible = false; basic.toneMapped = false; basic.vertexColors = true;
    g.add(new T.Mesh(geo, basic));

    const lambert = new T.MeshLambertMaterial({ color: 0xff8800, emissive: 0x112233, emissiveIntensity: 2, flatShading: true, bumpScale: 2, displacementScale: 3, displacementBias: 0.5, normalMapType: T.ObjectSpaceNormalMap, normalScale: new T.Vector2(2, -1) });
    allMaps(lambert, ['map', 'emissiveMap', 'bumpMap', 'normalMap', 'displacementMap']);
    g.add(new T.Mesh(geo, lambert));

    const phong = new T.MeshPhongMaterial({ specular: 0x445566, shininess: 77, envMapIntensity: 0.4 });
    allMaps(phong, ['map', 'specularMap']);
    g.add(new T.Mesh(geo, phong));

    const toon = new T.MeshToonMaterial({ color: 0x00ffff });
    allMaps(toon, ['gradientMap']);
    g.add(new T.Mesh(geo, toon));

    const matcap = new T.MeshMatcapMaterial();
    allMaps(matcap, ['matcap']);
    g.add(new T.Mesh(geo, matcap));

    g.add(new T.Mesh(geo, new T.MeshNormalMaterial({ flatShading: true, wireframe: true })));
    g.add(new T.Mesh(geo, new T.MeshDepthMaterial({ depthPacking: T.RGBADepthPacking, displacementScale: 2 })));
    g.add(new T.Mesh(geo, new T.MeshDistanceMaterial()));
    g.add(new T.Mesh(geo, new T.ShadowMaterial({ color: 0x220000, opacity: 0.3 })));
    const sm = new T.SpriteMaterial({ color: 0xff00ff, rotation: 0.5, sizeAttenuation: false });
    allMaps(sm, ['map', 'alphaMap']);
    const sprite = new T.Sprite(sm);
    sprite.center.set(0.2, 0.8);
    g.add(sprite);
    g.add(new T.Sprite());
    return g;
  };

  B.materials_physical = () => {
    const g = new T.Group();
    const geo = new T.SphereGeometry(1, 4, 3);
    const std = new T.MeshStandardMaterial({ roughness: 0.3, metalness: 0.7, envMapIntensity: 2 });
    allMaps(std, ['map', 'roughnessMap', 'metalnessMap', 'envMap', 'normalMap', 'aoMap']);
    g.add(new T.Mesh(geo, std));
    const phys = new T.MeshPhysicalMaterial({
      clearcoat: 0.5, clearcoatRoughness: 0.2, clearcoatNormalScale: new T.Vector2(0.5, 0.5), dispersion: 0.1, ior: 1.7,
      iridescence: 0.4, iridescenceIOR: 1.5, iridescenceThicknessRange: [200, 600], sheen: 0.6, sheenColor: 0x808000, sheenRoughness: 0.3,
      transmission: 0.9, thickness: 1.2, attenuationDistance: 5, attenuationColor: 0x00aaff, specularIntensity: 0.8, specularColor: 0xffaaaa,
      anisotropy: 0.3, anisotropyRotation: 1.1, retroreflectivity: 0.2, diffuseRoughness: 0.4,
    });
    allMaps(phys, ['clearcoatMap', 'clearcoatRoughnessMap', 'clearcoatNormalMap', 'iridescenceMap', 'iridescenceThicknessMap', 'sheenColorMap', 'sheenRoughnessMap', 'transmissionMap', 'thicknessMap', 'specularIntensityMap', 'specularColorMap', 'anisotropyMap', 'diffuseRoughnessMap']);
    g.add(new T.Mesh(geo, phys));
    g.add(new T.Mesh(geo, new T.MeshPhysicalMaterial()));
    return g;
  };

  B.materials_shader = () => {
    const g = new T.Group();
    const geo = new T.PlaneGeometry();
    const shader = new T.ShaderMaterial({
      name: 'shader',
      uniforms: {
        uFloat: { value: 1.5 }, uInt: { value: 3 }, uBool: { value: true },
        uColor: { value: new T.Color(0xff0000) }, uV2: { value: new T.Vector2(1, 2) }, uV3: { value: new T.Vector3(1, 2, 3) },
        uV4: { value: new T.Vector4(1, 2, 3, 4) }, uM3: { value: new T.Matrix3().set(1, 2, 3, 4, 5, 6, 7, 8, 9) },
        uM4: { value: new T.Matrix4().makeTranslation(1, 2, 3) }, uTex: { value: tex('uniformtex') }, uArr: { value: [1, 2, 3] },
        uQuat: { value: new T.Quaternion(0, 0, 0, 1) }, uNull: { value: null },
      },
      defines: { USE_FOO: '', COUNT: 3 },
      vertexShader: 'void main() { gl_Position = vec4(0.0); }',
      fragmentShader: 'void main() { gl_FragColor = vec4(1.0); }',
      lights: true, clipping: true, glslVersion: T.GLSL3, wireframe: true, fog: true,
    });
    shader.extensions.clipCullDistance = true;
    shader.extensions.multiDraw = true;
    shader.defaultAttributeValues = { color: [1, 0, 0], uv: [0, 1], uv1: [0, 0] };
    shader.index0AttributeName = 'position';
    g.add(new T.Mesh(geo, shader));
    g.add(new T.Mesh(geo, new T.RawShaderMaterial({ vertexShader: 'v', fragmentShader: 'f', uniforms: { time: { value: 0 } } })));
    g.add(new T.Mesh(geo, new T.ShaderMaterial()));
    return g;
  };

  B.textures = () => {
    const g = new T.Group();
    const geo = new T.PlaneGeometry();
    const t = tex('props');
    t.name = 'tex'; t.mapping = T.CubeReflectionMapping; t.channel = 2;
    t.wrapS = T.RepeatWrapping; t.wrapT = T.MirroredRepeatWrapping; t.repeat.set(2, 3); t.offset.set(0.1, 0.2); t.center.set(0.5, 0.25); t.rotation = 0.7;
    t.magFilter = T.NearestFilter; t.minFilter = T.LinearMipmapNearestFilter; t.anisotropy = 4;
    t.format = T.RGFormat; t.internalFormat = 'RG8'; t.type = T.HalfFloatType; t.colorSpace = T.SRGBColorSpace;
    t.flipY = false; t.generateMipmaps = false; t.mipmapsAutoUpdate = false; t.premultiplyAlpha = true; t.unpackAlignment = 2;
    t.normalized = true; t.userData = { u: 'v' };
    const shareSource = new T.Texture(); shareSource.source = t.source;
    const data = dataTex(3, 2);
    data.colorSpace = T.LinearSRGBColorSpace;
    const floatData = new T.DataTexture(new Float32Array([0.5, 0.25, 0.125, 1]), 1, 1, T.RGBAFormat, T.FloatType);
    const data3d = new T.Data3DTexture(new Uint8Array(8), 2, 2, 2);
    const cubeData = new T.CubeTexture([dataTex(), dataTex(), dataTex(), dataTex(), dataTex(), dataTex()]);
    const cubeFew = new T.CubeTexture([img('a'), img('b')]);
    const empty = new T.Texture();
    const canvasLike = new T.CanvasTexture(img('canvas'));
    const depth = new T.DepthTexture(4, 4);
    depth.compareFunction = T.LessCompare;
    const maps = [t, shareSource, data, floatData, data3d, cubeData, cubeFew, empty, canvasLike, depth];
    for (const m of maps) {
      const mat = new T.MeshBasicMaterial({ map: m });
      g.add(new T.Mesh(geo, mat));
    }
    return g;
  };

  B.skinned = () => {
    const s = new T.Scene();
    const geo = new T.CylinderGeometry(0.5, 0.5, 4, 4, 4);
    const pos = geo.attributes.position;
    const idx = []; const w = [];
    for (let i = 0; i < pos.count; i++) { const y = pos.getY(i) + 2; const b = Math.floor(y / 2); idx.push(b, b + 1, 0, 0); w.push(1 - (y % 2) / 2, (y % 2) / 2, 0, 0); }
    geo.setAttribute('skinIndex', new T.Uint16BufferAttribute(idx, 4));
    geo.setAttribute('skinWeight', new T.Float32BufferAttribute(w, 4));
    const bones = [new T.Bone(), new T.Bone(), new T.Bone()];
    bones[0].name = 'root'; bones[1].position.y = 2; bones[2].position.y = 2;
    bones[0].add(bones[1]); bones[1].add(bones[2]);
    const mesh = new T.SkinnedMesh(geo, new T.MeshStandardMaterial());
    mesh.add(bones[0]);
    mesh.bindMode = T.DetachedBindMode;
    mesh.bind(new T.Skeleton(bones));
    mesh.animations.push(clip('walk'));
    s.add(mesh);
    s.animations.push(clip('scene clip'), clip('another'));
    s.add(new T.Bone());
    return s;
  };

  B.instanced = () => {
    const g = new T.Group();
    const m = new T.InstancedMesh(new T.BoxGeometry(), new T.MeshPhongMaterial(), 3);
    for (let i = 0; i < 3; i++) {
      m.setMatrixAt(i, new T.Matrix4().makeTranslation(i, i * 2, 0));
      m.setColorAt(i, new T.Color(i / 3, 0.5, 1 - i / 3));
    }
    m.count = 2;
    g.add(m);
    g.add(new T.InstancedMesh(new T.SphereGeometry(), new T.MeshBasicMaterial(), 2));
    return g;
  };

  B.batched = () => {
    const material = new T.MeshBasicMaterial();
    const b = new T.BatchedMesh(4, 200, 400, material);
    const g0 = b.addGeometry(new T.BoxGeometry());
    const g1 = b.addGeometry(new T.SphereGeometry(1, 4, 3));
    const i0 = b.addInstance(g0); b.addInstance(g1); const i2 = b.addInstance(g0);
    b.setMatrixAt(i0, new T.Matrix4().makeTranslation(1, 0, 0));
    b.setColorAt(i2, new T.Color(1, 0, 0));
    b.setVisibleAt(i2, false);
    b.deleteInstance(1);
    b.perObjectFrustumCulled = false; b.sortObjects = false;
    return b;
  };

  B.batched_bounds = () => {
    const b = new T.BatchedMesh(2, 100, 200, new T.MeshBasicMaterial());
    const g0 = b.addGeometry(new T.BoxGeometry());
    b.addInstance(g0);
    b.getBoundingBoxAt(g0, new T.Box3());
    b.getBoundingSphereAt(g0, new T.Sphere());
    b.computeBoundingBox(); b.computeBoundingSphere();
    return b;
  };

  B.lod = () => {
    const lod = new T.LOD();
    lod.autoUpdate = false;
    const geo = new T.IcosahedronGeometry(1, 0);
    lod.addLevel(new T.Mesh(geo, new T.MeshBasicMaterial()), 0);
    lod.addLevel(new T.Mesh(geo, new T.MeshBasicMaterial()), 50, 0.1);
    lod.addLevel(new T.Points(geo, new T.PointsMaterial()), 100);
    return lod;
  };

  B.misc_objects = () => {
    const s = new T.Scene();
    s.add(new T.Points(new T.BufferGeometry(), new T.PointsMaterial({ color: 0x00ff00 })));
    const morph = new T.Mesh(new T.BoxGeometry(), new T.MeshBasicMaterial());
    morph.morphTargetDictionary = { smile: 0, frown: 1, 7: 2 };
    morph.morphTargetInfluences = [0.1, 0.2, 0.3];
    s.add(morph);
    s.add(new T.Line());
    s.add(new T.Mesh());
    return s;
  };

  B.animations_only = () => {
    const o = new T.Object3D();
    o.animations.push(clip('one'));
    const child = new T.Object3D();
    child.animations.push(o.animations[0], clip('two'));
    o.add(child);
    return o;
  };

  B.materials_physical_finite = () => {
    const g = B.materials_physical();
    g.traverse((o) => { if (o.material && o.material.isMeshPhysicalMaterial) o.material.attenuationDistance = 3; });
    return g;
  };

  // Hand-written files in older or unusual forms, which only upstream's parser wrote
  // back; `__json` marks them.
  const meta = { version: 4.5, type: 'Object', generator: 'hand' };
  const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
  B.legacy_constants = () => ({ __json: {
    metadata: meta,
    images: [{ uuid: id(1), url: 'data:image/png;base64,QUJD' }, { uuid: id(2), url: [{ data: [1, 2, 3, 4], width: 1, height: 1, type: 'Uint8Array' }, 'textures/b.png', {}] }, { uuid: id(3), url: { data: [0, 0, 0, 255], width: 1, height: 1, type: 'Uint8Array' } }, { uuid: id(4), url: {} }],
    textures: [
      { uuid: id(10), image: id(1), mapping: 'EquirectangularRefractionMapping', wrap: ['RepeatWrapping', 'MirroredRepeatWrapping'], minFilter: 'NearestMipmapLinearFilter', magFilter: 'NearestFilter', name: 'old' },
      { uuid: id(11), image: id(2), anisotropy: 8 },
      { uuid: id(12), image: id(3), compareFunction: 515, flipY: true },
      { uuid: id(13), image: id(4), internalFormat: 'RGBA8', channel: 1 },
    ],
    geometries: [
      { uuid: id(20), type: 'BufferGeometry', data: { attributes: { position: { itemSize: 3, type: 'Float32Array', array: [0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0], normalized: false } }, drawcalls: [{ start: 0, count: 3, materialIndex: 1 }, { start: 3, count: 1 }] } },
      { uuid: id(21), type: 'BufferGeometry', data: { attributes: { position: { itemSize: 3, type: 'Float32Array', array: [0, 0, 0], normalized: false } }, offsets: [{ start: 0, count: 1 }] } },
      { uuid: id(22), type: 'SphereGeometry', radius: 2 },
    ],
    materials: [
      { uuid: id(30), type: 'MeshStandardMaterial', normalScale: 2, map: id(10), envMap: id(11), vertexColors: 2, depthFunc: 3 },
      { uuid: id(31), type: 'MeshPhysicalMaterial', iridescenceThicknessRange: [150, 450], attenuationDistance: 7, clearcoatNormalScale: [3, 4], map: id(12), alphaMap: id(13) },
      { uuid: id(30), type: 'MeshBasicMaterial' },
      { uuid: id(32), type: 'UnknownMaterial', color: 65280 },
    ],
    object: { uuid: id(40), type: 'Scene', background: id(10), environment: id(11), fog: { type: 'Fog', name: '', color: 255, near: 1, far: 9 }, children: [
      { uuid: id(41), type: 'Mesh', geometry: id(20), material: [id(30), id(31)], position: [1, 2, 3], rotation: [0.5, 0, 0, 'YXZ'], scale: [2, 2, 2] },
      { uuid: id(42), type: 'PointCloud', geometry: id(21), material: id(32), quaternion: [0, 0.7071067811865476, 0, 0.7071067811865476] },
      { uuid: id(43), type: 'Mesh', geometry: id(22) },
      { uuid: id(44), type: 'Mesh', material: id(30) },
      { uuid: id(45), type: 'Something', name: 'unknown type', layers: 5, visible: false },
      { uuid: id(46), type: 'DirectionalLight', color: 16711680, target: id(41), shadow: { bias: 0.5, mapSize: [256, 256], camera: { uuid: id(47), type: 'OrthographicCamera', left: -1, right: 1, top: 1, bottom: -1, near: 0.5, far: 10 } } },
      { uuid: id(48), type: 'SpotLight', shadow: { focus: 0.5, camera: { uuid: id(49), type: 'PerspectiveCamera', fov: 30 } } },
      { uuid: id(50), type: 'Sprite', center: [0, 1] },
      { uuid: id(51), type: 'LOD', levels: [{ object: id(52), distance: 3 }, { object: 'nope', distance: 9 }], children: [{ uuid: id(52), type: 'Group' }] },
      { uuid: id(53), type: 'PerspectiveCamera', fov: 45, view: { enabled: true, fullWidth: 10, fullHeight: 20, offsetX: 1, offsetY: 2, width: 3, height: 4 } },
    ] },
  } });

  B.legacy_scene_number_background = () => ({ __json: {
    metadata: meta,
    object: { uuid: id(60), type: 'Scene', background: 4210752, fog: { type: 'FogExp2', name: 'dense', color: 8421504, density: 0.2 }, userData: { 1: 'a', b: 2 } },
  } });

  // Scenes with Infinity, -Infinity and NaN, which upstream's text holds as null (see
  // nonfinite_fixtures.mjs; json_uuid_diff checks their writers).
  for (const [name, builder] of Object.entries(nonfiniteBuilders(T))) if (!builder.writerOnly) B[name] = builder;

  return B;
}
