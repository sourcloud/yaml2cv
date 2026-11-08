import birdie
import gleam/list
import lustre/element
import yaml2cv/cv/decode
import yaml2cv/web/schema_help

pub fn documents_exactly_the_keys_the_decoder_accepts_test() {
  let documented =
    schema_help.groups()
    |> list.map(fn(group) {
      #(group.id, list.map(group.fields, fn(f) { f.key }))
    })
  assert documented
    == [
      #("document", decode.root_keys),
      #("style", decode.style_keys),
      #("person", decode.person_keys),
      #("contact", decode.contact_keys),
      #("link", decode.link_keys),
      #(
        "section",
        list.append(
          decode.section_keys,
          list.map(decode.section_kinds, fn(k) { k.1 }),
        ),
      ),
      #("entry", decode.entry_keys),
      #("skill", decode.skill_keys),
    ]
}

pub fn schema_help_test() {
  schema_help.view()
  |> element.to_string
  |> birdie.snap(title: "schema help dialog")
}
