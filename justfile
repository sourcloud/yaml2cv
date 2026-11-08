# List available recipes
default:
    @just --list

# Run the test suite
test:
    gleam test

# Format sources
fmt:
    gleam format src test dev

# Check formatting and types, then run tests (what CI runs)
check:
    gleam format --check src test dev
    gleam check
    gleam test

# Start the web server
run:
    gleam run

# Re-run tests on every change
watch:
    watchexec --exts gleam,typ,yaml --clear -- gleam test

# Build the production container image
image tag="yaml2cv:dev":
    podman build -t {{tag}} .
