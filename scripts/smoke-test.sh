#!/bin/sh
# Smoke-tests a running yaml2cv instance: health check, PDF render, editor
# page and preview. Usage: scripts/smoke-test.sh [base-url]
set -eu

base="${1:-http://localhost:8000}"
example="$(dirname "$0")/../priv/examples/example.yaml"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Wait up to 30 s for the server to come up.
i=0
until curl -sf "$base/healthz" >/dev/null; do
  i=$((i + 1))
  if [ "$i" -ge 30 ]; then
    echo "server at $base did not become healthy" >&2
    exit 1
  fi
  sleep 1
done
echo "ok   healthz"

curl -sf --data-binary @"$example" -H 'content-type: application/yaml' \
  "$base/api/v1/render" -o "$tmp/cv.pdf"
[ "$(head -c 5 "$tmp/cv.pdf")" = "%PDF-" ] || { echo "render did not return a PDF" >&2; exit 1; }
echo "ok   render"

curl -sf "$base/" | grep -q '<textarea' || { echo "editor page broken" >&2; exit 1; }
echo "ok   editor"

curl -sf --data-urlencode yaml@"$example" "$base/editor/preview" \
  | grep -q 'data:image/png;base64,' || { echo "preview broken" >&2; exit 1; }
echo "ok   preview"
