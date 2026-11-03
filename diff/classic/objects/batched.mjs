import { THREE, buildGeometry, applyTransform, buildCamera, encodeHit } from './common.mjs';

export function buildBatched(spec) {
  const material = new THREE.MeshBasicMaterial();
  material.side = spec.side;
  const mesh = new THREE.BatchedMesh(spec.maxInstances, spec.maxVertices, spec.maxIndices, material);
  applyTransform(mesh, spec.transform);
  mesh.updateMatrixWorld(true);
  return { mesh, material, geometries: spec.geometries.map(buildGeometry), out: [] };
}

export function batchedState(mesh) {
  return {
    instanceCount: mesh.instanceCount, maxInstanceCount: mesh.maxInstanceCount,
    unusedVertexCount: mesh.unusedVertexCount, unusedIndexCount: mesh.unusedIndexCount,
    nextIndexStart: mesh._nextIndexStart, nextVertexStart: mesh._nextVertexStart, geometryCount: mesh._geometryCount,
    availableInstanceIds: mesh._availableInstanceIds.slice(), availableGeometryIds: mesh._availableGeometryIds.slice(),
    instanceInfo: mesh._instanceInfo.map((i) => [i.visible, i.active, i.geometryIndex]),
    geometryInfo: mesh._geometryInfo.map((g) => [g.vertexStart, g.vertexCount, g.reservedVertexCount, g.indexStart, g.indexCount, g.reservedIndexCount, g.start, g.count, g.active]),
    index: mesh.geometry.index ? Array.from(mesh.geometry.index.array) : null,
    position: mesh.geometry.attributes.position ? Array.from(mesh.geometry.attributes.position.array) : null,
    uv: mesh.geometry.attributes.uv ? Array.from(mesh.geometry.attributes.uv.array) : null,
    positionRanges: mesh.geometry.attributes.position ? mesh.geometry.attributes.position.updateRanges.map((r) => [r.start, r.count]) : null,
    matrices: Array.from(mesh._matricesTexture.image.data),
    matricesSize: mesh._matricesTexture.image.width,
    indirect: Array.from(mesh._indirectTexture.image.data),
    colors: mesh._colorsTexture ? Array.from(mesh._colorsTexture.image.data) : null,
    versions: [mesh._matricesTexture.version, mesh._indirectTexture.version, mesh._colorsTexture ? mesh._colorsTexture.version : -1],
  };
}

export function applyBatchedOp(built, spec, op) {
  const { mesh, material, geometries, out } = built;
  const [name] = op;
  switch (name) {
    case 'addGeometry': out.push(mesh.addGeometry(geometries[op[1]], op[2], op[3])); break;
    case 'addInstance': out.push(mesh.addInstance(op[1])); break;
    case 'setMatrixAt': mesh.setMatrixAt(op[1], new THREE.Matrix4().fromArray(op[2])); break;
    case 'setColorAt': mesh.setColorAt(op[1], new THREE.Color(op[2][0], op[2][1], op[2][2])); out.push(mesh.getColorAt(op[1], new THREE.Color()).toArray()); break;
    case 'setVisibleAt': mesh.setVisibleAt(op[1], op[2]); out.push(mesh.getVisibleAt(op[1])); break;
    case 'deleteInstance': mesh.deleteInstance(op[1]); break;
    case 'deleteGeometry': mesh.deleteGeometry(op[1]); break;
    case 'optimize': mesh.optimize(); break;
    case 'setInstanceCount': mesh.setInstanceCount(op[1]); break;
    case 'setGeometrySize': mesh.setGeometrySize(op[1], op[2]); break;
    case 'setGeometryAt': out.push(mesh.setGeometryAt(op[1], geometries[op[2]])); break;
    case 'setGeometryIdAt': mesh.setGeometryIdAt(op[1], op[2]); out.push(mesh.getGeometryIdAt(op[1])); break;
    case 'draw': {
      const cam = buildCamera(op[1]);
      const o = op[2];
      mesh.sortObjects = o.sort; mesh.perObjectFrustumCulled = o.culled;
      material.transparent = o.transparent; material.wireframe = o.wireframe;
      mesh._visibilityChanged = true;
      mesh._updateDrawParameters(cam, mesh.geometry, material, o.format);
      out.push([mesh._multiDrawCount, mesh._mergedDrawCount, mesh._multiDrawBytesPerElement,
        Array.from(mesh._multiDrawStarts), Array.from(mesh._multiDrawCounts),
        Array.from(mesh._mergedDrawStarts), Array.from(mesh._mergedDrawCounts), Array.from(mesh._mergedDrawInstanceCounts),
        Array.from(mesh._indirectTexture.image.data)]);
      break;
    }
    case 'raycast': {
      const r = op[1];
      const rc = new THREE.Raycaster(new THREE.Vector3(...r.o), new THREE.Vector3(...r.d), r.near, r.far === null ? Infinity : r.far);
      const hits = [];
      mesh.raycast(rc, hits);
      hits.sort((a, b) => a.distance - b.distance);
      out.push(hits.map(encodeHit));
      break;
    }
    case 'bounds': {
      mesh.computeBoundingBox(); mesh.computeBoundingSphere();
      out.push([mesh.boundingBox.min.toArray(), mesh.boundingBox.max.toArray(), mesh.boundingSphere.center.toArray(), mesh.boundingSphere.radius]);
      break;
    }
    case 'clone': {
      const c = mesh.clone();
      out.push(batchedState(c));
      break;
    }
  }
}
