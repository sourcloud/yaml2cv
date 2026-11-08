import gleam/http
import gleam/http/response
import gleam/string
import wisp/simulate
import yaml2cv/render.{type RenderError, Overloaded, Renderer}
import yaml2cv/web/router.{Context}

const valid_cv = "schema_version: 1\nperson: {name: Jane Roe}\nsections: []\n"

fn context(pages: Result(List(BitArray), RenderError)) -> router.Context {
  Context(
    renderer: Renderer(
      render_pdf: fn(_) { Ok(<<"%PDF-fake">>) },
      render_svg_pages: fn(_) { pages },
    ),
    max_body_bytes: 1024,
    static_directory: "priv/static",
    example_cv: "person:\n  name: <Example>\n",
  )
}

fn get(path: String) {
  simulate.request(http.Get, path)
  |> router.handle_request(context(Ok([])))
}

fn post_form(path: String, yaml: String) {
  post_form_with(path, yaml, context(Ok([<<1, 2, 3>>])))
}

fn post_form_with(path: String, yaml: String, context: router.Context) {
  simulate.request(http.Post, path)
  |> simulate.form_body([#("yaml", yaml)])
  |> router.handle_request(context)
}

pub fn editor_page_preloads_example_test() {
  let response = get("/")
  assert response.status == 200
  assert response.get_header(response, "content-type")
    == Ok("text/html; charset=utf-8")
  let body = simulate.read_body(response)
  assert string.contains(body, "<textarea")
  assert string.contains(body, "name: &lt;Example&gt;")
}

pub fn pages_send_security_headers_test() {
  let response = get("/")
  let assert Ok(csp) = response.get_header(response, "content-security-policy")
  assert string.contains(csp, "default-src 'self'")
  assert string.contains(csp, "img-src 'self' data:")
  assert response.get_header(response, "x-content-type-options")
    == Ok("nosniff")
}

pub fn serves_static_assets_test() {
  let response = get("/static/css/app.css")
  assert response.status == 200
  assert response.get_header(response, "content-type")
    == Ok("text/css; charset=utf-8")
}

pub fn validate_reports_valid_cv_test() {
  let response = post_form("/editor/validate", valid_cv)
  assert response.status == 200
  assert string.contains(simulate.read_body(response), "ui-alert--success")
}

pub fn validate_lists_schema_errors_test() {
  let body =
    post_form("/editor/validate", "schema_version: 1\nsections: []\n")
    |> simulate.read_body
  assert string.contains(body, "ui-alert--danger")
  assert string.contains(body, "1 problem")
  assert string.contains(body, ">person</code>")
}

pub fn validate_shows_syntax_error_location_test() {
  let body = post_form("/editor/validate", "a: [b\n") |> simulate.read_body
  assert string.contains(body, "line 1, column 6")
}

pub fn preview_shows_pages_test() {
  let response = post_form("/editor/preview", valid_cv)
  assert response.status == 200
  assert string.contains(
    simulate.read_body(response),
    "src=\"data:image/svg+xml;base64,AQID\"",
  )
}

pub fn preview_keeps_last_result_for_invalid_cv_test() {
  let response = post_form("/editor/preview", "schema_version: 1")
  assert response.status == 204
}

pub fn preview_explains_render_errors_test() {
  let response =
    post_form_with("/editor/preview", valid_cv, context(Error(Overloaded)))
  assert response.status == 200
  let body = simulate.read_body(response)
  assert string.contains(body, "ui-alert--danger")
  assert string.contains(body, "busy")
}

pub fn download_returns_pdf_attachment_test() {
  let response = post_form("/editor/download", valid_cv)
  assert response.status == 200
  assert response.get_header(response, "content-type") == Ok("application/pdf")
  assert response.get_header(response, "content-disposition")
    == Ok("attachment; filename=\"cv.pdf\"")
}

pub fn download_of_invalid_cv_shows_errors_page_test() {
  let response = post_form("/editor/download", "schema_version: 1")
  assert response.status == 422
  let body = simulate.read_body(response)
  assert string.contains(body, "<!doctype html>")
  assert string.contains(body, "ui-error-list")
}

pub fn rejects_oversized_yaml_test() {
  let response = post_form("/editor/validate", string.repeat("#", 2000))
  assert response.status == 413
}

pub fn validate_explains_too_deeply_nested_yaml_test() {
  let nested = string.repeat("[", 30_000) <> string.repeat("]", 30_000)
  let body =
    post_form_with(
      "/editor/validate",
      nested,
      Context(..context(Ok([])), max_body_bytes: 100_000),
    )
    |> simulate.read_body
  assert string.contains(body, "nested too deeply")
}
