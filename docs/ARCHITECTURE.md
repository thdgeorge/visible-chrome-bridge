# Architecture

Design audit: 2026-10-22. This is an independent Windows lifecycle wrapper for
official upstream software, not an MCP server or a browser automation engine.
Real ChatGPT/Chrome acceptance remains a manual gate before a stable release.

## Validated upstream design

```text
Personal ChatGPT custom MCP connection
    -> OpenAI-hosted Secure MCP Tunnel endpoint
    <- outbound HTTPS polling by official tunnel-client
    -> stdio: installed node.exe + pinned chrome-devtools-mcp entry point
    -> --autoConnect -> user's running Chrome -> explicit Chrome consent
```

Chrome 144+ supports automatic connection to an already running browser. The
user enables it at `chrome://inspect/#remote-debugging` and accepts Chrome's
connection dialog. Chrome determines the default profile when multiple profiles
are running; all windows in that profile become accessible. The wrapper cannot
promise arbitrary profile selection. It never starts, terminates, or restarts
Chrome and never configures a Chrome debugging port or a new user data directory.

The tunnel client supports stdio commands directly. An MCP HTTP listener, public
ingress, Cloudflare runtime, and browser port forwarding are unnecessary here.
Only its health/admin listener binds to `127.0.0.1` on an OS-selected port.

## Read-only environment audit

The existing integration was inspected using executable versions, file metadata,
allowlisted configuration facts, process relationships, and scheduled task
metadata. No credentials, tunnel identifiers, browser data, or logs were copied.
The existing plugin was identified by the supplied name; its private ChatGPT
configuration was not exported or independently inspected in the UI.

Observed: a pre-existing tunnel client 0.0.11, Chrome 155, Node 24, a running
per-user logon task, a hidden runner with a restart loop, and a stdio MCP profile
using `npx`, `@latest`, and `--autoConnect`. A previous managed profile is present.
The legacy runner log is unbounded. These are observations, not instructions to
migrate or modify that setup. It must stay operational throughout development.

Obsolete assumptions: a separate Chrome profile is not necessary for
`--autoConnect`; tunnel transport does not require Cloudflare; startup must not
resolve `@latest`; old developer-mode-only ChatGPT instructions are not universal.
Current official documentation describes Plugins > Add custom MCP server >
Tunnel, subject to separate Platform and ChatGPT workspace permissions.

## Ownership and storage

Each Windows user installs a separate bridge under
`%LOCALAPPDATA%\VisibleChromeBridge`. There is no shared service or shared browser.
Every developer supplies their own tunnel and runtime API key, and creates their
own ChatGPT connection. The installer never imports existing tunnel-client
profiles or writes into their configuration directories.

Credentials are prompted as SecureStrings, encrypted with current-user Windows
DPAPI, and saved only outside the checkout. The data root uses a protected ACL
for the current user and SYSTEM. DPAPI does not protect against malware already
running as that user or an administrator. Plaintext exists briefly in worker
memory and the child process environment; it never appears in arguments or logs.
The MCP child must not inherit the runtime API key.

Versioned payloads are staged before activation. An atomic state pointer selects
the current payload; the previous pointer supports rollback. Start never downloads
dependencies. The official npm package and dependency lock are installed per
payload, with integrity verification and lifecycle scripts disabled. Tunnel
archives must match the upstream GitHub release asset SHA-256 digest. Missing
verification metadata is a hard failure, not permission to skip verification.
This trusts official GitHub/npm HTTPS metadata; it is not independent code signing.

## Lifecycle and update safety

Root PowerShell entry points work on Windows PowerShell 5.1 and PowerShell 7.
Shared implementation lives under `src/`. Installation copies the reviewed
wrapper into the per-user root so startup does not depend on the checkout.
A named mutex serializes state changes. A dedicated hidden worker owns the
tunnel process tree in a Windows Job Object; stopping the worker closes that job.
Chrome is attached externally and is never a member of the owned job.
Stop uses an instance-specific signal, not process-name matching or blind PID
killing. Child output is discarded by default; only bounded, non-sensitive
lifecycle outcomes are persisted. Readiness distinguishes process, health, and
tunnel readiness from actual Chrome consent and a successful ChatGPT tool call.

Manual updates stage and verify stable upstream versions while the bridge is
stopped. A running bridge blocks update and rollback. The project has no reliable
cross-product active-session detector, so automatic updates must never stop a
running bridge. Optional scheduled checks default to notify-only; explicit
unattended policy may update only while stopped. Failures retain the current
payload. There is no documented public API for refreshing a ChatGPT custom MCP
connection's tool catalog; the operator reviews/rescans tools in ChatGPT.

## Sources and verification boundary

- [Chrome DevTools MCP advanced usage](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/advanced-usage.md)
- [Chrome DevTools MCP requirements and privacy](https://github.com/ChromeDevTools/chrome-devtools-mcp)
- [Official tunnel client](https://github.com/openai/tunnel-client)
- [Secure MCP Tunnel guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels)
- [ChatGPT custom MCP setup and permissions](https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt)

Automated tests use isolated temporary roots and synthetic credentials. They
must not invoke the existing installation or attach to the user's browser.
Authenticating a new tunnel, Chrome consent, real tool discovery, Windows 10,
and cross-machine installation remain explicit manual QA gates.
