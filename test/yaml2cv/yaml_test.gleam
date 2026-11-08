import gleam/list
import gleam/string
import yaml2cv/yaml.{
  Bool, Float, Int, Map, Null, Sequence, String, SyntaxError, TimedOut,
  TooManyNodes,
}

pub fn parses_scalars_and_collections_test() {
  let source =
    "
text: hello
number: 42
ratio: 1.5
flag: true
nothing: ~
items: [a, 1]
"

  assert yaml.parse(source)
    == Ok([
      Map([
        #(String("text"), String("hello")),
        #(String("number"), Int(42)),
        #(String("ratio"), Float(1.5)),
        #(String("flag"), Bool(True)),
        #(String("nothing"), Null),
        #(String("items"), Sequence([String("a"), Int(1)])),
      ]),
    ])
}

pub fn parses_unicode_text_test() {
  assert yaml.parse("name: Jürgen Müller")
    == Ok([
      Map([#(String("name"), String("Jürgen Müller"))]),
    ])
}

pub fn parses_multiple_documents_test() {
  assert yaml.parse("a\n---\nb\n") == Ok([String("a"), String("b")])
}

pub fn parses_empty_input_as_no_documents_test() {
  assert yaml.parse("") == Ok([])
}

pub fn reports_syntax_error_with_location_test() {
  assert yaml.parse("person:\n  name: [unclosed\n")
    == Error(SyntaxError(
      message: "Unfinished flow collection",
      line: 2,
      column: 18,
    ))
}

pub fn describes_value_after_value_without_yamerl_internals_test() {
  assert yaml.parse("a: 1\nb\nc: 2\n")
    == Error(SyntaxError(
      message: "Unexpected value after a value; check the indentation or a missing \":\"",
      line: 2,
      column: 1,
    ))
}

pub fn describes_value_after_collection_end_test() {
  assert yaml.parse("a: [1] b\n")
    == Error(SyntaxError(
      message: "Unexpected value after the end of a list or mapping; check the indentation or a missing \":\"",
      line: 1,
      column: 8,
    ))
}

pub fn describes_collection_after_collection_end_test() {
  assert yaml.parse("a: [1] [2]\n")
    == Error(SyntaxError(
      message: "Unexpected list or mapping after the end of a list or mapping; check the indentation or a missing \":\"",
      line: 1,
      column: 8,
    ))
}

pub fn rejects_alias_expansion_bombs_test() {
  // Seven levels of ten aliases each expand to ten million nodes.
  let level = fn(name, item) {
    name <> ": &" <> name <> "\n" <> string.repeat("  - " <> item <> "\n", 10)
  }
  let source =
    level("a", "x")
    <> level("b", "*a")
    <> level("c", "*b")
    <> level("d", "*c")
    <> level("e", "*d")
    <> level("f", "*e")
    <> level("g", "*f")

  assert yaml.parse(source) == Error(TooManyNodes(limit: yaml.max_nodes))
}

pub fn allows_documents_within_node_budget_test() {
  let assert Ok([Sequence(items)]) =
    yaml.parse(string.repeat("- x\n", yaml.max_nodes - 1))
  assert list.length(items) == yaml.max_nodes - 1
}

pub fn aborts_parsing_that_takes_too_long_test() {
  // yamerl needs time quadratic in the nesting depth; 8000 levels take
  // well over a second.
  let source = string.repeat("[", 8000) <> string.repeat("]", 8000)
  assert yaml.parse_with(source, max_nodes: yaml.max_nodes, timeout: 100)
    == Error(TimedOut(limit: 100))
}

pub fn default_parse_has_a_time_limit_test() {
  assert yaml.parse_timeout > 0
  assert yaml.parse_timeout <= 5000
}
