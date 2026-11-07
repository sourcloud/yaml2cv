import yaml2cv/yaml.{Bool, Float, Int, Map, Null, Sequence, String, SyntaxError}

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
