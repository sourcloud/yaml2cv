//// Request routing and cross-cutting middleware.

import gleam/http
import gleam/http/response
import gleam/json
import wisp.{type Request, type Response}
import yaml2cv/render.{type Renderer}
import yaml2cv/web/api
import yaml2cv/web/compress
import yaml2cv/web/editor

/// Everything a request handler needs, injected so tests can swap parts.
pub type Context {
  Context(
    renderer: Renderer,
    max_body_bytes: Int,
    /// Directory served under `/static`.
    static_directory: String,
    /// YAML preloaded into the editor.
    example_cv: String,
  )
}

const content_security_policy =
  "default-src 'self'; img-src 'self' data:; "
  <> "style-src 'self'; script-src 'self'; object-src 'none'; "
  <> "base-uri 'none'; form-action 'self'; frame-ancestors 'none'"

/// Handles one HTTP request.
pub fn handle_request(request: Request, context: Context) -> Response {
  use <- wisp.log_request(request)
  use <- wisp.rescue_crashes
  use request <- wisp.handle_head(request)
  use <- compress.gzip(request)
  use <- security_headers
  use <- wisp.serve_static(
    request,
    under: "/static",
    from: context.static_directory,
  )

  case wisp.path_segments(request) {
    [] -> {
      use <- wisp.require_method(request, http.Get)
      editor.page(context.example_cv)
    }
    ["editor", "validate"] -> {
      use <- wisp.require_method(request, http.Post)
      editor.validate(request, context.max_body_bytes)
    }
    ["editor", "preview"] -> {
      use <- wisp.require_method(request, http.Post)
      editor.preview(request, context.renderer, context.max_body_bytes)
    }
    ["editor", "visual"] -> {
      use <- wisp.require_method(request, http.Post)
      editor.visual(request, context.max_body_bytes)
    }
    ["editor", "visual", "update"] -> {
      use <- wisp.require_method(request, http.Post)
      editor.visual_update(request, context.max_body_bytes)
    }
    ["editor", "download"] -> {
      use <- wisp.require_method(request, http.Post)
      editor.download(request, context.renderer, context.max_body_bytes)
    }
    ["healthz"] -> {
      use <- wisp.require_method(request, http.Get)
      json.object([#("status", json.string("ok"))])
      |> json.to_string
      |> wisp.json_response(200)
    }
    ["api", "v1", "validate"] -> {
      use <- wisp.require_method(request, http.Post)
      api.validate(request, context.max_body_bytes)
    }
    ["api", "v1", "render"] -> {
      use <- wisp.require_method(request, http.Post)
      api.render_pdf(request, context.renderer, context.max_body_bytes)
    }
    _ -> wisp.not_found()
  }
}

fn security_headers(next: fn() -> Response) -> Response {
  next()
  |> response.set_header("content-security-policy", content_security_policy)
  |> response.set_header("x-content-type-options", "nosniff")
  |> response.set_header("referrer-policy", "no-referrer")
}
