# Changelog

## Unreleased

- Clarify first-time onboarding in the README, including Git/ZIP install, Platform workspace and API-key permissions, and a safe real browser test.
- Document expected local status fields and the tested beta upstream dependency versions versus later releases.
- Align security and architecture status statements with the first real-PC QA evidence.

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
