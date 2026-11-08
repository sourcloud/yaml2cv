//// Labelled form fields (`priv/static/css/components/field.css`).

import gleam/list
import gleam/string
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

/// Labels of the photo field.
pub type PhotoLabels {
  PhotoLabels(choose: String, change: String, remove: String, failed: String)
}

/// A profile photo (ADR 0028), held as a data URI in a hidden input, with a
/// thumbnail and a button to choose it, which reads "change" and is joined
/// by a remove button once there is a photo. `editor.js` shrinks a
/// chosen file in the browser and writes it into the hidden input. Only
/// JPEG and PNG data URIs are shown as thumbnail.
pub fn photo(
  name name: String,
  label label: String,
  value value: String,
  labels labels: PhotoLabels,
) -> Element(message) {
  let has_photo = value != ""
  let thumbnail = case is_photo_uri(value) {
    True -> [attribute.src(value)]
    False -> [attribute.attribute("hidden", "")]
  }
  let choose_label = case has_photo {
    True -> labels.change
    False -> labels.choose
  }
  html.div(
    [
      attribute.class("ui-field"),
      attribute.role("group"),
      attribute.aria("label", label),
      attribute.data("photo-field", ""),
      attribute.data("photo-failed-label", labels.failed),
    ],
    [
      html.span([attribute.class("ui-field__label")], [html.text(label)]),
      html.div([attribute.class("ui-field__photo")], [
        html.img([
          attribute.class("ui-field__thumbnail"),
          attribute.alt(""),
          attribute.data("photo-thumbnail", ""),
          ..thumbnail
        ]),
        html.input([
          attribute.type_("hidden"),
          attribute.name(name),
          attribute.value(value),
          attribute.data("photo-value", ""),
        ]),
        html.input([
          attribute.type_("file"),
          attribute.accept(["image/jpeg", "image/png"]),
          attribute.attribute("hidden", ""),
          attribute.data("photo-input", ""),
        ]),
        html.button(
          [
            attribute.class("ui-button ui-button--secondary"),
            attribute.type_("button"),
            attribute.data("photo-choose", ""),
            attribute.data("choose-label", labels.choose),
            attribute.data("change-label", labels.change),
          ],
          [html.text(choose_label)],
        ),
        html.button(
          [
            attribute.class("ui-button ui-button--quiet"),
            attribute.type_("button"),
            attribute.data("photo-remove", ""),
            attribute.hidden(!has_photo),
          ],
          [html.text(labels.remove)],
        ),
      ]),
    ],
  )
}

fn is_photo_uri(value: String) -> Bool {
  string.starts_with(value, "data:image/jpeg;base64,")
  || string.starts_with(value, "data:image/png;base64,")
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
