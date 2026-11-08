# 0020. Phone home: admin endpoint and UDP heartbeat

- Status: Accepted
- Date: 2026-11-07

## Context

Operators want to discover running yaml2cv instances and see what they are,
where they listen, how they were built and deployed and how loaded the host
is, without logging into the machine. The only operational endpoint so far
is `/healthz` (ADR 0010), which answers "alive" and nothing else.

The information is sensitive: interface addresses, configuration and
deployment details help an attacker as much as an operator.

## Options

Delivery:

1. **Pull endpoint and UDP heartbeat** — the endpoint serves the full
   document; a small UDP packet announces the instance to a collector.
2. **Full document over UDP** — may outgrow one datagram and get lost.
3. **Endpoint only** — no proactive announcement.
4. **HTTP POST push** — reliable but needs retries and timeouts.

Exposure: separate admin listener; bearer token on the public port; public.

Format: the Health Check Response draft (`application/health+json`) or a
custom schema.

## Decision

**Admin listener.** A second HTTP listener, `ADMIN_BIND_ADDRESS` (default
`127.0.0.1`) and `ADMIN_PORT` (default `9000`), serves only:

| Path | Content |
| --- | --- |
| `GET /` | the full document |
| `GET /config` | the `config` member |
| `GET /status` | the `status` member |
| `GET /healthz` | `{"status": "ok"}` |

The public listener is unchanged. The container image keeps the loopback
default: the endpoint is then usable only from inside the container's
network namespace (`exec`, a sidecar in the same pod). Reaching it from
elsewhere is an explicit choice: set `ADMIN_BIND_ADDRESS=0.0.0.0` (in a
container that adds just its own address) and publish the port or allow it
in a network policy.

**Document.** A custom JSON schema, owner-supplied and extended:

```json
{
  "name": "yaml2cv",
  "version": "0.2.0",
  "requires": [],
  "address": {
    "host": "10.0.0.135",
    "port": "8000",
    "admin_port": "9000",
    "ipv6": null,
    "interfaces": [
      { "name": "eth0", "ipv4": ["10.0.0.135"], "ipv6": [] }
    ]
  },
  "heartbeat": { "interval": 10000, "mia_interval": 30000 },
  "config": {
    "git_revision": "585b6be",
    "build_date": "2026-11-07T21:00:00Z",
    "deployed_from": null,
    "deployed_by": null,
    "deployed_on": null,
    "settings": { "render_concurrency": 4 }
  },
  "status": { "memory": 41, "cpu_load": [0.4, 0.3, 0.2], "io_load": 0.1, "disk": 72 },
  "rel": { "self": "/", "config": "/config", "status": "/status", "health": "/healthz" }
}
```

- `requires` lists the components this instance depends on, from
  `REQUIRES` (comma-separated, default empty).
- `address.interfaces` lists only interfaces the public listener is
  reachable on: every non-loopback, non-link-local address of the bound
  family for a wildcard bind (`0.0.0.0` IPv4 only, `::` IPv4 and IPv6),
  otherwise the interface holding the bind address. `host` and `ipv6` are
  the first such IPv4 and IPv6 address, or `null`. Ports are strings, as in
  the owner's example.
- `config.git_revision` and `config.build_date` are baked into the image as
  build arguments (`GIT_REVISION`, `BUILD_DATE`); `deployed_from`,
  `deployed_by` and `deployed_on` come from the environment variables of the
  same name in upper case. Unset values are `null`. `settings` holds the
  effective configuration (no secrets exist).
- `status`, read from Linux `/proc`, `/sys/fs/cgroup` and `df`; any value
  that cannot be read is `null` (e.g. on macOS):
  - `memory`: percent used, of the cgroup limit if one is set, otherwise of
    the host;
  - `cpu_load`: 1, 5 and 15 minute load averages;
  - `io_load`: percent of time tasks stalled on I/O over the last 10 s
    (pressure stall information, `some avg10`);
  - `disk`: percent used of the file system holding `WORK_DIR`.
- `rel` lists paths on the admin listener, all of which exist.

**Heartbeat.** When `PHONE_HOME_TARGET` (`host:port`) is set, the service
sends a UDP datagram every `HEARTBEAT_INTERVAL_MS` (default 10 000) holding
`name`, `version`, `address` without `interfaces`, `heartbeat`, `status` and
`rel` as absolute URLs of the admin listener. A collector should consider
the instance missing after `HEARTBEAT_MIA_MS` (default three intervals)
without a packet. Send errors are logged and never stop the service. When
heartbeats are enabled while the admin listener is bound to loopback, a
warning is logged at start-up: the links in the heartbeat cannot be
followed.

## Consequences

- No new dependencies: sockets, interfaces and timers come from OTP.
- Secure by default: the admin endpoint is unreachable from outside until
  an operator opts in, and it must never be published to the internet.
- Deployments with a collector have to set `ADMIN_BIND_ADDRESS` as well as
  `PHONE_HOME_TARGET`.
- Status values are host- or cgroup-level, not per process.
- `rel` URLs in the heartbeat use the admin bind address, or `host` for a
  wildcard bind; behind NAT a collector may still not reach them.
