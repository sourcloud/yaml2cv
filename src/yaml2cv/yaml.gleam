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
  /// Parsing took longer than `limit` milliseconds and was aborted.
  TimedOut(limit: Int)
}

/// The maximum number of nodes, counted after alias expansion, across all
/// documents of one input. It bounds the work a small but alias-heavy input
/// ("billion laughs") can cause.
pub const max_nodes = 20_000

/// Maximum parse time in milliseconds. yamerl needs time quadratic in the
/// nesting depth, so a small but deeply nested input could otherwise keep a
/// CPU busy for minutes.
pub const parse_timeout = 2000

/// Parses a string into the root nodes of all documents it contains, within
/// the default node budget and time limit.
pub fn parse(source: String) -> Result(List(Node), ParseError) {
  parse_with(source, max_nodes:, timeout: parse_timeout)
}

/// Like `parse`, with an explicit node budget and time limit (milliseconds).
@external(erlang, "yaml2cv_yaml_ffi", "parse")
pub fn parse_with(
  source: String,
  max_nodes max_nodes: Int,
  timeout timeout: Int,
) -> Result(List(Node), ParseError)
