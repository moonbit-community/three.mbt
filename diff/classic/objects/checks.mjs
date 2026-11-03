// src/core objects vs upstream on 3050 seeded scenarios: raycasts against every object
// kind (mesh, lines, points, instanced, LOD, skinned, sprite, group), Box3 / frustum
// tests, skinning, skeletons and BatchedMesh operations.
export default [
	{
		name: 'classic_objects',
		area: 'classic',
		order: 50,
		title: 'objects (raycast, bounds, skinning, batched)',
		build: [ 'mbt' ],
		cmd: [ 'bash', 'run.sh', '1', '1' ],
		env: { SKIP_BUILD: '1' },
		summary: /scenarios identical/,
		expect: '3050/3050 scenarios identical, 1562410 scalar values compared',
		timeout: 600,
	},
];
