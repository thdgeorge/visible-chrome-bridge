# Installation

## Requirements

| Component | Requirement |
| --- | --- |
| Operating system | Windows 10/11 x64; both remain manual acceptance targets |
| Shell | Windows PowerShell 5.1 or PowerShell 7 on Windows |
| Download method | Git for Windows **or** GitHub release ZIP (Git optional) |
| Node.js | Node 22.12+ LTS in the 22.x line, or Node 24 LTS, with npm on PATH |
| Browser | Installed Google Chrome 144+; prefer current stable |
| Network | HTTPS to official GitHub releases, npm registry, and OpenAI tunnel service |
| Account | Personal tunnel/runtime key and eligible ChatGPT workspace; see [setup](CHATGPT-SETUP.md) |
| Privileges | Normal interactive Windows user; no administrator session required |

Review upstream [MCP requirements](https://github.com/ChromeDevTools/chrome-devtools-mcp#requirements) when selecting newer dependencies. Corporate application control, proxy, or browser policy may block execution or consent. Coordinate with your administrator instead of bypassing those policies.

Install prerequisites from [Node.js](https://nodejs.org/en/download), [Google Chrome](https://www.google.com/chrome/) and optionally [Git for Windows](https://git-scm.com/downloads/win).

Check dependencies in a fresh **non-admin** PowerShell window:

```powershell
$PSVersionTable.PSVersion
node --version
npm --version
# If using Git rather than ZIP:
git --version
```

If a command is missing, install that prerequisite and open a new PowerShell window. Do not bypass corporate policies or globally weaken execution restrictions.

The installer checks prerequisites and downloads verified payloads. It does not install Node.js or Chrome. No global npm installation is needed.

## Install as your own Windows user

```powershell
git clone https://github.com/thdgeorge/visible-chrome-bridge.git
Set-Location visible-chrome-bridge
.\Install-Windows.ps1 -TunnelVersion 0.0.17 -McpVersion 1.11.0
```

These exact upstream versions reproduce the **tested beta baseline**. Omitting both version flags on a **fresh install** selects the **current stable upstream versions** instead; those may include security/compatibility fixes but are not automatically covered by the earlier QA. See [version-selection guidance](UPDATES.md#tested-beta-baseline-versus-upstream-latest). Re-running the installer preserves the existing payload; use `Update-Bridge.ps1` to change installed dependency versions.

**No Git installed?** On the [repository Code page](https://github.com/thdgeorge/visible-chrome-bridge), select **Code → Download ZIP** for the current `main` source, or choose a versioned `Source code (zip)` archive from [GitHub Releases](https://github.com/thdgeorge/visible-chrome-bridge/releases). Extract it, open PowerShell **inside the extracted project directory containing `Install-Windows.ps1`**, and run the same installer command. Git is not required. Review script origin before execution. If Windows marks the archive as downloaded, use Properties > Unblock before extraction only after verifying it. Follow your organization's execution policy; no permanent policy change is required.

Enter the tunnel ID and runtime API key only at the secure interactive prompts. Do not put them in command arguments, transcripts, screenshots, issues, or repository files. A rerun preserves credentials and existing settings unless explicitly changed. `-ReplaceCredentials` deliberately asks for replacement credentials; stop your bridge before changing its installation.

The default root is `%LOCALAPPDATA%\VisibleChromeBridge`. It holds a private wrapper copy under `app`, versioned dependencies, state, and encrypted credentials. Installation does not migrate or modify pre-existing tunnel-client configuration.

For paths with spaces, quote values and reuse the same root on every command:

```powershell
$bridgeRoot = Join-Path $env:LOCALAPPDATA 'My Bridge'
.\Install-Windows.ps1 -DataRoot $bridgeRoot
.\Start-Bridge.ps1 -DataRoot $bridgeRoot
.\Get-BridgeStatus.ps1 -DataRoot $bridgeRoot
.\Stop-Bridge.ps1 -DataRoot $bridgeRoot
```

Use a dedicated local directory owned by this bridge. Do not use a repository, shared drive, browser profile, or another application's directory. Run commands as the same Windows user: DPAPI credentials are account-bound. Do not copy the private root between users.

Spaces and apostrophes in paths are supported. Directory junctions/reparse points,
UNC paths, and paths containing commas or line breaks are rejected. Commas are
delimiters in the upstream stdio command format. Node version-manager links are
resolved to the real `node.exe` before saving the startup path; keep that Node
version installed until you repair the bridge with another supported version.

## Prepare Chrome

Start Chrome yourself. In Chrome 144+, open `chrome://inspect/#remote-debugging` and enable the connection option. Accept Chrome's permission dialog when the MCP server requests access. With multiple profiles running, Chrome chooses its default profile; all open windows in that profile are available. Arbitrary profile selection is not promised. See upstream [automatic connection limitations](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/advanced-usage.md#automatically-connecting-to-a-running-chrome-instance).

## Start and confirm the connection

```powershell
.\Start-Bridge.ps1
.\Get-BridgeStatus.ps1
```

Start creates a hidden worker using installed dependencies. **It continues after the PowerShell window closes**. Chrome is not launched by the bridge; logon startup is **off by default**.

## Verify installation and first browser call

After `Start-Bridge.ps1`, inspect `Get-BridgeStatus.ps1` from the same Windows account and data root:

| Status | Expected | Interpretation |
| --- | --- | --- |
| `Installed` | `True` | Owned local installation exists |
| `Running` | `True` | Bridge worker is running |
| `Healthy` | `True` | Local health endpoint answered successfully |
| `RuntimeReady` | `True` | Local tunnel runtime is ready; **not proof of ChatGPT/browser access** |
| `BrowserVerified` | `False` is normal | **Always `False`**: local status cannot observe the result of your ChatGPT browser test |
| `TunnelVersion`, `McpVersion` | Installed versions | Useful for diagnosing mismatches |

If runtime readiness is pending, wait briefly and check the status again. If still unhealthy, see [troubleshooting](TROUBLESHOOTING.md). **Finish ChatGPT setup:** create the `Visible Chrome` plugin using **your tunnel**, manually open [https://example.com/](https://example.com/) in Chrome, and run the [read-only title test](CHATGPT-SETUP.md#prove-the-complete-path). Only a successful ChatGPT tool call with title **Example Domain** confirms the complete path.

## Optional startup and update policy

```powershell
.\Install-Windows.ps1 -StartAtLogon -UpdatePolicy Notify
```

This registers a per-user logon entry and scheduled checks for this root. Startup points at the installed copy, so the checkout need not stay in place. Registration does not start the current session. Chrome still needs to be opened by you. See [updates](UPDATES.md) before choosing `Unattended`. Default policy is `Manual`; reruns preserve preferences unless explicitly supplied.

## Stop and uninstall

```powershell
.\Stop-Bridge.ps1
.\Uninstall-Windows.ps1
```

Stop closes only this bridge's owned process tree. It never kills Chrome or other tunnel installations. Uninstall also removes this instance's logon and update registrations; private data is retained by default.

To deliberately delete its owned data after reviewing the root:

```powershell
.\Uninstall-Windows.ps1 -RemoveData
```

Use `-DataRoot` for custom installations. Local removal does not delete your OpenAI tunnel, revoke the key, or remove the ChatGPT connection; manage those separately if retiring the bridge. Unrelated installations are outside this uninstaller's ownership.
