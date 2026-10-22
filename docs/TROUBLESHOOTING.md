# Troubleshooting

Start with safe status output:

```powershell
.\Get-BridgeStatus.ps1
```

Use the same `-DataRoot` and Windows account as installation. Do not publish credentials, process environments, private configuration, browser screenshots, or unreviewed logs. The wrapper persists bounded lifecycle outcomes instead of raw child output.

## Diagnose one stage at a time

| Symptom | Check and recovery |
| --- | --- |
| Node or npm missing | Run `node --version` and `npm --version` in a fresh shell. Install supported Node LTS yourself, then retry. |
| Chrome missing/unsupported | Verify Chrome version and standard installation location. Upgrade through your approved channel. |
| Script execution blocked | Review download origin and PowerShell/application control policy. Do not permanently weaken policy. |
| Installation missing | Check account and `-DataRoot`. Default storage is per-user. |
| Credential decryption fails | Run as the original user. Do not copy DPAPI files between accounts; install your own credentials. |
| Worker absent or start fails | Inspect safe status, dependency paths, and application control policy; resolve the stated error and retry. |
| Worker runs but health unavailable | Allow brief initialization and recheck. Verify dependencies execute and network access works. |
| Local health succeeds but tunnel fails | Verify key validity, permissions, association, and outbound HTTPS. Health alone does not prove authorization. |
| Tunnel absent in ChatGPT | Revisit [setup](CHATGPT-SETUP.md) account and association checks. |
| Tools found but Chrome inaccessible | Check [Chrome preparation](INSTALLATION.md#prepare-chrome), retry a harmless call, and handle consent. |
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
