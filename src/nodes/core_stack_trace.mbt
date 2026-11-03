// nodes/core/StackTrace.js

///|
pub(all) struct StackFrame {
  fn_ : String
  file : String
  line : Int32
  column : Int32
}

///|
pub(all) struct StackTrace {
  stack : Array[StackFrame]
}

///|
extern "js" fn js_error_stack() -> String = "() => new Error().stack || ''"

///|
extern "js" fn js_filtered_stack(stack : String) -> @core.JsValue =
  #|(stack) => {
  #|  const IGNORED_FILES = [ /^StackTrace\.js$/, /^TSLCore\.js$/, /^.*Node\.js$/, /^three\.webgpu.*\.js$/ ];
  #|  const regex = /(?:at\s+(.+?)\s+\()?(?:(.+?)@)?([^@\s()]+):(\d+):(\d+)/;
  #|  return stack.split( '\n' ).map( line => {
  #|    const match = line.match( regex );
  #|    if ( ! match ) return null;
  #|    const fn = match[ 1 ] || match[ 2 ] || '';
  #|    const file = match[ 3 ].split( '?' )[ 0 ];
  #|    return { fn, file: file.split( '/' ).pop(), line: parseInt( match[ 4 ], 10 ), column: parseInt( match[ 5 ], 10 ) };
  #|  } ).filter( frame => frame && ! IGNORED_FILES.some( regex => regex.test( frame.file ) ) );
  #|}

///|
extern "js" fn js_frames_length(frames : @core.JsValue) -> Int32 = "(f) => f.length"

///|
extern "js" fn js_frame_string(
  frames : @core.JsValue,
  i : Int32,
  key : String,
) -> String = "(f, i, k) => String(f[i][k])"

///|
extern "js" fn js_frame_int(
  frames : @core.JsValue,
  i : Int32,
  key : String,
) -> Int32 = "(f, i, k) => f[i][k] | 0"

///|
/// Captures the current JS stack (or parses `stack_message`), dropping node internals.
pub fn StackTrace::new(stack_message? : String) -> StackTrace {
  let frames = js_filtered_stack(stack_message.unwrap_or(js_error_stack()))
  let stack = []
  for i in 0..<js_frames_length(frames) {
    stack.push({
      fn_: js_frame_string(frames, i, "fn"),
      file: js_frame_string(frames, i, "file"),
      line: js_frame_int(frames, i, "line"),
      column: js_frame_int(frames, i, "column"),
    })
  }
  { stack, }
}

///|
pub fn StackTrace::get_location(self : StackTrace) -> String {
  if self.stack.length() == 0 {
    return "[Unknown location]"
  }
  let main_stack = self.stack[0]
  let fn_name = if main_stack.fn_ != "" {
    "\"\{main_stack.fn_}()\" at "
  } else {
    ""
  }
  "\{fn_name}\"\{main_stack.file}:\{main_stack.line}\""
}

///|
pub fn StackTrace::get_error(self : StackTrace, message : String) -> String {
  if self.stack.length() == 0 {
    return message
  }
  let lines = self.stack.map(fn(frame) {
    let location = "\{frame.file}:\{frame.line}:\{frame.column}"
    if frame.fn_ != "" {
      "    at \{frame.fn_} (\{location})"
    } else {
      "    at \{location}"
    }
  })
  message + "\n" + lines.join("\n")
}
