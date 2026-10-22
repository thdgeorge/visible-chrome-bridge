# Validation record

Initial implementation checked on 2026-10-22. These results describe the tested
revision and do not certify future dependency releases or a production rollout.

## Executed locally

- **Original** Windows PowerShell 5.1 and PowerShell 7.6.6 baseline: `tests/Run-Tests.ps1`, **16 scenarios** passed in each shell (Node.js 24.18.0). **After first real-PC QA fixes**, the revised implementation passed **17 scenarios in each shell**; these counts describe different revisions. See final QA notes below.
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

## v0.1.0 updater regression checks (2026-10-22)

- PR #6 Windows CI ran the **isolated, offline test suite** successfully: **18/18 scenarios on Windows PowerShell 5.1 and 18/18 on PowerShell 7.6.6**, including the additional single-component dependency-update regression test. Original PR run: [Windows validation](https://github.com/thdgeorge/visible-chrome-bridge/actions/runs/39791289236).
- The synthetic metadata/payload test exercises: `-McpVersion` preserving the installed tunnel-client version; `-TunnelVersion` preserving installed MCP; unchanged-version no-op; explicit two-version selection; and no-version latest selection. Tests use a private fixture data root, stubbed upstream metadata, and **no real tunnel credentials or running Chrome**.
- This validates the **version-selection logic**, not a live update between two real Chrome MCP releases. Real update, rollback, and ChatGPT tool refresh remain manual acceptance targets.

## Required manual acceptance

Follow [CONTRIBUTING.md](../CONTRIBUTING.md#manual-acceptance-checklist) before a
stable release. Still unverified: Windows 10, clean Windows 11 without elevated
privileges, clean-machine interactive credential installation, actual logon startup and
scheduled-task behavior, consent decline/reconnect and negative authentication paths,
and upgrades/rollback across different upstream versions.

The first non-prerelease v0.1.0 is an initial public version, **not a production-readiness certification**; broader manual acceptance remains incomplete.

## First real-PC manual QA: 2026-10-22

Initial scoped QA completed with application fixes from revision `e5da5ef`
(the installed application matches that source). Scope: a separate QA tunnel,
the default per-user private data directory, existing running Chrome, and
read-only browser calls. Startup registration and automatic updates are excluded.
No tunnel identifiers, credentials, account details, or private browser contents are
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
| Worker and local runtime | Initial start FAILED: official client rejected `warn` logging without an explicit format. Fixed with `--log.format struct-text`; restart PASS: running, healthy, and ready. Encrypted credentials unchanged by application repair. The status command intentionally leaves `BrowserVerified=false`; manual browser evidence is recorded separately. |
| New tunnel authentication | PASS: HTTPS GET of this tunnel's metadata returned 200 with the new locally decrypted runtime key; response contents were suppressed. The subsequent user-reported ChatGPT browser call exercised real end-to-end use through the QA connection. |
| New ChatGPT connection and tool discovery | PASS, user-reported: the separate QA connection connected in ChatGPT and completed the requested browser tool call. This validation chat exposes only legacy tools, so the QA call was performed by the user in a separate ChatGPT conversation. |
| Chrome consent | PASS, user-reported: a new Chrome access prompt appeared for the QA test and the user accepted it. No security prompt was automated. |
| Read-only new browser operation | PASS, user-reported: QA found the existing manually opened `https://example.com/` tab and returned document title `Example Domain`. The user reported no browser/tab changes. No navigation, profile creation, or Chrome restart was performed by the validation agent. |
| Both integrations operational together | PASS with mixed evidence: user reported the successful QA browser call; immediately afterward, the legacy read-only tool succeeded while the QA runtime was still running. All seven baseline file hashes and the legacy scheduled-task definition matched. Original tunnel and Chrome PIDs remained alive. |
| Owned stop and unrelated-process preservation | PASS before and after new browser use: final graceful stop recorded `Stopped`, with zero of the seven captured owned processes remaining. Original Chrome and legacy tunnel stayed alive; legacy read-only tool still succeeded after the final stop. An earlier explicit restart returned running/healthy/ready. Final QA state is stopped. |
| Real process credential exposure | PASS: neither locally decrypted credential appeared in the seven owned processes' command lines; values and command lines were suppressed. Chrome was outside the owned process tree. MCP environment stripping is covered by the offline shim test, not a live memory inspection. |
| Startup/update registration | PASS: no registration for the new default root before or after installation/start; manual update policy only. |

No blocker remains for the initial installation/authentication/consent/read-only
browser/coexistence/stop scope. Evidence explicitly marked user-reported was not
independently replayed through the QA plugin in this validation chat.

Remaining broader manual acceptance gates from `CONTRIBUTING.md` are:

- Windows 10 and clean non-admin Windows 11 runs in both shells, including a
  spaced installation path and real missing/unsupported prerequisite recovery.
- Real installer reentry/idempotency and preference preservation, credential
  replacement, and rejection under another Windows account (fixtures already
  cover installer transactions and actual current-user DPAPI was tested).
- Denied/expired credentials and missing workspace association, consent decline,
  user-driven Chrome close/reopen, and reconnection after offline/worker failure.
- Sign-out/logon, installed-copy startup registration, scheduled notify policy,
  and explicitly opted-in unattended update behavior. These remain deliberately
  excluded from this PC run; no registration or automatic updates were enabled.
- Real version-to-version updates, corrupt/interrupted staging and rollback,
  explicit restart and ChatGPT tool rescan after update. Current transaction
  coverage uses fixtures rather than different live upstream versions.
- Real uninstall with retained data, reinstall, and deliberate removal of test
  data. No uninstall or private-data removal was performed in this run.

Live MCP child memory/environment was not inspected; key stripping was verified
with the actual launcher and synthetic child in offline tests. Broader pending
checks are not passes or evidence of a failure. No production-ready release or complete multi-machine acceptance is claimed.

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
