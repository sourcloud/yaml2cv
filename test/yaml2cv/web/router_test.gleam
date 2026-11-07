import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/string
import wisp/simulate
import yaml2cv/render.{
  type RenderError, CompileFailed, Overloaded, Renderer, RendererUnavailable,
  TimedOut,
}
import yaml2cv/web/router.{Context}

const valid_cv = "schema_version: 1\nperson: {name: Jane Roe}\nsections: []\n"

fn context(result: Result(BitArray, RenderError)) -> router.Context {
  Context(renderer: Renderer(render: fn(_) { result }), max_body_bytes: 1024)
}

fn post(path: String, body: String, content_type: String) {
  simulate.request(http.Post, path)
  |> simulate.string_body(body)
  |> simulate.header("content-type", content_type)
  |> router.handle_request(context(Ok(<<"%PDF-fake">>)))
}

fn problem_type(response) -> String {
  let body = simulate.read_body(response)
  let assert Ok(#(_, rest)) = string.split_once(body, "\"type\":\"")
  let assert Ok(#(slug, _)) = string.split_once(rest, "\"")
  slug
}

pub fn health_check_test() {
  let response =
    simulate.request(http.Get, "/healthz")
    |> router.handle_request(context(Ok(<<>>)))
  assert response.status == 200
  assert simulate.read_body(response) == "{\"status\":\"ok\"}"
}

pub fn validate_accepts_valid_cv_test() {
  let response = post("/api/v1/validate", valid_cv, "application/yaml")
  assert response.status == 200
  assert simulate.read_body(response) == "{\"valid\":true}"
}

pub fn validate_accepts_yaml_content_types_with_parameters_test() {
  assert post("/api/v1/validate", valid_cv, "text/yaml; charset=utf-8").status
    == 200
  assert post("/api/v1/validate", valid_cv, "text/plain").status == 200
}

pub fn validate_reports_schema_errors_as_problem_test() {
  let response =
    post("/api/v1/validate", "schema_version: 1\nsections: []", "text/yaml")
  assert response.status == 422
  assert response.get_header(response, "content-type")
    == Ok("application/problem+json")
  assert simulate.read_body(response)
    == "{\"type\":\"/problems/invalid-cv\",\"title\":\"Invalid CV\","
    <> "\"status\":422,\"detail\":\"The CV does not match the schema.\","
    <> "\"errors\":[{\"path\":\"person\",\"message\":\"is required\"}]}"
}

pub fn validate_reports_yaml_syntax_errors_as_problem_test() {
  let response = post("/api/v1/validate", "a: [b\n", "application/yaml")
  assert response.status == 422
  assert problem_type(response) == "/problems/invalid-yaml"
  assert string.contains(simulate.read_body(response), "\"line\":")
}

pub fn rejects_non_utf8_body_test() {
  let response =
    simulate.request(http.Post, "/api/v1/validate")
    |> simulate.bit_array_body(<<0xff, 0xfe>>)
    |> simulate.header("content-type", "application/yaml")
    |> router.handle_request(context(Ok(<<>>)))
  assert response.status == 422
  assert problem_type(response) == "/problems/invalid-yaml"
}

pub fn rejects_unsupported_media_type_test() {
  let response = post("/api/v1/validate", valid_cv, "application/json")
  assert response.status == 415
  assert problem_type(response) == "/problems/unsupported-media-type"
}

pub fn rejects_missing_content_type_test() {
  let request =
    simulate.request(http.Post, "/api/v1/render")
    |> simulate.string_body(valid_cv)
  let headers =
    list.filter(request.headers, fn(header) { header.0 != "content-type" })
  let response =
    request.Request(..request, headers:)
    |> router.handle_request(context(Ok(<<>>)))
  assert response.status == 415
}

pub fn rejects_too_large_body_test() {
  let response =
    post("/api/v1/render", valid_cv <> string.repeat("#", 1024), "text/yaml")
  assert response.status == 413
  assert problem_type(response) == "/problems/content-too-large"
}

pub fn render_returns_pdf_test() {
  let response = post("/api/v1/render", valid_cv, "application/yaml")
  assert response.status == 200
  assert response.get_header(response, "content-type") == Ok("application/pdf")
  assert response.get_header(response, "content-disposition")
    == Ok("inline; filename=\"cv.pdf\"")
  assert simulate.read_body_bits(response) == <<"%PDF-fake">>
}

pub fn render_validates_before_rendering_test() {
  let response = post("/api/v1/render", "schema_version: 1", "text/yaml")
  assert response.status == 422
  assert problem_type(response) == "/problems/invalid-cv"
}

fn render_with(result: Result(BitArray, RenderError)) {
  simulate.request(http.Post, "/api/v1/render")
  |> simulate.string_body(valid_cv)
  |> simulate.header("content-type", "application/yaml")
  |> router.handle_request(context(result))
}

pub fn render_maps_overload_to_503_with_retry_after_test() {
  let response = render_with(Error(Overloaded))
  assert response.status == 503
  assert problem_type(response) == "/problems/overloaded"
  assert response.get_header(response, "retry-after") == Ok("5")
}

pub fn render_maps_timeout_to_503_test() {
  let response = render_with(Error(TimedOut))
  assert response.status == 503
  assert problem_type(response) == "/problems/render-timeout"
}

pub fn render_maps_unavailable_renderer_to_503_test() {
  let response = render_with(Error(RendererUnavailable("no typst")))
  assert response.status == 503
  assert problem_type(response) == "/problems/renderer-unavailable"
  assert !string.contains(simulate.read_body(response), "no typst")
}

pub fn render_hides_compile_output_test() {
  let response = render_with(Error(CompileFailed("secret /tmp/path")))
  assert response.status == 500
  assert problem_type(response) == "/problems/render-failed"
  assert !string.contains(simulate.read_body(response), "secret")
}

pub fn rejects_wrong_method_test() {
  let response =
    simulate.request(http.Get, "/api/v1/render")
    |> router.handle_request(context(Ok(<<>>)))
  assert response.status == 405
}

pub fn unknown_path_is_not_found_test() {
  let response =
    simulate.request(http.Get, "/nope")
    |> router.handle_request(context(Ok(<<>>)))
  assert response.status == 404
}
