//// Minimal YAML parsing on top of the Erlang `yamerl` library (ADR 0008).

/// A parsed YAML value. Mapping keys keep their document order.
pub type Node {
  Null
  String(String)
  Bool(Bool)
  Int(Int)
  Float(Float)
  Sequence(List(Node))
  Map(List(#(Node, Node)))
}

pub type ParseError {
  /// `line` and `column` are 1-based, or 0 when yamerl reports no location.
  SyntaxError(message: String, line: Int, column: Int)
}

/// Parses a string into the root nodes of all documents it contains.
@external(erlang, "yaml2cv_yaml_ffi", "parse")
pub fn parse(source: String) -> Result(List(Node), ParseError)
