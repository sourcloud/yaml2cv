//// Request handling for the admin listener (ADR 0020). It is served on its
//// own port so the public listener never exposes these details.

import gleam/http
import gleam/json.{type Json}
import wisp.{type Request, type Response}
import yaml2cv/observe/document.{type Document}

/// Handles one request. `document` builds a fresh document, so every response
/// carries a current status sample.
pub fn handle_request(
  request: Request,
  document: fn() -> Document,
) -> Response {
  use <- wisp.log_request(request)
  use <- wisp.rescue_crashes
  use request <- wisp.handle_head(request)
  case wisp.path_segments(request) {
    [] -> respond(request, fn() { document.to_json(document()) })
    ["config"] -> respond(request, fn() { document.config_json(document()) })
    ["status"] ->
      respond(request, fn() { document.status_json(document().status) })
    ["healthz"] ->
      respond(request, fn() { json.object([#("status", json.string("ok"))]) })
    _ -> wisp.not_found()
  }
}

fn respond(request: Request, body: fn() -> Json) -> Response {
  use <- wisp.require_method(request, http.Get)
  body() |> json.to_string |> wisp.json_response(200)
}
