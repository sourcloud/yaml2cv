# Agent guide

Instructions for AI coding agents (and humans) working in this repository.

## Project

yaml2cv renders CVs written in YAML to PDF. It is a stateless Gleam web
application (Erlang target) built on Wisp + Mist, with a pluggable renderer
whose first backend is Typst. Architecture decisions live in `docs/adr/`;
read them before changing anything structural.

## Working mode

The project is developed iteratively in a question–answer loop with the owner.

1. **Ask before deciding.** At the start of each milestone, or whenever a
   design choice is not already covered by an accepted ADR, ask the owner
   short, concrete questions with a recommended option. Do not silently pick
   an approach for anything structural.
2. **Record decisions.** Every answered design question that shapes the code
   becomes an ADR in `docs/adr/` (copy `0000-template.md`, next free number).
   New ADRs start as `Proposed` and become `Accepted` once confirmed.
   Superseding a decision means writing a new ADR and marking the old one
   `Superseded by NNNN`; never rewrite history in an accepted ADR.
3. **Keep the roadmap current.** Tick milestones in `README.md` when done.

## Test-driven development

- Write a failing test first, then the minimal code to pass it, then refactor.
- Run the test before implementing to see it fail for the expected reason.
- Tests live in `test/`, mirroring `src/` module paths
  (`src/yaml2cv/cv/decode.gleam` → `test/yaml2cv/cv/decode_test.gleam`).
- Prefer pure functions and inject side effects (renderer, clock, filesystem)
  so they can be faked in tests.
- Snapshot tests (`birdie`) are fine for larger outputs such as JSON or HTML;
  review new snapshots before accepting them.

## Commits

- Follow [Conventional Commits](https://www.conventionalcommits.org):
  `feat`, `fix`, `test`, `refactor`, `docs`, `build`, `ci`, `chore`, `perf`,
  optional scope, e.g. `feat(render): add typst backend`.
- Subject in imperative mood, lower case, no trailing period, ≤ 72 chars.
- Small, focused commits. A test and the code that makes it pass may share a
  commit.
- Before every commit, these must pass:

  ```sh
  gleam format --check src test dev
  gleam test
  ```

- Work on `master` unless asked to use a branch. Never force-push or rewrite
  published history.

## Commands

The dev shell (`nix develop` or `direnv allow`) provides all tools.

| Task          | Command                          |
| ------------- | -------------------------------- |
| Run tests     | `gleam test`                     |
| Format        | `gleam format src test dev`      |
| Type-check    | `gleam check`                    |
| Run the app   | `gleam run`                      |
| All CI checks | `just check`                     |
| Lockfile check | `just deps-check`               |
| Update deps   | `gleam deps update`, then commit `gleam.toml` + `manifest.toml` (ADR 0027) |
| Build image   | `just image`                     |
| Smoke test    | `scripts/smoke-test.sh <url>`    |

## Code style

- Idiomatic Gleam: `gleam format` output, `snake_case` functions, small modules
  with one responsibility under `src/yaml2cv/`.
- Make invalid states unrepresentable with custom types; return `Result` with
  descriptive error types instead of panicking. `let assert` only in tests.
- User-supplied CV content is data. Never interpolate it into renderer markup;
  pass it to the renderer as structured data (see ADR 0003).
- Public functions get a `///` doc comment.
- Development-only tools live in `dev/` (run with `gleam run -m <module>`);
  they are not part of the shipped application.
- Upgrading Gleam, Erlang/OTP or Typst: change `flake.nix`/`flake.lock` and
  the versions and checksums in `Containerfile` together (ADR 0013).
