# yaml2cv

Keep your CV as structured data, get a typeset PDF back.

yaml2cv takes a CV written in a small YAML schema, validates it and renders it
to PDF using [Typst](https://typst.app). It ships as a lightweight, stateless
web application with an HTTP API and a browser-based editor with live
validation and preview.

Written in [Gleam](https://gleam.run) on the BEAM. Design decisions are
documented as [architecture decision records](docs/adr/).

## Example

```yaml
schema_version: 1

style:
  theme: classic   # or: minimal, studio, spotlight, cover
  color: blue
  paper: a4        # or: letter
  photo_shape: rectangle   # or: rounded, circle

person:
  name: John Doe
  title: Software Engineer
  # photo: data:image/jpeg;base64,...   # optional, see below

contact:
  email: john.doe@example.com

sections:
  - name: Professional Experience
    entries:
      - timespan: since 2020
        title: Example Job
        organization: Example Company
        location: Example City
        bullets:
          - This will be rendered as a bullet point

  - name: Languages
    kind: skills
    items:
      - name: English
        level: Native
```

The full schema is documented in
[ADR 0007](docs/adr/0007-cv-schema-version-1.md); a complete example is in
[`priv/examples/example.yaml`](priv/examples/example.yaml). The editor's
**Schema** button shows a reference of every key and option.

## Quickstart

The development environment is provided by a Nix flake (flakes must be
enabled):

```sh
direnv allow     # or: nix develop
just             # list tasks
just check       # format check, type-check, tests
just run         # start the server on http://localhost:8000
```

Open http://localhost:8000 for the editor: edit the YAML on the left, see
validation results and a live preview on the right, and download the PDF.
Switch the CV panel to **Visual** to edit the same document as building
blocks (person, contact, sections, entries, bullets, skills) instead of raw
YAML. The YAML stays the source of truth: every block edit is written back
to it, so it can be copied at any time. The first block edit rewrites the
YAML in a uniform layout, dropping comments (ADR 0024).

The service keeps nothing, so save your work: the **File** menu in the CV
panel copies the YAML, downloads it as `cv.yaml` and imports a saved file
back into the editor, all in the browser (ADR 0029).

The editor speaks English and German. It follows the browser's language;
the **EN | DE** switch in the header changes it, keeps the current YAML and
is remembered in the browser (ADR 0025). The HTTP API always answers in
English.

A profile photo is optional. It is stored inside the YAML as a base64 data
URI (`person.photo`), so the CV stays one self-contained file and the
service keeps nothing between requests. The photo field of the person block
in the editor's visual mode, next to the photo shape, crops and shrinks the
picked image in the browser and re-encodes it as JPEG, which removes EXIF data such as the GPS
location (ADR 0028).

Render a CV:

```sh
curl --data-binary @priv/examples/example.yaml \
     -H 'content-type: application/yaml' \
     http://localhost:8000/api/v1/render -o cv.pdf
```

## Container

```sh
podman build -t yaml2cv .        # or: just image
podman run --rm -p 8000:8000 yaml2cv
```

Released images are published to `ghcr.io/sourcloud/yaml2cv` for
`linux/amd64` and `linux/arm64`.

### Verifying an image

Release images carry signed SLSA build provenance (ADR 0031). It proves that
an image was built by this repository's release workflow and names the
commit it came from. Check the digest of the image you run:

```sh
podman image inspect --format '{{index .RepoDigests 0}}' ghcr.io/sourcloud/yaml2cv:<version>
gh attestation verify oci://ghcr.io/sourcloud/yaml2cv@sha256:<digest> \
  --repo sourcloud/yaml2cv
```

Every page of the editor shows the version and the commit the build claims
to come from, with a link to the source on GitHub. Builds from a working
tree with uncommitted changes (`just image`) are marked "modified". This is
self-reported and not a security check: a modified build can claim any
commit. Only the attestation is tamper-evident, and only the operator can
see which image a deployment runs.

### Deployment notes

- The service is stateless; run as many replicas as needed behind a load
  balancer. Rendering is CPU-bound; size `RENDER_CONCURRENCY` to the CPUs
  available to the container.
- It speaks plain HTTP. Terminate TLS at a reverse proxy or the platform's
  ingress.
- Rate-limit requests per client at that proxy, especially `POST
  /api/v1/render` and `/editor/*`. The built-in limiter caps parallel
  renders for the whole service, not per client, and the editor renders a
  preview whenever typing pauses.
- Set memory and CPU limits on the container (e.g. `--memory 512m
  --cpus 2`). Renders are bounded in time (`RENDER_TIMEOUT_MS`) but Typst's
  memory use is not limited by the application.
- HTML, JSON and preview responses are gzip-compressed by the service when
  the client accepts it; static files are not.
- `/healthz` is suitable for liveness and readiness probes.
- The image runs as an unprivileged user and works with a read-only root
  filesystem as long as `/tmp` is writable:

  ```sh
  podman run --read-only --tmpfs /tmp --cap-drop=ALL \
    --security-opt no-new-privileges -p 8000:8000 yaml2cv
  ```

- Third-party license notices are in `/app/THIRD_PARTY_NOTICES.md` and
  `/app/licenses/` inside the image. A running instance shows them at
  `/licenses`, linked from the page footer. Running from source
  (`gleam run`), the page lists no third-party components.

## HTTP API

| Endpoint | Request | Success |
| --- | --- | --- |
| `POST /api/v1/render` | YAML body | `200 application/pdf` |
| `POST /api/v1/validate` | YAML body | `200 {"valid": true}` |
| `GET /healthz` | | `200 {"status": "ok"}` |

The YAML body must be sent as `application/yaml`, `text/yaml` or
`text/plain`. Errors are
[RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) problem details, e.g.:

```json
{
  "type": "/problems/invalid-cv",
  "title": "Invalid CV",
  "status": 422,
  "detail": "The CV does not match the schema.",
  "errors": [{ "path": "person.name", "message": "is required" }]
}
```

The full list of problem types is in
[ADR 0010](docs/adr/0010-http-api.md).

## Configuration

All settings are environment variables:

| Variable | Default | Meaning |
| --- | --- | --- |
| `PORT` | `8000` | HTTP port |
| `BIND_ADDRESS` | `0.0.0.0` | Interface to listen on |
| `TYPST_PATH` | `typst` | Typst executable |
| `WORK_DIR` | `$TMPDIR/yaml2cv` | Temporary render jobs |
| `RENDER_TIMEOUT_MS` | `10000` | Kill a compile after this time |
| `RENDER_CONCURRENCY` | CPU schedulers | Parallel compiles |
| `RENDER_QUEUE_WAIT_MS` | `5000` | Max wait for a free render slot |
| `MAX_BODY_BYTES` | `1048576` | Request body limit; covers a CV with a photo at the 512 KiB limit (ADR 0028) |
| `ADMIN_BIND_ADDRESS` | `127.0.0.1` | Interface of the admin listener |
| `ADMIN_PORT` | `9000` | Port of the admin listener; must differ from `PORT` |
| `PHONE_HOME_TARGET` | unset | `host:port` of a UDP collector; enables heartbeats |
| `HEARTBEAT_INTERVAL_MS` | `10000` | Time between heartbeats |
| `HEARTBEAT_MIA_MS` | 3 × interval | Silence after which a collector should consider the instance missing |
| `REQUIRES` | empty | Comma-separated components this instance depends on |
| `DEPLOYED_BY`, `DEPLOYED_FROM`, `DEPLOYED_ON` | unset | Deployment details shown by the admin endpoint |
| `GIT_REVISION`, `BUILD_DATE` | set by the image build | Build details shown by the admin endpoint |

## Observability

A second HTTP listener (`ADMIN_PORT`, default 9000) describes the running
instance: name, version, dependencies, reachable addresses, heartbeat timing,
build and deployment details, configuration and system load (memory, CPU
load, I/O pressure, disk). It serves `GET /` (everything), `/config`,
`/status` and `/healthz`. It only listens on loopback by default, also in
the container image; to reach it from outside, set
`ADMIN_BIND_ADDRESS=0.0.0.0` and publish the port. Keep it off the internet;
it reveals internal details.

```sh
podman run --rm -p 8000:8000 -p 9000:9000 -e ADMIN_BIND_ADDRESS=0.0.0.0 yaml2cv
curl http://localhost:9000/status
# {"memory":13,"cpu_load":[1.31,0.54,0.3],"io_load":0.0,"disk":62}
```

With `PHONE_HOME_TARGET=collector:5140` the instance also sends a compact
JSON heartbeat by UDP every `HEARTBEAT_INTERVAL_MS`, with links back to the
admin endpoint, so also set `ADMIN_BIND_ADDRESS` to an address the collector
can reach. The format is documented in
[ADR 0020](docs/adr/0020-phone-home-observability.md).

## Versioning

yaml2cv follows [Semantic Versioning](https://semver.org). From 1.0.0 on,
these interfaces change incompatibly only in a new major version: CV schema
version 1, the HTTP API under `/api/v1` with its problem types, and the
environment variables above. How a CV looks within a theme, error message
wording, the editor and the admin listener may change in any release.
Only the latest release gets fixes. Details are in
[ADR 0033](docs/adr/0033-stability-promise-for-1-0.md).

## Roadmap

- [x] M0 — Repository hygiene: license, docs, workflow, ADRs
- [x] M1 — Dev environment (Nix flake), Gleam scaffold, CI
- [x] M2 — Domain model and YAML validation
- [x] M3 — Pluggable renderer with Typst backend
- [x] M4 — HTTP API
- [x] M5 — Browser editor (htmx)
- [x] M6 — Container image, removal of the legacy Python app, v0.1.0
- [x] M7 — Minimal single-column theme
- [x] M8 — Phone home: admin endpoint and UDP heartbeat
- [x] M9 — Visual block editor next to the YAML source
- [x] M10 — UI localisation (English, German)
- [x] M11 — Optional profile photo, kept inside the CV document (ADR 0028)
- [x] M12 — Photo-centred themes for creative jobs: studio, spotlight, cover
  (ADR 0030)
- [x] M13 — Signed build provenance and a footer linking to the source
  (ADR 0031)
- [x] M14 — 1.0: stability promise (ADR 0033), security policy, major-version
  image tag

## Security

Report vulnerabilities privately; see [SECURITY.md](SECURITY.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Copyright 2022–2026 Sascha Scheid.

Licensed under the [Apache License, Version 2.0](LICENSE).
