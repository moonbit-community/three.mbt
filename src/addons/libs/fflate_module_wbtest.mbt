// Tests of `unzlib_sync` against fflate's results.

///|
extern "js" fn fflate_test_try(f : () -> Unit) -> String = "(f) => { try { f(); return 'ok'; } catch (e) { return e.message + ' code=' + e.code; } }"

///|
extern "js" fn fflate_test_text(a : @core.TypedArray) -> String = "(a) => new TextDecoder().decode(a)"

///|
let fflate_test_hello : Array[Int32] = [
  120, 156, 203, 72, 205, 201, 201, 87, 200, 192, 32, 171, 114, 50, 147, 0, 152,
  120, 10, 130,
]

///|
test "unzlib_sync inflates a zlib stream" {
  let out = unzlib_sync(@core.TypedArray::uint8(fflate_test_hello))
  assert_eq(fflate_test_text(out), "hello hello hello hello zlib")
  assert_eq(out.type_name(), "Uint8Array")
}

///|
test "unzlib_sync throws fflate's errors" {
  assert_eq(
    fflate_test_try(() => ignore(unzlib_sync(@core.TypedArray::uint8(0)))),
    "invalid zlib data code=6",
  )
  let truncated = fflate_test_hello.copy()
  truncated.truncate(8)
  assert_eq(
    fflate_test_try(() => {
      ignore(unzlib_sync(@core.TypedArray::uint8(truncated)))
    }),
    "unexpected EOF code=0",
  )
  let dict = fflate_test_hello.copy()
  dict[1] = dict[1] ^ 0x20
  assert_eq(
    fflate_test_try(() => ignore(unzlib_sync(@core.TypedArray::uint8(dict)))),
    "invalid zlib data code=6",
  )
}
