# 0048. Render and validate CVs from the command line

- Status: Proposed
- Date: 2026-11-16

## Context

People want to keep their CV in a private Git repository and let a CI
pipeline (for example GitHub Actions) turn it into a PDF on every push or
on demand. Branches can then hold CVs with a different focus, and tags
mark versions. The CV is personal data, so it should not leave the runner.

The released image is only an HTTP server. A pipeline can start it as a
service container and `curl` the API, which works but needs a readiness
loop, an open port and a running server for a one-off job.

## Options

1. **Document the service container** — no code; clunky and needs a
   network inside the job.
2. **A command-line mode in the same binary and image** — `render` and
   `validate` subcommands that read files and write PDFs. The container can
   run with `--network none`, so privacy rests on the setup and not on
   trusting the application.
3. **A GitHub Action on top of 2** — most convenient on GitHub, ties the
   project to one CI vendor. Can follow later.

## Decision

Option 2, plus a README section "Rendering in CI" with a GitHub Actions
example. A GitHub Action is left for later.

**Dispatch.** Without arguments the program starts the server as before,
so existing deployments keep working; `serve` does the same explicitly.
`render`, `validate` and `help` (also `-h`, `--help`) select the
command-line mode. Anything else prints the usage and exits with 2. The
image's entrypoint passes extra arguments through, so
`podman run IMAGE render cv.yaml` works.

**Commands.**

```text
yaml2cv render [--json] [-o FILE | --out-dir DIR] INPUT...
yaml2cv validate [--json] INPUT...
```

- Every input is processed, even after one fails. `-` reads standard
  input; it may appear once.
- By default `cv-en.yaml` is rendered to `cv-en.pdf` next to it: a `.yaml`
  or `.yml` extension is replaced, any other name gets `.pdf` appended.
  Standard input is rendered to standard output.
- `-o FILE` names the output of a single input; `-o -` writes to standard
  output. `--out-dir DIR` writes all PDFs into an existing directory, named
  as above; two inputs with the same file name are a usage error. `-o` and
  `--out-dir` exclude each other and are not accepted by `validate`.
- Existing output files are overwritten.
- Progress (`cv.yaml: wrote cv.pdf`, `cv.yaml: valid`) goes to standard
  error, so standard output carries only a PDF.

**Errors.** As text on standard error, one line per problem, prefixed with
the file name (`<stdin>` for standard input):

```text
cv.yaml:3:5: mapping values are not allowed here
cv.yaml: person.name: is required
cv.yaml: rendering failed
```

With `--json`, every failed input instead produces one line on standard
error holding the RFC 9457 problem the HTTP API would return (ADR 0010),
with an extra `file` member. Render failures use the same problem types
as the API.

**Exit codes.** `0` all inputs succeeded; `1` at least one CV is invalid
or could not be rendered; `2` a usage error or an input that could not be
read or an output that could not be written. When both kinds occur, `2`
wins.

**Configuration.** The command-line mode reads the same environment
variables as the server; of those, `TYPST_PATH`, `WORK_DIR` and
`RENDER_TIMEOUT_MS` take effect. Renders run one after another.
`MAX_BODY_BYTES` does not apply to files, but the parser's node and time
limits do (ADR 0008).

**Container.** The image stays as it is (user `yaml2cv`, `WORKDIR /app`).
The documented invocation mounts the working directory and runs as the
caller so the PDFs belong to them:

```sh
podman run --rm --network none -u "$(id -u):$(id -g)" \
  -v "$PWD:/work" -w /work ghcr.io/sourcloud/yaml2cv:1 render cv.yaml
```

**Stability.** The subcommands, flags, default output names, the
`--json` format and the exit codes join the stable interfaces of
ADR 0033. The wording of text messages does not, like error messages of
the API.

## Consequences

- A CV can be rendered in CI or locally without starting a server and
  without network access.
- `argv` moves from a development to a runtime dependency.
- The problem documents are built in one place and shared by the API and
  the command line.
- A GitHub Action or a template repository can wrap the command later
  without changing it.
