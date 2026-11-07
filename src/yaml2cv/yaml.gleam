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
  /// The document expands to more than `limit` nodes, e.g. through aliases.
  TooManyNodes(limit: Int)
}

/// The maximum number of nodes, counted after alias expansion, across all
/// documents of one input. It bounds the work a small but alias-heavy input
/// ("billion laughs") can cause.
pub const max_nodes = 20_000

/// Parses a string into the root nodes of all documents it contains.
pub fn parse(source: String) -> Result(List(Node), ParseError) {
  parse_with_budget(source, max_nodes)
}

@external(erlang, "yaml2cv_yaml_ffi", "parse")
fn parse_with_budget(
  source: String,
  max_nodes: Int,
) -> Result(List(Node), ParseError)
