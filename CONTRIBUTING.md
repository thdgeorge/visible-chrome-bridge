# Contributing

Keep changes small, reviewable, and grounded in official upstream tooling. This project owns Windows lifecycle management; browser automation belongs to Chrome DevTools MCP and transport belongs to OpenAI's client.

## Development checks

Use a feature branch and PowerShell on Windows. Do not test against a personal working tunnel installation. The automated runner uses temporary roots and synthetic credentials, does not request real keys, and needs no Pester installation:

```powershell
.\tests\Run-Tests.ps1
git diff --check
```

Run under Windows PowerShell 5.1 and PowerShell 7 when available. GitHub Actions provides shell coverage; a hosted runner does not prove Windows 10 installation or Chrome consent. Add meaningful failure-path, quoting, version-selection, and ownership tests. Never contact a real tunnel or install unrelated tooling in unit tests.

For optional official-package staging and a real tunnel binary against local
fake services, see [the validation record](docs/VALIDATION.md#repeat-the-checks).
These checks do not authenticate a real tunnel or attach to Chrome.

## Manual acceptance checklist

Before a stable release, use separate test credentials. Record OS build, shell/Node/Chrome versions, wrapper revision, exact dependencies, date, and pass/fail evidence. Test Windows 10 x64 and clean Windows 11 x64, covering both supported shells.

- [ ] Install without admin rights into default and spaced paths.
- [ ] Check actionable failures for missing Node/npm, unsupported Node, and missing/unsupported Chrome without altering unrelated configuration.
- [ ] Reinstall idempotently; verify credential and explicit preference preservation.
- [ ] Verify credential replacement and failure under a different Windows account.
- [ ] Verify private ACLs, DPAPI, no secrets in process arguments or raw logs, and no runtime key in the MCP child's environment.
- [ ] Start with Chrome running; grant consent, discover tools, and complete a harmless real ChatGPT browser call in the intended profile.
- [ ] Decline consent, close Chrome yourself, and retry: failures must be actionable, and the wrapper must not start/restart Chrome.
- [ ] Test denied/expired credentials and missing workspace association; local health must not be presented as complete connection success.
- [ ] Stop/start repeatedly and after worker failure; owned children exit while unrelated tunnels and Chrome remain running.
- [ ] Exercise offline/reconnect, Windows sign-out/logon, startup from installed copy, and notify policy.
- [ ] Attempt updates while running: no worker interruption or payload change.
- [ ] While stopped, stage a verified update, simulate corrupt/missing metadata and interrupted staging, exercise rollback, and restart explicitly.
- [ ] Verify unattended opt-in updates only while stopped and skips a running bridge.
- [ ] Review/rescan tools in ChatGPT after updates and repeat the browser test.
- [ ] Uninstall retaining data, reinstall, then deliberately remove test data; only owned registrations and data may change.
- [ ] Confirm any pre-existing integration remains unchanged throughout testing.

Never disable verification to obtain a passing test. Exclude secrets, identifying paths, customer pages, account screenshots, and private logs from evidence. Separate automated results, manual observations, and untested assumptions.

## Pull requests and releases

Describe the concrete problem, resulting behavior, tests actually run, and limitations. Keep PowerShell 5.1 compatibility, quote paths, preserve ownership boundaries, and avoid process-name termination. Review the full diff and scan for secrets/private information before committing. Retain [upstream notices](THIRD-PARTY-NOTICES.md) when changing dependency handling.

Prepare PRs from feature branches without rewriting `main`. Merging or publishing a stable release requires maintainer approval and completed acceptance evidence. Report vulnerabilities through [security guidance](docs/SECURITY.md#reporting-a-security-problem).
