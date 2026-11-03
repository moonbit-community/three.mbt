// renderers/common/Constants.js

///|
/// `AttributeType`: how `Attributes.update` creates an attribute's buffer.
#derive(Eq, Debug)
pub(all) enum AttributeType {
  VERTEX
  INDEX
  STORAGE
  INDIRECT
}

///|
/// The upstream value of an `AttributeType` (`VERTEX` is 1).
pub fn AttributeType::value(self : AttributeType) -> Int32 {
  match self {
    VERTEX => 1
    INDEX => 2
    STORAGE => 3
    INDIRECT => 4
  }
}

///|
/// The size of a GPU memory chunk in bytes.
pub const GPU_CHUNK_BYTES : Int32 = 16
