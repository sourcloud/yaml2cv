//// Labelled form fields (`priv/static/css/components/field.css`).

import gleam/list
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

/// Whether a field must be filled in; required fields are marked with
/// `marker`, e.g. " (required)".
pub type Requirement {
  Required(marker: String)
  Optional
}

/// A single-line text input.
pub fn text(
  name name: String,
  label label: String,
  value value: String,
  requirement requirement: Requirement,
) -> Element(message) {
  wrap(label, requirement, [
    html.input([
      attribute.class("ui-field__input"),
      attribute.type_("text"),
      attribute.name(name),
      attribute.value(value),
      ..required(requirement)
    ]),
  ])
}

/// A multi-line text input.
pub fn textarea(
  name name: String,
  label label: String,
  value value: String,
  requirement requirement: Requirement,
) -> Element(message) {
  wrap(label, requirement, [
    html.textarea(
      [
        attribute.class("ui-field__input ui-field__input--multiline"),
        attribute.name(name),
        attribute.rows(5),
        ..required(requirement)
      ],
      value,
    ),
  ])
}

/// A choice from `options` (value, label) with `value` selected.
pub fn select(
  name name: String,
  label label: String,
  options options: List(#(String, String)),
  value value: String,
) -> Element(message) {
  wrap(label, Optional, [
    html.select(
      [attribute.class("ui-field__input"), attribute.name(name)],
      list.map(options, fn(option) {
        html.option(
          [attribute.value(option.0), attribute.selected(option.0 == value)],
          option.1,
        )
      }),
    ),
  ])
}

fn wrap(
  label: String,
  requirement: Requirement,
  control: List(Element(message)),
) -> Element(message) {
  let marker = case requirement {
    Required(marker:) ->
      html.span([attribute.class("ui-field__required")], [html.text(marker)])
    Optional -> element.none()
  }
  html.label([attribute.class("ui-field")], [
    html.span([attribute.class("ui-field__label")], [html.text(label), marker]),
    ..control
  ])
}

/// Browser validation is left to the server-side validation, so required
/// fields are only marked for assistive technology.
fn required(requirement: Requirement) -> List(Attribute(message)) {
  case requirement {
    Required(..) -> [attribute.aria_required(True)]
    Optional -> []
  }
}
