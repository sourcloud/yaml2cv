# 0010. HTTP API, configuration, limits and logging

- Status: Accepted
- Date: 2026-11-07

## Context

M4 exposes validation and rendering over HTTP (ADR 0004). The service must
be configurable for container deployment, robust against oversized or
malicious input, and observable without leaking personal data.

## Decision

**Configuration** comes from environment variables only, parsed and
validated at startup; invalid values abort startup with a clear message.

| Variable | Default | Meaning |
| --- | --- | --- |
| `PORT` | `8000` | HTTP port |
| `BIND_ADDRESS` | `0.0.0.0` | Interface to listen on |
| `TYPST_PATH` | `typst` | Typst executable (name on `PATH` or path) |
| `WORK_DIR` | `$TMPDIR/yaml2cv` or `/tmp/yaml2cv` | Temporary render jobs |
| `RENDER_TIMEOUT_MS` | `10000` | Kill a compile after this time |
| `RENDER_CONCURRENCY` | number of schedulers | Parallel compiles |
| `RENDER_QUEUE_WAIT_MS` | `5000` | Max wait for a free render slot |
| `MAX_BODY_BYTES` | `262144` | Request body limit |

**Endpoints.** The CV is sent as the raw request body with content type
`application/yaml`, `text/yaml` or `text/plain`.

- `POST /api/v1/validate` — `200 {"valid": true}` or a problem response.
- `POST /api/v1/render` — `200 application/pdf` (inline, `cv.pdf`) or a
  problem response.
- `GET /healthz` — `200 {"status": "ok"}`.

**Errors** use RFC 9457 `application/problem+json` with `type`, `title`,
`status`, `detail`. `type` is a relative URI `/problems/<slug>`:

| Slug | Status | Extra members |
| --- | --- | --- |
| `invalid-yaml` | 422 | `line`, `column` |
| `invalid-cv` | 422 | `errors: [{path, message}]` |
| `unsupported-media-type` | 415 | |
| `content-too-large` | 413 | |
| `overloaded` | 503 | `Retry-After` header |
| `render-timeout` | 503 | |
| `renderer-unavailable` | 503 | |
| `render-failed` | 500 | |

Internal details (Typst output, file paths) are logged, never returned.

**Limits.** Besides the body limit, YAML parsing enforces a node budget so
that alias expansion ("billion laughs") cannot blow up a small document.

**Logging.** Wisp's access log plus Erlang `logger` messages for render
failures, timeouts and overload. CV content is personal data and is never
logged.

## Consequences

- No config file to mount; everything is visible in the container spec.
- Problem types can later be documented at their `/problems/<slug>` URIs.
