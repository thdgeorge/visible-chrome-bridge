# Troubleshooting

Start with safe status output:

```powershell
.\Get-BridgeStatus.ps1
```

Use the same `-DataRoot` and Windows account as installation. Do not publish credentials, process environments, private configuration, browser screenshots, or unreviewed logs. The wrapper persists bounded lifecycle outcomes instead of raw child output.

**Status meaning:** `Running=True`, `Healthy=True`, `RuntimeReady=True` mean the **local bridge** is available, not that Chrome consent or ChatGPT succeeded. **`BrowserVerified=False` is always expected**, even after a successful browser call. See [status interpretation](INSTALLATION.md#verify-installation-and-first-browser-call).

## Diagnose one stage at a time

| Symptom | Check and recovery |
| --- | --- |
| Node or npm missing | Run `node --version` and `npm --version` in a fresh shell. Install supported Node LTS yourself, then retry. |
| Chrome missing/unsupported | Verify Chrome version and standard installation location. Upgrade through your approved channel. |
| Script execution blocked | Review download origin and PowerShell/application control policy. Do not permanently weaken policy. |
| `Microsoft.PowerShell.Security` cannot load / duplicate `ObjectSecurity` type data | A Windows PowerShell child may have inherited PowerShell 7's module search path. Open a fresh Windows PowerShell from the Start menu, or run the installer directly in PowerShell 7. If launching a child programmatically, remove `PSModulePath` from that child's environment only. Do not edit global module paths or disable security policy. |
| Installation missing | Check account and `-DataRoot`. Default storage is per-user. |
| Credential decryption fails | Run as the original user. Do not copy DPAPI files between accounts; install your own credentials. |
| Worker absent or start fails | Inspect safe status, dependency paths, and application control policy; resolve the stated error and retry. |
| Official client exits immediately / `UpstreamExited` | Check runtime configuration and service permissions. Tunnel-client 0.0.17 requires an explicit log format with `warn` logging; this wrapper supplies `--log.format struct-text` and discards child output. Repair an older installed application from the corrected checkout while stopped. |
| Worker runs but health unavailable | Allow brief initialization and recheck. Verify dependencies execute and network access works. |
| Local health succeeds but tunnel fails | Verify key validity, permissions, association, and outbound HTTPS. Health alone does not prove authorization. |
| Tunnel absent in ChatGPT | Confirm **ChatGPT workspace** association (not just the Platform organization), `Tunnels Read + Use`, and permission to create a private MCP plugin; see [setup](CHATGPT-SETUP.md#create-your-personal-tunnel). |
| Tools found but Chrome inaccessible | Open Chrome 144+ yourself, enable `chrome://inspect/#remote-debugging`, check Chrome's **default profile**, and accept the expected consent dialog. Retry the [read-only browser test](CHATGPT-SETUP.md#prove-the-complete-path). |
| Unexpected browser pages | Recheck Chrome's selected default profile before further actions. There is no arbitrary profile selector. |
| Update/rollback blocked | Finish automation and explicitly stop the bridge before retrying. |
| Download/integrity check fails | Check official release metadata and network/proxy interference. Keep the installed payload; never disable verification. |
| Tools changed after update | Review/rescan in ChatGPT and retest. If incompatible, stop and roll back. |

The [official tunnel guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) describes service network diagnostics. This wrapper isolates its configuration; do not repair it by overwriting an unrelated client profile.

## Restart the owned bridge

```powershell
.\Stop-Bridge.ps1
.\Start-Bridge.ps1
```

These affect only this bridge instance. Leave unrelated integrations and Chrome processes alone. If Chrome was closed, open it yourself before retrying a tool. Lost connectivity or a signed-out Windows session can make tools unavailable until the bridge runs again.

## Logon startup or scheduled checks

Startup uses a per-user registry Run entry; checks use a per-user scheduled task. Each name is derived from the root. Check the registration belongs to the correct root and its installed `app` copy exists. Logon startup does not start Chrome. Scheduled checking does not guarantee a desktop notification. Rerun the reviewed installer with explicit options to repair your own registration.

## Report a reproducible issue

Include wrapper revision, Windows/shell/Node/Chrome versions, installed dependency versions, safe status, and the failing step. Replace account names, tunnel IDs, identifying paths, and page contents with neutral placeholders. Describe expectations and safe recovery attempts. Report exposure privately using [security guidance](SECURITY.md#reporting-a-security-problem).
