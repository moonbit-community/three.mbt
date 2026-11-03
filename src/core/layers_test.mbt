///|
test "Layers set" {
  let a = @core.Layers::new()
  let mut power = 1.0
  for i in 0..<31 {
    a.set(i)
    assert_eq(a.mask, power)
    power = power * 2.0
  }
}

///|
test "Layers set 31 keeps the unsigned mask" {
  let a = @core.Layers::new()
  a.set(31)
  assert_eq(a.mask, 2147483648.0)
  assert_true(a.is_enabled(31))
}

///|
test "Layers enable" {
  let a = @core.Layers::new()
  a.set(0)
  a.enable(0)
  assert_eq(a.mask, 1)
  a.set(0)
  a.enable(1)
  assert_eq(a.mask, 3)
  a.set(1)
  a.enable(0)
  assert_eq(a.mask, 3)
  a.set(1)
  a.enable(1)
  assert_eq(a.mask, 2)
}

///|
test "Layers toggle" {
  let a = @core.Layers::new()
  a.set(0)
  a.toggle(0)
  assert_eq(a.mask, 0)
  a.set(0)
  a.toggle(1)
  assert_eq(a.mask, 3)
  a.set(1)
  a.toggle(0)
  assert_eq(a.mask, 3)
  a.set(1)
  a.toggle(1)
  assert_eq(a.mask, 0)
}

///|
test "Layers disable" {
  let a = @core.Layers::new()
  a.set(0)
  a.disable(0)
  assert_eq(a.mask, 0)
  a.set(0)
  a.disable(1)
  assert_eq(a.mask, 1)
  a.set(1)
  a.disable(0)
  assert_eq(a.mask, 2)
  a.set(1)
  a.disable(1)
  assert_eq(a.mask, 0)
}

///|
test "Layers test" {
  let a = @core.Layers::new()
  let b = @core.Layers::new()
  assert_true(a.test_(b))
  a.set(1)
  assert_false(a.test_(b))
  b.toggle(1)
  assert_true(a.test_(b))
}

///|
test "Layers isEnabled" {
  let a = @core.Layers::new()
  a.enable(1)
  assert_true(a.is_enabled(1))
  a.enable(2)
  assert_true(a.is_enabled(2))
  a.toggle(1)
  assert_false(a.is_enabled(1))
  assert_true(a.is_enabled(2))
}

///|
test "Layers enableAll and disableAll" {
  let a = @core.Layers::new()
  a.enable_all()
  assert_eq(a.mask, -1)
  assert_true(a.is_enabled(31))
  a.disable_all()
  assert_eq(a.mask, 0)
}
