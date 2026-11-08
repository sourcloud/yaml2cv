//// Browser editor: the page and the htmx endpoints behind it (ADR 0011).

import gleam/bytes_tree
import gleam/http/response
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import wisp.{type Request, type Response}
import yaml2cv/cv.{type Cv}
import yaml2cv/cv/decode.{
  type DecodeError, DocumentTooComplex, DocumentTooLarge, SchemaError,
  SyntaxError,
}
import yaml2cv/render.{type RenderError, type Renderer}
import yaml2cv/web/ui/alert
import yaml2cv/web/ui/button
import yaml2cv/web/ui/code_area
import yaml2cv/web/ui/error_list
import yaml2cv/web/ui/indicator
import yaml2cv/web/ui/page_stack
import yaml2cv/web/ui/panel
import yaml2cv/web/ui/shell

const title = "yaml2cv"

/// The id of the YAML source field; error locations jump into it.
const source_field = "cv"

/// `GET /` — the editor, preloaded with `example`.
pub fn page(example: String) -> Response {
  shell.view(
    title:,
    actions: [
      button.view(
        button.Primary,
        [attribute.type_("submit"), attribute.form("editor-form")],
        "Download PDF",
      ),
    ],
    content: [
      html.div([attribute.class("layout-editor")], [
        html.form(
          [
            attribute.id("editor-form"),
            attribute.method("post"),
            attribute.action("/editor/download"),
          ],
          [
            panel.view(
              title: "CV",
              actions: [
                button.view(
                  button.Secondary,
                  [
                    attribute.type_("button"),
                    attribute.data("copy-from", source_field),
                    attribute.data("copied-label", "Copied"),
                  ],
                  "Copy YAML",
                ),
              ],
              body: [
                code_area.view(
                  id: source_field,
                  name: "yaml",
                  label: "CV source in YAML",
                  value: example,
                  attributes: [],
                ),
                html.div(
                  [
                    attribute.id("validation"),
                    attribute.aria("live", "polite"),
                    ..live_update("/editor/validate", "400ms")
                  ],
                  [],
                ),
              ],
            ),
          ],
        ),
        html.div([attribute.class("layout-editor__preview")], [
          panel.view(
            title: "Preview",
            actions: [
              indicator.view(id: "preview-indicator", label: "Rendering…"),
            ],
            body: [
              html.div(
                [
                  attribute.id("preview"),
                  attribute.attribute("hx-indicator", "#preview-indicator"),
                  ..live_update("/editor/preview", "1s")
                ],
                [],
              ),
            ],
          ),
        ]),
      ]),
    ],
  )
  |> element.to_document_string
  |> wisp.html_response(200)
}

/// htmx attributes that post the editor content to `path` on load and after
/// typing pauses for `delay`, replacing any request still in flight.
fn live_update(path: String, delay: String) -> List(attribute.Attribute(a)) {
  [
    attribute.attribute("hx-post", path),
    attribute.attribute("hx-trigger", "load, input from:#cv delay:" <> delay),
    attribute.attribute("hx-include", "#cv"),
    attribute.attribute("hx-sync", "this:replace"),
  ]
}

/// `POST /editor/validate` — validation status fragment.
pub fn validate(request: Request, max_body_bytes: Int) -> Response {
  use source <- require_yaml_field(request, max_body_bytes)
  let view = case decode.from_yaml(source) {
    Ok(_) -> alert.view(alert.Success, "Valid CV", [])
    Error(errors) -> errors_view(errors)
  }
  fragment(view, 200)
}

/// `POST /editor/preview` — preview images fragment. Invalid documents get
/// `204 No Content` so the last good preview stays visible.
pub fn preview(
  request: Request,
  renderer: Renderer,
  max_body_bytes: Int,
) -> Response {
  use source <- require_yaml_field(request, max_body_bytes)
  case decode.from_yaml(source) {
    Error(_) -> wisp.response(204)
    Ok(cv) ->
      case renderer.render_svg_pages(cv) {
        Ok(pages) -> fragment(page_stack.view(pages), 200)
        Error(error) ->
          fragment(
            alert.view(alert.Danger, "Preview unavailable", [
              html.text(render_error_message(error)),
            ]),
            200,
          )
      }
  }
}

/// `POST /editor/download` — the PDF as an attachment, or an error page.
pub fn download(
  request: Request,
  renderer: Renderer,
  max_body_bytes: Int,
) -> Response {
  use source <- require_yaml_field(request, max_body_bytes)
  case decode.from_yaml(source) {
    Error(errors) -> error_page(errors_view(errors), 422)
    Ok(cv) -> download_pdf(renderer, cv)
  }
}

fn download_pdf(renderer: Renderer, cv: Cv) -> Response {
  case renderer.render_pdf(cv) {
    Ok(pdf) ->
      wisp.response(200)
      |> response.set_header("content-type", "application/pdf")
      |> response.set_header(
        "content-disposition",
        "attachment; filename=\"cv.pdf\"",
      )
      |> wisp.set_body(wisp.Bytes(bytes_tree.from_bit_array(pdf)))
    Error(error) -> {
      let status = case error {
        render.CompileFailed(..) -> 500
        _ -> 503
      }
      alert.view(alert.Danger, "Download failed", [
        html.text(render_error_message(error)),
      ])
      |> error_page(status)
    }
  }
}

/// Reads the `yaml` field of a form-encoded body. URL encoding can triple
/// the size of the text, so the body limit is relaxed accordingly and the
/// decoded text is checked against `max_body_bytes`.
fn require_yaml_field(
  request: Request,
  max_body_bytes: Int,
  next: fn(String) -> Response,
) -> Response {
  let request = wisp.set_max_body_size(request, max_body_bytes * 3)
  use form <- wisp.require_form(request)
  case list.key_find(form.values, "yaml") {
    Error(Nil) -> wisp.bad_request("Missing form field: yaml")
    Ok(source) ->
      case string.byte_size(source) > max_body_bytes {
        True -> wisp.content_too_large()
        False -> next(source)
      }
  }
}

fn errors_view(errors: List(DecodeError)) -> Element(a) {
  let count = list.length(errors)
  let title = case count {
    1 -> "1 problem"
    _ -> int.to_string(count) <> " problems"
  }
  // yamerl aborts at the first syntax error, so later problems stay hidden.
  let hint = case list.any(errors, is_syntax_error) {
    True ->
      html.p([], [
        html.text(
          "Parsing stops at the first syntax error. Fix it to see any further problems.",
        ),
      ])
    False -> element.none()
  }
  alert.view(alert.Danger, title, [
    error_list.view(list.map(errors, describe_error)),
    hint,
  ])
}

fn is_syntax_error(error: DecodeError) -> Bool {
  case error {
    SyntaxError(..) -> True
    _ -> False
  }
}

/// A decode error as an error list item; syntax errors with a known
/// position link to it in the editor.
fn describe_error(error: DecodeError) -> error_list.Item {
  case error {
    SchemaError(path:, message:) ->
      error_list.Item(location: path, message:, target: None)
    SyntaxError(message:, line: 0, ..) ->
      error_list.Item(location: "", message:, target: None)
    SyntaxError(message:, line:, column:) ->
      error_list.Item(
        location: "line "
          <> int.to_string(line)
          <> ", column "
          <> int.to_string(column),
        message:,
        target: Some(error_list.Target(field: source_field, line:, column:)),
      )
    DocumentTooComplex ->
      error_list.Item(
        location: "",
        message: "the document is nested too deeply to process",
        target: None,
      )
    DocumentTooLarge(max_nodes:) ->
      error_list.Item(
        location: "",
        message: "the document has more than "
          <> int.to_string(max_nodes)
          <> " nodes",
        target: None,
      )
  }
}

fn render_error_message(error: RenderError) -> String {
  case error {
    render.Overloaded -> {
      wisp.log_warning("editor render rejected: server overloaded")
      "The server is busy right now. Try again in a moment."
    }
    render.TimedOut -> {
      wisp.log_warning("editor render timed out")
      "Rendering took too long."
    }
    render.RendererUnavailable(reason:) -> {
      wisp.log_error("renderer unavailable: " <> reason)
      "The renderer is currently unavailable."
    }
    render.CompileFailed(output:) -> {
      wisp.log_error("render failed: " <> output)
      "The CV could not be rendered."
    }
  }
}

fn fragment(view: Element(a), status: Int) -> Response {
  wisp.html_response(element.to_string(view), status)
}

/// A full page showing `message` with a way back to the editor.
fn error_page(message: Element(a), status: Int) -> Response {
  shell.view(title:, actions: [], content: [
    panel.view(
      title: "Cannot create PDF",
      actions: [html.a([attribute.href("/")], [html.text("Back to editor")])],
      body: [message],
    ),
  ])
  |> element.to_document_string
  |> wisp.html_response(status)
}
