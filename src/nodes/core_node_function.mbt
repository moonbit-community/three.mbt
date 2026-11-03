// nodes/core/NodeFunction.js. `WGSLNodeFunction` and `GLSLNodeFunction` (in the
// backends) set `get_code`; upstream overrides `getCode( name = this.name )`.

///|
pub(all) struct NodeFunction {
  mut type_ : String
  mut inputs : Array[NodeFunctionInput]
  mut name : String
  mut precision : String
  /// `getCode( name )`; `None` is the abstract base, which warns.
  mut get_code_impl : ((NodeFunction, String) -> String)?
  /// The backend subclass payload (`inputsCode`, `blockCode`, ...).
  mut payload : @core.JsValue
}

///|
pub fn NodeFunction::new(
  type_ : String,
  inputs : Array[NodeFunctionInput],
  name~ : String = "",
  precision~ : String = "",
) -> NodeFunction {
  {
    type_,
    inputs,
    name,
    precision,
    get_code_impl: None,
    payload: @core.JsValue::undefined(),
  }
}

///|
/// `getCode( name = this.name )`.
pub fn NodeFunction::get_code(self : NodeFunction, name? : String) -> String {
  let name = name.unwrap_or(self.name)
  match self.get_code_impl {
    Some(f) => f(self, name)
    None => {
      @core.warn("Abstract function.")
      ""
    }
  }
}
