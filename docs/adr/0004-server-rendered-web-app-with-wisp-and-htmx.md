# 0004. Server-rendered web app with Wisp and htmx

- Status: Accepted
- Date: 2026-11-07

## Context

Beyond the existing "upload YAML, get PDF" endpoint we want a browser editor
with live validation and preview. The app should stay lightweight and easy to
deploy.

## Options

1. **Wisp + Mist + htmx** — server-rendered HTML fragments, minimal JS.
2. **Lustre server components** — LiveView-like stateful processes over
   WebSockets; more moving parts.
3. **Lustre SPA + JSON API** — two compile targets and a frontend build.

## Decision

Option 1. Mist is the HTTP server, Wisp the request/response framework.
HTML is built with `lustre/element` used purely as a type-safe HTML builder;
htmx (vendored static file) drives validation and preview requests.

The first milestone is **stateless**: no database, no accounts. Endpoints:

- `POST /api/v1/render` — YAML in, PDF out (422 with structured errors).
- `POST /api/v1/validate` — YAML in, validation result out.
- `GET /` and `/editor/*` — editor page and htmx fragments.
- `GET /healthz`.

## Consequences

- Simple to test with `wisp/testing`, no JS build step.
- Persistence or accounts would need a new ADR.
