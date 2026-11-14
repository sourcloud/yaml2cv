//// Completion data for the YAML editor (ADR 0045), built from the schema
//// reference so both always agree. `editor.js` reads it from the source
//// field's `data-completions` attribute.

import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import yaml2cv/web/i18n/texts.{type SchemaTexts}
import yaml2cv/web/schema_help.{type Field, type Mapping}

/// The keys of every mapping by path, with their requirement, explanation
/// (backticks mark code), allowed values and default, as a JSON string.
/// `nested` tells whether a key's value is a mapping or list of its own.
pub fn json(t: SchemaTexts) -> String {
  let mappings = schema_help.mappings(t)
  json.object([
    #("labels", json.object([#("default", json.string(t.default))])),
    #(
      "mappings",
      json.object(
        list.map(mappings, fn(mapping) {
          #(
            mapping.path,
            json.array(mapping.fields, field(mappings, mapping, _)),
          )
        }),
      ),
    ),
  ])
  |> json.to_string
}

fn field(mappings: List(Mapping), parent: Mapping, field: Field) -> Json {
  let path = case parent.path {
    "" -> field.key
    parent -> parent <> "." <> field.key
  }
  let nested =
    list.any(mappings, fn(mapping) {
      mapping.path == path || mapping.path == path <> "[]"
    })
  json.object([
    #("key", json.string(field.key)),
    #("requirement", json.string(field.requirement)),
    #("description", json.string(field.description)),
    #("values", json.array(field.values, json.string)),
    #("default", case field.default {
      Some(default) -> json.string(default)
      None -> json.null()
    }),
    #("nested", json.bool(nested)),
  ])
}
