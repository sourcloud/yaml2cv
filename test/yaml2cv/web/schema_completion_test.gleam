import birdie
import gleam/dynamic/decode
import gleam/json
import yaml2cv/web/i18n.{En}
import yaml2cv/web/schema_completion

pub fn completion_data_test() {
  schema_completion.json(i18n.texts(En).schema)
  |> birdie.snap(title: "schema completion data")
}

pub fn keys_holding_a_mapping_or_list_are_nested_test() {
  let json = schema_completion.json(i18n.texts(En).schema)
  let nested = fn(path) {
    let field = {
      use key <- decode.field("key", decode.string)
      use nested <- decode.field("nested", decode.bool)
      decode.success(#(key, nested))
    }
    json.parse(json, decode.at(["mappings", path], decode.list(field)))
  }
  assert nested("")
    == Ok([
      #("schema_version", False),
      #("language", False),
      #("style", True),
      #("person", True),
      #("contact", True),
      #("sections", True),
    ])
  assert nested("contact")
    == Ok([
      #("email", False),
      #("phone", False),
      #("website", False),
      #("links", True),
    ])
  assert nested("sections[]")
    == Ok([
      #("name", False),
      #("kind", False),
      #("entries", True),
      #("items", True),
      #("text", False),
    ])
}
