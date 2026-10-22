# Updates and rollback

## Safe defaults

Startup uses pinned, installed dependencies. It does not resolve `@latest`, download packages, or update Chrome. A newer upstream release is a candidate for review, not proof of compatibility.

| Policy | Behavior |
| --- | --- |
| `Manual` (default) | You run checks and apply updates explicitly |
| `Notify` | Per-user scheduled checks write a local update notice; no automatic application |
| `Unattended` | Explicit opt-in: scheduled checks may update only while stopped |

There is no reliable detector for every active ChatGPT/browser session. The running worker therefore blocks update and rollback under every policy. The updater never stops a running bridge and never restarts it after changing a payload. Unattended mode is not permission to interrupt work.

## Tested versions versus upstream latest

The initial real-PC QA on 2026-10-22 used **tunnel-client 0.0.17** and **chrome-devtools-mcp 1.11.0**. To reproduce that exact tested dependency combination on a **fresh** machine, use:

```powershell
.\Install-Windows.ps1 -TunnelVersion 0.0.17 -McpVersion 1.11.0
```

**Recommended default for new users:** run `.\Install-Windows.ps1` without version flags to install the **latest stable upstream releases**. Those releases may include important fixes but **are not automatically covered by earlier QA**. Check upstream release notes, runtime requirements and advisories; a previously tested version is not necessarily safer. Startup stays pinned to installed versions. Re-running the installer does not change installed dependency versions; use the updater while stopped. The **GitHub wrapper release version** and **upstream dependency versions** are separate.

## Check and update manually

```powershell
.\Get-BridgeStatus.ps1
.\Check-Updates.ps1
```

Read upstream release notes before applying changes. When you finish automation:

```powershell
.\Stop-Bridge.ps1
.\Update-Bridge.ps1
.\Start-Bridge.ps1
.\Get-BridgeStatus.ps1
```

With **no version flags**, the updater selects the latest stable releases of both upstream tools. With **only one** of `-TunnelVersion` or `-McpVersion`, it updates the specified component and **preserves the installed version of the other**. With both flags, it uses both requested versions. Pass published numeric versions without `@latest`, ranges, or prerelease tags. Use `-DataRoot` consistently for a custom installation.

The updater stages a versioned payload, checks the tunnel archive's official release SHA-256 digest, and uses npm integrity checks with lifecycle scripts disabled. Missing verification metadata or corrupt downloads fail the update. The current payload stays selected until staging succeeds. This verifies against official HTTPS metadata, not an independent signing key.

An activation pointer preserves the previous payload for rollback. Exact dependency versions and npm's lock are retained with each payload. Include the versions when reporting issues; do not attach the private installation.

## Updating just one component

To update **only Chrome DevTools MCP** to a reviewed published version, preserving the installed tunnel-client:

```powershell
.\Stop-Bridge.ps1
.\Update-Bridge.ps1 -McpVersion X.Y.Z
.\Start-Bridge.ps1
.\Get-BridgeStatus.ps1
```

Replace `X.Y.Z` with the numeric MCP version returned by `.\Check-Updates.ps1` (for example, `1.12.0` **only if that release exists and is compatible**). The first update downloads and verifies a new paired payload; the tunnel-client version is kept pinned even though its files are restaged. For only the tunnel-client, use `-TunnelVersion X.Y.Z` in the same stop/update/start workflow. Running the updater without any version flags updates **both** to their latest stable versions.

**ChatGPT plugin after an update:** `Visible Chrome` keeps the same private tunnel ID and API key, so do **not** recreate it for a normal version change. If tools or their schemas change, the ChatGPT workspace/app manager must review and **Refresh** the custom MCP tool catalog from the applicable workspace app settings; this is not automatically done by the bridge. New or changed actions may need approval, and the exact controls depend on workspace permissions. See [OpenAI's custom MCP documentation](https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt). In a fresh ChatGPT conversation, repeat the [harmless Example Domain test](CHATGPT-SETUP.md#prove-the-complete-path). If the tool catalog cannot be refreshed from your private-plugin UI, seek the workspace manager's controls instead of immediately deleting the plugin.

## Roll back

```powershell
.\Stop-Bridge.ps1
.\Update-Bridge.ps1 -Rollback
.\Start-Bridge.ps1
```

Rollback needs an earlier installed payload. It does not undo Chrome updates, OpenAI service changes, workspace permissions, or ChatGPT tool approvals. If no previous payload exists, select reviewed exact upstream versions through a normal update. If staging fails, inspect status and retry after resolving the network/dependency problem; never bypass integrity checks.

## Configure scheduled checks

```powershell
.\Install-Windows.ps1 -UpdatePolicy Notify
```

Choose `Unattended` only after completing acceptance and deciding automatic activation while stopped suits your environment. Choose `Manual` to remove scheduled checking. `Check-Updates.ps1 -Scheduled` is the task entry point; interactive checking remains available under every policy. Notices are local state, not email or guaranteed desktop alerts. Status reports the last safe outcome.

## Wrapper updates and ChatGPT tools

`Update-Bridge.ps1` updates upstream dependencies, not the source checkout. Review a new wrapper revision, stop the bridge, and rerun its installer to refresh the private `app` copy while preserving configuration. Review release notes for state migrations.

After either kind of update, manually review/rescan tools in ChatGPT and repeat the harmless test from [setup](CHATGPT-SETUP.md#prove-the-complete-path). A local update cannot certify ChatGPT's stored tool catalog.
