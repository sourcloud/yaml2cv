import birdie
import gleam/list
import lustre/element
import lustre/element/html
import yaml2cv/cv/decode
import yaml2cv/web/i18n.{De, En}
import yaml2cv/web/schema_help

pub fn documents_exactly_the_keys_the_decoder_accepts_test() {
  let documented =
    schema_help.groups(i18n.texts(En).schema)
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
  schema_help.view(i18n.texts(En).schema, close: "Close")
  |> element.to_string
  |> birdie.snap(title: "schema help dialog")
}

pub fn german_schema_help_test() {
  schema_help.view(i18n.texts(De).schema, close: "Schließen")
  |> element.to_string
  |> birdie.snap(title: "schema help dialog de")
}

pub fn rich_text_marks_code_test() {
  let html =
    html.p([], schema_help.rich("see `a.b` or `c`."))
    |> element.to_string
  assert html == "<p>see <code>a.b</code> or <code>c</code>.</p>"
}
