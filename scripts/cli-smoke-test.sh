#!/bin/sh
# Smoke-tests the command-line mode of a yaml2cv image (ADR 0048) the way
# the README documents it: no network, the caller's user, a mounted
# working directory.
# Usage: scripts/cli-smoke-test.sh [image] [engine]
set -eu

image="${1:-yaml2cv:dev}"
engine="${2:-podman}"
example="$(dirname "$0")/../priv/examples/example.yaml"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

yaml2cv() {
  "$engine" run --rm -i --network none -u "$(id -u):$(id -g)" \
    -v "$tmp:/work" -w /work "$image" "$@"
}

cp "$example" "$tmp/cv-en.yaml"
printf 'schema_version: 1\nperson: {}\nsections: []\n' > "$tmp/bad.yaml"

yaml2cv render cv-en.yaml
[ "$(head -c 5 "$tmp/cv-en.pdf")" = "%PDF-" ] || { echo "render wrote no PDF" >&2; exit 1; }
echo "ok   render file"

yaml2cv render - < "$tmp/cv-en.yaml" > "$tmp/stdout.pdf"
# Renders differ in a few ID bytes, but not in size; re-encoded or
# truncated output would.
[ "$(wc -c < "$tmp/stdout.pdf")" -eq "$(wc -c < "$tmp/cv-en.pdf")" ] \
  || { echo "stdout PDF differs in size from file output" >&2; exit 1; }
echo "ok   render stdin to stdout"

status=0
yaml2cv validate --json bad.yaml 2> "$tmp/err" || status=$?
[ "$status" -eq 1 ] || { echo "validate exited with $status, expected 1" >&2; exit 1; }
grep -q '"type":"/problems/invalid-cv"' "$tmp/err" || { echo "no invalid-cv problem" >&2; exit 1; }
echo "ok   validate"
