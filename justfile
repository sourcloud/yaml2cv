# List available recipes
default:
    @just --list

# Run the test suite
test:
    gleam test

# Format sources
fmt:
    gleam format src test dev

# Fail if manifest.toml is out of date with gleam.toml (ADR 0027)
deps-check:
    #!/usr/bin/env bash
    set -euo pipefail
    locked="$(mktemp)"
    trap 'rm -f "$locked"' EXIT
    cp manifest.toml "$locked"
    gleam deps download
    if ! diff -u "$locked" manifest.toml; then
        echo "manifest.toml is out of date with gleam.toml." >&2
        echo "Commit the regenerated manifest.toml together with gleam.toml." >&2
        exit 1
    fi

# Check the lockfile, formatting and types, then run tests (what CI runs)
check: deps-check
    gleam format --check src test dev
    gleam check
    gleam test

# Start the web server
run:
    gleam run

# Re-run tests on every change
watch:
    watchexec --exts gleam,typ,yaml --clear -- gleam test

# Build the production container image; uncommitted changes mark the
# revision as -dirty (ADR 0031)
image tag="yaml2cv:dev":
    podman build -t {{tag}} \
        --build-arg GIT_REVISION="$(git rev-parse HEAD)$(test -z "$(git status --porcelain)" || echo -dirty)" \
        --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" .

# Print release notes for the latest tag (what the release workflow publishes)
release-notes:
    git-cliff --latest --strip all
