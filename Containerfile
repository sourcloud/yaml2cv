# check=error=true
# yaml2cv production image (ADR 0013).
#
#   podman build -t yaml2cv .
#   podman run --rm -p 8000:8000 yaml2cv
#
# Versions match the Nix dev shell. When upgrading, update the version and
# the SHA-256 for every architecture (GitHub shows asset digests).

# Pin the multi-arch index digest and check that it lists every platform we
# publish (linux/amd64, linux/arm64); otherwise BuildKit silently falls back
# to another platform's image (ADR 0014).
ARG ERLANG_IMAGE=docker.io/library/erlang:29.1.2-alpine@sha256:0ac9b63db11be156be4e2834546e44aa0d7446aaffb05fedd4aea8c5a33ad998

# --- Build ---------------------------------------------------------------------
FROM ${ERLANG_IMAGE} AS build

ARG GLEAM_VERSION=1.19.2
RUN set -eu; \
    case "$(uname -m)" in \
      x86_64) arch=x86_64; sum=2ba2afb66ca9f6dcc01a4a6e9169b6942963bad6483bec9571ddc078cfe6f41f ;; \
      aarch64) arch=aarch64; sum=d1d1a9d53f6b317c0563a4806873c8ccace54291ead023373728af379402d4f1 ;; \
      *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    wget -qO /tmp/gleam.tar.gz \
      "https://github.com/gleam-lang/gleam/releases/download/v${GLEAM_VERSION}/gleam-v${GLEAM_VERSION}-${arch}-unknown-linux-musl.tar.gz"; \
    echo "${sum}  /tmp/gleam.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/gleam.tar.gz -C /usr/local/bin gleam; \
    rm /tmp/gleam.tar.gz

WORKDIR /build

# Dependencies first, so they stay cached while only sources change.
COPY gleam.toml manifest.toml ./
RUN gleam deps download

COPY LICENSE ./
COPY src src
COPY priv priv
COPY dev dev
RUN gleam export erlang-shipment \
 && gleam run -m notices -- build/erlang-shipment /notices \
 && mkdir -p /notices/licenses/erlang-otp \
 && cp LICENSE /notices/licenses/erlang-otp/LICENSE

# --- Typst ---------------------------------------------------------------------
FROM ${ERLANG_IMAGE} AS typst

ARG TYPST_VERSION=0.15.1
RUN set -eu; \
    apk add --no-cache xz; \
    case "$(uname -m)" in \
      x86_64) arch=x86_64; sum=a6d077d0a95eed5a2eba715b2dae06be954f624ccbf85758a03f389ded33118c ;; \
      aarch64) arch=aarch64; sum=5aa8d74a3d906e60ea12a66ac2f37f8eef1b14cbad7182a745e393a10c23dcee ;; \
      *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    wget -qO /tmp/typst.tar.xz \
      "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-${arch}-unknown-linux-musl.tar.xz"; \
    echo "${sum}  /tmp/typst.tar.xz" | sha256sum -c -; \
    mkdir /typst; \
    tar -xJf /tmp/typst.tar.xz -C /typst --strip-components=1

# --- Runtime -------------------------------------------------------------------
FROM ${ERLANG_IMAGE}

LABEL org.opencontainers.image.title="yaml2cv" \
      org.opencontainers.image.description="Render CVs written in YAML to PDF" \
      org.opencontainers.image.source="https://github.com/sourcloud/yaml2cv" \
      org.opencontainers.image.licenses="Apache-2.0"

RUN addgroup -S yaml2cv && adduser -S -G yaml2cv -H -h /app yaml2cv

COPY --from=typst /typst/typst /usr/local/bin/typst
COPY --from=typst /typst/LICENSE /typst/NOTICE /app/licenses/typst/
COPY --from=build /notices /app/
COPY --from=build /build/build/erlang-shipment /app
COPY LICENSE /app/LICENSE

ENV PORT=8000 \
    ADMIN_BIND_ADDRESS=0.0.0.0 \
    TYPST_PATH=/usr/local/bin/typst \
    WORK_DIR=/tmp/yaml2cv

# Build metadata for the admin endpoint (ADR 0020). Declared last so changing
# them only rebuilds this layer.
ARG GIT_REVISION=""
ARG BUILD_DATE=""
ENV GIT_REVISION=${GIT_REVISION} \
    BUILD_DATE=${BUILD_DATE}

USER yaml2cv
WORKDIR /app
EXPOSE 8000
ENTRYPOINT ["/app/entrypoint.sh", "run"]
