#!/bin/sh
# Smoke-tests a running yaml2cv instance: health check, PDF render, editor
# page and preview, plus the admin endpoint when its URL is given.
# Usage: scripts/smoke-test.sh [base-url] [admin-url]
set -eu

base="${1:-http://localhost:8000}"
admin="${2:-}"
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
  | grep -q 'data:image/svg+xml,' || { echo "preview broken" >&2; exit 1; }
echo "ok   preview"

if [ -n "$admin" ]; then
  curl -sf "$admin/" | grep -q '"name":"yaml2cv"' || { echo "admin document broken" >&2; exit 1; }
  for path in /config /status /healthz; do
    curl -sf "$admin$path" >/dev/null || { echo "admin $path broken" >&2; exit 1; }
  done
  echo "ok   admin"
fi
