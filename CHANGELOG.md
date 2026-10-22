# Changelog

## Unreleased

_No unreleased changes._

## [v0.1.0](https://github.com/thdgeorge/visible-chrome-bridge/releases/tag/v0.1.0) — 2026-10-22

First regular (non-prerelease) public release following `v0.1.0-beta.1`:

- **Fix single-component updates:** `Update-Bridge.ps1 -McpVersion X.Y.Z` preserves the installed tunnel-client version; `-TunnelVersion` preserves the installed MCP version. No flags continue selecting the latest stable upstream versions of **both**. Existing stop/rollback safeguards remain.
- Make `.\Install-Windows.ps1` without version flags the recommended **fresh-install** command (it already selected latest stable dependencies); retain exact `0.0.17` / `1.11.0` only as the first manually verified reference combination.
- Document independent dependency updates, tool-catalog review/refresh in ChatGPT, and how to distinguish wrapper, tunnel-client, and Chrome DevTools MCP versions.
- Add offline regression coverage for MCP-only, tunnel-only, explicit-both, latest-both, and unchanged-version operations.

**Scope:** `v0.1.0` is an initial public version, not a claim of completed multi-machine, security or production-readiness acceptance. See [validation](docs/VALIDATION.md); [issue #2](https://github.com/thdgeorge/visible-chrome-bridge/issues/2) tracks a previously intermittent Windows CI readiness fixture failure.

## [v0.1.0-beta.1](https://github.com/thdgeorge/visible-chrome-bridge/releases/tag/v0.1.0-beta.1) — 2026-10-22

Initial public preview:

- Add per-user Windows lifecycle scripts for the official OpenAI tunnel-client and Chrome DevTools MCP.
- Attach to existing Chrome with `--autoConnect` and explicit Chrome permission.
- Secure credentials using current-user DPAPI and private directory ACLs.
- Manage owned background processes with a Windows Job Object without terminating unrelated Chrome/tunnel processes.
- Install verified, pinned upstream dependency payloads; support stopped-bridge manual updates and rollback.
- Provide optional scheduled update checks (default policy: `Manual`), Windows CI, smoke tests, and public documentation.
- Complete **scoped first-PC QA** of local installation, runtime authentication, Chrome consent, a user-confirmed read-only ChatGPT tool call, coexistence and isolated stop. After real-PC fixes, **17 tests passed in both Windows PowerShell 5.1 and PowerShell 7**; see [validation](docs/VALIDATION.md) for boundaries.

**Beta, not a production-stable release.** Clean Windows machine acceptance, negative auth/consent cases, actual logon/scheduler, live updates/rollback and uninstall remain pending. A transient Windows runner readiness test failure is tracked in [issue #2](https://github.com/thdgeorge/visible-chrome-bridge/issues/2).
