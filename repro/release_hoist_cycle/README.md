# MoonBit release JS: hoisted constant emitted after a top-level value that needs it

`moon 0.1.20261102`. A top-level value (`special`) is initialized by a function (`make`)
that passes a literal to an optional argument. The release build hoists that literal into
a module-level `const`. When the value also takes part in a cycle that runs through a trait
object (the `Class` impl's `check` refers back to `special`), the release build emits the
hoisted constant *after* the value's initializer:

```js
const _M0FP35repro5hoist4main7special = _M0FP35repro5hoist4main4make();
const _M0FP35repro5hoist4main4makeN6constrS10 = "float";
```

```bash
moon build --target js && node _build/js/debug/build/main/main.js
# float
moon build --target js --release && node _build/js/release/build/main/main.js
# ReferenceError: Cannot access '_M0FP35repro5hoist4main4makeN6constrS10' before initialization
```

Filed as compiler/ideas#2654. On wasm-gc the release build silently prints `none` instead of failing.

A direct cycle (without the trait object) is rejected with error 4050, so the compiler
does track these dependencies; the trait-object edge just puts the value and the
constant in one component whose order is then arbitrary. Hoisted literals have no
dependencies, so emitting them before every top-level initializer would fix it.

In the three.js port this hits module-level nodes whose class refers back to them (e.g.
`depth`, whose `NodeClass::assign` checks `physical_equal(node, depth)`, mirroring
upstream's `depth.assign = ...`). Debug builds do not hoist and are unaffected; whether a
release build fails depends on the program, so it can appear after unrelated changes.
