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
privileges, clean-machine interactive credential installation, actual logon startup and
scheduled-task behavior, end-to-end use of a new personal OpenAI tunnel,
Chrome consent and decline/reconnect paths, ChatGPT discovery and real tool use,
and upgrades/rollback across different upstream versions.

No stable release has been published, and no production readiness is claimed.

## First real-PC manual QA: 2026-10-22

In progress against wrapper revision `d21219a` plus the fixes described below. Scope: a separate QA tunnel,
the default per-user private data directory, existing running Chrome, and
read-only browser calls. Startup registration and automatic updates are excluded.
No tunnel identifiers, credentials, account details, or browser contents are
included in this record.

Environment: Windows build `10.0.26200.0`, PowerShell `7.6.6`, Node.js `24.18.0`,
Chrome `155.0.8059.82`. The validation shell is not elevated.

| Check | Actual result |
| --- | --- |
| Feature branch and checkout | PASS: intended feature branch; clean before QA. |
| Prerequisites | PASS: installed Node/npm and Chrome detected by the real prerequisite checker. |
| Default data directory | PASS precondition: absent before installation; no existing bridge instance to overwrite. |
| Legacy baseline | PASS: configuration/credential/runner binary hashes and startup task definition baselined privately; no values copied into source. |
| Legacy browser integration before QA | PASS: existing plugin completed a read-only `list_pages` call; returned page details were suppressed. |
| Existing Chrome | PASS precondition: browser was already running; no explicit separate profile on its main process. |
| QA tunnel | PASS separation: newly stored tunnel differs from legacy profile identifiers (comparison stayed in memory). User created a separate runtime key; a read-only service metadata request confirmed a workspace association exists. |
| Real installation and credential storage | Initial attempt FAILED before credential entry: Windows PowerShell inherited an incompatible module path and could not load its security module. A controlled probe passed with `PSModulePath` absent from the child environment. Retry PASS: user completed both hidden prompts; pinned dependencies installed without elevation, DPAPI storage verified, root ACL protected with only current user and SYSTEM rules. |
| Worker and local runtime | Initial start FAILED: official client rejected `warn` logging without an explicit format. Fixed with `--log.format struct-text`; restart PASS: running, healthy, and ready, with browser verification still false. Encrypted credentials unchanged by application repair. |
| New tunnel authentication | PASS for authenticated read: HTTPS GET of this tunnel's metadata returned 200 with the new locally decrypted runtime key. Response contents were suppressed. End-to-end use permission and intended workspace access remain unproven until discovery/tool use. |
| New ChatGPT connection and tool discovery | PARTIAL, user-reported: the separate QA connection is connected in ChatGPT. This validation chat exposes only the legacy plugin tools, so a tool call explicitly through the QA connection is still required to confirm discovery/use. |
| Chrome consent | PENDING: user has been guided to invoke the QA connection against a manually opened public test page and report whether a consent prompt appeared. |
| Read-only new browser operation | PENDING: no new integration call performed. |
| Both integrations operational together | PARTIAL: legacy read-only tool still succeeds while the new runtime runs; new integration browser call remains pending. All seven baseline file hashes and the legacy scheduled-task definition match; original tunnel and Chrome PIDs remain alive. |
| Owned stop and unrelated-process preservation | PASS before new browser use: graceful stop recorded `Stopped`; all seven captured owned processes exited. Original Chrome and legacy tunnel stayed alive, and the legacy read-only tool still succeeded. Explicit restart returned running/healthy/ready. Repeat after the new browser call remains pending. |
| Real process credential exposure | PASS: neither locally decrypted credential appeared in the seven owned processes' command lines; values and command lines were suppressed. Chrome was outside the owned process tree. MCP environment stripping is covered by the offline shim test, not a live memory inspection. |
| Startup/update registration | PASS: no registration for the new default root before or after installation/start; manual update policy only. |

Pending checks are not passes or evidence of a failure. This first-PC run does
not cover clean-machine installation, Windows 10, credential rotation, scheduled
startup, unattended updates, or upgrades across upstream versions.

The failed first installation left an empty directory before writing its owner
marker. The installer now removes only that newly created empty directory when
initial storage setup fails; nonempty directories are retained. A regression
scenario checks both failure/retry and data preservation.

The startup failure exposed a smoke-test gap: its synthetic log-file option
implicitly selected a log format that the real worker did not set. The smoke
test now uses the worker's logging arguments without a log file and supplies
the synthetic tunnel identifier through the same environment mechanism. The
fake lifecycle client also rejects the invalid logging combination. After these
changes, all 17 offline scenarios passed under PowerShell 5.1 and 7.6.6, and the
official-client loopback smoke test passed under both shells. No real child
output was written to a log or included in this record.

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
