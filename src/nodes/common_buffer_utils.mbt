// renderers/common/BufferUtils.js

///|
/// `getFloatLength( floatLength )`: padded to a multiple of `GPU_CHUNK_BYTES`.
pub fn get_float_length(float_length : Int32) -> Int32 {
  float_length +
  (GPU_CHUNK_BYTES - float_length % GPU_CHUNK_BYTES) % GPU_CHUNK_BYTES
}

///|
/// `getVectorLength( count, vectorLength = 4 )`.
pub fn get_vector_length(count : Int32, vector_length~ : Int32 = 4) -> Int32 {
  let stride_length = get_stride_length(vector_length)
  let float_length = stride_length * count
  get_float_length(float_length)
}

///|
/// `getStrideLength( vectorLength )`: padded to a multiple of 4.
pub fn get_stride_length(vector_length : Int32) -> Int32 {
  let stride_length = 4
  vector_length +
  (stride_length - vector_length % stride_length) % stride_length
}
