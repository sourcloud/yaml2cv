//// Browser editor: the page and the htmx endpoints behind it (ADR 0011).

import gleam/bytes_tree
import gleam/http/response
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import wisp.{type Request, type Response}
import yaml2cv/build.{type Build}
import yaml2cv/cv.{type Cv}
import yaml2cv/cv/decode.{
  type DecodeError, DocumentTooComplex, DocumentTooLarge, SchemaError,
  SyntaxError,
}
import yaml2cv/cv/draft
import yaml2cv/cv/draft/emit
import yaml2cv/render.{type RenderError, type Renderer}
import yaml2cv/web/i18n.{type Locale}
import yaml2cv/web/i18n/texts.{type Texts}
import yaml2cv/web/schema_help
import yaml2cv/web/ui/alert
import yaml2cv/web/ui/button
import yaml2cv/web/ui/code_area
import yaml2cv/web/ui/error_list
import yaml2cv/web/ui/indicator
import yaml2cv/web/ui/menu
import yaml2cv/web/ui/page_stack
import yaml2cv/web/ui/panel
import yaml2cv/web/ui/segmented
import yaml2cv/web/ui/shell
import yaml2cv/web/visual
import yaml2cv/web/visual_form

const title = "yaml2cv"

/// The id of the YAML source field; error locations jump into it.
const source_field = "cv"

/// The id of the editor form, which the language switch submits too.
const form_id = "editor-form"

/// `GET /` — the editor in `locale`, preloaded with `source`.
pub fn page(
  locale: Locale,
  source: String,
  max_body_bytes: Int,
  build: Build,
) -> Response {
  editor_page(locale, source, max_body_bytes, None, build)
}

/// The editor page, in visual mode with the blocks of `blocks` if given.
fn editor_page(
  locale: Locale,
  source: String,
  max_body_bytes: Int,
  blocks: Option(draft.Draft),
  build: Build,
) -> Response {
  let texts = i18n.texts(locale)
  let t = texts.editor
  let mode = case blocks {
    Some(_) -> "visual"
    None -> "yaml"
  }
  shell.view(
    locale:,
    language_form: Some(form_id),
    build:,
    title:,
    actions: [],
    content: [
      html.div([attribute.class("layout-editor")], [
        // `editor.js` switches `data-mode` between `yaml` and `visual`.
        html.div(
          [attribute.class("editor-modes"), attribute.data("mode", mode)],
          [
            panel.view(
              title: t.cv_panel,
              actions: [
                mode_switch(t, option.is_some(blocks)),
                button.view(
                  button.Secondary,
                  [
                    attribute.type_("button"),
                    attribute.data("dialog-open", schema_help.dialog_id),
                    attribute.aria_haspopup("dialog"),
                  ],
                  t.schema_button,
                ),
                file_menu(texts, max_body_bytes),
              ],
              body: [
                html.form(
                  [
                    attribute.id(form_id),
                    attribute.class("editor-modes__source"),
                    attribute.method("post"),
                    attribute.action("/editor/download"),
                  ],
                  [
                    // Tells the language switch which mode to come back in;
                    // `editor.js` keeps it current.
                    html.input([
                      attribute.type_("hidden"),
                      attribute.name("mode"),
                      attribute.value(mode),
                      attribute.data("mode-field", ""),
                    ]),
                    code_area.view(
                      id: source_field,
                      name: "yaml",
                      label: t.source_label,
                      value: source,
                      attributes: [],
                    ),
                  ],
                ),
                // Filled by `POST /editor/visual`; the blocks have a form of
                // their own, so this sits outside the editor form.
                html.div(
                  [
                    attribute.id("visual"),
                    attribute.class("editor-modes__visual"),
                  ],
                  case blocks {
                    Some(cv) -> [visual.view(cv, texts)]
                    None -> []
                  },
                ),
                html.div(
                  [
                    attribute.id("validation"),
                    // Sticks to the bottom of the viewport (layout.css).
                    attribute.class("editor-status"),
                    attribute.aria("live", "polite"),
                    // One request also updates `#preview` (ADR 0041).
                    attribute.attribute("hx-indicator", "#preview-indicator"),
                    ..live_update("/editor/preview", "300ms")
                  ],
                  [],
                ),
              ],
            ),
          ],
        ),
        html.div([attribute.class("layout-editor__preview")], [
          panel.view(
            title: t.preview_panel,
            actions: [
              indicator.view(id: "preview-indicator", label: t.rendering),
              // Outside the form; `form` makes it submit the editor form.
              button.view(
                button.Primary,
                [attribute.type_("submit"), attribute.form(form_id)],
                t.download_pdf,
              ),
            ],
            body: [
              html.div([attribute.id("preview")], []),
            ],
          ),
        ]),
      ]),
      // Outside the editor form: the dialog has a form of its own.
      schema_help.view(texts.schema, close: texts.ui.close),
      visual.sync_placeholder(),
    ],
  )
  |> element.to_document_string
  |> wisp.html_response(200)
}

const import_field = "yaml-import"

/// Copy, download and import the YAML source, in the browser (ADR 0029).
/// Imports above the request body limit are refused, as the server would
/// refuse to check or render them.
fn file_menu(texts: Texts, max_body_bytes: Int) -> Element(a) {
  let t = texts.editor
  html.div([attribute.class("editor-file-menu")], [
    menu.view(id: "file", label: t.file_menu, align: menu.End, items: [
      menu.Item(t.copy_yaml, [
        attribute.data("copy-from", source_field),
        attribute.data("copied-label", t.copied),
        attribute.data("copy-failed-label", t.copy_failed),
      ]),
      menu.Item(t.download_yaml, [
        attribute.data("download-from", source_field),
        attribute.data("download-name", "cv.yaml"),
      ]),
      menu.Item(t.import_yaml, [attribute.data("import-choose", import_field)]),
    ]),
    html.input([
      attribute.id(import_field),
      attribute.type_("file"),
      attribute.accept([".yaml", ".yml", "application/yaml", "text/yaml"]),
      attribute.attribute("hidden", ""),
      attribute.data("import-into", source_field),
      attribute.data("import-max-bytes", int.to_string(max_body_bytes)),
      attribute.data(
        "import-failed-label",
        t.import_failed(max_body_bytes / 1024),
      ),
    ]),
  ])
}

/// YAML / Visual toggle. Visual asks the server for the blocks first; the
/// switch happens once it answers with `visual-ready` (ADR 0024).
fn mode_switch(t: texts.EditorTexts, visual: Bool) -> Element(a) {
  segmented.view(label: t.edit_mode, options: [
    segmented.Option(t.mode_yaml, !visual, [
      attribute.data("mode-switch", "yaml"),
    ]),
    segmented.Option(t.mode_visual, visual, [
      attribute.data("mode-switch", "visual"),
      attribute.attribute("hx-post", "/editor/visual"),
      attribute.attribute("hx-include", "#" <> source_field),
      attribute.attribute("hx-target", "#visual"),
    ]),
  ])
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

/// `POST /` — the editor in the posted `lang`, keeping the posted `yaml`
/// (`example` when missing) and, if the YAML fits the blocks, the posted
/// `mode`. The language switch submits here (ADR 0025).
pub fn switch_language(
  request: Request,
  max_body_bytes: Int,
  example: String,
  build: Build,
) -> Response {
  use fields <- require_form_within(request, max_body_bytes)
  let lang = option.from_result(list.key_find(fields, "lang"))
  let source = list.key_find(fields, "yaml") |> result.unwrap(example)
  let blocks = case list.key_find(fields, "mode") {
    Ok("visual") ->
      option.from_result(result.replace_error(draft.from_yaml(source), Nil))
    _ -> None
  }
  editor_page(
    i18n.from_request(request, lang),
    source,
    max_body_bytes,
    blocks,
    build,
  )
}

/// `POST /editor/preview` — validation status for `#validation`, and for a
/// valid document the rendered pages swapped out of band into `#preview`
/// (ADR 0041). An invalid document leaves the last good preview in place.
pub fn preview(
  request: Request,
  locale: Locale,
  renderer: Renderer,
  max_body_bytes: Int,
) -> Response {
  use source <- require_yaml_field(request, max_body_bytes)
  let texts = i18n.texts(locale)
  case decode.from_yaml(source) {
    Error(errors) -> fragment(errors_view(texts, errors), 200)
    Ok(cv) -> {
      let pages = case renderer.render_svg_pages(cv) {
        Ok(pages) -> page_stack.view(pages:, page_label: texts.ui.page)
        Error(error) ->
          alert.view(alert.Danger, texts.editor.preview_unavailable, [
            html.text(render_error_message(texts, error)),
          ])
      }
      let status = alert.view(alert.Success, texts.editor.valid, [])
      let preview =
        html.div(
          [
            attribute.id("preview"),
            attribute.attribute("hx-swap-oob", "innerHTML"),
          ],
          [pages],
        )
      wisp.html_response(
        element.to_string(status) <> element.to_string(preview),
        200,
      )
    }
  }
}

/// `POST /editor/download` — the PDF as an attachment, or an error page.
pub fn download(
  request: Request,
  locale: Locale,
  renderer: Renderer,
  max_body_bytes: Int,
  build: Build,
) -> Response {
  use source <- require_yaml_field(request, max_body_bytes)
  case decode.from_yaml(source) {
    Error(errors) ->
      error_page(locale, build, errors_view(i18n.texts(locale), errors), 422)
    Ok(cv) -> download_pdf(locale, build, renderer, cv)
  }
}

fn download_pdf(
  locale: Locale,
  build: Build,
  renderer: Renderer,
  cv: Cv,
) -> Response {
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
      let texts = i18n.texts(locale)
      alert.view(alert.Danger, texts.editor.download_failed, [
        html.text(render_error_message(texts, error)),
      ])
      |> error_page(locale, build, _, status)
    }
  }
}

/// `POST /editor/visual` — the blocks for the posted YAML, or why it cannot
/// be shown as blocks. Success triggers `visual-ready`, which switches the
/// mode; errors are retargeted to the mode errors next to the source.
pub fn visual(
  request: Request,
  locale: Locale,
  max_body_bytes: Int,
) -> Response {
  use source <- require_yaml_field(request, max_body_bytes)
  let texts = i18n.texts(locale)
  case draft.from_yaml(source) {
    Ok(cv) ->
      fragment(visual.view(cv, texts), 200)
      |> response.set_header("hx-trigger", "visual-ready")
    // Shown in place of the validation status, which would otherwise list
    // the same problems in a second alert; the next edit validates again.
    Error(errors) ->
      errors_alert(texts, texts.editor.visual_needs_fixes, errors)
      |> fragment(200)
      |> response.set_header("hx-retarget", "#validation")
      |> response.set_header("hx-reswap", "innerHTML")
  }
}

/// `POST /editor/visual/update` — the YAML regenerated from the posted
/// blocks, after applying the requested `op` if any. With an op the blocks
/// are re-rendered too.
pub fn visual_update(
  request: Request,
  locale: Locale,
  max_body_bytes: Int,
) -> Response {
  use fields <- require_form_within(request, max_body_bytes)
  let cv = visual_form.parse(list.filter(fields, fn(field) { field.0 != "op" }))
  case list.key_find(fields, "op") {
    // Typing: the blocks stay as they are.
    Error(Nil) -> visual.sync(emit.to_yaml(cv))
    // A button: unknown ops change nothing but still re-render the blocks,
    // as the button expects.
    Ok(op) -> {
      let cv = case visual_form.parse_op(op) {
        Ok(op) -> visual_form.apply(cv, op)
        Error(Nil) -> cv
      }
      element.fragment([
        visual.view(cv, i18n.texts(locale)),
        visual.sync(emit.to_yaml(cv)),
      ])
    }
  }
  |> fragment(200)
}

/// Reads the `yaml` field of a form-encoded body.
fn require_yaml_field(
  request: Request,
  max_body_bytes: Int,
  next: fn(String) -> Response,
) -> Response {
  use fields <- require_form_within(request, max_body_bytes)
  case list.key_find(fields, "yaml") {
    Error(Nil) -> wisp.bad_request("Missing form field: yaml")
    Ok(source) -> next(source)
  }
}

/// Reads a form-encoded body whose decoded names and values together stay
/// within `max_body_bytes`. URL encoding can triple the size of the text,
/// so the body limit is relaxed accordingly.
fn require_form_within(
  request: Request,
  max_body_bytes: Int,
  next: fn(List(#(String, String))) -> Response,
) -> Response {
  let request = wisp.set_max_body_size(request, max_body_bytes * 3)
  use form <- wisp.require_form(request)
  let size =
    list.fold(form.values, 0, fn(size, field) {
      size + string.byte_size(field.0) + string.byte_size(field.1)
    })
  case size > max_body_bytes {
    True -> wisp.content_too_large()
    False -> next(form.values)
  }
}

fn errors_view(texts: Texts, errors: List(DecodeError)) -> Element(a) {
  errors_alert(texts, texts.editor.problems(list.length(errors)), errors)
}

fn errors_alert(
  texts: Texts,
  title: String,
  errors: List(DecodeError),
) -> Element(a) {
  // yamerl aborts at the first syntax error, so later problems stay hidden.
  let hint = case list.any(errors, is_syntax_error) {
    True -> html.p([], [html.text(texts.editor.syntax_hint)])
    False -> element.none()
  }
  alert.view(alert.Danger, title, [
    error_list.view(
      errors: list.map(errors, describe_error(texts.editor, _)),
      document_label: texts.ui.whole_document,
      jump_label: texts.ui.show_in_editor,
    ),
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
fn describe_error(t: texts.EditorTexts, error: DecodeError) -> error_list.Item {
  case error {
    SchemaError(path:, problem:) ->
      error_list.Item(
        location: path,
        message: t.schema_problem(problem),
        target: None,
      )
    SyntaxError(message:, line: 0, ..) ->
      error_list.Item(location: "", message:, target: None)
    SyntaxError(message:, line:, column:) ->
      error_list.Item(
        location: t.location(line, column),
        message:,
        target: Some(error_list.Target(field: source_field, line:, column:)),
      )
    DocumentTooComplex ->
      error_list.Item(location: "", message: t.too_complex, target: None)
    DocumentTooLarge(max_nodes:) ->
      error_list.Item(
        location: "",
        message: t.too_large(max_nodes),
        target: None,
      )
  }
}

fn render_error_message(texts: Texts, error: RenderError) -> String {
  case error {
    render.Overloaded -> {
      wisp.log_warning("editor render rejected: server overloaded")
      texts.editor.busy
    }
    render.TimedOut -> {
      wisp.log_warning("editor render timed out")
      texts.editor.timed_out
    }
    render.RendererUnavailable(reason:) -> {
      wisp.log_error("renderer unavailable: " <> reason)
      texts.editor.renderer_unavailable
    }
    render.CompileFailed(output:) -> {
      wisp.log_error("render failed: " <> output)
      texts.editor.render_failed
    }
  }
}

fn fragment(view: Element(a), status: Int) -> Response {
  wisp.html_response(element.to_string(view), status)
}

/// A full page showing `message` with a way back to the editor.
fn error_page(
  locale: Locale,
  build: Build,
  message: Element(a),
  status: Int,
) -> Response {
  let t = i18n.texts(locale).editor
  shell.view(
    locale:,
    language_form: None,
    build:,
    title:,
    actions: [],
    content: [
      panel.view(
        title: t.cannot_create_pdf,
        actions: [html.a([attribute.href("/")], [html.text(t.back_to_editor)])],
        body: [message],
      ),
    ],
  )
  |> element.to_document_string
  |> wisp.html_response(status)
}
