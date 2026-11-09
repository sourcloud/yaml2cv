# Security policy

## Supported versions

Only the latest release gets fixes, including security fixes; there are no
backports (ADR 0033). Run the newest image, e.g. by following the
major-version tag `ghcr.io/sourcloud/yaml2cv:1`.

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub:
[Report a vulnerability](https://github.com/sourcloud/yaml2cv/security/advisories/new)
(the **Security** tab of the repository). Do not open a public issue.

Useful details are the affected version or image digest, the request or
CV that triggers the problem, and what you expected to happen. Do not send
real personal data; a made-up CV is enough.

This is a project maintained in spare time. You will get an answer as soon
as possible, and fixes are released and credited in a GitHub security
advisory once they are available.

## Scope

yaml2cv processes untrusted YAML, images and HTTP requests. In scope are,
for example, ways to make the service read or write files it should not,
run code, leak another request's data, or exhaust memory or CPU despite the
limits in ADR 0010 and ADR 0009.

Out of scope are deployments that ignore the deployment notes in the
README, such as an admin listener exposed to the internet or no rate limit
in front of the service.
