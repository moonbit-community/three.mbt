// Upstream side of the environments scenarios (MoonBit side:
// src/addons/environments/a6_environments_diff_test.mbt).
import fs from 'node:fs';
const C = eval( fs.readFileSync( new URL( './common.js', import.meta.url ), 'utf8' ) );
export async function runEnvironments() {
  const { RoomEnvironment } = await import( 'three/addons/environments/RoomEnvironment.js' );
  const { ColorEnvironment } = await import( 'three/addons/environments/ColorEnvironment.js' );
  const { DebugEnvironment } = await import( 'three/addons/environments/DebugEnvironment.js' );
  const out = {};
  // the scene as toJSON plus what toJSON leaves out: ids relative to the scene's, world
  // matrices, attribute bytes, dispose order
  const describe = ( scene ) => {
    scene.updateMatrixWorld();
    const objects = [];
    let firstMaterial = null, firstGeometry = null;
    scene.traverse( ( o ) => {
      const entry = [ o.id - scene.id, o.type, o.name, o.matrixWorld.elements ];
      if ( o.geometry ) {
        if ( firstGeometry === null ) firstGeometry = o.geometry.id;
        entry.push( o.geometry.id - firstGeometry, Object.keys( o.geometry.attributes ), Object.values( o.geometry.attributes ).map( ( a ) => Array.from( a.array ) ), o.geometry.index ? Array.from( o.geometry.index.array ) : null, o.geometry.groups );
      }
      if ( o.material ) { if ( firstMaterial === null ) firstMaterial = o.material.id; entry.push( o.material.id - firstMaterial ); }
      if ( o.isLight ) entry.push( o.intensity, o.distance, o.decay, o.color.toArray() );
      objects.push( entry );
    } );
    const log = [];
    scene.traverse( ( o ) => {
      if ( o.geometry ) o.geometry.addEventListener( 'dispose', () => log.push( 'geometry ' + ( o.geometry.id - firstGeometry ) ) );
      if ( o.material ) o.material.addEventListener( 'dispose', () => log.push( 'material ' + ( o.material.id - firstMaterial ) ) );
    } );
    const json = scene.toJSON();
    const clone = scene.clone();
    scene.dispose();
    return [ json, objects, log, scene.type, clone.type, clone.name, clone.children.length ];
  };
  out.env_room = C.canon( describe( new RoomEnvironment() ) );
  out.env_color = C.canon( describe( new ColorEnvironment( 0x336699 ) ) );
  out.env_color_default = C.canon( describe( new ColorEnvironment() ) );
  out.env_debug = C.canon( describe( new DebugEnvironment() ) );
  return out;
}
