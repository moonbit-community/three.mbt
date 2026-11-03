// Scenario specs for run.mjs. Loop modes: LoopOnce 2200, LoopRepeat 2201,
// LoopPingPong 2202. Interpolation: Discrete 2300, Linear 2301, Smooth 2302,
// Bezier 2303. Blend modes: Normal 2500, Additive 2501.

const DT = [0.016, 0.033, 0.1, 0.25, 0.4, 0.7, 1.3, 0.05, 0.9, 2.1, 0.3];
const updates = (list = DT) => list.map(dt => ['update', dt]);

const tree = {
  type: 'Group', name: 'root', children: [
    { type: 'Object3D', name: 'arm', position: [1, 2, 3], children: [
      { type: 'Mesh', name: 'hand', material: 0, morph: ['smile', 'frown', 'blink'] },
    ] },
    { type: 'PointLight', name: 'lamp' },
    { type: 'PerspectiveCamera', name: 'cam' },
  ],
};

export const scenarios = {
  transforms: {
    materials: [{ type: 'MeshStandardMaterial', name: 'skin' }],
    roots: [tree],
    clips: [{
      name: 'move', tracks: [
        { type: 'vector', name: 'arm.position', times: [0, 0.5, 1.2, 2], values: [0, 0, 0, 1, 2, 3, -1, 0.5, 2, 0, 0, 0] },
        { type: 'quaternion', name: 'arm.quaternion', times: [0, 1, 2], values: [0, 0, 0, 1, 0, 0.7071067811865476, 0, 0.7071067811865476, 0, 1, 0, 0] },
        { type: 'vector', name: 'hand.scale', times: [0, 0.7, 1.4, 2], values: [1, 1, 1, 2, 2, 2, 0.5, 1, 1.5, 1, 1, 1], interpolation: 2302 },
        { type: 'number', name: 'hand.rotation[y]', times: [0, 2], values: [0, 3.14159] },
        { type: 'bool', name: 'lamp.visible', times: [0, 0.3, 1.1], values: [true, false, true] },
        { type: 'string', name: 'cam.name', times: [0, 1], values: ['cam', 'cam2'] },
        { type: 'number', name: '.renderOrder', times: [0, 2], values: [0, 10], interpolation: 2300 },
        { type: 'bool', name: 'hand.castShadow', times: [0, 1], values: [false, true] },
      ],
    }],
    ops: [['action', 0], ['play', 0], ...updates(), ['stop', 0]],
  },

  skinned: {
    materials: [{ type: 'MeshBasicMaterial' }],
    roots: [{
      type: 'SkinnedMesh', name: 'body', material: 0, skeleton: ['Hips', 'Spine', 'Head'], children: [
        { type: 'Bone', name: 'Hips', position: [0, 1, 0], children: [
          { type: 'Bone', name: 'Spine', position: [0, 0.5, 0], children: [
            { type: 'Bone', name: 'Head', position: [0, 0.4, 0] },
          ] },
        ] },
      ],
    }],
    clips: [{
      name: 'walk', duration: 1.5, tracks: [
        { type: 'vector', name: '.bones[Hips].position', times: [0, 0.75, 1.5], values: [0, 1, 0, 0, 1.2, 0.3, 0, 1, 0] },
        { type: 'quaternion', name: '.bones[Spine].quaternion', times: [0, 0.75, 1.5], values: [0, 0, 0, 1, 0.3826834323650898, 0, 0, 0.9238795325112867, 0, 0, 0, 1] },
        { type: 'quaternion', name: 'Head.quaternion', times: [0, 1.5], values: [0, 0, 0, 1, 0, 0.5, 0, 0.8660254037844386] },
        { type: 'vector', name: '.bones[1].scale', times: [0, 1.5], values: [1, 1, 1, 1.5, 1.5, 1.5] },
      ],
    }],
    ops: [['listen', 'loop', 'log'], ['listen', 'finished', 'log'], ['action', 0], ['setLoop', 0, 2202, 3], ['set', 0, 'clampWhenFinished', true], ['play', 0],
      ...updates([0.3, 0.6, 0.9, 1.2, 0.7, 2.5, 0.4, 1.1, 0.2]), ['stopAllAction']],
  },

  morph: {
    materials: [{ type: 'MeshStandardMaterial' }],
    roots: [{ type: 'Mesh', name: 'face', material: 0, morph: ['smile', 'frown', 'blink'] }],
    clips: [
      { name: 'expr', tracks: [
        { type: 'number', name: '.morphTargetInfluences[smile]', times: [0, 1, 2], values: [0, 1, 0] },
        { type: 'number', name: '.morphTargetInfluences[2]', times: [0, 0.5, 1], values: [0, 1, 0.25], interpolation: 2302 },
      ] },
      { name: 'all', tracks: [
        { type: 'vector', name: '.morphTargetInfluences', times: [0, 1], values: [0, 0, 0, 1, 0.5, 0.25] },
      ] },
    ],
    clipOps: [['fromMorph', 'seq', ['smile', 'frown', 'blink'], 4, false], ['fromMorph', 'seqNoLoop', ['smile', 'frown'], 10, true]],
    ops: [['listen', 'finished', 'log'], ['action', 0], ['setLoop', 0, 2200, null], ['play', 0], ['action', 1], ['setEffectiveWeight', 1, 0.5], ['play', 1],
      ['action', 2], ['play', 2], ...updates([0.2, 0.3, 0.4, 0.5, 0.6, 1.0, 0.25]), ['stop', 0], ['update', 0.1]],
  },

  materials: {
    materials: [
      { type: 'MeshStandardMaterial', name: 'a', map: true },
      { type: 'MeshPhysicalMaterial', name: 'b' },
      { type: 'MeshBasicMaterial', name: 'c' },
    ],
    roots: [{ type: 'Scene', name: 'scene', fog: 'Fog', children: [
      { type: 'Mesh', name: 'one', material: 0 },
      { type: 'Mesh', name: 'multi', material: [1, 2] },
      { type: 'SpotLight', name: 'spot' },
      { type: 'HemisphereLight', name: 'hemi' },
      { type: 'OrthographicCamera', name: 'ortho' },
    ] }],
    clips: [{
      name: 'mat', tracks: [
        { type: 'number', name: 'one.material.opacity', times: [0, 1], values: [1, 0] },
        { type: 'color', name: 'one.material.color', times: [0, 1], values: [1, 1, 1, 0.2, 0.4, 0.6] },
        { type: 'number', name: 'one.material.emissive[g]', times: [0, 1], values: [0, 1] },
        { type: 'number', name: 'one.material.roughness', times: [0, 0.4, 1], values: [1, 0.2, 0.5], interpolation: 2302 },
        { type: 'number', name: 'one.material[metalness]', times: [0, 1], values: [0, 1] },
        { type: 'bool', name: 'one.material.transparent', times: [0, 0.5], values: [false, true] },
        { type: 'number', name: 'one.material.alphaTest', times: [0, 0.5, 1], values: [0, 0.5, 0] },
        { type: 'vector', name: 'one.map.offset', times: [0, 1], values: [0, 0, 0.5, 0.25] },
        { type: 'number', name: 'one.map.rotation', times: [0, 1], values: [0, 1] },
        { type: 'number', name: 'multi.material[0].opacity', times: [0, 1], values: [1, 0.5] },
        { type: 'number', name: 'multi.material[0].sheen', times: [0, 1], values: [0, 1] },
        { type: 'number', name: 'multi.material[1].opacity', times: [0, 1], values: [0.5, 1] },
        { type: 'number', name: 'spot.intensity', times: [0, 1], values: [1, 5] },
        { type: 'number', name: 'spot.angle', times: [0, 1], values: [0.5, 1] },
        { type: 'number', name: 'spot.penumbra', times: [0, 1], values: [0, 1] },
        { type: 'color', name: 'spot.color', times: [0, 1], values: [1, 1, 1, 1, 0, 0] },
        { type: 'number', name: 'spot.shadow[bias]', times: [0, 1], values: [0, -0.01] },
        { type: 'color', name: 'hemi.groundColor', times: [0, 1], values: [0, 0, 0, 1, 1, 0] },
        { type: 'number', name: 'ortho.zoom', times: [0, 1], values: [1, 2] },
        { type: 'number', name: 'ortho.left', times: [0, 1], values: [-1, -5] },
        { type: 'number', name: '.fog[far]', times: [0, 1], values: [100, 50] },
        { type: 'number', name: '.backgroundIntensity', times: [0, 1], values: [1, 0] },
        // not found: logged, and the binding does nothing
        { type: 'number', name: 'multi.material[1].roughness', times: [0, 1], values: [0, 1] },
        { type: 'number', name: 'nobody.position[x]', times: [0, 1], values: [0, 1] },
        { type: 'number', name: 'one.materials[0].opacity', times: [0, 1], values: [0, 1] },
        { type: 'number', name: 'one.bones[0].opacity', times: [0, 1], values: [0, 1] },
        { type: 'number', name: 'multi.material[5].opacity', times: [0, 1], values: [0, 1] },
        { type: 'number', name: '.morphTargetInfluences[0]', times: [0, 1], values: [0, 1] },
        { type: 'number', name: 'one.position[w]', times: [0, 1], values: [0, 1] },
      ],
    }],
    ops: [['action', 0], ['play', 0], ...updates([0.1, 0.2, 0.3, 0.4, 0.5]), ['stop', 0], ['update', 0.1]],
  },

  crossfade: {
    roots: [{ type: 'Object3D', name: 'o', children: [{ type: 'Object3D', name: 'p' }] }],
    clips: [
      { name: 'a', duration: 1, tracks: [
        { type: 'vector', name: '.position', times: [0, 1], values: [0, 0, 0, 10, 0, 0] },
        { type: 'quaternion', name: 'p.quaternion', times: [0, 1], values: [0, 0, 0, 1, 1, 0, 0, 0] },
      ] },
      { name: 'b', duration: 2.5, tracks: [
        { type: 'vector', name: '.position', times: [0, 2.5], values: [0, 5, 0, 0, -5, 3] },
        { type: 'quaternion', name: 'p.quaternion', times: [0, 2.5], values: [0, 0, 1, 0, 0, 1, 0, 0] },
      ] },
    ],
    ops: [['listen', 'loop', 'log'], ['action', 0], ['action', 1], ['play', 0], ...updates([0.3, 0.4]),
      ['crossFadeTo', 0, 1, 1.2, true], ['play', 1], ...updates([0.1, 0.3, 0.5, 0.7, 0.2, 1.5]),
      ['crossFadeFrom', 0, 1, 0.8, false], ['play', 0], ...updates([0.25, 0.25, 0.5, 0.25]),
      ['setEffectiveTimeScale', 0, -0.5], ['update', 0.4], ['halt', 0, 0.6], ...updates([0.2, 0.3, 0.4]),
      ['syncWith', 1, 0], ['warp', 1, 2, 0.5, 1], ['update', 0.5], ['setDuration', 1, 0.5], ['update', 0.6],
      ['mixerTimeScale', 2], ['update', 0.3], ['setTime', 1.7], ['stopFading', 0], ['stopWarping', 1], ['update', 0.2]],
  },

  additive: {
    roots: [{ type: 'Object3D', name: 'o' }],
    clips: [
      { name: 'base', tracks: [
        { type: 'vector', name: '.position', times: [0, 1, 2], values: [0, 0, 0, 1, 0, 0, 0, 0, 0] },
        { type: 'quaternion', name: '.quaternion', times: [0, 2], values: [0, 0, 0, 1, 0, 0.7071067811865476, 0, 0.7071067811865476] },
      ] },
      { name: 'wave', tracks: [
        { type: 'vector', name: '.position', times: [0, 0.5, 1], values: [0, 1, 0, 0, 2, 0, 0, 1.5, 0] },
        { type: 'quaternion', name: '.quaternion', times: [0, 1], values: [0, 0, 0.3826834323650898, 0.9238795325112867, 0.3826834323650898, 0, 0, 0.9238795325112867] },
        { type: 'number', name: '.scale[x]', times: [0, 1], values: [1, 3] },
      ] },
      { name: 'wave2', blendMode: 2501, tracks: [
        { type: 'vector', name: '.scale', times: [0, 1], values: [0, 0, 0, 0.5, 0.5, 0.5] },
      ] },
    ],
    clipOps: [['makeAdditive', 1, 0, null, 30]],
    ops: [['action', 0], ['action', 1], ['action', 2], ['action', 0, null, 2501], ['play', 0], ['play', 1], ['setEffectiveWeight', 1, 0.6], ['play', 2],
      ...updates([0.2, 0.5, 0.3, 0.8]), ['fadeOut', 1, 0.5], ...updates([0.1, 0.2, 0.3, 0.4]), ['play', 3], ['update', 0.3], ['stop', 0], ['update', 0.2]],
  },

  reverse: {
    roots: [{ type: 'Object3D', name: 'o', children: [{ type: 'Object3D', name: 'q' }] }],
    clips: [
      { name: 'r', duration: 0.75, tracks: [{ type: 'number', name: '.rotation[x]', times: [0, 0.75], values: [0, 270] }] },
      { name: 'u', duration: 1, tracks: [{ type: 'vector', name: 'q.position', times: [0, 1], values: [0, 0, 0, 1, 1, 1] }] },
    ],
    ops: [['listen', 'finished', 'reverse'], ['listen', 'loop', 'log'], ['action', 0], ['setLoop', 0, 2200, null], ['set', 0, 'clampWhenFinished', true], ['play', 0],
      ...updates([0.25, 0.25, 0.25, 0.5, 0.25, 0.25, 0.25, 0.001, 1, 1, 0.25, 0.25]),
      ['action', 1], ['set', 1, 'zeroSlopeAtStart', false], ['set', 1, 'zeroSlopeAtEnd', false], ['setLoop', 1, 2201, 'Infinity'], ['startAt', 1, 7], ['play', 1],
      ['mixerTimeScale', -1], ...updates([0.3, 0.4, 0.5, 0.2]), ['mixerTimeScale', 1], ...updates([0.3, 1.4, 0.1]), ['update', 0],
      ['set', 1, 'paused', true], ['update', 0.3], ['set', 1, 'paused', false], ['set', 1, 'timeScale', 0], ['update', 0.3],
      ['uncacheAction', 1], ['update', 0.2], ['play', 1], ['update', 0.2], ['uncacheRoot'], ['update', 0.1]],
  },

  bezier: {
    roots: [{ type: 'Object3D', name: 'o' }],
    clips: [{ name: 'bz', tracks: [
      { type: 'number', name: '.position[y]', times: [0, 1, 3], values: [0, 2, -1], interpolation: 2303,
        settings: { inTangents: [-0.3, 0, 0.7, 2.5, 2.2, -1], outTangents: [0.3, 0.5, 1.6, 1.5, 3.3, -1] } },
      { type: 'vector', name: '.scale', times: [0, 1, 2], values: [1, 1, 1, 2, 3, 4, 1, 1, 1], interpolation: 2302 },
    ] }],
    clipOps: [['evaluate', 0, 0, [-1, 0, 0.25, 0.5, 0.99, 1, 1.5, 2.9, 3, 4, 0.1]], ['evaluate', 0, 1, [0, 0.3, 1.5, 2, 0.6, 5, -2]], ['clone', 0], ['roundTrip', 1]],
    ops: [['action', 0], ['setLoop', 0, 2202, 'Infinity'], ['play', 0], ...updates()],
  },

  group: {
    roots: [{ type: 'Object3D', name: 'w', children: [
      { type: 'Object3D', name: 'g1' }, { type: 'Object3D', name: 'g2', position: [3, 3, 3] }, { type: 'Mesh', name: 'g3', material: 0 },
    ] }],
    materials: [{ type: 'MeshBasicMaterial' }],
    group: ['g1', 'g2', 'g3'],
    clips: [{ name: 'gc', tracks: [
      { type: 'vector', name: '.position', times: [0, 1], values: [0, 0, 0, 1, 2, 3] },
      { type: 'number', name: '.scale[z]', times: [0, 1], values: [1, 4] },
    ] }],
    ops: [['action', 0], ['play', 0], ...updates([0.25, 0.5]), ['stop', 0], ['update', 0.1], ['play', 0], ['update', 0.3]],
  },

  groupCache: {
    roots: [{ type: 'Object3D', name: 'w', children: [
      { type: 'Object3D', name: 'g1', position: [5, 0, 0] }, { type: 'Object3D', name: 'g2', position: [3, 3, 3] },
      { type: 'Object3D', name: 'g3', position: [0, 7, 0] }, { type: 'Object3D', name: 'g4' },
    ] }],
    group: ['g1', 'g2', 'g3'],
    clips: [{ name: 'gc', tracks: [
      { type: 'vector', name: '.position', times: [0, 1], values: [0, 0, 0, 1, 2, 3] },
      { type: 'quaternion', name: '.quaternion', times: [0, 1], values: [0, 0, 0, 1, 0, 1, 0, 0] },
    ] }],
    ops: [['groupRemove', ['g1']], ['action', 0], ['play', 0], ['update', 0.25], ['groupAdd', ['g4', 'g1']], ['update', 0.25],
      ['groupRemove', ['g2', 'g3']], ['update', 0.2], ['groupAdd', ['g1']], ['groupUncache', ['g2']], ['groupAdd', ['g3']], ['update', 0.1],
      ['stop', 0], ['update', 0.1], ['groupUncache', ['g4', 'g1']], ['play', 0], ['update', 0.3], ['groupRemove', ['g3']], ['stop', 0], ['update', 0.1]],
  },

  skeletonLookup: {
    materials: [{ type: 'MeshBasicMaterial' }],
    roots: [
      { type: 'SkinnedMesh', name: 'body', material: 0, skeleton: ['H2', 'S2'] },
      { type: 'Bone', name: 'H2', children: [{ type: 'Bone', name: 'S2', position: [0, 1, 0] }] },
    ],
    clips: [{ name: 'k', tracks: [
      { type: 'vector', name: 'H2.position', times: [0, 1], values: [0, 0, 0, 1, 1, 1] },
      { type: 'quaternion', name: 'S2.quaternion', times: [0, 1], values: [0, 0, 0, 1, 0, 0, 1, 0] },
      { type: 'vector', name: '.bones[S2].scale', times: [0, 1], values: [1, 1, 1, 2, 2, 2] },
    ] }],
    ops: [['action', 0], ['play', 0], ...updates([0.3, 0.3])],
  },

  byName: {
    roots: [{ type: 'Object3D', name: 'o' }],
    rootAnimations: true,
    clips: [{ name: 'idle', tracks: [{ type: 'number', name: '.position[x]', times: [0, 1], values: [0, 1] }] }],
    ops: [['actionByName', 'idle'], ['actionByName', 'missing'], ['play', 0], ['update', 0.5], ['action', 0], ['uncacheClip', 0], ['update', 0.5], ['play', 0], ['update', 0.2]],
  },

  utils: {
    roots: [{ type: 'Object3D', name: 'o' }],
    clips: [
      { name: 'long', tracks: [
        { type: 'vector', name: '.position', times: [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6], values: [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0, 1, 2, 0, 1] },
        { type: 'number', name: '.position[x]', times: [0, 0.1, 0.1, 0.2, 0.3, 0.4], values: [5, 5, 5, 5, 6, 6] },
        { type: 'quaternion', name: '.quaternion', times: [0, 0.3, 0.6], values: [0, 0, 0, 1, 0, 0.6, 0, 0.8, 0, 0, 0, 1] },
        { type: 'bool', name: '.visible', times: [0, 0.2, 0.4, 0.6], values: [true, true, false, false] },
        { type: 'string', name: '.name', times: [0, 0.2, 0.4], values: ['a', 'a', 'b'] },
        { type: 'number', name: '.renderOrder', times: [0, 0.2, 0.25, 0.4], values: [1, 2, 2, 3], interpolation: 2302 },
      ] },
      { name: 'ref', tracks: [
        { type: 'quaternion', name: '.quaternion', times: [0, 1], values: [0, 0.2, 0, 0.9797958971132712, 0, 0.4, 0, 0.916515138991168] },
        { type: 'vector', name: '.position', times: [0, 1], values: [1, 2, 3, 4, 5, 6] },
      ] },
      { name: 'bad', tracks: [
        { type: 'number', name: '.a', times: [0, 2, 1], values: [0, 1, 2] },
        { type: 'number', name: '.b', times: [0, 1], values: [0, 'NaN'] },
        { type: 'vector', name: '.c', times: [0, 1], values: [0, 1, 2] },
      ] },
    ],
    clipOps: [
      ['validate', 0], ['validate', 2], ['trackValidate', 2, 0], ['trackValidate', 2, 1], ['trackValidate', 2, 2],
      ['subclip', 0, 'sub', 2, 5, 10], ['subclip', 0, 'sub30', 1, 13, 30],
      ['clone', 0], ['makeAdditive', 3, 7, 1, 30], ['makeAdditive', 0, 3, null, 0],
      ['optimize', 0], ['trackScale', 1, 0, 2.5], ['trackShift', 1, 1, -0.3], ['trackTrim', 1, 0, 0.5, 1.2], ['trackTrim', 1, 1, 5, 6],
      ['trackOptimize', 1, 0], ['resetDuration', 1], ['trim', 3], ['trackInterpolation', 0, 2, 2302], ['trackInterpolation', 0, 3, 2301],
      ['trackInterpolation', 0, 0, 2300], ['roundTrip', 0], ['roundTrip', 2],
      ['fromMorphs', ['Walk_001', 'Walk_002', 'run1_3', 'run1_4', 'crdeath0059', 'x', '12', 'Walk_003'], 8, false],
      ['keyframeOrder', [3, 1, 2, 1, 0, 2], [30, 31, 10, 11, 20, 21, 12, 13, 0, 1, 22, 23], 2],
    ],
  },

  rotationWhole: {
    roots: [{ type: 'Object3D', name: 'o' }],
    clips: [{ name: 'q', tracks: [
      { type: 'vector', name: '.up', times: [0, 1], values: [0, 1, 0, 1, 0, 0] },
      { type: 'base', name: '.position[z]', times: [0, 1], values: [0, 2] },
    ] }],
    ops: [['action', 0], ['play', 0], ['update', 0.5], ['update', 0.3]],
  },
};

// --- random scenarios --------------------------------------------------------------

function rng(seed) {
  let s = seed >>> 0 || 1;
  return () => { s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
}

export function randomScenario(seed) {
  const r = rng(seed * 2654435761);
  const pick = a => a[Math.floor(r() * a.length)];
  const num = (lo, hi) => Math.round((lo + (hi - lo) * r()) * 1000) / 1000;
  const times = () => {
    const n = 1 + Math.floor(r() * 5);
    const t = [];
    let x = r() < 0.3 ? num(0, 0.5) : 0;
    for (let i = 0; i < n; i++) { t.push(x); x += r() < 0.1 ? 0 : num(0.05, 1.2); }
    return t;
  };
  const targets = [
    ['vector', 3, 'a.position'], ['vector', 3, 'b.scale'], ['quaternion', 4, 'a.quaternion'], ['quaternion', 4, '.bones[B1].quaternion'],
    ['number', 1, 'b.rotation[z]'], ['number', 1, '.morphTargetInfluences[m1]'], ['number', 1, 'm.morphTargetInfluences[0]'],
    ['color', 3, 'm.material.color'], ['number', 1, 'm.material.opacity'], ['bool', 1, 'b.visible'], ['string', 1, 'a.name'],
    ['number', 1, 'l.intensity'], ['vector', 3, '.bones[B2].position'], ['number', 1, 'c.fov'], ['bool', 1, 'm.material.wireframe'],
  ];
  const quat = () => { const q = [num(-1, 1), num(-1, 1), num(-1, 1), num(-1, 1)]; const l = Math.hypot(...q) || 1; return q.map(x => x / l); };
  const track = () => {
    const [type, size, name] = pick(targets);
    const t = times();
    const values = [];
    for (let i = 0; i < t.length; i++) {
      if (type === 'quaternion') values.push(...quat());
      else if (type === 'bool') values.push(r() < 0.5);
      else if (type === 'string') values.push(pick(['p', 'q', 'r']));
      else for (let j = 0; j < size; j++) values.push(num(-3, 3));
    }
    const spec = { type, name, times: t, values };
    if (type !== 'bool' && type !== 'string' && r() < 0.4) spec.interpolation = pick(type === 'quaternion' ? [2300, 2301] : [2300, 2301, 2302]);
    return spec;
  };
  const clips = [];
  const nClips = 1 + Math.floor(r() * 3);
  for (let i = 0; i < nClips; i++) {
    const tracks = [];
    const nTracks = 1 + Math.floor(r() * 4);
    for (let j = 0; j < nTracks; j++) tracks.push(track());
    const clip = { name: 'c' + i, tracks };
    if (r() < 0.4) clip.duration = num(0.2, 3);
    if (r() < 0.2) clip.blendMode = 2501;
    clips.push(clip);
  }
  const ops = [['listen', 'loop', 'log'], ['listen', 'finished', r() < 0.2 ? 'reverse' : 'log']];
  for (let i = 0; i < nClips; i++) ops.push(['action', i]);
  const nActions = nClips;
  // clip edits before playing
  const clipOps = [];
  const nEdits = Math.floor(r() * 4);
  for (let k = 0; k < nEdits; k++) {
    const c = Math.floor(r() * nClips);
    const t = Math.floor(r() * clips[c].tracks.length);
    const y = r();
    if (y < 0.15) clipOps.push(['trackOptimize', c, t]);
    else if (y < 0.3) clipOps.push(['trackScale', c, t, num(0.2, 3)]);
    else if (y < 0.45) clipOps.push(['trackShift', c, t, num(-1, 1)]);
    else if (y < 0.6) clipOps.push(['trackTrim', c, t, num(0, 1), num(0.5, 3)]);
    else if (y < 0.7) clipOps.push(['trackValidate', c, t]);
    else if (y < 0.75) clipOps.push(['trim', c]);
    else if (y < 0.8) clipOps.push(['resetDuration', c]);
    else if (y < 0.85) clipOps.push(['roundTrip', c]);
    // bool / string interpolants hold encoded values in the port (known deviation)
    else if (y < 0.9 && !['bool', 'string'].includes(clips[c].tracks[t].type)) clipOps.push(['evaluate', c, t, [num(-1, 4), num(0, 2), num(0, 2), num(2, 6)]]);
    else clipOps.push(['makeAdditive', c, num(0, 40), r() < 0.5 ? null : Math.floor(r() * nClips), pick([30, 24, 0, 60])]);
  }
  for (let k = 0; k < 30; k++) {
    const a = Math.floor(r() * nActions);
    const b = Math.floor(r() * nActions);
    const x = r();
    if (x < 0.4) ops.push(['update', r() < 0.1 ? -num(0, 0.5) : num(0, 0.8)]);
    else if (x < 0.5) ops.push(['play', a]);
    else if (x < 0.53) ops.push(['stop', a]);
    else if (x < 0.57) ops.push(['setLoop', a, pick([2200, 2201, 2202]), pick([null, 'Infinity', 0, 1, 2, 3])]);
    else if (x < 0.6) ops.push(['set', a, pick(['clampWhenFinished', 'paused', 'enabled', 'zeroSlopeAtStart', 'zeroSlopeAtEnd']), r() < 0.5]);
    else if (x < 0.63) ops.push(['set', a, pick(['timeScale', 'weight', 'time']), num(-1, 2)]);
    else if (x < 0.66) ops.push([pick(['fadeIn', 'fadeOut', 'halt', 'setDuration']), a, num(0.1, 2)]);
    else if (x < 0.69) ops.push([pick(['crossFadeTo', 'crossFadeFrom']), a, b, num(0.1, 2), r() < 0.5]);
    else if (x < 0.71) ops.push(['warp', a, num(0, 2), num(0, 2), num(0.1, 2)]);
    else if (x < 0.73) ops.push(['setEffectiveWeight', a, num(0, 1)]);
    else if (x < 0.75) ops.push(['setEffectiveTimeScale', a, num(-1, 2)]);
    else if (x < 0.77) ops.push(['startAt', a, num(0, 3)]);
    else if (x < 0.79) ops.push(['syncWith', a, b]);
    else if (x < 0.81) ops.push(['reset', a]);
    else if (x < 0.83) ops.push(['mixerTimeScale', pick([1, 1, 0.5, 2, -1])]);
    else if (x < 0.85) ops.push(['setTime', num(0, 4)]);
    else if (x < 0.86) ops.push(['stopAllAction']);
    else if (x < 0.87) ops.push([pick(['stopFading', 'stopWarping']), a]);
    else if (x < 0.875) ops.push(['uncacheAction', a]);
    else if (x < 0.88) ops.push(['uncacheClip', a]);
    else if (x < 0.885) ops.push(['uncacheRoot', r() < 0.5 ? 'a' : undefined]);
    else if (x < 0.895) ops.push(['action', a, r() < 0.5 ? 'a' : null, pick([2500, 2501])]);
    else ops.push(['update', num(0, 0.4)]);
  }
  return {
    materials: [{ type: 'MeshStandardMaterial', name: 'mm' }],
    roots: [{
      type: 'SkinnedMesh', name: 'm', material: 0, morph: ['m0', 'm1'], skeleton: ['B1', 'B2'], children: [
        { type: 'Bone', name: 'B1', children: [{ type: 'Bone', name: 'B2', position: [0, 1, 0] }] },
        { type: 'Object3D', name: 'a', children: [{ type: 'Object3D', name: 'b' }] },
        { type: 'PointLight', name: 'l' },
        { type: 'PerspectiveCamera', name: 'c' },
      ],
    }],
    clips,
    clipOps,
    ops,
  };
}

// AnimationUtils and track edits on random clips, without a mixer.
export function randomUtilsScenario(seed) {
  const base = randomScenario(seed);
  const r = rng(seed * 40503 + 7);
  const num = (lo, hi) => Math.round((lo + (hi - lo) * r()) * 1000) / 1000;
  const n = base.clips.length;
  const ops = [];
  for (let k = 0; k < 8; k++) {
    const c = Math.floor(r() * (n + ops.filter(o => o[0] === 'subclip' || o[0] === 'clone').length));
    const y = r();
    if (y < 0.2) ops.push(['subclip', c, 's' + k, num(0, 20), num(5, 60), [30, 24, 10][Math.floor(r() * 3)]]);
    else if (y < 0.35) ops.push(['makeAdditive', c, num(0, 40), r() < 0.5 ? null : Math.floor(r() * n), [30, 24, -1][Math.floor(r() * 3)]]);
    else if (y < 0.5) ops.push(['optimize', c]);
    else if (y < 0.6) ops.push(['validate', c]);
    else if (y < 0.7) ops.push(['clone', c]);
    else if (y < 0.8) ops.push(['roundTrip', c]);
    else if (y < 0.9) ops.push(['trim', c]);
    else ops.push(['resetDuration', c]);
  }
  const t = [];
  for (let i = 0; i < 6; i++) t.push(Math.floor(r() * 4));
  ops.push(['keyframeOrder', t, t.flatMap((x, i) => [x, i]), 2]);
  return { roots: base.roots, materials: base.materials, clips: base.clips, clipOps: ops };
}

// A mixer on an AnimationObjectGroup.
export function randomGroupScenario(seed) {
  const base = randomScenario(seed);
  for (const clip of base.clips) {
    for (const tr of clip.tracks) tr.name = tr.name.replace(/^[a-z]?\.bones\[B\d\]|^[abmlc]\./, '.').replace(/^\.\./, '.');
    clip.tracks = clip.tracks.filter(tr => !/morph|material|intensity|fov/.test(tr.name));
    if (clip.tracks.length === 0) clip.tracks.push({ type: 'vector', name: '.position', times: [0, 1], values: [0, 0, 0, 1, 1, 1] });
  }
  base.roots = [{ type: 'Object3D', name: 'w', children: [
    { type: 'Object3D', name: 'g1' }, { type: 'Object3D', name: 'g2', position: [1, 2, 3] }, { type: 'Bone', name: 'g3' },
    { type: 'Object3D', name: 'g4', scale: [2, 2, 2] },
  ] }];
  base.group = ['g1', 'g2', 'g3'];
  base.ops = base.ops.filter(o => !['uncacheAction', 'uncacheClip', 'uncacheRoot'].includes(o[0]) && !(o[0] === 'action' && o[2]));
  const r = rng(seed * 7919 + 3);
  const names = ['g1', 'g2', 'g3', 'g4'];
  const some = () => names.filter(() => r() < 0.4);
  for (let k = 0; k < 6; k++) {
    const at = 2 + Math.floor(r() * (base.ops.length - 2));
    base.ops.splice(at, 0, [['groupAdd', 'groupRemove', 'groupUncache'][Math.floor(r() * 3)], some()]);
  }
  delete base.clipOps;
  return base;
}

// --- the binding table -------------------------------------------------------------
// Reads (getValue) and writes (setValue) every property of the port's binding table
// through PropertyBinding on both sides, plus names that resolve to `undefined`.

const tableProps = [];
const P = (path, size = 1) => tableProps.push([path, size]);
for (const node of ['m', 'b']) {
  P(node + '.position', 3); P(node + '.scale', 3); P(node + '.up', 3); P(node + '.quaternion', 4);
  P(node + '.matrix', 16); P(node + '.matrixWorld', 16);
  for (const f of ['visible', 'castShadow', 'receiveShadow', 'frustumCulled', 'matrixAutoUpdate', 'matrixWorldAutoUpdate', 'matrixWorldNeedsUpdate', 'renderOrder']) P(node + '.' + f);
  for (const k of ['x', 'y', 'z']) { P(node + '.position[' + k + ']'); P(node + '.scale[' + k + ']'); P(node + '.rotation[' + k + ']'); P(node + '.up[' + k + ']'); }
  for (const k of ['x', 'y', 'z', 'w']) P(node + '.quaternion[' + k + ']');
  P(node + '.position[w]'); P(node + '.quaternion[0]'); P(node + '.rotation[w]');
}
P('m.morphTargetInfluences', 2); P('m.morphTargetInfluences[1]'); P('m.morphTargetInfluences[m0]'); P('m.morphTargetInfluences[nope]');
P('.children[0].position', 3); P('.children[1].scale[y]'); P('uuid-b.position', 3); P('uuid-b.quaternion[z]');
P('.bones[B].position', 3); P('.bones[B].quaternion', 4); P('.bones[0].scale[x]');
const materialNumbers = ['opacity', 'alphaTest', 'blendAlpha', 'polygonOffsetFactor', 'polygonOffsetUnits', 'lightMapIntensity', 'aoMapIntensity', 'envMapIntensity',
  'displacementScale', 'displacementBias', 'emissiveIntensity', 'bumpScale', 'roughness', 'metalness', 'anisotropyRotation', 'clearcoatRoughness', 'ior',
  'iridescenceIOR', 'sheenRoughness', 'thickness', 'attenuationDistance', 'specularIntensity', 'reflectivity', 'anisotropy', 'clearcoat', 'dispersion',
  'iridescence', 'sheen', 'transmission', 'diffuseRoughness', 'retroreflectivity', 'shininess', 'refractionRatio', 'wireframeLinewidth', 'linewidth',
  'scale', 'dashSize', 'gapSize', 'size', 'rotation'];
const materialFlags = ['transparent', 'alphaHash', 'vertexColors', 'depthTest', 'depthWrite', 'stencilWrite', 'clipIntersection', 'clipShadows', 'colorWrite',
  'polygonOffset', 'dithering', 'alphaToCoverage', 'premultipliedAlpha', 'forceSinglePass', 'allowOverride', 'visible', 'toneMapped', 'fog', 'wireframe',
  'flatShading', 'sizeAttenuation'];
const materialColors = ['blendColor', 'color', 'emissive', 'specular', 'sheenColor', 'attenuationColor', 'specularColor'];
for (const node of ['m', 'phong', 'dash', 'pts', 'spr']) {
  for (const f of materialNumbers) P(node + '.material.' + f);
  for (const f of materialFlags) P(node + '.material.' + f);
  for (const f of materialColors) { P(node + '.material.' + f, 3); P(node + '.material.' + f + '[g]'); }
  P(node + '.material.normalScale', 2); P(node + '.material.clearcoatNormalScale', 2); P(node + '.material.normalScale[y]');
  P(node + '.material.envMapRotation[x]'); P(node + '.material[opacity]'); P(node + '.material[roughness]');
}
P('multi.material[0].opacity'); P('multi.material[1].color', 3); P('multi.material[2].opacity'); P('multi.material.opacity');
for (const f of ['offset', 'repeat', 'center']) { P('m.map.' + f, 2); P('m.map.' + f + '[x]'); }
for (const f of ['rotation', 'flipY', 'matrixAutoUpdate', 'premultiplyAlpha', 'generateMipmaps']) P('m.map.' + f);
P('m.map.matrix', 9); P('spot.map.offset', 2); P('spr.center', 2); P('spr.center[y]');
for (const l of ['point', 'spot', 'dir', 'hemi', 'rect', 'probe']) {
  P(l + '.intensity'); P(l + '.color', 3); P(l + '.color[b]'); P(l + '.power'); P(l + '.distance'); P(l + '.decay'); P(l + '.angle'); P(l + '.penumbra');
  P(l + '.groundColor', 3); P(l + '.width'); P(l + '.height'); P(l + '.shadow[bias]'); P(l + '.shadow[normalBias]'); P(l + '.shadow[radius]'); P(l + '.shadow[intensity]');
}
P('probe.sh', 27); P('spot.target[visible]'); P('dir.target[renderOrder]');
for (const c of ['persp', 'ortho']) for (const f of ['fov', 'zoom', 'near', 'far', 'focus', 'aspect', 'filmGauge', 'filmOffset', 'left', 'right', 'top', 'bottom']) P(c + '.' + f);
for (const f of ['backgroundBlurriness', 'backgroundIntensity', 'environmentIntensity', 'fog[near]', 'fog[far]', 'fog[density]', 'backgroundRotation[x]', 'environmentRotation[z]']) P('.' + f);
P('lod.autoUpdate'); P('clip.enabled'); P('clip.clipIntersection'); P('clip.clipShadows'); P('m.autoUpdate'); P('m.enabled');

const tableOps = [];
for (const [path, size] of tableProps) {
  tableOps.push(['probe', path, size]);
  // booleans are written as 0 / 1: the port's Bool fields cannot hold other numbers
  const pokes = size === 1 ? [[0], [1]] : [Array.from({ length: size }, (_, i) => 0.5 + 0.25 * i)];
  for (const values of pokes) {
    tableOps.push(['poke', path, values]);
    tableOps.push(['probe', path, size]);
  }
}

scenarios.table = {
  materials: [
    { type: 'MeshPhysicalMaterial', name: 'phys', map: true }, { type: 'MeshPhongMaterial' }, { type: 'LineDashedMaterial' },
    { type: 'PointsMaterial' }, { type: 'SpriteMaterial' }, { type: 'MeshLambertMaterial' }, { type: 'LineBasicMaterial' },
  ],
  roots: [{ type: 'Scene', name: 'scene', fog: 'Fog', children: [
    { type: 'SkinnedMesh', name: 'm', material: 0, morph: ['m0', 'm1'], skeleton: ['B'], children: [{ type: 'Bone', name: 'B' }] },
    { type: 'Object3D', name: 'b', uuid: 'uuid-b', position: [1, 2, 3] },
    { type: 'Mesh', name: 'phong', material: 1 },
    { type: 'Line', name: 'dash', material: 2 },
    { type: 'Points', name: 'pts', material: 3 },
    { type: 'Sprite', name: 'spr', material: 4 },
    { type: 'Mesh', name: 'multi', material: [5, 6] },
    { type: 'PointLight', name: 'point' }, { type: 'SpotLight', name: 'spot', spotMap: true }, { type: 'DirectionalLight', name: 'dir' },
    { type: 'HemisphereLight', name: 'hemi' }, { type: 'RectAreaLight', name: 'rect' }, { type: 'LightProbe', name: 'probe' },
    { type: 'PerspectiveCamera', name: 'persp' }, { type: 'OrthographicCamera', name: 'ortho' },
    { type: 'LOD', name: 'lod' }, { type: 'ClippingGroup', name: 'clip' },
  ] }],
  clips: [],
  ops: tableOps,
};
scenarios.tableFogExp2 = {
  roots: [{ type: 'Scene', name: 'scene', fog: 'FogExp2' }],
  ops: ['fog[near]', 'fog[density]', 'backgroundIntensity'].flatMap(f => [['probe', '.' + f, 1], ['poke', '.' + f, [0.25]], ['probe', '.' + f, 1]]),
};
