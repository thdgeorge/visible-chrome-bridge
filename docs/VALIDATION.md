# Validation record

Preview implementation checked on 2026-10-22. These results describe the tested
revision and do not certify future dependency releases or a production rollout.

## Executed locally

- Windows PowerShell 5.1 and PowerShell 7.6.6: `tests/Run-Tests.ps1`, 16 scenarios
  passed in each shell. Node.js 24.18.0 was used.
- Native argument round trips include spaces, apostrophes, quotes, empty strings,
  trailing backslashes, and shell metacharacters without invoking a shell.
- Actual Windows DPAPI encryption/decryption and protected directory ACLs.
- Actual Windows Job Object containment: an owned child/descendant tree exits;
  an unrelated sentinel remains running.
- Offline fake tunnel worker: hidden startup, duplicate-start protection,
  loopback health, explicit stop, and update rejection while running.
- Fixture-based installer idempotency, preference/credential preservation,
  incompatible repair rejection, staging failure, update, and rollback.
- Archive corruption/traversal rejection, trusted-origin validation, npm lock
  origin/integrity validation, and missing-dependency diagnostics.
- Official tunnel-client 0.0.17 and Chrome DevTools MCP 1.11.0 downloaded to
  separate temporary directories from both PowerShell shells. Archive and
  license-sidecar SHA-256 verified,
  npm integrity lock validated, lifecycle scripts disabled, CLI version/help
  compatibility checked. No real credentials were supplied.
- A real official download deliberately supplied the wrong SHA-256 was rejected
  and the unverified file removed.
- `tests/Run-UpstreamSmoke.ps1` passed in both shells using the verified official
  tunnel binary and **fake local** control-plane/MCP endpoints. This exercises
  the real upstream command parser, stdio initialization, response forwarding,
  stripped MCP environment, and health checks. It does not use OpenAI or Chrome.
- Four pre-existing profile/runner file hashes matched their read-only baseline;
  the original tunnel process was still running with its original PID. Validation
  did not write to pre-existing configuration, startup registration, credentials,
  or logs. The running legacy process may continue writing its own logs.

Unit/fixture checks do not establish real provider or browser behavior. No
screenshots or browser data were captured.

## Required manual acceptance

Follow [CONTRIBUTING.md](../CONTRIBUTING.md#manual-acceptance-checklist) before a
stable release. Still unverified: Windows 10, clean Windows 11 without elevated
privileges, fresh interactive credential installation, actual logon startup and
scheduled-task behavior, authentication against a new personal OpenAI tunnel,
Chrome consent and decline/reconnect paths, ChatGPT discovery and real tool use,
and upgrades/rollback across different upstream versions.

No stable release has been published, and no production readiness is claimed.

## Repeat the checks

```powershell
.\tests\Run-Tests.ps1
```

For the explicit online staging check (downloads official packages, retains the
temporary payload for review), then a loopback-only transport test:

```powershell
$payload = .\tests\Stage-Upstream.ps1
.\tests\Run-UpstreamSmoke.ps1 -PayloadRoot $payload.PayloadRoot
```

The online test pins its defaults to the audited versions. Pass exact
`-TunnelVersion` and `-McpVersion` values to test a future candidate. Do not pass an
existing installation as a test destination. Review and remove only the exact
temporary payload when finished; never use blanket temporary-directory cleanup.
