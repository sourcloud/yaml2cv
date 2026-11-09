//// Request routing and cross-cutting middleware.

import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/option.{None}
import wisp.{type Request, type Response}
import yaml2cv/build.{type Build}
import yaml2cv/notices.{type Component}
import yaml2cv/render.{type Renderer}
import yaml2cv/web/api
import yaml2cv/web/compress
import yaml2cv/web/editor
import yaml2cv/web/i18n
import yaml2cv/web/licenses

/// Everything a request handler needs, injected so tests can swap parts.
pub type Context {
  Context(
    renderer: Renderer,
    max_body_bytes: Int,
    /// Directory served under `/static`.
    static_directory: String,
    /// Shown in the page footer (ADR 0031).
    build: Build,
    /// YAML preloaded into the editor.
    example_cv: String,
    /// Third-party components shown at `/licenses` (ADR 0032).
    notices: List(Component),
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
    [] ->
      case request.method {
        http.Get ->
          editor.page(
            locale(request),
            context.example_cv,
            context.max_body_bytes,
            context.build,
          )
        http.Post ->
          editor.switch_language(
            request,
            context.max_body_bytes,
            context.example_cv,
            context.build,
          )
        _ -> wisp.method_not_allowed([http.Get, http.Post])
      }
      |> localised
    ["editor", "validate"] -> {
      use <- wisp.require_method(request, http.Post)
      editor.validate(request, locale(request), context.max_body_bytes)
      |> localised
    }
    ["editor", "preview"] -> {
      use <- wisp.require_method(request, http.Post)
      editor.preview(
        request,
        locale(request),
        context.renderer,
        context.max_body_bytes,
      )
      |> localised
    }
    ["editor", "visual"] -> {
      use <- wisp.require_method(request, http.Post)
      editor.visual(request, locale(request), context.max_body_bytes)
      |> localised
    }
    ["editor", "visual", "update"] -> {
      use <- wisp.require_method(request, http.Post)
      editor.visual_update(request, locale(request), context.max_body_bytes)
      |> localised
    }
    ["editor", "download"] -> {
      use <- wisp.require_method(request, http.Post)
      editor.download(
        request,
        locale(request),
        context.renderer,
        context.max_body_bytes,
        context.build,
      )
      |> localised
    }
    ["licenses"] -> {
      use <- wisp.require_method(request, http.Get)
      // htmx asks for the body only, to show it in the footer dialog.
      case request.get_header(request, "hx-request") {
        Ok(_) -> licenses.fragment(locale(request), context.notices)
        Error(Nil) ->
          licenses.page(locale(request), context.build, context.notices)
      }
      |> localised
      |> response.prepend_header("vary", "hx-request")
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

fn locale(request: Request) -> i18n.Locale {
  i18n.from_request(request, None)
}

/// Marks a response whose language depends on the request (ADR 0025).
fn localised(response: Response) -> Response {
  response.set_header(response, "vary", "accept-language, " <> i18n.header)
}

fn security_headers(next: fn() -> Response) -> Response {
  next()
  |> response.set_header("content-security-policy", content_security_policy)
  |> response.set_header("x-content-type-options", "nosniff")
  |> response.set_header("referrer-policy", "no-referrer")
}
