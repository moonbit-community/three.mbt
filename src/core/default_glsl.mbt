// Upstream src/renderers/shaders/ShaderChunk/default_vertex.glsl.js and
// default_fragment.glsl.js, the default shaders of `ShaderMaterial`.

///|
pub let default_vertex : String =
  #|
  #|void main() {
  #|	gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
  #|}
  #|

///|
pub let default_fragment : String =
  #|
  #|void main() {
  #|	gl_FragColor = vec4( 1.0, 0.0, 0.0, 1.0 );
  #|}
  #|
